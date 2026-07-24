#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

app_bundle="${APP_BUNDLE}"
archive_mode="no"
user_home_dir="$(current_user_home)"
dbcode_version="${DBCODE_VERSION}"
dbcode_extension="${user_home_dir}/${DATA_FOLDER_NAME}/extensions/dbcode.dbcode-${dbcode_version}"
runtime_extensions="${user_home_dir}/${DATA_FOLDER_NAME}/extensions"

usage() {
  echo "Usage: ./script/audit_host_size.sh [--app PATH] [--dbcode PATH] [--runtime-extensions PATH] [--archive|--no-archive]" >&2
}

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --app)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      app_bundle="${2}"
      shift 2
      ;;
    --dbcode)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      dbcode_extension="${2}"
      shift 2
      ;;
    --runtime-extensions)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      runtime_extensions="${2}"
      shift 2
      ;;
    --archive)
      archive_mode="yes"
      shift
      ;;
    --no-archive)
      archive_mode="no"
      shift
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

for command_name in du find jq stat tar; do
  require_command "${command_name}"
done

[[ -d "${app_bundle}" ]] || {
  echo "App bundle not found: ${app_bundle}" >&2
  exit 1
}

code_oss_app="${app_bundle}/Contents/Resources/app"
electron_framework="${app_bundle}/Contents/Frameworks/Electron Framework.framework"
built_in_extensions="${code_oss_app}/extensions"
for required_path in "${code_oss_app}" "${electron_framework}" "${built_in_extensions}"; do
  [[ -d "${required_path}" ]] || {
    echo "Expected packaged host path not found: ${required_path}" >&2
    exit 1
  }
done

installed_kib() {
  du -sk "${1}" | awk '{print $1}'
}

app_installed_kib="$(installed_kib "${app_bundle}")"
electron_installed_kib="$(installed_kib "${electron_framework}")"
code_oss_installed_kib="$(installed_kib "${code_oss_app}")"
built_in_installed_kib="$(installed_kib "${built_in_extensions}")"
actual_extension_count="$(find "${built_in_extensions}" -mindepth 2 -maxdepth 2 -name package.json -print | wc -l | tr -d ' ')"

shared_node_modules_present="false"
[[ -d "${built_in_extensions}/node_modules" ]] && shared_node_modules_present="true"

source_map_count=0
source_map_logical_bytes=0
source_map_allocated_kib=0
while IFS= read -r -d '' source_map; do
  source_map_count=$((source_map_count + 1))
  source_map_logical_bytes=$((source_map_logical_bytes + $(stat -f '%z' "${source_map}")))
  source_map_allocated_kib=$((source_map_allocated_kib + $(du -k "${source_map}" | awk '{print $1}')))
done < <(find "${app_bundle}" -type f -name '*.map' -print0)

embedded_dbcode_count=0
while IFS= read -r -d '' manifest; do
  if jq -e '.publisher == "dbcode" and .name == "dbcode"' "${manifest}" >/dev/null 2>&1; then
    embedded_dbcode_count=$((embedded_dbcode_count + 1))
  fi
done < <(find "${built_in_extensions}" -mindepth 2 -maxdepth 2 -name package.json -print0)
external_dbcode_included_in_app="false"
[[ "${embedded_dbcode_count}" -gt 0 ]] && external_dbcode_included_in_app="true"

external_dbcode_path=""
external_dbcode_installed_kib="null"
external_dbcode_logical_bytes="null"
if [[ -d "${dbcode_extension}" ]]; then
  external_dbcode_path="${dbcode_extension}"
  external_dbcode_installed_kib="$(installed_kib "${dbcode_extension}")"
  external_dbcode_logical_bytes=0
  while IFS= read -r -d '' extension_file; do
    external_dbcode_logical_bytes=$((external_dbcode_logical_bytes + $(stat -f '%z' "${extension_file}")))
  done < <(find "${dbcode_extension}" -type f -print0)
fi

external_runtime_extension_count="null"
external_runtime_included_in_app="false"
external_runtime_installed_kib="null"
external_runtime_logical_bytes="null"
if [[ -d "${runtime_extensions}" ]]; then
  external_runtime_extension_count="$(find "${runtime_extensions}" -mindepth 2 -maxdepth 2 -name package.json -type f -print | wc -l | tr -d ' ')"
  external_runtime_installed_kib="$(installed_kib "${runtime_extensions}")"
  external_runtime_logical_bytes=0
  while IFS= read -r -d '' extension_file; do
    external_runtime_logical_bytes=$((external_runtime_logical_bytes + $(stat -f '%z' "${extension_file}")))
  done < <(find "${runtime_extensions}" -type f -print0)
  case "${runtime_extensions}/" in
    "${app_bundle}/"*) external_runtime_included_in_app="true" ;;
  esac
fi
external_runtime_vsix_bytes="$(jq '[.[].package_size] | add' <<<"${RUNTIME_EXTENSION_PACKAGES}")"

archive_bytes="null"
archive_path=""
cleanup_archive() {
  if [[ -n "${archive_path}" && -f "${archive_path}" ]]; then
    rm -f "${archive_path}"
  fi
}
trap cleanup_archive EXIT
if [[ "${archive_mode}" == "yes" ]]; then
  archive_path="$(mktemp "${TMPDIR:-/tmp}/dbcode-wrapper-size.XXXXXX")"
  COPYFILE_DISABLE=1 tar -czf "${archive_path}" -C "$(dirname "${app_bundle}")" "$(basename "${app_bundle}")"
  archive_bytes="$(stat -f '%z' "${archive_path}")"
fi

jq -n \
  --arg app_path "${app_bundle}" \
  --arg external_dbcode_path "${external_dbcode_path}" \
  --arg external_runtime_path "${runtime_extensions}" \
  --arg dbcode_version "${dbcode_version}" \
  --argjson app_installed_kib "${app_installed_kib}" \
  --argjson archive_bytes "${archive_bytes}" \
  --argjson electron_installed_kib "${electron_installed_kib}" \
  --argjson code_oss_installed_kib "${code_oss_installed_kib}" \
  --argjson built_in_installed_kib "${built_in_installed_kib}" \
  --argjson actual_extension_count "${actual_extension_count}" \
  --argjson shared_node_modules_present "${shared_node_modules_present}" \
  --argjson source_map_count "${source_map_count}" \
  --argjson source_map_logical_bytes "${source_map_logical_bytes}" \
  --argjson source_map_allocated_kib "${source_map_allocated_kib}" \
  --argjson external_dbcode_included_in_app "${external_dbcode_included_in_app}" \
  --argjson external_dbcode_installed_kib "${external_dbcode_installed_kib}" \
  --argjson external_dbcode_logical_bytes "${external_dbcode_logical_bytes}" \
  --argjson external_dbcode_vsix_bytes "${DBCODE_PACKAGE_SIZE}" \
  --argjson external_runtime_extension_count "${external_runtime_extension_count}" \
  --argjson external_runtime_included_in_app "${external_runtime_included_in_app}" \
  --argjson external_runtime_installed_kib "${external_runtime_installed_kib}" \
  --argjson external_runtime_logical_bytes "${external_runtime_logical_bytes}" \
  --argjson external_runtime_vsix_bytes "${external_runtime_vsix_bytes}" \
  '{
    schema_version: 1,
    app_path: $app_path,
    signed_app: {
      installed_kib: $app_installed_kib,
      indicative_archive_bytes: $archive_bytes
    },
    electron_framework: {
      installed_kib: $electron_installed_kib
    },
    code_oss_application: {
      installed_kib: $code_oss_installed_kib
    },
    built_in_extensions: {
      actual_extension_count: $actual_extension_count,
      shared_node_modules_present: $shared_node_modules_present,
      installed_kib: $built_in_installed_kib
    },
    source_maps: {
      file_count: $source_map_count,
      logical_bytes: $source_map_logical_bytes,
      allocated_kib: $source_map_allocated_kib
    },
    external_dbcode: {
      path: (if $external_dbcode_path == "" then null else $external_dbcode_path end),
      version: $dbcode_version,
      included_in_app: $external_dbcode_included_in_app,
      installed_kib: $external_dbcode_installed_kib,
      logical_bytes: $external_dbcode_logical_bytes,
      vsix_bytes: $external_dbcode_vsix_bytes
    },
    external_runtime: {
      path: (if $external_runtime_extension_count == null then null else $external_runtime_path end),
      extension_count: $external_runtime_extension_count,
      included_in_app: $external_runtime_included_in_app,
      installed_kib: $external_runtime_installed_kib,
      logical_bytes: $external_runtime_logical_bytes,
      vsix_bytes: $external_runtime_vsix_bytes
    }
  }'
