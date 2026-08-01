#!/usr/bin/env bash

set -euo pipefail

host_slimming_error() {
  echo "$1" >&2
}

validate_packaged_host_slimming() {
  [[ $# -eq 2 ]] || {
    host_slimming_error "Packaged-host slimming checks require an app bundle and policy file."
    return 2
  }

  local app_bundle="$1"
  local policy_file="$2"
  local product_json="${app_bundle}/Contents/Resources/app/product.json"
  local extensions_root="${app_bundle}/Contents/Resources/app/extensions"
  [[ -d "${app_bundle}" && ! -L "${app_bundle}" && \
    -f "${policy_file}" && ! -L "${policy_file}" && \
    -f "${product_json}" && ! -L "${product_json}" && \
    -d "${extensions_root}" && ! -L "${extensions_root}" ]] || {
    host_slimming_error "Packaged-host slimming inputs are missing, linked, or unsafe."
    return 1
  }

  local installed_app_kib installed_app_max_kib
  installed_app_kib="$(du -sk "${app_bundle}" | awk '{print $1}')"
  installed_app_max_kib="$(jq -er '.goals.installed_app_max_kib' "${policy_file}")"
  [[ "${installed_app_kib}" =~ ^[0-9]+$ && "${installed_app_max_kib}" =~ ^[0-9]+$ && \
    "${installed_app_kib}" -le "${installed_app_max_kib}" ]] || {
    host_slimming_error "The packaged app is larger than the reviewed installed-size limit: ${installed_app_kib} KiB."
    return 1
  }

  local source_map_count
  source_map_count="$(find "${app_bundle}" -type f -name '*.map' -print | wc -l | tr -d ' ')"
  [[ "${source_map_count}" -eq 0 ]] || {
    host_slimming_error "The packaged app contains ${source_map_count} source-map files."
    return 1
  }

  local expected_built_in_inventory actual_built_in_inventory
  expected_built_in_inventory="$(
    jq -r \
      '([.build.built_in_extensions.allowlist[].name] + [.build.built_in_extensions.first_party[].name]) | sort[]' \
      "${policy_file}"
  )"
  actual_built_in_inventory="$(
    find "${extensions_root}" -mindepth 1 -maxdepth 1 -print |
      sed 's#.*/##' |
      LC_ALL=C sort
  )"
  [[ "${actual_built_in_inventory}" == "${expected_built_in_inventory}" ]] || {
    host_slimming_error "The packaged built-in extension inventory does not match the reviewed allowlist."
    echo "Expected:" >&2
    printf '%s\n' "${expected_built_in_inventory}" >&2
    echo "Actual:" >&2
    printf '%s\n' "${actual_built_in_inventory}" >&2
    return 1
  }

  local extension_name extension_root extension_manifest
  while IFS= read -r extension_name; do
    extension_root="${extensions_root}/${extension_name}"
    [[ -d "${extension_root}" && ! -L "${extension_root}" ]] || {
      host_slimming_error "The packaged built-in extension is missing, linked, or unsafe: ${extension_name}"
      return 1
    }
    extension_manifest="${extension_root}/package.json"
    [[ -f "${extension_manifest}" && ! -L "${extension_manifest}" ]] || {
      host_slimming_error "The packaged built-in extension is missing a plain manifest: ${extension_name}"
      return 1
    }
    jq -e 'type == "object"' "${extension_manifest}" >/dev/null || {
      host_slimming_error "The packaged built-in extension has an invalid manifest: ${extension_name}"
      return 1
    }
    if jq -e '.publisher == "dbcode" and .name == "dbcode"' "${extension_manifest}" >/dev/null; then
      host_slimming_error "DBCode must remain external to the packaged app."
      return 1
    fi
  done <<<"${actual_built_in_inventory}"

  jq -e '.builtInExtensions | type == "array" and length == 0' "${product_json}" >/dev/null || {
    host_slimming_error "The packaged product must not advertise removed marketplace built-ins."
    return 1
  }
}
