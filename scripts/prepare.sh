
#!/usr/bin/env bash
set -Eeuo pipefail

workspace="$(cd "${1:?source directory is required}" && pwd)"
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$workspace"

rm -f .config

# ============================================================
# QModem: pin source commit, update feed, install packages
# ============================================================

# QModem is a build-time source feed, not a runtime OPKG/APK repository.
# Keep feeds.conf.default untouched.
test -f feeds.conf || cp feeds.conf.default feeds.conf

QMODEM_URL='https://github.com/FUjr/QModem.git'
QMODEM_COMMIT='5cc80e5f9fc218cd50bef9749dc7d0027e8b3072'

echo "=== Configuring pinned QModem feed ==="

# Remove any existing QModem feed entry to avoid stale configuration.
sed -i -E \
  '/^[[:space:]]*src-git(-full)?[[:space:]]+qmodem[[:space:]]+/d' \
  feeds.conf

# OpenWrt feed syntax: ^commit_hash pins an exact Git commit.
printf '%s\n' \
  "src-git qmodem ${QMODEM_URL}^${QMODEM_COMMIT}" >> feeds.conf

grep -n -E \
  '^[[:space:]]*src-git(-full)?[[:space:]]+qmodem[[:space:]]' \
  feeds.conf

echo "=== Updating all feeds ==="
./scripts/feeds update -a

echo "=== Verifying QModem feed directory ==="
if [ ! -d feeds/qmodem/.git ]; then
  echo "ERROR: QModem feed was not cloned successfully." >&2
  ls -la feeds  >&2 || true
  exit 1
fi

echo "=== Verifying checked-out QModem commit ==="
actual_commit="$(git -C feeds/qmodem rev-parse HEAD)"
if [ "$actual_commit" != "$QMODEM_COMMIT" ]; then
  echo "ERROR: QModem commit mismatch." >&2
  echo "Expected: $QMODEM_COMMIT" >&2
  echo "Actual:   $actual_commit" >&2
  exit 1
fi

echo "QModem commit verified: $actual_commit"

echo "=== Installing all feeds ==="
./scripts/feeds install -a

echo "=== Installing QModem packages ==="
./scripts/feeds install -a -f -p qmodem

echo "=== Verifying QModem package ==="
if [ ! -f package/feeds/qmodem/luci-app-qmodem-next/Makefile ]; then
  echo "ERROR: luci-app-qmodem-next was not installed." >&2
  ls -la package/feeds/qmodem >&2 || true
  exit 1
fi

echo "QModem package installed successfully."

# Remove the source-feed entry after package links have been installed.
# This prevents the QModem build-time feed from being treated as a
# runtime binary package repository.
sed -i -E \
  '/^[[:space:]]*src-git(-full)?[[:space:]]+qmodem[[:space:]]+/d' \
  feeds.conf

if grep -Eq \
  '^[[:space:]]*src-git(-full)?[[:space:]]+qmodem[[:space:]]' \
  feeds.conf; then
  echo "ERROR: QModem source feed remained in feeds.conf." >&2
  exit 1
fi

echo "QModem feed setup completed."

# ============================================================
# Optional AdGuard Home LuCI selection
# Default: disabled
# ============================================================
ENABLE_ADGUARDHOME="${ENABLE_ADGUARDHOME:-}"

if [ -z "$ENABLE_ADGUARDHOME" ]; then
  if [ -t 0 ]; then
    printf '\n'
    printf '%s\n' 'Include AdGuard Home LuCI in this firmware?'
    printf '%s\n' '  1) Enable'
    printf '%s\n' '  0) Disable (default)'
    read -r -p 'Select [0]: ' adguard_answer
    case "$adguard_answer" in
      1|y|Y|yes|YES|true|TRUE) ENABLE_ADGUARDHOME=1 ;;
      *) ENABLE_ADGUARDHOME=0 ;;
    esac
  else
    ENABLE_ADGUARDHOME=0
  fi
fi

case "$ENABLE_ADGUARDHOME" in
  1|true|TRUE|yes|YES) ENABLE_ADGUARDHOME=1 ;;
  0|false|FALSE|no|NO) ENABLE_ADGUARDHOME=0 ;;
  *)
    echo "ERROR: ENABLE_ADGUARDHOME must be true/false or 1/0." >&2
    exit 1
    ;;
esac

echo "AdGuard Home enabled: $ENABLE_ADGUARDHOME"

if [ "$ENABLE_ADGUARDHOME" = "1" ]; then

  # ============================================================
  # AdGuard Home LuCI app: pinned source feed
  # ============================================================

  ADGUARDHOME_URL='https://github.com/w9315273/luci-app-adguardhome.git'
  ADGUARDHOME_COMMIT='27853f3e1a831c9fd0380c166f68c7e0e0b9736f'

  echo "=== Configuring pinned AdGuard Home LuCI feed ==="

  test -f feeds.conf || cp feeds.conf.default feeds.conf

  sed -i -E \
    '/^[[:space:]]*src-git(-full)?[[:space:]]+adguardhome[[:space:]]+/d' \
    feeds.conf

  printf '%s\n' \
    "src-git adguardhome ${ADGUARDHOME_URL}^${ADGUARDHOME_COMMIT}" >> feeds.conf

  ./scripts/feeds update adguardhome

  if [ ! -d feeds/adguardhome/.git ]; then
    echo "ERROR: AdGuard Home feed was not cloned." >&2
    ls -la feeds >&2 || true
    exit 1
  fi

  actual_adguardhome_commit="$(git -C feeds/adguardhome rev-parse HEAD)"
  if [ "$actual_adguardhome_commit" != "$ADGUARDHOME_COMMIT" ]; then
    echo "ERROR: AdGuard Home commit mismatch." >&2
    echo "Expected: $ADGUARDHOME_COMMIT" >&2
    echo "Actual:   $actual_adguardhome_commit" >&2
    exit 1
  fi

  echo "AdGuard Home commit verified: $actual_adguardhome_commit"

  ./scripts/feeds install -a -f -p adguardhome

  if [ ! -f package/feeds/adguardhome/luci-app-adguardhome/Makefile ]; then
    echo "ERROR: luci-app-adguardhome Makefile was not installed." >&2
    find package/feeds/adguardhome -maxdepth 3 -name Makefile -print >&2 2>/dev/null || true
    exit 1
  fi

  echo "AdGuard Home LuCI package installed successfully."

  # 安裝完成後移除暫時的來源 feed 設定
  sed -i -E \
    '/^[[:space:]]*src-git(-full)?[[:space:]]+adguardhome[[:space:]]+/d' \
    feeds.conf

  if grep -Eq \
    '^[[:space:]]*src-git(-full)?[[:space:]]+adguardhome[[:space:]]' \
    feeds.conf; then
    echo "ERROR: AdGuard Home feed entry was not removed." >&2
    exit 1
  fi

  echo "AdGuard Home feed setup completed."

else
  echo "AdGuard Home disabled; skipping its feed and package installation."
fi

# ============================================================
# Remove the vendor modem package
# ============================================================

rm -rf package/mtk/applications/5g-modem

# ============================================================
# Replace Argon with Footstrap
# ============================================================

echo "=== Removing Argon theme packages ==="

find feeds/luci feeds/packages -maxdepth 3 -type d \
  \( -name 'luci-theme-argon' -o -name 'luci-app-argon-config' \) \
  -prune -exec rm -rf {} + 2>/dev/null || true

rm -rf package/luci-theme-argon package/luci-app-argon-config

echo "=== Fetching Footstrap source ==="

footstrap_tmp="$(mktemp -d)"

if ! git clone --depth 1 \
  https://github.com/VizzleTF/luci-theme-footstrap.git \
  "$footstrap_tmp"; then
  rm -rf "$footstrap_tmp"
  echo "ERROR: Failed to clone Footstrap." >&2
  exit 1
fi

if [ ! -f "$footstrap_tmp/luci-theme-footstrap/Makefile" ]; then
  echo "ERROR: Footstrap package Makefile not found." >&2
  find "$footstrap_tmp" -maxdepth 4 -name Makefile -print >&2 || true
  rm -rf "$footstrap_tmp"
  exit 1
fi

rm -rf package/luci-theme-footstrap
mv "$footstrap_tmp/luci-theme-footstrap" package/luci-theme-footstrap
rm -rf "$footstrap_tmp"

test -f package/luci-theme-footstrap/Makefile

echo "Footstrap source installed."

# ============================================================
# Install H5000M overlay script
# ============================================================

echo "=== Installing H5000M overlay script ==="

overlay_script="$project_root/overlay/etc/uci-defaults/99-h5000m-zh-tw"

if [ ! -f "$overlay_script" ]; then
  echo "ERROR: H5000M overlay script not found: $overlay_script" >&2
  exit 1
fi

mkdir -p files/etc/uci-defaults
cp -a "$overlay_script" files/etc/uci-defaults/
chmod +x files/etc/uci-defaults/99-h5000m-zh-tw

# ============================================================
# Load upstream defconfig and H5000M configuration
# ============================================================

echo "=== Downloading upstream defconfig ==="

curl -fsSL \
  "https://raw.githubusercontent.com/padavanonly/immortalwrt-mt798x-6.6/mt798x-mt799x-6.6-mtwifi/defconfig/mt7987_mt7992.config" \
  -o .config

if [ ! -s .config ]; then
  echo "ERROR: Upstream defconfig is missing or empty." >&2
  exit 1
fi

cat "$project_root/config/h5000m.config" >> .config

echo "=== Running make defconfig ==="
if [ "$ENABLE_ADGUARDHOME" = "1" ]; then
  printf '%s\n' 'CONFIG_PACKAGE_luci-app-adguardhome=y' >> .config
fi
make defconfig

# ============================================================
# Verify required build settings
# ============================================================

echo "=== Checking required build settings ==="

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

  if ! grep -Fqx "$required" .config; then
    echo "ERROR: Required build setting is missing: $required" >&2
    exit 1
  fi
done

# ============================================================
# Verify forbidden/conflicting build settings
# ============================================================

echo "=== Checking conflicting build settings ==="

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
    echo "ERROR: Conflicting build setting was selected: $forbidden" >&2
    exit 1
  fi
done

# ============================================================
# Record theme build information
# ============================================================

printf 'Theme: luci-theme-footstrap\nSource: VizzleTF/luci-theme-footstrap\n' \
  > .footstrap-buildinfo

echo "Build configuration is ready."
