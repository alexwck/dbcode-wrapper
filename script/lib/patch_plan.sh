#!/usr/bin/env bash

set -euo pipefail

patch_plan_file() {
  printf '%s\n' "${PATCH_PLAN_FILE:-${REPO_ROOT}/host/patches/patch-plan.json}"
}

patch_plan_entries() {
  local stage="${1}"
  local plan_file="${2:-$(patch_plan_file)}"

  jq -er --arg stage "${stage}" '
    .entries
    | map(select(.stage == $stage))
    | sort_by(.order)
    | .[]
    | [.order, .patch, .sha256]
    | @tsv
  ' "${plan_file}"
}

patch_plan_files() {
  local stage="${1}"
  local plan_file="${2:-$(patch_plan_file)}"

  patch_plan_entries "${stage}" "${plan_file}" |
    while IFS=$'\t' read -r _ patch_relative _; do
      printf '%s/%s\n' "${REPO_ROOT}/host/patches" "${patch_relative}"
    done
}

patch_plan_maintained_tree_digest() {
  local source_root="${1}"
  local plan_file="${2:-$(patch_plan_file)}"

  (
    while IFS= read -r maintained_file; do
      [[ -f "${source_root}/${maintained_file}" ]] || {
        echo "Maintained Code OSS path is missing: ${maintained_file}" >&2
        exit 1
      }
      printf '%s  %s\n' \
        "$(shasum -a 256 "${source_root}/${maintained_file}" | awk '{print $1}')" \
        "${maintained_file}"
    done < <(jq -er '.maintained_code_oss_paths | sort | .[]' "${plan_file}")
  ) | shasum -a 256 | awk '{print $1}'
}

patch_plan_validate() {
  local plan_file="${1:-$(patch_plan_file)}"
  local patch_root="${REPO_ROOT}/host/patches"
  local listed_files actual_files entry_order patch_relative expected_sha actual_sha

  jq -e \
    --arg vscodium_commit "${VSCODIUM_COMMIT}" \
    --arg code_oss_commit "${CODE_OSS_COMMIT}" '
      .schema_version == 1 and
      .target.vscodium_commit == $vscodium_commit and
      .target.code_oss_commit == $code_oss_commit and
      (.entries | length > 0) and
      ([.entries[].order] | length == (unique | length)) and
      ([.entries[].id] | length == (unique | length)) and
      ([.entries[].patch] | length == (unique | length)) and
      all(.entries[];
        (.order | type == "number") and
        (.id | type == "string" and length > 0) and
        (.purpose | type == "string" and length > 0) and
        (.touched_areas | type == "array" and length > 0) and
        (.files | type == "array" and length > 0) and
        (.sha256 | test("^[0-9a-f]{64}$")) and
        ((.stage == "vscodium" and (.patch | startswith("vscodium/"))) or
         (.stage == "code-oss" and (.patch | startswith("code-oss/"))))
      ) and
      (.maintained_code_oss_paths | length > 0) and
      (.maintained_code_oss_paths == (.maintained_code_oss_paths | unique | sort)) and
      (([.entries[] | select(.stage == "code-oss") | .files[]] | sort) == .maintained_code_oss_paths) and
      .maintained_tree_digest_algorithm == "sha256-of-sorted-sha256-space-space-path-records" and
      (.expected_maintained_tree_sha256 | test("^[0-9a-f]{64}$")) and
      .migration_proof.historical_patch_count == 13 and
      (.migration_proof.historical_stack_sha256 | test("^[0-9a-f]{64}$")) and
      .migration_proof.historical_tree_sha256 == .migration_proof.semantic_tree_sha256 and
      .migration_proof.prepared_tree_sha256 == .expected_maintained_tree_sha256 and
      .migration_proof.equivalent == true
    ' "${plan_file}" >/dev/null || {
      echo "Invalid maintained patch plan: ${plan_file}" >&2
      return 1
    }

  listed_files="$(jq -r '.entries[].patch' "${plan_file}" | LC_ALL=C sort)"
  actual_files="$(
    cd "${patch_root}"
    find vscodium code-oss -type f -name '*.patch' -print | LC_ALL=C sort
  )"
  [[ "${listed_files}" == "${actual_files}" ]] || {
    echo "The patch plan must list every maintained patch exactly once." >&2
    diff -u <(printf '%s\n' "${listed_files}") <(printf '%s\n' "${actual_files}") || true
    return 1
  }

  while IFS=$'\t' read -r entry_order patch_relative expected_sha; do
    [[ "${patch_relative}" != /* && "${patch_relative}" != *..* ]] || {
      echo "Unsafe patch-plan path at order ${entry_order}: ${patch_relative}" >&2
      return 1
    }
    actual_sha="$(shasum -a 256 "${patch_root}/${patch_relative}" | awk '{print $1}')"
    [[ "${actual_sha}" == "${expected_sha}" ]] || {
      echo "Patch digest mismatch at order ${entry_order}: ${patch_relative}" >&2
      return 1
    }
    git apply --numstat "${patch_root}/${patch_relative}" >/dev/null || {
      echo "Malformed patch at order ${entry_order}: ${patch_relative}" >&2
      return 1
    }
  done < <(jq -er '.entries | sort_by(.order) | .[] | [.order, .patch, .sha256] | @tsv' "${plan_file}")
}
