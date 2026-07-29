#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

policy_file="${REPO_ROOT}/host/dbcode-feature-policy.json"
approved_history_file="${REPO_ROOT}/host/approved-release-history.json"
focused_feature_sources=(
  "${REPO_ROOT}/host/patches/code-oss/200-final-focused-dbcode-shell.patch"
  "${REPO_ROOT}/host/patches/code-oss/400-release-profile-and-dbcode-integrations.patch"
  "${REPO_ROOT}/host/code-oss-overlay/src/vs/workbench/contrib/dbcodeWrapper/browser/dbcodeWrapper.contribution.ts"
  "${REPO_ROOT}/host/code-oss-overlay/src/vs/workbench/contrib/dbcodeWrapper/browser/media/dbcodeWrapper.css"
)
catalogue_contract_module="${REPO_ROOT}/host/qa/connection-catalogue-contract.cjs"
rendered_test="${REPO_ROOT}/host/qa/focused-shell-rendered.cjs"
manifest_file=""
dbcode_id="${DBCODE_ID}"
dbcode_version="${DBCODE_VERSION}"
dbcode_engine="${DBCODE_ENGINE}"
expected_contributions_sha256="${DBCODE_CONTRIBUTIONS_SHA256}"
code_oss_version="${CODE_OSS_VERSION}"
code_oss_commit="${CODE_OSS_COMMIT}"
vscodium_version="${VSCODIUM_TAG}"
vscodium_commit="${VSCODIUM_COMMIT}"
policy_approval_status="$(
  jq -er \
    --arg release_status "${RELEASE_COMPATIBILITY_STATUS}" \
    --arg extension_id "${dbcode_id}" \
    --arg extension_version "${dbcode_version}" \
    --arg dbcode_sha256 "${DBCODE_SHA256}" \
    --arg signature_sha256 "${DBCODE_SIGNATURE_ARCHIVE_SHA256}" \
    --arg code_oss_version "${code_oss_version}" \
    --arg code_oss_commit "${code_oss_commit}" \
    --arg vscodium_version "${vscodium_version}" \
    --arg vscodium_commit "${vscodium_commit}" '
    if any(.approved_release_sets[];
      .compatibility_status == "approved" and
      .dbcode.id == $extension_id and
      .dbcode.version == $extension_version and
      .dbcode.vsix_sha256 == $dbcode_sha256 and
      .dbcode.signature_archive_sha256 == $signature_sha256 and
      .host.code_oss_tag == $code_oss_version and
      .host.code_oss_commit == $code_oss_commit and
      .host.vscodium_tag == $vscodium_version and
      .host.vscodium_commit == $vscodium_commit
    ) then "approved" else $release_status end
  ' "${approved_history_file}"
)"

if [[ $# -eq 1 && "${1}" == "--source-only" ]]; then
  :
elif [[ $# -eq 2 && "${1}" == "--manifest" ]]; then
  manifest_file="${2}"
elif [[ $# -ne 0 ]]; then
  echo "Usage: ./script/test_dbcode_feature_contract.sh [--source-only | --manifest <package.json>]" >&2
  exit 2
else
  manifest_file="$(current_user_home)/.dbcode-wrapper/extensions/${dbcode_id}-${dbcode_version}/package.json"
fi

[[ -f "${policy_file}" ]] || {
  echo "Missing the DBCode feature compatibility matrix: ${policy_file}" >&2
  exit 1
}

jq -e \
  --arg extension_id "${dbcode_id}" \
  --arg extension_version "${dbcode_version}" \
  --arg extension_engine "${dbcode_engine}" \
  --arg code_oss_version "${code_oss_version}" \
  --arg code_oss_commit "${code_oss_commit}" \
  --arg vscodium_version "${vscodium_version}" \
  --arg vscodium_commit "${vscodium_commit}" \
  --arg approval_status "${policy_approval_status}" \
  --arg contributions_sha256 "${expected_contributions_sha256}" '
  .schema_version == 2 and
  .approval_status == $approval_status and
  .extension == {
    id: $extension_id,
    version: $extension_version,
    engine: $extension_engine,
    source: "public-package-manifest"
  } and
  .host == {
    code_oss: {version: $code_oss_version, commit: $code_oss_commit},
    vscodium: {version: $vscodium_version, commit: $vscodium_commit}
  } and
  .public_contribution_contract.jq_sorted_compact_contributes_sha256 == $contributions_sha256 and
  .connection_capability_contract.owner == "unchanged-dbcode" and
  .connection_capability_contract.supported_connection_scope == "every item exposed by the exact installed DBCode New Connection catalogue" and
  .connection_capability_contract.preservation_mode == "complete-rendered-catalogue" and
  .connection_capability_contract.wrapper_database_allowlist == false and
  .connection_capability_contract.wrapper_catalogue_transformations == [] and
  .connection_capability_contract.entry_point == {
    command: "dbcode.connections.add",
    route: "Connections Home > New connection",
    ownership: "unchanged-dbcode",
    wrapper_arguments: []
  } and
  .connection_capability_contract.required_focused_routes == [
    "Connections Home",
    "Connections Home > New connection",
    "Connections Home > Import connections",
    "Connection tools > Tunnels",
    "Connection tools > Authentication Profiles",
    "Database Explorer",
    "DBCode-owned connection and database-object actions"
  ] and
  (.connection_capability_contract.catalogue_snapshot as $catalogue |
    $catalogue.source == "rendered-new-connection-picker" and
    $catalogue.extension == ($extension_id + "@" + $extension_version) and
    $catalogue.normalization == "Unicode NFC, collapsed whitespace, case-sensitive code-point sort" and
    $catalogue.section_count >= 10 and
    $catalogue.item_count >= 80 and
    $catalogue.declared_section_item_total == $catalogue.item_count and
    ($catalogue.sorted_label_sha256 | test("^[0-9a-f]{64}$")) and
    ($catalogue.ordered_section_shape_sha256 | test("^[0-9a-f]{64}$")) and
    $catalogue.raw_labels_committed == false
  ) and
  (.connection_capability_contract.change_policy | contains("requires complete release-pair review")) and
  .connection_capability_contract.representative_acceptance_fixtures == [
    "PostgreSQL", "DuckDB", "Parquet", "SQLite sample", "Python notebook"
  ] and
  (.connection_capability_contract.runtime_boundaries | length) == 6 and
  ((.feature_groups[] | select(.id == "data-file-editor") | .prior_compatibility_failure) as $failure |
    $failure.extension == "dbcode.dbcode@1.36.1" and
    $failure.host == "Code OSS 1.126.0" and
    ($failure.message | length) > 80
  ) and
  (.boundary | length) > 40 and
  (.feature_groups | length) >= 10 and
  ([.feature_groups[].id] | length) == ([.feature_groups[].id] | unique | length) and
  all(.feature_groups[];
    (.status == "supported" or .status == "limited" or .status == "requires-validation") and
    (.evidence_levels | length) > 0 and
    (.evidence_levels | length) == (.evidence_levels | unique | length) and
    all(.evidence_levels[];
      . == "declared" or . == "reachable" or . == "rendered" or . == "live"
    ) and
    (.declared_contributions | length) > 0 and
    (.focused_routes | length) > 0 and
    (.evidence | length) > 0
  ) and
  (if .approval_status == "approved"
    then all(.feature_groups[]; .status != "requires-validation")
    else true
  end) and
  ((.feature_groups[] | select(.id == "stored-routine-debugger")) as $debugger |
    $debugger.status == "limited" and
    ($debugger | has("release_gate") | not) and
    ($debugger.validation_boundary | contains("not a deployment gate"))
  ) and
  ([.feature_groups[].id] | index("ai")) == null and
  ([
    "ai-provider-configuration",
    "ai-inline-completion",
    "ai-query-builder",
    "ai-grid",
    "ai-explore",
    "ai-plan-analysis",
    "ai-query-explanations",
    "copilot-tools",
    "mcp-auto-registration",
    "mcp-http-server",
    "ai-inferred-relationships",
    "team-ai-controls"
  ] - [.feature_groups[].id] | length) == 0 and
  ((.feature_groups[] | select(.id == "ai-provider-configuration")) as $ai |
    $ai.status == "supported" and
    $ai.evidence_levels == ["declared", "reachable"] and
    ($ai.evidence | contains("terms-gated")) and
    ($ai.evidence | contains("live model calls"))
  ) and
  ((.feature_groups[] | select(.id == "ai-inline-completion")) as $completion |
    $completion.status == "limited" and
    ($completion.evidence_levels | index("live")) == null
  ) and
  ((.feature_groups[] | select(.id == "copilot-tools")) as $copilot |
    $copilot.status == "limited" and
    ($copilot.evidence | contains("Generic Code OSS Chat"))
  ) and
  ((.feature_groups[] | select(.id == "mcp-auto-registration")) as $mcp_auto |
    $mcp_auto.status == "supported" and
    $mcp_auto.evidence_levels == ["declared", "reachable"] and
    ($mcp_auto.evidence | contains("HTTP server"))
  ) and
  ((.feature_groups[] | select(.id == "mcp-http-server")) as $mcp_http |
    $mcp_http.status == "limited" and
    ($mcp_http.evidence_levels | index("rendered")) == null and
    $mcp_http.focused_routes == ["DBCode Settings > AI > MCP"] and
    ($mcp_http.evidence | contains("only declared")) and
    ($mcp_http.evidence | contains("external client"))
  ) and
  ((.feature_groups[] | select(.id == "ai-inferred-relationships")) as $relationships |
    $relationships.status == "limited" and
    ($relationships.evidence | contains("workspace settings"))
  ) and
  .public_contribution_contract.contribution_keys == [
    "breakpoints",
    "colors",
    "commands",
    "configuration",
    "customEditors",
    "debuggers",
    "icons",
    "keybindings",
    "languageModelTools",
    "languages",
    "mcpServerDefinitionProviders",
    "menus",
    "notebookRenderer",
    "notebooks",
    "submenus",
    "views",
    "viewsContainers",
    "viewsWelcome"
  ] and
  .public_contribution_contract.commands.count == 171 and
  (.public_contribution_contract.commands.sorted_ids_sha256 | test("^[0-9a-f]{64}$")) and
  (.public_contribution_contract.views | length) == 8 and
  (.public_contribution_contract.custom_editor.selector_extensions | length) == 11 and
  (.public_contribution_contract.notebook.renderer == "dbcode-notebook-renderer") and
  .public_contribution_contract.debugger == {
    type: "dbcode",
    label: "%Database Routine Debugger%",
    languages: ["sql"],
    breakpoint_languages: ["sql"],
    command: "dbcode.debug.routine"
  } and
  (.public_contribution_contract.language_model_tools | length) == 12 and
  .public_contribution_contract.mcp_server_definition_providers == ["dbcode"] and
  (.public_contribution_contract.configuration_titles | length) == 11 and
  ([.focused_routes.wrapper_commands[].id] | sort) == [
    "dbcodeWrapper.openDbcodeAiSettings",
    "dbcodeWrapper.openDbcodeSettings",
    "dbcodeWrapper.revealScratchFiles",
    "dbcodeWrapper.startProfileMigration"
  ] and
  ([.focused_routes.dbcode_commands[].id] | sort) == [
    "dbcode.ai.chooseProvider",
    "dbcode.ai.setApiKey",
    "dbcode.connections.import",
    "dbcode.notebook.new",
    "dbcode.queryBuilder.open"
  ] and
  ([.focused_routes.dbcode_commands[].id] | unique | length) == (.focused_routes.dbcode_commands | length) and
  all(.focused_routes.dbcode_commands[]; (.route | length) > 10) and
  ([.focused_routes.contextual_commands[].id] | unique | length) == (.focused_routes.contextual_commands | length) and
  ([.focused_routes.dbcode_owned_item_commands[].id] | unique | length) == (.focused_routes.dbcode_owned_item_commands | length) and
  all(.focused_routes.dbcode_owned_item_commands[]; (.route | length) > 10) and
  .command_exposure_policy.declared_command_count == .public_contribution_contract.commands.count and
  ([.command_exposure_policy.explicitly_unavailable[].id] | sort) == [
    "dbcode.connections.bindFolder",
    "dbcode.library.revealFile",
    "dbcode.watchedFolders.add"
  ] and
  all(.command_exposure_policy.explicitly_unavailable[]; (.enforcement | length) > 30 and (.reason | length) > 30) and
  ([.command_exposure_policy.suppressed_duplicates[].id] | sort) == [
    "dbcode.notebook.new",
    "dbcode.queryBuilder.open"
  ] and
  all(.command_exposure_policy.suppressed_duplicates[]; (.retained_route | length) > 20 and (.suppressed_route | length) > 20 and (.reason | length) > 30) and
  (.intentional_limits | length) >= 4 and
  all(.intentional_limits[]; (.reason | length) > 40 and (.fallback | length) > 20)
' "${policy_file}" >/dev/null || {
  echo "The DBCode feature compatibility matrix is incomplete or does not match the locked release set." >&2
  exit 1
}

expected_command_ids_sha256="$(jq -er '.public_contribution_contract.commands.sorted_ids_sha256' "${policy_file}")"

for required_catalogue_source in "${catalogue_contract_module}" "${rendered_test}"; do
  [[ -f "${required_catalogue_source}" ]] || {
    echo "Missing the complete DBCode connection-catalogue gate: ${required_catalogue_source}" >&2
    exit 1
  }
done

for required_catalogue_contract in \
  'createConnectionCatalogueSnapshot' \
  'verifyConnectionCatalogueSnapshot' \
  'captureConnectionCatalogueSnapshot' \
  'unchanged DBCode exposes the reviewed New Connection catalogue' \
  'connection-catalogue-rendered-report.json' \
  'rawLabelsStored: false'; do
  rg -Fq -- "${required_catalogue_contract}" "${catalogue_contract_module}" "${rendered_test}" || {
    echo "The complete DBCode connection-catalogue gate is missing: ${required_catalogue_contract}" >&2
    exit 1
  }
done

if rg -Fq -- 'dbcode.connections.add' "${focused_feature_sources[@]}" "${REPO_ROOT}/host/extensions"; then
  echo "The wrapper must not intercept DBCode's owned New Connection command or pass it a database allowlist." >&2
  exit 1
fi

for focused_feature_source in "${focused_feature_sources[@]}"; do
  [[ -f "${focused_feature_source}" ]] || {
    echo "Missing the focused feature source: ${focused_feature_source}" >&2
    exit 1
  }
done

for required_route in \
  'dbcodeWrapper.openDbcodeSettings' \
  'dbcodeWrapper.openDbcodeAiSettings' \
  'dbcodeWrapper.revealScratchFiles' \
  'dbcode.scratchFiles.path' \
  'INativeHostService' \
  'showItemInFolder' \
  '@ext:dbcode.dbcode' \
  "createButton('tools'" \
  'showDbcodeToolsMenu' \
  'dbcode.notebook.new' \
  'dbcode.queryBuilder.open' \
  'dbcode.ai.chooseProvider' \
  'dbcode.ai.setApiKey' \
  '@ext:dbcode.dbcode custom model' \
  'DBCODE_WRAPPER_HIDDEN_TREE_ACTIONS' \
  'dbcode.library.revealFile' \
  'settings-editor > .settings-header' \
  'settings-toc-wrapper' \
  'split-view-view:has(.settings-tree-container)' \
  'product.dbcodeWrapperFocusedShell'; do
  rg -Fq -- "${required_route}" "${focused_feature_sources[@]}" || {
    echo "The focused-shell sources are missing route contract: ${required_route}" >&2
    exit 1
  }
done

for removed_duplicate_or_broken_route in \
  'dbcodeWrapper.openDataFile' \
  'dbcodeWrapper.dataFileEditorUnavailable' \
  'dbcode.ai.changeModel' \
  'dbcode.mcp.start' \
  'dbcode.mcp.stop' \
  'dbcode.mcp.oauth.revokeTokens' \
  'dbcode.scratchFiles.openFolder'; do
  if rg -Fq -- "${removed_duplicate_or_broken_route}" "${focused_feature_sources[@]}"; then
    echo "The focused shell still exposes a broken or duplicate advanced route: ${removed_duplicate_or_broken_route}" >&2
    exit 1
  fi
done

if rg -Fq 'workbench.action.files.openFile' "${focused_feature_sources[@]}"; then
  echo "The data-file route must not expose the generic file opener." >&2
  exit 1
fi

if [[ -n "${manifest_file}" ]]; then
  [[ -f "${manifest_file}" ]] || {
    echo "Missing DBCode public package manifest: ${manifest_file}" >&2
    exit 1
  }

  actual_contributions_sha256="$(jq -S -c '.contributes' "${manifest_file}" | shasum -a 256 | awk '{print $1}')"
  [[ "${actual_contributions_sha256}" == "${expected_contributions_sha256}" ]] || {
    echo "DBCode ${dbcode_version} public contributions do not match the locked canonical digest." >&2
    exit 1
  }

  jq -e --slurpfile policy "${policy_file}" '
    def sorted: sort;
    def filename_patterns: map(.filenamePattern | ltrimstr("*.")) | sorted;
    . as $manifest |
    $policy[0] as $expected |
    (($manifest.publisher + "." + $manifest.name) == $expected.extension.id) and
    ($manifest.version == $expected.extension.version) and
    ($manifest.engines.vscode == $expected.extension.engine) and
    (($manifest.contributes | keys | sorted) == $expected.public_contribution_contract.contribution_keys) and
    (($manifest.contributes.commands | length) == $expected.public_contribution_contract.commands.count) and
    (($manifest.contributes.commands | length) == $expected.command_exposure_policy.declared_command_count) and
    (($manifest.contributes.commands | map(.command) | index($expected.connection_capability_contract.entry_point.command)) != null) and
    ([$manifest.contributes.menus["view/title"][]? | select(.command == $expected.connection_capability_contract.entry_point.command and (.when | contains("dbcode.connections.view")))] | length) == 1 and
    ([$manifest.contributes.views[][] | .id] | sorted) == ($expected.public_contribution_contract.views | sorted) and
    (($manifest.contributes.customEditors | map(select(.viewType == $expected.public_contribution_contract.custom_editor.view_type)) | length) == 1) and
    (($manifest.contributes.customEditors[] | select(.viewType == $expected.public_contribution_contract.custom_editor.view_type) | .selector | filename_patterns) == ($expected.public_contribution_contract.custom_editor.selector_extensions | sorted)) and
    (($manifest.contributes.notebooks | map(select(.type == $expected.public_contribution_contract.notebook.type)) | length) == 1) and
    (($manifest.contributes.notebooks[] | select(.type == $expected.public_contribution_contract.notebook.type) | .selector | filename_patterns) == ($expected.public_contribution_contract.notebook.selector_extensions | sorted)) and
    (($manifest.contributes.notebookRenderer | map(.id) | sorted) == [$expected.public_contribution_contract.notebook.renderer]) and
    (($manifest.contributes.breakpoints | map(.language) | sorted) == ($expected.public_contribution_contract.debugger.breakpoint_languages | sorted)) and
    ([$manifest.contributes.debuggers[] |
      select(
        .type == $expected.public_contribution_contract.debugger.type and
        .label == $expected.public_contribution_contract.debugger.label and
        ((.languages | sorted) == ($expected.public_contribution_contract.debugger.languages | sorted))
      )
    ] | length) == 1 and
    (($manifest.contributes.languageModelTools | map(.name) | sorted) == ($expected.public_contribution_contract.language_model_tools | sorted)) and
    (($manifest.contributes.mcpServerDefinitionProviders | map(.id) | sorted) == ($expected.public_contribution_contract.mcp_server_definition_providers | sorted)) and
    (($manifest.contributes.configuration | map(.title) | sorted) == ($expected.public_contribution_contract.configuration_titles | sorted)) and
    (($expected.public_contribution_contract.required_configuration_keys - ([
      $manifest.contributes.configuration[]?.properties? | keys[]
    ] | unique | sorted)) | length) == 0 and
    ([
      $expected.focused_routes.dbcode_commands[].id,
      $expected.focused_routes.contextual_commands[].id,
      $expected.focused_routes.dbcode_owned_item_commands[].id
    ] | unique - ($manifest.contributes.commands | map(.command) | unique) | length) == 0 and
    ([
      $expected.focused_routes.contextual_commands[].id
    ] | unique - ([
      $manifest.contributes.menus["view/item/context"][]?.command,
      $manifest.contributes.menus["editor/context"][]?.command,
      $manifest.contributes.menus["notebook/toolbar"][]?.command,
      $manifest.contributes.menus["notebook/cell/execute"][]?.command
    ] | map(select(. != null)) | unique) | length) == 0
  ' "${manifest_file}" >/dev/null || {
    echo "DBCode ${dbcode_version} public contributions no longer match the reviewed compatibility matrix." >&2
    exit 1
  }

  actual_command_ids_sha256="$(jq -r '.contributes.commands[].command' "${manifest_file}" | LC_ALL=C sort | shasum -a 256 | awk '{print $1}')"
  [[ "${actual_command_ids_sha256}" == "${expected_command_ids_sha256}" ]] || {
    echo "DBCode ${dbcode_version} command IDs no longer match the reviewed compatibility matrix." >&2
    exit 1
  }
fi

echo "DBCode advanced-feature compatibility contract checks passed."
