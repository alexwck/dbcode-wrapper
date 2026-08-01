#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/generated_workspace.sh"
source "${REPO_ROOT}/script/lib/artifact_digest.sh"
source "${REPO_ROOT}/script/lib/compiled_host_cache.sh"
source "${REPO_ROOT}/script/lib/source_digest.sh"
source "${REPO_ROOT}/script/lib/release_identity.sh"
source "${REPO_ROOT}/script/lib/local_signing_identity.sh"
source "${REPO_ROOT}/script/lib/release_source_snapshot.sh"
source "${REPO_ROOT}/script/lib/dist_checkpoint.sh"
source "${REPO_ROOT}/script/lib/host_slimming.sh"

dist_checkpoint_acquire "static-smoke"
trap 'dist_checkpoint_exit "$?"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

usage() {
  echo "Usage: ./script/smoke_host.sh [--app APP --manifest FILE]" >&2
  exit 2
}

smoke_app="${APP_BUNDLE}"
smoke_manifest="${BUILD_MANIFEST}"
explicit_app="no"
explicit_manifest="no"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      [[ $# -ge 2 ]] || usage
      smoke_app="$2"
      explicit_app="yes"
      shift
      ;;
    --manifest)
      [[ $# -ge 2 ]] || usage
      smoke_manifest="$2"
      explicit_manifest="yes"
      shift
      ;;
    *)
      usage
      ;;
  esac
  shift
done
[[ "${explicit_app}" == "${explicit_manifest}" ]] || usage

APP_BUNDLE="${smoke_app}"
BUILD_MANIFEST="${smoke_manifest}"

info_plist="${APP_BUNDLE}/Contents/Info.plist"
product_json="${APP_BUNDLE}/Contents/Resources/app/product.json"
slimming_policy="${REPO_ROOT}/host/slimming-policy.json"
built_in_extensions_root="${APP_BUNDLE}/Contents/Resources/app/extensions"
if [[ ! -f "${info_plist}" || ! -f "${product_json}" || ! -f "${BUILD_MANIFEST}" || \
  ! -f "${slimming_policy}" || ! -d "${built_in_extensions_root}" ]]; then
  echo "Static host inputs are incomplete: app=${APP_BUNDLE}, manifest=${BUILD_MANIFEST}" >&2
  exit 1
fi

bundle_name="$(plutil -extract CFBundleName raw "${info_plist}")"
bundle_identifier="$(plutil -extract CFBundleIdentifier raw "${info_plist}")"
bundle_executable="$(plutil -extract CFBundleExecutable raw "${info_plist}")"
bundle_url_scheme="$(plutil -extract CFBundleURLTypes.0.CFBundleURLSchemes.0 raw "${info_plist}")"
app_executable="${APP_BUNDLE}/Contents/MacOS/${bundle_executable}"

[[ "${bundle_name}" == "${APP_NAME}" ]] || { echo "Unexpected bundle name: ${bundle_name}" >&2; exit 1; }
[[ "${bundle_identifier}" == "${BUNDLE_IDENTIFIER}" ]] || { echo "Unexpected bundle identifier: ${bundle_identifier}" >&2; exit 1; }
[[ "${bundle_url_scheme}" == "${URL_SCHEME}" ]] || { echo "Unexpected URL scheme: ${bundle_url_scheme}" >&2; exit 1; }
[[ "$(jq -er '.sharedDataFolderName' "${product_json}")" == "${SHARED_DATA_FOLDER_NAME}" ]] || { echo "Unexpected shared-data folder identity." >&2; exit 1; }
[[ "$(jq -er '.darwinProfileUUID' "${product_json}")" == "${DARWIN_PROFILE_UUID}" ]] || { echo "Unexpected macOS profile UUID." >&2; exit 1; }
[[ "$(jq -er '.darwinProfilePayloadUUID' "${product_json}")" == "${DARWIN_PROFILE_PAYLOAD_UUID}" ]] || { echo "Unexpected macOS profile payload UUID." >&2; exit 1; }
[[ "$(jq -er '.dbcodeWrapperFocusedShell' "${product_json}")" == "true" ]] || { echo "Production must enable the focused DBCode shell." >&2; exit 1; }
[[ "$(jq -er '.dbcodeWrapperFocusedShellNarrowBreakpoint' "${product_json}")" == "${FOCUSED_SHELL_NARROW_BREAKPOINT}" ]] || { echo "Unexpected focused-shell narrow breakpoint." >&2; exit 1; }
[[ "$(jq -er '.dbcodeWrapperStorageNamespace' "${product_json}")" == "${STORAGE_NAMESPACE}" ]] || { echo "Unexpected focused-shell storage namespace." >&2; exit 1; }
[[ "$(jq -er '.dbcodeWrapperQueryFolderName' "${product_json}")" == "${QUERY_FOLDER_NAME}" ]] || { echo "Unexpected focused-shell query folder." >&2; exit 1; }

validate_packaged_host_slimming "${APP_BUNDLE}" "${slimming_policy}"

architecture_list="$(lipo -archs "${app_executable}")"
[[ " ${architecture_list} " == *" ${TARGET_ARCH} "* ]] || { echo "The app is not ${TARGET_ARCH}: ${architecture_list}" >&2; exit 1; }
if [[ "${architecture_list}" == *"x86_64"* ]]; then
  echo "The proof bundle unexpectedly contains x86_64 code." >&2
  exit 1
fi

plist_json="$(plutil -convert json -o - "${info_plist}")"
actual_extensions="$(jq -c '[.CFBundleDocumentTypes[]?.CFBundleTypeExtensions[]?] | unique | sort' <<<"${plist_json}")"
expected_extensions="$(jq -c 'unique | sort' <<<"${DOCUMENT_EXTENSIONS}")"
[[ "${actual_extensions}" == "${expected_extensions}" ]] || {
  echo "Database file associations do not match the release lock." >&2
  echo "Expected: ${expected_extensions}" >&2
  echo "Actual:   ${actual_extensions}" >&2
  exit 1
}

codesign --verify --deep --strict "${APP_BUNDLE}"
load_local_signing_identity
expected_designated_requirement="$(local_signing_expected_requirement "${BUNDLE_IDENTIFIER}")"
actual_designated_requirement="$(codesign -d -r- "${APP_BUNDLE}" 2>&1 | sed -n '/^designated => /p')"
[[ "${actual_designated_requirement}" == "${expected_designated_requirement}" ]] || {
  echo "The app does not have the expected persistent local-signing requirement." >&2
  exit 1
}
verify_local_signed_code "${APP_BUNDLE}" "${BUNDLE_IDENTIFIER}"
manifest_digest="$(jq -er '.artifact.sha256' "${BUILD_MANIFEST}")"
current_digest="$(artifact_digest "${APP_BUNDLE}")"
[[ "${manifest_digest}" == "${current_digest}" ]] || { echo "Application digest does not match the build manifest." >&2; exit 1; }
[[ "$(jq -er '.artifact.bundle_identifier' "${BUILD_MANIFEST}")" == "${BUNDLE_IDENTIFIER}" ]] || { echo "Manifest bundle identifier mismatch." >&2; exit 1; }
[[ "$(jq -er '.artifact.signature_requirement' "${BUILD_MANIFEST}")" == "${expected_designated_requirement}" ]] || { echo "Manifest signing requirement mismatch." >&2; exit 1; }
[[ "$(jq -er '.artifact.signature_scope' "${BUILD_MANIFEST}")" == "${SIGNING_SCOPE}" ]] || { echo "Manifest signing scope mismatch." >&2; exit 1; }
[[ "$(jq -er '.artifact.signature_kind' "${BUILD_MANIFEST}")" == "certificate" ]] || { echo "Manifest signing kind mismatch." >&2; exit 1; }
[[ "$(jq -er '.artifact.signing_certificate_sha1' "${BUILD_MANIFEST}")" == "${LOCAL_SIGNING_CERTIFICATE_SHA1}" ]] || { echo "Manifest signing certificate SHA-1 mismatch." >&2; exit 1; }
[[ "$(jq -er '.artifact.signing_certificate_sha256' "${BUILD_MANIFEST}")" == "${LOCAL_SIGNING_CERTIFICATE_SHA256}" ]] || { echo "Manifest signing certificate SHA-256 mismatch." >&2; exit 1; }
jq -e '
  .artifact.cryptographic_update_identity_stable == null
  and .artifact.signing_continuity_evidence == "pending-rebuilt-release-comparison"
  and .artifact.signing_continuity_receipt_sha256 == null
  and .artifact.safe_storage_access_stable_across_rebuilds == null
  and .artifact.safe_storage_rebuild_behavior == "pending-manual-rebuild-observation"
' "${BUILD_MANIFEST}" >/dev/null || { echo "Manifest signing and Safe Storage evidence is inconsistent." >&2; exit 1; }
[[ "$(jq -er '.artifact.shared_data_folder_name' "${BUILD_MANIFEST}")" == "${SHARED_DATA_FOLDER_NAME}" ]] || { echo "Manifest shared-data folder mismatch." >&2; exit 1; }
[[ "$(jq -er '.artifact.focused_shell.enabled' "${BUILD_MANIFEST}")" == "true" ]] || { echo "Manifest focused-shell state mismatch." >&2; exit 1; }
jq -e '
  .artifact.focused_shell.result_location == "below"
  and (.artifact.focused_shell | has("automatic_result_layout") | not)
' "${BUILD_MANIFEST}" >/dev/null || { echo "Manifest DBCode result location mismatch." >&2; exit 1; }
expected_runtime_extensions="$(
  jq -c '
    .packages
    | map({
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
    | sort_by(.id)
  ' <<<"${RELEASE_EXTENSION_SPEC}"
)"
actual_runtime_extensions="$(jq -c '.runtime_extensions | sort_by(.id)' "${BUILD_MANIFEST}")"
[[ "${actual_runtime_extensions}" == "${expected_runtime_extensions}" ]] || {
  echo "Manifest runtime extensions do not match the complete mandatory release set." >&2
  exit 1
}
jq -e '
  (keys | sort) == [
    "artifact",
    "built_at_utc",
    "packaging",
    "profile",
    "release",
    "runtime",
    "runtime_extensions",
    "schema_version",
    "source",
    "toolchain"
  ]
' "${BUILD_MANIFEST}" >/dev/null || { echo "Manifest must describe only DBCode Wrapper." >&2; exit 1; }
[[ "$(jq -er '.schema_version' "${BUILD_MANIFEST}")" == "6" ]] || { echo "Unexpected build-manifest schema." >&2; exit 1; }
expected_source_set_id="$(release_source_set_id)"
expected_release_set_id="${expected_source_set_id}-artifact-$(jq -er '.artifact.sha256' "${BUILD_MANIFEST}")"
[[ "$(jq -er '.release.source_set_id' "${BUILD_MANIFEST}")" == "${expected_source_set_id}" ]] || { echo "Manifest candidate source-set mismatch." >&2; exit 1; }
[[ "$(jq -er '.release.release_set_id' "${BUILD_MANIFEST}")" == "${expected_release_set_id}" ]] || { echo "Manifest exact candidate release-set mismatch." >&2; exit 1; }
[[ "$(jq -er '.release.compatibility_status' "${BUILD_MANIFEST}")" == "candidate" ]] || { echo "A newly built artifact must remain a candidate until its exact compatibility gate passes." >&2; exit 1; }
[[ "$(jq -er '.release.validation_issue' "${BUILD_MANIFEST}")" == "${RELEASE_VALIDATION_ISSUE}" ]] || { echo "Manifest validation issue mismatch." >&2; exit 1; }
[[ "$(jq -er '.profile.schema_version' "${BUILD_MANIFEST}")" == "${PROFILE_SCHEMA_VERSION}" ]] || { echo "Manifest profile schema mismatch." >&2; exit 1; }
jq -e '
  .packaging.status == "built-and-signed"
  and .packaging.layer == "vscodium"
  and .packaging.updater_enabled == false
  and .packaging.external_runtime_in_app == false
  and .packaging.external_runtime_setup == "focused-pinned-official-sources"
  and (.packaging.external_runtime_setup_manifest_sha256 | test("^[0-9a-f]{64}$"))
  and .packaging.source_map_file_count == 0
' "${BUILD_MANIFEST}" >/dev/null || { echo "Manifest packaging result mismatch." >&2; exit 1; }
runtime_setup_root="${APP_BUNDLE}/Contents/Resources/app/extensions/dbcode-wrapper-profile-migration"
runtime_setup_manifest="${runtime_setup_root}/runtime-extension-set.json"
runtime_setup_logic="${runtime_setup_root}/runtimeSetup.js"
runtime_setup_verifier="${runtime_setup_root}/openVsxPackageVerifier.js"
profile_identity="${runtime_setup_root}/profile-identity.json"
profile_layout_logic="${runtime_setup_root}/profile-layout.js"
managed_profile_settings="${runtime_setup_root}/managed-settings.json"
runtime_setup_zip_library="${APP_BUNDLE}/Contents/Resources/app/node_modules/yauzl/package.json"
runtime_setup_semver_library="${APP_BUNDLE}/Contents/Resources/app/node_modules/semver/package.json"
[[ -f "${runtime_setup_manifest}" && ! -L "${runtime_setup_manifest}" && \
  -f "${runtime_setup_logic}" && -f "${runtime_setup_verifier}" && \
  -f "${profile_identity}" && ! -L "${profile_identity}" && \
  -f "${profile_layout_logic}" && -f "${managed_profile_settings}" && \
  ! -L "${managed_profile_settings}" && -f "${runtime_setup_zip_library}" && \
  ! -L "${runtime_setup_zip_library}" && -f "${runtime_setup_semver_library}" && \
  ! -L "${runtime_setup_semver_library}" ]] || {
  echo "The focused first-run runtime setup is missing from the signed app." >&2
  exit 1
}
jq -e '
  .name == "yauzl"
  and (.version | type == "string" and length > 0)
' "${runtime_setup_zip_library}" >/dev/null || {
  echo "The signed app cannot read the verified Open VSX package archives." >&2
  exit 1
}
jq -e '
  .name == "semver"
  and (.version | type == "string" and length > 0)
' "${runtime_setup_semver_library}" >/dev/null || {
  echo "The signed app cannot verify extension engine compatibility." >&2
  exit 1
}
[[ "$(shasum -a 256 "${runtime_setup_manifest}" | awk '{print $1}')" == \
  "$(jq -er '.packaging.external_runtime_setup_manifest_sha256' "${BUILD_MANIFEST}")" ]] || {
  echo "The focused first-run runtime setup manifest does not match the build manifest." >&2
  exit 1
}
"${NODE_BIN_DIR}/node" -e '
  const fs = require("node:fs");
  const [logic, record] = process.argv.slice(1);
  require(logic).validateRuntimeConfiguration(JSON.parse(fs.readFileSync(record, "utf8")));
' "${runtime_setup_logic}" "${runtime_setup_manifest}"
"${NODE_BIN_DIR}/node" -e '
  const [logic, record] = process.argv.slice(1);
  require(logic).loadProfileIdentity(record);
' "${profile_layout_logic}" "${profile_identity}"
smoke_root="$(generated_workspace_path "smoke-evidence")"
generated_workspace_assert_path "smoke-evidence" "${smoke_root}"
mkdir -p "${smoke_root}"
expected_runtime_setup_manifest="${smoke_root}/expected-runtime-extension-set.$$.json"
expected_profile_identity="${smoke_root}/expected-profile-identity.$$.json"
generated_workspace_assert_path "smoke-evidence" "${expected_runtime_setup_manifest}"
generated_workspace_assert_path "smoke-evidence" "${expected_profile_identity}"
"${REPO_ROOT}/script/generate_runtime_setup_manifest.sh" "${expected_runtime_setup_manifest}" >/dev/null
"${REPO_ROOT}/script/generate_profile_identity.sh" "${expected_profile_identity}" >/dev/null
cmp -s "${runtime_setup_manifest}" "${expected_runtime_setup_manifest}" || {
  rm -f "${expected_runtime_setup_manifest}" "${expected_profile_identity}"
  echo "The focused first-run setup does not match the exact Release Specification package set." >&2
  exit 1
}
cmp -s "${profile_identity}" "${expected_profile_identity}" || {
  rm -f "${expected_runtime_setup_manifest}" "${expected_profile_identity}"
  echo "The packaged profile identity does not match the exact Release Specification." >&2
  exit 1
}
cmp -s "${managed_profile_settings}" "${REPO_ROOT}/host/profile/settings.json" || {
  rm -f "${expected_runtime_setup_manifest}" "${expected_profile_identity}"
  echo "The packaged managed settings do not match the canonical profile settings." >&2
  exit 1
}
rm -f "${expected_runtime_setup_manifest}" "${expected_profile_identity}"
[[ "$(jq -er '.source.vscodium.commit' "${BUILD_MANIFEST}")" == "${VSCODIUM_COMMIT}" ]] || { echo "Manifest VSCodium commit mismatch." >&2; exit 1; }
[[ "$(jq -er '.source.code_oss.commit' "${BUILD_MANIFEST}")" == "${CODE_OSS_COMMIT}" ]] || { echo "Manifest Code OSS commit mismatch." >&2; exit 1; }
[[ "$(jq -er '.runtime.electron' "${BUILD_MANIFEST}")" == "${ELECTRON_VERSION}" ]] || { echo "Manifest Electron version mismatch." >&2; exit 1; }
manifest_source_snapshot="$(jq -c '.source.snapshot' "${BUILD_MANIFEST}")"
release_source_snapshot_verify_json "${REPO_ROOT}" "${manifest_source_snapshot}"
jq -e '
  .source.repository_revision == .source.snapshot.repository_revision
  and .source.release_lock_sha256 == .source.snapshot.release_lock_sha256
  and .source.overlay_sha256 == .source.snapshot.host_script_sha256
  and .source.compiled_host.schema_version == 2
  and (.source.compiled_host.input_id | test("^compiled-host-[0-9a-f]{64}$"))
  and (.source.compiled_host.source_revision | test("^[0-9a-f]{40}$"))
  and .source.compiled_host.app_digest_algorithm == "sha256-files-modes-links-v1"
  and (.source.compiled_host.app_sha256 | test("^[0-9a-f]{64}$"))
  and .source.compiled_host.compilation_environment.schema_version == 1
  and (.source.compiled_host.cache_status | IN("hit", "miss-built"))
' "${BUILD_MANIFEST}" >/dev/null || {
  echo "The build manifest has an invalid immutable source or compiled-host record." >&2
  exit 1
}
[[ "$(jq -er '.source.release_lock_sha256' "${BUILD_MANIFEST}")" == "$(shasum -a 256 "${LOCK_FILE}" | awk '{print $1}')" ]] || { echo "The build manifest has a stale release lock." >&2; exit 1; }
[[ "$(jq -er '.source.shell_patch_revision' "${BUILD_MANIFEST}")" == "$(shell_patch_digest)" ]] || { echo "The build manifest has stale host patches." >&2; exit 1; }
[[ "$(jq -er '.source.compiled_host.input_id' "${BUILD_MANIFEST}")" == "$(compiled_host_input_id "${LOCK_FILE}" "${REPO_ROOT}")" ]] || { echo "The build manifest has stale compiled-host inputs." >&2; exit 1; }
jq -e '.runtime.node and .runtime.chromium and .runtime.electron and .runtime.code_oss' "${BUILD_MANIFEST}" >/dev/null

echo "Static host checks passed: identity, darwin-${TARGET_ARCH}, SQL document association, signature, and manifest."
