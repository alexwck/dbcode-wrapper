#!/usr/bin/env bash

set -euo pipefail
umask 077

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_root}/lib/host_config.sh"
source "${script_root}/lib/artifact_digest.sh"
source "${script_root}/lib/private_release.sh"
source "${script_root}/lib/approved_release_set.sh"
source "${script_root}/lib/generated_workspace.sh"

app_path=""
manifest_file=""
release_lock=""
acceptance_file=""
dmg_file=""
compatibility_file=""
verification_file=""
source_repository=""
source_tag=""
history_file=""
confirmation=""
output_dir=""

usage() {
  cat >&2 <<'EOF'
Usage: ./script/approve_private_release.sh \
  --app PATH \
  --manifest FILE \
  --release-lock FILE \
  --acceptance FILE \
  --dmg FILE \
  --compatibility FILE \
  --verification FILE \
  --source-repository DIR \
  --source-tag TAG \
  --history FILE \
  --confirm-release-set ID \
  --output-dir DIR
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) [[ $# -ge 2 ]] || usage; app_path="$2"; shift ;;
    --manifest) [[ $# -ge 2 ]] || usage; manifest_file="$2"; shift ;;
    --release-lock) [[ $# -ge 2 ]] || usage; release_lock="$2"; shift ;;
    --acceptance) [[ $# -ge 2 ]] || usage; acceptance_file="$2"; shift ;;
    --dmg) [[ $# -ge 2 ]] || usage; dmg_file="$2"; shift ;;
    --compatibility) [[ $# -ge 2 ]] || usage; compatibility_file="$2"; shift ;;
    --verification) [[ $# -ge 2 ]] || usage; verification_file="$2"; shift ;;
    --source-repository) [[ $# -ge 2 ]] || usage; source_repository="$2"; shift ;;
    --source-tag) [[ $# -ge 2 ]] || usage; source_tag="$2"; shift ;;
    --history) [[ $# -ge 2 ]] || usage; history_file="$2"; shift ;;
    --confirm-release-set) [[ $# -ge 2 ]] || usage; confirmation="$2"; shift ;;
    --output-dir) [[ $# -ge 2 ]] || usage; output_dir="$2"; shift ;;
    *) usage ;;
  esac
  shift
done

[[ -n "${app_path}" && -n "${manifest_file}" && -n "${release_lock}" && \
  -n "${acceptance_file}" && -n "${dmg_file}" && -n "${compatibility_file}" && \
  -n "${verification_file}" && -n "${source_repository}" && -n "${source_tag}" && \
  -n "${history_file}" && -n "${confirmation}" && -n "${output_dir}" ]] || usage

output_dir="$(
  generated_workspace_resolve_path \
    "acceptance-evidence" \
    "${output_dir}" \
    allow-temporary
)"

for command in cmp codesign git jq lipo plutil rg shasum stat; do
  require_command "${command}"
done

private_release_assert_file "${dmg_file}" "The private-release disk image"
private_release_assert_file "${compatibility_file}" "The compatibility manifest"
private_release_assert_file "${verification_file}" "The verification receipt"
private_release_assert_file "${history_file}" "The base Approved Release Set history"
private_release_assert_sanitized_metadata "${compatibility_file}" "${verification_file}"
approved_release_history_validate "${history_file}" >/dev/null

release_set_id="$(jq -er '.release.release_set_id' "${manifest_file}")"
[[ "${confirmation}" == "${release_set_id}" ]] || {
  echo "Approval requires --confirm-release-set ${release_set_id}." >&2
  exit 1
}
[[ "$(jq -er '.schema_version' "${acceptance_file}")" == "3" ]] || {
  echo "Prompt-free approval requires a schema-3 acceptance report." >&2
  exit 1
}
[[ ! -e "${output_dir}" && ! -L "${output_dir}" ]] || {
  echo "Refusing to replace an existing prompt-free approval bundle: ${output_dir}" >&2
  exit 1
}

private_release_validate_sources \
  "${app_path}" \
  "${manifest_file}" \
  "${release_lock}" \
  "${acceptance_file}"
private_release_validate_source_tag \
  "${source_repository}" \
  "${source_tag}" \
  "${manifest_file}" \
  "${release_lock}" >/dev/null

manifest_sha256="$(shasum -a 256 "${manifest_file}" | awk '{print $1}')"
release_lock_sha256="$(shasum -a 256 "${release_lock}" | awk '{print $1}')"
acceptance_sha256="$(shasum -a 256 "${acceptance_file}" | awk '{print $1}')"
compatibility_sha256="$(shasum -a 256 "${compatibility_file}" | awk '{print $1}')"
verification_sha256="$(shasum -a 256 "${verification_file}" | awk '{print $1}')"
dmg_sha256="$(shasum -a 256 "${dmg_file}" | awk '{print $1}')"
dmg_size_bytes="$(stat -f '%z' "${dmg_file}")"

jq -e \
  --arg dmg_name "$(basename "${dmg_file}")" \
  --arg dmg_sha256 "${dmg_sha256}" \
  --argjson dmg_size_bytes "${dmg_size_bytes}" '
    .schema_version == 1
    and .disk_image.filename == $dmg_name
    and .disk_image.sha256 == $dmg_sha256
    and .disk_image.size_bytes == $dmg_size_bytes
    and .disk_image.read_only == true
  ' "${compatibility_file}" >/dev/null || {
  echo "The compatibility manifest does not describe this exact disk image." >&2
  exit 1
}

[[ ! -e "${output_dir}" && ! -L "${output_dir}" ]] || {
  echo "Refusing to replace an existing prompt-free approval bundle: ${output_dir}" >&2
  exit 1
}
output_parent="$(dirname "${output_dir}")"
mkdir -p "${output_parent}"
output_parent="$(cd "${output_parent}" && pwd -P)"
output_name="$(basename "${output_dir}")"
staging_root="$(mktemp -d "${output_parent}/.${output_name}.staging.XXXXXX")"
cleanup_staging_root() {
  [[ -n "${staging_root:-}" ]] || return 0
  case "${staging_root}" in
    "${output_parent}/.${output_name}.staging."*) rm -rf "${staging_root}" ;;
    *)
      echo "Refusing to remove unexpected approval staging path: ${staging_root}" >&2
      return 1
      ;;
  esac
  staging_root=""
}
trap cleanup_staging_root EXIT INT TERM

attestation_file="${staging_root}/approval-attestation.json"
record_file="${staging_root}/approved-release-set.json"
output_history="${staging_root}/approved-release-sets.json"
jq -n \
  --arg approved_at "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --arg release_set_id "${release_set_id}" \
  --arg source_tag "${source_tag}" \
  --arg compatibility_manifest_sha256 "${compatibility_sha256}" \
  --arg candidate_manifest_sha256 "${manifest_sha256}" \
  --arg release_lock_sha256 "${release_lock_sha256}" \
  --arg acceptance_sha256 "${acceptance_sha256}" \
  --arg verification_sha256 "${verification_sha256}" '
    {
      schema_version: 2,
      approved_at: $approved_at,
      release_set_id: $release_set_id,
      source_tag: $source_tag,
      compatibility_manifest_sha256: $compatibility_manifest_sha256,
      candidate_manifest_sha256: $candidate_manifest_sha256,
      release_lock_sha256: $release_lock_sha256,
      acceptance_sha256: $acceptance_sha256,
      verification_sha256: $verification_sha256,
      confirmation: "exact-release-set-id",
      approval_mode: "prompt-free-private-release",
      automatic_install: false,
      privileged_install: false,
      production_profile_written: false,
      installed_app_changed: false
    }
  ' > "${attestation_file}"

approved_release_set_write_prompt_free_approval \
  "${compatibility_file}" \
  "${manifest_file}" \
  "${release_lock}" \
  "${attestation_file}" \
  "${acceptance_file}" \
  "${verification_file}" \
  "${history_file}" \
  "${record_file}" \
  "${output_history}" >/dev/null
approved_release_record_validate "${record_file}" >/dev/null
approved_release_history_validate "${output_history}" >/dev/null
jq -e \
  --arg release_set_id "${release_set_id}" '
    ([.approved_release_sets[] | select(.id == $release_set_id)] | length) == 1
  ' "${output_history}" >/dev/null || {
  echo "The approved history does not contain exactly one copy of this release set." >&2
  exit 1
}
private_release_assert_sanitized_metadata \
  "${attestation_file}" \
  "${record_file}" \
  "${output_history}"
chmod 600 "${attestation_file}" "${record_file}" "${output_history}"

mv "${staging_root}" "${output_dir}"
staging_root=""
trap - EXIT INT TERM

echo "Prompt-free private release approved without installation:"
printf '  %s\n' \
  "${output_dir}/approval-attestation.json" \
  "${output_dir}/approved-release-set.json" \
  "${output_dir}/approved-release-sets.json"
