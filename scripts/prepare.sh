#!/usr/bin/env bash
set -Eeuo pipefail


workspace="$(cd "${1:?source directory is required}" && pwd)"
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"


cd "$workspace"


rm -f .config


# QModem is a build-time source feed, not a runtime OPKG/APK repository.
# Keep feeds.conf.default untouched so its Git URL cannot leak into firmware.
test -f feeds.conf || cp feeds.conf.default feeds.conf
if ! grep -Eq '^src-git(-full)?[[:space:]]+qmodem[[:space:]]' feeds.conf; then
  printf '%s\n' 'src-git qmodem https://github.com/FUjr/QModem.git;main' >> feeds.conf
fi


./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds install -a -f -p qmodem
test -f package/feeds/qmodem/luci-app-qmodem-next/Makefile || {
  echo 'QModem feed did not install luci-app-qmodem-next.' >&2
  exit 1
}


rm -rf package/mtk/applications/5g-modem


# Remove obsolete Argon theme and config package
find feeds/luci feeds/packages -maxdepth 3 -type d \
  \( -name 'luci-theme-argon' -o -name 'luci-app-argon-config' \) \
  -prune -exec rm -rf {} + 2>/dev/null || true
rm -rf package/luci-theme-argon package/luci-app-argon-config

# Fetch Footstrap source
footstrap_tmp="$(mktemp -d)"
if ! git clone --depth 1 \
  https://github.com/VizzleTF/luci-theme-footstrap.git "$footstrap_tmp"; then
  rm -rf "$footstrap_tmp"
  exit 1
fi

if [ ! -f "$footstrap_tmp/luci-theme-footstrap/Makefile" ]; then
  echo 'Footstrap package Makefile not found; inspect upstream repository layout.' >&2
  find "$footstrap_tmp" -maxdepth 3 -name Makefile -print
  rm -rf "$footstrap_tmp"
  exit 1
fi

rm -rf package/luci-theme-footstrap
mv "$footstrap_tmp/luci-theme-footstrap" package/luci-theme-footstrap
rm -rf "$footstrap_tmp"

test -f package/luci-theme-footstrap/Makefile

# 2. 建立 files 檔案結構並複製 overlay 腳本
mkdir -p files/etc/uci-defaults
if [ -f "$project_root/overlay/etc/uci-defaults/99-h5000m-zh-tw" ]; then
    cp -a "$project_root/overlay/etc/uci-defaults/99-h5000m-zh-tw" files/etc/uci-defaults/
fi
chmod +x files/etc/uci-defaults/99-h5000m-zh-tw


curl -sSL "https://raw.githubusercontent.com/padavanonly/immortalwrt-mt798x-6.6/mt798x-mt799x-6.6-mtwifi/defconfig/mt7987_mt7992.config" > .config
cat "$project_root/config/h5000m.config" >> .config


make defconfig


for required in \
  'CONFIG_PACKAGE_luci-app-qmodem-next=y' \
  'CONFIG_PACKAGE_luci-app-qmodem-ttlfw4=y' \
  'CONFIG_PACKAGE_qmodem=y' \
  'CONFIG_PACKAGE_ndisc6=y' \
  'CONFIG_PACKAGE_kmod-mt7992=y' \
  'CONFIG_PACKAGE_kmod-mt799a=y' \
  'CONFIG_PACKAGE_kmod-mt_hwifi=y' \
  'CONFIG_PACKAGE_kmod-mt_wifi7=y' \
  'CONFIG_PACKAGE_luci-ssl-openssl=y' \
  'CONFIG_PACKAGE_luci-theme-footstrap=y' \
  'CONFIG_WARP_VERSION="3_1"'; do
  grep -Fqx "$required" .config || {
    echo "Required build setting is missing: $required" >&2
    exit 1
  }
done


for forbidden in \
  'CONFIG_PACKAGE_luci-app-modem=y' \
  'CONFIG_PACKAGE_luci-app-qmodem=y' \
  'CONFIG_PACKAGE_luci-app-qmodem-sms=y' \
  'CONFIG_PACKAGE_luci-app-qmodem-mwan=y' \
  'CONFIG_PACKAGE_luci-app-qmodem-ttl=y' \
  'CONFIG_PACKAGE_luci-app-qmodem-hc=y' \
  'CONFIG_PACKAGE_libustream-mbedtls=y' \
  'CONFIG_PACKAGE_libustream-mbedtls20201210=y'; do
  if grep -Fqx "$forbidden" .config; then
    echo "Conflicting build setting was selected: $forbidden" >&2
    exit 1
  fi
done



# QModem packages are already linked under package/feeds/qmodem. Remove only
# the source-feed entry before the firmware build so base-files cannot emit a
# non-existent qmodem binary repository into /etc/opkg/distfeeds.conf.
sed -i -E '/^[[:space:]]*src-git(-full)?[[:space:]]+qmodem[[:space:]]+/d' feeds.conf
if grep -Eq '^[[:space:]]*src-git(-full)?[[:space:]]+qmodem[[:space:]]' feeds.conf; then
  echo 'QModem source feed remained in feeds.conf after sanitizing.' >&2
  exit 1
fi
printf 'Theme: luci-theme-footstrap\nSource: VizzleTF/luci-theme-footstrap\n' > .footstrap-buildinfo


echo 'Build configuration is ready.'
