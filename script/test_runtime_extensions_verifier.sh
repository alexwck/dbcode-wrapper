#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

runtime_extension_packages="$(jq -c '.packages' <<<"${RELEASE_EXTENSION_SPEC}")"
dbcode_package_spec="$(jq -c '.dbcode' <<<"${RELEASE_EXTENSION_SPEC}")"
dbcode_id="$(jq -er '.id' <<<"${dbcode_package_spec}")"
dbcode_version="$(jq -er '.version' <<<"${dbcode_package_spec}")"
verifier="${REPO_ROOT}/script/verify_openvsx_package.sh"
verifier_adapter="${REPO_ROOT}/script/verify_openvsx_package.cjs"
verification_module="${REPO_ROOT}/host/extensions/dbcode-wrapper-profile-migration/openVsxPackageVerifier.js"
[[ -x "${verifier}" ]] || {
  echo "The shared Open VSX package verifier is missing." >&2
  exit 1
}

[[ -f "${verifier_adapter}" && -f "${verification_module}" ]] || {
  echo "The shared Open VSX verification module or script adapter is missing." >&2
  exit 1
}

rg -Fq 'verify_openvsx_package.cjs' "${verifier}" || {
  echo "The shell verifier must delegate to its Node adapter." >&2
  exit 1
}
rg -Fq 'verifyOpenVsxPackage' "${verifier_adapter}" || {
  echo "The script adapter must delegate to the shared Open VSX verifier." >&2
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
' <<<"${runtime_extension_packages}")

test_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-wrapper-runtime-verifier.XXXXXX")"
cleanup_test_root() {
  rm -rf "${test_root}"
}
trap cleanup_test_root EXIT INT TERM

dbcode_root="${runtime_cache}/${dbcode_id}/${dbcode_version}"
tampered_package_root="${test_root}/dbcode.dbcode"
cp -R "${dbcode_root}" "${tampered_package_root}"
jq '.verified = false' "${dbcode_root}/registry.json" > "${tampered_package_root}/registry.json"
if "${verifier}" \
  "${dbcode_id}" \
  "${tampered_package_root}" >/dev/null 2>&1; then
  echo "The shared verifier accepted an unverified Open VSX publisher record." >&2
  exit 1
fi

echo "Runtime-extension verifier accepted every locked package and rejected tampered metadata."
