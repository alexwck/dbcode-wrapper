#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/patch_plan.sh"

usage() {
  echo "Usage: ./script/materialize_code_oss_overlay.sh --source-root DIR [--plan FILE]" >&2
  exit 2
}

source_root=""
plan_file="$(patch_plan_file)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-root)
      [[ $# -ge 2 ]] || usage
      source_root="$2"
      shift
      ;;
    --plan)
      [[ $# -ge 2 ]] || usage
      plan_file="$2"
      shift
      ;;
    *)
      usage
      ;;
  esac
  shift
done

[[ -n "${source_root}" && -d "${source_root}" && ! -L "${source_root}" ]] || usage
[[ -f "${plan_file}" && ! -L "${plan_file}" ]] || usage
source_root="$(cd "${source_root}" && pwd -P)"
plan_file="$(
  cd "$(dirname "${plan_file}")"
  printf '%s/%s\n' "$(pwd -P)" "$(basename "${plan_file}")"
)"

patch_plan_validate "${plan_file}"
patch_plan_materialize_overlay "${source_root}" "${plan_file}"

echo "Code OSS overlay materialized."
