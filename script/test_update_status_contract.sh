#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"
source "${REPO_ROOT}/script/lib/approved_release_set.sh"

extension_root="${REPO_ROOT}/host/extensions/dbcode-wrapper-release-status"
extension_manifest="${extension_root}/package.json"
extension_runtime="${extension_root}/extension.js"
status_logic="${extension_root}/release-status.js"
approved_release_contract="${extension_root}/approved-release-set.js"
status_patches=(
  "${REPO_ROOT}/host/patches/code-oss/200-final-focused-dbcode-shell.patch"
  "${REPO_ROOT}/host/patches/code-oss/400-release-profile-and-dbcode-integrations.patch"
)
installed_manifest_generator="${REPO_ROOT}/script/generate_installed_release_status.sh"
approved_history="${REPO_ROOT}/host/approved-release-history.json"
rendered_qa="${REPO_ROOT}/host/qa/focused-shell-rendered.cjs"

for required_file in \
  "${extension_manifest}" \
  "${extension_runtime}" \
  "${status_logic}" \
  "${approved_release_contract}" \
  "${rendered_qa}" \
  "${status_patches[@]}" \
  "${installed_manifest_generator}"; do
  [[ -f "${required_file}" ]] || {
    echo "Missing focused update-status file: ${required_file}" >&2
    exit 1
  }
done

for rendered_cache_contract in \
  'schemaVersion: 2' \
  'vscodium: {' \
  'codeOss: {'; do
  rg -Fq "${rendered_cache_contract}" "${rendered_qa}" || {
    echo "Rendered QA still seeds the obsolete two-feed update cache: ${rendered_cache_contract}" >&2
    exit 1
  }
done

jq -e '
  .publisher == "dbcode-wrapper"
  and .name == "release-status"
  and .main == "./extension.js"
  and (.activationEvents | sort) == [
    "onCommand:dbcodeWrapper.checkForUpdates",
    "onCommand:dbcodeWrapper.getUpdateStatus",
    "onCommand:dbcodeWrapper.reviewUpdates"
  ]
  and ([.contributes.commands[].command] | sort) == [
    "dbcodeWrapper.checkForUpdates",
    "dbcodeWrapper.getUpdateStatus",
    "dbcodeWrapper.reviewUpdates"
  ]
  and all(.contributes.menus.commandPalette[]; .when == "false")
' "${extension_manifest}" >/dev/null || {
  echo "The release-status bridge must stay inside the focused DBCode shell." >&2
  exit 1
}

for official_endpoint in \
  'https://api.github.com/repos/VSCodium/vscodium/releases/latest' \
  'https://api.github.com/repos/microsoft/vscode/releases/latest' \
  'https://open-vsx.org/api/dbcode/dbcode'; do
  rg -Fq "${official_endpoint}" "${status_logic}" || {
    echo "The update checker is missing an official metadata endpoint: ${official_endpoint}" >&2
    exit 1
  }
done

for required_runtime_contract in \
  'release-status-state.json' \
  'installed-release-set.json' \
  'approved-release-sets.json' \
  'Review' \
  'Remind Later' \
  'Skip This Version' \
  'Code OSS runtime' \
  'VSCodium packaging' \
  'A Code OSS runtime, VSCodium packaging, or DBCode update is available.' \
  'DBCode Wrapper never installs updates automatically.' \
  'DBCode Wrapper is never replaced with stock VSCodium' \
  'never installed alone' \
  'Installed ${formatDate(release.installedPublishedAt)}' \
  'Available ${formatDate(release.availablePublishedAt)}' \
  'dbcodeWrapper.applyUpdateStatus' \
  'localApprovedHistoryUri' \
  'loadApprovedReleaseSets' \
  'getStatus(force, false)' \
  'DBCODE_WRAPPER_QA_CAPTURE_RELEASE_LINKS' \
  'rendered-release-link-capture.jsonl' \
  'vscode.env.openExternal' \
  'workspace.fs.rename'; do
  rg -Fq "${required_runtime_contract}" "${extension_runtime}" || {
    echo "The release-status bridge is missing: ${required_runtime_contract}" >&2
    exit 1
  }
done

if rg -n 'installExtension|download|child_process|execFile|spawn\(|app\.quit|reloadWindow|restart' "${extension_runtime}" "${status_logic}"; then
  echo "Update discovery must not install, download, quit, reload, restart, or spawn another process." >&2
  exit 1
fi

for required_shell_contract in \
  'dbcodeWrapper.getUpdateStatus' \
  'dbcodeWrapper.reviewUpdates' \
  'dbcodeWrapper.checkForUpdates' \
  'dbcodeWrapper.applyUpdateStatus' \
  'dbcodeWrapperReleaseStatus' \
  'Ready to install' \
  'Not tested' \
  'vscodium?: { installedVersion: string }' \
  'codeOss?: { installedVersion: string }' \
  'Code OSS {0}, DBCode {1}: current' \
  "createButton('release-status'"; do
  rg -Fq "${required_shell_contract}" "${status_patches[@]}" || {
    echo "The focused shell is missing update-state contract: ${required_shell_contract}" >&2
    exit 1
  }
done

jq -n -e \
  --argjson build "${RELEASE_BUILD_SPEC}" \
  --argjson extensions "${RELEASE_EXTENSION_SPEC}" '
  $build.release.release_set_base_id == (
    "code-oss-" + $build.runtime.code_oss_version
    + "-dbcode-" + $extensions.dbcode.version
  )
  and $build.release.compatibility_status == "candidate"
  and ($build.release.profile_schema_version | type == "number" and . >= 1)
  and ($build.release.validation_issue | type == "string" and length > 0)
  and ($build.upstream.vscodium.published_at | type == "string")
  and ($build.upstream.vscodium.release_notes_url | startswith("https://github.com/VSCodium/vscodium/releases/tag/"))
  and ($build.upstream.code_oss.published_at | type == "string")
  and ($build.upstream.code_oss.release_notes_url | startswith("https://github.com/microsoft/vscode/releases/tag/"))
  and $extensions.dbcode.release_notes_url == ("https://dbcode.io/docs/changelog/" + $extensions.dbcode.version)
' >/dev/null || {
  echo "The release lock must identify the immutable candidate source set and its official notes." >&2
  exit 1
}

if ! approved_release_history_validate "${approved_history}" >/dev/null; then
  echo "Ready candidates must come from complete approved release-set manifests." >&2
  exit 1
fi

for manifest_contract in \
  'schema_version: 6' \
  'release_set_id' \
  'profile_schema_version' \
  'compatibility_status' \
  'packaging_status' \
  'built_in_extension_count' \
  'source_map_file_count' \
  'release_source_snapshot' \
  'compiled_host'; do
  rg -Fq "${manifest_contract}" "${REPO_ROOT}/script/generate_manifest.sh" || {
    echo "The installed build manifest is missing: ${manifest_contract}" >&2
    exit 1
  }
done

rg -Fq 'generate_installed_release_status.sh' "${REPO_ROOT}/script/assemble_host.sh" || {
  echo "The production build must create the runtime release identity." >&2
  exit 1
}
rg -Fq 'approved-release-sets.json' "${REPO_ROOT}/script/assemble_host.sh" || {
  echo "The production build must bundle the local approved-candidate registry." >&2
  exit 1
}

installed_identity="$(mktemp "${TMPDIR:-/tmp}/dbcode-installed-release.XXXXXX")"
trap 'rm -f "${installed_identity}"' EXIT
"${installed_manifest_generator}" "${installed_identity}" >/dev/null
jq -e \
  --arg release_set_base_id "$(jq -er '.release.release_set_base_id' <<<"${RELEASE_BUILD_SPEC}")" \
  --argjson profile_schema_version "$(jq -er '.release.profile_schema_version' <<<"${RELEASE_BUILD_SPEC}")" '
  (.sourceSetId | startswith($release_set_base_id + "-source-"))
  and (.sourceSetId | ltrimstr($release_set_base_id + "-source-") | test("^[0-9a-f]{64}$"))
  and .compatibilityStatus == "candidate"
  and .profileSchemaVersion == $profile_schema_version
  and .target == {platform: "darwin", architecture: "arm64"}
  and (has("releaseSetId") | not)
' "${installed_identity}" >/dev/null || {
  echo "The bundled identity must remain a source-bound candidate until ticket 07 approves an exact artifact." >&2
  exit 1
}

"${NODE_BIN_DIR}/node" --check "${extension_runtime}"
"${NODE_BIN_DIR}/node" --check "${status_logic}"
"${NODE_BIN_DIR}/node" --check "${approved_release_contract}"
"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_approved_release_set.mjs"
"${NODE_BIN_DIR}/node" --test "${REPO_ROOT}/script/test_update_status.mjs"

echo "Focused update-status contracts passed."
