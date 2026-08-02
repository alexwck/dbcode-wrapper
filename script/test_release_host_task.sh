#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/generated_workspace.sh"

task="${REPO_ROOT}/script/release_host.sh"
[[ -x "${task}" ]] || {
  echo "Missing executable owner-facing Host Release task: script/release_host.sh" >&2
  exit 1
}

plan="$("${task}" plan)"
release_tag="v${WRAPPER_VERSION}"
release_source_revision="$(git -C "${REPO_ROOT}" rev-parse 'HEAD^{commit}')"
current_branch="$(git -C "${REPO_ROOT}" branch --show-current)"
working_tree_clean="true"
[[ -z "$(git -C "${REPO_ROOT}" status --porcelain)" ]] || working_tree_clean="false"
existing_tag_revision=""
if git -C "${REPO_ROOT}" rev-parse --verify "refs/tags/${release_tag}" >/dev/null 2>&1; then
  existing_tag_revision="$(git -C "${REPO_ROOT}" rev-parse "${release_tag}^{commit}")"
fi
release_evidence_key="${release_tag}-source-${release_source_revision}"
expected_rendered_report="$(
  generated_workspace_path "rendered-screenshots"
)/focused-shell-rendered-report.json"

jq -e \
  --arg repository "${REPO_ROOT}" \
  --arg release_tag "${release_tag}" \
  --arg source_revision "${release_source_revision}" \
  --arg evidence_key "${release_evidence_key}" \
  --arg app "${APP_BUNDLE}" \
  --arg manifest "${BUILD_MANIFEST}" \
  --arg release_lock "${LOCK_FILE}" \
  --arg rendered_report "${expected_rendered_report}" \
  --arg acceptance "${BUILD_ROOT}/acceptance/fast-release/${release_evidence_key}/final-acceptance-report.json" \
  --arg assets "${BUILD_ROOT}/host-release/${release_evidence_key}" \
  --arg approval "${BUILD_ROOT}/acceptance/fast-release/${release_evidence_key}-approval" \
  --arg approved_history_candidate "${BUILD_ROOT}/acceptance/fast-release/${release_evidence_key}-approval/approved-release-sets.json" \
  --arg history "${REPO_ROOT}/host/approved-release-history.json" \
  --arg current_branch "${current_branch}" \
  --argjson working_tree_clean "${working_tree_clean}" \
  --arg existing_tag_revision "${existing_tag_revision}" '
    .schema_version == 2
    and .release_tag == $release_tag
    and .source_revision == $source_revision
    and .evidence_key == $evidence_key
    and .source_repository == $repository
    and (.preparation.ready | type) == "boolean"
    and ((.preparation.blocker == null) or ((.preparation.blocker | type) == "string"))
    and .preparation.current_branch == $current_branch
    and .preparation.working_tree_clean == $working_tree_clean
    and .preparation.existing_tag_revision == (
      if $existing_tag_revision == "" then null else $existing_tag_revision end
    )
    and .paths == {
      app: $app,
      manifest: $manifest,
      release_lock: $release_lock,
      rendered_report: $rendered_report,
      acceptance: $acceptance,
      assets: $assets,
      approval: $approval,
      approved_history_candidate: $approved_history_candidate,
      approved_history: $history
    }
    and .stages == ["preflight", "build", "static", "render", "accept", "tag", "package", "approve", "record", "publish"]
    and .signing_preflight_prompt_free == true
    and .build_owned_by_prepare == true
    and .rendered_smoke_owned_by_prepare == true
    and .dist_checkpoint_serialized == true
    and .tag_created_after_acceptance == true
    and .approval_history_commit_required == true
    and .exact_evidence_resume_supported == true
    and .explicit_publish_required == true
    and .automatic_publish == false
  ' <<<"${plan}" >/dev/null

alternate_fixture_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
alternate_generated_root="$(
  mktemp -d "${alternate_fixture_parent%/}/dbcode-release-task-generated.XXXXXX"
)"
alternate_node_bin="$(
  printf '%s/.build/toolchains/node-v%s-darwin-%s/bin\n' \
    "${alternate_generated_root}" \
    "${NODE_VERSION}" \
    "${TARGET_ARCH}"
)"
mkdir -p "${alternate_node_bin}"
ln -s "${NODE_BIN_DIR}/node" "${alternate_node_bin}/node"
alternate_plan="$(
  DBCODE_WRAPPER_GENERATED_REPO_ROOT="${alternate_generated_root}" \
    "${task}" plan
)"
jq -e \
  --arg rendered_report "${alternate_generated_root}/output/playwright/focused-shell-rendered-report.json" \
  '.paths.rendered_report == $rendered_report' \
  <<<"${alternate_plan}" >/dev/null || {
  echo "The owner-facing release task ignored the launcher generated-workspace root." >&2
  exit 1
}
case "${alternate_generated_root}" in
  "${alternate_fixture_parent%/}"/dbcode-release-task-generated.*)
    rm -rf "${alternate_generated_root}"
    ;;
  *)
    echo "Refusing to remove an unexpected alternate generated root." >&2
    exit 1
    ;;
esac

for required_release_step in \
  'approved-release-sets.json' \
  'approved_release_history_record_approval' \
  'approval_history_commit_required' \
  'Record and commit host/approved-release-history.json before publication.'; do
  rg -Fq "${required_release_step}" "${task}" || {
    echo "The owner-facing release task is missing: ${required_release_step}" >&2
    exit 1
  }
done

if "${task}" publish >/dev/null 2>&1; then
  echo "The owner-facing release task published without --publish." >&2
  exit 1
fi
if "${task}" plan --publish >/dev/null 2>&1; then
  echo "The owner-facing release task accepted --publish outside publication." >&2
  exit 1
fi

fixture_parent="${TMPDIR:-/private/tmp}"
fixture_root="$(mktemp -d "${fixture_parent%/}/dbcode-release-task.XXXXXX")"
cleanup_fixture() {
  case "${fixture_root}" in
    "${fixture_parent%/}/dbcode-release-task."*) rm -rf "${fixture_root}" ;;
    *)
      echo "Refusing to remove an unexpected release-task fixture: ${fixture_root}" >&2
      return 1
      ;;
  esac
}
trap cleanup_fixture EXIT INT TERM

# Keep any outer release lease open, but do not pass its repository identity to
# this isolated fixture. The fixture owner opens its own kernel-backed lease.
unset DBCODE_WRAPPER_DIST_CHECKPOINT_FD

mkdir -p \
  "${fixture_root}/script/lib" \
  "${fixture_root}/host" \
  "${fixture_root}/dist"
cp "${task}" "${fixture_root}/script/release_host.sh"
cp "${REPO_ROOT}/script/lib/dist_checkpoint.sh" \
  "${fixture_root}/script/lib/dist_checkpoint.sh"
chmod 755 "${fixture_root}/script/release_host.sh"

cat > "${fixture_root}/script/lib/host_config.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
GENERATED_REPO_ROOT="${DBCODE_WRAPPER_GENERATED_REPO_ROOT:-${REPO_ROOT}}"
BUILD_ROOT="${GENERATED_REPO_ROOT}/.build"
DIST_ROOT="${GENERATED_REPO_ROOT}/dist"
WRAPPER_VERSION="9.9.9"
APP_BUNDLE="${DIST_ROOT}/DBCode Wrapper.app"
BUILD_MANIFEST="${DIST_ROOT}/build-manifest.json"
LOCK_FILE="${REPO_ROOT}/host/release-lock.json"
assert_generated_path() {
  case "$1" in
    "${BUILD_ROOT}"/*|"${DIST_ROOT}"/*) ;;
    *) return 1 ;;
  esac
}
EOF

cat > "${fixture_root}/script/lib/generated_workspace.sh" <<'EOF'
#!/usr/bin/env bash
fixture_generated_root="${REPO_ROOT}/.${FIXTURE_GENERATED_DIRECTORY_NAME:-build}"
generated_workspace_path() {
  case "$1" in
    rendered-evidence) printf '%s\n' "${fixture_generated_root}/qa" ;;
    rendered-screenshots) printf '%s\n' "${REPO_ROOT}/output/playwright" ;;
    acceptance-evidence) printf '%s\n' "${fixture_generated_root}/acceptance" ;;
    host-release-assets) printf '%s\n' "${fixture_generated_root}/host-release" ;;
    *) return 1 ;;
  esac
}
EOF

cat > "${fixture_root}/script/lib/approved_release_set.sh" <<'EOF'
#!/usr/bin/env bash
approved_release_set_validate_recorded_approval() {
  printf 'validate-approval\n' >> "${RELEASE_TASK_LOG}"
}
approved_release_history_record_approval() {
  [[ "$1" == "$4" ]]
  printf 'record\n' >> "${RELEASE_TASK_LOG}"
  cp "$3" "$4"
}
EOF

cat > "${fixture_root}/script/setup_local_signing_identity.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == "--status" && $# -eq 1 ]]
printf 'preflight\n' >> "${RELEASE_TASK_LOG}"
[[ "${MOCK_SIGNING_STATUS:-ready}" == "ready" ]]
EOF

cat > "${fixture_root}/script/build_host.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
fixture_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
"${fixture_root}/script/setup_local_signing_identity.sh" --status
printf 'build\n' >> "${RELEASE_TASK_LOG}"
[[ "${DBCODE_WRAPPER_DIST_CHECKPOINT_FD:-}" == "9" ]]
[[ -e /dev/fd/9 ]]
/usr/bin/lockf -s -t 0 9
mkdir -p "${fixture_root}/dist/DBCode Wrapper.app"
fixture_revision="$(git -C "${fixture_root}" rev-parse HEAD)"
jq -n \
  --arg revision "${fixture_revision}" '
    {
      source: {snapshot: {repository_revision: $revision}},
      release: {release_set_id: "fixture-release-set"},
      artifact: {sha256: ("a" * 64)}
    }
  ' > "${fixture_root}/dist/build-manifest.json"
EOF

cat > "${fixture_root}/script/smoke_host.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
fixture_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
[[ -d "${fixture_root}/dist/DBCode Wrapper.app" ]]
[[ -f "${fixture_root}/dist/build-manifest.json" ]]
printf 'static\n' >> "${RELEASE_TASK_LOG}"
EOF

cat > "${fixture_root}/script/test_focused_shell_rendered.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
fixture_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
printf 'render\n' >> "${RELEASE_TASK_LOG}"
mkdir -p "${fixture_root}/output/playwright"
jq -n '
  {
    status: "passed",
    mode: "smoke",
    releaseSetId: "fixture-release-set",
    profile: {name: "qa", persistent: true},
    errors: [],
    checks: []
  }
' > "${fixture_root}/output/playwright/focused-shell-rendered-report.json"
EOF

cat > "${fixture_root}/script/verify_fast_release.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) output="$2"; shift ;;
  esac
  shift
done
[[ -n "${output}" ]]
printf 'accept\n' >> "${RELEASE_TASK_LOG}"
mkdir -p "$(dirname "${output}")"
jq -n \
  --arg status "${MOCK_ACCEPTANCE_STATUS:-passed}" '
    {
      schema_version: 3,
      status: $status,
      gates: {complete: (if $status == "passed" then "passed" else "failed" end)}
    }
  ' > "${output}"
EOF

cat > "${fixture_root}/script/host_release_contract.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
fixture_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
[[ "$1" == "prompt-free-acceptance-record" && $# -eq 4 ]]
printf 'validate-acceptance\n' >> "${RELEASE_TASK_LOG}"
if [[ "${MOCK_ADVANCE_SOURCE_DURING_VALIDATION:-no}" == "yes" ]]; then
  current_revision="$(git -C "${fixture_root}" rev-parse HEAD)"
  advanced_revision="$(
    printf 'advance source during acceptance\n' |
      git -C "${fixture_root}" commit-tree \
        "${current_revision}^{tree}" \
        -p "${current_revision}"
  )"
  git -C "${fixture_root}" update-ref \
    refs/heads/main \
    "${advanced_revision}" \
    "${current_revision}"
fi
jq -e '
  .schema_version == 3
  and .status == "passed"
  and .gates.complete == "passed"
' "$4" >/dev/null
EOF

cat > "${fixture_root}/script/package_host_release.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output_dir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir) output_dir="$2"; shift ;;
  esac
  shift
done
[[ -n "${output_dir}" ]]
printf 'package\n' >> "${RELEASE_TASK_LOG}"
mkdir -p "${output_dir}"
printf 'fixture dmg\n' > "${output_dir}/fixture.dmg"
dmg_sha256="$(shasum -a 256 "${output_dir}/fixture.dmg" | awk '{print $1}')"
dmg_size_bytes="$(stat -f '%z' "${output_dir}/fixture.dmg")"
printf '%s  fixture.dmg\n' "${dmg_sha256}" \
  > "${output_dir}/fixture.dmg.sha256"
printf 'fixture notes\n' > "${output_dir}/fixture-install-and-rollback.txt"
notes_sha256="$(
  shasum -a 256 "${output_dir}/fixture-install-and-rollback.txt" |
    awk '{print $1}'
)"
jq -n \
  --arg dmg_sha256 "${dmg_sha256}" \
  --argjson dmg_size_bytes "${dmg_size_bytes}" \
  --arg notes_sha256 "${notes_sha256}" '
    {
      schema_version: 1,
      disk_image: {
        filename: "fixture.dmg",
        sha256: $dmg_sha256,
        size_bytes: $dmg_size_bytes,
        install_guide_sha256: $notes_sha256
      },
      assets: {
        checksum: "fixture.dmg.sha256",
        compatibility: "fixture-compatibility.json",
        install_and_rollback: "fixture-install-and-rollback.txt",
        verification: "fixture-verification.json"
      }
    }
  ' > "${output_dir}/fixture-compatibility.json"
printf '{}\n' > "${output_dir}/fixture-verification.json"
EOF

cat > "${fixture_root}/script/approve_host_release.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output_dir=""
source_tag=""
compatibility_file=""
verification_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir) output_dir="$2"; shift ;;
    --source-tag) source_tag="$2"; shift ;;
    --compatibility) compatibility_file="$2"; shift ;;
    --verification) verification_file="$2"; shift ;;
  esac
  shift
done
[[ -n "${output_dir}" && -n "${source_tag}" && \
  -n "${compatibility_file}" && -n "${verification_file}" ]]
printf 'approve\n' >> "${RELEASE_TASK_LOG}"
mkdir -p "${output_dir}"
jq -n \
  --arg tag "${source_tag}" \
  --arg compatibility_sha256 "$(shasum -a 256 "${compatibility_file}" | awk '{print $1}')" \
  --arg verification_sha256 "$(shasum -a 256 "${verification_file}" | awk '{print $1}')" '
  {
    schema_version: 2,
    release_set_id: "fixture-release-set",
    source_tag: $tag,
    compatibility_manifest_sha256: $compatibility_sha256,
    verification_sha256: $verification_sha256
  }
' > "${output_dir}/approval-attestation.json"
printf '{"schema_version":2,"id":"fixture-release-set"}\n' \
  > "${output_dir}/approved-release-set.json"
printf '{"schema_version":2,"approved_release_sets":[{"id":"fixture-release-set"}]}\n' \
  > "${output_dir}/approved-release-sets.json"
EOF

cat > "${fixture_root}/script/publish_release.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'publish\n' >> "${RELEASE_TASK_LOG}"
EOF

chmod 755 \
  "${fixture_root}/script/setup_local_signing_identity.sh" \
  "${fixture_root}/script/build_host.sh" \
  "${fixture_root}/script/smoke_host.sh" \
  "${fixture_root}/script/test_focused_shell_rendered.sh" \
  "${fixture_root}/script/verify_fast_release.sh" \
  "${fixture_root}/script/host_release_contract.sh" \
  "${fixture_root}/script/package_host_release.sh" \
  "${fixture_root}/script/approve_host_release.sh" \
  "${fixture_root}/script/publish_release.sh"

printf '{}\n' > "${fixture_root}/host/release-lock.json"
printf '{"schema_version":2,"approved_release_sets":[]}\n' \
  > "${fixture_root}/host/approved-release-history.json"
printf '.build/\ndist/\noutput/\n' > "${fixture_root}/.gitignore"

git -C "${fixture_root}" init -q
git -C "${fixture_root}" branch -M main
git -C "${fixture_root}" config user.name "Release Task Test"
git -C "${fixture_root}" config user.email "release-task@example.invalid"
git -C "${fixture_root}" add .
git -C "${fixture_root}" commit -qm "fixture source"
tagged_fixture_revision="$(git -C "${fixture_root}" rev-parse HEAD)"
git -C "${fixture_root}" tag -a v9.9.9 -m "fixture old release"
printf 'new release source\n' > "${fixture_root}/current-source.txt"
git -C "${fixture_root}" add current-source.txt
git -C "${fixture_root}" commit -qm "advance fixture source"
fixture_revision="$(git -C "${fixture_root}" rev-parse HEAD)"
fixture_evidence_key="v9.9.9-source-${fixture_revision}"

export RELEASE_TASK_LOG="${fixture_root}/.build/release-task.log"
mkdir -p "${fixture_root}/.build"
: > "${RELEASE_TASK_LOG}"

blocked_plan="$("${fixture_root}/script/release_host.sh" plan)"
jq -e \
  --arg source_revision "${fixture_revision}" \
  --arg tag_revision "${tagged_fixture_revision}" '
    .schema_version == 2
    and .source_revision == $source_revision
    and .preparation == {
      ready: false,
      blocker: "release-tag-identifies-another-commit",
      current_branch: "main",
      working_tree_clean: true,
      existing_tag_revision: $tag_revision
    }
  ' <<<"${blocked_plan}" >/dev/null
if "${fixture_root}/script/release_host.sh" prepare >/dev/null 2>&1; then
  echo "The release task prepared a source whose version tag identifies another commit." >&2
  exit 1
fi
[[ ! -s "${RELEASE_TASK_LOG}" ]]
[[ ! -e "${fixture_root}/.build/locks/dist-checkpoint.lock" ]]
git -C "${fixture_root}" tag -d v9.9.9 >/dev/null

legacy_approval_dir="${fixture_root}/.build/acceptance/fast-release/v9.9.9-approval"
mkdir -p "${legacy_approval_dir}"
printf 'retained legacy approval\n' > "${legacy_approval_dir}/retained.txt"

export MOCK_ACCEPTANCE_STATUS="failed"
if "${fixture_root}/script/release_host.sh" prepare >/dev/null 2>&1; then
  echo "The release task accepted an incomplete report." >&2
  exit 1
fi
[[ "$(paste -sd, "${RELEASE_TASK_LOG}")" == \
  "preflight,build,static,render,accept,validate-acceptance" ]]
[[ -f "${fixture_root}/.build/locks/dist-checkpoint.lock" ]]
/usr/bin/lockf -s -t 0 -k \
  "${fixture_root}/.build/locks/dist-checkpoint.lock" \
  /usr/bin/true
[[ -z "$(git -C "${fixture_root}" tag --list v9.9.9)" ]] || {
  echo "The release task created a tag before full acceptance validation." >&2
  exit 1
}
rm -f "${fixture_root}/.build/acceptance/fast-release/${fixture_evidence_key}/final-acceptance-report.json"

unset MOCK_ACCEPTANCE_STATUS
: > "${RELEASE_TASK_LOG}"
"${fixture_root}/script/release_host.sh" prepare >/dev/null
[[ "$(git -C "${fixture_root}" rev-parse 'v9.9.9^{commit}')" == "${fixture_revision}" ]]
[[ "$(paste -sd, "${RELEASE_TASK_LOG}")" == \
  "preflight,static,accept,validate-acceptance,package,approve,validate-approval,record" ]]
[[ "$(git -C "${fixture_root}" status --porcelain)" == \
  " M host/approved-release-history.json" ]]
[[ "$(<"${legacy_approval_dir}/retained.txt")" == "retained legacy approval" ]]

cp "${fixture_root}/current-source.txt" \
  "${fixture_root}/.build/current-source.clean"
printf 'uncommitted release source\n' >> "${fixture_root}/current-source.txt"
: > "${RELEASE_TASK_LOG}"
dirty_resume_plan="$("${fixture_root}/script/release_host.sh" plan)"
jq -e '
  .preparation.ready == false
  and .preparation.blocker == "release-source-not-clean"
  and .preparation.working_tree_clean == false
' <<<"${dirty_resume_plan}" >/dev/null
if "${fixture_root}/script/release_host.sh" prepare >/dev/null 2>&1; then
  echo "The release task resumed from an unrelated dirty source." >&2
  exit 1
fi
[[ ! -s "${RELEASE_TASK_LOG}" ]]
cp "${fixture_root}/.build/current-source.clean" \
  "${fixture_root}/current-source.txt"

export MOCK_ADVANCE_SOURCE_DURING_VALIDATION="yes"
: > "${RELEASE_TASK_LOG}"
if "${fixture_root}/script/release_host.sh" prepare >/dev/null 2>&1; then
  echo "The release task accepted a checkout that advanced after preflight." >&2
  exit 1
fi
unset MOCK_ADVANCE_SOURCE_DURING_VALIDATION
[[ "$(paste -sd, "${RELEASE_TASK_LOG}")" == \
  "preflight,static,validate-acceptance" ]]
advanced_fixture_revision="$(git -C "${fixture_root}" rev-parse HEAD)"
[[ "${advanced_fixture_revision}" != "${fixture_revision}" ]]
git -C "${fixture_root}" update-ref \
  refs/heads/main \
  "${fixture_revision}" \
  "${advanced_fixture_revision}"

verification_asset="${fixture_root}/.build/host-release/${fixture_evidence_key}/fixture-verification.json"
rm -f "${verification_asset}"
: > "${RELEASE_TASK_LOG}"
if "${fixture_root}/script/release_host.sh" prepare >/dev/null 2>&1; then
  echo "The release task reused an incomplete Host Release asset set." >&2
  exit 1
fi
[[ "$(paste -sd, "${RELEASE_TASK_LOG}")" == \
  "preflight,static,validate-acceptance" ]]
printf '{}\n' > "${verification_asset}"

printf '{"changed":true}\n' > "${verification_asset}"
: > "${RELEASE_TASK_LOG}"
if "${fixture_root}/script/release_host.sh" prepare >/dev/null 2>&1; then
  echo "The release task reused assets that no longer match their approval." >&2
  exit 1
fi
[[ "$(paste -sd, "${RELEASE_TASK_LOG}")" == \
  "preflight,static,validate-acceptance,validate-approval" ]]
printf '{}\n' > "${verification_asset}"

: > "${RELEASE_TASK_LOG}"
"${fixture_root}/script/release_host.sh" prepare >/dev/null
[[ "$(paste -sd, "${RELEASE_TASK_LOG}")" == \
  "preflight,static,validate-acceptance,validate-approval,record" ]]

git -C "${fixture_root}" add host/approved-release-history.json
git -C "${fixture_root}" commit -qm "record approval"
: > "${RELEASE_TASK_LOG}"
"${fixture_root}/script/release_host.sh" publish --publish >/dev/null
[[ "$(paste -sd, "${RELEASE_TASK_LOG}")" == "validate-approval,publish" ]]

echo "Owner-facing Host Release task contract passed."
