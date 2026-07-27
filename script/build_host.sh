#!/usr/bin/env bash

set -euo pipefail
umask 077

launcher_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "${launcher_repo_root}/script/lib/release_source_snapshot.sh"

usage() {
  echo "Usage: ./script/build_host.sh [--release-ref REF]" >&2
  exit 2
}

release_ref="HEAD"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release-ref)
      [[ $# -ge 2 ]] || usage
      release_ref="$2"
      shift
      ;;
    *)
      usage
      ;;
  esac
  shift
done

release_source_temp="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-release-source.XXXXXX")"
release_source_record="${release_source_temp}/snapshot.json"
materialized_source="${release_source_temp}/source"
cleanup_release_source_temp() {
  rm -rf "${release_source_temp}"
}
trap cleanup_release_source_temp EXIT INT TERM

release_source_snapshot_write_record \
  "${launcher_repo_root}" \
  "${release_ref}" \
  "${release_source_record}"
release_source_snapshot_materialize \
  "${launcher_repo_root}" \
  "${release_source_record}" \
  "${materialized_source}" >/dev/null

DBCODE_WRAPPER_GENERATED_REPO_ROOT="${launcher_repo_root}" \
DBCODE_WRAPPER_RELEASE_SOURCE_RECORD="${release_source_record}" \
  "${materialized_source}/script/assemble_host.sh"
