#!/usr/bin/env bash

set -euo pipefail

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checker="${script_root}/check_public_push_readiness.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-public-push-test.XXXXXX")"
approved_email="123456+dbcode-owner@users.noreply.github.com"
private_home_name="alexabelle"

cleanup() {
  rm -rf "${fixture_root}"
}
trap cleanup EXIT

initialize_repository() {
  local repository="$1"
  local author_email="$2"

  mkdir -p "${repository}"
  git -c init.defaultBranch=main -C "${repository}" init -q
  git -C "${repository}" config user.name "DBCode Wrapper test"
  git -C "${repository}" config user.email "${author_email}"
  printf '%s\n' \
    '# DBCode Wrapper' \
    '' \
    'This is not an official DBCode product.' \
    'DBCode is not included.' \
    'No public app download is provided.' >"${repository}/README.md"
  printf '%s\n' '**Public Source Repository**: source only.' >"${repository}/CONTEXT.md"
  printf '%s\n' \
    'Code OSS' \
    'VSCodium' \
    'MIT License' \
    'Copyright (c) 2018-present The VSCodium contributors' \
    'Copyright (c) 2018-present Peter Squicciarini' \
    'Copyright (c) 2015-present Microsoft Corporation' \
    'Permission is hereby granted, free of charge, to any person obtaining a copy.' \
    'The above copyright notice and this permission notice shall be included.' \
    'THE SOFTWARE IS PROVIDED "AS IS".' >"${repository}/THIRD_PARTY_NOTICES.md"
  printf '%s\n' \
    'MIT License' \
    '' \
    'Permission is hereby granted, free of charge, to any person obtaining a copy.' >"${repository}/LICENSE"
}

commit_all() {
  local repository="$1"
  local message="$2"

  git -C "${repository}" add -A
  git -C "${repository}" commit -q -m "${message}"
}

licence_digest() {
  local repository="$1"
  local selected_ref="${2:-main}"

  git -C "${repository}" show "${selected_ref}:LICENSE" | shasum -a 256 | awk '{print $1}'
}

expect_pass() {
  local repository="$1"
  local selected_ref="${2:-main}"
  local approved_digest="${3:-$(licence_digest "${repository}" "${selected_ref}")}"

  "${checker}" \
    --repository "${repository}" \
    --ref "${selected_ref}" \
    --approved-author-email "${approved_email}" \
    --private-home-name "${private_home_name}" \
    --approved-license-sha256 "${approved_digest}" >/dev/null
}

expect_fail() {
  local repository="$1"
  local selected_ref="${2:-main}"
  local approved_digest="${3:-$(licence_digest "${repository}" "${selected_ref}")}"

  if "${checker}" \
    --repository "${repository}" \
    --ref "${selected_ref}" \
    --approved-author-email "${approved_email}" \
    --private-home-name "${private_home_name}" \
    --approved-license-sha256 "${approved_digest}" >/dev/null 2>&1; then
    echo "Expected the public-push readiness check to reject ${repository}." >&2
    exit 1
  fi
}

safe_repository="${fixture_root}/safe"
initialize_repository "${safe_repository}" "${approved_email}"
mkdir -p "${safe_repository}/script"
printf '%s\n' '/Users/alex/data/test.duckdb' >"${safe_repository}/script/portable-test-fixture.txt"
commit_all "${safe_repository}" "Initial public source"
expect_pass "${safe_repository}"

reserved_repository="${fixture_root}/all-rights-reserved"
initialize_repository "${reserved_repository}" "${approved_email}"
printf '%s\n' \
  'Copyright (c) 2026 DBCode Wrapper contributors.' \
  'All rights reserved.' >"${reserved_repository}/LICENSE"
commit_all "${reserved_repository}" "Initial public source"
expect_pass "${reserved_repository}"
expect_fail "${reserved_repository}" main '0000000000000000000000000000000000000000000000000000000000000000'

wrong_author_repository="${fixture_root}/wrong-author"
initialize_repository "${wrong_author_repository}" "personal@example.com"
commit_all "${wrong_author_repository}" "Initial public source"
expect_fail "${wrong_author_repository}"

deleted_snapshot_repository="${fixture_root}/deleted-snapshot"
initialize_repository "${deleted_snapshot_repository}" "${approved_email}"
mkdir -p "${deleted_snapshot_repository}/host"
printf '%s\n' '{"contributes":{}}' >"${deleted_snapshot_repository}/host/dbcode-public-contributions-1.36.2.json"
commit_all "${deleted_snapshot_repository}" "Add copied contribution snapshot"
rm "${deleted_snapshot_repository}/host/dbcode-public-contributions-1.36.2.json"
commit_all "${deleted_snapshot_repository}" "Remove copied contribution snapshot"
expect_fail "${deleted_snapshot_repository}"

private_key_repository="${fixture_root}/private-key"
initialize_repository "${private_key_repository}" "${approved_email}"
printf '%s%s\n%s\n%s%s\n' \
  '-----BEGIN ' 'PRIVATE KEY-----' \
  'test-only-material' \
  '-----END ' 'PRIVATE KEY-----' >"${private_key_repository}/innocent-notes.txt"
commit_all "${private_key_repository}" "Add unsafe material"
expect_fail "${private_key_repository}"

token_repository="${fixture_root}/token"
initialize_repository "${token_repository}" "${approved_email}"
printf '%s%s\n' 'ghp_' 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' >"${token_repository}/innocent-notes.txt"
commit_all "${token_repository}" "Add unsafe token"
expect_fail "${token_repository}"

personal_path_repository="${fixture_root}/personal-path"
initialize_repository "${personal_path_repository}" "${approved_email}"
printf '%s%s%s\n' '/Users/' "${private_home_name}" '/private-project' >"${personal_path_repository}/innocent-notes.txt"
commit_all "${personal_path_repository}" "Add personal path"
expect_fail "${personal_path_repository}"

commit_message_token_repository="${fixture_root}/commit-message-token"
initialize_repository "${commit_message_token_repository}" "${approved_email}"
commit_all "${commit_message_token_repository}" "Initial public source"
printf '%s\n' 'safe file' >"${commit_message_token_repository}/notes.txt"
git -C "${commit_message_token_repository}" add notes.txt
unsafe_commit_message="$(printf '%s%s' 'ghp_' 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB')"
git -C "${commit_message_token_repository}" commit -q -m "${unsafe_commit_message}"
expect_fail "${commit_message_token_repository}"

commit_message_path_repository="${fixture_root}/commit-message-path"
initialize_repository "${commit_message_path_repository}" "${approved_email}"
commit_all "${commit_message_path_repository}" "Initial public source"
printf '%s\n' 'safe file' >"${commit_message_path_repository}/notes.txt"
git -C "${commit_message_path_repository}" add notes.txt
unsafe_path_message="$(printf '%s%s%s' '/Users/' "${private_home_name}" '/private-project')"
git -C "${commit_message_path_repository}" commit -q -m "${unsafe_path_message}"
expect_fail "${commit_message_path_repository}"

tagger_repository="${fixture_root}/tagger-email"
initialize_repository "${tagger_repository}" "${approved_email}"
commit_all "${tagger_repository}" "Initial public source"
git -C "${tagger_repository}" config user.email "personal@example.com"
git -C "${tagger_repository}" tag -a public-v1 -m "Approved public source"
expect_fail "${tagger_repository}" public-v1

tag_message_repository="${fixture_root}/tag-message"
initialize_repository "${tag_message_repository}" "${approved_email}"
commit_all "${tag_message_repository}" "Initial public source"
unsafe_tag_message="$(printf '%s%s' 'ghp_' 'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC')"
git -C "${tag_message_repository}" tag -a public-v1 -m "${unsafe_tag_message}"
expect_fail "${tag_message_repository}" public-v1

nested_tag_repository="${fixture_root}/nested-tag"
initialize_repository "${nested_tag_repository}" "${approved_email}"
commit_all "${nested_tag_repository}" "Initial public source"
git -C "${nested_tag_repository}" config user.email "personal@example.com"
unsafe_inner_tag_message="$(printf '%s%s' 'ghp_' 'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD')"
git -C "${nested_tag_repository}" tag -a private-inner -m "${unsafe_inner_tag_message}"
git -C "${nested_tag_repository}" config user.email "${approved_email}"
git -C "${nested_tag_repository}" tag -a public-v1 private-inner -m "Approved public source" 2>/dev/null
expect_fail "${nested_tag_repository}" public-v1

deleted_database_repository="${fixture_root}/deleted-database"
initialize_repository "${deleted_database_repository}" "${approved_email}"
printf '%s\n' 'test database data' >"${deleted_database_repository}/customer.sqlite"
commit_all "${deleted_database_repository}" "Add unsafe local database"
rm "${deleted_database_repository}/customer.sqlite"
commit_all "${deleted_database_repository}" "Remove unsafe local database"
expect_fail "${deleted_database_repository}"

echo "Exact-ref public-push readiness checks passed."
