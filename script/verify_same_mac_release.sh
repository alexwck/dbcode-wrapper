#!/usr/bin/env bash

set -euo pipefail
umask 077

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_root}/lib/host_config.sh"
source "${script_root}/lib/artifact_digest.sh"
source "${script_root}/lib/local_signing_identity.sh"
source "${script_root}/lib/generated_workspace.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  ./script/verify_same_mac_release.sh \
    --app APP --manifest FILE --release-lock FILE --profile-root DIR \
    --proof FILE --continuity FILE --matrix FILE --health FILE \
    --rollback FILE --rendered-report FILE --development-log FILE \
    --smoke-log FILE --output FILE
EOF
  exit 2
}

app=""
manifest=""
release_lock=""
profile_root=""
proof=""
continuity=""
matrix=""
health=""
rollback=""
rendered_report=""
development_log=""
smoke_log=""
output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) [[ $# -ge 2 ]] || usage; app="$2"; shift ;;
    --manifest) [[ $# -ge 2 ]] || usage; manifest="$2"; shift ;;
    --release-lock) [[ $# -ge 2 ]] || usage; release_lock="$2"; shift ;;
    --profile-root) [[ $# -ge 2 ]] || usage; profile_root="$2"; shift ;;
    --proof) [[ $# -ge 2 ]] || usage; proof="$2"; shift ;;
    --continuity) [[ $# -ge 2 ]] || usage; continuity="$2"; shift ;;
    --matrix) [[ $# -ge 2 ]] || usage; matrix="$2"; shift ;;
    --health) [[ $# -ge 2 ]] || usage; health="$2"; shift ;;
    --rollback) [[ $# -ge 2 ]] || usage; rollback="$2"; shift ;;
    --rendered-report) [[ $# -ge 2 ]] || usage; rendered_report="$2"; shift ;;
    --development-log) [[ $# -ge 2 ]] || usage; development_log="$2"; shift ;;
    --smoke-log) [[ $# -ge 2 ]] || usage; smoke_log="$2"; shift ;;
    --output) [[ $# -ge 2 ]] || usage; output_file="$2"; shift ;;
    *) usage ;;
  esac
  shift
done

[[ -n "${app}" && -n "${manifest}" && -n "${release_lock}" && -n "${profile_root}" ]] || usage
[[ -n "${proof}" && -n "${continuity}" && -n "${matrix}" && -n "${health}" ]] || usage
[[ -n "${rollback}" && -n "${rendered_report}" && -n "${development_log}" ]] || usage
[[ -n "${smoke_log}" && -n "${output_file}" ]] || usage
output_file="$(
  generated_workspace_resolve_path \
    "acceptance-evidence" \
    "${output_file}" \
    allow-temporary
)"

require_plain_file() {
  local path_value="$1"
  local label="$2"
  [[ -f "${path_value}" && ! -L "${path_value}" ]] || {
    echo "${label} is missing or symlinked: ${path_value}" >&2
    exit 1
  }
}

require_owner_only_directory() {
  local path_value="$1"
  local label="$2"
  [[ -d "${path_value}" && ! -L "${path_value}" ]] || {
    echo "${label} is missing or symlinked: ${path_value}" >&2
    exit 1
  }
  [[ "$(stat -f '%u' "${path_value}")" == "$(id -u)" && \
    "$(stat -f '%Lp' "${path_value}")" == "700" ]] || {
    echo "${label} must be owned by the current user with mode 700: ${path_value}" >&2
    exit 1
  }
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

for required_tool in codesign du file jq lipo pgrep plutil rg shasum stat; do
  require_command "${required_tool}"
done

[[ -d "${app}" && ! -L "${app}" ]] || {
  echo "The release application is missing or symlinked: ${app}" >&2
  exit 1
}
for evidence_file in \
  "${manifest}" \
  "${release_lock}" \
  "${proof}" \
  "${continuity}" \
  "${matrix}" \
  "${health}" \
  "${rollback}" \
  "${rendered_report}" \
  "${development_log}" \
  "${smoke_log}"; do
  require_plain_file "${evidence_file}" "Acceptance evidence"
done
[[ ! -L "${output_file}" ]] || {
  echo "Refusing a symlinked acceptance report." >&2
  exit 1
}
if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
  echo "Quit ${APP_NAME} completely before final acceptance." >&2
  exit 1
fi

app_sha256="$(artifact_digest "${app}")"
release_set_id="$(jq -er '.release.release_set_id' "${manifest}")"
manifest_sha256="$(sha256_file "${manifest}")"
release_lock_sha256="$(sha256_file "${release_lock}")"
continuity_sha256="$(sha256_file "${continuity}")"
proof_sha256="$(sha256_file "${proof}")"
matrix_sha256="$(sha256_file "${matrix}")"
health_sha256="$(sha256_file "${health}")"
rollback_sha256="$(sha256_file "${rollback}")"
rendered_report_sha256="$(sha256_file "${rendered_report}")"
development_log_sha256="$(sha256_file "${development_log}")"
smoke_log_sha256="$(sha256_file "${smoke_log}")"

bundle_identifier="$(plutil -extract CFBundleIdentifier raw "${app}/Contents/Info.plist")"
bundle_name="$(plutil -extract CFBundleName raw "${app}/Contents/Info.plist")"
bundle_executable="$(plutil -extract CFBundleExecutable raw "${app}/Contents/Info.plist")"
main_executable="${app}/Contents/MacOS/${bundle_executable}"
[[ "$(basename "${app}")" == "${APP_NAME}.app" && "${bundle_name}" == "${APP_NAME}" ]] || {
  echo "The application does not have the approved DBCode Wrapper name." >&2
  exit 1
}
[[ "${bundle_identifier}" == "${BUNDLE_IDENTIFIER}" ]] || {
  echo "The application does not have the approved bundle identifier." >&2
  exit 1
}
[[ -x "${main_executable}" ]] || {
  echo "The application has no executable main process." >&2
  exit 1
}
[[ "$(lipo -archs "${main_executable}")" == "arm64" ]] || {
  echo "The same-Mac release must be Apple-silicon only." >&2
  exit 1
}

load_local_signing_identity
verify_local_signed_code "${app}" "${BUNDLE_IDENTIFIER}"
signature_requirement="$(codesign -d -r- "${app}" 2>&1 | sed -n '/^designated => /p')"
expected_requirement="$(local_signing_expected_requirement "${BUNDLE_IDENTIFIER}")"
[[ "${signature_requirement}" == "${expected_requirement}" ]] || {
  echo "The release does not use the persistent local signing requirement." >&2
  exit 1
}

jq -e \
  --arg app_sha256 "${app_sha256}" \
  --arg bundle_identifier "${BUNDLE_IDENTIFIER}" \
  --arg certificate_sha1 "${LOCAL_SIGNING_CERTIFICATE_SHA1}" \
  --arg certificate_sha256 "${LOCAL_SIGNING_CERTIFICATE_SHA256}" \
  --arg continuity_sha256 "${continuity_sha256}" \
  --arg release_lock_sha256 "${release_lock_sha256}" \
  --arg requirement "${signature_requirement}" '
    .schema_version >= 5
    and .release.compatibility_status == "candidate"
    and .source.release_lock_sha256 == $release_lock_sha256
    and .artifact.app_name == "DBCode Wrapper"
    and .artifact.bundle_identifier == $bundle_identifier
    and .artifact.architecture == "arm64"
    and .artifact.sha256 == $app_sha256
    and .artifact.signature_kind == "certificate"
    and .artifact.signature_scope == "current-user-private-use"
    and .artifact.signature_requirement == $requirement
    and .artifact.signing_certificate_sha1 == $certificate_sha1
    and .artifact.signing_certificate_sha256 == $certificate_sha256
    and .artifact.cryptographic_update_identity_stable == true
    and .artifact.signing_continuity_evidence == "verified-distinct-rebuilt-artifacts"
    and .artifact.signing_continuity_receipt_sha256 == $continuity_sha256
    and .artifact.safe_storage_access_stable_across_rebuilds == false
    and .artifact.safe_storage_rebuild_behavior == "manual-approval-may-repeat-after-host-rebuild"
    and .artifact.focused_shell.enabled == true
    and .artifact.focused_shell.automatic_result_layout == {wide: "beside", narrow: "below"}
    and .artifact.document_extensions == ["sql"]
  ' "${manifest}" >/dev/null || {
  echo "The build manifest does not describe the exact private signed release." >&2
  exit 1
}

jq -e \
  --arg app_sha256 "${app_sha256}" \
  --arg release_set_id "${release_set_id}" \
  --arg certificate_sha1 "${LOCAL_SIGNING_CERTIFICATE_SHA1}" \
  --arg certificate_sha256 "${LOCAL_SIGNING_CERTIFICATE_SHA256}" \
  --arg requirement "${signature_requirement}" '
    .schema_version == 1
    and .scope == "current-user-private-use"
    and .current.artifact_sha256 == $app_sha256
    and .current.release_set_id == $release_set_id
    and .signing_certificate == {sha1: $certificate_sha1, sha256: $certificate_sha256}
    and .designated_requirement == $requirement
    and .previous.artifact_sha256 != .current.artifact_sha256
    and .cryptographic_identity_stable == true
    and .safe_storage_access_stable_across_rebuilds == false
    and .safe_storage_rebuild_behavior == "manual-approval-may-repeat-after-host-rebuild"
    and .safe_storage_prompt_observation == "accepted-new-approval-after-distinct-rebuild"
    and (.safe_storage_prompt_note | type == "string" and length > 0)
    and .distribution_claims == {
      developer_id: false,
      notarized: false,
      public_distribution_ready: false
    }
  ' "${continuity}" >/dev/null || {
  echo "The rebuilt-app signing and Safe Storage continuity proof is incomplete." >&2
  exit 1
}

dbcode_id="$(jq -er '.extension.dbcode.id' "${release_lock}")"
dbcode_version="$(jq -er '.extension.dbcode.version' "${release_lock}")"
dbcode_sha256="$(jq -er '.extension.dbcode.sha256' "${release_lock}")"
expected_extensions="$(jq -r '
  ([.extension.dbcode] + (.extension.python_notebooks.packages // []))[]
  | .id + "@" + .version
' "${release_lock}" | LC_ALL=C sort)"

jq -e \
  --arg app_sha256 "${app_sha256}" \
  --arg release_set_id "${release_set_id}" \
  --arg manifest_sha256 "${manifest_sha256}" \
  --arg requirement "${signature_requirement}" \
  --arg dbcode_id "${dbcode_id}" \
  --arg dbcode_version "${dbcode_version}" \
  --arg dbcode_sha256 "${dbcode_sha256}" \
  --arg expected_extensions "${expected_extensions}" '
    .schema_version >= 5
    and .status == "passed"
    and .approved_release_set.host.app_sha256 == $app_sha256
    and .approved_release_set.host.release_set_id == $release_set_id
    and .approved_release_set.host.candidate_manifest_sha256 == $manifest_sha256
    and .approved_release_set.host.signature_requirement == $requirement
    and .approved_release_set.host.focused_shell.enabled == true
    and .approved_release_set.dbcode.id == $dbcode_id
    and .approved_release_set.dbcode.version == $dbcode_version
    and .approved_release_set.dbcode.vsix_sha256 == $dbcode_sha256
    and .approved_release_set.dbcode.installed_extensions == $expected_extensions
    and ([.manual_checks.activation, .manual_checks.credential_reentry,
          .manual_checks.update_discovery, .manual_checks.postgresql,
          .manual_checks.debugger,
          .manual_checks.duckdb, .manual_checks.parquet,
          .manual_checks.persistence] | all(.status == "passed"))
    and (.launches | length) >= 2
    and (.complete_quits | length) >= 2
    and .active_launch.kind == "relaunch"
    and .last_complete_quit.after_launch_id == .active_launch.id
    and .active_launch.normal_profile_before == .active_launch.normal_profile_after
    and .fixtures.postgresql.server_enforced_read_only == true
    and .fixtures.postgresql.verified_result == {
      transaction_read_only: "on", row_count: 3, amount_sum: "75.00"
    }
    and .fixtures.duckdb.verified_result.row_count == 3
    and .fixtures.duckdb.verified_result.amount_sum == "61.50"
    and .fixtures.parquet.verified_result.row_count == 3
    and .fixtures.parquet.verified_result.amount_sum == "61.50"
  ' "${proof}" >/dev/null || {
  echo "The real-profile DBCode, database, or persistence proof is stale or incomplete." >&2
  exit 1
}

jq -e \
  --arg release_set_id "${release_set_id}" \
  --arg app_sha256 "${app_sha256}" \
  --arg dbcode_version "${dbcode_version}" '
    .schema_version == 1
    and .status == "passed"
    and .promotion_ready == true
    and .candidate_release_set_id == $release_set_id
    and ([.combinations[].combination] | sort) == ["H0/D0", "H0/D1", "H1/D0", "H1/D1"]
    and ([.combinations[]] | all(
      .status == "passed"
      and .checks.static == "passed"
      and .checks.runtime == "passed"
      and .checks.bundle_unchanged == true
      and .checks.surprise_update_absent == true
    ))
    and ([.combinations[] | select(.combination == "H1/D1")][0] | (
      .host.app_sha256 == $app_sha256
      and .dbcode.version == $dbcode_version
      and .details.runtime.normal_pro_activation == true
      and .details.runtime.postgresql == true
      and .details.runtime.debugger == true
      and .details.runtime.duckdb == true
      and .details.runtime.parquet == true
      and (.details.runtime.hyphen_path_preflight == "passed"
           or .details.runtime.hyphen_path_preflight == "not-required")
      and .details.runtime.full_quit_and_relaunch == true
      and .details.runtime.normal_profiles_unchanged == true
    ))
  ' "${matrix}" >/dev/null || {
  echo "The four-way compatibility matrix is stale or incomplete." >&2
  exit 1
}

jq -e \
  --arg release_set_id "${release_set_id}" \
  --arg app_sha256 "${app_sha256}" \
  --arg manifest_sha256 "${manifest_sha256}" '
    .schema_version == 1
    and .status == "passed"
    and .release_set_id == $release_set_id
    and .app_sha256 == $app_sha256
    and .build_manifest_sha256 == $manifest_sha256
    and .first_launch_ready == true
    and .first_quit_complete == true
    and .relaunch_ready == true
    and .final_quit_complete == true
    and .dbcode_started == true
    and .account_restored == true
    and .keychain_error_absent == true
    and .surprise_update_absent == true
    and .failures == []
  ' "${health}" >/dev/null || {
  echo "The promoted candidate restart-health proof is stale or incomplete." >&2
  exit 1
}

jq -e --arg release_set_id "${release_set_id}" '
  .schema_version == 1
  and .status == "rolled-back"
  and .active_release_set_id == $release_set_id
  and .restore_release_set_id != $release_set_id
  and (.rolled_back_at | type == "string" and length > 0)
' "${rollback}" >/dev/null || {
  echo "The complete-set rollback rehearsal is stale or incomplete." >&2
  exit 1
}

jq -e --slurpfile feature_policy "${REPO_ROOT}/host/dbcode-feature-policy.json" '
  .status == "passed"
  and .errors == []
  and (.checks | length) >= 35
  and any(.checks[].name; contains("first launch visibly creates a fresh Standalone DBCode Profile"))
  and any(.checks[].name; contains("migration data is owner-only"))
  and any(.checks[].name; contains("hyphen-path DuckDB preflight"))
  and any(.checks[].name; contains("production shell exposes only DBCode-focused chrome"))
  and any(.checks[].name; contains("real query grid"))
  and any(.checks[].name; contains("real DBCode notebook and executes Python"))
  and any(.checks[].name; contains("required runtime extensions activate"))
  and any(.checks[];
    .name == "unchanged DBCode exposes the complete reviewed New Connection catalogue"
    and .catalogue == $feature_policy[0].connection_capability_contract.catalogue_snapshot
    and .wrapperDatabaseAllowlist == false
    and .rawLabelsStored == false
  )
  and any(.checks[].name; contains("no unexpected renderer page or console errors"))
' "${rendered_report}" >/dev/null || {
  echo "The rendered focused-shell acceptance report is incomplete." >&2
  exit 1
}

rg -Fxq 'Development source checks passed without rebuilding the app.' "${development_log}" || {
  echo "The development gate log is incomplete." >&2
  exit 1
}
rg -Fxq 'Static host checks passed: identity, darwin-arm64, SQL document association, signature, and manifest.' "${smoke_log}" || {
  echo "The smoke log is missing the static host result." >&2
  exit 1
}
rg -Fxq 'Independent launch passed with a stable renderer, isolated directories, and no normal-profile changes.' "${smoke_log}" || {
  echo "The smoke log is missing the independent launch result." >&2
  exit 1
}

extensions_root="${profile_root}/extensions"
proof_profile_root="$(jq -er '.isolation.profile_root.path' "${proof}")"
user_data_root="$(jq -er '.isolation.user_data_root' "${proof}")"
shared_data_root="$(jq -er '.isolation.shared_data_root' "${proof}")"
cache_root="$(jq -er '.isolation.cache_root.path' "${proof}")"
logs_root="$(jq -er '.isolation.logs_root.path' "${proof}")"
[[ "${proof_profile_root}" == "${profile_root}" ]] || {
  echo "The proof belongs to a different private profile root." >&2
  exit 1
}
require_owner_only_directory "${profile_root}" "Private profile root"
require_owner_only_directory "${extensions_root}" "Executable extension root"
require_owner_only_directory "${user_data_root}" "Profile user-data root"
require_owner_only_directory "${shared_data_root}" "Shared-data root"
require_owner_only_directory "${cache_root}" "Profile cache root"
require_owner_only_directory "${logs_root}" "Profile log root"

actual_extensions="$({
  while IFS= read -r extension_manifest; do
    jq -r '.publisher + "." + .name + "@" + .version' "${extension_manifest}"
  done < <(find "${extensions_root}" -mindepth 2 -maxdepth 2 -name package.json -type f -print)
} | LC_ALL=C sort)"
[[ "${actual_extensions}" == "${expected_extensions}" ]] || {
  echo "The executable extension root does not match the exact release lock." >&2
  exit 1
}

app_size_kib="$(du -sk "${app}" | awk '{print $1}')"
rendered_check_count="$(jq -er '.checks | length' "${rendered_report}")"
rendered_warning_count="$(jq -er '.warnings | length' "${rendered_report}")"
manual_checks="$(jq -c '.manual_checks' "${proof}")"

mkdir -p "$(dirname "${output_file}")"
report_temp="${output_file}.tmp"
jq -n \
  --arg completed_at_utc "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --arg release_set_id "${release_set_id}" \
  --arg app_name "${APP_NAME}" \
  --arg bundle_identifier "${BUNDLE_IDENTIFIER}" \
  --arg app_sha256 "${app_sha256}" \
  --argjson app_size_kib "${app_size_kib}" \
  --arg signature_requirement "${signature_requirement}" \
  --arg certificate_common_name "${SIGNING_IDENTITY_COMMON_NAME}" \
  --arg certificate_sha1 "${LOCAL_SIGNING_CERTIFICATE_SHA1}" \
  --arg certificate_sha256 "${LOCAL_SIGNING_CERTIFICATE_SHA256}" \
  --arg code_oss_version "$(jq -er '.runtime.code_oss_version' "${release_lock}")" \
  --arg dbcode_id "${dbcode_id}" \
  --arg dbcode_version "${dbcode_version}" \
  --arg dbcode_sha256 "${dbcode_sha256}" \
  --arg installed_extensions "${actual_extensions}" \
  --arg manifest_sha256 "${manifest_sha256}" \
  --arg release_lock_sha256 "${release_lock_sha256}" \
  --arg continuity_sha256 "${continuity_sha256}" \
  --arg proof_sha256 "${proof_sha256}" \
  --arg matrix_sha256 "${matrix_sha256}" \
  --arg health_sha256 "${health_sha256}" \
  --arg rollback_sha256 "${rollback_sha256}" \
  --arg rendered_report_sha256 "${rendered_report_sha256}" \
  --arg development_log_sha256 "${development_log_sha256}" \
  --arg smoke_log_sha256 "${smoke_log_sha256}" \
  --argjson rendered_check_count "${rendered_check_count}" \
  --argjson rendered_warning_count "${rendered_warning_count}" \
  --argjson manual_checks "${manual_checks}" '
    {
      schema_version: 2,
      status: "passed",
      completed_at_utc: $completed_at_utc,
      scope: "current-user-private-use",
      release: {
        release_set_id: $release_set_id,
        app_name: $app_name,
        bundle_identifier: $bundle_identifier,
        platform: "darwin",
        architecture: "arm64",
        app_sha256: $app_sha256,
        installed_size_kib: $app_size_kib,
        code_oss_version: $code_oss_version,
        dbcode: {id: $dbcode_id, version: $dbcode_version, vsix_sha256: $dbcode_sha256},
        installed_extensions: ($installed_extensions | split("\n"))
      },
      signing: {
        kind: "certificate",
        scope: "current-user-private-use",
        designated_requirement: $signature_requirement,
        certificate: {
          common_name: $certificate_common_name,
          sha1: $certificate_sha1,
          sha256: $certificate_sha256
        },
        cryptographic_identity_stable_across_rebuilds: true,
        safe_storage_access_stable_across_rebuilds: false,
        safe_storage_prompt_observation: "accepted-new-approval-after-distinct-rebuild",
        safe_storage_rebuild_behavior: "manual-approval-may-repeat-after-host-rebuild"
      },
      gates: {
        development_contracts: "passed",
        strict_signature_and_manifest: "passed",
        rebuilt_host_safe_storage_behavior: "accepted-limitation",
        independent_launch_and_profile_isolation: "passed",
        dbcode_focused_rendered_interface: "passed",
        exact_external_extension_inventory: "passed",
        lifetime_entitlement_and_persistence: "passed",
        protected_credential_reentry: "passed",
        read_only_update_discovery: "passed",
        postgresql_read_only: "passed",
        stored_routine_debugger: "passed",
        duckdb_and_parquet: "passed",
        first_run_migration_and_hyphen_path: "passed",
        four_way_update_compatibility: "passed",
        promotion_restart_health: "passed",
        complete_set_rollback: "passed",
        owner_only_profile_permissions: "passed",
        bundle_unchanged_after_use: "passed"
      },
      manual_evidence: $manual_checks,
      rendered_evidence: {
        check_count: $rendered_check_count,
        known_warning_count: $rendered_warning_count,
        unexpected_error_count: 0
      },
      evidence_sha256: {
        build_manifest: $manifest_sha256,
        release_lock: $release_lock_sha256,
        signing_continuity: $continuity_sha256,
        real_profile_proof: $proof_sha256,
        compatibility_matrix: $matrix_sha256,
        restart_health: $health_sha256,
        rollback: $rollback_sha256,
        rendered_report: $rendered_report_sha256,
        development_log: $development_log_sha256,
        smoke_log: $smoke_log_sha256
      },
      failures: [],
      waivers: [],
      private_use_risks: [
        "The local certificate is trusted only for this current user and Mac.",
        "The app is not Developer ID signed or notarized and is not ready for public distribution.",
        "Each distinct downloaded host release may require Open Anyway and one new Safe Storage approval; unchanged-artifact relaunches must not repeat either approval.",
        "The release is Apple-silicon only; Intel and multi-user use are not supported.",
        "Every future Code OSS or DBCode update must pass the complete Approved Release Set matrix again.",
        "This private wrapper is not an official DBCode product or endorsement."
      ],
      distribution_claims: {
        developer_id: false,
        notarized: false,
        public_distribution_ready: false,
        intel_support: false,
        multi_user_support: false,
        official_dbcode_endorsement: false
      }
    }
  ' > "${report_temp}"
chmod 600 "${report_temp}"
mv "${report_temp}" "${output_file}"

echo "Same-Mac release acceptance passed: ${output_file}"
