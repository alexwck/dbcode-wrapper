#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

host_session_module="${REPO_ROOT}/script/lib/host-session.js"
host_session_shell="${REPO_ROOT}/script/lib/host_session.sh"
host_session_cli="${REPO_ROOT}/script/host_session.cjs"

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

rg -Fq 'host_session_write_policy' "${REPO_ROOT}/script/run_host.sh" || {
  echo "The normal launch path does not declare a Host Session policy." >&2
  exit 1
}
rg -Fq 'host_session_run' "${REPO_ROOT}/script/run_host.sh" || {
  echo "The normal launch path does not use the Host Session lifecycle." >&2
  exit 1
}

for removed_loop in \
  'pgrep -P "${app_pid}"' \
  'kill -TERM "${app_pid}"' \
  'kill -KILL "${app_pid}"'; do
  if rg -Fq "${removed_loop}" "${REPO_ROOT}/script/run_host.sh"; then
    echo "A removed launch or quit loop returned: ${removed_loop}" >&2
    exit 1
  fi
done

rg -Fq 'Foreground debugging deliberately' "${REPO_ROOT}/script/run_host.sh" || {
  echo "Foreground debugging must remain an explicit non-production adapter." >&2
  exit 1
}
[[ ! -e "${REPO_ROOT}/script/lib/launch_readiness.sh" ]] || {
  echo "The superseded launch-readiness helper still exists." >&2
  exit 1
}

if rg -Fq 'validate-policy' "${host_session_cli}" "${host_session_shell}"; then
  echo "Host Session still exposes the redundant validate-policy command." >&2
  exit 1
fi
if rg -Fq "command === 'stop'" "${host_session_cli}"; then
  echo "Host Session still exposes the unused stop command adapter." >&2
  exit 1
fi
if rg -Fq 'return validateSessionPolicy(policy);' "${host_session_cli}"; then
  echo "The Host Session adapter still validates a policy before run validates it." >&2
  exit 1
fi
rg -Fq 'return stopValidatedHostSession(result, policy, runtime);' "${host_session_module}" || {
  echo "Host Session run must reuse its already validated policy during shutdown." >&2
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
