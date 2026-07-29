#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/generated_workspace.sh"
source "${REPO_ROOT}/script/lib/patch_plan.sh"

usage() {
  echo "Usage: ./script/compile_host.sh [--environment-record FILE]" >&2
  exit 2
}

environment_record="${BUILD_ROOT}/compiled-host-environment.json"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment-record)
      [[ $# -ge 2 ]] || usage
      environment_record="$2"
      shift
      ;;
    *)
      usage
      ;;
  esac
  shift
done
[[ -n "${environment_record}" && ! -L "${environment_record}" ]] || usage

"${REPO_ROOT}/script/bootstrap_toolchain.sh"
export PATH="${NODE_BIN_DIR}:${PATH}"

generated_workspace_assert_path "toolchain-cache" "${TOOLCHAIN_ROOT}"
generated_workspace_assert_path "download-cache" "${BUILD_ROOT}/downloads"
generated_workspace_assert_path "build-work" "${WORK_ROOT}"
"${REPO_ROOT}/script/prepare_source.sh"

slimming_policy_file="${REPO_ROOT}/host/slimming-policy.json"
built_in_extension_mode="$(jq -er '.build.built_in_extensions.mode' "${slimming_policy_file}")"
case "${built_in_extension_mode}" in
  allowlist)
    dbcode_wrapper_builtin_extension_allowlist="$(
      jq -er '.build.built_in_extensions.allowlist[].name' "${slimming_policy_file}" |
        paste -sd, -
    )"
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
export DBCODE_WRAPPER_STORAGE_NAMESPACE="${STORAGE_NAMESPACE}"
export DBCODE_WRAPPER_QUERY_FOLDER_NAME="${QUERY_FOLDER_NAME}"
export DBCODE_WRAPPER_URL_SCHEME="${URL_SCHEME}"
export DBCODE_WRAPPER_SERVER_APPLICATION_NAME="${SERVER_APPLICATION_NAME}"
export DBCODE_WRAPPER_SERVER_DATA_FOLDER_NAME="${SERVER_DATA_FOLDER_NAME}"
export DBCODE_WRAPPER_TUNNEL_APPLICATION_NAME="${TUNNEL_APPLICATION_NAME}"
export DBCODE_WRAPPER_NARROW_BREAKPOINT="${FOCUSED_SHELL_NARROW_BREAKPOINT}"
export DBCODE_WRAPPER_DARWIN_PROFILE_UUID="${DARWIN_PROFILE_UUID}"
export DBCODE_WRAPPER_DARWIN_PROFILE_PAYLOAD_UUID="${DARWIN_PROFILE_PAYLOAD_UUID}"
export DBCODE_WRAPPER_PATCH_PLAN_FILE="$(patch_plan_file)"
export DBCODE_WRAPPER_PATCH_TREE_VERIFIER="${REPO_ROOT}/script/verify_prepared_patch_tree.sh"
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

echo "Compiling ${APP_NAME} for darwin-${TARGET_ARCH}"
echo "VSCodium ${VSCODIUM_TAG} (${VSCODIUM_COMMIT})"
echo "Code OSS ${CODE_OSS_TAG} (${CODE_OSS_COMMIT})"
echo "Node $(node --version), npm $(npm --version)"

(
  cd "${WORK_ROOT}"
  ./build.sh
)

compiled_app="${WORK_ROOT}/VSCode-darwin-${TARGET_ARCH}/${APP_NAME}.app"
[[ -d "${compiled_app}" && ! -L "${compiled_app}" ]] || {
  echo "Expected compiled host not found: ${compiled_app}" >&2
  exit 1
}

echo "Compiled host: ${compiled_app}"

environment_parent="$(dirname "${environment_record}")"
mkdir -p "${environment_parent}"
[[ -d "${environment_parent}" && ! -L "${environment_parent}" ]] || {
  echo "Compiled-host environment record parent is unsafe: ${environment_parent}" >&2
  exit 1
}
environment_temporary="$(mktemp "${environment_parent}/.compiled-host-environment.XXXXXX")"
cleanup_environment_temporary() {
  rm -f "${environment_temporary}"
}
trap cleanup_environment_temporary EXIT INT TERM

jq -S -n \
  --arg node "$("${NODE_BIN_DIR}/node" --version)" \
  --arg npm "$("${NODE_BIN_DIR}/npm" --version)" \
  --arg python "$(python3 --version 2>&1 | awk '{print $2}')" \
  --arg clang "$(clang --version | sed -n '1p')" \
  --arg macos_sdk "$(xcrun --sdk macosx --show-sdk-version)" \
  --arg macos "$(sw_vers -productVersion)" '
    {
      schema_version: 1,
      node: $node,
      npm: $npm,
      python: $python,
      clang: $clang,
      macos_sdk: $macos_sdk,
      macos: $macos
    }
  ' > "${environment_temporary}"
chmod 600 "${environment_temporary}"
mv "${environment_temporary}" "${environment_record}"
trap - EXIT INT TERM

echo "Compilation environment: ${environment_record}"
