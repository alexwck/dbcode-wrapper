#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/profile_paths.sh"
source "${REPO_ROOT}/script/lib/host_session.sh"

requested_action="run"
if [[ $# -gt 0 ]]; then
  requested_action="${1}"
  shift
fi

case "${requested_action}" in
  --logs)
    latest_log="$(find "${BUILD_ROOT}/logs" "${BUILD_ROOT}/profiles" -type f -name '*.log' -print 2>/dev/null | xargs ls -t 2>/dev/null | head -1 || true)"
    if [[ -z "${latest_log}" ]]; then
      echo "No host log exists yet." >&2
      exit 1
    fi
    tail -n 200 -f "${latest_log}"
    exit 0
    ;;
  --verify)
    if [[ ! -d "${APP_BUNDLE}" ]]; then
      "${REPO_ROOT}/script/build_host.sh"
    fi
    exec "${REPO_ROOT}/script/smoke_host.sh"
    ;;
  --debug)
    run_mode=(--debug)
    ;;
  --telemetry)
    if [[ ! -d "${APP_BUNDLE}" ]]; then
      "${REPO_ROOT}/script/build_host.sh"
    else
      "${REPO_ROOT}/script/generate_manifest.sh"
    fi
    jq '{built_at_utc, source, toolchain, runtime, artifact}' "${BUILD_MANIFEST}"
    exit 0
    ;;
  run)
    run_mode=()
    ;;
  *)
    echo "Usage: ./script/build_and_run.sh [--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac

if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
  resolve_profile_paths default
  active_session_policy="${PROFILE_STATE_ROOT}/active-host-session-policy.json"
  active_session_result="${PROFILE_STATE_ROOT}/active-host-session.json"
  if [[ -f "${active_session_policy}" && -f "${active_session_result}" ]] && \
    [[ "$(jq -r '.status // empty' "${active_session_result}" 2>/dev/null)" == "ready" ]]; then
    host_session_stop "${active_session_policy}" "${active_session_result}" "${active_session_result}"
  else
    echo "Quit ${APP_NAME} before rebuilding; the running app is not owned by an active Host Session." >&2
    exit 1
  fi
fi

"${REPO_ROOT}/script/build_host.sh"
exec "${REPO_ROOT}/script/run_host.sh" "${run_mode[@]}"
