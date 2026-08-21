#!/usr/bin/env bash
set -Eeuo pipefail

workspace="${1:?請提供上游原始碼目錄}"
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$workspace"

./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds install -a -f -p qmodem

# 使用最新版 Argon 主題；若上游已提供同名套件，先移除以避免重複定義。
find feeds/luci feeds/packages -maxdepth 3 -type d \
  \( -name 'luci-theme-argon' -o -name 'luci-app-argon-config' \) \
  -prune -exec rm -rf {} + 2>/dev/null || true
rm -rf package/luci-theme-argon
git clone --depth 1 --branch openwrt-24.10 \
  https://github.com/sbwml/luci-theme-argon.git package/luci-theme-argon

install -d package/base-files/files/etc/uci-defaults
install -m 0755 "$project_root/overlay/etc/uci-defaults/99-h5000m-zh-tw" \
  package/base-files/files/etc/uci-defaults/99-h5000m-zh-tw

cat "$project_root/config/h5000m.config" > .config
make defconfig

echo '設定準備完成。'

