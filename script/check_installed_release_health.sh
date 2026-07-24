#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/artifact_digest.sh"
source "${REPO_ROOT}/script/lib/host_session.sh"

# A failed health check must still leave a complete receipt for diagnosis.
set +e
set -uo pipefail

usage() {
  echo "Usage: ./script/check_installed_release_health.sh --layout FILE --state FILE --output FILE" >&2
  exit 2
}

layout_file=""
state_file=""
output_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --layout) [[ $# -ge 2 ]] || usage; layout_file="$2"; shift ;;
    --state) [[ $# -ge 2 ]] || usage; state_file="$2"; shift ;;
    --output) [[ $# -ge 2 ]] || usage; output_file="$2"; shift ;;
    *) usage ;;
  esac
  shift
done
[[ -n "${layout_file}" && -n "${state_file}" && -n "${output_file}" ]] || usage
[[ ! -L "${output_file}" ]] || {
  echo "Refusing a symlinked restart health receipt: ${output_file}" >&2
  exit 1
}

output_parent="$(cd "$(dirname "${output_file}")" 2>/dev/null && pwd -P)"
[[ -n "${output_parent}" ]] || {
  echo "The restart health receipt parent does not exist." >&2
  exit 1
}

failure_file="$(mktemp "${output_parent}/restart-health-failures.XXXXXX")"
target_app=""
runtime_root=""

record_failure() {
  local failure="$1"
  rg -Fxq "${failure}" "${failure_file}" 2>/dev/null || printf '%s\n' "${failure}" >> "${failure_file}"
}

bundle_process_ids() {
  [[ -n "${target_app}" ]] || return 0
  ps -ax -o pid= -o command= 2>/dev/null | while read -r process_id process_command; do
    case "${process_command}" in
      *"${target_app}/Contents/"*) printf '%s\n' "${process_id}" ;;
    esac
  done
}

cleanup() {
  [[ ! -e "${failure_file}" ]] || rm -f "${failure_file}"
}
trap cleanup EXIT INT TERM

first_launch_ready="false"
first_quit_complete="false"
relaunch_ready="false"
final_quit_complete="false"
dbcode_started="false"
account_restored="false"
keychain_error_absent="false"
surprise_update_absent="false"

release_set_id="unknown"
expected_app_sha=""
expected_manifest_sha=""
expected_extensions_sha=""
if [[ -f "${state_file}" && ! -L "${state_file}" ]]; then
  release_set_id="$(jq -r '.active.release_set_id // "unknown"' "${state_file}" 2>/dev/null)"
  expected_app_sha="$(jq -r '.active.app_sha256 // empty' "${state_file}" 2>/dev/null)"
  expected_manifest_sha="$(jq -r '.active.build_manifest_sha256 // empty' "${state_file}" 2>/dev/null)"
  expected_extensions_sha="$(jq -r '.active.extensions_sha256 // empty' "${state_file}" 2>/dev/null)"
else
  record_failure "installed-state-missing-or-unsafe"
fi

target_manifest=""
target_user_data=""
target_extensions=""
target_shared_data=""
state_root=""
if [[ -f "${layout_file}" && ! -L "${layout_file}" ]] && \
  jq -e '.schema_version == 1' "${layout_file}" >/dev/null 2>&1; then
  target_app="$(jq -r '.targets.app // empty' "${layout_file}")"
  target_manifest="$(jq -r '.targets.build_manifest // empty' "${layout_file}")"
  target_user_data="$(jq -r '.targets.user_data // empty' "${layout_file}")"
  target_extensions="$(jq -r '.targets.extensions // empty' "${layout_file}")"
  target_shared_data="$(jq -r '.targets.shared_data // empty' "${layout_file}")"
  state_root="$(jq -r '.state_root // empty' "${layout_file}")"
else
  record_failure "install-layout-missing-or-invalid"
fi

inputs_ready="true"
if ! jq -e '.schema_version == 1 and .status == "pending-health-check"' \
  "${state_file}" >/dev/null 2>&1; then
  record_failure "installed-state-not-pending-health-check"
  inputs_ready="false"
fi
for required_path in target_app target_user_data target_extensions target_shared_data state_root; do
  path_value="${!required_path:-}"
  if [[ -z "${path_value}" || ! -d "${path_value}" || -L "${path_value}" ]]; then
    record_failure "unsafe-or-missing-${required_path//_/-}"
    inputs_ready="false"
  fi
done
if [[ -z "${target_manifest}" || ! -f "${target_manifest}" || -L "${target_manifest}" ]]; then
  record_failure "unsafe-or-missing-target-manifest"
  inputs_ready="false"
fi
ipc_socket_path="${target_user_data}/1.12-main.sock"
if [[ -n "${target_user_data}" && "${#ipc_socket_path}" -gt 103 ]]; then
  record_failure "user-data-path-too-long-for-ipc"
  inputs_ready="false"
fi

actual_app_sha=""
actual_manifest_sha=""
actual_extensions_sha=""
if [[ "${inputs_ready}" == "true" ]]; then
  actual_app_sha="$(artifact_digest "${target_app}")"
  actual_manifest_sha="$(shasum -a 256 "${target_manifest}" | awk '{print $1}')"
  actual_extensions_sha="$(directory_content_digest "${target_extensions}")"
  [[ "${actual_app_sha}" == "${expected_app_sha}" ]] || {
    record_failure "installed-app-state-mismatch"
    inputs_ready="false"
  }
  [[ "${actual_manifest_sha}" == "${expected_manifest_sha}" ]] || {
    record_failure "installed-manifest-state-mismatch"
    inputs_ready="false"
  }
  [[ "${actual_extensions_sha}" == "${expected_extensions_sha}" ]] || {
    record_failure "installed-extensions-state-mismatch"
    inputs_ready="false"
  }
  jq -e --arg app_sha "${actual_app_sha}" '
    .artifact.sha256 == $app_sha
    and .packaging.updater_enabled == false
  ' "${target_manifest}" >/dev/null 2>&1 || {
    record_failure "installed-manifest-health-policy"
    inputs_ready="false"
  }
fi

app_executable=""
if [[ "${inputs_ready}" == "true" ]]; then
  executable_name="$(plutil -extract CFBundleExecutable raw "${target_app}/Contents/Info.plist" 2>/dev/null)"
  app_executable="${target_app}/Contents/MacOS/${executable_name}"
  if [[ -z "${executable_name}" || ! -x "${app_executable}" || -L "${app_executable}" ]]; then
    record_failure "installed-bundle-executable"
    inputs_ready="false"
  fi
fi

if [[ "${inputs_ready}" == "true" ]] && [[ -n "$(bundle_process_ids)" ]]; then
  record_failure "installed-app-not-fully-stopped"
  inputs_ready="false"
fi

launch_timeout="${DBCODE_WRAPPER_HEALTH_TIMEOUT_SECONDS:-90}"
if [[ ! "${launch_timeout}" =~ ^[0-9]+$ || "${launch_timeout}" -lt 1 || "${launch_timeout}" -gt 600 ]]; then
  launch_timeout=90
fi

launch_dbcode_started="false"
launch_account_restored="false"
launch_keychain_clear="false"
launch_update_clear="false"
launch_quit_complete="false"

launch_once() {
  local launch_number="$1"
  local launch_root="${runtime_root}/launch-${launch_number}"
  local host_log="${launch_root}/host.log"
  local logs_root="${launch_root}/logs"
  local cache_root="${launch_root}/cache"
  local session_policy="${launch_root}/host-session-policy.json"
  local session_result="${launch_root}/host-session-result.json"
  local launch_arguments launch_environment

  launch_dbcode_started="false"
  launch_account_restored="false"
  launch_keychain_clear="false"
  launch_update_clear="false"
  launch_quit_complete="false"
  mkdir -p "${logs_root}" "${cache_root}"
  chmod -R go-rwx "${launch_root}"
  launch_arguments="$(jq -cn --args '$ARGS.positional' -- \
    --user-data-dir "${target_user_data}" \
    --extensions-dir "${target_extensions}" \
    --shared-data-dir "${target_shared_data}" \
    --disk-cache-dir "${cache_root}" \
    --logsPath "${logs_root}" \
    --disable-telemetry \
    --disable-updates \
    --disable-workspace-trust \
    --new-window \
    --skip-release-notes \
    --skip-welcome \
    "${REPO_ROOT}/host/qa/project-query.sql")"
  launch_environment="$(jq -cn \
    --arg shared_data_root "${target_shared_data}" \
    --arg extensions_root "${target_extensions}" \
    --arg backup_root "$(dirname "${state_root}")" \
    --arg app_bundle "${target_app}" \
    --arg relaunch_args "${launch_arguments}" '{
      DBCODE_WRAPPER_SHARED_DATA_ROOT: $shared_data_root,
      DBCODE_WRAPPER_EXTENSIONS_ROOT: $extensions_root,
      DBCODE_WRAPPER_PROFILE_BACKUP_ROOT: $backup_root,
      DBCODE_WRAPPER_APP_BUNDLE: $app_bundle,
      DBCODE_WRAPPER_RECOVERY_RELAUNCH_ARGS: $relaunch_args,
      ELECTRON_ENABLE_LOGGING: "1"
    }')"
  host_session_write_policy \
    "${session_policy}" \
    "installed-health-${launch_number}-$$" \
    "${app_executable}" \
    "${launch_arguments}" \
    "${launch_environment}" \
    "${host_log}" \
    "${logs_root}" \
    "${launch_timeout}" \
    1000 \
    1 \
    true \
    '[{"kind":"literal","value":"DBCode started"},{"kind":"regex","value":"Auth: (Sign in restored|Web-session JWT refreshed)"}]' \
    '[]' \
    quit-after-ready \
    false

  if host_session_run "${session_policy}" "${session_result}"; then
    launch_dbcode_started="true"
    launch_account_restored="true"
  fi

  if ! rg -Fq 'Keychain lookup failed:' "${host_log}" "${logs_root}" 2>/dev/null && \
    ! rg -Fq "An OS keyring couldn't be identified" "${host_log}" "${logs_root}" 2>/dev/null; then
    launch_keychain_clear="true"
  fi
  if ! rg -i -q 'update.*(install|download)|install.*update' \
    "${host_log}" "${logs_root}" 2>/dev/null; then
    launch_update_clear="true"
  fi

  if [[ -f "${session_result}" ]] && \
    [[ "$(jq -r '.quit.complete // false' "${session_result}" 2>/dev/null)" == "true" ]] && \
    [[ -z "$(bundle_process_ids)" ]]; then
    launch_quit_complete="true"
  fi

  [[ "${launch_dbcode_started}" == "true" && "${launch_quit_complete}" == "true" ]]
}

if [[ "${inputs_ready}" == "true" ]]; then
  runtime_root="${state_root}/restart-health-$(date -u +'%Y%m%dT%H%M%SZ')-$$"
  if mkdir -p "${runtime_root}" && chmod 700 "${runtime_root}"; then
    launch_once 1
    first_result=$?
    first_launch_ready="${launch_dbcode_started}"
    first_quit_complete="${launch_quit_complete}"
    first_dbcode="${launch_dbcode_started}"
    first_account="${launch_account_restored}"
    first_keychain="${launch_keychain_clear}"
    first_update="${launch_update_clear}"

    if [[ "${first_result}" -eq 0 ]]; then
      launch_once 2
      second_result=$?
      relaunch_ready="${launch_dbcode_started}"
      final_quit_complete="${launch_quit_complete}"
      if [[ "${second_result}" -eq 0 && "${first_dbcode}" == "true" && \
        "${launch_dbcode_started}" == "true" ]]; then
        dbcode_started="true"
      fi
      if [[ "${first_account}" == "true" && "${launch_account_restored}" == "true" ]]; then
        account_restored="true"
      fi
      if [[ "${first_keychain}" == "true" && "${launch_keychain_clear}" == "true" ]]; then
        keychain_error_absent="true"
      fi
      if [[ "${first_update}" == "true" && "${launch_update_clear}" == "true" ]]; then
        surprise_update_absent="true"
      fi
    else
      record_failure "first-installed-launch-or-quit"
    fi
  else
    record_failure "restart-health-evidence-directory"
  fi
fi

[[ "${first_launch_ready}" == "true" ]] || record_failure "first-launch-readiness"
[[ "${first_quit_complete}" == "true" ]] || record_failure "first-complete-quit"
[[ "${relaunch_ready}" == "true" ]] || record_failure "relaunch-readiness"
[[ "${final_quit_complete}" == "true" ]] || record_failure "final-complete-quit"
[[ "${dbcode_started}" == "true" ]] || record_failure "dbcode-started-twice"
[[ "${account_restored}" == "true" ]] || record_failure "account-restored-twice"
[[ "${keychain_error_absent}" == "true" ]] || record_failure "keychain-cleanliness-not-proven"
[[ "${surprise_update_absent}" == "true" ]] || record_failure "surprise-update-absence-not-proven"

if [[ -n "${actual_app_sha}" && -d "${target_app}" ]] && \
  [[ "$(artifact_digest "${target_app}")" != "${actual_app_sha}" ]]; then
  record_failure "installed-app-changed-during-health-check"
fi
if [[ -n "${actual_extensions_sha}" && -d "${target_extensions}" ]] && \
  [[ "$(directory_content_digest "${target_extensions}")" != "${actual_extensions_sha}" ]]; then
  record_failure "installed-extensions-changed-during-health-check"
fi

status="failed"
if [[ "${first_launch_ready}" == "true" && \
  "${first_quit_complete}" == "true" && \
  "${relaunch_ready}" == "true" && \
  "${final_quit_complete}" == "true" && \
  "${dbcode_started}" == "true" && \
  "${account_restored}" == "true" && \
  "${keychain_error_absent}" == "true" && \
  "${surprise_update_absent}" == "true" && \
  ! -s "${failure_file}" ]]; then
  status="passed"
fi

receipt_temp="$(mktemp "${output_parent}/restart-health-receipt.XXXXXX")"
jq -n \
  --arg checked_at_utc "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --arg release_set_id "${release_set_id}" \
  --arg app_sha256 "${expected_app_sha}" \
  --arg build_manifest_sha256 "${expected_manifest_sha}" \
  --arg extensions_sha256 "${expected_extensions_sha}" \
  --arg status "${status}" \
  --argjson first_launch_ready "${first_launch_ready}" \
  --argjson first_quit_complete "${first_quit_complete}" \
  --argjson relaunch_ready "${relaunch_ready}" \
  --argjson final_quit_complete "${final_quit_complete}" \
  --argjson dbcode_started "${dbcode_started}" \
  --argjson account_restored "${account_restored}" \
  --argjson keychain_error_absent "${keychain_error_absent}" \
  --argjson surprise_update_absent "${surprise_update_absent}" \
  --arg evidence_path "${runtime_root}" \
  --arg failures "$(cat "${failure_file}")" '
    {
      schema_version: 1,
      checked_at_utc: $checked_at_utc,
      release_set_id: $release_set_id,
      app_sha256: $app_sha256,
      build_manifest_sha256: $build_manifest_sha256,
      extensions_sha256: $extensions_sha256,
      first_launch_ready: $first_launch_ready,
      first_quit_complete: $first_quit_complete,
      relaunch_ready: $relaunch_ready,
      final_quit_complete: $final_quit_complete,
      dbcode_started: $dbcode_started,
      account_restored: $account_restored,
      keychain_error_absent: $keychain_error_absent,
      surprise_update_absent: $surprise_update_absent,
      evidence_path: $evidence_path,
      failures: ($failures | split("\n") | map(select(length > 0))),
      status: $status
    }
  ' > "${receipt_temp}"
chmod 600 "${receipt_temp}"
mv "${receipt_temp}" "${output_file}"

if [[ "${status}" != "passed" ]]; then
  echo "Installed release health checks failed: ${output_file}" >&2
  exit 1
fi
echo "Installed release health checks passed: ${output_file}"
