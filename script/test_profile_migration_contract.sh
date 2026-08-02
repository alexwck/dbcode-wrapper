#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

extension_root="${REPO_ROOT}/host/extensions/dbcode-wrapper-profile-migration"
extension_manifest="${extension_root}/package.json"
extension_runtime="${extension_root}/extension.js"
extension_view="${extension_root}/view.js"
first_run_command_router="${extension_root}/firstRunCommandRouter.js"
webview_safety="${extension_root}/webviewSafety.js"
migration_logic="${extension_root}/migration.js"
profile_setup="${extension_root}/profileSetup.js"
profile_identity="${extension_root}/profile-identity.json"
staging_logic="${extension_root}/staging.js"
recovery_logic="${extension_root}/profileRecovery.js"
recovery_worker="${extension_root}/profileRecoveryWorker.js"
profile_layout="${extension_root}/profile-layout.js"
runtime_setup="${extension_root}/runtimeSetup.js"
openvsx_package_verifier="${extension_root}/openVsxPackageVerifier.js"
runtime_setup_controller="${extension_root}/runtimeSetupController.js"
runtime_setup_view="${extension_root}/runtimeSetupView.js"
profile_layout_cli="${REPO_ROOT}/script/profile_layout.cjs"
profile_identity_generator="${REPO_ROOT}/script/generate_profile_identity.sh"
host_assembler="${REPO_ROOT}/script/assemble_host.sh"
host_smoke="${REPO_ROOT}/script/smoke_host.sh"
managed_settings="${extension_root}/managed-settings.json"
canonical_settings="${REPO_ROOT}/host/profile/settings.json"
shell_sources=(
  "${REPO_ROOT}/host/patches/code-oss/200-final-focused-dbcode-shell.patch"
  "${REPO_ROOT}/host/patches/code-oss/400-release-profile-and-dbcode-integrations.patch"
  "${REPO_ROOT}/host/code-oss-overlay/src/vs/workbench/contrib/dbcodeWrapper/browser/dbcodeWrapper.contribution.ts"
)
profile_paths="${REPO_ROOT}/script/lib/profile_paths.sh"
host_launcher="${REPO_ROOT}/script/run_host.sh"

for required_file in \
  "${extension_manifest}" \
  "${extension_runtime}" \
  "${extension_view}" \
  "${first_run_command_router}" \
  "${webview_safety}" \
  "${migration_logic}" \
  "${profile_setup}" \
  "${profile_identity}" \
  "${staging_logic}" \
  "${recovery_logic}" \
  "${recovery_worker}" \
  "${profile_layout}" \
  "${runtime_setup}" \
  "${openvsx_package_verifier}" \
  "${runtime_setup_controller}" \
  "${runtime_setup_view}" \
  "${profile_layout_cli}" \
  "${profile_identity_generator}" \
  "${canonical_settings}" \
  "${shell_sources[@]}"; do
  [[ -f "${required_file}" ]] || {
    echo "Missing focused profile-migration file: ${required_file}" >&2
    exit 1
  }
done

[[ ! -e "${managed_settings}" ]] || {
  echo "The profile-migration extension still tracks a duplicate managed settings file." >&2
  exit 1
}
for settings_owner in "${host_assembler}" "${host_smoke}"; do
  rg -Fq 'host/profile/settings.json' "${settings_owner}" || {
    echo "Assembly and Static Host Smoke must use the canonical managed settings source." >&2
    exit 1
  }
  rg -Fq 'managed-settings.json' "${settings_owner}" || {
    echo "Assembly and Static Host Smoke must own the packaged managed settings copy." >&2
    exit 1
  }
done

for identity_build_contract in \
  'generate_profile_identity.sh' \
  'profile-identity.json'; do
  rg -Fq "${identity_build_contract}" "${host_assembler}" "${host_smoke}" || {
    echo "Release assembly and static smoke must verify generated profile identity: ${identity_build_contract}" >&2
    exit 1
  }
done
rg -Fq 'loadProfileIdentity' "${host_smoke}" || {
  echo "Static smoke must validate the packaged profile identity through Profile Layout." >&2
  exit 1
}

test_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-profile-identity-contract.XXXXXX")"
cleanup_test_root() {
  rm -rf "${test_root}"
}
trap cleanup_test_root EXIT INT TERM
generated_profile_identity="${test_root}/profile-identity.json"
"${profile_identity_generator}" "${generated_profile_identity}" >/dev/null
cmp -s "${profile_identity}" "${generated_profile_identity}" || {
  echo "The bundled Profile Layout identity is stale or not generated from the Release Specification." >&2
  exit 1
}

absolute_profile_identity="${test_root}/absolute path/profile identity.json"
"${profile_identity_generator}" "${absolute_profile_identity}" >/dev/null
cmp -s "${profile_identity}" "${absolute_profile_identity}" || {
  echo "Profile identity generation changed for an absolute path with spaces." >&2
  exit 1
}

(
  cd "${test_root}"
  "${profile_identity_generator}" "relative path/profile identity.json" >/dev/null
)
cmp -s "${profile_identity}" "${test_root}/relative path/profile identity.json" || {
  echo "Profile identity generation changed for a relative path with spaces." >&2
  exit 1
}

symlinked_profile_identity="${test_root}/linked-profile-identity.json"
ln -s "${profile_identity}" "${symlinked_profile_identity}"
if "${profile_identity_generator}" "${symlinked_profile_identity}" >/dev/null 2>&1; then
  echo "Profile identity generation replaced a symbolic link." >&2
  exit 1
fi

directory_profile_identity="${test_root}/directory-profile-identity.json"
mkdir "${directory_profile_identity}"
if "${profile_identity_generator}" "${directory_profile_identity}" >/dev/null 2>&1; then
  echo "Profile identity generation accepted a directory as its output file." >&2
  exit 1
fi

jq -e '
  .schema_version == 1
  and .target == {platform: "darwin", architecture: "arm64"}
  and .profile_schema_version == 1
  and .product == {
    app_name: "DBCode Wrapper",
    application_name: "dbcode-wrapper",
    bundle_identifier: "io.alexabelle.dbcodewrapper",
    data_folder_name: ".dbcode-wrapper",
    user_data_folder_name: "DBCode Wrapper",
    extensions_folder_name: "extensions",
    shared_data_folder_name: ".dbcode-wrapper-shared",
    backup_folder_name: "DBCode Wrapper Profile Backups",
    storage_namespace: "dbcode-wrapper",
    query_folder_name: "queries"
  }
' "${profile_identity}" >/dev/null || {
  echo "The generated Profile Layout identity is incomplete." >&2
  exit 1
}

jq -e '
  .publisher == "dbcode-wrapper"
  and .name == "profile-migration"
  and .main == "./extension.js"
  and (.activationEvents | sort) == [
    "onCommand:dbcodeWrapper.startProfileMigration",
    "onCommand:dbcodeWrapper.startRuntimeSetup",
    "onStartupFinished"
  ]
  and ([.contributes.commands[].command] | sort) == [
    "dbcodeWrapper.startProfileMigration",
    "dbcodeWrapper.startRuntimeSetup"
  ]
  and all(.contributes.menus.commandPalette[]; .when == "false")
' "${extension_manifest}" >/dev/null || {
  echo "Profile migration must stay inside the focused DBCode shell." >&2
  exit 1
}

for required_runtime_contract in \
  'dbcode.connections.import' \
  'showOpenDialog' \
  'stageReviewedInventory' \
  'cleanupReviewedInventory' \
  'globalState' \
  'Passwords, tokens, private keys, licence data, and old connection identifiers are never migrated.' \
  'DBCode will ask you to map and preview these reviewed fields again before importing.' \
  'Back up and recreate profile' \
  'workbench.action.quit' \
  'recreateStandaloneProfile' \
  'shouldRelaunchApplication(request, processesExited, outcome)' \
  'deriveRecoveryLayout' \
  'DBCODE_WRAPPER_PROFILE_LAYOUT_JSON' \
  'profileLayout' \
  'crypto.randomUUID()' \
  'void vscode.window.showInformationMessage' \
  'Choose CSV' \
  'enableScripts: true'; do
  rg -Fq "${required_runtime_contract}" "${extension_runtime}" "${extension_view}" "${recovery_logic}" "${recovery_worker}" || {
    echo "The profile-migration flow is missing: ${required_runtime_contract}" >&2
    exit 1
  }
done

for required_orchestration_contract in \
  'class ProfileSetup' \
  'async dispatch(action)' \
  'async panelClosed()' \
  'async recreateProfile()' \
  'requireMatchingRelaunchPath' \
  'await this.adapter.startRecovery(this.recoveryRequest())' \
  'await this.adapter.quit()'; do
  rg -Fq "${required_orchestration_contract}" "${profile_setup}" || {
    echo "Profile Setup is missing orchestration: ${required_orchestration_contract}" >&2
    exit 1
  }
done

if rg -n 'class ProfileMigrationController|this\.plan|this\.staged|preflightProgress|finishPreflight|recoveryRequest' "${extension_runtime}"; then
  echo "The extension must remain a thin host adapter for Profile Setup." >&2
  exit 1
fi

rg -Fq 'new ProfileSetup({' "${extension_runtime}" || {
  echo "The extension must delegate Profile Setup actions to the testable module." >&2
  exit 1
}

for required_first_run_contract in \
  'createFirstRunCommandRouter' \
  'this.registerCommand(START_RUNTIME_SETUP_COMMAND' \
  'this.registerCommand(START_MIGRATION_COMMAND' \
  'openProfileSetup' \
  'setRuntimeSetup' \
  'setProfileSetup' \
  'setUnavailable'; do
  rg -Fq "${required_first_run_contract}" "${extension_runtime}" "${first_run_command_router}" || {
    echo "First-run commands are not routed through the always-registered command seam: ${required_first_run_contract}" >&2
    exit 1
  }
done

for required_webview_safety_contract in \
  'renderWebviewDocument' \
  "default-src 'none'" \
  'script-src' \
  'escapeHtml'; do
  rg -Fq "${required_webview_safety_contract}" "${extension_view}" "${runtime_setup_view}" "${webview_safety}" || {
    echo "First-run webviews are missing the shared fail-closed safety contract: ${required_webview_safety_contract}" >&2
    exit 1
  }
done

if rg -n '\.vscode|Code/User|VSCodium/User|globalStorage/dbcode\.dbcode|SecretStorage' "${extension_runtime}" "${extension_view}" "${migration_logic}" "${profile_setup}" "${staging_logic}" "${recovery_logic}" "${recovery_worker}"; then
  echo "Profile migration must not inspect or copy another editor profile or secret store." >&2
  exit 1
fi

if rg -n '/usr/bin/security|context\.secrets|keytar|find-generic-password|delete-generic-password' "${extension_runtime}" "${profile_setup}" "${recovery_logic}" "${recovery_worker}"; then
  echo "Profile recovery must not read, write, or delete macOS Keychain records." >&2
  exit 1
fi

for required_recovery_contract in \
  'PROFILE_BACKUP_ROOT=' \
  'DBCODE_WRAPPER_SHARED_DATA_ROOT' \
  'DBCODE_WRAPPER_EXTENSIONS_ROOT' \
  'DBCODE_WRAPPER_PROFILE_LAYOUT_JSON' \
  'DBCODE_WRAPPER_PROFILE_BACKUP_ROOT' \
  'DBCODE_WRAPPER_APP_BUNDLE' \
  'DBCODE_WRAPPER_RECOVERY_RELAUNCH_ARGS'; do
  rg -Fq "${required_recovery_contract}" "${profile_paths}" "${host_launcher}" || {
    echo "The Standalone DBCode Profile launcher is missing recovery path wiring: ${required_recovery_contract}" >&2
    exit 1
  }
done

for required_shell_contract in \
  'dbcodeWrapper.startProfileMigration' \
  'Profile Setup…'; do
  rg -Fq "${required_shell_contract}" "${shell_sources[@]}" || {
    echo "The focused shell is missing profile setup: ${required_shell_contract}" >&2
    exit 1
  }
done

jq -e '
  any(.build.built_in_extensions.first_party[];
    .name == "dbcode-wrapper-profile-migration"
    and .source == "host/extensions/dbcode-wrapper-profile-migration"
  )
' "${REPO_ROOT}/host/slimming-policy.json" >/dev/null || {
  echo "The production package must include the reviewed profile-migration bridge." >&2
  exit 1
}

"${NODE_BIN_DIR}/node" --check "${extension_runtime}"
"${NODE_BIN_DIR}/node" --check "${extension_view}"
"${NODE_BIN_DIR}/node" --check "${first_run_command_router}"
"${NODE_BIN_DIR}/node" --check "${webview_safety}"
"${NODE_BIN_DIR}/node" --check "${migration_logic}"
"${NODE_BIN_DIR}/node" --check "${profile_setup}"
"${NODE_BIN_DIR}/node" --check "${staging_logic}"
"${NODE_BIN_DIR}/node" --check "${recovery_logic}"
"${NODE_BIN_DIR}/node" --check "${recovery_worker}"
"${NODE_BIN_DIR}/node" --check "${profile_layout}"
"${NODE_BIN_DIR}/node" --check "${runtime_setup}"
"${NODE_BIN_DIR}/node" --check "${openvsx_package_verifier}"
"${NODE_BIN_DIR}/node" --check "${runtime_setup_controller}"
"${NODE_BIN_DIR}/node" --check "${runtime_setup_view}"
"${NODE_BIN_DIR}/node" --check "${profile_layout_cli}"
"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_profile_layout.mjs"
"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_profile_migration.mjs"

echo "Focused profile-migration contracts passed."
