#!/usr/bin/env bash

set -euo pipefail

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
verifier="${script_root}/verify_same_mac_release.sh"
continuity_verifier="${script_root}/verify_local_signing_continuity.sh"

[[ -x "${verifier}" ]] || {
  echo "Missing executable same-Mac release verifier: ${verifier}" >&2
  exit 1
}

for required_option in \
  --app \
  --manifest \
  --release-lock \
  --profile-root \
  --proof \
  --continuity \
  --matrix \
  --health \
  --rollback \
  --rendered-report \
  --development-log \
  --smoke-log \
  --output; do
  rg -Fq -- "${required_option}" "${verifier}" || {
    echo "The same-Mac verifier is missing ${required_option}." >&2
    exit 1
  }
done

rg -Fq 'verify_local_signed_code' "${verifier}"
rg -Fq 'artifact_digest' "${verifier}"
rg -Fq 'accepted-new-approval-after-distinct-rebuild' "${verifier}"
rg -Fq 'manual-approval-may-repeat-after-host-rebuild' "${verifier}"
rg -Fq 'current-user-private-use' "${verifier}"
rg -Fq 'public_distribution_ready: false' "${verifier}"
rg -Fq 'developer_id: false' "${verifier}"
rg -Fq 'notarized: false' "${verifier}"
rg -Fq 'failures: []' "${verifier}"
rg -Fq 'waivers: []' "${verifier}"
rg -Fq '.manual_checks.credential_reentry' "${verifier}"
rg -Fq '.manual_checks.update_discovery' "${verifier}"
rg -Fq '.approved_release_set.host.candidate_manifest_sha256 == $manifest_sha256' "${verifier}"
rg -Fq '.build_manifest_sha256 == $manifest_sha256' "${verifier}"
rg -Fq '.details.runtime.hyphen_path_preflight == "not-required"' "${verifier}"
rg -Fq 'unchanged DBCode exposes the complete reviewed New Connection catalogue' "${verifier}"
rg -Fq '.connection_capability_contract.catalogue_snapshot' "${verifier}"
rg -Fq '.wrapperDatabaseAllowlist == false' "${verifier}"

rg -Fq -- '--safe-storage-observation' "${continuity_verifier}"
rg -Fq 'accepted-new-approval-after-distinct-rebuild' "${continuity_verifier}"

if rg -Fq 'passed-no-repeat-after-distinct-rebuild' "${verifier}" || \
  rg -Fq 'passed-no-repeat-after-distinct-rebuild' "${continuity_verifier}"; then
  echo "The unpaid release must not claim prompt-free Safe Storage across rebuilt hosts." >&2
  exit 1
fi

if rg -q 'public_distribution_ready: true|developer_id: true|notarized: true' "${verifier}"; then
  echo "The same-Mac release verifier must not claim public distribution readiness." >&2
  exit 1
fi

echo "Same-Mac release acceptance contracts passed."
