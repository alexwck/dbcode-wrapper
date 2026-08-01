#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

host_session_module="${REPO_ROOT}/script/lib/host-session.js"
host_session_shell="${REPO_ROOT}/script/lib/host_session.sh"
host_session_cli="${REPO_ROOT}/script/host_session.cjs"
contract_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode host session shell.XXXXXX")"
cleanup_contract_root() {
  case "${contract_root}" in
    "${TMPDIR:-/tmp}/dbcode host session shell."*) rm -rf "${contract_root}" ;;
    *) echo "Refusing to remove unexpected Host Session test path: ${contract_root}" >&2; return 1 ;;
  esac
}
trap cleanup_contract_root EXIT INT TERM

for required_file in \
  "${host_session_module}" \
  "${host_session_shell}" \
  "${host_session_cli}" \
  "${REPO_ROOT}/script/test_host_session.mjs"; do
  [[ -f "${required_file}" ]] || {
    echo "Missing Host Session file: ${required_file}" >&2
    exit 1
  }
done

source "${host_session_shell}"
policy_file="${contract_root}/policy.json"
host_log="${contract_root}/host.log"
log_root="${contract_root}/logs"
launch_record="$(jq -cn \
  --arg session_id "default-test" \
  --arg executable "/Applications/DBCode Wrapper.app/Contents/MacOS/Electron" \
  --arg host_log "${host_log}" \
  --arg log_root "${log_root}" '
    {
      session_id: $session_id,
      executable: $executable,
      arguments: ["--user-data-dir", "/tmp/dbcode profile"],
      environment: {ELECTRON_ENABLE_LOGGING: "1"},
      host_log: $host_log,
      log_root: $log_root,
      timeout_seconds: 17
    }
  ')"
host_session_write_policy "${policy_file}" "${launch_record}"
jq -e \
  --arg app_name "${APP_NAME}" \
  --arg host_log "${host_log}" \
  --arg log_root "${log_root}" '
    .schema_version == 1
    and .session_id == "default-test"
    and .executable == "/Applications/DBCode Wrapper.app/Contents/MacOS/Electron"
    and .arguments == ["--user-data-dir", "/tmp/dbcode profile"]
    and .environment == {ELECTRON_ENABLE_LOGGING: "1"}
    and .host_log == $host_log
    and .log_root == $log_root
    and .readiness.timeout_seconds == 17
    and .readiness.poll_interval_ms == 1000
    and .readiness.renderer == {
      command_contains: [($app_name + " Helper (Renderer).app"), "--type=renderer"],
      stable_observations: 1
    }
    and .readiness.dbcode == {
      required: true,
      log_suffix: "/dbcode.dbcode/DBCode.log",
      patterns: [{kind: "literal", value: "DBCode starting..."}]
    }
    and .readiness.host_log_patterns == []
    and .readiness.fatal_host_log_patterns == [{
      kind: "regex",
      value: "Library not loaded:|not valid for use in process|renderer process gone|GPU process isn.t usable|FATAL:"
    }]
    and .completion == {
      mode: "wait-for-exit",
      require_dbcode_before_exit: false,
      graceful_timeout_seconds: 10,
      force_timeout_seconds: 5
    }
  ' "${policy_file}" >/dev/null

invalid_policy_file="${contract_root}/invalid-policy.json"
invalid_launch_record="$(jq -c '. + {readiness: {}}' <<<"${launch_record}")"
if host_session_write_policy "${invalid_policy_file}" "${invalid_launch_record}" 2>/dev/null; then
  echo "Host Session accepted an unexpected launch-record field." >&2
  exit 1
fi
[[ ! -e "${invalid_policy_file}" ]] || {
  echo "Host Session wrote a policy for an invalid launch record." >&2
  exit 1
}

rg -Fq 'host_session_write_policy' "${REPO_ROOT}/script/run_host.sh" || {
  echo "The normal launch path does not declare a Host Session policy." >&2
  exit 1
}
rg -Fq 'host_session_run' "${REPO_ROOT}/script/run_host.sh" || {
  echo "The normal launch path does not use the Host Session lifecycle." >&2
  exit 1
}

rg -Fq 'Foreground debugging deliberately' "${REPO_ROOT}/script/run_host.sh" || {
  echo "Foreground debugging must remain an explicit non-production adapter." >&2
  exit 1
}
rg -Fq './script/host_session.cjs run --policy FILE --output FILE' "${host_session_cli}" || {
  echo "Host Session must expose one run command." >&2
  exit 1
}

"${NODE_BIN_DIR}/node" --check "${host_session_module}"
"${NODE_BIN_DIR}/node" --check "${host_session_cli}"
"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_host_session.mjs"

echo "Host Session lifecycle contracts passed."
