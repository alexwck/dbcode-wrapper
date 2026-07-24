#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

if [[ $# -ne 2 ]]; then
  echo "Usage: ./script/verify_openvsx_package.sh <extension-id> <package-root>" >&2
  exit 2
fi

requested_package_id="$1"
package_root="$2"
vsix_file="${package_root}/package.vsix"
signature_archive="${package_root}/signature.sigzip"
registry_record="${package_root}/registry.json"
sha256_record="${package_root}/package.sha256"
downloaded_public_key="${package_root}/openvsx-public-key.pem"

[[ -d "${package_root}" && ! -L "${package_root}" ]] || {
  echo "Missing or unsafe Open VSX package root: ${package_root}" >&2
  exit 1
}

for required_file in \
  "${vsix_file}" \
  "${signature_archive}" \
  "${registry_record}" \
  "${sha256_record}" \
  "${downloaded_public_key}"; do
  [[ -f "${required_file}" && ! -L "${required_file}" ]] || {
    echo "Missing or unsafe Open VSX acquisition file: ${required_file}" >&2
    exit 1
  }
done

for required_command in cmp jq openssl shasum stat unzip xxd; do
  require_command "${required_command}"
done

package_record="$(jq -cer --arg id "${requested_package_id}" '
  map(select(.id == $id))
  | if length == 1 then .[0] else error("package not found or duplicated") end
' <<<"${RUNTIME_EXTENSION_PACKAGES}")" || {
  echo "The Release Specification has no unique package ${requested_package_id}." >&2
  exit 1
}

package_value() {
  jq -er "${1}" <<<"${package_record}"
}

package_namespace="$(package_value '.namespace')"
package_name="$(package_value '.name')"
package_id="$(package_value '.id')"
package_publisher="$(package_value '.publisher')"
package_version="$(package_value '.version')"
package_engine="$(package_value '.engine')"
package_target_platform="$(package_value '.target_platform')"
package_published_at="$(package_value '.published_at')"
registry_api_url="$(package_value '.registry_api_url')"
download_url="$(package_value '.download_url')"
signature_url="$(package_value '.signature_url')"
sha256_url="$(package_value '.sha256_url')"
public_key_url="$(package_value '.public_key_url')"
expected_vsix_sha="$(package_value '.sha256')"
expected_signature_sha="$(package_value '.signature_archive_sha256')"
expected_public_key_sha="$(package_value '.public_key_sha256')"
expected_package_size="$(package_value '.package_size')"
public_key_id="$(package_value '.public_key_id')"
pinned_public_key="${REPO_ROOT}/host/keys/openvsx-${public_key_id}.pem"

engine_checker="${REPO_ROOT}/script/check_vscode_engine.cjs"
[[ -x "${NODE_BIN_DIR}/node" && -f "${engine_checker}" ]] || {
  echo "The pinned Code OSS engine compatibility checker is unavailable." >&2
  exit 1
}
if ! "${NODE_BIN_DIR}/node" "${engine_checker}" "${CODE_OSS_VERSION}" "${package_engine}"; then
  echo "Approved package ${package_id}@${package_version} is not compatible with Code OSS ${CODE_OSS_VERSION}." >&2
  exit 1
fi

jq -e \
  --arg namespace "${package_namespace}" \
  --arg name "${package_name}" \
  --arg version "${package_version}" \
  --arg engine "${package_engine}" \
  --arg target_platform "${package_target_platform}" \
  --arg published_at "${package_published_at}" \
  --arg registry_api_url "${registry_api_url}" \
  --arg download_url "${download_url}" \
  --arg signature_url "${signature_url}" \
  --arg sha256_url "${sha256_url}" \
  --arg public_key_url "${public_key_url}" '
    .namespace == $namespace
    and .name == $name
    and .version == $version
    and .engines.vscode == $engine
    and .targetPlatform == $target_platform
    and .timestamp == $published_at
    and .verified == true
    and .preRelease == false
    and .deprecated == false
    and .files.download == $download_url
    and .files.signature == $signature_url
    and .files.sha256 == $sha256_url
    and .files.publicKey == $public_key_url
    and $registry_api_url == ("https://open-vsx.org/api/" + $namespace + "/" + $name + "/" + $version)
  ' "${registry_record}" >/dev/null || {
  echo "The Open VSX record does not match locked package ${package_id}@${package_version}." >&2
  exit 1
}

recorded_sha="$(tr -d '[:space:]' < "${sha256_record}")"
[[ "${recorded_sha}" == "${expected_vsix_sha}" ]] || {
  echo "The official SHA-256 record does not match locked package ${package_id}@${package_version}." >&2
  exit 1
}

actual_vsix_sha="$(shasum -a 256 "${vsix_file}" | awk '{print $1}')"
actual_signature_sha="$(shasum -a 256 "${signature_archive}" | awk '{print $1}')"
actual_public_key_sha="$(shasum -a 256 "${downloaded_public_key}" | awk '{print $1}')"
[[ -f "${pinned_public_key}" ]] || {
  echo "Missing pinned Open VSX public key: ${pinned_public_key}" >&2
  exit 1
}
pinned_public_key_sha="$(shasum -a 256 "${pinned_public_key}" | awk '{print $1}')"

[[ "${actual_vsix_sha}" == "${expected_vsix_sha}" ]] || {
  echo "The VSIX SHA-256 does not match locked package ${package_id}@${package_version}." >&2
  exit 1
}
[[ "${actual_signature_sha}" == "${expected_signature_sha}" ]] || {
  echo "The signature archive does not match locked package ${package_id}@${package_version}." >&2
  exit 1
}
[[ "${actual_public_key_sha}" == "${expected_public_key_sha}" ]] || {
  echo "The downloaded Open VSX public key does not match the approved key." >&2
  exit 1
}
[[ "${pinned_public_key_sha}" == "${expected_public_key_sha}" ]] || {
  echo "The pinned Open VSX public key does not match the release lock." >&2
  exit 1
}
cmp -s "${downloaded_public_key}" "${pinned_public_key}" || {
  echo "The downloaded and pinned Open VSX public keys differ." >&2
  exit 1
}

actual_package_size="$(stat -f '%z' "${vsix_file}")"
[[ "${actual_package_size}" == "${expected_package_size}" ]] || {
  echo "The VSIX size does not match locked package ${package_id}@${package_version}." >&2
  exit 1
}

extension_manifest="$(unzip -p "${vsix_file}" extension/package.json)"
jq -e \
  --arg publisher "${package_publisher}" \
  --arg name "${package_name}" \
  --arg version "${package_version}" \
  --arg engine "${package_engine}" '
    .publisher == $publisher
    and .name == $name
    and .version == $version
    and .engines.vscode == $engine
  ' <<<"${extension_manifest}" >/dev/null || {
  echo "The VSIX manifest is not locked package ${package_id}@${package_version}." >&2
  exit 1
}

verification_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-wrapper-signature.XXXXXX")"
cleanup_verification_root() {
  rm -rf "${verification_root}"
}
trap cleanup_verification_root EXIT INT TERM
unzip -q "${signature_archive}" -d "${verification_root}"

signature_file="${verification_root}/.signature.sig"
signature_manifest="${verification_root}/.signature.manifest"
dummy_p7s="${verification_root}/.signature.p7s"
[[ -f "${signature_file}" && -f "${signature_manifest}" && -f "${dummy_p7s}" ]] || {
  echo "The Open VSX signature archive is incomplete." >&2
  exit 1
}
[[ "$(stat -f '%z' "${signature_file}")" == "64" ]] || {
  echo "The Open VSX Ed25519 signature has an invalid size." >&2
  exit 1
}

if ! openssl pkeyutl \
  -verify \
  -pubin \
  -inkey "${pinned_public_key}" \
  -rawin \
  -in "${vsix_file}" \
  -sigfile "${signature_file}" >/dev/null; then
  echo "The Open VSX Ed25519 signature is invalid." >&2
  exit 1
fi

manifest_sha_base64="$(jq -er '.package.digests.sha256' "${signature_manifest}")"
manifest_sha_hex="$(printf '%s' "${manifest_sha_base64}" | openssl base64 -d -A | xxd -p -c 256)"
manifest_package_size="$(jq -er '.package.size' "${signature_manifest}")"
[[ "${manifest_sha_hex}" == "${expected_vsix_sha}" ]] || {
  echo "The signature manifest identifies a different VSIX digest." >&2
  exit 1
}
[[ "${manifest_package_size}" == "${expected_package_size}" ]] || {
  echo "The signature manifest identifies a different VSIX size." >&2
  exit 1
}

echo "Verified ${package_id}@${package_version}: official stable record, manifest, SHA-256, and Ed25519 signature."
