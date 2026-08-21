#!/usr/bin/env bash
set -Eeuo pipefail

workspace="${1:?source directory is required}"
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$workspace"

./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds install -a -f -p qmodem

# Use Jerrykuku's maintained Argon theme and configuration app.
find feeds/luci feeds/packages -maxdepth 3 -type d \
  \( -name 'luci-theme-argon' -o -name 'luci-app-argon-config' \) \
  -prune -exec rm -rf {} + 2>/dev/null || true
rm -rf package/luci-theme-argon package/luci-app-argon-config
git clone --depth 1 --branch master \
  https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone --depth 1 --branch master \
  https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config

install -d package/base-files/files/etc/uci-defaults
install -m 0755 "$project_root/overlay/etc/uci-defaults/99-h5000m-zh-tw" \
  package/base-files/files/etc/uci-defaults/99-h5000m-zh-tw

cat "$project_root/config/h5000m.config" > .config
make defconfig

echo 'Build configuration is ready.'

