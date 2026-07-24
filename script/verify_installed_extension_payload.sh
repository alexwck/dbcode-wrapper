#!/usr/bin/env bash

set -euo pipefail
umask 077

if [[ $# -ne 4 ]]; then
  echo "Usage: ./script/verify_installed_extension_payload.sh VSIX EXTENSIONS_DIR EXTENSION_ID VERSION" >&2
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
  echo "The installed extension root is missing or unsafe: ${extensions_root}" >&2
  exit 1
}
[[ "${extension_id}" =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ && \
  "${extension_version}" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || {
  echo "The expected extension identity is invalid." >&2
  exit 2
}
for required_tool in cmp find grep jq mktemp sort uniq unzip; do
  command -v "${required_tool}" >/dev/null 2>&1 || {
    echo "Required command not found: ${required_tool}" >&2
    exit 1
  }
done

installed_manifest=""
match_count=0
while IFS= read -r candidate_manifest; do
  if jq -e \
    --arg extension_id "${extension_id}" \
    --arg extension_version "${extension_version}" '
      (.publisher + "." + .name) == $extension_id
      and .version == $extension_version
    ' "${candidate_manifest}" >/dev/null 2>&1; then
    installed_manifest="${candidate_manifest}"
    match_count=$((match_count + 1))
  fi
done < <(find "${extensions_root}" -mindepth 2 -maxdepth 2 -name package.json -type f -print)
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

verify_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-installed-payload.XXXXXX")"
cleanup_verify_root() {
  [[ -n "${verify_root:-}" ]] || return 0
  rm -rf "${verify_root}"
  verify_root=""
}
trap cleanup_verify_root EXIT INT TERM

while IFS= read -r archive_path; do
  case "${archive_path}" in
    ""|/*|./*|../*|*/../*|*/..|*//*|*\\*)
      echo "The verified VSIX contains an unsafe path." >&2
      exit 1
      ;;
  esac
done <<<"${entry_list}"
unzip -qq "${vsix_file}" -d "${verify_root}/archive"
[[ -z "$(find "${verify_root}/archive" -type l -print -quit)" ]] || {
  echo "The verified VSIX extracts a symlinked payload." >&2
  exit 1
}

payload_file_count=0
while IFS= read -r archive_path; do
  case "${archive_path}" in
    extension/|*/)
      continue
      ;;
    extension/*)
      relative_path="${archive_path#extension/}"
      ;;
    *)
      continue
      ;;
  esac

  archive_file="${verify_root}/archive/${archive_path}"
  [[ -f "${archive_file}" && ! -L "${archive_file}" ]] || {
    echo "The verified VSIX payload file is missing after safe extraction: ${relative_path}." >&2
    exit 1
  }
  installed_path="${installed_directory}/${relative_path}"
  [[ -f "${installed_path}" && ! -L "${installed_path}" ]] || {
    echo "Installed ${extension_id}@${extension_version} is missing signed payload file ${relative_path}." >&2
    exit 1
  }
  if [[ "${relative_path}" == *.db ]]; then
    for sqlite_suffix in wal shm journal; do
      signed_sidecar="extension/${relative_path}-${sqlite_suffix}"
      installed_sidecar="${installed_path}-${sqlite_suffix}"
      if ! grep -Fxq "${signed_sidecar}" <<<"${entry_list}" && \
        [[ -e "${installed_sidecar}" || -L "${installed_sidecar}" ]]; then
        echo "Installed ${extension_id}@${extension_version} has unsigned SQLite sidecar ${relative_path}-${sqlite_suffix}." >&2
        exit 1
      fi
    done
  fi
  if [[ "${relative_path}" == "package.json" ]]; then
    archive_package="$(jq -S -c 'del(.__metadata)' "${archive_file}")"
    installed_package="$(jq -S -c 'del(.__metadata)' "${installed_path}")"
    [[ "${archive_package}" == "${installed_package}" ]] || {
      echo "Installed ${extension_id}@${extension_version} changed signed payload file ${relative_path}." >&2
      exit 1
    }
  else
    cmp -s "${archive_file}" "${installed_path}" || {
      echo "Installed ${extension_id}@${extension_version} changed signed payload file ${relative_path}." >&2
      exit 1
    }
  fi
  payload_file_count=$((payload_file_count + 1))
done <<<"${entry_list}"
[[ "${payload_file_count}" -gt 0 ]] || {
  echo "The verified VSIX contains no extension payload files." >&2
  exit 1
}

[[ -f "${installed_directory}/.vsixmanifest" && ! -L "${installed_directory}/.vsixmanifest" ]] || {
  echo "Installed ${extension_id}@${extension_version} is missing its VSIX manifest." >&2
  exit 1
}
cmp -s \
  "${verify_root}/archive/extension.vsixmanifest" \
  "${installed_directory}/.vsixmanifest" || {
  echo "Installed ${extension_id}@${extension_version} changed its VSIX manifest." >&2
  exit 1
}

cleanup_verify_root
trap - EXIT INT TERM
echo "Verified installed ${extension_id}@${extension_version} signed payload; runtime-created extra files were left intact."
