#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

verifier="${REPO_ROOT}/script/verify_openvsx_package.sh"
verifier_adapter="${REPO_ROOT}/script/verify_openvsx_package.cjs"
verification_module="${REPO_ROOT}/host/extensions/dbcode-wrapper-profile-migration/openVsxPackageVerifier.js"
engine_checker="${REPO_ROOT}/script/check_vscode_engine.cjs"
[[ -x "${verifier}" ]] || {
  echo "The shared Open VSX package verifier is missing." >&2
  exit 1
}

[[ -f "${engine_checker}" ]] || {
  echo "The VS Code engine compatibility checker is missing." >&2
  exit 1
}
[[ -f "${verifier_adapter}" && -f "${verification_module}" ]] || {
  echo "The shared Open VSX verification module or script adapter is missing." >&2
  exit 1
}

"${NODE_BIN_DIR}/node" "${engine_checker}" "${CODE_OSS_VERSION}" '^1.95.0'
if "${NODE_BIN_DIR}/node" "${engine_checker}" "${CODE_OSS_VERSION}" '^1.127.0'; then
  echo "The engine checker accepted an extension that needs a newer Code OSS host." >&2
  exit 1
fi

rg -Fq 'verify_openvsx_package.cjs' "${verifier}" || {
  echo "The shell verifier must delegate to its Node adapter." >&2
  exit 1
}
rg -Fq 'verifyOpenVsxPackage' "${verifier_adapter}" || {
  echo "The script adapter must delegate to the shared Open VSX verifier." >&2
  exit 1
}
rg -Fq 'openVsxPackageVerifier' "${engine_checker}" || {
  echo "The engine checker must use the shared Open VSX verifier." >&2
  exit 1
}

runtime_cache="${CACHE_ROOT}/runtime-extensions"
while IFS=$'\t' read -r extension_id extension_version; do
  package_root="${runtime_cache}/${extension_id}/${extension_version}"
  for package_file in package.vsix signature.sigzip registry.json package.sha256 openvsx-public-key.pem; do
    [[ -f "${package_root}/${package_file}" ]] || {
      echo "Prepare the locked runtime extensions before running the verifier test: ${extension_id}@${extension_version}" >&2
      exit 1
    }
  done

  "${verifier}" \
    "${extension_id}" \
    "${package_root}" >/dev/null
done < <(jq -r '
  .[] | [.id, .version] | @tsv
' <<<"${RUNTIME_EXTENSION_PACKAGES}")

test_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-wrapper-runtime-verifier.XXXXXX")"
cleanup_test_root() {
  rm -rf "${test_root}"
}
trap cleanup_test_root EXIT INT TERM

dbcode_root="${runtime_cache}/${DBCODE_ID}/${DBCODE_VERSION}"
tampered_package_root="${test_root}/dbcode.dbcode"
cp -R "${dbcode_root}" "${tampered_package_root}"
jq '.verified = false' "${dbcode_root}/registry.json" > "${tampered_package_root}/registry.json"
if "${verifier}" \
  "${DBCODE_ID}" \
  "${tampered_package_root}" >/dev/null 2>&1; then
  echo "The shared verifier accepted an unverified Open VSX publisher record." >&2
  exit 1
fi

echo "Runtime-extension verifier accepted every locked package and rejected tampered metadata."
