#!/usr/bin/env bash

set -euo pipefail

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_root}/lib/host_config.sh"
source "${script_root}/lib/private_release.sh"
source "${script_root}/lib/artifact_digest.sh"
inspector="${script_root}/inspect_private_release_tree.sh"
packager="${script_root}/package_private_release.sh"
verifier="${script_root}/verify_private_release.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-private-release-test.XXXXXX")"

cleanup() {
  rm -rf "${test_root}"
}
trap cleanup EXIT INT TERM

canonical_root="${test_root}/canonical-root"
mkdir -p "${canonical_root}/mounted" "${test_root}/sibling"
ln -s "${canonical_root}" "${test_root}/root-alias"
private_release_path_is_within \
  "${test_root}/root-alias" \
  "${canonical_root}/mounted" || {
  echo "A canonical mount path was rejected through its safe root alias." >&2
  exit 1
}
if private_release_path_is_within \
  "${test_root}/root-alias" \
  "${test_root}/sibling"; then
  echo "A path outside the canonical mount root was accepted." >&2
  exit 1
fi

safe_tree="${test_root}/safe"
mkdir -p "${safe_tree}/DBCode Wrapper.app/Contents/Resources"
printf '%s\n' \
  'IconKeyValue,Descriptions' \
  'key,Key or password' \
  'gist-secret,Secret Gist' \
  > "${safe_tree}/DBCode Wrapper.app/Contents/Resources/public-icon-metadata.csv"
printf '%s\n' \
  'DBCode Wrapper is for Macs owned by the licence holder.' \
  'DBCode is not included and must be installed separately.' \
  'Verify the published SHA-256 before opening this disk image.' \
  'Use System Settings > Privacy & Security > Open Anyway.' \
  'Do not disable Gatekeeper.' \
  'This app is self-signed. Apple has neither identified nor notarized it.' \
  'Rollback restores the previous complete Approved Release Set.' \
  > "${safe_tree}/Install DBCode Wrapper.txt"

bash "${inspector}" \
  --root "${safe_tree}" \
  --app-name "DBCode Wrapper.app" \
  --guide-name "Install DBCode Wrapper.txt"

bundled_dbcode_tree="${test_root}/bundled-dbcode"
cp -R "${safe_tree}" "${bundled_dbcode_tree}"
mkdir -p "${bundled_dbcode_tree}/DBCode Wrapper.app/Contents/Resources/app/extensions/dbcode.dbcode-1.36.2"
printf '%s\n' '{"publisher":"dbcode","name":"dbcode","version":"1.36.2"}' \
  > "${bundled_dbcode_tree}/DBCode Wrapper.app/Contents/Resources/app/extensions/dbcode.dbcode-1.36.2/package.json"
if bash "${inspector}" \
  --root "${bundled_dbcode_tree}" \
  --app-name "DBCode Wrapper.app" \
  --guide-name "Install DBCode Wrapper.txt" >/dev/null 2>&1; then
  echo "The Private Personal Release tree accepted a bundled DBCode extension." >&2
  exit 1
fi

profile_tree="${test_root}/profile"
cp -R "${safe_tree}" "${profile_tree}"
mkdir -p "${profile_tree}/DBCode Wrapper.app/Contents/Resources/User/globalStorage"
printf '%s\n' 'private profile state' \
  > "${profile_tree}/DBCode Wrapper.app/Contents/Resources/User/globalStorage/state.vscdb"
if bash "${inspector}" \
  --root "${profile_tree}" \
  --app-name "DBCode Wrapper.app" \
  --guide-name "Install DBCode Wrapper.txt" >/dev/null 2>&1; then
  echo "The Private Personal Release tree accepted copied profile state." >&2
  exit 1
fi

extension_cache_tree="${test_root}/extension-cache"
cp -R "${safe_tree}" "${extension_cache_tree}"
mkdir -p "${extension_cache_tree}/DBCode Wrapper.app/Contents/Resources/CachedExtensionVSIXs"
printf '%s\n' 'cached package' \
  > "${extension_cache_tree}/DBCode Wrapper.app/Contents/Resources/CachedExtensionVSIXs/package.zip"
if bash "${inspector}" \
  --root "${extension_cache_tree}" \
  --app-name "DBCode Wrapper.app" \
  --guide-name "Install DBCode Wrapper.txt" >/dev/null 2>&1; then
  echo "The Private Personal Release tree accepted an extension cache." >&2
  exit 1
fi

database_tree="${test_root}/database"
cp -R "${safe_tree}" "${database_tree}"
mkdir -p "${database_tree}/DBCode Wrapper.app/Contents/Resources"
printf '%s\n' 'private database' \
  > "${database_tree}/DBCode Wrapper.app/Contents/Resources/personal.duckdb"
if bash "${inspector}" \
  --root "${database_tree}" \
  --app-name "DBCode Wrapper.app" \
  --guide-name "Install DBCode Wrapper.txt" >/dev/null 2>&1; then
  echo "The Private Personal Release tree accepted a private database." >&2
  exit 1
fi

sensitive_state_tree="${test_root}/sensitive-state"
cp -R "${safe_tree}" "${sensitive_state_tree}"
mkdir -p "${sensitive_state_tree}/DBCode Wrapper.app/Contents/Resources"
printf '%s\n' '{"licenseKey":"fixture","password":"fixture","activation":"active"}' \
  > "${sensitive_state_tree}/DBCode Wrapper.app/Contents/Resources/state.json"
if bash "${inspector}" \
  --root "${sensitive_state_tree}" \
  --app-name "DBCode Wrapper.app" \
  --guide-name "Install DBCode Wrapper.txt" >/dev/null 2>&1; then
  echo "The Private Personal Release tree accepted licence, credential, and activation state." >&2
  exit 1
fi

credential_csv_tree="${test_root}/credential-csv"
cp -R "${safe_tree}" "${credential_csv_tree}"
mkdir -p "${credential_csv_tree}/DBCode Wrapper.app/Contents/Resources"
printf '%s\n' \
  'name,host,username,database_password' \
  'Private database,db.internal,owner,fixture-secret' \
  > "${credential_csv_tree}/DBCode Wrapper.app/Contents/Resources/connections.csv"
if bash "${inspector}" \
  --root "${credential_csv_tree}" \
  --app-name "DBCode Wrapper.app" \
  --guide-name "Install DBCode Wrapper.txt" >/dev/null 2>&1; then
  echo "The Private Personal Release tree accepted a credential-bearing CSV." >&2
  exit 1
fi

credential_key_value_tree="${test_root}/credential-key-value"
cp -R "${safe_tree}" "${credential_key_value_tree}"
mkdir -p "${credential_key_value_tree}/DBCode Wrapper.app/Contents/Resources"
printf '%s\n' \
  'key,value' \
  'database_password,fixture-secret' \
  > "${credential_key_value_tree}/DBCode Wrapper.app/Contents/Resources/connection-settings.csv"
if bash "${inspector}" \
  --root "${credential_key_value_tree}" \
  --app-name "DBCode Wrapper.app" \
  --guide-name "Install DBCode Wrapper.txt" >/dev/null 2>&1; then
  echo "The Private Personal Release tree accepted row-oriented credentials." >&2
  exit 1
fi

keychain_export_tree="${test_root}/keychain-export"
cp -R "${safe_tree}" "${keychain_export_tree}"
mkdir -p "${keychain_export_tree}/DBCode Wrapper.app/Contents/Resources"
printf '%s\n' 'fixture keychain export' \
  > "${keychain_export_tree}/DBCode Wrapper.app/Contents/Resources/keychain-export.txt"
if bash "${inspector}" \
  --root "${keychain_export_tree}" \
  --app-name "DBCode Wrapper.app" \
  --guide-name "Install DBCode Wrapper.txt" >/dev/null 2>&1; then
  echo "The Private Personal Release tree accepted a Keychain export." >&2
  exit 1
fi

secret_tree="${test_root}/secret"
cp -R "${safe_tree}" "${secret_tree}"
mkdir -p "${secret_tree}/DBCode Wrapper.app/Contents/Resources"
printf '%s\n' \
  '-----BEGIN PRIVATE KEY-----' \
  'fixture-secret' \
  '-----END PRIVATE KEY-----' \
  > "${secret_tree}/DBCode Wrapper.app/Contents/Resources/notes.txt"
if bash "${inspector}" \
  --root "${secret_tree}" \
  --app-name "DBCode Wrapper.app" \
  --guide-name "Install DBCode Wrapper.txt" >/dev/null 2>&1; then
  echo "The Private Personal Release tree accepted private-key material." >&2
  exit 1
fi

escaping_link_tree="${test_root}/escaping-link"
cp -R "${safe_tree}" "${escaping_link_tree}"
printf '%s\n' 'private external data' > "${test_root}/outside.txt"
ln -s "${test_root}/outside.txt" \
  "${escaping_link_tree}/DBCode Wrapper.app/Contents/outside.txt"
if bash "${inspector}" \
  --root "${escaping_link_tree}" \
  --app-name "DBCode Wrapper.app" \
  --guide-name "Install DBCode Wrapper.txt" >/dev/null 2>&1; then
  echo "The Private Personal Release tree accepted an escaping symbolic link." >&2
  exit 1
fi

fixture_repository="${test_root}/source"
mkdir -p "${fixture_repository}/host"
git -c init.defaultBranch=main -C "${fixture_repository}" init -q
git -C "${fixture_repository}" config user.name "DBCode Wrapper test"
git -C "${fixture_repository}" config user.email "dbcode-wrapper@example.invalid"
cp "${LOCK_FILE}" "${fixture_repository}/host/release-lock.json"
git -C "${fixture_repository}" add host/release-lock.json
git -C "${fixture_repository}" commit -q -m "Fixture source"
source_commit="$(git -C "${fixture_repository}" rev-parse HEAD)"
source_tag="private-release-fixture"
git -C "${fixture_repository}" tag -a "${source_tag}" -m "Fixture source tag"
release_lock="${fixture_repository}/host/release-lock.json"
release_lock_sha256="$(shasum -a 256 "${release_lock}" | awk '{print $1}')"

fixture_app="${test_root}/DBCode Wrapper.app"
mkdir -p \
  "${fixture_app}/Contents/MacOS" \
  "${fixture_app}/Contents/Resources/app/extensions/dbcode-wrapper-profile-migration"
printf '%s\n' 'fixture executable' > "${fixture_app}/Contents/MacOS/DBCode Wrapper"
chmod 755 "${fixture_app}/Contents/MacOS/DBCode Wrapper"
printf '%s\n' 'Code OSS licence fixture' > "${fixture_app}/Contents/Resources/app/LICENSE.txt"
printf '%s\n' 'Third-party notices fixture' > "${fixture_app}/Contents/Resources/app/ThirdPartyNotices.txt"
printf '%s\n' 'Chromium notices fixture' > "${fixture_app}/Contents/Resources/LICENSES.chromium.html"
cp \
  "${REPO_ROOT}/host/extensions/dbcode-wrapper-profile-migration/runtimeSetup.js" \
  "${fixture_app}/Contents/Resources/app/extensions/dbcode-wrapper-profile-migration/runtimeSetup.js"
"${REPO_ROOT}/script/generate_runtime_setup_manifest.sh" \
  "${fixture_app}/Contents/Resources/app/extensions/dbcode-wrapper-profile-migration/runtime-extension-set.json" \
  >/dev/null
runtime_setup_sha256="$(
  shasum -a 256 \
    "${fixture_app}/Contents/Resources/app/extensions/dbcode-wrapper-profile-migration/runtime-extension-set.json" |
    awk '{print $1}'
)"
printf '%s\n' \
  '<?xml version="1.0" encoding="UTF-8"?>' \
  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
  '<plist version="1.0"><dict>' \
  '<key>CFBundleName</key><string>DBCode Wrapper</string>' \
  '<key>CFBundleIdentifier</key><string>io.alexabelle.dbcodewrapper</string>' \
  '<key>CFBundleExecutable</key><string>DBCode Wrapper</string>' \
  '<key>LSMinimumSystemVersion</key><string>12.0</string>' \
  '</dict></plist>' \
  > "${fixture_app}/Contents/Info.plist"
app_sha256="$(artifact_digest "${fixture_app}")"
fixture_runtime_extensions="$(
  jq -c '
    [
      .[] | {
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
      }
    ]
  ' <<<"${RUNTIME_EXTENSION_PACKAGES}"
)"
fixture_installed_extensions="$(
  jq -c '[.[] | "\(.id)@\(.version)"] | sort' <<<"${RUNTIME_EXTENSION_PACKAGES}"
)"
fixture_dbcode_version="$(jq -er '.version' <<<"${DBCODE_PACKAGE_SPEC}")"
fixture_dbcode_sha256="$(jq -er '.sha256' <<<"${DBCODE_PACKAGE_SPEC}")"

manifest_file="${test_root}/build-manifest.json"
jq -n \
  --arg source_commit "${source_commit}" \
  --arg release_lock_sha256 "${release_lock_sha256}" \
  --arg runtime_setup_sha256 "${runtime_setup_sha256}" \
  --arg app_sha256 "${app_sha256}" \
  --arg code_oss_version "${CODE_OSS_VERSION}" \
  --arg vscodium_version "${VSCODIUM_TAG}" \
  --argjson runtime_extensions "${fixture_runtime_extensions}" '
    {
      schema_version: 5,
      source: {
        repository_revision: $source_commit,
        release_lock_sha256: $release_lock_sha256
      },
      release: {
        compatibility_status: "candidate",
        source_set_id: "fixture-source-set",
        release_set_id: ("fixture-source-set-artifact-" + $app_sha256)
      },
      runtime: {
        code_oss: $code_oss_version,
        host: $vscodium_version
      },
      artifact: {
        app_name: "DBCode Wrapper",
        bundle_identifier: "io.alexabelle.dbcodewrapper",
        platform: "darwin",
        architecture: "arm64",
        sha256: $app_sha256,
        signature_kind: "certificate",
        signature_requirement: "designated => fixture requirement",
        signature_scope: "current-user-private-use",
        signing_certificate_sha1: ("b" * 40),
        signing_certificate_sha256: ("c" * 64)
      },
      packaging: {
        status: "built-and-signed",
        updater_enabled: false,
        external_runtime_in_app: false,
        external_runtime_setup: "focused-pinned-official-sources",
        external_runtime_setup_manifest_sha256: $runtime_setup_sha256
      },
      runtime_extensions: $runtime_extensions
    }
  ' > "${manifest_file}"
manifest_sha256="$(shasum -a 256 "${manifest_file}" | awk '{print $1}')"
release_set_id="$(jq -er '.release.release_set_id' "${manifest_file}")"

acceptance_file="${test_root}/final-acceptance.json"
jq -n \
  --arg release_set_id "${release_set_id}" \
  --arg app_sha256 "${app_sha256}" \
  --arg manifest_sha256 "${manifest_sha256}" \
  --arg release_lock_sha256 "${release_lock_sha256}" \
  --arg code_oss_version "${CODE_OSS_VERSION}" \
  --arg dbcode_version "${fixture_dbcode_version}" \
  --arg dbcode_sha256 "${fixture_dbcode_sha256}" \
  --argjson installed_extensions "${fixture_installed_extensions}" '
    def evidence:
      {
        build_manifest: $manifest_sha256,
        release_lock: $release_lock_sha256,
        signing_continuity: ("1" * 64),
        real_profile_proof: ("2" * 64),
        compatibility_matrix: ("3" * 64),
        restart_health: ("4" * 64),
        rollback: ("5" * 64),
        rendered_report: ("6" * 64),
        development_log: ("7" * 64),
        smoke_log: ("8" * 64)
      };
    def manual:
      {
        status: "passed",
        expected_result: "fixture expected result",
        note: "fixture note",
        launch_id: "launch-2",
        launch_kind: "relaunch",
        recorded_at: "2026-07-24T00:00:00Z"
      };
    {
      schema_version: 1,
      status: "passed",
      completed_at_utc: "2026-07-24T00:00:00Z",
      scope: "current-user-private-use",
      release: {
        release_set_id: $release_set_id,
        app_sha256: $app_sha256,
        platform: "darwin",
        architecture: "arm64",
        code_oss_version: $code_oss_version,
        dbcode: {id: "dbcode.dbcode", version: $dbcode_version, vsix_sha256: $dbcode_sha256},
        installed_extensions: $installed_extensions
      },
      signing: {
        kind: "certificate",
        scope: "current-user-private-use",
        designated_requirement: "designated => fixture requirement",
        certificate: {sha1: ("b" * 40), sha256: ("c" * 64)},
        cryptographic_identity_stable_across_rebuilds: true,
        safe_storage_access_stable_across_rebuilds: false,
        safe_storage_prompt_observation: "accepted-new-approval-after-distinct-rebuild",
        safe_storage_rebuild_behavior: "manual-approval-may-repeat-after-host-rebuild"
      },
      gates: {
        development_contracts: "passed",
        strict_signature_and_manifest: "passed",
        rebuilt_host_safe_storage_behavior: "accepted-limitation",
        independent_launch_and_profile_isolation: "passed",
        dbcode_focused_rendered_interface: "passed",
        exact_external_extension_inventory: "passed",
        lifetime_entitlement_and_persistence: "passed",
        protected_credential_reentry: "passed",
        read_only_update_discovery: "passed",
        postgresql_read_only: "passed",
        duckdb_and_parquet: "passed",
        first_run_migration_and_hyphen_path: "passed",
        four_way_update_compatibility: "passed",
        promotion_restart_health: "passed",
        complete_set_rollback: "passed",
        owner_only_profile_permissions: "passed",
        bundle_unchanged_after_use: "passed"
      },
      manual_evidence: {
        activation: manual,
        credential_reentry: manual,
        update_discovery: manual,
        postgresql: manual,
        duckdb: manual,
        parquet: manual,
        persistence: manual
      },
      rendered_evidence: {
        check_count: 36,
        known_warning_count: 0,
        unexpected_error_count: 0
      },
      evidence_sha256: evidence,
      failures: [],
      waivers: [],
      private_use_risks: ["1", "2", "3", "4", "5", "6"],
      distribution_claims: {
        developer_id: false,
        notarized: false,
        public_distribution_ready: false,
        intel_support: false,
        multi_user_support: false,
        official_dbcode_endorsement: false
      }
    }
  ' > "${acceptance_file}"

stub_bin="${test_root}/bin"
mkdir -p "${stub_bin}"
for stub_name in codesign diskutil ditto hdiutil lipo; do
  touch "${stub_bin}/${stub_name}"
  chmod 755 "${stub_bin}/${stub_name}"
done

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'if [[ "$*" == *"-d -r-"* ]]; then' \
  '  echo "designated => fixture requirement" >&2' \
  'elif [[ "$*" == *"-dvvv"* ]]; then' \
  '  echo "Authority=DBCode Wrapper fixture" >&2' \
  'fi' \
  > "${stub_bin}/codesign"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'cp -R "$1" "$2"' \
  > "${stub_bin}/ditto"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'echo arm64' \
  > "${stub_bin}/lipo"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'cat <<EOF' \
  '<?xml version="1.0" encoding="UTF-8"?>' \
  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
  '<plist version="1.0"><dict>' \
  '<key>Writable</key><false/>' \
  '<key>WritableMedia</key><false/>' \
  '<key>FilesystemType</key><string>hfs</string>' \
  '</dict></plist>' \
  'EOF' \
  > "${stub_bin}/diskutil"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'operation="$1"; shift' \
  'case "${operation}" in' \
  '  create)' \
  '    source_folder=""' \
  '    arguments=("$@")' \
  '    for ((index=0; index<${#arguments[@]}; index++)); do' \
  '      [[ "${arguments[$index]}" != "-srcfolder" ]] || source_folder="${arguments[$((index + 1))]}"' \
  '    done' \
  '    target="${arguments[$((${#arguments[@]} - 1))]}"' \
  '    /usr/bin/tar -cf "${target}" -C "${source_folder}" .' \
  '    ;;' \
  '  verify)' \
  '    /usr/bin/tar -tf "$1" >/dev/null' \
  '    ;;' \
  '  attach)' \
  '    mount_root=""' \
  '    arguments=("$@")' \
  '    for ((index=0; index<${#arguments[@]}; index++)); do' \
  '      [[ "${arguments[$index]}" != "-mountroot" ]] || mount_root="${arguments[$((index + 1))]}"' \
  '    done' \
  '    image="${arguments[$((${#arguments[@]} - 1))]}"' \
  '    mount_path="${mount_root}/DBCode Wrapper"' \
  '    mkdir -p "${mount_path}"' \
  '    /usr/bin/tar -xf "${image}" -C "${mount_path}"' \
  '    cat <<EOF' \
  '<?xml version="1.0" encoding="UTF-8"?>' \
  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
  '<plist version="1.0"><dict><key>system-entities</key><array><dict>' \
  '<key>mount-point</key><string>${mount_path}</string>' \
  '<key>dev-entry</key><string>/dev/disk-fixture</string>' \
  '</dict></array></dict></plist>' \
  'EOF' \
  '    ;;' \
  '  detach) ;;' \
  '  *) exit 2 ;;' \
  'esac' \
  > "${stub_bin}/hdiutil"

package_source_arguments=(
  --manifest "${manifest_file}"
  --release-lock "${release_lock}"
  --acceptance "${acceptance_file}"
  --source-repository "${fixture_repository}"
  --source-tag "${source_tag}"
)

package_output="${test_root}/package-output"
PATH="${stub_bin}:${PATH}" bash "${packager}" \
  --app "${fixture_app}" \
  "${package_source_arguments[@]}" \
  --output-dir "${package_output}" >/dev/null

relative_package_output="${test_root}/relative-package-output"
if ! relative_package_result="$(
  cd "${test_root}"
  PATH="${stub_bin}:${PATH}" bash "${packager}" \
    --app "DBCode Wrapper.app" \
    "${package_source_arguments[@]}" \
    --output-dir "${relative_package_output}" 2>&1
)"; then
  echo "The task-level packager rejected a valid relative application path." >&2
  printf '%s\n' "${relative_package_result}" >&2
  exit 1
fi

dmg_file="$(find "${package_output}" -maxdepth 1 -type f -name '*.dmg' -print -quit)"
checksum_file="${dmg_file}.sha256"
compatibility_file="$(find "${package_output}" -maxdepth 1 -type f -name '*-compatibility.json' -print -quit)"
notes_file="$(find "${package_output}" -maxdepth 1 -type f -name '*-install-and-rollback.txt' -print -quit)"
packaged_verification="$(find "${package_output}" -maxdepth 1 -type f -name '*-verification.json' -print -quit)"
[[ -n "${dmg_file}" && -f "${checksum_file}" && -f "${compatibility_file}" && \
  -f "${notes_file}" && -f "${packaged_verification}" ]] || {
  echo "The task-level packager did not produce the exact five-asset release." >&2
  exit 1
}
jq -e \
  --arg source_tag "${source_tag}" \
  --arg source_commit "${source_commit}" '
    .source.tag == $source_tag
    and .source.repository_revision == $source_commit
    and .external_runtime.setup == "focused-pinned-official-sources"
    and .claims.dbcode_included == false
    and .claims.public_application_release == false
  ' "${compatibility_file}" >/dev/null

malformed_lock="${test_root}/malformed-release-lock.json"
printf '%s\n' '{"schema_version":4,"fixture":"malformed"}' > "${malformed_lock}"
if malformed_lock_output="$(
  PATH="${stub_bin}:${PATH}" bash "${packager}" \
    --app "${fixture_app}" \
    --manifest "${manifest_file}" \
    --release-lock "${malformed_lock}" \
    --acceptance "${acceptance_file}" \
    --source-repository "${fixture_repository}" \
    --source-tag "${source_tag}" \
    --output-dir "${test_root}/malformed-lock-package" 2>&1
)"; then
  echo "The task-level packager accepted a malformed Release Specification." >&2
  exit 1
fi
[[ "${malformed_lock_output}" == *"Release Specification is invalid"* ]] || {
  echo "The task-level packager did not reject the malformed lock through the Release Specification." >&2
  exit 1
}

malformed_runtime_app="${test_root}/Malformed Runtime.app"
cp -R "${fixture_app}" "${malformed_runtime_app}"
printf '%s\n' '{"schema_version":1,"setup":"focused-pinned-official-sources"}' \
  > "${malformed_runtime_app}/Contents/Resources/app/extensions/dbcode-wrapper-profile-migration/runtime-extension-set.json"
malformed_runtime_sha256="$(
  shasum -a 256 \
    "${malformed_runtime_app}/Contents/Resources/app/extensions/dbcode-wrapper-profile-migration/runtime-extension-set.json" |
    awk '{print $1}'
)"
malformed_app_sha256="$(artifact_digest "${malformed_runtime_app}")"
malformed_manifest="${test_root}/malformed-runtime-manifest.json"
jq \
  --arg app_sha256 "${malformed_app_sha256}" \
  --arg runtime_setup_sha256 "${malformed_runtime_sha256}" '
    .artifact.sha256 = $app_sha256
    | .packaging.external_runtime_setup_manifest_sha256 = $runtime_setup_sha256
    | .release.release_set_id = ("fixture-source-set-artifact-" + $app_sha256)
  ' "${manifest_file}" > "${malformed_manifest}"
malformed_manifest_sha256="$(shasum -a 256 "${malformed_manifest}" | awk '{print $1}')"
malformed_acceptance="${test_root}/malformed-runtime-acceptance.json"
jq \
  --arg app_sha256 "${malformed_app_sha256}" \
  --arg release_set_id "$(jq -er '.release.release_set_id' "${malformed_manifest}")" \
  --arg manifest_sha256 "${malformed_manifest_sha256}" '
    .release.app_sha256 = $app_sha256
    | .release.release_set_id = $release_set_id
    | .evidence_sha256.build_manifest = $manifest_sha256
  ' "${acceptance_file}" > "${malformed_acceptance}"
if malformed_runtime_output="$(
  PATH="${stub_bin}:${PATH}" bash "${packager}" \
    --app "${malformed_runtime_app}" \
    --manifest "${malformed_manifest}" \
    --release-lock "${release_lock}" \
    --acceptance "${malformed_acceptance}" \
    --source-repository "${fixture_repository}" \
    --source-tag "${source_tag}" \
    --output-dir "${test_root}/malformed-runtime-package" 2>&1
)"; then
  echo "The task-level packager accepted a malformed focused runtime setup manifest." >&2
  exit 1
fi
[[ "${malformed_runtime_output}" == *"focused first-run runtime setup manifest is invalid"* ]] || {
  echo "The task-level packager did not reject the malformed focused runtime through its validator." >&2
  exit 1
}

independent_output_dir="${test_root}/independent-verification"
mkdir -p "${independent_output_dir}"
independent_receipt="${independent_output_dir}/$(basename "${packaged_verification}")"
PATH="${stub_bin}:${PATH}" bash "${verifier}" \
  --dmg "${dmg_file}" \
  --checksum "${checksum_file}" \
  --manifest "${manifest_file}" \
  --release-lock "${release_lock}" \
  --acceptance "${acceptance_file}" \
  --source-repository "${fixture_repository}" \
  --source-tag "${source_tag}" \
  --compatibility "${compatibility_file}" \
  --notes "${notes_file}" \
  --output "${independent_receipt}" >/dev/null
jq -e '
  .status == "passed"
  and .checks.source_tag == "passed"
  and .checks.complete_same_mac_acceptance == "passed"
  and .failures == []
' "${independent_receipt}" >/dev/null

incomplete_acceptance="${test_root}/incomplete-acceptance.json"
jq 'del(.gates)' "${acceptance_file}" > "${incomplete_acceptance}"
if PATH="${stub_bin}:${PATH}" bash "${packager}" \
  --app "${fixture_app}" \
  --manifest "${manifest_file}" \
  --release-lock "${release_lock}" \
  --acceptance "${incomplete_acceptance}" \
  --source-repository "${fixture_repository}" \
  --source-tag "${source_tag}" \
  --output-dir "${test_root}/invalid-package" >/dev/null 2>&1; then
  echo "The task-level packager accepted an incomplete same-Mac acceptance receipt." >&2
  exit 1
fi

echo "Private Personal Release tree contracts passed."
