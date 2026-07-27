#!/usr/bin/env bash

set -euo pipefail

source_cache_ensure_commit_ref() {
  [[ $# -eq 3 ]] || {
    echo "Usage: source_cache_ensure_commit_ref CACHE_DIR COMMIT CACHE_REF" >&2
    return 2
  }

  local cache_dir="$1"
  local expected_commit="$2"
  local cache_ref="$3"
  local actual_commit

  if git --git-dir="${cache_dir}" show-ref --verify --quiet "${cache_ref}"; then
    actual_commit="$(git --git-dir="${cache_dir}" rev-parse "${cache_ref}^{commit}")"
    [[ "${actual_commit}" == "${expected_commit}" ]] || {
      echo "Cache ref ${cache_ref} resolves to ${actual_commit}, expected ${expected_commit}." >&2
      return 1
    }
    return 0
  fi

  if git --git-dir="${cache_dir}" cat-file -e "${expected_commit}^{commit}" 2>/dev/null; then
    git --git-dir="${cache_dir}" update-ref "${cache_ref}" "${expected_commit}"
  else
    git --git-dir="${cache_dir}" fetch --depth 1 origin "${expected_commit}:${cache_ref}"
  fi

  actual_commit="$(git --git-dir="${cache_dir}" rev-parse "${cache_ref}^{commit}")"
  [[ "${actual_commit}" == "${expected_commit}" ]] || {
    echo "Cache ref ${cache_ref} resolves to ${actual_commit}, expected ${expected_commit}." >&2
    return 1
  }
}
