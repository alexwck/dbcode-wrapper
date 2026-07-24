#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/artifact_digest.sh"
source "${REPO_ROOT}/script/lib/approved_release_set.sh"
source "${REPO_ROOT}/script/lib/generated_workspace.sh"

release_id="${1:-}"
[[ -n "${release_id}" && "${release_id}" =~ ^[a-z0-9][a-z0-9._-]+$ ]] || {
  echo "Usage: ./script/verify_release_rollback.sh <release-id>" >&2
  exit 2
}

history_file="${REPO_ROOT}/host/approved-release-history.json"
snapshot_parent="$(generated_workspace_path "rollback-evidence")"
snapshot_root="${snapshot_parent}/${release_id}"
generated_workspace_assert_path "rollback-evidence" "${snapshot_root}"
snapshot_manifest="${snapshot_root}/rollback-manifest.json"

history_entry="$(approved_release_history_record "${history_file}" "${release_id}")"

[[ -f "${snapshot_manifest}" && ! -L "${snapshot_manifest}" ]] || {
  echo "Prepared rollback snapshot not found: ${snapshot_manifest}" >&2
  exit 1
}

app_relative="$(jq -er '.artifact.app_path' "${snapshot_manifest}")"
build_manifest_relative="$(jq -er '.artifact.build_manifest_path' "${snapshot_manifest}")"
profile_relative="$(jq -er '.runtime.profile_path' "${snapshot_manifest}")"
release_lock_relative="$(jq -er '.source.release_lock_path' "${snapshot_manifest}")"
case "${app_relative}" in "${APP_NAME}.app") ;; *) echo "Unexpected rollback app path." >&2; exit 1;; esac
case "${build_manifest_relative}" in build-manifest.json) ;; *) echo "Unexpected rollback manifest path." >&2; exit 1;; esac
case "${profile_relative}" in profile) ;; *) echo "Unexpected rollback profile path." >&2; exit 1;; esac
case "${release_lock_relative}" in release-lock.json) ;; *) echo "Unexpected rollback release-lock path." >&2; exit 1;; esac

snapshot_app="${snapshot_root}/${app_relative}"
snapshot_build_manifest="${snapshot_root}/${build_manifest_relative}"
snapshot_profile="${snapshot_root}/${profile_relative}"
snapshot_extensions="${snapshot_profile}/extensions"
snapshot_lock="${snapshot_root}/${release_lock_relative}"

[[ -d "${snapshot_app}" && ! -L "${snapshot_app}" ]] || { echo "Rollback app is missing." >&2; exit 1; }
[[ -f "${snapshot_build_manifest}" && ! -L "${snapshot_build_manifest}" ]] || { echo "Rollback build manifest is missing." >&2; exit 1; }
[[ -d "${snapshot_extensions}" && ! -L "${snapshot_extensions}" ]] || { echo "Rollback extension root is missing." >&2; exit 1; }
[[ -f "${snapshot_lock}" && ! -L "${snapshot_lock}" ]] || { echo "Rollback release lock is missing." >&2; exit 1; }

codesign --verify --deep --strict "${snapshot_app}"
actual_requirement="$(codesign -d -r- "${snapshot_app}" 2>&1 | sed -n '/^designated => /p')"
actual_app_sha="$(artifact_digest "${snapshot_app}")"
actual_build_manifest_sha="$(shasum -a 256 "${snapshot_build_manifest}" | awk '{print $1}')"
actual_extensions_sha="$(artifact_digest "${snapshot_extensions}")"
actual_release_lock_sha="$(shasum -a 256 "${snapshot_lock}" | awk '{print $1}')"
installed_extensions="$({
  while IFS= read -r extension_manifest; do
    jq -r '.publisher + "." + .name + "@" + .version' "${extension_manifest}"
  done < <(find "${snapshot_extensions}" -mindepth 2 -maxdepth 2 -name package.json -type f -print)
} | LC_ALL=C sort)"

expected_dbcode_id="$(jq -er '.dbcode.id' <<<"${history_entry}")"
expected_dbcode_version="$(jq -er '.dbcode.version' <<<"${history_entry}")"
expected_dbcode_sha="$(jq -er '.dbcode.vsix_sha256' <<<"${history_entry}")"
expected_dbcode_signature_sha="$(jq -er '.dbcode.signature_archive_sha256' <<<"${history_entry}")"
expected_source_commit="$(jq -er '.source_commit' <<<"${history_entry}")"
expected_vscodium_tag="$(jq -er '.host.vscodium_tag' <<<"${history_entry}")"
expected_vscodium_commit="$(jq -er '.host.vscodium_commit' <<<"${history_entry}")"
expected_code_oss_tag="$(jq -er '.host.code_oss_tag' <<<"${history_entry}")"
expected_code_oss_commit="$(jq -er '.host.code_oss_commit' <<<"${history_entry}")"
expected_inventory="${expected_dbcode_id}@${expected_dbcode_version}"
[[ "${installed_extensions}" == "${expected_inventory}" ]] || {
  echo "Rollback extension inventory mismatch." >&2
  printf 'Expected: %s\nActual: %s\n' "${expected_inventory}" "${installed_extensions}" >&2
  exit 1
}

jq -e \
  --arg dbcode_id "${expected_dbcode_id}" \
  --arg dbcode_version "${expected_dbcode_version}" \
  --arg dbcode_sha "${expected_dbcode_sha}" \
  --arg dbcode_signature_sha "${expected_dbcode_signature_sha}" \
  --arg vscodium_tag "${expected_vscodium_tag}" \
  --arg vscodium_commit "${expected_vscodium_commit}" \
  --arg code_oss_tag "${expected_code_oss_tag}" \
  --arg code_oss_commit "${expected_code_oss_commit}" '
    .extension.dbcode.id == $dbcode_id
    and .extension.dbcode.version == $dbcode_version
    and .extension.dbcode.sha256 == $dbcode_sha
    and .extension.dbcode.signature_archive_sha256 == $dbcode_signature_sha
    and .upstream.vscodium.tag == $vscodium_tag
    and .upstream.vscodium.commit == $vscodium_commit
    and .upstream.code_oss.tag == $code_oss_tag
    and .upstream.code_oss.commit == $code_oss_commit
  ' "${snapshot_lock}" >/dev/null || {
  echo "Rollback release lock does not match the approved release history." >&2
  exit 1
}

jq -e \
  --arg source_commit "${expected_source_commit}" \
  --arg release_lock_sha "${actual_release_lock_sha}" \
  --arg dbcode_id "${expected_dbcode_id}" \
  --arg dbcode_version "${expected_dbcode_version}" \
  --arg dbcode_sha "${expected_dbcode_sha}" \
  --arg dbcode_signature_sha "${expected_dbcode_signature_sha}" \
  --arg vscodium_tag "${expected_vscodium_tag}" \
  --arg vscodium_commit "${expected_vscodium_commit}" \
  --arg code_oss_tag "${expected_code_oss_tag}" \
  --arg code_oss_commit "${expected_code_oss_commit}" '
    .source.repository_revision == $source_commit
    and .source.release_lock_sha256 == $release_lock_sha
    and .source.vscodium == {tag: $vscodium_tag, commit: $vscodium_commit}
    and .source.code_oss == {tag: $code_oss_tag, commit: $code_oss_commit}
    and .approved_extension.id == $dbcode_id
    and .approved_extension.version == $dbcode_version
    and .approved_extension.vsix_sha256 == $dbcode_sha
    and .approved_extension.signature_archive_sha256 == $dbcode_signature_sha
    and .artifact.bundle_identifier == "io.alexabelle.dbcodewrapper"
  ' "${snapshot_build_manifest}" >/dev/null || {
  echo "Rollback build manifest does not match the approved release history and release lock." >&2
  exit 1
}

jq -e \
  --arg release_id "${release_id}" \
  --arg source_commit "${expected_source_commit}" \
  --arg release_lock_sha256 "${actual_release_lock_sha}" \
  --arg app_sha256 "${actual_app_sha}" \
  --arg build_manifest_sha256 "${actual_build_manifest_sha}" \
  --arg extensions_sha256 "${actual_extensions_sha}" \
  --arg signature_requirement "${actual_requirement}" \
  --arg inventory "${installed_extensions}" '
    .schema_version == 1
    and .release_id == $release_id
    and .source_commit == $source_commit
    and .source.release_lock_path == "release-lock.json"
    and .source.release_lock_sha256 == $release_lock_sha256
    and .artifact.app_sha256 == $app_sha256
    and .artifact.build_manifest_sha256 == $build_manifest_sha256
    and .artifact.signature_requirement == $signature_requirement
    and .runtime.extensions_sha256 == $extensions_sha256
    and .runtime.installed_extensions == $inventory
    and .verification.static_host_smoke == true
    and .verification.mock_keychain_launch_smoke == true
    and .verification.exact_extension_inventory == true
  ' "${snapshot_manifest}" >/dev/null || {
  echo "Rollback snapshot does not match its verified manifest." >&2
  exit 1
}

[[ "$(jq -er '.artifact.sha256' "${snapshot_build_manifest}")" == "${actual_app_sha}" ]] || {
  echo "The retained app does not match its original build manifest." >&2
  exit 1
}

echo "Verified runnable rollback snapshot: ${release_id}"
