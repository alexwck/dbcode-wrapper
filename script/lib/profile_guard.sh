#!/usr/bin/env bash

set -euo pipefail

normal_profile_fingerprint() {
  local user_home_dir
  user_home_dir="$(current_user_home)"
  local profile_roots=(
    "${user_home_dir}/Library/Application Support/Code/User"
    "${user_home_dir}/Library/Application Support/VSCodium/User"
    "${user_home_dir}/.vscode/extensions"
    "${user_home_dir}/.vscode-oss/extensions"
    "${user_home_dir}/.vscode-oss-shared"
  )

  {
    local profile_item
    for profile_item in "${profile_roots[@]}"; do
      if [[ -e "${profile_item}" ]]; then
        find "${profile_item}" -type f -exec stat -f '%N|%m|%z' {} + 2>/dev/null
      else
        printf 'missing|%s\n' "${profile_item}"
      fi
    done
  } | LC_ALL=C sort | shasum -a 256 | awk '{print $1}'
}

normal_profile_owner_commands() {
  local user_home_dir
  user_home_dir="$(current_user_home)"
  local profile_roots=(
    "${user_home_dir}/Library/Application Support/Code/User"
    "${user_home_dir}/Library/Application Support/VSCodium/User"
    "${user_home_dir}/.vscode/extensions"
    "${user_home_dir}/.vscode-oss/extensions"
    "${user_home_dir}/.vscode-oss-shared"
  )

  local profile_root
  for profile_root in "${profile_roots[@]}"; do
    if [[ -d "${profile_root}" ]]; then
      lsof -n -P -F c +D "${profile_root}" 2>/dev/null || true
    fi
  done | sed -n 's/^c//p' | LC_ALL=C sort -u
}

record_private_profile_paths() {
  local host_log="$1"
  local user_data_root="$2"
  local shared_data_root="$3"
  local extensions_root="$4"

  [[ -f "${host_log}" && ! -L "${host_log}" ]] || {
    echo "The private-profile evidence log must be a plain file." >&2
    return 1
  }
  printf '%s\n' \
    "DBCode Wrapper user data: ${user_data_root}/User/globalStorage" \
    "DBCode Wrapper shared data: ${shared_data_root}/sharedStorage" \
    "DBCode Wrapper extensions: ${extensions_root}" \
    >> "${host_log}"
  chmod 600 "${host_log}"
}

normal_profile_external_activity_evidence() {
  local host_log="$1"
  local owner_commands="$2"
  local user_home_dir
  user_home_dir="$(current_user_home)"

  local required_private_path
  for required_private_path in \
    "${user_home_dir}/Library/Application Support/${APP_NAME}/User/globalStorage" \
    "${user_home_dir}/${SHARED_DATA_FOLDER_NAME}/sharedStorage" \
    "${user_home_dir}/${DATA_FOLDER_NAME}/extensions"; do
    rg -Fq "${required_private_path}" "${host_log}" || {
      echo "The proof log does not show the private DBCode Wrapper path: ${required_private_path}" >&2
      return 1
    }
  done

  local forbidden_normal_path
  for forbidden_normal_path in \
    "${user_home_dir}/Library/Application Support/Code/User" \
    "${user_home_dir}/Library/Application Support/VSCodium/User" \
    "${user_home_dir}/.vscode/extensions" \
    "${user_home_dir}/.vscode-oss/extensions" \
    "${user_home_dir}/.vscode-oss-shared"; do
    if rg -Fq "${forbidden_normal_path}" "${host_log}"; then
      echo "DBCode Wrapper referenced a normal editor profile: ${forbidden_normal_path}" >&2
      return 1
    fi
  done

  [[ -n "${owner_commands}" ]] || {
    echo "A normal editor profile changed, but no external editor currently owns it." >&2
    return 1
  }
  local owner_command
  while IFS= read -r owner_command; do
    case "${owner_command}" in
      Code|"Code Helper"|VSCodium|"VSCodium Helper") ;;
      *)
        echo "Unexpected process owns a normal editor profile: ${owner_command}" >&2
        return 1
        ;;
    esac
  done <<<"${owner_commands}"

  jq -cn \
    --argjson owners "$(jq -R -s -c 'split("\n") | map(select(length > 0))' <<<"${owner_commands}")" '
      {
        normal_profiles_unchanged: false,
        dbcode_wrapper_private_paths_verified: true,
        normal_profile_activity: {
          attribution: "external-editor-processes",
          owners: $owners
        }
      }
    '
}
