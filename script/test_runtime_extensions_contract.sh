#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

expected_extension_ids='[
  "dbcode.dbcode",
  "ms-python.python",
  "ms-toolsai.jupyter",
  "ms-toolsai.jupyter-keymap",
  "ms-toolsai.jupyter-renderers",
  "ms-toolsai.vscode-jupyter-cell-tags",
  "ms-toolsai.vscode-jupyter-slideshow"
]'

jq -e \
  --argjson expected_extension_ids "${expected_extension_ids}" '
  .dbcode.version == "1.36.2" and
  .python_notebooks.required == true and
  .python_notebooks.user_installation_required == false and
  .python_notebooks.kernel_runtime == "user-selected" and
  ((.packages | map(.id) | sort) == $expected_extension_ids) and
  ((.packages | map(.id) | length) == (.packages | map(.id) | unique | length)) and
  all(.packages[];
    . as $package |
    $package.namespace == ($package.id | split(".")[0]) and
    $package.name == ($package.id | split(".")[1]) and
    $package.publisher == $package.namespace and
    ($package.version | type == "string" and length > 0) and
    ($package.engine | type == "string" and length > 0) and
    $package.verified_publisher == true and
    $package.pre_release == false and
    $package.deprecated == false and
    ($package.registry_api_url == ("https://open-vsx.org/api/" + $package.namespace + "/" + $package.name + "/" + $package.version)) and
    ($package.target_platform == "universal" or $package.target_platform == "darwin-arm64") and
    ($package.download_url | startswith("https://open-vsx.org/api/" + $package.namespace + "/" + $package.name + "/")) and
    ($package.download_url | contains("/" + $package.version + "/file/")) and
    ($package.signature_url | startswith("https://open-vsx.org/api/" + $package.namespace + "/" + $package.name + "/")) and
    ($package.signature_url | contains("/" + $package.version + "/file/")) and
    ($package.sha256_url | startswith("https://open-vsx.org/api/" + $package.namespace + "/" + $package.name + "/")) and
    ($package.sha256_url | contains("/" + $package.version + "/file/")) and
    ($package.public_key_url | startswith("https://open-vsx.org/api/-/public-key/")) and
    ($package.sha256 | test("^[0-9a-f]{64}$")) and
    ($package.signature_archive_sha256 | test("^[0-9a-f]{64}$")) and
    ($package.public_key_sha256 | test("^[0-9a-f]{64}$")) and
    ($package.package_size > 0)
  )
' <<<"${RELEASE_EXTENSION_SPEC}" >/dev/null || {
  echo "The release lock must define DBCode 1.36.2 and the complete mandatory Python-notebook runtime set." >&2
  exit 1
}

manifest_generator="${REPO_ROOT}/script/generate_manifest.sh"
host_smoke="${REPO_ROOT}/script/smoke_host.sh"
runtime_preparer="${REPO_ROOT}/script/prepare_dbcode.sh"
feature_policy="${REPO_ROOT}/host/dbcode-feature-policy.json"
approved_history="${REPO_ROOT}/host/approved-release-history.json"

rg -Fq -- '--argjson runtime_extensions' "${manifest_generator}" || {
  echo "The build manifest must record the complete mandatory runtime-extension set." >&2
  exit 1
}
rg -Fq 'runtime_extensions: $runtime_extensions' "${manifest_generator}" || {
  echo "The build manifest must expose the complete runtime-extension set." >&2
  exit 1
}
rg -Fq '.runtime_extensions' "${host_smoke}" || {
  echo "The host smoke test must verify every required runtime extension against the release lock." >&2
  exit 1
}
rg -Fq -- '--do-not-include-pack-dependencies' "${runtime_preparer}" || {
  echo "Runtime installation must never fetch unverified extension dependencies or extension-pack members." >&2
  exit 1
}
rg -Fq -- '--allow-candidate' "${runtime_preparer}" || {
  echo "A candidate runtime set must require an explicit preparation flag." >&2
  exit 1
}
jq -e '.approval_status == "approved"' "${feature_policy}" >/dev/null || {
  echo "DBCode 1.36.2 must be labelled approved after the complete real-profile and rollback gates pass." >&2
  exit 1
}
jq -e '
  (.excluded_optional_runtime_members | map(.id) | sort) == [
    "ms-python.debugpy",
    "ms-python.vscode-python-envs"
  ]
  and all(.excluded_optional_runtime_members[]; (.reason | type == "string" and length > 20))
' "${feature_policy}" >/dev/null || {
  echo "The two omitted Python extension-pack members need explicit focused-product reasons." >&2
  exit 1
}
rg -Fq 'excluded_optional_extension_ids' "${runtime_preparer}" || {
  echo "Release-set preparation must remove only explicitly excluded optional runtime members." >&2
  exit 1
}
rg -Fq -- '--allow-candidate' "${REPO_ROOT}/script/proof_dbcode.sh" || {
  echo "Only the explicit candidate proof may prepare the normal profile before approval." >&2
  exit 1
}
rg -Fq -- '--allow-candidate' "${REPO_ROOT}/script/test_focused_shell_rendered.sh" || {
  echo "Rendered QA must opt into the candidate runtime explicitly." >&2
  exit 1
}
if rg -Fq -- '--allow-candidate' "${REPO_ROOT}/script/run_host.sh"; then
  echo "An ordinary development launch must not silently opt into an unapproved runtime set." >&2
  exit 1
fi

if jq -e 'any(.packages[]; .id == "ms-python.debugpy" or .id == "ms-python.vscode-python-envs")' \
  <<<"${RELEASE_EXTENSION_SPEC}" >/dev/null; then
  echo "The focused notebook runtime must not install optional Python debugger or environment-manager pack members." >&2
  exit 1
fi

jq -e '
  .schema_version == 2
  and (.approved_release_sets | length) >= 1
  and any(.approved_release_sets[];
    .compatibility_status == "approved"
    and .source_commit == "cc2b112cca02f41ef9853ccde60176a18f0852e0"
    and .host.code_oss_tag == "1.126.0"
    and .dbcode.version == "1.36.1"
    and (.dbcode.vsix_sha256 | test("^[0-9a-f]{64}$"))
    and (.dbcode.signature_archive_sha256 | test("^[0-9a-f]{64}$"))
    and .rollback.kind == "source-rebuild"
  )
' "${approved_history}" >/dev/null || {
  echo "The last approved DBCode 1.36.1 release set must remain addressable for rollback." >&2
  exit 1
}

echo "Locked runtime-extension release-set contract checks passed."
