#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/source_digest.sh"

identity_library="${REPO_ROOT}/script/lib/release_identity.sh"
[[ -f "${identity_library}" ]] || {
  echo "Missing release identity library: ${identity_library}" >&2
  exit 1
}
source "${identity_library}"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/dbcode-release-identity.XXXXXX")"
trap 'rm -rf "${test_root}"' EXIT

candidate_lock="${test_root}/candidate.json"
relabeled_lock="${test_root}/relabeled.json"
changed_product_lock="${test_root}/changed-product.json"
slimming_policy="${test_root}/slimming-policy.json"
changed_result_policy="${test_root}/changed-result-policy.json"
changed_build_policy="${test_root}/changed-build-policy.json"
cp "${LOCK_FILE}" "${candidate_lock}"
jq '.release.compatibility_status = "approved" | .release.validation_issue = "different-label"' \
  "${candidate_lock}" > "${relabeled_lock}"
jq '.product.url_scheme = "different-dbcode-wrapper"' \
  "${candidate_lock}" > "${changed_product_lock}"
cp "${REPO_ROOT}/host/slimming-policy.json" "${slimming_policy}"
jq '.result.signed_app.installed_kib += 1' "${slimming_policy}" > "${changed_result_policy}"
jq '.build.ship_source_maps = true' "${slimming_policy}" > "${changed_build_policy}"

candidate_id="$(release_source_set_id "${candidate_lock}")"
relabeled_id="$(release_source_set_id "${relabeled_lock}")"
changed_product_id="$(release_source_set_id "${changed_product_lock}")"

[[ "${candidate_id}" == "${relabeled_id}" ]] || {
  echo "Approval labels must not change the immutable release-set identity." >&2
  exit 1
}
[[ "${candidate_id}" != "${changed_product_id}" ]] || {
  echo "Build-affecting product changes must change the canonical source-set identity." >&2
  exit 1
}
[[ "$(slimming_build_policy_digest "${slimming_policy}")" == "$(slimming_build_policy_digest "${changed_result_policy}")" ]] || {
  echo "Measured size results must not change the immutable release-set identity." >&2
  exit 1
}
[[ "$(slimming_build_policy_digest "${slimming_policy}")" != "$(slimming_build_policy_digest "${changed_build_policy}")" ]] || {
  echo "Build-affecting slimming changes must change the immutable release-set identity." >&2
  exit 1
}
[[ "${candidate_id}" =~ ^code-oss-1\.126\.0-dbcode-1\.36\.2-source-[0-9a-f]{64}$ ]] || {
  echo "Unexpected canonical release-set identity: ${candidate_id}" >&2
  exit 1
}

payload="$(release_source_set_identity_payload "${candidate_lock}")"
jq -e '
  .target == {platform: "darwin", architecture: "arm64"}
  and .profile_schema_version == 1
  and .product.url_scheme == "dbcode-wrapper"
  and .product.document_extensions == ["sql"]
  and .toolchain.node.version == "24.15.0"
  and (.wrapper_source_sha256 | test("^[0-9a-f]{64}$"))
  and (.shell_patch_revision | test("^[0-9a-f]{64}$"))
  and (.slimming_build_policy_sha256 | test("^[0-9a-f]{64}$"))
  and .upstream.vscodium.commit == "4015f2d0191311733aa5dbb2abde8101dce63eef"
  and .upstream.code_oss.commit == "7e7950df89d055b5a378379db9ee14290772148a"
  and .extension.dbcode.version == "1.36.2"
  and (.runtime_extensions | length) == 7
  and all(.runtime_extensions[]; (.vsix_sha256 | test("^[0-9a-f]{64}$")))
' <<<"${payload}" >/dev/null || {
  echo "The canonical release identity is missing immutable compatibility inputs." >&2
  exit 1
}

echo "Canonical release-set identity contracts passed."
