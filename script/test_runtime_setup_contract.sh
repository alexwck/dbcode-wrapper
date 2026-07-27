#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

extension_root="${REPO_ROOT}/host/extensions/dbcode-wrapper-profile-migration"
extension_manifest="${extension_root}/package.json"
extension_runtime="${extension_root}/extension.js"
setup_logic="${extension_root}/runtimeSetup.js"
setup_controller="${extension_root}/runtimeSetupController.js"
setup_view="${extension_root}/runtimeSetupView.js"
generator="${REPO_ROOT}/script/generate_runtime_setup_manifest.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-runtime-setup-contract.XXXXXX")"

cleanup() {
  rm -rf "${test_root}"
}
trap cleanup EXIT INT TERM

for required_file in \
  "${extension_manifest}" \
  "${extension_runtime}" \
  "${setup_logic}" \
  "${setup_controller}" \
  "${setup_view}" \
  "${generator}"; do
  [[ -f "${required_file}" ]] || {
    echo "Missing focused first-run runtime setup file: ${required_file}" >&2
    exit 1
  }
done
[[ -x "${generator}" ]] || {
  echo "The focused runtime setup manifest generator is not executable." >&2
  exit 1
}

generated_manifest="${test_root}/runtime-extension-set.json"
"${generator}" "${generated_manifest}" >/dev/null
"${NODE_BIN_DIR}/node" -e '
  const fs = require("node:fs");
  const [logic, record] = process.argv.slice(1);
  require(logic).validateRuntimeConfiguration(JSON.parse(fs.readFileSync(record, "utf8")));
' "${setup_logic}" "${generated_manifest}"

expected_packages="$(
  jq -c '
    .packages
    | map({
      role,
      namespace,
      name,
      id,
      publisher,
      version,
      engine,
      target_platform,
      published_at,
      verified_publisher,
      pre_release,
      deprecated,
      registry_api_url,
      download_url,
      signature_url,
      sha256_url,
      public_key_id,
      public_key_url,
      sha256,
      signature_archive_sha256,
      public_key_sha256,
      package_size
    })
  ' <<<"${RELEASE_EXTENSION_SPEC}"
)"
[[ "$(jq -c '.packages' "${generated_manifest}")" == "${expected_packages}" ]] || {
  echo "The focused first-run setup does not contain the exact Release Specification package set." >&2
  exit 1
}
jq -e \
  --arg code_oss_version "${CODE_OSS_VERSION}" \
  --arg application_name "${APPLICATION_NAME}" '
    .schema_version == 1
    and .setup == "focused-pinned-official-sources"
    and .code_oss_version == $code_oss_version
    and .application_name == $application_name
    and (.packages | length) == 7
    and ([.packages[].id] | sort) == [
      "dbcode.dbcode",
      "ms-python.python",
      "ms-toolsai.jupyter",
      "ms-toolsai.jupyter-keymap",
      "ms-toolsai.jupyter-renderers",
      "ms-toolsai.vscode-jupyter-cell-tags",
      "ms-toolsai.vscode-jupyter-slideshow"
    ]
    and (.public_keys | length) == 1
  ' "${generated_manifest}" >/dev/null || {
  echo "The focused first-run setup identity is incomplete." >&2
  exit 1
}

jq -e '
  (.activationEvents | sort) == [
    "onCommand:dbcodeWrapper.startProfileMigration",
    "onCommand:dbcodeWrapper.startRuntimeSetup",
    "onStartupFinished"
  ]
  and ([.contributes.commands[].command] | sort) == [
    "dbcodeWrapper.startProfileMigration",
    "dbcodeWrapper.startRuntimeSetup"
  ]
  and all(.contributes.menus.commandPalette[]; .when == "false")
' "${extension_manifest}" >/dev/null || {
  echo "The focused runtime setup must remain startup-only and hidden from the generic command surface." >&2
  exit 1
}

for required_contract in \
  'loadRuntimeConfiguration(context.extensionPath)' \
  'runtimeSetup.requiresSetup()' \
  'runtimeSetup.open()' \
  'acquireAndVerifyPackage' \
  'verifyPackageAcquisition' \
  'crypto.verify(null' \
  'workbench.action.reloadWindow' \
  '--do-not-include-pack-dependencies' \
  '--list-extensions' \
  'focused-pinned-official-sources'; do
  rg -Fq -- "${required_contract}" \
    "${extension_runtime}" \
    "${setup_logic}" \
    "${setup_controller}" \
    "${setup_view}" || {
    echo "The focused first-run contract is missing: ${required_contract}" >&2
    exit 1
  }
done

if rg -n \
  'workbench\.extensions\.installExtension|workbench\.view\.extensions|browse extensions|search extensions' \
  "${extension_runtime}" \
  "${setup_logic}" \
  "${setup_controller}" \
  "${setup_view}"; then
  echo "The focused first-run setup must not expose or call a general extension surface." >&2
  exit 1
fi

rg -Fq 'generate_runtime_setup_manifest.sh' "${REPO_ROOT}/script/assemble_host.sh" || {
  echo "The production build does not generate the pinned runtime setup manifest." >&2
  exit 1
}
rg -Fq 'node_modules/yauzl/package.json' "${REPO_ROOT}/script/smoke_host.sh" || {
  echo "The signed-host smoke gate does not protect the runtime setup ZIP dependency." >&2
  exit 1
}
for manifest_contract in \
  'external_runtime_setup: "focused-pinned-official-sources"' \
  'external_runtime_setup_manifest_sha256'; do
  rg -Fq "${manifest_contract}" \
    "${REPO_ROOT}/script/generate_manifest.sh" \
    "${REPO_ROOT}/script/smoke_host.sh" || {
    echo "The signed-host manifest is missing focused setup evidence: ${manifest_contract}" >&2
    exit 1
  }
done

"${NODE_BIN_DIR}/node" --check "${setup_logic}"
"${NODE_BIN_DIR}/node" --check "${setup_controller}"
"${NODE_BIN_DIR}/node" --check "${setup_view}"
"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_runtime_setup.mjs"

echo "Focused first-run runtime setup contracts passed."
