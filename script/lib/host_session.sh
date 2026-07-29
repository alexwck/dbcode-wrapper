#!/usr/bin/env bash

set -euo pipefail

host_session_default_fatal_patterns() {
  jq -cn '[
    {kind: "regex", value: "Library not loaded:|not valid for use in process|renderer process gone|GPU process isn.t usable|FATAL:"}
  ]'
}

host_session_write_policy() {
  local output_file="$1"
  local session_id="$2"
  local executable="$3"
  local arguments_json="$4"
  local environment_json="$5"
  local host_log="$6"
  local log_root="$7"
  local timeout_seconds="$8"
  local poll_interval_ms="$9"
  local stable_observations="${10}"
  local dbcode_required="${11}"
  local dbcode_patterns_json="${12}"
  local host_log_patterns_json="${13}"
  local completion_mode="${14}"
  local require_dbcode_before_exit="${15}"
  local fatal_patterns_json="${16:-$(host_session_default_fatal_patterns)}"

  [[ "${output_file}" == /* && ! -L "${output_file}" ]] || {
    echo "Host Session policy path must be absolute and must not be a symbolic link." >&2
    return 1
  }
  jq -n \
    --arg session_id "${session_id}" \
    --arg app_name "${APP_NAME}" \
    --arg executable "${executable}" \
    --argjson arguments "${arguments_json}" \
    --argjson environment "${environment_json}" \
    --arg host_log "${host_log}" \
    --arg log_root "${log_root}" \
    --argjson timeout_seconds "${timeout_seconds}" \
    --argjson poll_interval_ms "${poll_interval_ms}" \
    --argjson stable_observations "${stable_observations}" \
    --argjson dbcode_required "${dbcode_required}" \
    --argjson dbcode_patterns "${dbcode_patterns_json}" \
    --argjson host_log_patterns "${host_log_patterns_json}" \
    --argjson fatal_host_log_patterns "${fatal_patterns_json}" \
    --arg completion_mode "${completion_mode}" \
    --argjson require_dbcode_before_exit "${require_dbcode_before_exit}" '
      {
        schema_version: 1,
        session_id: $session_id,
        executable: $executable,
        arguments: $arguments,
        environment: $environment,
        host_log: $host_log,
        log_root: $log_root,
        readiness: {
          timeout_seconds: $timeout_seconds,
          poll_interval_ms: $poll_interval_ms,
          renderer: {
            command_contains: [($app_name + " Helper (Renderer).app"), "--type=renderer"],
            stable_observations: $stable_observations
          },
          dbcode: {
            required: $dbcode_required,
            log_suffix: "/dbcode.dbcode/DBCode.log",
            patterns: $dbcode_patterns
          },
          host_log_patterns: $host_log_patterns,
          fatal_host_log_patterns: $fatal_host_log_patterns
        },
        completion: {
          mode: $completion_mode,
          require_dbcode_before_exit: $require_dbcode_before_exit,
          graceful_timeout_seconds: 10,
          force_timeout_seconds: 5
        }
      }
    ' > "${output_file}"
  chmod 600 "${output_file}"
  "${NODE_BIN_DIR}/node" "${REPO_ROOT}/script/host_session.cjs" \
    validate-policy --policy "${output_file}" >/dev/null
}

host_session_run() {
  "${NODE_BIN_DIR}/node" "${REPO_ROOT}/script/host_session.cjs" \
    run --policy "$1" --output "$2"
}
