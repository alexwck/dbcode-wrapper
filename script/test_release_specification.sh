#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
release_specification="${repo_root}/script/release_specification.sh"
release_lock="${repo_root}/host/release-lock.json"

[[ -x "${release_specification}" ]] || {
  echo "Missing executable Release Specification interface: ${release_specification}" >&2
  exit 1
}

"${release_specification}" validate "${release_lock}" >/dev/null
jq -e '.schema_version == 6' "${release_lock}" >/dev/null

build_record="$("${release_specification}" build "${release_lock}")"
compiled_host_record="$("${release_specification}" compiled-host "${release_lock}")"
extension_record="$("${release_specification}" extensions "${release_lock}")"
profile_record="$("${release_specification}" profile "${release_lock}")"
identity_record="$("${release_specification}" identity "${release_lock}")"

jq -e '
  .schema_version == 1
  and .target == {platform: "darwin", architecture: "arm64"}
  and .upstream.code_oss.tag == "1.126.0"
  and .upstream.code_oss.published_at == "2026-06-24T12:49:34Z"
  and .upstream.code_oss.release_notes_url == "https://github.com/microsoft/vscode/releases/tag/1.126.0"
  and .runtime.code_oss_version == "1.126.0"
  and .release.wrapper_version == "0.1.3"
  and .release.release_set_base_id == "code-oss-1.126.0-dbcode-1.36.4"
  and .distribution.channel == "github-published-release"
  and .distribution.repository == "alexwck/dbcode-wrapper"
  and .distribution.public_download == true
  and .distribution.dbcode_bundled == false
  and .distribution.release_assets == ["dmg", "checksum"]
  and .product.application_name == "dbcode-wrapper"
  and (has("extension") | not)
' <<<"${build_record}" >/dev/null

jq -e \
  --arg code_oss_commit "$(jq -er '.upstream.code_oss.commit' "${release_lock}")" '
  .schema_version == 1
  and .target == {platform: "darwin", architecture: "arm64"}
  and .upstream.code_oss.commit == $code_oss_commit
  and .product.app_name == "DBCode Wrapper"
  and .product.document_extensions == ["sql"]
  and (has("extension") | not)
  and (has("release") | not)
  and (.product | has("signing") | not)
' <<<"${compiled_host_record}" >/dev/null

jq -e '
  .schema_version == 1
  and .host_code_oss_version == "1.126.0"
  and .dbcode.id == "dbcode.dbcode"
  and .dbcode.version == "1.36.4"
  and .dbcode.release_notes_url == "https://dbcode.io/docs/changelog/1.36.4"
  and .python_notebooks.required == true
  and (.packages | length) == 7
  and ([.packages[].id] | unique | length) == 7
' <<<"${extension_record}" >/dev/null

jq -e '
  .schema_version == 1
  and .profile_schema_version == 1
  and .product.app_name == "DBCode Wrapper"
  and .product.application_name == "dbcode-wrapper"
  and .product.bundle_identifier == "io.alexabelle.dbcodewrapper"
  and .product.data_folder_name == ".dbcode-wrapper"
  and .product.user_data_folder_name == "DBCode Wrapper"
  and .product.extensions_folder_name == "extensions"
  and .product.shared_data_folder_name == ".dbcode-wrapper-shared"
  and .product.backup_folder_name == "DBCode Wrapper Profile Backups"
  and .product.storage_namespace == "dbcode-wrapper"
  and .product.query_folder_name == "queries"
  and .product.document_extensions == ["sql"]
  and .product.focused_shell.enabled == true
  and (has("extension") | not)
' <<<"${profile_record}" >/dev/null

jq -e '
  .schema_version == 1
  and .profile_schema_version == 1
  and .extension.dbcode.version == "1.36.4"
  and (.runtime_extensions | length) == 7
  and (has("release") | not)
' <<<"${identity_record}" >/dev/null

test_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-release-specification.XXXXXX")"
cleanup_test_root() {
  rm -rf "${test_root}"
}
trap cleanup_test_root EXIT INT TERM

invalid_schema="${test_root}/invalid-schema.json"
missing_profile_identity="${test_root}/missing-profile-identity.json"
unsafe_profile_identity="${test_root}/unsafe-profile-identity.json"
unsafe_application_identity="${test_root}/unsafe-application-identity.json"
unsafe_bundle_identity="${test_root}/unsafe-bundle-identity.json"
missing_distribution="${test_root}/missing-distribution.json"
missing_package="${test_root}/missing-package.json"
duplicate_package_id="${test_root}/duplicate-package-id.json"
mismatched_release_notes="${test_root}/mismatched-release-notes.json"
invalid_published_at="${test_root}/invalid-published-at.json"
symlinked_lock="${test_root}/symlinked-lock.json"
historical_schema_2="${test_root}/historical-schema-2.json"
historical_schema_2_with_notebooks="${test_root}/historical-schema-2-with-notebooks.json"
malformed_historical_schema_2="${test_root}/malformed-historical-schema-2.json"
historical_schema_4="${test_root}/historical-schema-4.json"
historical_schema_5="${test_root}/historical-schema-5.json"
different_historical_schema_4="${test_root}/different-historical-schema-4.json"
different_host_schema_4="${test_root}/different-host-schema-4.json"
profile_only_schema_5="${test_root}/profile-only-schema-5.json"
query_storage_schema_5="${test_root}/query-storage-schema-5.json"
schema_2_with_release="${test_root}/schema-2-with-release.json"
schema_4_without_release="${test_root}/schema-4-without-release.json"
schema_4_without_notebooks="${test_root}/schema-4-without-notebooks.json"
schema_2_with_false_timestamp="${test_root}/schema-2-with-false-timestamp.json"
schema_4_with_false_contribution_digest="${test_root}/schema-4-with-false-contribution-digest.json"
schema_4_with_false_signing="${test_root}/schema-4-with-false-signing.json"
jq '.schema_version = 99' "${release_lock}" > "${invalid_schema}"
jq 'del(.product.storage_namespace)' "${release_lock}" > "${missing_profile_identity}"
jq '.product.query_folder_name = "../queries"' "${release_lock}" > "${unsafe_profile_identity}"
jq '.product.application_name = "../dbcode-wrapper"' "${release_lock}" > "${unsafe_application_identity}"
jq '.product.bundle_identifier = "not a bundle identifier"' "${release_lock}" > "${unsafe_bundle_identity}"
jq 'del(.distribution)' "${release_lock}" > "${missing_distribution}"
jq 'del(.extension.dbcode.sha256)' "${release_lock}" > "${missing_package}"
jq '.extension.python_notebooks.packages[1].namespace = .extension.python_notebooks.packages[0].namespace
  | .extension.python_notebooks.packages[1].name = .extension.python_notebooks.packages[0].name
  | .extension.python_notebooks.packages[1].id = .extension.python_notebooks.packages[0].id' \
  "${release_lock}" > "${duplicate_package_id}"
jq '.upstream.code_oss.release_notes_url = "https://github.com/microsoft/vscode/releases/tag/1.125.0"' \
  "${release_lock}" > "${mismatched_release_notes}"
jq '.upstream.code_oss.published_at = "not-a-date"' \
  "${release_lock}" > "${invalid_published_at}"
ln -s "${release_lock}" "${symlinked_lock}"
jq '
  .schema_version = 2
  | del(
      .release,
      .product.signing,
      .upstream.vscodium.published_at,
      .upstream.vscodium.release_notes_url,
      .upstream.code_oss.published_at,
      .upstream.code_oss.release_notes_url,
      .extension.dbcode.target_platform,
      .extension.dbcode.published_at,
      .extension.dbcode.release_notes_url,
      .extension.dbcode.jq_sorted_compact_contributes_sha256,
      .extension.python_notebooks
    )
' "${release_lock}" > "${historical_schema_2}"
jq --slurpfile current "${release_lock}" \
  '.extension.python_notebooks = $current[0].extension.python_notebooks' \
  "${historical_schema_2}" > "${historical_schema_2_with_notebooks}"
jq 'del(.extension.dbcode.sha256)' \
  "${historical_schema_2}" > "${malformed_historical_schema_2}"
jq '
  .schema_version = 4
  |
  del(
    .upstream.code_oss.published_at,
    .upstream.code_oss.release_notes_url,
    .extension.dbcode.release_notes_url
  )
' "${release_lock}" > "${historical_schema_4}"
jq '
  .schema_version = 5
  | del(.distribution, .release.wrapper_version)
' "${release_lock}" > "${historical_schema_5}"
jq '.extension.dbcode.version = "1.36.1"' \
  "${historical_schema_4}" > "${different_historical_schema_4}"
jq '.upstream.code_oss.commit = ("0" * 40)' \
  "${historical_schema_4}" > "${different_host_schema_4}"
jq '
  .product.user_data_folder_name = "Alternate Profile Data"
  | .product.extensions_folder_name = "alternate-extensions"
  | .product.backup_folder_name = "Alternate Profile Backups"
  | .release.profile_schema_version += 1
' "${release_lock}" > "${profile_only_schema_5}"
jq '.product.storage_namespace = "alternate-storage"' \
  "${release_lock}" > "${query_storage_schema_5}"
jq '.release = {
  release_set_base_id: "code-oss-1.126.0-dbcode-1.36.4",
  compatibility_status: "approved",
  profile_schema_version: 1,
  validation_issue: "invalid-schema-2-release"
}' "${historical_schema_2}" > "${schema_2_with_release}"
jq 'del(.release)' \
  "${historical_schema_4}" > "${schema_4_without_release}"
jq 'del(.extension.python_notebooks)' \
  "${historical_schema_4}" > "${schema_4_without_notebooks}"
jq '.upstream.vscodium.published_at = false' \
  "${historical_schema_2}" > "${schema_2_with_false_timestamp}"
jq '.extension.dbcode.jq_sorted_compact_contributes_sha256 = false' \
  "${historical_schema_4}" > "${schema_4_with_false_contribution_digest}"
jq '.product.signing = false' \
  "${historical_schema_4}" > "${schema_4_with_false_signing}"

for invalid_lock in "${invalid_schema}" "${missing_profile_identity}" "${unsafe_profile_identity}" "${unsafe_application_identity}" "${unsafe_bundle_identity}" "${missing_distribution}" "${missing_package}" "${duplicate_package_id}" "${mismatched_release_notes}" "${invalid_published_at}" "${symlinked_lock}"; do
  if "${release_specification}" validate "${invalid_lock}" >/dev/null 2>&1; then
    echo "Release Specification accepted invalid input: ${invalid_lock}" >&2
    exit 1
  fi
  if "${release_specification}" build "${invalid_lock}" >/dev/null 2>&1; then
    echo "Release Specification returned a purpose record for invalid input: ${invalid_lock}" >&2
    exit 1
  fi
done

if "${release_specification}" validate "${historical_schema_2}" >/dev/null 2>&1; then
  echo "Strict Release Specification validation accepted a frozen historical record." >&2
  exit 1
fi
if "${release_specification}" validate "${historical_schema_5}" >/dev/null 2>&1; then
  echo "Strict Release Specification validation accepted the public host-release schema." >&2
  exit 1
fi

"${release_specification}" historical-validate "${historical_schema_2}" >/dev/null
"${release_specification}" historical-validate \
  "${historical_schema_2_with_notebooks}" >/dev/null
"${release_specification}" historical-validate "${historical_schema_5}" >/dev/null
historical_notebook_extension_record="$(
  "${release_specification}" historical-extensions \
    "${historical_schema_2_with_notebooks}"
)"
jq -e '
  .python_notebooks.required == true
  and (.packages | length) == 7
' <<<"${historical_notebook_extension_record}" >/dev/null
historical_build_record="$(
  "${release_specification}" historical-build "${historical_schema_2}"
)"
historical_extension_record="$(
  "${release_specification}" historical-extensions "${historical_schema_2}"
)"
historical_profile_record="$(
  "${release_specification}" historical-profile "${historical_schema_2}"
)"
historical_identity_record="$(
  "${release_specification}" historical-identity "${historical_schema_2}"
)"

jq -e '
  .schema_version == 1
  and .runtime.code_oss_version == "1.126.0"
  and .target == {platform: "darwin", architecture: "arm64"}
  and .release == null
' <<<"${historical_build_record}" >/dev/null

jq -e '
  .schema_version == 1
  and .dbcode.id == "dbcode.dbcode"
  and .dbcode.target_platform == "universal"
  and .python_notebooks.required == false
  and .packages == [.dbcode + {role: "database-client"}]
' <<<"${historical_extension_record}" >/dev/null

jq -e '
  .schema_version == 1
  and .profile_schema_version == 1
  and .product.bundle_identifier == "io.alexabelle.dbcodewrapper"
' <<<"${historical_profile_record}" >/dev/null

expected_historical_identity="$(
  jq -S -c '{
    schema_version,
    target,
    upstream,
    toolchain,
    runtime,
    product,
    profile_schema_version,
    extension,
    runtime_extensions
  }' <<<"${historical_identity_record}"
)"
[[ "${historical_identity_record}" == "${expected_historical_identity}" ]] || {
  echo "Historical Release Specification identity output is not canonical." >&2
  exit 1
}
jq -e '
  .profile_schema_version == 1
  and .runtime_extensions == [{
    role: "database-client",
    id: "dbcode.dbcode",
    version: "1.36.4",
    target_platform: "universal",
    vsix_sha256: .runtime_extensions[0].vsix_sha256,
    signature_archive_sha256: .runtime_extensions[0].signature_archive_sha256
  }]
' <<<"${historical_identity_record}" >/dev/null

if "${release_specification}" historical-validate \
  "${malformed_historical_schema_2}" >/dev/null 2>&1; then
  echo "Historical Release Specification validation accepted a missing DBCode digest." >&2
  exit 1
fi

for invalid_historical_lock in \
  "${schema_2_with_release}" \
  "${schema_4_without_release}" \
  "${schema_4_without_notebooks}" \
  "${schema_2_with_false_timestamp}" \
  "${schema_4_with_false_contribution_digest}" \
  "${schema_4_with_false_signing}"; do
  if "${release_specification}" historical-validate \
    "${invalid_historical_lock}" >/dev/null 2>&1; then
    echo "Historical Release Specification accepted fields from the wrong frozen schema." >&2
    exit 1
  fi
done

"${release_specification}" same-dbcode-payload \
  "${release_lock}" "${historical_schema_4}" >/dev/null
if "${release_specification}" same-dbcode-payload \
  "${release_lock}" "${different_historical_schema_4}" >/dev/null 2>&1; then
  echo "Release Specification treated a different DBCode version as the same package." >&2
  exit 1
fi

"${release_specification}" same-host-build-contract \
  "${release_lock}" "${historical_schema_4}" >/dev/null
"${release_specification}" same-host-build-contract \
  "${release_lock}" "${profile_only_schema_5}" >/dev/null
if "${release_specification}" same-host-build-contract \
  "${release_lock}" "${different_host_schema_4}" >/dev/null 2>&1; then
  echo "Release Specification treated a different Code OSS commit as the same host runtime." >&2
  exit 1
fi
if "${release_specification}" same-host-build-contract \
  "${release_lock}" "${query_storage_schema_5}" >/dev/null 2>&1; then
  echo "Release Specification reused a host with a different compiled query identity." >&2
  exit 1
fi

if "${release_specification}" unknown "${release_lock}" >/dev/null 2>&1; then
  echo "Release Specification accepted an unknown purpose." >&2
  exit 1
fi

echo "Release Specification purpose-level record contracts passed."
