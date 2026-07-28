#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

module="${REPO_ROOT}/script/lib/generated-workspace-retention.js"
cli="${REPO_ROOT}/script/generated_workspace.cjs"
shell_adapter="${REPO_ROOT}/script/lib/generated_workspace.sh"
task_command="${REPO_ROOT}/script/generated_workspace.sh"

for required_file in \
  "${module}" \
  "${cli}" \
  "${shell_adapter}" \
  "${task_command}" \
  "${REPO_ROOT}/script/test_generated_workspace_retention.mjs"; do
  [[ -f "${required_file}" ]] || {
    echo "Missing generated workspace retention file: ${required_file}" >&2
    exit 1
  }
done

for caller in \
  "${REPO_ROOT}/script/prepare_source.sh" \
  "${REPO_ROOT}/script/prepare_dbcode.sh" \
  "${REPO_ROOT}/script/assemble_host.sh" \
  "${REPO_ROOT}/script/compile_host.sh" \
  "${REPO_ROOT}/script/build_icon.sh" \
  "${REPO_ROOT}/script/smoke_host.sh" \
  "${REPO_ROOT}/script/test_focused_shell_rendered.sh" \
  "${REPO_ROOT}/script/prepare_release_rollback.sh" \
  "${REPO_ROOT}/script/verify_release_rollback.sh" \
  "${REPO_ROOT}/script/preview_release_rollback.sh" \
  "${REPO_ROOT}/script/package_host_release.sh" \
  "${REPO_ROOT}/script/verify_host_release.sh" \
  "${REPO_ROOT}/script/publish_release.sh"; do
  rg -Fq 'lib/generated_workspace.sh' "${caller}" || {
    echo "A generated-output workflow does not load the retention contract: ${caller}" >&2
    exit 1
  }
done

source "${shell_adapter}"
if rg -n '\$\{(REPO_ROOT|repo_root)\}/\.build' "${REPO_ROOT}/script" --glob 'test_*'; then
  echo "A test targets generated output under its source checkout instead of BUILD_ROOT." >&2
  exit 1
fi
temporary_fixture="/private/tmp/dbcode-wrapper-retention-contract-fixture"
generated_workspace_resolve_path \
  "acceptance-evidence" \
  "${BUILD_ROOT}/acceptance/managed-fixture" \
  allow-temporary >/dev/null
if generated_workspace_resolve_path \
  "acceptance-evidence" \
  "${temporary_fixture}" \
  allow-temporary >/dev/null 2>&1; then
  echo "Temporary workflow output was accepted without the explicit test gate." >&2
  exit 1
fi
DBCODE_WRAPPER_TEST_ALLOW_TEMPORARY_OUTPUT=yes \
  generated_workspace_resolve_path \
    "acceptance-evidence" \
    "${temporary_fixture}" \
    allow-temporary >/dev/null

rg -Fq 'generated_workspace_assert_path "build-cache" "${CACHE_ROOT}"' \
  "${REPO_ROOT}/script/prepare_source.sh"
rg -Fq 'generated_workspace_assert_path "build-work" "${WORK_ROOT}"' \
  "${REPO_ROOT}/script/prepare_source.sh"
rg -Fq 'runtime_cache_root="$(' \
  "${REPO_ROOT}/script/prepare_dbcode.sh"
rg -Fq '"build-cache"' \
  "${REPO_ROOT}/script/prepare_dbcode.sh"
rg -Fq 'assert_generated_path "${APP_BUNDLE}"' \
  "${REPO_ROOT}/script/assemble_host.sh"
rg -Fq 'generated_workspace_assert_path "toolchain-cache" "${TOOLCHAIN_ROOT}"' \
  "${REPO_ROOT}/script/compile_host.sh"
rg -Fq 'generated_workspace_assert_path "download-cache" "${BUILD_ROOT}/downloads"' \
  "${REPO_ROOT}/script/compile_host.sh"
rg -Fq 'generated_parent="$(generated_workspace_path "generated-source")"' \
  "${REPO_ROOT}/script/build_icon.sh"
rg -Fq 'smoke_root="$(generated_workspace_path "smoke-evidence")"' \
  "${REPO_ROOT}/script/smoke_host.sh"
rg -Fq 'expected_runtime_setup_manifest="${smoke_root}/' \
  "${REPO_ROOT}/script/smoke_host.sh"
if rg -Fq 'expected_runtime_setup_manifest="${BUILD_ROOT}/' \
  "${REPO_ROOT}/script/smoke_host.sh"; then
  echo "Smoke evidence bypasses the registered smoke root." >&2
  exit 1
fi
rg -Fq 'qa_root="$(generated_workspace_path "rendered-evidence")"' \
  "${REPO_ROOT}/script/test_focused_shell_rendered.sh"
rg -Fq 'output_root="$(generated_workspace_path "rendered-screenshots")"' \
  "${REPO_ROOT}/script/test_focused_shell_rendered.sh"
rg -Fq "process.env.DBCODE_WRAPPER_QA_ROOT" \
  "${REPO_ROOT}/host/qa/ticket-03-rendered.cjs"
rg -Fq "process.env.DBCODE_WRAPPER_RENDERED_OUTPUT_ROOT" \
  "${REPO_ROOT}/host/qa/ticket-03-rendered.cjs"
rg -Fq 'snapshot_parent="$(generated_workspace_path "rollback-evidence")"' \
  "${REPO_ROOT}/script/prepare_release_rollback.sh"
rg -Fq 'worktree_parent="$(generated_workspace_path "rollback-worktrees")"' \
  "${REPO_ROOT}/script/prepare_release_rollback.sh"
rg -Fq 'snapshot_parent="$(generated_workspace_path "rollback-evidence")"' \
  "${REPO_ROOT}/script/verify_release_rollback.sh"
rg -Fq 'snapshot_parent="$(generated_workspace_path "rollback-evidence")"' \
  "${REPO_ROOT}/script/preview_release_rollback.sh"
rg -Fq 'output_dir="$(' \
  "${REPO_ROOT}/script/package_host_release.sh"
rg -Fq '"host-release-assets"' \
  "${REPO_ROOT}/script/package_host_release.sh"
rg -Fq 'temporary_root="$(mktemp -d "${output_dir}/.staging.XXXXXX")"' \
  "${REPO_ROOT}/script/package_host_release.sh"
if rg -Fq 'mktemp -d "${TMPDIR:-/private/tmp}/dbcode-host-release.' \
  "${REPO_ROOT}/script/package_host_release.sh"; then
  echo "Host-release staging bypasses its registered output root." >&2
  exit 1
fi
rg -Fq 'output_file="$(' \
  "${REPO_ROOT}/script/verify_host_release.sh"
rg -Fq '"host-release-assets"' \
  "${REPO_ROOT}/script/verify_host_release.sh"
rg -Fq '"host-release-assets"' \
  "${REPO_ROOT}/script/publish_release.sh"

bootstrap="${REPO_ROOT}/script/bootstrap_toolchain.sh"
rg -Fq 'assert_bootstrap_generated_path "${BUILD_ROOT}"' "${bootstrap}"
rg -Fq 'assert_bootstrap_generated_path "${TOOLCHAIN_ROOT}"' "${bootstrap}"
rg -Fq 'assert_bootstrap_generated_path "${BUILD_ROOT}/downloads"' "${bootstrap}"
rg -Fq 'assert_bootstrap_generated_path "${NODE_ROOT}"' "${bootstrap}"
rg -Fq 'assert_bootstrap_generated_path "${node_archive}"' "${bootstrap}"
python3 - "${bootstrap}" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
guard = source.index('assert_bootstrap_generated_path "${BUILD_ROOT}"')
mutation = source.index('mkdir -p "${TOOLCHAIN_ROOT}" "${BUILD_ROOT}/downloads"')
if guard >= mutation:
    raise SystemExit("Bootstrap generated-path guards must run before the first mutation.")
PY

"${NODE_BIN_DIR}/node" --check "${module}"
"${NODE_BIN_DIR}/node" --check "${cli}"
"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_generated_workspace_retention.mjs"

echo "Generated workspace retention contracts passed."
