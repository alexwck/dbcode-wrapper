#!/usr/bin/env bash

set -euo pipefail
umask 077

launcher_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "${launcher_repo_root}/script/lib/host_config.sh"
source "${launcher_repo_root}/script/lib/release_source_snapshot.sh"
source "${launcher_repo_root}/script/lib/dist_checkpoint.sh"

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

release_source_parent=""
release_source_temp=""
cleanup_release_source_temp() {
  local exit_status=$?
  trap - EXIT INT TERM
  if [[ -n "${release_source_temp}" ]]; then
    case "${release_source_temp}" in
      "${release_source_parent}"/dbcode-release-source.*) rm -rf "${release_source_temp}" ;;
      *)
        echo "Refusing to remove an unexpected release source path: ${release_source_temp}" >&2
        [[ "${exit_status}" -ne 0 ]] || exit_status=1
        ;;
    esac
  fi
  if ! dist_checkpoint_release; then
    [[ "${exit_status}" -ne 0 ]] || exit_status=1
  fi
  exit "${exit_status}"
}
dist_checkpoint_acquire "host-build"
trap cleanup_release_source_temp EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

release_source_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
release_source_temp="$(mktemp -d "${release_source_parent}/dbcode-release-source.XXXXXX")"
release_source_record="${release_source_temp}/snapshot.json"
materialized_source="${release_source_temp}/source"

release_source_snapshot_write_record \
  "${launcher_repo_root}" \
  "${release_ref}" \
  "${release_source_record}"
release_source_snapshot_materialize \
  "${launcher_repo_root}" \
  "${release_source_record}" \
  "${materialized_source}" >/dev/null

DBCODE_WRAPPER_GENERATED_REPO_ROOT="${launcher_repo_root}" \
  "${materialized_source}/script/setup_local_signing_identity.sh" --status

DBCODE_WRAPPER_GENERATED_REPO_ROOT="${launcher_repo_root}" \
DBCODE_WRAPPER_RELEASE_SOURCE_RECORD="${release_source_record}" \
  "${materialized_source}/script/assemble_host.sh"
