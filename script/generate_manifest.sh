#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/artifact_digest.sh"
source "${REPO_ROOT}/script/lib/compiled_host_cache.sh"
source "${REPO_ROOT}/script/lib/source_digest.sh"
source "${REPO_ROOT}/script/lib/release_identity.sh"
source "${REPO_ROOT}/script/lib/local_signing_identity.sh"
source "${REPO_ROOT}/script/lib/release_source_snapshot.sh"

require_command codesign
require_command jq
require_command plutil
require_command shasum

manifest_app="${1:-${APP_BUNDLE}}"
manifest_output="${2:-${BUILD_MANIFEST}}"
info_plist="${manifest_app}/Contents/Info.plist"
release_source_record="${DBCODE_WRAPPER_RELEASE_SOURCE_RECORD:-}"
compiled_host_receipt="${DBCODE_WRAPPER_COMPILED_HOST_RECEIPT:-}"
compiled_host_cache_status="${DBCODE_WRAPPER_COMPILED_HOST_CACHE_STATUS:-}"

[[ -f "${release_source_record}" && ! -L "${release_source_record}" ]] || {
  echo "Manifest generation requires a Release Source Snapshot record." >&2
  exit 1
}
[[ -f "${compiled_host_receipt}" && ! -L "${compiled_host_receipt}" ]] || {
  echo "Manifest generation requires a compiled-host cache receipt." >&2
  exit 1
}
case "${compiled_host_cache_status}" in
  hit|miss-built) ;;
  *)
    echo "Manifest generation requires a valid compiled-host cache status." >&2
    exit 1
    ;;
esac

release_source_snapshot_verify_record "${REPO_ROOT}" "${release_source_record}"
release_source_snapshot="$(
  jq -c '{
    schema_version,
    mode,
    requested_ref,
    repository_revision,
    tree_oid,
    snapshot_sha256,
    host_script_sha256,
    release_lock_sha256
  }' "${release_source_record}"
)"
git_revision="$(jq -er '.repository_revision' <<<"${release_source_snapshot}")"
release_lock_sha256="$(jq -er '.release_lock_sha256' <<<"${release_source_snapshot}")"
overlay_sha256="$(jq -er '.host_script_sha256' <<<"${release_source_snapshot}")"

expected_compiled_host_input_id="$(
  compiled_host_input_id "${LOCK_FILE}" "${REPO_ROOT}"
)"
jq -e \
  --arg input_id "${expected_compiled_host_input_id}" \
  --arg app_name "${APP_NAME}" '
    .schema_version == 2
    and .compiled_host_input_id == $input_id
    and .app_name == $app_name
    and (.source_revision | test("^[0-9a-f]{40}$"))
    and .app_digest_algorithm == "sha256-files-modes-links-v1"
    and (.app_sha256 | test("^[0-9a-f]{64}$"))
    and .compilation_environment.schema_version == 1
    and (.compilation_environment.node | type == "string" and length > 0)
    and (.compilation_environment.npm | type == "string" and length > 0)
    and (.compilation_environment.python | type == "string" and length > 0)
    and (.compilation_environment.clang | type == "string" and length > 0)
    and (.compilation_environment.macos_sdk | type == "string" and length > 0)
    and (.compilation_environment.macos | type == "string" and length > 0)
  ' "${compiled_host_receipt}" >/dev/null || {
  echo "The compiled-host receipt does not match the current compilation inputs." >&2
  exit 1
}
compiled_host="$(
  jq -c \
    --arg cache_status "${compiled_host_cache_status}" '
      {
        schema_version,
        input_id: .compiled_host_input_id,
        source_revision,
        app_digest_algorithm,
        app_sha256,
        compilation_environment,
        cache_status: $cache_status
      }
    ' "${compiled_host_receipt}"
)"

if [[ ! -f "${info_plist}" ]]; then
  echo "Cannot generate a manifest without ${info_plist}." >&2
  exit 1
fi
bundle_executable="$(plutil -extract CFBundleExecutable raw "${info_plist}")"
app_executable="${manifest_app}/Contents/MacOS/${bundle_executable}"
raw_runtime_versions="$(
  env -u NODE_OPTIONS \
    ELECTRON_RUN_AS_NODE=1 \
    "${app_executable}" -p 'JSON.stringify(process.versions)'
)"
jq -e . >/dev/null <<<"${raw_runtime_versions}"
runtime_versions="$(
  jq -c \
    --arg code_oss "${CODE_OSS_TAG}" \
    --arg host "${VSCODIUM_TAG}" \
    '. + {chromium: .chrome, code_oss: $code_oss, host: $host}' \
    <<<"${raw_runtime_versions}"
)"

plist_json="$(plutil -convert json -o - "${info_plist}")"
document_extensions="$(jq -c '[.CFBundleDocumentTypes[]?.CFBundleTypeExtensions[]?] | unique | sort' <<<"${plist_json}")"
app_entitlements_json="$(plutil -convert json -o - "${REPO_ROOT}/host/entitlements/app.plist")"
helper_entitlements_json="$(plutil -convert json -o - "${REPO_ROOT}/host/entitlements/helper.plist")"
plugin_entitlements_json="$(plutil -convert json -o - "${REPO_ROOT}/host/entitlements/helper-plugin.plist")"

artifact_sha256="$(artifact_digest "${manifest_app}")"
source_set_id="$(release_source_set_id)"
release_set_id="${source_set_id}-artifact-${artifact_sha256}"
shell_patch_revision="$(shell_patch_digest)"
runtime_extensions="$(
  jq -c '
    map({
        role,
        id,
        version,
        target_platform,
        verified_publisher,
        vsix_sha256: .sha256,
        signature_archive_sha256,
        public_key_id,
        public_key_sha256,
        install_location: "external-private-profile",
        required: true
      })
  ' <<<"${RUNTIME_EXTENSION_PACKAGES}"
)"
packaging_status="built-and-signed"
packaging_installed_kib="$(du -sk "${manifest_app}" | awk '{print $1}')"
packaging_built_in_extension_count="$(find "${manifest_app}/Contents/Resources/app/extensions" -mindepth 2 -maxdepth 2 -name package.json -print | wc -l | tr -d ' ')"
packaging_source_map_file_count="$(find "${manifest_app}" -type f -name '*.map' -print | wc -l | tr -d ' ')"
packaging_built_in_extension_mode="$(jq -er '.build.built_in_extensions.mode' "${REPO_ROOT}/host/slimming-policy.json")"
runtime_setup_manifest="${manifest_app}/Contents/Resources/app/extensions/dbcode-wrapper-profile-migration/runtime-extension-set.json"
[[ -f "${runtime_setup_manifest}" && ! -L "${runtime_setup_manifest}" ]] || {
  echo "The signed app is missing its focused first-run runtime setup manifest." >&2
  exit 1
}
runtime_setup_manifest_sha256="$(shasum -a 256 "${runtime_setup_manifest}" | awk '{print $1}')"

node_actual="$(jq -er '.compilation_environment.node' <<<"${compiled_host}")"
npm_actual="$(jq -er '.compilation_environment.npm' <<<"${compiled_host}")"
python_actual="$(jq -er '.compilation_environment.python' <<<"${compiled_host}")"
clang_full="$(jq -er '.compilation_environment.clang' <<<"${compiled_host}")"
sdk_actual="$(jq -er '.compilation_environment.macos_sdk' <<<"${compiled_host}")"
macos_actual="$(jq -er '.compilation_environment.macos' <<<"${compiled_host}")"
signature_identifier="$(codesign -dvv "${manifest_app}" 2>&1 | sed -n 's/^Identifier=//p')"
signature_requirement="$(codesign -d -r- "${manifest_app}" 2>&1 | sed -n '/^designated => /p')"
signature_details="$(codesign -dvvv "${manifest_app}" 2>&1)"
[[ "${signature_details}" != *'Signature=adhoc'* ]] || {
  echo "The DBCode Wrapper manifest refuses an ad-hoc signed app." >&2
  exit 1
}
load_local_signing_identity
verify_local_signed_code "${manifest_app}" "${signature_identifier}"
signature_kind="certificate"
cryptographic_update_identity_stable="null"
safe_storage_access_stable_across_rebuilds="null"
safe_storage_rebuild_behavior="pending-manual-rebuild-observation"
signing_continuity_evidence="pending-rebuilt-release-comparison"
signing_continuity_receipt_sha256=""

release_source_snapshot_verify_record "${REPO_ROOT}" "${release_source_record}"
mkdir -p "$(dirname "${manifest_output}")"
jq -n \
  --arg built_at_utc "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --arg repository_revision "${git_revision}" \
  --arg release_lock_sha256 "${release_lock_sha256}" \
  --arg shell_patch_revision "${shell_patch_revision}" \
  --arg overlay_sha256 "${overlay_sha256}" \
  --argjson release_source_snapshot "${release_source_snapshot}" \
  --argjson compiled_host "${compiled_host}" \
  --arg vscodium_tag "${VSCODIUM_TAG}" \
  --arg vscodium_commit "${VSCODIUM_COMMIT}" \
  --arg vscodium_published_at "${VSCODIUM_PUBLISHED_AT}" \
  --arg vscodium_release_notes_url "${VSCODIUM_RELEASE_NOTES_URL}" \
  --arg code_oss_tag "${CODE_OSS_TAG}" \
  --arg code_oss_commit "${CODE_OSS_COMMIT}" \
  --arg source_set_id "${source_set_id}" \
  --arg release_set_id "${release_set_id}" \
  --arg wrapper_version "${WRAPPER_VERSION}" \
  --arg compatibility_status "${RELEASE_COMPATIBILITY_STATUS}" \
  --arg validation_issue "${RELEASE_VALIDATION_ISSUE}" \
  --argjson profile_schema_version "${PROFILE_SCHEMA_VERSION}" \
  --arg build_node "${node_actual}" \
  --arg build_npm "${npm_actual}" \
  --arg build_python "${python_actual}" \
  --arg build_clang "${clang_full}" \
  --arg build_sdk "${sdk_actual}" \
  --arg build_macos "${macos_actual}" \
  --arg architecture "${TARGET_ARCH}" \
  --arg app_name "${APP_NAME}" \
  --arg application_name "${APPLICATION_NAME}" \
  --arg bundle_identifier "${BUNDLE_IDENTIFIER}" \
  --arg signature_identifier "${signature_identifier}" \
  --arg signature_kind "${signature_kind}" \
  --arg signature_requirement "${signature_requirement}" \
  --arg signature_scope "${SIGNING_SCOPE}" \
  --arg signing_certificate_common_name "${SIGNING_IDENTITY_COMMON_NAME}" \
  --arg signing_certificate_sha1 "${LOCAL_SIGNING_CERTIFICATE_SHA1}" \
  --arg signing_certificate_sha256 "${LOCAL_SIGNING_CERTIFICATE_SHA256}" \
  --arg signing_continuity_evidence "${signing_continuity_evidence}" \
  --arg signing_continuity_receipt_sha256 "${signing_continuity_receipt_sha256}" \
  --arg safe_storage_rebuild_behavior "${safe_storage_rebuild_behavior}" \
  --arg url_scheme "${URL_SCHEME}" \
  --arg shared_data_folder_name "${SHARED_DATA_FOLDER_NAME}" \
  --arg data_folder_name "${DATA_FOLDER_NAME}" \
  --arg artifact_sha256 "${artifact_sha256}" \
  --arg packaging_status "${packaging_status}" \
  --arg packaging_built_in_extension_mode "${packaging_built_in_extension_mode}" \
  --arg runtime_setup_manifest_sha256 "${runtime_setup_manifest_sha256}" \
  --argjson packaging_installed_kib "${packaging_installed_kib}" \
  --argjson built_in_extension_count "${packaging_built_in_extension_count}" \
  --argjson source_map_file_count "${packaging_source_map_file_count}" \
  --arg focused_shell_result_location "${FOCUSED_SHELL_RESULT_LOCATION}" \
  --argjson focused_shell_enabled "${FOCUSED_SHELL_ENABLED}" \
  --argjson focused_shell_narrow_breakpoint "${FOCUSED_SHELL_NARROW_BREAKPOINT}" \
  --argjson runtime_extensions "${runtime_extensions}" \
  --argjson runtime_versions "${runtime_versions}" \
  --argjson document_extensions "${document_extensions}" \
  --argjson app_entitlements "${app_entitlements_json}" \
  --argjson helper_entitlements "${helper_entitlements_json}" \
  --argjson plugin_entitlements "${plugin_entitlements_json}" \
  --argjson cryptographic_update_identity_stable "${cryptographic_update_identity_stable}" \
  --argjson safe_storage_access_stable_across_rebuilds "${safe_storage_access_stable_across_rebuilds}" \
  '{
    schema_version: 6,
    built_at_utc: $built_at_utc,
    release: {
      wrapper_version: $wrapper_version,
      source_set_id: $source_set_id,
      release_set_id: $release_set_id,
      compatibility_status: $compatibility_status,
      validation_issue: $validation_issue
    },
    source: {
      repository_revision: $repository_revision,
      release_lock_sha256: $release_lock_sha256,
      shell_patch_revision: $shell_patch_revision,
      overlay_sha256: $overlay_sha256,
      snapshot: $release_source_snapshot,
      compiled_host: $compiled_host,
      vscodium: {
        tag: $vscodium_tag,
        commit: $vscodium_commit,
        published_at: $vscodium_published_at,
        release_notes_url: $vscodium_release_notes_url
      },
      code_oss: {tag: $code_oss_tag, commit: $code_oss_commit}
    },
    profile: {
      schema_version: $profile_schema_version,
      data_folder_name: $data_folder_name,
      shared_data_folder_name: $shared_data_folder_name,
      isolated_from_vscode: true
    },
    toolchain: {
      node: $build_node,
      npm: $build_npm,
      python: $build_python,
      clang: $build_clang,
      macos_sdk: $build_sdk,
      macos: $build_macos
    },
    runtime: $runtime_versions,
    runtime_extensions: $runtime_extensions,
    packaging: {
      status: $packaging_status,
      layer: "vscodium",
      built_in_extension_mode: $packaging_built_in_extension_mode,
      built_in_extension_count: $built_in_extension_count,
      source_map_file_count: $source_map_file_count,
      installed_kib: $packaging_installed_kib,
      updater_enabled: false,
      external_runtime_in_app: false,
      external_runtime_setup: "focused-pinned-official-sources",
      external_runtime_setup_manifest_sha256: $runtime_setup_manifest_sha256
    },
    artifact: {
      app_name: $app_name,
      application_name: $application_name,
      platform: "darwin",
      architecture: $architecture,
      bundle_identifier: $bundle_identifier,
      signature_identifier: $signature_identifier,
      signature_kind: $signature_kind,
      signature_requirement: $signature_requirement,
      signature_scope: $signature_scope,
      signing_certificate_common_name: $signing_certificate_common_name,
      signing_certificate_sha1: $signing_certificate_sha1,
      signing_certificate_sha256: $signing_certificate_sha256,
      cryptographic_update_identity_stable: $cryptographic_update_identity_stable,
      signing_continuity_evidence: $signing_continuity_evidence,
      signing_continuity_receipt_sha256: (
        if $signing_continuity_receipt_sha256 == ""
        then null
        else $signing_continuity_receipt_sha256
        end
      ),
      safe_storage_access_stable_across_rebuilds: $safe_storage_access_stable_across_rebuilds,
      safe_storage_rebuild_behavior: $safe_storage_rebuild_behavior,
      url_scheme: $url_scheme,
      shared_data_folder_name: $shared_data_folder_name,
      document_extensions: $document_extensions,
      entitlements: {
        app: $app_entitlements,
        helper: $helper_entitlements,
        plugin: $plugin_entitlements
      },
      focused_shell: {
        enabled: $focused_shell_enabled,
        result_location: $focused_shell_result_location,
        narrow_breakpoint: $focused_shell_narrow_breakpoint
      },
      sha256: $artifact_sha256
    }
  }' > "${manifest_output}"

echo "Build manifest: ${manifest_output}"
