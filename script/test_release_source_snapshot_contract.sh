#!/usr/bin/env bash

set -euo pipefail
umask 077

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
snapshot_command="${script_root}/release_source_snapshot.sh"
source "${script_root}/lib/release_source_snapshot.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-release-source-snapshot.XXXXXX")"
repository="${test_root}/source repository"
record="${test_root}/snapshot records/release source.json"

cleanup() {
  rm -rf "${test_root}"
}
trap cleanup EXIT INT TERM

[[ -x "${snapshot_command}" ]] || {
  echo "Missing Release Source Snapshot command: ${snapshot_command}" >&2
  exit 1
}

mkdir -p "${repository}/host" "${repository}/script"
git -c init.defaultBranch=main -C "${repository}" init -q
git -C "${repository}" config user.name "DBCode Wrapper Test"
git -C "${repository}" config user.email "dbcode-wrapper-test@example.invalid"
printf '%s\n' '{"schema_version":1}' > "${repository}/host/release-lock.json"
printf '%s\n' 'wrapper source' > "${repository}/host/wrapper.txt"
printf '%s\n' '#!/usr/bin/env bash' > "${repository}/script/build.sh"
printf '%s\n' '# Fixture repository' > "${repository}/README.md"
git -C "${repository}" add .
git -C "${repository}" commit -q -m "Create immutable release source"

source_commit="$(git -C "${repository}" rev-parse HEAD)"
source_tree="$(git -C "${repository}" rev-parse 'HEAD^{tree}')"
release_lock_sha256="$(shasum -a 256 "${repository}/host/release-lock.json" | awk '{print $1}')"

"${snapshot_command}" create \
  --repository "${repository}" \
  --ref HEAD \
  --output "${record}"

jq -e \
  --arg source_commit "${source_commit}" \
  --arg source_tree "${source_tree}" \
  --arg release_lock_sha256 "${release_lock_sha256}" '
    .schema_version == 1
    and .mode == "immutable-git-commit"
    and .requested_ref == "HEAD"
    and .repository_revision == $source_commit
    and .tree_oid == $source_tree
    and .release_lock_sha256 == $release_lock_sha256
    and (.snapshot_sha256 | test("^[0-9a-f]{64}$"))
    and (.host_script_sha256 | test("^[0-9a-f]{64}$"))
  ' "${record}" >/dev/null

"${snapshot_command}" verify \
  --repository "${repository}" \
  --record "${record}"

(
  cd "${test_root}"
  "${snapshot_command}" create \
    --repository "source repository" \
    --ref HEAD \
    --output "relative records/release source.json" >/dev/null
  "${snapshot_command}" verify \
    --repository "source repository" \
    --record "relative records/release source.json" >/dev/null
)

printf '%s\n' 'changed wrapper source' > "${repository}/host/wrapper.txt"
release_source_snapshot_verify_json \
  "${repository}" \
  "$(jq -c . "${record}")"
materialized_source="${test_root}/materialized source"
release_source_snapshot_materialize \
  "${repository}" \
  "${record}" \
  "${materialized_source}" >/dev/null
[[ "$(cat "${materialized_source}/host/wrapper.txt")" == "wrapper source" ]] || {
  echo "The materialized source did not use the recorded immutable commit." >&2
  exit 1
}
release_source_snapshot_verify_record "${materialized_source}" "${record}"
if "${snapshot_command}" verify \
  --repository "${repository}" \
  --record "${record}" >/dev/null 2>&1; then
  echo "The Release Source Snapshot accepted a changed tracked file." >&2
  exit 1
fi
if "${snapshot_command}" create \
  --repository "${repository}" \
  --ref HEAD \
  --output "${test_root}/dirty.json" >/dev/null 2>&1; then
  echo "The Release Source Snapshot accepted a dirty working tree." >&2
  exit 1
fi

git -C "${repository}" add host/wrapper.txt
git -C "${repository}" commit -q -m "Change wrapper source"
printf '%s\n' 'untracked release input' > "${repository}/host/untracked.txt"
if "${snapshot_command}" create \
  --repository "${repository}" \
  --ref HEAD \
  --output "${test_root}/untracked.json" >/dev/null 2>&1; then
  echo "The Release Source Snapshot accepted an untracked file." >&2
  exit 1
fi

rm "${repository}/host/untracked.txt"
if "${snapshot_command}" create \
  --repository "${repository}" \
  --ref "${source_commit}" \
  --output "${test_root}/wrong-head.json" >/dev/null 2>&1; then
  echo "The Release Source Snapshot accepted a ref other than the checked-out commit." >&2
  exit 1
fi

echo "Release Source Snapshot contracts passed."
