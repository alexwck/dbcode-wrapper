#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/source_digest.sh"
source "${REPO_ROOT}/script/lib/release_identity.sh"

output_file="${1:-}"
[[ -n "${output_file}" ]] || {
  echo "Usage: ./script/generate_installed_release_status.sh OUTPUT_FILE" >&2
  exit 2
}

mkdir -p "$(dirname "${output_file}")"
jq -n \
  --argjson build "${RELEASE_BUILD_SPEC}" \
  --argjson extensions "${RELEASE_EXTENSION_SPEC}" \
  --arg source_set_id "$(release_source_set_id)" \
  --arg compatibility_status "${RELEASE_COMPATIBILITY_STATUS}" '
{
  schemaVersion: 1,
  sourceSetId: $source_set_id,
  compatibilityStatus: $compatibility_status,
  profileSchemaVersion: $build.release.profile_schema_version,
  target: {
    platform: $build.target.platform,
    architecture: $build.target.architecture
  },
  host: {
    version: $build.upstream.vscodium.tag,
    publishedAt: $build.upstream.vscodium.published_at,
    releaseNotesUrl: $build.upstream.vscodium.release_notes_url,
    vscodiumCommit: $build.upstream.vscodium.commit,
    codeOssVersion: $build.runtime.code_oss_version,
    codeOssPublishedAt: $build.upstream.code_oss.published_at,
    codeOssReleaseNotesUrl: $build.upstream.code_oss.release_notes_url,
    codeOssCommit: $build.upstream.code_oss.commit
  },
  dbcode: {
    version: $extensions.dbcode.version,
    publishedAt: $extensions.dbcode.published_at,
    releaseNotesUrl: $extensions.dbcode.release_notes_url,
    sha256: $extensions.dbcode.sha256
  }
}' > "${output_file}"

echo "Installed release identity: ${output_file}"
