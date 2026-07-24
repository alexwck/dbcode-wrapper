#!/usr/bin/env bash

set -euo pipefail

catalogue_only="no"
if [[ $# -eq 1 && "$1" == "--connection-catalogue-only" ]]; then
  catalogue_only="yes"
elif [[ $# -ne 0 ]]; then
  echo "Usage: ./script/test_focused_shell_rendered.sh [--connection-catalogue-only]" >&2
  exit 2
fi

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/profile_paths.sh"

qa_script="${REPO_ROOT}/host/qa/ticket-03-rendered.cjs"
playwright_module="${WORK_ROOT}/vscode/node_modules/playwright"
bundled_playwright_module="${APP_BUNDLE}/Contents/Resources/app/node_modules/playwright-core"

[[ -x "${NODE_BIN_DIR}/node" ]] || {
  echo "Build the pinned host before running the rendered focused-shell checks." >&2
  exit 1
}
[[ -d "${APP_BUNDLE}" ]] || {
  echo "The DBCode Wrapper app bundle is required." >&2
  exit 1
}
[[ -f "${playwright_module}/package.json" || -f "${bundled_playwright_module}/package.json" ]] || {
  echo "Neither the pinned source build nor the signed app contains its Playwright automation dependency." >&2
  exit 1
}

"${REPO_ROOT}/script/prepare_dbcode.sh" --profile qa --allow-candidate
"${REPO_ROOT}/script/prepare_python_notebook_qa.sh"
resolve_profile_paths qa
DBCODE_WRAPPER_PROFILE_LAYOUT_JSON="${PROFILE_LAYOUT}" \
DBCODE_WRAPPER_QA_EXTENSIONS_DIR="${PROFILE_EXTENSIONS_ROOT}" \
DBCODE_WRAPPER_QA_JUPYTER_PATH="${BUILD_ROOT}/qa/jupyter/share/jupyter" \
DBCODE_WRAPPER_CONNECTION_CATALOGUE_ONLY="${catalogue_only}" \
  "${NODE_BIN_DIR}/node" "${qa_script}"
