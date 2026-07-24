#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

focused_shell_patch="${REPO_ROOT}/host/patches/code-oss/200-final-focused-dbcode-shell.patch"
integration_patch="${REPO_ROOT}/host/patches/code-oss/400-release-profile-and-dbcode-integrations.patch"
focused_patches=("${focused_shell_patch}" "${integration_patch}")
rendered_test="${REPO_ROOT}/host/qa/ticket-03-rendered.cjs"
profile_settings="${REPO_ROOT}/host/profile/settings.json"
manifest_generator="${REPO_ROOT}/script/generate_manifest.sh"
smoke_test="${REPO_ROOT}/script/smoke_host.sh"
proof_test="${REPO_ROOT}/script/proof_dbcode.sh"

jq -e '
  .product.focused_shell.enabled == true and
  .product.focused_shell.automatic_result_layout.wide == "beside" and
  .product.focused_shell.automatic_result_layout.narrow == "below" and
  (.product.focused_shell | has("default_result_location") | not) and
  (.product.focused_shell | has("supported_result_locations") | not) and
  (.product.focused_shell | has("default_results_position") | not) and
  (.product.focused_shell | has("narrow_results_position") | not) and
  .product.focused_shell.narrow_breakpoint == 1050 and
  (.product | has("diagnostic") | not)
' <<<"${RELEASE_PROFILE_SPEC}" >/dev/null

for release_contract in "${manifest_generator}" "${smoke_test}" "${proof_test}"; do
  rg -Fq 'automatic_result_layout' "${release_contract}" || {
    echo "The release contract does not describe automatic result layout: ${release_contract}" >&2
    exit 1
  }
  if rg -Fq 'default_result_location' "${release_contract}" || rg -Fq 'supported_result_locations' "${release_contract}"; then
    echo "The release contract still describes removed manual result-layout metadata: ${release_contract}" >&2
    exit 1
  fi
done

for focused_patch in "${focused_patches[@]}"; do
  [[ -f "${focused_patch}" ]] || {
    echo "Missing focused-shell source patch: ${focused_patch}" >&2
    exit 1
  }
done

for required_shell_simplification in \
  'applyAutomaticResultLocation' \
  'showConnectionsMenu' \
  'showQueriesMenu' \
  'EventHelper.stop(event, true)' \
  'IEditorGroupsService' \
  'GroupsOrder.GRID_APPEARANCE' \
  'cleanupEmptyEditorGroups' \
  'onDidCloseEditor(() => this.scheduleEmptyEditorGroupCleanup(group))' \
  'emptyGroupsPendingCleanup.add(group)' \
  'cleanupAllEmptyGroups' \
  'candidates ?? existingGroups' \
  'existingGroups.includes(group)' \
  'group.isEmpty' \
  'ConfigurationTarget.USER' \
  'activeViewDescriptors' \
  'DBCODE_STREAMS_VIEW' \
  "this.root.dataset.dbcodeWrapperDbcodeState === 'active'" \
  'dbcodeWrapperResultLocationState' \
  'resultLocationUpdateSequence' \
  'enforcePanelOwnership' \
  'isConnectionsHomePanelVisible' \
  'this.viewsService.getVisibleViewContainer(ViewContainerLocation.Panel)' \
  'genericPanel' \
  'dbcode-wrapper-sql-editor-group' \
  'isDbcodeWrapperSqlContextAction' \
  "action.id.startsWith('dbcode.')" \
  'editor.action.clipboardCopyAction' \
  'codicon-split-horizontal'; do
  rg -Fq -- "${required_shell_simplification}" "${focused_patches[@]}" || {
    echo "The final focused-shell seams are missing contract: ${required_shell_simplification}" >&2
    exit 1
  }
done

for required_panel_regression in \
  "page.keyboard.press('Meta+Shift+M')" \
  'A generic panel shortcut displaced Connections Home.' \
  'Connections Home lost ownership of the panel after a generic panel shortcut.'; do
  rg -Fq -- "${required_panel_regression}" "${rendered_test}" || {
    echo "The rendered focused-shell test is missing the generic-panel regression: ${required_panel_regression}" >&2
    exit 1
  }
done

if rg -q '^\+.*ConfigurationTarget\.MEMORY' "${focused_shell_patch}"; then
  echo "The final shell patch still uses a renderer-only memory setting that DBCode cannot observe." >&2
  exit 1
fi

for required_connections_home in \
  'DBCODE_RESULT_LOCATION_SETTING' \
  'ConfigurationTarget.USER' \
  'toggleConnectionsHome' \
  'openConnectionsHome' \
  'ensureConnectionsHomeMaximized' \
  'dbcodeWrapperConnectionsHome' \
  "createButton('database-explorer'" \
  'dbcode-wrapper-connections-home-title' \
  'dbcode-wrapper-connections-home-close' \
  'surfaceOpeningCount > 0' \
  'this.connectionsHomeOpen &&'; do
  rg -Fq -- "${required_connections_home}" "${focused_shell_patch}" || {
    echo "The Connections Home patch is missing contract: ${required_connections_home}" >&2
    exit 1
  }
done

for required_contextual_surface in \
  'DBCODE_WRAPPER_NATIVE_TITLE_ROW_HEIGHT' \
  'dbcodeWrapperActiveSurface' \
  'activeTextEditorLanguageId' \
  '.notifications-toasts' \
  '.title-actions .action-item:has(.action-label.codicon-toolbar-more)'; do
  rg -Fq -- "${required_contextual_surface}" "${focused_shell_patch}" || {
    echo "The contextual-surfaces patch is missing contract: ${required_contextual_surface}" >&2
    exit 1
  }
done

[[ -f "${rendered_test}" ]] || {
  echo "Missing the reproducible rendered focused-shell test." >&2
  exit 1
}

for required_contract in \
  dbcodeWrapperFocusedShell \
  dbcode-wrapper-focused \
  dbcode-wrapper-database-contextbar \
  dbcodeWrapper.openSqlFile \
  dbcode.resultLocation \
  dbcode.connections.view \
  dbcode.tunnels.view \
  dbcode.authProfiles.view \
  dbcode.streams.view \
  dbcode.history.view \
  dbcode.library.view \
  dbcode.account.view \
  dbcode.panelView \
  dbcode.connections.sqlFile \
  workbench.view.extension.dbcodeActivitybarContainer \
  workbench.view.extension.dbcodePanelContainer \
  'IEditorService' \
  'IFileDialogService' \
  'IFileService' \
  'IUserDataProfileService' \
  'IViewDescriptorService' \
  'WorkbenchPhase.AfterRestored' \
  'this.surfaceOpeningCount' \
  "activateByEvent('onLanguage:sql')" \
  'DBCode active' \
  "joinPath(queryFolder, 'scratch.sql')" \
  "extensions: ['sql']" \
  "accelerator: 'CmdOrCtrl+O'" \
  'DBCODE_WRAPPER_TITLEBAR_HEIGHT' \
  'Only SQL query files can be dropped onto the query canvas.' \
  'Parts.BANNER_PART, Parts.PANEL_PART, Parts.STATUSBAR_PART' \
  'this.viewsService.openViewContainer(DBCODE_ACTIVITY_CONTAINER' \
  'this.viewsService.openViewContainer(DBCODE_PANEL_CONTAINER' \
  'visibleContainer?.id === DBCODE_ACTIVITY_CONTAINER'; do
  rg -Fq "${required_contract}" "${focused_patches[@]}" || {
    echo "The focused-shell patch is missing contract: ${required_contract}" >&2
    exit 1
  }
done

for required_refinement in \
  'DBCODE_CONNECTIONS_VIEW' \
  'model.setVisible' \
  'model.visibleViewDescriptors' \
  'DBCODE_WRAPPER_TITLEBAR_HEIGHT'; do
  rg -Fq -- "${required_refinement}" "${focused_shell_patch}" || {
    echo "The Appshot refinement patch is missing contract: ${required_refinement}" >&2
    exit 1
  }
done

for required_visibility_fix in \
  "extensionId=dbcode.dbcode" \
  "purpose=webviewView" \
  'clip-path: none !important'; do
  rg -Fq -- "${required_visibility_fix}" "${focused_shell_patch}" || {
    echo "The Results visibility patch is missing contract: ${required_visibility_fix}" >&2
    exit 1
  }
done

focused_source="${WORK_ROOT}/vscode/src/vs/workbench/contrib/dbcodeWrapper/browser/dbcodeWrapper.contribution.ts"
if [[ -f "${focused_source}" ]] && ! rg -Fq \
  'registerWorkbenchContribution2(DbcodeWrapperFocusedShellContribution.ID, DbcodeWrapperFocusedShellContribution, WorkbenchPhase.AfterRestored);' \
  "${focused_source}"; then
  echo "The prepared focused shell does not register its workbench contribution." >&2
  exit 1
fi

if [[ -f "${focused_source}" ]] && rg -Fq 'const dragHandle =' "${focused_source}"; then
  echo "The final focused shell still creates the global six-dot Results drag handle." >&2
  exit 1
fi

if [[ -f "${focused_source}" ]] && rg -Fq 'dbcode-wrapper-query-context' "${focused_source}"; then
  echo "The final focused shell still renders the redundant Query and editor-name context." >&2
  exit 1
fi

if [[ -f "${focused_source}" ]] && rg -Fq "createButton('maximize-" "${focused_source}"; then
  echo "The final focused shell still puts both maximize controls in the global toolbar." >&2
  exit 1
fi

for removed_result_control in \
  'resultsBesideButton' \
  'resultsBelowButton' \
  "createButton('results-beside'" \
  "createButton('results-below'" \
  'Place new results beside query' \
  'Place new results below query'; do
  if [[ -f "${focused_source}" ]] && rg -Fq "${removed_result_control}" "${focused_source}"; then
    echo "The final focused shell still exposes a removed result-position control: ${removed_result_control}" >&2
    exit 1
  fi
done

for removed_results_panel_contract in \
  'dbcodeWrapperResultsSurface' \
  'dbcode-wrapper-results-drag-surface' \
  "createButton('results-surface'" \
  "createButton('query-surface'" \
  'private async openResults'; do
  if [[ -f "${focused_source}" ]] && rg -Fq "${removed_results_panel_contract}" "${focused_source}"; then
    echo "The final focused shell still owns the removed Results panel contract: ${removed_results_panel_contract}" >&2
    exit 1
  fi
done

focused_css="${WORK_ROOT}/vscode/src/vs/workbench/contrib/dbcodeWrapper/browser/media/dbcodeWrapper.css"
if [[ -f "${focused_css}" ]] && rg -Fq '.dbcode-wrapper-drag-handle' "${focused_css}"; then
  echo "The final focused shell still contains styling for the removed six-dot Results drag handle." >&2
  exit 1
fi

shortcut_count="$(rg --no-filename -F "accelerator: 'CmdOrCtrl+O'" "${focused_patches[@]}" | rg -c '^\+' || true)"
[[ "${shortcut_count}" == "1" ]] || {
  echo "The SQL-file shortcut must have exactly one native menu route." >&2
  exit 1
}

for invented_state in 'SQL workspace' 'DBCode ready'; do
  if rg -Fq "${invented_state}" "${focused_patches[@]}"; then
    echo "The database context bar must not present invented state: ${invented_state}" >&2
    exit 1
  fi
done

if rg -Fq "event.metaKey && !event.shiftKey && key === 'o'" "${focused_patches[@]}" || rg -Fq 'KeyCode.KeyO' "${focused_patches[@]}"; then
  echo "The SQL-file shortcut must use only the native Database menu route, not a second DOM or keybinding handler." >&2
  exit 1
fi

if rg -Fq 'workbench.action.files.openFile' "${focused_patches[@]}"; then
  echo "The production Database menu must not expose the generic file opener." >&2
  exit 1
fi

for rendered_contract in \
  'dbcodeWrapperConnectionsHome' \
  'dbcodeWrapperResultLocation' \
  'dbcodeWrapperResultLocationState' \
  'dbcodeWrapperDrawerViews' \
  'dbcodeWrapperActiveSurface' \
  'getWindowButtonPosition' \
  'sidebarOverflowVisible' \
  'notificationToastStyle' \
  'findDbcodePanelFrame' \
  'Connections Home' \
  'Connections toggles its Home surface closed' \
  'Connections Home actions enter DBCode connection, import, sample, and SQL-file workflows' \
  'captureConnectionCatalogueSnapshot' \
  'unchanged DBCode exposes the complete reviewed New Connection catalogue' \
  'wrapperDatabaseAllowlist: false' \
  'rawLabelsStored: false' \
  'Database Explorer' \
  'Connection tools group Tunnels and Authentication Profiles' \
  'Queries groups History and Library while Account stays on the right' \
  'advancedToolLabels' \
  'removedToolLabels' \
  'openFilteredDbcodeSettings' \
  'DBCode Settings opens with the extension filter and no generic settings navigation' \
  'verifyDbcodeQuickInputTool' \
  'the retained DBCode AI tools open their real provider and API-key workflows' \
  'Show Scratch Files in Finder uses the configured DBCode path without an external URL alert' \
  "the focused Query Builder route opens DBCode's real connection workflow without a duplicate tree shortcut" \
  'the focused tools route opens a real DBCode notebook and executes Python without a duplicate tree shortcut' \
  'Database Explorer keeps the DBCode relationship-diagram action reachable without generic IDE actions' \
  'sidebarVisible' \
  'assertResultsBeside' \
  'assertResultsBelow' \
  'assertNoResultPositionControls' \
  'pinned DBCode context commands remain available' \
  'empty editor groups are cleaned up' \
  'automatic wide and narrow result placement' \
  'without a wrapper Results panel' \
  'automatic result layout resets wide while Database Explorer stays hidden and completed Profile Setup stays closed across relaunch' \
  'reviewMigrationInventory' \
  'DBCode completes CSV source selection, file selection, custom mapping, preview, confirmation, and import' \
  'Profile Setup hands reviewed CSV to DBCode' \
  'Keep this connection deferred' \
  'reviewed migration data is owner-only' \
  'contextual recovery backs up and recreates only the Standalone DBCode Profile after a partial import' \
  'preservedBoundaries' \
  'openSampleActorTable' \
  'visibleLabel' \
  'document.activeElement' \
  'horizontalOverflow' \
  '--use-mock-keychain' \
  "page.on('console'" \
  "page.on('pageerror'"; do
  rg -Fq -- "${rendered_contract}" "${rendered_test}" || {
    echo "The rendered test is missing coverage: ${rendered_contract}" >&2
    exit 1
  }
done

for removed_rendered_contract in \
  'Place new results beside query' \
  'Place new results below query' \
  'result location persists while Database Explorer stays hidden across relaunch'; do
  if rg -Fq -- "${removed_rendered_contract}" "${rendered_test}"; then
    echo "The rendered acceptance flow still exercises a removed result-position control: ${removed_rendered_contract}" >&2
    exit 1
  fi
done

if rg -Uq '\.part\.panel > \.title \{\n[[:space:]]*display: none' "${focused_patches[@]}"; then
  echo "The focused shell must preserve the Results panel title row for layout." >&2
  exit 1
fi

if rg -Fq '.part.panel > .content' "${focused_patches[@]}"; then
  echo "The focused shell must not force the Results content into a collapsed panel." >&2
  exit 1
fi

jq -e '
  ."breadcrumbs.enabled" == false and
	."dbcode.resultLocation" == "beside" and
  ."window.commandCenter" == false and
  ."workbench.layoutControl.enabled" == false and
  ."workbench.activityBar.location" == "hidden" and
  ."git.enabled" == false and
  ."git.openRepositoryInParentFolders" == "never" and
  ."workbench.statusBar.visible" == false and
  (. | has("workbench.panel.defaultLocation") | not) and
  ."workbench.tips.enabled" == false
' "${profile_settings}" >/dev/null

rg -Fq 'patch_plan_validate' "${REPO_ROOT}/script/prepare_source.sh" || {
  echo "Source preparation must validate the maintained patch plan." >&2
  exit 1
}
rg -Fq 'patch_plan_files code-oss' "${REPO_ROOT}/script/prepare_source.sh" || {
  echo "Source preparation must install Code OSS patches in manifest order." >&2
  exit 1
}

if [[ -d "${APP_BUNDLE}" ]]; then
  jq -e '.dbcodeWrapperFocusedShell == true' \
    "${APP_BUNDLE}/Contents/Resources/app/product.json" >/dev/null
fi

echo "Focused-shell contract checks passed."
