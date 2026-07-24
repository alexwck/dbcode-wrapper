#!/usr/bin/env bash

set -euo pipefail

host_set=""
output_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host-set) host_set="$2"; shift ;;
    --dbcode-set) shift ;;
    --output) output_file="$2"; shift ;;
    *) echo "Unknown fake runtime-gate option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ "${DBCODE_WRAPPER_TEST_MUTATE_APP:-}" == "yes" ]]; then
  set_root="$(cd "$(dirname "${host_set}")" && pwd)"
  app_relative="$(jq -r '.paths.app' "${host_set}")"
  printf 'modified during launch\n' >> "${set_root}/${app_relative}/Contents/MacOS/DBCode Wrapper"
fi

runtime_status="${DBCODE_WRAPPER_TEST_RUNTIME_STATUS:-passed}"
case "${runtime_status}" in passed|failed) ;; *) exit 2 ;; esac
runtime_passed="true"
[[ "${runtime_status}" == "passed" ]] || runtime_passed="false"

jq -n \
  --arg status "${runtime_status}" \
  --argjson runtime_passed "${runtime_passed}" '
  {
    schema_version: 1,
    status: $status,
    focused_database_shell: $runtime_passed,
    dbcode_started: $runtime_passed,
    normal_pro_activation: $runtime_passed,
    postgresql: $runtime_passed,
    duckdb: $runtime_passed,
    parquet: $runtime_passed,
    hyphen_path_preflight: "not-required",
    full_quit_and_relaunch: $runtime_passed,
    normal_profiles_unchanged: true,
    surprise_update_absent: $runtime_passed
  }
' > "${output_file}"

[[ "${runtime_status}" == "passed" ]]
