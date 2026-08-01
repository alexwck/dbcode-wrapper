#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/profile_paths.sh"
source "${REPO_ROOT}/script/lib/profile_settings.sh"
source "${REPO_ROOT}/script/lib/generated_workspace.sh"

profile_name="default"
allow_candidate="no"
while [[ $# -gt 0 ]]; do
  case "${1}" in
    --profile)
      [[ $# -ge 2 ]] || { echo "--profile requires default or qa." >&2; exit 2; }
      profile_name="$2"
      shift
      ;;
    --allow-candidate)
      allow_candidate="yes"
      ;;
    *)
      echo "Usage: ./script/prepare_dbcode.sh [--profile default|qa] [--allow-candidate]" >&2
      exit 2
      ;;
  esac
  shift
done

feature_policy_file="${REPO_ROOT}/host/dbcode-feature-policy.json"
approval_status="$(jq -er '.approval_status' "${feature_policy_file}")"
case "${approval_status}" in
  approved) ;;
  candidate)
    [[ "${allow_candidate}" == "yes" ]] || {
      echo "The locked DBCode runtime is still a candidate. Use the explicit proof or rendered QA workflow until it is approved." >&2
      exit 1
    }
    ;;
  *)
    echo "Unsupported DBCode release approval status: ${approval_status}" >&2
    exit 1
    ;;
esac

managed_settings="${REPO_ROOT}/host/profile/settings.json"
runtime_cache_root="$(
  generated_workspace_resolve_path \
    "build-cache" \
    "${CACHE_ROOT}/runtime-extensions"
)"

if [[ ! -d "${APP_BUNDLE}" ]]; then
  echo "Build the host first with ./script/build_host.sh" >&2
  exit 1
fi

for required_command in chmod cmp curl find grep jq mv shasum sort; do
  require_command "${required_command}"
done

resolve_profile_paths "${profile_name}" || {
  echo "DBCode can only be prepared in the default or generated QA profile." >&2
  exit 2
}
profile_root="${PROFILE_STATE_ROOT}"
user_data_root="${PROFILE_USER_DATA_ROOT}"
extensions_root="${PROFILE_EXTENSIONS_ROOT}"
shared_data_root="${PROFILE_SHARED_DATA_ROOT}"
profile_cache_root="${PROFILE_CACHE_ROOT}"
profile_log_root="${PROFILE_LOG_ROOT}"
profile_layout_assert_mutable state user_data extensions shared_data cache logs

ensure_private_directory() {
  local private_directory="$1"
  if [[ -L "${private_directory}" ]]; then
    echo "Refusing a symlinked private runtime directory: ${private_directory}" >&2
    exit 1
  fi
  mkdir -p "${private_directory}"
  chmod "${PROFILE_DIRECTORY_MODE}" "${private_directory}"
}

for private_directory in \
  "${profile_root}" \
  "${user_data_root}" \
  "${user_data_root}/User" \
  "${extensions_root}" \
  "${shared_data_root}" \
  "${profile_cache_root}" \
  "${profile_log_root}" \
  "${runtime_cache_root}"; do
  ensure_private_directory "${private_directory}"
done

settings_file="${user_data_root}/User/settings.json"
apply_managed_profile_settings "${settings_file}" "${managed_settings}"

package_entries() {
  jq -r '
    .[] |
    [.id, .id, .version, .registry_api_url, .download_url,
     .signature_url, .sha256_url, .public_key_url] | @tsv
  ' <<<"${RUNTIME_EXTENSION_PACKAGES}"
}

download_file() {
  local label="$1"
  local url="$2"
  local destination="$3"
  local partial_file="${destination}.part"

  if [[ -f "${destination}" && ! -L "${destination}" ]]; then
    return
  fi
  if [[ -L "${destination}" ]]; then
    echo "Refusing a symlinked runtime cache file: ${destination}" >&2
    exit 1
  fi

  rm -f "${partial_file}"
  echo "Downloading ${label} from its pinned Open VSX URL..."
  curl \
    --fail \
    --location \
    --proto '=https' \
    --retry 3 \
    --show-error \
    --silent \
    --tlsv1.2 \
    --output "${partial_file}" \
    "${url}"
  chmod "${PROFILE_FILE_MODE}" "${partial_file}"
  mv "${partial_file}" "${destination}"
}

while IFS=$'\t' read -r package_id extension_id extension_version registry_api_url download_url signature_url sha256_url public_key_url <&3; do
  package_root="${runtime_cache_root}/${extension_id}/${extension_version}"
  ensure_private_directory "${runtime_cache_root}/${extension_id}"
  ensure_private_directory "${package_root}"

  registry_record="${package_root}/registry.json"
  vsix_file="${package_root}/package.vsix"
  signature_archive="${package_root}/signature.sigzip"
  sha256_record="${package_root}/package.sha256"
  downloaded_public_key="${package_root}/openvsx-public-key.pem"

  download_file "${extension_id} registry record" "${registry_api_url}" "${registry_record}"
  download_file "${extension_id} VSIX" "${download_url}" "${vsix_file}"
  download_file "${extension_id} signature archive" "${signature_url}" "${signature_archive}"
  download_file "${extension_id} SHA-256 record" "${sha256_url}" "${sha256_record}"
  download_file "Open VSX public key" "${public_key_url}" "${downloaded_public_key}"

  "${REPO_ROOT}/script/verify_openvsx_package.sh" \
    "${package_id}" \
    "${package_root}"
done 3< <(package_entries)

host_cli="${APP_BUNDLE}/Contents/Resources/app/bin/${APPLICATION_NAME}"
[[ -x "${host_cli}" ]] || {
  echo "The standalone host CLI is missing: ${host_cli}" >&2
  exit 1
}

cli_profile_args=(
  --user-data-dir "${user_data_root}"
  --extensions-dir "${extensions_root}"
  --shared-data-dir "${shared_data_root}"
  --disable-updates
)

list_installed_extensions() {
  "${host_cli}" "${cli_profile_args[@]}" --list-extensions --show-versions | LC_ALL=C sort
}

is_obsolete_extension_manifest() {
  local manifest_path="$1"
  local directory_name
  directory_name="$(basename "$(dirname "${manifest_path}")")"

  [[ -f "${extensions_root}/.obsolete" ]] &&
    jq -e --arg directory_name "${directory_name}" '.[$directory_name] == true' \
      "${extensions_root}/.obsolete" >/dev/null 2>&1
}

active_extension_manifests() {
  local manifest_path
  while IFS= read -r manifest_path; do
    if ! is_obsolete_extension_manifest "${manifest_path}"; then
      printf '%s\n' "${manifest_path}"
    fi
  done < <(find "${extensions_root}" -mindepth 2 -maxdepth 2 -name package.json -type f -print)
}

expected_extensions="$(jq -r '
  .[] | .id + "@" + .version
' <<<"${RUNTIME_EXTENSION_PACKAGES}" | LC_ALL=C sort)"
expected_extension_ids="$(jq -r '
  .[].id
' <<<"${RUNTIME_EXTENSION_PACKAGES}" | LC_ALL=C sort)"
excluded_optional_extension_ids="$(jq -r '.excluded_optional_runtime_members[].id' "${feature_policy_file}" | LC_ALL=C sort)"

installed_extensions="$(list_installed_extensions)"
while IFS= read -r installed_extension <&3; do
  [[ -z "${installed_extension}" ]] && continue
  installed_id="${installed_extension%@*}"
  if ! grep -Fxq "${installed_id}" <<<"${expected_extension_ids}"; then
    if grep -Fxq "${installed_id}" <<<"${excluded_optional_extension_ids}"; then
      echo "Removing excluded optional runtime member ${installed_extension}..."
      "${host_cli}" "${cli_profile_args[@]}" --uninstall-extension "${installed_id}"
      continue
    fi
    echo "The private extension directory contains an unrelated extension: ${installed_extension}" >&2
    exit 1
  fi
  if ! grep -Fxq "${installed_extension}" <<<"${expected_extensions}"; then
    echo "Removing superseded locked runtime extension ${installed_extension}..."
    "${host_cli}" "${cli_profile_args[@]}" --uninstall-extension "${installed_id}"
  fi
done 3<<<"${installed_extensions}"

while IFS=$'\t' read -r _package_id extension_id extension_version _registry_api_url _download_url _signature_url _sha256_url _public_key_url <&3; do
  installed_extensions="$(list_installed_extensions)"
  if ! grep -Fxq "${extension_id}@${extension_version}" <<<"${installed_extensions}"; then
    vsix_file="${runtime_cache_root}/${extension_id}/${extension_version}/package.vsix"
    echo "Installing verified ${extension_id}@${extension_version} into the private profile..."
    "${host_cli}" \
      "${cli_profile_args[@]}" \
      --install-extension "${vsix_file}" \
      --do-not-include-pack-dependencies \
      --force
  fi
done 3< <(package_entries)

installed_extensions="$(list_installed_extensions)"
[[ "${installed_extensions}" == "${expected_extensions}" ]] || {
  echo "The private profile does not contain the exact locked runtime-extension release set." >&2
  printf 'Expected extensions:\n%s\nInstalled extensions:\n%s\n' "${expected_extensions}" "${installed_extensions}" >&2
  exit 1
}

installed_manifest_inventory="$({
  while IFS= read -r installed_manifest; do
    jq -r '.publisher + "." + .name + "@" + .version' "${installed_manifest}"
  done < <(active_extension_manifests)
} | LC_ALL=C sort)"
[[ "${installed_manifest_inventory}" == "${expected_extensions}" ]] || {
  echo "The private extension root contains an unexpected active package directory." >&2
  printf 'Expected manifests:\n%s\nInstalled manifests:\n%s\n' "${expected_extensions}" "${installed_manifest_inventory}" >&2
  exit 1
}

dbcode_id="${DBCODE_ID}"
installed_dbcode_manifest=""
while IFS= read -r installed_manifest; do
  if jq -e \
    --arg extension_id "${dbcode_id}" \
    --arg extension_version "${DBCODE_VERSION}" \
    '(.publisher + "." + .name) == $extension_id and .version == $extension_version' \
    "${installed_manifest}" >/dev/null; then
    installed_dbcode_manifest="${installed_manifest}"
    break
  fi
done < <(active_extension_manifests)
[[ -n "${installed_dbcode_manifest}" ]] || {
  echo "The installed DBCode package manifest is missing from ${extensions_root}." >&2
  exit 1
}
"${REPO_ROOT}/script/test_dbcode_feature_contract.sh" --manifest "${installed_dbcode_manifest}"

echo "Prepared the exact ${approval_status} DBCode and Python-notebook release set in private ${profile_name} profile ${profile_root}"
