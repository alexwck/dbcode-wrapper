#!/usr/bin/env bash

set -euo pipefail

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
development_gate="${script_root}/check_development.sh"
trace_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-development-gate-contract.XXXXXX")"
fixture_root="${trace_root}/repo"
fixture_script_root="${fixture_root}/script"
fixture_bin="${trace_root}/bin"
trace_file="${trace_root}/executions.log"
trap 'rm -rf "${trace_root}"' EXIT

require_line_once() {
  local file="${1}"
  local line="${2}"
  local description="${3}"
  local actual_count

  actual_count="$(rg -Fxc -- "${line}" "${file}" || true)"
  if [[ "${actual_count}" != "1" ]]; then
    echo "${description}: expected 1, found ${actual_count}." >&2
    exit 1
  fi
}

mkdir -p "${fixture_script_root}" "${fixture_bin}"
cp "${development_gate}" "${fixture_script_root}/check_development.sh"

while IFS= read -r script_name; do
  cat > "${fixture_script_root}/${script_name}" <<'STUB'
#!/usr/bin/env bash

set -euo pipefail

printf 'script:%s\n' "$(basename "${0}")" >> "${DBCODE_DEVELOPMENT_TRACE:?}"
STUB
  chmod +x "${fixture_script_root}/${script_name}"
done < <(
  awk -F'"' '
    $2 ~ /^\$\{script_root\}\/.*\.sh$/ {
      sub(/^\$\{script_root\}\//, "", $2)
      print $2
    }
  ' "${development_gate}" |
    sort -u
)

for command_name in node git; do
  cat > "${fixture_bin}/${command_name}" <<'STUB'
#!/usr/bin/env bash

set -euo pipefail

printf '%s:%s\n' "$(basename "${0}")" "${*}" >> "${DBCODE_DEVELOPMENT_TRACE:?}"
STUB
  chmod +x "${fixture_bin}/${command_name}"
done

DBCODE_DEVELOPMENT_TRACE="${trace_file}" \
  PATH="${fixture_bin}:${PATH}" \
  "${fixture_script_root}/check_development.sh" >/dev/null

for adapter in \
  test_update_status_contract.sh \
  test_profile_migration_contract.sh \
  test_host_session_contract.sh; do
  require_line_once \
    "${trace_file}" \
    "script:${adapter}" \
    "The development gate must invoke ${adapter} exactly once"
done

for owned_node_test in \
  test_approved_release_set.mjs \
  test_update_status.mjs \
  test_profile_layout.mjs \
  test_profile_migration.mjs \
  test_host_session.mjs; do
  if rg -Fq "${owned_node_test}" "${trace_file}"; then
    echo "The development gate must leave ${owned_node_test} to its focused contract adapter." >&2
    exit 1
  fi
done

require_line_once \
  "${script_root}/test_update_status_contract.sh" \
  '"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_approved_release_set.mjs"' \
  "The update-status adapter must run its Approved Release Set Node tests with pinned Node"
require_line_once \
  "${script_root}/test_update_status_contract.sh" \
  '"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_update_status.mjs"' \
  "The update-status adapter must run its update-status Node tests with pinned Node"
require_line_once \
  "${script_root}/test_profile_migration_contract.sh" \
  '"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_profile_layout.mjs"' \
  "The profile-migration adapter must run its profile-layout Node tests with pinned Node"
require_line_once \
  "${script_root}/test_profile_migration_contract.sh" \
  '"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_profile_migration.mjs"' \
  "The profile-migration adapter must run its migration Node tests with pinned Node"
require_line_once \
  "${script_root}/test_host_session_contract.sh" \
  '"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_host_session.mjs"' \
  "The Host Session adapter must run its Node tests with pinned Node"

echo "Development gate execution contracts passed."
