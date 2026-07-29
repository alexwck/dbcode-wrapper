#!/usr/bin/env bash

set -euo pipefail
umask 077

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_root}/lib/host_config.sh"
source "${script_root}/lib/artifact_digest.sh"
source "${script_root}/lib/host_release.sh"
source "${script_root}/lib/host_release_guide.sh"
source "${script_root}/lib/generated_workspace.sh"

app_path=""
manifest_file=""
release_lock=""
acceptance_file=""
output_dir=""
source_repository=""
source_tag=""

usage() {
  cat >&2 <<'EOF'
Usage: ./script/package_host_release.sh \
  --app PATH \
  --manifest FILE \
  --release-lock FILE \
  --acceptance FILE \
  --source-repository DIR \
  --source-tag TAG \
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
    --source-repository) [[ $# -ge 2 ]] || usage; source_repository="$2"; shift ;;
    --source-tag) [[ $# -ge 2 ]] || usage; source_tag="$2"; shift ;;
    --output-dir) [[ $# -ge 2 ]] || usage; output_dir="$2"; shift ;;
    *) usage ;;
  esac
  shift
done
[[ -n "${app_path}" && -n "${manifest_file}" && -n "${release_lock}" && \
  -n "${acceptance_file}" && -n "${source_repository}" && -n "${source_tag}" && \
  -n "${output_dir}" ]] || usage
output_dir="$(
  generated_workspace_resolve_path \
    "host-release-assets" \
    "${output_dir}" \
    allow-temporary
)"

for command in cmp codesign ditto git hdiutil jq lipo plutil rg shasum stat; do
  require_command "${command}"
done

release_context="$(
  host_release_context_record \
    "${app_path}" \
    "${manifest_file}" \
    "${release_lock}" \
    "${acceptance_file}" \
    "${source_repository}" \
    "${source_tag}"
)"
source_commit="$(jq -er '.source.repository_revision' <<<"${release_context}")"

[[ ! -L "${output_dir}" ]] || {
  echo "The host-release output directory must not be a symbolic link." >&2
  exit 1
}
mkdir -p "${output_dir}"
[[ -d "${output_dir}" && "$(stat -f '%u' "${output_dir}")" == "$(id -u)" ]] || {
  echo "The host-release output directory is unsafe." >&2
  exit 1
}
chmod 700 "${output_dir}"
[[ -z "$(find "${output_dir}" -mindepth 1 -maxdepth 1 -print -quit)" ]] || {
  echo "The host-release output directory must be empty." >&2
  exit 1
}

release_set_id="$(jq -er '.release.release_set_id' <<<"${release_context}")"
wrapper_version="$(jq -er '.release.wrapper_version' <<<"${release_context}")"
[[ "${source_tag}" == "v${wrapper_version}" ]] || {
  echo "The source tag must match wrapper version ${wrapper_version}: v${wrapper_version}" >&2
  exit 1
}
code_oss_version="$(jq -er '.release.code_oss_version' <<<"${release_context}")"
vscodium_version="$(jq -er '.release.vscodium_version' <<<"${release_context}")"
dbcode_version="$(jq -er '.release.dbcode_version' <<<"${release_context}")"
architecture="$(jq -er '.release.architecture' <<<"${release_context}")"
app_sha256="$(jq -er '.app.sha256' <<<"${release_context}")"
package_stem="DBCode-Wrapper-${wrapper_version}-${vscodium_version}-dbcode-${dbcode_version}-src-${source_commit:0:12}-app-${app_sha256:0:12}-${architecture}"
dmg_name="${package_stem}.dmg"
checksum_name="${dmg_name}.sha256"
compatibility_name="${package_stem}-compatibility.json"
guide_name="Install DBCode Wrapper.txt"
notes_name="${package_stem}-install-and-rollback.txt"
verification_name="${package_stem}-verification.json"

for output_name in \
  "${dmg_name}" \
  "${checksum_name}" \
  "${compatibility_name}" \
  "${notes_name}" \
  "${verification_name}"; do
  [[ ! -e "${output_dir}/${output_name}" ]] || {
    echo "Refusing to overwrite an existing release asset: ${output_dir}/${output_name}" >&2
    exit 1
  }
done

temporary_root="$(mktemp -d "${output_dir}/.staging.XXXXXX")"
cleanup_temporary_root() {
  [[ -n "${temporary_root:-}" ]] || return 0
  case "${temporary_root}" in
    "${output_dir}/.staging."*) rm -rf "${temporary_root}" ;;
    *)
      echo "Refusing to remove unexpected host-release path: ${temporary_root}" >&2
      return 1
      ;;
  esac
  temporary_root=""
}
trap cleanup_temporary_root EXIT INT TERM

release_tree="${temporary_root}/volume"
mkdir -p "${release_tree}"
ditto "${app_path}" "${release_tree}/DBCode Wrapper.app"
host_release_write_install_guide \
  "${release_tree}/${guide_name}" \
  "${release_set_id}" \
  "${code_oss_version}" \
  "${dbcode_version}"
cp "${release_tree}/${guide_name}" "${temporary_root}/${notes_name}"

"${script_root}/inspect_host_release_tree.sh" \
  --root "${release_tree}" \
  --app-name "DBCode Wrapper.app" \
  --guide-name "${guide_name}"
host_release_validate_copied_app \
  "${release_tree}/DBCode Wrapper.app" \
  "${release_context}"

hdiutil create \
  -quiet \
  -fs HFS+ \
  -format UDZO \
  -volname "DBCode Wrapper" \
  -srcfolder "${release_tree}" \
  "${temporary_root}/${dmg_name}"
hdiutil verify "${temporary_root}/${dmg_name}" >/dev/null

dmg_sha256="$(shasum -a 256 "${temporary_root}/${dmg_name}" | awk '{print $1}')"
dmg_size_bytes="$(stat -f '%z' "${temporary_root}/${dmg_name}")"
guide_sha256="$(shasum -a 256 "${release_tree}/${guide_name}" | awk '{print $1}')"

[[ "${dmg_size_bytes}" -lt 2147483648 ]] || {
  echo "The host-release disk image exceeds GitHub's 2 GiB asset limit." >&2
  exit 1
}

package_record="$(
  host_release_package_record \
    "${dmg_name}" \
    "${dmg_sha256}" \
    "${dmg_size_bytes}" \
    "${guide_name}" \
    "${guide_sha256}" \
    "${checksum_name}" \
    "${compatibility_name}" \
    "${notes_name}" \
    "${verification_name}"
)"
host_release_write_compatibility_manifest \
  "${temporary_root}/${compatibility_name}" \
  "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  "${release_context}" \
  "${package_record}"

printf '%s  %s\n' "${dmg_sha256}" "${dmg_name}" > "${temporary_root}/${checksum_name}"

"${script_root}/verify_host_release.sh" \
  --dmg "${temporary_root}/${dmg_name}" \
  --checksum "${temporary_root}/${checksum_name}" \
  --manifest "${manifest_file}" \
  --release-lock "${release_lock}" \
  --acceptance "${acceptance_file}" \
  --source-repository "${source_repository}" \
  --source-tag "${source_tag}" \
  --compatibility "${temporary_root}/${compatibility_name}" \
  --notes "${temporary_root}/${notes_name}" \
  --output "${temporary_root}/${verification_name}"

host_release_assert_sanitized_metadata \
  "${temporary_root}/${checksum_name}" \
  "${temporary_root}/${compatibility_name}" \
  "${temporary_root}/${notes_name}" \
  "${temporary_root}/${verification_name}"

for output_name in \
  "${dmg_name}" \
  "${checksum_name}" \
  "${compatibility_name}" \
  "${notes_name}" \
  "${verification_name}"; do
  mv "${temporary_root}/${output_name}" "${output_dir}/${output_name}"
  chmod 600 "${output_dir}/${output_name}"
done
cleanup_temporary_root
trap - EXIT INT TERM

expected_output_entries="$(
  printf '%s\n' \
    "${dmg_name}" \
    "${checksum_name}" \
    "${compatibility_name}" \
    "${notes_name}" \
    "${verification_name}" |
    LC_ALL=C sort
)"
actual_output_entries="$(find "${output_dir}" -mindepth 1 -maxdepth 1 -print | sed 's#^.*/##' | LC_ALL=C sort)"
[[ "${actual_output_entries}" == "${expected_output_entries}" ]] || {
  echo "The host-release output contains unexpected assets." >&2
  exit 1
}

echo "Verified host-release assets:"
printf '  %s\n' \
  "${output_dir}/${dmg_name}" \
  "${output_dir}/${checksum_name}" \
  "${output_dir}/${compatibility_name}" \
  "${output_dir}/${notes_name}" \
  "${output_dir}/${verification_name}"
