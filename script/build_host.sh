#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

"${REPO_ROOT}/script/bootstrap_toolchain.sh"
export PATH="${NODE_BIN_DIR}:${PATH}"

"${REPO_ROOT}/script/prepare_source.sh"

slimming_policy_file="${REPO_ROOT}/host/slimming-policy.json"
built_in_extension_mode="$(jq -er '.build.built_in_extensions.mode' "${slimming_policy_file}")"
case "${built_in_extension_mode}" in
  allowlist)
    dbcode_wrapper_builtin_extension_allowlist="$(jq -er '.build.built_in_extensions.allowlist[].name' "${slimming_policy_file}" | paste -sd, -)"
    [[ -n "${dbcode_wrapper_builtin_extension_allowlist}" ]] || {
      echo "The built-in extension allowlist must not be empty." >&2
      exit 1
    }
    ;;
  all)
    dbcode_wrapper_builtin_extension_allowlist=""
    ;;
  *)
    echo "Unsupported built-in extension mode: ${built_in_extension_mode}" >&2
    exit 1
    ;;
esac

export APP_NAME="${APP_NAME}"
export ASSETS_REPOSITORY="VSCodium/vscodium"
export BINARY_NAME="${APPLICATION_NAME}"
export CI_BUILD="no"
export DISABLE_UPDATE="yes"
export GLOBAL_DIRNAME="${APPLICATION_NAME}"
export GH_REPO_PATH="VSCodium/vscodium"
export MS_COMMIT="${CODE_OSS_COMMIT}"
export MS_TAG="${CODE_OSS_TAG}"
export NODE_OPTIONS="--max-old-space-size=8192"
export OS_NAME="osx"
export ORG_NAME="DBCodeWrapper"
export DBCODE_WRAPPER_OVERLAY="yes"
export DBCODE_WRAPPER_APP_NAME="${APP_NAME}"
export DBCODE_WRAPPER_APPLICATION_NAME="${APPLICATION_NAME}"
export DBCODE_WRAPPER_BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER}"
export DBCODE_WRAPPER_DATA_FOLDER_NAME="${DATA_FOLDER_NAME}"
export DBCODE_WRAPPER_SHARED_DATA_FOLDER_NAME="${SHARED_DATA_FOLDER_NAME}"
export DBCODE_WRAPPER_URL_SCHEME="${URL_SCHEME}"
export DBCODE_WRAPPER_SERVER_APPLICATION_NAME="${SERVER_APPLICATION_NAME}"
export DBCODE_WRAPPER_SERVER_DATA_FOLDER_NAME="${SERVER_DATA_FOLDER_NAME}"
export DBCODE_WRAPPER_TUNNEL_APPLICATION_NAME="${TUNNEL_APPLICATION_NAME}"
export DBCODE_WRAPPER_NARROW_BREAKPOINT="${FOCUSED_SHELL_NARROW_BREAKPOINT}"
export DBCODE_WRAPPER_DARWIN_PROFILE_UUID="${DARWIN_PROFILE_UUID}"
export DBCODE_WRAPPER_DARWIN_PROFILE_PAYLOAD_UUID="${DARWIN_PROFILE_PAYLOAD_UUID}"
export DBCODE_WRAPPER_STRIP_SOURCE_MAPS="yes"
export DBCODE_WRAPPER_BUILTIN_EXTENSION_ALLOWLIST="${dbcode_wrapper_builtin_extension_allowlist}"
export RELEASE_VERSION="${VSCODIUM_TAG}"
export SHOULD_BUILD="yes"
export SHOULD_BUILD_CLI="no"
export SHOULD_BUILD_REH="no"
export SHOULD_BUILD_REH_WEB="no"
export TUNNEL_APP_NAME="${TUNNEL_APPLICATION_NAME}"
export VSCODE_ARCH="${TARGET_ARCH}"
export VSCODE_LATEST="no"
export VSCODE_QUALITY="stable"

echo "Building ${APP_NAME} for darwin-${TARGET_ARCH}"
echo "VSCodium ${VSCODIUM_TAG} (${VSCODIUM_COMMIT})"
echo "Code OSS ${CODE_OSS_TAG} (${CODE_OSS_COMMIT})"
echo "Node $(node --version), npm $(npm --version)"

(
  cd "${WORK_ROOT}"
  ./build.sh
)

built_app="${WORK_ROOT}/VSCode-darwin-${TARGET_ARCH}/${APP_NAME}.app"
if [[ ! -d "${built_app}" ]]; then
  echo "Expected build output not found: ${built_app}" >&2
  exit 1
fi

mkdir -p "${DIST_ROOT}"
assert_generated_path "${APP_BUNDLE}"
rm -rf "${APP_BUNDLE}"
ditto "${built_app}" "${APP_BUNDLE}"

copy_first_party_extensions() {
  local extension_name extension_source source_path destination_path
  while IFS=$'\t' read -r extension_name extension_source; do
    source_path="${REPO_ROOT}/${extension_source}"
    destination_path="${APP_BUNDLE}/Contents/Resources/app/extensions/${extension_name}"
    [[ -f "${source_path}/package.json" ]] || {
      echo "Missing reviewed first-party extension: ${source_path}" >&2
      exit 1
    }
    [[ ! -e "${destination_path}" ]] || {
      echo "First-party extension would replace an upstream extension: ${extension_name}" >&2
      exit 1
    }
    ditto "${source_path}" "${destination_path}"
  done < <(jq -r '.build.built_in_extensions.first_party[] | [.name, .source] | @tsv' "${slimming_policy_file}")
}

copy_first_party_extensions

runtime_setup_extension="${APP_BUNDLE}/Contents/Resources/app/extensions/dbcode-wrapper-profile-migration"
"${REPO_ROOT}/script/generate_runtime_setup_manifest.sh" \
  "${runtime_setup_extension}/runtime-extension-set.json"

release_status_extension="${APP_BUNDLE}/Contents/Resources/app/extensions/dbcode-wrapper-release-status"
"${REPO_ROOT}/script/generate_installed_release_status.sh" "${release_status_extension}/installed-release-set.json"
cp "${REPO_ROOT}/host/approved-release-history.json" "${release_status_extension}/approved-release-sets.json"

"${REPO_ROOT}/script/sign_host.sh" "${APP_BUNDLE}"
"${REPO_ROOT}/script/generate_manifest.sh" "${APP_BUNDLE}" "${BUILD_MANIFEST}"

echo "Built application: ${APP_BUNDLE}"
echo "Manifest: ${BUILD_MANIFEST}"
