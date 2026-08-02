#!/usr/bin/env bash

set -euo pipefail

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
build_task="${script_root}/build_host.sh"
checkpoint_module="${script_root}/lib/dist_checkpoint.sh"
source_digest_module="${script_root}/lib/source_digest.sh"

[[ -x "${build_task}" ]] || {
  echo "Missing owner-facing build task: script/build_host.sh" >&2
  exit 1
}
[[ -f "${checkpoint_module}" ]] || {
  echo "Missing dist checkpoint module: script/lib/dist_checkpoint.sh" >&2
  exit 1
}
rg -Fq 'script/lib/dist_checkpoint.sh' "${source_digest_module}" || {
  echo "The wrapper source digest does not cover the dist checkpoint module." >&2
  exit 1
}

for checkpoint_reader in \
  "${script_root}/smoke_host.sh" \
  "${script_root}/test_focused_shell_rendered.sh" \
  "${script_root}/verify_fast_release.sh" \
  "${script_root}/package_host_release.sh" \
  "${script_root}/verify_host_release.sh"; do
  rg -Fq 'lib/dist_checkpoint.sh' "${checkpoint_reader}" || {
    echo "A release reader does not load the dist checkpoint: ${checkpoint_reader}" >&2
    exit 1
  }
  rg -Fq 'dist_checkpoint_acquire' "${checkpoint_reader}" || {
    echo "A release reader does not acquire the dist checkpoint: ${checkpoint_reader}" >&2
    exit 1
  }
  rg -Fq 'dist_checkpoint_exit' "${checkpoint_reader}" || {
    echo "A release reader does not release the dist checkpoint: ${checkpoint_reader}" >&2
    exit 1
  }
done

assembly_trap_line="$(rg -n '^trap cleanup_assembly_stage EXIT$' "${script_root}/assemble_host.sh" | cut -d: -f1)"
assembly_stage_line="$(rg -n '^dist_checkpoint_create_stage$' "${script_root}/assemble_host.sh" | cut -d: -f1)"
[[ -n "${assembly_trap_line}" && -n "${assembly_stage_line}" && \
  "${assembly_trap_line}" -lt "${assembly_stage_line}" ]] || {
  echo "Host assembly must own cleanup before it creates the dist stage." >&2
  exit 1
}

fixture_parent="$(cd "${TMPDIR:-/private/tmp}" && pwd -P)"
fixture_root="$(mktemp -d "${fixture_parent%/}/dbcode-build-task.XXXXXX")"
first_pid=""
assembly_release=""
reader_pid=""
reader_release=""
borrower_pid=""
borrower_release=""
lease_parent_pid=""
cleanup_fixture() {
  local exit_status=$?
  trap - EXIT INT TERM
  if [[ -n "${first_pid}" ]] && kill -0 "${first_pid}" 2>/dev/null; then
    if [[ -n "${assembly_release}" ]]; then
      : > "${assembly_release}"
    fi
    for _ in {1..100}; do
      kill -0 "${first_pid}" 2>/dev/null || break
      sleep 0.01
    done
    if kill -0 "${first_pid}" 2>/dev/null; then
      kill -TERM "${first_pid}" 2>/dev/null || true
    fi
    wait "${first_pid}" 2>/dev/null || true
  fi
  if [[ -n "${reader_pid}" ]] && kill -0 "${reader_pid}" 2>/dev/null; then
    [[ -z "${reader_release}" ]] || : > "${reader_release}"
    wait "${reader_pid}" 2>/dev/null || true
  fi
  if [[ -n "${borrower_pid}" ]] && kill -0 "${borrower_pid}" 2>/dev/null; then
    [[ -z "${borrower_release}" ]] || : > "${borrower_release}"
    for _ in {1..200}; do
      kill -0 "${borrower_pid}" 2>/dev/null || break
      sleep 0.01
    done
    if kill -0 "${borrower_pid}" 2>/dev/null; then
      kill -TERM "${borrower_pid}" 2>/dev/null || true
      for _ in {1..100}; do
        kill -0 "${borrower_pid}" 2>/dev/null || break
        sleep 0.01
      done
    fi
    if kill -0 "${borrower_pid}" 2>/dev/null; then
      kill -KILL "${borrower_pid}" 2>/dev/null || true
      for _ in {1..100}; do
        kill -0 "${borrower_pid}" 2>/dev/null || break
        sleep 0.01
      done
    fi
    if kill -0 "${borrower_pid}" 2>/dev/null; then
      echo "The orphan checkpoint borrower survived fixture cleanup." >&2
      [[ "${exit_status}" -ne 0 ]] || exit_status=1
    fi
  fi
  if [[ -n "${lease_parent_pid}" ]] && kill -0 "${lease_parent_pid}" 2>/dev/null; then
    kill -TERM "${lease_parent_pid}" 2>/dev/null || true
    wait "${lease_parent_pid}" 2>/dev/null || true
  fi
  case "${fixture_root}" in
    "${fixture_parent%/}/dbcode-build-task."*)
      if ! rm -rf "${fixture_root}"; then
        [[ "${exit_status}" -ne 0 ]] || exit_status=1
      fi
      ;;
    *)
      echo "Refusing to remove an unexpected build-task fixture: ${fixture_root}" >&2
      [[ "${exit_status}" -ne 0 ]] || exit_status=1
      ;;
  esac
  exit "${exit_status}"
}
trap cleanup_fixture EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Fixture processes must open their fixture lock rather than borrow an outer
# release task's inherited descriptor. The open descriptor itself remains
# inherited, so an outer kernel lease is still held for this test's lifetime.
unset DBCODE_WRAPPER_DIST_CHECKPOINT_FD

mkdir -p \
  "${fixture_root}/bin" \
  "${fixture_root}/script/lib" \
  "${fixture_root}/fixture/materialized"
cp "${build_task}" "${fixture_root}/script/build_host.sh"
cp "${checkpoint_module}" "${fixture_root}/script/lib/dist_checkpoint.sh"
cp "${script_root}/test_focused_shell_rendered.sh" \
  "${fixture_root}/script/test_focused_shell_rendered.sh"
chmod 755 \
  "${fixture_root}/script/build_host.sh" \
  "${fixture_root}/script/test_focused_shell_rendered.sh"

cat > "${fixture_root}/script/lib/artifact_digest.sh" <<'EOF'
#!/usr/bin/env bash
artifact_digest() {
  [[ -z "${MOCK_READER_STARTED_FILE:-}" ]] || : > "${MOCK_READER_STARTED_FILE}"
  if [[ -n "${MOCK_READER_RELEASE_FILE:-}" ]]; then
    for _ in {1..500}; do
      [[ -e "${MOCK_READER_RELEASE_FILE}" ]] && break
      sleep 0.01
    done
    [[ -e "${MOCK_READER_RELEASE_FILE}" ]]
  fi
  printf 'fixture-digest\n'
}
EOF

cat > "${fixture_root}/script/lib/generated_workspace.sh" <<'EOF'
#!/usr/bin/env bash
generated_workspace_path() {
  printf '%s/.build/%s\n' "${GENERATED_REPO_ROOT}" "$1"
}
generated_workspace_assert_path() {
  return 0
}
EOF

cat > "${fixture_root}/script/lib/profile_paths.sh" <<'EOF'
#!/usr/bin/env bash
resolve_profile_paths() {
  PROFILE_LAYOUT="${GENERATED_REPO_ROOT}/.build/profile-layout.json"
  PROFILE_EXTENSIONS_ROOT="${GENERATED_REPO_ROOT}/.build/profile-extensions"
}
EOF

cat > "${fixture_root}/bin/mv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${MOCK_MV_FAIL_STAGE_PROMOTION:-no}" == "yes" && \
  "$#" -eq 2 && "$1" == */.build/assembly/dist.candidate && "$2" == */dist ]]; then
  exit 73
fi
exec /bin/mv "$@"
EOF
chmod 755 "${fixture_root}/bin/mv"

cat > "${fixture_root}/bin/chmod" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${MOCK_CHMOD_FAIL_CANDIDATE:-no}" == "yes" && \
  "${!#}" == */.build/assembly/dist.candidate ]]; then
  exit 74
fi
exec /bin/chmod "$@"
EOF
chmod 755 "${fixture_root}/bin/chmod"

cat > "${fixture_root}/bin/rm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${MOCK_RM_FAIL_CHECKPOINT:-no}" == "yes" && \
  ("${!#}" == */.build/assembly/dist.candidate || \
    "${!#}" == */.build/assembly/dist.previous) ]]; then
  exit 75
fi
exec /bin/rm "$@"
EOF
chmod 755 "${fixture_root}/bin/rm"

cat > "${fixture_root}/script/lib/host_config.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
GENERATED_REPO_ROOT="${DBCODE_WRAPPER_GENERATED_REPO_ROOT:-${REPO_ROOT}}"
BUILD_ROOT="${GENERATED_REPO_ROOT}/.build"
DIST_ROOT="${GENERATED_REPO_ROOT}/dist"
NODE_BIN_DIR="${GENERATED_REPO_ROOT}/fixture/node-bin"
WORK_ROOT="${GENERATED_REPO_ROOT}/.build/work"
APP_BUNDLE="${DIST_ROOT}/DBCode Wrapper.app"
BUILD_MANIFEST="${DIST_ROOT}/build-manifest.json"
assert_generated_path() {
  case "$1" in
    "${BUILD_ROOT}"/*|"${DIST_ROOT}"/*) ;;
    *) return 1 ;;
  esac
}
EOF

cat > "${fixture_root}/script/lib/release_source_snapshot.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
release_source_snapshot_write_record() {
  local repository="$1"
  local output_file="$3"
  mkdir -p "$(dirname "${output_file}")"
  printf '{"repository":"%s"}\n' "${repository}" > "${output_file}"
}
release_source_snapshot_materialize() {
  local repository="$1"
  local destination="$3"
  mkdir -p "${destination}/script/lib"
  cp "${repository}/fixture/materialized/setup_local_signing_identity.sh" \
    "${destination}/script/setup_local_signing_identity.sh"
  cp "${repository}/fixture/materialized/assemble_host.sh" \
    "${destination}/script/assemble_host.sh"
  cp "${repository}/script/lib/host_config.sh" \
    "${destination}/script/lib/host_config.sh"
  cp "${repository}/script/lib/dist_checkpoint.sh" \
    "${destination}/script/lib/dist_checkpoint.sh"
  chmod 755 \
    "${destination}/script/setup_local_signing_identity.sh" \
    "${destination}/script/assemble_host.sh"
  printf '%s\n' "${destination}"
}
EOF

cat > "${fixture_root}/fixture/materialized/setup_local_signing_identity.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == "--status" && $# -eq 1 ]]
printf 'preflight\n' >> "${BUILD_TASK_LOG}"
[[ "${MOCK_SIGNING_STATUS:-ready}" == "ready" ]]
EOF

cat > "${fixture_root}/fixture/materialized/assemble_host.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/dist_checkpoint.sh"
dist_checkpoint_require_lease
printf 'assemble\n' >> "${BUILD_TASK_LOG}"
if [[ -n "${MOCK_EXPECT_EXISTING_CHECKPOINT:-}" ]]; then
  [[ -f "${DIST_ROOT}/checkpoint.txt" ]]
  [[ "$(<"${DIST_ROOT}/checkpoint.txt")" == \
    "${MOCK_EXPECT_EXISTING_CHECKPOINT}" ]]
fi
if [[ -n "${MOCK_ASSEMBLY_STARTED_FILE:-}" ]]; then
  : > "${MOCK_ASSEMBLY_STARTED_FILE}"
fi
if [[ -n "${MOCK_ASSEMBLY_RELEASE_FILE:-}" ]]; then
  for _ in {1..200}; do
    [[ -e "${MOCK_ASSEMBLY_RELEASE_FILE}" ]] && break
    sleep 0.01
  done
  [[ -e "${MOCK_ASSEMBLY_RELEASE_FILE}" ]] || {
    echo "Timed out waiting for the synthetic assembly release." >&2
    exit 1
  }
fi
dist_checkpoint_create_stage
printf 'complete\n' > "${DIST_CHECKPOINT_STAGE}/checkpoint.txt"
if [[ "${MOCK_ASSEMBLY_FAIL_BEFORE_PROMOTION:-no}" == "yes" ]]; then
  exit 1
fi
dist_checkpoint_promote_stage "${DIST_CHECKPOINT_STAGE}"
EOF

export BUILD_TASK_LOG="${fixture_root}/.build/build-task.log"
mkdir -p "${fixture_root}/.build"

checkpoint_is_available() {
  DBCODE_WRAPPER_DIST_CHECKPOINT_FD= \
    bash -c '
      set -euo pipefail
      source "$1/script/lib/host_config.sh"
      source "$1/script/lib/dist_checkpoint.sh"
      dist_checkpoint_acquire "availability-probe"
      dist_checkpoint_release
    ' _ "${fixture_root}"
}

if TMPDIR="${fixture_root}/missing-tmp" \
  "${fixture_root}/script/build_host.sh" >/dev/null 2>&1; then
  echo "The build accepted a missing temporary root." >&2
  exit 1
fi
checkpoint_is_available

mkdir -p \
  "${fixture_root}/.build/assembly" \
  "${fixture_root}/.build/assembly/dist.candidate" \
  "${fixture_root}/dist"
printf 'previous\n' > "${fixture_root}/dist/checkpoint.txt"
/bin/mv \
  "${fixture_root}/dist" \
  "${fixture_root}/.build/assembly/dist.previous"
printf 'candidate\n' \
  > "${fixture_root}/.build/assembly/dist.candidate/checkpoint.txt"
: > "${BUILD_TASK_LOG}"
MOCK_EXPECT_EXISTING_CHECKPOINT="previous" \
  "${fixture_root}/script/build_host.sh" >/dev/null
[[ "$(paste -sd, "${BUILD_TASK_LOG}")" == "preflight,assemble" ]]
[[ ! -e "${fixture_root}/.build/assembly/dist.previous" ]]
[[ ! -e "${fixture_root}/.build/assembly/dist.candidate" ]]
checkpoint_is_available

mkdir -p "${fixture_root}/.build/assembly/dist.candidate"
printf 'interrupted\n' \
  > "${fixture_root}/.build/assembly/dist.candidate/checkpoint.txt"
: > "${BUILD_TASK_LOG}"
if MOCK_RM_FAIL_CHECKPOINT="yes" PATH="${fixture_root}/bin:${PATH}" \
  "${fixture_root}/script/build_host.sh" >/dev/null 2>&1; then
  echo "The build accepted a failed checkpoint recovery." >&2
  exit 1
fi
[[ -d "${fixture_root}/.build/assembly/dist.candidate" ]]
[[ ! -s "${BUILD_TASK_LOG}" ]]
checkpoint_is_available
[[ ! -e "${fixture_root}/.build/assembly/dist.candidate" ]]

export MOCK_SIGNING_STATUS="not-ready"
: > "${BUILD_TASK_LOG}"
if "${fixture_root}/script/build_host.sh" >/dev/null 2>&1; then
  echo "The build continued after a failed signing preflight." >&2
  exit 1
fi
[[ "$(paste -sd, "${BUILD_TASK_LOG}")" == "preflight" ]]
checkpoint_is_available

unset MOCK_SIGNING_STATUS
mkdir -p "${fixture_root}/dist"
printf 'previous\n' > "${fixture_root}/dist/checkpoint.txt"
: > "${BUILD_TASK_LOG}"
export MOCK_ASSEMBLY_FAIL_BEFORE_PROMOTION="yes"
if "${fixture_root}/script/build_host.sh" >/dev/null 2>&1; then
  echo "The synthetic assembly failure unexpectedly succeeded." >&2
  exit 1
fi
unset MOCK_ASSEMBLY_FAIL_BEFORE_PROMOTION
[[ "$(<"${fixture_root}/dist/checkpoint.txt")" == "previous" ]]
checkpoint_is_available

: > "${BUILD_TASK_LOG}"
MOCK_MV_FAIL_STAGE_PROMOTION="yes" \
PATH="${fixture_root}/bin:${PATH}" \
  "${fixture_root}/script/build_host.sh" >/dev/null 2>&1 && {
    echo "The synthetic promotion failure unexpectedly succeeded." >&2
    exit 1
  }
[[ "$(<"${fixture_root}/dist/checkpoint.txt")" == "previous" ]]
checkpoint_is_available
[[ -z "$(find "${fixture_root}/.build/assembly" -mindepth 1 -maxdepth 1 -print -quit)" ]]

: > "${BUILD_TASK_LOG}"
MOCK_CHMOD_FAIL_CANDIDATE="yes" \
PATH="${fixture_root}/bin:${PATH}" \
  "${fixture_root}/script/build_host.sh" >/dev/null 2>&1 && {
    echo "The synthetic candidate ownership failure unexpectedly succeeded." >&2
    exit 1
  }
[[ ! -e "${fixture_root}/.build/assembly/dist.candidate" ]]
[[ "$(<"${fixture_root}/dist/checkpoint.txt")" == "previous" ]]
checkpoint_is_available

: > "${BUILD_TASK_LOG}"
"${fixture_root}/script/build_host.sh" >/dev/null
[[ "$(paste -sd, "${BUILD_TASK_LOG}")" == "preflight,assemble" ]]
[[ -f "${fixture_root}/dist/checkpoint.txt" ]]
checkpoint_is_available

assembly_started="${fixture_root}/.build/assembly-started"
assembly_release="${fixture_root}/.build/assembly-release"
first_output="${fixture_root}/.build/first-build.log"
second_output="${fixture_root}/.build/second-build.log"
reader_output="${fixture_root}/.build/reader.log"
: > "${BUILD_TASK_LOG}"
MOCK_ASSEMBLY_STARTED_FILE="${assembly_started}" \
MOCK_ASSEMBLY_RELEASE_FILE="${assembly_release}" \
  "${fixture_root}/script/build_host.sh" > "${first_output}" 2>&1 &
first_pid=$!
for _ in {1..200}; do
  [[ -e "${assembly_started}" ]] && break
  sleep 0.01
done
[[ -e "${assembly_started}" ]] || {
  echo "The first synthetic build did not reach assembly." >&2
  exit 1
}
if "${fixture_root}/script/test_focused_shell_rendered.sh" \
  > "${reader_output}" 2>&1; then
  echo "A reader accepted a dist checkpoint owned by another build." >&2
  exit 1
fi
rg -Fq 'Another command owns the dist checkpoint' "${reader_output}"
if "${fixture_root}/script/build_host.sh" > "${second_output}" 2>&1; then
  echo "A second build acquired the active dist checkpoint." >&2
  exit 1
fi
rg -Fq 'Another command owns the dist checkpoint' "${second_output}"
: > "${assembly_release}"
wait "${first_pid}"
first_pid=""
checkpoint_is_available

mkdir -p \
  "${fixture_root}/fixture/node-bin" \
  "${fixture_root}/dist/DBCode Wrapper.app" \
  "${fixture_root}/.build/work/vscode/node_modules/playwright"
printf '{}\n' > "${fixture_root}/.build/work/vscode/node_modules/playwright/package.json"
jq -n '{artifact: {sha256: "fixture-digest"}, release: {release_set_id: "fixture-release-set"}}' \
  > "${fixture_root}/dist/build-manifest.json"
cat > "${fixture_root}/fixture/node-bin/node" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "${fixture_root}/script/prepare_dbcode.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod 755 \
  "${fixture_root}/fixture/node-bin/node" \
  "${fixture_root}/script/prepare_dbcode.sh"

reader_started="${fixture_root}/.build/reader-started"
reader_release="${fixture_root}/.build/reader-release"
reader_first_output="${fixture_root}/.build/reader-first.log"
writer_after_reader_output="${fixture_root}/.build/writer-after-reader.log"
MOCK_READER_STARTED_FILE="${reader_started}" \
MOCK_READER_RELEASE_FILE="${reader_release}" \
  "${fixture_root}/script/test_focused_shell_rendered.sh" \
    > "${reader_first_output}" 2>&1 &
reader_pid=$!
for _ in {1..200}; do
  [[ -e "${reader_started}" ]] && break
  sleep 0.01
done
[[ -e "${reader_started}" ]] || {
  echo "The public rendered reader did not acquire the dist checkpoint." >&2
  exit 1
}
if "${fixture_root}/script/build_host.sh" > "${writer_after_reader_output}" 2>&1; then
  echo "A build replaced the dist checkpoint while a reader held it." >&2
  exit 1
fi
rg -Fq 'Another command owns the dist checkpoint' "${writer_after_reader_output}"
: > "${reader_release}"
wait "${reader_pid}"
reader_pid=""
checkpoint_is_available

cat > "${fixture_root}/script/lease_borrower.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
fixture_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "${fixture_root}/script/lib/host_config.sh"
source "${fixture_root}/script/lib/dist_checkpoint.sh"
dist_checkpoint_acquire "live-borrower"
: > "${MOCK_BORROWER_STARTED_FILE}"
while [[ ! -e "${MOCK_BORROWER_RELEASE_FILE}" ]]; do
  sleep 0.01
done
dist_checkpoint_release
EOF
cat > "${fixture_root}/script/lease_parent.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
fixture_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "${fixture_root}/script/lib/host_config.sh"
source "${fixture_root}/script/lib/dist_checkpoint.sh"
dist_checkpoint_acquire "lease-parent"
"${fixture_root}/script/lease_borrower.sh" &
borrower_pid=$!
printf '%s\n' "${borrower_pid}" > "${MOCK_BORROWER_PID_FILE}"
wait "${borrower_pid}"
EOF
chmod 755 \
  "${fixture_root}/script/lease_borrower.sh" \
  "${fixture_root}/script/lease_parent.sh"

borrower_started="${fixture_root}/.build/borrower-started"
borrower_release="${fixture_root}/.build/borrower-release"
borrower_pid_file="${fixture_root}/.build/borrower.pid"
parent_output="${fixture_root}/.build/lease-parent.log"
MOCK_BORROWER_STARTED_FILE="${borrower_started}" \
MOCK_BORROWER_RELEASE_FILE="${borrower_release}" \
MOCK_BORROWER_PID_FILE="${borrower_pid_file}" \
  "${fixture_root}/script/lease_parent.sh" > "${parent_output}" 2>&1 &
lease_parent_pid=$!
for _ in {1..200}; do
  [[ -e "${borrower_started}" && -s "${borrower_pid_file}" ]] && break
  sleep 0.01
done
[[ -e "${borrower_started}" && -s "${borrower_pid_file}" ]] || {
  echo "The inherited dist checkpoint borrower did not start." >&2
  exit 1
}
borrower_pid="$(<"${borrower_pid_file}")"
kill -KILL "${lease_parent_pid}"
wait "${lease_parent_pid}" 2>/dev/null || true
lease_parent_pid=""
if "${fixture_root}/script/build_host.sh" > "${second_output}" 2>&1; then
  echo "A build acquired the checkpoint while an inherited borrower was alive." >&2
  exit 1
fi
rg -Fq 'Another command owns the dist checkpoint' "${second_output}"
: > "${borrower_release}"
for _ in {1..300}; do
  kill -0 "${borrower_pid}" 2>/dev/null || break
  sleep 0.01
done
if kill -0 "${borrower_pid}" 2>/dev/null; then
  echo "The inherited dist checkpoint borrower did not exit." >&2
  exit 1
fi
borrower_pid=""
checkpoint_is_available

echo "Owner-facing build task contracts passed."
