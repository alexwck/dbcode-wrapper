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
verifier_script="${REPO_ROOT}/script/verify_prepared_patch_tree.sh"
identity_patch="${REPO_ROOT}/host/patches/vscodium/0001-dbcode-wrapper-identity.patch"

[[ -x "${verifier_script}" ]] || {
  echo "The prepared Code OSS tree verifier is missing or not executable." >&2
  exit 1
}
rg -Fq 'export DBCODE_WRAPPER_PATCH_TREE_VERIFIER=' "${compile_script}" || {
  echo "The compile step must provide the prepared-tree verifier to VSCodium." >&2
  exit 1
}
rg -Fq '"${DBCODE_WRAPPER_PATCH_TREE_VERIFIER}"' "${identity_patch}" || {
  echo "VSCodium preparation must verify the Code OSS tree after applying patches." >&2
  exit 1
}
if rg -Fq 'patch_plan_maintained_tree_digest "${WORK_ROOT}/vscode"' "${compile_script}"; then
  echo "The compile step must not inspect the Code OSS tree before VSCodium prepares it." >&2
  exit 1
fi

verifier_fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-patch-tree-verifier.XXXXXX")"
cleanup_verifier_fixture() {
  rm -rf "${verifier_fixture_root}"
}
trap cleanup_verifier_fixture EXIT

mkdir -p "${verifier_fixture_root}/source"
printf '%s\n' "approved" > "${verifier_fixture_root}/source/fixture.txt"
jq -n '
  {
    maintained_code_oss_paths: ["fixture.txt"],
    expected_maintained_tree_sha256: ("0" * 64)
  }
' > "${verifier_fixture_root}/plan.json"
fixture_digest="$(
  patch_plan_maintained_tree_digest \
    "${verifier_fixture_root}/source" \
    "${verifier_fixture_root}/plan.json"
)"
jq \
  --arg digest "${fixture_digest}" \
  '.expected_maintained_tree_sha256 = $digest' \
  "${verifier_fixture_root}/plan.json" \
  > "${verifier_fixture_root}/plan.approved.json"

"${verifier_script}" \
  --source-root "${verifier_fixture_root}/source" \
  --plan "${verifier_fixture_root}/plan.approved.json" \
  >/dev/null

printf '%s\n' "changed" > "${verifier_fixture_root}/source/fixture.txt"
set +e
changed_tree_output="$(
  "${verifier_script}" \
    --source-root "${verifier_fixture_root}/source" \
    --plan "${verifier_fixture_root}/plan.approved.json" \
    2>&1
)"
changed_tree_status=$?
set -e
[[ "${changed_tree_status}" -eq 1 &&
  "${changed_tree_output}" == *"does not match the approved semantic patch plan"* ]] || {
  echo "The prepared-tree verifier accepted an unapproved Code OSS tree." >&2
  exit 1
}

cleanup_verifier_fixture
trap - EXIT

echo "Maintained patch-plan checks passed."
