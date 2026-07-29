#!/usr/bin/env bash

set -euo pipefail

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${script_root}/.." && pwd)"
source "${script_root}/lib/patch_plan.sh"

usage() {
  echo "Usage: ./script/verify_prepared_patch_tree.sh --source-root DIR [--plan FILE]" >&2
  exit 2
}

source_root=""
plan_file="$(patch_plan_file)"
while [[ $# -gt 0 ]]; do
  case "${1}" in
    --source-root)
      [[ $# -ge 2 ]] || usage
      source_root="${2}"
      shift
      ;;
    --plan)
      [[ $# -ge 2 ]] || usage
      plan_file="${2}"
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

expected_digest="$(jq -er '.expected_maintained_tree_sha256' "${plan_file}")"
actual_digest="$(patch_plan_maintained_tree_digest "${source_root}" "${plan_file}")"
[[ "${actual_digest}" == "${expected_digest}" ]] || {
  echo "The prepared Code OSS tree does not match the approved semantic patch plan." >&2
  exit 1
}

echo "Prepared Code OSS patch tree verified."
