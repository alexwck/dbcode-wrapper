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

for caller in \
  "${REPO_ROOT}/script/run_host.sh" \
  "${REPO_ROOT}/script/smoke_release_pair.sh" \
  "${REPO_ROOT}/script/check_installed_release_health.sh"; do
  rg -Fq 'host_session_write_policy' "${caller}" || {
    echo "A production launch path does not declare a Host Session policy: ${caller}" >&2
    exit 1
  }
  rg -Fq 'host_session_run' "${caller}" || {
    echo "A production launch path does not use the Host Session lifecycle: ${caller}" >&2
    exit 1
  }
done

for removed_loop in \
  'pgrep -P "${app_pid}"' \
  'kill -TERM "${app_pid}"' \
  'kill -KILL "${app_pid}"'; do
  if rg -Fq "${removed_loop}" \
    "${REPO_ROOT}/script/run_host.sh" \
    "${REPO_ROOT}/script/smoke_release_pair.sh" \
    "${REPO_ROOT}/script/check_installed_release_health.sh"; then
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

"${NODE_BIN_DIR}/node" --check "${host_session_module}"
"${NODE_BIN_DIR}/node" --check "${host_session_cli}"
"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_host_session.mjs"

echo "Host Session lifecycle contracts passed."
