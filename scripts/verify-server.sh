#!/usr/bin/env bash
set -Eeuo pipefail

LISTEN_PORT="${LISTEN_PORT:-443}"
XRAY_BIN="${XRAY_BIN:-/usr/local/bin/xray}"
XRAY_CONFIG="${XRAY_CONFIG:-/usr/local/etc/xray/config.json}"

failed=0

check() {
  local label="$1"
  shift
  if "$@"; then
    printf '通过：%s\n' "$label"
  else
    printf '失败：%s\n' "$label" >&2
    failed=1
  fi
}

check "Xray 程序存在" test -x "$XRAY_BIN"
check "Xray 配置存在" test -f "$XRAY_CONFIG"

if [[ -x "$XRAY_BIN" && -f "$XRAY_CONFIG" ]]; then
  check "Xray 配置校验" "$XRAY_BIN" run -test -config "$XRAY_CONFIG"
fi

check "Xray 服务 active" systemctl is-active --quiet xray
check "目标端口正在监听" sh -c "ss -lntp | grep -qE '[:.]${LISTEN_PORT}[[:space:]]'"

if command -v ufw >/dev/null 2>&1; then
  ufw status
else
  echo "提示：未安装 UFW。"
fi

if command -v fail2ban-client >/dev/null 2>&1; then
  fail2ban-client status sshd || true
else
  echo "提示：未安装 Fail2ban。"
fi

if (( failed != 0 )); then
  echo "服务器验收未通过。不要继续客户端导入。" >&2
  exit 1
fi

echo "服务器本机验收通过。仍需执行外部 TCP 和真实客户端请求测试。"
