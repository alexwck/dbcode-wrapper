#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/profile_paths.sh"

user_home_dir="$(current_user_home)"
extensions_folder_name="$(jq -er '.product.extensions_folder_name' <<<"${RELEASE_PROFILE_SPEC}")"
backup_folder_name="$(jq -er '.product.backup_folder_name' <<<"${RELEASE_PROFILE_SPEC}")"

resolve_profile_paths default
jq -e \
  --arg app_name "${APP_NAME}" \
  --arg application_name "${APPLICATION_NAME}" \
  --arg bundle_identifier "${BUNDLE_IDENTIFIER}" \
  --arg data_folder_name "${DATA_FOLDER_NAME}" \
  --arg user_data_folder_name "${USER_DATA_FOLDER_NAME}" \
  --arg extensions_folder_name "${extensions_folder_name}" \
  --arg shared_data_folder_name "${SHARED_DATA_FOLDER_NAME}" \
  --arg backup_folder_name "${backup_folder_name}" \
  --arg storage_namespace "${STORAGE_NAMESPACE}" \
  --arg query_folder_name "${QUERY_FOLDER_NAME}" \
  --argjson profile_schema_version "${PROFILE_SCHEMA_VERSION}" '
    .schema_version == 2
    and .profile_schema_version == $profile_schema_version
    and .profile_name == "default"
    and .product == {
      app_name: $app_name,
      application_name: $application_name,
      bundle_identifier: $bundle_identifier,
      data_folder_name: $data_folder_name,
      user_data_folder_name: $user_data_folder_name,
      extensions_folder_name: $extensions_folder_name,
      shared_data_folder_name: $shared_data_folder_name,
      backup_folder_name: $backup_folder_name,
      storage_namespace: $storage_namespace,
      query_folder_name: $query_folder_name
    }
    and .permissions == {directory_mode: "0700", file_mode: "0600"}
  ' <<<"${PROFILE_LAYOUT}" >/dev/null || {
  echo "The default profile layout does not match the Release Specification." >&2
  exit 1
}
[[ "${PROFILE_USER_DATA_ROOT}" == "${user_home_dir}/Library/Application Support/${USER_DATA_FOLDER_NAME}" ]] || {
  echo "The default user-data path does not match a normal self-launch." >&2
  exit 1
}
[[ "${PROFILE_EXTENSIONS_ROOT}" == "${user_home_dir}/${DATA_FOLDER_NAME}/${extensions_folder_name}" ]] || {
  echo "The default extension path does not match a normal self-launch." >&2
  exit 1
}
[[ "${PROFILE_SHARED_DATA_ROOT}" == "${user_home_dir}/${SHARED_DATA_FOLDER_NAME}" ]] || {
  echo "The default shared-data path does not match a normal self-launch." >&2
  exit 1
}
[[ "${PROFILE_BACKUP_ROOT}" == "${user_home_dir}/Library/Application Support/${backup_folder_name}" ]] || {
  echo "The default profile-backup path does not match a normal self-launch." >&2
  exit 1
}
[[ "${PROFILE_QUERY_ROOT}" == "${PROFILE_USER_DATA_ROOT}/User/globalStorage/${STORAGE_NAMESPACE}/${QUERY_FOLDER_NAME}" ]] || {
  echo "The default query path does not match the generated profile identity." >&2
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
[[ "${PROFILE_EXTENSIONS_ROOT}" == "${BUILD_ROOT}/qa/profile/${extensions_folder_name}" ]] || {
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

if resolve_profile_paths unsupported 2>/dev/null; then
  echo "Profile Layout accepted an unsupported profile name." >&2
  exit 1
fi

echo "DBCode Wrapper self-launch profile paths are consistent."
