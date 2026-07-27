#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: ./script/generate_profile_identity.sh <output-json>" >&2
  exit 2
fi

output_file="$1"
[[ ! -L "${output_file}" && ( ! -e "${output_file}" || -f "${output_file}" ) ]] || {
  echo "The generated profile identity output must be a regular file path." >&2
  exit 1
}
output_parent="$(dirname "${output_file}")"
mkdir -p "${output_parent}"
[[ -d "${output_parent}" && ! -L "${output_parent}" ]] || {
  echo "The generated profile identity parent is unsafe." >&2
  exit 1
}

temporary_file="$(mktemp "${output_parent}/.profile-identity.XXXXXX")"
cleanup() {
  rm -f "${temporary_file}"
}
trap cleanup EXIT INT TERM

jq -S '
  {
    schema_version,
    target,
    profile_schema_version,
    product: {
      app_name: .product.app_name,
      application_name: .product.application_name,
      bundle_identifier: .product.bundle_identifier,
      data_folder_name: .product.data_folder_name,
      user_data_folder_name: .product.user_data_folder_name,
      extensions_folder_name: .product.extensions_folder_name,
      shared_data_folder_name: .product.shared_data_folder_name,
      backup_folder_name: .product.backup_folder_name,
      storage_namespace: .product.storage_namespace,
      query_folder_name: .product.query_folder_name
    }
  }
' <<<"${RELEASE_PROFILE_SPEC}" > "${temporary_file}"

jq -e '
  (keys | sort) == ["product", "profile_schema_version", "schema_version", "target"]
  and .schema_version == 1
  and .target == {platform: "darwin", architecture: "arm64"}
  and (.profile_schema_version | type == "number" and . > 0 and floor == .)
  and (.product | keys | sort) == [
    "app_name",
    "application_name",
    "backup_folder_name",
    "bundle_identifier",
    "data_folder_name",
    "extensions_folder_name",
    "query_folder_name",
    "shared_data_folder_name",
    "storage_namespace",
    "user_data_folder_name"
  ]
  and all(.product[]; type == "string" and length > 0)
' "${temporary_file}" >/dev/null || {
  echo "The generated profile identity is invalid." >&2
  exit 1
}

chmod 644 "${temporary_file}"
mv "${temporary_file}" "${output_file}"
trap - EXIT INT TERM

echo "Generated profile identity: ${output_file}"
