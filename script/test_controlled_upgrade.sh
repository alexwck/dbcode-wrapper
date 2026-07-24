#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/artifact_digest.sh"

upgrade_script="${REPO_ROOT}/script/controlled_upgrade.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-controlled-upgrade.XXXXXX")"
export DBCODE_WRAPPER_TEST_ALLOW_TEMPORARY_OUTPUT="yes"

cleanup_test_root() {
  rm -rf "${test_root}"
}
trap cleanup_test_root EXIT INT TERM

current_set="${test_root}/current-set.json"
candidate_set="${test_root}/candidate-set.json"
gate_script="${REPO_ROOT}/script/fixtures/test_controlled_upgrade_gate.sh"
gate_log="${test_root}/gate.log"
matrix_receipt="${test_root}/matrix-receipt.json"

jq -n '
  {
    schema_version: 1,
    role: "current",
    prepared_at_utc: "2026-07-23T00:00:00Z",
    release: {
      release_set_id: "current-release",
      source_set_id: "current-source"
    },
    source: {repository_revision: ("1" * 40)},
    target: {platform: "darwin", architecture: "arm64"},
    host: {
      app_sha256: ("a" * 64),
      build_manifest_sha256: ("2" * 64),
      code_oss_version: "1.126.0"
    },
    dbcode: {
      id: "dbcode.dbcode",
      version: "1.36.1",
      vsix_sha256: ("b" * 64),
      signature_archive_sha256: ("3" * 64)
    },
    profile: {
      schema_version: 1,
      user_data_sha256: ("4" * 64),
      source_extensions_sha256: ("5" * 64),
      extensions_sha256: ("5" * 64),
      shared_data_sha256: ("6" * 64),
      installed_extensions: ["dbcode.dbcode@1.36.1"],
      restored_signed_payloads: []
    },
    evidence: {},
    paths: {
      app: "DBCode Wrapper.app",
      build_manifest: "build-manifest.json",
      release_lock: "release-lock.json",
      user_data: "profile/user-data",
      extensions: "profile/extensions",
      shared_data: "profile/shared-data"
    }
  }
' > "${current_set}"

jq -n '
  {
    schema_version: 1,
    role: "candidate",
    prepared_at_utc: "2026-07-23T00:00:00Z",
    release: {
      release_set_id: "candidate-release",
      source_set_id: "candidate-source"
    },
    source: {repository_revision: ("7" * 40)},
    target: {platform: "darwin", architecture: "arm64"},
    host: {
      app_sha256: ("c" * 64),
      build_manifest_sha256: ("8" * 64),
      code_oss_version: "1.127.0"
    },
    dbcode: {
      id: "dbcode.dbcode",
      version: "1.37.0",
      vsix_sha256: ("d" * 64),
      signature_archive_sha256: ("9" * 64)
    },
    profile: {
      schema_version: 2,
      user_data_sha256: ("a" * 64),
      source_extensions_sha256: ("b" * 64),
      extensions_sha256: ("b" * 64),
      shared_data_sha256: ("c" * 64),
      installed_extensions: ["dbcode.dbcode@1.37.0"],
      restored_signed_payloads: []
    },
    evidence: {proof_sha256: ("d" * 64)},
    paths: {
      app: "DBCode Wrapper.app",
      build_manifest: "build-manifest.json",
      release_lock: "release-lock.json",
      user_data: "profile/user-data",
      extensions: "profile/extensions",
      shared_data: "profile/shared-data",
      proof: "evidence/proof-state.json"
    }
  }
' > "${candidate_set}"

DBCODE_WRAPPER_COMBINATION_GATE="${gate_script}" \
DBCODE_WRAPPER_TEST_GATE_LOG="${gate_log}" \
  "${upgrade_script}" matrix \
    --current-set "${current_set}" \
    --candidate-set "${candidate_set}" \
    --output "${matrix_receipt}"

expected_gate_log=$'H0/D0 current-release current-release\nH0/D1 current-release candidate-release\nH1/D0 candidate-release current-release\nH1/D1 candidate-release candidate-release'
[[ "$(cat "${gate_log}")" == "${expected_gate_log}" ]] || {
  echo "The compatibility runner did not execute the four independent host/DBCode pairings." >&2
  cat "${gate_log}" >&2
  exit 1
}

jq -e '
  .schema_version == 1
  and .status == "passed"
  and .promotion_ready == true
  and .current_release_set_id == "current-release"
  and .candidate_release_set_id == "candidate-release"
  and [.combinations[].combination] == ["H0/D0", "H0/D1", "H1/D0", "H1/D1"]
  and all(.combinations[];
    .status == "passed"
    and .checks.static == "passed"
    and .checks.runtime == "passed"
    and .checks.bundle_unchanged == true
    and .checks.surprise_update_absent == true
  )
' "${matrix_receipt}" >/dev/null || {
  echo "The compatibility receipt did not preserve every independent result." >&2
  exit 1
}

tampered_receipt="${test_root}/tampered-matrix.json"
if DBCODE_WRAPPER_COMBINATION_GATE="${gate_script}" \
  DBCODE_WRAPPER_TEST_GATE_LOG="${gate_log}" \
  DBCODE_WRAPPER_TEST_TAMPER_COMBINATION="H0/D1" \
  "${upgrade_script}" matrix \
    --current-set "${current_set}" \
    --candidate-set "${candidate_set}" \
    --output "${tampered_receipt}" >/dev/null 2>&1; then
  echo "The compatibility runner accepted a receipt copied from the wrong pairing." >&2
  exit 1
fi

mixed_failure_receipt="${test_root}/mixed-failure-matrix.json"
if DBCODE_WRAPPER_COMBINATION_GATE="${gate_script}" \
  DBCODE_WRAPPER_TEST_GATE_LOG="${gate_log}" \
  DBCODE_WRAPPER_TEST_FAIL_COMBINATION="H1/D0" \
  "${upgrade_script}" matrix \
    --current-set "${current_set}" \
    --candidate-set "${candidate_set}" \
    --output "${mixed_failure_receipt}" >/dev/null 2>&1; then
  echo "The compatibility runner accepted a failed mixed host and DBCode pairing." >&2
  exit 1
fi
jq -e '
  .status == "failed"
  and .promotion_ready == false
  and (.combinations | length) == 4
  and (.combinations[] | select(.combination == "H1/D0") | .status) == "failed"
' "${mixed_failure_receipt}" >/dev/null || {
  echo "A failed mixed pairing did not leave a fail-closed matrix receipt." >&2
  exit 1
}

fixture_root="${test_root}/fixture"
fixture_app="${fixture_root}/DBCode Wrapper.app"
fixture_manifest="${fixture_root}/build-manifest.json"
fixture_lock="${fixture_root}/release-lock.json"
fixture_proof="${fixture_root}/proof-state.json"
fixture_user_data="${fixture_root}/source-profile/DBCode Wrapper"
fixture_extensions="${fixture_root}/source-profile/extensions"
fixture_shared_data="${fixture_root}/source-profile/.dbcode-wrapper-shared"
prepared_set="${test_root}/prepared/candidate-release"

mkdir -p \
  "${fixture_app}/Contents/MacOS" \
  "${fixture_user_data}/User/globalStorage" \
  "${fixture_extensions}/dbcode.dbcode-1.37.0" \
  "${fixture_shared_data}/sharedStorage"
printf 'fixture-app\n' > "${fixture_app}/Contents/MacOS/DBCode Wrapper"
printf 'private-profile\n' > "${fixture_user_data}/User/globalStorage/state.vscdb"
printf 'shared-profile\n' > "${fixture_shared_data}/sharedStorage/state.vscdb"
jq -n '{publisher: "dbcode", name: "dbcode", version: "1.37.0", engines: {vscode: "^1.127.0"}}' \
  > "${fixture_extensions}/dbcode.dbcode-1.37.0/package.json"

fixture_app_sha="$(artifact_digest "${fixture_app}")"
fixture_source_id="code-oss-1.127.0-dbcode-1.37.0-source-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
fixture_release_id="${fixture_source_id}-artifact-${fixture_app_sha}"
jq -n \
  --arg app_sha "${fixture_app_sha}" \
  --arg source_set_id "${fixture_source_id}" \
  --arg release_set_id "${fixture_release_id}" '
    {
      schema_version: 5,
      release: {
        source_set_id: $source_set_id,
        release_set_id: $release_set_id,
        compatibility_status: "candidate",
        validation_issue: "07-promote-and-roll-back-approved-release-sets"
      },
      source: {
        repository_revision: ("1" * 40),
        release_lock_sha256: ("2" * 64),
        shell_patch_revision: ("3" * 64),
        overlay_sha256: ("4" * 64),
        vscodium: {tag: "1.127.0", commit: ("5" * 40)},
        code_oss: {tag: "1.127.0", commit: ("6" * 40)}
      },
      profile: {schema_version: 2},
      runtime_extensions: [{
        id: "dbcode.dbcode",
        version: "1.37.0",
        vsix_sha256: ("d" * 64),
        signature_archive_sha256: ("e" * 64)
      }],
      packaging: {status: "built-and-signed", updater_enabled: false},
      artifact: {
        app_name: "DBCode Wrapper",
        platform: "darwin",
        architecture: "arm64",
        bundle_identifier: "io.alexabelle.dbcodewrapper",
        sha256: $app_sha
      }
    }
  ' > "${fixture_manifest}"
jq '
  .upstream.vscodium.tag = "1.127.0"
  | .upstream.vscodium.commit = ("5" * 40)
  | .upstream.vscodium.release_notes_url = "https://github.com/VSCodium/vscodium/releases/tag/1.127.0"
  | .upstream.code_oss.tag = "1.127.0"
  | .upstream.code_oss.commit = ("6" * 40)
  | .upstream.code_oss.release_notes_url = "https://github.com/microsoft/vscode/releases/tag/1.127.0"
  | .runtime.code_oss_version = "1.127.0"
  | .release.release_set_base_id = "code-oss-1.127.0-dbcode-1.37.0"
  | .release.compatibility_status = "candidate"
  | .release.profile_schema_version = 2
  | .release.validation_issue = "07-promote-and-roll-back-approved-release-sets"
  | .extension.dbcode.version = "1.37.0"
  | .extension.dbcode.release_notes_url = "https://dbcode.io/docs/changelog/1.37.0"
  | .extension.dbcode.engine = "^1.127.0"
  | .extension.dbcode.sha256 = ("d" * 64)
  | .extension.dbcode.signature_archive_sha256 = ("e" * 64)
' "${LOCK_FILE}" > "${fixture_lock}"
while IFS=$'\t' read -r extension_id extension_version extension_engine; do
  extension_directory="${fixture_extensions}/${extension_id}-${extension_version}"
  mkdir -p "${extension_directory}"
  jq -n \
    --arg id "${extension_id}" \
    --arg version "${extension_version}" \
    --arg engine "${extension_engine}" '
      ($id | split(".")) as $parts
      | {publisher: $parts[0], name: ($parts[1:] | join(".")), version: $version, engines: {vscode: $engine}}
    ' > "${extension_directory}/package.json"
done < <(jq -r '
  ([.extension.dbcode] + .extension.python_notebooks.packages)[]
  | [.id, .version, .engine] | @tsv
' "${fixture_lock}")
fixture_lock_sha="$(shasum -a 256 "${fixture_lock}" | awk '{print $1}')"
jq --arg lock_sha "${fixture_lock_sha}" '.source.release_lock_sha256 = $lock_sha' \
  "${fixture_manifest}" > "${fixture_manifest}.tmp"
mv "${fixture_manifest}.tmp" "${fixture_manifest}"
jq -n \
  --arg release_set_id "${fixture_release_id}" '
  ["activation", "credential_reentry", "update_discovery", "postgresql", "duckdb", "parquet", "persistence"] as $checks
  | {
      schema_version: 5,
      status: "passed",
      completed_at: "2026-07-21T04:00:00Z",
      approved_release_set: {
        host: {release_set_id: $release_set_id},
        dbcode: {id: "dbcode.dbcode", version: "1.37.0"}
      },
      launches: [
        {id: "launch-1", kind: "launch", launched_at: "2026-07-21T01:00:00Z", ready_at: "2026-07-21T01:01:00Z", normal_profile_before: "normal-a"},
        {id: "launch-2", kind: "relaunch", launched_at: "2026-07-21T02:00:00Z", ready_at: "2026-07-21T02:01:00Z", normal_profile_before: "normal-a"}
      ],
      complete_quits: [
        {after_launch_id: "launch-1", quit_at: "2026-07-21T01:30:00Z"},
        {after_launch_id: "launch-2", quit_at: "2026-07-21T03:30:00Z"}
      ],
      last_complete_quit: {after_launch_id: "launch-2", quit_at: "2026-07-21T03:30:00Z"},
      active_launch: {
        id: "launch-2",
        kind: "relaunch",
        previous_launch_id: "launch-1",
        previous_complete_quit: {after_launch_id: "launch-1", quit_at: "2026-07-21T01:30:00Z"},
        launched_at: "2026-07-21T02:00:00Z",
        ready_at: "2026-07-21T02:01:00Z",
        normal_profile_before: "normal-a"
      },
      manual_checks: (reduce $checks[] as $check ({};
        .[$check] = {
          status: "passed",
          launch_id: "launch-2",
          launch_kind: "relaunch",
          recorded_at: "2026-07-21T03:00:00Z",
          note: "Observed the expected fixture result.",
          expected_result: "Fixture result contract."
        }
      )),
      fixtures: {
        postgresql: {
          server_enforced_read_only: true,
          verified_result: {transaction_read_only: "on", row_count: 3, amount_sum: "75.00"}
        },
        duckdb: {verified_result: {amount_sum: "61.50", first_id: 1, last_id: 3, row_count: 3}},
        parquet: {verified_result: {amount_sum: "61.50", first_id: 1, last_id: 3, row_count: 3}}
      }
    }
' > "${fixture_proof}"

"${upgrade_script}" prepare-set \
  --role candidate \
  --app "${fixture_app}" \
  --manifest "${fixture_manifest}" \
  --release-lock "${fixture_lock}" \
  --user-data "${fixture_user_data}" \
  --extensions "${fixture_extensions}" \
  --shared-data "${fixture_shared_data}" \
  --proof "${fixture_proof}" \
  --output-dir "${prepared_set}"

jq -e \
  --arg app_sha "${fixture_app_sha}" \
  --arg source_set_id "${fixture_source_id}" \
  --arg release_set_id "${fixture_release_id}" \
  --arg manifest_sha "$(shasum -a 256 "${prepared_set}/build-manifest.json" | awk '{print $1}')" \
  --arg proof_sha "$(shasum -a 256 "${prepared_set}/evidence/proof-state.json" | awk '{print $1}')" '
    .schema_version == 1
    and .role == "candidate"
    and .release == {release_set_id: $release_set_id, source_set_id: $source_set_id}
    and .host.app_sha256 == $app_sha
    and .host.build_manifest_sha256 == $manifest_sha
    and .host.code_oss_version == "1.127.0"
    and .dbcode.id == "dbcode.dbcode"
    and .dbcode.version == "1.37.0"
    and .dbcode.vsix_sha256 == ("d" * 64)
    and .profile.schema_version == 2
    and (.profile.installed_extensions | length) == 7
    and (.profile.installed_extensions | index("dbcode.dbcode@1.37.0")) != null
    and .profile.source_extensions_sha256 == .profile.extensions_sha256
    and .profile.restored_signed_payloads == []
    and .evidence.proof_sha256 == $proof_sha
    and .paths == {
      app: "DBCode Wrapper.app",
      build_manifest: "build-manifest.json",
      release_lock: "release-lock.json",
      user_data: "profile/user-data",
      extensions: "profile/extensions",
      shared_data: "profile/shared-data",
      proof: "evidence/proof-state.json"
    }
  ' "${prepared_set}/release-set.json" >/dev/null || {
  echo "The prepared candidate does not bind the complete isolated release set." >&2
  exit 1
}

[[ "$(stat -f '%Lp' "${prepared_set}")" == "700" ]] || {
  echo "The prepared release set is not private to its owner." >&2
  exit 1
}
cmp -s \
  "${fixture_user_data}/User/globalStorage/state.vscdb" \
  "${prepared_set}/profile/user-data/User/globalStorage/state.vscdb" || {
  echo "The candidate profile clone does not match its private source." >&2
  exit 1
}

tampered_manifest="${fixture_root}/tampered-manifest.json"
jq '.artifact.sha256 = ("f" * 64)' "${fixture_manifest}" > "${tampered_manifest}"
if "${upgrade_script}" prepare-set \
  --role candidate \
  --app "${fixture_app}" \
  --manifest "${tampered_manifest}" \
  --release-lock "${fixture_lock}" \
  --user-data "${fixture_user_data}" \
  --extensions "${fixture_extensions}" \
  --shared-data "${fixture_shared_data}" \
  --proof "${fixture_proof}" \
  --output-dir "${test_root}/prepared/tampered" >/dev/null 2>&1; then
  echo "Candidate preparation accepted an app that did not match its manifest." >&2
  exit 1
fi

combination_checker="${REPO_ROOT}/script/check_release_combination.sh"
production_static_gate="${REPO_ROOT}/script/verify_release_set_static.sh"
production_runtime_gate="${REPO_ROOT}/script/smoke_release_pair.sh"
production_health_gate="${REPO_ROOT}/script/check_installed_release_health.sh"
static_gate="${REPO_ROOT}/script/fixtures/test_release_static_gate.sh"
runtime_gate="${REPO_ROOT}/script/fixtures/test_release_runtime_gate.sh"
combination_receipt="${test_root}/combination-receipt.json"

static_failure_receipt="${test_root}/unsigned-static-receipt.json"
if "${production_static_gate}" \
  --host-set "${prepared_set}/release-set.json" \
  --dbcode-set "${prepared_set}/release-set.json" \
  --output "${static_failure_receipt}" >/dev/null 2>&1; then
  echo "The production static gate accepted an unsigned fake app." >&2
  exit 1
fi
jq -e '
  .schema_version == 1
  and .status == "failed"
  and (.source_and_artifact_identity | type == "boolean")
  and (.hashes_and_signatures | type == "boolean")
  and (.architecture_and_minimum_macos | type == "boolean")
  and (.dbcode_engine_compatible | type == "boolean")
  and (.unchanged_extension_packages | type == "boolean")
  and (.connection_capability_contract | type == "boolean")
  and (.extension_allowlist_exact | type == "boolean")
  and (.nested_signature_and_entitlements | type == "boolean")
  and (.failures | type == "array" and length > 0)
' "${static_failure_receipt}" >/dev/null || {
  echo "The production static gate did not leave a complete failure receipt." >&2
  exit 1
}

runtime_failure_receipt="${test_root}/unlaunchable-runtime-receipt.json"
if DBCODE_WRAPPER_PRESERVE_FAILED_RUNTIME=yes \
  "${production_runtime_gate}" \
  --host-set "${prepared_set}/release-set.json" \
  --dbcode-set "${prepared_set}/release-set.json" \
  --output "${runtime_failure_receipt}" >/dev/null 2>&1; then
  echo "The production runtime gate accepted an unlaunchable fake app." >&2
  exit 1
fi
jq -e '
  .schema_version == 1
  and .status == "failed"
  and (.focused_database_shell | type == "boolean")
  and (.dbcode_started | type == "boolean")
  and (.normal_pro_activation | type == "boolean")
  and (.postgresql | type == "boolean")
  and (.duckdb | type == "boolean")
  and (.parquet | type == "boolean")
  and (.hyphen_path_preflight == "passed" or .hyphen_path_preflight == "not-required" or .hyphen_path_preflight == "not-run")
  and (.full_quit_and_relaunch | type == "boolean")
  and (.normal_profiles_unchanged | type == "boolean")
  and (.surprise_update_absent | type == "boolean")
  and (.evidence_path | type == "string" and length > 0)
  and (.failures | type == "array" and length > 0)
' "${runtime_failure_receipt}" >/dev/null || {
  echo "The production runtime gate did not leave a complete failure receipt." >&2
  exit 1
}
[[ -d "${runtime_failure_receipt%.json}.evidence" ]] || {
  echo "The production runtime gate did not preserve requested failure evidence." >&2
  exit 1
}
[[ -f "${runtime_failure_receipt%.json}.evidence/extensions/dbcode.dbcode-1.37.0/package.json" ]] || {
  echo "The isolated runtime clone nested the extension root under an extra directory." >&2
  exit 1
}

health_failure_root="${test_root}/unlaunchable-health"
health_failure_layout="${health_failure_root}/layout.json"
health_failure_state="${health_failure_root}/state/installed-release-set.json"
health_failure_receipt="${health_failure_root}/receipt.json"
health_failure_user_data="${health_failure_root}/a-deliberately-long-user-data-parent-that-exceeds-the-macos-unix-socket-path-limit/user-data"
mkdir -p "$(dirname "${health_failure_state}")" "$(dirname "${health_failure_user_data}")"
cp -cR "${prepared_set}/profile/user-data" "${health_failure_user_data}"
jq -n \
  --arg app "${prepared_set}/DBCode Wrapper.app" \
  --arg manifest "${prepared_set}/build-manifest.json" \
  --arg user_data "${health_failure_user_data}" \
  --arg extensions "${prepared_set}/profile/extensions" \
  --arg shared_data "${prepared_set}/profile/shared-data" \
  --arg state_root "$(dirname "${health_failure_state}")" \
  --arg previous_root "${health_failure_root}/previous" '
    {
      schema_version: 1,
      targets: {
        app: $app,
        build_manifest: $manifest,
        user_data: $user_data,
        extensions: $extensions,
        shared_data: $shared_data
      },
      state_root: $state_root,
      previous_root: $previous_root
    }
  ' > "${health_failure_layout}"
jq -n \
  --arg release_set_id "${fixture_release_id}" \
  --arg app_sha "$(artifact_digest "${prepared_set}/DBCode Wrapper.app")" \
  --arg manifest_sha "$(shasum -a 256 "${prepared_set}/build-manifest.json" | awk '{print $1}')" \
  --arg extensions_sha "$(directory_content_digest "${prepared_set}/profile/extensions")" '
    {
      schema_version: 1,
      status: "pending-health-check",
      active: {
        release_set_id: $release_set_id,
        app_sha256: $app_sha,
        build_manifest_sha256: $manifest_sha,
        extensions_sha256: $extensions_sha
      }
    }
  ' > "${health_failure_state}"
if "${production_health_gate}" \
  --layout "${health_failure_layout}" \
  --state "${health_failure_state}" \
  --output "${health_failure_receipt}" >/dev/null 2>&1; then
  echo "The production health gate accepted an unlaunchable installed app." >&2
  exit 1
fi
jq -e \
  --arg release_set_id "${fixture_release_id}" '
  .schema_version == 1
  and .status == "failed"
  and .release_set_id == $release_set_id
  and (.app_sha256 | test("^[0-9a-f]{64}$"))
  and (.build_manifest_sha256 | test("^[0-9a-f]{64}$"))
  and (.extensions_sha256 | test("^[0-9a-f]{64}$"))
  and (.first_launch_ready | type == "boolean")
  and (.first_quit_complete | type == "boolean")
  and (.relaunch_ready | type == "boolean")
  and (.final_quit_complete | type == "boolean")
  and (.dbcode_started | type == "boolean")
  and (.account_restored | type == "boolean")
  and (.keychain_error_absent | type == "boolean")
  and (.surprise_update_absent | type == "boolean")
  and any(.failures[]; . == "user-data-path-too-long-for-ipc")
  and (.failures | type == "array" and length > 0)
' "${health_failure_receipt}" >/dev/null || {
  echo "The production health gate did not leave a complete failure receipt." >&2
  exit 1
}

DBCODE_WRAPPER_STATIC_GATE="${static_gate}" \
DBCODE_WRAPPER_RUNTIME_GATE="${runtime_gate}" \
  "${combination_checker}" \
    --combination H1/D1 \
    --host-set "${prepared_set}/release-set.json" \
    --dbcode-set "${prepared_set}/release-set.json" \
    --output "${combination_receipt}"

jq -e \
  --arg app_sha "${fixture_app_sha}" \
  --arg release_set_id "${fixture_release_id}" '
    .schema_version == 1
    and .combination == "H1/D1"
    and .host == {release_set_id: $release_set_id, app_sha256: $app_sha}
    and .dbcode.id == "dbcode.dbcode"
    and .dbcode.version == "1.37.0"
    and .checks.static == "passed"
    and .checks.runtime == "passed"
    and .checks.bundle_unchanged == true
    and .checks.surprise_update_absent == true
    and .details.static.source_and_artifact_identity == true
    and .details.static.connection_capability_contract == true
    and .details.static.nested_signature_and_entitlements == true
    and .details.runtime.dbcode_started == true
    and .status == "passed"
  ' "${combination_receipt}" >/dev/null || {
  echo "The release-combination receipt omitted a required static or runtime result." >&2
  exit 1
}

failed_combination_receipt="${test_root}/failed-combination-receipt.json"
if DBCODE_WRAPPER_STATIC_GATE="${static_gate}" \
  DBCODE_WRAPPER_RUNTIME_GATE="${runtime_gate}" \
  DBCODE_WRAPPER_TEST_RUNTIME_STATUS="failed" \
  "${combination_checker}" \
    --combination H1/D1 \
    --host-set "${prepared_set}/release-set.json" \
    --dbcode-set "${prepared_set}/release-set.json" \
    --output "${failed_combination_receipt}" >/dev/null 2>&1; then
  echo "The release-combination gate accepted a failed runtime check." >&2
  exit 1
fi
jq -e '
  .schema_version == 1
  and .status == "failed"
  and .checks.static == "passed"
  and .checks.runtime == "failed"
  and .checks.bundle_unchanged == true
  and .checks.surprise_update_absent == false
  and .details.runtime.status == "failed"
' "${failed_combination_receipt}" >/dev/null || {
  echo "A failed runtime combination did not leave a complete combined receipt." >&2
  exit 1
}

current_fixture_root="${test_root}/current-fixture"
current_fixture_app="${current_fixture_root}/DBCode Wrapper.app"
current_fixture_manifest="${current_fixture_root}/build-manifest.json"
current_fixture_lock="${current_fixture_root}/release-lock.json"
current_fixture_user_data="${current_fixture_root}/source-profile/user-data"
current_fixture_extensions="${current_fixture_root}/source-profile/extensions"
current_fixture_shared_data="${current_fixture_root}/source-profile/shared-data"
prepared_current_set="${test_root}/prepared/current-release"
mkdir -p \
  "${current_fixture_app}/Contents/MacOS" \
  "${current_fixture_user_data}/User/globalStorage" \
  "${current_fixture_extensions}/dbcode.dbcode-1.36.1" \
  "${current_fixture_shared_data}/sharedStorage"
printf 'current-app\n' > "${current_fixture_app}/Contents/MacOS/DBCode Wrapper"
printf 'current-profile\n' > "${current_fixture_user_data}/User/globalStorage/state.vscdb"
printf 'current-shared\n' > "${current_fixture_shared_data}/sharedStorage/state.vscdb"
jq -n '{publisher: "dbcode", name: "dbcode", version: "1.36.1", engines: {vscode: "^1.126.0"}}' \
  > "${current_fixture_extensions}/dbcode.dbcode-1.36.1/package.json"
current_fixture_app_sha="$(artifact_digest "${current_fixture_app}")"
jq \
  --arg app_sha "${current_fixture_app_sha}" '
    .release.source_set_id = "current-source"
    | .release.release_set_id = "current-release"
    | .release.compatibility_status = "approved"
    | .source.repository_revision = ("7" * 40)
    | .source.vscodium.tag = "1.126.0"
    | .source.code_oss.tag = "1.126.0"
    | .profile.schema_version = 1
    | .runtime_extensions = [{
        id: "dbcode.dbcode",
        version: "1.36.1",
        vsix_sha256: ("8" * 64),
        signature_archive_sha256: ("9" * 64)
      }]
    | .artifact.sha256 = $app_sha
  ' "${fixture_manifest}" > "${current_fixture_manifest}"
jq '
  .upstream.vscodium.tag = "1.126.0"
  | .upstream.vscodium.commit = ("7" * 40)
  | .upstream.vscodium.release_notes_url = "https://github.com/VSCodium/vscodium/releases/tag/1.126.0"
  | .runtime.code_oss_version = "1.126.0"
  | .upstream.code_oss.tag = "1.126.0"
  | .upstream.code_oss.commit = ("7" * 40)
  | .upstream.code_oss.release_notes_url = "https://github.com/microsoft/vscode/releases/tag/1.126.0"
  | .release.release_set_base_id = "code-oss-1.126.0-dbcode-1.36.1"
  | .release.compatibility_status = "approved"
  | .release.profile_schema_version = 1
  | .extension.dbcode.version = "1.36.1"
  | .extension.dbcode.release_notes_url = "https://dbcode.io/docs/changelog/1.36.1"
  | .extension.dbcode.engine = "^1.126.0"
  | .extension.dbcode.sha256 = ("8" * 64)
  | .extension.dbcode.signature_archive_sha256 = ("9" * 64)
  ' "${fixture_lock}" > "${current_fixture_lock}"
while IFS=$'\t' read -r extension_id extension_version extension_engine; do
  extension_directory="${current_fixture_extensions}/${extension_id}-${extension_version}"
  mkdir -p "${extension_directory}"
  jq -n \
    --arg id "${extension_id}" \
    --arg version "${extension_version}" \
    --arg engine "${extension_engine}" '
      ($id | split(".")) as $parts
      | {publisher: $parts[0], name: ($parts[1:] | join(".")), version: $version, engines: {vscode: $engine}}
    ' > "${extension_directory}/package.json"
done < <(jq -r '
  ([.extension.dbcode] + .extension.python_notebooks.packages)[]
  | [.id, .version, .engine] | @tsv
' "${current_fixture_lock}")
current_fixture_lock_sha="$(shasum -a 256 "${current_fixture_lock}" | awk '{print $1}')"
jq --arg lock_sha "${current_fixture_lock_sha}" '.source.release_lock_sha256 = $lock_sha' \
  "${current_fixture_manifest}" > "${current_fixture_manifest}.tmp"
mv "${current_fixture_manifest}.tmp" "${current_fixture_manifest}"

"${upgrade_script}" prepare-set \
  --role current \
  --app "${current_fixture_app}" \
  --manifest "${current_fixture_manifest}" \
  --release-lock "${current_fixture_lock}" \
  --user-data "${current_fixture_user_data}" \
  --extensions "${current_fixture_extensions}" \
  --shared-data "${current_fixture_shared_data}" \
  --output-dir "${prepared_current_set}"

historical_current_lock="${current_fixture_root}/historical-release-lock.json"
historical_current_manifest="${current_fixture_root}/historical-build-manifest.json"
prepared_historical_current_set="${test_root}/prepared/historical-current-release"
jq '
  del(
    .upstream.code_oss.published_at,
    .upstream.code_oss.release_notes_url,
    .extension.dbcode.release_notes_url
  )
' "${current_fixture_lock}" > "${historical_current_lock}"
historical_current_lock_sha="$(
  shasum -a 256 "${historical_current_lock}" | awk '{print $1}'
)"
jq --arg lock_sha "${historical_current_lock_sha}" \
  '.source.release_lock_sha256 = $lock_sha' \
  "${current_fixture_manifest}" > "${historical_current_manifest}"

"${upgrade_script}" prepare-set \
  --role current \
  --app "${current_fixture_app}" \
  --manifest "${historical_current_manifest}" \
  --release-lock "${historical_current_lock}" \
  --user-data "${current_fixture_user_data}" \
  --extensions "${current_fixture_extensions}" \
  --shared-data "${current_fixture_shared_data}" \
  --output-dir "${prepared_historical_current_set}"

jq -e '
  .role == "current"
  and .release.release_set_id == "current-release"
  and .host.code_oss_version == "1.126.0"
  and .dbcode.version == "1.36.1"
  and (.profile.installed_extensions | length) == 7
' "${prepared_historical_current_set}/release-set.json" >/dev/null || {
  echo "Historical current-set preparation did not preserve the complete release set." >&2
  exit 1
}

if "${upgrade_script}" prepare-set \
  --role current \
  --app "${current_fixture_app}" \
  --manifest "${current_fixture_manifest}" \
  --release-lock "${historical_current_lock}" \
  --user-data "${current_fixture_user_data}" \
  --extensions "${current_fixture_extensions}" \
  --shared-data "${current_fixture_shared_data}" \
  --output-dir "${test_root}/prepared/unbound-historical-current" >/dev/null 2>&1; then
  echo "Historical current-set preparation accepted a manifest bound to another lock." >&2
  exit 1
fi

unbound_historical_manifest="${current_fixture_root}/unbound-historical-build-manifest.json"
jq 'del(.source.release_lock_sha256)' \
  "${historical_current_manifest}" > "${unbound_historical_manifest}"
if "${upgrade_script}" prepare-set \
  --role current \
  --app "${current_fixture_app}" \
  --manifest "${unbound_historical_manifest}" \
  --release-lock "${historical_current_lock}" \
  --user-data "${current_fixture_user_data}" \
  --extensions "${current_fixture_extensions}" \
  --shared-data "${current_fixture_shared_data}" \
  --output-dir "${test_root}/prepared/missing-historical-lock-binding" >/dev/null 2>&1; then
  echo "Historical current-set preparation accepted a manifest without an exact lock binding." >&2
  exit 1
fi

if "${upgrade_script}" prepare-set \
  --role candidate \
  --app "${current_fixture_app}" \
  --manifest "${historical_current_manifest}" \
  --release-lock "${historical_current_lock}" \
  --user-data "${current_fixture_user_data}" \
  --extensions "${current_fixture_extensions}" \
  --shared-data "${current_fixture_shared_data}" \
  --proof "${fixture_proof}" \
  --output-dir "${test_root}/prepared/historical-candidate" >/dev/null 2>&1; then
  echo "Candidate preparation accepted a frozen historical Release Specification." >&2
  exit 1
fi

promotion_matrix="${test_root}/promotion-matrix.json"
current_descriptor_sha="$(shasum -a 256 "${prepared_current_set}/release-set.json" | awk '{print $1}')"
candidate_descriptor_sha="$(shasum -a 256 "${prepared_set}/release-set.json" | awk '{print $1}')"
jq -n \
  --arg current_sha "${current_descriptor_sha}" \
  --arg candidate_id "${fixture_release_id}" \
  --arg candidate_sha "${candidate_descriptor_sha}" '
    def receipt($combination; $host; $dbcode; $full): {
      schema_version: 1,
      combination: $combination,
      host: {release_set_id: $host, app_sha256: (if $host == "current-release" then ("0" * 64) else ("1" * 64) end)},
      dbcode: {id: "dbcode.dbcode", version: $dbcode, vsix_sha256: ("2" * 64)},
      checks: {static: "passed", runtime: "passed", bundle_unchanged: true, surprise_update_absent: true},
      details: {
        static: {connection_capability_contract: true},
        runtime: {
          focused_database_shell: true,
          dbcode_started: true,
          normal_pro_activation: $full,
          postgresql: $full,
          duckdb: $full,
          parquet: $full,
          hyphen_path_preflight: (if $full then "passed" else "not-required" end),
          full_quit_and_relaunch: true,
          normal_profiles_unchanged: true,
          surprise_update_absent: true
        }
      },
      status: "passed"
    };
    {
      schema_version: 1,
      created_at_utc: "2026-07-21T05:00:00Z",
      current_release_set_id: "current-release",
      candidate_release_set_id: $candidate_id,
      current_release_set_sha256: $current_sha,
      candidate_release_set_sha256: $candidate_sha,
      combinations: [
        receipt("H0/D0"; "current-release"; "1.36.1"; false),
        receipt("H0/D1"; "current-release"; "1.37.0"; false),
        receipt("H1/D0"; $candidate_id; "1.36.1"; false),
        receipt("H1/D1"; $candidate_id; "1.37.0"; true)
      ],
      promotion_ready: true,
      status: "passed"
    }
  ' > "${promotion_matrix}"

install_root="${test_root}/installed"
install_app="${install_root}/application/DBCode Wrapper.app"
install_manifest="${install_root}/application/build-manifest.json"
install_user_data="${install_root}/profile/user-data"
install_extensions="${install_root}/profile/extensions"
install_shared_data="${install_root}/profile/shared-data"
upgrade_state_root="${install_root}/upgrade-state"
previous_root="${install_root}/previous"
install_layout="${test_root}/install-layout.json"
mkdir -p "$(dirname "${install_app}")" "$(dirname "${install_user_data}")"
ditto "${prepared_current_set}/DBCode Wrapper.app" "${install_app}"
cp "${prepared_current_set}/build-manifest.json" "${install_manifest}"
ditto "${prepared_current_set}/profile/user-data" "${install_user_data}"
ditto "${prepared_current_set}/profile/extensions" "${install_extensions}"
ditto "${prepared_current_set}/profile/shared-data" "${install_shared_data}"
jq -n \
  --arg app "${install_app}" \
  --arg manifest "${install_manifest}" \
  --arg user_data "${install_user_data}" \
  --arg extensions "${install_extensions}" \
  --arg shared_data "${install_shared_data}" \
  --arg state_root "${upgrade_state_root}" \
  --arg previous_root "${previous_root}" '
    {
      schema_version: 1,
      targets: {
        app: $app,
        build_manifest: $manifest,
        user_data: $user_data,
        extensions: $extensions,
        shared_data: $shared_data
      },
      state_root: $state_root,
      previous_root: $previous_root
    }
  ' > "${install_layout}"

failed_promotion_matrix="${test_root}/failed-promotion-matrix.json"
jq '
  .combinations = [
    .combinations[]
    | if .combination == "H1/D0" then
        .status = "failed"
        | .checks.static = "failed"
        | .checks.runtime = "failed"
        | .checks.surprise_update_absent = false
      else . end
  ]
  | .promotion_ready = false
  | .status = "failed"
' "${promotion_matrix}" > "${failed_promotion_matrix}"
installed_before_failed_promotion="$(artifact_digest "${install_root}")"
if "${upgrade_script}" promote \
  --current-set "${prepared_current_set}/release-set.json" \
  --candidate-set "${prepared_set}/release-set.json" \
  --matrix "${failed_promotion_matrix}" \
  --layout "${install_layout}" \
  --confirm-release-set "${fixture_release_id}" >/dev/null 2>&1; then
  echo "Promotion accepted a matrix with a failed mixed pairing." >&2
  exit 1
fi
[[ "$(artifact_digest "${install_root}")" == "${installed_before_failed_promotion}" ]] || {
  echo "A rejected mixed-pair promotion changed the installed release." >&2
  exit 1
}
[[ ! -e "${upgrade_state_root}/installed-release-set.json" ]] || {
  echo "A rejected mixed-pair promotion created installed-set state." >&2
  exit 1
}

overlapping_layout="${test_root}/overlapping-install-layout.json"
jq '.targets.extensions = (.targets.user_data + "/extensions")' \
  "${install_layout}" > "${overlapping_layout}"
if overlap_error="$("${upgrade_script}" promote \
  --current-set "${prepared_current_set}/release-set.json" \
  --candidate-set "${prepared_set}/release-set.json" \
  --matrix "${promotion_matrix}" \
  --layout "${overlapping_layout}" \
  --confirm-release-set "${fixture_release_id}" 2>&1)"; then
  echo "Promotion accepted overlapping install-layout paths." >&2
  exit 1
fi
grep -Fq 'Install-layout paths must not overlap.' <<<"${overlap_error}" || {
  echo "Promotion rejected an overlapping layout only after reaching another check." >&2
  exit 1
}

protected_root="${test_root}/protected"
mkdir -p "${protected_root}/normal-vscode" "${protected_root}/keychain"
printf 'database sentinel\n' > "${protected_root}/user-database.duckdb"
printf 'normal profile sentinel\n' > "${protected_root}/normal-vscode/state.vscdb"
printf 'keychain sentinel\n' > "${protected_root}/keychain/login.keychain-db"
protected_before="$(artifact_digest "${protected_root}")"

if "${upgrade_script}" promote \
  --current-set "${prepared_current_set}/release-set.json" \
  --candidate-set "${prepared_set}/release-set.json" \
  --matrix "${promotion_matrix}" \
  --layout "${install_layout}" \
  --confirm-release-set wrong-release >/dev/null 2>&1; then
  echo "Promotion accepted a confirmation for another release set." >&2
  exit 1
fi
[[ ! -e "${upgrade_state_root}/installed-release-set.json" ]] || {
  echo "A rejected promotion changed the installed-set state." >&2
  exit 1
}

"${upgrade_script}" promote \
  --current-set "${prepared_current_set}/release-set.json" \
  --candidate-set "${prepared_set}/release-set.json" \
  --matrix "${promotion_matrix}" \
  --layout "${install_layout}" \
  --confirm-release-set "${fixture_release_id}"

[[ "$(artifact_digest "${install_app}")" == "${fixture_app_sha}" ]] || {
  echo "Promotion did not install the candidate app." >&2
  exit 1
}
cmp -s "${prepared_set}/build-manifest.json" "${install_manifest}" || {
  echo "Promotion did not install the candidate manifest." >&2
  exit 1
}
[[ -f "${install_extensions}/dbcode.dbcode-1.37.0/package.json" ]] || {
  echo "Promotion did not install the candidate extension root." >&2
  exit 1
}
jq -e \
  --arg candidate_id "${fixture_release_id}" '
  .schema_version == 1
  and .status == "pending-health-check"
  and .active.release_set_id == $candidate_id
  and .previous.release_set_id == "current-release"
  and (.previous.snapshot_path | type == "string" and length > 0)
' "${upgrade_state_root}/installed-release-set.json" >/dev/null || {
  echo "Promotion did not retain the previous set until health acceptance." >&2
  exit 1
}
jq -e \
  --arg candidate_id "${fixture_release_id}" '
  .schema_version == 2
  and any(.approved_release_sets[];
    .schema_version == 1
    and .id == $candidate_id
    and .compatibility_status == "approved"
    and .dbcode.id == "dbcode.dbcode"
    and .dbcode.version == "1.37.0"
    and (.approval.proof_sha256 | test("^[0-9a-f]{64}$"))
    and (.approval.gate_receipt_sha256 | test("^[0-9a-f]{64}$"))
  )
' "${install_user_data}/User/globalStorage/dbcode-wrapper.release-status/approved-release-sets.json" >/dev/null || {
  echo "Promotion did not publish the exact local Approved Release Set record." >&2
  exit 1
}
[[ "$(artifact_digest "${protected_root}")" == "${protected_before}" ]] || {
  echo "Promotion changed data outside the explicit DBCode Wrapper layout." >&2
  exit 1
}

health_gate="${REPO_ROOT}/script/fixtures/test_installed_health_gate.sh"
if DBCODE_WRAPPER_HEALTH_GATE="${health_gate}" \
  "${upgrade_script}" health \
    --layout "${install_layout}" \
    --confirm-release-set wrong-release >/dev/null 2>&1; then
  echo "Restart health acceptance allowed confirmation for another release set." >&2
  exit 1
fi
jq -e '.status == "pending-health-check"' \
  "${upgrade_state_root}/installed-release-set.json" >/dev/null || {
  echo "A rejected health confirmation changed the installed-set state." >&2
  exit 1
}

DBCODE_WRAPPER_HEALTH_GATE="${health_gate}" \
  "${upgrade_script}" health \
    --layout "${install_layout}" \
    --confirm-release-set "${fixture_release_id}"
jq -e \
  --arg candidate_id "${fixture_release_id}" '
  .status == "accepted"
  and .active.release_set_id == $candidate_id
  and (.health.receipt_sha256 | test("^[0-9a-f]{64}$"))
  and (.health.accepted_at | type == "string" and length > 0)
' "${upgrade_state_root}/installed-release-set.json" >/dev/null || {
  echo "Restart health did not accept the exact installed candidate." >&2
  exit 1
}

"${upgrade_script}" rollback \
  --layout "${install_layout}" \
  --confirm-release-set current-release
[[ "$(artifact_digest "${install_app}")" == "${current_fixture_app_sha}" ]] || {
  echo "Rollback did not restore the complete previous app." >&2
  exit 1
}
cmp -s "${prepared_current_set}/build-manifest.json" "${install_manifest}" || {
  echo "Rollback did not restore the previous build manifest." >&2
  exit 1
}
[[ -f "${install_extensions}/dbcode.dbcode-1.36.1/package.json" && \
  ! -e "${install_extensions}/dbcode.dbcode-1.37.0" ]] || {
  echo "Rollback mixed the previous and candidate extension roots." >&2
  exit 1
}
[[ "$(cat "${install_user_data}/User/globalStorage/state.vscdb")" == "current-profile" ]] || {
  echo "Rollback did not restore the previous user-data profile." >&2
  exit 1
}
[[ "$(cat "${install_shared_data}/sharedStorage/state.vscdb")" == "current-shared" ]] || {
  echo "Rollback did not restore the previous shared-data profile." >&2
  exit 1
}
jq -e \
  --arg candidate_id "${fixture_release_id}" '
  .status == "rolled-back"
  and .active.release_set_id == "current-release"
  and .rolled_back_from.release_set_id == $candidate_id
' "${upgrade_state_root}/installed-release-set.json" >/dev/null || {
  echo "Rollback did not record the restored complete set." >&2
  exit 1
}
[[ "$(artifact_digest "${protected_root}")" == "${protected_before}" ]] || {
  echo "Health or rollback changed data outside the explicit DBCode Wrapper layout." >&2
  exit 1
}

"${upgrade_script}" promote \
  --current-set "${prepared_current_set}/release-set.json" \
  --candidate-set "${prepared_set}/release-set.json" \
  --matrix "${promotion_matrix}" \
  --layout "${install_layout}" \
  --confirm-release-set "${fixture_release_id}"
DBCODE_WRAPPER_HEALTH_GATE="${health_gate}" \
  "${upgrade_script}" health \
    --layout "${install_layout}" \
    --confirm-release-set "${fixture_release_id}"
if DBCODE_WRAPPER_TEST_FAIL_ROLLBACK_AFTER_TARGET_MOVE=2 \
  "${upgrade_script}" rollback \
    --layout "${install_layout}" \
    --confirm-release-set current-release >/dev/null 2>&1; then
  echo "The injected half-swap rollback failure unexpectedly succeeded." >&2
  exit 1
fi
[[ "$(artifact_digest "${install_app}")" == "${fixture_app_sha}" ]] || {
  echo "A half-swap rollback failure did not restore the active candidate app." >&2
  exit 1
}
cmp -s "${prepared_set}/build-manifest.json" "${install_manifest}" || {
  echo "A half-swap rollback failure did not restore the active candidate manifest." >&2
  exit 1
}
[[ -f "${install_extensions}/dbcode.dbcode-1.37.0/package.json" && \
  ! -e "${install_extensions}/dbcode.dbcode-1.36.1" ]] || {
  echo "A half-swap rollback failure mixed active and previous extension roots." >&2
  exit 1
}
jq -e --arg candidate_id "${fixture_release_id}" \
  '.status == "accepted" and .active.release_set_id == $candidate_id' \
  "${upgrade_state_root}/installed-release-set.json" >/dev/null || {
  echo "A failed rollback changed the accepted installed-set state." >&2
  exit 1
}
jq -e '.status == "restored-active-set-after-failed-rollback"' \
  "${upgrade_state_root}/rollback-transaction.json" >/dev/null || {
  echo "A failed rollback did not record its complete active-set restoration." >&2
  exit 1
}
if find "${install_root}" \( -name '*.incoming-*' -o -name '*.outgoing-*' -o -name '*.failed-*' \) -print -quit | grep -q .; then
  echo "The failed rollback left a partial transaction beside the installed set." >&2
  exit 1
fi
"${upgrade_script}" rollback \
  --layout "${install_layout}" \
  --confirm-release-set current-release
[[ "$(artifact_digest "${protected_root}")" == "${protected_before}" ]] || {
  echo "A failed rollback changed data outside the explicit DBCode Wrapper layout." >&2
  exit 1
}

failure_install_root="${test_root}/failed-installed"
failure_app="${failure_install_root}/application/DBCode Wrapper.app"
failure_manifest="${failure_install_root}/application/build-manifest.json"
failure_user_data="${failure_install_root}/profile/user-data"
failure_extensions="${failure_install_root}/profile/extensions"
failure_shared_data="${failure_install_root}/profile/shared-data"
failure_state_root="${failure_install_root}/upgrade-state"
failure_previous_root="${failure_install_root}/previous"
failure_layout="${test_root}/failure-install-layout.json"
mkdir -p "$(dirname "${failure_app}")" "$(dirname "${failure_user_data}")"
ditto "${prepared_current_set}/DBCode Wrapper.app" "${failure_app}"
cp "${prepared_current_set}/build-manifest.json" "${failure_manifest}"
ditto "${prepared_current_set}/profile/user-data" "${failure_user_data}"
ditto "${prepared_current_set}/profile/extensions" "${failure_extensions}"
ditto "${prepared_current_set}/profile/shared-data" "${failure_shared_data}"
jq -n \
  --arg app "${failure_app}" \
  --arg manifest "${failure_manifest}" \
  --arg user_data "${failure_user_data}" \
  --arg extensions "${failure_extensions}" \
  --arg shared_data "${failure_shared_data}" \
  --arg state_root "${failure_state_root}" \
  --arg previous_root "${failure_previous_root}" '
    {
      schema_version: 1,
      targets: {app: $app, build_manifest: $manifest, user_data: $user_data, extensions: $extensions, shared_data: $shared_data},
      state_root: $state_root,
      previous_root: $previous_root
    }
  ' > "${failure_layout}"

if DBCODE_WRAPPER_TEST_FAIL_AFTER_SWAP=3 \
  "${upgrade_script}" promote \
    --current-set "${prepared_current_set}/release-set.json" \
    --candidate-set "${prepared_set}/release-set.json" \
    --matrix "${promotion_matrix}" \
    --layout "${failure_layout}" \
    --confirm-release-set "${fixture_release_id}" >/dev/null 2>&1; then
  echo "The injected promotion failure unexpectedly succeeded." >&2
  exit 1
fi
[[ "$(artifact_digest "${failure_app}")" == "${current_fixture_app_sha}" ]] || {
  echo "A failed promotion did not restore the current app." >&2
  exit 1
}
cmp -s "${prepared_current_set}/build-manifest.json" "${failure_manifest}" || {
  echo "A failed promotion did not restore the current manifest." >&2
  exit 1
}
[[ -f "${failure_extensions}/dbcode.dbcode-1.36.1/package.json" ]] || {
  echo "A failed promotion did not restore the current extension root." >&2
  exit 1
}
[[ "$(cat "${failure_user_data}/User/globalStorage/state.vscdb")" == "current-profile" ]] || {
  echo "A failed promotion did not restore current user data." >&2
  exit 1
}
[[ "$(cat "${failure_shared_data}/sharedStorage/state.vscdb")" == "current-shared" ]] || {
  echo "A failed promotion did not restore current shared data." >&2
  exit 1
}
jq -e '.status == "restored-after-failed-promotion"' \
  "${failure_state_root}/promotion-transaction.json" >/dev/null || {
  echo "The failed promotion did not record its automatic restoration." >&2
  exit 1
}
if find "${failure_install_root}" \( -name '*.incoming-*' -o -name '*.outgoing-*' -o -name '*.failed-*' \) -print -quit | grep -q .; then
  echo "The failed promotion left a partial transaction beside the installed set." >&2
  exit 1
fi

if DBCODE_WRAPPER_TEST_FAIL_AFTER_TARGET_MOVE=2 \
  "${upgrade_script}" promote \
    --current-set "${prepared_current_set}/release-set.json" \
    --candidate-set "${prepared_set}/release-set.json" \
    --matrix "${promotion_matrix}" \
    --layout "${failure_layout}" \
    --confirm-release-set "${fixture_release_id}" >/dev/null 2>&1; then
  echo "The injected half-swap promotion failure unexpectedly succeeded." >&2
  exit 1
fi
[[ "$(artifact_digest "${failure_app}")" == "${current_fixture_app_sha}" ]] || {
  echo "A half-swap failure did not restore the moved current app." >&2
  exit 1
}
cmp -s "${prepared_current_set}/build-manifest.json" "${failure_manifest}" || {
  echo "A half-swap failure did not restore the moved current manifest." >&2
  exit 1
}
[[ -f "${failure_extensions}/dbcode.dbcode-1.36.1/package.json" ]] || {
  echo "A half-swap failure did not preserve the current extension root." >&2
  exit 1
}
if find "${failure_install_root}" \( -name '*.incoming-*' -o -name '*.outgoing-*' -o -name '*.failed-*' \) -print -quit | grep -q .; then
  echo "The half-swap failure left a partial transaction beside the installed set." >&2
  exit 1
fi

if DBCODE_WRAPPER_STATIC_GATE="${static_gate}" \
  DBCODE_WRAPPER_RUNTIME_GATE="${runtime_gate}" \
  DBCODE_WRAPPER_TEST_MUTATE_APP="yes" \
  "${combination_checker}" \
    --combination H1/D1 \
    --host-set "${prepared_set}/release-set.json" \
    --dbcode-set "${prepared_set}/release-set.json" \
    --output "${test_root}/mutated-combination.json" >/dev/null 2>&1; then
  echo "The release-combination gate accepted an app modified during its runtime check." >&2
  exit 1
fi

echo "Controlled-upgrade compatibility matrix contracts passed."
