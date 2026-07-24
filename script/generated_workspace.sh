#!/usr/bin/env bash

set -euo pipefail

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_root}/lib/host_config.sh"
source "${script_root}/lib/generated_workspace.sh"

generated_workspace_require_runtime
exec "${NODE_BIN_DIR}/node" "${script_root}/generated_workspace.cjs" "$@"
