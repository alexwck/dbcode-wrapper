#!/usr/bin/env bash

set -euo pipefail
umask 077

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_root}/lib/host_config.sh"
source "${script_root}/lib/artifact_digest.sh"
source "${script_root}/lib/private_release.sh"
source "${script_root}/lib/generated_workspace.sh"

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
Usage: ./script/verify_private_release.sh \
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
    "private-release-assets" \
    "${output_file}" \
    allow-temporary
)"

for command in cmp codesign diskutil git hdiutil jq lipo plutil rg shasum stat; do
  require_command "${command}"
done
private_release_assert_file "${dmg_file}" "The disk image"
private_release_assert_file "${checksum_file}" "The checksum file"
private_release_assert_file "${manifest_file}" "The build manifest"
private_release_assert_file "${release_lock}" "The release lock"
private_release_assert_file "${acceptance_file}" "The final acceptance report"
private_release_assert_file "${compatibility_file}" "The compatibility manifest"
private_release_assert_file "${notes_file}" "The install and rollback notes"
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

source_commit="$(
  private_release_validate_source_tag \
    "${source_repository}" \
    "${source_tag}" \
    "${manifest_file}" \
    "${release_lock}"
)"
private_release_assert_sanitized_metadata \
  "${checksum_file}" \
  "${compatibility_file}" \
  "${notes_file}"

dmg_sha256="$(shasum -a 256 "${dmg_file}" | awk '{print $1}')"
dmg_size_bytes="$(stat -f '%z' "${dmg_file}")"
[[ "${dmg_size_bytes}" -lt 2147483648 ]] || {
  echo "The Private Personal Release disk image exceeds GitHub's 2 GiB asset limit." >&2
  exit 1
}
manifest_sha256="$(shasum -a 256 "${manifest_file}" | awk '{print $1}')"
release_lock_sha256="$(shasum -a 256 "${release_lock}" | awk '{print $1}')"
acceptance_sha256="$(shasum -a 256 "${acceptance_file}" | awk '{print $1}')"
notes_sha256="$(shasum -a 256 "${notes_file}" | awk '{print $1}')"
release_set_id="$(jq -er '.release.release_set_id' "${manifest_file}")"
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
  --arg source_commit "${source_commit}" \
  --arg release_set_id "${release_set_id}" \
  '
    .schema_version == 1
    and .scope == "private-personal-release"
    and .source.tag == $source_tag
    and .source.repository_revision == $source_commit
    and .release.release_set_id == $release_set_id
    and .release.architecture == "arm64"
    and .disk_image.filename == $dmg_name
    and .disk_image.sha256 == $dmg_sha256
    and .disk_image.size_bytes == $dmg_size_bytes
  ' "${compatibility_file}" >/dev/null || {
  echo "The compatibility manifest does not describe this exact private release." >&2
  exit 1
}

hdiutil verify "${dmg_file}" >/dev/null

mount_root="$(mktemp -d "${TMPDIR:-/private/tmp}/dbcode-private-release-mount.XXXXXX")"
attach_plist="${mount_root}/attach.plist"
mounted_device=""
mounted_path=""
cleanup_mount() {
  if [[ -n "${mounted_device}" ]]; then
    hdiutil detach "${mounted_device}" -quiet >/dev/null 2>&1 || \
      hdiutil detach "${mounted_device}" -force -quiet >/dev/null 2>&1 || true
  fi
  case "${mount_root}" in
    "${TMPDIR:-/private/tmp}"/dbcode-private-release-mount.*) rm -rf "${mount_root}" ;;
    *) echo "Refusing to remove unexpected private-release mount root: ${mount_root}" >&2 ;;
  esac
}
trap cleanup_mount EXIT INT TERM

hdiutil attach \
  -readonly \
  -nobrowse \
  -mountroot "${mount_root}" \
  -plist \
  "${dmg_file}" > "${attach_plist}"
attach_json="$(plutil -convert json -o - "${attach_plist}")"
mounted_path="$(jq -er '[."system-entities"[] | select(."mount-point" != null) | ."mount-point"] | first' <<<"${attach_json}")"
mounted_device="$(jq -er '[."system-entities"[] | select(."mount-point" != null) | ."dev-entry"] | first' <<<"${attach_json}")"
private_release_path_is_within "${mount_root}" "${mounted_path}" || {
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
"${script_root}/inspect_private_release_tree.sh" \
  --root "${mounted_path}" \
  --app-name "${app_name}" \
  --guide-name "${guide_name}"
private_release_validate_sources \
  "${mounted_path}/${app_name}" \
  "${manifest_file}" \
  "${release_lock}" \
  "${acceptance_file}"

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
minimum_macos="$(plutil -extract LSMinimumSystemVersion raw "${mounted_path}/${app_name}/Contents/Info.plist")"
private_release_write_compatibility_manifest \
  "${expected_compatibility}" \
  "$(jq -er '.created_at_utc' "${compatibility_file}")" \
  "${manifest_file}" \
  "${release_lock}" \
  "${acceptance_file}" \
  "${source_tag}" \
  "${source_commit}" \
  "$(basename "${dmg_file}")" \
  "${dmg_sha256}" \
  "${dmg_size_bytes}" \
  "${guide_name}" \
  "${guide_sha256}" \
  "$(basename "${checksum_file}")" \
  "$(basename "${compatibility_file}")" \
  "$(basename "${notes_file}")" \
  "$(basename "${output_file}")" \
  "${minimum_macos}"
private_release_validate_compatibility_manifest \
  "${compatibility_file}" \
  "${expected_compatibility}"

hdiutil detach "${mounted_device}" -quiet
mounted_device=""

jq -n \
  --arg verified_at_utc "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --arg release_set_id "${release_set_id}" \
  --arg source_tag "${source_tag}" \
  --arg source_commit "${source_commit}" \
  --arg dmg_name "$(basename "${dmg_file}")" \
  --arg dmg_sha256 "${dmg_sha256}" \
  --arg manifest_sha256 "${manifest_sha256}" \
  --arg release_lock_sha256 "${release_lock_sha256}" \
  --arg acceptance_sha256 "${acceptance_sha256}" \
  --arg checksum_sha256 "$(shasum -a 256 "${checksum_file}" | awk '{print $1}')" \
  --arg compatibility_sha256 "$(shasum -a 256 "${compatibility_file}" | awk '{print $1}')" \
  --arg notes_sha256 "${notes_sha256}" '
    {
      schema_version: 1,
      status: "passed",
      verified_at_utc: $verified_at_utc,
      release_set_id: $release_set_id,
      source: {tag: $source_tag, repository_revision: $source_commit},
      disk_image: {filename: $dmg_name, sha256: $dmg_sha256},
      evidence: {
        build_manifest_sha256: $manifest_sha256,
        release_lock_sha256: $release_lock_sha256,
        final_acceptance_sha256: $acceptance_sha256,
        checksum_sha256: $checksum_sha256,
        compatibility_manifest_sha256: $compatibility_sha256,
        install_and_rollback_sha256: $notes_sha256
      },
      checks: {
        source_tag: "passed",
        complete_same_mac_acceptance: "passed",
        disk_image_integrity: "passed",
        mounted_read_only: "passed",
        exact_top_level_contents: "passed",
        host_only_content_scan: "passed",
        app_artifact_digest: "passed",
        nested_code_signatures: "passed",
        designated_requirement: "passed",
        apple_silicon_only: "passed",
        upstream_notices: "passed",
        install_guide: "passed",
        external_runtime_not_bundled: "passed",
        private_data_absent: "passed"
      },
      failures: []
    }
  ' > "${output_file}"
chmod 600 "${output_file}"
private_release_assert_sanitized_metadata "${output_file}"

echo "Private Personal Release verification passed: ${output_file}"
