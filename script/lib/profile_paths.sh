#!/usr/bin/env bash

set -euo pipefail

load_profile_layout_record() {
  PROFILE_STATE_ROOT="$(jq -er '.paths.state' <<<"${PROFILE_LAYOUT}")"
  PROFILE_USER_DATA_ROOT="$(jq -er '.paths.user_data' <<<"${PROFILE_LAYOUT}")"
  PROFILE_EXTENSIONS_ROOT="$(jq -er '.paths.extensions' <<<"${PROFILE_LAYOUT}")"
  PROFILE_SHARED_DATA_ROOT="$(jq -er '.paths.shared_data' <<<"${PROFILE_LAYOUT}")"
  PROFILE_BACKUP_ROOT="$(jq -er '.paths.backup' <<<"${PROFILE_LAYOUT}")"
  PROFILE_CACHE_ROOT="$(jq -er '.paths.cache' <<<"${PROFILE_LAYOUT}")"
  PROFILE_LOG_ROOT="$(jq -er '.paths.logs' <<<"${PROFILE_LAYOUT}")"
  PROFILE_QUERY_ROOT="$(jq -er '.paths.queries' <<<"${PROFILE_LAYOUT}")"
  PROFILE_DIRECTORY_MODE="$(jq -er '.permissions.directory_mode' <<<"${PROFILE_LAYOUT}")"
  PROFILE_FILE_MODE="$(jq -er '.permissions.file_mode' <<<"${PROFILE_LAYOUT}")"
  if [[ "$(jq -er '.uses_natural_paths' <<<"${PROFILE_LAYOUT}")" == "true" ]]; then
    PROFILE_USES_NATURAL_PATHS="yes"
  else
    PROFILE_USES_NATURAL_PATHS="no"
  fi
}

resolve_profile_paths() {
  local profile_name="$1"
  local user_home_dir
  user_home_dir="$(current_user_home)"
  PROFILE_LAYOUT="$("${NODE_BIN_DIR}/node" "${REPO_ROOT}/script/profile_layout.cjs" \
    record "${profile_name}" "${user_home_dir}" "${BUILD_ROOT}")" || return $?
  load_profile_layout_record
}

profile_layout_assert_mutable() {
  "${NODE_BIN_DIR}/node" "${REPO_ROOT}/script/profile_layout.cjs" \
    check-record "${PROFILE_LAYOUT}" "$@"
}
