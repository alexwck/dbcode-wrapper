#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

jq -e '.id == "dbcode.dbcode"' <<<"${DBCODE_PACKAGE_SPEC}" >/dev/null || {
  echo "The Release Specification is missing the locked DBCode package." >&2
  exit 1
}

dbcode_id="${DBCODE_ID}"
dbcode_version="${DBCODE_VERSION}"

[[ "${dbcode_id}" == "dbcode.dbcode" ]] || {
  echo "The release lock must select the official DBCode extension." >&2
  exit 1
}
[[ "${dbcode_version}" == "1.36.2" ]] || {
  echo "The release lock must select the approved DBCode 1.36.2 package." >&2
  exit 1
}

jq -e '
  .namespace == "dbcode"
  and .name == "dbcode"
  and .publisher == "dbcode"
  and .engine == "^1.95.0"
  and .target_platform == "universal"
  and .verified_publisher == true
  and .pre_release == false
  and .deprecated == false
  and (.published_at | type == "string")
  and (.registry_api_url | startswith("https://open-vsx.org/api/"))
  and (.download_url | startswith("https://open-vsx.org/api/"))
  and (.signature_url | startswith("https://open-vsx.org/api/"))
  and (.sha256_url | startswith("https://open-vsx.org/api/"))
  and (.public_key_url | startswith("https://open-vsx.org/api/-/public-key/"))
  and (.sha256 | test("^[0-9a-f]{64}$"))
  and (.signature_archive_sha256 | test("^[0-9a-f]{64}$"))
  and (.public_key_sha256 | test("^[0-9a-f]{64}$"))
  and (.package_size > 0)
' <<<"${DBCODE_PACKAGE_SPEC}" >/dev/null

public_key_id="${DBCODE_PUBLIC_KEY_ID}"
public_key="${REPO_ROOT}/host/keys/openvsx-${public_key_id}.pem"
[[ -f "${public_key}" ]] || {
  echo "Missing pinned Open VSX public key: ${public_key}" >&2
  exit 1
}
expected_key_sha="${DBCODE_PUBLIC_KEY_SHA256}"
actual_key_sha="$(shasum -a 256 "${public_key}" | awk '{print $1}')"
[[ "${actual_key_sha}" == "${expected_key_sha}" ]] || {
  echo "The pinned Open VSX public key does not match the release lock." >&2
  exit 1
}

settings_file="${REPO_ROOT}/host/profile/settings.json"
jq -e '
  ."update.mode" == "none"
  and ."extensions.autoCheckUpdates" == false
  and ."extensions.autoUpdate" == false
  and ."extensions.ignoreRecommendations" == true
  and ."security.workspace.trust.enabled" == false
  and ."telemetry.telemetryLevel" == "off"
' "${settings_file}" >/dev/null

for required_script in prepare_dbcode.sh verify_openvsx_package.sh proof_dbcode.sh test_profile_paths.sh test_profile_settings.sh test_proof_state.sh test_runtime_extensions_contract.sh test_runtime_extensions_verifier.sh; do
  [[ -x "${REPO_ROOT}/script/${required_script}" ]] || {
    echo "Missing executable DBCode workflow script: script/${required_script}" >&2
    exit 1
  }
done

for profile_aware_script in prepare_dbcode.sh run_host.sh proof_dbcode.sh; do
  rg -Fq 'profile_paths.sh' "${REPO_ROOT}/script/${profile_aware_script}" || {
    echo "${profile_aware_script} must share the self-launch profile path contract." >&2
    exit 1
  }
done

rg -Fq 'prepare_dbcode.sh' "${REPO_ROOT}/script/run_host.sh" || {
  echo "Normal host launch must prepare the locked runtime-extension set first." >&2
  exit 1
}
rg -Fq -- '--disable-workspace-trust' "${REPO_ROOT}/script/run_host.sh" || {
  echo "The dedicated DBCode host must not leave its only extension disabled in Restricted Mode." >&2
  exit 1
}
rg -Fq 'Keychain lookup failed:' "${REPO_ROOT}/script/proof_dbcode.sh" || {
  echo "The DBCode proof must reject a failed macOS Keychain lookup." >&2
  exit 1
}
rg -Fq '.artifact.signature_requirement' "${REPO_ROOT}/script/proof_dbcode.sh" || {
  echo "The DBCode proof must bind its evidence to the host signing identity." >&2
  exit 1
}
rg -Fq 'artifact_digest "${APP_BUNDLE}"' "${REPO_ROOT}/script/proof_dbcode.sh" || {
  echo "The DBCode proof must hash the launched app instead of trusting the manifest alone." >&2
  exit 1
}
rg -Fq 'dbcodeWrapperFocusedShell' "${REPO_ROOT}/script/proof_dbcode.sh" || {
  echo "The DBCode proof must bind evidence to the focused-shell product state." >&2
  exit 1
}
rg -Fq 'proof_parent="$(generated_workspace_path "proof-evidence")"' \
  "${REPO_ROOT}/script/proof_dbcode.sh" || {
  echo "The current wrapper proof must use the registered proof-evidence root." >&2
  exit 1
}
rg -Fq 'proof_root="${proof_parent}/dbcode-wrapper"' "${REPO_ROOT}/script/proof_dbcode.sh" || {
  echo "The current wrapper proof must not reuse historical Ticket 02 evidence." >&2
  exit 1
}
rg -Fq 'DBCODE_WRAPPER_LAUNCH_TIMEOUT_SECONDS=300' "${REPO_ROOT}/script/proof_dbcode.sh" || {
  echo "The real-Keychain proof must leave enough time for the app window to become ready." >&2
  exit 1
}
rg -Fq -- '--manual-proof' "${REPO_ROOT}/script/proof_dbcode.sh" || {
  echo "The manual proof must not impose an activation deadline while the user is completing first-run setup." >&2
  exit 1
}
host_session_contract="${REPO_ROOT}/script/lib/host-session.js"
[[ -f "${host_session_contract}" ]] || {
  echo "Missing Host Session contract: script/lib/host-session.js" >&2
  exit 1
}
for session_caller in \
  "${REPO_ROOT}/script/run_host.sh" \
  "${REPO_ROOT}/script/smoke_host.sh" \
  "${REPO_ROOT}/script/smoke_release_pair.sh" \
  "${REPO_ROOT}/script/check_installed_release_health.sh"; do
  rg -Fq 'host_session_' "${session_caller}" || {
    echo "A launch path does not use the Host Session contract: ${session_caller}" >&2
    exit 1
  }
done
rg -Fq 'require_dbcode_before_exit="true"' "${REPO_ROOT}/script/run_host.sh" || {
  echo "The manual proof must require DBCode evidence before the user closes the app." >&2
  exit 1
}
rg -Fq 'failure_at' "${REPO_ROOT}/script/proof_dbcode.sh" || {
  echo "The proof must record failed launches instead of leaving ambiguous active evidence." >&2
  exit 1
}
fresh_evidence_guard_count="$(rg -Fc '[[ -f "${evidence_file}" ]] || return 0' "${REPO_ROOT}/script/proof_dbcode.sh")"
[[ "${fresh_evidence_guard_count}" -eq 2 ]] || {
  echo "Optional proof evidence helpers must succeed when no previous evidence exists." >&2
  exit 1
}
rg -Fq '[[ -n "${active_launch_id}" ]] || return 0' "${REPO_ROOT}/script/proof_dbcode.sh" || {
  echo "The proof must allow an evidence file that has no previous active launch." >&2
  exit 1
}
rg -Fq 'active-dbcode-log' "${REPO_ROOT}/script/run_host.sh" || {
  echo "The host launch must identify the DBCode log created by the active run." >&2
  exit 1
}
rg -Fq 'dbcode_activation_log' "${REPO_ROOT}/script/proof_dbcode.sh" || {
  echo "The DBCode proof must record the active DBCode log as runtime evidence." >&2
  exit 1
}
rg -Fq 'verify_duckdb_fixture.py' "${REPO_ROOT}/script/proof_dbcode.sh" || {
  echo "The DBCode proof must independently verify its persistent DuckDB and Parquet fixtures." >&2
  exit 1
}
rg -Fq 'proof_state_is_finalizable' "${REPO_ROOT}/script/proof_dbcode.sh" || {
  echo "The DBCode proof must reject stale or incomplete persistence sequences." >&2
  exit 1
}
rg -Fq 'prepare_duckdb no' "${REPO_ROOT}/script/proof_dbcode.sh" || {
  echo "The persistence relaunch must reject missing DuckDB or Parquet fixtures instead of recreating them." >&2
  exit 1
}

fingerprint_line="$(rg -n 'before_fingerprint=' "${REPO_ROOT}/script/proof_dbcode.sh" | cut -d: -f1)"
prepare_line="$(rg -n '^  prepare_all ' "${REPO_ROOT}/script/proof_dbcode.sh" | cut -d: -f1)"
[[ -n "${fingerprint_line}" && -n "${prepare_line}" && "${fingerprint_line}" -lt "${prepare_line}" ]] || {
  echo "The normal-profile fingerprint must be captured before proof preparation begins." >&2
  exit 1
}

echo "DBCode acquisition and profile contract checks passed."
