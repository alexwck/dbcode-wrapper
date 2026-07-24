#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

verifier="${REPO_ROOT}/script/verify_installed_extension_payload.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-extension-payload.XXXXXX")"
cleanup_test_root() {
  rm -rf "${test_root}"
}
trap cleanup_test_root EXIT INT TERM

package_root="${test_root}/package"
installed_root="${test_root}/extensions/sample.extension-1.2.3"
mkdir -p "${package_root}/extension/resources" "${installed_root}/resources"
jq -n '{publisher: "sample", name: "extension", version: "1.2.3", engines: {vscode: "^1.95.0"}}' \
  > "${package_root}/extension/package.json"
printf 'signed payload\n' > "${package_root}/extension/payload.txt"
printf 'signed sqlite database\n' > "${package_root}/extension/resources/sample.db"
printf '<manifest />\n' > "${package_root}/extension.vsixmanifest"
printf '<types />\n' > "${package_root}/[Content_Types].xml"
(
  cd "${package_root}"
  zip -q -r "${test_root}/package.vsix" extension extension.vsixmanifest '[Content_Types].xml'
)
cp "${package_root}/extension/package.json" "${installed_root}/package.json"
jq '.__metadata = {installedTimestamp: 123456789, size: 42, targetPlatform: "undefined"}' \
  "${installed_root}/package.json" > "${installed_root}/package.json.tmp"
mv "${installed_root}/package.json.tmp" "${installed_root}/package.json"
cp "${package_root}/extension/payload.txt" "${installed_root}/payload.txt"
cp "${package_root}/extension/resources/sample.db" "${installed_root}/resources/sample.db"
cp "${package_root}/extension.vsixmanifest" "${installed_root}/.vsixmanifest"
printf 'runtime-created data\n' > "${installed_root}/allowed-runtime-extra.bin"

"${verifier}" \
  "${test_root}/package.vsix" \
  "${test_root}/extensions" \
  sample.extension \
  1.2.3

printf 'stale transaction data\n' > "${installed_root}/resources/sample.db-wal"
if "${verifier}" \
  "${test_root}/package.vsix" \
  "${test_root}/extensions" \
  sample.extension \
  1.2.3 >/dev/null 2>&1; then
  echo "The installed-payload verifier accepted an unsigned SQLite transaction sidecar." >&2
  exit 1
fi
rm "${installed_root}/resources/sample.db-wal"

printf 'modified payload\n' > "${installed_root}/payload.txt"
if "${verifier}" \
  "${test_root}/package.vsix" \
  "${test_root}/extensions" \
  sample.extension \
  1.2.3 >/dev/null 2>&1; then
  echo "The installed-payload verifier accepted a changed signed package file." >&2
  exit 1
fi

cp "${package_root}/extension/payload.txt" "${installed_root}/payload.txt"
rm "${installed_root}/package.json"
if "${verifier}" \
  "${test_root}/package.vsix" \
  "${test_root}/extensions" \
  sample.extension \
  1.2.3 >/dev/null 2>&1; then
  echo "The installed-payload verifier accepted a missing signed package file." >&2
  exit 1
fi

echo "Installed extension payload checks passed while allowing runtime-created extras."
