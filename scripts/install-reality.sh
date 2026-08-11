#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "错误：请使用 root 或 sudo 运行。" >&2
  exit 1
fi

: "${REALITY_TARGET:?请设置 REALITY_TARGET，例如 target.example:443}"
: "${REALITY_SERVER_NAME:?请设置 REALITY_SERVER_NAME}"

LISTEN_PORT="${LISTEN_PORT:-443}"
CLIENT_FINGERPRINT="${CLIENT_FINGERPRINT:-chrome}"
XRAY_BIN="/usr/local/bin/xray"
XRAY_CONFIG="/usr/local/etc/xray/config.json"
CLIENT_INFO="/root/reality-client.env"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="/root/reality-backup-${STAMP}"
KEY_TMP="$(mktemp /root/.reality-keypair.XXXXXX)"

cleanup() {
  rm -f "$KEY_TMP" /tmp/install-xray.sh
}
trap cleanup EXIT

case "$LISTEN_PORT" in
  ''|*[!0-9]*)
    echo "错误：LISTEN_PORT 必须是数字。" >&2
    exit 1
    ;;
esac

if (( LISTEN_PORT < 1 || LISTEN_PORT > 65535 )); then
  echo "错误：LISTEN_PORT 超出有效范围。" >&2
  exit 1
fi

if [[ ! "$REALITY_TARGET" =~ ^[A-Za-z0-9.-]+:[0-9]{1,5}$ ]]; then
  echo "错误：REALITY_TARGET 必须使用 hostname:port 格式。" >&2
  exit 1
fi

if [[ ! "$REALITY_SERVER_NAME" =~ ^[A-Za-z0-9.-]+$ ]]; then
  echo "错误：REALITY_SERVER_NAME 只能包含合法主机名字符。" >&2
  exit 1
fi

umask 077
mkdir -p "$BACKUP_DIR"
cp -a /usr/local/etc/xray "$BACKUP_DIR/" 2>/dev/null || true

apt-get update -qq
apt-get install -y -qq curl ca-certificates openssl

curl -fL --retry 3 \
  https://github.com/XTLS/Xray-install/raw/main/install-release.sh \
  -o /tmp/install-xray.sh
bash /tmp/install-xray.sh install

UUID="$($XRAY_BIN uuid)"
$XRAY_BIN x25519 > "$KEY_TMP"

PRIVATE_KEY="$(awk -F': *' '/^(PrivateKey|Private key):/ {print $2; exit}' "$KEY_TMP")"
PUBLIC_KEY="$(awk -F': *' '/^(Password \(PublicKey\)|PublicKey|Public key|Password):/ {print $2; exit}' "$KEY_TMP")"
SHORT_ID="$(openssl rand -hex 8)"

for value in UUID PRIVATE_KEY PUBLIC_KEY SHORT_ID; do
  if [[ -z "${!value:-}" ]]; then
    echo "错误：未能生成 $value。请检查当前 Xray x25519 输出格式。" >&2
    exit 1
  fi
done

install -d -m 755 /usr/local/etc/xray

cat > "$XRAY_CONFIG" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${LISTEN_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "raw",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "target": "${REALITY_TARGET}",
          "xver": 0,
          "serverNames": [
            "${REALITY_SERVER_NAME}"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            "${SHORT_ID}"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ]
}
EOF

chown root:nogroup "$XRAY_CONFIG"
chmod 640 "$XRAY_CONFIG"

cat > "$CLIENT_INFO" <<EOF
ADDRESS=<VPS_IP>
PORT=${LISTEN_PORT}
UUID=${UUID}
FLOW=xtls-rprx-vision
SECURITY=reality
SNI=${REALITY_SERVER_NAME}
FINGERPRINT=${CLIENT_FINGERPRINT}
PUBLIC_KEY=${PUBLIC_KEY}
SHORT_ID=${SHORT_ID}
NETWORK=tcp
EOF
chmod 600 "$CLIENT_INFO"

$XRAY_BIN run -test -config "$XRAY_CONFIG"
systemctl enable xray >/dev/null
systemctl restart xray
sleep 1

systemctl is-active --quiet xray
ss -lntp | grep -qE "[:.]${LISTEN_PORT}[[:space:]]"

echo "部署和本机校验完成。"
echo "备份目录：$BACKUP_DIR"
echo "客户端参数仅保存在：$CLIENT_INFO"
echo "脚本不会打印客户端参数。请继续配置防火墙并进行外部验收。"
