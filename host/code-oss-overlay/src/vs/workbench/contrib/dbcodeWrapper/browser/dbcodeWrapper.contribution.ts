/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import './media/dbcodeWrapper.css';
import { addDisposableListener, EventHelper } from '../../../../base/browser/dom.js';
import { mainWindow } from '../../../../base/browser/window.js';
import { Separator, toAction } from '../../../../base/common/actions.js';
import { INativeHostService } from '../../../../platform/native/common/native.js';
import { IPathService } from '../../../services/path/common/pathService.js';
import { disposableTimeout } from '../../../../base/common/async.js';
import { Disposable, DisposableStore, MutableDisposable } from '../../../../base/common/lifecycle.js';
import { joinPath } from '../../../../base/common/resources.js';
import { localize } from '../../../../nls.js';
import { CommandsRegistry, ICommandService } from '../../../../platform/commands/common/commands.js';
import { ConfigurationTarget, IConfigurationService } from '../../../../platform/configuration/common/configuration.js';
import { IContextMenuService, IContextViewService } from '../../../../platform/contextview/browser/contextView.js';
import { IFileDialogService } from '../../../../platform/dialogs/common/dialogs.js';
import { IFileService } from '../../../../platform/files/common/files.js';
import { INotificationService } from '../../../../platform/notification/common/notification.js';
import product from '../../../../platform/product/common/product.js';
import { IQuickInputService } from '../../../../platform/quickinput/common/quickInput.js';
import { IWorkbenchContribution, registerWorkbenchContribution2, WorkbenchPhase } from '../../../common/contributions.js';
import { IViewDescriptorService, ViewContainerLocation } from '../../../common/views.js';
import { IWebviewService } from '../../webview/browser/webview.js';
import { GroupsOrder, IEditorGroup, IEditorGroupsService } from '../../../services/editor/common/editorGroupsService.js';
import { IEditorService } from '../../../services/editor/common/editorService.js';
import { IExtensionService } from '../../../services/extensions/common/extensions.js';
import { IWorkbenchLayoutService, Parts } from '../../../services/layout/browser/layoutService.js';
import { IUserDataProfileService } from '../../../services/userDataProfile/common/userDataProfile.js';
import { IViewsService } from '../../../services/views/common/viewsService.js';
import {
	DBCODE_DRAWER_VIEWS,
	decideDbcodeDrawerTransition,
	isPersistentDbcodeDrawerView,
	type DbcodeDrawerTransition,
	type DbcodeDrawerViewId
} from './dbcodeWrapperDrawerNavigation.js';

const DBCODE_ACTIVITY_CONTAINER = 'workbench.view.extension.dbcodeActivitybarContainer';
const DBCODE_CONNECTIONS_VIEW = DBCODE_DRAWER_VIEWS.connections;
const DBCODE_TUNNELS_VIEW = DBCODE_DRAWER_VIEWS.tunnels;
const DBCODE_AUTH_PROFILES_VIEW = DBCODE_DRAWER_VIEWS.authProfiles;
const DBCODE_STREAMS_VIEW = DBCODE_DRAWER_VIEWS.streams;
const DBCODE_HISTORY_VIEW = DBCODE_DRAWER_VIEWS.history;
const DBCODE_LIBRARY_VIEW = DBCODE_DRAWER_VIEWS.library;
const DBCODE_ACCOUNT_VIEW = DBCODE_DRAWER_VIEWS.account;
const DBCODE_PANEL_CONTAINER = 'workbench.view.extension.dbcodePanelContainer';
const DBCODE_PANEL_VIEW = 'dbcode.panelView';
const DBCODE_RESULT_LOCATION_SETTING = 'dbcode.resultLocation';
const OPEN_SQL_FILE_COMMAND = 'dbcodeWrapper.openSqlFile';
const OPEN_DBCODE_SETTINGS_COMMAND = 'dbcodeWrapper.openDbcodeSettings';
const OPEN_DBCODE_AI_SETTINGS_COMMAND = 'dbcodeWrapper.openDbcodeAiSettings';
const OPEN_BSON_RESULT_FROM_CLIPBOARD_COMMAND = 'dbcodeWrapper.openBsonResultFromClipboard';
const OPEN_BSON_RESULT_FROM_FILE_COMMAND = 'dbcodeWrapper.openBsonResultFromFile';
const REVEAL_SCRATCH_FILES_COMMAND = 'dbcodeWrapper.revealScratchFiles';
const GET_UPDATE_STATUS_COMMAND = 'dbcodeWrapper.getUpdateStatus';
const REVIEW_UPDATES_COMMAND = 'dbcodeWrapper.reviewUpdates';
const CHECK_FOR_UPDATES_COMMAND = 'dbcodeWrapper.checkForUpdates';
const APPLY_UPDATE_STATUS_COMMAND = 'dbcodeWrapper.applyUpdateStatus';

interface DbcodeWrapperReleaseStatus {
	kind: 'current' | 'update-available' | 'offline' | 'invalid';
	updatesAvailable: boolean;
	readyToInstall: boolean;
	vscodium?: { installedVersion: string };
	codeOss?: { installedVersion: string };
	dbcode?: { installedVersion: string };
}

if (product.dbcodeWrapperFocusedShell) {
	CommandsRegistry.registerCommand(OPEN_SQL_FILE_COMMAND, async accessor => {
		const fileDialogService = accessor.get(IFileDialogService);
		const editorService = accessor.get(IEditorService);
		const resources = await fileDialogService.showOpenDialog({
			title: localize('dbcodeWrapper.openSqlFile', "Open SQL File"),
			openLabel: localize('dbcodeWrapper.openSqlFileButton', "Open Query"),
			canSelectFiles: true,
			canSelectFolders: false,
			canSelectMany: true,
			filters: [{
				name: localize('dbcodeWrapper.sqlFiles', "SQL query files"),
				extensions: ['sql']
			}]
		});
		if (resources?.length) {
			await editorService.openEditors(resources.map(resource => ({
				resource,
				options: { pinned: true, preserveFocus: false }
			})));
		}
	});

	CommandsRegistry.registerCommand(OPEN_DBCODE_SETTINGS_COMMAND, accessor =>
		accessor.get(ICommandService).executeCommand('workbench.action.openSettings', '@ext:dbcode.dbcode')
	);

	CommandsRegistry.registerCommand(OPEN_DBCODE_AI_SETTINGS_COMMAND, accessor =>
		accessor.get(ICommandService).executeCommand('workbench.action.openSettings', '@ext:dbcode.dbcode custom model')
	);

	CommandsRegistry.registerCommand(REVEAL_SCRATCH_FILES_COMMAND, async accessor => {
		const configurationService = accessor.get(IConfigurationService);
		const fileService = accessor.get(IFileService);
		const nativeHostService = accessor.get(INativeHostService);
		const notificationService = accessor.get(INotificationService);
		const pathService = accessor.get(IPathService);
		const configuredPath = configurationService.getValue<string>('dbcode.scratchFiles.path')?.trim() || '~/.dbcode/scratch';
		const userHome = pathService.userHome({ preferLocal: true });
		let scratchFolder = userHome;
		if (configuredPath.startsWith('~/')) {
			scratchFolder = joinPath(userHome, configuredPath.slice(2));
		} else if (configuredPath !== '~') {
			const pathModule = await pathService.path;
			if (!pathModule.isAbsolute(configuredPath)) {
				notificationService.error(localize('dbcodeWrapper.scratchPathInvalid', "DBCode's Scratch Files path must be absolute or start with ~/ before it can be shown in Finder."));
				return;
			}
			scratchFolder = await pathService.fileURI(configuredPath);
		}
		await fileService.createFolder(scratchFolder);
		await nativeHostService.showItemInFolder(scratchFolder.fsPath);
	});
}

export class DbcodeWrapperFocusedShellContribution extends Disposable implements IWorkbenchContribution {

	static readonly ID = 'workbench.contrib.dbcodeWrapperFocusedShell';

	private readonly root!: HTMLElement;
	private readonly narrowBreakpoint = product.dbcodeWrapperFocusedShellNarrowBreakpoint ?? 1050;
	private surfaceOpeningCount = 0;
	private connectionsHomeOpen = false;
	private connectionsHomeTitle: HTMLElement | undefined;
	private connectionsHomeCloseButton: HTMLButtonElement | undefined;
	private connectionsButton: HTMLButtonElement | undefined;
	private databaseExplorerButton: HTMLButtonElement | undefined;
	private dbcodeExtensionStatus: HTMLElement | undefined;
	private releaseStatusButton: HTMLButtonElement | undefined;
	private readonly emptyGroupCleanup = this._register(new MutableDisposable());
	private readonly webviewDismissLayers = this._register(new MutableDisposable<DisposableStore>());
	private readonly webviewDismissLayerRefresh = this._register(new MutableDisposable());
	private readonly emptyGroupsPendingCleanup = new Set<IEditorGroup>();
	private cleanupAllEmptyGroups = false;

	constructor(
		@IWorkbenchLayoutService private readonly layoutService: IWorkbenchLayoutService,
		@IViewDescriptorService private readonly viewDescriptorService: IViewDescriptorService,
		@IViewsService private readonly viewsService: IViewsService,
		@ICommandService private readonly commandService: ICommandService,
		@IConfigurationService private readonly configurationService: IConfigurationService,
		@IContextMenuService private readonly contextMenuService: IContextMenuService,
		@IContextViewService private readonly contextViewService: IContextViewService,
		@IWebviewService private readonly webviewService: IWebviewService,
		@IFileService private readonly fileService: IFileService,
		@IExtensionService private readonly extensionService: IExtensionService,
		@IUserDataProfileService private readonly userDataProfileService: IUserDataProfileService,
		@INotificationService private readonly notificationService: INotificationService,
		@IQuickInputService private readonly quickInputService: IQuickInputService,
		@IEditorGroupsService private readonly editorGroupsService: IEditorGroupsService,
		@IEditorService private readonly editorService: IEditorService
	) {
		super();

		if (!product.dbcodeWrapperFocusedShell) {
			return;
		}

		this.root = this.layoutService.mainContainer;
		this.root.classList.add('dbcode-wrapper-focused');
		this._register(CommandsRegistry.registerCommand(APPLY_UPDATE_STATUS_COMMAND, (_accessor, status: DbcodeWrapperReleaseStatus | undefined) => this.applyReleaseStatus(status)));

		this.root.dataset.dbcodeWrapperShell = 'focused';

		this.lockProductionPresentation();
		this.installToolbar();
		this.registerListeners();
		this.registerEditorGroupCleanup();
		this.applyResponsiveLayout(this.layoutService.mainContainerDimension.width);
		this.updateControlState();
		void this.restoreDbcodeSurface();
	}

	private lockProductionPresentation(): void {
		for (const part of [Parts.ACTIVITYBAR_PART, Parts.AUXILIARYBAR_PART, Parts.BANNER_PART, Parts.PANEL_PART, Parts.STATUSBAR_PART]) {
			this.layoutService.setPartHidden(true, part);
		}

		this.layoutService.setPartHidden(true, Parts.SIDEBAR_PART);

		this.layoutService.setPanelAlignment('center');
	}

	private installToolbar(): void {
		const titlebar = this.layoutService.getContainer(mainWindow, Parts.TITLEBAR_PART);
		const center = titlebar?.querySelector<HTMLElement>('.titlebar-center');
		if (!center || center.querySelector('.dbcode-wrapper-toolbar')) {
			return;
		}

		const toolbar = mainWindow.document.createElement('nav');
		toolbar.className = 'dbcode-wrapper-toolbar dbcode-wrapper-database-contextbar';
		toolbar.setAttribute('aria-label', localize('dbcodeWrapper.toolbar', "DBCode workspace controls"));
		center.append(toolbar);

		const databaseActions = mainWindow.document.createElement('span');
		databaseActions.className = 'dbcode-wrapper-toolbar-group database-actions';
		toolbar.append(databaseActions);

		this.connectionsButton = this.createButton('connections', localize('dbcodeWrapper.connections', "Connections"), 'database', true, () => this.toggleConnectionsHome());
		databaseActions.append(this.connectionsButton);
		databaseActions.append(this.createButton('connection-tools', localize('dbcodeWrapper.connectionTools', "Connection tools"), 'chevron-down', false, button => this.showConnectionsMenu(button)));
		this.databaseExplorerButton = this.createButton('database-explorer', localize('dbcodeWrapper.databaseExplorer', "Database Explorer"), 'list-tree', false, () => this.toggleDrawer(DBCODE_CONNECTIONS_VIEW));
		databaseActions.append(this.databaseExplorerButton);
		databaseActions.append(this.createButton('open-sql', localize('dbcodeWrapper.openSqlFile', "Open SQL"), 'folder-opened', true, () => this.runOutsideConnectionsHome(() => this.commandService.executeCommand(OPEN_SQL_FILE_COMMAND))));
		databaseActions.append(this.createButton('new-query', localize('dbcodeWrapper.newQuery', "New query"), 'new-file', true, () => this.runOutsideConnectionsHome(() => this.commandService.executeCommand('dbcode.connections.sqlFile'))));
		databaseActions.append(this.createButton('queries', localize('dbcodeWrapper.queries', "Queries"), 'library', true, button => this.showQueriesMenu(button)));
		databaseActions.append(this.createButton('tools', localize('dbcodeWrapper.dbcodeTools', "DBCode tools"), 'tools', true, button => this.showDbcodeToolsMenu(button)));

		const divider = mainWindow.document.createElement('span');
		divider.className = 'dbcode-wrapper-toolbar-divider';
		divider.setAttribute('aria-hidden', 'true');
		toolbar.append(divider);

		const extensionState = mainWindow.document.createElement('span');
		extensionState.className = 'dbcode-wrapper-extension-state starting';
		extensionState.append(this.createIcon('circle-filled'));
		this.dbcodeExtensionStatus = mainWindow.document.createElement('span');
		this.dbcodeExtensionStatus.textContent = localize('dbcodeWrapper.starting', "DBCode starting");
		extensionState.append(this.dbcodeExtensionStatus);
		toolbar.append(extensionState);
		this.releaseStatusButton = this.createButton('release-status', localize('dbcodeWrapper.checkingUpdates', "Checking for updates"), 'sync', false, () => this.commandService.executeCommand(REVIEW_UPDATES_COMMAND));
		this.releaseStatusButton.dataset.dbcodeWrapperReleaseStatus = 'checking';
		toolbar.append(this.releaseStatusButton);
		this.root.dataset.dbcodeWrapperDbcodeState = 'starting';
		this.updateActiveEditorState();
		toolbar.append(this.createButton('account', localize('dbcodeWrapper.account', "Account"), 'account', false, () => this.toggleDrawer(DBCODE_ACCOUNT_VIEW)));
	}

	private createIcon(name: string): HTMLElement {
		const icon = mainWindow.document.createElement('span');
		icon.className = `codicon codicon-${name}`;
		icon.setAttribute('aria-hidden', 'true');
		return icon;
	}

	private createButton(action: string, label: string, icon: string, showLabel: boolean, handler: (button: HTMLButtonElement) => void | Promise<unknown>): HTMLButtonElement {
		const button = mainWindow.document.createElement('button');
		button.className = 'dbcode-wrapper-toolbar-button';
		button.type = 'button';
		button.dataset.dbcodeWrapperAction = action;
		button.title = label;
		button.setAttribute('aria-label', label);
		button.append(this.createIcon(icon));
		if (showLabel) {
			const text = mainWindow.document.createElement('span');
			text.className = 'dbcode-wrapper-button-label';
			text.textContent = label;
			button.append(text);
		}
		this._register(addDisposableListener(button, 'click', event => {
			EventHelper.stop(event, true);
			void handler(button);
		}));
		return button;
	}

	private showConnectionsMenu(anchor: HTMLElement): void {
		const actions = [
			toAction({ id: 'dbcodeWrapper.tunnels', label: localize('dbcodeWrapper.tunnels', "Tunnels"), run: () => this.toggleDrawer(DBCODE_TUNNELS_VIEW) }),
			toAction({ id: 'dbcodeWrapper.authenticationProfiles', label: localize('dbcodeWrapper.authenticationProfiles', "Authentication Profiles"), run: () => this.toggleDrawer(DBCODE_AUTH_PROFILES_VIEW) }),
			new Separator(),
			toAction({ id: 'dbcodeWrapper.profileSetup', label: localize('dbcodeWrapper.profileSetup', "Profile Setup…"), run: () => this.executeDbcodeCommand('dbcodeWrapper.startProfileMigration') })
		];
		const streamsViewContainer = this.viewDescriptorService.getViewContainerByViewId(DBCODE_STREAMS_VIEW);
		if (streamsViewContainer && this.viewDescriptorService.getViewContainerModel(streamsViewContainer).activeViewDescriptors.some(descriptor => descriptor.id === DBCODE_STREAMS_VIEW)) {
			actions.push(toAction({ id: 'dbcodeWrapper.activeStreams', label: localize('dbcodeWrapper.activeStreams', "Active Streams"), run: () => this.toggleDrawer(DBCODE_STREAMS_VIEW) }));
		}
		this.contextMenuService.showContextMenu({
			getAnchor: () => anchor,
			getActions: () => actions
		});
	}

	private showQueriesMenu(anchor: HTMLElement): void {
		this.contextMenuService.showContextMenu({
			getAnchor: () => anchor,
			getActions: () => [
				toAction({ id: 'dbcodeWrapper.history', label: localize('dbcodeWrapper.history', "History"), run: () => this.toggleDrawer(DBCODE_HISTORY_VIEW) }),
				toAction({ id: 'dbcodeWrapper.library', label: localize('dbcodeWrapper.library', "Library"), run: () => this.toggleDrawer(DBCODE_LIBRARY_VIEW) })
			]
		});
	}

	private showDbcodeToolsMenu(anchor: HTMLElement): void {
		this.contextMenuService.showContextMenu({
			getAnchor: () => anchor,
			getActions: () => [
				toAction({ id: 'dbcodeWrapper.notebook', label: localize('dbcodeWrapper.notebook', "New DBCode Notebook"), run: () => this.executeDbcodeCommand('dbcode.notebook.new') }),
				toAction({ id: 'dbcodeWrapper.pythonKernel', label: localize('dbcodeWrapper.pythonKernel', "Start Python Kernel…"), run: () => this.executeDbcodeCommand('dbcodeWrapper.startPythonKernel') }),
				toAction({ id: 'dbcodeWrapper.queryBuilder', label: localize('dbcodeWrapper.queryBuilder', "Query Builder"), run: () => this.executeDbcodeCommand('dbcode.queryBuilder.open') }),
				new Separator(),
				toAction({ id: 'dbcodeWrapper.openBsonResultFromClipboard', label: localize('dbcodeWrapper.openBsonResultFromClipboard', "Open Copied BSON Result"), run: () => this.executeDbcodeCommand(OPEN_BSON_RESULT_FROM_CLIPBOARD_COMMAND) }),
				toAction({ id: 'dbcodeWrapper.openBsonResultFromFile', label: localize('dbcodeWrapper.openBsonResultFromFile', "Open BSON Result File…"), run: () => this.executeDbcodeCommand(OPEN_BSON_RESULT_FROM_FILE_COMMAND) }),
				new Separator(),
				toAction({ id: 'dbcodeWrapper.settings', label: localize('dbcodeWrapper.settings', "DBCode Settings…"), run: () => this.executeDbcodeCommand(OPEN_DBCODE_SETTINGS_COMMAND) }),
				toAction({ id: 'dbcodeWrapper.checkForUpdates', label: localize('dbcodeWrapper.checkForUpdates', "Check for Updates…"), run: () => this.checkForUpdates() }),
				new Separator(),
				toAction({ id: 'dbcodeWrapper.aiProvider', label: localize('dbcodeWrapper.aiProvider', "AI: Choose Provider"), run: () => this.executeDbcodeCommand('dbcode.ai.chooseProvider') }),
				toAction({ id: 'dbcodeWrapper.aiCustomModel', label: localize('dbcodeWrapper.aiCustomModel', "AI: Configure Custom Model…"), run: () => this.executeDbcodeCommand(OPEN_DBCODE_AI_SETTINGS_COMMAND) }),
				toAction({ id: 'dbcodeWrapper.aiApiKey', label: localize('dbcodeWrapper.aiApiKey', "AI: Set Custom Model API Key…"), run: () => this.executeDbcodeCommand('dbcode.ai.setApiKey') }),
				new Separator(),
				toAction({ id: 'dbcodeWrapper.scratchFolder', label: localize('dbcodeWrapper.scratchFolder', "Show Scratch Files in Finder"), run: () => this.executeDbcodeCommand(REVEAL_SCRATCH_FILES_COMMAND) })
			]
		});
	}

	private executeDbcodeCommand(commandId: string): Promise<void> {
		return this.runOutsideConnectionsHome(() => this.commandService.executeCommand(commandId));
	}

	private async checkForUpdates(): Promise<void> {
		await this.runOutsideConnectionsHome(async () => {
			const status = await this.commandService.executeCommand<DbcodeWrapperReleaseStatus>(CHECK_FOR_UPDATES_COMMAND);
			this.applyReleaseStatus(status);
		});
	}

	private async runOutsideConnectionsHome(action: () => void | Promise<unknown>): Promise<void> {
		this.closeConnectionsHome();
		await action();
	}

	private async runWhileOpeningSurface(action: () => Promise<void>): Promise<void> {
		this.surfaceOpeningCount++;
		try {
			await action();
		} finally {
			this.surfaceOpeningCount--;
			this.enforcePanelOwnership();
		}
	}

	private isConnectionsHomePanelVisible(): boolean {
		const visiblePanel = this.viewsService.getVisibleViewContainer(ViewContainerLocation.Panel);
		return this.layoutService.isVisible(Parts.PANEL_PART) &&
			visiblePanel?.id === DBCODE_PANEL_CONTAINER &&
			this.viewsService.isViewVisible(DBCODE_PANEL_VIEW);
	}

	private enforcePanelOwnership(): void {
		if (this.surfaceOpeningCount > 0) {
			return;
		}

		if (this.connectionsHomeOpen && this.isConnectionsHomePanelVisible()) {
			return;
		}

		this.connectionsHomeOpen = false;
		this.root.dataset.dbcodeWrapperConnectionsHome = 'closed';
		if (this.layoutService.isVisible(Parts.PANEL_PART)) {
			this.layoutService.setPartHidden(true, Parts.PANEL_PART);
		}
	}

	private registerListeners(): void {
		this._register(this.editorService.onDidActiveEditorChange(() => {
			this.closeConnectionsHome();
			this.updateActiveEditorState();
			this.updateControlState();
		}));
		this._register(addDisposableListener(mainWindow.document, 'drop', event => {
			const droppedFiles = Array.from(event.dataTransfer?.files ?? []);
			if (droppedFiles.length > 0 && droppedFiles.some(file => !file.name.toLowerCase().endsWith('.sql'))) {
				event.preventDefault();
				event.stopImmediatePropagation();
				this.notificationService.info(localize('dbcodeWrapper.sqlDropOnly', "Use Connections for database and data files. Only SQL query files can be dropped onto the query canvas."));
			}
		}, true));
		this._register(this.layoutService.onDidLayoutMainContainer(dimension => {
			this.applyResponsiveLayout(dimension.width);
			this.ensureConnectionsHomeMaximized();
			this.refreshWebviewDismissLayers();
		}));
		this._register(this.layoutService.onDidChangePartVisibility(() => {
			this.enforcePanelOwnership();
			this.updateControlState();
		}));
		this._register(this.viewsService.onDidChangeViewContainerVisibility(event => {
			if (this.surfaceOpeningCount > 0) {
				this.updateControlState();
				return;
			}

			if (!event.visible) {
				this.updateControlState();
				return;
			}

			if (event.location === ViewContainerLocation.Sidebar) {
				this.layoutService.setPartHidden(true, Parts.SIDEBAR_PART);
			}
			if (event.location === ViewContainerLocation.Panel) {
				this.enforcePanelOwnership();
			}
			this.updateControlState();
		}));
		this._register(addDisposableListener(mainWindow.document, 'pointerdown', event => this.closeTransientSurfacesFromPointer(event), true));
		this._register(addDisposableListener(mainWindow.document, 'focusin', event => this.closeTransientSurfacesFromFocus(event), true));
		this._register(this.webviewService.onDidChangeActiveWebview(webview => {
			if (webview) {
				this.closeTransientSurfacesFromWebviewFocus();
			}
		}));
		this._register(this.contextMenuService.onDidShowContextMenu(() => {
			this.refreshWebviewDismissLayers();
			this.scheduleWebviewDismissLayerRefresh();
		}));
		this._register(this.contextMenuService.onDidHideContextMenu(() => this.scheduleWebviewDismissLayerRefresh()));
		this._register(this.quickInputService.onShow(() => {
			this.refreshWebviewDismissLayers();
			this.scheduleWebviewDismissLayerRefresh();
		}));
		this._register(this.quickInputService.onHide(() => this.scheduleWebviewDismissLayerRefresh()));
		this._register(addDisposableListener(mainWindow.document, 'keydown', event => this.handleKeydown(event), true));
	}

	private isVisibleElement(element: HTMLElement | null): element is HTMLElement {
		if (!element) {
			return false;
		}
		const bounds = element.getBoundingClientRect();
		return getComputedStyle(element).display !== 'none' && bounds.width > 0 && bounds.height > 0;
	}

	private eventPathContains(event: PointerEvent, element: HTMLElement | null): boolean {
		return Boolean(element && event.composedPath().includes(element));
	}

	private isDrawerToggleEvent(event: PointerEvent): boolean {
		return event.composedPath().some(target =>
			target instanceof HTMLElement &&
			['database-explorer', 'account'].includes(target.dataset.dbcodeWrapperAction ?? '')
		);
	}

	private closeTransientSurfacesFromPointer(event: PointerEvent): void {
		const quickInput = this.root.querySelector<HTMLElement>('.quick-input-widget');
		const clickedQuickInput = this.eventPathContains(event, quickInput);
		if (this.isVisibleElement(quickInput) && !clickedQuickInput) {
			void this.quickInputService.cancel();
		}

		const visibleContextViews = Array.from(this.root.querySelectorAll<HTMLElement>('.context-view')).filter(element => this.isVisibleElement(element));
		const clickedContextView = visibleContextViews.some(element => this.eventPathContains(event, element));
		if (visibleContextViews.length > 0 && !clickedContextView) {
			this.contextViewService.hideContextView(true);
		}

		const sidebar = this.root.querySelector<HTMLElement>('.part.sidebar');
		const clickedContextLayer = event.composedPath().some(target =>
			target instanceof Element && Boolean(target.closest('.context-view, .monaco-dialog-box, .notifications-toasts'))
		);
		const activeDrawerView = this.activeDrawerView();
		if (activeDrawerView && !this.eventPathContains(event, sidebar) && !clickedQuickInput && !clickedContextLayer && !this.isDrawerToggleEvent(event)) {
			void this.applyDrawerTransition(decideDbcodeDrawerTransition(
				{ open: this.isDbcodeDrawerOpen(), activeView: activeDrawerView },
				{ kind: 'dismiss' }
			));
		}
	}

	private closeTransientSurfacesFromFocus(event: FocusEvent): void {
		if (!(event.target instanceof HTMLIFrameElement)) {
			return;
		}
		this.closeTransientSurfacesFromWebviewFocus();
	}

	private closeTransientSurfacesFromWebviewFocus(): void {
		const quickInput = this.root.querySelector<HTMLElement>('.quick-input-widget');
		if (this.isVisibleElement(quickInput)) {
			void this.quickInputService.cancel();
		}
		if (Array.from(this.root.querySelectorAll<HTMLElement>('.context-view')).some(element => this.isVisibleElement(element))) {
			this.contextViewService.hideContextView(true);
		}
		const activeDrawerView = this.activeDrawerView();
		if (activeDrawerView) {
			void this.applyDrawerTransition(decideDbcodeDrawerTransition(
				{ open: this.isDbcodeDrawerOpen(), activeView: activeDrawerView },
				{ kind: 'dismiss' }
			));
		}
		this.refreshWebviewDismissLayers();
	}

	private scheduleWebviewDismissLayerRefresh(): void {
		this.webviewDismissLayerRefresh.value = disposableTimeout(() => this.refreshWebviewDismissLayers(), 0);
	}

	private refreshWebviewDismissLayers(): void {
		this.webviewDismissLayers.clear();
		const quickInput = this.root.querySelector<HTMLElement>('.quick-input-widget');
		const contextViewVisible = Array.from(this.root.querySelectorAll<HTMLElement>('.context-view')).some(element => this.isVisibleElement(element));
		const activeDrawerView = this.activeDrawerView();
		const transientDrawerVisible = Boolean(activeDrawerView && !isPersistentDbcodeDrawerView(activeDrawerView));
		if (!this.isVisibleElement(quickInput) && !contextViewVisible && !transientDrawerVisible) {
			return;
		}

		const layers = new DisposableStore();
		for (const editorContainer of this.root.querySelectorAll<HTMLElement>('.part.editor > .content .editor-group-container > .editor-container')) {
			if (!this.isVisibleElement(editorContainer)) {
				continue;
			}
			const bounds = editorContainer.getBoundingClientRect();
			const layer = mainWindow.document.createElement('div');
			layer.className = 'dbcode-wrapper-webview-dismiss-layer';
			layer.setAttribute('aria-hidden', 'true');
			layer.style.left = `${bounds.left}px`;
			layer.style.top = `${bounds.top}px`;
			layer.style.width = `${bounds.width}px`;
			layer.style.height = `${bounds.height}px`;
			this.root.append(layer);
			layers.add({ dispose: () => layer.remove() });
		}
		this.webviewDismissLayers.value = layers;
	}

	private hasVisibleTransientOverlay(): boolean {
		return Array.from(this.root.querySelectorAll<HTMLElement>('.quick-input-widget, .context-view, .monaco-dialog-box'))
			.some(element => this.isVisibleElement(element));
	}

	private registerEditorGroupCleanup(): void {
		for (const group of this.editorGroupsService.groups) {
			this.registerEditorGroup(group);
		}
		this._register(this.editorGroupsService.onDidAddGroup(group => this.registerEditorGroup(group)));
		void this.editorGroupsService.whenRestored.then(() => this.scheduleEmptyEditorGroupCleanup());
	}

	private registerEditorGroup(group: IEditorGroup): void {
		this._register(group.onDidActiveEditorChange(() => this.updateEditorGroupPresentation()));
		this._register(group.onDidCloseEditor(() => this.scheduleEmptyEditorGroupCleanup(group)));
	}

	private scheduleEmptyEditorGroupCleanup(group?: IEditorGroup): void {
		if (group) {
			this.emptyGroupsPendingCleanup.add(group);
		} else {
			this.cleanupAllEmptyGroups = true;
		}

		this.emptyGroupCleanup.value = disposableTimeout(() => {
			const candidates = this.cleanupAllEmptyGroups ? undefined : [...this.emptyGroupsPendingCleanup];
			this.emptyGroupsPendingCleanup.clear();
			this.cleanupAllEmptyGroups = false;
			this.cleanupEmptyEditorGroups(candidates);
		}, 250);
	}

	private cleanupEmptyEditorGroups(candidates?: readonly IEditorGroup[]): void {
		const existingGroups = this.editorGroupsService.getGroups(GroupsOrder.GRID_APPEARANCE);
		for (const group of candidates ?? existingGroups) {
			if (this.editorGroupsService.count <= 1) {
				break;
			}
			if (existingGroups.includes(group) && group.isEmpty) {
				this.editorGroupsService.removeGroup(group);
			}
		}
		this.updateEditorGroupPresentation();
	}

	private updateActiveEditorState(): void {
		const queryName = this.editorService.activeEditor?.getName() ?? localize('dbcodeWrapper.untitledSql', "Untitled SQL");
		this.root.dataset.dbcodeWrapperQueryName = queryName;
		this.updateEditorGroupPresentation();
	}

	private updateEditorGroupPresentation(): void {
		const groups = this.editorGroupsService.getGroups(GroupsOrder.GRID_APPEARANCE);
		const elements = this.root.querySelectorAll<HTMLElement>('.part.editor > .content .editor-group-container');
		for (let index = 0; index < elements.length; index++) {
			const group = groups[index];
			const resourceIsSql = group?.activeEditor?.resource?.path.toLowerCase().endsWith('.sql') === true;
			const activeTextEditorIsSql = group === this.editorGroupsService.activeGroup && this.editorService.activeTextEditorLanguageId === 'sql';
			elements[index].classList.toggle('dbcode-wrapper-sql-editor-group', resourceIsSql || activeTextEditorIsSql);
		}
	}

	private isSqlEditorActive(): boolean {
		if (this.editorService.activeTextEditorLanguageId === 'sql') {
			return true;
		}

		return this.editorService.activeEditor?.resource?.path.toLowerCase().endsWith('.sql') === true;
	}

	private activeDrawerView(): string | undefined {
		const visibleContainer = this.viewsService.getVisibleViewContainer(ViewContainerLocation.Sidebar);
		if (!this.layoutService.isVisible(Parts.SIDEBAR_PART) || visibleContainer?.id !== DBCODE_ACTIVITY_CONTAINER) {
			return undefined;
		}
		return this.root.dataset.dbcodeWrapperDrawerView;
	}

	private applyResponsiveLayout(width: number): void {
		const isNarrow = width < this.narrowBreakpoint;
		this.root.classList.toggle('dbcode-wrapper-narrow', isNarrow);
		this.root.dataset.dbcodeWrapperNarrow = String(isNarrow);
		this.updateControlState();
	}

	private async applyDefaultResultLocation(): Promise<void> {
		try {
			await this.configurationService.updateValue(DBCODE_RESULT_LOCATION_SETTING, 'below', ConfigurationTarget.USER);
		} catch {
			return;
		}
	}

	private async restoreDbcodeSurface(): Promise<void> {
		await this.extensionService.whenInstalledExtensionsRegistered();
		await this.applyDefaultResultLocation();
		if (!this.editorService.activeEditor) {
			await this.openScratchQuery();
		}
		await this.extensionService.activateByEvent('onLanguage:sql');
		if (this.dbcodeExtensionStatus) {
			this.dbcodeExtensionStatus.parentElement?.classList.remove('starting');
			this.dbcodeExtensionStatus.textContent = localize('dbcodeWrapper.active', "DBCode active");
		}
		this.root.dataset.dbcodeWrapperDbcodeState = 'active';
		void this.refreshReleaseStatus();
		this.enforcePanelOwnership();
		this.updateControlState();
	}

	private async refreshReleaseStatus(): Promise<void> {
		try {
			const status = await this.commandService.executeCommand<DbcodeWrapperReleaseStatus>(GET_UPDATE_STATUS_COMMAND);
			this.applyReleaseStatus(status);
		} catch {
			this.applyReleaseStatus({ kind: 'offline', updatesAvailable: false, readyToInstall: false });
		}
	}

	private applyReleaseStatus(status: DbcodeWrapperReleaseStatus | undefined): void {
		const button = this.releaseStatusButton;
		if (!button || !status || !['current', 'update-available', 'offline', 'invalid'].includes(status.kind)) {
			return;
		}
		const presentation = status.kind === 'update-available'
			? {
				icon: status.readyToInstall ? 'verified-filled' : 'arrow-up',
				label: status.readyToInstall
					? localize('dbcodeWrapper.updateReady', "Ready to install")
					: localize('dbcodeWrapper.updateNotTested', "Update available — Not tested")
			}
			: status.kind === 'current'
				? {
					icon: 'check',
					label: status.codeOss && status.dbcode
						? localize('dbcodeWrapper.currentVersions', "Code OSS {0}, DBCode {1}: current", status.codeOss.installedVersion, status.dbcode.installedVersion)
						: localize('dbcodeWrapper.current', "Code OSS and DBCode are current")
				}
				: {
					icon: 'warning',
					label: localize('dbcodeWrapper.updateUnavailable', "Update check unavailable")
				};
		const icon = button.querySelector<HTMLElement>('.codicon');
		if (icon) {
			icon.className = `codicon codicon-${presentation.icon}`;
		}
		button.dataset.dbcodeWrapperReleaseStatus = status.readyToInstall ? 'ready' : status.kind;
		button.title = presentation.label;
		button.setAttribute('aria-label', presentation.label);
		this.root.dataset.dbcodeWrapperReleaseStatus = button.dataset.dbcodeWrapperReleaseStatus;
	}

	private async openScratchQuery(): Promise<void> {
		const storageNamespace = product.dbcodeWrapperStorageNamespace;
		const queryFolderName = product.dbcodeWrapperQueryFolderName;
		if (!storageNamespace || !queryFolderName) {
			throw new Error('DBCode Wrapper query storage identity is missing.');
		}
		const queryFolder = joinPath(this.userDataProfileService.currentProfile.globalStorageHome, storageNamespace, queryFolderName);
		const queryResource = joinPath(queryFolder, 'scratch.sql');
		await this.fileService.createFolder(queryFolder);
		if (!(await this.fileService.exists(queryResource))) {
			await this.fileService.createFile(queryResource);
		}
		await this.editorService.openEditor({ resource: queryResource, options: { pinned: true } });
	}

	private ensureConnectionsHomeMaximized(): void {
		if (this.connectionsHomeOpen &&
			this.isConnectionsHomePanelVisible() &&
			!this.layoutService.isPanelMaximized()) {
			this.layoutService.toggleMaximizedPanel();
		}
	}

	private async openConnectionsHome(): Promise<void> {
		this.layoutService.setPartHidden(true, Parts.SIDEBAR_PART);
		await this.runWhileOpeningSurface(async () => {
			const container = await this.viewsService.openViewContainer(DBCODE_PANEL_CONTAINER, true);
			const view = await this.viewsService.openView(DBCODE_PANEL_VIEW, true);
			this.connectionsHomeOpen = Boolean(container && view);
			this.installConnectionsHomeChrome();
		});
		this.ensureConnectionsHomeMaximized();
		this.updateControlState();
	}

	private installConnectionsHomeChrome(): void {
		const titlebar = this.root.querySelector<HTMLElement>('.part.panel > .title');
		if (!titlebar) {
			return;
		}

		if (!this.connectionsHomeTitle?.isConnected) {
			const title = mainWindow.document.createElement('span');
			title.className = 'dbcode-wrapper-connections-home-title';
			title.append(this.createIcon('database'));
			const text = mainWindow.document.createElement('span');
			text.textContent = localize('dbcodeWrapper.connectionsHome', "Connections");
			title.append(text);
			titlebar.prepend(title);
			this.connectionsHomeTitle = title;
		}

		if (!this.connectionsHomeCloseButton?.isConnected) {
			const closeButton = mainWindow.document.createElement('button');
			closeButton.className = 'dbcode-wrapper-connections-home-close';
			closeButton.type = 'button';
			closeButton.title = localize('dbcodeWrapper.closeConnections', "Close Connections");
			closeButton.setAttribute('aria-label', closeButton.title);
			closeButton.append(this.createIcon('close'));
			titlebar.append(closeButton);
			this._register(addDisposableListener(closeButton, 'click', () => this.closeConnectionsHome()));
			this.connectionsHomeCloseButton = closeButton;
		}

		if (!titlebar.classList.contains('dbcode-wrapper-connections-home-titlebar')) {
			titlebar.classList.add('dbcode-wrapper-connections-home-titlebar');
			this._register(addDisposableListener(titlebar, 'contextmenu', event => {
				if (this.connectionsHomeOpen) {
					event.preventDefault();
					event.stopImmediatePropagation();
				}
			}, true));
		}
	}

	private async toggleConnectionsHome(): Promise<void> {
		if (this.connectionsHomeOpen && this.layoutService.isVisible(Parts.PANEL_PART)) {
			this.closeConnectionsHome();
			return;
		}
		await this.openConnectionsHome();
	}

	private closeConnectionsHome(): void {
		this.connectionsHomeOpen = false;
		this.root.dataset.dbcodeWrapperConnectionsHome = 'closed';
		if (this.layoutService.isVisible(Parts.PANEL_PART) && this.layoutService.isPanelMaximized()) {
			this.layoutService.toggleMaximizedPanel();
		}
		if (this.layoutService.isVisible(Parts.PANEL_PART)) {
			this.layoutService.setPartHidden(true, Parts.PANEL_PART);
		}
		this.updateControlState();
	}

	private async toggleDrawer(viewId: DbcodeDrawerViewId): Promise<void> {
		this.closeConnectionsHome();
		await this.applyDrawerTransition(decideDbcodeDrawerTransition(
			{
				open: this.isDbcodeDrawerOpen(),
				activeView: this.viewsService.isViewVisible(viewId) ? viewId : undefined
			},
			{ kind: 'toggle', viewId }
		));
	}

	private async applyDrawerTransition(transition: DbcodeDrawerTransition): Promise<void> {
		if (transition.kind === 'open') {
			await this.openDrawerView(transition.viewId);
			return;
		}
		if (transition.kind === 'close') {
			this.closeDbcodeDrawer();
		}
	}

	private isDbcodeDrawerOpen(): boolean {
		const visibleContainer = this.viewsService.getVisibleViewContainer(ViewContainerLocation.Sidebar);
		return this.layoutService.isVisible(Parts.SIDEBAR_PART) && visibleContainer?.id === DBCODE_ACTIVITY_CONTAINER;
	}

	private closeDbcodeDrawer(): void {
		if (this.isDbcodeDrawerOpen()) {
			this.layoutService.setPartHidden(true, Parts.SIDEBAR_PART);
			this.updateControlState();
		}
	}

	private configureDrawerViews(viewId: DbcodeDrawerViewId): void {
		const viewContainer = this.viewDescriptorService.getViewContainerById(DBCODE_ACTIVITY_CONTAINER);
		if (!viewContainer) {
			this.root.dataset.dbcodeWrapperDrawerViews = 'unavailable';
			return;
		}

		const model = this.viewDescriptorService.getViewContainerModel(viewContainer);
		for (const descriptor of model.allViewDescriptors) {
			const visible = descriptor.id === viewId;
			if (model.isVisible(descriptor.id) !== visible) {
				model.setVisible(descriptor.id, visible);
			}
		}

		this.root.dataset.dbcodeWrapperDrawerViews = model.visibleViewDescriptors.map(descriptor => descriptor.id).join(',');
	}

	private async openDrawerView(viewId: DbcodeDrawerViewId): Promise<void> {
		this.closeConnectionsHome();
		await this.runWhileOpeningSurface(async () => {
			this.configureDrawerViews(viewId);
			const container = await this.viewsService.openViewContainer(DBCODE_ACTIVITY_CONTAINER, true);
			const view = await this.viewsService.openView(viewId, true);
			this.root.dataset.dbcodeWrapperDrawerView = container && view ? viewId : 'unavailable';
		});
		this.updateControlState();
	}

	private updateControlState(): void {
		const drawerOpen = this.isDbcodeDrawerOpen();
		const drawerView = drawerOpen ? this.activeDrawerView() : undefined;

		this.root.classList.toggle('dbcode-wrapper-drawer-open', drawerOpen);
		this.root.dataset.dbcodeWrapperDrawer = drawerOpen ? 'open' : 'closed';
		this.root.dataset.dbcodeWrapperConnectionsHome = this.connectionsHomeOpen ? 'open' : 'closed';
		this.root.dataset.dbcodeWrapperActiveSurface = this.connectionsHomeOpen ? 'connections' :
			drawerView === DBCODE_CONNECTIONS_VIEW ? 'explorer' :
			drawerView ? 'dbcode' :
			this.isSqlEditorActive() ? 'query' : 'data';
		this.connectionsButton?.setAttribute('aria-expanded', String(this.connectionsHomeOpen));
		this.connectionsButton?.classList.toggle('active', this.connectionsHomeOpen);
		this.databaseExplorerButton?.setAttribute('aria-expanded', String(drawerView === DBCODE_CONNECTIONS_VIEW));
		this.databaseExplorerButton?.classList.toggle('active', drawerView === DBCODE_CONNECTIONS_VIEW);
		this.refreshWebviewDismissLayers();
	}

	private handleKeydown(event: KeyboardEvent): void {
		if (event.key === 'Escape' && this.hasVisibleTransientOverlay()) {
			return;
		}

		if (event.key === 'Escape' && this.connectionsHomeOpen) {
			this.closeConnectionsHome();
			event.preventDefault();
			event.stopImmediatePropagation();
			return;
		}

		if (event.key === 'Escape' && this.layoutService.isVisible(Parts.SIDEBAR_PART)) {
			const visible = this.viewsService.getVisibleViewContainer(ViewContainerLocation.Sidebar);
			const activeDrawerView = this.activeDrawerView();
			const transition = decideDbcodeDrawerTransition(
				{ open: visible?.id === DBCODE_ACTIVITY_CONTAINER, activeView: activeDrawerView },
				{ kind: 'dismiss' }
			);
			if (transition.kind === 'close') {
				void this.applyDrawerTransition(transition);
				event.preventDefault();
				event.stopImmediatePropagation();
			}
			return;
		}

		const key = event.key.toLowerCase();
		if (event.metaKey && !event.shiftKey && key === 'b') {
			void this.toggleDrawer(DBCODE_CONNECTIONS_VIEW);
			this.blockKey(event);
			return;
		}

		const commandPalette = event.key === 'F1' || (event.metaKey && event.shiftKey && key === 'p');
		const quickOpen = event.metaKey && !event.shiftKey && key === 'p';
		const settings = event.metaKey && key === ',';
		const genericPanel = ((event.metaKey || event.ctrlKey) && !event.shiftKey && key === 'j') ||
			((event.metaKey || event.ctrlKey) && event.shiftKey && ['m', 'u', 'y'].includes(key)) ||
			(event.ctrlKey && key === '`');
		const genericView = (event.metaKey || event.ctrlKey) && event.shiftKey && ['e', 'f', 'g', 'd', 'x'].includes(key);
		if (commandPalette || quickOpen || settings || genericPanel || genericView) {
			this.blockKey(event);
		}
	}

	private blockKey(event: KeyboardEvent): void {
		event.preventDefault();
		event.stopImmediatePropagation();
	}
}

registerWorkbenchContribution2(DbcodeWrapperFocusedShellContribution.ID, DbcodeWrapperFocusedShellContribution, WorkbenchPhase.AfterRestored);
