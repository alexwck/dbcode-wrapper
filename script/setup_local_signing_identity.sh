#!/usr/bin/env bash

set -euo pipefail
umask 077

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_root}/lib/host_config.sh"
source "${script_root}/lib/local_signing_identity.sh"

usage() {
  echo "Usage: ./script/setup_local_signing_identity.sh [--status]" >&2
  exit 2
}

status_only="no"
if [[ $# -eq 1 && "$1" == "--status" ]]; then
  status_only="yes"
elif [[ $# -ne 0 ]]; then
  usage
fi

for required_tool in codesign jq openssl security shasum stat; do
  require_command "${required_tool}"
done

if load_local_signing_identity >/dev/null 2>&1; then
  echo "Persistent local signing is ready."
  echo "Identity: ${SIGNING_IDENTITY_COMMON_NAME}"
  echo "Certificate SHA-256: ${LOCAL_SIGNING_CERTIFICATE_SHA256}"
  echo "Scope: ${SIGNING_SCOPE}"
  exit 0
fi

if [[ "${status_only}" == "yes" ]]; then
  echo "Persistent local signing is not ready." >&2
  exit 1
fi

default_keychain="$(security default-keychain -d user | sed -E 's/^[[:space:]]*"(.*)"[[:space:]]*$/\1/')"
case "${default_keychain}" in
  "$(current_user_home)/Library/Keychains/"*) ;;
  *)
    echo "The default user Keychain is outside the current user's Keychains folder: ${default_keychain}" >&2
    exit 1
    ;;
esac
[[ -f "${default_keychain}" && ! -L "${default_keychain}" ]] || {
  echo "The default user Keychain is missing or unsafe: ${default_keychain}" >&2
  exit 1
}

mkdir -p "${LOCAL_SIGNING_ROOT}"
chmod 700 "${LOCAL_SIGNING_ROOT}"

write_signing_metadata() {
  local certificate_file="$1"
  local keychain="$2"
  local certificate_sha1 certificate_sha256 metadata_temp
  IFS=$'\t' read -r certificate_sha1 certificate_sha256 < <(local_signing_certificate_hashes "${certificate_file}")
  cp "${certificate_file}" "${LOCAL_SIGNING_ROOT}/local-signing-certificate.pem"
  chmod 600 "${LOCAL_SIGNING_ROOT}/local-signing-certificate.pem"
  metadata_temp="${LOCAL_SIGNING_METADATA_FILE}.tmp"
  jq -n \
    --arg mode "${SIGNING_MODE}" \
    --arg scope "${SIGNING_SCOPE}" \
    --arg common_name "${SIGNING_IDENTITY_COMMON_NAME}" \
    --arg keychain "${keychain}" \
    --arg certificate_sha1 "${certificate_sha1}" \
    --arg certificate_sha256 "${certificate_sha256}" '
      {
        schema_version: 1,
        mode: $mode,
        scope: $scope,
        identity_common_name: $common_name,
        keychain: $keychain,
        certificate_sha1: $certificate_sha1,
        certificate_sha256: $certificate_sha256,
        certificate_path: "local-signing-certificate.pem"
      }
    ' > "${metadata_temp}"
  chmod 600 "${metadata_temp}"
  mv "${metadata_temp}" "${LOCAL_SIGNING_METADATA_FILE}"
}

trust_and_verify_identity() {
  load_local_signing_metadata
  echo "macOS may ask for your login password to trust this certificate for code signing only."
  security add-trusted-cert \
    -r trustRoot \
    -p codeSign \
    -k "${LOCAL_SIGNING_KEYCHAIN}" \
    "${LOCAL_SIGNING_CERTIFICATE_FILE}"
  load_local_signing_identity

  local signing_probe
  signing_probe="$(mktemp "${TMPDIR:-/private/tmp}/dbcode-wrapper-signing-probe.XXXXXX")"
  cp /usr/bin/true "${signing_probe}"
  codesign \
    --force \
    --keychain "${LOCAL_SIGNING_KEYCHAIN}" \
    --sign "${LOCAL_SIGNING_IDENTITY}" \
    --timestamp=none \
    "${signing_probe}"
  codesign --verify --strict "${signing_probe}"
  rm -f "${signing_probe}"
}

if [[ -f "${LOCAL_SIGNING_METADATA_FILE}" ]]; then
  load_local_signing_metadata
  trust_and_verify_identity
  echo "Persistent local signing is ready."
  echo "Certificate SHA-256: ${LOCAL_SIGNING_CERTIFICATE_SHA256}"
  exit 0
fi

existing_identity_lines="$(security find-identity -p codesigning "${default_keychain}" | \
  awk -v name="${SIGNING_IDENTITY_COMMON_NAME}" 'index($0, "\"" name "\"") > 0 {print}')"
existing_identity_count="$(printf '%s\n' "${existing_identity_lines}" | awk 'NF {count++} END {print count + 0}')"
if [[ "${existing_identity_count}" -gt 1 ]]; then
  echo "More than one Keychain identity is named ${SIGNING_IDENTITY_COMMON_NAME}." >&2
  echo "Resolve the duplicate identities in Keychain Access before continuing." >&2
  exit 1
fi
if [[ "${existing_identity_count}" -eq 1 ]]; then
  existing_sha1="$(awk '{print $2}' <<<"${existing_identity_lines}")"
  existing_certificate="$(mktemp "${TMPDIR:-/private/tmp}/dbcode-wrapper-existing-certificate.XXXXXX.pem")"
  security find-certificate \
    -c "${SIGNING_IDENTITY_COMMON_NAME}" \
    -p \
    "${default_keychain}" > "${existing_certificate}"
  IFS=$'\t' read -r exported_sha1 _ < <(local_signing_certificate_hashes "${existing_certificate}")
  [[ "${exported_sha1}" == "${existing_sha1}" ]] || {
    rm -f "${existing_certificate}"
    echo "The existing signing certificate is ambiguous. Resolve it in Keychain Access." >&2
    exit 1
  }
  write_signing_metadata "${existing_certificate}" "${default_keychain}"
  rm -f "${existing_certificate}"
  trust_and_verify_identity
  echo "Recovered and verified the existing persistent local signing identity."
  echo "Certificate SHA-256: ${LOCAL_SIGNING_CERTIFICATE_SHA256}"
  exit 0
fi

temporary_root="$(mktemp -d "${TMPDIR:-/private/tmp}/dbcode-wrapper-local-signing.XXXXXX")"
cleanup_temporary_root() {
  case "${temporary_root}" in
    "${TMPDIR:-/private/tmp}"/dbcode-wrapper-local-signing.*) rm -rf "${temporary_root}" ;;
    *) echo "Refusing to remove unexpected signing setup path: ${temporary_root}" >&2 ;;
  esac
}
trap cleanup_temporary_root EXIT INT TERM

private_key="${temporary_root}/identity.key"
certificate="${temporary_root}/identity.pem"
identity_archive="${temporary_root}/identity.p12"
identity_archive_passphrase="$(openssl rand -hex 32)"
openssl req \
  -new \
  -newkey rsa:3072 \
  -x509 \
  -sha256 \
  -days 3650 \
  -nodes \
  -subj "/CN=${SIGNING_IDENTITY_COMMON_NAME}/O=DBCode Wrapper Personal Use" \
  -addext 'basicConstraints=critical,CA:FALSE' \
  -addext 'keyUsage=critical,digitalSignature' \
  -addext 'extendedKeyUsage=codeSigning' \
  -keyout "${private_key}" \
  -out "${certificate}" \
  2>/dev/null
chmod 600 "${private_key}" "${certificate}"
openssl pkcs12 \
  -export \
  -legacy \
  -name "${SIGNING_IDENTITY_COMMON_NAME}" \
  -inkey "${private_key}" \
  -in "${certificate}" \
  -passout "pass:${identity_archive_passphrase}" \
  -out "${identity_archive}"
chmod 600 "${identity_archive}"

security import "${identity_archive}" \
  -k "${default_keychain}" \
  -f pkcs12 \
  -P "${identity_archive_passphrase}" \
  -T /usr/bin/codesign
unset identity_archive_passphrase
write_signing_metadata "${certificate}" "${default_keychain}"
trust_and_verify_identity

echo "Created the persistent DBCode Wrapper local signing identity."
echo "Identity: ${SIGNING_IDENTITY_COMMON_NAME}"
echo "Certificate SHA-256: ${LOCAL_SIGNING_CERTIFICATE_SHA256}"
echo "Scope: ${SIGNING_SCOPE}"
echo "This identity signs the public host release. It is not Apple-trusted; downloaded builds may require Open Anyway."
