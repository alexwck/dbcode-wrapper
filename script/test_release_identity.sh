#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/source_digest.sh"

identity_library="${REPO_ROOT}/script/lib/release_identity.sh"
source_digest_library="${REPO_ROOT}/script/lib/source_digest.sh"
[[ -f "${identity_library}" ]] || {
  echo "Missing release identity library: ${identity_library}" >&2
  exit 1
}
source "${identity_library}"

rg -Fq 'script/generate_profile_identity.sh' "${source_digest_library}" || {
  echo "Profile identity generation must be part of the immutable wrapper source digest." >&2
  exit 1
}
rg -Fq 'script/verify_openvsx_package.cjs' "${source_digest_library}" || {
  echo "Open VSX package verification must be part of the immutable wrapper source digest." >&2
  exit 1
}
rg -Fq 'script/runtime_extension_set.cjs' "${source_digest_library}" || {
  echo "The production Runtime Extension Set must be part of the immutable wrapper source digest." >&2
  exit 1
}

test_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-release-identity.XXXXXX")"
trap 'rm -rf "${test_root}"' EXIT

candidate_lock="${test_root}/candidate.json"
relabeled_lock="${test_root}/relabeled.json"
changed_product_lock="${test_root}/changed-product.json"
slimming_policy="${test_root}/slimming-policy.json"
changed_evidence_policy="${test_root}/changed-evidence-policy.json"
changed_build_policy="${test_root}/changed-build-policy.json"
cp "${LOCK_FILE}" "${candidate_lock}"
jq '.release.compatibility_status = "approved" | .release.validation_issue = "different-label"' \
  "${candidate_lock}" > "${relabeled_lock}"
jq '.product.url_scheme = "different-dbcode-wrapper"' \
  "${candidate_lock}" > "${changed_product_lock}"
cp "${REPO_ROOT}/host/slimming-policy.json" "${slimming_policy}"
jq '.measurement_evidence = "docs/architecture/different-measurement.md"' \
  "${slimming_policy}" > "${changed_evidence_policy}"
jq '.build.ship_source_maps = true' "${slimming_policy}" > "${changed_build_policy}"

candidate_id="$(release_source_set_id "${candidate_lock}")"
relabeled_id="$(release_source_set_id "${relabeled_lock}")"
changed_product_id="$(release_source_set_id "${changed_product_lock}")"
release_set_base_id="$(jq -er '.release.release_set_base_id' <<<"${RELEASE_BUILD_SPEC}")"

[[ "${candidate_id}" == "${relabeled_id}" ]] || {
  echo "Approval labels must not change the immutable release-set identity." >&2
  exit 1
}
[[ "${candidate_id}" != "${changed_product_id}" ]] || {
  echo "Build-affecting product changes must change the canonical source-set identity." >&2
  exit 1
}
[[ "$(slimming_build_policy_digest "${slimming_policy}")" == "$(slimming_build_policy_digest "${changed_evidence_policy}")" ]] || {
  echo "Historical measurement evidence must not change the immutable release-set identity." >&2
  exit 1
}
[[ "$(slimming_build_policy_digest "${slimming_policy}")" != "$(slimming_build_policy_digest "${changed_build_policy}")" ]] || {
  echo "Build-affecting slimming changes must change the immutable release-set identity." >&2
  exit 1
}
candidate_source_sha="${candidate_id#"${release_set_base_id}-source-"}"
[[ "${candidate_id}" == "${release_set_base_id}-source-${candidate_source_sha}" && "${candidate_source_sha}" =~ ^[0-9a-f]{64}$ ]] || {
  echo "Unexpected canonical release-set identity: ${candidate_id}" >&2
  exit 1
}

echo "Canonical release-set identity contracts passed."
