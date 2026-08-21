#!/usr/bin/env bash
set -Eeuo pipefail

workspace="${1:?source directory is required}"
output="${2:?output directory is required}"

rm -rf "$output"
mkdir -p "$output"

mapfile -t firmware < <(find "$workspace/bin/targets" -type f \
  \( -iname '*h5000m*' -o -name '*.manifest' -o -name '*.buildinfo' \))

if (( ${#firmware[@]} == 0 )); then
  echo 'No H5000M firmware artifacts were found.' >&2
  exit 1
fi

cp -f "${firmware[@]}" "$output/"
cp -f "$workspace/.config" "$output/build.config"
cp -f "$workspace/.adguardhome-buildinfo" "$output/ADGUARDHOME-SOURCE.txt"
cp -f "$workspace/.argon-buildinfo" "$output/ARGON-SOURCE.txt"

(
  cd "$output"
  sha256sum -- * > SHA256SUMS
)

echo "Collected ${#firmware[@]} build artifacts."

