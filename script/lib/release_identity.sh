#!/usr/bin/env bash

set -euo pipefail

release_source_set_identity_payload() {
  local release_lock="${1:-${LOCK_FILE}}"
  local wrapper_source_sha256 shell_patch_revision slimming_build_policy_sha256

  wrapper_source_sha256="$(wrapper_source_digest)"
  shell_patch_revision="$(shell_patch_digest)"
  slimming_build_policy_sha256="$(slimming_build_policy_digest)"
  release_specification_record identity "${release_lock}" | jq -S -c \
    --arg wrapper_source_sha256 "${wrapper_source_sha256}" \
    --arg shell_patch_revision "${shell_patch_revision}" \
    --arg slimming_build_policy_sha256 "${slimming_build_policy_sha256}" '
      . + {
        wrapper_source_sha256: $wrapper_source_sha256,
        shell_patch_revision: $shell_patch_revision,
        slimming_build_policy_sha256: $slimming_build_policy_sha256
      }
    '
}

release_source_set_id() {
  local release_lock="${1:-${LOCK_FILE}}"
  local base_id identity_sha256

  base_id="$(release_specification_record build "${release_lock}" | jq -er '.release.release_set_base_id')"
  identity_sha256="$(release_source_set_identity_payload "${release_lock}" | shasum -a 256 | awk '{print $1}')"
  printf '%s-source-%s\n' "${base_id}" "${identity_sha256}"
}
