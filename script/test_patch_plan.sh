#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/patch_plan.sh"

plan_file="${REPO_ROOT}/host/patches/patch-plan.json"

patch_plan_validate "${plan_file}"
declare -F patch_plan_verify_cached_stage >/dev/null || {
  echo "Patch Plan must own cached-stage verification and its temporary index." >&2
  exit 1
}
declare -F patch_plan_materialize_overlay >/dev/null || {
  echo "Patch Plan must own first-class Code OSS overlay materialization." >&2
  exit 1
}

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
  .schema_version == 3 and
  [.entries[] | select(.stage == "code-oss") | .id] == [
    "product-identity-and-macos-packaging",
    "final-focused-dbcode-shell",
    "host-slimming-policy",
    "release-profile-and-dbcode-integrations"
  ] and
  ([.entries[].overlay_files[]] | length == 3) and
  (has("migration_proof") | not)
' "${plan_file}" >/dev/null || {
  echo "The current semantic patch plan is incomplete or retains migration-only proof." >&2
  exit 1
}

compile_script="${REPO_ROOT}/script/compile_host.sh"
materializer_script="${REPO_ROOT}/script/materialize_code_oss_overlay.sh"
verifier_script="${REPO_ROOT}/script/verify_prepared_patch_tree.sh"
identity_patch="${REPO_ROOT}/host/patches/vscodium/0001-dbcode-wrapper-identity.patch"

[[ -x "${materializer_script}" ]] || {
  echo "The first-class Code OSS overlay materializer is missing or not executable." >&2
  exit 1
}
[[ -x "${verifier_script}" ]] || {
  echo "The prepared Code OSS tree verifier is missing or not executable." >&2
  exit 1
}
rg -Fq 'export DBCODE_WRAPPER_PATCH_TREE_MATERIALIZER=' "${compile_script}" || {
  echo "The compile step must provide the Code OSS overlay materializer to VSCodium." >&2
  exit 1
}
rg -Fq 'export DBCODE_WRAPPER_PATCH_TREE_VERIFIER=' "${compile_script}" || {
  echo "The compile step must provide the prepared-tree verifier to VSCodium." >&2
  exit 1
}
rg -Fq '"${DBCODE_WRAPPER_PATCH_TREE_MATERIALIZER}"' "${identity_patch}" || {
  echo "VSCodium preparation must materialize the first-class Code OSS overlay." >&2
  exit 1
}
rg -Fq '"${DBCODE_WRAPPER_PATCH_TREE_VERIFIER}"' "${identity_patch}" || {
  echo "VSCodium preparation must verify the Code OSS tree after applying patches." >&2
  exit 1
}
materializer_line="$(
  rg -n -F '"${DBCODE_WRAPPER_PATCH_TREE_MATERIALIZER}"' "${identity_patch}" |
    cut -d: -f1
)"
verifier_line="$(
  rg -n -F '"${DBCODE_WRAPPER_PATCH_TREE_VERIFIER}"' "${identity_patch}" |
    cut -d: -f1
)"
(( materializer_line < verifier_line )) || {
  echo "VSCodium must materialize the Code OSS overlay before verifying the prepared tree." >&2
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

mkdir -p "${verifier_fixture_root}/overlay-source"
(
  cd "${verifier_fixture_root}"
  "${materializer_script}" \
    --source-root overlay-source \
    --plan "${plan_file}" \
    >/dev/null
)
absolute_overlay_source="${verifier_fixture_root}/absolute overlay source"
mkdir "${absolute_overlay_source}"
"${materializer_script}" \
  --source-root "${absolute_overlay_source}" \
  --plan host/patches/patch-plan.json \
  >/dev/null

for materialized_overlay_root in \
  "${verifier_fixture_root}/overlay-source" \
  "${absolute_overlay_source}"; do
  while IFS=$'\t' read -r overlay_source overlay_target overlay_sha; do
    cmp \
      "${REPO_ROOT}/${overlay_source}" \
      "${materialized_overlay_root}/${overlay_target}" \
      >/dev/null || {
        echo "The Code OSS overlay changed while being materialized: ${overlay_target}" >&2
        exit 1
      }
    [[ "$(
      shasum -a 256 "${materialized_overlay_root}/${overlay_target}" |
        awk '{print $1}'
    )" == "${overlay_sha}" ]] || {
      echo "The materialized Code OSS overlay has the wrong digest: ${overlay_target}" >&2
      exit 1
    }
  done < <(patch_plan_overlay_files "${plan_file}")
done

set +e
existing_overlay_output="$(
  "${materializer_script}" \
    --source-root "${absolute_overlay_source}" \
    --plan host/patches/patch-plan.json \
    2>&1
)"
existing_overlay_status=$?
set -e
[[ "${existing_overlay_status}" -ne 0 &&
  "${existing_overlay_output}" == *"overlay target already exists"* ]] || {
  echo "The Code OSS overlay materializer replaced an existing target." >&2
  exit 1
}
[[ -z "$(
  find "${absolute_overlay_source}" -name '.dbcode-overlay.*' -print -quit
)" ]] || {
  echo "The Code OSS overlay materializer leaked a temporary file after failure." >&2
  exit 1
}

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

git -C "${verifier_fixture_root}" init --quiet seed
git -C "${verifier_fixture_root}/seed" config user.name "DBCode Wrapper Test"
git -C "${verifier_fixture_root}/seed" config user.email "dbcode-wrapper-test@example.invalid"
printf '%s\n' "fixture" > "${verifier_fixture_root}/seed/fixture.txt"
git -C "${verifier_fixture_root}/seed" add fixture.txt
git -C "${verifier_fixture_root}/seed" commit --quiet -m "fixture"
fixture_commit="$(git -C "${verifier_fixture_root}/seed" rev-parse HEAD)"
git clone --quiet --bare \
  "${verifier_fixture_root}/seed" \
  "${verifier_fixture_root}/cache.git"
set +e
cached_stage_output="$(
  TMPDIR="${verifier_fixture_root}" \
    patch_plan_verify_cached_stage \
      "${verifier_fixture_root}/cache.git" \
      "${fixture_commit}" \
      vscodium 2>&1
)"
cached_stage_status=$?
set -e
[[ "${cached_stage_status}" -ne 0 ]] || {
  echo "The incompatible cached-stage fixture unexpectedly accepted wrapper patches." >&2
  exit 1
}
[[ -z "$(find "${verifier_fixture_root}" -maxdepth 1 -name 'dbcode-vscodium-patch-index.*' -print -quit)" ]] || {
  echo "Cached-stage verification leaked its temporary Git index after failure." >&2
  exit 1
}

TMPDIR="${verifier_fixture_root}" \
  patch_plan_verify_cached_stage \
    "${verifier_fixture_root}/cache.git" \
    "${fixture_commit}" \
    fixture-success
[[ -z "$(find "${verifier_fixture_root}" -maxdepth 1 -name 'dbcode-fixture-success-patch-index.*' -print -quit)" ]] || {
  echo "Cached-stage verification leaked its temporary Git index after success." >&2
  exit 1
}

cleanup_verifier_fixture
trap - EXIT

echo "Maintained patch-plan checks passed."
