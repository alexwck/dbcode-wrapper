#!/usr/bin/env bash

set -euo pipefail
umask 077

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_root}/.." && pwd)"
source "${script_root}/lib/host_config.sh"

cache_library="${script_root}/lib/compiled_host_cache.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-compiled-host-cache.XXXXXX")"
fixture_source="${test_root}/source tree"
fixture_cache="${test_root}/cache root"
fixture_app="${test_root}/Fixture Host.app"
fixture_environment="${test_root}/compiled-host-environment.json"

cleanup() {
  rm -rf "${test_root}"
}
trap cleanup EXIT INT TERM

[[ -f "${cache_library}" ]] || {
  echo "Missing compiled-host cache module: ${cache_library}" >&2
  exit 1
}
source "${cache_library}"

mkdir -p "${fixture_source}" "${fixture_app}/Contents"
ditto "${repo_root}/host" "${fixture_source}/host"
ditto "${repo_root}/script" "${fixture_source}/script"
printf '%s\n' 'compiled host fixture' > "${fixture_app}/Contents/payload.txt"
chmod 755 "${fixture_app}/Contents/payload.txt"
jq -n '{
  schema_version: 1,
  node: "v22.15.0",
  npm: "10.9.2",
  python: "3.9.6",
  clang: "Apple clang version 17.0.0",
  macos_sdk: "15.5",
  macos: "15.5"
}' > "${fixture_environment}"

baseline_lock="${fixture_source}/host/release-lock.json"
dbcode_only_lock="${test_root}/dbcode-only-release-lock.json"
host_changed_lock="${test_root}/host-changed-release-lock.json"
profile_only_lock="${test_root}/profile-only-release-lock.json"
query_storage_lock="${test_root}/query-storage-release-lock.json"

jq '
  .extension.dbcode.version = "9.9.9"
  | .extension.dbcode.release_notes_url = "https://dbcode.io/docs/changelog/9.9.9"
  | .release.release_set_base_id = ("code-oss-" + .runtime.code_oss_version + "-dbcode-9.9.9")
' "${baseline_lock}" > "${dbcode_only_lock}"
jq '.product.app_name = "Different Wrapper Name"' \
  "${baseline_lock}" > "${host_changed_lock}"
jq '
  .product.user_data_folder_name = "Alternate Profile Data"
  | .product.extensions_folder_name = "alternate-extensions"
  | .product.backup_folder_name = "Alternate Profile Backups"
  | .release.profile_schema_version += 1
' "${baseline_lock}" > "${profile_only_lock}"
jq '.product.storage_namespace = "alternate-storage"' \
  "${baseline_lock}" > "${query_storage_lock}"

baseline_id="$(compiled_host_input_id "${baseline_lock}" "${fixture_source}")"
dbcode_only_id="$(compiled_host_input_id "${dbcode_only_lock}" "${fixture_source}")"
host_changed_id="$(compiled_host_input_id "${host_changed_lock}" "${fixture_source}")"
profile_only_id="$(compiled_host_input_id "${profile_only_lock}" "${fixture_source}")"
query_storage_id="$(compiled_host_input_id "${query_storage_lock}" "${fixture_source}")"

[[ "${baseline_id}" =~ ^compiled-host-[0-9a-f]{64}$ ]]
[[ "${baseline_id}" == "${dbcode_only_id}" ]] || {
  echo "A DBCode-only release change invalidated the compiled host." >&2
  exit 1
}
[[ "${baseline_id}" != "${host_changed_id}" ]] || {
  echo "A host product change reused the compiled host." >&2
  exit 1
}
[[ "${baseline_id}" == "${profile_only_id}" ]] || {
  echo "A profile-only identity change invalidated the compiled host." >&2
  exit 1
}
[[ "${baseline_id}" != "${query_storage_id}" ]] || {
  echo "A compiled query identity change reused the compiled host." >&2
  exit 1
}

fixture_patch_plan="${fixture_source}/host/patches/patch-plan.json"
fixture_patch_plan_backup="${test_root}/patch-plan.json"
fixture_patch_plan_temp="${test_root}/patch-plan.tmp.json"
cp "${fixture_patch_plan}" "${fixture_patch_plan_backup}"
jq '
  .entries[0].purpose += " Plain-English clarification."
  | .entries[0].touched_areas[0] += " wording"
' "${fixture_patch_plan}" > "${fixture_patch_plan_temp}"
mv "${fixture_patch_plan_temp}" "${fixture_patch_plan}"
[[ "$(compiled_host_input_id "${baseline_lock}" "${fixture_source}")" == "${baseline_id}" ]] || {
  echo "Descriptive Patch Plan wording invalidated the compiled host." >&2
  exit 1
}
jq '.entries[0].order += 1' "${fixture_patch_plan_backup}" > "${fixture_patch_plan_temp}"
mv "${fixture_patch_plan_temp}" "${fixture_patch_plan}"
[[ "$(compiled_host_input_id "${baseline_lock}" "${fixture_source}")" != "${baseline_id}" ]] || {
  echo "A build-relevant Patch Plan change reused the compiled host." >&2
  exit 1
}
cp "${fixture_patch_plan_backup}" "${fixture_patch_plan}"

fixture_icon="${fixture_source}/host/icon/dbcode-wrapper.svg"
fixture_build_script="${fixture_source}/script/bootstrap_toolchain.sh"
chmod 600 "${fixture_icon}"
chmod 700 "${fixture_build_script}"
[[ "$(compiled_host_input_id "${baseline_lock}" "${fixture_source}")" == "${baseline_id}" ]] || {
  echo "Ambient checkout permissions invalidated the compiled host." >&2
  exit 1
}
chmod 644 "${fixture_icon}"
chmod 755 "${fixture_build_script}"
chmod 644 "${fixture_build_script}"
[[ "$(compiled_host_input_id "${baseline_lock}" "${fixture_source}")" != "${baseline_id}" ]] || {
  echo "A tracked executable-mode change reused the compiled host." >&2
  exit 1
}
chmod 755 "${fixture_build_script}"

printf '\n<!-- release-assembly-only fixture -->\n' >> \
  "${fixture_source}/host/extensions/dbcode-wrapper-release-status/package.json"
[[ "$(compiled_host_input_id "${baseline_lock}" "${fixture_source}")" == "${baseline_id}" ]] || {
  echo "A release-assembly extension change invalidated the compiled host." >&2
  exit 1
}

printf '\n# Historical validation adapter fixture.\n' >> \
  "${fixture_source}/script/lib/release_specification.sh"
[[ "$(compiled_host_input_id "${baseline_lock}" "${fixture_source}")" == "${baseline_id}" ]] || {
  echo "A historical compatibility adapter invalidated the compiled host." >&2
  exit 1
}
release_specification_backup="${test_root}/release-specification.sh"
cp "${fixture_source}/script/lib/release_specification.sh" "${release_specification_backup}"
printf '\nrelease_specification_record() { return 1; }\n' >> \
  "${fixture_source}/script/lib/release_specification.sh"
[[ "$(compiled_host_input_id "${baseline_lock}" "${fixture_source}")" != "${baseline_id}" ]] || {
  echo "An active Release Specification change reused the compiled host." >&2
  exit 1
}
cp "${release_specification_backup}" "${fixture_source}/script/lib/release_specification.sh"

release_records_module="${fixture_source}/script/lib/release_specification_records.jq"
release_records_backup="${test_root}/release-specification-records.jq"
cp "${release_records_module}" "${release_records_backup}"
printf '\n# Active record projection fixture.\n' >> "${release_records_module}"
[[ "$(compiled_host_input_id "${baseline_lock}" "${fixture_source}")" != "${baseline_id}" ]] || {
  echo "An active Release Specification record projection reused the compiled host." >&2
  exit 1
}
cp "${release_records_backup}" "${release_records_module}"

fixture_slimming_policy="${fixture_source}/host/slimming-policy.json"
fixture_slimming_backup="${test_root}/slimming-policy.json"
fixture_slimming_temp="${test_root}/slimming-policy.tmp.json"
cp "${fixture_slimming_policy}" "${fixture_slimming_backup}"
jq '.build.built_in_extensions.first_party[0].reason += " Documentation only."' \
  "${fixture_slimming_policy}" > "${fixture_slimming_temp}"
mv "${fixture_slimming_temp}" "${fixture_slimming_policy}"
[[ "$(compiled_host_input_id "${baseline_lock}" "${fixture_source}")" == "${baseline_id}" ]] || {
  echo "Assembly-only slimming guidance invalidated the compiled host." >&2
  exit 1
}
jq '.build.built_in_extensions.allowlist[0].name = "changed-compiled-built-in"' \
  "${fixture_slimming_policy}" > "${fixture_slimming_temp}"
mv "${fixture_slimming_temp}" "${fixture_slimming_policy}"
[[ "$(compiled_host_input_id "${baseline_lock}" "${fixture_source}")" != "${baseline_id}" ]] || {
  echo "A compiled built-in allowlist change reused the compiled host." >&2
  exit 1
}
cp "${fixture_slimming_backup}" "${fixture_slimming_policy}"

printf '\n<!-- compiled icon fixture -->\n' >> \
  "${fixture_source}/host/icon/dbcode-wrapper.svg"
[[ "$(compiled_host_input_id "${baseline_lock}" "${fixture_source}")" != "${baseline_id}" ]] || {
  echo "A compiled host icon change reused the compiled host." >&2
  exit 1
}

compiled_host_cache_publish \
  "${fixture_cache}" \
  "${baseline_id}" \
  "Fixture Host" \
  "${fixture_app}" \
  "0123456789abcdef0123456789abcdef01234567" \
  "${fixture_environment}"

cached_app="$(
  compiled_host_cache_resolve \
    "${fixture_cache}" \
    "${baseline_id}" \
    "Fixture Host"
)"
[[ -d "${cached_app}" && -f "${cached_app}/Contents/payload.txt" ]]
jq -e '
  .schema_version == 2
  and .app_digest_algorithm == "sha256-files-modes-links-v1"
  and .compilation_environment.node == "v22.15.0"
' "$(dirname "${cached_app}")/receipt.json" >/dev/null

chmod 644 "${cached_app}/Contents/payload.txt"
if compiled_host_cache_resolve \
  "${fixture_cache}" \
  "${baseline_id}" \
  "Fixture Host" >/dev/null 2>&1; then
  echo "The compiled-host cache accepted a changed executable mode." >&2
  exit 1
fi
compiled_host_cache_publish \
  "${fixture_cache}" \
  "${baseline_id}" \
  "Fixture Host" \
  "${fixture_app}" \
  "0123456789abcdef0123456789abcdef01234567" \
  "${fixture_environment}"
cached_app="$(
  compiled_host_cache_resolve \
    "${fixture_cache}" \
    "${baseline_id}" \
    "Fixture Host"
)"
[[ -x "${cached_app}/Contents/payload.txt" ]] || {
  echo "The rebuilt compiled-host cache did not restore the executable mode." >&2
  exit 1
}

printf '%s\n' 'tampered' >> "${cached_app}/Contents/payload.txt"
if compiled_host_cache_resolve \
  "${fixture_cache}" \
  "${baseline_id}" \
  "Fixture Host" >/dev/null 2>&1; then
  echo "The compiled-host cache accepted changed application bytes." >&2
  exit 1
fi

compiled_host_cache_publish \
  "${fixture_cache}" \
  "${baseline_id}" \
  "Fixture Host" \
  "${fixture_app}" \
  "0123456789abcdef0123456789abcdef01234567" \
  "${fixture_environment}"
rebuilt_cached_app="$(
  compiled_host_cache_resolve \
    "${fixture_cache}" \
    "${baseline_id}" \
    "Fixture Host"
)"
[[ "$(cat "${rebuilt_cached_app}/Contents/payload.txt")" == "compiled host fixture" ]] || {
  echo "A damaged compiled-host cache entry was not rebuilt from the source app." >&2
  exit 1
}
find "${fixture_cache}/compiled-hosts/rejected" \
  -mindepth 1 \
  -maxdepth 1 \
  -type d \
  -name "${baseline_id}-*" |
  grep -q . || {
  echo "The damaged compiled-host cache entry was not retained for investigation." >&2
  exit 1
}

symlink_guard_root="${test_root}/generated-root"
symlink_guard_outside="${test_root}/outside-generated-root"
mkdir -p "${symlink_guard_root}" "${symlink_guard_outside}"
for generated_parent in .build dist; do
  ln -s "${symlink_guard_outside}" "${symlink_guard_root}/${generated_parent}"
  if DBCODE_WRAPPER_GENERATED_REPO_ROOT="${symlink_guard_root}" \
    bash -c '
      source "$1"
      case "$2" in
        .build) assert_generated_path "${CACHE_ROOT}/compiled-hosts" ;;
        dist) assert_generated_path "${APP_BUNDLE}" ;;
      esac
    ' _ "${script_root}/lib/host_config.sh" "${generated_parent}" \
      >/dev/null 2>&1; then
    echo "Generated-path validation accepted a symbolic-link parent: ${generated_parent}" >&2
    exit 1
  fi
  rm "${symlink_guard_root}/${generated_parent}"
done

rg -Fq './build.sh' "${repo_root}/script/compile_host.sh"
if rg -Fq './build.sh' "${repo_root}/script/build_host.sh"; then
  echo "Release assembly still runs the upstream host build directly." >&2
  exit 1
fi
if rg -Fq 'bootstrap_toolchain.sh' "${repo_root}/script/assemble_host.sh"; then
  echo "A compiled-host cache hit still runs compiler-only preflight." >&2
  exit 1
fi
rg -Fq -- '--environment-record' "${repo_root}/script/compile_host.sh"
rg -Fq 'compilation_environment' "${repo_root}/script/generate_manifest.sh"
rg -Fq 'release_source_snapshot_materialize' "${repo_root}/script/build_host.sh"
rg -Fq '"${materialized_source}/script/assemble_host.sh"' \
  "${repo_root}/script/build_host.sh"
for assembly_contract in \
  'compiled_host_cache_resolve' \
  'compiled_host_cache_publish' \
  'copy_first_party_extensions' \
  'release_source_snapshot_verify_record'; do
  rg -Fq "${assembly_contract}" "${repo_root}/script/assemble_host.sh" || {
    echo "Release assembly is missing: ${assembly_contract}" >&2
    exit 1
  }
done

echo "Compiled-host cache contracts passed."
