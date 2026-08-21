# AirPi H5000M Firmware Builder

An independent cloud build project for the Hiveton / AirPi H5000M. It builds CloseWRT-based firmware from PadavanOnly's MT7987 / MT7992 branch with a Traditional Chinese LuCI interface, 5G modem tools, and practical H5000M packages.

## Features

- Traditional Chinese (`zh_tw`) LuCI is enabled inside the firmware.
- The firmware defaults to the `Asia/Taipei` timezone.
- QModem, MBIM, QMI, and common USB 5G modem support.
- Jerrykuku's Argon theme and Argon configuration app.
- ccache, download cache, and host toolchain cache for faster rebuilds.
- Weekly builds at 04:00 Monday in Taiwan, plus manual builds.
- Every release includes firmware, the resolved build configuration, and SHA256 checksums.
- Existing releases are retained for rollback.

## Download

Open **Releases** and download the firmware file containing `h5000m` in its name. Verify it against `SHA256SUMS` before flashing.

## Run a manual build

1. Open **Actions**.
2. Select **Build H5000M firmware**.
3. Select **Run workflow**.
4. Leave **Ignore existing build cache** disabled for normal builds.

The first build creates the toolchain and compiler cache. Later builds should be significantly faster.

## Safety

- This project automates firmware builds and cannot guarantee compatibility with every hardware revision.
- Back up the factory firmware, EEPROM, partitions, and configuration before flashing.
- Confirm that the device is a Hiveton / AirPi H5000M.
- Set a strong administrator password immediately after first login.
- Upstream source code, drivers, themes, and packages retain their respective licenses.

## Repository layout

```text
.github/workflows/build.yml   GitHub Actions build and release workflow
config/h5000m.config          Minimal maintainable firmware seed configuration
overlay/                      First-boot Traditional Chinese and timezone defaults
scripts/prepare.sh            Feed, theme, and configuration preparation
scripts/collect.sh            Artifact collection and SHA256 generation
```

## Upstream projects

- [PadavanOnly ImmortalWrt MT798x](https://github.com/padavanonly/immortalwrt-mt798x-6.6)
- [QModem](https://github.com/FUjr/QModem)
- [Jerrykuku Argon theme](https://github.com/jerrykuku/luci-theme-argon)
- [Jerrykuku Argon configuration app](https://github.com/jerrykuku/luci-app-argon-config)

The automation in this repository is licensed under the MIT License. That license does not replace the licenses of any upstream firmware source, driver, theme, or package.

