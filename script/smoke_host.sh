#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/artifact_digest.sh"
source "${REPO_ROOT}/script/lib/profile_guard.sh"
source "${REPO_ROOT}/script/lib/source_digest.sh"
source "${REPO_ROOT}/script/lib/release_identity.sh"
source "${REPO_ROOT}/script/lib/local_signing_identity.sh"
source "${REPO_ROOT}/script/lib/profile_paths.sh"
source "${REPO_ROOT}/script/lib/host_session.sh"

static_only="no"
if [[ "${1:-}" == "--static-only" ]]; then
  static_only="yes"
elif [[ $# -gt 0 ]]; then
  echo "Usage: ./script/smoke_host.sh [--static-only]" >&2
  exit 2
fi

info_plist="${APP_BUNDLE}/Contents/Info.plist"
product_json="${APP_BUNDLE}/Contents/Resources/app/product.json"
if [[ ! -f "${info_plist}" || ! -f "${product_json}" || ! -f "${BUILD_MANIFEST}" ]]; then
  echo "Build the host first with ./script/build_host.sh" >&2
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
  (.artifact.cryptographic_update_identity_stable == null
    and .artifact.signing_continuity_evidence == "pending-rebuilt-release-comparison"
    and .artifact.signing_continuity_receipt_sha256 == null
    and .artifact.safe_storage_access_stable_across_rebuilds == null
    and .artifact.safe_storage_rebuild_behavior == "pending-manual-rebuild-observation")
  or
  (.artifact.cryptographic_update_identity_stable == true
    and .artifact.signing_continuity_evidence == "verified-distinct-rebuilt-artifacts"
    and (.artifact.signing_continuity_receipt_sha256 | test("^[0-9a-f]{64}$"))
    and .artifact.safe_storage_access_stable_across_rebuilds == false
    and .artifact.safe_storage_rebuild_behavior == "manual-approval-may-repeat-after-host-rebuild")
' "${BUILD_MANIFEST}" >/dev/null || { echo "Manifest signing and Safe Storage evidence is inconsistent." >&2; exit 1; }
[[ "$(jq -er '.artifact.shared_data_folder_name' "${BUILD_MANIFEST}")" == "${SHARED_DATA_FOLDER_NAME}" ]] || { echo "Manifest shared-data folder mismatch." >&2; exit 1; }
[[ "$(jq -er '.artifact.focused_shell.enabled' "${BUILD_MANIFEST}")" == "true" ]] || { echo "Manifest focused-shell state mismatch." >&2; exit 1; }
jq -e '.artifact.focused_shell.automatic_result_layout == {wide: "beside", narrow: "below"}' "${BUILD_MANIFEST}" >/dev/null || { echo "Manifest automatic DBCode result layout mismatch." >&2; exit 1; }
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
[[ "$(jq -er '.schema_version' "${BUILD_MANIFEST}")" == "5" ]] || { echo "Unexpected build-manifest schema." >&2; exit 1; }
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
runtime_setup_zip_library="${APP_BUNDLE}/Contents/Resources/app/node_modules/yauzl/package.json"
[[ -f "${runtime_setup_manifest}" && ! -L "${runtime_setup_manifest}" && \
  -f "${runtime_setup_logic}" && -f "${runtime_setup_zip_library}" && \
  ! -L "${runtime_setup_zip_library}" ]] || {
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
mkdir -p "${BUILD_ROOT}"
expected_runtime_setup_manifest="${BUILD_ROOT}/expected-runtime-extension-set.$$.json"
assert_generated_path "${expected_runtime_setup_manifest}"
"${REPO_ROOT}/script/generate_runtime_setup_manifest.sh" "${expected_runtime_setup_manifest}" >/dev/null
cmp -s "${runtime_setup_manifest}" "${expected_runtime_setup_manifest}" || {
  rm -f "${expected_runtime_setup_manifest}"
  echo "The focused first-run setup does not match the exact Release Specification package set." >&2
  exit 1
}
rm -f "${expected_runtime_setup_manifest}"
[[ "$(jq -er '.source.vscodium.commit' "${BUILD_MANIFEST}")" == "${VSCODIUM_COMMIT}" ]] || { echo "Manifest VSCodium commit mismatch." >&2; exit 1; }
[[ "$(jq -er '.source.code_oss.commit' "${BUILD_MANIFEST}")" == "${CODE_OSS_COMMIT}" ]] || { echo "Manifest Code OSS commit mismatch." >&2; exit 1; }
[[ "$(jq -er '.runtime.electron' "${BUILD_MANIFEST}")" == "${ELECTRON_VERSION}" ]] || { echo "Manifest Electron version mismatch." >&2; exit 1; }
[[ "$(jq -er '.source.release_lock_sha256' "${BUILD_MANIFEST}")" == "$(shasum -a 256 "${LOCK_FILE}" | awk '{print $1}')" ]] || { echo "The build manifest has a stale release lock." >&2; exit 1; }
[[ "$(jq -er '.source.shell_patch_revision' "${BUILD_MANIFEST}")" == "$(shell_patch_digest)" ]] || { echo "The build manifest has stale host patches." >&2; exit 1; }
[[ "$(jq -er '.source.overlay_sha256' "${BUILD_MANIFEST}")" == "$(overlay_digest)" ]] || { echo "The build manifest has a stale host overlay." >&2; exit 1; }
jq -e '.runtime.node and .runtime.chromium and .runtime.electron and .runtime.code_oss' "${BUILD_MANIFEST}" >/dev/null

echo "Static host checks passed: identity, darwin-${TARGET_ARCH}, SQL document association, signature, and manifest."

if [[ "${static_only}" == "yes" ]]; then
  exit 0
fi

external_code_pids=()
for external_process in "Visual Studio Code" "Code" "VSCodium"; do
  while IFS= read -r external_pid; do
    [[ -n "${external_pid}" ]] && external_code_pids+=("${external_pid}")
  done < <(pgrep -x "${external_process}" 2>/dev/null || true)
done

if [[ ${#external_code_pids[@]} -gt 0 ]]; then
  echo "Coexistence check: existing VS Code/VSCodium PIDs are ${external_code_pids[*]}."
else
  echo "Independent-launch check: no VS Code or VSCodium process is running."
fi

normal_profile_before="$(normal_profile_fingerprint)"
smoke_root="${BUILD_ROOT}/smoke"
query_file="${REPO_ROOT}/host/qa/project-query.sql"
assert_generated_path "${smoke_root}"
rm -rf "${smoke_root}"
mkdir -p "${smoke_root}"
resolve_isolated_profile_paths "${smoke_root}"
profile_layout_assert_mutable state user_data extensions shared_data backup cache logs
mkdir -p \
  "${PROFILE_USER_DATA_ROOT}" \
  "${PROFILE_EXTENSIONS_ROOT}" \
  "${PROFILE_SHARED_DATA_ROOT}" \
  "${PROFILE_BACKUP_ROOT}" \
  "${PROFILE_CACHE_ROOT}" \
  "${PROFILE_LOG_ROOT}"
chmod "${PROFILE_DIRECTORY_MODE}" \
  "${PROFILE_STATE_ROOT}" \
  "${PROFILE_USER_DATA_ROOT}" \
  "${PROFILE_EXTENSIONS_ROOT}" \
  "${PROFILE_SHARED_DATA_ROOT}" \
  "${PROFILE_BACKUP_ROOT}" \
  "${PROFILE_CACHE_ROOT}" \
  "${PROFILE_LOG_ROOT}"
smoke_log="${smoke_root}/host.log"
smoke_policy="${smoke_root}/host-session-policy.json"
smoke_result="${smoke_root}/host-session-result.json"
smoke_arguments="$(jq -cn --args '$ARGS.positional' -- \
  --verbose \
  --use-mock-keychain \
  --user-data-dir "${PROFILE_USER_DATA_ROOT}" \
  --extensions-dir "${PROFILE_EXTENSIONS_ROOT}" \
  --shared-data-dir "${PROFILE_SHARED_DATA_ROOT}" \
  --disk-cache-dir "${PROFILE_CACHE_ROOT}" \
  --logsPath "${PROFILE_LOG_ROOT}" \
  --disable-extensions \
  --new-window \
  --skip-release-notes \
  --skip-welcome \
  "${query_file}")"
smoke_environment="$(jq -cn --arg profile_layout "${PROFILE_LAYOUT}" '{
  DBCODE_WRAPPER_PROFILE_LAYOUT_JSON: $profile_layout,
  ELECTRON_ENABLE_LOGGING: "1"
}')"
host_log_patterns="$(jq -cn --arg state_db "${PROFILE_SHARED_DATA_ROOT}/sharedStorage/state.vscdb" '[
  {kind: "literal", value: $state_db}
]')"
host_session_write_policy \
  "${smoke_policy}" \
  "isolated-smoke-$(date -u +'%Y%m%dT%H%M%SZ')-$$" \
  "${app_executable}" \
  "${smoke_arguments}" \
  "${smoke_environment}" \
  "${smoke_log}" \
  "${PROFILE_LOG_ROOT}" \
  25 \
  1000 \
  3 \
  false \
  '[]' \
  "${host_log_patterns}" \
  quit-after-ready \
  false
host_session_run "${smoke_policy}" "${smoke_result}" || {
  echo "The isolated host failed its Host Session policy. See ${smoke_log}" >&2
  exit 1
}

app_pid="$(jq -er '.process.app_pid' "${smoke_result}")"
renderer_pid="$(jq -er '.process.renderer_pid' "${smoke_result}")"
process_command="$(jq -er '.process.command' "${smoke_result}")"
process_parent="$(jq -er '.process.parent_pid' "${smoke_result}")"
[[ "${process_command}" == *"${APP_NAME}.app/Contents/MacOS/${bundle_executable}"* ]] || { echo "Unexpected launched process: ${process_command}" >&2; exit 1; }
[[ "${process_command}" == *"--user-data-dir ${PROFILE_USER_DATA_ROOT}"* ]] || { echo "The launched process is not using the isolated user-data directory." >&2; exit 1; }
[[ "${process_command}" == *"--extensions-dir ${PROFILE_EXTENSIONS_ROOT}"* ]] || { echo "The launched process is not using the isolated extension directory." >&2; exit 1; }
[[ "${process_command}" == *"--shared-data-dir ${PROFILE_SHARED_DATA_ROOT}"* ]] || { echo "The launched process is not using the isolated shared-data directory." >&2; exit 1; }
[[ "${process_command}" == *"${query_file}"* ]] || { echo "The launched process did not receive the project SQL file." >&2; exit 1; }
rg -Fq "${query_file}" "${smoke_log}" || { echo "The host did not resolve the project SQL file during launch." >&2; exit 1; }
[[ -f "${PROFILE_SHARED_DATA_ROOT}/sharedStorage/state.vscdb" ]] || { echo "The host did not create shared storage inside the isolated directory." >&2; exit 1; }
for external_pid in "${external_code_pids[@]}"; do
  [[ "${app_pid}" != "${external_pid}" ]] || { echo "The host reused an external Code process." >&2; exit 1; }
  [[ "${process_parent}" != "${external_pid}" ]] || { echo "The host was launched by an external Code process." >&2; exit 1; }
done

normal_profile_after="$(normal_profile_fingerprint)"
[[ "${normal_profile_before}" == "${normal_profile_after}" ]] || {
  echo "A normal VS Code or VSCodium profile changed during the isolated launch." >&2
  exit 1
}

echo "Independent launch passed with a stable renderer, isolated directories, and no normal-profile changes."
