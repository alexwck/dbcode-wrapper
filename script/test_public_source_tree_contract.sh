#!/usr/bin/env bash

set -euo pipefail

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_root}/.." && pwd)"

readme="${repo_root}/README.md"
context="${repo_root}/CONTEXT.md"
ignore_file="${repo_root}/.gitignore"
public_verification_key="${repo_root}/host/keys/openvsx-14ccb407-4e79-41ed-be5a-6d608325c45a.pem"
third_party_notices="${repo_root}/THIRD_PARTY_NOTICES.md"

[[ -f "${readme}" ]] || {
  echo "A public repository needs a root README that explains its release boundary." >&2
  exit 1
}

for required_statement in \
  'This is not an official DBCode product' \
  'DBCode is not included' \
  'Published releases contain only the wrapper host'; do
  rg -Fq "${required_statement}" "${readme}" || {
    echo "The public repository README is missing: ${required_statement}" >&2
    exit 1
  }
done

rg -Fq '**Public Source Repository**:' "${context}" || {
  echo "CONTEXT.md must define the public source and host-release boundary." >&2
  exit 1
}

[[ -f "${third_party_notices}" ]] || {
  echo "A public repository must retain its Code OSS and VSCodium notices." >&2
  exit 1
}
for notice_name in \
  'Code OSS' \
  'VSCodium' \
  'MIT License' \
  'Copyright (c) 2018-present The VSCodium contributors' \
  'Copyright (c) 2018-present Peter Squicciarini' \
  'Copyright (c) 2015-present Microsoft Corporation' \
  'Permission is hereby granted, free of charge' \
  'The above copyright notice and this permission notice shall be included' \
  'THE SOFTWARE IS PROVIDED "AS IS"'; do
  rg -Fq "${notice_name}" "${third_party_notices}" || {
    echo "The third-party notice file is missing: ${notice_name}" >&2
    exit 1
  }
done

for ignored_pattern in '*.dmg' '*.db' '*.db3' '*.sqlite' '*.sqlite3' '*.vsix' '*.p12' '*.pfx' '*.key' '*.duckdb' '*.parquet'; do
  rg -Fxq "${ignored_pattern}" "${ignore_file}" || {
    echo "The public repository ignore policy is missing ${ignored_pattern}." >&2
    exit 1
  }
done

tracked_forbidden="$({
  git -C "${repo_root}" ls-files
} | rg -i '^(dist|\.build|output)/|^host/dbcode-public-contributions-[^/]+\.json$|\.(dmg|db|db3|sqlite|sqlite3|vsix|p12|pfx|key|duckdb|parquet)$' |
  while IFS= read -r tracked_path; do
    [[ -e "${repo_root}/${tracked_path}" ]] && printf '%s\n' "${tracked_path}"
  done || true)"
[[ -z "${tracked_forbidden}" ]] || {
  echo "Generated app, extracted extension, database, or signing files are tracked:" >&2
  printf '%s\n' "${tracked_forbidden}" >&2
  exit 1
}

[[ "$(sed -n '1p' "${public_verification_key}")" == '-----BEGIN PUBLIC KEY-----' ]] || {
  echo "The tracked Open VSX verification key is not clearly public-only." >&2
  exit 1
}
if rg -Fq 'PRIVATE KEY' "${public_verification_key}"; then
  echo "The tracked Open VSX verification key contains private-key material." >&2
  exit 1
fi

echo "Current public-source tree contracts passed."
