const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const {
	createConnectionCatalogueSnapshot,
	verifyConnectionCatalogueSnapshot
} = require('./connection-catalogue-contract.cjs');
const { isExpectedDbcodeShutdownChannelClose } = require('./extension-host-log-policy.cjs');
const { createProfileLayout } = require('../extensions/dbcode-wrapper-profile-migration/profile-layout.js');

const repoRoot = path.resolve(__dirname, '../..');
const releaseLock = JSON.parse(fs.readFileSync(path.join(repoRoot, 'host/release-lock.json'), 'utf8'));
const featurePolicy = JSON.parse(fs.readFileSync(path.join(repoRoot, 'host/dbcode-feature-policy.json'), 'utf8'));
const appName = releaseLock.product.app_name;
const productionExecutable = path.join(repoRoot, 'dist', `${appName}.app`, 'Contents/MacOS', appName);
const sourcePlaywrightModule = path.join(repoRoot, '.build/work', `vscodium-${releaseLock.upstream.vscodium.tag}`, 'vscode/node_modules/playwright');
const bundledPlaywrightModule = path.join(repoRoot, 'dist', `${appName}.app`, 'Contents/Resources/app/node_modules/playwright-core');
const playwrightModule = fs.existsSync(path.join(sourcePlaywrightModule, 'package.json')) ? sourcePlaywrightModule : bundledPlaywrightModule;
const { _electron: electron } = require(playwrightModule);
const qaExtensions = process.env.DBCODE_WRAPPER_QA_EXTENSIONS_DIR;
assert.ok(qaExtensions && path.isAbsolute(qaExtensions), 'DBCODE_WRAPPER_QA_EXTENSIONS_DIR must name the isolated QA extension directory.');
const qaJupyterPath = process.env.DBCODE_WRAPPER_QA_JUPYTER_PATH;
assert.ok(qaJupyterPath && path.isAbsolute(qaJupyterPath), 'DBCODE_WRAPPER_QA_JUPYTER_PATH must name the isolated QA Jupyter data directory.');
assert.ok(fs.existsSync(path.join(qaJupyterPath, 'kernels/dbcode-wrapper-qa/kernel.json')), 'The isolated DBCode Python kernel is missing.');
const obsoleteExtensionDirectories = fs.existsSync(path.join(qaExtensions, '.obsolete'))
	? JSON.parse(fs.readFileSync(path.join(qaExtensions, '.obsolete'), 'utf8'))
	: {};
const qaExtensionDirectories = fs.readdirSync(qaExtensions).filter(entry =>
	fs.statSync(path.join(qaExtensions, entry)).isDirectory()
	&& fs.existsSync(path.join(qaExtensions, entry, 'package.json'))
	&& obsoleteExtensionDirectories[entry] !== true
).sort();
const qaExtensionRecords = qaExtensionDirectories.map(directory => {
	const manifest = JSON.parse(fs.readFileSync(path.join(qaExtensions, directory, 'package.json'), 'utf8'));
	return { directory, id: `${manifest.publisher}.${manifest.name}`, version: manifest.version, manifest };
});
const expectedRuntimeExtensions = [releaseLock.extension.dbcode, ...releaseLock.extension.python_notebooks.packages]
	.map(extension => `${extension.id}@${extension.version}`)
	.sort();
assert.deepEqual(
	qaExtensionRecords.map(extension => `${extension.id}@${extension.version}`).sort(),
	expectedRuntimeExtensions,
	'The isolated QA extension directory must contain the exact locked DBCode and Python-notebook release set under test.'
);
const dbcodeExtensionDirectory = qaExtensionRecords.find(extension => extension.id === 'dbcode.dbcode')?.directory;
assert.ok(dbcodeExtensionDirectory, 'The isolated QA extension directory does not contain DBCode.');
const dbcodeManifest = JSON.parse(fs.readFileSync(path.join(qaExtensions, dbcodeExtensionDirectory, 'package.json'), 'utf8'));
const streamsView = dbcodeManifest.contributes.views.dbcodeActivitybarContainer.find(view => view.id === 'dbcode.streams.view');
assert.equal(streamsView?.when, 'dbcode.hasActiveStreams', 'The pinned DBCode package no longer exposes Streams only while a stream is active.');
const qaRoot = path.join(repoRoot, '.build/qa');
const workspacePath = path.join(qaRoot, 'workspace');
const persistentProfileRoot = path.join(qaRoot, 'rendered');
const externalReleaseLinkCapturePath = path.join(
	persistentProfileRoot,
	'user-data/User/globalStorage/dbcode-wrapper.release-status/rendered-release-link-capture.jsonl'
);
const outputRoot = path.join(repoRoot, 'output/playwright');
const connectionCatalogueOnly = process.env.DBCODE_WRAPPER_CONNECTION_CATALOGUE_ONLY === 'yes';
const reportPath = path.join(
	outputRoot,
	connectionCatalogueOnly ? 'ticket-22-connection-catalogue-report.json' : 'ticket-03-rendered-report.json'
);
const projectQueryPath = path.join(repoRoot, 'host/qa/project-query.sql');
const migrationInventoryPath = path.join(qaRoot, 'profile-migration-rendered-inventory.json');
const migrationDuckdbPath = path.join(qaRoot, 'rendered-proof-with-hyphen.duckdb');
const migrationSecondDuckdbPath = path.join(qaRoot, 'rendered-second-hyphen.duckdb');
const migrationDuckdbImportPath = path.join(qaRoot, 'hyphen-duckdb-preflight.csv');
const migrationDuckdbFixturePath = path.join(repoRoot, 'host/qa/fixtures/read-only-duckdb-fixture.duckdb.gz.base64');
const focusedShellTimeout = Number(process.env.DBCODE_WRAPPER_QA_TIMEOUT_MS ?? 60000);
const connectionDrawerViews = ['dbcode.connections.view'];
const connectionToolDrawers = [
	['Tunnels', 'dbcode.tunnels.view'],
	['Authentication Profiles', 'dbcode.authProfiles.view']
];
const queryDrawers = [
	['History', 'dbcode.history.view'],
	['Library', 'dbcode.library.view']
];
const advancedToolLabels = [
	'New DBCode Notebook',
	'Start Python Kernel…',
	'Query Builder',
	'DBCode Settings…',
	'Check for Updates…',
	'AI: Choose Provider',
	'AI: Set API Key',
	'Show Scratch Files in Finder'
];
const removedToolLabels = [
	'Open Data File…',
	'Open Scratch Files Folder',
	'AI: Change Model',
	'MCP: Start HTTP Server',
	'MCP: Stop HTTP Server',
	'MCP: Revoke OAuth Tokens'
];

fs.mkdirSync(workspacePath, { recursive: true });
fs.mkdirSync(outputRoot, { recursive: true });
const migrationDuckdbFixture = zlib.gunzipSync(Buffer.from(fs.readFileSync(migrationDuckdbFixturePath, 'utf8').trim(), 'base64'));
fs.writeFileSync(migrationDuckdbPath, migrationDuckdbFixture, { mode: 0o600 });
fs.writeFileSync(migrationSecondDuckdbPath, migrationDuckdbFixture, { mode: 0o600 });
fs.writeFileSync(migrationDuckdbImportPath, [
	'name,type,path,connectionType',
	`Rendered-Hyphen-DuckDB,duckdb,${migrationDuckdbPath},socket`
].join('\n') + '\n', { mode: 0o600 });
const migrationDuckdbDigest = crypto.createHash('sha256').update(migrationDuckdbFixture).digest('hex');
fs.writeFileSync(migrationInventoryPath, `${JSON.stringify([
	{
		name: 'Rendered PostgreSQL',
		type: 'postgresql',
		host: 'localhost',
		port: 5432,
		database: 'postgres',
		username: 'dbcode_wrapper',
		ssl: 'prefer'
	},
	{
		name: 'Rendered Parquet',
		type: 'parquet',
		path: path.join(qaRoot, 'rendered-proof.parquet')
	},
	{
		name: 'Rendered hyphen DuckDB one',
		type: 'duckdb',
		path: migrationDuckdbPath
	},
	{
		name: 'Rendered hyphen DuckDB two',
		type: 'duckdb',
		path: migrationSecondDuckdbPath
	}
], null, 2)}\n`, { mode: 0o600 });

const report = {
	startedAt: new Date().toISOString(),
	checks: [],
	warnings: [],
	errors: []
};

function record(name, details = {}) {
	report.checks.push({ name, ...details });
	console.log(`PASS ${name}`, JSON.stringify(details));
}

function scanExtensionHostLogs(profileRoot) {
	const logRoot = path.join(profileRoot, 'user-data/logs');
	const findings = [];
	const knownPackageWarnings = [];
	const knownShutdownWarnings = [];
	const requiredExtensionIds = new Set(qaExtensionRecords.map(extension => extension.id));
	const visit = directory => {
		if (!fs.existsSync(directory)) return;
		for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
			const entryPath = path.join(directory, entry.name);
			if (entry.isDirectory()) {
				visit(entryPath);
			} else if (entry.isFile() && entry.name.endsWith('.log')) {
				const relativePath = path.relative(logRoot, entryPath);
				const pathParts = relativePath.split(path.sep);
				const extensionHostIndex = pathParts.indexOf('exthost');
				if (extensionHostIndex < 0) continue;
				const extensionLogOwner = pathParts[extensionHostIndex + 1];
				if (extensionLogOwner !== 'exthost.log'
					&& !requiredExtensionIds.has(extensionLogOwner)
					&& !extensionLogOwner.startsWith('output_logging_')) continue;
				const lines = fs.readFileSync(entryPath, 'utf8').split(/\r?\n/);
				for (const [index, line] of lines.entries()) {
					if (!/\[(?:error|critical)\]|\bFATAL\b/i.test(line)) continue;
					const finding = `${relativePath}:${index + 1}: ${line}`;
					if (line.includes("Failed to read 'SQLite Binary' version file")
						|| line.includes('Unable to find workspace for given file')) {
						knownPackageWarnings.push(finding);
					} else if (isExpectedDbcodeShutdownChannelClose(lines, index)) {
						knownShutdownWarnings.push(finding);
					} else {
						findings.push(finding);
					}
				}
			}
		}
	};
	visit(logRoot);
	for (const warning of knownPackageWarnings) {
		report.warnings.push(`Pinned DBCode package omits its optional SQLite Binary version marker: ${warning}`);
	}
	for (const warning of knownShutdownWarnings) {
		report.warnings.push(`DBCode finished a child process after the extension host began a clean shutdown: ${warning}`);
	}
	assert.deepEqual(findings, [], `Required runtime extensions emitted unexpected activation errors:\n${findings.join('\n')}`);
	record('required runtime extensions activate without unexpected extension-host errors', {
		logRoot,
		knownPackageWarningCount: knownPackageWarnings.length,
		knownShutdownWarningCount: knownShutdownWarnings.length
	});
}

async function captureSignedWindow(app, page, filename) {
	await page.bringToFront();
	const screenshotPath = path.join(outputRoot, filename);
	let lastError;
	for (let attempt = 0; attempt < 3; attempt++) {
		await page.waitForTimeout(300);
		const mediaSourceId = await app.evaluate(({ BrowserWindow }) => {
			const window = BrowserWindow.getFocusedWindow() ?? BrowserWindow.getAllWindows().find(candidate => candidate.isVisible());
			return window?.getMediaSourceId() ?? null;
		});
		assert.match(mediaSourceId ?? '', /^window:\d+:/, 'Electron did not expose the signed app window for native capture.');
		const windowId = mediaSourceId.split(':')[1];
		try {
			execFileSync('/usr/sbin/screencapture', ['-x', '-l', windowId, screenshotPath]);
			assert.ok(fs.statSync(screenshotPath).size > 0, `The signed-window capture ${filename} is empty.`);
			return;
		} catch (error) {
			lastError = error;
		}
	}
	throw lastError;
}

async function setSignedWindowContentSize(app, page, width, height) {
	await app.evaluate(({ BrowserWindow }, size) => {
		const window = BrowserWindow.getFocusedWindow() ?? BrowserWindow.getAllWindows().find(candidate => candidate.isVisible());
		if (!window) {
			throw new Error('The signed DBCode Wrapper window is not available for resizing.');
		}
		window.setContentSize(size.width, size.height, false);
	}, { width, height });
	await page.waitForFunction(size => innerWidth === size.width && innerHeight === size.height, { width, height });
}

async function getWindowButtonPosition(app) {
	return app.evaluate(({ BrowserWindow }) => {
		const window = BrowserWindow.getFocusedWindow() ?? BrowserWindow.getAllWindows().find(candidate => candidate.isVisible());
		return window?.getWindowButtonPosition() ?? null;
	});
}

function profileArgs(root, extensionsDir) {
	const userData = path.join(root, 'user-data');
	const sharedData = path.join(root, 'shared-data');
	fs.mkdirSync(path.join(userData, 'User'), { recursive: true });
	fs.mkdirSync(sharedData, { recursive: true });
	const updateStateRoot = path.join(userData, 'User/globalStorage/dbcode-wrapper.release-status');
	const updateStatePath = path.join(updateStateRoot, 'release-status-state.json');
	if (!fs.existsSync(updateStatePath)) {
		const checkedAt = new Date().toISOString();
		fs.mkdirSync(updateStateRoot, { recursive: true });
		fs.writeFileSync(updateStatePath, `${JSON.stringify({
			schemaVersion: 2,
			decisions: { skippedCandidates: [] },
			lastCheckAt: checkedAt,
			lastCheckResult: 'success',
			metadataCache: {
				checkedAt,
				available: {
					vscodium: {
						version: releaseLock.upstream.vscodium.tag,
						publishedAt: releaseLock.upstream.vscodium.published_at,
						releaseNotesUrl: releaseLock.upstream.vscodium.release_notes_url
					},
					codeOss: {
						version: releaseLock.upstream.code_oss.tag,
						publishedAt: releaseLock.upstream.code_oss.published_at,
						releaseNotesUrl: releaseLock.upstream.code_oss.release_notes_url
					},
					dbcode: {
						version: releaseLock.extension.dbcode.version,
						publishedAt: releaseLock.extension.dbcode.published_at,
						releaseNotesUrl: releaseLock.extension.dbcode.release_notes_url
					}
				}
			}
		}, null, 2)}\n`);
	}
	return [
		'--user-data-dir', userData,
		'--extensions-dir', extensionsDir,
		'--shared-data-dir', sharedData
	];
}

async function waitForReleaseStatus(page) {
	await page.waitForFunction(() => {
		const status = document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperReleaseStatus;
		return status && status !== 'checking';
	});
}

function commonArgs(extra = []) {
	return [
		...extra,
		'--use-mock-keychain',
		'--disable-telemetry',
		'--disable-updates',
		'--disable-workspace-trust',
		'--new-window',
		'--skip-release-notes',
		'--skip-welcome',
		workspacePath
	];
}

function recoveryEnvironment(executablePath, args) {
	const userDataIndex = args.indexOf('--user-data-dir');
	const sharedDataIndex = args.indexOf('--shared-data-dir');
	if (userDataIndex < 0 || sharedDataIndex < 0 || !args[userDataIndex + 1] || !args[sharedDataIndex + 1]) {
		return {};
	}
	const profileRoot = path.dirname(args[userDataIndex + 1]);
	const buildRoot = path.join(repoRoot, '.build');
	const unusedHomeDirectory = path.join(buildRoot, 'qa/home-not-used');
	const profileLayout = profileRoot === path.join(buildRoot, 'qa/profile')
		? createProfileLayout({
			profileName: 'qa',
			homeDirectory: unusedHomeDirectory,
			buildRoot
		})
		: createProfileLayout({
			profileName: 'isolated',
			homeDirectory: unusedHomeDirectory,
			buildRoot,
			stateRoot: path.resolve(profileRoot),
			extensionsRoot: path.resolve(qaExtensions)
		});
	return {
		DBCODE_WRAPPER_QA_RECOVERY: '1',
		DBCODE_WRAPPER_PROFILE_LAYOUT_JSON: JSON.stringify(profileLayout),
		DBCODE_WRAPPER_EXTENSIONS_ROOT: path.resolve(qaExtensions),
		DBCODE_WRAPPER_SHARED_DATA_ROOT: path.resolve(args[sharedDataIndex + 1]),
		DBCODE_WRAPPER_PROFILE_BACKUP_ROOT: `${path.resolve(profileRoot)}-backups`,
		DBCODE_WRAPPER_APP_BUNDLE: path.resolve(executablePath, '../../..'),
		DBCODE_WRAPPER_RECOVERY_RELAUNCH_ARGS: JSON.stringify(args)
	};
}

async function launch(executablePath, args, extraEnv = {}) {
	const app = await electron.launch({
		executablePath,
		args,
		env: {
			...process.env,
			JUPYTER_PATH: qaJupyterPath,
			...recoveryEnvironment(executablePath, args),
			...extraEnv
		}
	});
	const page = await app.firstWindow({ timeout: 60000 });
	let collectDiagnostics = true;
	page.on('console', message => {
		if (!collectDiagnostics) {
			return;
		}
		if (message.type() === 'warning') {
			report.warnings.push(message.text());
		}
		if (message.type() === 'error') {
			const location = message.location();
			const details = `console: ${message.text()}${location.url ? ` at ${location.url}:${location.lineNumber}` : ''}`;
			if (message.text() === 'Failed to load resource: net::ERR_FILE_NOT_FOUND' && location.url.endsWith('/resources/svgs/success-gutter.svg')) {
				report.warnings.push(`Pinned DBCode package references its query-success gutter icon without the out/ prefix: ${location.url}`);
			} else if (message.text().includes('[DEP0040]') && message.text().includes('punycode')) {
				report.warnings.push(`Pinned Python/Jupyter runtime emitted Node's punycode deprecation warning: ${message.text()}`);
			} else {
				report.errors.push(details);
			}
		}
	});
	page.on('pageerror', error => {
		if (collectDiagnostics) {
			report.errors.push(`page: ${error.message}`);
		}
	});
	return {
		app,
		page,
		stopDiagnostics: () => {
			collectDiagnostics = false;
		}
	};
}

async function waitForFocusedShell(app, page) {
	await setSignedWindowContentSize(app, page, 1440, 900);
	await page.locator('.dbcode-wrapper-toolbar').waitFor({ timeout: focusedShellTimeout });
	try {
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDbcodeState === 'active', null, { timeout: focusedShellTimeout });
	} catch (error) {
		const snapshot = await page.evaluate(() => {
			const root = document.querySelector('.monaco-workbench');
			const panel = document.querySelector('.part.panel');
			const panelBounds = panel?.getBoundingClientRect();
			return {
				dataset: root ? { ...root.dataset } : null,
				activeTabs: [...document.querySelectorAll('.tab.active .label-name')].map(element => element.textContent?.trim()),
				iframeSources: [...document.querySelectorAll('iframe')].map(frame => frame.src),
				panel: panel ? {
					display: getComputedStyle(panel).display,
					width: panelBounds?.width,
					height: panelBounds?.height,
					title: panel.querySelector('.title')?.textContent?.trim()
				} : null
			};
		});
		throw new Error(`Focused shell did not activate DBCode: ${JSON.stringify(snapshot)}. ${error.message}`);
	}
	await page.waitForTimeout(1000);
}

async function waitForAutomaticResultLocation(page, location) {
	await page.waitForFunction(expected => {
		const dataset = document.querySelector('.monaco-workbench')?.dataset;
		return dataset?.dbcodeWrapperResultLocation === expected && dataset.dbcodeWrapperResultLocationState === 'ready';
	}, location);
}

async function geometry(page) {
	return page.evaluate(() => {
		const rect = selector => document.querySelector(selector)?.getBoundingClientRect().toJSON() ?? null;
		const visible = selector => {
			const element = document.querySelector(selector);
			if (!element) {
				return false;
			}
			const box = element.getBoundingClientRect();
			return getComputedStyle(element).display !== 'none' && box.width > 0 && box.height > 0;
		};
		const root = document.querySelector('.monaco-workbench');
		const visibleEditorGroups = [...document.querySelectorAll('.editor-group-container')]
			.filter(element => {
				const box = element.getBoundingClientRect();
				return getComputedStyle(element).display !== 'none' && box.width > 0 && box.height > 0;
			})
			.map(element => ({
				bounds: element.getBoundingClientRect().toJSON(),
				tabs: [...element.querySelectorAll('.tab .label-name')].map(tab => tab.textContent?.trim() ?? '').filter(Boolean),
				className: element.className
			}));
		return {
			dataset: root ? { ...root.dataset } : null,
			rootClass: root?.className ?? '',
			titlebar: rect('.part.titlebar'),
			titlebarInlineStyle: document.querySelector('.part.titlebar')?.getAttribute('style') ?? '',
			titlebarComputedHeight: document.querySelector('.part.titlebar') ? getComputedStyle(document.querySelector('.part.titlebar')).height : null,
			titlebarContainer: rect('.part.titlebar > .titlebar-container'),
			toolbar: rect('.dbcode-wrapper-toolbar'),
			toolbarClass: document.querySelector('.dbcode-wrapper-toolbar')?.className ?? '',
			windowTitleVisible: visible('.part.titlebar .window-title'),
			windowTitleText: document.querySelector('.part.titlebar .window-title')?.textContent ?? '',
			queryContextVisible: visible('.dbcode-wrapper-query-context'),
			queryName: document.querySelector('.dbcode-wrapper-query-name')?.textContent ?? '',
			dbcodeExtensionState: document.querySelector('.dbcode-wrapper-extension-state')?.textContent ?? '',
			editor: rect('.part.editor'),
			panel: rect('.part.panel'),
			panelVisible: visible('.part.panel'),
			sidebar: rect('.part.sidebar'),
			sidebarVisible: visible('.part.sidebar'),
			sidebarOverflowVisible: visible('.part.sidebar > .title .title-actions .action-label.codicon-toolbar-more'),
			sidebarTitleActionCount: [...document.querySelectorAll('.part.sidebar > .title .title-actions .action-item')]
				.filter(element => {
					const box = element.getBoundingClientRect();
					return getComputedStyle(element).display !== 'none' && box.width > 0 && box.height > 0;
				}).length,
			sidebarTitleActions: [...document.querySelectorAll('.part.sidebar > .title .title-actions .action-item')].map(element => ({
				label: element.querySelector('.action-label')?.getAttribute('aria-label') ?? element.getAttribute('aria-label'),
				title: element.querySelector('.action-label')?.getAttribute('title') ?? element.getAttribute('title'),
				className: element.querySelector('.action-label')?.className ?? '',
				visible: getComputedStyle(element).display !== 'none' && element.getBoundingClientRect().width > 0 && element.getBoundingClientRect().height > 0
			})),
			breadcrumbsVisible: visible('.breadcrumbs-control'),
			activitybarVisible: visible('.part.activitybar'),
			auxiliarybarVisible: visible('.part.auxiliarybar'),
			statusbarVisible: visible('.part.statusbar'),
			commandCenterVisible: visible('.command-center-center'),
			quickInputVisible: visible('.quick-input-widget'),
			panelTitleVisibility: document.querySelector('.part.panel > .title') ? getComputedStyle(document.querySelector('.part.panel > .title')).visibility : null,
			connectionsHomeTitleVisible: visible('.dbcode-wrapper-connections-home-title'),
			connectionsHomeTitle: document.querySelector('.dbcode-wrapper-connections-home-title')?.textContent?.trim() ?? '',
			connectionsHomeCloseVisible: visible('.dbcode-wrapper-connections-home-close'),
			terminalVisible: [...document.querySelectorAll('.terminal-wrapper, .terminal-instance')].some(element => {
				const box = element.getBoundingClientRect();
				return getComputedStyle(element).display !== 'none' && box.width > 0 && box.height > 0;
			}),
			horizontalOverflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
			iframeSources: [...document.querySelectorAll('iframe')].map(frame => frame.src),
			dbcodeFrames: [...document.querySelectorAll('iframe')]
				.filter(frame => frame.src.includes('extensionId=dbcode.dbcode'))
				.map(frame => frame.getBoundingClientRect().toJSON()),
			visibleEditorGroups,
			emptyEditorGroupCount: visibleEditorGroups.filter(group => group.tabs.length === 0).length,
			sqlEditorTitleActionCount: [...document.querySelectorAll('.editor-group-container.dbcode-wrapper-sql-editor-group > .title .editor-actions .action-item')]
				.filter(element => element.getBoundingClientRect().width > 0 && element.getBoundingClientRect().height > 0).length,
			genericEditorTitleActionCount: [...document.querySelectorAll('.editor-group-container > .title .editor-actions .action-item')]
				.filter(element => {
					const label = element.querySelector('.action-label');
					const generic = label?.classList.contains('codicon-toolbar-more') || label?.classList.contains('codicon-split-horizontal') || label?.classList.contains('codicon-split-vertical');
					return generic && element.getBoundingClientRect().width > 0 && element.getBoundingClientRect().height > 0;
				}).length,
			toolbarActions: [...document.querySelectorAll('.dbcode-wrapper-toolbar button')].map(button => {
				const bounds = button.getBoundingClientRect();
				const visibleText = button.querySelector('.dbcode-wrapper-button-label');
				return {
					action: button.dataset.dbcodeWrapperAction,
					label: button.getAttribute('aria-label'),
					title: button.getAttribute('title'),
					visibleLabel: visibleText && getComputedStyle(visibleText).display !== 'none' ? visibleText.textContent : null,
					pressed: button.getAttribute('aria-pressed'),
					expanded: button.getAttribute('aria-expanded'),
					disabled: button.disabled,
					bounds: bounds.toJSON()
				};
			})
		};
	});
}

function resultLayout(state, queryName) {
	const query = state.visibleEditorGroups.find(group => group.tabs.includes(queryName));
	const results = state.visibleEditorGroups.find(group => group !== query && group.tabs.some(tab => tab === 'DBCode' || /SELECT/i.test(tab)));
	return { query, results };
}

function assertResultsBeside(state, queryName) {
	const layout = resultLayout(state, queryName);
	assert.ok(layout.query, `The ${queryName} editor group is not visible.`);
	assert.ok(layout.results, `The DBCode result editor group is not visible: ${JSON.stringify(state.visibleEditorGroups)}`);
	assert.ok(layout.results.bounds.x >= layout.query.bounds.right - 1, 'DBCode results are not beside the query.');
	assert.ok(Math.abs(layout.results.bounds.y - layout.query.bounds.y) <= 1, 'Beside results do not share the query top edge.');
	return layout;
}

function assertResultsBelow(state, queryName) {
	const layout = resultLayout(state, queryName);
	assert.ok(layout.query, `The ${queryName} editor group is not visible.`);
	assert.ok(layout.results, `The DBCode result editor group is not visible: ${JSON.stringify(state.visibleEditorGroups)}`);
	assert.ok(layout.results.bounds.y >= layout.query.bounds.bottom - 1, 'DBCode results are not below the query.');
	assert.ok(Math.abs(layout.results.bounds.x - layout.query.bounds.x) <= 1, 'Below results do not share the query left edge.');
	return layout;
}

function assertNoResultPositionControls(state) {
	const removedActions = state.toolbarActions.filter(item => item.action === 'results-beside' || item.action === 'results-below');
	assert.deepEqual(removedActions, [], 'The shell still renders a manual result-position control.');
}

async function notificationToastStyle(page) {
	const toast = page.locator('.notifications-toasts .notification-toast').last();
	await toast.waitFor({ state: 'visible', timeout: 5000 });
	return toast.evaluate(element => {
		const style = getComputedStyle(element);
		return {
			backgroundColor: style.backgroundColor,
			borderColor: style.borderColor,
			borderRadius: style.borderRadius,
			boxShadow: style.boxShadow
		};
	});
}

async function visibleContextMenuText(page) {
	return page.evaluate(() => [...document.querySelectorAll('.context-view')]
		.filter(element => {
			const box = element.getBoundingClientRect();
			return getComputedStyle(element).display !== 'none' && box.width > 0 && box.height > 0;
		})
		.map(element => element.textContent ?? '')
		.join(' '));
}

async function captureNativeContextMenu(app, page, trigger, required = true) {
	await app.evaluate(({ Menu }) => {
		const originalPopup = Menu.prototype.popup;
		globalThis.__dbcodeWrapperNativeMenuProbe = {
			originalPopup,
			menus: [],
			error: null
		};
		Menu.prototype.popup = function (options = {}) {
			const serialize = menu => menu.items.map(item => ({
				label: item.label,
				type: item.type,
				enabled: item.enabled,
				visible: item.visible,
				submenu: item.submenu ? serialize(item.submenu) : []
			}));
			globalThis.__dbcodeWrapperNativeMenuProbe.menus.push(serialize(this));
			options.callback?.();
		};
	});

	try {
		await trigger();
		if (!required) await page.waitForTimeout(300);
		const deadline = Date.now() + 3000;
		let snapshot;
			do {
				snapshot = await app.evaluate(() => {
					const probe = globalThis.__dbcodeWrapperNativeMenuProbe;
					return { menus: probe.menus, error: probe.error };
				});
				if (snapshot.menus.length || !required) break;
				await page.waitForTimeout(50);
			} while (Date.now() < deadline);
			assert.equal(snapshot.error, null, snapshot.error);
			if (required) assert.ok(snapshot.menus.length > 0, 'The expected native context menu did not open.');
			return snapshot.menus.flat();
	} finally {
		await app.evaluate(({ Menu }) => {
			const probe = globalThis.__dbcodeWrapperNativeMenuProbe;
			if (probe?.originalPopup) Menu.prototype.popup = probe.originalPopup;
			delete globalThis.__dbcodeWrapperNativeMenuProbe;
		});
	}
}

function nativeMenuText(items) {
	const collect = items => items.flatMap(item => [item.label, ...collect(item.submenu)]);
	return collect(items).join(' ');
}

async function captureNativeToolbarMenu(app, page, action) {
	return captureNativeContextMenu(
		app,
		page,
		() => page.locator(`[data-dbcode-wrapper-action="${action}"]`).click()
	);
}

async function openToolbarMenu(page, action) {
	for (let attempt = 0; attempt < 4; attempt++) {
		const contextMenuVisible = await page.evaluate(() => [...document.querySelectorAll('.context-view')].some(element => {
			const box = element.getBoundingClientRect();
			return getComputedStyle(element).display !== 'none' && box.width > 0 && box.height > 0;
		}));
		if (!contextMenuVisible) break;
		await page.keyboard.press('Escape');
		await page.waitForTimeout(100);
	}
	await page.locator(`[data-dbcode-wrapper-action="${action}"]`).click();
	await page.waitForFunction(() => [...document.querySelectorAll('.context-view')].some(element => {
		const box = element.getBoundingClientRect();
		return getComputedStyle(element).display !== 'none' && box.width > 0 && box.height > 0;
	}));
	await page.waitForTimeout(150);
	return visibleContextMenuText(page);
}

async function ensureDrawerOpen(page, button) {
	const drawerState = await page.locator('.monaco-workbench').getAttribute('data-dbcode-wrapper-drawer');
	if (drawerState !== 'open') {
		await button.click();
	}
	await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawer === 'open');
}

async function expandTreeRow(page, labelPattern) {
	const row = page.locator('.part.sidebar .monaco-list-row').filter({ hasText: labelPattern }).first();
	try {
		await row.waitFor({ state: 'visible', timeout: 15000 });
	} catch (error) {
		const visibleRows = await page.locator('.part.sidebar .monaco-list-row').allTextContents();
		throw new Error(`DBCode tree row ${String(labelPattern)} was not visible. Available rows: ${JSON.stringify(visibleRows)}. ${error.message}`);
	}
	const twistie = row.locator('.monaco-tl-twistie').first();
	if (await twistie.count() && (await twistie.getAttribute('class'))?.includes('collapsed')) {
		await twistie.click();
	}
	return row;
}

async function deepFrameText(frame) {
	return frame.locator('body').evaluate(body => {
		const collect = root => {
			let value = root.textContent ?? '';
			for (const element of root.querySelectorAll('*')) {
				if (element.shadowRoot) {
					value += collect(element.shadowRoot);
				}
			}
			return value;
		};
		return collect(body).replace(/\s+/g, ' ').trim();
	});
}

async function findDbcodePanelFrame(page, expectedText, timeout = 30000) {
	const deadline = Date.now() + timeout;
	while (Date.now() < deadline) {
		for (const frame of page.frames()) {
			if (frame === page.mainFrame() || !await frame.locator('dbc-panel').count().catch(() => 0)) {
				continue;
			}
			const text = await deepFrameText(frame).catch(() => '');
			if (!expectedText || expectedText.test(text)) {
				return { frame, text };
			}
		}
		await page.waitForTimeout(300);
	}
	throw new Error(`DBCode did not render the expected panel content: ${String(expectedText)}.`);
}

async function findProfileSetupFrame(page, expectedText, timeout = 30000) {
	const deadline = Date.now() + timeout;
	while (Date.now() < deadline) {
		for (const frame of page.frames()) {
			if (frame === page.mainFrame()) {
				continue;
			}
			const text = await deepFrameText(frame).catch(() => '');
			if (expectedText.test(text)) {
				return { frame, text };
			}
		}
		await page.waitForTimeout(200);
	}
	throw new Error(`Profile Setup did not render the expected content: ${String(expectedText)}.`);
}

async function waitForProfileSetupToClose(page, timeout = 15000) {
	const deadline = Date.now() + timeout;
	while (Date.now() < deadline) {
		let visible = false;
		for (const frame of page.frames()) {
			if (frame === page.mainFrame()) continue;
			const text = await deepFrameText(frame).catch(() => '');
			if (/Standalone DBCode Profile setup|Set up your Standalone DBCode Profile|Profile setup is complete/i.test(text)) {
				visible = true;
				break;
			}
		}
		if (!visible) return;
		await page.waitForTimeout(200);
	}
	throw new Error('Profile Setup did not close.');
}

async function reviewMigrationInventory(app, page) {
	const welcome = await findProfileSetupFrame(page, /Set up your Standalone DBCode Profile/i);
	const dialogCalls = await withOpenDialogProbe(app, { canceled: false, filePaths: [migrationInventoryPath] }, async () => {
		await welcome.frame.getByRole('button', { name: /Review an import file/i }).click();
		await findProfileSetupFrame(page, /Review connection details/i);
	});
	assert.equal(dialogCalls.length, 1, 'Profile Setup must open exactly one native inventory picker.');
	assert.deepEqual(dialogCalls[0].filters, [{ name: 'Connection inventories', extensions: ['json', 'csv'] }]);
	assert.ok(dialogCalls[0].properties.includes('openFile'));
	assert.ok(!dialogCalls[0].properties.includes('openDirectory'));
	const preview = await findProfileSetupFrame(page, /Review connection details/i);
	assert.match(preview.text, /2\s*Ready for DBCode/i);
	assert.match(preview.text, /2\s*Need DuckDB preflight/i);
	assert.match(preview.text, /Rendered PostgreSQL/i);
	assert.match(preview.text, /Rendered Parquet/i);
	assert.match(preview.text, /Rendered hyphen DuckDB/i);
	assert.match(preview.text, new RegExp(migrationDuckdbPath.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
	assert.match(preview.text, /Passwords, tokens, private keys, licence data, and old connection identifiers are never migrated/i);
	return preview;
}

async function findNotebookPythonOutput(page, expectedText, timeout = 30000) {
	const deadline = Date.now() + timeout;
	let renderedFrames = [];
	while (Date.now() < deadline) {
		renderedFrames = [];
		for (const frame of page.frames()) {
			if (frame === page.mainFrame()) {
				continue;
			}
			const outputs = await frame.locator('.output').allInnerTexts().catch(() => []);
			if (outputs.length > 0) {
				renderedFrames.push({ url: frame.url(), outputs: outputs.map(text => text.slice(0, 500)) });
			}
			for (const output of outputs) {
				const text = output.replace(/\s+/g, ' ').trim();
				if (expectedText.test(text)) {
					return { url: frame.url(), text };
				}
			}
		}
		await page.waitForTimeout(200);
	}
	throw new Error(`DBCode did not render the expected Python output: ${String(expectedText)}. Frames: ${JSON.stringify(renderedFrames)}`);
}

async function clickVisibleButtonAcrossFrames(page, name) {
	for (const frame of page.frames()) {
		const button = frame.getByRole('button', { name }).first();
		if (await button.isVisible().catch(() => false)) {
			await button.click();
			return true;
		}
	}
	return false;
}

async function acceptDbcodeTermsIfOffered(page, timeout = 5000) {
	const deadline = Date.now() + timeout;
	while (Date.now() < deadline) {
		if (await clickVisibleButtonAcrossFrames(page, /^Agree$/i)) {
			await page.waitForTimeout(750);
			return true;
		}
		await page.waitForTimeout(200);
	}
	return false;
}

async function openConnectionsHome(page, button) {
	if (await page.locator('.monaco-workbench').getAttribute('data-dbcode-wrapper-connections-home') !== 'open') {
		await button.click();
	}
	await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperConnectionsHome === 'open');
	return findDbcodePanelFrame(page, /New connection/i);
}

async function closeConnectionsHome(page) {
	if (await page.locator('.monaco-workbench').getAttribute('data-dbcode-wrapper-connections-home') === 'open') {
		await page.locator('.dbcode-wrapper-connections-home-close').click();
	}
	await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperConnectionsHome === 'closed');
}

async function captureConnectionCatalogueSnapshot(page, timeout = 20000) {
	const deadline = Date.now() + timeout;
	while (Date.now() < deadline) {
		for (const frame of page.frames()) {
			if (!frame.url().includes('/fake.html')) continue;
			const sections = await frame.evaluate(() => {
				const connectionUi = document.querySelector('connection-ui');
				const picker = connectionUi?.shadowRoot?.querySelector('connection-picker');
				const pickerRoot = picker?.shadowRoot;
				if (!pickerRoot) return null;

				const renderedSections = [];
				let currentSection = null;
				for (const element of pickerRoot.querySelectorAll('.sec-h, .count, .nm')) {
					const text = (element.textContent ?? '').replace(/\s+/g, ' ').trim();
					if (element.classList.contains('sec-h')) {
						currentSection = { title: text, declaredCount: null, labels: [] };
						renderedSections.push(currentSection);
					} else if (currentSection && element.classList.contains('count')) {
						currentSection.declaredCount = Number(text);
					} else if (currentSection && element.classList.contains('nm')) {
						currentSection.labels.push(text);
					}
				}
				return renderedSections.filter(section => Number.isSafeInteger(section.declaredCount));
			}).catch(() => null);
			if (sections?.length) {
				return createConnectionCatalogueSnapshot({
					extensionId: featurePolicy.extension.id,
					extensionVersion: featurePolicy.extension.version,
					sections
				});
			}
		}
		await page.waitForTimeout(250);
	}
	throw new Error('DBCode did not expose a counted New Connection catalogue before the rendered-proof timeout.');
}

function verifyRenderedConnectionCatalogue(snapshot) {
	return verifyConnectionCatalogueSnapshot(
		snapshot,
		featurePolicy.connection_capability_contract.catalogue_snapshot
	);
}

async function connectionCatalogueSnapshotProof() {
	fs.mkdirSync(qaRoot, { recursive: true });
	const profileRoot = fs.mkdtempSync(path.join(qaRoot, 'c-'));
	const args = profileArgs(profileRoot, qaExtensions);
	fs.copyFileSync(path.join(repoRoot, 'host/profile/settings.json'), path.join(profileRoot, 'user-data/User/settings.json'));
	let session;
	try {
		session = await launch(productionExecutable, commonArgs(args));
		const { app, page } = session;
		await waitForFocusedShell(app, page);
		const welcome = await findProfileSetupFrame(page, /Set up your Standalone DBCode Profile/i);
		await welcome.frame.getByRole('button', { name: /Start fresh/i }).click();
		const complete = await findProfileSetupFrame(page, /Profile setup is complete/i);
		await complete.frame.getByRole('button', { name: 'Close', exact: true }).click();
		await waitForProfileSetupToClose(page);
		const connections = page.locator('[data-dbcode-wrapper-action="connections"]');
		await openConnectionsHome(page, connections);
		assert.equal(await clickVisibleButtonAcrossFrames(page, /New connection/i), true);
		const snapshot = await captureConnectionCatalogueSnapshot(page);
		verifyRenderedConnectionCatalogue(snapshot);
		record('unchanged DBCode exposes the complete reviewed New Connection catalogue', {
			catalogue: snapshot,
			wrapperDatabaseAllowlist: false,
			rawLabelsStored: false
		});
	} finally {
		if (session) {
			session.stopDiagnostics();
			await session.app.close().catch(() => undefined);
		}
		fs.rmSync(profileRoot, { recursive: true, force: true });
	}
}

async function dismissQuickInput(page) {
	const quickInput = page.locator('.quick-input-widget');
	for (let attempt = 0; attempt < 8 && await quickInput.isVisible(); attempt++) {
		await page.keyboard.press('Escape');
		await page.waitForTimeout(200);
	}
	assert.equal(await quickInput.isVisible(), false, 'A completed DBCode workflow left a quick picker open.');
}

async function chooseQaPythonKernel(page) {
	const quickInput = page.locator('.quick-input-widget');
	const steps = [];
	const deadline = Date.now() + 60000;
	for (let attempt = 0; attempt < 6 && Date.now() < deadline;) {
		const kernelReady = await page.locator('.notifications-toasts .notification-toast')
			.filter({ hasText: /Python kernel ready\./ })
			.isVisible()
			.catch(() => false);
		if (kernelReady) {
			steps.push('Previously selected kernel started without another picker.');
			return steps;
		}
		if (!await quickInput.isVisible().catch(() => false)) {
			await page.waitForTimeout(250);
			continue;
		}
		attempt++;
		const text = (await quickInput.innerText()).replace(/\s+/g, ' ').trim();
		steps.push(text);
		const qaKernel = quickInput.locator('.monaco-list-row')
			.filter({ hasText: /DBCode Wrapper QA \(Python\)|python-kernel-ipykernel-7\.3\.0/i })
			.first();
		if (await qaKernel.isVisible().catch(() => false)) {
			await qaKernel.click();
			return steps;
		}

		let nextChoice;
		for (const label of [/Select Another Kernel/i, /Jupyter Kernel/i, /Local Kernel Specs/i, /Python Environments/i]) {
			const candidate = quickInput.locator('.monaco-list-row').filter({ hasText: label }).first();
			if (await candidate.isVisible().catch(() => false)) {
				nextChoice = candidate;
				break;
			}
		}
		if (!nextChoice) {
			throw new Error(`The focused kernel setup could not reach the isolated QA kernel: ${JSON.stringify(steps)}`);
		}
		await nextChoice.click();
		await page.waitForTimeout(500);
	}
	throw new Error(`The focused kernel setup did not start the isolated QA kernel: ${JSON.stringify(steps)}`);
}

async function approveSampleConnectionIfOffered(page, timeout = 10000) {
	const quickInput = page.locator('.quick-input-widget');
	const deadline = Date.now() + timeout;
	const steps = [];
	let approvals = 0;
	let hiddenChecks = 0;

	while (Date.now() < deadline) {
		if (!await quickInput.isVisible().catch(() => false)) {
			if (approvals > 0) {
				hiddenChecks++;
				if (hiddenChecks >= 3) {
					return { approved: true, approvals, steps };
				}
			}
			await page.waitForTimeout(200);
			continue;
		}

		hiddenChecks = 0;
		const text = (await quickInput.innerText()).replace(/\s+/g, ' ').trim();
		const rows = quickInput.locator('.monaco-list-row');
		let target = rows.filter({ hasText: /main.*sakila\.db/i }).first();
		if (!await target.isVisible().catch(() => false)) {
			target = rows.filter({ hasText: /Sample - SQLite/i }).first();
		}
		if (!await target.isVisible().catch(() => false)) {
			if (approvals === 0) {
				return { approved: false, approvals, steps };
			}
			return { approved: true, approvals, steps };
		}

		steps.push(text);
		await target.click();
		approvals++;
		await page.waitForTimeout(350);
	}

	return { approved: approvals > 0, approvals, steps };
}

async function approveDbcodeKernelAccessIfOffered(app, action, timeout = 30000) {
	await app.evaluate(({ dialog }) => {
		const original = dialog.showMessageBox;
		globalThis.__dbcodeWrapperKernelAccessProbe = { original, calls: [] };
		dialog.showMessageBox = async (...args) => {
			const options = args.at(-1);
			const message = `${options?.message ?? ''} ${options?.detail ?? ''}`;
			if (/grant Kernel access.*dbcode\.dbcode/i.test(message)) {
				const buttons = options.buttons ?? [];
				const response = buttons.findIndex(label => label.replaceAll('&', '').trim().toLowerCase() === 'allow');
				globalThis.__dbcodeWrapperKernelAccessProbe.calls.push({
					message: options.message,
					detail: options.detail,
					buttons,
					response
				});
				if (response >= 0) {
					return { response, checkboxChecked: false };
				}
			}
			return original.apply(dialog, args);
		};
	});

	try {
		await action();
		const deadline = Date.now() + timeout;
		while (Date.now() < deadline) {
			const calls = await app.evaluate(() => globalThis.__dbcodeWrapperKernelAccessProbe?.calls ?? []);
			if (calls.length > 0) {
				const call = calls[0];
				assert.match(`${call.message} ${call.detail}`, /execute code against Jupyter Kernels/i);
				assert.ok(call.response >= 0, `The native DBCode kernel permission did not offer Allow: ${JSON.stringify(call.buttons)}`);
				return { approved: true, ...call };
			}
			await new Promise(resolve => setTimeout(resolve, 100));
		}
		return { approved: false, message: null, detail: null, buttons: [], response: -1 };
	} finally {
		await app.evaluate(({ dialog }) => {
			const probe = globalThis.__dbcodeWrapperKernelAccessProbe;
			if (probe?.original) dialog.showMessageBox = probe.original;
			delete globalThis.__dbcodeWrapperKernelAccessProbe;
		});
	}
}

async function withOpenDialogProbe(app, response, action) {
	await app.evaluate(({ dialog }, probeResponse) => {
		globalThis.__dbcodeWrapperDialogProbe = {
			original: dialog.showOpenDialog,
			calls: [],
			response: probeResponse
		};
		dialog.showOpenDialog = async (...args) => {
			globalThis.__dbcodeWrapperDialogProbe.calls.push(args.at(-1));
			return globalThis.__dbcodeWrapperDialogProbe.response;
		};
	}, response);

	let calls;
	try {
		await action();
	} finally {
		calls = await app.evaluate(({ dialog }) => {
			const probe = globalThis.__dbcodeWrapperDialogProbe;
			if (probe?.original) {
				dialog.showOpenDialog = probe.original;
			}
			delete globalThis.__dbcodeWrapperDialogProbe;
			return probe?.calls ?? [];
		});
	}
	return calls;
}

async function withMessageBoxChoices(app, choices, action) {
	await app.evaluate(({ dialog }, selectedButtons) => {
		globalThis.__dbcodeWrapperMessageBoxProbe = {
			original: dialog.showMessageBox,
			calls: [],
			selectedButtons
		};
		dialog.showMessageBox = async (...args) => {
			const probe = globalThis.__dbcodeWrapperMessageBoxProbe;
			const options = args.at(-1);
			const selection = probe.selectedButtons[probe.calls.length];
			const selectedButton = typeof selection === 'string' ? selection : selection?.button;
			const buttons = options?.buttons ?? [];
			const response = selectedButton === undefined
				? -1
				: buttons.findIndex(label => label.replaceAll('&', '').trim().toLowerCase() === selectedButton.toLowerCase());
			probe.calls.push({
				message: options?.message ?? '',
				detail: options?.detail ?? '',
				buttons,
				selectedButton,
				response,
				held: Boolean(selection?.hold)
			});
			if (response >= 0) {
				if (selection?.hold) {
					return new Promise(resolve => {
						probe.release = () => {
							delete probe.release;
							resolve({ response, checkboxChecked: false });
						};
					});
				}
				return { response, checkboxChecked: false };
			}
			return probe.original.apply(dialog, args);
		};
	}, choices);

	let calls;
	try {
		await action();
	} finally {
		calls = await app.evaluate(({ dialog }) => {
			const probe = globalThis.__dbcodeWrapperMessageBoxProbe;
			if (probe?.original) dialog.showMessageBox = probe.original;
			delete globalThis.__dbcodeWrapperMessageBoxProbe;
			return probe?.calls ?? [];
		});
	}
	return calls;
}

async function waitForApplicationExit(app, timeout = 30000) {
	const child = app.process();
	if (child.exitCode !== null) return child.exitCode;
	return new Promise((resolve, reject) => {
		const timer = setTimeout(() => {
			child.off('exit', onExit);
			reject(new Error('DBCode Wrapper did not quit for Standalone DBCode Profile recovery.'));
		}, timeout);
		const onExit = code => {
			clearTimeout(timer);
			resolve(code);
		};
		child.once('exit', onExit);
	});
}

async function approveProfileRecovery(app, action) {
	await app.evaluate(({ dialog }) => {
		globalThis.__dbcodeWrapperRecoveryDialogProbe = {
			original: dialog.showMessageBox,
			calls: []
		};
		dialog.showMessageBox = async (...args) => {
			const probe = globalThis.__dbcodeWrapperRecoveryDialogProbe;
			const options = args.at(-1);
			if (!/Back up and recreate the Standalone DBCode Profile/i.test(options?.message ?? '')) {
				return probe.original.apply(dialog, args);
			}
			const buttons = options?.buttons ?? [];
			const response = buttons.findIndex(label => label.replaceAll('&', '').trim() === 'Back Up and Recreate Profile');
			probe.calls.push({
				message: options.message,
				detail: options.detail ?? '',
				buttons,
				response
			});
			return new Promise(resolve => {
				probe.release = () => {
					delete probe.release;
					resolve({ response, checkboxChecked: false });
				};
			});
		};
	});

	await action();
	let calls = [];
	for (let attempt = 0; attempt < 100; attempt++) {
		calls = await app.evaluate(() => globalThis.__dbcodeWrapperRecoveryDialogProbe?.calls ?? []);
		if (calls.length > 0) break;
		await new Promise(resolve => setTimeout(resolve, 100));
	}
	assert.equal(calls.length, 1, 'Profile recovery did not show exactly one native confirmation.');
	assert.match(calls[0].detail, /move only its user and shared profile data into an owner-only backup/i);
	assert.match(calls[0].detail, /Normal VS Code, Keychain records, verified extensions, and database files are not changed/i);
	assert.ok(calls[0].response >= 0, 'The native profile recovery confirmation did not offer its explicit approval action.');

	const exit = waitForApplicationExit(app);
	assert.equal(await app.evaluate(() => {
		const release = globalThis.__dbcodeWrapperRecoveryDialogProbe?.release;
		if (!release) return false;
		release();
		return true;
	}), true, 'The profile recovery confirmation was not waiting for explicit approval.');
	assert.equal(await exit, 0, 'DBCode Wrapper did not quit cleanly for profile recovery.');
	return calls[0];
}

function processExists(pid) {
	try {
		process.kill(pid, 0);
		return true;
	} catch (error) {
		return error?.code === 'EPERM';
	}
}

function profileApplicationProcesses(userDataRoot) {
	const processList = execFileSync('/bin/ps', ['-axo', 'pid=,command='], { encoding: 'utf8' });
	return processList.split('\n').flatMap(line => {
		const match = line.match(/^\s*(\d+)\s+(.+)$/);
		if (!match) return [];
		const pid = Number(match[1]);
		const command = match[2];
		return command.includes(productionExecutable)
			&& command.includes('--user-data-dir')
			&& command.includes(userDataRoot)
			? [{ pid, command }]
			: [];
	});
}

async function waitForAutomaticProfileRelaunch(userDataRoot, timeout = 60000) {
	const deadline = Date.now() + timeout;
	while (Date.now() < deadline) {
		const matches = profileApplicationProcesses(userDataRoot);
		if (matches.length === 1) return matches[0];
		if (matches.length > 1) {
			throw new Error(`Profile recovery opened more than one DBCode Wrapper process: ${JSON.stringify(matches)}`);
		}
		await new Promise(resolve => setTimeout(resolve, 200));
	}
	throw new Error('Profile recovery did not automatically reopen DBCode Wrapper with the recreated profile.');
}

async function waitForPathToDisappear(target, timeout = 30000) {
	const deadline = Date.now() + timeout;
	while (Date.now() < deadline) {
		if (!fs.existsSync(target)) return;
		await new Promise(resolve => setTimeout(resolve, 100));
	}
	throw new Error(`Timed out waiting for ${target} to be consumed.`);
}

async function waitForRecoveryBackup(backupRoot, timeout = 60000) {
	const deadline = Date.now() + timeout;
	while (Date.now() < deadline) {
		if (fs.existsSync(backupRoot)) {
			for (const entry of fs.readdirSync(backupRoot, { withFileTypes: true })) {
				const backupDirectory = path.join(backupRoot, entry.name);
				const manifestPath = path.join(backupDirectory, 'recovery.json');
				if (entry.isDirectory() && fs.existsSync(manifestPath)) {
					return { backupDirectory, manifest: JSON.parse(fs.readFileSync(manifestPath, 'utf8')) };
				}
			}
		}
		await new Promise(resolve => setTimeout(resolve, 100));
	}
	throw new Error(`Timed out waiting for an owner-only recovery backup below ${backupRoot}.`);
}

async function terminateExactProfileProcess(pid, userDataRoot, timeout = 30000) {
	const exactMatch = profileApplicationProcesses(userDataRoot).find(processRecord => processRecord.pid === pid);
	if (!exactMatch) return;
	process.kill(pid, 'SIGTERM');
	const deadline = Date.now() + timeout;
	while (Date.now() < deadline) {
		if (!processExists(pid)) return;
		await new Promise(resolve => setTimeout(resolve, 100));
	}
	throw new Error(`Automatically relaunched DBCode Wrapper process ${pid} did not quit after SIGTERM.`);
}

async function withShowItemInFolderProbe(app, action) {
	await app.evaluate(({ shell }) => {
		globalThis.__dbcodeWrapperShowItemProbe = {
			original: shell.showItemInFolder,
			calls: []
		};
		shell.showItemInFolder = pathToShow => {
			globalThis.__dbcodeWrapperShowItemProbe.calls.push(pathToShow);
		};
	});

	try {
		await action();
		for (let attempt = 0; attempt < 30; attempt++) {
			const calls = await app.evaluate(() => globalThis.__dbcodeWrapperShowItemProbe?.calls ?? []);
			if (calls.length > 0) {
				return calls;
			}
			await new Promise(resolve => setTimeout(resolve, 100));
		}
		return [];
	} finally {
		await app.evaluate(({ shell }) => {
			const probe = globalThis.__dbcodeWrapperShowItemProbe;
			if (probe?.original) {
				shell.showItemInFolder = probe.original;
			}
			delete globalThis.__dbcodeWrapperShowItemProbe;
		});
	}
}

function capturedExternalReleaseLinks() {
	if (!fs.existsSync(externalReleaseLinkCapturePath)) return [];
	return fs.readFileSync(externalReleaseLinkCapturePath, 'utf8')
		.split(/\r?\n/)
		.filter(Boolean);
}

async function waitForCapturedExternalReleaseLink(previousCount, timeout = 10000) {
	const deadline = Date.now() + timeout;
	while (Date.now() < deadline) {
		const calls = capturedExternalReleaseLinks();
		if (calls.length > previousCount) return calls;
		await new Promise(resolve => setTimeout(resolve, 100));
	}
	return capturedExternalReleaseLinks();
}

async function closeDbcodeResultEditor(page) {
	const resultTab = page.locator('.editor-group-container .tab').filter({ hasText: /^DBCode$/ }).first();
	await resultTab.waitFor({ state: 'visible', timeout: 15000 });
	const close = resultTab.locator('.codicon-close').first();
	if (await close.count()) {
		await close.click();
	} else {
		await resultTab.click({ button: 'middle' });
	}
	await page.waitForFunction(() => [...document.querySelectorAll('.editor-group-container .tab .label-name')]
		.every(tab => tab.textContent?.trim() !== 'DBCode'));
}

async function closeModalEditor(page) {
	const modal = page.locator('.monaco-modal-editor-block');
	await modal.waitFor({ state: 'visible', timeout: 15000 });
	const close = modal.locator('[aria-label="Close Modal Editor"], [title="Close Modal Editor"], .codicon-close').last();
	await close.click();
	await modal.waitFor({ state: 'hidden', timeout: 15000 });
}

async function openFilteredDbcodeSettings(page) {
	await openToolbarMenu(page, 'tools');
	await page.getByRole('menuitem', { name: 'DBCode Settings…', exact: true }).click();
	const settingsEditor = page.locator('.settings-editor').last();
	await settingsEditor.waitFor({ state: 'visible', timeout: 15000 });
	await page.waitForFunction(() => document.querySelector('.settings-editor .settings-header .view-lines')
		?.textContent?.includes('@ext:dbcode.dbcode'), null, { timeout: 15000 });
	const text = (await settingsEditor.innerText()).replace(/\s+/g, ' ');
	assert.match(text, /DBCode/i);
	return text;
}

async function verifyDbcodeQuickInputTool(page, label, expectedText) {
	await openToolbarMenu(page, 'tools');
	await page.getByRole('menuitem', { name: label, exact: true }).click();
	const quickInput = page.locator('.quick-input-widget');
	await quickInput.waitFor({ state: 'visible', timeout: 15000 });
	const text = (await quickInput.innerText()).replace(/\s+/g, ' ').trim();
	assert.match(text, expectedText, `${label} did not open the expected DBCode workflow.`);
	await page.keyboard.press('Escape');
	await dismissQuickInput(page);
	return text;
}

async function importHyphenDuckdbForPreflight(app, page) {
	const connections = page.locator('[data-dbcode-wrapper-action="connections"]');
	await openConnectionsHome(page, connections);
	let importMessages;
	const dialogCalls = await withOpenDialogProbe(app, { canceled: false, filePaths: [migrationDuckdbImportPath] }, async () => {
		assert.equal(await clickVisibleButtonAcrossFrames(page, /Import connections/i), true, 'Connections Home did not expose DBCode Import for the DuckDB preflight.');
		const picker = page.locator('.quick-input-widget');
		await picker.waitFor({ state: 'visible', timeout: 15000 });
		importMessages = await withMessageBoxChoices(app, ['Import'], async () => {
			const csvSource = picker.locator('.monaco-list-row').filter({ hasText: /CSV/i }).first();
			assert.equal(await csvSource.isVisible(), true, 'DBCode Import did not offer CSV for the DuckDB preflight.');
			await csvSource.click();
			const customFormat = picker.locator('.monaco-list-row').filter({ hasText: /Custom Format/i }).first();
			await customFormat.waitFor({ state: 'visible', timeout: 15000 });
			await customFormat.click();
			for (const [sourceField, targetField] of [
				['name', 'name'],
				['type', 'driver'],
				['path', 'socket'],
				['connectionType', 'connectionType']
			]) {
				await page.waitForFunction(field => {
					const quickInput = document.querySelector('.quick-input-widget');
					const text = (quickInput?.textContent ?? '').replace(/\s+/g, ' ').trim().toLowerCase();
					return text.includes(`map source field: ${field.toLowerCase()}`);
				}, sourceField, { timeout: 15000 });
				const target = picker.getByText(targetField, { exact: true }).first();
				assert.equal(await target.isVisible(), true, `DBCode CSV import did not offer ${targetField} for the DuckDB preflight.`);
				await target.click();
			}
			for (let attempt = 0; attempt < 100; attempt++) {
				if (await app.evaluate(() => (globalThis.__dbcodeWrapperMessageBoxProbe?.calls.length ?? 0) >= 1)) break;
				await page.waitForTimeout(100);
			}
		});
	});
	assert.equal(dialogCalls.length, 1, 'DBCode DuckDB preflight import did not use exactly one native file picker.');
	assert.equal(importMessages.length, 1, 'DBCode DuckDB preflight import did not show exactly one reviewed confirmation.');
	assert.match(importMessages[0].message, /1 connection\(s\) found/i);
	assert.equal(importMessages[0].selectedButton, 'Import');
	await closeConnectionsHome(page);

	const explorer = page.locator('[data-dbcode-wrapper-action="database-explorer"]');
	await explorer.click();
	await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawer === 'open');
	await page.locator('.part.sidebar .monaco-list-row').filter({ hasText: /Rendered-Hyphen-DuckDB/i }).first().waitFor({ state: 'visible', timeout: 15000 });
	await explorer.click();
	await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawer === 'closed');
}

async function runHyphenDuckdbReadOnlyPreflight(page) {
	const digestBefore = crypto.createHash('sha256').update(fs.readFileSync(migrationDuckdbPath)).digest('hex');
	assert.equal(digestBefore, migrationDuckdbDigest, 'The hyphen-path DuckDB fixture changed before its preflight.');
	const scratchTab = page.locator('.tab').filter({ hasText: /^scratch\.sql$/i }).first();
	await scratchTab.click();
	await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperQueryName === 'scratch.sql');
	const editor = page.locator('.editor-group-container.dbcode-wrapper-sql-editor-group .monaco-editor').last();
	await editor.locator('.view-line').first().click();
	await page.keyboard.press('Meta+A');
	await page.keyboard.insertText('SELECT 1 AS dbcode_wrapper_read_only_preflight;');
	await page.keyboard.press('Control+Shift+Meta+O');

	const picker = page.locator('.quick-input-widget');
	const pickerSnapshots = [];
	const acceptDuckdbPicker = async waitSteps => {
		let selectedConnection = false;
		let hiddenSteps = 0;
		for (let waitStep = 0; waitStep < waitSteps; waitStep++) {
			if (!await picker.isVisible().catch(() => false)) {
				if (selectedConnection) {
					hiddenSteps++;
					if (hiddenSteps >= 4) break;
				}
				await page.waitForTimeout(250);
				continue;
			}
			hiddenSteps = 0;
			const pickerText = (await picker.innerText()).replace(/\s+/g, ' ').trim();
			pickerSnapshots.push(pickerText);
			if (/\b0 Results\b/i.test(pickerText)) {
				await page.waitForTimeout(300);
				continue;
			}
			const rows = picker.locator('.monaco-list-row');
			let target = rows.filter({ hasText: /Rendered-Hyphen-DuckDB/i }).first();
			if (!await target.isVisible().catch(() => false)) {
				target = rows.filter({ hasText: /main|rendered-proof-with-hyphen\.duckdb/i }).first();
			}
			if (!await target.isVisible().catch(() => false)) {
				await page.waitForTimeout(250);
				continue;
			}
			await target.click();
			selectedConnection = true;
			await page.waitForTimeout(350);
		}
		return selectedConnection;
	};
	let selectedConnection = await acceptDuckdbPicker(40);
	if (!selectedConnection && (await page.locator('.part.editor').innerText()).includes('Select a connection')) {
		await page.getByText('Select a connection', { exact: true }).last().click();
		selectedConnection = await acceptDuckdbPicker(40);
	}
	if (await picker.isVisible().catch(() => false)) await dismissQuickInput(page);
	if (!selectedConnection) {
		const snapshot = {
			pickerSnapshots,
			activeTabs: await page.locator('.tab.active .label-name').allTextContents(),
			editorText: (await page.locator('.part.editor').innerText()).replace(/\s+/g, ' ').slice(0, 800),
			notifications: await page.locator('.notifications-toasts').allTextContents()
		};
		throw new Error(`DBCode did not offer the manually imported DuckDB connection for its read-only preflight: ${JSON.stringify(snapshot)}`);
	}
	await editor.locator('.view-line').first().click();
	await page.keyboard.press('Control+Enter');
	const handledExecutionPicker = await acceptDuckdbPicker(16);
	if (await picker.isVisible().catch(() => false)) await dismissQuickInput(page);
	if (handledExecutionPicker) {
		await editor.locator('.view-line').first().click();
		await page.keyboard.press('Control+Enter');
	}

	let passed = false;
	let resultText = '';
	try {
		const result = await findDbcodePanelFrame(page, /dbcode_wrapper_read_only_preflight/i, 30000);
		resultText = result.text.replace(/\s+/g, ' ').trim();
		assert.match(resultText, /dbcode_wrapper_read_only_preflight/i);
		assert.match(resultText, /\b1\b/);
		passed = true;
	} catch {
		const latePickerText = await picker.isVisible().catch(() => false)
			? (await picker.innerText()).replace(/\s+/g, ' ').trim()
			: '';
		resultText = [
			latePickerText,
			...(await page.locator('.notifications-toasts .notification-toast').allTextContents()),
			(await page.locator('.part.editor').innerText()).replace(/\s+/g, ' ').trim()
		].join(' ').slice(0, 1200);
	}
	if (await picker.isVisible().catch(() => false)) await dismissQuickInput(page);
	const digestAfter = crypto.createHash('sha256').update(fs.readFileSync(migrationDuckdbPath)).digest('hex');
	assert.equal(digestAfter, digestBefore, 'DBCode changed the DuckDB file during the read-only preflight.');
	return { passed, resultText, digest: digestAfter, pickerSnapshots };
}

async function executeProjectQuery(page) {
	const sqlEditor = page.locator('.editor-group-container.dbcode-wrapper-sql-editor-group .monaco-editor').last();
	const triggerExecution = async () => {
		await sqlEditor.locator('.view-line').first().click();
		await page.keyboard.press('Meta+A');
		await page.keyboard.press('Control+Enter');
	};
	await triggerExecution();
	const quickInput = page.locator('.quick-input-widget');
	let selectedConnection = false;
	const quickPickSnapshots = [];
	const acceptConnectionPicker = async waitSteps => {
		let accepted = false;
		let hiddenSteps = 0;
		for (let waitStep = 0; waitStep < waitSteps; waitStep++) {
			if (await quickInput.isVisible()) {
				hiddenSteps = 0;
				const quickPickText = (await quickInput.innerText()).replace(/\s+/g, ' ').trim();
				quickPickSnapshots.push(quickPickText);
				if (/\b0 Results\b/i.test(quickPickText)) {
					await page.waitForTimeout(300);
					continue;
				}
				const rows = quickInput.locator('.monaco-list-row');
				let target = rows.filter({ hasText: /main.*sakila\.db/i }).first();
				if (!await target.isVisible().catch(() => false)) {
					target = rows.filter({ hasText: /Sample - SQLite/i }).first();
				}
				if (await target.isVisible().catch(() => false)) {
					await target.click();
				} else {
					await page.keyboard.press('Enter');
				}
				accepted = true;
				await page.waitForTimeout(350);
				continue;
			}
			if (accepted) {
				hiddenSteps++;
				if (hiddenSteps >= 4) {
					break;
				}
			}
			await page.waitForTimeout(250);
		}
		return accepted;
	};
	selectedConnection = await acceptConnectionPicker(40);
	if (!selectedConnection && (await page.locator('.part.editor').innerText()).includes('Select a connection')) {
		await page.getByText('Select a connection', { exact: true }).last().click();
		selectedConnection = await acceptConnectionPicker(40);
	}
	if (await quickInput.isVisible()) {
		const currentQuickPick = (await quickInput.innerText()).replace(/\s+/g, ' ').trim();
		throw new Error('DBCode still requested a connection choice after the available sample selections were accepted: ' + JSON.stringify({ quickPickSnapshots, currentQuickPick }));
	}
	if (selectedConnection) {
		await page.waitForFunction(() => document.querySelector('.part.editor')?.textContent?.includes('Sample - SQLite'));
		await triggerExecution();
	}
	try {
		return await findDbcodePanelFrame(page, /project_query_proof/i, 10000);
	} catch {
		await triggerExecution();
		try {
			return await findDbcodePanelFrame(page, /project_query_proof/i, 30000);
		} catch (error) {
			const snapshot = {
				quickPickSnapshots,
				activeTabs: await page.locator('.tab.active .label-name').allTextContents(),
				editorText: (await page.locator('.part.editor').innerText()).replace(/\s+/g, ' ').slice(0, 800),
				notifications: await page.locator('.notifications-toasts').allTextContents(),
				frames: []
			};
			for (const frame of page.frames()) {
				if (frame !== page.mainFrame()) {
					snapshot.frames.push((await deepFrameText(frame).catch(() => '')).slice(0, 800));
				}
			}
			throw new Error('DBCode query did not produce the proof grid: ' + JSON.stringify(snapshot) + '. ' + error.message);
		}
	}
}

async function openSampleActorTable(page) {
	await expandTreeRow(page, 'Sample - SQLite');
	await expandTreeRow(page, /main.*sakila\.db/i);
	await expandTreeRow(page, /^Tables\s*18/i);
	const actorRow = page.locator('.part.sidebar .monaco-list-row').filter({ hasText: /actor\s*200 rows/i }).first();
	await actorRow.waitFor({ state: 'visible', timeout: 15000 });
	await actorRow.dblclick();
	await page.waitForFunction(() => [...document.querySelectorAll('.tab.active .label-name')]
		.some(tab => /Sample - SQLite\/main\/actor/i.test(tab.textContent ?? '')), null, { timeout: 30000 });
	await page.waitForFunction(() => {
		const panel = document.querySelector('.part.panel');
		return !panel || getComputedStyle(panel).display === 'none' || panel.getBoundingClientRect().width === 0 || panel.getBoundingClientRect().height === 0;
	}, null, { timeout: 15000 });

	for (let attempt = 0; attempt < 30; attempt++) {
		for (const frame of page.frames()) {
			if (frame === page.mainFrame()) {
				continue;
			}
			const text = await deepFrameText(frame).catch(() => '');
			if (/actor_id/i.test(text) && /PENELOPE/i.test(text)) {
				return { frame, text };
			}
		}
		await page.waitForTimeout(500);
	}
	throw new Error('DBCode did not render the populated Sample - SQLite/main/actor table editor.');
}

async function openProjectQueryWithSqlAction(app, page) {
	let openError;
	const dialogCalls = await withOpenDialogProbe(app, { canceled: false, filePaths: [projectQueryPath] }, async () => {
		await page.locator('[data-dbcode-wrapper-action="open-sql"]').click();
		try {
			await page.waitForFunction(expected => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperQueryName === expected, path.basename(projectQueryPath), { timeout: 15000 });
		} catch (error) {
			openError = error;
		}
	});

	assert.equal(dialogCalls.length, 1, 'Open SQL File must open exactly one native SQL picker.');
	assert.deepEqual(dialogCalls[0].filters, [{ name: 'SQL query files', extensions: ['sql'] }]);
	assert.ok(dialogCalls[0].properties.includes('openFile'));
	assert.ok(dialogCalls[0].properties.includes('multiSelections'));
	assert.ok(!dialogCalls[0].properties.includes('openDirectory'));
	if (openError) {
		const queryName = await page.locator('.monaco-workbench').getAttribute('data-dbcode-wrapper-query-name');
		const tabs = await page.locator('.tab .label-name').allTextContents();
		throw new Error(`Open SQL File did not activate ${path.basename(projectQueryPath)}; current query is ${queryName}; tabs are ${JSON.stringify(tabs)}. ${openError.message}`);
	}
	return dialogCalls;
}

async function freshDefaultProof() {
	fs.mkdirSync(qaRoot, { recursive: true });
	const profileRoot = fs.mkdtempSync(path.join(qaRoot, 'f-'));
	const args = profileArgs(profileRoot, qaExtensions);
	const settingsPath = path.join(profileRoot, 'user-data/User/settings.json');
	fs.copyFileSync(path.join(repoRoot, 'host/profile/settings.json'), settingsPath);
	let session;
	try {
		session = await launch(productionExecutable, commonArgs(args));
		const { app, page } = session;
		await waitForFocusedShell(app, page);
		await waitForReleaseStatus(page);
		const welcome = await findProfileSetupFrame(page, /Set up your Standalone DBCode Profile/i);
		assert.match(welcome.text, /Nothing is copied automatically/i);
		assert.match(welcome.text, /Normal VS Code, VSCodium, Keychain, Settings Sync, extension state, and licence storage are never used as migration sources/i);
		await welcome.frame.getByRole('button', { name: /Start fresh/i }).click();
		const complete = await findProfileSetupFrame(page, /Profile setup is complete/i);
		assert.match(complete.text, /other editor profiles were not used/i);
		await page.screenshot({ path: path.join(outputRoot, 'ticket-04-fresh-profile-setup.png') });
		await complete.frame.getByRole('button', { name: 'Close', exact: true }).click();
		await waitForProfileSetupToClose(page);
		record('first launch visibly creates a fresh Standalone DBCode Profile without copying another editor profile');
		const state = await geometry(page);
		assert.equal(state.dataset.dbcodeWrapperNarrow, 'false');
		assert.equal(state.panelVisible, false, 'A fresh profile must not open a duplicate Results panel.');
		assert.equal(state.sidebarVisible, false, 'A fresh profile must keep Database Explorer hidden until requested.');
		assert.equal(state.dataset.dbcodeWrapperConnectionsHome, 'closed');
		assert.equal(state.dataset.dbcodeWrapperResultLocation, 'beside');
		assert.equal(state.dataset.dbcodeWrapperResultLocationState, 'ready');
		assert.deepEqual(state.toolbarActions.map(item => item.action), [
			'connections', 'connection-tools', 'database-explorer', 'open-sql', 'new-query', 'queries', 'tools', 'release-status', 'account'
		]);
		assert.equal(state.dataset.dbcodeWrapperReleaseStatus, 'current');
		assertNoResultPositionControls(state);
		assert.equal(state.terminalVisible, false, 'A fresh profile must not restore Terminal.');
		record('fresh profile starts with the query canvas, Connections Home closed, and automatic wide result placement');
		const nativeConnectionTools = nativeMenuText(await captureNativeToolbarMenu(app, page, 'connection-tools'));
		assert.match(nativeConnectionTools, /Connections Home/);
		assert.match(nativeConnectionTools, /Tunnels/);
		assert.match(nativeConnectionTools, /Authentication Profiles/);
		assert.match(nativeConnectionTools, /Profile Setup…/);
		assert.doesNotMatch(nativeConnectionTools, /Active Streams/, 'Streams must stay hidden until DBCode reports an active stream.');
		const nativeQueries = nativeMenuText(await captureNativeToolbarMenu(app, page, 'queries'));
		assert.match(nativeQueries, /History/);
		assert.match(nativeQueries, /Library/);
		const nativeTools = nativeMenuText(await captureNativeToolbarMenu(app, page, 'tools'));
		for (const label of advancedToolLabels) assert.ok(nativeTools.includes(label), `DBCode tools is missing ${label}.`);
		for (const label of removedToolLabels) assert.ok(!nativeTools.includes(label), `DBCode tools still exposes the broken or duplicate ${label} route.`);
		assert.equal(featurePolicy.extension.version, dbcodeManifest.version);
		record('default macOS menus expose the reviewed connection, query, and advanced DBCode routes', {
			externalExtensions: qaExtensionDirectories
		});
	} finally {
		if (session) {
			session.stopDiagnostics();
			await session.app.close().catch(() => undefined);
		}
		fs.rmSync(profileRoot, { recursive: true, force: true });
	}
}

async function productionProof() {
	fs.rmSync(persistentProfileRoot, { recursive: true, force: true });
	const args = profileArgs(persistentProfileRoot, qaExtensions);
	const settingsPath = path.join(persistentProfileRoot, 'user-data/User/settings.json');
	const scratchFilesPath = path.join(persistentProfileRoot, 'scratch-files');
	fs.copyFileSync(path.join(repoRoot, 'host/profile/settings.json'), settingsPath);
	const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
	settings['window.menuStyle'] = 'custom';
	settings['workbench.list.openMode'] = 'doubleClick';
	settings['dbcode.scratchFiles.path'] = scratchFilesPath;
	fs.writeFileSync(settingsPath, `${JSON.stringify(settings, null, 2)}\n`);
	const releaseLinkCaptureEnvironment = {
		DBCODE_WRAPPER_QA_CAPTURE_RELEASE_LINKS: '1'
	};
	const { app, page, stopDiagnostics } = await launch(productionExecutable, commonArgs(args), releaseLinkCaptureEnvironment);
	try {
		await waitForFocusedShell(app, page);
		await waitForReleaseStatus(page);
		let preview = await reviewMigrationInventory(app, page);
		await preview.frame.getByRole('button', { name: 'Continue', exact: true }).click();
		let importPage = await findProfileSetupFrame(page, /Continue in DBCode Import/i);
		let stagedPath = (await importPage.frame.locator('.file-card code').textContent()).trim();
		assert.equal(path.basename(stagedPath), 'reviewed-connections.csv');
		assert.ok(path.resolve(stagedPath).startsWith(`${path.resolve(persistentProfileRoot)}${path.sep}`), 'Reviewed migration data escaped the private QA profile.');
		assert.equal(fs.statSync(path.dirname(stagedPath)).mode & 0o777, 0o700);
		assert.equal(fs.statSync(stagedPath).mode & 0o777, 0o600);
		const firstStagedContents = fs.readFileSync(stagedPath, 'utf8');
		assert.match(firstStagedContents, /^name,type,host,port,database,username,ssl,path,connectionType\n/);
		assert.match(firstStagedContents, /Rendered PostgreSQL/);
		assert.match(firstStagedContents, /Rendered Parquet/);
		assert.doesNotMatch(firstStagedContents, /Rendered hyphen DuckDB|rendered-proof-with-hyphen|rendered-second-hyphen/i, 'A hyphen-path DuckDB connection entered the batch import.');
		await importPage.frame.getByRole('button', { name: /Cancel and delete file/i }).click();
		await findProfileSetupFrame(page, /Set up your Standalone DBCode Profile/i);
		assert.equal(fs.existsSync(stagedPath), false, 'Cancelling Profile Setup left reviewed temporary data behind.');
		record('reviewed migration data is owner-only, excludes the deferred DuckDB path, and is deleted on cancellation');

		preview = await reviewMigrationInventory(app, page);
		await preview.frame.getByRole('button', { name: 'Continue', exact: true }).click();
		importPage = await findProfileSetupFrame(page, /Continue in DBCode Import/i);
		stagedPath = (await importPage.frame.locator('.file-card code').textContent()).trim();
		assert.equal(fs.existsSync(stagedPath), true);
		await importPage.frame.getByRole('button', { name: /Open DBCode Import/i }).click();
		const importSourcePicker = page.locator('.quick-input-widget');
		await importSourcePicker.waitFor({ state: 'visible', timeout: 15000 });
		const importSourceText = (await importSourcePicker.innerText()).replace(/\s+/g, ' ').trim();
		assert.match(importSourceText, /CSV|JSON|Azure Data Studio|Import/i, 'Profile Setup did not invoke DBCode\'s declared connection importer.');
		const profileImportDialogCalls = await withOpenDialogProbe(app, { canceled: false, filePaths: [stagedPath] }, async () => {
			const csvSource = importSourcePicker.locator('.monaco-list-row').filter({ hasText: /CSV/i }).first();
			assert.equal(await csvSource.isVisible(), true, 'DBCode Import did not offer CSV as a source.');
			await csvSource.click();
			await page.waitForTimeout(3000);
		});
		assert.equal(profileImportDialogCalls.length, 1, 'DBCode CSV import must open exactly one file picker.');
		const customFormat = importSourcePicker.locator('.monaco-list-row').filter({ hasText: /Custom Format/i }).first();
		assert.equal(await customFormat.isVisible(), true, 'DBCode CSV import did not offer its documented custom field mapping.');
		await customFormat.click();
		const reviewedMappings = [
			['name', 'name'],
			['type', 'driver'],
			['host', 'host'],
			['port', 'port'],
			['database', 'database'],
			['username', 'username'],
			['ssl', 'ssl'],
			['path', 'socket'],
			['connectionType', 'connectionType']
		];
		let dbcodePreview;
		const profileImportMessages = await withMessageBoxChoices(app, ['Preview', { button: 'Import', hold: true }], async () => {
			for (const [sourceField, targetField] of reviewedMappings) {
				try {
					await page.waitForFunction(field => {
						const picker = document.querySelector('.quick-input-widget');
						const visible = picker && getComputedStyle(picker).display !== 'none' && picker.getBoundingClientRect().height > 0;
						const text = (picker?.textContent ?? '').replace(/\s+/g, ' ').trim().toLowerCase();
						return visible && text.includes(`map source field: ${field.toLowerCase()}`);
					}, sourceField, { timeout: 15000 });
				} catch (error) {
					const current = await importSourcePicker.isVisible().catch(() => false) ? (await importSourcePicker.innerText()).replace(/\s+/g, ' ').trim() : 'not visible';
					throw new Error(`DBCode CSV mapping did not reach source field ${sourceField}. Current picker: ${current}. ${error.message}`);
				}
				const target = importSourcePicker.getByText(targetField, { exact: true }).first();
				assert.equal(await target.isVisible(), true, `DBCode CSV import did not offer ${targetField} for source field ${sourceField}.`);
				await target.click();
			}
			for (let attempt = 0; attempt < 60; attempt++) {
				const messageCount = await app.evaluate(() => globalThis.__dbcodeWrapperMessageBoxProbe?.calls.length ?? 0);
				if (messageCount >= 2) break;
				await page.waitForTimeout(100);
			}
			assert.equal(await app.evaluate(() => globalThis.__dbcodeWrapperMessageBoxProbe?.calls.length ?? 0), 2, 'DBCode did not open its preview confirmation after field mapping.');
			const activeTabs = (await page.locator('.tab.active .label-name').allTextContents()).map(value => value.trim());
			const previewText = (await page.locator('.monaco-editor .view-lines').last().innerText().catch(() => '')).replace(/\s+/g, ' ').trim();
			assert.ok(activeTabs.some(tab => tab !== 'scratch.sql' && tab !== 'Profile Setup'), `DBCode did not open a preview editor: ${JSON.stringify(activeTabs)}`);
			assert.match(previewText, /Rendered PostgreSQL/i, 'DBCode preview did not show the reviewed PostgreSQL connection.');
			assert.match(previewText, /Rendered Parquet/i, 'DBCode preview did not show the reviewed Parquet connection.');
			dbcodePreview = { activeTabs, preview: previewText.slice(0, 500) };
			await page.screenshot({ path: path.join(outputRoot, 'ticket-04-dbcode-import-preview.png') });
			assert.equal(await app.evaluate(() => {
				const release = globalThis.__dbcodeWrapperMessageBoxProbe?.release;
				if (!release) return false;
				release();
				return true;
			}), true, 'DBCode import confirmation was not waiting for the reviewed choice.');
			await page.waitForTimeout(1200);
		});
		assert.equal(profileImportMessages.length, 2);
		assert.match(profileImportMessages[0].message, /2 connection\(s\) found/i);
		assert.deepEqual(profileImportMessages[0].buttons, ['Import', 'Cancel', 'Preview']);
		assert.equal(profileImportMessages[0].selectedButton, 'Preview');
		assert.match(profileImportMessages[1].message, /Preview opened.*2 connection\(s\)/i);
		assert.equal(profileImportMessages[1].selectedButton, 'Import');
		assert.equal(profileImportMessages[1].held, true);

		const importedExplorer = page.locator('[data-dbcode-wrapper-action="database-explorer"]');
		await importedExplorer.click();
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawer === 'open');
		const importedPostgres = page.locator('.part.sidebar .monaco-list-row').filter({ hasText: /Rendered PostgreSQL/i }).first();
		const importedParquet = page.locator('.part.sidebar .monaco-list-row').filter({ hasText: /Rendered Parquet/i }).first();
		await importedPostgres.waitFor({ state: 'visible', timeout: 15000 });
		await importedParquet.waitFor({ state: 'visible', timeout: 15000 });
		await page.screenshot({ path: path.join(outputRoot, 'ticket-04-dbcode-imported-connections.png') });
		await importedExplorer.click();
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawer === 'closed');
		record('DBCode completes CSV source selection, file selection, custom mapping, preview, confirmation, and import', {
			connections: ['Rendered PostgreSQL', 'Rendered Parquet'],
			mappings: reviewedMappings,
			preview: dbcodePreview
		});
		const importConfirmation = await findProfileSetupFrame(page, /Did the reviewed import finish/i);
		assert.match(importConfirmation.text, /DBCode's own field mapping and preview/i);
		await importConfirmation.frame.getByRole('button', { name: /Import finished/i }).click();
		let firstPreflight = await findProfileSetupFrame(page, /Test the deferred DuckDB connection/i);
		assert.match(firstPreflight.text, new RegExp(`DBCode ${releaseLock.extension.dbcode.version.replaceAll('.', '\\.')}`));
		assert.match(firstPreflight.text, /Connection 1 of 2/i);
		assert.match(firstPreflight.text, /SELECT 1 AS dbcode_wrapper_read_only_preflight;/i);
		assert.match(firstPreflight.text, new RegExp(migrationDuckdbPath.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
		assert.doesNotMatch(firstPreflight.text, new RegExp(migrationSecondDuckdbPath.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
		assert.match(firstPreflight.text, /never renames, moves, or rewrites|Do not rename/i);
		await importHyphenDuckdbForPreflight(app, page);
		const duckdbPreflight = await runHyphenDuckdbReadOnlyPreflight(page);
		await page.locator('.tab').filter({ hasText: /^Profile Setup$/i }).first().click();
		firstPreflight = await findProfileSetupFrame(page, /Connection 1 of 2/i);
		if (duckdbPreflight.passed) {
			await firstPreflight.frame.getByRole('button', { name: /The read-only preflight returned 1/i }).click();
		} else {
			await firstPreflight.frame.getByRole('button', { name: /Keep this connection deferred/i }).click();
		}
		const secondPreflight = await findProfileSetupFrame(page, /Connection 2 of 2/i);
		assert.match(secondPreflight.text, /Connection 2 of 2/i);
		assert.match(secondPreflight.text, new RegExp(migrationSecondDuckdbPath.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
		assert.doesNotMatch(secondPreflight.text, new RegExp(migrationDuckdbPath.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
		await page.screenshot({ path: path.join(outputRoot, 'ticket-04-reviewed-profile-migration.png') });
		await secondPreflight.frame.getByRole('button', { name: /Keep this connection deferred/i }).click();
		const migrationComplete = await findProfileSetupFrame(page, /Profile setup is complete/i);
		const deferredCount = duckdbPreflight.passed ? 1 : 2;
		assert.match(migrationComplete.text, new RegExp(`${deferredCount} DuckDB connection(?:s)? remain(?:s)? deferred`, 'i'));
		assert.equal(fs.existsSync(stagedPath), false, 'Completing Profile Setup left reviewed temporary data behind.');
		await migrationComplete.frame.getByRole('button', { name: 'Close', exact: true }).click();
		await waitForProfileSetupToClose(page);
		const scratchTabAfterImport = page.locator('.tab').filter({ hasText: /^scratch\.sql$/i }).first();
		await scratchTabAfterImport.click();
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperQueryName === 'scratch.sql');
		record('focused Profile Setup hands reviewed CSV to DBCode and records each hyphen-path DuckDB preflight independently', {
			dbcodeVersion: releaseLock.extension.dbcode.version,
			importSourcePreview: importSourceText.slice(0, 160),
			hyphenPathPreflight: {
				passed: duckdbPreflight.passed,
				fileDigestUnchanged: duckdbPreflight.digest,
				result: duckdbPreflight.resultText.slice(0, 240)
			}
		});
		let state = await geometry(page);
		assert.equal(state.panelVisible, false, 'The generic workbench panel must stay hidden outside Connections Home.');
		assert.equal(state.terminalVisible, false, 'Terminal must not appear in the DBCode-focused shell.');
		assert.equal(state.activitybarVisible, false);
		assert.equal(state.auxiliarybarVisible, false);
		assert.equal(state.statusbarVisible, false);
		assert.equal(state.commandCenterVisible, false);
		assert.ok(state.horizontalOverflow <= 0);
		const wideOverflow = state.horizontalOverflow;

		assert.ok(state.titlebar.height >= 80, 'The redesign needs a distinct native-title row and database action row.');
		assert.ok(state.toolbar.height >= 46, 'The database action row is too short.');
		assert.ok(state.toolbarClass.includes('dbcode-wrapper-database-contextbar'));
		assert.equal(state.windowTitleVisible, true);
		assert.match(state.windowTitleText, /^DBCode Wrapper/);
		assert.ok(!state.windowTitleText.includes('workspace'));
		assert.equal(state.queryContextVisible, false, 'The toolbar must not repeat an inert Query badge or editor name.');
		assert.equal(state.queryName, '');
		assert.equal(state.dataset.dbcodeWrapperQueryName, 'scratch.sql');
		assert.equal(state.dataset.dbcodeWrapperActiveSurface, 'query');
		assert.equal(state.dataset.dbcodeWrapperDbcodeState, 'active');
		assert.equal(state.dbcodeExtensionState, 'DBCode active');
		assert.equal(state.breadcrumbsVisible, false);
		assert.deepEqual(state.toolbarActions.map(item => item.action), [
			'connections', 'connection-tools', 'database-explorer', 'open-sql', 'new-query', 'queries', 'tools', 'release-status', 'account'
		]);
		assert.equal(state.dataset.dbcodeWrapperReleaseStatus, 'current');
		assertNoResultPositionControls(state);
		assert.ok(state.toolbarActions.every(item => item.label), 'Every icon-only toolbar action needs an accessible name.');
		const explorerAction = state.toolbarActions.find(item => item.action === 'database-explorer');
		assert.equal(explorerAction.visibleLabel, null);
		assert.ok(state.toolbarActions.find(item => item.action === 'connections').bounds.x <= 20);
		assert.ok(state.toolbarActions.find(item => item.action === 'account').bounds.x > state.toolbarActions.find(item => item.action === 'tools').bounds.x, 'Account must stay on the right side of the database toolbar.');

		const nativeWindowButtons = await getWindowButtonPosition(app);
		assert.ok(nativeWindowButtons, 'Electron did not report the macOS window-control position.');
		assert.ok(nativeWindowButtons.y <= 10, 'macOS window controls are still vertically centred across the toolbar at y=' + nativeWindowButtons.y + '.');
		await captureSignedWindow(app, page, 'ticket-03-signed-window-wide.png');

		await page.keyboard.press('F1');
		await page.waitForTimeout(250);
		assert.equal((await geometry(page)).quickInputVisible, false, 'The generic Command Palette must remain unavailable.');
		const menuState = await app.evaluate(({ Menu }) => {
			const menu = Menu.getApplicationMenu();
			const database = menu?.items.find(item => item.label === 'Database');
			const tools = database?.submenu?.items.find(item => item.label === 'DBCode Tools');
			return {
				topLevel: menu?.items.map(item => item.label) ?? [],
				database: database?.submenu?.items.filter(item => item.type !== 'separator').map(item => ({ label: item.label, accelerator: item.accelerator })) ?? [],
				tools: tools?.submenu?.items.filter(item => item.type !== 'separator').map(item => item.label) ?? []
			};
		});
		assert.deepEqual(menuState.topLevel, ['DBCode Wrapper', 'Database', 'Edit', 'Window']);
		assert.equal(menuState.database.find(item => item.label === 'Open SQL File…')?.accelerator, 'CmdOrCtrl+O');
		assert.ok(menuState.database.some(item => item.label === 'Profile Setup…'), 'The native Database menu is missing Profile Setup.');
		assert.ok(menuState.database.some(item => item.label === 'DBCode Tools'), 'The native Database menu is missing DBCode Tools.');
		assert.deepEqual(menuState.tools, advancedToolLabels, 'The native DBCode Tools menu must contain only the retained working routes.');
		for (const label of removedToolLabels) {
			assert.ok(!menuState.database.some(item => item.label === label), `The native Database menu still exposes ${label}.`);
			assert.ok(!menuState.tools.includes(label), `The native DBCode Tools menu still exposes ${label}.`);
		}
		assert.ok(!menuState.database.some(item => item.label === 'Open Database or Query...'));
		record('production shell exposes only DBCode-focused chrome', {
			menuLabels: menuState.topLevel,
			databaseMenu: menuState.database,
			toolbarActions: state.toolbarActions.map(item => item.label)
		});

		await page.locator('[data-dbcode-wrapper-action="release-status"]').click();
		const releaseStatusPicker = page.locator('.quick-input-widget');
		await releaseStatusPicker.waitFor({ state: 'visible' });
		const releaseStatusText = (await releaseStatusPicker.innerText()).replace(/\s+/g, ' ').trim();
		assert.equal(await releaseStatusPicker.locator('.monaco-list-row').count(), 3, 'Release review must show Code OSS, VSCodium packaging, and DBCode as separate rows.');
		assert.match(releaseStatusText, /DBCode Wrapper is current/i);
		assert.match(releaseStatusText, /Code OSS runtime.*1\.126\.0.*current/i);
		assert.match(releaseStatusText, /VSCodium packaging.*1\.126\.04524.*current/i);
		assert.match(releaseStatusText, /DBCode.*1\.36\.2.*current/i);
		assert.match(releaseStatusText, /Published/i, 'Release review must include publication dates.');
		const officialReleaseLinks = [
			['Code OSS runtime', releaseLock.upstream.code_oss.release_notes_url],
			['VSCodium packaging', releaseLock.upstream.vscodium.release_notes_url],
			['DBCode', releaseLock.extension.dbcode.release_notes_url]
		];
		const openedReleaseLinks = {};
		for (const [index, [label, expectedUrl]] of officialReleaseLinks.entries()) {
			if (index > 0) {
				await page.locator('[data-dbcode-wrapper-action="release-status"]').click();
				await releaseStatusPicker.waitFor({ state: 'visible' });
			}
			const row = releaseStatusPicker.locator('.monaco-list-row').nth(index);
			assert.match((await row.innerText()).replace(/\s+/g, ' '), new RegExp(label, 'i'));
			const previousCalls = capturedExternalReleaseLinks();
			await row.click();
			const calls = await waitForCapturedExternalReleaseLink(previousCalls.length);
			assert.equal(calls.length, previousCalls.length + 1, `${label} did not open exactly one external release page.`);
			assert.equal(calls.at(-1), expectedUrl, `${label} did not open its exact official release page.`);
			await releaseStatusPicker.waitFor({ state: 'hidden' });
			openedReleaseLinks[label] = calls.at(-1);
		}
		record('release review opens the exact official page for every release row', {
			preview: releaseStatusText.slice(0, 240),
			links: openedReleaseLinks
		});

		const settingsText = await openFilteredDbcodeSettings(page);
		const settingsHeaderVisible = await page.locator('.settings-editor > .settings-header').last().isVisible().catch(() => false);
		const settingsTocVisible = await page.locator('.settings-editor .settings-toc-wrapper').last().isVisible().catch(() => false);
		assert.equal(settingsHeaderVisible, false, 'Filtered DBCode Settings must not expose an editable search that can escape the DBCode filter.');
		assert.equal(settingsTocVisible, false, 'Filtered DBCode Settings must not reopen generic settings navigation.');
		state = await geometry(page);
		assert.equal(state.panelVisible, false);
		assert.equal(state.sidebarVisible, false);
		assert.equal(state.terminalVisible, false);
		await page.screenshot({ path: path.join(outputRoot, 'ticket-05-dbcode-settings.png') });
		record('DBCode Settings opens with the extension filter and no generic settings navigation', {
			filter: '@ext:dbcode.dbcode',
			editableSearchVisible: settingsHeaderVisible,
			preview: settingsText.slice(0, 160)
		});
		await acceptDbcodeTermsIfOffered(page);
		await closeModalEditor(page);

		const aiProviderPrompt = await verifyDbcodeQuickInputTool(page, 'AI: Choose Provider', /Choose AI Provider|DBCode AI/i);
		const aiApiKeyPrompt = await verifyDbcodeQuickInputTool(page, 'AI: Set API Key', /Custom Model API Key|Set API Key|Clear API Key/i);
		state = await geometry(page);
		assert.equal(state.panelVisible, false);
		assert.equal(state.sidebarVisible, false);
		assert.equal(state.terminalVisible, false);
		record('the retained DBCode AI tools open their real provider and API-key workflows', {
			provider: aiProviderPrompt.slice(0, 100),
			apiKey: aiApiKeyPrompt.slice(0, 100)
		});

		const scratchFolderCalls = await withShowItemInFolderProbe(app, async () => {
			await openToolbarMenu(page, 'tools');
			await page.getByRole('menuitem', { name: 'Show Scratch Files in Finder', exact: true }).click();
		});
		assert.deepEqual(scratchFolderCalls, [scratchFilesPath], 'Scratch Files must use the native Finder reveal route with DBCode\'s configured path.');
		assert.equal(fs.statSync(scratchFilesPath).isDirectory(), true, 'The configured Scratch Files folder was not created.');
		state = await geometry(page);
		assert.equal(state.panelVisible, false);
		assert.equal(state.sidebarVisible, false);
		assert.equal(state.terminalVisible, false);
		record('Show Scratch Files in Finder uses the configured DBCode path without an external URL alert', { path: scratchFilesPath });

		const connections = page.locator('[data-dbcode-wrapper-action="connections"]');
		await connections.focus();
		assert.equal(await page.evaluate(() => document.activeElement?.getAttribute('data-dbcode-wrapper-action')), 'connections');
		await page.keyboard.press('Enter');
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperConnectionsHome === 'open');
		await page.waitForFunction(() => {
			const panel = document.querySelector('.part.panel');
			return Boolean(panel && getComputedStyle(panel).display !== 'none' && panel.getBoundingClientRect().height > 0);
		});
		await acceptDbcodeTermsIfOffered(page, 1000);
		const home = await findDbcodePanelFrame(page, /New connection/i);
		assert.match(home.text, /Sample database/i);
		assert.match(home.text, /Import connections/i);
		assert.match(home.text, /Open SQL file/i);
		state = await geometry(page);
		assert.equal(state.dataset.dbcodeWrapperActiveSurface, 'connections');
		assert.equal(state.dataset.dbcodeWrapperDrawer, 'closed');
		assert.equal(state.panelVisible, true);
		assert.ok(state.panel.width >= 1400 && state.panel.height >= 700, 'Connections Home does not own the main canvas.');
		assert.equal(state.connectionsHomeTitleVisible, true);
		assert.equal(state.connectionsHomeTitle, 'Connections');
		assert.equal(state.connectionsHomeCloseVisible, true);
		assert.equal(await connections.getAttribute('aria-expanded'), 'true');
		assertNoResultPositionControls(state);
		const homeContextMenus = await captureNativeContextMenu(
			app,
			page,
			() => page.locator('.dbcode-wrapper-connections-home-titlebar').click({ button: 'right' }),
			false
		);
		assert.equal(homeContextMenus.length, 0, 'Connections Home must not expose a native panel menu or Terminal.');
		assert.equal(await visibleContextMenuText(page), '', 'Connections Home must not expose generic panel choices or Terminal.');
		await page.keyboard.press('Meta+Shift+M');
		await page.waitForTimeout(500);
		state = await geometry(page);
		assert.equal(state.dataset.dbcodeWrapperConnectionsHome, 'open', 'A generic panel shortcut displaced Connections Home.');
		assert.equal(state.connectionsHomeTitleVisible, true, 'Connections Home lost ownership of the panel after a generic panel shortcut.');
		assert.equal(state.terminalVisible, false, 'A generic Terminal surface replaced Connections Home.');
		await page.screenshot({ path: path.join(outputRoot, 'ticket-03-connections-home.png') });
		record('Connections opens DBCode card-based Connections Home in the main canvas', {
			cards: ['New connection', 'Sample database', 'Import connections', 'Open SQL file']
		});

		await connections.click();
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperConnectionsHome === 'closed');
		assert.equal((await geometry(page)).panelVisible, false, 'Pressing Connections again must close Connections Home.');
		assert.equal(await connections.getAttribute('aria-expanded'), 'false');
		record('Connections toggles its Home surface closed and restores the query canvas');

		await openConnectionsHome(page, connections);
		const newConnectionDialogCalls = await withOpenDialogProbe(app, { canceled: true, filePaths: [] }, async () => {
			assert.equal(await clickVisibleButtonAcrossFrames(page, /New connection/i), true, 'Connections Home did not expose the new-connection action.');
			await page.waitForFunction(() => {
				const root = document.querySelector('.monaco-workbench');
				const quickInput = document.querySelector('.quick-input-widget');
				const quickInputVisible = quickInput && getComputedStyle(quickInput).display !== 'none' && quickInput.getBoundingClientRect().height > 0;
				return root?.dataset.dbcodeWrapperConnectionsHome === 'closed' || quickInputVisible;
			}, null, { timeout: 10000 });
		});
		const catalogueSnapshot = await captureConnectionCatalogueSnapshot(page);
		verifyRenderedConnectionCatalogue(catalogueSnapshot);
		record('unchanged DBCode exposes the complete reviewed New Connection catalogue', {
			catalogue: catalogueSnapshot,
			wrapperDatabaseAllowlist: false,
			rawLabelsStored: false
		});
		state = await geometry(page);
		assert.ok(state.dataset.dbcodeWrapperConnectionsHome === 'closed' || state.quickInputVisible || newConnectionDialogCalls.length > 0, 'New connection did not open a DBCode workflow.');
		await dismissQuickInput(page);
		await closeConnectionsHome(page);
		const activeTabAfterNewConnection = (await page.locator('.tab.active .label-name').allTextContents()).at(-1)?.trim() ?? '';
		if (activeTabAfterNewConnection && activeTabAfterNewConnection !== 'scratch.sql') {
			const activeTab = page.locator('.tab.active').last();
			const close = activeTab.locator('.codicon-close').first();
			if (await close.count()) {
				await close.click();
			}
		}

		await openConnectionsHome(page, connections);
		const importDialogCalls = await withOpenDialogProbe(app, { canceled: true, filePaths: [] }, async () => {
			assert.equal(await clickVisibleButtonAcrossFrames(page, /Import connections/i), true, 'Connections Home did not expose the import action.');
			await page.waitForTimeout(1000);
		});
		state = await geometry(page);
		assert.ok(state.quickInputVisible || state.dataset.dbcodeWrapperConnectionsHome === 'closed' || importDialogCalls.length > 0, 'Import connections did not open a DBCode workflow.');
		await dismissQuickInput(page);
		await closeConnectionsHome(page);

		await openConnectionsHome(page, connections);
		const homeOpenSqlDialogCalls = await withOpenDialogProbe(app, { canceled: true, filePaths: [] }, async () => {
			assert.equal(await clickVisibleButtonAcrossFrames(page, /Open SQL file/i), true, 'Connections Home did not expose its SQL-file action.');
			await page.waitForTimeout(500);
		});
		assert.equal(homeOpenSqlDialogCalls.length, 1, 'Connections Home did not hand Open SQL file to the native picker.');
		await closeConnectionsHome(page);

		await openConnectionsHome(page, connections);

		let sampleClicked = await clickVisibleButtonAcrossFrames(page, /Sample database/i);
		if (!sampleClicked) sampleClicked = await clickVisibleButtonAcrossFrames(page, /Explore With a Sample Database/i);
		assert.equal(sampleClicked, true, 'Connections Home did not expose the DBCode sample database action.');
		await page.waitForTimeout(1500);
		record('Connections Home actions enter DBCode connection, import, sample, and SQL-file workflows');

		const explorer = page.locator('[data-dbcode-wrapper-action="database-explorer"]');
		await openConnectionsHome(page, connections);
		await explorer.click();
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawer === 'open');
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperConnectionsHome === 'closed');
		await page.waitForFunction(() => {
			const text = document.querySelector('.part.sidebar')?.textContent ?? '';
			return text.includes('Sample - SQLite') && !text.includes('No connections created.');
		}, null, { timeout: 30000 });
		state = await geometry(page);
		assert.ok(state.sidebar.width >= 250);
		assert.equal(state.dataset.dbcodeWrapperDrawerView, 'dbcode.connections.view');
		assert.equal(state.dataset.dbcodeWrapperActiveSurface, 'explorer');
		assert.equal(state.sidebarOverflowVisible, false, 'Database Explorer still exposes the generic Views menu: ' + JSON.stringify(state.sidebarTitleActions) + '.');
		assert.deepEqual(state.dataset.dbcodeWrapperDrawerViews.split(','), connectionDrawerViews);
		assert.equal(await explorer.getAttribute('aria-expanded'), 'true');
		assert.equal(await connections.getAttribute('aria-expanded'), 'false');
		await page.screenshot({ path: path.join(outputRoot, 'ticket-03-database-explorer.png') });
		record('Database Explorer is a separate contextual tree and shows the sample connection');

		await expandTreeRow(page, 'Sample - SQLite');
		const databaseRow = await expandTreeRow(page, /main.*sakila\.db/i);
		await page.locator('.part.sidebar .monaco-list-row').filter({ hasText: /^Tables\s*18/i }).first().waitFor({ state: 'visible', timeout: 30000 });
		await databaseRow.click();
		await databaseRow.click({ button: 'right' });
		await page.waitForFunction(() => [...document.querySelectorAll('.context-view')].some(element => {
			const box = element.getBoundingClientRect();
			return getComputedStyle(element).display !== 'none' && box.width > 0 && box.height > 0;
		}));
		const databaseContextText = await visibleContextMenuText(page);
		assert.doesNotMatch(databaseContextText, /DBCode Notebook|Query Builder/i);
		assert.doesNotMatch(databaseContextText, /Terminal|Extensions|Source Control/i);
		await page.keyboard.press('Escape');

		await openToolbarMenu(page, 'tools');
		await page.getByRole('menuitem', { name: 'Query Builder', exact: true }).click();
		const queryBuilderPrompt = page.locator('.quick-input-widget');
		await queryBuilderPrompt.waitFor({ state: 'visible', timeout: 15000 });
		const queryBuilderPromptText = (await queryBuilderPrompt.innerText()).replace(/\s+/g, ' ').trim();
		assert.match(queryBuilderPromptText, /Sample - SQLite|Select.*connection|Select.*database/i, 'Query Builder did not open its DBCode connection workflow.');
		await page.keyboard.press('Escape');
		await dismissQuickInput(page);
		record("the focused Query Builder route opens DBCode's real connection workflow without a duplicate tree shortcut", { prompt: queryBuilderPromptText.slice(0, 120) });

		await openToolbarMenu(page, 'tools');
		await page.getByRole('menuitem', { name: 'New DBCode Notebook', exact: true }).click();
		try {
			await page.locator('.notebook-editor').last().waitFor({ state: 'visible', timeout: 30000 });
		} catch (error) {
			const notebookState = await page.evaluate(() => ({
				tabs: [...document.querySelectorAll('.editor-group-container .tab .label-name')].map(item => item.textContent?.trim()),
				notifications: [...document.querySelectorAll('.notification-toast')].map(item => item.textContent?.replace(/\s+/g, ' ').trim()),
				quickInput: document.querySelector('.quick-input-widget')?.textContent?.replace(/\s+/g, ' ').trim() ?? '',
				quickInputVisible: (() => {
					const item = document.querySelector('.quick-input-widget');
					if (!item) return false;
					const box = item.getBoundingClientRect();
					return getComputedStyle(item).display !== 'none' && box.width > 0 && box.height > 0;
				})(),
				visibleEditors: [...document.querySelectorAll('.editor-instance')].filter(item => {
					const box = item.getBoundingClientRect();
					return getComputedStyle(item).display !== 'none' && box.width > 0 && box.height > 0;
				}).map(item => item.className),
				frames: [...document.querySelectorAll('iframe')].map(item => item.src)
			}));
			throw new Error(`DBCode Notebook did not render: ${JSON.stringify({ notebookState, rendererErrors: report.errors })}. ${error.message}`);
		}
		const notebookTabName = (await page.locator('.tab.active .label-name').last().textContent())?.trim() ?? '';
		assert.match(notebookTabName, /notebook|dbcnb|dbcode/i);
		const notebookEditor = page.locator('.notebook-editor:visible').last();
		await notebookEditor.click({ position: { x: 120, y: 120 } });
		await page.keyboard.press('b');
		const firstNotebookCell = notebookEditor.locator('.monaco-list-row').first();
		await firstNotebookCell.waitFor({ state: 'visible', timeout: 10000 });
		const sqlLanguageStatus = firstNotebookCell.locator('.cell-status-item').filter({ hasText: /MS SQL/i }).last();
		await sqlLanguageStatus.waitFor({ state: 'visible', timeout: 10000 });
		await sqlLanguageStatus.click();
		const languagePicker = page.locator('.quick-input-widget');
		await languagePicker.waitFor({ state: 'visible', timeout: 10000 });
		const languagePickerText = (await languagePicker.innerText()).replace(/\s+/g, ' ').trim();
		assert.match(languagePickerText, /Python/i, 'DBCode notebook language selection does not expose Python.');
		const pythonLanguage = languagePicker.locator('.monaco-list-row').filter({ hasText: /Python/i }).first();
		await pythonLanguage.click();
		await languagePicker.waitFor({ state: 'hidden', timeout: 10000 });
		const pythonProofCode = `dbcode_wrapper_notebook_proof = 6 * 7\nprint('DBCODE_NOTEBOOK_PYTHON_OUTPUT_42', dbcode_wrapper_notebook_proof)`;
		await firstNotebookCell.locator('.monaco-editor').first().click();
		await page.keyboard.insertText(pythonProofCode);
		await firstNotebookCell.getByText('DBCODE_NOTEBOOK_PYTHON_OUTPUT_42', { exact: false }).waitFor({ state: 'visible', timeout: 10000 });
		const pythonNotebookCell = notebookEditor.locator('.monaco-list-row')
			.filter({ hasText: /DBCODE_NOTEBOOK_PYTHON_OUTPUT_42/ })
			.first();

		await openToolbarMenu(page, 'tools');
		await page.getByRole('menuitem', { name: 'Start Python Kernel…', exact: true }).click();
		const bootstrapKernelPickerSteps = await chooseQaPythonKernel(page);
		await page.waitForFunction(() => [...document.querySelectorAll('.notifications-toasts .notification-toast')]
			.some(item => item.textContent?.includes('Python kernel ready.')), null, { timeout: 60000 });
		await page.waitForFunction(expectedTab => [...document.querySelectorAll('.tab.active .label-name')]
			.some(item => item.textContent?.trim() === expectedTab), notebookTabName, { timeout: 10000 });
		assert.equal(
			await page.locator('.tab:visible .label-name').filter({ hasText: /dbcode-wrapper-python-kernel\.ipynb/i }).count(),
			0,
			'The private kernel bootstrap notebook leaked into the focused tab strip.'
		);

		const executePythonCell = pythonNotebookCell.locator('.action-label.codicon-notebook-execute');
		const kernelAccessApproval = await approveDbcodeKernelAccessIfOffered(app, () => executePythonCell.click());
		assert.equal(kernelAccessApproval.approved, true, 'The fresh QA profile did not grant DBCode its visible first-use Jupyter permission.');
		record('the rendered proof grants DBCode first-use Jupyter kernel access through the visible security dialog', kernelAccessApproval);
		const notebookConnectionApproval = await approveSampleConnectionIfOffered(page, 3000);
		assert.equal(notebookConnectionApproval.approved, false, 'A Python-only DBCode cell unexpectedly asked for a database connection.');
		let notebookPythonOutput = await findNotebookPythonOutput(page, /DBCODE_NOTEBOOK_PYTHON_OUTPUT_42\s+42/);
		const selectedKernelStatus = (await pythonNotebookCell.locator('.cell-status-item').allTextContents())
			.join(' ')
			.replace(/\s+/g, ' ')
			.trim();
		assert.match(selectedKernelStatus, /python - dbcode-wrapper-python-kernel\.ipynb/i, 'DBCode did not attach to the isolated running Python kernel.');
		const repeatedKernelAccessApproval = await approveDbcodeKernelAccessIfOffered(app, () => executePythonCell.click(), 2000);
		assert.equal(repeatedKernelAccessApproval.approved, false, 'Jupyter asked for DBCode kernel access more than once.');
		notebookPythonOutput = await findNotebookPythonOutput(page, /DBCODE_NOTEBOOK_PYTHON_OUTPUT_42\s+42/);
		const notebookInventory = await notebookEditor.evaluate(editor => ({
			text: editor.textContent?.replace(/\s+/g, ' ').trim().slice(0, 800) ?? '',
			cellCount: editor.querySelectorAll('.monaco-list-row').length
		}));
		state = await geometry(page);
		assert.equal(state.panelVisible, false);
		assert.equal(state.terminalVisible, false);
		await page.screenshot({ path: path.join(outputRoot, 'ticket-05-notebook.png') });
		record('the focused tools route opens a real DBCode notebook and executes Python without a duplicate tree shortcut', {
			tab: notebookTabName,
			languagePickerText,
			bootstrapKernelPickerSteps,
			kernelAccessApproval,
			repeatedKernelAccessApproval,
			notebookConnectionApproval,
			selectedKernelStatus,
			pythonOutput: notebookPythonOutput.text,
			pythonOutputFrame: notebookPythonOutput.url,
			notebookInventory
		});

		await ensureDrawerOpen(page, explorer);
		await expandTreeRow(page, 'Sample - SQLite');
		await expandTreeRow(page, /main.*sakila\.db/i);
		await expandTreeRow(page, /^Tables\s*18/i);
		const actorRow = page.locator('.part.sidebar .monaco-list-row').filter({ hasText: /actor/i }).first();
		await actorRow.waitFor({ state: 'visible', timeout: 15000 });
		await actorRow.click();
		await actorRow.click({ button: 'right' });
		await page.waitForFunction(() => [...document.querySelectorAll('.context-view')].some(element => {
			const box = element.getBoundingClientRect();
			return getComputedStyle(element).display !== 'none' && box.width > 0 && box.height > 0;
		}));
		const tableContextText = await visibleContextMenuText(page);
		assert.match(tableContextText, /Entity Relationship Diagram/i);
		assert.doesNotMatch(tableContextText, /Terminal|Extensions|Source Control/i);
		const diagramAction = page.locator('.context-view:visible').last().getByRole('menuitem', { name: /Entity Relationship Diagram/i });
		assert.notEqual(await diagramAction.getAttribute('aria-disabled'), 'true', 'DBCode exposed the diagram action as disabled.');
		await page.screenshot({ path: path.join(outputRoot, 'ticket-05-diagram-route.png') });
		await page.keyboard.press('Escape');
		record('Database Explorer keeps the DBCode relationship-diagram action reachable without generic IDE actions');

		const connectionToolsText = await openToolbarMenu(page, 'connection-tools');
		assert.match(connectionToolsText, /Connections Home/);
		assert.match(connectionToolsText, /Tunnels/);
		assert.match(connectionToolsText, /Authentication Profiles/);
		assert.match(connectionToolsText, /Profile Setup…/);
		assert.doesNotMatch(connectionToolsText, /Active Streams/, 'Streams must stay hidden until DBCode reports an active stream.');
		await page.keyboard.press('Escape');
		await openToolbarMenu(page, 'connection-tools');
		await page.getByRole('menuitem', { name: 'Profile Setup…', exact: true }).click();
		const reopenedSetup = await findProfileSetupFrame(page, /Set up your Standalone DBCode Profile/i);
		await reopenedSetup.frame.getByRole('button', { name: /Not now/i }).click();
		await waitForProfileSetupToClose(page);
		record('Connection tools reopens focused Profile Setup without exposing the Command Palette');
		for (const [label, viewId] of connectionToolDrawers) {
			await openToolbarMenu(page, 'connection-tools');
			await page.getByRole('menuitem', { name: label, exact: true }).click();
			try {
				await page.waitForFunction(expected => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawerView === expected, viewId, { timeout: 5000 });
			} catch (error) {
				const drawerState = await geometry(page);
				throw new Error(`Connection tool ${label} did not open ${viewId}: ${JSON.stringify(drawerState.dataset)}. ${error.message}`);
			}
			const drawerState = await geometry(page);
			assert.equal(drawerState.dataset.dbcodeWrapperDrawer, 'open');
			assert.equal(drawerState.dataset.dbcodeWrapperDrawerViews, viewId);
			assert.equal(drawerState.dataset.dbcodeWrapperActiveSurface, 'dbcode');
			assert.equal(drawerState.panelVisible, false);
			assert.equal(drawerState.sidebarOverflowVisible, false);
		}
		record('Connection tools group Tunnels and Authentication Profiles under connection management');

		const queriesMenuText = await openToolbarMenu(page, 'queries');
		assert.match(queriesMenuText, /History/);
		assert.match(queriesMenuText, /Library/);
		await page.keyboard.press('Escape');
		for (const [label, viewId] of queryDrawers) {
			await openToolbarMenu(page, 'queries');
			await page.getByRole('menuitem', { name: label, exact: true }).click();
			await page.waitForFunction(expected => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawerView === expected, viewId);
			const drawerState = await geometry(page);
			assert.equal(drawerState.dataset.dbcodeWrapperDrawerViews, viewId);
			assert.equal(drawerState.sidebarOverflowVisible, false);
			if (label === 'History') await page.screenshot({ path: path.join(outputRoot, 'ticket-03-history.png') });
		}

		await page.locator('[data-dbcode-wrapper-action="account"]').click();
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawerView === 'dbcode.account.view');
		await page.waitForFunction(() => [...document.querySelectorAll('.part.sidebar > .title .title-actions .action-item')]
			.filter(element => getComputedStyle(element).display !== 'none' && element.getBoundingClientRect().width > 0 && element.getBoundingClientRect().height > 0).length >= 2);
		state = await geometry(page);
		assert.ok(state.sidebarTitleActionCount >= 2, 'Account refresh and sign-out actions must remain available.');
		record('Queries groups History and Library while Account stays on the right');

		await openConnectionsHome(page, connections);
		const dialogCalls = await openProjectQueryWithSqlAction(app, page);
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperConnectionsHome === 'closed');
		state = await geometry(page);
		assert.equal(state.dataset.dbcodeWrapperQueryName, path.basename(projectQueryPath));
		assert.ok(state.windowTitleText.includes(path.basename(projectQueryPath)));
		assert.equal(state.sqlEditorTitleActionCount, 0, 'The SQL tab still repeats DBCode query actions in its title row.');
		assert.equal(state.genericEditorTitleActionCount, 0, 'A generic editor split or overflow action is still visible.');
		const dbcodeSqlContextCommands = dbcodeManifest.contributes.menus['editor/context']
			.map(item => item.command)
			.filter(command => command.startsWith('dbcode.'));
		assert.ok(dbcodeSqlContextCommands.includes('dbcode.editor.execute'));
		assert.ok(dbcodeSqlContextCommands.includes('dbcode.editor.copyQuery'));
		assert.ok(dbcodeSqlContextCommands.includes('dbcode.library.addScript'));
		record('SQL editor removes duplicate title actions while the pinned DBCode context commands remain available', {
			commands: dbcodeSqlContextCommands
		});
		const nonSqlDropBlocked = await page.evaluate(() => {
			const transfer = new DataTransfer();
			transfer.items.add(new File(['not a query'], 'notes.txt', { type: 'text/plain' }));
			const event = new DragEvent('drop', { bubbles: true, cancelable: true, dataTransfer: transfer });
			document.dispatchEvent(event);
			return event.defaultPrevented;
		});
		assert.equal(nonSqlDropBlocked, true, 'Non-SQL files must not enter the query canvas through drag-and-drop.');
		const toastStyle = await notificationToastStyle(page);
		assert.notEqual(toastStyle.backgroundColor, 'rgba(0, 0, 0, 0)');
		assert.notEqual(toastStyle.borderColor, 'rgba(0, 0, 0, 0)');
		assert.ok(parseFloat(toastStyle.borderRadius) >= 5);
		assert.notEqual(toastStyle.boxShadow, 'none');
		record('Open SQL uses the SQL-only picker and non-SQL drops use the wrapper notification design', {
			queryName: state.dataset.dbcodeWrapperQueryName,
			dialog: dialogCalls,
			notificationToastStyle: toastStyle
		});

		const firstResult = await executeProjectQuery(page);
		assert.match(firstResult.text, /Rows\s*:\s*1/i, 'DBCode did not render the real query row count.');
		state = await geometry(page);
		assert.equal(state.panelVisible, false, 'DBCode query results must not reopen the generic workbench panel.');
		assert.equal(state.terminalVisible, false);
		const besideLayout = assertResultsBeside(state, path.basename(projectQueryPath));
		const resultFrameElement = await firstResult.frame.frameElement();
		const resultFrameBounds = await resultFrameElement.boundingBox();
		assert.ok(resultFrameBounds, 'The populated DBCode result frame has no rendered bounds.');
		const webviewHit = await page.evaluate(bounds => {
			const hit = document.elementFromPoint(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2);
			return hit ? { tag: hit.tagName.toLowerCase(), className: String(hit.className) } : null;
		}, resultFrameBounds);
		assert.equal(webviewHit?.tag, 'iframe', 'DBCode result grid exists but is covered by ' + (webviewHit?.tag ?? 'nothing') + '.');
		await page.screenshot({ path: path.join(outputRoot, 'ticket-03-results-beside.png') });
		record('DBCode renders the real query grid beside the query without a wrapper Results panel', {
			column: 'project_query_proof',
			rowCount: 1,
			query: besideLayout.query.bounds,
			results: besideLayout.results.bounds
		});

		await ensureDrawerOpen(page, explorer);
		const actorTable = await openSampleActorTable(page);
		state = await geometry(page);
		assert.equal(state.dataset.dbcodeWrapperDrawer, 'open');
		assert.equal(state.panelVisible, false);
		assert.match(actorTable.text, /first_name/i);
		assert.match(actorTable.text, /last_name/i);
		assertNoResultPositionControls(state);
		await page.screenshot({ path: path.join(outputRoot, 'ticket-03-sample-actor-table.png') });
		record('the populated DBCode table editor stays beside Database Explorer without a generic workbench panel');
		await explorer.click();
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawer === 'closed');

		const queryTab = page.locator('.tab').filter({ hasText: path.basename(projectQueryPath) }).first();
		await queryTab.click();
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperActiveSurface === 'query');
		await closeDbcodeResultEditor(page);
		await page.waitForFunction(() => [...document.querySelectorAll('.editor-group-container')]
			.filter(element => element.getBoundingClientRect().width > 0 && element.getBoundingClientRect().height > 0)
			.every(element => element.querySelectorAll('.tab .label-name').length > 0));
		state = await geometry(page);
		assert.equal(state.emptyEditorGroupCount, 0);
		record('empty editor groups are cleaned up without closing the populated SQL query');

		await setSignedWindowContentSize(app, page, 900, 800);
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperNarrow === 'true');
		await waitForAutomaticResultLocation(page, 'below');
		const secondResult = await executeProjectQuery(page);
		assert.match(secondResult.text, /project_query_proof/i);
		state = await geometry(page);
		assert.equal(state.panelVisible, false);
		assertNoResultPositionControls(state);
		const belowLayout = assertResultsBelow(state, path.basename(projectQueryPath));
		await page.screenshot({ path: path.join(outputRoot, 'ticket-03-results-below.png') });
		record('automatic wide and narrow result placement uses DBCode grids without shell controls', {
			wide: besideLayout,
			query: belowLayout.query.bounds,
			results: belowLayout.results.bounds
		});

		state = await geometry(page);
		assert.ok(state.horizontalOverflow <= 0);
		await connections.click();
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperConnectionsHome === 'open');
		await findDbcodePanelFrame(page, /New connection/i);
		state = await geometry(page);
		assert.equal(state.panelVisible, true);
		assert.ok(state.panel.width >= 890 && state.panel.height >= 600, 'Connections Home does not fill the narrow main canvas.');
		assert.ok(state.horizontalOverflow <= 0);
		await page.screenshot({ path: path.join(outputRoot, 'ticket-03-narrow-connections-home.png') });
		await captureSignedWindow(app, page, 'ticket-03-signed-window-narrow.png');
		await page.locator('.dbcode-wrapper-connections-home-close').click();
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperConnectionsHome === 'closed');
		await setSignedWindowContentSize(app, page, 1440, 900);
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperNarrow === 'false');
		await waitForAutomaticResultLocation(page, 'beside');
		assert.equal((await geometry(page)).panelVisible, false);
		record('wide and narrow Connections Home layouts avoid horizontal overflow', { wide: wideOverflow, narrow: state.horizontalOverflow });

		await explorer.click();
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawer === 'open');
		assert.equal((await geometry(page)).sidebarVisible, true);
		await setSignedWindowContentSize(app, page, 900, 800);
		await page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperNarrow === 'true');
		await waitForAutomaticResultLocation(page, 'below');
	} finally {
		stopDiagnostics();
		await app.close();
	}
	const persistedSettings = JSON.parse(fs.readFileSync(path.join(persistentProfileRoot, 'user-data/User/settings.json'), 'utf8'));
	assert.equal(persistedSettings['dbcode.resultLocation'], 'below', 'Closing a narrow window must leave DBCode aligned with the last rendered layout until the next launch recalculates it.');

	const second = await launch(productionExecutable, commonArgs(args), releaseLinkCaptureEnvironment);
	try {
		await waitForFocusedShell(second.app, second.page);
		await second.page.waitForTimeout(1800);
		for (const frame of second.page.frames()) {
			if (frame === second.page.mainFrame()) continue;
			const frameText = await deepFrameText(frame).catch(() => '');
			assert.doesNotMatch(frameText, /Set up your Standalone DBCode Profile/i, 'Completed Profile Setup opened again after relaunch.');
		}
		const state = await geometry(second.page);
		assert.equal(state.dataset.dbcodeWrapperResultLocation, 'beside');
		assert.equal(state.dataset.dbcodeWrapperResultLocationState, 'ready');
		assert.equal(state.panelVisible, false);
		assert.equal(state.sidebarVisible, false, 'Database Explorer was restored without a user request.');
		assert.equal(state.dataset.dbcodeWrapperDrawer, 'closed');
		assert.equal(state.terminalVisible, false);
		assertNoResultPositionControls(state);
		record('automatic result layout resets wide while Database Explorer stays hidden and completed Profile Setup stays closed across relaunch');
	} finally {
		second.stopDiagnostics();
		await second.app.close();
	}
	scanExtensionHostLogs(persistentProfileRoot);
	const resetSettings = JSON.parse(fs.readFileSync(path.join(persistentProfileRoot, 'user-data/User/settings.json'), 'utf8'));
	assert.equal(resetSettings['dbcode.resultLocation'], 'beside', 'A wide relaunch must replace a stale narrow result location with the managed wide baseline.');
}

async function profileRecoveryProof() {
	const profileRoot = persistentProfileRoot;
	const userDataRoot = path.join(profileRoot, 'user-data');
	const sharedDataRoot = path.join(profileRoot, 'shared-data');
	const backupRoot = `${profileRoot}-backups`;
	const boundaryRoot = path.join(qaRoot, 'ticket-04-recovery-boundaries');
	const normalEditorState = path.join(boundaryRoot, 'normal-vscode/User/settings.json');
	const databasePath = path.join(boundaryRoot, 'project-data-with-hyphen.duckdb');
	const extensionManifestPath = path.join(qaExtensions, dbcodeExtensionDirectory, 'package.json');
	const normalEditorContents = '{"editor.fontSize":15}\n';
	const databaseContents = 'unchanged database boundary\n';
	const extensionManifestContents = fs.readFileSync(extensionManifestPath);
	let active;
	let clean;
	let automaticRelaunch;
	fs.rmSync(backupRoot, { recursive: true, force: true });
	fs.rmSync(boundaryRoot, { recursive: true, force: true });
	fs.mkdirSync(path.dirname(normalEditorState), { recursive: true });
	fs.writeFileSync(normalEditorState, normalEditorContents);
	fs.writeFileSync(databasePath, databaseContents);

	try {
		const importedSettings = JSON.parse(fs.readFileSync(path.join(userDataRoot, 'User/settings.json'), 'utf8'));
		assert.ok(importedSettings['dbcode.connections']?.some(connection => connection.name === 'Rendered PostgreSQL'));
		assert.ok(importedSettings['dbcode.connections']?.some(connection => connection.name === 'Rendered Parquet'));
		assert.ok(importedSettings['dbcode.connections']?.some(connection => connection.name === 'Rendered-Hyphen-DuckDB'));
		fs.mkdirSync(path.join(sharedDataRoot, 'recovery-proof'), { recursive: true });
		fs.writeFileSync(path.join(sharedDataRoot, 'recovery-proof/state.txt'), 'shared profile state\n');

		const args = commonArgs(profileArgs(profileRoot, qaExtensions));
		active = await launch(productionExecutable, args);
		await waitForFocusedShell(active.app, active.page);
		await waitForReleaseStatus(active.page);
		await openToolbarMenu(active.page, 'connection-tools');
		await active.page.getByRole('menuitem', { name: 'Profile Setup…', exact: true }).click();
		const preview = await reviewMigrationInventory(active.app, active.page);
		await preview.frame.getByRole('button', { name: 'Continue', exact: true }).click();
		const importPage = await findProfileSetupFrame(active.page, /Continue in DBCode Import/i);
		const stagedPath = (await importPage.frame.locator('.file-card code').textContent()).trim();
		assert.equal(fs.existsSync(stagedPath), true, 'The partial-import recovery proof did not create reviewed temporary data.');
		await importPage.frame.getByRole('button', { name: /Open DBCode Import/i }).click();
		const sourcePicker = active.page.locator('.quick-input-widget');
		await sourcePicker.waitFor({ state: 'visible', timeout: 15000 });
		await dismissQuickInput(active.page);
		const partialImport = await findProfileSetupFrame(active.page, /Did the reviewed import finish/i);
		assert.match(partialImport.text, /Back up and recreate profile/i);
		await active.page.screenshot({ path: path.join(outputRoot, 'ticket-04-profile-recovery-ready.png') });

		active.stopDiagnostics();
		const dialog = await approveProfileRecovery(active.app, () => partialImport.frame.getByRole('button', { name: /Back up and recreate profile/i }).click());
		active = undefined;
		const outcomePath = path.join(backupRoot, 'last-recovery.json');
		const recovery = await waitForRecoveryBackup(backupRoot, 60000);
		automaticRelaunch = await waitForAutomaticProfileRelaunch(userDataRoot, 60000);
		await waitForPathToDisappear(outcomePath, 60000);
		assert.equal(recovery.manifest.profile, 'Standalone DBCode Profile');
		assert.ok(path.resolve(recovery.backupDirectory).startsWith(`${path.resolve(backupRoot)}${path.sep}`), 'Profile recovery escaped its dedicated backup root.');
		assert.equal(fs.statSync(backupRoot).mode & 0o777, 0o700);
		assert.equal(fs.statSync(recovery.backupDirectory).mode & 0o777, 0o700);

		const backedUpSettingsPath = path.join(recovery.backupDirectory, 'user-data/User/settings.json');
		const backedUpSettings = JSON.parse(fs.readFileSync(backedUpSettingsPath, 'utf8'));
		assert.ok(backedUpSettings['dbcode.connections']?.some(connection => connection.name === 'Rendered PostgreSQL'));
		assert.ok(backedUpSettings['dbcode.connections']?.some(connection => connection.name === 'Rendered Parquet'));
		assert.ok(backedUpSettings['dbcode.connections']?.some(connection => connection.name === 'Rendered-Hyphen-DuckDB'));
		assert.equal(fs.readFileSync(path.join(recovery.backupDirectory, 'shared-data/recovery-proof/state.txt'), 'utf8'), 'shared profile state\n');
		const backedUpStagedPath = path.join(recovery.backupDirectory, 'user-data', path.relative(userDataRoot, stagedPath));
		assert.equal(fs.existsSync(backedUpStagedPath), false, 'Recovery backed up temporary reviewed import data instead of deleting it first.');

		const managedSettings = fs.readFileSync(path.join(repoRoot, 'host/profile/settings.json'), 'utf8');
		assert.equal(fs.readFileSync(path.join(userDataRoot, 'User/settings.json'), 'utf8'), managedSettings);
		assert.equal(fs.statSync(userDataRoot).mode & 0o777, 0o700);
		assert.equal(fs.statSync(sharedDataRoot).mode & 0o777, 0o700);
		assert.equal(fs.statSync(path.join(userDataRoot, 'User/settings.json')).mode & 0o777, 0o600);
		assert.equal(JSON.parse(managedSettings)['dbcode.connections'], undefined, 'Managed clean settings unexpectedly contain migrated DBCode connections.');
		assert.deepEqual(fs.readFileSync(extensionManifestPath), extensionManifestContents, 'Profile recovery changed the verified external DBCode extension.');
		assert.equal(fs.readFileSync(normalEditorState, 'utf8'), normalEditorContents, 'Profile recovery changed the normal editor sentinel.');
		assert.equal(fs.readFileSync(databasePath, 'utf8'), databaseContents, 'Profile recovery changed the database sentinel.');
		record('successful recovery automatically reopens exactly one app process on the recreated Standalone DBCode Profile', {
			pid: automaticRelaunch.pid,
			outcomeConsumed: true
		});
		await terminateExactProfileProcess(automaticRelaunch.pid, userDataRoot);
		automaticRelaunch = undefined;

		fs.writeFileSync(outcomePath, `${JSON.stringify({
			schemaVersion: 1,
			status: 'complete',
			backupDirectory: recovery.backupDirectory,
			completedAt: new Date().toISOString()
		}, null, 2)}\n`, { mode: 0o600 });
		fs.chmodSync(outcomePath, 0o600);

		const cleanArgs = commonArgs(profileArgs(profileRoot, qaExtensions));
		clean = await launch(productionExecutable, cleanArgs);
		await waitForFocusedShell(clean.app, clean.page);
		const recoveryNotice = clean.page.locator('.notifications-toasts .notification-toast').filter({ hasText: /A clean Standalone DBCode Profile was created/i }).first();
		await recoveryNotice.waitFor({ state: 'visible', timeout: 15000 });
		const cleanSetup = await findProfileSetupFrame(clean.page, /Set up your Standalone DBCode Profile/i);
		assert.match(cleanSetup.text, /Nothing is copied automatically/i);
		const explorer = clean.page.locator('[data-dbcode-wrapper-action="database-explorer"]');
		await explorer.click();
		await clean.page.waitForFunction(() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawer === 'open');
		const cleanExplorerText = (await clean.page.locator('.part.sidebar').innerText()).replace(/\s+/g, ' ').trim();
		assert.doesNotMatch(cleanExplorerText, /Rendered PostgreSQL|Rendered Parquet|Rendered-Hyphen-DuckDB/i, 'Recreated profile still exposes imported connections.');
		await clean.page.screenshot({ path: path.join(outputRoot, 'ticket-04-profile-recovery-complete.png') });
		record('contextual recovery backs up and recreates only the Standalone DBCode Profile after a partial import', {
			backedUpConnections: ['Rendered PostgreSQL', 'Rendered Parquet', 'Rendered-Hyphen-DuckDB'],
			backupMode: '0700',
			settingsMode: '0600',
			dialog,
			preservedBoundaries: ['verified extensions', 'normal editor data', 'database files'],
			keychainBoundary: 'rendered automation stayed on Chromium mock Keychain; recovery has no real-Keychain path'
		});
	} finally {
		if (active) {
			active.stopDiagnostics();
			await active.app.close().catch(() => undefined);
		}
		if (clean) {
			clean.stopDiagnostics();
			await clean.app.close().catch(() => undefined);
		}
		if (automaticRelaunch) {
			await terminateExactProfileProcess(automaticRelaunch.pid, userDataRoot).catch(() => undefined);
		}
		fs.rmSync(profileRoot, { recursive: true, force: true });
		fs.rmSync(backupRoot, { recursive: true, force: true });
		fs.rmSync(boundaryRoot, { recursive: true, force: true });
	}
}
(async () => {
	try {
		if (connectionCatalogueOnly) {
			await connectionCatalogueSnapshotProof();
			report.completedAt = new Date().toISOString();
			report.status = 'passed';
			return;
		}
		await freshDefaultProof();
		await productionProof();
		await profileRecoveryProof();
		assert.deepEqual(report.errors, []);
		const deferredHomeRegistrationWarnings = report.warnings.filter(warning => warning.includes('No webview with type dbcode.panelView is registered'));
		assert.ok(deferredHomeRegistrationWarnings.length <= 2, 'Connections Home webview registration warned more than once per disposable profile generation.');
		record('each disposable profile generation may defer one hidden Connections Home webview until DBCode startup activation', { warningCount: deferredHomeRegistrationWarnings.length });
		record('no unexpected renderer page or console errors were observed');
		report.completedAt = new Date().toISOString();
		report.status = 'passed';
	} catch (error) {
		report.completedAt = new Date().toISOString();
		report.status = 'failed';
		report.failure = error.stack ?? String(error);
		throw error;
	} finally {
		fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
	}
})().catch(error => {
	console.error(error);
	process.exitCode = 1;
});
