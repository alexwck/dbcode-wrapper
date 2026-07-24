#!/usr/bin/env bash

if [[ "${DBCODE_WRAPPER_PRIVATE_RELEASE_GUIDE_LIBRARY_LOADED:-}" == "yes" ]]; then
  return 0 2>/dev/null || exit 0
fi
DBCODE_WRAPPER_PRIVATE_RELEASE_GUIDE_LIBRARY_LOADED="yes"

private_release_write_install_guide() {
  local output_file="$1"
  local release_set_id="$2"
  local code_oss_version="$3"
  local dbcode_version="$4"

  printf '%s\n' \
    'DBCode Wrapper — Private Personal Release' \
    '' \
    'This host is for Macs owned by the licence holder. It is not a public application release.' \
    'DBCode is not included and must be installed separately from its official distribution.' \
    '' \
    "Approved release set: ${release_set_id}" \
    "Compatible host: Code OSS ${code_oss_version}" \
    "Compatible DBCode: ${dbcode_version}" \
    '' \
    'Install' \
    '1. Verify the published SHA-256 before opening this disk image.' \
    '2. Drag DBCode Wrapper.app into Applications.' \
    '3. Try one normal launch.' \
    '4. If macOS blocks it, use System Settings > Privacy & Security > Open Anyway.' \
    '5. Do not disable Gatekeeper and do not remove quarantine automatically.' \
    '6. Use the focused first-run setup to obtain and verify the exact DBCode and Python/Jupyter packages from Open VSX.' \
    '7. Enter the DBCode licence and protected database credentials on this Mac.' \
    '' \
    'Trust boundary' \
    'This app is self-signed. Apple has neither identified nor notarized it.' \
    'A distinct host build may need one new Safe Storage approval.' \
    'An unchanged approved app must not repeat that approval after Always Allow.' \
    '' \
    'Rollback' \
    'Quit DBCode Wrapper completely, then restore the previous complete Approved Release Set.' \
    'Do not mix an old host with a new extension profile unless that exact pair passed the compatibility matrix.' \
    > "${output_file}"
}
