#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

failed=0
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

scan_pattern() {
  local label="$1"
  local pattern="$2"

  if git grep -nEI "$pattern" -- . \
    ':!scripts/check-sensitive.sh' \
    ':!.gitignore' > "$tmp" 2>/dev/null; then
    if grep -vE '<(UUID|VLESS_URI|TOKEN|VPS_IP|REALITY_PRIVATE_KEY)>' "$tmp" >/dev/null; then
      echo "发现可能的${label}：" >&2
      grep -vE '<(UUID|VLESS_URI|TOKEN|VPS_IP|REALITY_PRIVATE_KEY)>' "$tmp" >&2
      failed=1
    fi
  fi
}

scan_pattern "节点 URI" 'vless://'
scan_pattern "UUID" '[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}'
scan_pattern "GitHub Token" 'gh[opsu]_[A-Za-z0-9]{20,}'
scan_pattern "私钥" 'BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY'

if git grep -nE '([0-9]{1,3}\.){3}[0-9]{1,3}' -- . \
  ':!scripts/check-sensitive.sh' > "$tmp" 2>/dev/null; then
  unexpected_ip="$(grep -vE '(^|[^0-9])(0\.0\.0\.0|127\.0\.0\.1|1\.1\.1\.1|192\.0\.2\.[0-9]+|198\.51\.100\.[0-9]+|203\.0\.113\.[0-9]+)([^0-9]|$)' "$tmp" || true)"
  if [[ -n "$unexpected_ip" ]]; then
    echo "发现需要人工确认的 IPv4 地址：" >&2
    printf '%s\n' "$unexpected_ip" >&2
    failed=1
  fi
fi

if (( failed != 0 )); then
  echo "敏感信息扫描失败。请先检查并清理。" >&2
  exit 1
fi

echo "敏感信息扫描通过。仍需人工检查 git diff。"
