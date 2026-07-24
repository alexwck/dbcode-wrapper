#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

extension_root="${REPO_ROOT}/host/extensions/dbcode-wrapper-profile-migration"
extension_manifest="${extension_root}/package.json"
extension_runtime="${extension_root}/extension.js"
extension_view="${extension_root}/view.js"
migration_logic="${extension_root}/migration.js"
staging_logic="${extension_root}/staging.js"
recovery_logic="${extension_root}/profileRecovery.js"
recovery_worker="${extension_root}/profileRecoveryWorker.js"
profile_layout="${extension_root}/profile-layout.js"
runtime_setup="${extension_root}/runtimeSetup.js"
runtime_setup_controller="${extension_root}/runtimeSetupController.js"
runtime_setup_view="${extension_root}/runtimeSetupView.js"
profile_layout_cli="${REPO_ROOT}/script/profile_layout.cjs"
managed_settings="${extension_root}/managed-settings.json"
shell_patches=(
  "${REPO_ROOT}/host/patches/code-oss/200-final-focused-dbcode-shell.patch"
  "${REPO_ROOT}/host/patches/code-oss/400-release-profile-and-dbcode-integrations.patch"
)
profile_paths="${REPO_ROOT}/script/lib/profile_paths.sh"
host_launcher="${REPO_ROOT}/script/run_host.sh"

for required_file in \
  "${extension_manifest}" \
  "${extension_runtime}" \
  "${extension_view}" \
  "${migration_logic}" \
  "${staging_logic}" \
  "${recovery_logic}" \
  "${recovery_worker}" \
  "${profile_layout}" \
  "${runtime_setup}" \
  "${runtime_setup_controller}" \
  "${runtime_setup_view}" \
  "${profile_layout_cli}" \
  "${managed_settings}" \
  "${shell_patches[@]}"; do
  [[ -f "${required_file}" ]] || {
    echo "Missing focused profile-migration file: ${required_file}" >&2
    exit 1
  }
done

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
  'DBCODE_WRAPPER_QA_RECOVERY' \
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

if rg -n '\.vscode|Code/User|VSCodium/User|globalStorage/dbcode\.dbcode|SecretStorage' "${extension_runtime}" "${extension_view}" "${migration_logic}" "${staging_logic}" "${recovery_logic}" "${recovery_worker}"; then
  echo "Profile migration must not inspect or copy another editor profile or secret store." >&2
  exit 1
fi

if rg -n '/usr/bin/security|context\.secrets|keytar|find-generic-password|delete-generic-password' "${extension_runtime}" "${recovery_logic}" "${recovery_worker}"; then
  echo "Profile recovery must not read, write, or delete macOS Keychain records." >&2
  exit 1
fi

cmp -s "${managed_settings}" "${REPO_ROOT}/host/profile/settings.json" || {
  echo "Profile recovery must recreate the exact managed Standalone DBCode Profile settings." >&2
  exit 1
}

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
  rg -Fq "${required_shell_contract}" "${shell_patches[@]}" || {
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
"${NODE_BIN_DIR}/node" --check "${migration_logic}"
"${NODE_BIN_DIR}/node" --check "${staging_logic}"
"${NODE_BIN_DIR}/node" --check "${recovery_logic}"
"${NODE_BIN_DIR}/node" --check "${recovery_worker}"
"${NODE_BIN_DIR}/node" --check "${profile_layout}"
"${NODE_BIN_DIR}/node" --check "${runtime_setup}"
"${NODE_BIN_DIR}/node" --check "${runtime_setup_controller}"
"${NODE_BIN_DIR}/node" --check "${runtime_setup_view}"
"${NODE_BIN_DIR}/node" --check "${profile_layout_cli}"
"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_profile_layout.mjs"
"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_profile_migration.mjs"

echo "Focused profile-migration contracts passed."
