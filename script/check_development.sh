#!/usr/bin/env bash

set -euo pipefail

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_root}/.." && pwd)"

"${script_root}/test_host_contract.sh" --source-only
"${script_root}/test_patch_plan.sh"
"${script_root}/test_development_gate_contract.sh"
"${script_root}/test_release_specification.sh"
"${script_root}/test_host_slimming_contract.sh" --source-only
"${script_root}/test_dbcode_contract.sh"
"${script_root}/test_runtime_extensions_contract.sh"
"${script_root}/test_installed_extension_payload.sh"
"${script_root}/test_restore_installed_extension_payload.sh"
"${script_root}/test_python_notebook_contract.sh"
node --test "${script_root}/test_connection_catalogue_contract.mjs"
"${script_root}/test_dbcode_feature_contract.sh" --source-only
"${script_root}/test_profile_paths.sh"
"${script_root}/test_host_session_contract.sh"
"${script_root}/test_profile_settings.sh"
"${script_root}/test_proof_state.sh"
"${script_root}/test_release_rollback_contract.sh"
"${script_root}/test_release_identity.sh"
"${script_root}/test_local_signing_contract.sh"
"${script_root}/test_same_mac_release_contract.sh"
"${script_root}/test_public_source_tree_contract.sh"
"${script_root}/test_public_push_readiness.sh"
"${script_root}/test_runtime_setup_contract.sh"
"${script_root}/test_private_release_contract.sh"
"${script_root}/test_update_status_contract.sh"
"${script_root}/test_controlled_upgrade.sh"
"${script_root}/test_profile_migration_contract.sh"
node "${script_root}/test_extension_host_log_policy.mjs"
"${script_root}/test_focused_shell_contract.sh"
git -C "${repo_root}" diff --check

echo "Development source checks passed without rebuilding the app."
