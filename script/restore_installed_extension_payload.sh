#!/usr/bin/env bash

set -euo pipefail
umask 077

if [[ $# -ne 4 ]]; then
  echo "Usage: ./script/restore_installed_extension_payload.sh VSIX ISOLATED_EXTENSIONS_DIR EXTENSION_ID VERSION" >&2
  exit 2
fi

vsix_file="$1"
extensions_root="$2"
extension_id="$3"
extension_version="$4"

[[ -f "${vsix_file}" && ! -L "${vsix_file}" ]] || {
  echo "The verified VSIX is missing or unsafe: ${vsix_file}" >&2
  exit 1
}
[[ -d "${extensions_root}" && ! -L "${extensions_root}" ]] || {
  echo "The isolated extension root is missing or unsafe: ${extensions_root}" >&2
  exit 1
}
[[ "${extension_id}" =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ && \
  "${extension_version}" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || {
  echo "The expected extension identity is invalid." >&2
  exit 2
}
for required_tool in ditto find grep jq mktemp mv sort uniq unzip; do
  command -v "${required_tool}" >/dev/null 2>&1 || {
    echo "Required command not found: ${required_tool}" >&2
    exit 1
  }
done

installed_manifest=""
match_count=0
while IFS= read -r candidate_manifest <&3; do
  if jq -e \
    --arg extension_id "${extension_id}" \
    --arg extension_version "${extension_version}" '
      (.publisher + "." + .name) == $extension_id
      and .version == $extension_version
    ' "${candidate_manifest}" >/dev/null 2>&1; then
    installed_manifest="${candidate_manifest}"
    match_count=$((match_count + 1))
  fi
done 3< <(find "${extensions_root}" -mindepth 2 -maxdepth 2 -name package.json -type f -print)
[[ "${match_count}" -eq 1 ]] || {
  echo "Expected exactly one installed ${extension_id}@${extension_version} payload; found ${match_count}." >&2
  exit 1
}

installed_directory="$(dirname "${installed_manifest}")"
[[ -d "${installed_directory}" && ! -L "${installed_directory}" && ! -L "${installed_manifest}" ]] || {
  echo "The installed ${extension_id}@${extension_version} payload is symlinked or unsafe." >&2
  exit 1
}
[[ -z "$(find "${installed_directory}" -type l -print -quit)" ]] || {
  echo "The installed ${extension_id}@${extension_version} payload contains a symlink." >&2
  exit 1
}

entry_list="$(unzip -Z1 "${vsix_file}")"
[[ -n "${entry_list}" ]] || {
  echo "The verified VSIX has no entries." >&2
  exit 1
}
if [[ -n "$(printf '%s\n' "${entry_list}" | LC_ALL=C sort | uniq -d)" ]]; then
  echo "The verified VSIX contains duplicate paths." >&2
  exit 1
fi
while IFS= read -r archive_path; do
  case "${archive_path}" in
    ""|/*|./*|../*|*/../*|*/..|*//*|*\\*)
      echo "The verified VSIX contains an unsafe path." >&2
      exit 1
      ;;
  esac
done <<<"${entry_list}"

restore_root="$(mktemp -d "${extensions_root}/.signed-payload-restore.XXXXXX")"
cleanup_restore_root() {
  [[ -n "${restore_root:-}" ]] || return 0
  case "${restore_root}" in
    "${extensions_root}/.signed-payload-restore."*) rm -rf "${restore_root}" ;;
    *) echo "Refusing to remove unexpected payload-restore path: ${restore_root}" >&2; return 1 ;;
  esac
  restore_root=""
}
trap cleanup_restore_root EXIT INT TERM

unzip -qq "${vsix_file}" -d "${restore_root}/archive"
archive_payload="${restore_root}/archive/extension"
archive_manifest="${restore_root}/archive/extension.vsixmanifest"
[[ -d "${archive_payload}" && ! -L "${archive_payload}" ]] || {
  echo "The verified VSIX does not contain a plain extension payload." >&2
  exit 1
}
[[ -f "${archive_manifest}" && ! -L "${archive_manifest}" ]] || {
  echo "The verified VSIX does not contain a plain extension manifest." >&2
  exit 1
}
[[ -z "$(find "${restore_root}/archive" -type l -print -quit)" ]] || {
  echo "The verified VSIX extracts a symlinked payload." >&2
  exit 1
}

installed_metadata="$(jq -c '.__metadata // null' "${installed_manifest}")"
ditto "${archive_payload}" "${installed_directory}"
cp "${archive_manifest}" "${installed_directory}/.vsixmanifest"
while IFS= read -r archive_path; do
  case "${archive_path}" in
    extension/*.db)
      relative_database="${archive_path#extension/}"
      for sqlite_suffix in wal shm journal; do
        if ! grep -Fxq "${archive_path}-${sqlite_suffix}" <<<"${entry_list}"; then
          rm -f "${installed_directory}/${relative_database}-${sqlite_suffix}"
        fi
      done
      ;;
  esac
done <<<"${entry_list}"
if [[ "${installed_metadata}" != "null" ]]; then
  jq --argjson installed_metadata "${installed_metadata}" \
    '.__metadata = $installed_metadata' \
    "${installed_directory}/package.json" > "${installed_directory}/package.json.restore.tmp"
  mv "${installed_directory}/package.json.restore.tmp" "${installed_directory}/package.json"
fi

"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/verify_installed_extension_payload.sh" \
  "${vsix_file}" \
  "${extensions_root}" \
  "${extension_id}" \
  "${extension_version}" >/dev/null

cleanup_restore_root
trap - EXIT INT TERM
echo "Restored signed ${extension_id}@${extension_version} files inside the isolated extension copy."
