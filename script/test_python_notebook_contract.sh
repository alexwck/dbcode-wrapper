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

qa_kernel_preparer="${REPO_ROOT}/script/prepare_python_notebook_qa.sh"
[[ -x "${qa_kernel_preparer}" ]] || {
  echo "The rendered proof needs a project-local Python-kernel preparer." >&2
  exit 1
}

rg -Fq 'ipykernel==7.3.0' "${qa_kernel_preparer}" || {
  echo "The QA Python kernel must pin its top-level ipykernel dependency." >&2
  exit 1
}
rg -Fq 'DBCODE_WRAPPER_QA_JUPYTER_PATH' "${REPO_ROOT}/script/test_focused_shell_rendered.sh" || {
  echo "The rendered proof must pass its isolated Jupyter data path to DBCode Wrapper." >&2
  exit 1
}

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

rg -Fq 'copy_first_party_extensions' "${REPO_ROOT}/script/build_host.sh" || {
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
rg -Fq 'dbcode_wrapper_notebook_proof = 6 * 7' "${REPO_ROOT}/host/qa/ticket-03-rendered.cjs" || {
  echo "The rendered proof must execute a deterministic Python expression in a DBCode notebook." >&2
  exit 1
}
rg -Fq 'DBCODE_NOTEBOOK_PYTHON_OUTPUT_42' "${REPO_ROOT}/host/qa/ticket-03-rendered.cjs" || {
  echo "The rendered proof must assert the real Python kernel output." >&2
  exit 1
}
rg -Fq 'findNotebookPythonOutput' "${REPO_ROOT}/host/qa/ticket-03-rendered.cjs" || {
  echo "The rendered proof must read the deterministic result from DBCode's rendered notebook output frame." >&2
  exit 1
}
rg -Fq 'DBCode Wrapper QA \(Python\)' "${REPO_ROOT}/host/qa/ticket-03-rendered.cjs" || {
  echo "The rendered proof must select the isolated Python kernel through DBCode's visible kernel flow." >&2
  exit 1
}

rg -Fq 'scanExtensionHostLogs' "${REPO_ROOT}/host/qa/ticket-03-rendered.cjs" || {
  echo "The rendered notebook proof must reject required extension-host activation errors." >&2
  exit 1
}
rg -Fq 'python-kernel-ipykernel-7\.3\.0' "${REPO_ROOT}/host/qa/ticket-03-rendered.cjs" || {
  echo "The rendered proof must also accept Jupyter's direct QA virtual-environment label." >&2
  exit 1
}
rg -Fq 'approveSampleConnectionIfOffered' "${REPO_ROOT}/host/qa/ticket-03-rendered.cjs" || {
  echo "The rendered proof must approve its own sample DBCode connection without manual input." >&2
  exit 1
}
rg -Fq 'approveDbcodeKernelAccessIfOffered' "${REPO_ROOT}/host/qa/ticket-03-rendered.cjs" || {
  echo "The rendered proof must approve DBCode's first-use Jupyter access without manual input." >&2
  exit 1
}

echo "Core Python-notebook contract checks passed."
