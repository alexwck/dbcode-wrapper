#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/profile_paths.sh"
source "${REPO_ROOT}/script/lib/host_session.sh"

launch_style="monitored"
workspace_path=""
launch_timeout_seconds="${DBCODE_WRAPPER_LAUNCH_TIMEOUT_SECONDS:-30}"

if [[ ! "${launch_timeout_seconds}" =~ ^[0-9]+$ ]] || \
  [[ "${launch_timeout_seconds}" -lt 1 || "${launch_timeout_seconds}" -gt 600 ]]; then
  echo "DBCODE_WRAPPER_LAUNCH_TIMEOUT_SECONDS must be an integer from 1 to 600." >&2
  exit 2
fi

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --debug)
      launch_style="foreground-debug"
      ;;
    --workspace)
      [[ $# -ge 2 ]] || { echo "--workspace requires a directory." >&2; exit 2; }
      workspace_path="$2"
      shift
      ;;
    *)
      echo "Unknown run option: ${1}" >&2
      exit 2
      ;;
  esac
  shift
done

if [[ ! -d "${APP_BUNDLE}" ]]; then
  echo "Build the host first with ./script/build_host.sh" >&2
  exit 1
fi

if [[ -n "${workspace_path}" && ! -d "${workspace_path}" ]]; then
  echo "Workspace directory does not exist: ${workspace_path}" >&2
  exit 1
fi

current_release_lock_sha256="$(shasum -a 256 "${LOCK_FILE}" | awk '{print $1}')"
if [[ "${DBCODE_WRAPPER_PREPARED_RELEASE_SET_SHA256:-}" != "${current_release_lock_sha256}" ]]; then
  "${REPO_ROOT}/script/prepare_dbcode.sh" --profile default
fi

resolve_profile_paths default
profile_layout_assert_mutable state user_data extensions shared_data backup cache logs
profile_root="${PROFILE_STATE_ROOT}"
user_data_root="${PROFILE_USER_DATA_ROOT}"
extensions_root="${PROFILE_EXTENSIONS_ROOT}"
shared_data_root="${PROFILE_SHARED_DATA_ROOT}"
backup_root="${PROFILE_BACKUP_ROOT}"
cache_root="${PROFILE_CACHE_ROOT}"
log_root="${PROFILE_LOG_ROOT}"
mkdir -p "${user_data_root}" "${extensions_root}" "${shared_data_root}" "${backup_root}" "${cache_root}" "${log_root}"
chmod "${PROFILE_DIRECTORY_MODE}" "${profile_root}" "${user_data_root}" "${extensions_root}" "${shared_data_root}" "${backup_root}" "${cache_root}" "${log_root}"

launch_args=(
  --disable-telemetry
  --disable-updates
  --new-window
  --skip-release-notes
  --skip-welcome
)

if [[ "${PROFILE_USES_NATURAL_PATHS}" == "no" ]]; then
  launch_args=(
    --user-data-dir "${user_data_root}"
    --extensions-dir "${extensions_root}"
    --shared-data-dir "${shared_data_root}"
    --disk-cache-dir "${cache_root}"
    --logsPath "${log_root}"
    --disable-telemetry
    --disable-updates
    --disable-workspace-trust
    --new-window
    --skip-release-notes
    --skip-welcome
  )
fi

if [[ -n "${workspace_path}" ]]; then
  launch_args+=("${workspace_path}")
fi

if [[ "${launch_style}" == "foreground-debug" ]]; then
  launch_args+=(--open-devtools --inspect-extensions=0 --verbose)
fi

export DBCODE_WRAPPER_SHARED_DATA_ROOT="${shared_data_root}"
export DBCODE_WRAPPER_EXTENSIONS_ROOT="${extensions_root}"
export DBCODE_WRAPPER_PROFILE_BACKUP_ROOT="${backup_root}"
export DBCODE_WRAPPER_APP_BUNDLE="${APP_BUNDLE}"
export DBCODE_WRAPPER_PROFILE_LAYOUT_JSON="${PROFILE_LAYOUT}"
DBCODE_WRAPPER_RECOVERY_RELAUNCH_ARGS="$(jq -cn --args '$ARGS.positional' -- "${launch_args[@]}")"
export DBCODE_WRAPPER_RECOVERY_RELAUNCH_ARGS

bundle_executable="$(plutil -extract CFBundleExecutable raw "${APP_BUNDLE}/Contents/Info.plist")"
app_executable="${APP_BUNDLE}/Contents/MacOS/${bundle_executable}"

if [[ "${launch_style}" == "foreground-debug" ]]; then
  # Foreground debugging deliberately streams the application directly to the developer.
  # Normal monitored launches always use the Host Session module below.
  ELECTRON_ENABLE_LOGGING=1 "${app_executable}" "${launch_args[@]}" 2>&1 | tee "${log_root}/host-debug.log"
else
  host_log="${log_root}/proof-host.log"
  active_dbcode_log_file="${profile_root}/active-dbcode-log"
  session_policy_file="${profile_root}/active-host-session-policy.json"
  session_result_file="${profile_root}/active-host-session.json"
  rm -f "${active_dbcode_log_file}"
  launch_arguments_json="$(jq -cn --args '$ARGS.positional' -- "${launch_args[@]}")"
  launch_environment_json="$(jq -cn \
    --arg shared_data_root "${shared_data_root}" \
    --arg extensions_root "${extensions_root}" \
    --arg backup_root "${backup_root}" \
    --arg app_bundle "${APP_BUNDLE}" \
    --arg profile_layout "${PROFILE_LAYOUT}" \
    --arg relaunch_args "${DBCODE_WRAPPER_RECOVERY_RELAUNCH_ARGS}" '
      {
        DBCODE_WRAPPER_SHARED_DATA_ROOT: $shared_data_root,
        DBCODE_WRAPPER_EXTENSIONS_ROOT: $extensions_root,
        DBCODE_WRAPPER_PROFILE_BACKUP_ROOT: $backup_root,
        DBCODE_WRAPPER_APP_BUNDLE: $app_bundle,
        DBCODE_WRAPPER_PROFILE_LAYOUT_JSON: $profile_layout,
        DBCODE_WRAPPER_RECOVERY_RELAUNCH_ARGS: $relaunch_args,
        ELECTRON_ENABLE_LOGGING: "1"
      }
    ')"
  dbcode_required="true"
  require_dbcode_before_exit="false"
  dbcode_patterns_json='[{"kind":"literal","value":"DBCode starting..."}]'
  host_session_write_policy \
    "${session_policy_file}" \
    "default-$(date -u +'%Y%m%dT%H%M%SZ')-$$" \
    "${app_executable}" \
    "${launch_arguments_json}" \
    "${launch_environment_json}" \
    "${host_log}" \
    "${log_root}" \
    "${launch_timeout_seconds}" \
    1000 \
    1 \
    "${dbcode_required}" \
    "${dbcode_patterns_json}" \
    '[]' \
    wait-for-exit \
    "${require_dbcode_before_exit}"

  if ! host_session_run "${session_policy_file}" "${session_result_file}"; then
    echo "${APP_NAME} failed its Host Session policy. See ${host_log}" >&2
    tail -n 80 "${host_log}" >&2 || true
    exit 1
  fi
  [[ -f "${host_log}" && ! -L "${host_log}" ]] || {
    echo "The private-profile evidence log must be a plain file." >&2
    exit 1
  }
  printf '%s\n' \
    "DBCode Wrapper user data: ${user_data_root}/User/globalStorage" \
    "DBCode Wrapper shared data: ${shared_data_root}/sharedStorage" \
    "DBCode Wrapper extensions: ${extensions_root}" \
    >> "${host_log}"
  chmod 600 "${host_log}"
  dbcode_log="$(jq -er '.evidence.dbcode_log' "${session_result_file}")"
  printf '%s\n' "${dbcode_log}" > "${active_dbcode_log_file}"
  chmod "${PROFILE_FILE_MODE}" "${active_dbcode_log_file}"
  printf '%s\n' "$(jq -er '.process.app_pid' "${session_result_file}")" > "${profile_root}/host.pid"
  chmod "${PROFILE_FILE_MODE}" "${profile_root}/host.pid"
fi

echo "Completed ${APP_NAME} Host Session with Standalone DBCode Profile ${profile_root}"
