#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/artifact_digest.sh"
source "${REPO_ROOT}/script/lib/approved_release_set.sh"
source "${REPO_ROOT}/script/lib/proof_state.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  ./script/controlled_upgrade.sh prepare-set --role current|candidate --app PATH --manifest FILE \
    --release-lock FILE --user-data DIR --extensions DIR --shared-data DIR \
    [--proof FILE] [--release-id ID] --output-dir DIR
  ./script/controlled_upgrade.sh matrix --current-set FILE --candidate-set FILE --output FILE
  ./script/controlled_upgrade.sh promote --current-set FILE --candidate-set FILE --matrix FILE \
    --layout FILE --confirm-release-set ID
  ./script/controlled_upgrade.sh health --layout FILE --confirm-release-set ID
  ./script/controlled_upgrade.sh rollback --layout FILE --confirm-release-set ID
EOF
  exit 2
}

canonical_existing_path() {
  local path_value="$1"
  local path_parent path_name
  path_parent="$(cd "$(dirname "${path_value}")" && pwd -P)"
  path_name="$(basename "${path_value}")"
  printf '%s/%s\n' "${path_parent}" "${path_name}"
}

require_plain_directory() {
  local path_value="$1"
  local label="$2"
  [[ -d "${path_value}" && ! -L "${path_value}" ]] || {
    echo "${label} is missing or symlinked: ${path_value}" >&2
    exit 1
  }
}

require_plain_file() {
  local path_value="$1"
  local label="$2"
  [[ -f "${path_value}" && ! -L "${path_value}" ]] || {
    echo "${label} is missing or symlinked: ${path_value}" >&2
    exit 1
  }
}

assert_app_stopped() {
  if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
    echo "Quit ${APP_NAME} completely before preparing or changing a release set." >&2
    exit 1
  fi
}

prepare_set_command() {
  local role=""
  local source_app=""
  local source_manifest=""
  local source_lock=""
  local source_user_data=""
  local source_extensions=""
  local source_shared_data=""
  local source_proof=""
  local release_id_override=""
  local output_dir=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --role) [[ $# -ge 2 ]] || usage; role="$2"; shift ;;
      --app) [[ $# -ge 2 ]] || usage; source_app="$2"; shift ;;
      --manifest) [[ $# -ge 2 ]] || usage; source_manifest="$2"; shift ;;
      --release-lock) [[ $# -ge 2 ]] || usage; source_lock="$2"; shift ;;
      --user-data) [[ $# -ge 2 ]] || usage; source_user_data="$2"; shift ;;
      --extensions) [[ $# -ge 2 ]] || usage; source_extensions="$2"; shift ;;
      --shared-data) [[ $# -ge 2 ]] || usage; source_shared_data="$2"; shift ;;
      --proof) [[ $# -ge 2 ]] || usage; source_proof="$2"; shift ;;
      --release-id) [[ $# -ge 2 ]] || usage; release_id_override="$2"; shift ;;
      --output-dir) [[ $# -ge 2 ]] || usage; output_dir="$2"; shift ;;
      *) usage ;;
    esac
    shift
  done

  case "${role}" in current|candidate) ;; *) usage ;; esac
  [[ -n "${source_app}" && -n "${source_manifest}" && -n "${source_lock}" ]] || usage
  [[ -n "${source_user_data}" && -n "${source_extensions}" && -n "${source_shared_data}" ]] || usage
  [[ -n "${output_dir}" ]] || usage
  if [[ "${role}" == "candidate" && -z "${source_proof}" ]]; then
    echo "A candidate release set requires its completed proof evidence." >&2
    exit 1
  fi

  assert_app_stopped
  require_plain_directory "${source_app}" "Release-set app"
  require_plain_file "${source_manifest}" "Build manifest"
  require_plain_file "${source_lock}" "Release lock"
  require_plain_directory "${source_user_data}" "Profile user-data directory"
  require_plain_directory "${source_extensions}" "Profile extension directory"
  require_plain_directory "${source_shared_data}" "Profile shared-data directory"
  if [[ -n "${source_proof}" ]]; then
    require_plain_file "${source_proof}" "Proof evidence"
  fi

  for required_tool in cmp ditto jq pgrep shasum; do
    require_command "${required_tool}"
  done

  local release_specification_reader release_specification_mode
  if release_specification_validate "${source_lock}" >/dev/null 2>&1; then
    release_specification_reader="release_specification_record"
    release_specification_mode="strict"
  elif [[ "${role}" == "current" ]] && \
    release_specification_historical_validate "${source_lock}" >/dev/null 2>&1; then
    release_specification_reader="release_specification_historical_record"
    release_specification_mode="historical"
  else
    if [[ "${role}" == "candidate" ]]; then
      echo "A candidate requires the current strict Release Specification." >&2
    else
      echo "The current release has neither a valid current nor supported historical Release Specification." >&2
    fi
    exit 1
  fi

  local manifest_schema release_set_id source_set_id
  manifest_schema="$(jq -er '.schema_version' "${source_manifest}")"
  [[ "${manifest_schema}" =~ ^[0-9]+$ && "${manifest_schema}" -ge 2 ]] || {
    echo "Unsupported build-manifest schema: ${manifest_schema}" >&2
    exit 1
  }
  release_set_id="$(jq -r '.release.release_set_id // empty' "${source_manifest}")"
  source_set_id="$(jq -r '.release.source_set_id // empty' "${source_manifest}")"
  if [[ -n "${release_id_override}" ]]; then
    [[ "${release_id_override}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]+$ ]] || {
      echo "The release ID contains unsupported characters." >&2
      exit 2
    }
    if [[ -n "${release_set_id}" && "${release_set_id}" != "${release_id_override}" ]]; then
      echo "The release ID override does not match the build manifest." >&2
      exit 1
    fi
    release_set_id="${release_id_override}"
  fi
  [[ -n "${release_set_id}" ]] || {
    echo "A legacy build manifest requires --release-id." >&2
    exit 1
  }
  [[ -n "${source_set_id}" ]] || source_set_id="${release_set_id}"

  local app_name manifest_app_sha actual_app_sha lock_sha manifest_lock_sha
  app_name="$(jq -er '.artifact.app_name' "${source_manifest}")"
  [[ "${app_name}" == "${APP_NAME}" && "$(basename "${source_app}")" == "${APP_NAME}.app" ]] || {
    echo "The prepared app does not have the DBCode Wrapper identity." >&2
    exit 1
  }
  manifest_app_sha="$(jq -er '.artifact.sha256' "${source_manifest}")"
  actual_app_sha="$(artifact_digest "${source_app}")"
  [[ "${manifest_app_sha}" == "${actual_app_sha}" ]] || {
    echo "The release-set app does not match its build manifest." >&2
    exit 1
  }
  lock_sha="$(shasum -a 256 "${source_lock}" | awk '{print $1}')"
  manifest_lock_sha="$(jq -r '.source.release_lock_sha256 // empty' "${source_manifest}")"
  if [[ "${release_specification_mode}" == "historical" ]]; then
    [[ -n "${manifest_lock_sha}" && "${manifest_lock_sha}" == "${lock_sha}" ]] || {
      echo "A historical Release Specification requires an exact build-manifest lock binding." >&2
      exit 1
    }
  elif [[ -n "${manifest_lock_sha}" && "${manifest_lock_sha}" != "${lock_sha}" ]]; then
    echo "The release lock does not match the build manifest." >&2
    exit 1
  fi

  local source_build_spec source_extension_spec source_profile_spec
  source_build_spec="$("${release_specification_reader}" build "${source_lock}")"
  source_extension_spec="$("${release_specification_reader}" extensions "${source_lock}")"
  source_profile_spec="$("${release_specification_reader}" profile "${source_lock}")"

  local dbcode_id dbcode_version dbcode_sha dbcode_signature_sha code_oss_version
  local profile_schema expected_extensions actual_extensions
  dbcode_id="$(jq -er '.dbcode.id' <<<"${source_extension_spec}")"
  dbcode_version="$(jq -er '.dbcode.version' <<<"${source_extension_spec}")"
  dbcode_sha="$(jq -er '.dbcode.sha256' <<<"${source_extension_spec}")"
  dbcode_signature_sha="$(jq -er '.dbcode.signature_archive_sha256' <<<"${source_extension_spec}")"
  code_oss_version="$(jq -er '.runtime.code_oss_version' <<<"${source_build_spec}")"
  profile_schema="$(jq -er '.profile_schema_version' <<<"${source_profile_spec}")"
  expected_extensions="$(jq -r '
    .packages[] | .id + "@" + .version
  ' <<<"${source_extension_spec}" | LC_ALL=C sort)"
  actual_extensions="$({
    while IFS= read -r extension_manifest; do
      jq -r '.publisher + "." + .name + "@" + .version' "${extension_manifest}"
    done < <(find "${source_extensions}" -mindepth 2 -maxdepth 2 -name package.json -type f -print)
  } | LC_ALL=C sort)"
  [[ "${actual_extensions}" == "${expected_extensions}" ]] || {
    echo "The prepared profile does not contain the exact release-lock extension set." >&2
    printf 'Expected:\n%s\nActual:\n%s\n' "${expected_extensions}" "${actual_extensions}" >&2
    exit 1
  }

  if [[ -n "${source_proof}" && "${role}" == "candidate" ]]; then
    jq -e \
      --arg release_set_id "${release_set_id}" \
      --arg dbcode_id "${dbcode_id}" \
      --arg dbcode_version "${dbcode_version}" '
        .schema_version >= 5
        and .status == "passed"
        and .approved_release_set.host.release_set_id == $release_set_id
        and .approved_release_set.dbcode.id == $dbcode_id
        and .approved_release_set.dbcode.version == $dbcode_version
      ' "${source_proof}" >/dev/null || {
      echo "The candidate proof is incomplete or belongs to another release set." >&2
      exit 1
    }
  fi

  local output_parent output_name output_absolute source_absolute
  output_name="$(basename "${output_dir}")"
  mkdir -p "$(dirname "${output_dir}")"
  output_parent="$(cd "$(dirname "${output_dir}")" && pwd -P)"
  output_absolute="${output_parent}/${output_name}"
  [[ ! -e "${output_absolute}" && ! -L "${output_absolute}" ]] || {
    echo "Refusing to replace an existing prepared release set: ${output_absolute}" >&2
    exit 1
  }
  for source_absolute in \
    "$(canonical_existing_path "${source_app}")" \
    "$(canonical_existing_path "${source_user_data}")" \
    "$(canonical_existing_path "${source_extensions}")" \
    "$(canonical_existing_path "${source_shared_data}")"; do
    case "${output_absolute}/" in
      "${source_absolute}/"*)
        echo "The prepared release set must be separate from every installed source directory." >&2
        exit 1
        ;;
    esac
  done

  local staging_root
  staging_root="$(mktemp -d "${output_parent}/.${output_name}.staging.XXXXXX")"
  cleanup_staging_root() {
    [[ -n "${staging_root:-}" ]] || return 0
    case "${staging_root}" in
      "${output_parent}/.${output_name}.staging."*) rm -rf "${staging_root}" ;;
      *) echo "Refusing to remove unexpected release-set staging path: ${staging_root}" >&2; return 1 ;;
    esac
    staging_root=""
  }
  trap cleanup_staging_root EXIT INT TERM

  local source_user_data_sha source_extensions_sha source_shared_data_sha
  source_user_data_sha="$(directory_content_digest "${source_user_data}")"
  source_extensions_sha="$(directory_content_digest "${source_extensions}")"
  source_shared_data_sha="$(directory_content_digest "${source_shared_data}")"

  mkdir -p "${staging_root}/profile" "${staging_root}/evidence"
  clone_path "${source_app}" "${staging_root}/${APP_NAME}.app"
  cp "${source_manifest}" "${staging_root}/build-manifest.json"
  cp "${source_lock}" "${staging_root}/release-lock.json"
  clone_path "${source_user_data}" "${staging_root}/profile/user-data"
  clone_path "${source_extensions}" "${staging_root}/profile/extensions"
  clone_path "${source_shared_data}" "${staging_root}/profile/shared-data"
  if [[ -n "${source_proof}" ]]; then
    cp "${source_proof}" "${staging_root}/evidence/proof-state.json"
  fi

  [[ "${source_user_data_sha}" == \
    "$(directory_content_digest "${staging_root}/profile/user-data")" ]] || {
    echo "The source user-data profile changed while it was being cloned." >&2
    exit 1
  }
  [[ "${source_extensions_sha}" == \
    "$(directory_content_digest "${staging_root}/profile/extensions")" ]] || {
    echo "The source extension root changed while it was being cloned." >&2
    exit 1
  }
  [[ "${source_shared_data_sha}" == \
    "$(directory_content_digest "${staging_root}/profile/shared-data")" ]] || {
    echo "The source shared-data profile changed while it was being cloned." >&2
    exit 1
  }

  local restored_payloads_file="${staging_root}/evidence/restored-signed-payloads.txt"
  : > "${restored_payloads_file}"
  if [[ "${role}" == "candidate" ]] && cmp -s "${source_lock}" "${LOCK_FILE}"; then
    local extension_id extension_version package_root
    while IFS=$'\t' read -r extension_id extension_version <&3; do
      package_root="${CACHE_ROOT}/runtime-extensions/${extension_id}/${extension_version}"
      "${REPO_ROOT}/script/verify_openvsx_package.sh" \
        "${extension_id}" "${package_root}" >/dev/null
      if ! "${REPO_ROOT}/script/verify_installed_extension_payload.sh" \
        "${package_root}/package.vsix" \
        "${staging_root}/profile/extensions" \
        "${extension_id}" \
        "${extension_version}" >/dev/null 2>&1; then
        "${REPO_ROOT}/script/restore_installed_extension_payload.sh" \
          "${package_root}/package.vsix" \
          "${staging_root}/profile/extensions" \
          "${extension_id}" \
          "${extension_version}" >/dev/null
        printf '%s@%s\n' "${extension_id}" "${extension_version}" >> "${restored_payloads_file}"
      fi
      "${REPO_ROOT}/script/verify_installed_extension_payload.sh" \
        "${package_root}/package.vsix" \
        "${staging_root}/profile/extensions" \
        "${extension_id}" \
        "${extension_version}" >/dev/null
    done 3< <(jq -r '.[] | [.id, .version] | @tsv' <<<"${RUNTIME_EXTENSION_PACKAGES}")
  fi

  local copied_app_sha manifest_sha user_data_sha extensions_sha shared_data_sha proof_sha
  copied_app_sha="$(artifact_digest "${staging_root}/${APP_NAME}.app")"
  manifest_sha="$(shasum -a 256 "${staging_root}/build-manifest.json" | awk '{print $1}')"
  user_data_sha="$(directory_content_digest "${staging_root}/profile/user-data")"
  extensions_sha="$(directory_content_digest "${staging_root}/profile/extensions")"
  shared_data_sha="$(directory_content_digest "${staging_root}/profile/shared-data")"
  proof_sha=""
  if [[ -n "${source_proof}" ]]; then
    proof_sha="$(shasum -a 256 "${staging_root}/evidence/proof-state.json" | awk '{print $1}')"
  fi
  [[ "${copied_app_sha}" == "${actual_app_sha}" ]] || {
    echo "The copied candidate app changed during preparation." >&2
    exit 1
  }
  [[ "${source_user_data_sha}" == "${user_data_sha}" ]] || {
    echo "Candidate preparation unexpectedly changed the copied user-data profile." >&2
    exit 1
  }
  [[ "${source_shared_data_sha}" == "${shared_data_sha}" ]] || {
    echo "Candidate preparation unexpectedly changed the copied shared-data profile." >&2
    exit 1
  }

  local target_platform target_architecture source_revision
  target_platform="$(jq -er '.target.platform' <<<"${source_build_spec}")"
  target_architecture="$(jq -er '.target.architecture' <<<"${source_build_spec}")"
  source_revision="$(jq -r '.source.repository_revision // empty' "${source_manifest}")"
  jq -n \
    --arg role "${role}" \
    --arg prepared_at_utc "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --arg release_set_id "${release_set_id}" \
    --arg source_set_id "${source_set_id}" \
    --arg source_revision "${source_revision}" \
    --arg target_platform "${target_platform}" \
    --arg target_architecture "${target_architecture}" \
    --arg app_sha "${copied_app_sha}" \
    --arg manifest_sha "${manifest_sha}" \
    --arg code_oss_version "${code_oss_version}" \
    --arg dbcode_id "${dbcode_id}" \
    --arg dbcode_version "${dbcode_version}" \
    --arg dbcode_sha "${dbcode_sha}" \
    --arg dbcode_signature_sha "${dbcode_signature_sha}" \
    --argjson profile_schema "${profile_schema}" \
    --arg user_data_sha "${user_data_sha}" \
    --arg source_extensions_sha "${source_extensions_sha}" \
    --arg extensions_sha "${extensions_sha}" \
    --arg shared_data_sha "${shared_data_sha}" \
    --arg installed_extensions "${actual_extensions}" \
    --arg restored_payloads "$(cat "${restored_payloads_file}")" \
    --arg proof_sha "${proof_sha}" '
      {
        schema_version: 1,
        role: $role,
        prepared_at_utc: $prepared_at_utc,
        release: {
          release_set_id: $release_set_id,
          source_set_id: $source_set_id
        },
        source: {repository_revision: $source_revision},
        target: {platform: $target_platform, architecture: $target_architecture},
        host: {
          app_sha256: $app_sha,
          build_manifest_sha256: $manifest_sha,
          code_oss_version: $code_oss_version
        },
        dbcode: {
          id: $dbcode_id,
          version: $dbcode_version,
          vsix_sha256: $dbcode_sha,
          signature_archive_sha256: $dbcode_signature_sha
        },
        profile: {
          schema_version: $profile_schema,
          user_data_sha256: $user_data_sha,
          source_extensions_sha256: $source_extensions_sha,
          extensions_sha256: $extensions_sha,
          shared_data_sha256: $shared_data_sha,
          installed_extensions: ($installed_extensions | split("\n") | map(select(length > 0))),
          restored_signed_payloads: ($restored_payloads | split("\n") | map(select(length > 0)))
        },
        evidence: (
          if $proof_sha == "" then {} else {proof_sha256: $proof_sha} end
        ),
        paths: ({
          app: "DBCode Wrapper.app",
          build_manifest: "build-manifest.json",
          release_lock: "release-lock.json",
          user_data: "profile/user-data",
          extensions: "profile/extensions",
          shared_data: "profile/shared-data"
        } + if $proof_sha == "" then {} else {proof: "evidence/proof-state.json"} end)
      }
    ' > "${staging_root}/release-set.json"
  approved_release_set_validate "${staging_root}/release-set.json" >/dev/null
  rm -f "${restored_payloads_file}"

  chmod -R go-rwx "${staging_root}"
  chmod 700 "${staging_root}"
  mv "${staging_root}" "${output_absolute}"
  staging_root=""
  trap - EXIT INT TERM
  echo "Prepared isolated ${role} release set: ${output_absolute}"
}

clone_path() {
  local source_path="$1"
  local destination_path="$2"
  if [[ -d "${source_path}" ]]; then
    if ! cp -cR "${source_path}" "${destination_path}" 2>/dev/null; then
      ditto "${source_path}" "${destination_path}"
    fi
  else
    if ! cp -c "${source_path}" "${destination_path}" 2>/dev/null; then
      cp "${source_path}" "${destination_path}"
    fi
  fi
}

layout_value() {
  local layout_file="$1"
  local selector="$2"
  local value
  value="$(jq -er "${selector}" "${layout_file}")"
  [[ "${value}" == /* ]] || {
    echo "Install-layout paths must be absolute: ${selector}" >&2
    return 1
  }
  printf '%s\n' "${value}"
}

validate_install_layout() {
  local layout_file="$1"
  require_plain_file "${layout_file}" "Install layout"
  jq -e '
    .schema_version == 1
    and (.targets | keys | sort) == ["app", "build_manifest", "extensions", "shared_data", "user_data"]
    and all([
      .targets.app,
      .targets.build_manifest,
      .targets.extensions,
      .targets.shared_data,
      .targets.user_data,
      .state_root,
      .previous_root
    ][]; type == "string" and startswith("/"))
    and ([
      .targets.app,
      .targets.build_manifest,
      .targets.extensions,
      .targets.shared_data,
      .targets.user_data,
      .state_root,
      .previous_root
    ] | unique | length) == 7
  ' "${layout_file}" >/dev/null || {
    echo "The install layout is incomplete or unsafe." >&2
    exit 1
  }
  [[ "$(basename "$(layout_value "${layout_file}" '.targets.app')")" == "${APP_NAME}.app" ]] || {
    echo "The install layout app target has an unexpected name." >&2
    exit 1
  }
  [[ "$(basename "$(layout_value "${layout_file}" '.targets.build_manifest')")" == "build-manifest.json" ]] || {
    echo "The install layout manifest target has an unexpected name." >&2
    exit 1
  }

  local -a layout_paths
  layout_paths=(
    "$(layout_value "${layout_file}" '.targets.app')" \
    "$(layout_value "${layout_file}" '.targets.build_manifest')" \
    "$(layout_value "${layout_file}" '.targets.user_data')" \
    "$(layout_value "${layout_file}" '.targets.extensions')" \
    "$(layout_value "${layout_file}" '.targets.shared_data')" \
    "$(layout_value "${layout_file}" '.state_root')" \
    "$(layout_value "${layout_file}" '.previous_root')"
  )
  local first_index second_index first_path second_path
  for ((first_index = 0; first_index < ${#layout_paths[@]}; first_index++)); do
    first_path="${layout_paths[$first_index]}"
    case "${first_path}" in
      /|*/../*|*/..|*/./*|*/.)
        echo "Install-layout paths must be normalized private locations." >&2
        exit 1
        ;;
    esac
    for ((second_index = first_index + 1; second_index < ${#layout_paths[@]}; second_index++)); do
      second_path="${layout_paths[$second_index]}"
      case "${first_path}/" in
        "${second_path}/"*) echo "Install-layout paths must not overlap." >&2; exit 1 ;;
      esac
      case "${second_path}/" in
        "${first_path}/"*) echo "Install-layout paths must not overlap." >&2; exit 1 ;;
      esac
    done
  done
}

assert_installed_matches_set() {
  local set_file="$1"
  local target_app="$2"
  local target_manifest="$3"
  local target_user_data="$4"
  local target_extensions="$5"
  local target_shared_data="$6"

  require_plain_directory "${target_app}" "Installed app"
  require_plain_file "${target_manifest}" "Installed build manifest"
  require_plain_directory "${target_user_data}" "Installed user-data profile"
  require_plain_directory "${target_extensions}" "Installed extension root"
  require_plain_directory "${target_shared_data}" "Installed shared-data profile"
  [[ "$(artifact_digest "${target_app}")" == "$(jq -er '.host.app_sha256' "${set_file}")" ]] || {
    echo "The installed app does not match the declared current release set." >&2
    exit 1
  }
  [[ "$(shasum -a 256 "${target_manifest}" | awk '{print $1}')" == \
    "$(jq -er '.host.build_manifest_sha256' "${set_file}")" ]] || {
    echo "The installed manifest does not match the declared current release set." >&2
    exit 1
  }
  [[ "$(directory_content_digest "${target_user_data}")" == "$(jq -er '.profile.user_data_sha256' "${set_file}")" ]] || {
    echo "The installed user-data profile changed after current-set preparation." >&2
    exit 1
  }
  [[ "$(directory_content_digest "${target_extensions}")" == "$(jq -er '.profile.extensions_sha256' "${set_file}")" ]] || {
    echo "The installed extension root changed after current-set preparation." >&2
    exit 1
  }
  [[ "$(directory_content_digest "${target_shared_data}")" == "$(jq -er '.profile.shared_data_sha256' "${set_file}")" ]] || {
    echo "The installed shared-data profile changed after current-set preparation." >&2
    exit 1
  }
}

validate_promotion_matrix() {
  local matrix_file="$1"
  local current_set="$2"
  local candidate_set="$3"
  require_plain_file "${matrix_file}" "Compatibility matrix"
  local current_id candidate_id current_sha candidate_sha
  current_id="$(jq -er '.release.release_set_id' "${current_set}")"
  candidate_id="$(jq -er '.release.release_set_id' "${candidate_set}")"
  current_sha="$(shasum -a 256 "${current_set}" | awk '{print $1}')"
  candidate_sha="$(shasum -a 256 "${candidate_set}" | awk '{print $1}')"
  jq -e \
    --arg current_id "${current_id}" \
    --arg candidate_id "${candidate_id}" \
    --arg current_sha "${current_sha}" \
    --arg candidate_sha "${candidate_sha}" '
      .schema_version == 1
      and .status == "passed"
      and .promotion_ready == true
      and .current_release_set_id == $current_id
      and .candidate_release_set_id == $candidate_id
      and .current_release_set_sha256 == $current_sha
      and .candidate_release_set_sha256 == $candidate_sha
      and [.combinations[].combination] == ["H0/D0", "H0/D1", "H1/D0", "H1/D1"]
      and all(.combinations[];
        .status == "passed"
        and .checks.static == "passed"
        and .checks.runtime == "passed"
        and .checks.bundle_unchanged == true
        and .checks.surprise_update_absent == true
      )
      and .combinations[3].host.release_set_id == $candidate_id
      and .combinations[3].details.runtime.focused_database_shell == true
      and .combinations[3].details.runtime.dbcode_started == true
      and .combinations[3].details.runtime.normal_pro_activation == true
      and .combinations[3].details.runtime.postgresql == true
      and .combinations[3].details.runtime.duckdb == true
      and .combinations[3].details.runtime.parquet == true
      and .combinations[3].details.static.connection_capability_contract == true
      and (.combinations[3].details.runtime.hyphen_path_preflight == "passed"
        or .combinations[3].details.runtime.hyphen_path_preflight == "not-required")
      and .combinations[3].details.runtime.full_quit_and_relaunch == true
      and .combinations[3].details.runtime.normal_profiles_unchanged == true
      and .combinations[3].details.runtime.surprise_update_absent == true
    ' "${matrix_file}" >/dev/null || {
    echo "The compatibility matrix does not approve this exact complete candidate set." >&2
    exit 1
  }
}

write_approval_record() {
  local candidate_set="$1"
  local matrix_file="$2"
  local candidate_user_data="$3"
  local state_root="$4"
  local candidate_manifest candidate_proof release_id approval_root attestation_file
  local manifest_sha proof_sha matrix_sha registry_dir registry_file record_file
  candidate_manifest="$(approved_release_set_member "${candidate_set}" build_manifest)"
  candidate_proof="$(approved_release_set_member "${candidate_set}" proof)"
  release_id="$(jq -er '.release.release_set_id' "${candidate_set}")"
  manifest_sha="$(shasum -a 256 "${candidate_manifest}" | awk '{print $1}')"
  proof_sha="$(shasum -a 256 "${candidate_proof}" | awk '{print $1}')"
  matrix_sha="$(shasum -a 256 "${matrix_file}" | awk '{print $1}')"
  approval_root="${state_root}/approvals/${release_id}"
  mkdir -p "${approval_root}"
  chmod 700 "${state_root}" "${state_root}/approvals" "${approval_root}"
  attestation_file="${approval_root}/approval-attestation.json"
  jq -n \
    --arg approved_at "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --arg release_set_id "${release_id}" \
    --arg candidate_set_sha256 "$(shasum -a 256 "${candidate_set}" | awk '{print $1}')" \
    --arg candidate_manifest_sha256 "${manifest_sha}" \
    --arg proof_sha256 "${proof_sha}" \
    --arg gate_receipt_sha256 "${matrix_sha}" '
      {
        schema_version: 1,
        approved_at: $approved_at,
        release_set_id: $release_set_id,
        candidate_set_sha256: $candidate_set_sha256,
        candidate_manifest_sha256: $candidate_manifest_sha256,
        proof_sha256: $proof_sha256,
        gate_receipt_sha256: $gate_receipt_sha256,
        confirmation: "exact-release-set-id",
        automatic_install: false,
        privileged_install: false
      }
    ' > "${attestation_file}"
  chmod 600 "${attestation_file}"
  record_file="${approval_root}/approved-release-set.json"
  registry_dir="${candidate_user_data}/User/globalStorage/dbcode-wrapper.release-status"
  registry_file="${registry_dir}/approved-release-sets.json"
  mkdir -p "${registry_dir}"
  chmod 700 "${candidate_user_data}" "${candidate_user_data}/User" "${candidate_user_data}/User/globalStorage" "${registry_dir}"
  approved_release_set_write_approval \
    "${candidate_set}" \
    "${candidate_manifest}" \
    "${attestation_file}" \
    "${candidate_proof}" \
    "${matrix_file}" \
    "${record_file}" \
    "${registry_file}"
}

safe_remove_transaction_path() {
  local path_value="$1"
  local transaction_id="$2"
  case "${path_value}" in
    *.incoming-"${transaction_id}"|*.outgoing-"${transaction_id}"|*.failed-"${transaction_id}") rm -rf "${path_value}" ;;
    *) echo "Refusing to remove an unexpected transaction path: ${path_value}" >&2; return 1 ;;
  esac
}

promote_command() {
  local current_set=""
  local candidate_set=""
  local matrix_file=""
  local layout_file=""
  local confirmation=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --current-set) [[ $# -ge 2 ]] || usage; current_set="$2"; shift ;;
      --candidate-set) [[ $# -ge 2 ]] || usage; candidate_set="$2"; shift ;;
      --matrix) [[ $# -ge 2 ]] || usage; matrix_file="$2"; shift ;;
      --layout) [[ $# -ge 2 ]] || usage; layout_file="$2"; shift ;;
      --confirm-release-set) [[ $# -ge 2 ]] || usage; confirmation="$2"; shift ;;
      *) usage ;;
    esac
    shift
  done
  [[ -n "${current_set}" && -n "${candidate_set}" && -n "${matrix_file}" && -n "${layout_file}" ]] || usage
  require_release_set "${current_set}" "Current"
  require_release_set "${candidate_set}" "Candidate"
  local candidate_id current_id
  candidate_id="$(jq -er '.release.release_set_id' "${candidate_set}")"
  current_id="$(jq -er '.release.release_set_id' "${current_set}")"
  [[ "${confirmation}" == "${candidate_id}" ]] || {
    echo "Promotion requires --confirm-release-set ${candidate_id}." >&2
    exit 1
  }
  [[ "$(jq -er '.role' "${candidate_set}")" == "candidate" ]] || {
    echo "Only an isolated candidate release set can be promoted." >&2
    exit 1
  }
  assert_app_stopped
  validate_install_layout "${layout_file}"
  validate_promotion_matrix "${matrix_file}" "${current_set}" "${candidate_set}"

  local candidate_proof
  candidate_proof="$(approved_release_set_member "${candidate_set}" proof)"
  proof_state_is_finalizable "${candidate_proof}" || {
    echo "The candidate proof does not contain a complete launch, quit, relaunch, and database gate." >&2
    exit 1
  }

  local target_app target_manifest target_user_data target_extensions target_shared_data
  local state_root previous_parent
  target_app="$(layout_value "${layout_file}" '.targets.app')"
  target_manifest="$(layout_value "${layout_file}" '.targets.build_manifest')"
  target_user_data="$(layout_value "${layout_file}" '.targets.user_data')"
  target_extensions="$(layout_value "${layout_file}" '.targets.extensions')"
  target_shared_data="$(layout_value "${layout_file}" '.targets.shared_data')"
  state_root="$(layout_value "${layout_file}" '.state_root')"
  previous_parent="$(layout_value "${layout_file}" '.previous_root')"
  assert_installed_matches_set \
    "${current_set}" \
    "${target_app}" \
    "${target_manifest}" \
    "${target_user_data}" \
    "${target_extensions}" \
    "${target_shared_data}"

  mkdir -p "${state_root}" "${previous_parent}"
  chmod 700 "${state_root}" "${previous_parent}"
  local transaction_id snapshot_root
  transaction_id="$(date -u +'%Y%m%dT%H%M%SZ')-$$"
  snapshot_root="${previous_parent}/${current_id}-${transaction_id}"
  [[ ! -e "${snapshot_root}" && ! -L "${snapshot_root}" ]] || {
    echo "The previous-set snapshot already exists: ${snapshot_root}" >&2
    exit 1
  }
  mkdir -p "${snapshot_root}/profile"
  clone_path "${target_app}" "${snapshot_root}/${APP_NAME}.app"
  clone_path "${target_manifest}" "${snapshot_root}/build-manifest.json"
  clone_path "${target_user_data}" "${snapshot_root}/profile/user-data"
  clone_path "${target_extensions}" "${snapshot_root}/profile/extensions"
  clone_path "${target_shared_data}" "${snapshot_root}/profile/shared-data"
  cp "${current_set}" "${snapshot_root}/release-set.json"
  chmod -R go-rwx "${snapshot_root}"
  chmod 700 "${snapshot_root}"
  assert_installed_matches_set \
    "${snapshot_root}/release-set.json" \
    "${snapshot_root}/${APP_NAME}.app" \
    "${snapshot_root}/build-manifest.json" \
    "${snapshot_root}/profile/user-data" \
    "${snapshot_root}/profile/extensions" \
    "${snapshot_root}/profile/shared-data"

  local candidate_app candidate_manifest candidate_user_data candidate_extensions candidate_shared_data
  candidate_app="$(approved_release_set_member "${candidate_set}" app)"
  candidate_manifest="$(approved_release_set_member "${candidate_set}" build_manifest)"
  candidate_user_data="$(approved_release_set_member "${candidate_set}" user_data)"
  candidate_extensions="$(approved_release_set_member "${candidate_set}" extensions)"
  candidate_shared_data="$(approved_release_set_member "${candidate_set}" shared_data)"

  local incoming_app_root incoming_manifest_root incoming_user_data_root incoming_extensions_root incoming_shared_data_root
  local incoming_app incoming_manifest incoming_user_data incoming_extensions incoming_shared_data
  incoming_app_root="${target_app}.incoming-${transaction_id}"
  incoming_manifest_root="${target_manifest}.incoming-${transaction_id}"
  incoming_user_data_root="${target_user_data}.incoming-${transaction_id}"
  incoming_extensions_root="${target_extensions}.incoming-${transaction_id}"
  incoming_shared_data_root="${target_shared_data}.incoming-${transaction_id}"
  mkdir -p \
    "${incoming_app_root}" \
    "${incoming_manifest_root}" \
    "${incoming_user_data_root}" \
    "${incoming_extensions_root}" \
    "${incoming_shared_data_root}"
  incoming_app="${incoming_app_root}/$(basename "${target_app}")"
  incoming_manifest="${incoming_manifest_root}/$(basename "${target_manifest}")"
  incoming_user_data="${incoming_user_data_root}/$(basename "${target_user_data}")"
  incoming_extensions="${incoming_extensions_root}/$(basename "${target_extensions}")"
  incoming_shared_data="${incoming_shared_data_root}/$(basename "${target_shared_data}")"
  clone_path "${candidate_app}" "${incoming_app}"
  clone_path "${candidate_manifest}" "${incoming_manifest}"
  clone_path "${candidate_user_data}" "${incoming_user_data}"
  clone_path "${candidate_extensions}" "${incoming_extensions}"
  clone_path "${candidate_shared_data}" "${incoming_shared_data}"
  write_approval_record "${candidate_set}" "${matrix_file}" "${incoming_user_data}" "${state_root}" >/dev/null

  [[ "$(artifact_digest "${incoming_app}")" == "$(jq -er '.host.app_sha256' "${candidate_set}")" ]] || {
    echo "The staged candidate app changed before promotion." >&2
    exit 1
  }
  [[ "$(shasum -a 256 "${incoming_manifest}" | awk '{print $1}')" == \
    "$(jq -er '.host.build_manifest_sha256' "${candidate_set}")" ]] || {
    echo "The staged candidate manifest changed before promotion." >&2
    exit 1
  }
  [[ "$(directory_content_digest "${incoming_extensions}")" == \
    "$(jq -er '.profile.extensions_sha256' "${candidate_set}")" ]] || {
    echo "The staged candidate extension root changed before promotion." >&2
    exit 1
  }
  [[ "$(directory_content_digest "${incoming_shared_data}")" == \
    "$(jq -er '.profile.shared_data_sha256' "${candidate_set}")" ]] || {
    echo "The staged candidate shared-data profile changed before promotion." >&2
    exit 1
  }

  local targets incoming_paths incoming_roots outgoing_paths
  targets=("${target_app}" "${target_manifest}" "${target_extensions}" "${target_user_data}" "${target_shared_data}")
  incoming_paths=("${incoming_app}" "${incoming_manifest}" "${incoming_extensions}" "${incoming_user_data}" "${incoming_shared_data}")
  incoming_roots=("${incoming_app_root}" "${incoming_manifest_root}" "${incoming_extensions_root}" "${incoming_user_data_root}" "${incoming_shared_data_root}")
  outgoing_paths=(
    "${target_app}.outgoing-${transaction_id}"
    "${target_manifest}.outgoing-${transaction_id}"
    "${target_extensions}.outgoing-${transaction_id}"
    "${target_user_data}.outgoing-${transaction_id}"
    "${target_shared_data}.outgoing-${transaction_id}"
  )
  local journal_file="${state_root}/promotion-transaction.json"
  jq -n \
    --arg transaction_id "${transaction_id}" \
    --arg current_release_set_id "${current_id}" \
    --arg candidate_release_set_id "${candidate_id}" \
    --arg snapshot_path "${snapshot_root}" \
    --argjson targets "$(printf '%s\n' "${targets[@]}" | jq -R -s -c 'split("\n") | map(select(length > 0))')" \
    --argjson incoming "$(printf '%s\n' "${incoming_paths[@]}" | jq -R -s -c 'split("\n") | map(select(length > 0))')" \
    --argjson outgoing "$(printf '%s\n' "${outgoing_paths[@]}" | jq -R -s -c 'split("\n") | map(select(length > 0))')" '
      {
        schema_version: 1,
        transaction_id: $transaction_id,
        status: "swapping",
        current_release_set_id: $current_release_set_id,
        candidate_release_set_id: $candidate_release_set_id,
        snapshot_path: $snapshot_path,
        targets: $targets,
        incoming: $incoming,
        outgoing: $outgoing
      }
    ' > "${journal_file}"
  chmod 600 "${journal_file}"

  local moved_out_count=0 swapped_count=0 swap_failed="false" index reverse_index
  for index in 0 1 2 3 4; do
    if ! mv "${targets[$index]}" "${outgoing_paths[$index]}"; then
      swap_failed="true"
      break
    fi
    moved_out_count=$((moved_out_count + 1))
    if [[ "${DBCODE_WRAPPER_TEST_FAIL_AFTER_TARGET_MOVE:-}" == "${moved_out_count}" ]]; then
      swap_failed="true"
      break
    fi
    if ! mv "${incoming_paths[$index]}" "${targets[$index]}"; then
      swap_failed="true"
      break
    fi
    swapped_count=$((swapped_count + 1))
    if [[ "${DBCODE_WRAPPER_TEST_FAIL_AFTER_SWAP:-}" == "${swapped_count}" ]]; then
      swap_failed="true"
      break
    fi
  done

  if [[ "${swap_failed}" == "true" ]]; then
    local recovery_incomplete="false"
    for ((reverse_index = moved_out_count - 1; reverse_index >= 0; reverse_index--)); do
      local failed_path="${targets[$reverse_index]}.failed-${transaction_id}"
      if [[ -e "${targets[$reverse_index]}" || -L "${targets[$reverse_index]}" ]]; then
        mv "${targets[$reverse_index]}" "${failed_path}" || recovery_incomplete="true"
      fi
      if [[ -e "${outgoing_paths[$reverse_index]}" || -L "${outgoing_paths[$reverse_index]}" ]]; then
        mv "${outgoing_paths[$reverse_index]}" "${targets[$reverse_index]}" || recovery_incomplete="true"
      else
        recovery_incomplete="true"
      fi
      [[ ! -e "${failed_path}" ]] || safe_remove_transaction_path "${failed_path}" "${transaction_id}"
    done
    for index in 0 1 2 3 4; do
      [[ ! -e "${incoming_roots[$index]}" ]] || safe_remove_transaction_path "${incoming_roots[$index]}" "${transaction_id}"
      if [[ -e "${outgoing_paths[$index]}" || -L "${outgoing_paths[$index]}" ]]; then
        recovery_incomplete="true"
      fi
    done
    if [[ "${recovery_incomplete}" == "true" ]]; then
      jq '.status = "recovery-incomplete-after-failed-promotion"' "${journal_file}" > "${journal_file}.tmp"
      mv "${journal_file}.tmp" "${journal_file}"
      echo "Promotion failed and automatic recovery is incomplete. Preserved outgoing paths are recorded in ${journal_file}." >&2
      exit 1
    fi
    jq '.status = "restored-after-failed-promotion"' "${journal_file}" > "${journal_file}.tmp"
    mv "${journal_file}.tmp" "${journal_file}"
    assert_installed_matches_set \
      "${current_set}" \
      "${target_app}" \
      "${target_manifest}" \
      "${target_user_data}" \
      "${target_extensions}" \
      "${target_shared_data}"
    echo "Promotion failed and the complete current release set was restored." >&2
    exit 1
  fi

  local installed_state="${state_root}/installed-release-set.json"
  jq -n \
    --arg promoted_at "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --arg transaction_id "${transaction_id}" \
    --arg active_release_set_id "${candidate_id}" \
    --arg active_set_sha256 "$(shasum -a 256 "${candidate_set}" | awk '{print $1}')" \
    --arg active_app_sha256 "$(artifact_digest "${target_app}")" \
    --arg active_manifest_sha256 "$(shasum -a 256 "${target_manifest}" | awk '{print $1}')" \
    --arg active_user_data_sha256 "$(directory_content_digest "${target_user_data}")" \
    --arg active_extensions_sha256 "$(directory_content_digest "${target_extensions}")" \
    --arg active_shared_data_sha256 "$(directory_content_digest "${target_shared_data}")" \
    --arg previous_release_set_id "${current_id}" \
    --arg snapshot_path "${snapshot_root}" \
    --arg matrix_sha256 "$(shasum -a 256 "${matrix_file}" | awk '{print $1}')" '
      {
        schema_version: 1,
        status: "pending-health-check",
        promoted_at: $promoted_at,
        transaction_id: $transaction_id,
        active: {
          release_set_id: $active_release_set_id,
          release_set_sha256: $active_set_sha256,
          app_sha256: $active_app_sha256,
          build_manifest_sha256: $active_manifest_sha256,
          user_data_sha256: $active_user_data_sha256,
          extensions_sha256: $active_extensions_sha256,
          shared_data_sha256: $active_shared_data_sha256,
          compatibility_matrix_sha256: $matrix_sha256
        },
        previous: {
          release_set_id: $previous_release_set_id,
          snapshot_path: $snapshot_path
        }
      }
    ' > "${installed_state}.tmp"
  chmod 600 "${installed_state}.tmp"
  mv "${installed_state}.tmp" "${installed_state}"
  jq '.status = "pending-health-check"' "${journal_file}" > "${journal_file}.tmp"
  mv "${journal_file}.tmp" "${journal_file}"

  for index in 0 1 2 3 4; do
    safe_remove_transaction_path "${outgoing_paths[$index]}" "${transaction_id}"
    safe_remove_transaction_path "${incoming_roots[$index]}" "${transaction_id}"
  done
  echo "Promoted complete release set ${candidate_id}; restart health acceptance is still required."
}

health_command() {
  local layout_file=""
  local confirmation=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --layout) [[ $# -ge 2 ]] || usage; layout_file="$2"; shift ;;
      --confirm-release-set) [[ $# -ge 2 ]] || usage; confirmation="$2"; shift ;;
      *) usage ;;
    esac
    shift
  done
  [[ -n "${layout_file}" ]] || usage
  validate_install_layout "${layout_file}"
  local state_root state_file active_id
  state_root="$(layout_value "${layout_file}" '.state_root')"
  state_file="${state_root}/installed-release-set.json"
  require_plain_file "${state_file}" "Installed release-set state"
  active_id="$(jq -er '.active.release_set_id' "${state_file}")"
  [[ "${confirmation}" == "${active_id}" ]] || {
    echo "Health acceptance requires --confirm-release-set ${active_id}." >&2
    exit 1
  }
  jq -e '.schema_version == 1 and .status == "pending-health-check"' "${state_file}" >/dev/null || {
    echo "The installed release set is not awaiting restart health acceptance." >&2
    exit 1
  }
  assert_app_stopped

  local target_app target_manifest target_extensions
  target_app="$(layout_value "${layout_file}" '.targets.app')"
  target_manifest="$(layout_value "${layout_file}" '.targets.build_manifest')"
  target_extensions="$(layout_value "${layout_file}" '.targets.extensions')"
  [[ "$(artifact_digest "${target_app}")" == "$(jq -er '.active.app_sha256' "${state_file}")" ]] || {
    echo "The installed app changed before restart health acceptance." >&2
    exit 1
  }
  [[ "$(shasum -a 256 "${target_manifest}" | awk '{print $1}')" == \
    "$(jq -er '.active.build_manifest_sha256' "${state_file}")" ]] || {
    echo "The installed manifest changed before restart health acceptance." >&2
    exit 1
  }
  [[ "$(directory_content_digest "${target_extensions}")" == "$(jq -er '.active.extensions_sha256' "${state_file}")" ]] || {
    echo "The installed extension root changed before restart health acceptance." >&2
    exit 1
  }

  local health_gate receipt_file gate_exit=0
  health_gate="${DBCODE_WRAPPER_HEALTH_GATE:-${REPO_ROOT}/script/check_installed_release_health.sh}"
  [[ -f "${health_gate}" && ! -L "${health_gate}" && -x "${health_gate}" ]] || {
    echo "The installed release health gate is missing or unsafe: ${health_gate}" >&2
    exit 1
  }
  receipt_file="${state_root}/restart-health-receipt.json"
  [[ ! -L "${receipt_file}" ]] || {
    echo "Refusing a symlinked restart health receipt." >&2
    exit 1
  }
  "${health_gate}" \
    --layout "${layout_file}" \
    --state "${state_file}" \
    --output "${receipt_file}" || gate_exit=$?
  [[ -f "${receipt_file}" && ! -L "${receipt_file}" ]] || {
    echo "The restart health gate did not produce a receipt." >&2
    exit 1
  }
  jq -e \
    --arg release_set_id "${active_id}" \
    --arg app_sha "$(jq -er '.active.app_sha256' "${state_file}")" \
    --arg manifest_sha "$(jq -er '.active.build_manifest_sha256' "${state_file}")" \
    --arg extensions_sha "$(jq -er '.active.extensions_sha256' "${state_file}")" '
      .schema_version == 1
      and .status == "passed"
      and .release_set_id == $release_set_id
      and .app_sha256 == $app_sha
      and .build_manifest_sha256 == $manifest_sha
      and .extensions_sha256 == $extensions_sha
      and .first_launch_ready == true
      and .first_quit_complete == true
      and .relaunch_ready == true
      and .final_quit_complete == true
      and .dbcode_started == true
      and .account_restored == true
      and .keychain_error_absent == true
      and .surprise_update_absent == true
    ' "${receipt_file}" >/dev/null || {
    echo "The restart health receipt is incomplete or belongs to another installed set." >&2
    exit 1
  }
  [[ "${gate_exit}" -eq 0 ]] || {
    echo "The restart health gate reported failure." >&2
    exit 1
  }
  [[ "$(artifact_digest "${target_app}")" == "$(jq -er '.active.app_sha256' "${state_file}")" ]] || {
    echo "The installed app changed during restart health checking." >&2
    exit 1
  }
  [[ "$(directory_content_digest "${target_extensions}")" == "$(jq -er '.active.extensions_sha256' "${state_file}")" ]] || {
    echo "The installed extension root changed during restart health checking." >&2
    exit 1
  }

  local accepted_at receipt_sha state_temp journal_file
  accepted_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  receipt_sha="$(shasum -a 256 "${receipt_file}" | awk '{print $1}')"
  state_temp="${state_file}.tmp"
  jq \
    --arg accepted_at "${accepted_at}" \
    --arg receipt_sha "${receipt_sha}" '
      .status = "accepted"
      | .health = {accepted_at: $accepted_at, receipt_sha256: $receipt_sha}
    ' "${state_file}" > "${state_temp}"
  chmod 600 "${state_temp}"
  mv "${state_temp}" "${state_file}"
  journal_file="${state_root}/promotion-transaction.json"
  if [[ -f "${journal_file}" && ! -L "${journal_file}" ]]; then
    jq --arg accepted_at "${accepted_at}" '.status = "accepted" | .accepted_at = $accepted_at' \
      "${journal_file}" > "${journal_file}.tmp"
    mv "${journal_file}.tmp" "${journal_file}"
  fi
  echo "Accepted installed release set ${active_id} after full restart health checks."
}

rollback_command() {
  local layout_file=""
  local confirmation=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --layout) [[ $# -ge 2 ]] || usage; layout_file="$2"; shift ;;
      --confirm-release-set) [[ $# -ge 2 ]] || usage; confirmation="$2"; shift ;;
      *) usage ;;
    esac
    shift
  done
  [[ -n "${layout_file}" ]] || usage
  validate_install_layout "${layout_file}"

  local state_root state_file previous_parent active_id restore_id snapshot_root
  state_root="$(layout_value "${layout_file}" '.state_root')"
  previous_parent="$(layout_value "${layout_file}" '.previous_root')"
  state_file="${state_root}/installed-release-set.json"
  require_plain_file "${state_file}" "Installed release-set state"
  jq -e '.schema_version == 1 and (.status == "accepted" or .status == "pending-health-check")' \
    "${state_file}" >/dev/null || {
    echo "The installed release set has no active promotion to roll back." >&2
    exit 1
  }
  active_id="$(jq -er '.active.release_set_id' "${state_file}")"
  restore_id="$(jq -er '.previous.release_set_id' "${state_file}")"
  snapshot_root="$(jq -er '.previous.snapshot_path' "${state_file}")"
  [[ "${confirmation}" == "${restore_id}" ]] || {
    echo "Rollback requires --confirm-release-set ${restore_id}." >&2
    exit 1
  }
  assert_app_stopped

  local previous_parent_absolute snapshot_parent_absolute
  previous_parent_absolute="$(cd "${previous_parent}" && pwd -P)"
  require_plain_directory "${snapshot_root}" "Previous release-set snapshot"
  snapshot_parent_absolute="$(cd "$(dirname "${snapshot_root}")" && pwd -P)"
  [[ "${snapshot_parent_absolute}" == "${previous_parent_absolute}" ]] || {
    echo "The recorded previous set is outside the private rollback root." >&2
    exit 1
  }
  local snapshot_set="${snapshot_root}/release-set.json"
  require_release_set "${snapshot_set}" "Previous"
  [[ "$(jq -er '.release.release_set_id' "${snapshot_set}")" == "${restore_id}" ]] || {
    echo "The previous snapshot belongs to another release set." >&2
    exit 1
  }
  assert_installed_matches_set \
    "${snapshot_set}" \
    "${snapshot_root}/${APP_NAME}.app" \
    "${snapshot_root}/build-manifest.json" \
    "${snapshot_root}/profile/user-data" \
    "${snapshot_root}/profile/extensions" \
    "${snapshot_root}/profile/shared-data"

  local target_app target_manifest target_user_data target_extensions target_shared_data
  target_app="$(layout_value "${layout_file}" '.targets.app')"
  target_manifest="$(layout_value "${layout_file}" '.targets.build_manifest')"
  target_user_data="$(layout_value "${layout_file}" '.targets.user_data')"
  target_extensions="$(layout_value "${layout_file}" '.targets.extensions')"
  target_shared_data="$(layout_value "${layout_file}" '.targets.shared_data')"
  require_plain_directory "${target_app}" "Active app"
  require_plain_file "${target_manifest}" "Active manifest"
  require_plain_directory "${target_user_data}" "Active user-data profile"
  require_plain_directory "${target_extensions}" "Active extension root"
  require_plain_directory "${target_shared_data}" "Active shared-data profile"
  [[ "$(artifact_digest "${target_app}")" == "$(jq -er '.active.app_sha256' "${state_file}")" ]] || {
    echo "The active app changed before rollback." >&2
    exit 1
  }
  [[ "$(shasum -a 256 "${target_manifest}" | awk '{print $1}')" == \
    "$(jq -er '.active.build_manifest_sha256' "${state_file}")" ]] || {
    echo "The active manifest changed before rollback." >&2
    exit 1
  }
  [[ "$(directory_content_digest "${target_extensions}")" == "$(jq -er '.active.extensions_sha256' "${state_file}")" ]] || {
    echo "The active extension root changed before rollback." >&2
    exit 1
  }

  local transaction_id replaced_snapshot
  transaction_id="$(date -u +'%Y%m%dT%H%M%SZ')-$$"
  replaced_snapshot="${previous_parent}/${active_id}-before-rollback-${transaction_id}"
  [[ ! -e "${replaced_snapshot}" && ! -L "${replaced_snapshot}" ]] || {
    echo "The active-set safety snapshot already exists." >&2
    exit 1
  }
  mkdir -p "${replaced_snapshot}/profile"
  clone_path "${target_app}" "${replaced_snapshot}/${APP_NAME}.app"
  clone_path "${target_manifest}" "${replaced_snapshot}/build-manifest.json"
  clone_path "${target_user_data}" "${replaced_snapshot}/profile/user-data"
  clone_path "${target_extensions}" "${replaced_snapshot}/profile/extensions"
  clone_path "${target_shared_data}" "${replaced_snapshot}/profile/shared-data"
  jq -n \
    --arg captured_at "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --arg release_set_id "${active_id}" \
    --arg app_sha "$(artifact_digest "${replaced_snapshot}/${APP_NAME}.app")" \
    --arg manifest_sha "$(shasum -a 256 "${replaced_snapshot}/build-manifest.json" | awk '{print $1}')" \
    --arg user_data_sha "$(directory_content_digest "${replaced_snapshot}/profile/user-data")" \
    --arg extensions_sha "$(directory_content_digest "${replaced_snapshot}/profile/extensions")" \
    --arg shared_data_sha "$(directory_content_digest "${replaced_snapshot}/profile/shared-data")" '
      {
        schema_version: 1,
        captured_at: $captured_at,
        release_set_id: $release_set_id,
        app_sha256: $app_sha,
        build_manifest_sha256: $manifest_sha,
        user_data_sha256: $user_data_sha,
        extensions_sha256: $extensions_sha,
        shared_data_sha256: $shared_data_sha
      }
    ' > "${replaced_snapshot}/replaced-set.json"
  chmod -R go-rwx "${replaced_snapshot}"
  chmod 700 "${replaced_snapshot}"

  local incoming_app_root incoming_manifest_root incoming_user_data_root incoming_extensions_root incoming_shared_data_root
  local incoming_app incoming_manifest incoming_user_data incoming_extensions incoming_shared_data
  incoming_app_root="${target_app}.incoming-${transaction_id}"
  incoming_manifest_root="${target_manifest}.incoming-${transaction_id}"
  incoming_user_data_root="${target_user_data}.incoming-${transaction_id}"
  incoming_extensions_root="${target_extensions}.incoming-${transaction_id}"
  incoming_shared_data_root="${target_shared_data}.incoming-${transaction_id}"
  mkdir -p \
    "${incoming_app_root}" \
    "${incoming_manifest_root}" \
    "${incoming_user_data_root}" \
    "${incoming_extensions_root}" \
    "${incoming_shared_data_root}"
  incoming_app="${incoming_app_root}/$(basename "${target_app}")"
  incoming_manifest="${incoming_manifest_root}/$(basename "${target_manifest}")"
  incoming_user_data="${incoming_user_data_root}/$(basename "${target_user_data}")"
  incoming_extensions="${incoming_extensions_root}/$(basename "${target_extensions}")"
  incoming_shared_data="${incoming_shared_data_root}/$(basename "${target_shared_data}")"
  clone_path "${snapshot_root}/${APP_NAME}.app" "${incoming_app}"
  clone_path "${snapshot_root}/build-manifest.json" "${incoming_manifest}"
  clone_path "${snapshot_root}/profile/user-data" "${incoming_user_data}"
  clone_path "${snapshot_root}/profile/extensions" "${incoming_extensions}"
  clone_path "${snapshot_root}/profile/shared-data" "${incoming_shared_data}"

  local targets incoming_paths incoming_roots outgoing_paths
  targets=("${target_app}" "${target_manifest}" "${target_extensions}" "${target_user_data}" "${target_shared_data}")
  incoming_paths=("${incoming_app}" "${incoming_manifest}" "${incoming_extensions}" "${incoming_user_data}" "${incoming_shared_data}")
  incoming_roots=("${incoming_app_root}" "${incoming_manifest_root}" "${incoming_extensions_root}" "${incoming_user_data_root}" "${incoming_shared_data_root}")
  outgoing_paths=(
    "${target_app}.outgoing-${transaction_id}"
    "${target_manifest}.outgoing-${transaction_id}"
    "${target_extensions}.outgoing-${transaction_id}"
    "${target_user_data}.outgoing-${transaction_id}"
    "${target_shared_data}.outgoing-${transaction_id}"
  )
  local journal_file="${state_root}/rollback-transaction.json"
  jq -n \
    --arg transaction_id "${transaction_id}" \
    --arg active_release_set_id "${active_id}" \
    --arg restore_release_set_id "${restore_id}" \
    --arg restore_snapshot_path "${snapshot_root}" \
    --arg replaced_snapshot_path "${replaced_snapshot}" '
      {
        schema_version: 1,
        transaction_id: $transaction_id,
        status: "restoring",
        active_release_set_id: $active_release_set_id,
        restore_release_set_id: $restore_release_set_id,
        restore_snapshot_path: $restore_snapshot_path,
        replaced_snapshot_path: $replaced_snapshot_path
      }
    ' > "${journal_file}"
  chmod 600 "${journal_file}"

  local moved_out_count=0 swapped_count=0 swap_failed="false" index reverse_index
  for index in 0 1 2 3 4; do
    if ! mv "${targets[$index]}" "${outgoing_paths[$index]}"; then
      swap_failed="true"
      break
    fi
    moved_out_count=$((moved_out_count + 1))
    if [[ "${DBCODE_WRAPPER_TEST_FAIL_ROLLBACK_AFTER_TARGET_MOVE:-}" == "${moved_out_count}" ]]; then
      swap_failed="true"
      break
    fi
    if ! mv "${incoming_paths[$index]}" "${targets[$index]}"; then
      swap_failed="true"
      break
    fi
    swapped_count=$((swapped_count + 1))
    if [[ "${DBCODE_WRAPPER_TEST_FAIL_ROLLBACK_AFTER_SWAP:-}" == "${swapped_count}" ]]; then
      swap_failed="true"
      break
    fi
  done

  if [[ "${swap_failed}" == "true" ]]; then
    local recovery_incomplete="false"
    for ((reverse_index = moved_out_count - 1; reverse_index >= 0; reverse_index--)); do
      local failed_path="${targets[$reverse_index]}.failed-${transaction_id}"
      if [[ -e "${targets[$reverse_index]}" || -L "${targets[$reverse_index]}" ]]; then
        mv "${targets[$reverse_index]}" "${failed_path}" || recovery_incomplete="true"
      fi
      if [[ -e "${outgoing_paths[$reverse_index]}" || -L "${outgoing_paths[$reverse_index]}" ]]; then
        mv "${outgoing_paths[$reverse_index]}" "${targets[$reverse_index]}" || recovery_incomplete="true"
      else
        recovery_incomplete="true"
      fi
      [[ ! -e "${failed_path}" ]] || safe_remove_transaction_path "${failed_path}" "${transaction_id}"
    done
    for index in 0 1 2 3 4; do
      [[ ! -e "${incoming_roots[$index]}" ]] || safe_remove_transaction_path "${incoming_roots[$index]}" "${transaction_id}"
      if [[ -e "${outgoing_paths[$index]}" || -L "${outgoing_paths[$index]}" ]]; then
        recovery_incomplete="true"
      fi
    done
    if [[ "${recovery_incomplete}" == "true" ]]; then
      jq '.status = "recovery-incomplete-after-failed-rollback"' "${journal_file}" > "${journal_file}.tmp"
      mv "${journal_file}.tmp" "${journal_file}"
      echo "Rollback failed and automatic recovery is incomplete. Preserved outgoing paths are recorded in ${journal_file}." >&2
      exit 1
    fi
    jq '.status = "restored-active-set-after-failed-rollback"' "${journal_file}" > "${journal_file}.tmp"
    mv "${journal_file}.tmp" "${journal_file}"
    echo "Rollback failed and the active release set was restored." >&2
    exit 1
  fi

  assert_installed_matches_set \
    "${snapshot_set}" \
    "${target_app}" \
    "${target_manifest}" \
    "${target_user_data}" \
    "${target_extensions}" \
    "${target_shared_data}"

  local rolled_back_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  jq \
    --arg rolled_back_at "${rolled_back_at}" \
    --arg active_id "${restore_id}" \
    --arg active_set_sha "$(shasum -a 256 "${snapshot_set}" | awk '{print $1}')" \
    --arg app_sha "$(artifact_digest "${target_app}")" \
    --arg manifest_sha "$(shasum -a 256 "${target_manifest}" | awk '{print $1}')" \
    --arg user_data_sha "$(directory_content_digest "${target_user_data}")" \
    --arg extensions_sha "$(directory_content_digest "${target_extensions}")" \
    --arg shared_data_sha "$(directory_content_digest "${target_shared_data}")" \
    --arg rolled_back_from_id "${active_id}" \
    --arg replaced_snapshot "${replaced_snapshot}" '
      .status = "rolled-back"
      | .rolled_back_at = $rolled_back_at
      | .rolled_back_from = {
          release_set_id: $rolled_back_from_id,
          snapshot_path: $replaced_snapshot
        }
      | .active = {
          release_set_id: $active_id,
          release_set_sha256: $active_set_sha,
          app_sha256: $app_sha,
          build_manifest_sha256: $manifest_sha,
          user_data_sha256: $user_data_sha,
          extensions_sha256: $extensions_sha,
          shared_data_sha256: $shared_data_sha
        }
      | del(.health)
    ' "${state_file}" > "${state_file}.tmp"
  chmod 600 "${state_file}.tmp"
  mv "${state_file}.tmp" "${state_file}"
  jq --arg rolled_back_at "${rolled_back_at}" '.status = "rolled-back" | .rolled_back_at = $rolled_back_at' \
    "${journal_file}" > "${journal_file}.tmp"
  mv "${journal_file}.tmp" "${journal_file}"

  for index in 0 1 2 3 4; do
    safe_remove_transaction_path "${outgoing_paths[$index]}" "${transaction_id}"
    safe_remove_transaction_path "${incoming_roots[$index]}" "${transaction_id}"
  done
  echo "Rolled back the complete installed set to ${restore_id}."
}

require_release_set() {
  local release_set_file="$1"
  local label="$2"

  if ! approved_release_set_validate "${release_set_file}" >/dev/null; then
    echo "${label} release-set record is incomplete or invalid: ${release_set_file}" >&2
    exit 1
  fi
}

matrix_command() {
  local current_set=""
  local candidate_set=""
  local output_file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --current-set)
        [[ $# -ge 2 ]] || usage
        current_set="$2"
        shift
        ;;
      --candidate-set)
        [[ $# -ge 2 ]] || usage
        candidate_set="$2"
        shift
        ;;
      --output)
        [[ $# -ge 2 ]] || usage
        output_file="$2"
        shift
        ;;
      *) usage ;;
    esac
    shift
  done

  [[ -n "${current_set}" && -n "${candidate_set}" && -n "${output_file}" ]] || usage
  require_release_set "${current_set}" "Current"
  require_release_set "${candidate_set}" "Candidate"
  [[ ! -L "${output_file}" ]] || {
    echo "Refusing a symlinked matrix output: ${output_file}" >&2
    exit 1
  }

  local gate_command="${DBCODE_WRAPPER_COMBINATION_GATE:-${REPO_ROOT}/script/check_release_combination.sh}"
  [[ -f "${gate_command}" && ! -L "${gate_command}" && -x "${gate_command}" ]] || {
    echo "The release-combination gate is missing or unsafe: ${gate_command}" >&2
    exit 1
  }

  local output_parent
  output_parent="$(cd "$(dirname "${output_file}")" && pwd)"
  local receipt_root
  receipt_root="$(mktemp -d "${output_parent}/.compatibility-matrix.XXXXXX")"
  cleanup_receipt_root() {
    [[ -n "${receipt_root:-}" ]] || return 0
    case "${receipt_root}" in
      "${output_parent}/.compatibility-matrix."*) rm -rf "${receipt_root}" ;;
      *) echo "Refusing to remove unexpected matrix staging path: ${receipt_root}" >&2; return 1 ;;
    esac
    receipt_root=""
  }
  trap cleanup_receipt_root EXIT INT TERM

  local combination host_set dbcode_set receipt_file gate_status
  for combination in H0/D0 H0/D1 H1/D0 H1/D1; do
    case "${combination}" in
      H0/D0) host_set="${current_set}"; dbcode_set="${current_set}" ;;
      H0/D1) host_set="${current_set}"; dbcode_set="${candidate_set}" ;;
      H1/D0) host_set="${candidate_set}"; dbcode_set="${current_set}" ;;
      H1/D1) host_set="${candidate_set}"; dbcode_set="${candidate_set}" ;;
      *) echo "Unsupported compatibility combination: ${combination}" >&2; exit 1 ;;
    esac
    receipt_file="${receipt_root}/${combination//\//-}.json"
    gate_status=0
    "${gate_command}" \
      --combination "${combination}" \
      --host-set "${host_set}" \
      --dbcode-set "${dbcode_set}" \
      --output "${receipt_file}" || gate_status=$?

    [[ -f "${receipt_file}" && ! -L "${receipt_file}" ]] || {
      echo "The ${combination} gate did not produce an independent receipt." >&2
      exit 1
    }

    local expected_host_release expected_host_sha expected_dbcode_id
    local expected_dbcode_version expected_dbcode_sha receipt_status
    expected_host_release="$(jq -er '.release.release_set_id' "${host_set}")"
    expected_host_sha="$(jq -er '.host.app_sha256' "${host_set}")"
    expected_dbcode_id="$(jq -er '.dbcode.id' "${dbcode_set}")"
    expected_dbcode_version="$(jq -er '.dbcode.version' "${dbcode_set}")"
    expected_dbcode_sha="$(jq -er '.dbcode.vsix_sha256' "${dbcode_set}")"

    jq -e \
      --arg combination "${combination}" \
      --arg host_release "${expected_host_release}" \
      --arg host_sha "${expected_host_sha}" \
      --arg dbcode_id "${expected_dbcode_id}" \
      --arg dbcode_version "${expected_dbcode_version}" \
      --arg dbcode_sha "${expected_dbcode_sha}" '
        .schema_version == 1
        and .combination == $combination
        and .host.release_set_id == $host_release
        and .host.app_sha256 == $host_sha
        and .dbcode.id == $dbcode_id
        and .dbcode.version == $dbcode_version
        and .dbcode.vsix_sha256 == $dbcode_sha
        and (.status == "passed" or .status == "failed")
        and (.checks.static == "passed" or .checks.static == "failed")
        and (.checks.runtime == "passed" or .checks.runtime == "failed")
        and (.checks.bundle_unchanged | type == "boolean")
        and (.checks.surprise_update_absent | type == "boolean")
      ' "${receipt_file}" >/dev/null || {
      echo "The ${combination} receipt is incomplete or belongs to another pairing." >&2
      exit 1
    }

    receipt_status="$(jq -er '.status' "${receipt_file}")"
    if [[ "${gate_status}" -eq 0 && "${receipt_status}" != "passed" ]] || \
      [[ "${gate_status}" -ne 0 && "${receipt_status}" != "failed" ]]; then
      echo "The ${combination} gate exit status disagrees with its receipt." >&2
      exit 1
    fi
  done

  local current_release candidate_release current_sha candidate_sha
  current_release="$(jq -er '.release.release_set_id' "${current_set}")"
  candidate_release="$(jq -er '.release.release_set_id' "${candidate_set}")"
  current_sha="$(shasum -a 256 "${current_set}" | awk '{print $1}')"
  candidate_sha="$(shasum -a 256 "${candidate_set}" | awk '{print $1}')"

  local matrix_temp="${receipt_root}/matrix.json"
  jq -n \
    --arg created_at_utc "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --arg current_release_set_id "${current_release}" \
    --arg candidate_release_set_id "${candidate_release}" \
    --arg current_release_set_sha256 "${current_sha}" \
    --arg candidate_release_set_sha256 "${candidate_sha}" \
    --slurpfile h0d0 "${receipt_root}/H0-D0.json" \
    --slurpfile h0d1 "${receipt_root}/H0-D1.json" \
    --slurpfile h1d0 "${receipt_root}/H1-D0.json" \
    --slurpfile h1d1 "${receipt_root}/H1-D1.json" '
      [$h0d0[0], $h0d1[0], $h1d0[0], $h1d1[0]] as $combinations
      | all($combinations[]; .status == "passed") as $promotion_ready
      | {
          schema_version: 1,
          created_at_utc: $created_at_utc,
          current_release_set_id: $current_release_set_id,
          candidate_release_set_id: $candidate_release_set_id,
          current_release_set_sha256: $current_release_set_sha256,
          candidate_release_set_sha256: $candidate_release_set_sha256,
          combinations: $combinations,
          promotion_ready: $promotion_ready,
          status: (if $promotion_ready then "passed" else "failed" end)
        }
    ' > "${matrix_temp}"
  mv "${matrix_temp}" "${output_file}"
  chmod 600 "${output_file}"

  local matrix_status
  matrix_status="$(jq -er '.status' "${output_file}")"
  if [[ "${matrix_status}" != "passed" ]]; then
    echo "Compatibility matrix completed, but at least one required pairing failed: ${output_file}" >&2
    return 1
  fi
  echo "Compatibility matrix passed with four independent receipts: ${output_file}"
}

command_name="${1:-}"
[[ -n "${command_name}" ]] || usage
shift
case "${command_name}" in
  prepare-set) prepare_set_command "$@" ;;
  matrix) matrix_command "$@" ;;
  promote) promote_command "$@" ;;
  health) health_command "$@" ;;
  rollback) rollback_command "$@" ;;
  *) usage ;;
esac
