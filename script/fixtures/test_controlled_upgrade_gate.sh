#!/usr/bin/env bash

set -euo pipefail

combination=""
host_set=""
dbcode_set=""
output_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --combination) combination="$2"; shift ;;
    --host-set) host_set="$2"; shift ;;
    --dbcode-set) dbcode_set="$2"; shift ;;
    --output) output_file="$2"; shift ;;
    *) echo "Unknown fake gate option: $1" >&2; exit 2 ;;
  esac
  shift
done

printf '%s %s %s\n' \
  "${combination}" \
  "$(jq -r '.release.release_set_id' "${host_set}")" \
  "$(jq -r '.release.release_set_id' "${dbcode_set}")" \
  >> "${DBCODE_WRAPPER_TEST_GATE_LOG}"

host_release_set_id="$(jq -r '.release.release_set_id' "${host_set}")"
if [[ "${DBCODE_WRAPPER_TEST_TAMPER_COMBINATION:-}" == "${combination}" ]]; then
  host_release_set_id="copied-from-another-pair"
fi

jq -n \
  --arg combination "${combination}" \
  --arg host_release_set_id "${host_release_set_id}" \
  --arg host_app_sha256 "$(jq -r '.host.app_sha256' "${host_set}")" \
  --arg dbcode_id "$(jq -r '.dbcode.id' "${dbcode_set}")" \
  --arg dbcode_version "$(jq -r '.dbcode.version' "${dbcode_set}")" \
  --arg dbcode_vsix_sha256 "$(jq -r '.dbcode.vsix_sha256' "${dbcode_set}")" '
    {
      schema_version: 1,
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
        static: "passed",
        runtime: "passed",
        bundle_unchanged: true,
        surprise_update_absent: true
      },
      status: "passed"
    }
  ' > "${output_file}"

if [[ "${DBCODE_WRAPPER_TEST_FAIL_COMBINATION:-}" == "${combination}" ]]; then
  jq '
    .checks.static = "failed"
    | .checks.runtime = "failed"
    | .checks.surprise_update_absent = false
    | .status = "failed"
  ' "${output_file}" > "${output_file}.tmp"
  mv "${output_file}.tmp" "${output_file}"
  exit 1
fi
