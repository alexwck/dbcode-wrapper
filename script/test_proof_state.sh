#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/proof_state.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/profile_guard.sh"

proof_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/proof_dbcode.sh"
if rg -Fq '."dbcode.connections"' "${proof_script}"; then
  echo "The proof must not depend on an undocumented DBCode settings key." >&2
  exit 1
fi

test_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-wrapper-proof-state.XXXXXX")"
cleanup_test_root() {
  rm -rf "${test_root}"
}
trap cleanup_test_root EXIT INT TERM

manifest_identity_a="${test_root}/manifest-identity-a.json"
manifest_identity_b="${test_root}/manifest-identity-b.json"
manifest_identity_changed="${test_root}/manifest-identity-changed.json"
jq -n '{
  schema_version: 5,
  built_at_utc: "2026-07-18T00:00:00Z",
  release: {release_set_id: "release-a", compatibility_status: "candidate"},
  source: {
    repository_revision: "commit-a",
    overlay_sha256: "overlay-a",
    release_lock_sha256: "lock-a",
    code_oss: {tag: "1.126.0", commit: "code-a"}
  },
  runtime: {electron: "39.8.1"},
  runtime_extensions: [{id: "dbcode.dbcode", version: "1.36.2"}],
  profile: {schema_version: 2},
  packaging: {status: "built-and-signed"},
  artifact: {
    sha256: "app-a",
    bundle_identifier: "io.alexabelle.dbcodewrapper",
    cryptographic_update_identity_stable: null,
    signing_continuity_evidence: "pending-rebuilt-release-comparison",
    signing_continuity_receipt_sha256: null,
    safe_storage_access_stable_across_rebuilds: null,
    safe_storage_rebuild_behavior: "pending-manual-rebuild-observation"
  }
}' > "${manifest_identity_a}"
jq '
  .built_at_utc = "2026-07-20T00:00:00Z"
  | .source.repository_revision = "commit-b"
  | .source.overlay_sha256 = "overlay-b"
  | .artifact.cryptographic_update_identity_stable = true
  | .artifact.signing_continuity_evidence = "verified-distinct-rebuilt-artifacts"
  | .artifact.signing_continuity_receipt_sha256 = "continuity-a"
  | .artifact.safe_storage_access_stable_across_rebuilds = false
  | .artifact.safe_storage_rebuild_behavior = "manual-approval-may-repeat-after-host-rebuild"
' "${manifest_identity_a}" > "${manifest_identity_b}"
jq '.runtime.electron = "40.0.0"' "${manifest_identity_a}" > "${manifest_identity_changed}"
identity_a="$(proof_state_candidate_manifest_identity_sha256 "${manifest_identity_a}")"
[[ "${identity_a}" == "$(proof_state_candidate_manifest_identity_sha256 "${manifest_identity_b}")" ]] || {
  echo "Bookkeeping-only manifest fields changed the proof identity." >&2
  exit 1
}
[[ "${identity_a}" != "$(proof_state_candidate_manifest_identity_sha256 "${manifest_identity_changed}")" ]] || {
  echo "A runtime manifest change kept the old proof identity." >&2
  exit 1
}

canonical_extension_inventory="$(
  printf '%s\n' \
    'ms-toolsai.jupyter@2025.9.1' \
    'dbcode.dbcode@1.36.2' \
    'ms-toolsai.jupyter-renderers@1.3.0' |
    proof_state_canonical_extension_inventory
)"
expected_extension_inventory=$'dbcode.dbcode@1.36.2\nms-toolsai.jupyter-renderers@1.3.0\nms-toolsai.jupyter@2025.9.1'
[[ "${canonical_extension_inventory}" == "${expected_extension_inventory}" ]] || {
  echo "The proof snapshot did not canonicalize the installed extension inventory." >&2
  exit 1
}

valid_evidence="${test_root}/valid.json"
jq -n '
  ["activation", "credential_reentry", "update_discovery", "postgresql", "duckdb", "parquet", "persistence"] as $checks
  | {
      launches: [
        {id: "launch-1", kind: "launch", launched_at: "2026-07-18T00:00:00Z", ready_at: "2026-07-18T00:00:10Z", normal_profile_before: "normal-profile-a"},
        {id: "launch-2", kind: "relaunch", launched_at: "2026-07-18T00:02:00Z", ready_at: "2026-07-18T00:02:10Z", normal_profile_before: "normal-profile-a"}
      ],
      complete_quits: [
        {after_launch_id: "launch-1", quit_at: "2026-07-18T00:01:00Z"},
        {after_launch_id: "launch-2", quit_at: "2026-07-18T00:04:00Z"}
      ],
      last_complete_quit: {
        after_launch_id: "launch-2",
        quit_at: "2026-07-18T00:04:00Z"
      },
      active_launch: {
        id: "launch-2",
        kind: "relaunch",
        previous_launch_id: "launch-1",
        previous_complete_quit: {after_launch_id: "launch-1", quit_at: "2026-07-18T00:01:00Z"},
        launched_at: "2026-07-18T00:02:00Z",
        ready_at: "2026-07-18T00:02:10Z",
        normal_profile_before: "normal-profile-a"
      },
      manual_checks: (reduce $checks[] as $check ({};
        .[$check] = {
          status: "passed",
          launch_id: "launch-2",
          launch_kind: "relaunch",
          recorded_at: "2026-07-18T00:03:00Z",
          note: "Observed expected result.",
          expected_result: "Expected result contract."
        }
      ))
    }
' > "${valid_evidence}"

proof_state_is_finalizable "${valid_evidence}" || {
  echo "A complete launch, quit, relaunch, and fresh-check sequence was rejected." >&2
  exit 1
}

assert_rejected() {
  local label="$1"
  local filter="$2"
  local invalid_evidence="${test_root}/${label}.json"
  jq "${filter}" "${valid_evidence}" > "${invalid_evidence}"
  if proof_state_is_finalizable "${invalid_evidence}"; then
    echo "The proof validator accepted ${label}." >&2
    exit 1
  fi
}

assert_rejected "an active first launch" '.active_launch.kind = "launch"'
assert_rejected "an initial quit tied to another launch" '.active_launch.previous_complete_quit.after_launch_id = "wrong-launch"'
assert_rejected "an initial quit before its launch" '.active_launch.previous_complete_quit.quit_at = "2026-07-17T23:59:00Z"'
assert_rejected "a missing final quit" 'del(.complete_quits[1], .last_complete_quit)'
assert_rejected "a final quit before relaunch readiness" '.complete_quits[1].quit_at = "2026-07-18T00:02:05Z" | .last_complete_quit.quit_at = "2026-07-18T00:02:05Z"'
assert_rejected "an unready initial launch" 'del(.launches[0].ready_at)'
assert_rejected "an unready relaunch" 'del(.active_launch.ready_at)'
assert_rejected "an initial launch without a normal-profile snapshot" 'del(.launches[0].normal_profile_before)'
assert_rejected "a relaunch without a normal-profile snapshot" 'del(.active_launch.normal_profile_before)'
assert_rejected "a stale manual check" '.manual_checks.duckdb.launch_id = "launch-1"'
assert_rejected "an empty manual note" '.manual_checks.parquet.note = ""'
assert_rejected "a check recorded before relaunch" '.manual_checks.postgresql.recorded_at = "2026-07-18T00:01:30Z"'
assert_rejected "missing protected-credential re-entry evidence" 'del(.manual_checks.credential_reentry)'
assert_rejected "missing update-discovery evidence" 'del(.manual_checks.update_discovery)'

legacy_evidence="${test_root}/legacy-schema-4.json"
migrated_legacy_evidence="${test_root}/migrated-schema-5.json"
jq '
  .schema_version = 4
  | del(.complete_quits, .active_launch.previous_complete_quit)
  | .launches = [.launches[] | del(.previous_complete_quit)]
' "${valid_evidence}" > "${legacy_evidence}"
proof_state_migrate_quit_history "${legacy_evidence}" "${migrated_legacy_evidence}"
jq -e '
  .schema_version == 5
  and .active_launch.previous_complete_quit == {
    after_launch_id: "launch-1",
    verified_before_relaunch_at: "2026-07-18T00:02:00Z",
    evidence: "validated-by-schema-4-relaunch-transition"
  }
  and .complete_quits == [{after_launch_id: "launch-2", quit_at: "2026-07-18T00:04:00Z"}]
' "${migrated_legacy_evidence}" >/dev/null || {
  echo "Schema 4 evidence did not preserve its validated relaunch transition during migration." >&2
  exit 1
}
proof_state_is_finalizable "${migrated_legacy_evidence}" || {
  echo "Migrated schema 4 evidence was rejected after preserving both proof transitions." >&2
  exit 1
}

profile_host_log="${test_root}/private-profile-host.log"
user_home_dir="$(current_user_home)"
touch "${profile_host_log}"
record_private_profile_paths \
  "${profile_host_log}" \
  "${user_home_dir}/Library/Application Support/${APP_NAME}" \
  "${user_home_dir}/${SHARED_DATA_FOLDER_NAME}" \
  "${user_home_dir}/${DATA_FOLDER_NAME}/extensions"
external_activity_evidence="$(
  normal_profile_external_activity_evidence \
    "${profile_host_log}" \
    $'Code\nCode Helper'
)"
jq -e '
  .normal_profiles_unchanged == false
  and .dbcode_wrapper_private_paths_verified == true
  and .normal_profile_activity == {
    attribution: "external-editor-processes",
    owners: ["Code", "Code Helper"]
  }
' <<<"${external_activity_evidence}" >/dev/null || {
  echo "External VS Code activity was not recorded as separate from DBCode Wrapper." >&2
  exit 1
}
if normal_profile_external_activity_evidence \
  "${profile_host_log}" \
  "DBCode Wrapper" >/dev/null 2>&1; then
  echo "The profile guard attributed normal-profile activity to DBCode Wrapper itself." >&2
  exit 1
fi
printf '%s\n' \
  "Normal profile: ${user_home_dir}/Library/Application Support/Code/User/state.vscdb" \
  >> "${profile_host_log}"
if normal_profile_external_activity_evidence \
  "${profile_host_log}" \
  "Code" >/dev/null 2>&1; then
  echo "The profile guard accepted a DBCode Wrapper log that referenced a normal editor profile." >&2
  exit 1
fi

profile_changed_while_closed="${test_root}/profile-changed-while-closed.json"
jq '.active_launch.normal_profile_before = "normal-profile-b"' "${valid_evidence}" > "${profile_changed_while_closed}"
proof_state_is_finalizable "${profile_changed_while_closed}" || {
  echo "The proof validator must allow an external editor to change its own profile while DBCode Wrapper is closed." >&2
  exit 1
}

release_evidence="${test_root}/release-evidence.json"
release_snapshot="${test_root}/release-snapshot.json"
refreshed_release="${test_root}/refreshed-release.json"
jq '. + {
  status: "passed",
  completed_at: "2026-07-18T00:04:00Z",
  release_set_under_test: {
    host: {
      app_name: "DBCode Wrapper",
      app_sha256: "old-app",
      release_set_id: "old-release",
      candidate_manifest_sha256: "old-manifest",
      vscodium: {tag: "1.126.04524", commit: "vscodium-commit"},
      code_oss: {tag: "1.126.0", commit: "code-commit"}
    },
    dbcode: {id: "dbcode.dbcode", version: "1.36.1", vsix_sha256: "old-dbcode", installed_extensions: "dbcode.dbcode@1.36.1"}
  }
}' "${valid_evidence}" > "${release_evidence}"
jq -n '{
  host: {
    app_name: "DBCode Wrapper",
    app_sha256: "new-app",
    release_set_id: "new-release",
    candidate_manifest_sha256: "new-manifest"
  },
  dbcode: {id: "dbcode.dbcode", version: "1.36.2", vsix_sha256: "new-dbcode", installed_extensions: "dbcode.dbcode@1.36.2"},
  isolation: {profile_root: {path: "/private/profile", mode: "700"}},
  fixtures: {duckdb: {path: "/private/proof.duckdb"}}
}' > "${release_snapshot}"
proof_state_refresh_release_set \
  "${release_evidence}" \
  "${release_snapshot}" \
  "2026-07-20T00:00:00Z" \
  "${refreshed_release}"
jq -e '
  .status == "awaiting-manual-checks"
  and .prepared_at == "2026-07-20T00:00:00Z"
  and .release_set_checked_at == "2026-07-20T00:00:00Z"
  and .release_set_under_test.host.app_sha256 == "new-app"
  and .release_set_under_test.host.release_set_id == "new-release"
  and .release_set_under_test.host.candidate_manifest_sha256 == "new-manifest"
  and .release_set_under_test.host.vscodium.commit == "vscodium-commit"
  and .release_set_under_test.host.code_oss.commit == "code-commit"
  and .release_set_under_test.dbcode.version == "1.36.2"
  and (.approved_release_set | not)
  and .launches == []
  and (.active_launch | not)
  and (.last_complete_quit | not)
  and (.completed_at | not)
  and (.manual_checks | keys) == ["activation", "credential_reentry", "duckdb", "parquet", "persistence", "postgresql", "update_discovery"]
  and all(.manual_checks[]; .status == "pending" and (keys == ["status"]))
' "${refreshed_release}" >/dev/null || {
  echo "A changed host or DBCode release set inherited stale proof evidence." >&2
  exit 1
}

manifest_change_snapshot="${test_root}/manifest-change-snapshot.json"
manifest_change_result="${test_root}/manifest-change-result.json"
jq -n '{
  host: {
    app_name: "DBCode Wrapper",
    app_sha256: "old-app",
    release_set_id: "new-source-release",
    candidate_manifest_sha256: "new-candidate-manifest"
  },
  dbcode: {id: "dbcode.dbcode", version: "1.36.1", vsix_sha256: "old-dbcode", installed_extensions: "dbcode.dbcode@1.36.1"},
  isolation: {profile_root: {path: "/private/profile", mode: "700"}},
  fixtures: {duckdb: {path: "/private/proof.duckdb"}}
}' > "${manifest_change_snapshot}"
proof_state_refresh_release_set \
  "${release_evidence}" \
  "${manifest_change_snapshot}" \
  "2026-07-20T00:30:00Z" \
  "${manifest_change_result}"
jq -e '
  .status == "awaiting-manual-checks"
  and .release_set_under_test.host.app_sha256 == "old-app"
  and .release_set_under_test.host.release_set_id == "new-source-release"
  and .release_set_under_test.host.candidate_manifest_sha256 == "new-candidate-manifest"
  and all(.manual_checks[]; .status == "pending")
' "${manifest_change_result}" >/dev/null || {
  echo "A changed release-set identity inherited stale proof evidence." >&2
  exit 1
}

metadata_refresh_evidence="${test_root}/metadata-refresh-evidence.json"
metadata_refresh_snapshot="${test_root}/metadata-refresh-snapshot.json"
metadata_refresh_result="${test_root}/metadata-refresh-result.json"
jq '. + {
  status: "passed",
  completed_at: "2026-07-18T00:04:00Z",
  approved_release_set: {
    host: {
      app_name: "DBCode Wrapper",
      bundle_identifier: "io.alexabelle.dbcodewrapper",
      app_sha256: "approved-app",
      release_set_id: "approved-release",
      candidate_manifest_sha256: "old-candidate-manifest",
      candidate_manifest_identity_sha256: "approved-manifest-identity"
    },
    dbcode: {
      id: "dbcode.dbcode",
      version: "1.36.2",
      vsix_sha256: "approved-dbcode",
      installed_extensions: "dbcode.dbcode@1.36.2\nms-python.python@2026.4.0\nms-toolsai.jupyter@2025.9.1\nms-toolsai.jupyter-keymap@1.1.2\nms-toolsai.jupyter-renderers@1.3.0\nms-toolsai.vscode-jupyter-cell-tags@0.1.9\nms-toolsai.vscode-jupyter-slideshow@0.1.6"
    }
  }
}' "${valid_evidence}" > "${metadata_refresh_evidence}"
jq -n '{
  host: {
    app_name: "DBCode Wrapper",
    bundle_identifier: "io.alexabelle.dbcodewrapper",
    app_sha256: "approved-app",
    release_set_id: "approved-release",
    candidate_manifest_sha256: "new-candidate-manifest",
    candidate_manifest_identity_sha256: "approved-manifest-identity"
  },
  dbcode: {
    id: "dbcode.dbcode",
    version: "1.36.2",
    vsix_sha256: "approved-dbcode",
    installed_extensions: "dbcode.dbcode@1.36.2\nms-python.python@2026.4.0\nms-toolsai.jupyter-keymap@1.1.2\nms-toolsai.jupyter-renderers@1.3.0\nms-toolsai.jupyter@2025.9.1\nms-toolsai.vscode-jupyter-cell-tags@0.1.9\nms-toolsai.vscode-jupyter-slideshow@0.1.6"
  },
  isolation: {profile_root: {path: "/private/profile", mode: "700"}},
  fixtures: {duckdb: {path: "/private/proof.duckdb"}}
}' > "${metadata_refresh_snapshot}"
proof_state_refresh_release_set \
  "${metadata_refresh_evidence}" \
  "${metadata_refresh_snapshot}" \
  "2026-07-20T00:45:00Z" \
  "${metadata_refresh_result}"
jq -e '
  .status == "passed"
  and .completed_at == "2026-07-18T00:04:00Z"
  and .release_set_checked_at == "2026-07-20T00:45:00Z"
  and .approved_release_set.host.candidate_manifest_sha256 == "new-candidate-manifest"
  and (.release_set_under_test | not)
  and (.previous_approved_release_set | not)
  and (.launches | length) == 2
  and all(.manual_checks[]; .status == "passed" and .launch_id == "launch-2")
' "${metadata_refresh_result}" >/dev/null || {
  echo "A metadata-only candidate manifest refresh discarded approved proof evidence." >&2
  exit 1
}

duplicate_extension_snapshot="${test_root}/duplicate-extension-snapshot.json"
duplicate_extension_result="${test_root}/duplicate-extension-result.json"
jq '.dbcode.installed_extensions += "\nms-toolsai.jupyter@2025.9.1"' \
  "${metadata_refresh_snapshot}" > "${duplicate_extension_snapshot}"
proof_state_refresh_release_set \
  "${metadata_refresh_evidence}" \
  "${duplicate_extension_snapshot}" \
  "2026-07-20T00:47:00Z" \
  "${duplicate_extension_result}"
jq -e '
  .status == "awaiting-manual-checks"
  and (.release_set_under_test.dbcode.installed_extensions
    | split("\n")
    | map(select(. == "ms-toolsai.jupyter@2025.9.1"))
    | length) == 2
  and all(.manual_checks[]; .status == "pending")
' "${duplicate_extension_result}" >/dev/null || {
  echo "Canonical extension comparison concealed a duplicate extension." >&2
  exit 1
}

manifest_identity_change_snapshot="${test_root}/manifest-identity-change-snapshot.json"
manifest_identity_change_result="${test_root}/manifest-identity-change-result.json"
jq '.host.candidate_manifest_identity_sha256 = "changed-manifest-identity"' \
  "${metadata_refresh_snapshot}" > "${manifest_identity_change_snapshot}"
proof_state_refresh_release_set \
  "${metadata_refresh_result}" \
  "${manifest_identity_change_snapshot}" \
  "2026-07-20T00:50:00Z" \
  "${manifest_identity_change_result}"
jq -e '
  .status == "awaiting-manual-checks"
  and .release_set_under_test.host.candidate_manifest_identity_sha256 == "changed-manifest-identity"
  and all(.manual_checks[]; .status == "pending")
' "${manifest_identity_change_result}" >/dev/null || {
  echo "A changed canonical candidate manifest identity inherited approved proof evidence." >&2
  exit 1
}

promoted_release="${test_root}/promoted-release.json"
proof_state_promote_release_set \
  "${refreshed_release}" \
  "2026-07-20T01:00:00Z" \
  "${promoted_release}"
jq -e '
  .status == "passed"
  and .completed_at == "2026-07-20T01:00:00Z"
  and .approved_release_set.dbcode.version == "1.36.2"
  and (.release_set_under_test | not)
' "${promoted_release}" >/dev/null || {
  echo "A passing candidate was not promoted to the approved release set." >&2
  exit 1
}

echo "Proof state requires a complete quit, relaunch, and fresh evidence for every check."
