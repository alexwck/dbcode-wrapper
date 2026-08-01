#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

jq -e '.id == "dbcode.dbcode"' <<<"${DBCODE_PACKAGE_SPEC}" >/dev/null || {
  echo "The Release Specification is missing the locked DBCode package." >&2
  exit 1
}

dbcode_id="${DBCODE_ID}"
dbcode_version="${DBCODE_VERSION}"

[[ "${dbcode_id}" == "dbcode.dbcode" ]] || {
  echo "The release lock must select the official DBCode extension." >&2
  exit 1
}
jq -e \
  --arg dbcode_version "${dbcode_version}" \
  '.extension.id == "dbcode.dbcode" and .extension.version == $dbcode_version' \
  "${REPO_ROOT}/host/dbcode-feature-policy.json" >/dev/null || {
  echo "The DBCode feature policy must match the selected official DBCode package." >&2
  exit 1
}

jq -e '
  .namespace == "dbcode"
  and .name == "dbcode"
  and .publisher == "dbcode"
  and .engine == "^1.95.0"
  and .target_platform == "universal"
  and .verified_publisher == true
  and .pre_release == false
  and .deprecated == false
  and (.published_at | type == "string")
  and (.registry_api_url | startswith("https://open-vsx.org/api/"))
  and (.download_url | startswith("https://open-vsx.org/api/"))
  and (.signature_url | startswith("https://open-vsx.org/api/"))
  and (.sha256_url | startswith("https://open-vsx.org/api/"))
  and (.public_key_url | startswith("https://open-vsx.org/api/-/public-key/"))
  and (.sha256 | test("^[0-9a-f]{64}$"))
  and (.signature_archive_sha256 | test("^[0-9a-f]{64}$"))
  and (.public_key_sha256 | test("^[0-9a-f]{64}$"))
  and (.package_size > 0)
' <<<"${DBCODE_PACKAGE_SPEC}" >/dev/null

public_key_id="${DBCODE_PUBLIC_KEY_ID}"
public_key="${REPO_ROOT}/host/keys/openvsx-${public_key_id}.pem"
[[ -f "${public_key}" ]] || {
  echo "Missing pinned Open VSX public key: ${public_key}" >&2
  exit 1
}
expected_key_sha="${DBCODE_PUBLIC_KEY_SHA256}"
actual_key_sha="$(shasum -a 256 "${public_key}" | awk '{print $1}')"
[[ "${actual_key_sha}" == "${expected_key_sha}" ]] || {
  echo "The pinned Open VSX public key does not match the release lock." >&2
  exit 1
}

settings_file="${REPO_ROOT}/host/profile/settings.json"
jq -e '
  ."update.mode" == "none"
  and ."extensions.autoCheckUpdates" == false
  and ."extensions.autoUpdate" == false
  and ."extensions.ignoreRecommendations" == true
  and ."security.workspace.trust.enabled" == false
  and ."telemetry.telemetryLevel" == "off"
' "${settings_file}" >/dev/null

for required_script in prepare_dbcode.sh verify_openvsx_package.sh test_profile_paths.sh test_profile_settings.sh test_runtime_extensions_contract.sh test_runtime_extensions_verifier.sh; do
  [[ -x "${REPO_ROOT}/script/${required_script}" ]] || {
    echo "Missing executable DBCode workflow script: script/${required_script}" >&2
    exit 1
  }
done
[[ -f "${REPO_ROOT}/script/verify_openvsx_package.cjs" ]] || {
  echo "Missing Open VSX package verification adapter: script/verify_openvsx_package.cjs" >&2
  exit 1
}

for profile_aware_script in prepare_dbcode.sh run_host.sh; do
  rg -Fq 'profile_paths.sh' "${REPO_ROOT}/script/${profile_aware_script}" || {
    echo "${profile_aware_script} must share the self-launch profile path contract." >&2
    exit 1
  }
done

rg -Fq 'prepare_dbcode.sh' "${REPO_ROOT}/script/run_host.sh" || {
  echo "Normal host launch must prepare the locked runtime-extension set first." >&2
  exit 1
}
rg -Fq -- '--disable-workspace-trust' "${REPO_ROOT}/script/run_host.sh" || {
  echo "The dedicated DBCode host must not leave its only extension disabled in Restricted Mode." >&2
  exit 1
}
if rg -Fq -- '--manual-proof' "${REPO_ROOT}/script/run_host.sh"; then
  echo "The normal host launch still exposes the superseded manual-proof mode." >&2
  exit 1
fi
host_session_contract="${REPO_ROOT}/script/lib/host-session.js"
[[ -f "${host_session_contract}" ]] || {
  echo "Missing Host Session contract: script/lib/host-session.js" >&2
  exit 1
}
rg -Fq 'host_session_' "${REPO_ROOT}/script/run_host.sh" || {
  echo "The normal launch path must use the Host Session contract." >&2
  exit 1
}
rg -Fq 'active-dbcode-log' "${REPO_ROOT}/script/run_host.sh" || {
  echo "The host launch must identify the DBCode log created by the active run." >&2
  exit 1
}

echo "DBCode acquisition and profile contract checks passed."
