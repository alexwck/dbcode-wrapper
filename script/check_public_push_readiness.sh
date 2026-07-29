#!/usr/bin/env bash

set -euo pipefail

repository=""
selected_ref=""
approved_author_email=""
approved_license_sha256=""
private_home_name=""

usage() {
  cat >&2 <<'EOF'
Usage: ./script/check_public_push_readiness.sh \
  --repository <git repository> \
  --ref <exact ref to publish> \
  --approved-author-email <public email> \
  --private-home-name <local account name> \
  --approved-license-sha256 <sha256 of the approved LICENSE file>
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repository)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      repository="$2"
      shift 2
      ;;
    --ref)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      selected_ref="$2"
      shift 2
      ;;
    --approved-author-email)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      approved_author_email="$2"
      shift 2
      ;;
    --private-home-name)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      private_home_name="$2"
      shift 2
      ;;
    --approved-license-sha256)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      approved_license_sha256="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "${repository}" || -z "${selected_ref}" || -z "${approved_author_email}" || -z "${private_home_name}" || -z "${approved_license_sha256}" ]]; then
  usage
  exit 2
fi

if [[ ! "${private_home_name}" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "The private home name must be a local account name, not a path." >&2
  exit 2
fi

if [[ ! "${approved_license_sha256}" =~ ^[0-9a-f]{64}$ ]]; then
  echo "The approved licence SHA-256 must contain exactly 64 lowercase hexadecimal characters." >&2
  exit 2
fi

git -C "${repository}" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "Not a Git repository: ${repository}" >&2
  exit 1
}

resolved_object="$(git -C "${repository}" rev-parse --verify "${selected_ref}" 2>/dev/null)" || {
  echo "The selected public ref does not resolve to a commit: ${selected_ref}" >&2
  exit 1
}
resolved_object_type="$(git -C "${repository}" cat-file -t "${resolved_object}")"
if [[ "${resolved_object_type}" == "tag" ]]; then
  tag_target="$(git -C "${repository}" cat-file tag "${resolved_object}" | sed -n 's/^object //p' | head -n 1)"
  if [[ "$(git -C "${repository}" cat-file -t "${tag_target}")" == "tag" ]]; then
    echo "Nested annotated tags are not accepted for a public push." >&2
    exit 1
  fi
fi
commit="$(git -C "${repository}" rev-parse --verify "${selected_ref}^{commit}" 2>/dev/null)" || {
  echo "The selected public ref does not peel to a commit: ${selected_ref}" >&2
  exit 1
}

for required_path in README.md CONTEXT.md THIRD_PARTY_NOTICES.md LICENSE; do
  git -C "${repository}" cat-file -e "${commit}:${required_path}" 2>/dev/null || {
    echo "The selected public ref is missing ${required_path}." >&2
    exit 1
  }
done

read_ref_file() {
  git -C "${repository}" show "${commit}:$1"
}

readme="$(read_ref_file README.md)"
context="$(read_ref_file CONTEXT.md)"
third_party_notices="$(read_ref_file THIRD_PARTY_NOTICES.md)"

for required_statement in \
  'This is not an official DBCode product' \
  'DBCode is not included' \
  'Published releases contain only the wrapper host'; do
  [[ "${readme}" == *"${required_statement}"* ]] || {
    echo "The selected public README is missing: ${required_statement}" >&2
    exit 1
  }
done

[[ "${context}" == *'**Public Source Repository**:'* ]] || {
  echo "The selected CONTEXT.md does not define the public-source boundary." >&2
  exit 1
}

for required_notice in \
  'Code OSS' \
  'VSCodium' \
  'MIT License' \
  'Copyright (c) 2018-present The VSCodium contributors' \
  'Copyright (c) 2018-present Peter Squicciarini' \
  'Copyright (c) 2015-present Microsoft Corporation' \
  'Permission is hereby granted, free of charge' \
  'The above copyright notice and this permission notice shall be included' \
  'THE SOFTWARE IS PROVIDED "AS IS"'; do
  [[ "${third_party_notices}" == *"${required_notice}"* ]] || {
    echo "The selected third-party notices are missing: ${required_notice}" >&2
    exit 1
  }
done

actual_license_sha256="$(read_ref_file LICENSE | shasum -a 256 | awk '{print $1}')"
[[ "${actual_license_sha256}" == "${approved_license_sha256}" ]] || {
  echo "The selected ref's LICENSE file does not match the owner-approved SHA-256." >&2
  exit 1
}

tagger_email=""
if [[ "${resolved_object_type}" == "tag" ]]; then
  tagger_email="$(git -C "${repository}" cat-file tag "${resolved_object}" | sed -n 's/^tagger .*<\([^>]*\)> [0-9][0-9]* [-+][0-9][0-9]*$/\1/p' | head -n 1)"
fi

unexpected_emails="$(
  {
    git -C "${repository}" log --format='%ae%n%ce' "${commit}"
    [[ -z "${tagger_email}" ]] || printf '%s\n' "${tagger_email}"
  } |
    LC_ALL=C sort -u |
    while IFS= read -r email; do
      [[ -z "${email}" || "${email}" == "${approved_author_email}" ]] || printf '%s\n' "${email}"
    done
)"
if [[ -n "${unexpected_emails}" ]]; then
  echo "The selected history contains author or committer email addresses other than the approved public email:" >&2
  printf '%s\n' "${unexpected_emails}" >&2
  exit 1
fi

historical_paths="$(git -C "${repository}" log --name-only --format= "${commit}" | sed '/^$/d' | LC_ALL=C sort -u)"
forbidden_paths="$(
  printf '%s\n' "${historical_paths}" |
    rg -i '(^|/)host/dbcode-public-contributions-[^/]+\.json$|(^|/)comparator-design-audit/[^/]+\.png$|(^|/)assets/codicon\.ttf$|(^|/)(dist|\.build|output|real-profile|acceptance-profile|user-data)/|\.(dmg|sha256|db|db3|sqlite|sqlite3|vsix|p12|pfx|key|duckdb|parquet|accdb|avro|csv|ddb|ipynb|mdb|sigzip|xlsx)$' || true
)"
if [[ -n "${forbidden_paths}" ]]; then
  echo "The selected history contains files that must not be published:" >&2
  printf '%s\n' "${forbidden_paths}" >&2
  exit 1
fi

mac_user_root='/Users'
linux_user_root='/home'
mac_private_home="${mac_user_root}/${private_home_name}/"
linux_private_home="${linux_user_root}/${private_home_name}/"
sensitive_pattern='-----BEGIN (RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----[[:space:]]*$|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}'

if git -C "${repository}" log --format='%B' "${commit}" | LC_ALL=C rg -a -q -- "${sensitive_pattern}"; then
  echo "The selected commit messages contain a private-key or live-token pattern." >&2
  exit 1
fi
if git -C "${repository}" log --format='%B' "${commit}" | LC_ALL=C rg -a -F -q -e "${mac_private_home}" -e "${linux_private_home}"; then
  echo "The selected commit messages contain an absolute personal home path." >&2
  exit 1
fi

if [[ "${resolved_object_type}" == "tag" ]]; then
  if git -C "${repository}" cat-file tag "${resolved_object}" | LC_ALL=C rg -a -q -- "${sensitive_pattern}"; then
    echo "The selected annotated tag contains a private-key or live-token pattern." >&2
    exit 1
  fi
  if git -C "${repository}" cat-file tag "${resolved_object}" | LC_ALL=C rg -a -F -q -e "${mac_private_home}" -e "${linux_private_home}"; then
    echo "The selected annotated tag contains an absolute personal home path." >&2
    exit 1
  fi
fi

history_blob_ids() {
  git -C "${repository}" rev-list --objects "${commit}" |
    awk '{print $1}' |
    LC_ALL=C sort -u |
    git -C "${repository}" cat-file --batch-check='%(objectname) %(objecttype)' |
    awk '$2 == "blob" { print $1 }'
}

history_blob_stream() {
  history_blob_ids |
    git -C "${repository}" cat-file --batch
}

if (
  set +o pipefail
  history_blob_stream | LC_ALL=C rg -a -q -- "${sensitive_pattern}"
); then
  echo "The selected history contains a private-key or live-token pattern." >&2
  exit 1
fi

if (
  set +o pipefail
  history_blob_stream | LC_ALL=C rg -a -F -q -e "${mac_private_home}" -e "${linux_private_home}"
); then
  echo "The selected history contains an absolute personal home path." >&2
  exit 1
fi

echo "Public-push readiness passed for ${selected_ref} (${commit})."
