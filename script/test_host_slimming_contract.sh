#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

check_built_artifact="yes"
if [[ $# -eq 1 && "${1}" == "--source-only" ]]; then
  check_built_artifact="no"
elif [[ $# -ne 0 ]]; then
  echo "Usage: ./script/test_host_slimming_contract.sh [--source-only]" >&2
  exit 2
fi

policy_file="${REPO_ROOT}/host/slimming-policy.json"
audit_script="${REPO_ROOT}/script/audit_host_size.sh"
slimming_patch="${REPO_ROOT}/host/patches/code-oss/300-host-slimming-policy.patch"

[[ -f "${policy_file}" ]] || {
  echo "Missing host slimming policy: ${policy_file}" >&2
  exit 1
}

jq -e '
  .schema_version == 1 and
  .baseline.signed_app.installed_kib == 937596 and
  .baseline.signed_app.indicative_archive_bytes == 264659573 and
  .baseline.electron_framework.installed_kib == 270980 and
  .baseline.code_oss_application.installed_kib == 642436 and
  .baseline.built_in_extensions.actual_extension_count == 93 and
  .baseline.built_in_extensions.shared_node_modules_present == true and
  .baseline.built_in_extensions.installed_kib == 167336 and
  .baseline.source_maps.file_count == 826 and
  .baseline.source_maps.logical_bytes == 364904314 and
  .baseline.source_maps.allocated_kib == 358596 and
  .baseline.external_dbcode.version == "1.36.1" and
  .baseline.external_dbcode.included_in_app == false and
  .baseline.external_dbcode.installed_kib == 271444 and
  .baseline.external_dbcode.logical_bytes == 274298343 and
  .baseline.external_dbcode.vsix_bytes == 43262773 and
  .goals.installed_app_max_kib == 614400 and
  .goals.indicative_archive_max_bytes == 200000000 and
  .goals.installed_app_max_kib < (.baseline.signed_app.installed_kib * 0.7) and
  .goals.indicative_archive_max_bytes < (.baseline.signed_app.indicative_archive_bytes * 0.8) and
  .result.signed_app.installed_kib == 462100 and
  .result.signed_app.indicative_archive_bytes == 166475377 and
  .result.signed_app.installed_reduction_kib == 475496 and
  .result.signed_app.archive_reduction_bytes == 98184196 and
  .result.electron_framework.installed_kib == 270980 and
  .result.code_oss_application.installed_kib == 167472 and
  .result.built_in_extensions == {actual_extension_count: 9, shared_node_modules_present: false, installed_kib: 776} and
  .result.source_maps == {file_count: 0, logical_bytes: 0, allocated_kib: 0} and
  .result.external_dbcode == {
    version: "1.36.2",
    included_in_app: false,
    installed_kib: 271532,
    logical_bytes: 274400008,
    vsix_bytes: 43297713
  } and
  .result.external_runtime == {
    extension_count: 7,
    included_in_app: false,
    installed_kib: 361544,
    logical_bytes: 359124746,
    vsix_bytes: 70858742
  } and
  .result.external_dbcode.included_in_app == false and
  .result.startup_smoke.median_wall_time_seconds == 7.18 and
  .result.startup_smoke.controlled_pre_slim_baseline_available == false and
  .build.ship_source_maps == false and
  .build.built_in_extensions.mode == "allowlist" and
  .build.built_in_extensions.rollback_paths.all_built_ins != null and
  ([.build.built_in_extensions.allowlist[].name] | sort) == ["ipynb", "notebook-renderers", "python", "sql", "theme-defaults", "theme-seti"] and
  .build.built_in_extensions.first_party == [
    {
      name: "dbcode-wrapper-python-kernel",
      source: "host/extensions/dbcode-wrapper-python-kernel",
      reason: "The focused bridge starts a user-selected Jupyter kernel for DBCode Python cells without exposing a general Jupyter workbench."
    },
    {
      name: "dbcode-wrapper-release-status",
      source: "host/extensions/dbcode-wrapper-release-status",
      reason: "The focused bridge reports official host and DBCode release metadata without exposing an extension marketplace or automatic updater."
    },
    {
      name: "dbcode-wrapper-profile-migration",
      source: "host/extensions/dbcode-wrapper-profile-migration",
      reason: "The focused first-run bridge verifies and installs the pinned external runtime on a fresh Mac, then reviews non-secret connection details without reading another editor profile or secret store."
    }
  ] and
  all(.build.built_in_extensions.allowlist[]; (.reason | length) > 30 and .rollback == "all_built_ins") and
  all(.build.built_in_extensions.removed_groups[]; (.reason | length) > 30 and (.names | length) > 0 and .rollback == "all_built_ins") and
  (([.build.built_in_extensions.allowlist[].name] + [.build.built_in_extensions.removed_groups[].names[]]) | length) == 93 and
  (([.build.built_in_extensions.allowlist[].name] + [.build.built_in_extensions.removed_groups[].names[]]) | unique | length) == 93
' "${policy_file}" >/dev/null || {
  echo "The slimming policy must keep the measured baseline and separate material installed and archive goals." >&2
  exit 1
}

[[ -x "${audit_script}" ]] || {
  echo "The reproducible host size audit is missing or not executable." >&2
  exit 1
}
bash -n "${audit_script}"

rg -Fq -- '--runtime-extensions' "${audit_script}" || {
  echo "The size audit must measure the complete external runtime set separately from the app bundle." >&2
  exit 1
}
rg -Fq 'external_runtime:' "${audit_script}" || {
  echo "The size audit must report the complete external runtime set." >&2
  exit 1
}

rg -Fq 'export DBCODE_WRAPPER_STRIP_SOURCE_MAPS="yes"' "${REPO_ROOT}/script/build_host.sh" || {
  echo "The production build must request source-map omission explicitly." >&2
  exit 1
}
rg -Fq 'export DBCODE_WRAPPER_BUILTIN_EXTENSION_ALLOWLIST' "${REPO_ROOT}/script/build_host.sh" || {
  echo "The production build must pass the reviewed built-in extension allowlist to Code OSS." >&2
  exit 1
}
rg -Fq "process.env['DBCODE_WRAPPER_STRIP_SOURCE_MAPS'] === 'yes'" "${slimming_patch}" || {
  echo "The Code OSS packaging overlay must use the explicit source-map policy." >&2
  exit 1
}
rg -Fq "process.env['DBCODE_WRAPPER_BUILTIN_EXTENSION_ALLOWLIST']" "${slimming_patch}" || {
  echo "The Code OSS packaging overlay must read the reviewed built-in extension allowlist." >&2
  exit 1
}
rg -Fq "!.build/extensions/node_modules/**" "${slimming_patch}" || {
  echo "The allowlisted declarative extensions must not retain shared dependencies from removed built-ins." >&2
  exit 1
}
rg -Fq "path.join(import.meta.dirname, '..', '.build', 'extensions')" "${slimming_patch}" || {
  echo "The allowlist must resolve the built-in extension directory without depending on a later local variable." >&2
  exit 1
}
source_map_filter_count="$(rg -Fc "!**/*.map" "${slimming_patch}")"
[[ "${source_map_filter_count}" -eq 2 ]] || {
  echo "The Code OSS packaging overlay must omit maps from application and dependency streams." >&2
  exit 1
}

if rg -n '(find .*\.map.*-delete|rm .*\.map)' \
  "${REPO_ROOT}/script/build_host.sh" \
  "${REPO_ROOT}/script/sign_host.sh"; then
  echo "Source maps must be omitted by packaging, not deleted from the built or signed app." >&2
  exit 1
fi

if [[ "${check_built_artifact}" == "yes" && -d "${APP_BUNDLE}" ]]; then
  audit_json="$("${audit_script}" --app "${APP_BUNDLE}" --no-archive)"
  expected_allowlist="$(jq -c '([.build.built_in_extensions.allowlist[].name] + [.build.built_in_extensions.first_party[].name]) | sort' "${policy_file}")"
  actual_allowlist="$(find "${APP_BUNDLE}/Contents/Resources/app/extensions" -mindepth 2 -maxdepth 2 -name package.json -print | sed 's#/package.json$##; s#.*/extensions/##' | LC_ALL=C sort | jq -R -s -c 'split("\n")[:-1]')"
  [[ "${actual_allowlist}" == "${expected_allowlist}" ]] || {
    echo "The built app extension set does not match the reviewed allowlist." >&2
    echo "Expected: ${expected_allowlist}" >&2
    echo "Actual:   ${actual_allowlist}" >&2
    exit 1
  }
  jq -e --argjson max_installed_kib "$(jq -er '.goals.installed_app_max_kib' "${policy_file}")" '
    .source_maps.file_count == 0 and
    .signed_app.installed_kib <= $max_installed_kib and
    .built_in_extensions.actual_extension_count == 9 and
    .built_in_extensions.shared_node_modules_present == false and
    .external_dbcode.included_in_app == false
  ' <<<"${audit_json}" >/dev/null || {
    echo "The built app does not satisfy the installed-size or source-map contract." >&2
    exit 1
  }
  jq -e '.builtInExtensions | length == 0' "${APP_BUNDLE}/Contents/Resources/app/product.json" >/dev/null || {
    echo "The packaged product must not advertise removed marketplace built-ins." >&2
    exit 1
  }
fi

echo "Host slimming contract checks passed."
