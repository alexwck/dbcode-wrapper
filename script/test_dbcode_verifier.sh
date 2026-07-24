#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

dbcode_version="${DBCODE_VERSION}"
package_root="${CACHE_ROOT}/runtime-extensions/dbcode.dbcode/${dbcode_version}"
vsix_file="${package_root}/package.vsix"
signature_archive="${package_root}/signature.sigzip"
registry_record="${package_root}/registry.json"
sha256_record="${package_root}/package.sha256"
public_key="${package_root}/openvsx-public-key.pem"

for acquisition_file in \
  "${vsix_file}" \
  "${signature_archive}" \
  "${registry_record}" \
  "${sha256_record}" \
  "${public_key}"; do
  [[ -f "${acquisition_file}" ]] || {
    echo "Prepare DBCode before running the verifier integration test." >&2
    exit 1
  }
done

"${REPO_ROOT}/script/verify_openvsx_package.sh" \
  "${DBCODE_ID}" \
  "${package_root}" >/dev/null

test_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-wrapper-verifier-test.XXXXXX")"
cleanup_test_root() {
  rm -rf "${test_root}"
}
trap cleanup_test_root EXIT INT TERM

tampered_registry_root="${test_root}/tampered-registry"
cp -R "${package_root}" "${tampered_registry_root}"
jq '.verified = false' "${registry_record}" > "${tampered_registry_root}/registry.json"
if "${REPO_ROOT}/script/verify_openvsx_package.sh" \
  "${DBCODE_ID}" \
  "${tampered_registry_root}" >/dev/null 2>&1; then
  echo "The verifier accepted an unverified Open VSX publisher record." >&2
  exit 1
fi

tampered_signature_root="${test_root}/tampered-signature"
cp -R "${package_root}" "${tampered_signature_root}"
printf 'tampered' >> "${tampered_signature_root}/signature.sigzip"
if "${REPO_ROOT}/script/verify_openvsx_package.sh" \
  "${DBCODE_ID}" \
  "${tampered_signature_root}" >/dev/null 2>&1; then
  echo "The verifier accepted a modified signature archive." >&2
  exit 1
fi

echo "DBCode verifier accepted the official package and rejected tampered records."
