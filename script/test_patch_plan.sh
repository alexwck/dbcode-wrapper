#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/patch_plan.sh"

plan_file="${REPO_ROOT}/host/patches/patch-plan.json"

patch_plan_validate "${plan_file}"

expected_vscodium_order=$'vscodium/0001-dbcode-wrapper-identity.patch\nvscodium/0002-make-tunnel-cli-optional.patch'
actual_vscodium_order="$(patch_plan_entries vscodium "${plan_file}" | cut -f2)"
[[ "${actual_vscodium_order}" == "${expected_vscodium_order}" ]] || {
  echo "The VSCodium patch stage is not in its approved semantic order." >&2
  exit 1
}

expected_code_oss_order=$'code-oss/100-product-identity-and-macos-packaging.patch\ncode-oss/200-final-focused-dbcode-shell.patch\ncode-oss/300-host-slimming-policy.patch\ncode-oss/400-release-profile-and-dbcode-integrations.patch'
actual_code_oss_order="$(patch_plan_entries code-oss "${plan_file}" | cut -f2)"
[[ "${actual_code_oss_order}" == "${expected_code_oss_order}" ]] || {
  echo "The Code OSS patch stage is not in its approved semantic order." >&2
  exit 1
}

jq -e '
  [.entries[] | select(.stage == "code-oss") | .id] == [
    "product-identity-and-macos-packaging",
    "final-focused-dbcode-shell",
    "host-slimming-policy",
    "release-profile-and-dbcode-integrations"
  ] and
  .migration_proof.historical_tree_sha256 == .migration_proof.semantic_tree_sha256 and
  .migration_proof.prepared_tree_sha256 == .expected_maintained_tree_sha256 and
  .migration_proof.equivalent == true
' "${plan_file}" >/dev/null || {
  echo "The semantic migration proof is incomplete." >&2
  exit 1
}

compile_script="${REPO_ROOT}/script/compile_host.sh"
rg -Fq 'patch_plan_maintained_tree_digest "${WORK_ROOT}/vscode"' "${compile_script}" || {
  echo "The compile step must verify the applied Code OSS patch tree." >&2
  exit 1
}

echo "Maintained patch-plan checks passed."
