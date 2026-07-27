#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

history_file="${REPO_ROOT}/host/approved-release-history.json"
prepare_script="${REPO_ROOT}/script/prepare_release_rollback.sh"
verify_script="${REPO_ROOT}/script/verify_release_rollback.sh"
preview_script="${REPO_ROOT}/script/preview_release_rollback.sh"

jq -e '
  .schema_version == 2
  and any(.approved_release_sets[];
    .id == "code-oss-1.126.0-dbcode-1.36.1"
    and .compatibility_status == "approved"
    and .source_commit == "cc2b112cca02f41ef9853ccde60176a18f0852e0"
    and .target == {platform: "darwin", architecture: "arm64"}
    and .profile.schema_version == 1
    and .manifest.schema_version == 2
    and (.manifest.build_manifest_sha256 | test("^[0-9a-f]{64}$"))
    and (.manifest.artifact_sha256 | test("^[0-9a-f]{64}$"))
    and (.manifest.shell_patch_revision | test("^[0-9a-f]{64}$"))
    and (.manifest.overlay_sha256 | test("^[0-9a-f]{64}$"))
    and .manifest.packaging_status == "built-and-signed"
    and .rollback.kind == "source-rebuild"
    and .rollback.prepare_command == "./script/prepare_release_rollback.sh code-oss-1.126.0-dbcode-1.36.1"
    and .rollback.verify_command == "./script/verify_release_rollback.sh code-oss-1.126.0-dbcode-1.36.1"
    and .rollback.preview_command == "./script/preview_release_rollback.sh code-oss-1.126.0-dbcode-1.36.1 --clone-current-profile"
  )
' "${history_file}" >/dev/null || {
  echo "Approved release history must name the exact guarded rollback operations." >&2
  exit 1
}

for rollback_script in "${prepare_script}" "${verify_script}" "${preview_script}"; do
  [[ -f "${rollback_script}" ]] || { echo "Missing rollback script: ${rollback_script}" >&2; exit 1; }
  bash -n "${rollback_script}"
done

for required_step in \
  'worktree add --detach' \
  './script/build_host.sh' \
  'script/smoke_host.sh' \
  './script/prepare_dbcode.sh --profile qa' \
  'verify_release_rollback.sh'; do
  rg -Fq "${required_step}" "${prepare_script}" || {
    echo "Rollback preparation is missing: ${required_step}" >&2
    exit 1
  }
done

rg -Fq 'mktemp -d /private/tmp/dbcode-rollback-smoke.XXXXXX' "${prepare_script}" || {
  echo "Rollback smoke must use a short temporary path for the macOS IPC socket." >&2
  exit 1
}
rg -Fq 'ln -s "${worktree_root}" "${short_smoke_root}/repo"' "${prepare_script}" || {
  echo "Rollback smoke must expose the exact detached worktree through the short path." >&2
  exit 1
}
if rg -Fq 'ln -s "${shared_target}"' "${prepare_script}"; then
  echo "Rollback builds must not bypass generated-path validation through shared cache links." >&2
  exit 1
fi
rg -Fq 'rm "${legacy_shared_link}"' "${prepare_script}" || {
  echo "Rollback preparation must remove only its known legacy shared-cache links." >&2
  exit 1
}

rg -Fq 'codesign --verify --deep --strict' "${verify_script}" || {
  echo "Rollback verification must validate the retained app signature." >&2
  exit 1
}
rg -Fq 'artifact_digest "${snapshot_app}"' "${verify_script}" || {
  echo "Rollback verification must validate the retained app digest." >&2
  exit 1
}
rg -Fq 'Rollback release lock does not match the approved release history.' "${verify_script}" || {
  echo "Rollback verification must bind the retained release lock to the approved history." >&2
  exit 1
}
rg -Fq '.source.release_lock_sha256 == $release_lock_sha' "${verify_script}" || {
  echo "Rollback verification must bind the original build manifest to the retained release lock." >&2
  exit 1
}
for rollback_script in "${verify_script}" "${preview_script}"; do
  rg -Fq 'release_specification_historical_record profile "${snapshot_lock}"' "${rollback_script}" || {
    echo "Rollback must derive the retained app identity from its Release Specification: ${rollback_script}" >&2
    exit 1
  }
done
if rg -Fq 'io.alexabelle.dbcodewrapper' "${verify_script}"; then
  echo "Rollback verification must not duplicate the production bundle identifier." >&2
  exit 1
fi
rg -Fq -- '--clone-current-profile' "${preview_script}" || {
  echo "Rollback preview must support a disposable clone of the current DBCode profile." >&2
  exit 1
}
rg -Fq 'ditto "${snapshot_root}/profile/extensions" "${preview_root}/extensions"' "${preview_script}" || {
  echo "Rollback preview must use the previous release extension root as one set." >&2
  exit 1
}
rg -Fq 'mktemp -d /private/tmp/dbcode-rollback-preview.XXXXXX' "${preview_script}" || {
  echo "Rollback preview must use a short temporary path for the macOS IPC socket." >&2
  exit 1
}
if rg -Fq '"${APP_BUNDLE}"' "${preview_script}"; then
  echo "Rollback preview must not replace or launch the current approved app." >&2
  exit 1
fi

echo "Release rollback snapshot contracts passed."
