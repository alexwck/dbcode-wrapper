#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/artifact_digest.sh"
source "${REPO_ROOT}/script/lib/profile_guard.sh"
source "${REPO_ROOT}/script/lib/profile_paths.sh"
source "${REPO_ROOT}/script/lib/proof_state.sh"
source "${REPO_ROOT}/script/lib/local_signing_identity.sh"
source "${REPO_ROOT}/script/lib/host_session.sh"
source "${REPO_ROOT}/script/lib/generated_workspace.sh"
source "${REPO_ROOT}/script/lib/postgres_debugger_fixture.sh"

proof_parent="$(generated_workspace_path "proof-evidence")"
proof_root="${proof_parent}/dbcode-wrapper"
generated_workspace_assert_path "proof-evidence" "${proof_root}"
workspace_root="${proof_root}/workspace"
evidence_root="${proof_root}/evidence"
evidence_file="${evidence_root}/proof-state.json"
fixture_venv="${proof_root}/fixture-venv"
resolve_profile_paths default
profile_layout_assert_mutable state user_data extensions shared_data backup cache logs
profile_root="${PROFILE_STATE_ROOT}"
user_data_root="${PROFILE_USER_DATA_ROOT}"
extensions_root="${PROFILE_EXTENSIONS_ROOT}"
shared_data_root="${PROFILE_SHARED_DATA_ROOT}"
cache_root="${PROFILE_CACHE_ROOT}"
logs_root="${PROFILE_LOG_ROOT}"

postgres_container="dbcode-wrapper-proof-postgres"
postgres_image="docker.io/library/postgres:17.4-alpine"
postgres_port="55433"

dbcode_id="${DBCODE_ID}"
dbcode_version="${DBCODE_VERSION}"
postgres_fixture_summary='{}'
duckdb_fixture_summary='{}'

iso_timestamp() {
  date -u +'%Y-%m-%dT%H:%M:%SZ'
}

prepare_postgres() {
  require_command podman

  if ! podman container exists "${postgres_container}"; then
    podman run --detach \
      --name "${postgres_container}" \
      --env POSTGRES_USER=dbcode_proof \
      --env POSTGRES_PASSWORD=dbcode-proof-admin \
      --env POSTGRES_DB=dbcode_proof \
      --publish "127.0.0.1:${postgres_port}:5432" \
      "${postgres_image}" >/dev/null
  elif [[ "$(podman inspect --format '{{.State.Running}}' "${postgres_container}")" != "true" ]]; then
    podman start "${postgres_container}" >/dev/null
  fi

  local ready="no"
  local stable_ready_checks=0
  local attempt
  for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
    if podman exec "${postgres_container}" pg_isready -U dbcode_proof -d dbcode_proof >/dev/null 2>&1; then
      stable_ready_checks=$((stable_ready_checks + 1))
      if [[ ${stable_ready_checks} -ge 3 ]]; then
        ready="yes"
        break
      fi
    else
      stable_ready_checks=0
    fi
    sleep 1
  done
  [[ "${ready}" == "yes" ]] || {
    echo "The PostgreSQL proof container did not become ready." >&2
    exit 1
  }

  local seeded="no"
  for attempt in 1 2 3 4 5; do
    if podman exec -i "${postgres_container}" \
      psql -U dbcode_proof -d dbcode_proof \
      < "${REPO_ROOT}/host/proof/postgres-seed.sql" >/dev/null; then
      seeded="yes"
      break
    fi
    sleep 1
  done
  [[ "${seeded}" == "yes" ]] || {
    echo "The PostgreSQL proof fixture could not be seeded." >&2
    exit 1
  }

  local read_only_state expected_rows
  read_only_state="$(
    podman exec \
      --env PGPASSWORD=dbcode-readonly \
      "${postgres_container}" \
      psql -At -U dbcode_reader -d dbcode_proof -c 'SHOW transaction_read_only;'
  )"
  expected_rows="$(
    podman exec \
      --env PGPASSWORD=dbcode-readonly \
      "${postgres_container}" \
      psql -At -U dbcode_reader -d dbcode_proof \
      -c "SELECT count(*) || '|' || sum(amount) FROM public.proof_items;"
  )"
  [[ "${read_only_state}" == "on" ]] || {
    echo "The PostgreSQL proof account is not server-enforced read-only." >&2
    exit 1
  }
  [[ "${expected_rows}" == "3|75.00" ]] || {
    echo "The PostgreSQL proof fixture has unexpected data: ${expected_rows}" >&2
    exit 1
  }

  postgres_fixture_summary="$(
    jq -cn \
      --arg transaction_read_only "${read_only_state}" \
      --arg result_summary "${expected_rows}" '
        ($result_summary | split("|")) as $result
        | {
            transaction_read_only: $transaction_read_only,
            row_count: ($result[0] | tonumber),
            amount_sum: $result[1]
          }
      '
  )"
}

prepare_duckdb() {
  local allow_fixture_generation="$1"
  require_command python3

  if [[ ! -x "${fixture_venv}/bin/python" ]]; then
    python3 -m venv "${fixture_venv}"
    "${fixture_venv}/bin/python" -m pip install \
      --disable-pip-version-check \
      --quiet \
      duckdb==1.5.4
  fi

  if [[ ! -f "${workspace_root}/STANDALONE_DBCODE_PROOF.duckdb" || ! -f "${workspace_root}/STANDALONE_DBCODE_PROOF.parquet" ]]; then
    [[ "${allow_fixture_generation}" == "yes" ]] || {
      echo "The persisted DuckDB or Parquet proof file is missing during relaunch." >&2
      exit 1
    }
    "${fixture_venv}/bin/python" \
      "${REPO_ROOT}/host/proof/generate_duckdb_fixture.py" \
      "${workspace_root}"
  fi

  duckdb_fixture_summary="$(
    "${fixture_venv}/bin/python" \
      "${REPO_ROOT}/host/proof/verify_duckdb_fixture.py" \
      "${workspace_root}"
  )"
  jq -e '
    .duckdb == {amount_sum: "61.50", first_id: 1, last_id: 3, row_count: 3}
    and .parquet == {amount_sum: "61.50", first_id: 1, last_id: 3, row_count: 3}
  ' <<<"${duckdb_fixture_summary}" >/dev/null

  cp \
    "${REPO_ROOT}/host/proof/postgres-read-only-proof.sql" \
    "${workspace_root}/postgres-read-only-proof.sql"
}

collect_proof_snapshot() {
  local extension_list profile_mode extension_mode cache_mode logs_mode
  local info_plist product_json current_app_sha256 manifest_app_sha256
  local release_set_id candidate_manifest_sha256 candidate_manifest_identity_sha256
  local current_app_name current_bundle_identifier current_signature_requirement
  local current_focused_shell current_narrow_breakpoint
  local host_cli="${APP_BUNDLE}/Contents/Resources/app/bin/${APPLICATION_NAME}"
  info_plist="${APP_BUNDLE}/Contents/Info.plist"
  product_json="${APP_BUNDLE}/Contents/Resources/app/product.json"
  current_app_sha256="$(artifact_digest "${APP_BUNDLE}")"
  manifest_app_sha256="$(jq -er '.artifact.sha256' "${BUILD_MANIFEST}")"
  release_set_id="$(jq -er '.release.release_set_id' "${BUILD_MANIFEST}")"
  candidate_manifest_sha256="$(shasum -a 256 "${BUILD_MANIFEST}" | awk '{print $1}')"
  candidate_manifest_identity_sha256="$(proof_state_candidate_manifest_identity_sha256 "${BUILD_MANIFEST}")"
  [[ "${current_app_sha256}" == "${manifest_app_sha256}" ]] || {
    echo "The launched app does not match the build manifest." >&2
    exit 1
  }
  [[ "$(jq -er '.release.compatibility_status' "${BUILD_MANIFEST}")" == "candidate" ]] || {
    echo "The proof must start from an immutable candidate manifest." >&2
    exit 1
  }
  current_app_name="$(plutil -extract CFBundleName raw "${info_plist}")"
  current_bundle_identifier="$(plutil -extract CFBundleIdentifier raw "${info_plist}")"
  current_signature_requirement="$(codesign -d -r- "${APP_BUNDLE}" 2>&1 | sed -n '/^designated => /p')"
  current_focused_shell="$(jq -er '.dbcodeWrapperFocusedShell' "${product_json}")"
  current_narrow_breakpoint="$(jq -er '.dbcodeWrapperFocusedShellNarrowBreakpoint' "${product_json}")"
  [[ "${current_app_name}" == "${APP_NAME}" ]] || { echo "The proof app has an unexpected name." >&2; exit 1; }
  [[ "${current_bundle_identifier}" == "${BUNDLE_IDENTIFIER}" ]] || { echo "The proof app has an unexpected bundle identifier." >&2; exit 1; }
  load_local_signing_identity
  [[ "${current_signature_requirement}" == "$(local_signing_expected_requirement "${BUNDLE_IDENTIFIER}")" ]] || { echo "The proof app has an unexpected signing identity." >&2; exit 1; }
  verify_local_signed_code "${APP_BUNDLE}" "${BUNDLE_IDENTIFIER}"
  [[ "$(jq -er '.artifact.signature_requirement' "${BUILD_MANIFEST}")" == "${current_signature_requirement}" ]] || { echo "The proof app signing identity does not match the manifest." >&2; exit 1; }
  [[ "${current_focused_shell}" == "true" ]] || { echo "The proof app is not the focused DBCode shell." >&2; exit 1; }
  [[ "${current_narrow_breakpoint}" == "${FOCUSED_SHELL_NARROW_BREAKPOINT}" ]] || { echo "The proof app has an unexpected focused-shell breakpoint." >&2; exit 1; }
  jq -e '
    .artifact.focused_shell.enabled == true
    and .artifact.focused_shell.automatic_result_layout == {wide: "beside", narrow: "below"}
  ' "${BUILD_MANIFEST}" >/dev/null || {
    echo "The candidate manifest does not describe the focused shell under test." >&2
    exit 1
  }
  extension_list="$(
    "${host_cli}" \
      --user-data-dir "${user_data_root}" \
      --extensions-dir "${extensions_root}" \
      --shared-data-dir "${shared_data_root}" \
      --disable-updates \
      --list-extensions \
      --show-versions |
      proof_state_canonical_extension_inventory
  )"
  profile_mode="$(stat -f '%Lp' "${profile_root}")"
  extension_mode="$(stat -f '%Lp' "${extensions_root}")"
  cache_mode="$(stat -f '%Lp' "${cache_root}")"
  logs_mode="$(stat -f '%Lp' "${logs_root}")"

  jq -n \
    --arg app_name "${current_app_name}" \
    --arg bundle_identifier "${current_bundle_identifier}" \
    --arg app_sha256 "${current_app_sha256}" \
    --arg release_set_id "${release_set_id}" \
    --arg candidate_manifest_sha256 "${candidate_manifest_sha256}" \
    --arg candidate_manifest_identity_sha256 "${candidate_manifest_identity_sha256}" \
    --arg signature_requirement "${current_signature_requirement}" \
    --argjson focused_shell "$(jq -c '.artifact.focused_shell' "${BUILD_MANIFEST}")" \
    --arg dbcode_id "${dbcode_id}" \
    --arg dbcode_version "${dbcode_version}" \
    --arg dbcode_sha256 "${DBCODE_SHA256}" \
    --arg signature_sha256 "${DBCODE_SIGNATURE_ARCHIVE_SHA256}" \
    --arg extension_list "${extension_list}" \
    --arg profile_root "${profile_root}" \
    --arg user_data_root "${user_data_root}" \
    --arg extensions_root "${extensions_root}" \
    --arg shared_data_root "${shared_data_root}" \
    --arg cache_root "${cache_root}" \
    --arg logs_root "${logs_root}" \
    --arg profile_mode "${profile_mode}" \
    --arg extension_mode "${extension_mode}" \
    --arg cache_mode "${cache_mode}" \
    --arg logs_mode "${logs_mode}" \
    --arg postgres_image "$(podman inspect --format '{{.ImageName}}@{{.Image}}' "${postgres_container}")" \
    --arg postgres_address "127.0.0.1:${postgres_port}/dbcode_proof" \
    --arg duckdb "${workspace_root}/STANDALONE_DBCODE_PROOF.duckdb" \
    --arg parquet "${workspace_root}/STANDALONE_DBCODE_PROOF.parquet" \
    --argjson postgres_verification "${postgres_fixture_summary}" \
    --argjson postgres_debugger_verification "${postgres_debugger_fixture_summary}" \
    --argjson duckdb_verification "${duckdb_fixture_summary}" '
      {
        host: {
          app_name: $app_name,
          bundle_identifier: $bundle_identifier,
          app_sha256: $app_sha256,
          release_set_id: $release_set_id,
          candidate_manifest_sha256: $candidate_manifest_sha256,
          candidate_manifest_identity_sha256: $candidate_manifest_identity_sha256,
          signature_requirement: $signature_requirement,
          focused_shell: $focused_shell
        },
        dbcode: {
          id: $dbcode_id,
          version: $dbcode_version,
          vsix_sha256: $dbcode_sha256,
          signature_archive_sha256: $signature_sha256,
          installed_extensions: $extension_list
        },
        isolation: {
          profile_root: {path: $profile_root, mode: $profile_mode},
          user_data_root: $user_data_root,
          extensions_root: {path: $extensions_root, mode: $extension_mode},
          shared_data_root: $shared_data_root,
          cache_root: {path: $cache_root, mode: $cache_mode},
          logs_root: {path: $logs_root, mode: $logs_mode}
        },
        fixtures: {
          postgresql: {
            address: $postgres_address,
            image: $postgres_image,
            server_enforced_read_only: true,
            verified_result: $postgres_verification
          },
          postgresql_debugger: $postgres_debugger_verification,
          duckdb: {path: $duckdb, verified_result: $duckdb_verification.duckdb},
          parquet: {path: $parquet, verified_result: $duckdb_verification.parquet}
        }
      }
    '
}

create_evidence_record() {
  if [[ -f "${evidence_file}" ]]; then
    return
  fi

  local snapshot
  snapshot="$(collect_proof_snapshot)"
  jq -n \
    --arg prepared_at "$(iso_timestamp)" \
    --arg vscodium_tag "${VSCODIUM_TAG}" \
    --arg vscodium_commit "${VSCODIUM_COMMIT}" \
    --arg code_oss_tag "${CODE_OSS_TAG}" \
    --arg code_oss_commit "${CODE_OSS_COMMIT}" \
    --argjson pending_manual_checks "$(proof_state_pending_manual_checks_json)" \
    --argjson snapshot "${snapshot}" '
      {
        schema_version: 5,
        manual_check_schema_version: 2,
        status: "awaiting-manual-checks",
        prepared_at: $prepared_at,
        release_set_under_test: {
          host: {
            app_name: $snapshot.host.app_name,
            bundle_identifier: $snapshot.host.bundle_identifier,
            vscodium: {tag: $vscodium_tag, commit: $vscodium_commit},
            code_oss: {tag: $code_oss_tag, commit: $code_oss_commit},
            app_sha256: $snapshot.host.app_sha256,
            release_set_id: $snapshot.host.release_set_id,
            candidate_manifest_sha256: $snapshot.host.candidate_manifest_sha256,
            candidate_manifest_identity_sha256: $snapshot.host.candidate_manifest_identity_sha256,
            signature_requirement: $snapshot.host.signature_requirement,
            focused_shell: $snapshot.host.focused_shell
          },
          dbcode: $snapshot.dbcode
        },
        isolation: $snapshot.isolation,
        fixtures: $snapshot.fixtures,
        launches: [],
        complete_quits: [],
        manual_checks: $pending_manual_checks
      }
    ' > "${evidence_file}"
  chmod 600 "${evidence_file}"
}

refresh_evidence_release_set() {
  [[ -f "${evidence_file}" ]] || return 0

  local evidence_temp snapshot snapshot_file
  snapshot="$(collect_proof_snapshot)"
  snapshot_file="${evidence_file}.snapshot.tmp"
  evidence_temp="${evidence_file}.tmp"
  printf '%s\n' "${snapshot}" > "${snapshot_file}"
  proof_state_refresh_release_set \
    "${evidence_file}" \
    "${snapshot_file}" \
    "$(iso_timestamp)" \
    "${evidence_temp}"
  mv "${evidence_temp}" "${evidence_file}"
  rm -f "${snapshot_file}"
}

mark_active_launch_failed() {
  local reason="$1"
  [[ -f "${evidence_file}" ]] || return 0

  local active_launch_id
  active_launch_id="$(jq -r '
    if (.active_launch.id // "") != ""
      and (.active_launch.ready_at // "") == ""
      and (.active_launch.failure_at // "") == ""
    then .active_launch.id
    else empty
    end
  ' "${evidence_file}")"
  [[ -n "${active_launch_id}" ]] || return 0

  local evidence_temp="${evidence_file}.tmp"
  local failure_at
  failure_at="$(iso_timestamp)"
  jq \
    --arg launch_id "${active_launch_id}" \
    --arg failure_at "${failure_at}" \
    --arg failure_reason "${reason}" '
      .active_launch.failure_at = $failure_at
      | .active_launch.failure_reason = $failure_reason
      | .launches = [
          .launches[]
          | if .id == $launch_id then
              . + {failure_at: $failure_at, failure_reason: $failure_reason}
            else
              .
            end
        ]
    ' "${evidence_file}" > "${evidence_temp}"
  mv "${evidence_temp}" "${evidence_file}"
}

prepare_all() {
  local proof_phase="${1:-prepare}"
  mkdir -p "${workspace_root}" "${evidence_root}"
  chmod 700 "${proof_root}" "${workspace_root}" "${evidence_root}"

  "${REPO_ROOT}/script/prepare_dbcode.sh" --profile default --allow-candidate
  prepare_postgres
  postgres_debugger_fixture_prepare "${workspace_root}"
  if [[ "${proof_phase}" == "relaunch" ]]; then
    prepare_duckdb no
  else
    prepare_duckdb yes
  fi

  current_lock_sha="$(shasum -a 256 "${LOCK_FILE}" | awk '{print $1}')"
  manifest_lock_sha="$(jq -er '.source.release_lock_sha256' "${BUILD_MANIFEST}")"
  [[ "${current_lock_sha}" == "${manifest_lock_sha}" ]] || {
    echo "The app must be rebuilt so its manifest records the locked DBCode release set under test." >&2
    exit 1
  }

  create_evidence_record
  refresh_evidence_release_set
}

prepare_debugger_fixture() {
  mkdir -p "${workspace_root}"
  chmod 700 "${proof_root}" "${workspace_root}"
  postgres_debugger_fixture_prepare "${workspace_root}"
  jq -n \
    --arg proof_sql "${workspace_root}/postgres-debugger-proof.sql" \
    --argjson fixture "${postgres_debugger_fixture_summary}" '
      {
        fixture: $fixture,
        proof_sql: $proof_sql
      }
    '
}

launch_proof() {
  local launch_kind="$1"
  if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
    echo "Quit ${APP_NAME} completely before starting a proof launch." >&2
    exit 1
  fi

  local before_fingerprint normal_profile_owners_before previous_launch_id="" previous_complete_quit="null"
  before_fingerprint="$(normal_profile_fingerprint)"
  normal_profile_owners_before="$(normal_profile_owner_commands)"

  if [[ "${launch_kind}" == "launch" ]]; then
    mark_active_launch_failed "Superseded after an incomplete initial launch."
  fi

  if [[ "${launch_kind}" == "relaunch" ]]; then
    [[ -f "${evidence_file}" ]] || {
      echo "Run an initial proof launch before the persistence relaunch." >&2
      exit 1
    }
    previous_launch_id="$(jq -er '.active_launch.id' "${evidence_file}")"
    jq -e --arg previous_launch_id "${previous_launch_id}" '
      .active_launch.kind == "launch"
      and .last_complete_quit.after_launch_id == $previous_launch_id
      and ((.last_complete_quit.quit_at // "") | length > 0)
      and ((.active_launch.ready_at // "") | length > 0)
      and (.active_launch.ready_at <= .last_complete_quit.quit_at)
      and (.active_launch.launched_at <= .last_complete_quit.quit_at)
    ' "${evidence_file}" >/dev/null || {
      echo "Record a complete quit after the active proof launch before relaunching." >&2
      exit 1
    }
    previous_complete_quit="$(jq -c '.last_complete_quit' "${evidence_file}")"
  fi

  prepare_all "${launch_kind}"

  local evidence_temp launch_id launch_number launched_at
  launch_number="$(jq -er '(.launches | length) + 1' "${evidence_file}")"
  launch_id="launch-${launch_number}"
  launched_at="$(iso_timestamp)"
  evidence_temp="${evidence_file}.tmp"
  jq \
    --arg id "${launch_id}" \
    --arg kind "${launch_kind}" \
    --arg launched_at "${launched_at}" \
    --arg previous_launch_id "${previous_launch_id}" \
    --argjson previous_complete_quit "${previous_complete_quit}" \
    --arg normal_profile_owners_before "${normal_profile_owners_before}" \
    --arg normal_profile_before "${before_fingerprint}" '
      (
        {
          id: $id,
          kind: $kind,
          launched_at: $launched_at,
          normal_profile_before: $normal_profile_before,
          normal_profile_owners_before: (
            $normal_profile_owners_before | split("\n") | map(select(length > 0))
          )
        }
        + if $previous_launch_id == "" then {}
          else {
            previous_launch_id: $previous_launch_id,
            previous_complete_quit: $previous_complete_quit
          } end
      ) as $launch
      | .launches += [$launch]
      | .active_launch = $launch
    ' "${evidence_file}" > "${evidence_temp}"
  mv "${evidence_temp}" "${evidence_file}"

  if DBCODE_WRAPPER_LAUNCH_TIMEOUT_SECONDS=300 \
    DBCODE_WRAPPER_PREPARED_RELEASE_SET_SHA256="$(shasum -a 256 "${LOCK_FILE}" | awk '{print $1}')" \
    "${REPO_ROOT}/script/run_host.sh" --manual-proof --workspace "${workspace_root}"; then
    :
  else
    mark_active_launch_failed "DBCode did not reach a live renderer and activation log."
    echo "The proof launch failed before DBCode readiness; the failed attempt was recorded." >&2
    return 1
  fi

  local ready_at active_dbcode_log active_session_result
  active_session_result="${profile_root}/active-host-session.json"
  ready_at="$(jq -er '.ready_at' "${active_session_result}")"
  IFS= read -r active_dbcode_log < "${profile_root}/active-dbcode-log"
  jq \
    --arg launch_id "${launch_id}" \
    --arg ready_at "${ready_at}" \
    --arg dbcode_log "${active_dbcode_log}" '
      .active_launch.ready_at = $ready_at
      | .active_launch.dbcode_log = $dbcode_log
      | .launches = [
          .launches[]
          | if .id == $launch_id then
              . + {ready_at: $ready_at, dbcode_log: $dbcode_log}
            else
              .
            end
        ]
    ' "${evidence_file}" > "${evidence_temp}"
  mv "${evidence_temp}" "${evidence_file}"
}

record_manual_check() {
  [[ $# -ge 3 ]] || {
    echo "Usage: ./script/proof_dbcode.sh record <activation|credential_reentry|update_discovery|postgresql|debugger|duckdb|parquet|persistence> <passed|failed> <observation>" >&2
    exit 2
  }
  local check_name="$1"
  local check_status="$2"
  local check_note="$3"
  local expected_result
  [[ -n "${check_note}" ]] || {
    echo "Every manual proof result needs a clear observation." >&2
    exit 2
  }

  case "${check_name}" in
    activation)
      expected_result="DBCode restores the lifetime account without another licence entry, and the unchanged locally signed artifact does not repeat the macOS Safe Storage approval."
      ;;
    credential_reentry)
      expected_result="A reviewed imported connection contains no protected password, DBCode asks for it on first use, and the connection succeeds only after the user enters it through DBCode."
      ;;
    update_discovery)
      expected_result="Check for Updates shows the Code OSS host and DBCode extension separately, performs no installation, and leaves the approved release set unchanged."
      ;;
    postgresql)
      expected_result="DBCode reports transaction_read_only=on and returns 3 rows with amount sum 75.00."
      ;;
    debugger)
      expected_result="DBCode starts a PL/pgSQL routine debug session, stops at a SQL breakpoint, exposes stepping and variables, completes with the expected result, and returns to the focused database shell without a generic IDE workbench."
      ;;
    duckdb)
      expected_result="DBCode returns the 3 persistent DuckDB rows with amount sum 61.50."
      ;;
    parquet)
      expected_result="DBCode directly reads the 3 Parquet rows with amount sum 61.50."
      ;;
    persistence)
      expected_result="The lifetime account, saved connections, persistent DuckDB state, and successful proof queries survive a complete quit and relaunch."
      ;;
    *) echo "Unknown manual check: ${check_name}" >&2; exit 2 ;;
  esac
  case "${check_status}" in
    passed|failed) ;;
    *) echo "Manual check status must be passed or failed." >&2; exit 2 ;;
  esac
  [[ -f "${evidence_file}" ]] || {
    echo "Prepare the DBCode Wrapper proof before recording results." >&2
    exit 1
  }

  local active_launch_id active_launch_kind
  active_launch_id="$(jq -er '.active_launch.id' "${evidence_file}")"
  active_launch_kind="$(jq -er '.active_launch.kind' "${evidence_file}")"
  [[ "${active_launch_kind}" == "relaunch" ]] || {
    echo "Record final manual checks only after the independently verified relaunch." >&2
    exit 1
  }
  jq -e '.active_launch.ready_at | type == "string" and length > 0' "${evidence_file}" >/dev/null || {
    echo "The active relaunch has not reached DBCode readiness." >&2
    exit 1
  }
  local evidence_temp="${evidence_file}.tmp"
  jq \
    --arg check "${check_name}" \
    --arg status "${check_status}" \
    --arg note "${check_note}" \
    --arg expected_result "${expected_result}" \
    --arg launch_id "${active_launch_id}" \
    --arg launch_kind "${active_launch_kind}" \
    --arg recorded_at "$(iso_timestamp)" '
      .manual_checks[$check] = {
        status: $status,
        expected_result: $expected_result,
        note: $note,
        launch_id: $launch_id,
        launch_kind: $launch_kind,
        recorded_at: $recorded_at
      }
    ' "${evidence_file}" > "${evidence_temp}"
  mv "${evidence_temp}" "${evidence_file}"
  echo "Recorded ${check_name}: ${check_status}"
}

quit_proof() {
  local active_launch_id=""
  local session_policy_file="${profile_root}/active-host-session-policy.json"
  local session_result_file="${profile_root}/active-host-session.json"
  if [[ -f "${evidence_file}" ]]; then
    active_launch_id="$(jq -r '.active_launch.id // empty' "${evidence_file}")"
  fi
  if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
    [[ -f "${session_policy_file}" && -f "${session_result_file}" ]] || {
      echo "The running proof app has no validated Host Session record." >&2
      exit 1
    }
    [[ "$(jq -er '.status' "${session_result_file}")" == "ready" ]] || {
      echo "The running proof app is not owned by a ready Host Session." >&2
      exit 1
    }
    host_session_stop "${session_policy_file}" "${session_result_file}" "${session_result_file}"
  fi
  if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
    echo "${APP_NAME} did not quit completely through its Host Session." >&2
    exit 1
  fi
  if [[ -f "${evidence_file}" ]]; then
    [[ -n "${active_launch_id}" ]] || {
      echo "The evidence has no active launch to associate with this quit." >&2
      exit 1
    }
    local evidence_temp="${evidence_file}.tmp"
    jq \
      --arg quit_at "$(iso_timestamp)" \
      --arg after_launch_id "${active_launch_id}" '
        ({quit_at: $quit_at, after_launch_id: $after_launch_id}) as $quit
        | .last_complete_quit_at = $quit_at
        | .last_complete_quit = $quit
        | .complete_quits = (
            [(.complete_quits // [])[] | select(.after_launch_id != $after_launch_id)] + [$quit]
          )
      ' \
      "${evidence_file}" > "${evidence_temp}"
    mv "${evidence_temp}" "${evidence_file}"
  fi
  echo "${APP_NAME} is completely stopped."
}

finalize_proof() {
  [[ -f "${evidence_file}" ]] || {
    echo "Prepare and run the DBCode Wrapper proof before finalizing it." >&2
    exit 1
  }
  local migrated_evidence="${evidence_file}.migrated.tmp"
  proof_state_migrate_quit_history "${evidence_file}" "${migrated_evidence}"
  mv "${migrated_evidence}" "${evidence_file}"

  proof_state_is_finalizable "${evidence_file}" || {
    echo "Finalization requires an initial launch, a linked complete quit, a relaunch, and eight fresh passing observations from that relaunch." >&2
    jq '{active_launch, last_complete_quit, manual_checks}' "${evidence_file}" >&2
    exit 1
  }

  local host_log="${logs_root}/proof-host.log"
  [[ -f "${host_log}" ]] || {
    echo "The active proof launch has no host log." >&2
    exit 1
  }
  if rg -Fq 'Keychain lookup failed:' "${host_log}" || \
    rg -Fq "An OS keyring couldn't be identified" "${host_log}"; then
    echo "The active proof launch reported a macOS Keychain failure." >&2
    exit 1
  fi

  local active_dbcode_log_file="${profile_root}/active-dbcode-log"
  [[ -f "${active_dbcode_log_file}" && ! -L "${active_dbcode_log_file}" ]] || {
    echo "The active proof launch did not record its DBCode activation log." >&2
    exit 1
  }
  local active_dbcode_log
  IFS= read -r active_dbcode_log < "${active_dbcode_log_file}"
  case "${active_dbcode_log}" in
    "${logs_root}"/*) ;;
    *)
      echo "The active DBCode log is outside the private log root." >&2
      exit 1
      ;;
  esac
  [[ -f "${active_dbcode_log}" && ! -L "${active_dbcode_log}" ]] || {
    echo "The active DBCode activation log is missing." >&2
    exit 1
  }
  rg -Fq 'DBCode started' "${active_dbcode_log}" || {
    echo "DBCode did not finish starting in the active proof launch." >&2
    exit 1
  }
  rg -q 'Auth: (Sign in restored|Web-session JWT refreshed)' "${active_dbcode_log}" || {
    echo "The active DBCode log does not show a restored signed-in account." >&2
    exit 1
  }
  if rg -Fq 'Keychain lookup failed:' "${active_dbcode_log}" || \
    rg -Fq "An OS keyring couldn't be identified" "${active_dbcode_log}"; then
    echo "The active DBCode log reported a macOS Keychain failure." >&2
    exit 1
  fi
  local current_app_sha256
  current_app_sha256="$(artifact_digest "${APP_BUNDLE}")"
  [[ "$(jq -er '.release_set_under_test.host.app_sha256' "${evidence_file}")" == "${current_app_sha256}" ]] || {
    echo "The proof evidence names a stale host build." >&2
    exit 1
  }
  [[ "$(jq -er '.artifact.sha256' "${BUILD_MANIFEST}")" == "${current_app_sha256}" ]] || {
    echo "The proof app no longer matches its build manifest." >&2
    exit 1
  }
  [[ "$(jq -er '.release.compatibility_status' "${BUILD_MANIFEST}")" == "candidate" ]] || {
    echo "The proof manifest is no longer an immutable candidate." >&2
    exit 1
  }
  local current_candidate_manifest_sha256
  current_candidate_manifest_sha256="$(shasum -a 256 "${BUILD_MANIFEST}" | awk '{print $1}')"
  [[ "$(jq -er '.release_set_under_test.host.release_set_id' "${evidence_file}")" == "$(jq -er '.release.release_set_id' "${BUILD_MANIFEST}")" ]] || {
    echo "The proof evidence names a stale release-set identity." >&2
    exit 1
  }
  [[ "$(jq -er '.release_set_under_test.host.candidate_manifest_sha256' "${evidence_file}")" == "${current_candidate_manifest_sha256}" ]] || {
    echo "The proof evidence names a stale candidate manifest." >&2
    exit 1
  }
  jq -e \
    --arg app_name "$(plutil -extract CFBundleName raw "${APP_BUNDLE}/Contents/Info.plist")" \
    --arg bundle_identifier "$(plutil -extract CFBundleIdentifier raw "${APP_BUNDLE}/Contents/Info.plist")" '
      .release_set_under_test.host.app_name == $app_name
      and .release_set_under_test.host.bundle_identifier == $bundle_identifier
      and .release_set_under_test.host.focused_shell.enabled == true
      and .release_set_under_test.host.focused_shell.automatic_result_layout == {wide: "beside", narrow: "below"}
    ' "${evidence_file}" >/dev/null || {
    echo "The proof evidence is not bound to the current focused-shell identity." >&2
    exit 1
  }
  local durable_profile_state="${user_data_root}/User/globalStorage"
  local durable_profile_database="${durable_profile_state}/state.vscdb"
  [[ -d "${durable_profile_state}" && ! -L "${durable_profile_state}" ]] || {
    echo "The active DBCode Wrapper profile has no durable global state." >&2
    exit 1
  }
  [[ -s "${durable_profile_database}" && ! -L "${durable_profile_database}" ]] || {
    echo "The active DBCode Wrapper profile has no durable state database." >&2
    exit 1
  }
  local durable_profile_sha256
  durable_profile_sha256="$(artifact_digest "${durable_profile_state}")"

  local normal_profile_before normal_profile_after isolation_evidence evidence_temp
  normal_profile_before="$(jq -er '.active_launch.normal_profile_before' "${evidence_file}")"
  normal_profile_after="$(normal_profile_fingerprint)"
  if [[ "${normal_profile_before}" == "${normal_profile_after}" ]]; then
    isolation_evidence='{
      "normal_profiles_unchanged": true,
      "dbcode_wrapper_private_paths_verified": true
    }'
  else
    isolation_evidence="$(
      normal_profile_external_activity_evidence \
        "${host_log}" \
        "$(normal_profile_owner_commands)"
    )" || {
      echo "A normal editor profile changed and could not be attributed to its own editor process." >&2
      exit 1
    }
  fi

  evidence_temp="${evidence_file}.tmp"
  jq \
    --arg normal_profile_after "${normal_profile_after}" \
    --arg dbcode_log "${active_dbcode_log}" \
    --arg dbcode_log_sha256 "$(shasum -a 256 "${active_dbcode_log}" | awk '{print $1}')" \
    --arg durable_profile_state "${durable_profile_state}" \
    --arg durable_profile_sha256 "${durable_profile_sha256}" \
    --argjson isolation_evidence "${isolation_evidence}" '
      .active_launch.normal_profile_after = $normal_profile_after
      | .active_launch.dbcode_activation_log = {
          path: $dbcode_log,
          sha256: $dbcode_log_sha256
        }
      | .active_launch.durable_profile_state = {
          path: $durable_profile_state,
          sha256: $durable_profile_sha256
        }
      | .isolation = (.isolation + $isolation_evidence)
    ' "${evidence_file}" > "${evidence_temp}"
  proof_state_promote_release_set \
    "${evidence_temp}" \
    "$(iso_timestamp)" \
    "${evidence_file}"
  rm -f "${evidence_temp}"
  echo "DBCode Wrapper proof passed. Evidence: ${evidence_file}"
}

show_status() {
  [[ -f "${evidence_file}" ]] || {
    echo "No DBCode Wrapper evidence exists yet. Run ./script/proof_dbcode.sh prepare" >&2
    exit 1
  }
  jq '{status, completed_at, release_set_under_test, approved_release_set, previous_approved_release_set, isolation, fixtures, launches, last_complete_quit, active_launch, manual_checks}' "${evidence_file}"
}

case "${1:-status}" in
  prepare)
    prepare_all prepare
    show_status
    ;;
  prepare-debugger)
    prepare_debugger_fixture
    ;;
  launch)
    launch_proof launch
    ;;
  quit)
    quit_proof
    ;;
  relaunch)
    launch_proof relaunch
    ;;
  record)
    shift
    record_manual_check "$@"
    ;;
  finalize)
    finalize_proof
    ;;
  status)
    show_status
    ;;
  *)
    echo "Usage: ./script/proof_dbcode.sh [prepare|prepare-debugger|launch|quit|relaunch|record|finalize|status]" >&2
    exit 2
    ;;
esac
