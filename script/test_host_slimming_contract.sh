#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

if [[ $# -ne 0 ]]; then
  echo "Usage: ./script/test_host_slimming_contract.sh" >&2
  exit 2
fi

policy_file="${REPO_ROOT}/host/slimming-policy.json"
slimming_patch="${REPO_ROOT}/host/patches/code-oss/300-host-slimming-policy.patch"
slimming_check_module="${REPO_ROOT}/script/lib/host_slimming.sh"

[[ -f "${policy_file}" ]] || {
  echo "Missing host slimming policy: ${policy_file}" >&2
  exit 1
}

jq -e '
  .schema_version == 2 and
  .measurement_evidence == "docs/architecture/host-slimming-measurement-2026-07-21.md" and
  .goals == {installed_app_max_kib: 614400} and
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
  echo "The active slimming policy must keep build choices, size goals, rollback, and a separate evidence link." >&2
  exit 1
}

measurement_file="${REPO_ROOT}/$(jq -er '.measurement_evidence' "${policy_file}")"
[[ -f "${measurement_file}" && ! -L "${measurement_file}" ]] || {
  echo "The dated host-slimming measurement evidence is missing or linked." >&2
  exit 1
}
for required_measurement in \
  '826 files; 364,904,314 logical bytes; 358,596 allocated KiB' \
  'projected an installed app of 579,000 KiB' \
  'Electron Framework, installed | 270,980 KiB' \
  '274,400,008 logical bytes' \
  '## Recorded acceptance at the time'; do
  rg -Fq "${required_measurement}" "${measurement_file}" || {
    echo "The dated host-slimming evidence is incomplete: ${required_measurement}" >&2
    exit 1
  }
done

[[ -f "${slimming_check_module}" ]] || {
  echo "Static Host Smoke is missing its packaged-host slimming checks." >&2
  exit 1
}
source "${slimming_check_module}"
rg -Fq 'validate_packaged_host_slimming "${APP_BUNDLE}" "${slimming_policy}"' \
  "${REPO_ROOT}/script/smoke_host.sh" || {
  echo "Static Host Smoke does not run the packaged-host slimming checks." >&2
  exit 1
}

rg -Fq 'export DBCODE_WRAPPER_STRIP_SOURCE_MAPS="yes"' "${REPO_ROOT}/script/compile_host.sh" || {
  echo "Host compilation must request source-map omission explicitly." >&2
  exit 1
}
rg -Fq 'export DBCODE_WRAPPER_BUILTIN_EXTENSION_ALLOWLIST' "${REPO_ROOT}/script/compile_host.sh" || {
  echo "Host compilation must pass the reviewed built-in extension allowlist to Code OSS." >&2
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
  "${REPO_ROOT}/script/assemble_host.sh" \
  "${REPO_ROOT}/script/compile_host.sh" \
  "${REPO_ROOT}/script/sign_host.sh"; then
  echo "Source maps must be omitted by packaging, not deleted from the built or signed app." >&2
  exit 1
fi

fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-host-slimming.XXXXXX")"
cleanup_fixture() {
  rm -rf "${fixture_root}"
}
trap cleanup_fixture EXIT INT TERM
fixture_app="${fixture_root}/Fixture Host.app"
fixture_extensions="${fixture_app}/Contents/Resources/app/extensions"
fixture_product="${fixture_app}/Contents/Resources/app/product.json"
fixture_policy="${fixture_root}/slimming policy.json"
mkdir -p "${fixture_extensions}"
cp "${policy_file}" "${fixture_policy}"
jq -n '{builtInExtensions: []}' > "${fixture_product}"
while IFS= read -r extension_name; do
  mkdir -p "${fixture_extensions}/${extension_name}"
  jq -n --arg name "${extension_name}" \
    '{name: $name, publisher: "wrapper-fixture"}' > \
    "${fixture_extensions}/${extension_name}/package.json"
done < <(
  jq -r \
    '([.build.built_in_extensions.allowlist[].name] + [.build.built_in_extensions.first_party[].name]) | sort[]' \
    "${fixture_policy}"
)

validate_packaged_host_slimming "${fixture_app}" "${fixture_policy}"

oversize_policy="${fixture_root}/oversize policy.json"
jq '.goals.installed_app_max_kib = 0' "${fixture_policy}" > "${oversize_policy}"
if validate_packaged_host_slimming "${fixture_app}" "${oversize_policy}" >/dev/null 2>&1; then
  echo "Static Host Smoke accepted an app above its installed-size limit." >&2
  exit 1
fi

touch "${fixture_app}/unexpected.map"
if validate_packaged_host_slimming "${fixture_app}" "${fixture_policy}" >/dev/null 2>&1; then
  echo "Static Host Smoke accepted a packaged source map." >&2
  exit 1
fi
rm "${fixture_app}/unexpected.map"

mkdir -p "${fixture_extensions}/unexpected-extension"
jq -n '{name: "unexpected-extension", publisher: "wrapper-fixture"}' > \
  "${fixture_extensions}/unexpected-extension/package.json"
if validate_packaged_host_slimming "${fixture_app}" "${fixture_policy}" >/dev/null 2>&1; then
  echo "Static Host Smoke accepted an unexpected built-in extension." >&2
  exit 1
fi
rm -rf "${fixture_extensions}/unexpected-extension"

sql_manifest="${fixture_extensions}/sql/package.json"
cp "${sql_manifest}" "${fixture_root}/sql-package.json"
jq -n '{name: "dbcode", publisher: "dbcode"}' > "${sql_manifest}"
if validate_packaged_host_slimming "${fixture_app}" "${fixture_policy}" >/dev/null 2>&1; then
  echo "Static Host Smoke accepted embedded DBCode." >&2
  exit 1
fi
cp "${fixture_root}/sql-package.json" "${sql_manifest}"

printf '{' > "${sql_manifest}"
if validate_packaged_host_slimming "${fixture_app}" "${fixture_policy}" >/dev/null 2>&1; then
  echo "Static Host Smoke accepted an invalid extension manifest." >&2
  exit 1
fi
cp "${fixture_root}/sql-package.json" "${sql_manifest}"

mv "${fixture_extensions}/sql" "${fixture_root}/outside-sql"
ln -s "${fixture_root}/outside-sql" "${fixture_extensions}/sql"
if validate_packaged_host_slimming "${fixture_app}" "${fixture_policy}" >/dev/null 2>&1; then
  echo "Static Host Smoke followed a linked extension directory." >&2
  exit 1
fi

echo "Host slimming contract checks passed."
