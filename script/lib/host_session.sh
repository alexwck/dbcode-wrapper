#!/usr/bin/env bash

set -euo pipefail

host_session_default_fatal_patterns() {
  jq -cn '[
    {kind: "regex", value: "Library not loaded:|not valid for use in process|renderer process gone|GPU process isn.t usable|FATAL:"}
  ]'
}

host_session_write_policy() {
  local output_file="$1"
  local launch_record_json="$2"
  local fatal_patterns_json

  [[ "${output_file}" == /* && ! -L "${output_file}" ]] || {
    echo "Host Session policy path must be absolute and must not be a symbolic link." >&2
    return 1
  }
  jq -e '
    type == "object"
    and (keys == [
      "arguments",
      "environment",
      "executable",
      "host_log",
      "log_root",
      "session_id",
      "timeout_seconds"
    ])
    and (.session_id | type == "string" and length > 0)
    and (.executable | type == "string" and length > 0)
    and (.arguments | type == "array" and all(.[]; type == "string"))
    and (.environment | type == "object" and all(to_entries[]; .value | type == "string"))
    and (.host_log | type == "string" and length > 0)
    and (.log_root | type == "string" and length > 0)
    and (.timeout_seconds | type == "number" and floor == . and . > 0)
  ' <<<"${launch_record_json}" >/dev/null || {
    echo "Host Session launch record is invalid." >&2
    return 1
  }
  fatal_patterns_json="$(host_session_default_fatal_patterns)"
  jq -n \
    --arg app_name "${APP_NAME}" \
    --argjson launch "${launch_record_json}" \
    --argjson fatal_host_log_patterns "${fatal_patterns_json}" '
      {
        schema_version: 1,
        session_id: $launch.session_id,
        executable: $launch.executable,
        arguments: $launch.arguments,
        environment: $launch.environment,
        host_log: $launch.host_log,
        log_root: $launch.log_root,
        readiness: {
          timeout_seconds: $launch.timeout_seconds,
          poll_interval_ms: 1000,
          renderer: {
            command_contains: [($app_name + " Helper (Renderer).app"), "--type=renderer"],
            stable_observations: 1
          },
          dbcode: {
            required: true,
            log_suffix: "/dbcode.dbcode/DBCode.log",
            patterns: [{kind: "literal", value: "DBCode starting..."}]
          },
          host_log_patterns: [],
          fatal_host_log_patterns: $fatal_host_log_patterns
        },
        completion: {
          mode: "wait-for-exit",
          require_dbcode_before_exit: false,
          graceful_timeout_seconds: 10,
          force_timeout_seconds: 5
        }
      }
    ' > "${output_file}"
  chmod 600 "${output_file}"
}

host_session_run() {
  "${NODE_BIN_DIR}/node" "${REPO_ROOT}/script/host_session.cjs" \
    run --policy "$1" --output "$2"
}
