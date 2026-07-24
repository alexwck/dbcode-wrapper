#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/patch_plan.sh"

require_command git
require_command jq

patch_plan_validate

vscodium_cache="${CACHE_ROOT}/vscodium.git"
code_oss_cache="${CACHE_ROOT}/code-oss.git"

mkdir -p "${CACHE_ROOT}" "${BUILD_ROOT}/work"

prepare_bare_cache() {
  local cache_dir="${1}"
  local remote_url="${2}"

  if [[ ! -d "${cache_dir}" ]]; then
    git init --bare "${cache_dir}" >/dev/null
    git --git-dir="${cache_dir}" remote add origin "${remote_url}"
  fi
}

prepare_bare_cache "${vscodium_cache}" "${VSCODIUM_REPOSITORY}"
if ! git --git-dir="${vscodium_cache}" cat-file -e "${VSCODIUM_COMMIT}^{commit}" 2>/dev/null; then
  git --git-dir="${vscodium_cache}" fetch --depth 1 origin "refs/tags/${VSCODIUM_TAG}:refs/tags/${VSCODIUM_TAG}"
fi
vscodium_actual="$(git --git-dir="${vscodium_cache}" rev-parse "refs/tags/${VSCODIUM_TAG}^{commit}")"
if [[ "${vscodium_actual}" != "${VSCODIUM_COMMIT}" ]]; then
  echo "VSCodium tag ${VSCODIUM_TAG} resolved to ${vscodium_actual}, expected ${VSCODIUM_COMMIT}." >&2
  exit 1
fi

prepare_bare_cache "${code_oss_cache}" "${CODE_OSS_REPOSITORY}"
if ! git --git-dir="${code_oss_cache}" cat-file -e "${CODE_OSS_COMMIT}^{commit}" 2>/dev/null; then
  git --git-dir="${code_oss_cache}" fetch --depth 1 origin "${CODE_OSS_COMMIT}:refs/dbcode-wrapper/pinned"
fi
code_oss_actual="$(git --git-dir="${code_oss_cache}" rev-parse "${CODE_OSS_COMMIT}^{commit}")"
if [[ "${code_oss_actual}" != "${CODE_OSS_COMMIT}" ]]; then
  echo "Code OSS commit mismatch: ${code_oss_actual}." >&2
  exit 1
fi

assert_generated_path "${WORK_ROOT}"
rm -rf "${WORK_ROOT}"
git clone --quiet --no-checkout "${vscodium_cache}" "${WORK_ROOT}"
git -C "${WORK_ROOT}" checkout --quiet --detach "${VSCODIUM_COMMIT}"

while IFS= read -r overlay_patch; do
  git -C "${WORK_ROOT}" apply "${overlay_patch}"
done < <(patch_plan_files vscodium)

mkdir -p "${WORK_ROOT}/vscode"
git -C "${WORK_ROOT}/vscode" init --quiet
git -C "${WORK_ROOT}/vscode" config filter.lfs.process ""
git -C "${WORK_ROOT}/vscode" config filter.lfs.smudge cat
git -C "${WORK_ROOT}/vscode" config filter.lfs.clean cat
git -C "${WORK_ROOT}/vscode" config filter.lfs.required false
git -C "${WORK_ROOT}/vscode" remote add origin "${code_oss_cache}"
git -C "${WORK_ROOT}/vscode" fetch --quiet --depth 1 origin "${CODE_OSS_COMMIT}"
git -C "${WORK_ROOT}/vscode" checkout --quiet --detach FETCH_HEAD

mkdir -p "${WORK_ROOT}/patches/user"
while IFS= read -r code_oss_patch; do
  cp "${code_oss_patch}" "${WORK_ROOT}/patches/user/$(basename "${code_oss_patch}")"
done < <(patch_plan_files code-oss)

icon_path="$("${REPO_ROOT}/script/build_icon.sh")"
cp "${icon_path}" "${WORK_ROOT}/src/stable/resources/darwin/code.icns"
cp "${REPO_ROOT}/host/icon/dbcode-wrapper.svg" "${WORK_ROOT}/src/stable/src/vs/workbench/browser/media/code-icon.svg"

printf '%s\n' "vscodium=${VSCODIUM_COMMIT}" "code_oss=${CODE_OSS_COMMIT}" > "${WORK_ROOT}/.dbcode-wrapper-overlay"

echo "Prepared VSCodium ${VSCODIUM_TAG} (${VSCODIUM_COMMIT})"
echo "Prepared Code OSS ${CODE_OSS_TAG} (${CODE_OSS_COMMIT})"
