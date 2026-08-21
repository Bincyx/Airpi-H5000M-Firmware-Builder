#!/usr/bin/env bash
set -Eeuo pipefail

workspace="${1:?請提供上游原始碼目錄}"
output="${2:?請提供輸出目錄}"

rm -rf "$output"
mkdir -p "$output"

mapfile -t firmware < <(find "$workspace/bin/targets" -type f \
  \( -iname '*h5000m*' -o -name '*.manifest' -o -name 'sha256sums' -o -name '*.buildinfo' \))

if (( ${#firmware[@]} == 0 )); then
  echo '找不到 H5000M 韌體產物。' >&2
  exit 1
fi

cp -f "${firmware[@]}" "$output/"
cp -f "$workspace/.config" "$output/build.config"

(
  cd "$output"
  sha256sum -- * > SHA256SUMS
)

echo "已收集 ${#firmware[@]} 個建置產物。"

