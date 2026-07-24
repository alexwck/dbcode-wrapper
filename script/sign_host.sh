#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/local_signing_identity.sh"

require_command codesign
require_command file
require_command plutil
require_command xattr
load_local_signing_identity

sign_target="${1:-${APP_BUNDLE}}"
if [[ ! -d "${sign_target}" || "${sign_target}" != *.app ]]; then
  echo "Expected a macOS application bundle, got: ${sign_target}" >&2
  exit 1
fi

app_entitlements="${REPO_ROOT}/host/entitlements/app.plist"
helper_entitlements="${REPO_ROOT}/host/entitlements/helper.plist"
plugin_entitlements="${REPO_ROOT}/host/entitlements/helper-plugin.plist"
target_bundle_identifier="$(plutil -extract CFBundleIdentifier raw "${sign_target}/Contents/Info.plist")"
development_requirement="=designated => anchor H\"${LOCAL_SIGNING_CERTIFICATE_SHA1}\" and identifier \"${target_bundle_identifier}\""
expected_requirement="$(local_signing_expected_requirement "${target_bundle_identifier}")"
signing_args=(
  --force
  --keychain "${LOCAL_SIGNING_KEYCHAIN}"
  --sign "${LOCAL_SIGNING_IDENTITY}"
  --timestamp=none
)

xattr -cr "${sign_target}"

while IFS= read -r code_file; do
  if file -b "${code_file}" | grep -q 'Mach-O'; then
    codesign "${signing_args[@]}" "${code_file}"
  fi
done < <(
  find "${sign_target}/Contents" -type f -print |
    awk -F/ '{print NF "\t" $0}' |
    sort -rn |
    cut -f2-
)

while IFS= read -r nested_bundle; do
  nested_name="$(basename "${nested_bundle}")"
  if [[ "${nested_bundle}" == *.framework ]]; then
    codesign "${signing_args[@]}" "${nested_bundle}"
  elif [[ "${nested_name}" == *"Helper (Plugin).app"* ]]; then
    codesign "${signing_args[@]}" --options runtime --entitlements "${plugin_entitlements}" "${nested_bundle}"
  else
    codesign "${signing_args[@]}" --options runtime --entitlements "${helper_entitlements}" "${nested_bundle}"
  fi
done < <(
  find "${sign_target}/Contents" -depth -type d \( -name '*.framework' -o -name '*.xpc' -o -name '*.app' \) -print
)

codesign \
  "${signing_args[@]}" \
  --options runtime \
  --requirements "${development_requirement}" \
  --entitlements "${app_entitlements}" \
  "${sign_target}"
codesign --verify --deep --strict --verbose=2 "${sign_target}"
verify_local_signed_code "${sign_target}" "${target_bundle_identifier}"

actual_requirement="$(codesign -d -r- "${sign_target}" 2>&1 | sed -n '/^designated => /p')"
[[ "${actual_requirement}" == "${expected_requirement}" ]] || {
  echo "The app does not have the expected persistent local-signing requirement." >&2
  echo "Expected: ${expected_requirement}" >&2
  echo "Actual:   ${actual_requirement}" >&2
  exit 1
}

echo "Persistent current-user local signature verified: ${sign_target}"
