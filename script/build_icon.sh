#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/generated_workspace.sh"

require_command clang
require_command sips
require_command python3

icon_renderer_source="${REPO_ROOT}/host/icon/render_icon.m"
generated_parent="$(generated_workspace_path "generated-source")"
generated_root="${generated_parent}/icon"
iconset_root="${generated_root}/DBCodeWrapper.iconset"
base_png="${generated_root}/DBCodeWrapper-1024.png"
output_icns="${generated_root}/DBCodeWrapper.icns"
icon_renderer="${generated_root}/render-icon"

generated_workspace_assert_path "generated-source" "${generated_root}"
generated_workspace_assert_path "build-cache" "${CACHE_ROOT}/clang-modules"
rm -rf "${generated_root}"
mkdir -p "${iconset_root}"

mkdir -p "${CACHE_ROOT}/clang-modules"
CLANG_MODULE_CACHE_PATH="${CACHE_ROOT}/clang-modules" clang -fobjc-arc -framework AppKit "${icon_renderer_source}" -o "${icon_renderer}"
"${icon_renderer}" "${base_png}"

for icon_size in 16 32 128 256 512; do
  retina_size=$((icon_size * 2))
  sips -z "${icon_size}" "${icon_size}" "${base_png}" --out "${iconset_root}/icon_${icon_size}x${icon_size}.png" >/dev/null
  sips -z "${retina_size}" "${retina_size}" "${base_png}" --out "${iconset_root}/icon_${icon_size}x${icon_size}@2x.png" >/dev/null
done

python3 "${REPO_ROOT}/script/build_icns.py" "${iconset_root}" "${output_icns}"
echo "${output_icns}"
