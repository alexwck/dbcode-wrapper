#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

kernel_bridge_dir="${REPO_ROOT}/host/extensions/dbcode-wrapper-python-kernel"
kernel_bridge_manifest="${kernel_bridge_dir}/package.json"
kernel_bridge_runtime="${kernel_bridge_dir}/extension.js"
focused_shell_patch="${REPO_ROOT}/host/patches/code-oss/200-final-focused-dbcode-shell.patch"

jq -e '
  .required == true
  and .user_installation_required == false
  and .kernel_runtime == "user-selected"
' <<<"${PYTHON_NOTEBOOK_SPEC}" >/dev/null || {
  echo "Python notebook support must be a core wrapper feature with a user-selected kernel." >&2
  exit 1
}

if [[ -e "${REPO_ROOT}/script/prepare_python_notebook_qa.sh" ]]; then
  echo "The prompt-free release path must not maintain a separate QA kernel installer." >&2
  exit 1
fi
jq -e '
  .publisher == "dbcode-wrapper"
  and .name == "python-kernel-bridge"
  and .main == "./extension.js"
  and any(.contributes.commands[]; .command == "dbcodeWrapper.startPythonKernel")
  and any(.contributes.menus.commandPalette[]; .command == "dbcodeWrapper.startPythonKernel" and .when == "false")
' "${kernel_bridge_manifest}" >/dev/null || {
  echo "The app must bundle a focused Python-kernel bridge without adding it to the Command Palette." >&2
  exit 1
}

for required_api in \
  "extensions.getExtension('ms-toolsai.jupyter')" \
  'window.activeNotebookEditor' \
  'workspace.openNotebookDocument(bootstrapUri)' \
  'window.showNotebookDocument' \
  "commands.executeCommand('notebook.selectKernel'" \
  "commands.executeCommand('notebook.execute'" \
  'jupyter.exports.kernels.getKernel'; do
  rg -Fq "${required_api}" "${kernel_bridge_runtime}" || {
    echo "The Python-kernel bridge must use the stable notebook and Jupyter APIs: ${required_api}" >&2
    exit 1
  }
done

rg -Fq 'previousNotebookEditor.notebook' "${kernel_bridge_runtime}" || {
  echo "The kernel bridge must return to the exact DBCode notebook that started it." >&2
  exit 1
}

if rg -n 'child_process|execFile|spawn\(' "${kernel_bridge_runtime}"; then
  echo "The bridge must let Jupyter start the user-selected kernel instead of launching Python itself." >&2
  exit 1
fi

rg -Fq 'copy_first_party_extensions' "${REPO_ROOT}/script/assemble_host.sh" || {
  echo "The production build must bundle the reviewed first-party kernel bridge before signing." >&2
  exit 1
}
rg -Fq 'Start Python Kernel…' "${focused_shell_patch}" || {
  echo "DBCode Tools must provide the focused Python-kernel setup route." >&2
  exit 1
}
rg -Fq "dbcode-wrapper-python-kernel.ipynb" "${focused_shell_patch}" || {
  echo "The private bootstrap notebook must stay out of the visible DBCode tab strip." >&2
  exit 1
}
for rendered_notebook_contract in \
  'the DBCode notebook route remains reachable without starting a kernel' \
  'kernelStarted: false' \
  'permissionPromptExpected: false'; do
  rg -Fq "${rendered_notebook_contract}" "${REPO_ROOT}/host/qa/ticket-03-rendered.cjs" || {
    echo "The rendered smoke is missing its prompt-free notebook route check: ${rendered_notebook_contract}" >&2
    exit 1
  }
done

if rg -Fq 'prepare_python_notebook_qa.sh' "${REPO_ROOT}/script/test_focused_shell_rendered.sh"; then
  echo "The fast rendered smoke must not prepare or start a Python kernel." >&2
  exit 1
fi

for forbidden_interactive_notebook_contract in \
  'runDbcodeKernelCellWithHumanGate' \
  'focusDbcodeWindowForHumanKernelGate' \
  'HUMAN ACTION REQUIRED' \
  'DBCODE_WRAPPER_QA_MANUAL_KERNEL_GATE' \
  'kernel-permission-preflight' \
  'verifyNotebookRoute' \
  '.notebookOverlay.notebook-editor:visible' \
  'dbcode_wrapper_notebook_proof = 6 * 7' \
  'DBCODE_NOTEBOOK_PYTHON_OUTPUT_42' \
  'findNotebookPythonOutput' \
  'chooseQaPythonKernel'; do
  if rg -Fq "${forbidden_interactive_notebook_contract}" \
    "${REPO_ROOT}/host/qa/ticket-03-rendered.cjs" \
    "${REPO_ROOT}/script/test_focused_shell_rendered.sh"; then
    echo "The fast rendered smoke still contains an interactive Kernel workflow: ${forbidden_interactive_notebook_contract}" >&2
    exit 1
  fi
done

echo "Core Python-notebook contract checks passed."
