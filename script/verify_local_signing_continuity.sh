#!/usr/bin/env bash

set -euo pipefail
umask 077

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_root}/lib/host_config.sh"
source "${script_root}/lib/artifact_digest.sh"
source "${script_root}/lib/local_signing_identity.sh"

usage() {
  echo "Usage: ./script/verify_local_signing_continuity.sh --previous-app APP --previous-manifest FILE --current-app APP --current-manifest FILE --output FILE [--safe-storage-observation pending-manual-rebuild-check|accepted-new-approval-after-distinct-rebuild] [--safe-storage-note TEXT]" >&2
  exit 2
}

previous_app=""
previous_manifest=""
current_app=""
current_manifest=""
output_file=""
safe_storage_observation="pending-manual-rebuild-check"
safe_storage_note=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --previous-app) [[ $# -ge 2 ]] || usage; previous_app="$2"; shift ;;
    --previous-manifest) [[ $# -ge 2 ]] || usage; previous_manifest="$2"; shift ;;
    --current-app) [[ $# -ge 2 ]] || usage; current_app="$2"; shift ;;
    --current-manifest) [[ $# -ge 2 ]] || usage; current_manifest="$2"; shift ;;
    --output) [[ $# -ge 2 ]] || usage; output_file="$2"; shift ;;
    --safe-storage-observation) [[ $# -ge 2 ]] || usage; safe_storage_observation="$2"; shift ;;
    --safe-storage-note) [[ $# -ge 2 ]] || usage; safe_storage_note="$2"; shift ;;
    *) usage ;;
  esac
  shift
done

case "${safe_storage_observation}" in
  pending-manual-rebuild-check)
    [[ -z "${safe_storage_note}" ]] || {
      echo "Do not attach a manual observation note while the Safe Storage check is pending." >&2
      exit 2
    }
    ;;
  accepted-new-approval-after-distinct-rebuild)
    [[ -n "${safe_storage_note}" ]] || {
      echo "The accepted Safe Storage observation requires a clear manual note." >&2
      exit 2
    }
    ;;
  *) usage ;;
esac

[[ -n "${previous_app}" && -n "${previous_manifest}" && -n "${current_app}" && \
  -n "${current_manifest}" && -n "${output_file}" ]] || usage
[[ -d "${previous_app}" && -d "${current_app}" ]] || {
  echo "Both compared application bundles must exist." >&2
  exit 1
}
for manifest_file in "${previous_manifest}" "${current_manifest}"; do
  [[ -f "${manifest_file}" && ! -L "${manifest_file}" ]] || {
    echo "Missing or unsafe build manifest: ${manifest_file}" >&2
    exit 1
  }
done
[[ ! -L "${output_file}" ]] || {
  echo "Refusing a symlinked signing-continuity receipt." >&2
  exit 1
}

load_local_signing_identity
previous_identifier="$(plutil -extract CFBundleIdentifier raw "${previous_app}/Contents/Info.plist")"
current_identifier="$(plutil -extract CFBundleIdentifier raw "${current_app}/Contents/Info.plist")"
[[ "${previous_identifier}" == "${BUNDLE_IDENTIFIER}" && "${current_identifier}" == "${BUNDLE_IDENTIFIER}" ]] || {
  echo "The compared apps do not share the approved DBCode Wrapper bundle identifier." >&2
  exit 1
}
verify_local_signed_code "${previous_app}" "${BUNDLE_IDENTIFIER}"
verify_local_signed_code "${current_app}" "${BUNDLE_IDENTIFIER}"

previous_artifact_sha256="$(artifact_digest "${previous_app}")"
current_artifact_sha256="$(artifact_digest "${current_app}")"
[[ "${previous_artifact_sha256}" != "${current_artifact_sha256}" ]] || {
  echo "Signing continuity must compare two distinct signed app artifacts." >&2
  exit 1
}
[[ "$(jq -er '.artifact.sha256' "${previous_manifest}")" == "${previous_artifact_sha256}" ]] || {
  echo "The previous app does not match its manifest." >&2
  exit 1
}
[[ "$(jq -er '.artifact.sha256' "${current_manifest}")" == "${current_artifact_sha256}" ]] || {
  echo "The current app does not match its manifest." >&2
  exit 1
}

previous_requirement="$(codesign -d -r- "${previous_app}" 2>&1 | sed -n '/^designated => /p')"
current_requirement="$(codesign -d -r- "${current_app}" 2>&1 | sed -n '/^designated => /p')"
expected_requirement="$(local_signing_expected_requirement "${BUNDLE_IDENTIFIER}")"
[[ "${previous_requirement}" == "${expected_requirement}" && \
  "${current_requirement}" == "${expected_requirement}" ]] || {
  echo "The compared app builds do not share the configured designated requirement." >&2
  exit 1
}

for manifest_file in "${previous_manifest}" "${current_manifest}"; do
  jq -e \
    --arg requirement "${expected_requirement}" \
    --arg certificate_sha1 "${LOCAL_SIGNING_CERTIFICATE_SHA1}" \
    --arg certificate_sha256 "${LOCAL_SIGNING_CERTIFICATE_SHA256}" \
    --arg scope "${SIGNING_SCOPE}" '
      .artifact.signature_kind == "certificate"
      and .artifact.signature_requirement == $requirement
      and .artifact.signature_scope == $scope
      and .artifact.signing_certificate_sha1 == $certificate_sha1
      and .artifact.signing_certificate_sha256 == $certificate_sha256
    ' "${manifest_file}" >/dev/null || {
    echo "A compared manifest does not describe the persistent local certificate." >&2
    exit 1
  }
done

mkdir -p "$(dirname "${output_file}")"
output_temp="${output_file}.tmp"
jq -n \
  --arg verified_at_utc "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --arg bundle_identifier "${BUNDLE_IDENTIFIER}" \
  --arg certificate_sha1 "${LOCAL_SIGNING_CERTIFICATE_SHA1}" \
  --arg certificate_sha256 "${LOCAL_SIGNING_CERTIFICATE_SHA256}" \
  --arg designated_requirement "${expected_requirement}" \
  --arg previous_artifact_sha256 "${previous_artifact_sha256}" \
  --arg previous_release_set_id "$(jq -er '.release.release_set_id' "${previous_manifest}")" \
  --arg current_artifact_sha256 "${current_artifact_sha256}" \
  --arg current_release_set_id "$(jq -er '.release.release_set_id' "${current_manifest}")" \
  --arg safe_storage_prompt_observation "${safe_storage_observation}" \
  --arg safe_storage_prompt_note "${safe_storage_note}" '
    {
      schema_version: 1,
      verified_at_utc: $verified_at_utc,
      scope: "current-user-private-use",
      bundle_identifier: $bundle_identifier,
      signing_certificate: {
        sha1: $certificate_sha1,
        sha256: $certificate_sha256
      },
      designated_requirement: $designated_requirement,
      previous: {
        artifact_sha256: $previous_artifact_sha256,
        release_set_id: $previous_release_set_id
      },
      current: {
        artifact_sha256: $current_artifact_sha256,
        release_set_id: $current_release_set_id
      },
      cryptographic_identity_stable: true,
      safe_storage_access_stable_across_rebuilds: (
        if $safe_storage_prompt_observation == "accepted-new-approval-after-distinct-rebuild"
        then false
        else null
        end
      ),
      safe_storage_rebuild_behavior: (
        if $safe_storage_prompt_observation == "accepted-new-approval-after-distinct-rebuild"
        then "manual-approval-may-repeat-after-host-rebuild"
        else "pending-manual-rebuild-observation"
        end
      ),
      safe_storage_prompt_observation: $safe_storage_prompt_observation,
      safe_storage_prompt_note: $safe_storage_prompt_note,
      safe_storage_observed_at_utc: (
        if $safe_storage_prompt_observation == "accepted-new-approval-after-distinct-rebuild"
        then $verified_at_utc
        else null
        end
      ),
      distribution_claims: {
        developer_id: false,
        notarized: false,
        public_distribution_ready: false
      }
    }
  ' > "${output_temp}"
chmod 600 "${output_temp}"
mv "${output_temp}" "${output_file}"

echo "Persistent local-signing continuity verified: ${output_file}"
