#!/usr/bin/env bash

set -euo pipefail

digest_source_files() {
  (
    cd "${REPO_ROOT}"
    find "$@" -type f ! -name '.DS_Store' -print0 2>/dev/null |
      LC_ALL=C sort -z |
      xargs -0 shasum -a 256
  ) | shasum -a 256 | awk '{print $1}'
}

shell_patch_digest() {
  digest_source_files \
    host/patches/patch-plan.json \
    host/patches/vscodium \
    host/patches/code-oss \
    host/code-oss-overlay
}

wrapper_source_digest() {
  digest_source_files \
    host/entitlements \
    host/approved-release-history.json \
    host/extensions \
    host/icon \
    host/profile/settings.json \
    host/dbcode-feature-policy.json \
    script/assemble_host.sh \
    script/bootstrap_toolchain.sh \
    script/build_host.sh \
    script/compile_host.sh \
    script/build_icon.sh \
    script/build_icns.py \
    script/check_vscode_engine.cjs \
    script/materialize_code_oss_overlay.sh \
    script/verify_openvsx_package.cjs \
    script/verify_openvsx_package.sh \
    script/prepare_source.sh \
    script/sign_host.sh \
    script/setup_local_signing_identity.sh \
    script/generate_manifest.sh \
    script/generate_installed_release_status.sh \
    script/generate_profile_identity.sh \
    script/generate_runtime_setup_manifest.sh \
    script/lib/artifact_digest.sh \
    script/lib/compiled_host_cache.sh \
    script/lib/dist_checkpoint.sh \
    script/lib/generated_workspace.sh \
    script/lib/host_config.sh \
    script/lib/local_signing_identity.sh \
    script/lib/patch_plan.sh \
    script/lib/release_source_snapshot.sh \
    script/lib/release_specification.sh \
    script/lib/source_cache.sh \
    script/lib/source_digest.sh \
    script/lib/release_identity.sh
}

slimming_build_policy_digest() {
  local policy_file="${1:-${REPO_ROOT}/host/slimming-policy.json}"
  jq -S -c '{schema_version, build}' "${policy_file}" |
    shasum -a 256 |
    awk '{print $1}'
}
