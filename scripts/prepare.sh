#!/usr/bin/env bash
set -Eeuo pipefail

workspace="${1:?source directory is required}"
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$workspace"

# QModem is not part of the standard ImmortalWrt 24.10 feeds.  Register its
# official source before updating feeds so luci-app-qmodem-next is available.
if ! grep -Eq '^src-git(-full)?[[:space:]]+qmodem[[:space:]]' feeds.conf.default; then
  printf '%s\n' 'src-git qmodem https://github.com/FUjr/QModem.git;main' >> feeds.conf.default
fi

./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds install -a -f -p qmodem
test -f package/feeds/qmodem/luci-app-qmodem-next/Makefile || {
  echo 'QModem feed did not install luci-app-qmodem-next.' >&2
  exit 1
}

# Backport the current OpenWrt AdGuard Home package and LuCI integration.
# The package recipe follows the latest stable upstream release and is rebuilt
# by this ImmortalWrt tree as an IPK; the complete OpenWrt feeds are not mixed.
adguard_sources="$(mktemp -d)"
trap 'rm -rf "$adguard_sources"' EXIT

git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/openwrt/packages.git "$adguard_sources/packages"
git -C "$adguard_sources/packages" sparse-checkout set net/adguardhome

git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/openwrt/luci.git "$adguard_sources/luci"
git -C "$adguard_sources/luci" sparse-checkout set applications/luci-app-adguardhome

adguard_latest_version="$(sed -n 's/^PKG_VERSION:=//p' \
  "$adguard_sources/packages/net/adguardhome/Makefile" | head -n 1)"
test -n "$adguard_latest_version"

# ImmortalWrt 24.10 currently provides Go 1.23.x.  AdGuard Home 0.107.57 is
# the final stable release using Go 1.23; 0.107.58 and later require Go 1.24+.
adguard_version='0.107.57'
adguard_source_hash='9df951486dab0e83485b596c0393f91d4ff2994de26101b43af8344efb7c1536'
adguard_frontend_hash='fc0b57d80dece4219bfba833b48122ffe7a140ee2026cd3cf4c7181ccdcf8c9e'

rm -rf feeds/packages/net/adguardhome feeds/luci/applications/luci-app-adguardhome
cp -a "$adguard_sources/packages/net/adguardhome" feeds/packages/net/adguardhome
cp -a "$adguard_sources/luci/applications/luci-app-adguardhome" \
  feeds/luci/applications/luci-app-adguardhome

sed -i \
  -e "s/^PKG_VERSION:=.*/PKG_VERSION:=$adguard_version/" \
  -e "s/^PKG_HASH:=.*/PKG_HASH:=$adguard_source_hash/" \
  -e "s/^FRONTEND_HASH:=.*/FRONTEND_HASH:=$adguard_frontend_hash/" \
  feeds/packages/net/adguardhome/Makefile

./scripts/feeds update -i packages
./scripts/feeds update -i luci
./scripts/feeds install -f -p packages adguardhome
./scripts/feeds install -f -p luci luci-app-adguardhome

grep -Fq "option config_file '/etc/adguardhome/adguardhome.yaml'" \
  feeds/packages/net/adguardhome/files/adguardhome.conf
grep -Fq "option work_dir '/var/lib/adguardhome'" \
  feeds/packages/net/adguardhome/files/adguardhome.conf

# Use the maintained master sources and compile both packages inside this
# ImmortalWrt 24.10 tree as IPKs.  The obsolete 18.06/0.9.x branch is excluded.
find feeds/luci feeds/packages -maxdepth 3 -type d \
  \( -name 'luci-theme-argon' -o -name 'luci-app-argon-config' \) \
  -prune -exec rm -rf {} + 2>/dev/null || true
rm -rf package/luci-theme-argon package/luci-app-argon-config
git clone --depth 1 --branch master \
  https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone --depth 1 --branch master \
  https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config

# The upstream master supports both APK and IPK.  This ImmortalWrt 24.10 tree
# is IPK-only and does not provide the APK-only wget-any virtual package.
sed -i 's/^LUCI_DEPENDS:=.*/LUCI_DEPENDS:=+wget +jsonfilter/' \
  package/luci-theme-argon/Makefile

# Never fall back to Jerrykuku's obsolete 18.06/0.9.x config package.
argon_config_makefile='package/luci-app-argon-config/Makefile'
test -f "$argon_config_makefile"
argon_config_version="$(sed -n 's/^PKG_VERSION:=//p' \
  "$argon_config_makefile" | head -n 1)"
test -n "$argon_config_version"
case "$argon_config_version" in
  0.9*)
    echo "Obsolete luci-app-argon-config was selected: $argon_config_version" >&2
    exit 1
    ;;
esac

install -d package/base-files/files/etc/uci-defaults
install -m 0755 "$project_root/overlay/etc/uci-defaults/99-h5000m-zh-tw" \
  package/base-files/files/etc/uci-defaults/99-h5000m-zh-tw

cat "$project_root/config/h5000m.config" > .config
make defconfig

for required in \
  'CONFIG_PACKAGE_adguardhome=y' \
  'CONFIG_PACKAGE_luci-app-adguardhome=y' \
  'CONFIG_PACKAGE_luci-app-qmodem-next=y' \
  'CONFIG_PACKAGE_luci-ssl-openssl=y' \
  'CONFIG_WARP_VERSION="3_1"'; do
  grep -Fqx "$required" .config || {
    echo "Required build setting is missing: $required" >&2
    exit 1
  }
done

for forbidden in \
  'CONFIG_PACKAGE_luci-app-modem=y' \
  'CONFIG_PACKAGE_luci-app-qmodem=y' \
  'CONFIG_PACKAGE_libustream-mbedtls=y' \
  'CONFIG_PACKAGE_libustream-mbedtls20201210=y'; do
  if grep -Fqx "$forbidden" .config; then
    echo "Conflicting build setting was selected: $forbidden" >&2
    exit 1
  fi
done

printf 'AdGuard Home: %s (pinned for Go 1.23 compatibility)\nLatest recipe observed: %s\nPackage recipe: openwrt/packages master\nLuCI source: openwrt/luci master\n' \
  "$adguard_version" "$adguard_latest_version" > .adguardhome-buildinfo

printf 'Argon theme source: jerrykuku/luci-theme-argon master\nArgon config: %s (modern master source, built as IPK; 0.9.x rejected)\n' \
  "$argon_config_version" > .argon-buildinfo

echo 'Build configuration is ready.'

