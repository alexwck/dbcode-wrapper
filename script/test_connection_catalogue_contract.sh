#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

catalogue_test="${REPO_ROOT}/script/test_connection_catalogue_contract.mjs"
[[ -f "${catalogue_test}" ]] || {
  echo "Missing connection-catalogue test: ${catalogue_test}" >&2
  exit 1
}

"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_connection_catalogue_contract.mjs"
