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

host_config_expected_names=(
  RELEASE_BUILD_SPEC
  RELEASE_EXTENSION_SPEC
  RELEASE_PROFILE_SPEC
  APP_NAME
  APPLICATION_NAME
  BUNDLE_IDENTIFIER
  URL_SCHEME
  DATA_FOLDER_NAME
  USER_DATA_FOLDER_NAME
  SHARED_DATA_FOLDER_NAME
  STORAGE_NAMESPACE
  QUERY_FOLDER_NAME
  SERVER_APPLICATION_NAME
  SERVER_DATA_FOLDER_NAME
  TUNNEL_APPLICATION_NAME
  SIGNING_MODE
  SIGNING_IDENTITY_COMMON_NAME
  SIGNING_SCOPE
  FOCUSED_SHELL_ENABLED
  FOCUSED_SHELL_RESULT_LOCATION
  FOCUSED_SHELL_NARROW_BREAKPOINT
  DARWIN_PROFILE_UUID
  DARWIN_PROFILE_PAYLOAD_UUID
  DOCUMENT_EXTENSIONS
  PROFILE_SCHEMA_VERSION
  TARGET_ARCH
  VSCODIUM_TAG
  VSCODIUM_COMMIT
  VSCODIUM_REPOSITORY
  VSCODIUM_PUBLISHED_AT
  VSCODIUM_RELEASE_NOTES_URL
  CODE_OSS_TAG
  CODE_OSS_COMMIT
  CODE_OSS_REPOSITORY
  CODE_OSS_VERSION
  ELECTRON_VERSION
  WRAPPER_VERSION
  RELEASE_COMPATIBILITY_STATUS
  RELEASE_VALIDATION_ISSUE
  NODE_VERSION
  NODE_NPM_VERSION
  NODE_ARCHIVE_URL
  NODE_ARCHIVE_SHA256
  PYTHON_VERSION
  APPLE_CLANG_VERSION
  MACOS_SDK_VERSION
)
host_config_parts=()
while IFS= read -r -d '' host_config_part; do
  host_config_parts+=("${host_config_part}")
done < <(release_specification_host_config_pairs "${LOCK_FILE}")

host_config_expected_part_count=$((
  (${#host_config_expected_names[@]} + 1) * 2
))
[[ "${#host_config_parts[@]}" -eq "${host_config_expected_part_count}" ]] || {
  echo "Host Configuration materialization was incomplete." >&2
  exit 1
}
for ((host_config_index = 0;
  host_config_index < ${#host_config_expected_names[@]};
  host_config_index += 1)); do
  host_config_name_index=$((host_config_index * 2))
  [[ "${host_config_parts[host_config_name_index]}" == "${host_config_expected_names[host_config_index]}" ]] || {
    echo "Host Configuration returned an unexpected field." >&2
    exit 1
  }
done
host_config_sentinel_index=$((${#host_config_expected_names[@]} * 2))
[[ "${host_config_parts[host_config_sentinel_index]}" == "__HOST_CONFIG_COMPLETE__" && \
  "${host_config_parts[host_config_sentinel_index + 1]}" == "1" ]] || {
  echo "Host Configuration materialization did not complete." >&2
  exit 1
}

for ((host_config_index = 0;
  host_config_index < ${#host_config_expected_names[@]};
  host_config_index += 1)); do
  host_config_value_index=$((host_config_index * 2 + 1))
  printf -v "${host_config_expected_names[host_config_index]}" \
    '%s' "${host_config_parts[host_config_value_index]}"
done
unset \
  host_config_expected_names \
  host_config_parts \
  host_config_part \
  host_config_expected_part_count \
  host_config_index \
  host_config_name_index \
  host_config_sentinel_index \
  host_config_value_index

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
