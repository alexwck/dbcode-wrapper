#!/usr/bin/env bash

set -euo pipefail

rendered_mode="smoke"
if [[ $# -gt 1 ]]; then
  echo "Usage: ./script/test_focused_shell_rendered.sh [--connection-catalogue-only]" >&2
  exit 2
fi
if [[ $# -eq 1 ]]; then
  case "$1" in
    --connection-catalogue-only)
      rendered_mode="connection-catalogue"
      ;;
    *)
      echo "Usage: ./script/test_focused_shell_rendered.sh [--connection-catalogue-only]" >&2
      exit 2
      ;;
  esac
fi

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/artifact_digest.sh"
source "${REPO_ROOT}/script/lib/generated_workspace.sh"
source "${REPO_ROOT}/script/lib/profile_paths.sh"

qa_script="${REPO_ROOT}/host/qa/focused-shell-rendered.cjs"
[[ -x "${NODE_BIN_DIR}/node" ]] || {
  echo "Build the pinned host before running the rendered focused-shell checks." >&2
  exit 1
}
qa_root="$(generated_workspace_path "rendered-evidence")"
output_root="$(generated_workspace_path "rendered-screenshots")"
playwright_module="${WORK_ROOT}/vscode/node_modules/playwright"
bundled_playwright_module="${APP_BUNDLE}/Contents/Resources/app/node_modules/playwright-core"

[[ -d "${APP_BUNDLE}" ]] || {
  echo "The DBCode Wrapper app bundle is required." >&2
  exit 1
}
[[ -f "${BUILD_MANIFEST}" ]] || {
  echo "The DBCode Wrapper build manifest is required." >&2
  exit 1
}
[[ -f "${playwright_module}/package.json" || -f "${bundled_playwright_module}/package.json" ]] || {
  echo "Neither the pinned source build nor the signed app contains its Playwright automation dependency." >&2
  exit 1
}
generated_workspace_assert_path "rendered-evidence" "${qa_root}"
generated_workspace_assert_path "rendered-screenshots" "${output_root}"

resolve_profile_paths qa
app_sha256="$(artifact_digest "${APP_BUNDLE}")"
manifest_app_sha256="$(jq -er '.artifact.sha256' "${BUILD_MANIFEST}")"
[[ "${app_sha256}" == "${manifest_app_sha256}" ]] || {
  echo "The rendered app digest does not match its build manifest." >&2
  exit 1
}
release_set_id="$(jq -er '.release.release_set_id' "${BUILD_MANIFEST}")"

"${REPO_ROOT}/script/prepare_dbcode.sh" --profile qa --allow-candidate
DBCODE_WRAPPER_PROFILE_LAYOUT_JSON="${PROFILE_LAYOUT}" \
DBCODE_WRAPPER_QA_EXTENSIONS_DIR="${PROFILE_EXTENSIONS_ROOT}" \
DBCODE_WRAPPER_QA_ROOT="${qa_root}" \
DBCODE_WRAPPER_RENDERED_OUTPUT_ROOT="${output_root}" \
DBCODE_WRAPPER_RENDERED_MODE="${rendered_mode}" \
DBCODE_WRAPPER_RELEASE_SET_ID="${release_set_id}" \
  "${NODE_BIN_DIR}/node" "${qa_script}"
