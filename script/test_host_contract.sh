#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/local_signing_identity.sh"
source "${REPO_ROOT}/script/lib/patch_plan.sh"

check_built_artifact="yes"
if [[ $# -eq 1 && "${1}" == "--source-only" ]]; then
  check_built_artifact="no"
elif [[ $# -ne 0 ]]; then
  echo "Usage: ./script/test_host_contract.sh [--source-only]" >&2
  exit 2
fi

release_specification_validate "${LOCK_FILE}"
jq -e . "${REPO_ROOT}"/host/profile/*.json >/dev/null
jq -e '
  (.upstream.code_oss.repository | endswith("/microsoft/vscode.git")) and
  (.upstream | has("vscode") | not) and
  (.runtime.code_oss_version | type == "string") and
  (.runtime | has("vscode_version") | not)
' <<<"${RELEASE_BUILD_SPEC}" >/dev/null || {
  echo "The release lock must name Code OSS as the runtime source." >&2
  exit 1
}

expected_extensions='["sql"]'
actual_extensions="$(jq -c 'unique | sort' <<<"${DOCUMENT_EXTENSIONS}")"
[[ "${actual_extensions}" == "${expected_extensions}" ]] || { echo "The app must claim SQL query documents only." >&2; exit 1; }

for entitlement_file in "${REPO_ROOT}"/host/entitlements/*.plist; do
  plutil -lint "${entitlement_file}" >/dev/null
done

while IFS= read -r shell_script; do
  bash -n "${shell_script}"
done < <(find "${REPO_ROOT}/script" -type f -name '*.sh' -print | sort)

patch_plan_validate
while IFS= read -r overlay_patch; do
  git apply --numstat "${overlay_patch}" >/dev/null || {
    echo "Malformed maintained overlay patch: ${overlay_patch}" >&2
    exit 1
  }
done < <(
  patch_plan_files vscodium
  patch_plan_files code-oss
)

if rg -q '^[[:space:]]*"\$\{REPO_ROOT\}/script/build_host\.sh"' "${REPO_ROOT}/script/run_host.sh"; then
  echo "Normal development launch must not trigger a host rebuild." >&2
  exit 1
fi

if rg -Fq --glob '!test_host_contract.sh' 'dscl ' "${REPO_ROOT}/script"; then
  echo "Host scripts must resolve the current user without depending on directory-service access." >&2
  exit 1
fi

identity_patch="${REPO_ROOT}/host/patches/vscodium/0001-dbcode-wrapper-identity.patch"
for product_key in \
  app_name \
  application_name \
  bundle_identifier \
  url_scheme \
  data_folder_name \
  shared_data_folder_name \
  darwin_profile_uuid \
  darwin_profile_payload_uuid; do
  product_value="$(jq -er ".product.${product_key}" <<<"${RELEASE_PROFILE_SPEC}")"
  if rg -Fq "${product_value}" "${identity_patch}"; then
    echo "The identity patch duplicates release-lock value ${product_key}." >&2
    exit 1
  fi
done
if rg -q '"name":"Folder"|public\.folder' "${identity_patch}"; then
  echo "The private database host must not claim the general folder association." >&2
  exit 1
fi
if rg -q 'DuckDB database|SQLite database|Parquet data file|Delimited data file' "${identity_patch}"; then
  echo "Database and data sources must enter through DBCode Connections, not macOS document associations." >&2
  exit 1
fi
plutil -convert json -o - "${REPO_ROOT}/host/entitlements/helper.plist" |
  jq -e '."com.apple.security.cs.disable-library-validation" == true' >/dev/null || {
  echo "Electron helpers must be allowed to load the ad hoc signed framework." >&2
  exit 1
}
rg -q 'darwinBundleDocumentTypes: product\.darwinBundleDocumentTypes' \
  "${REPO_ROOT}/host/patches/code-oss/100-product-identity-and-macos-packaging.patch"

reference_vscodium="${BUILD_ROOT}/upstream/vscodium"
reference_code_oss="${reference_vscodium}/vscode"
if [[ -d "${reference_vscodium}/.git" ]]; then
  while IFS= read -r vscodium_patch; do
    git -C "${reference_vscodium}" apply --check "${vscodium_patch}"
  done < <(patch_plan_files vscodium)
fi
if [[ -d "${reference_code_oss}/.git" ]]; then
  patch_index="$(mktemp "${BUILD_ROOT}/code-oss-patch-index.XXXXXX")"
  rm -f "${patch_index}"
  cleanup_patch_index() {
    rm -f "${patch_index}"
  }
  trap cleanup_patch_index EXIT
  GIT_INDEX_FILE="${patch_index}" git -C "${reference_code_oss}" read-tree HEAD
  while IFS= read -r code_oss_patch; do
    GIT_INDEX_FILE="${patch_index}" git -C "${reference_code_oss}" apply --cached --check "${code_oss_patch}"
    GIT_INDEX_FILE="${patch_index}" git -C "${reference_code_oss}" apply --cached "${code_oss_patch}"
  done < <(patch_plan_files code-oss)
  cleanup_patch_index
  trap - EXIT
fi

if [[ "${check_built_artifact}" == "yes" && -d "${APP_BUNDLE}" ]]; then
  load_local_signing_identity
  expected_designated_requirement="$(local_signing_expected_requirement "${BUNDLE_IDENTIFIER}")"
  actual_designated_requirement="$(codesign -d -r- "${APP_BUNDLE}" 2>&1 | sed -n '/^designated => /p')"
  [[ "${actual_designated_requirement}" == "${expected_designated_requirement}" ]] || {
    echo "The DBCode Wrapper signature does not have the expected persistent requirement." >&2
    echo "Expected: ${expected_designated_requirement}" >&2
    echo "Actual:   ${actual_designated_requirement}" >&2
    exit 1
  }
  verify_local_signed_code "${APP_BUNDLE}" "${BUNDLE_IDENTIFIER}"
  "${REPO_ROOT}/script/smoke_host.sh" --static-only
fi

"${REPO_ROOT}/script/test_single_app_identity_contract.sh"

echo "Host overlay contract checks passed."
