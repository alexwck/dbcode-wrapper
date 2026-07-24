#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/generated_workspace.sh"

ipykernel_version="7.3.0"
qa_root="$(generated_workspace_path "rendered-evidence")"
qa_python_root="${qa_root}/python-kernel-ipykernel-${ipykernel_version}"
qa_jupyter_prefix="${qa_root}/jupyter"
qa_jupyter_path="${qa_jupyter_prefix}/share/jupyter"

generated_workspace_assert_path "rendered-evidence" "${qa_python_root}"
generated_workspace_assert_path "rendered-evidence" "${qa_jupyter_prefix}"
for private_directory in "${qa_root}" "${qa_python_root}" "${qa_jupyter_prefix}"; do
  if [[ -L "${private_directory}" ]]; then
    echo "Refusing a symlinked QA Python path: ${private_directory}" >&2
    exit 1
  fi
done

mkdir -p "${qa_root}"
chmod 700 "${qa_root}"

if [[ ! -x "${qa_python_root}/bin/python" ]]; then
  python3 -m venv "${qa_python_root}"
fi

installed_ipykernel="$({
  PYTHONNOUSERSITE=1 "${qa_python_root}/bin/python" -c \
    'import importlib.metadata; print(importlib.metadata.version("ipykernel"))'
} 2>/dev/null || true)"
if [[ "${installed_ipykernel}" != "${ipykernel_version}" ]]; then
  PYTHONNOUSERSITE=1 "${qa_python_root}/bin/python" -m pip install \
    --disable-pip-version-check \
    "ipykernel==7.3.0"
fi

PYTHONNOUSERSITE=1 "${qa_python_root}/bin/python" -c '
import importlib.metadata
import sys

assert importlib.metadata.version("ipykernel") == "7.3.0"
assert sys.prefix != sys.base_prefix
'

mkdir -p "${qa_jupyter_prefix}"
chmod 700 "${qa_python_root}" "${qa_jupyter_prefix}"
PYTHONNOUSERSITE=1 "${qa_python_root}/bin/python" -m ipykernel install \
  --prefix "${qa_jupyter_prefix}" \
  --name dbcode-wrapper-qa \
  --display-name "DBCode Wrapper QA (Python)" >/dev/null

kernel_manifest="${qa_jupyter_path}/kernels/dbcode-wrapper-qa/kernel.json"
jq -e \
  --arg python "${qa_python_root}/bin/python" \
  '.argv[0] == $python and .display_name == "DBCode Wrapper QA (Python)" and .language == "python"' \
  "${kernel_manifest}" >/dev/null

echo "Prepared isolated DBCode Python notebook kernel at ${qa_jupyter_path}"
