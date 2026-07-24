#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/artifact_digest.sh"
source "${REPO_ROOT}/script/lib/approved_release_set.sh"
source "${REPO_ROOT}/script/lib/generated_workspace.sh"

release_id="${1:-}"
[[ -n "${release_id}" && "${release_id}" =~ ^[a-z0-9][a-z0-9._-]+$ ]] || {
  echo "Usage: ./script/prepare_release_rollback.sh <release-id>" >&2
  exit 2
}

history_file="${REPO_ROOT}/host/approved-release-history.json"
history_entry="$(approved_release_history_record "${history_file}" "${release_id}")"
source_commit="$(jq -er '.source_commit' <<<"${history_entry}")"
snapshot_parent="$(generated_workspace_path "rollback-evidence")"
snapshot_root="${snapshot_parent}/${release_id}"
worktree_parent="$(generated_workspace_path "rollback-worktrees")"
worktree_root="${worktree_parent}/${release_id}"
generated_workspace_assert_path "rollback-evidence" "${snapshot_root}"
generated_workspace_assert_path "rollback-worktrees" "${worktree_root}"

if [[ -d "${snapshot_root}" ]]; then
  "${REPO_ROOT}/script/verify_release_rollback.sh" "${release_id}"
  exit 0
fi

git -C "${REPO_ROOT}" cat-file -e "${source_commit}^{commit}"
mkdir -p "$(dirname "${worktree_root}")" "${snapshot_parent}"
if [[ -d "${worktree_root}" ]]; then
  existing_source_commit="$(git -C "${worktree_root}" rev-parse HEAD)"
  [[ "${existing_source_commit}" == "${source_commit}" ]] || {
    echo "Existing rollback worktree is from the wrong source commit: ${existing_source_commit}" >&2
    exit 1
  }
  echo "Resuming retained rollback worktree: ${worktree_root}"
else
  git -C "${REPO_ROOT}" worktree add --detach "${worktree_root}" "${source_commit}"
fi

build_succeeded="no"
cleanup_worktree() {
  if [[ "${build_succeeded}" == "yes" ]]; then
    git -C "${REPO_ROOT}" worktree remove --force "${worktree_root}"
  else
    echo "Rollback build failed; retained diagnostic worktree: ${worktree_root}" >&2
  fi
}
trap cleanup_worktree EXIT INT TERM

for legacy_shared_directory in cache toolchains; do
  legacy_shared_link="${worktree_root}/.build/${legacy_shared_directory}"
  legacy_shared_target="${BUILD_ROOT}/${legacy_shared_directory}"
  if [[ -L "${legacy_shared_link}" ]]; then
    [[ "$(readlink "${legacy_shared_link}")" == "${legacy_shared_target}" ]] || {
      echo "Rollback worktree has an unexpected ${legacy_shared_directory} link." >&2
      exit 1
    }
    rm "${legacy_shared_link}"
    echo "Removed the legacy shared rollback ${legacy_shared_directory} link."
  fi
done

source_app="${worktree_root}/dist/${APP_NAME}.app"
source_manifest="${worktree_root}/dist/build-manifest.json"
source_profile="${worktree_root}/.build/qa/profile"

if [[ -d "${source_app}" && -f "${source_manifest}" ]]; then
  echo "Reusing the retained rollback app; the smoke test will verify it before snapshotting."
else
  (
    cd "${worktree_root}"
    ./script/build_host.sh
  )
fi

short_smoke_root="$(mktemp -d /private/tmp/dbcode-rollback-smoke.XXXXXX)"
cleanup_short_smoke() {
  [[ -n "${short_smoke_root:-}" ]] || return 0
  case "${short_smoke_root}" in
    /private/tmp/dbcode-rollback-smoke.*) rm -rf "${short_smoke_root}" ;;
    *) echo "Refusing to remove unexpected rollback smoke path: ${short_smoke_root}" >&2; return 1;;
  esac
  short_smoke_root=""
}
trap 'cleanup_short_smoke; cleanup_worktree' EXIT INT TERM
ln -s "${worktree_root}" "${short_smoke_root}/repo"
"${short_smoke_root}/repo/script/smoke_host.sh"
cleanup_short_smoke
trap cleanup_worktree EXIT INT TERM

(
  cd "${worktree_root}"
  ./script/prepare_dbcode.sh --profile qa
)

[[ -d "${source_app}" && -f "${source_manifest}" && -d "${source_profile}/extensions" ]] || {
  echo "The previous release build did not produce a complete rollback set." >&2
  exit 1
}

staging_root="$(mktemp -d "${snapshot_parent}/.${release_id}.staging.XXXXXX")"
cleanup_staging() {
  [[ -d "${staging_root}" ]] || return 0
  case "${staging_root}" in
    "${snapshot_parent}/.${release_id}.staging."*) rm -rf "${staging_root}" ;;
    *) echo "Refusing to remove unexpected rollback staging path: ${staging_root}" >&2; return 1;;
  esac
}
trap 'cleanup_staging; cleanup_worktree' EXIT INT TERM

ditto "${source_app}" "${staging_root}/${APP_NAME}.app"
cp "${source_manifest}" "${staging_root}/build-manifest.json"
ditto "${source_profile}" "${staging_root}/profile"
cp "${worktree_root}/host/release-lock.json" "${staging_root}/release-lock.json"

snapshot_app="${staging_root}/${APP_NAME}.app"
snapshot_extensions="${staging_root}/profile/extensions"
snapshot_lock="${staging_root}/release-lock.json"
installed_extensions="$({
  while IFS= read -r extension_manifest; do
    jq -r '.publisher + "." + .name + "@" + .version' "${extension_manifest}"
  done < <(find "${snapshot_extensions}" -mindepth 2 -maxdepth 2 -name package.json -type f -print)
} | LC_ALL=C sort)"

jq -n \
  --arg created_at_utc "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --arg release_id "${release_id}" \
  --arg source_commit "${source_commit}" \
  --arg release_lock_path "release-lock.json" \
  --arg release_lock_sha256 "$(shasum -a 256 "${snapshot_lock}" | awk '{print $1}')" \
  --arg app_path "${APP_NAME}.app" \
  --arg app_sha256 "$(artifact_digest "${snapshot_app}")" \
  --arg build_manifest_sha256 "$(shasum -a 256 "${staging_root}/build-manifest.json" | awk '{print $1}')" \
  --arg signature_requirement "$(codesign -d -r- "${snapshot_app}" 2>&1 | sed -n '/^designated => /p')" \
  --arg extensions_sha256 "$(artifact_digest "${snapshot_extensions}")" \
  --arg installed_extensions "${installed_extensions}" '
    {
      schema_version: 1,
      created_at_utc: $created_at_utc,
      release_id: $release_id,
      source_commit: $source_commit,
      source: {
        release_lock_path: $release_lock_path,
        release_lock_sha256: $release_lock_sha256
      },
      artifact: {
        app_path: $app_path,
        app_sha256: $app_sha256,
        build_manifest_path: "build-manifest.json",
        build_manifest_sha256: $build_manifest_sha256,
        signature_requirement: $signature_requirement
      },
      runtime: {
        profile_path: "profile",
        extensions_sha256: $extensions_sha256,
        installed_extensions: $installed_extensions
      },
      verification: {
        static_host_smoke: true,
        mock_keychain_launch_smoke: true,
        exact_extension_inventory: true
      }
    }
  ' > "${staging_root}/rollback-manifest.json"

mv "${staging_root}" "${snapshot_root}"
build_succeeded="yes"
trap cleanup_worktree EXIT INT TERM
"${REPO_ROOT}/script/verify_release_rollback.sh" "${release_id}"

echo "Prepared runnable rollback snapshot: ${snapshot_root}"
