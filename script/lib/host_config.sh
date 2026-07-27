#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
GENERATED_REPO_ROOT="${DBCODE_WRAPPER_GENERATED_REPO_ROOT:-${REPO_ROOT}}"
[[ "${GENERATED_REPO_ROOT}" == /* &&
  "${GENERATED_REPO_ROOT}" != "/" &&
  -d "${GENERATED_REPO_ROOT}" &&
  ! -L "${GENERATED_REPO_ROOT}" ]] || {
  echo "Generated repository root is missing or unsafe: ${GENERATED_REPO_ROOT}" >&2
  exit 1
}
GENERATED_REPO_ROOT="$(cd "${GENERATED_REPO_ROOT}" && pwd -P)"
LOCK_FILE="${REPO_ROOT}/host/release-lock.json"

source "${REPO_ROOT}/script/lib/release_specification.sh"

RELEASE_BUILD_SPEC="$(release_specification_record build "${LOCK_FILE}")"
RELEASE_EXTENSION_SPEC="$(release_specification_record extensions "${LOCK_FILE}")"
RELEASE_PROFILE_SPEC="$(release_specification_record profile "${LOCK_FILE}")"

APP_NAME="$(jq -er '.product.app_name' <<<"${RELEASE_PROFILE_SPEC}")"
APPLICATION_NAME="$(jq -er '.product.application_name' <<<"${RELEASE_PROFILE_SPEC}")"
BUNDLE_IDENTIFIER="$(jq -er '.product.bundle_identifier' <<<"${RELEASE_PROFILE_SPEC}")"
URL_SCHEME="$(jq -er '.product.url_scheme' <<<"${RELEASE_PROFILE_SPEC}")"
DATA_FOLDER_NAME="$(jq -er '.product.data_folder_name' <<<"${RELEASE_PROFILE_SPEC}")"
USER_DATA_FOLDER_NAME="$(jq -er '.product.user_data_folder_name' <<<"${RELEASE_PROFILE_SPEC}")"
EXTENSIONS_FOLDER_NAME="$(jq -er '.product.extensions_folder_name' <<<"${RELEASE_PROFILE_SPEC}")"
SHARED_DATA_FOLDER_NAME="$(jq -er '.product.shared_data_folder_name' <<<"${RELEASE_PROFILE_SPEC}")"
BACKUP_FOLDER_NAME="$(jq -er '.product.backup_folder_name' <<<"${RELEASE_PROFILE_SPEC}")"
STORAGE_NAMESPACE="$(jq -er '.product.storage_namespace' <<<"${RELEASE_PROFILE_SPEC}")"
QUERY_FOLDER_NAME="$(jq -er '.product.query_folder_name' <<<"${RELEASE_PROFILE_SPEC}")"
SERVER_APPLICATION_NAME="$(jq -er '.product.server_application_name' <<<"${RELEASE_PROFILE_SPEC}")"
SERVER_DATA_FOLDER_NAME="$(jq -er '.product.server_data_folder_name' <<<"${RELEASE_PROFILE_SPEC}")"
TUNNEL_APPLICATION_NAME="$(jq -er '.product.tunnel_application_name' <<<"${RELEASE_PROFILE_SPEC}")"
SIGNING_MODE="$(jq -er '.product.signing.mode' <<<"${RELEASE_PROFILE_SPEC}")"
SIGNING_IDENTITY_COMMON_NAME="$(jq -er '.product.signing.identity_common_name' <<<"${RELEASE_PROFILE_SPEC}")"
SIGNING_SCOPE="$(jq -er '.product.signing.scope' <<<"${RELEASE_PROFILE_SPEC}")"
FOCUSED_SHELL_ENABLED="$(jq -er '.product.focused_shell.enabled' <<<"${RELEASE_PROFILE_SPEC}")"
FOCUSED_SHELL_AUTOMATIC_RESULT_LAYOUT="$(jq -c '.product.focused_shell.automatic_result_layout' <<<"${RELEASE_PROFILE_SPEC}")"
FOCUSED_SHELL_NARROW_BREAKPOINT="$(jq -er '.product.focused_shell.narrow_breakpoint' <<<"${RELEASE_PROFILE_SPEC}")"
DARWIN_PROFILE_UUID="$(jq -er '.product.darwin_profile_uuid' <<<"${RELEASE_PROFILE_SPEC}")"
DARWIN_PROFILE_PAYLOAD_UUID="$(jq -er '.product.darwin_profile_payload_uuid' <<<"${RELEASE_PROFILE_SPEC}")"
DOCUMENT_EXTENSIONS="$(jq -c '.product.document_extensions' <<<"${RELEASE_PROFILE_SPEC}")"
PROFILE_SCHEMA_VERSION="$(jq -er '.profile_schema_version' <<<"${RELEASE_PROFILE_SPEC}")"
TARGET_ARCH="$(jq -er '.target.architecture' <<<"${RELEASE_BUILD_SPEC}")"
VSCODIUM_TAG="$(jq -er '.upstream.vscodium.tag' <<<"${RELEASE_BUILD_SPEC}")"
VSCODIUM_COMMIT="$(jq -er '.upstream.vscodium.commit' <<<"${RELEASE_BUILD_SPEC}")"
VSCODIUM_REPOSITORY="$(jq -er '.upstream.vscodium.repository' <<<"${RELEASE_BUILD_SPEC}")"
VSCODIUM_PUBLISHED_AT="$(jq -er '.upstream.vscodium.published_at' <<<"${RELEASE_BUILD_SPEC}")"
VSCODIUM_RELEASE_NOTES_URL="$(jq -er '.upstream.vscodium.release_notes_url' <<<"${RELEASE_BUILD_SPEC}")"
CODE_OSS_TAG="$(jq -er '.upstream.code_oss.tag' <<<"${RELEASE_BUILD_SPEC}")"
CODE_OSS_COMMIT="$(jq -er '.upstream.code_oss.commit' <<<"${RELEASE_BUILD_SPEC}")"
CODE_OSS_REPOSITORY="$(jq -er '.upstream.code_oss.repository' <<<"${RELEASE_BUILD_SPEC}")"
CODE_OSS_VERSION="$(jq -er '.runtime.code_oss_version' <<<"${RELEASE_BUILD_SPEC}")"
ELECTRON_VERSION="$(jq -er '.runtime.electron_version' <<<"${RELEASE_BUILD_SPEC}")"
RELEASE_SET_BASE_ID="$(jq -er '.release.release_set_base_id' <<<"${RELEASE_BUILD_SPEC}")"
RELEASE_COMPATIBILITY_STATUS="$(jq -er '.release.compatibility_status' <<<"${RELEASE_BUILD_SPEC}")"
RELEASE_VALIDATION_ISSUE="$(jq -er '.release.validation_issue' <<<"${RELEASE_BUILD_SPEC}")"
NODE_VERSION="$(jq -er '.toolchain.node.version' <<<"${RELEASE_BUILD_SPEC}")"
NODE_NPM_VERSION="$(jq -er '.toolchain.node.npm_version' <<<"${RELEASE_BUILD_SPEC}")"
NODE_ARCHIVE_URL="$(jq -er '.toolchain.node.archive_url' <<<"${RELEASE_BUILD_SPEC}")"
NODE_ARCHIVE_SHA256="$(jq -er '.toolchain.node.archive_sha256' <<<"${RELEASE_BUILD_SPEC}")"
PYTHON_VERSION="$(jq -er '.toolchain.python_version' <<<"${RELEASE_BUILD_SPEC}")"
APPLE_CLANG_VERSION="$(jq -er '.toolchain.apple_clang_version' <<<"${RELEASE_BUILD_SPEC}")"
MACOS_SDK_VERSION="$(jq -er '.toolchain.macos_sdk_version' <<<"${RELEASE_BUILD_SPEC}")"
DBCODE_PACKAGE_SPEC="$(jq -c '.dbcode' <<<"${RELEASE_EXTENSION_SPEC}")"
PYTHON_NOTEBOOK_SPEC="$(jq -c '.python_notebooks' <<<"${RELEASE_EXTENSION_SPEC}")"
RUNTIME_EXTENSION_PACKAGES="$(jq -c '.packages' <<<"${RELEASE_EXTENSION_SPEC}")"
DBCODE_ID="$(jq -er '.id' <<<"${DBCODE_PACKAGE_SPEC}")"
DBCODE_VERSION="$(jq -er '.version' <<<"${DBCODE_PACKAGE_SPEC}")"
DBCODE_ENGINE="$(jq -er '.engine' <<<"${DBCODE_PACKAGE_SPEC}")"
DBCODE_SHA256="$(jq -er '.sha256' <<<"${DBCODE_PACKAGE_SPEC}")"
DBCODE_SIGNATURE_ARCHIVE_SHA256="$(jq -er '.signature_archive_sha256' <<<"${DBCODE_PACKAGE_SPEC}")"
DBCODE_PUBLIC_KEY_ID="$(jq -er '.public_key_id' <<<"${DBCODE_PACKAGE_SPEC}")"
DBCODE_PUBLIC_KEY_SHA256="$(jq -er '.public_key_sha256' <<<"${DBCODE_PACKAGE_SPEC}")"
DBCODE_CONTRIBUTIONS_SHA256="$(jq -er '.jq_sorted_compact_contributes_sha256' <<<"${DBCODE_PACKAGE_SPEC}")"
DBCODE_PACKAGE_SIZE="$(jq -er '.package_size' <<<"${DBCODE_PACKAGE_SPEC}")"

BUILD_ROOT="${GENERATED_REPO_ROOT}/.build"
CACHE_ROOT="${BUILD_ROOT}/cache"
WORK_ROOT="${BUILD_ROOT}/work/vscodium-${VSCODIUM_TAG}"
TOOLCHAIN_ROOT="${BUILD_ROOT}/toolchains"
NODE_ROOT="${TOOLCHAIN_ROOT}/node-v${NODE_VERSION}-darwin-${TARGET_ARCH}"
NODE_BIN_DIR="${NODE_ROOT}/bin"
DIST_ROOT="${GENERATED_REPO_ROOT}/dist"
APP_BUNDLE="${DIST_ROOT}/${APP_NAME}.app"
BUILD_MANIFEST="${DIST_ROOT}/build-manifest.json"

require_command() {
  if ! command -v "${1}" >/dev/null 2>&1; then
    echo "Required command not found: ${1}" >&2
    exit 1
  fi
}

current_user_home() {
  local user_name user_home_dir
  user_name="$(id -un)"
  user_home_dir="$(id -P "${user_name}" | awk -F: '{print $9}')"
  [[ -n "${user_home_dir}" && "${user_home_dir}" == /* ]] || {
    echo "Could not resolve the current user's home directory." >&2
    return 1
  }
  printf '%s\n' "${user_home_dir}"
}

assert_generated_path() {
  local candidate="$1"
  local relative current component
  local -a components=()

  case "${candidate}" in
    "${BUILD_ROOT}"/*|"${DIST_ROOT}"/*) ;;
    *)
      echo "Refusing to modify a path outside generated output: ${candidate}" >&2
      exit 1
      ;;
  esac

  relative="${candidate#"${GENERATED_REPO_ROOT}/"}"
  case "${relative}" in
    ""|..|../*|*/../*|*/..)
      echo "Refusing a generated path with parent traversal: ${candidate}" >&2
      exit 1
      ;;
  esac

  current="${GENERATED_REPO_ROOT}"
  IFS='/' read -r -a components <<<"${relative}"
  for component in "${components[@]}"; do
    [[ -n "${component}" ]] || continue
    current="${current}/${component}"
    if [[ -L "${current}" ]]; then
      echo "Refusing a generated path with a symbolic-link ancestor: ${current}" >&2
      exit 1
    fi
  done
}
