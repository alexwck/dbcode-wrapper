#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/artifact_digest.sh"
source "${REPO_ROOT}/script/lib/approved_release_set.sh"

usage() {
  echo "Usage: ./script/check_release_combination.sh --combination H0/D0|H0/D1|H1/D0|H1/D1 --host-set FILE --dbcode-set FILE --output FILE" >&2
  exit 2
}

combination=""
host_set=""
dbcode_set=""
output_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --combination) [[ $# -ge 2 ]] || usage; combination="$2"; shift ;;
    --host-set) [[ $# -ge 2 ]] || usage; host_set="$2"; shift ;;
    --dbcode-set) [[ $# -ge 2 ]] || usage; dbcode_set="$2"; shift ;;
    --output) [[ $# -ge 2 ]] || usage; output_file="$2"; shift ;;
    *) usage ;;
  esac
  shift
done

case "${combination}" in H0/D0|H0/D1|H1/D0|H1/D1) ;; *) usage ;; esac
[[ -n "${host_set}" && -n "${dbcode_set}" && -n "${output_file}" ]] || usage
approved_release_set_validate "${host_set}" >/dev/null
approved_release_set_validate "${dbcode_set}" >/dev/null
[[ ! -L "${output_file}" ]] || {
  echo "Refusing a symlinked combination receipt: ${output_file}" >&2
  exit 1
}

host_app="$(approved_release_set_member "${host_set}" app)"
expected_app_sha="$(jq -er '.host.app_sha256' "${host_set}")"
initial_app_sha="$(artifact_digest "${host_app}")"
[[ "${initial_app_sha}" == "${expected_app_sha}" ]] || {
  echo "The host app changed after its release set was prepared." >&2
  exit 1
}

static_gate="${DBCODE_WRAPPER_STATIC_GATE:-${REPO_ROOT}/script/verify_release_set_static.sh}"
runtime_gate="${DBCODE_WRAPPER_RUNTIME_GATE:-${REPO_ROOT}/script/smoke_release_pair.sh}"
for gate_file in "${static_gate}" "${runtime_gate}"; do
  [[ -f "${gate_file}" && ! -L "${gate_file}" && -x "${gate_file}" ]] || {
    echo "Release gate is missing or unsafe: ${gate_file}" >&2
    exit 1
  }
done

output_parent="$(cd "$(dirname "${output_file}")" && pwd -P)"
receipt_root="$(mktemp -d "${output_parent}/.release-combination.XXXXXX")"
cleanup_receipt_root() {
  [[ -n "${receipt_root:-}" ]] || return 0
  case "${receipt_root}" in
    "${output_parent}/.release-combination."*) rm -rf "${receipt_root}" ;;
    *) echo "Refusing to remove unexpected combination staging path: ${receipt_root}" >&2; return 1 ;;
  esac
  receipt_root=""
}
trap cleanup_receipt_root EXIT INT TERM

static_receipt="${receipt_root}/static.json"
runtime_receipt="${receipt_root}/runtime.json"
static_exit=0
runtime_exit=0
"${static_gate}" \
  --host-set "${host_set}" \
  --dbcode-set "${dbcode_set}" \
  --output "${static_receipt}" || static_exit=$?

[[ -f "${static_receipt}" && ! -L "${static_receipt}" ]] || {
  echo "The static release gate did not produce a receipt." >&2
  exit 1
}
jq -e '
  .schema_version == 1
  and (.status == "passed" or .status == "failed")
  and (.source_and_artifact_identity | type == "boolean")
  and (.hashes_and_signatures | type == "boolean")
  and (.architecture_and_minimum_macos | type == "boolean")
  and (.dbcode_engine_compatible | type == "boolean")
  and (.unchanged_extension_packages | type == "boolean")
  and (.connection_capability_contract | type == "boolean")
  and (.extension_allowlist_exact | type == "boolean")
  and (.nested_signature_and_entitlements | type == "boolean")
' "${static_receipt}" >/dev/null || {
  echo "The static release receipt is incomplete." >&2
  exit 1
}
static_status="$(jq -er '.status' "${static_receipt}")"
if [[ "${static_exit}" -eq 0 && "${static_status}" != "passed" ]] || \
  [[ "${static_exit}" -ne 0 && "${static_status}" != "failed" ]]; then
  echo "The static release gate exit status disagrees with its receipt." >&2
  exit 1
fi

if [[ "${static_status}" == "passed" ]]; then
  "${runtime_gate}" \
    --host-set "${host_set}" \
    --dbcode-set "${dbcode_set}" \
    --output "${runtime_receipt}" || runtime_exit=$?
else
  jq -n '{
    schema_version: 1,
    status: "failed",
    focused_database_shell: false,
    dbcode_started: false,
    normal_pro_activation: false,
    postgresql: false,
    duckdb: false,
    parquet: false,
    hyphen_path_preflight: "not-run",
    full_quit_and_relaunch: false,
    normal_profiles_unchanged: false,
    surprise_update_absent: false,
    failure: "Static checks failed; the app was not launched."
  }' > "${runtime_receipt}"
  runtime_exit=1
fi

[[ -f "${runtime_receipt}" && ! -L "${runtime_receipt}" ]] || {
  echo "The runtime release gate did not produce a receipt." >&2
  exit 1
}
jq -e '
  .schema_version == 1
  and (.status == "passed" or .status == "failed")
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
' "${runtime_receipt}" >/dev/null || {
  echo "The runtime release receipt is incomplete." >&2
  exit 1
}
runtime_status="$(jq -er '.status' "${runtime_receipt}")"
if [[ "${runtime_exit}" -eq 0 && "${runtime_status}" != "passed" ]] || \
  [[ "${runtime_exit}" -ne 0 && "${runtime_status}" != "failed" ]]; then
  echo "The runtime release gate exit status disagrees with its receipt." >&2
  exit 1
fi

final_app_sha="$(artifact_digest "${host_app}")"
bundle_unchanged="false"
[[ "${final_app_sha}" == "${initial_app_sha}" ]] && bundle_unchanged="true"
surprise_update_absent="$(jq -r '.surprise_update_absent' "${runtime_receipt}")"
combination_status="failed"
if [[ "${static_status}" == "passed" && "${runtime_status}" == "passed" && \
  "${bundle_unchanged}" == "true" && "${surprise_update_absent}" == "true" ]]; then
  combination_status="passed"
fi

receipt_temp="${receipt_root}/combination.json"
jq -n \
  --arg checked_at_utc "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --arg combination "${combination}" \
  --arg host_release_set_id "$(jq -er '.release.release_set_id' "${host_set}")" \
  --arg host_app_sha256 "${expected_app_sha}" \
  --arg dbcode_id "$(jq -er '.dbcode.id' "${dbcode_set}")" \
  --arg dbcode_version "$(jq -er '.dbcode.version' "${dbcode_set}")" \
  --arg dbcode_vsix_sha256 "$(jq -er '.dbcode.vsix_sha256' "${dbcode_set}")" \
  --arg static_status "${static_status}" \
  --arg runtime_status "${runtime_status}" \
  --argjson bundle_unchanged "${bundle_unchanged}" \
  --argjson surprise_update_absent "${surprise_update_absent}" \
  --arg status "${combination_status}" \
  --slurpfile static "${static_receipt}" \
  --slurpfile runtime "${runtime_receipt}" '
    {
      schema_version: 1,
      checked_at_utc: $checked_at_utc,
      combination: $combination,
      host: {
        release_set_id: $host_release_set_id,
        app_sha256: $host_app_sha256
      },
      dbcode: {
        id: $dbcode_id,
        version: $dbcode_version,
        vsix_sha256: $dbcode_vsix_sha256
      },
      checks: {
        static: $static_status,
        runtime: $runtime_status,
        bundle_unchanged: $bundle_unchanged,
        surprise_update_absent: $surprise_update_absent
      },
      details: {static: $static[0], runtime: $runtime[0]},
      status: $status
    }
  ' > "${receipt_temp}"
mv "${receipt_temp}" "${output_file}"
chmod 600 "${output_file}"

if [[ "${combination_status}" != "passed" ]]; then
  echo "Release combination ${combination} failed: ${output_file}" >&2
  exit 1
fi
echo "Release combination ${combination} passed: ${output_file}"
