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
launch_record="$(jq -cn \
  --arg session_id "default-test" \
  --arg app_name "${APP_NAME}" \
  --arg executable "/Applications/DBCode Wrapper.app/Contents/MacOS/Electron" \
  --arg host_log "${contract_root}/host.log" \
  --arg log_root "${contract_root}/logs" '
    {
      session_id: $session_id,
      app_name: $app_name,
      executable: $executable,
      arguments: ["--user-data-dir", "/tmp/dbcode profile"],
      environment: {ELECTRON_ENABLE_LOGGING: "1"},
      host_log: $host_log,
      log_root: $log_root,
      timeout_seconds: 17
    }
  ')"

stub_node_root="${contract_root}/node bin"
mkdir -p "${stub_node_root}"
cat > "${stub_node_root}/node" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == */script/host_session.cjs ]]
[[ "$2" == "run" && "$3" == "--launch" && "$5" == "--policy" && "$7" == "--output" ]]
cat "$4" > "${HOST_SESSION_STUB_LAUNCH_RECORD}"
printf '%s\n' "$6" "$8" > "${HOST_SESSION_STUB_OUTPUT_PATHS}"
EOF
chmod 755 "${stub_node_root}/node"
original_node_bin_dir="${NODE_BIN_DIR}"
NODE_BIN_DIR="${stub_node_root}"
export HOST_SESSION_STUB_LAUNCH_RECORD="${contract_root}/captured-launch.json"
export HOST_SESSION_STUB_OUTPUT_PATHS="${contract_root}/captured-paths.txt"
policy_file="${contract_root}/active policy.json"
output_file="${contract_root}/active result.json"
host_session_run "${launch_record}" "${policy_file}" "${output_file}"
NODE_BIN_DIR="${original_node_bin_dir}"

[[ "$(jq -S -c . "${HOST_SESSION_STUB_LAUNCH_RECORD}")" == "$(jq -S -c . <<<"${launch_record}")" ]] || {
  echo "The Host Session shell adapter changed the purpose-level launch record." >&2
  exit 1
}
captured_policy_path="$(sed -n '1p' "${HOST_SESSION_STUB_OUTPUT_PATHS}")"
captured_output_path="$(sed -n '2p' "${HOST_SESSION_STUB_OUTPUT_PATHS}")"
[[ "${captured_policy_path}" == "${policy_file}" && "${captured_output_path}" == "${output_file}" ]] || {
  echo "The Host Session shell adapter changed a path containing spaces." >&2
  exit 1
}
if find "${contract_root}" -name '.host-session-launch.*' -print -quit | grep -q .; then
  echo "The Host Session shell adapter left its temporary launch record behind." >&2
  exit 1
fi

rg -Fq 'host_session_run "${launch_record_json}" "${session_policy_file}" "${session_result_file}"' \
  "${REPO_ROOT}/script/run_host.sh" || {
  echo "The normal launch path does not use the purpose-level Host Session interface." >&2
  exit 1
}
if rg -Fq 'host_session_write_policy' "${REPO_ROOT}/script/run_host.sh" "${host_session_shell}"; then
  echo "Host Session policy construction still leaks into the shell adapter." >&2
  exit 1
fi
rg -Fq 'Foreground debugging deliberately' "${REPO_ROOT}/script/run_host.sh" || {
  echo "Foreground debugging must remain an explicit non-production adapter." >&2
  exit 1
}
rg -Fq './script/host_session.cjs run --launch FILE --policy FILE --output FILE' "${host_session_cli}" || {
  echo "Host Session must expose one run command." >&2
  exit 1
}

"${NODE_BIN_DIR}/node" --check "${host_session_module}"
"${NODE_BIN_DIR}/node" --check "${host_session_cli}"
"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_host_session.mjs"

echo "Host Session lifecycle contracts passed."
