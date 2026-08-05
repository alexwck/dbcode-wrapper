#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/host_config.sh"

focused_shell_patch="${REPO_ROOT}/host/patches/code-oss/200-final-focused-dbcode-shell.patch"
integration_patch="${REPO_ROOT}/host/patches/code-oss/400-release-profile-and-dbcode-integrations.patch"
focused_shell_typescript="${REPO_ROOT}/host/code-oss-overlay/src/vs/workbench/contrib/dbcodeWrapper/browser/dbcodeWrapper.contribution.ts"
focused_drawer_navigation="${REPO_ROOT}/host/code-oss-overlay/src/vs/workbench/contrib/dbcodeWrapper/browser/dbcodeWrapperDrawerNavigation.ts"
focused_shell_styles="${REPO_ROOT}/host/code-oss-overlay/src/vs/workbench/contrib/dbcodeWrapper/browser/media/dbcodeWrapper.css"
focused_sources=(
  "${focused_shell_patch}"
  "${integration_patch}"
  "${focused_shell_typescript}"
  "${focused_drawer_navigation}"
  "${focused_shell_styles}"
)
transport_patches=("${focused_shell_patch}" "${integration_patch}")
rendered_test="${REPO_ROOT}/host/qa/focused-shell-rendered.cjs"
profile_settings="${REPO_ROOT}/host/profile/settings.json"
manifest_generator="${REPO_ROOT}/script/generate_manifest.sh"
smoke_test="${REPO_ROOT}/script/smoke_host.sh"
extension_host_log_policy_test="${REPO_ROOT}/host/qa/extension-host-log-policy.test.cjs"
rendered_session_support_test="${REPO_ROOT}/host/qa/rendered-session-support.test.cjs"
focused_workspace_navigation_test="${REPO_ROOT}/script/test_focused_workspace_navigation.mjs"

jq -e '
  .product.focused_shell.enabled == true and
  .product.focused_shell.result_location == "below" and
  .product.focused_shell.narrow_breakpoint == 1050
' <<<"${RELEASE_PROFILE_SPEC}" >/dev/null

for release_contract in "${manifest_generator}" "${smoke_test}"; do
  rg -Fq 'result_location' "${release_contract}" || {
    echo "The release contract does not describe the DBCode result location: ${release_contract}" >&2
    exit 1
  }
done

for focused_source_file in "${focused_sources[@]}"; do
  [[ -f "${focused_source_file}" ]] || {
    echo "Missing focused-shell source: ${focused_source_file}" >&2
    exit 1
  }
done

for required_shell_simplification in \
  'applyDefaultResultLocation' \
  'showConnectionsMenu' \
  'showQueriesMenu' \
  'EventHelper.stop(event, true)' \
  'IEditorGroupsService' \
  'GroupsOrder.GRID_APPEARANCE' \
  'cleanupEmptyEditorGroups' \
  'onDidCloseEditor(() => this.scheduleEmptyEditorGroupCleanup(group))' \
  'emptyGroupsPendingCleanup.add(group)' \
  'cleanupAllEmptyGroups' \
  'dbcodeWrapperStorageNamespace' \
  'dbcodeWrapperQueryFolderName' \
  'candidates ?? existingGroups' \
  'existingGroups.includes(group)' \
  'group.isEmpty' \
  'ConfigurationTarget.USER' \
  'activeViewDescriptors' \
  'DBCODE_STREAMS_VIEW' \
  'decideDbcodeDrawerTransition' \
  'isPersistentDbcodeDrawerView' \
  'enforcePanelOwnership' \
  'isConnectionsHomePanelVisible' \
  'this.viewsService.getVisibleViewContainer(ViewContainerLocation.Panel)' \
  'genericPanel' \
  'dbcode-wrapper-sql-editor-group' \
  'isDbcodeWrapperSqlContextAction' \
  "action.id.startsWith('dbcode.')" \
  'editor.action.clipboardCopyAction' \
  'codicon-split-horizontal'; do
  rg -Fq -- "${required_shell_simplification}" "${focused_sources[@]}" || {
    echo "The final focused-shell seams are missing contract: ${required_shell_simplification}" >&2
    exit 1
  }
done

for required_bottom_result_contract in \
  'applyDefaultResultLocation()' \
  "updateValue(DBCODE_RESULT_LOCATION_SETTING, 'below', ConfigurationTarget.USER)"; do
  rg -Fq -- "${required_bottom_result_contract}" "${focused_shell_typescript}" || {
    echo "The focused shell does not keep new DBCode results below the query: ${required_bottom_result_contract}" >&2
    exit 1
  }
done

if rg -Fq "joinPath(this.userDataProfileService.currentProfile.globalStorageHome, 'dbcode-wrapper', 'queries')" "${focused_shell_typescript}"; then
  echo "The focused shell must not duplicate the Release Specification query storage identity." >&2
  exit 1
fi

for required_quick_input_regression in \
  'assertExpandedQuickInputAboveDatabaseToolbar' \
  'assertQuickInputDismissesOnOutsideClick' \
  'The release status picker' \
  'quickInputOwnsOverlap' \
  'quickInputZIndex' \
  'toolbarZIndex'; do
  rg -Fq -- "${required_quick_input_regression}" "${rendered_test}" || {
    echo "The rendered focused-shell test is missing the quick-input overlap regression: ${required_quick_input_regression}" >&2
    exit 1
  }
done

for required_transient_surface_contract in \
  'IQuickInputService' \
  'IContextViewService' \
  'IWebviewService' \
  'closeTransientSurfacesFromPointer' \
  'closeTransientSurfacesFromFocus' \
  'closeTransientSurfacesFromWebviewFocus' \
  'refreshWebviewDismissLayers' \
  'scheduleWebviewDismissLayerRefresh' \
  'webviewDismissLayers' \
  'webviewDismissLayerRefresh' \
  'dbcode-wrapper-webview-dismiss-layer' \
  'this.root.append(layer)' \
  '.editor-group-container > .editor-container' \
  'this.quickInputService.cancel()' \
  'this.contextViewService.hideContextView(true)' \
  'this.contextMenuService.onDidShowContextMenu' \
  'this.quickInputService.onShow' \
  'this.webviewService.onDidChangeActiveWebview' \
  "addDisposableListener(mainWindow.document, 'pointerdown'" \
  "addDisposableListener(mainWindow.document, 'focusin'" \
  'isDrawerToggleEvent' \
  'hasVisibleTransientOverlay' \
  'HTMLIFrameElement' \
  'closeDbcodeDrawer' \
  "{ kind: 'dismiss' }" \
  'event.composedPath()'; do
  rg -Fq -- "${required_transient_surface_contract}" "${focused_sources[@]}" || {
    echo "The focused shell does not dismiss transient surfaces consistently: ${required_transient_surface_contract}" >&2
    exit 1
  }
done

focused_drawer_persistence_contract="$(
  sed -n \
    '/export function isPersistentDbcodeDrawerView(viewId: string | undefined): boolean {/,/^}/p' \
    "${focused_drawer_navigation}"
)"
for required_persistent_drawer_contract in \
  'return Boolean(viewId && viewId !== DBCODE_DRAWER_VIEWS.account);'; do
  rg -Fq -- "${required_persistent_drawer_contract}" <<<"${focused_drawer_persistence_contract}" || {
    echo "The focused shell does not keep every non-Account DBCode drawer persistent: ${required_persistent_drawer_contract}" >&2
    exit 1
  }
done

for required_drawer_route_toggle in \
  "this.toggleDrawer(DBCODE_CONNECTIONS_VIEW)" \
  "this.toggleDrawer(DBCODE_TUNNELS_VIEW)" \
  "this.toggleDrawer(DBCODE_AUTH_PROFILES_VIEW)" \
  "this.toggleDrawer(DBCODE_STREAMS_VIEW)" \
  "this.toggleDrawer(DBCODE_HISTORY_VIEW)" \
  "this.toggleDrawer(DBCODE_LIBRARY_VIEW)"; do
  rg -Fq -- "${required_drawer_route_toggle}" "${focused_shell_typescript}" || {
    echo "A persistent DBCode route cannot collapse and restore its own drawer: ${required_drawer_route_toggle}" >&2
    exit 1
  }
done

for redundant_drawer_control in \
  "createButton('drawer-toggle'" \
  'togglePersistentDrawer' \
  'lastPersistentDrawerView' \
  'drawerToggleButton' \
  '"Collapse drawer"' \
  '"Expand drawer"'; do
  if rg -Fq -- "${redundant_drawer_control}" "${focused_shell_typescript}"; then
    echo "The focused shell still exposes the redundant shared drawer control: ${redundant_drawer_control}" >&2
    exit 1
  fi
done

focused_keydown_contract="$(
  sed -n \
    '/private handleKeydown(event: KeyboardEvent): void {/,/private blockKey(event: KeyboardEvent): void {/p' \
    "${focused_shell_typescript}"
)"
for required_persistent_drawer_keydown_contract in \
  'const activeDrawerView = this.activeDrawerView();' \
  'decideDbcodeDrawerTransition(' \
  "{ kind: 'dismiss' }" \
  "transition.kind === 'close'"; do
  rg -Fq -- "${required_persistent_drawer_keydown_contract}" <<<"${focused_keydown_contract}" || {
    echo "Escape still closes a persistent DBCode drawer: ${required_persistent_drawer_keydown_contract}" >&2
    exit 1
  }
done

for required_quick_input_layer in \
  '--dbcode-wrapper-quick-input-z-index' \
  '.monaco-workbench.dbcode-wrapper-focused .quick-input-widget' \
  'z-index: var(--dbcode-wrapper-quick-input-z-index);'; do
  rg -Fq -- "${required_quick_input_layer}" "${focused_shell_styles}" || {
    echo "The focused shell does not keep expanded quick inputs above the database toolbar: ${required_quick_input_layer}" >&2
    exit 1
  }
done

if ! rg -Uq '\.monaco-workbench\.dbcode-wrapper-focused \.part\.titlebar \.command-center \{\n[[:space:]]*display: none !important;' "${focused_shell_styles}"; then
  echo "The focused shell does not hard-hide the generic Code OSS title-bar command center." >&2
  exit 1
fi

if rg -Fq "toAction({ id: 'dbcodeWrapper.connectionsHome'" "${focused_shell_typescript}"; then
  echo "The connection-tools menu still duplicates the primary Connections route." >&2
  exit 1
fi

for required_ai_configuration_route in \
  'OPEN_DBCODE_AI_SETTINGS_COMMAND' \
  '@ext:dbcode.dbcode custom model' \
  'AI: Configure Custom Model…' \
  'AI: Set Custom Model API Key…'; do
  rg -Fq -- "${required_ai_configuration_route}" "${focused_shell_typescript}" || {
    echo "The focused DBCode tools menu does not explain the supported AI-provider setup: ${required_ai_configuration_route}" >&2
    exit 1
  }
done

if rg -q 'ConfigurationTarget\.MEMORY' "${focused_shell_typescript}"; then
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
  rg -Fq -- "${required_connections_home}" "${focused_shell_typescript}" || {
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
  rg -Fq -- "${required_contextual_surface}" "${focused_sources[@]}" || {
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
  dbcodeWrapper.openBsonResultFromClipboard \
  dbcodeWrapper.openBsonResultFromFile \
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
  rg -Fq "${required_contract}" "${focused_sources[@]}" || {
    echo "The focused-shell patch is missing contract: ${required_contract}" >&2
    exit 1
  }
done

for required_refinement in \
  'DBCODE_CONNECTIONS_VIEW' \
  'model.setVisible' \
  'model.visibleViewDescriptors' \
  'DBCODE_WRAPPER_TITLEBAR_HEIGHT'; do
  rg -Fq -- "${required_refinement}" "${focused_sources[@]}" || {
    echo "The Appshot refinement patch is missing contract: ${required_refinement}" >&2
    exit 1
  }
done

for required_visibility_fix in \
  "extensionId=dbcode.dbcode" \
  "purpose=webviewView" \
  'clip-path: none !important'; do
  rg -Fq -- "${required_visibility_fix}" "${focused_sources[@]}" || {
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

focused_css="${WORK_ROOT}/vscode/src/vs/workbench/contrib/dbcodeWrapper/browser/media/dbcodeWrapper.css"
shortcut_count="$(rg --no-filename -F "accelerator: 'CmdOrCtrl+O'" "${transport_patches[@]}" | rg -c '^\+' || true)"
[[ "${shortcut_count}" == "1" ]] || {
  echo "The SQL-file shortcut must have exactly one native menu route." >&2
  exit 1
}

for invented_state in 'SQL workspace' 'DBCode ready'; do
  if rg -Fq "${invented_state}" "${focused_sources[@]}"; then
    echo "The database context bar must not present invented state: ${invented_state}" >&2
    exit 1
  fi
done

if rg -Fq "event.metaKey && !event.shiftKey && key === 'o'" "${focused_sources[@]}" || rg -Fq 'KeyCode.KeyO' "${focused_sources[@]}"; then
  echo "The SQL-file shortcut must use only the native Database menu route, not a second DOM or keybinding handler." >&2
  exit 1
fi

if rg -Fq 'workbench.action.files.openFile' "${focused_sources[@]}"; then
  echo "The production Database menu must not expose the generic file opener." >&2
  exit 1
fi

for rendered_contract in \
  'dbcodeWrapperConnectionsHome' \
  'qaProfileLayout.paths.state' \
  'persistent: true' \
  "'--disable-extension', 'dbcode-wrapper.profile-migration'" \
  'preparePersistentQaSettings' \
  'captureLogOffsets' \
  'scanCurrentExtensionHostLogs' \
  'findDbcodePanelFrame' \
  'Connections Home' \
  'Connections Home owns the main canvas without opening Terminal' \
  'Database Explorer remains persistent across outside click and Escape' \
  'History and Library remain persistent and their own actions collapse and restore the drawer' \
  'Account remains temporary and closes on outside click or Escape' \
  'captureConnectionCatalogueSnapshot' \
  'unchanged DBCode exposes the reviewed New Connection catalogue' \
  'wrapperDatabaseAllowlist: false' \
  'rawLabelsStored: false' \
  'advancedToolLabels' \
  'policyExcludedToolLabels' \
  'DBCode AI provider, custom-model, and API-key routes remain reachable without sending data' \
  'modelCallMade: false' \
  'secretEntered: false' \
  'Query Builder remains reachable from DBCode Tools' \
  'the DBCode notebook route remains reachable without starting a kernel' \
  'kernelStarted: false' \
  'permissionPromptExpected: false' \
  'DBCode Settings remains reachable from DBCode Tools without activating it' \
  'verifyBsonResultViewerRoute' \
  'BSON Result Viewer renders readable values, separate types, and plain JSON without a database' \
  'networkUsed: false' \
  'clipboardRead: false' \
  'the release status quick input stays above the toolbar and closes on outside click' \
  'Open SQL File renders the deterministic query without executing it' \
  'databaseRead: false' \
  'databaseWrite: false' \
  '--use-mock-keychain' \
  "page.on('console'" \
  "page.on('pageerror'"; do
  rg -Fq -- "${rendered_contract}" "${rendered_test}" || {
    echo "The rendered test is missing coverage: ${rendered_contract}" >&2
    exit 1
  }
done

if rg -Uq '\.part\.panel > \.title \{\n[[:space:]]*display: none' "${focused_shell_styles}"; then
  echo "The focused shell must preserve the Results panel title row for layout." >&2
  exit 1
fi

if rg -Fq '.part.panel > .content' "${focused_shell_styles}"; then
  echo "The focused shell must not force the Results content into a collapsed panel." >&2
  exit 1
fi

jq -e '
  ."breadcrumbs.enabled" == false and
	."dbcode.resultLocation" == "below" and
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

"${NODE_BIN_DIR}/node" "${extension_host_log_policy_test}"
"${NODE_BIN_DIR}/node" --test "${rendered_session_support_test}"
"${NODE_BIN_DIR}/node" --experimental-strip-types --test "${focused_workspace_navigation_test}"

echo "Focused-shell contract checks passed."
