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

patch_plan_overlay_files() {
  local plan_file="${1:-$(patch_plan_file)}"

  jq -er '
    .entries
    | sort_by(.order)
    | .[]
    | .overlay_files[]?
    | [.source, .target, .sha256]
    | @tsv
  ' "${plan_file}"
}

patch_plan_materialize_overlay() (
  local source_root="${1}"
  local plan_file="${2:-$(patch_plan_file)}"
  local source_root_physical source_relative target_relative expected_sha
  local source_path target_path target_parent_relative target_parent
  local source_sha target_sha target_temporary path_component
  local -a parent_components

  [[ "${source_root}" == /* && -d "${source_root}" && ! -L "${source_root}" ]] || {
    echo "Code OSS overlay target must be an absolute real directory: ${source_root}" >&2
    return 1
  }
  source_root_physical="$(cd "${source_root}" && pwd -P)"

  target_temporary=""
  cleanup_overlay_temporary() {
    [[ -z "${target_temporary}" ]] || rm -f "${target_temporary}"
  }
  trap cleanup_overlay_temporary EXIT HUP INT TERM

  while IFS=$'\t' read -r source_relative target_relative expected_sha; do
    case "${source_relative}" in
      host/code-oss-overlay/*) ;;
      *)
        echo "Unsafe Code OSS overlay source: ${source_relative}" >&2
        return 1
        ;;
    esac
    case "${target_relative}" in
      src/*) ;;
      *)
        echo "Unsafe Code OSS overlay target: ${target_relative}" >&2
        return 1
        ;;
    esac
    [[ "${source_relative}" != *..* && "${target_relative}" != *..* ]] || {
      echo "Code OSS overlay paths must not contain '..'." >&2
      return 1
    }

    source_path="${REPO_ROOT}/${source_relative}"
    [[ -f "${source_path}" && ! -L "${source_path}" ]] || {
      echo "Code OSS overlay source is missing or symlinked: ${source_relative}" >&2
      return 1
    }
    source_sha="$(shasum -a 256 "${source_path}" | awk '{print $1}')"
    [[ "${source_sha}" == "${expected_sha}" ]] || {
      echo "Code OSS overlay source digest mismatch: ${source_relative}" >&2
      return 1
    }

    target_parent_relative="${target_relative%/*}"
    target_parent="${source_root_physical}"
    IFS='/' read -r -a parent_components <<<"${target_parent_relative}"
    for path_component in "${parent_components[@]}"; do
      target_parent="${target_parent}/${path_component}"
      [[ ! -L "${target_parent}" ]] || {
        echo "Code OSS overlay target parent is symlinked: ${target_parent}" >&2
        return 1
      }
      if [[ ! -e "${target_parent}" ]]; then
        mkdir "${target_parent}"
      fi
      [[ -d "${target_parent}" ]] || {
        echo "Code OSS overlay target parent is not a directory: ${target_parent}" >&2
        return 1
      }
    done

    target_path="${source_root_physical}/${target_relative}"
    [[ ! -e "${target_path}" && ! -L "${target_path}" ]] || {
      echo "Code OSS overlay target already exists: ${target_relative}" >&2
      return 1
    }
    target_temporary="$(mktemp "${target_parent}/.dbcode-overlay.XXXXXX")"
    cp "${source_path}" "${target_temporary}"
    chmod 0644 "${target_temporary}"
    target_sha="$(shasum -a 256 "${target_temporary}" | awk '{print $1}')"
    [[ "${target_sha}" == "${expected_sha}" ]] || {
      echo "Materialized Code OSS overlay digest mismatch: ${target_relative}" >&2
      return 1
    }
    mv "${target_temporary}" "${target_path}"
    target_temporary=""
  done < <(patch_plan_overlay_files "${plan_file}")
)

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

patch_plan_verify_cached_stage() (
  local cache_repository="${1}"
  local source_commit="${2}"
  local stage="${3}"
  local patch_index stage_patch

  [[ -d "${cache_repository}" ]] || return 0
  git --git-dir="${cache_repository}" cat-file -e "${source_commit}^{commit}"

  patch_index="$(mktemp "${TMPDIR:-/tmp}/dbcode-${stage}-patch-index.XXXXXX")"
  cleanup_patch_index() {
    rm -f "${patch_index}"
  }
  trap cleanup_patch_index EXIT HUP INT TERM
  rm -f "${patch_index}"

  GIT_INDEX_FILE="${patch_index}" \
    git --git-dir="${cache_repository}" read-tree "${source_commit}"
  while IFS= read -r stage_patch; do
    GIT_INDEX_FILE="${patch_index}" \
      git --git-dir="${cache_repository}" apply --cached --check "${stage_patch}"
    GIT_INDEX_FILE="${patch_index}" \
      git --git-dir="${cache_repository}" apply --cached "${stage_patch}"
  done < <(patch_plan_files "${stage}")
)

patch_plan_validate() {
  local plan_file="${1:-$(patch_plan_file)}"
  local patch_root="${REPO_ROOT}/host/patches"
  local listed_files actual_files entry_order patch_relative expected_sha actual_sha
  local overlay_source overlay_target

  jq -e \
    --arg vscodium_commit "${VSCODIUM_COMMIT}" \
    --arg code_oss_commit "${CODE_OSS_COMMIT}" '
      .schema_version == 2 and
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
        (.files == (.files | unique)) and
        (.overlay_files | type == "array") and
        all(.overlay_files[];
          (.source | type == "string" and startswith("host/code-oss-overlay/")) and
          (.target | type == "string" and startswith("src/")) and
          (.sha256 | test("^[0-9a-f]{64}$"))
        ) and
        (.sha256 | test("^[0-9a-f]{64}$")) and
        ((.stage == "vscodium" and (.patch | startswith("vscodium/"))) or
         (.stage == "code-oss" and (.patch | startswith("code-oss/"))))
      ) and
      (.maintained_code_oss_paths | length > 0) and
      (.maintained_code_oss_paths == (.maintained_code_oss_paths | unique | sort)) and
      ([.entries[].overlay_files[].source] | length == (unique | length)) and
      ([.entries[].overlay_files[].target] | length == (unique | length)) and
      (([
        .entries[]
        | select(.stage == "code-oss")
        | (.files[]), (.overlay_files[].target)
      ] | sort) == .maintained_code_oss_paths) and
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

  while IFS=$'\t' read -r overlay_source overlay_target expected_sha; do
    [[ "${overlay_source}" != /* && "${overlay_source}" != *..* ]] || {
      echo "Unsafe patch-plan overlay source: ${overlay_source}" >&2
      return 1
    }
    [[ "${overlay_target}" != /* && "${overlay_target}" != *..* ]] || {
      echo "Unsafe patch-plan overlay target: ${overlay_target}" >&2
      return 1
    }
    actual_sha="$(shasum -a 256 "${REPO_ROOT}/${overlay_source}" | awk '{print $1}')"
    [[ "${actual_sha}" == "${expected_sha}" ]] || {
      echo "Overlay digest mismatch: ${overlay_source}" >&2
      return 1
    }
  done < <(patch_plan_overlay_files "${plan_file}")
}
