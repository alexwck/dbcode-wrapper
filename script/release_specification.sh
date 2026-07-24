#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${repo_root}/script/lib/release_specification.sh"

usage() {
  echo "Usage: ./script/release_specification.sh <validate|build|extensions|profile|identity|historical-validate|historical-build|historical-extensions|historical-profile|historical-identity> [release-lock.json]" >&2
  echo "       ./script/release_specification.sh <same-dbcode-payload|same-host-build-contract> CURRENT_LOCK COMPARED_LOCK" >&2
  exit 2
}

purpose="${1:-}"
if [[ "${purpose}" == "same-dbcode-payload" || "${purpose}" == "same-host-build-contract" ]]; then
  [[ $# -eq 3 ]] || usage
  if [[ "${purpose}" == "same-dbcode-payload" ]]; then
    release_specification_same_dbcode_payload "$2" "$3"
  else
    release_specification_same_host_build_contract "$2" "$3"
  fi
  exit
fi

release_lock="${2:-${repo_root}/host/release-lock.json}"
[[ -n "${purpose}" && $# -le 2 ]] || usage

case "${purpose}" in
  validate)
    release_specification_validate "${release_lock}"
    ;;
  build|extensions|profile|identity)
    release_specification_record "${purpose}" "${release_lock}"
    ;;
  historical-validate)
    release_specification_historical_validate "${release_lock}"
    ;;
  historical-build|historical-extensions|historical-profile|historical-identity)
    release_specification_historical_record "${purpose#historical-}" "${release_lock}"
    ;;
  *)
    usage
    ;;
esac
