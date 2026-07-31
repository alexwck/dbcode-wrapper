#!/usr/bin/env bash

set -euo pipefail
umask 077

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_root}/lib/host_config.sh"
source "${script_root}/lib/artifact_digest.sh"
source "${script_root}/lib/approved_release_set.sh"
source "${script_root}/lib/host_release.sh"
source "${script_root}/lib/generated_workspace.sh"
source "${script_root}/lib/dist_checkpoint.sh"

dist_checkpoint_acquire "host-release-verification"
trap 'dist_checkpoint_exit "$?"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

dmg_file=""
checksum_file=""
manifest_file=""
release_lock=""
acceptance_file=""
compatibility_file=""
notes_file=""
output_file=""
source_repository=""
source_tag=""

usage() {
  cat >&2 <<'EOF'
Usage: ./script/verify_host_release.sh \
  --dmg FILE \
  --checksum FILE \
  --manifest FILE \
  --release-lock FILE \
  --acceptance FILE \
  --source-repository DIR \
  --source-tag TAG \
  --compatibility FILE \
  --notes FILE \
  --output FILE
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dmg) [[ $# -ge 2 ]] || usage; dmg_file="$2"; shift ;;
    --checksum) [[ $# -ge 2 ]] || usage; checksum_file="$2"; shift ;;
    --manifest) [[ $# -ge 2 ]] || usage; manifest_file="$2"; shift ;;
    --release-lock) [[ $# -ge 2 ]] || usage; release_lock="$2"; shift ;;
    --acceptance) [[ $# -ge 2 ]] || usage; acceptance_file="$2"; shift ;;
    --source-repository) [[ $# -ge 2 ]] || usage; source_repository="$2"; shift ;;
    --source-tag) [[ $# -ge 2 ]] || usage; source_tag="$2"; shift ;;
    --compatibility) [[ $# -ge 2 ]] || usage; compatibility_file="$2"; shift ;;
    --notes) [[ $# -ge 2 ]] || usage; notes_file="$2"; shift ;;
    --output) [[ $# -ge 2 ]] || usage; output_file="$2"; shift ;;
    *) usage ;;
  esac
  shift
done
[[ -n "${dmg_file}" && -n "${checksum_file}" && -n "${manifest_file}" && \
  -n "${release_lock}" && -n "${acceptance_file}" && -n "${compatibility_file}" && \
  -n "${notes_file}" && -n "${output_file}" && -n "${source_repository}" && \
  -n "${source_tag}" ]] || usage
output_file="$(
  generated_workspace_resolve_path \
    "host-release-assets" \
    "${output_file}" \
    allow-temporary
)"

for command in cmp codesign diskutil git hdiutil jq lipo plutil rg shasum stat; do
  require_command "${command}"
done
host_release_assert_file "${dmg_file}" "The disk image"
host_release_assert_file "${checksum_file}" "The checksum file"
host_release_assert_file "${manifest_file}" "The build manifest"
host_release_assert_file "${release_lock}" "The release lock"
host_release_assert_file "${acceptance_file}" "The final acceptance report"
host_release_assert_file "${compatibility_file}" "The compatibility manifest"
host_release_assert_file "${notes_file}" "The install and rollback notes"
[[ ! -L "${output_file}" ]] || {
  echo "The verification receipt must not be a symbolic link." >&2
  exit 1
}
[[ ! -e "${output_file}" ]] || {
  echo "Refusing to overwrite an existing verification receipt: ${output_file}" >&2
  exit 1
}
output_parent="$(cd "$(dirname "${output_file}")" 2>/dev/null && pwd -P)"
[[ -n "${output_parent}" ]] || {
  echo "The verification receipt parent does not exist." >&2
  exit 1
}

source_commit="$(jq -er '.source.repository_revision' "${manifest_file}")"
host_release_assert_sanitized_metadata \
  "${checksum_file}" \
  "${compatibility_file}" \
  "${notes_file}"

dmg_sha256="$(shasum -a 256 "${dmg_file}" | awk '{print $1}')"
dmg_size_bytes="$(stat -f '%z' "${dmg_file}")"
[[ "${dmg_size_bytes}" -lt 2147483648 ]] || {
  echo "The Host release disk image exceeds GitHub's 2 GiB asset limit." >&2
  exit 1
}
manifest_sha256="$(shasum -a 256 "${manifest_file}" | awk '{print $1}')"
release_lock_sha256="$(shasum -a 256 "${release_lock}" | awk '{print $1}')"
acceptance_sha256="$(shasum -a 256 "${acceptance_file}" | awk '{print $1}')"
notes_sha256="$(shasum -a 256 "${notes_file}" | awk '{print $1}')"
release_set_id="$(jq -er '.release.release_set_id' "${manifest_file}")"
source_tree_oid="$(jq -er '.source.snapshot.tree_oid' "${manifest_file}")"
source_snapshot_sha256="$(jq -er '.source.snapshot.snapshot_sha256' "${manifest_file}")"
compiled_host_input_id="$(jq -er '.source.compiled_host.input_id' "${manifest_file}")"
expected_checksum="${dmg_sha256}  $(basename "${dmg_file}")"
[[ "$(cat "${checksum_file}")" == "${expected_checksum}" ]] || {
  echo "The checksum file does not cover this exact disk image." >&2
  exit 1
}

jq -e \
  --arg dmg_name "$(basename "${dmg_file}")" \
  --arg dmg_sha256 "${dmg_sha256}" \
  --argjson dmg_size_bytes "${dmg_size_bytes}" \
  --arg source_tag "${source_tag}" \
  --arg wrapper_version "$(jq -er '.release.wrapper_version' "${release_lock}")" \
  --arg source_commit "${source_commit}" \
  --arg source_tree_oid "${source_tree_oid}" \
  --arg source_snapshot_sha256 "${source_snapshot_sha256}" \
  --arg compiled_host_input_id "${compiled_host_input_id}" \
  --arg release_set_id "${release_set_id}" \
  '
    .schema_version == 1
    and .scope == "public-host-release"
    and .transfer.channel == "github-published-release"
    and .transfer.draft_required == false
    and .transfer.public_download == true
    and .transfer.owned_devices_only == false
    and .claims.public_application_release == true
    and .claims.dbcode_included == false
    and .source.tag == $source_tag
    and .release.wrapper_version == $wrapper_version
    and .source.tag == ("v" + $wrapper_version)
    and .source.repository_revision == $source_commit
    and .source.tree_oid == $source_tree_oid
    and .source.snapshot_sha256 == $source_snapshot_sha256
    and .source.compiled_host_input_id == $compiled_host_input_id
    and .release.release_set_id == $release_set_id
    and .release.architecture == "arm64"
    and .disk_image.filename == $dmg_name
    and .disk_image.sha256 == $dmg_sha256
    and .disk_image.size_bytes == $dmg_size_bytes
  ' "${compatibility_file}" >/dev/null || {
  echo "The compatibility manifest does not describe this exact host release." >&2
  exit 1
}

hdiutil verify "${dmg_file}" >/dev/null

mount_root="$(mktemp -d "${TMPDIR:-/private/tmp}/dbcode-host-release-mount.XXXXXX")"
attach_plist="${mount_root}/attach.plist"
mounted_device=""
mounted_path=""
cleanup_mount() {
  local exit_status=$?
  if [[ -n "${mounted_device}" ]]; then
    hdiutil detach "${mounted_device}" -quiet >/dev/null 2>&1 || \
      hdiutil detach "${mounted_device}" -force -quiet >/dev/null 2>&1 || true
  fi
  case "${mount_root}" in
    "${TMPDIR:-/private/tmp}"/dbcode-host-release-mount.*) rm -rf "${mount_root}" ;;
    *)
      echo "Refusing to remove unexpected host-release mount root: ${mount_root}" >&2
      [[ "${exit_status}" -ne 0 ]] || exit_status=1
      ;;
  esac
  dist_checkpoint_exit "${exit_status}"
}
trap cleanup_mount EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

hdiutil attach \
  -readonly \
  -nobrowse \
  -mountroot "${mount_root}" \
  -plist \
  "${dmg_file}" > "${attach_plist}"
attach_json="$(plutil -convert json -o - "${attach_plist}")"
mounted_path="$(jq -er '[."system-entities"[] | select(."mount-point" != null) | ."mount-point"] | first' <<<"${attach_json}")"
mounted_device="$(jq -er '[."system-entities"[] | select(."mount-point" != null) | ."dev-entry"] | first' <<<"${attach_json}")"
host_release_path_is_within "${mount_root}" "${mounted_path}" || {
  echo "The disk image mounted outside its private verification root." >&2
  exit 1
}
[[ -d "${mounted_path}" && ! -L "${mounted_path}" ]] || {
  echo "The disk image mount is missing or unsafe." >&2
  exit 1
}

disk_info_json="$(diskutil info -plist "${mounted_device}" | plutil -convert json -o - -)"
jq -e '
  .Writable == false
  and .WritableMedia == false
  and .FilesystemType == "hfs"
' <<<"${disk_info_json}" >/dev/null || {
  echo "The disk image did not mount as a read-only volume." >&2
  exit 1
}

app_name="$(jq -er '.app.filename' "${compatibility_file}")"
guide_name="$(jq -er '.disk_image.contents[] | select(endswith(".txt"))' "${compatibility_file}")"
"${script_root}/inspect_host_release_tree.sh" \
  --root "${mounted_path}" \
  --app-name "${app_name}" \
  --guide-name "${guide_name}"
release_context="$(
  host_release_context_record \
    "${mounted_path}/${app_name}" \
    "${manifest_file}" \
    "${release_lock}" \
    "${acceptance_file}" \
    "${source_repository}" \
    "${source_tag}"
)"
[[ "${source_commit}" == "$(jq -er '.source.repository_revision' <<<"${release_context}")" ]] || {
  echo "The mounted release context has an unexpected source revision." >&2
  exit 1
}

guide_sha256="$(shasum -a 256 "${mounted_path}/${guide_name}" | awk '{print $1}')"
[[ "${guide_sha256}" == "$(jq -er '.disk_image.install_guide_sha256' "${compatibility_file}")" ]] || {
  echo "The mounted install guide does not match the compatibility manifest." >&2
  exit 1
}
[[ "${guide_sha256}" == "${notes_sha256}" ]] || {
  echo "The external install notes do not match the guide inside the disk image." >&2
  exit 1
}

expected_compatibility="${mount_root}/expected-compatibility.json"
package_record="$(
  host_release_package_record \
    "$(basename "${dmg_file}")" \
    "${dmg_sha256}" \
    "${dmg_size_bytes}" \
    "${guide_name}" \
    "${guide_sha256}" \
    "$(basename "${checksum_file}")" \
    "$(basename "${compatibility_file}")" \
    "$(basename "${notes_file}")" \
    "$(basename "${output_file}")"
)"
host_release_write_compatibility_manifest \
  "${expected_compatibility}" \
  "$(jq -er '.created_at_utc' "${compatibility_file}")" \
  "${release_context}" \
  "${package_record}"
host_release_validate_compatibility_manifest \
  "${compatibility_file}" \
  "${expected_compatibility}"

hdiutil detach "${mounted_device}" -quiet
mounted_device=""

verification_checks="$(approved_release_set_prompt_free_verification_checks)"
jq -n \
  --arg verified_at_utc "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --arg release_set_id "${release_set_id}" \
  --arg source_tag "${source_tag}" \
  --arg source_commit "${source_commit}" \
  --arg source_tree_oid "${source_tree_oid}" \
  --arg source_snapshot_sha256 "${source_snapshot_sha256}" \
  --arg compiled_host_input_id "${compiled_host_input_id}" \
  --arg dmg_name "$(basename "${dmg_file}")" \
  --arg dmg_sha256 "${dmg_sha256}" \
  --arg manifest_sha256 "${manifest_sha256}" \
  --arg release_lock_sha256 "${release_lock_sha256}" \
  --arg acceptance_sha256 "${acceptance_sha256}" \
  --arg checksum_sha256 "$(shasum -a 256 "${checksum_file}" | awk '{print $1}')" \
  --arg compatibility_sha256 "$(shasum -a 256 "${compatibility_file}" | awk '{print $1}')" \
  --arg notes_sha256 "${notes_sha256}" \
  --argjson verification_checks "${verification_checks}" '
    {
      schema_version: 1,
      status: "passed",
      verified_at_utc: $verified_at_utc,
      release_set_id: $release_set_id,
      source: {
        tag: $source_tag,
        repository_revision: $source_commit,
        tree_oid: $source_tree_oid,
        snapshot_sha256: $source_snapshot_sha256,
        compiled_host_input_id: $compiled_host_input_id
      },
      disk_image: {filename: $dmg_name, sha256: $dmg_sha256},
      evidence: {
        build_manifest_sha256: $manifest_sha256,
        release_lock_sha256: $release_lock_sha256,
        final_acceptance_sha256: $acceptance_sha256,
        checksum_sha256: $checksum_sha256,
        compatibility_manifest_sha256: $compatibility_sha256,
        install_and_rollback_sha256: $notes_sha256
      },
      checks: $verification_checks,
      failures: []
    }
  ' > "${output_file}"
chmod 600 "${output_file}"
host_release_assert_sanitized_metadata "${output_file}"

echo "Host release verification passed: ${output_file}"
