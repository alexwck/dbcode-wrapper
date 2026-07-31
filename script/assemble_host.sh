#!/usr/bin/env bash

set -euo pipefail
umask 077

[[ $# -eq 0 ]] || {
  echo "assemble_host.sh is an internal build task and accepts no arguments." >&2
  exit 2
}

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/compiled_host_cache.sh"
source "${REPO_ROOT}/script/lib/generated_workspace.sh"
source "${REPO_ROOT}/script/lib/release_source_snapshot.sh"
source "${REPO_ROOT}/script/lib/dist_checkpoint.sh"

release_source_record="${DBCODE_WRAPPER_RELEASE_SOURCE_RECORD:-}"
[[ -f "${release_source_record}" && ! -L "${release_source_record}" ]] || {
  echo "Release assembly requires a Release Source Snapshot record." >&2
  exit 1
}
release_source_snapshot_verify_record "${REPO_ROOT}" "${release_source_record}"
release_source_revision="$(jq -er '.repository_revision' "${release_source_record}")"
dist_checkpoint_require_lease

require_command ditto
require_command jq
require_command shasum
assert_generated_path "${CACHE_ROOT}/compiled-hosts"
assert_generated_path "${APP_BUNDLE}"

compiled_host_input_id="$(compiled_host_input_id "${LOCK_FILE}" "${REPO_ROOT}")"
compiled_host_cache_status="hit"
if ! compiled_host_app="$(
  compiled_host_cache_resolve \
    "${CACHE_ROOT}" \
    "${compiled_host_input_id}" \
    "${APP_NAME}"
)"; then
  compiled_host_cache_status="miss-built"
  compiled_host_environment_record="$(dirname "${release_source_record}")/compiled-host-environment.json"
  "${REPO_ROOT}/script/compile_host.sh" \
    --environment-record "${compiled_host_environment_record}"
  release_source_snapshot_verify_record "${REPO_ROOT}" "${release_source_record}"

  compiled_app="${WORK_ROOT}/VSCode-darwin-${TARGET_ARCH}/${APP_NAME}.app"
  compiled_host_cache_publish \
    "${CACHE_ROOT}" \
    "${compiled_host_input_id}" \
    "${APP_NAME}" \
    "${compiled_app}" \
    "${release_source_revision}" \
    "${compiled_host_environment_record}"
  compiled_host_app="$(
    compiled_host_cache_resolve \
      "${CACHE_ROOT}" \
      "${compiled_host_input_id}" \
      "${APP_NAME}"
  )"
fi

release_source_snapshot_verify_record "${REPO_ROOT}" "${release_source_record}"
compiled_host_entry="$(
  compiled_host_cache_entry_path \
    "${CACHE_ROOT}" \
    "${compiled_host_input_id}" \
    "${APP_NAME}"
)"
compiled_host_receipt="${compiled_host_entry}/receipt.json"

cleanup_assembly_stage() {
  local exit_status=$?
  trap - EXIT INT TERM
  if ! dist_checkpoint_recover_promotion; then
    [[ "${exit_status}" -ne 0 ]] || exit_status=1
  fi
  exit "${exit_status}"
}
trap cleanup_assembly_stage EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

dist_checkpoint_create_stage
assembly_dist="${DIST_CHECKPOINT_STAGE}"
assembly_app="${assembly_dist}/${APP_NAME}.app"
assembly_manifest="${assembly_dist}/build-manifest.json"

ditto "${compiled_host_app}" "${assembly_app}"

copy_first_party_extensions() {
  local extension_name extension_source source_path destination_path
  while IFS=$'\t' read -r extension_name extension_source; do
    source_path="${REPO_ROOT}/${extension_source}"
    destination_path="${assembly_app}/Contents/Resources/app/extensions/${extension_name}"
    [[ -f "${source_path}/package.json" ]] || {
      echo "Missing reviewed first-party extension: ${source_path}" >&2
      exit 1
    }
    [[ ! -e "${destination_path}" ]] || {
      echo "First-party extension would replace an upstream extension: ${extension_name}" >&2
      exit 1
    }
    ditto "${source_path}" "${destination_path}"
  done < <(
    jq -r \
      '.build.built_in_extensions.first_party[] | [.name, .source] | @tsv' \
      "${REPO_ROOT}/host/slimming-policy.json"
  )
}

copy_first_party_extensions

runtime_setup_extension="${assembly_app}/Contents/Resources/app/extensions/dbcode-wrapper-profile-migration"
"${REPO_ROOT}/script/generate_profile_identity.sh" \
  "${runtime_setup_extension}/profile-identity.json"
"${REPO_ROOT}/script/generate_runtime_setup_manifest.sh" \
  "${runtime_setup_extension}/runtime-extension-set.json"

release_status_extension="${assembly_app}/Contents/Resources/app/extensions/dbcode-wrapper-release-status"
"${REPO_ROOT}/script/generate_installed_release_status.sh" \
  "${release_status_extension}/installed-release-set.json"
cp \
  "${REPO_ROOT}/host/approved-release-history.json" \
  "${release_status_extension}/approved-release-sets.json"

release_source_snapshot_verify_record "${REPO_ROOT}" "${release_source_record}"
"${REPO_ROOT}/script/sign_host.sh" "${assembly_app}"
DBCODE_WRAPPER_RELEASE_SOURCE_RECORD="${release_source_record}" \
DBCODE_WRAPPER_COMPILED_HOST_RECEIPT="${compiled_host_receipt}" \
DBCODE_WRAPPER_COMPILED_HOST_CACHE_STATUS="${compiled_host_cache_status}" \
  "${REPO_ROOT}/script/generate_manifest.sh" "${assembly_app}" "${assembly_manifest}"

[[ -d "${assembly_app}" && ! -L "${assembly_app}" ]] || {
  echo "The staged Host application is incomplete or unsafe: ${assembly_app}" >&2
  exit 1
}
[[ -f "${assembly_manifest}" && ! -L "${assembly_manifest}" ]] || {
  echo "The staged build manifest is incomplete or unsafe: ${assembly_manifest}" >&2
  exit 1
}

dist_checkpoint_promote_stage "${assembly_dist}"

echo "Built application: ${APP_BUNDLE}"
echo "Compiled-host cache: ${compiled_host_cache_status} (${compiled_host_input_id})"
echo "Manifest: ${BUILD_MANIFEST}"
