#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

runtime_extension_packages="$(jq -c '.packages' <<<"${RELEASE_EXTENSION_SPEC}")"
if [[ $# -ne 1 ]]; then
  echo "Usage: ./script/generate_runtime_setup_manifest.sh <output-json>" >&2
  exit 2
fi

output_file="$1"
[[ ! -L "${output_file}" ]] || {
  echo "The focused runtime setup manifest must not replace a symbolic link." >&2
  exit 1
}
output_parent="$(dirname "${output_file}")"
mkdir -p "${output_parent}"
[[ -d "${output_parent}" && ! -L "${output_parent}" ]] || {
  echo "The focused runtime setup manifest parent is unsafe." >&2
  exit 1
}

packages="$(
  jq -c '
    map({
      role,
      namespace,
      name,
      id,
      publisher,
      version,
      engine,
      target_platform,
      published_at,
      verified_publisher,
      pre_release,
      deprecated,
      registry_api_url,
      download_url,
      signature_url,
      sha256_url,
      public_key_id,
      public_key_url,
      sha256,
      signature_archive_sha256,
      public_key_sha256,
      package_size
    })
  ' <<<"${runtime_extension_packages}"
)"

public_keys='[]'
while IFS=$'\t' read -r public_key_id public_key_sha256; do
  public_key_file="${REPO_ROOT}/host/keys/openvsx-${public_key_id}.pem"
  [[ -f "${public_key_file}" && ! -L "${public_key_file}" ]] || {
    echo "The pinned Open VSX public key is missing or unsafe: ${public_key_file}" >&2
    exit 1
  }
  actual_public_key_sha256="$(shasum -a 256 "${public_key_file}" | awk '{print $1}')"
  [[ "${actual_public_key_sha256}" == "${public_key_sha256}" ]] || {
    echo "The pinned Open VSX public key does not match the Release Specification." >&2
    exit 1
  }
  public_keys="$(
    jq -c \
      --arg id "${public_key_id}" \
      --arg sha256 "${public_key_sha256}" \
      --rawfile pem "${public_key_file}" \
      '. + [{id: $id, sha256: $sha256, pem: $pem}]' \
      <<<"${public_keys}"
  )"
done < <(
  jq -r \
    'map([.public_key_id, .public_key_sha256] | @tsv) | unique | sort | .[]' \
    <<<"${runtime_extension_packages}"
)

temporary_file="$(mktemp "${output_parent}/.runtime-extension-set.XXXXXX")"
cleanup() {
  rm -f "${temporary_file}"
}
trap cleanup EXIT INT TERM

jq -n \
  --arg code_oss_version "${CODE_OSS_VERSION}" \
  --arg application_name "${APPLICATION_NAME}" \
  --argjson packages "${packages}" \
  --argjson public_keys "${public_keys}" '
    {
      schema_version: 1,
      setup: "focused-pinned-official-sources",
      code_oss_version: $code_oss_version,
      application_name: $application_name,
      packages: $packages,
      public_keys: $public_keys
    }
  ' > "${temporary_file}"

jq -e '
  .schema_version == 1
  and .setup == "focused-pinned-official-sources"
  and (.packages | length) > 0
  and ([.packages[].id] | length) == ([.packages[].id] | unique | length)
  and ([.public_keys[].id] | length) == ([.public_keys[].id] | unique | length)
  and all(.packages[];
    .verified_publisher == true
    and .pre_release == false
    and .deprecated == false
    and (.sha256 | test("^[0-9a-f]{64}$"))
    and (.signature_archive_sha256 | test("^[0-9a-f]{64}$"))
    and (.public_key_sha256 | test("^[0-9a-f]{64}$"))
  )
' "${temporary_file}" >/dev/null || {
  echo "The generated focused runtime setup manifest is invalid." >&2
  exit 1
}

chmod 644 "${temporary_file}"
mv "${temporary_file}" "${output_file}"
trap - EXIT INT TERM

echo "Focused runtime setup manifest: ${output_file}"
