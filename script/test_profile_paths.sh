#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/profile_paths.sh"

user_home_dir="$(current_user_home)"

resolve_profile_paths default
jq -e \
  --arg app_name "${APP_NAME}" \
  --arg data_folder_name "${DATA_FOLDER_NAME}" \
  --arg shared_data_folder_name "${SHARED_DATA_FOLDER_NAME}" \
  --argjson profile_schema_version "${PROFILE_SCHEMA_VERSION}" '
    .schema_version == 1
    and .profile_schema_version == $profile_schema_version
    and .profile_name == "default"
    and .product == {
      app_name: $app_name,
      data_folder_name: $data_folder_name,
      shared_data_folder_name: $shared_data_folder_name
    }
    and .permissions == {directory_mode: "0700", file_mode: "0600"}
  ' <<<"${PROFILE_LAYOUT}" >/dev/null || {
  echo "The default profile layout does not match the Release Specification." >&2
  exit 1
}
[[ "${PROFILE_USER_DATA_ROOT}" == "${user_home_dir}/Library/Application Support/${APP_NAME}" ]] || {
  echo "The default user-data path does not match a normal self-launch." >&2
  exit 1
}
[[ "${PROFILE_EXTENSIONS_ROOT}" == "${user_home_dir}/${DATA_FOLDER_NAME}/extensions" ]] || {
  echo "The default extension path does not match a normal self-launch." >&2
  exit 1
}
[[ "${PROFILE_SHARED_DATA_ROOT}" == "${user_home_dir}/${SHARED_DATA_FOLDER_NAME}" ]] || {
  echo "The default shared-data path does not match a normal self-launch." >&2
  exit 1
}
[[ "${PROFILE_BACKUP_ROOT}" == "${user_home_dir}/Library/Application Support/${APP_NAME} Profile Backups" ]] || {
  echo "The default profile-backup path does not match a normal self-launch." >&2
  exit 1
}
[[ "${PROFILE_USES_NATURAL_PATHS}" == "yes" ]] || {
  echo "The default profile must use direct-launch paths." >&2
  exit 1
}
[[ "${PROFILE_DIRECTORY_MODE}" == "0700" && "${PROFILE_FILE_MODE}" == "0600" ]] || {
  echo "The default profile does not carry private filesystem modes." >&2
  exit 1
}

resolve_profile_paths qa
[[ "${PROFILE_STATE_ROOT}" == "${BUILD_ROOT}/qa/profile" ]] || {
  echo "The QA profile must stay inside generated build output." >&2
  exit 1
}
[[ "${PROFILE_EXTENSIONS_ROOT}" == "${BUILD_ROOT}/qa/profile/extensions" ]] || {
  echo "The QA extension path is not isolated." >&2
  exit 1
}
[[ "${PROFILE_BACKUP_ROOT}" == "${BUILD_ROOT}/qa/profile-backups" ]] || {
  echo "The QA profile-backup path is not isolated from the profile being recreated." >&2
  exit 1
}
[[ "${PROFILE_USES_NATURAL_PATHS}" == "no" ]] || {
  echo "The QA profile must use explicit isolated paths." >&2
  exit 1
}

isolated_state_root="${BUILD_ROOT}/profile-layout-test/session-one"
isolated_extensions_root="${BUILD_ROOT}/profile-layout-test/verified-extensions"
resolve_isolated_profile_paths "${isolated_state_root}" "${isolated_extensions_root}"
[[ "${PROFILE_STATE_ROOT}" == "${isolated_state_root}" ]] || {
  echo "The isolated profile state root changed while loading its layout." >&2
  exit 1
}
[[ "${PROFILE_EXTENSIONS_ROOT}" == "${isolated_extensions_root}" ]] || {
  echo "The isolated profile did not preserve its separately verified extension root." >&2
  exit 1
}

if resolve_profile_paths diagnostic 2>/dev/null; then
  echo "The removed full-workbench diagnostic profile is still accepted." >&2
  exit 1
fi

echo "DBCode Wrapper self-launch profile paths are consistent."
