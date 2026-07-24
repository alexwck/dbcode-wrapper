#!/usr/bin/env bash

set -euo pipefail

apply_managed_profile_settings() {
  local settings_file="$1"
  local managed_settings_file="$2"

  if [[ -L "${settings_file}" ]]; then
    echo "Refusing a symlinked private profile settings file." >&2
    return 1
  fi

  if [[ ! -e "${settings_file}" ]]; then
    cp "${managed_settings_file}" "${settings_file}"
    chmod 600 "${settings_file}"
    return
  fi

  jq -e 'type == "object"' "${settings_file}" >/dev/null || {
    echo "The private profile settings file is not valid JSON." >&2
    return 1
  }

  local settings_temp
  settings_temp="$(mktemp "${settings_file}.tmp.XXXXXX")"
  jq -s '.[0] * .[1]' "${settings_file}" "${managed_settings_file}" > "${settings_temp}"
  chmod 600 "${settings_temp}"
  mv "${settings_temp}" "${settings_file}"
}
