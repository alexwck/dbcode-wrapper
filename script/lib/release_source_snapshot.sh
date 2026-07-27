#!/usr/bin/env bash

if [[ "${DBCODE_WRAPPER_RELEASE_SOURCE_SNAPSHOT_LOADED:-}" == "yes" ]]; then
  return 0 2>/dev/null || exit 0
fi
DBCODE_WRAPPER_RELEASE_SOURCE_SNAPSHOT_LOADED="yes"

release_source_snapshot_assert_repository() {
  local repository="$1"

  [[ -d "${repository}" && ! -L "${repository}" ]] || {
    echo "The release source repository is missing or unsafe: ${repository}" >&2
    return 1
  }
  git -C "${repository}" rev-parse --git-dir >/dev/null 2>&1 || {
    echo "The release source is not a Git repository: ${repository}" >&2
    return 1
  }
}

release_source_snapshot_resolve_commit() {
  local repository="$1"
  local source_ref="$2"

  [[ -n "${source_ref}" ]] || {
    echo "The release source ref is required." >&2
    return 1
  }
  git -C "${repository}" rev-parse --verify "${source_ref}^{commit}" 2>/dev/null || {
    echo "The release source ref does not resolve to a commit: ${source_ref}" >&2
    return 1
  }
}

release_source_snapshot_digest() {
  local repository="$1"
  local source_commit="$2"

  git -C "${repository}" ls-tree -r -z --full-tree "${source_commit}" |
    shasum -a 256 |
    awk '{print $1}'
}

release_source_snapshot_host_script_digest() {
  local repository="$1"
  local source_commit="$2"

  git -C "${repository}" ls-tree -r -z --full-tree "${source_commit}" -- host script |
    shasum -a 256 |
    awk '{print $1}'
}

release_source_snapshot_lock_digest() {
  local repository="$1"
  local source_commit="$2"

  git -C "${repository}" cat-file -e \
    "${source_commit}:host/release-lock.json" 2>/dev/null || {
    echo "The release source commit does not contain host/release-lock.json." >&2
    return 1
  }
  git -C "${repository}" show "${source_commit}:host/release-lock.json" 2>/dev/null |
    shasum -a 256 |
    awk '{print $1}'
}

release_source_snapshot_assert_clean_checkout() {
  local repository="$1"
  local source_commit="$2"
  local head_commit worktree_status

  head_commit="$(git -C "${repository}" rev-parse --verify 'HEAD^{commit}')"
  [[ "${head_commit}" == "${source_commit}" ]] || {
    echo "The checked-out commit does not match the Release Source Snapshot." >&2
    return 1
  }
  worktree_status="$(git -C "${repository}" status --porcelain=v1 --untracked-files=all)"
  [[ -z "${worktree_status}" ]] || {
    echo "The Release Source Snapshot requires a clean working tree." >&2
    return 1
  }
}

release_source_snapshot_record_json() {
  local repository="$1"
  local source_ref="$2"
  local source_commit tree_oid snapshot_sha256 host_script_sha256 release_lock_sha256

  release_source_snapshot_assert_repository "${repository}" || return 1
  source_commit="$(release_source_snapshot_resolve_commit "${repository}" "${source_ref}")" || return 1
  release_source_snapshot_assert_clean_checkout "${repository}" "${source_commit}" || return 1

  tree_oid="$(git -C "${repository}" rev-parse --verify "${source_commit}^{tree}")"
  snapshot_sha256="$(release_source_snapshot_digest "${repository}" "${source_commit}")"
  host_script_sha256="$(release_source_snapshot_host_script_digest "${repository}" "${source_commit}")"
  release_lock_sha256="$(release_source_snapshot_lock_digest "${repository}" "${source_commit}")"

  [[ "${source_commit}" =~ ^[0-9a-f]{40}$ &&
    "${tree_oid}" =~ ^[0-9a-f]{40}$ &&
    "${snapshot_sha256}" =~ ^[0-9a-f]{64}$ &&
    "${host_script_sha256}" =~ ^[0-9a-f]{64}$ &&
    "${release_lock_sha256}" =~ ^[0-9a-f]{64}$ ]] || {
    echo "The Release Source Snapshot could not derive an immutable source identity." >&2
    return 1
  }

  jq -S -n -c \
    --arg created_at_utc "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --arg requested_ref "${source_ref}" \
    --arg repository_revision "${source_commit}" \
    --arg tree_oid "${tree_oid}" \
    --arg snapshot_sha256 "${snapshot_sha256}" \
    --arg host_script_sha256 "${host_script_sha256}" \
    --arg release_lock_sha256 "${release_lock_sha256}" '
      {
        schema_version: 1,
        mode: "immutable-git-commit",
        created_at_utc: $created_at_utc,
        requested_ref: $requested_ref,
        repository_revision: $repository_revision,
        tree_oid: $tree_oid,
        snapshot_sha256: $snapshot_sha256,
        host_script_sha256: $host_script_sha256,
        release_lock_sha256: $release_lock_sha256
      }
    '
}

release_source_snapshot_write_record() {
  local repository="$1"
  local source_ref="$2"
  local output_file="$3"
  local output_parent output_name temporary_file

  [[ -n "${output_file}" && ! -L "${output_file}" ]] || {
    echo "The Release Source Snapshot output is missing or unsafe." >&2
    return 1
  }
  mkdir -p "$(dirname "${output_file}")"
  output_parent="$(cd "$(dirname "${output_file}")" && pwd -P)"
  output_name="$(basename "${output_file}")"
  temporary_file="$(mktemp "${output_parent}/.${output_name}.XXXXXX")"
  cleanup_release_source_record() {
    rm -f "${temporary_file}"
  }
  trap cleanup_release_source_record RETURN

  release_source_snapshot_record_json "${repository}" "${source_ref}" > "${temporary_file}"
  chmod 600 "${temporary_file}"
  mv "${temporary_file}" "${output_parent}/${output_name}"
  temporary_file=""
  trap - RETURN
}

release_source_snapshot_verify_json() {
  local repository="$1"
  local snapshot_json="$2"
  local source_commit expected_tree_oid expected_snapshot_sha256
  local expected_host_script_sha256 expected_release_lock_sha256

  release_source_snapshot_assert_repository "${repository}" || return 1
  jq -e '
    .schema_version == 1
    and .mode == "immutable-git-commit"
    and (.requested_ref | type == "string" and length > 0)
    and (.repository_revision | test("^[0-9a-f]{40}$"))
    and (.tree_oid | test("^[0-9a-f]{40}$"))
    and (.snapshot_sha256 | test("^[0-9a-f]{64}$"))
    and (.host_script_sha256 | test("^[0-9a-f]{64}$"))
    and (.release_lock_sha256 | test("^[0-9a-f]{64}$"))
  ' <<<"${snapshot_json}" >/dev/null || {
    echo "The Release Source Snapshot record is invalid." >&2
    return 1
  }

  source_commit="$(jq -er '.repository_revision' <<<"${snapshot_json}")"
  git -C "${repository}" cat-file -e "${source_commit}^{commit}" 2>/dev/null || {
    echo "The Release Source Snapshot commit is unavailable." >&2
    return 1
  }
  expected_tree_oid="$(
    git -C "${repository}" rev-parse --verify "${source_commit}^{tree}"
  )"
  expected_snapshot_sha256="$(
    release_source_snapshot_digest "${repository}" "${source_commit}"
  )"
  expected_host_script_sha256="$(
    release_source_snapshot_host_script_digest "${repository}" "${source_commit}"
  )"
  expected_release_lock_sha256="$(
    release_source_snapshot_lock_digest "${repository}" "${source_commit}"
  )"

  jq -e \
    --arg tree_oid "${expected_tree_oid}" \
    --arg snapshot_sha256 "${expected_snapshot_sha256}" \
    --arg host_script_sha256 "${expected_host_script_sha256}" \
    --arg release_lock_sha256 "${expected_release_lock_sha256}" '
      .tree_oid == $tree_oid
      and .snapshot_sha256 == $snapshot_sha256
      and .host_script_sha256 == $host_script_sha256
      and .release_lock_sha256 == $release_lock_sha256
    ' <<<"${snapshot_json}" >/dev/null || {
    echo "The Release Source Snapshot does not match its immutable Git commit." >&2
    return 1
  }
}

release_source_snapshot_verify_record() {
  local repository="$1"
  local record_file="$2"
  local source_commit snapshot_json

  release_source_snapshot_assert_repository "${repository}" || return 1
  [[ -f "${record_file}" && ! -L "${record_file}" ]] || {
    echo "The Release Source Snapshot record is missing or unsafe: ${record_file}" >&2
    return 1
  }

  snapshot_json="$(jq -c . "${record_file}")"
  release_source_snapshot_verify_json "${repository}" "${snapshot_json}" || return 1
  source_commit="$(jq -er '.repository_revision' <<<"${snapshot_json}")"
  release_source_snapshot_assert_clean_checkout "${repository}" "${source_commit}"
}

release_source_snapshot_materialize() {
  local repository="$1"
  local record_file="$2"
  local destination="$3"
  local destination_parent source_commit snapshot_json

  release_source_snapshot_assert_repository "${repository}" || return 1
  [[ -f "${record_file}" && ! -L "${record_file}" ]] || {
    echo "The Release Source Snapshot record is missing or unsafe: ${record_file}" >&2
    return 1
  }
  [[ -n "${destination}" && "${destination}" == /* &&
    "${destination}" != "/" &&
    ! -e "${destination}" &&
    ! -L "${destination}" ]] || {
    echo "The materialized release source destination is unsafe: ${destination}" >&2
    return 1
  }

  snapshot_json="$(jq -c . "${record_file}")"
  release_source_snapshot_verify_json "${repository}" "${snapshot_json}" || return 1
  source_commit="$(jq -er '.repository_revision' <<<"${snapshot_json}")"

  mkdir -p "$(dirname "${destination}")"
  destination_parent="$(cd "$(dirname "${destination}")" && pwd -P)"
  destination="${destination_parent}/$(basename "${destination}")"

  if ! git clone --quiet --no-hardlinks --no-checkout "${repository}" "${destination}"; then
    rm -rf "${destination}"
    return 1
  fi
  if ! git -C "${destination}" checkout --quiet --detach "${source_commit}"; then
    rm -rf "${destination}"
    return 1
  fi
  if ! release_source_snapshot_verify_record "${destination}" "${record_file}"; then
    rm -rf "${destination}"
    return 1
  fi

  printf '%s\n' "${destination}"
}
