#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/profile_settings.sh"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-wrapper-profile-settings.XXXXXX")"
cleanup_test_root() {
  rm -rf "${test_root}"
}
trap cleanup_test_root EXIT INT TERM

settings_file="${test_root}/settings.json"
jq -n '{
  "extensions.autoUpdate": "off",
  "dbcode.connections": [{"name": "preserve-me"}],
  "dbcode.resultLocation": "below"
}' > "${settings_file}"

apply_managed_profile_settings "${settings_file}" "${REPO_ROOT}/host/profile/settings.json"

jq -e '
  ."extensions.autoUpdate" == false
  and ."security.workspace.trust.enabled" == false
  and ."dbcode.connections" == [{"name": "preserve-me"}]
  and ."dbcode.resultLocation" == "below"
' "${settings_file}" >/dev/null

echo "Managed host settings are enforced without removing DBCode connection settings."
