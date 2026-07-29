#!/usr/bin/env bash

set -euo pipefail

generated_workspace_require_runtime() {
  if [[ ! -x "${NODE_BIN_DIR}/node" ]]; then
    echo "The pinned Node.js toolchain is required. Run ./script/bootstrap_toolchain.sh first." >&2
    return 1
  fi
}

generated_workspace_path() {
  generated_workspace_require_runtime || return 1
  "${NODE_BIN_DIR}/node" "${REPO_ROOT}/script/generated_workspace.cjs" \
    path \
    --id "$1" \
    --repo-root "${GENERATED_REPO_ROOT:-${REPO_ROOT}}"
}

generated_workspace_resolve_path() {
  local root_id="$1"
  local path_value="$2"
  local fixture_mode="${3:-managed-only}"
  local arguments=(assert-path --id "${root_id}" --path "${path_value}")
  local managed_result
  generated_workspace_require_runtime || return 1
  if managed_result="$(
    "${NODE_BIN_DIR}/node" "${REPO_ROOT}/script/generated_workspace.cjs" \
      "${arguments[@]}" \
      --repo-root "${GENERATED_REPO_ROOT:-${REPO_ROOT}}" 2>&1
  )"; then
    jq -er '.path' <<<"${managed_result}"
    return
  fi
  case "${fixture_mode}" in
    managed-only)
      echo "${managed_result}" >&2
      return 1
      ;;
    allow-temporary)
      if [[ "${DBCODE_WRAPPER_TEST_ALLOW_TEMPORARY_OUTPUT:-no}" != "yes" ]]; then
        echo "${managed_result}" >&2
        echo "Temporary generated output is restricted to an explicit test fixture." >&2
        return 1
      fi
      arguments+=(--allow-temporary)
      ;;
    *)
      echo "Unknown generated workspace fixture mode: ${fixture_mode}" >&2
      return 2
      ;;
  esac
  "${NODE_BIN_DIR}/node" "${REPO_ROOT}/script/generated_workspace.cjs" \
    "${arguments[@]}" \
    --repo-root "${GENERATED_REPO_ROOT:-${REPO_ROOT}}" |
    jq -er '.path'
}

generated_workspace_assert_path() {
  generated_workspace_resolve_path "$@" >/dev/null
}
