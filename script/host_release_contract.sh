#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${repo_root}/script/lib/release_specification.sh"
source "${repo_root}/script/lib/host_release.sh"

usage() {
  echo "Usage: ./script/host_release_contract.sh prompt-free-acceptance-record MANIFEST RELEASE_LOCK ACCEPTANCE" >&2
  exit 2
}

command="${1:-}"
[[ "${command}" == "prompt-free-acceptance-record" && $# -eq 4 ]] || usage

host_release_prompt_free_acceptance_record "$2" "$3" "$4"
