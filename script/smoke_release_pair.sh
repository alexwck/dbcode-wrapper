#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/approved_release_set.sh"
source "${REPO_ROOT}/script/lib/profile_guard.sh"
source "${REPO_ROOT}/script/lib/proof_state.sh"
source "${REPO_ROOT}/script/lib/profile_paths.sh"
source "${REPO_ROOT}/script/lib/host_session.sh"

usage() {
  echo "Usage: ./script/smoke_release_pair.sh --host-set FILE --dbcode-set FILE --output FILE" >&2
  exit 2
}

host_set=""
dbcode_set=""
output_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host-set) [[ $# -ge 2 ]] || usage; host_set="$2"; shift ;;
    --dbcode-set) [[ $# -ge 2 ]] || usage; dbcode_set="$2"; shift ;;
    --output) [[ $# -ge 2 ]] || usage; output_file="$2"; shift ;;
    *) usage ;;
  esac
  shift
done
[[ -n "${host_set}" && -n "${dbcode_set}" && -n "${output_file}" ]] || usage
[[ ! -L "${output_file}" ]] || {
  echo "Refusing a symlinked runtime receipt: ${output_file}" >&2
  exit 1
}

clone_directory() {
  local source_path="$1"
  local destination_path="$2"
  if ! cp -cR "${source_path}" "${destination_path}" 2>/dev/null; then
    ditto "${source_path}" "${destination_path}"
  fi
}

inputs_ready="false"
host_app=""
host_manifest=""
source_user_data=""
source_extensions=""
source_shared_data=""
if approved_release_set_validate "${host_set}" >/dev/null && \
  approved_release_set_validate "${dbcode_set}" >/dev/null && \
  host_app="$(approved_release_set_member "${host_set}" app)" && \
  host_manifest="$(approved_release_set_member "${host_set}" build_manifest)" && \
  source_user_data="$(approved_release_set_member "${dbcode_set}" user_data)" && \
  source_extensions="$(approved_release_set_member "${dbcode_set}" extensions)" && \
  source_shared_data="$(approved_release_set_member "${dbcode_set}" shared_data)"; then
  inputs_ready="true"
fi

output_parent="$(cd "$(dirname "${output_file}")" && pwd -P)"
runtime_root="$(mktemp -d /private/tmp/dbcode-release-runtime.XXXXXX)"
runtime_backup_root="${runtime_root}-backups"
cleanup_runtime() {
  [[ -n "${runtime_root:-}" ]] || return 0
  case "${runtime_root}" in
    /private/tmp/dbcode-release-runtime.*)
      rm -rf "${runtime_root}"
      if [[ "${runtime_backup_root}" == /private/tmp/dbcode-release-runtime.*-backups ]]; then
        rm -rf "${runtime_backup_root}"
      fi
      ;;
    *) echo "Refusing to remove unexpected runtime-check path: ${runtime_root}" >&2; return 1 ;;
  esac
  runtime_root=""
}
trap cleanup_runtime EXIT INT TERM

failures_file="${runtime_root}/failures.txt"
: > "${failures_file}"
record_failure() {
  printf '%s\n' "$1" >> "${failures_file}"
}

focused_database_shell="false"
dbcode_started="false"
normal_pro_activation="false"
postgresql="false"
debugger="false"
duckdb="false"
parquet="false"
hyphen_path_preflight="not-run"
full_quit_and_relaunch="false"
normal_profiles_unchanged="false"
surprise_update_absent="false"

if [[ "${inputs_ready}" == "true" ]] && \
  jq -e '
    .artifact.focused_shell.enabled == true
    and .artifact.focused_shell.automatic_result_layout == {wide: "beside", narrow: "below"}
  ' "${host_manifest}" >/dev/null 2>&1 && \
  jq -e '.dbcodeWrapperFocusedShell == true' \
    "${host_app}/Contents/Resources/app/product.json" >/dev/null 2>&1; then
  focused_database_shell="true"
else
  record_failure "focused-database-shell"
fi

proof_file=""
if [[ "${inputs_ready}" == "true" ]] && jq -e '.paths.proof | type == "string"' "${dbcode_set}" >/dev/null 2>&1; then
  proof_file="$(approved_release_set_member "${dbcode_set}" proof || true)"
fi
dbcode_version="$(jq -r '.dbcode.version // empty' "${dbcode_set}" 2>/dev/null || true)"
proof_manual_check_schema=""
if [[ -n "${proof_file}" ]]; then
  proof_manual_check_schema="$(jq -r '.manual_check_schema_version // 1' "${proof_file}" 2>/dev/null || true)"
fi
if [[ -n "${proof_file}" ]] && \
  proof_state_is_runtime_usable "${proof_file}" "${dbcode_version}" && \
  jq -e \
    --arg host_release "$(jq -er '.release.release_set_id' "${host_set}")" \
    --arg dbcode_id "$(jq -er '.dbcode.id' "${dbcode_set}")" \
    --arg dbcode_version "${dbcode_version}" \
    --argjson manual_check_schema "${proof_manual_check_schema}" '
      .status == "passed"
      and .approved_release_set.host.release_set_id == $host_release
      and .approved_release_set.dbcode.id == $dbcode_id
      and .approved_release_set.dbcode.version == $dbcode_version
      and .manual_checks.activation.status == "passed"
      and .manual_checks.postgresql.status == "passed"
      and (
        if $manual_check_schema == 2
        then .manual_checks.debugger.status == "passed"
        else (.manual_checks | has("debugger") | not)
        end
      )
      and .manual_checks.duckdb.status == "passed"
      and .manual_checks.parquet.status == "passed"
      and .manual_checks.persistence.status == "passed"
      and .fixtures.postgresql.server_enforced_read_only == true
      and .fixtures.postgresql.verified_result == {
        transaction_read_only: "on", row_count: 3, amount_sum: "75.00"
      }
      and .fixtures.duckdb.verified_result == {
        amount_sum: "61.50", first_id: 1, last_id: 3, row_count: 3
      }
      and .fixtures.parquet.verified_result == {
        amount_sum: "61.50", first_id: 1, last_id: 3, row_count: 3
      }
    ' "${proof_file}" >/dev/null 2>&1; then
  normal_pro_activation="true"
  postgresql="true"
  if [[ "${proof_manual_check_schema}" == "2" ]]; then
    debugger="true"
  fi
  duckdb="true"
  parquet="true"
fi

if jq -e \
  --arg dbcode_version "${dbcode_version}" \
  --arg host_version "$(jq -r '.host.code_oss_version // empty' "${host_set}" 2>/dev/null || true)" '
    .approval_status == "approved"
    and .extension.version == $dbcode_version
    and .host.code_oss.version == $host_version
    and any(.feature_groups[];
      .id == "profile-setup-and-connection-import"
      and .status == "supported"
      and (.evidence | contains("hyphen-path DuckDB"))
    )
  ' "${REPO_ROOT}/host/dbcode-feature-policy.json" >/dev/null 2>&1; then
  hyphen_path_preflight="passed"
else
  hyphen_path_preflight="not-required"
fi

normal_profile_before="$(normal_profile_fingerprint)"
launch_checks_passed="false"
if [[ "${inputs_ready}" == "true" ]] && ! pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
  resolve_isolated_profile_paths "${runtime_root}"
  profile_layout_assert_mutable state user_data extensions shared_data backup cache logs
  run_user_data="${PROFILE_USER_DATA_ROOT}"
  run_extensions="${PROFILE_EXTENSIONS_ROOT}"
  run_shared_data="${PROFILE_SHARED_DATA_ROOT}"
  run_cache="${PROFILE_CACHE_ROOT}"
  run_logs="${PROFILE_LOG_ROOT}"
  mkdir -p "${run_user_data}" "${run_cache}" "${run_logs}"
  if [[ -d "${source_user_data}/User" ]]; then
    clone_directory "${source_user_data}/User" "${run_user_data}/User"
  fi
  clone_directory "${source_extensions}" "${run_extensions}"
  clone_directory "${source_shared_data}" "${run_shared_data}"
  chmod -R go-rwx "${runtime_root}"

  info_plist="${host_app}/Contents/Info.plist"
  executable_name="$(plutil -extract CFBundleExecutable raw "${info_plist}" 2>/dev/null || true)"
  app_executable="${host_app}/Contents/MacOS/${executable_name}"
  query_file="${REPO_ROOT}/host/qa/project-query.sql"
  launch_timeout="${DBCODE_WRAPPER_RELEASE_LAUNCH_TIMEOUT_SECONDS:-90}"
  if [[ ! "${launch_timeout}" =~ ^[0-9]+$ || "${launch_timeout}" -lt 1 || "${launch_timeout}" -gt 600 ]]; then
    launch_timeout=90
  fi

  launch_once() {
    local launch_number="$1"
    local host_log="${runtime_root}/host-${launch_number}.log"
    local session_policy="${runtime_root}/host-session-${launch_number}-policy.json"
    local session_result="${runtime_root}/host-session-${launch_number}-result.json"
    [[ -x "${app_executable}" && ! -L "${app_executable}" ]] || return 1
    local launch_arguments launch_environment relaunch_args
    launch_arguments="$(jq -cn --args '$ARGS.positional' -- \
      --user-data-dir "${run_user_data}" \
      --extensions-dir "${run_extensions}" \
      --shared-data-dir "${run_shared_data}" \
      --disk-cache-dir "${run_cache}" \
      --logsPath "${run_logs}" \
      --use-mock-keychain \
      --disable-telemetry \
      --disable-updates \
      --disable-workspace-trust \
      --new-window \
      --skip-release-notes \
      --skip-welcome \
      "${query_file}")"
    relaunch_args="${launch_arguments}"
    launch_environment="$(jq -cn \
      --arg shared_data_root "${run_shared_data}" \
      --arg extensions_root "${run_extensions}" \
      --arg backup_root "${PROFILE_BACKUP_ROOT}" \
      --arg app_bundle "${host_app}" \
      --arg profile_layout "${PROFILE_LAYOUT}" \
      --arg relaunch_args "${relaunch_args}" '{
        DBCODE_WRAPPER_QA_RECOVERY: "1",
        DBCODE_WRAPPER_SHARED_DATA_ROOT: $shared_data_root,
        DBCODE_WRAPPER_EXTENSIONS_ROOT: $extensions_root,
        DBCODE_WRAPPER_PROFILE_BACKUP_ROOT: $backup_root,
        DBCODE_WRAPPER_APP_BUNDLE: $app_bundle,
        DBCODE_WRAPPER_PROFILE_LAYOUT_JSON: $profile_layout,
        DBCODE_WRAPPER_RECOVERY_RELAUNCH_ARGS: $relaunch_args,
        ELECTRON_ENABLE_LOGGING: "1"
      }')"
    host_session_write_policy \
      "${session_policy}" \
      "release-pair-${launch_number}-$$" \
      "${app_executable}" \
      "${launch_arguments}" \
      "${launch_environment}" \
      "${host_log}" \
      "${run_logs}" \
      "${launch_timeout}" \
      1000 \
      1 \
      true \
      '[{"kind":"literal","value":"DBCode started"}]' \
      '[]' \
      quit-after-ready \
      false
    host_session_run "${session_policy}" "${session_result}" || return 1
    if rg -q 'update.*(install|download)|install.*update' "${host_log}" "${run_logs}" 2>/dev/null; then
      return 1
    fi
    return 0
  }

  if launch_once 1 && launch_once 2; then
    launch_checks_passed="true"
    dbcode_started="true"
    full_quit_and_relaunch="true"
  else
    record_failure "isolated-dbcode-launch-quit-relaunch"
  fi
else
  record_failure "app-not-fully-stopped-or-runtime-input-missing"
fi

normal_profile_after="$(normal_profile_fingerprint)"
if [[ "${normal_profile_before}" == "${normal_profile_after}" ]]; then
  normal_profiles_unchanged="true"
else
  record_failure "normal-editor-profile-changed"
fi

if [[ "${launch_checks_passed}" == "true" ]] && \
  { [[ "$(jq -r '.packaging.updater_enabled // false' "${host_manifest}" 2>/dev/null || true)" == "false" ]]; }; then
  surprise_update_absent="true"
else
  record_failure "surprise-update-behaviour"
fi

status="failed"
if [[ "${focused_database_shell}" == "true" && \
  "${dbcode_started}" == "true" && \
  "${full_quit_and_relaunch}" == "true" && \
  "${normal_profiles_unchanged}" == "true" && \
  "${surprise_update_absent}" == "true" ]]; then
  status="passed"
fi

evidence_path=""
if [[ "${status}" == "failed" && "${DBCODE_WRAPPER_PRESERVE_FAILED_RUNTIME:-}" == "yes" ]]; then
  output_basename="$(basename "${output_file}")"
  evidence_path="${output_parent}/${output_basename%.json}.evidence"
  if [[ -e "${evidence_path}" || -L "${evidence_path}" ]]; then
    record_failure "requested-failure-evidence-path-exists"
    evidence_path=""
  fi
fi

receipt_temp="${runtime_root}/runtime-receipt.json"
jq -n \
  --arg checked_at_utc "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --arg status "${status}" \
  --argjson focused_database_shell "${focused_database_shell}" \
  --argjson dbcode_started "${dbcode_started}" \
  --argjson normal_pro_activation "${normal_pro_activation}" \
  --argjson postgresql "${postgresql}" \
  --argjson debugger "${debugger}" \
  --argjson duckdb "${duckdb}" \
  --argjson parquet "${parquet}" \
  --arg hyphen_path_preflight "${hyphen_path_preflight}" \
  --argjson full_quit_and_relaunch "${full_quit_and_relaunch}" \
  --argjson normal_profiles_unchanged "${normal_profiles_unchanged}" \
  --argjson surprise_update_absent "${surprise_update_absent}" \
  --arg evidence_path "${evidence_path}" \
  --arg failures "$(cat "${failures_file}")" '
    {
      schema_version: 1,
      checked_at_utc: $checked_at_utc,
      status: $status,
      focused_database_shell: $focused_database_shell,
      dbcode_started: $dbcode_started,
      normal_pro_activation: $normal_pro_activation,
      postgresql: $postgresql,
      debugger: $debugger,
      duckdb: $duckdb,
      parquet: $parquet,
      hyphen_path_preflight: $hyphen_path_preflight,
      full_quit_and_relaunch: $full_quit_and_relaunch,
      normal_profiles_unchanged: $normal_profiles_unchanged,
      surprise_update_absent: $surprise_update_absent,
      evidence_path: $evidence_path,
      failures: ($failures | split("\n") | map(select(length > 0)))
    }
  ' > "${receipt_temp}"
cp "${receipt_temp}" "${output_file}"
chmod 600 "${output_file}"
if [[ -n "${evidence_path}" ]]; then
  mv "${runtime_root}" "${evidence_path}"
  runtime_root=""
fi

if [[ "${status}" != "passed" ]]; then
  echo "Runtime release-pair checks failed: ${output_file}" >&2
  exit 1
fi
echo "Runtime release-pair checks passed: ${output_file}"
