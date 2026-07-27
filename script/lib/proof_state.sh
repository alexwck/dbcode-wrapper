#!/usr/bin/env bash

set -euo pipefail

proof_state_legacy_manual_checks_json() {
  jq -cn '[
    "activation",
    "credential_reentry",
    "update_discovery",
    "postgresql",
    "duckdb",
    "parquet",
    "persistence"
  ]'
}

proof_state_required_manual_checks_json() {
  proof_state_legacy_manual_checks_json |
    jq -c '.[:4] + ["debugger"] + .[4:]'
}

proof_state_pending_manual_checks_json() {
  proof_state_required_manual_checks_json |
    jq -c 'reduce .[] as $check ({}; .[$check] = {status: "pending"})'
}

proof_state_canonical_extension_inventory() {
  LC_ALL=C sort
}

proof_state_candidate_manifest_identity_sha256() {
  local manifest_file="$1"
  jq -S -c '
    del(
      .built_at_utc,
      .source.repository_revision,
      .source.overlay_sha256,
      .artifact.cryptographic_update_identity_stable,
      .artifact.signing_continuity_evidence,
      .artifact.signing_continuity_receipt_sha256,
      .artifact.safe_storage_access_stable_across_rebuilds,
      .artifact.safe_storage_rebuild_behavior
    )
  ' "${manifest_file}" |
    shasum -a 256 |
    awk '{print $1}'
}

proof_state_refresh_release_set() {
  local evidence_file="$1"
  local snapshot_file="$2"
  local checked_at="$3"
  local output_file="$4"

  jq \
    --arg checked_at "${checked_at}" \
    --argjson pending_manual_checks "$(proof_state_pending_manual_checks_json)" \
    --slurpfile snapshot "${snapshot_file}" '
      $snapshot[0] as $current
      | def host_identity: {
          app_name,
          bundle_identifier,
          app_sha256,
          release_set_id,
          signature_requirement,
          focused_shell
        };
      def manifest_identity_changed($existing; $current):
        ($existing.candidate_manifest_identity_sha256 // "") as $existing_identity
        | ($current.candidate_manifest_identity_sha256 // "") as $current_identity
        | if $existing_identity != "" and $current_identity != "" then
            $existing_identity != $current_identity
          elif $existing_identity == "" and $current_identity == "" then
            ($existing.candidate_manifest_sha256 // "") != ($current.candidate_manifest_sha256 // "")
          elif $existing_identity == "" then
            ($existing.candidate_manifest_sha256 // "") != ($current.candidate_manifest_sha256 // "")
          else
            true
          end;
      def canonical_dbcode_inventory:
        if type == "object"
            and has("installed_extensions")
            and (.installed_extensions | type) == "string"
          then
            .installed_extensions |= (split("\n") | sort | join("\n"))
          else
            .
          end;
      if (.release_set_under_test // null) == null
          and (.approved_release_set // null) != null
          and .status != "passed"
        then
          .release_set_under_test = .approved_release_set
          | del(.approved_release_set, .approved_release_set_checked_at)
        else . end
      | (.release_set_under_test // .approved_release_set // {}) as $existing_release_set
      | (
          (($existing_release_set.host | host_identity) != ($current.host | host_identity))
          or manifest_identity_changed($existing_release_set.host; $current.host)
          or (($existing_release_set.dbcode | canonical_dbcode_inventory) != ($current.dbcode | canonical_dbcode_inventory))
        ) as $release_set_changed
      | if $release_set_changed then
          if .status == "passed" and (.approved_release_set // null) != null then
            .previous_approved_release_set = .approved_release_set
          else . end
          | .release_set_under_test = {
              host: (($existing_release_set.host // {}) + $current.host),
              dbcode: $current.dbcode
            }
          | .status = "awaiting-manual-checks"
          | .prepared_at = $checked_at
          | del(.completed_at, .active_launch, .last_complete_quit, .last_complete_quit_at)
          | .launches = []
          | .complete_quits = []
          | .manual_check_schema_version = 2
          | .manual_checks = $pending_manual_checks
        else
          .
        end
      | .release_set_checked_at = $checked_at
      | if .status == "passed" and (.release_set_under_test // null) == null then
          .approved_release_set.host = (.approved_release_set.host + $current.host)
          | .approved_release_set.dbcode = $current.dbcode
        else
          .release_set_under_test.host = (.release_set_under_test.host + $current.host)
          | .release_set_under_test.dbcode = $current.dbcode
        end
      | .isolation = $current.isolation
      | .fixtures = $current.fixtures
      | if .status != "passed" and (.manual_checks | has("debugger"))
        then .manual_check_schema_version = 2
        else . end
    ' "${evidence_file}" > "${output_file}"
}

proof_state_promote_release_set() {
  local evidence_file="$1"
  local completed_at="$2"
  local output_file="$3"

  jq \
    --arg completed_at "${completed_at}" '
      if (.release_set_under_test // null) == null then
        error("No candidate release set is available for promotion.")
      else . end
      | if (.approved_release_set // null) != null
          and .approved_release_set != .release_set_under_test
        then .previous_approved_release_set = .approved_release_set
        else . end
      | .approved_release_set = .release_set_under_test
      | del(.release_set_under_test)
      | .status = "passed"
      | .completed_at = $completed_at
    ' "${evidence_file}" > "${output_file}"
}

proof_state_migrate_quit_history() {
  local evidence_file="$1"
  local output_file="$2"

  jq '
    if (.schema_version // 4) >= 5 then
      .
    else
      (.active_launch // {}) as $active
      | ([.launches[]? | select(.id == $active.previous_launch_id)][0] // {}) as $previous
      | (.last_complete_quit // {}) as $last_quit
      | .schema_version = 5
      | .complete_quits = (
          if (($last_quit.after_launch_id // "") | length) > 0 then [$last_quit] else [] end
        )
      | if $active.kind == "relaunch"
          and (($active.previous_launch_id // "") | length) > 0
          and $previous.id == $active.previous_launch_id
          and (($previous.ready_at // "") | length) > 0
          and (($active.launched_at // "") | length) > 0
        then
          (
            if $last_quit.after_launch_id == $active.previous_launch_id then
              $last_quit
            else
              {
                after_launch_id: $active.previous_launch_id,
                verified_before_relaunch_at: $active.launched_at,
                evidence: "validated-by-schema-4-relaunch-transition"
              }
            end
          ) as $previous_quit
          | .active_launch.previous_complete_quit = $previous_quit
          | .launches = [
              .launches[]
              | if .id == $active.id then . + {previous_complete_quit: $previous_quit} else . end
            ]
        else . end
    end
  ' "${evidence_file}" > "${output_file}"
}

proof_state_is_complete() {
  local evidence_file="$1"
  local gate_mode="$2"
  local debugger_required
  local expected_manual_check_schema
  local required_checks
  case "${gate_mode}" in
    current)
      debugger_required="true"
      expected_manual_check_schema="2"
      required_checks="$(proof_state_required_manual_checks_json)"
      ;;
    historical)
      debugger_required="false"
      expected_manual_check_schema="1"
      required_checks="$(proof_state_legacy_manual_checks_json)"
      ;;
    *)
      echo "Unknown proof gate mode: ${gate_mode}" >&2
      return 2
      ;;
  esac

  jq -e \
    --argjson required_checks "${required_checks}" \
    --argjson debugger_required "${debugger_required}" \
    --argjson expected_manual_check_schema "${expected_manual_check_schema}" '
    . as $root
    | ($root.active_launch // {}) as $active
    | ($root.fixtures.postgresql_debugger // {}) as $debugger_fixture
    | ([$root.launches[]? | select(.id == $active.previous_launch_id)][0] // {}) as $previous
    | ($active.previous_complete_quit // {}) as $previous_quit
    | (
        [$root.complete_quits[]? | select(.after_launch_id == $active.id)][0]
        // (if ($root.last_complete_quit.after_launch_id // "") == ($active.id // "")
              then $root.last_complete_quit else {} end)
      ) as $active_quit
    | ($active.kind == "relaunch")
      and (($active.id // "") | length > 0)
      and (($active.previous_launch_id // "") | length > 0)
      and (($active.launched_at // "") | length > 0)
      and (($active.ready_at // "") >= $active.launched_at)
      and ($previous.id == $active.previous_launch_id)
      and ($previous.kind == "launch")
      and (($previous.normal_profile_before // "") | length > 0)
      and (($active.normal_profile_before // "") | length > 0)
      and (($previous.ready_at // "") >= ($previous.launched_at // ""))
      and ($previous_quit.after_launch_id == $active.previous_launch_id)
      and (
        (
          (($previous_quit.quit_at // "") | length > 0)
          and ($previous.ready_at <= $previous_quit.quit_at)
          and ($previous_quit.quit_at < $active.launched_at)
        )
        or (
          $previous_quit.evidence == "validated-by-schema-4-relaunch-transition"
          and $previous_quit.verified_before_relaunch_at == $active.launched_at
          and ($previous.ready_at < $active.launched_at)
        )
      )
      and ($active_quit.after_launch_id == $active.id)
      and (($active_quit.quit_at // "") | length > 0)
      and ($active.ready_at <= $active_quit.quit_at)
      and ([$root.launches[]? | select(.kind == "launch")] | length > 0)
      and ([$root.launches[]?.id] | index($active.id) != null)
      and (($root.manual_check_schema_version // 1) == $expected_manual_check_schema)
      and (
        if $debugger_required then
          ($debugger_fixture.address == "127.0.0.1:55434/dbcode_debugger_proof")
          and ($debugger_fixture.image
            | test("^localhost/dbcode-wrapper-postgres-debugger:17[.]4-pldebugger-1[.]10@sha256:[0-9a-f]{64}$"))
          and ($debugger_fixture.base_image
            == "docker.io/library/postgres:17.4-bookworm@sha256:304ab813518754228f9f792f79d6da36359b82d8ecf418096c636725f8c930ad")
          and ($debugger_fixture.package == "postgresql-17-pldebugger=1:1.10-1.pgdg12+1")
          and ($debugger_fixture.containerfile_sha256 | test("^[0-9a-f]{64}$"))
          and ($debugger_fixture.seed_sha256 | test("^[0-9a-f]{64}$"))
          and ($debugger_fixture.server_enforced_loopback == true)
          and ($debugger_fixture.authentication == "local-loopback-test-fixture")
          and ($debugger_fixture.shared_preload_libraries
            | split(",") | map(gsub("^ +| +$"; "")) | index("plugin_debugger") != null)
          and ($debugger_fixture.extension == {name: "pldbgapi", version: "1.1"})
          and ($debugger_fixture.routine == {
            schema: "debugger_proof",
            name: "calculate_total",
            language: "plpgsql",
            owner: "dbcode_debugger",
            owner_is_superuser: false,
            arguments: [5, 3],
            expected_result: 22
          })
        else
          true
        end
      )
      and (($root.manual_checks | keys | sort) == ($required_checks | sort))
      and ([
        $required_checks[] as $check
        | ($root.manual_checks[$check] // {}) as $manual
        | ($manual.status == "passed")
          and ($manual.launch_id == $active.id)
          and ($manual.launch_kind == "relaunch")
          and (($manual.recorded_at // "") >= $active.ready_at)
          and (($manual.note // "") | length > 0)
          and (($manual.expected_result // "") | length > 0)
      ] | all)
  ' "${evidence_file}" >/dev/null
}

proof_state_is_finalizable() {
  proof_state_is_complete "$1" current
}

proof_state_is_runtime_usable() {
  local evidence_file="$1"
  local expected_dbcode_version="$2"
  local evidence_dbcode_version
  local manual_check_schema
  evidence_dbcode_version="$(
    jq -er '.approved_release_set.dbcode.version // .release_set_under_test.dbcode.version' \
      "${evidence_file}"
  )" || return 1
  [[ "${evidence_dbcode_version}" == "${expected_dbcode_version}" ]] || return 1
  manual_check_schema="$(jq -er '.manual_check_schema_version // 1' "${evidence_file}")" || return 1

  case "${manual_check_schema}" in
    2)
      proof_state_is_complete "${evidence_file}" current
      ;;
    1)
      case "${expected_dbcode_version}" in
        1.36.1|1.36.2) proof_state_is_complete "${evidence_file}" historical ;;
        *) return 1 ;;
      esac
      ;;
    *)
      return 1
      ;;
  esac
}
