#!/usr/bin/env bash

set -euo pipefail

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_root}/.." && pwd)"

"${script_root}/test_host_contract.sh" --source-only
"${script_root}/test_patch_plan.sh"
"${script_root}/test_release_specification.sh"
"${script_root}/test_release_source_snapshot_contract.sh"
"${script_root}/test_build_host_task.sh"
"${script_root}/test_compiled_host_cache_contract.sh"
"${script_root}/test_host_slimming_contract.sh"
"${script_root}/test_dbcode_contract.sh"
"${script_root}/test_runtime_extensions_contract.sh"
"${script_root}/test_python_notebook_contract.sh"
"${script_root}/test_connection_catalogue_contract.sh"
"${script_root}/test_dbcode_feature_contract.sh" --source-only
"${script_root}/test_profile_paths.sh"
"${script_root}/test_host_session_contract.sh"
"${script_root}/test_generated_workspace_contract.sh"
"${script_root}/test_profile_settings.sh"
"${script_root}/test_release_identity.sh"
"${script_root}/test_local_signing_contract.sh"
"${script_root}/test_public_source_tree_contract.sh"
"${script_root}/test_runtime_setup_contract.sh"
"${script_root}/test_fast_release_acceptance_contract.sh"
"${script_root}/test_release_host_task.sh"
"${script_root}/test_update_status_contract.sh"
"${script_root}/test_profile_migration_contract.sh"
"${script_root}/test_focused_shell_contract.sh"
git -C "${repo_root}" diff --check

echo "Development source checks passed without rebuilding the app."
