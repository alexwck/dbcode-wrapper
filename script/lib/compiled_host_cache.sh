#!/usr/bin/env bash

set -euo pipefail

if [[ "${DBCODE_WRAPPER_COMPILED_HOST_CACHE_LOADED:-0}" == "1" ]]; then
  return 0
fi
DBCODE_WRAPPER_COMPILED_HOST_CACHE_LOADED=1

compiled_host_cache_script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${compiled_host_cache_script_root}/lib/artifact_digest.sh"
source "${compiled_host_cache_script_root}/lib/patch_plan.sh"
source "${compiled_host_cache_script_root}/lib/release_specification.sh"

compiled_host_sha256_text() {
  shasum -a 256 | awk '{print $1}'
}

compiled_host_file_mode() {
  local file_path="$1"

  if [[ -x "${file_path}" ]]; then
    printf '755\n'
  else
    printf '644\n'
  fi
}

compiled_host_digest_source_files() {
  local source_root="$1"
  shift

  [[ "${source_root}" == /* && -d "${source_root}" && ! -L "${source_root}" ]] || {
    echo "Compiled-host source root must be an absolute real directory: ${source_root}" >&2
    return 1
  }
  (( "$#" > 0 )) || {
    echo "Compiled-host digest needs at least one source path." >&2
    return 1
  }

  (
    cd "${source_root}"

    local relative_path item_path item_digest item_mode link_target
    for relative_path in "$@"; do
      case "${relative_path}" in
        ""|/*|..|../*|*/../*|*/..)
          echo "Unsafe compiled-host source path: ${relative_path}" >&2
          return 1
          ;;
      esac
      [[ -e "${relative_path}" && ! -L "${relative_path}" ]] || {
        echo "Compiled-host source path is missing or symlinked: ${relative_path}" >&2
        return 1
      }

      if [[ -f "${relative_path}" ]]; then
        item_digest="$(shasum -a 256 "${relative_path}" | awk '{print $1}')"
        item_mode="$(compiled_host_file_mode "${relative_path}")"
        printf 'file\t%s\t%s\t%s\n' "${relative_path}" "${item_mode}" "${item_digest}"
        continue
      fi

      [[ -d "${relative_path}" ]] || {
        echo "Unsupported compiled-host source path: ${relative_path}" >&2
        return 1
      }

      while IFS= read -r -d '' item_path; do
        if [[ -L "${item_path}" ]]; then
          link_target="$(readlink "${item_path}")"
          printf 'link\t%s\t%s\n' "${item_path}" "${link_target}"
        elif [[ -f "${item_path}" ]]; then
          item_digest="$(shasum -a 256 "${item_path}" | awk '{print $1}')"
          item_mode="$(compiled_host_file_mode "${item_path}")"
          printf 'file\t%s\t%s\t%s\n' "${item_path}" "${item_mode}" "${item_digest}"
        fi
      done < <(
        find "${relative_path}" \( -type f -o -type l \) -print0 |
          LC_ALL=C sort -z
      )
    done
  ) | LC_ALL=C sort | compiled_host_sha256_text
}

compiled_host_patch_digest() {
  local source_root="$1"

  {
    patch_plan_compiled_host_projection \
      "${source_root}/host/patches/patch-plan.json"
    compiled_host_digest_source_files \
      "${source_root}" \
      "host/patches/vscodium" \
      "host/patches/code-oss" \
      "host/code-oss-overlay"
  } | compiled_host_sha256_text
}

compiled_host_implementation_digest() {
  local source_root="$1"
  local -a implementation_paths=(
    "host/icon"
    "script/bootstrap_toolchain.sh"
    "script/prepare_source.sh"
    "script/build_icon.sh"
    "script/build_icns.py"
    "script/materialize_code_oss_overlay.sh"
    "script/lib/artifact_digest.sh"
    "script/lib/compiled_host_cache.sh"
    "script/lib/generated_workspace.sh"
    "script/lib/host_config.sh"
    "script/lib/patch_plan.sh"
    "script/lib/source_cache.sh"
  )

  if [[ -f "${source_root}/script/compile_host.sh" ]]; then
    implementation_paths+=("script/compile_host.sh")
  fi

  compiled_host_digest_source_files "${source_root}" "${implementation_paths[@]}"
}

compiled_host_release_specification_digest() {
  local source_root="$1"
  local release_specification_module="${source_root}/script/lib/release_specification.sh"
  local records_module="${source_root}/script/lib/release_specification_records.jq"

  [[ -f "${release_specification_module}" && ! -L "${release_specification_module}" &&
    -f "${records_module}" && ! -L "${records_module}" ]] || {
    echo "Compiled-host Release Specification module is missing or symlinked." >&2
    return 1
  }

  {
    bash -c '
      set -euo pipefail
      source "$1"
      declare -f \
        release_specification_validate \
        release_specification_module_root \
        release_specification_records_module \
        release_specification_require_records_module \
        release_specification_record
    ' _ "${release_specification_module}"
    compiled_host_digest_source_files \
      "${source_root}" \
      "script/lib/release_specification_records.jq"
  } | compiled_host_sha256_text
}

compiled_host_slimming_digest() {
  local source_root="$1"
  local slimming_policy="${source_root}/host/slimming-policy.json"

  [[ -f "${slimming_policy}" && ! -L "${slimming_policy}" ]] || {
    echo "Compiled-host slimming policy is missing or symlinked: ${slimming_policy}" >&2
    return 1
  }

  jq -S -c '{
    schema_version,
    ship_source_maps: .build.ship_source_maps,
    built_in_extensions: {
      mode: .build.built_in_extensions.mode,
      allowlist: [.build.built_in_extensions.allowlist[].name]
    }
  }' "${slimming_policy}" |
    compiled_host_sha256_text
}

compiled_host_input_payload() {
  local release_lock="$1"
  local source_root="$2"
  local release_record patch_sha implementation_sha release_specification_sha slimming_sha

  release_record="$(release_specification_record compiled-host "${release_lock}")"
  patch_sha="$(compiled_host_patch_digest "${source_root}")"
  implementation_sha="$(compiled_host_implementation_digest "${source_root}")"
  release_specification_sha="$(
    compiled_host_release_specification_digest "${source_root}"
  )"
  slimming_sha="$(compiled_host_slimming_digest "${source_root}")"

  jq -S -c -n \
    --argjson release "${release_record}" \
    --arg patch_sha256 "${patch_sha}" \
    --arg implementation_sha256 "${implementation_sha}" \
    --arg release_specification_sha256 "${release_specification_sha}" \
    --arg slimming_sha256 "${slimming_sha}" \
    '{
      schema_version: 2,
      release: $release,
      source: {
        patches_sha256: $patch_sha256,
        implementation_sha256: $implementation_sha256,
        release_specification_sha256: $release_specification_sha256,
        slimming_sha256: $slimming_sha256
      }
    }'
}

compiled_host_input_id() {
  local release_lock="$1"
  local source_root="$2"
  local input_sha

  input_sha="$(
    compiled_host_input_payload "${release_lock}" "${source_root}" |
      compiled_host_sha256_text
  )"
  printf 'compiled-host-%s\n' "${input_sha}"
}

compiled_host_cache_assert_identity() {
  local input_id="$1"
  local app_name="$2"

  [[ "${input_id}" =~ ^compiled-host-[0-9a-f]{64}$ ]] || {
    echo "Invalid compiled-host input ID: ${input_id}" >&2
    return 1
  }
  [[ "${app_name}" =~ ^[A-Za-z0-9][A-Za-z0-9._\ -]*$ ]] || {
    echo "Unsafe compiled-host app name: ${app_name}" >&2
    return 1
  }
}

compiled_host_cache_root_validate() {
  local cache_root="$1"

  [[ "${cache_root}" == /* && "${cache_root}" != "/" ]] || {
    echo "Compiled-host cache root must be a narrow absolute path: ${cache_root}" >&2
    return 1
  }
  case "${cache_root}" in
    *"/../"*|*/..)
      echo "Compiled-host cache root contains parent traversal: ${cache_root}" >&2
      return 1
      ;;
  esac
  [[ ! -L "${cache_root}" ]] || {
    echo "Compiled-host cache root must not be a symbolic link: ${cache_root}" >&2
    return 1
  }
}

compiled_host_cache_entry_path() {
  local cache_root="$1"
  local input_id="$2"
  local app_name="$3"

  compiled_host_cache_root_validate "${cache_root}"
  compiled_host_cache_assert_identity "${input_id}" "${app_name}"
  printf '%s/compiled-hosts/%s\n' "${cache_root%/}" "${input_id}"
}

compiled_host_cache_resolve() {
  local cache_root="$1"
  local input_id="$2"
  local app_name="$3"
  local entry_path app_path receipt_path expected_digest actual_digest

  entry_path="$(compiled_host_cache_entry_path "${cache_root}" "${input_id}" "${app_name}")"
  app_path="${entry_path}/${app_name}.app"
  receipt_path="${entry_path}/receipt.json"

  [[ -d "${entry_path}" && ! -L "${entry_path}" ]] || return 1
  [[ -d "${app_path}" && ! -L "${app_path}" ]] || return 1
  [[ -f "${receipt_path}" && ! -L "${receipt_path}" ]] || return 1

  jq -e \
    --arg input_id "${input_id}" \
    --arg app_name "${app_name}" \
    '
      .schema_version == 2
      and .compiled_host_input_id == $input_id
      and .app_name == $app_name
      and (.source_revision | type == "string" and test("^[0-9a-f]{40}$"))
      and .app_digest_algorithm == "sha256-files-modes-links-v1"
      and (.app_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
      and .compilation_environment.schema_version == 1
      and (.compilation_environment.node | type == "string" and length > 0)
      and (.compilation_environment.npm | type == "string" and length > 0)
      and (.compilation_environment.python | type == "string" and length > 0)
      and (.compilation_environment.clang | type == "string" and length > 0)
      and (.compilation_environment.macos_sdk | type == "string" and length > 0)
      and (.compilation_environment.macos | type == "string" and length > 0)
    ' "${receipt_path}" >/dev/null || return 1

  expected_digest="$(jq -er '.app_sha256' "${receipt_path}")"
  actual_digest="$(artifact_digest_with_modes "${app_path}")"
  [[ "${actual_digest}" == "${expected_digest}" ]] || return 1

  printf '%s\n' "${app_path}"
}

compiled_host_cache_publish() {
  local cache_root="$1"
  local input_id="$2"
  local app_name="$3"
  local source_app="$4"
  local source_revision="$5"
  local environment_record="$6"
  local entry_path compiled_root rejected_root rejected_path stage_path stage_app app_digest
  local compilation_environment

  compiled_host_cache_root_validate "${cache_root}"
  compiled_host_cache_assert_identity "${input_id}" "${app_name}"
  [[ -d "${source_app}" && ! -L "${source_app}" ]] || {
    echo "Compiled-host application is missing or symlinked: ${source_app}" >&2
    return 1
  }
  [[ "${source_revision}" =~ ^[0-9a-f]{40}$ ]] || {
    echo "Invalid compiled-host source revision: ${source_revision}" >&2
    return 1
  }
  [[ -f "${environment_record}" && ! -L "${environment_record}" ]] || {
    echo "Compiled-host environment record is missing or symlinked: ${environment_record}" >&2
    return 1
  }
  compilation_environment="$(jq -c . "${environment_record}")"
  jq -e '
    .schema_version == 1
    and (.node | type == "string" and length > 0)
    and (.npm | type == "string" and length > 0)
    and (.python | type == "string" and length > 0)
    and (.clang | type == "string" and length > 0)
    and (.macos_sdk | type == "string" and length > 0)
    and (.macos | type == "string" and length > 0)
  ' <<<"${compilation_environment}" >/dev/null || {
    echo "Compiled-host environment record is invalid." >&2
    return 1
  }

  entry_path="$(compiled_host_cache_entry_path "${cache_root}" "${input_id}" "${app_name}")"
  compiled_root="$(dirname "${entry_path}")"
  mkdir -p "${compiled_root}"
  [[ -d "${compiled_root}" && ! -L "${compiled_root}" ]] || {
    echo "Compiled-host cache directory is unsafe: ${compiled_root}" >&2
    return 1
  }

  if compiled_host_cache_resolve "${cache_root}" "${input_id}" "${app_name}" >/dev/null 2>&1; then
    return 0
  fi

  if [[ -e "${entry_path}" || -L "${entry_path}" ]]; then
    [[ -d "${entry_path}" && ! -L "${entry_path}" ]] || {
      echo "Refusing unsafe compiled-host cache entry: ${entry_path}" >&2
      return 1
    }
    rejected_root="${compiled_root}/rejected"
    mkdir -p "${rejected_root}"
    [[ -d "${rejected_root}" && ! -L "${rejected_root}" ]] || {
      echo "Compiled-host rejected-cache directory is unsafe: ${rejected_root}" >&2
      return 1
    }
    rejected_path="$(
      printf '%s/%s-%s-%s\n' \
        "${rejected_root}" \
        "${input_id}" \
        "$(date -u '+%Y%m%dT%H%M%SZ')" \
        "$$"
    )"
    mv "${entry_path}" "${rejected_path}"
  fi

  stage_path="$(mktemp -d "${compiled_root}/.${input_id}.XXXXXX")"
  stage_app="${stage_path}/${app_name}.app"
  if ! ditto "${source_app}" "${stage_app}"; then
    rm -rf "${stage_path}"
    return 1
  fi

  app_digest="$(artifact_digest_with_modes "${stage_app}")"
  jq -S -n \
    --arg input_id "${input_id}" \
    --arg app_name "${app_name}" \
    --arg source_revision "${source_revision}" \
    --arg app_sha256 "${app_digest}" \
    --argjson compilation_environment "${compilation_environment}" \
    '{
      schema_version: 2,
      compiled_host_input_id: $input_id,
      app_name: $app_name,
      source_revision: $source_revision,
      app_digest_algorithm: "sha256-files-modes-links-v1",
      app_sha256: $app_sha256,
      compilation_environment: $compilation_environment
    }' > "${stage_path}/receipt.json"

  if ! mv "${stage_path}" "${entry_path}"; then
    rm -rf "${stage_path}"
    return 1
  fi

  compiled_host_cache_resolve \
    "${cache_root}" \
    "${input_id}" \
    "${app_name}" >/dev/null
}
