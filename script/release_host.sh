#!/usr/bin/env bash

set -euo pipefail
umask 077

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<'EOF'
Usage:
  ./script/release_host.sh plan
  ./script/release_host.sh prepare
  ./script/release_host.sh publish --publish

The prepare action checks signing readiness, builds or reuses one complete Host
checkpoint, runs static and one-profile rendered smoke, performs final prompt-free
acceptance, creates or verifies the annotated source tag, packages and independently
verifies the host, and records approval. It leaves one approval-history change to
commit. Publication remains a separate explicit action.
EOF
  exit 2
}

action="${1:-}"
[[ -n "${action}" ]] || usage
shift

publish_confirmed="no"
case "${action}" in
  plan|prepare)
    [[ $# -eq 0 ]] || usage
    ;;
  publish)
    [[ $# -eq 1 && "$1" == "--publish" ]] || usage
    publish_confirmed="yes"
    ;;
  *)
    usage
    ;;
esac

source "${script_root}/lib/host_config.sh"
source "${script_root}/lib/generated_workspace.sh"
source "${script_root}/lib/approved_release_set.sh"
source "${script_root}/lib/dist_checkpoint.sh"

release_tag="v${WRAPPER_VERSION}"
rendered_output_root="$(generated_workspace_path "rendered-screenshots")"
acceptance_root="$(generated_workspace_path "acceptance-evidence")"
assets_root="$(generated_workspace_path "host-release-assets")"

rendered_report="${rendered_output_root}/focused-shell-rendered-report.json"
acceptance_file="${acceptance_root}/fast-release/${release_tag}/final-acceptance-report.json"
assets_dir="${assets_root}/${release_tag}"
approval_dir="${acceptance_root}/fast-release/${release_tag}-approval"
approved_history="${REPO_ROOT}/host/approved-release-history.json"
approved_history_candidate="${approval_dir}/approved-release-sets.json"

release_prepare_checkpoint() {
  local exit_status=$?
  trap - EXIT INT TERM
  if ! dist_checkpoint_release; then
    [[ "${exit_status}" -ne 0 ]] || exit_status=1
  fi
  exit "${exit_status}"
}

write_plan() {
  jq -n \
    --arg release_tag "${release_tag}" \
    --arg source_repository "${REPO_ROOT}" \
    --arg app "${APP_BUNDLE}" \
    --arg manifest "${BUILD_MANIFEST}" \
    --arg release_lock "${LOCK_FILE}" \
    --arg rendered_report "${rendered_report}" \
    --arg acceptance "${acceptance_file}" \
    --arg assets "${assets_dir}" \
    --arg approval "${approval_dir}" \
    --arg approved_history_candidate "${approved_history_candidate}" \
    --arg approved_history "${approved_history}" '
      {
        schema_version: 1,
        release_tag: $release_tag,
        source_repository: $source_repository,
        paths: {
          app: $app,
          manifest: $manifest,
          release_lock: $release_lock,
          rendered_report: $rendered_report,
          acceptance: $acceptance,
          assets: $assets,
          approval: $approval,
          approved_history_candidate: $approved_history_candidate,
          approved_history: $approved_history
        },
        stages: ["preflight", "build", "static", "render", "accept", "tag", "package", "approve", "record", "publish"],
        signing_preflight_prompt_free: true,
        build_owned_by_prepare: true,
        rendered_smoke_owned_by_prepare: true,
        dist_checkpoint_serialized: true,
        tag_created_after_acceptance: true,
        approval_history_commit_required: true,
        exact_evidence_resume_supported: true,
        explicit_publish_required: true,
        automatic_publish: false
      }
    '
}

assert_plain_file() {
  local file="$1"
  local label="$2"
  [[ -f "${file}" && ! -L "${file}" ]] || {
    echo "${label} is missing or unsafe: ${file}" >&2
    exit 1
  }
}

assert_plain_directory() {
  local directory="$1"
  local label="$2"
  [[ -d "${directory}" && ! -L "${directory}" ]] || {
    echo "${label} is missing or unsafe: ${directory}" >&2
    exit 1
  }
}

run_signing_preflight() {
  "${script_root}/setup_local_signing_identity.sh" --status
}

build_matches_current_source() {
  local current_revision
  [[ -d "${APP_BUNDLE}" && ! -L "${APP_BUNDLE}" ]] || return 1
  [[ -f "${BUILD_MANIFEST}" && ! -L "${BUILD_MANIFEST}" ]] || return 1
  current_revision="$(git -C "${REPO_ROOT}" rev-parse 'HEAD^{commit}')"
  jq -e \
    --arg current_revision "${current_revision}" \
    '.source.snapshot.repository_revision == $current_revision' \
    "${BUILD_MANIFEST}" >/dev/null 2>&1
}

ensure_build() {
  if build_matches_current_source; then
    run_signing_preflight
    echo "Reusing the exact signed Host checkpoint: ${APP_BUNDLE}"
  else
    "${script_root}/build_host.sh"
  fi
  assert_plain_directory "${APP_BUNDLE}" "The signed Host application"
  assert_plain_file "${BUILD_MANIFEST}" "The build manifest"
  build_matches_current_source || {
    echo "The signed Host checkpoint does not describe the current source commit." >&2
    exit 1
  }
}

run_static_smoke() {
  "${script_root}/smoke_host.sh"
}

rendered_report_matches_build() {
  local release_set_id
  [[ -f "${rendered_report}" && ! -L "${rendered_report}" ]] || return 1
  release_set_id="$(jq -er '.release.release_set_id' "${BUILD_MANIFEST}")" || return 1
  jq -e \
    --arg release_set_id "${release_set_id}" '
      .status == "passed"
      and .mode == "smoke"
      and .releaseSetId == $release_set_id
      and .profile.name == "qa"
      and .profile.persistent == true
      and .errors == []
    ' "${rendered_report}" >/dev/null 2>&1
}

ensure_rendered_smoke() {
  if rendered_report_matches_build; then
    echo "Reusing exact one-profile rendered evidence: ${rendered_report}"
  else
    "${script_root}/test_focused_shell_rendered.sh"
  fi
  rendered_report_matches_build || {
    echo "The one-profile rendered report does not match the signed Host checkpoint." >&2
    exit 1
  }
}

run_acceptance() {
  "${script_root}/verify_fast_release.sh" \
    --app "${APP_BUNDLE}" \
    --manifest "${BUILD_MANIFEST}" \
    --release-lock "${LOCK_FILE}" \
    --rendered-report "${rendered_report}" \
    --output "${acceptance_file}"
}

validate_acceptance() {
  "${script_root}/host_release_contract.sh" \
    prompt-free-acceptance-record \
    "${BUILD_MANIFEST}" \
    "${LOCK_FILE}" \
    "${acceptance_file}" >/dev/null
}

create_or_verify_tag() {
  assert_plain_file "${BUILD_MANIFEST}" "The build manifest"
  assert_plain_file "${acceptance_file}" "The prompt-free acceptance report"

  local source_revision tag_object tag_commit
  source_revision="$(jq -er '.source.snapshot.repository_revision' "${BUILD_MANIFEST}")"

  [[ "$(git -C "${REPO_ROOT}" branch --show-current)" == "main" ]] || {
    echo "The release source tag must be created from main." >&2
    exit 1
  }

  if tag_object="$(git -C "${REPO_ROOT}" rev-parse --verify "refs/tags/${release_tag}" 2>/dev/null)"; then
    [[ "$(git -C "${REPO_ROOT}" cat-file -t "${tag_object}")" == "tag" ]] || {
      echo "The existing source tag is not annotated: ${release_tag}" >&2
      exit 1
    }
    tag_commit="$(git -C "${REPO_ROOT}" rev-parse "${release_tag}^{commit}")"
    [[ "${tag_commit}" == "${source_revision}" ]] || {
      echo "The immutable source tag identifies another commit: ${release_tag}" >&2
      exit 1
    }
    git -C "${REPO_ROOT}" merge-base --is-ancestor "${source_revision}" main || {
      echo "The immutable source tag is not contained in main: ${release_tag}" >&2
      exit 1
    }
    echo "Verified existing annotated source tag ${release_tag}."
    return
  fi

  [[ -z "$(git -C "${REPO_ROOT}" status --porcelain)" ]] || {
    echo "The release source must be clean before creating its tag." >&2
    exit 1
  }
  [[ "$(git -C "${REPO_ROOT}" rev-parse HEAD)" == "${source_revision}" ]] || {
    echo "The build manifest does not describe the current release commit." >&2
    exit 1
  }

  git -C "${REPO_ROOT}" tag \
    -a "${release_tag}" \
    -m "DBCode Wrapper ${release_tag}"
  echo "Created annotated source tag ${release_tag}."
}

run_package() {
  "${script_root}/package_host_release.sh" \
    --app "${APP_BUNDLE}" \
    --manifest "${BUILD_MANIFEST}" \
    --release-lock "${LOCK_FILE}" \
    --acceptance "${acceptance_file}" \
    --source-repository "${REPO_ROOT}" \
    --source-tag "${release_tag}" \
    --output-dir "${assets_dir}"
}

one_release_asset() {
  local pattern="$1"
  local label="$2"
  local -a matches=()
  local candidate

  while IFS= read -r -d '' candidate; do
    matches+=("${candidate}")
  done < <(
    find "${assets_dir}" \
      -mindepth 1 \
      -maxdepth 1 \
      -type f \
      -name "${pattern}" \
      -print0
  )
  [[ "${#matches[@]}" -eq 1 ]] || {
    echo "Expected one ${label} under ${assets_dir}; found ${#matches[@]}." >&2
    exit 1
  }
  printf '%s\n' "${matches[0]}"
}

validate_release_assets() {
  local dmg_file checksum_file compatibility_file notes_file verification_file
  local entry entry_count dmg_sha256 dmg_size_bytes notes_sha256 expected_checksum

  [[ -d "${assets_dir}" && ! -L "${assets_dir}" ]] || {
    echo "The Host Release asset directory is missing or unsafe: ${assets_dir}" >&2
    exit 1
  }
  entry_count="$(
    find "${assets_dir}" -mindepth 1 -maxdepth 1 -print |
      wc -l |
      tr -d '[:space:]'
  )"
  [[ "${entry_count}" == "5" ]] || {
    echo "The Host Release asset directory must contain exactly five files." >&2
    exit 1
  }
  while IFS= read -r -d '' entry; do
    [[ -f "${entry}" && ! -L "${entry}" ]] || {
      echo "The Host Release asset is missing or unsafe: ${entry}" >&2
      exit 1
    }
  done < <(find "${assets_dir}" -mindepth 1 -maxdepth 1 -print0)

  dmg_file="$(one_release_asset '*.dmg' 'host DMG')"
  checksum_file="$(one_release_asset '*.dmg.sha256' 'host DMG checksum')"
  compatibility_file="$(one_release_asset '*-compatibility.json' 'compatibility manifest')"
  notes_file="$(one_release_asset '*-install-and-rollback.txt' 'install and rollback notes')"
  verification_file="$(one_release_asset '*-verification.json' 'verification receipt')"

  jq -e . "${verification_file}" >/dev/null || {
    echo "The Host Release verification receipt is not valid JSON." >&2
    exit 1
  }
  dmg_sha256="$(shasum -a 256 "${dmg_file}" | awk '{print $1}')"
  dmg_size_bytes="$(stat -f '%z' "${dmg_file}")"
  notes_sha256="$(shasum -a 256 "${notes_file}" | awk '{print $1}')"
  jq -e \
    --arg dmg_name "$(basename "${dmg_file}")" \
    --arg dmg_sha256 "${dmg_sha256}" \
    --argjson dmg_size_bytes "${dmg_size_bytes}" \
    --arg checksum_name "$(basename "${checksum_file}")" \
    --arg compatibility_name "$(basename "${compatibility_file}")" \
    --arg notes_name "$(basename "${notes_file}")" \
    --arg notes_sha256 "${notes_sha256}" \
    --arg verification_name "$(basename "${verification_file}")" '
      .schema_version == 1
      and .disk_image.filename == $dmg_name
      and .disk_image.sha256 == $dmg_sha256
      and .disk_image.size_bytes == $dmg_size_bytes
      and .disk_image.install_guide_sha256 == $notes_sha256
      and .assets.checksum == $checksum_name
      and .assets.compatibility == $compatibility_name
      and .assets.install_and_rollback == $notes_name
      and .assets.verification == $verification_name
    ' "${compatibility_file}" >/dev/null || {
    echo "The Host Release assets do not match their compatibility manifest." >&2
    exit 1
  }
  expected_checksum="${dmg_sha256}  $(basename "${dmg_file}")"
  [[ "$(<"${checksum_file}")" == "${expected_checksum}" ]] || {
    echo "The Host Release checksum does not cover the exact disk image." >&2
    exit 1
  }
}

run_approval() {
  local release_set_id dmg_file compatibility_file verification_file
  release_set_id="$(jq -er '.release.release_set_id' "${BUILD_MANIFEST}")"
  dmg_file="$(one_release_asset '*.dmg' 'host DMG')"
  compatibility_file="$(one_release_asset '*-compatibility.json' 'compatibility manifest')"
  verification_file="$(one_release_asset '*-verification.json' 'verification receipt')"

  "${script_root}/approve_host_release.sh" \
    --manifest "${BUILD_MANIFEST}" \
    --release-lock "${LOCK_FILE}" \
    --acceptance "${acceptance_file}" \
    --dmg "${dmg_file}" \
    --compatibility "${compatibility_file}" \
    --verification "${verification_file}" \
    --source-repository "${REPO_ROOT}" \
    --source-tag "${release_tag}" \
    --history "${approved_history}" \
    --confirm-release-set "${release_set_id}" \
    --output-dir "${approval_dir}"
}

assert_approved() {
  local attestation="${approval_dir}/approval-attestation.json"
  local approved_record="${approval_dir}/approved-release-set.json"
  local compatibility_file verification_file
  assert_plain_file "${attestation}" "The Host Release approval attestation"
  assert_plain_file "${approved_record}" "The approved release record"
  assert_plain_file "${approved_history_candidate}" "The generated Approved Release Set history"
  approved_release_set_validate_recorded_approval \
    "${BUILD_MANIFEST}" \
    "${LOCK_FILE}" \
    "${attestation}" \
    "${approved_record}" \
    "${approved_history_candidate}" \
    "${release_tag}"

  compatibility_file="$(one_release_asset '*-compatibility.json' 'compatibility manifest')"
  verification_file="$(one_release_asset '*-verification.json' 'verification receipt')"
  jq -e \
    --arg compatibility_sha256 "$(shasum -a 256 "${compatibility_file}" | awk '{print $1}')" \
    --arg verification_sha256 "$(shasum -a 256 "${verification_file}" | awk '{print $1}')" '
      .compatibility_manifest_sha256 == $compatibility_sha256
      and .verification_sha256 == $verification_sha256
    ' "${attestation}" >/dev/null || {
    echo "The approval does not bind the current Host Release assets." >&2
    exit 1
  }
}

record_approved_history() {
  local approved_record="${approval_dir}/approved-release-set.json"

  assert_plain_file "${approved_history}" "The tracked Approved Release Set history"
  assert_plain_file "${approved_record}" "The approved release record"
  assert_plain_file "${approved_history_candidate}" "The generated Approved Release Set history"

  approved_release_history_record_approval \
    "${approved_history}" \
    "${approved_record}" \
    "${approved_history_candidate}" \
    "${approved_history}"

  echo "Recorded the exact approval in host/approved-release-history.json."
}

case "${action}" in
  plan)
    write_plan
    ;;
  prepare)
    dist_checkpoint_acquire "host-release-prepare"
    trap release_prepare_checkpoint EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    ensure_build
    run_static_smoke
    ensure_rendered_smoke
    if [[ -e "${acceptance_file}" || -L "${acceptance_file}" ]]; then
      assert_plain_file "${acceptance_file}" "The reusable prompt-free acceptance report"
      echo "Reusing exact prompt-free acceptance evidence: ${acceptance_file}"
    else
      run_acceptance
    fi
    validate_acceptance
    create_or_verify_tag
    if [[ -e "${assets_dir}" || -L "${assets_dir}" ]]; then
      [[ -d "${assets_dir}" && ! -L "${assets_dir}" ]] || {
        echo "The reusable Host Release asset directory is missing or unsafe: ${assets_dir}" >&2
        exit 1
      }
      echo "Reusing exact Host Release assets: ${assets_dir}"
    else
      run_package
    fi
    validate_release_assets
    if [[ -e "${approval_dir}" || -L "${approval_dir}" ]]; then
      [[ -d "${approval_dir}" && ! -L "${approval_dir}" ]] || {
        echo "The reusable Host Release approval directory is missing or unsafe: ${approval_dir}" >&2
        exit 1
      }
      echo "Reusing exact Host Release approval: ${approval_dir}"
    else
      run_approval
    fi
    assert_approved
    record_approved_history
    echo "Prepared and approved ${release_tag}; publication remains separate."
    echo "Record and commit host/approved-release-history.json before publication."
    ;;
  publish)
    [[ "${publish_confirmed}" == "yes" ]] || usage
    assert_approved
    "${script_root}/publish_release.sh" \
      --source-repository "${REPO_ROOT}" \
      --source-tag "${release_tag}" \
      --release-lock "${LOCK_FILE}" \
      --assets-dir "${assets_dir}" \
      --publish
    ;;
esac
