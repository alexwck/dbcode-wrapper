#!/usr/bin/env bash

set -euo pipefail
umask 077

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
launcher_repo_root="$(cd "${script_root}/.." && pwd -P)"

usage() {
  cat >&2 <<'EOF'
Usage:
  ./script/verify_fast_release.sh \
    --app APP \
    --manifest FILE \
    --release-lock FILE \
    --rendered-report FILE \
    --output FILE
EOF
  exit 2
}

app=""
manifest=""
release_lock=""
rendered_report=""
output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) [[ $# -ge 2 ]] || usage; app="$2"; shift ;;
    --manifest) [[ $# -ge 2 ]] || usage; manifest="$2"; shift ;;
    --release-lock) [[ $# -ge 2 ]] || usage; release_lock="$2"; shift ;;
    --rendered-report) [[ $# -ge 2 ]] || usage; rendered_report="$2"; shift ;;
    --output) [[ $# -ge 2 ]] || usage; output_file="$2"; shift ;;
    *) usage ;;
  esac
  shift
done

[[ -n "${app}" && -n "${manifest}" && -n "${release_lock}" ]] || usage
[[ -n "${rendered_report}" ]] || usage
[[ -n "${output_file}" ]] || usage

absolute_from_caller() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$(pwd -P)" "$1" ;;
  esac
}

if [[ "${DBCODE_WRAPPER_RELEASE_VERIFIER_MATERIALIZED:-no}" != "yes" ]]; then
  app="$(absolute_from_caller "${app}")"
  manifest="$(absolute_from_caller "${manifest}")"
  release_lock="$(absolute_from_caller "${release_lock}")"
  rendered_report="$(absolute_from_caller "${rendered_report}")"
  output_file="$(absolute_from_caller "${output_file}")"

  [[ -f "${manifest}" && ! -L "${manifest}" ]] || {
    echo "The build manifest is missing or symlinked: ${manifest}" >&2
    exit 1
  }
  command -v jq >/dev/null 2>&1 || {
    echo "Required command not found: jq" >&2
    exit 1
  }
  source "${script_root}/lib/release_source_snapshot.sh"

  verifier_source_temp="$(
    mktemp -d "${TMPDIR:-/tmp}/dbcode-release-verifier-source.XXXXXX"
  )"
  verifier_source_record="${verifier_source_temp}/snapshot.json"
  materialized_verifier_source="${verifier_source_temp}/source"
  cleanup_verifier_source() {
    rm -rf "${verifier_source_temp}"
  }
  trap cleanup_verifier_source EXIT INT TERM

  jq -S '.source.snapshot' "${manifest}" > "${verifier_source_record}"
  materialized_verifier_source="$(
    release_source_snapshot_materialize \
      "${launcher_repo_root}" \
      "${verifier_source_record}" \
      "${materialized_verifier_source}"
  )"

  DBCODE_WRAPPER_GENERATED_REPO_ROOT="${launcher_repo_root}" \
  DBCODE_WRAPPER_RELEASE_VERIFIER_MATERIALIZED="yes" \
  DBCODE_WRAPPER_RELEASE_VERIFIER_SOURCE_ROOT="${materialized_verifier_source}" \
    "${materialized_verifier_source}/script/verify_fast_release.sh" \
      --app "${app}" \
      --manifest "${manifest}" \
      --release-lock "${release_lock}" \
      --rendered-report "${rendered_report}" \
      --output "${output_file}"
  exit $?
fi

source "${script_root}/lib/host_config.sh"
source "${script_root}/lib/artifact_digest.sh"
source "${script_root}/lib/generated_workspace.sh"
source "${script_root}/lib/release_source_snapshot.sh"

[[ "${DBCODE_WRAPPER_RELEASE_VERIFIER_SOURCE_ROOT:-}" == "${REPO_ROOT}" ]] || {
  echo "Release verification is not running from its materialized source." >&2
  exit 1
}

output_file="$(
  generated_workspace_resolve_path \
    "acceptance-evidence" \
    "${output_file}" \
    allow-temporary
)"

for required_tool in codesign du file jq lipo plutil rg shasum stat; do
  require_command "${required_tool}"
done

[[ -d "${app}" && ! -L "${app}" ]] || {
  echo "The release application is missing or symlinked: ${app}" >&2
  exit 1
}
for evidence_file in \
  "${manifest}" \
  "${release_lock}" \
  "${rendered_report}"; do
  [[ -f "${evidence_file}" && ! -L "${evidence_file}" ]] || {
    echo "Automated release evidence is missing or symlinked: ${evidence_file}" >&2
    exit 1
  }
done
[[ ! -L "${output_file}" ]] || {
  echo "Refusing a symlinked acceptance report." >&2
  exit 1
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

app_sha256="$(artifact_digest "${app}")"
manifest_sha256="$(sha256_file "${manifest}")"
release_lock_sha256="$(sha256_file "${release_lock}")"
rendered_report_sha256="$(sha256_file "${rendered_report}")"
release_set_id="$(jq -er '.release.release_set_id' "${manifest}")"

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
[[ -x "${main_executable}" && "$(lipo -archs "${main_executable}")" == "arm64" ]] || {
  echo "The prompt-free Host Release must contain one Apple-silicon executable." >&2
  exit 1
}

codesign --verify --deep --strict "${app}"
signature_requirement="$(codesign -d -r- "${app}" 2>&1 | sed -n '/^designated => /p')"

jq -e \
  --arg app_sha256 "${app_sha256}" \
  --arg bundle_identifier "${BUNDLE_IDENTIFIER}" \
  --arg release_lock_sha256 "${release_lock_sha256}" \
  --arg wrapper_version "${WRAPPER_VERSION}" \
  --arg signature_requirement "${signature_requirement}" '
    .schema_version == 6
    and .release.wrapper_version == $wrapper_version
    and .artifact.sha256 == $app_sha256
    and .artifact.bundle_identifier == $bundle_identifier
    and .artifact.architecture == "arm64"
    and .artifact.signature_kind == "certificate"
    and .artifact.signature_scope == "current-user-private-use"
    and .artifact.signature_requirement == $signature_requirement
    and .artifact.focused_shell.enabled == true
    and .artifact.focused_shell.result_location == "below"
    and (.artifact.focused_shell | has("automatic_result_layout") | not)
    and .source.release_lock_sha256 == $release_lock_sha256
    and .source.repository_revision == .source.snapshot.repository_revision
    and .source.release_lock_sha256 == .source.snapshot.release_lock_sha256
    and .source.overlay_sha256 == .source.snapshot.host_script_sha256
    and .source.snapshot.schema_version == 1
    and .source.snapshot.mode == "immutable-git-commit"
    and (.source.snapshot.tree_oid | test("^[0-9a-f]{40}$"))
    and (.source.snapshot.snapshot_sha256 | test("^[0-9a-f]{64}$"))
    and .source.compiled_host.schema_version == 2
    and (.source.compiled_host.input_id | test("^compiled-host-[0-9a-f]{64}$"))
    and (.source.compiled_host.source_revision | test("^[0-9a-f]{40}$"))
    and .source.compiled_host.app_digest_algorithm == "sha256-files-modes-links-v1"
    and (.source.compiled_host.app_sha256 | test("^[0-9a-f]{64}$"))
    and .source.compiled_host.compilation_environment.schema_version == 1
    and (.source.compiled_host.cache_status | IN("hit", "miss-built"))
  ' "${manifest}" >/dev/null || {
  echo "The build manifest does not describe this exact signed app." >&2
  exit 1
}
manifest_source_snapshot="$(jq -c '.source.snapshot' "${manifest}")"
release_source_snapshot_verify_json "${REPO_ROOT}" "${manifest_source_snapshot}"
release_source_snapshot_assert_clean_checkout \
  "${REPO_ROOT}" \
  "$(jq -er '.repository_revision' <<<"${manifest_source_snapshot}")"

code_oss_version="$(jq -er '.runtime.code_oss' "${manifest}")"
vscodium_version="$(jq -er '.runtime.host' "${manifest}")"
dbcode_id="$(jq -er '.runtime_extensions[] | select(.id == "dbcode.dbcode") | .id' "${manifest}")"
dbcode_version="$(jq -er '.runtime_extensions[] | select(.id == "dbcode.dbcode") | .version' "${manifest}")"
dbcode_sha256="$(jq -er '.runtime_extensions[] | select(.id == "dbcode.dbcode") | .vsix_sha256' "${manifest}")"

jq -e \
  --arg code_oss_version "${code_oss_version}" \
  --arg vscodium_version "${vscodium_version}" \
  --arg dbcode_id "${dbcode_id}" \
  --arg dbcode_version "${dbcode_version}" \
  --arg dbcode_sha256 "${dbcode_sha256}" '
    .runtime.code_oss_version == $code_oss_version
    and .upstream.vscodium.tag == $vscodium_version
    and .extension.dbcode.id == $dbcode_id
    and .extension.dbcode.version == $dbcode_version
    and .extension.dbcode.sha256 == $dbcode_sha256
  ' "${release_lock}" >/dev/null || {
  echo "The build manifest and release lock do not identify the same runtime set." >&2
  exit 1
}

gate_temp="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-fast-release-gates.XXXXXX")"
development_log="${gate_temp}/development.log"
smoke_log="${gate_temp}/smoke.log"
cleanup_gate_temp() {
  rm -rf "${gate_temp}"
}
trap cleanup_gate_temp EXIT INT TERM

echo "Running development contracts from the exact release source..."
if ! "${script_root}/check_development.sh" >"${development_log}" 2>&1; then
  cat "${development_log}" >&2
  echo "The exact-source development gate failed." >&2
  exit 1
fi
echo "Running static smoke against the exact signed app..."
if ! "${script_root}/smoke_host.sh" \
  --app "${app}" \
  --manifest "${manifest}" >"${smoke_log}" 2>&1; then
  cat "${smoke_log}" >&2
  echo "The exact-app static smoke failed." >&2
  exit 1
fi

feature_policy="${REPO_ROOT}/host/dbcode-feature-policy.json"
jq -e \
  --arg release_set_id "${release_set_id}" \
  --slurpfile feature_policy "${feature_policy}" '
    .status == "passed"
    and .mode == "smoke"
    and .releaseSetId == $release_set_id
    and .profile.name == "qa"
    and .profile.persistent == true
    and .errors == []
    and any(.checks[];
      .name == "unchanged DBCode exposes the reviewed New Connection catalogue"
      and .catalogue == $feature_policy[0].connection_capability_contract.catalogue_snapshot
      and .wrapperDatabaseAllowlist == false
      and .rawLabelsStored == false
    )
    and any(.checks[];
      .name == "the DBCode notebook route remains reachable without starting a kernel"
      and .evidence == "reachable"
      and .kernelStarted == false
      and .permissionPromptExpected == false
    )
    and any(.checks[];
      .name == "DBCode AI provider, custom-model, and API-key routes remain reachable without sending data"
      and .evidence == "reachable"
      and .modelCallMade == false
      and .secretEntered == false
    )
    and any(.checks[];
      .name == "Open SQL File renders the deterministic query without executing it"
      and .databaseRead == false
      and .databaseWrite == false
    )
    and any(.checks[].name; . == "current runtime-extension logs contain no unexpected activation errors")
  ' "${rendered_report}" >/dev/null || {
  echo "The prompt-free rendered smoke is incomplete." >&2
  exit 1
}

rg -Fxq 'Development source checks passed without rebuilding the app.' "${development_log}" || {
  echo "The development gate log is incomplete." >&2
  exit 1
}
rg -Fxq \
  'Static host checks passed: identity, darwin-arm64, SQL document association, signature, and manifest.' \
  "${smoke_log}" || {
  echo "The smoke log is missing the static host result." >&2
  exit 1
}
development_log_sha256="$(sha256_file "${development_log}")"
smoke_log_sha256="$(sha256_file "${smoke_log}")"
expected_extensions="$(jq -r '.runtime_extensions[] | .id + "@" + .version' "${manifest}" | LC_ALL=C sort)"
rendered_check_count="$(jq -er '.checks | length' "${rendered_report}")"
rendered_warning_count="$(jq -er '.warnings | length' "${rendered_report}")"
app_size_kib="$(du -sk "${app}" | awk '{print $1}')"
certificate_sha1="$(jq -er '.artifact.signing_certificate_sha1' "${manifest}")"
certificate_sha256="$(jq -er '.artifact.signing_certificate_sha256' "${manifest}")"
source_revision="$(jq -er '.source.snapshot.repository_revision' "${manifest}")"
source_tree_oid="$(jq -er '.source.snapshot.tree_oid' "${manifest}")"
source_snapshot_sha256="$(jq -er '.source.snapshot.snapshot_sha256' "${manifest}")"
compiled_host_input_id="$(jq -er '.source.compiled_host.input_id' "${manifest}")"

mkdir -p "$(dirname "${output_file}")"
report_temp="${output_file}.tmp"
jq -n \
  --arg completed_at_utc "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --arg release_set_id "${release_set_id}" \
  --arg app_sha256 "${app_sha256}" \
  --argjson app_size_kib "${app_size_kib}" \
  --arg signature_requirement "${signature_requirement}" \
  --arg certificate_sha1 "${certificate_sha1}" \
  --arg certificate_sha256 "${certificate_sha256}" \
  --arg source_revision "${source_revision}" \
  --arg source_tree_oid "${source_tree_oid}" \
  --arg source_snapshot_sha256 "${source_snapshot_sha256}" \
  --arg compiled_host_input_id "${compiled_host_input_id}" \
  --arg code_oss_version "${code_oss_version}" \
  --arg dbcode_id "${dbcode_id}" \
  --arg dbcode_version "${dbcode_version}" \
  --arg dbcode_sha256 "${dbcode_sha256}" \
  --arg installed_extensions "${expected_extensions}" \
  --arg manifest_sha256 "${manifest_sha256}" \
  --arg release_lock_sha256 "${release_lock_sha256}" \
  --arg rendered_report_sha256 "${rendered_report_sha256}" \
  --arg development_log_sha256 "${development_log_sha256}" \
  --arg smoke_log_sha256 "${smoke_log_sha256}" \
  --argjson rendered_check_count "${rendered_check_count}" \
  --argjson rendered_warning_count "${rendered_warning_count}" '
    {
      schema_version: 3,
      status: "passed",
      completed_at_utc: $completed_at_utc,
      scope: "current-user-private-use",
      source: {
        repository_revision: $source_revision,
        tree_oid: $source_tree_oid,
        snapshot_sha256: $source_snapshot_sha256,
        compiled_host_input_id: $compiled_host_input_id
      },
      release: {
        release_set_id: $release_set_id,
        app_name: "DBCode Wrapper",
        bundle_identifier: "io.alexabelle.dbcodewrapper",
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
        certificate: {sha1: $certificate_sha1, sha256: $certificate_sha256}
      },
      automation: {
        profile_name: "qa",
        persistent_profile: true,
        person_controlled_actions: "not-invoked",
        kernel_started: false,
        sql_executed: false,
        model_called: false,
        secret_entered: false
      },
      gates: {
        development_contracts: "passed",
        strict_signature_and_manifest: "passed",
        signed_app_one_profile_launch: "passed",
        dbcode_focused_rendered_interface: "passed",
        exact_external_extension_inventory: "passed",
        prompt_free_automation: "passed",
        bundle_unchanged_after_use: "passed"
      },
      gate_execution: {
        source_snapshot_sha256: $source_snapshot_sha256,
        release_set_id: $release_set_id,
        app_sha256: $app_sha256,
        build_manifest_sha256: $manifest_sha256,
        development_runner: "script/check_development.sh",
        static_smoke_runner: "script/smoke_host.sh"
      },
      rendered_evidence: {
        check_count: $rendered_check_count,
        known_warning_count: $rendered_warning_count,
        unexpected_error_count: 0
      },
      evidence_sha256: {
        build_manifest: $manifest_sha256,
        release_lock: $release_lock_sha256,
        rendered_report: $rendered_report_sha256,
        development_log: $development_log_sha256,
        smoke_log: $smoke_log_sha256
      },
      failures: [],
      waivers: [],
      private_use_risks: [
        "The local certificate is trusted only for this current user and Mac.",
        "The app is not Developer ID signed or notarized and is not ready for public distribution.",
        "Normal app use may show macOS, DBCode licence, sign-in, or external-service prompts that automation does not approve.",
        "The release is Apple-silicon only; Intel and multi-user use are not supported.",
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

echo "Prompt-free release acceptance passed: ${output_file}"
