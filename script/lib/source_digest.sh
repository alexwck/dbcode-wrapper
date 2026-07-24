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
    host/patches/code-oss
}

overlay_digest() {
  digest_source_files host script .codex/environments
}

wrapper_source_digest() {
  digest_source_files \
    host/entitlements \
    host/approved-release-history.json \
    host/extensions \
    host/icon \
    host/profile/settings.json \
    host/dbcode-feature-policy.json \
    script/bootstrap_toolchain.sh \
    script/build_host.sh \
    script/build_icon.sh \
    script/build_icns.py \
    script/check_vscode_engine.cjs \
    script/prepare_source.sh \
    script/sign_host.sh \
    script/setup_local_signing_identity.sh \
    script/verify_local_signing_continuity.sh \
    script/verify_same_mac_release.sh \
    script/generate_manifest.sh \
    script/generate_installed_release_status.sh \
    script/lib/host_config.sh \
    script/lib/local_signing_identity.sh \
    script/lib/source_digest.sh \
    script/lib/release_identity.sh
}

slimming_build_policy_digest() {
  local policy_file="${1:-${REPO_ROOT}/host/slimming-policy.json}"
  jq -S -c '{schema_version, build}' "${policy_file}" |
    shasum -a 256 |
    awk '{print $1}'
}
