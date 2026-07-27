#!/usr/bin/env bash

set -euo pipefail
umask 077

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_root}/.." && pwd)"
source "${script_root}/lib/host_config.sh"
test_root="$(mktemp -d "${BUILD_ROOT}/local-signing-contract.XXXXXX")"
cleanup_test_root() {
  case "${test_root}" in
    "${BUILD_ROOT}/local-signing-contract."*) rm -rf "${test_root}" ;;
    *) echo "Refusing to remove unexpected signing-test path: ${test_root}" >&2; return 1 ;;
  esac
}
trap cleanup_test_root EXIT INT TERM

signing_library="${script_root}/lib/local_signing_identity.sh"
setup_script="${script_root}/setup_local_signing_identity.sh"
continuity_script="${script_root}/verify_local_signing_continuity.sh"

for required_file in "${signing_library}" "${setup_script}" "${continuity_script}"; do
  [[ -f "${required_file}" ]] || {
    echo "Missing local-signing component: ${required_file}" >&2
    exit 1
  }
done

jq -e '
  .product.signing == {
    mode: "local-certificate",
    identity_common_name: "DBCode Wrapper Local Signing",
    scope: "current-user-private-use"
  }
' <<<"${RELEASE_PROFILE_SPEC}" >/dev/null || {
  echo "The release lock must pin the private local-signing contract." >&2
  exit 1
}

rg -Fq 'security add-trusted-cert' "${setup_script}"
rg -Fq -- '-r trustRoot' "${setup_script}"
rg -Fq -- '-p codeSign' "${setup_script}"
rg -Fq -- '-T /usr/bin/codesign' "${setup_script}"
if rg -q -- '(^|[[:space:]])-A([[:space:]]|$)' "${setup_script}" || \
  rg -q 'add-trusted-cert.*[[:space:]]-d([[:space:]]|$)' "${setup_script}"; then
  echo "Local signing must not allow every application or change admin trust." >&2
  exit 1
fi

if rg -Fq -- '--sign -' "${script_root}/sign_host.sh"; then
  echo "The release signer must not fall back to an ad-hoc identity." >&2
  exit 1
fi
rg -Fq 'load_local_signing_identity' "${script_root}/sign_host.sh"
rg -Fq 'local_signing_expected_requirement' "${script_root}/sign_host.sh"

export DBCODE_WRAPPER_SIGNING_ROOT="${test_root}/signing"
mkdir -p "${DBCODE_WRAPPER_SIGNING_ROOT}"
chmod 700 "${DBCODE_WRAPPER_SIGNING_ROOT}"
certificate_sha1="0123456789ABCDEF0123456789ABCDEF01234567"
certificate_sha256="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
fixture_keychain="$(security default-keychain -d user | sed -E 's/^[[:space:]]*"(.*)"[[:space:]]*$/\1/')"
jq -n \
  --arg certificate_sha1 "${certificate_sha1}" \
  --arg certificate_sha256 "${certificate_sha256}" \
  --arg keychain "${fixture_keychain}" '
    {
      schema_version: 1,
      mode: "local-certificate",
      scope: "current-user-private-use",
      identity_common_name: "DBCode Wrapper Local Signing",
      keychain: $keychain,
      certificate_sha1: $certificate_sha1,
      certificate_sha256: $certificate_sha256,
      certificate_path: "local-signing-certificate.pem"
    }
  ' > "${DBCODE_WRAPPER_SIGNING_ROOT}/identity.json"
chmod 600 "${DBCODE_WRAPPER_SIGNING_ROOT}/identity.json"
printf '%s\n' 'fixture public certificate' > "${DBCODE_WRAPPER_SIGNING_ROOT}/local-signing-certificate.pem"
chmod 600 "${DBCODE_WRAPPER_SIGNING_ROOT}/local-signing-certificate.pem"

source "${script_root}/lib/host_config.sh"
source "${signing_library}"
load_local_signing_metadata
[[ "${LOCAL_SIGNING_CERTIFICATE_SHA1}" == "${certificate_sha1}" ]]
[[ "$(local_signing_expected_requirement "${BUNDLE_IDENTIFIER}")" == \
  "designated => certificate root = H\"${certificate_sha1,,}\" and identifier \"${BUNDLE_IDENTIFIER}\"" ]]

chmod 644 "${DBCODE_WRAPPER_SIGNING_ROOT}/identity.json"
if (load_local_signing_metadata) >/dev/null 2>&1; then
  echo "The signing metadata accepted permissions wider than the current user." >&2
  exit 1
fi

echo "Persistent local-signing contracts passed."
