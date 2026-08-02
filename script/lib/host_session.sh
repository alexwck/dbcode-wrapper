#!/usr/bin/env bash

set -euo pipefail

host_session_run() (
  local launch_record_json="$1"
  local policy_file="$2"
  local output_file="$3"
  local launch_file

  [[ "${policy_file}" == /* && ! -L "${policy_file}" ]] || {
    echo "Host Session policy path must be absolute and must not be a symbolic link." >&2
    return 1
  }
  launch_file="$(mktemp "$(dirname "${policy_file}")/.host-session-launch.XXXXXX")"
  cleanup_host_session_launch() {
    rm -f "${launch_file}"
  }
  trap cleanup_host_session_launch EXIT INT TERM
  printf '%s\n' "${launch_record_json}" > "${launch_file}"
  chmod 600 "${launch_file}"

  "${NODE_BIN_DIR}/node" "${REPO_ROOT}/script/host_session.cjs" \
    run \
    --launch "${launch_file}" \
    --policy "${policy_file}" \
    --output "${output_file}"
)
