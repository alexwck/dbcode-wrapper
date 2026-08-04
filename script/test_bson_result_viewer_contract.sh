#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

if [[ $# -ne 0 ]]; then
  echo "Usage: ./script/test_bson_result_viewer_contract.sh" >&2
  exit 2
fi

extension_root="${REPO_ROOT}/host/extensions/dbcode-wrapper-bson-viewer"
extension_manifest="${extension_root}/package.json"
extension_runtime="${extension_root}/extension.js"
display_model="${extension_root}/ejson-display.js"
viewer_controller="${extension_root}/bson-result-viewer.js"
viewer_webview="${extension_root}/viewer-webview.js"
focused_shell="${REPO_ROOT}/host/code-oss-overlay/src/vs/workbench/contrib/dbcodeWrapper/browser/dbcodeWrapper.contribution.ts"
slimming_policy="${REPO_ROOT}/host/slimming-policy.json"
host_assembler="${REPO_ROOT}/script/assemble_host.sh"
development_gate="${REPO_ROOT}/script/check_development.sh"
node_test="${REPO_ROOT}/script/test_bson_result_viewer.mjs"
rendered_qa="${REPO_ROOT}/host/qa/focused-shell-rendered.cjs"
rendered_fixture="${REPO_ROOT}/host/qa/bson-result-viewer-sample.ejson"

for required_file in \
  "${extension_manifest}" \
  "${extension_runtime}" \
  "${display_model}" \
  "${viewer_controller}" \
  "${viewer_webview}" \
  "${focused_shell}" \
  "${slimming_policy}" \
  "${rendered_qa}" \
  "${rendered_fixture}" \
  "${node_test}"; do
  [[ -f "${required_file}" ]] || {
    echo "Missing BSON Result Viewer file: ${required_file}" >&2
    exit 1
  }
done

jq -e '
  length == 1
  and .[0].requestedamount == {"$numberInt": "0"}
  and .[0].numericString == "0"
  and .[0].escapedJson == "{\"nested\":{\"$numberInt\":\"2\"}}"
' "${rendered_fixture}" >/dev/null || {
  echo "The rendered BSON Result Viewer fixture must stay small, synthetic, and type-distinguishing." >&2
  exit 1
}

jq -e '
  .publisher == "dbcode-wrapper"
  and .name == "bson-result-viewer"
  and .main == "./extension.js"
  and (.activationEvents | sort) == [
    "onCommand:dbcodeWrapper.openBsonResultFromClipboard",
    "onCommand:dbcodeWrapper.openBsonResultFromFile"
  ]
  and ([.contributes.commands[].command] | sort) == [
    "dbcodeWrapper.openBsonResultFromClipboard",
    "dbcodeWrapper.openBsonResultFromFile"
  ]
  and all(.contributes.menus.commandPalette[]; .when == "false")
  and .contributes.keybindings == [{
    command: "dbcodeWrapper.openBsonResultFromClipboard",
    key: "ctrl+alt+j",
    mac: "cmd+alt+j",
    when: "!inputFocus"
  }]
' "${extension_manifest}" >/dev/null || {
  echo "BSON Result Viewer commands must stay inside the focused shell with one explicit clipboard shortcut." >&2
  exit 1
}

jq -e '
  [.build.built_in_extensions.first_party[] |
    select(.name == "dbcode-wrapper-bson-viewer" and .source == "host/extensions/dbcode-wrapper-bson-viewer")
  ] | length == 1
' "${slimming_policy}" >/dev/null || {
  echo "The reviewed first-party extension set does not package the BSON Result Viewer." >&2
  exit 1
}

for shell_contract in \
  "dbcodeWrapper.openBsonResultFromClipboard" \
  "dbcodeWrapper.openBsonResultFromFile" \
  "Open Copied BSON Result" \
  "Open BSON Result File…"; do
  rg -Fq "${shell_contract}" "${focused_shell}" || {
    echo "DBCode Tools is missing the BSON Result Viewer route: ${shell_contract}" >&2
    exit 1
  }
done

for rendered_contract in \
  "verifyBsonResultViewerRoute" \
  "bson-result-viewer-sample.ejson" \
  "BSON Result Viewer renders readable values with separate types without a database" \
  "databaseRead: false" \
  "networkUsed: false"; do
  rg -Fq "${rendered_contract}" "${rendered_qa}" || {
    echo "Rendered QA is missing BSON Result Viewer coverage: ${rendered_contract}" >&2
    exit 1
  }
done

for adapter_contract in \
  "vscode.env.clipboard.readText()" \
  "vscode.window.showOpenDialog" \
  "vscode.workspace.fs.stat" \
  "vscode.workspace.fs.readFile" \
  "vscode.env.clipboard.writeText" \
  "localResourceRoots: []" \
  "retainContextWhenHidden: false" \
  "message?.type === 'parseEmbedded'" \
  "type: 'copySucceeded'"; do
  rg -Fq "${adapter_contract}" "${extension_runtime}" || {
    echo "The BSON Result Viewer adapter is missing: ${adapter_contract}" >&2
    exit 1
  }
done

for safety_contract in \
  "DEFAULT_MAX_INPUT_BYTES = 10 * 1024 * 1024" \
  "TextDecoder('utf-8', { fatal: true })" \
  "default-src 'none'" \
  "latestPayload = undefined" \
  "Could not copy the displayed BSON value." \
  "vscode.setState({ mode: activeMode, parseEmbedded: parseEmbedded.checked })" \
  "textContent"; do
  rg -Fq "${safety_contract}" "${extension_runtime}" "${viewer_controller}" "${viewer_webview}" || {
    echo "The local BSON Result Viewer is missing its input or webview safety contract: ${safety_contract}" >&2
    exit 1
  }
done

if rg -n 'setState\([^\n]*query|saved\.query' "${viewer_webview}"; then
  echo "The BSON Result Viewer must not persist search text or result-derived state." >&2
  exit 1
fi

if rg -n 'https?://|node:(http|https|net)|child_process|setInterval|globalState|workspaceState|globalStorage|context\.secrets|SecretStorage' \
  "${extension_runtime}" \
  "${display_model}" \
  "${viewer_controller}" \
  "${viewer_webview}"; then
  echo "The BSON Result Viewer must not use the network, polling, persistent state, processes, or secrets." >&2
  exit 1
fi

rg -Fq 'copy_first_party_extensions' "${host_assembler}" || {
  echo "Host assembly no longer owns the reviewed first-party extension projection." >&2
  exit 1
}
rg -Fq 'test_bson_result_viewer_contract.sh' "${development_gate}" || {
  echo "The development gate does not run the focused BSON Result Viewer contract." >&2
  exit 1
}

"${NODE_BIN_DIR}/node" --test "${node_test}"

echo "BSON Result Viewer contracts passed."
