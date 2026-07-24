#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

restorer="${REPO_ROOT}/script/restore_installed_extension_payload.sh"
verifier="${REPO_ROOT}/script/verify_installed_extension_payload.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-extension-restore.XXXXXX")"
cleanup_test_root() {
  rm -rf "${test_root}"
}
trap cleanup_test_root EXIT INT TERM

package_root="${test_root}/package"
extensions_root="${test_root}/isolated-extensions"
installed_root="${extensions_root}/sample.extension-1.2.3"
mkdir -p "${package_root}/extension/nested" "${package_root}/extension/resources" \
  "${installed_root}/nested" "${installed_root}/resources"
jq -n '{publisher: "sample", name: "extension", version: "1.2.3", engines: {vscode: "^1.95.0"}}' \
  > "${package_root}/extension/package.json"
printf 'official payload\n' > "${package_root}/extension/nested/payload.txt"
printf 'official sqlite database\n' > "${package_root}/extension/resources/sample.db"
printf '<manifest />\n' > "${package_root}/extension.vsixmanifest"
printf '<types />\n' > "${package_root}/[Content_Types].xml"
(
  cd "${package_root}"
  zip -q -r "${test_root}/package.vsix" extension extension.vsixmanifest '[Content_Types].xml'
)

jq '.__metadata = {installedTimestamp: 123456789, size: 42, targetPlatform: "undefined"}' \
  "${package_root}/extension/package.json" > "${installed_root}/package.json"
printf 'runtime-modified payload\n' > "${installed_root}/nested/payload.txt"
printf 'runtime-modified sqlite database\n' > "${installed_root}/resources/sample.db"
printf 'stale WAL\n' > "${installed_root}/resources/sample.db-wal"
printf 'stale shared memory\n' > "${installed_root}/resources/sample.db-shm"
printf 'stale journal\n' > "${installed_root}/resources/sample.db-journal"
printf '<changed />\n' > "${installed_root}/.vsixmanifest"
printf 'keep this runtime download\n' > "${installed_root}/runtime-extra.bin"

"${restorer}" \
  "${test_root}/package.vsix" \
  "${extensions_root}" \
  sample.extension \
  1.2.3

"${verifier}" \
  "${test_root}/package.vsix" \
  "${extensions_root}" \
  sample.extension \
  1.2.3 >/dev/null

[[ "$(cat "${installed_root}/runtime-extra.bin")" == "keep this runtime download" ]] || {
  echo "Signed-payload restoration removed a runtime-created extension file." >&2
  exit 1
}
jq -e '
  .__metadata == {installedTimestamp: 123456789, size: 42, targetPlatform: "undefined"}
' "${installed_root}/package.json" >/dev/null || {
  echo "Signed-payload restoration removed the host installation metadata." >&2
  exit 1
}
for sqlite_sidecar in \
  "${installed_root}/resources/sample.db-wal" \
  "${installed_root}/resources/sample.db-shm" \
  "${installed_root}/resources/sample.db-journal"; do
  [[ ! -e "${sqlite_sidecar}" && ! -L "${sqlite_sidecar}" ]] || {
    echo "Signed-payload restoration left a stale SQLite transaction sidecar." >&2
    exit 1
  }
done

echo "Signed extension payload restoration preserved runtime extras and install metadata."
