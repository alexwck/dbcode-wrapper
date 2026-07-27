#!/usr/bin/env bash

set -euo pipefail
umask 077

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_root}/lib/release_source_snapshot.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  ./script/release_source_snapshot.sh create --repository DIR --ref REF --output FILE
  ./script/release_source_snapshot.sh verify --repository DIR --record FILE
EOF
  exit 2
}

[[ $# -ge 1 ]] || usage
command_name="$1"
shift

repository=""
source_ref=""
output_file=""
record_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repository) [[ $# -ge 2 ]] || usage; repository="$2"; shift ;;
    --ref) [[ $# -ge 2 ]] || usage; source_ref="$2"; shift ;;
    --output) [[ $# -ge 2 ]] || usage; output_file="$2"; shift ;;
    --record) [[ $# -ge 2 ]] || usage; record_file="$2"; shift ;;
    *) usage ;;
  esac
  shift
done

case "${command_name}" in
  create)
    [[ -n "${repository}" && -n "${source_ref}" && -n "${output_file}" &&
      -z "${record_file}" ]] || usage
    release_source_snapshot_write_record \
      "${repository}" \
      "${source_ref}" \
      "${output_file}"
    echo "Release Source Snapshot created: ${output_file}"
    ;;
  verify)
    [[ -n "${repository}" && -n "${record_file}" &&
      -z "${source_ref}" && -z "${output_file}" ]] || usage
    release_source_snapshot_verify_record "${repository}" "${record_file}"
    echo "Release Source Snapshot verified: ${record_file}"
    ;;
  *)
    usage
    ;;
esac
