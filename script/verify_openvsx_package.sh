#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

if [[ $# -ne 2 ]]; then
  echo "Usage: ./script/verify_openvsx_package.sh <extension-id> <package-root>" >&2
  exit 2
fi

runtime_extension_packages="$(jq -c '.packages' <<<"${RELEASE_EXTENSION_SPEC}")"
adapter="${REPO_ROOT}/script/verify_openvsx_package.cjs"
yauzl_module="${APP_BUNDLE}/Contents/Resources/app/node_modules/yauzl"
[[ -x "${NODE_BIN_DIR}/node" && -f "${adapter}" && -d "${yauzl_module}" ]] || {
  echo "The signed host Open VSX verifier is unavailable." >&2
  exit 1
}

exec "${NODE_BIN_DIR}/node" \
  "${adapter}" \
  "$1" \
  "$2" \
  "${CODE_OSS_VERSION}" \
  "${runtime_extension_packages}" \
  "${REPO_ROOT}/host/keys" \
  "${yauzl_module}"
