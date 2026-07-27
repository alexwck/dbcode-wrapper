#!/usr/bin/env bash

set -euo pipefail

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fast_acceptance="${script_root}/verify_fast_release.sh"
private_release_module="${script_root}/lib/private_release.sh"

bash -n "${fast_acceptance}"

for required_contract in \
  '--rendered-report' \
  'schema_version: 3' \
  'profile_name: "qa"' \
  'persistent_profile: true' \
  'person_controlled_actions: "not-invoked"' \
  'source_snapshot_sha256' \
  'compiled_host_input_id' \
  'mode == "immutable-git-commit"' \
  'release_source_snapshot_materialize' \
  'materialized_verifier_source="$(' \
  'DBCODE_WRAPPER_RELEASE_VERIFIER_MATERIALIZED' \
  '"${script_root}/check_development.sh"' \
  '"${script_root}/smoke_host.sh"' \
  '--app "${app}"' \
  '--manifest "${manifest}"' \
  'gate_execution' \
  'build_manifest_sha256: $manifest_sha256' \
  'kernel_started: false' \
  'sql_executed: false' \
  'model_called: false' \
  'secret_entered: false' \
  'prompt_free_automation: "passed"' \
  'signed_app_one_profile_launch: "passed"' \
  'unchanged DBCode exposes the reviewed New Connection catalogue' \
  'the DBCode notebook route remains reachable without starting a kernel' \
  'DBCode AI provider, custom-model, and API-key routes remain reachable without sending data' \
  'Open SQL File renders the deterministic query without executing it'; do
  rg -Fq -- "${required_contract}" "${fast_acceptance}" || {
    echo "The prompt-free acceptance command is missing: ${required_contract}" >&2
    exit 1
  }
done

for forbidden_contract in \
  '--development-log' \
  '--smoke-log' \
  '--proof' \
  '--continuity' \
  '--matrix' \
  '--health' \
  '--rollback' \
  'manual_checks' \
  'manual_evidence' \
  'Independent launch passed'; do
  if rg -Fq -- "${forbidden_contract}" "${fast_acceptance}"; then
    echo "The prompt-free acceptance command still requires legacy evidence: ${forbidden_contract}" >&2
    exit 1
  fi
done

stale_development_log="$(mktemp "${TMPDIR:-/tmp}/dbcode-stale-development.XXXXXX")"
stale_smoke_log="$(mktemp "${TMPDIR:-/tmp}/dbcode-stale-smoke.XXXXXX")"
trap 'rm -f "${stale_development_log}" "${stale_smoke_log}"' EXIT
printf '%s\n' 'Development source checks passed without rebuilding the app.' \
  > "${stale_development_log}"
printf '%s\n' \
  'Static host checks passed: identity, darwin-arm64, SQL document association, signature, and manifest.' \
  > "${stale_smoke_log}"
set +e
stale_log_output="$(
  "${fast_acceptance}" \
    --app "/tmp/stale.app" \
    --manifest "/tmp/stale-manifest.json" \
    --release-lock "/tmp/stale-release-lock.json" \
    --rendered-report "/tmp/stale-rendered.json" \
    --development-log "${stale_development_log}" \
    --smoke-log "${stale_smoke_log}" \
    --output "/tmp/stale-acceptance.json" 2>&1
)"
stale_log_status=$?
set -e
[[ "${stale_log_status}" -eq 2 && "${stale_log_output}" == *"Usage:"* ]] || {
  echo "The prompt-free acceptance command did not reject detached stale logs." >&2
  exit 1
}

rg -Fq '[[ "${acceptance_schema}" == "3" ]]' "${private_release_module}" || {
  echo "Private packaging must accept prompt-free schema 3 evidence." >&2
  exit 1
}

echo "Prompt-free release acceptance contracts passed."
