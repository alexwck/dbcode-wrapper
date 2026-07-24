#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

require_command curl
require_command jq
require_command shasum
require_command tar
require_command python3
require_command clang
require_command xcrun

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "${TARGET_ARCH}" ]]; then
  echo "This proof build requires an Apple-silicon Mac (${TARGET_ARCH})." >&2
  exit 1
fi

python_actual="$(python3 --version 2>&1 | awk '{print $2}')"
if [[ "${python_actual}" != "${PYTHON_VERSION}" ]]; then
  echo "Python ${PYTHON_VERSION} is required; found ${python_actual}." >&2
  exit 1
fi

clang_actual="$(clang --version | sed -n '1s/Apple clang version \([^ ]*\).*/\1/p')"
if [[ "${clang_actual}" != "${APPLE_CLANG_VERSION}" ]]; then
  echo "Apple clang ${APPLE_CLANG_VERSION} is required; found ${clang_actual}." >&2
  exit 1
fi

sdk_actual="$(xcrun --sdk macosx --show-sdk-version)"
if [[ "${sdk_actual}" != "${MACOS_SDK_VERSION}" ]]; then
  echo "macOS SDK ${MACOS_SDK_VERSION} is required; found ${sdk_actual}." >&2
  exit 1
fi

mkdir -p "${TOOLCHAIN_ROOT}" "${BUILD_ROOT}/downloads"
node_archive="${BUILD_ROOT}/downloads/node-v${NODE_VERSION}-darwin-${TARGET_ARCH}.tar.gz"

if [[ ! -x "${NODE_BIN_DIR}/node" ]]; then
  if [[ ! -f "${node_archive}" ]] || [[ "$(shasum -a 256 "${node_archive}" | awk '{print $1}')" != "${NODE_ARCHIVE_SHA256}" ]]; then
    echo "Downloading pinned Node.js ${NODE_VERSION}..."
    curl --fail --location --retry 3 --output "${node_archive}" "${NODE_ARCHIVE_URL}"
  fi

  archive_actual="$(shasum -a 256 "${node_archive}" | awk '{print $1}')"
  if [[ "${archive_actual}" != "${NODE_ARCHIVE_SHA256}" ]]; then
    echo "Node.js archive checksum mismatch." >&2
    exit 1
  fi

  extract_root="$(mktemp -d "${TOOLCHAIN_ROOT}/node-extract.XXXXXX")"
  trap 'rm -rf "${extract_root}"' EXIT
  tar -xzf "${node_archive}" -C "${extract_root}"
  extracted_node="${extract_root}/node-v${NODE_VERSION}-darwin-${TARGET_ARCH}"
  if [[ ! -x "${extracted_node}/bin/node" ]]; then
    echo "The Node.js archive did not contain the expected toolchain." >&2
    exit 1
  fi
  mv "${extracted_node}" "${NODE_ROOT}"
  trap - EXIT
  rm -rf "${extract_root}"
fi

node_actual="$("${NODE_BIN_DIR}/node" --version)"
npm_actual="$("${NODE_BIN_DIR}/npm" --version)"
if [[ "${node_actual}" != "v${NODE_VERSION}" || "${npm_actual}" != "${NODE_NPM_VERSION}" ]]; then
  echo "Pinned Node.js toolchain validation failed: node=${node_actual}, npm=${npm_actual}." >&2
  exit 1
fi

echo "Toolchain ready: Node ${node_actual}, npm ${npm_actual}, Python ${python_actual}, clang ${clang_actual}, SDK ${sdk_actual}"
