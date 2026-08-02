#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: ./script/generate_runtime_setup_manifest.sh <output-json>" >&2
  exit 2
fi

case "$1" in
  /*) output_file="$1" ;;
  *) output_file="${PWD}/$1" ;;
esac
"${NODE_BIN_DIR}/node" "${REPO_ROOT}/script/runtime_extension_set.cjs" \
  write \
  "${output_file}" \
  "${APPLICATION_NAME}" \
  "${RELEASE_EXTENSION_SPEC}" \
  "${REPO_ROOT}/host/keys"

echo "Focused runtime setup manifest: ${output_file}"
