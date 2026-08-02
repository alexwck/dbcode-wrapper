'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
	createConnectionCatalogueSnapshot,
	verifyConnectionCatalogueSnapshot
} = require('./connection-catalogue-contract.cjs');
const { isExpectedRuntimeExtensionShutdownChannelClose } = require('./extension-host-log-policy.cjs');
const {
	closeElectronSession,
	preparePersistentQaSettings
} = require('./rendered-session-support.cjs');

const repoRoot = path.resolve(__dirname, '../..');
const releaseLock = JSON.parse(fs.readFileSync(path.join(repoRoot, 'host/release-lock.json'), 'utf8'));
const featurePolicy = JSON.parse(fs.readFileSync(path.join(repoRoot, 'host/dbcode-feature-policy.json'), 'utf8'));
const appName = releaseLock.product.app_name;
const productionExecutable = path.join(repoRoot, 'dist', `${appName}.app`, 'Contents/MacOS', appName);
const sourcePlaywrightModule = path.join(
	repoRoot,
	'.build/work',
	`vscodium-${releaseLock.upstream.vscodium.tag}`,
	'vscode/node_modules/playwright'
);
const bundledPlaywrightModule = path.join(
	repoRoot,
	'dist',
	`${appName}.app`,
	'Contents/Resources/app/node_modules/playwright-core'
);
const playwrightModule = fs.existsSync(path.join(sourcePlaywrightModule, 'package.json'))
	? sourcePlaywrightModule
	: bundledPlaywrightModule;
const { _electron: electron } = require(playwrightModule);

const qaExtensions = process.env.DBCODE_WRAPPER_QA_EXTENSIONS_DIR;
assert.ok(
	qaExtensions && path.isAbsolute(qaExtensions),
	'DBCODE_WRAPPER_QA_EXTENSIONS_DIR must name the isolated QA extension directory.'
);
const qaRoot = process.env.DBCODE_WRAPPER_QA_ROOT;
assert.ok(
	qaRoot && path.isAbsolute(qaRoot),
	'DBCODE_WRAPPER_QA_ROOT must name the registered rendered-evidence root.'
);
let qaProfileLayout;
try {
	qaProfileLayout = JSON.parse(process.env.DBCODE_WRAPPER_PROFILE_LAYOUT_JSON);
} catch {
	assert.fail('DBCODE_WRAPPER_PROFILE_LAYOUT_JSON must contain the canonical QA profile layout.');
}
assert.equal(qaProfileLayout.profile_name, 'qa');
assert.equal(qaProfileLayout.paths.state, path.join(qaRoot, 'profile'));
assert.equal(qaProfileLayout.paths.extensions, qaExtensions);

const outputRoot = process.env.DBCODE_WRAPPER_RENDERED_OUTPUT_ROOT;
assert.ok(
	outputRoot && path.isAbsolute(outputRoot),
	'DBCODE_WRAPPER_RENDERED_OUTPUT_ROOT must name the rendered-screenshot root.'
);
const renderedMode = process.env.DBCODE_WRAPPER_RENDERED_MODE ?? 'smoke';
assert.ok(
	renderedMode === 'smoke' || renderedMode === 'connection-catalogue',
	'DBCODE_WRAPPER_RENDERED_MODE must be smoke or connection-catalogue.'
);
const releaseSetId = process.env.DBCODE_WRAPPER_RELEASE_SET_ID;
assert.ok(releaseSetId, 'DBCODE_WRAPPER_RELEASE_SET_ID must identify the built release set.');

const profileRoot = qaProfileLayout.paths.state;
const userDataRoot = qaProfileLayout.paths.user_data ?? path.join(profileRoot, 'user-data');
const sharedDataRoot = qaProfileLayout.paths.shared_data ?? path.join(profileRoot, 'shared-data');
const cacheRoot = qaProfileLayout.paths.cache;
const logRoot = qaProfileLayout.paths.logs;
const workspacePath = path.join(qaRoot, 'workspace');
const scratchFilesPath = path.join(profileRoot, 'scratch-files');
const settingsPath = path.join(userDataRoot, 'User/settings.json');
const projectQueryPath = path.join(repoRoot, 'host/qa/project-query.sql');
const timeout = Number(process.env.DBCODE_WRAPPER_QA_TIMEOUT_MS ?? 60000);
const reportPath = path.join(
	outputRoot,
	renderedMode === 'connection-catalogue'
		? 'connection-catalogue-rendered-report.json'
		: 'focused-shell-rendered-report.json'
);

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
	return {
		directory,
		id: `${manifest.publisher}.${manifest.name}`,
		version: manifest.version,
		manifest
	};
});
const expectedRuntimeExtensions = [
	releaseLock.extension.dbcode,
	...releaseLock.extension.python_notebooks.packages
].map(extension => `${extension.id}@${extension.version}`).sort();
assert.deepEqual(
	qaExtensionRecords.map(extension => `${extension.id}@${extension.version}`).sort(),
	expectedRuntimeExtensions,
	'The persistent QA profile must contain the exact locked DBCode and Python-notebook release set.'
);
const dbcodeRecord = qaExtensionRecords.find(extension => extension.id === 'dbcode.dbcode');
assert.ok(dbcodeRecord, 'The persistent QA profile does not contain DBCode.');
assert.equal(dbcodeRecord.version, featurePolicy.extension.version);

const advancedToolLabels = [
	'New DBCode Notebook',
	'Start Python Kernel…',
	'Query Builder',
	'DBCode Settings…',
	'AI: Choose Provider',
	'AI: Configure Custom Model…',
	'AI: Set Custom Model API Key…'
];
const unavailableToolLabels = [
	'Open Data File…',
	'Open Scratch Files Folder',
	'AI: Change Model',
	'MCP: Start HTTP Server',
	'MCP: Stop HTTP Server',
	'MCP: Revoke OAuth Tokens'
];

fs.mkdirSync(outputRoot, { recursive: true });
fs.mkdirSync(workspacePath, { recursive: true });
fs.mkdirSync(cacheRoot, { recursive: true });
fs.mkdirSync(logRoot, { recursive: true });
assert.ok(fs.existsSync(settingsPath), 'The prepared persistent QA profile is missing its managed settings.');
preparePersistentQaSettings(settingsPath, scratchFilesPath);

const report = {
	startedAt: new Date().toISOString(),
	mode: renderedMode,
	profile: {
		name: qaProfileLayout.profile_name,
		state: profileRoot,
		persistent: true
	},
	releaseSetId,
	checks: [],
	warnings: [],
	errors: []
};

function record(name, details = {}) {
	report.checks.push({ name, ...details });
	console.log(`PASS ${name}`, JSON.stringify(details));
}

function visitFiles(root, visitor) {
	if (!fs.existsSync(root)) {
		return;
	}
	for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
		const entryPath = path.join(root, entry.name);
		if (entry.isDirectory()) {
			visitFiles(entryPath, visitor);
		} else if (entry.isFile()) {
			visitor(entryPath);
		}
	}
}

function captureLogOffsets() {
	const offsets = new Map();
	visitFiles(logRoot, logPath => {
		if (logPath.endsWith('.log')) {
			offsets.set(logPath, fs.statSync(logPath).size);
		}
	});
	return offsets;
}

function scanCurrentExtensionHostLogs(offsets) {
	const findings = [];
	const knownPackageWarnings = [];
	const knownShutdownWarnings = [];
	const requiredExtensionIds = new Set(qaExtensionRecords.map(extension => extension.id));
	visitFiles(logRoot, logPath => {
		if (!logPath.endsWith('.log')) {
			return;
		}
		const relativePath = path.relative(logRoot, logPath);
		const pathParts = relativePath.split(path.sep);
		const extensionHostIndex = pathParts.indexOf('exthost');
		if (extensionHostIndex < 0) {
			return;
		}
		const extensionLogOwner = pathParts[extensionHostIndex + 1];
		if (
			extensionLogOwner !== 'exthost.log'
			&& !requiredExtensionIds.has(extensionLogOwner)
			&& !extensionLogOwner.startsWith('output_logging_')
		) {
			return;
		}
		const contents = fs.readFileSync(logPath, 'utf8');
		const currentContents = contents.slice(Math.min(offsets.get(logPath) ?? 0, contents.length));
		const lines = currentContents.split(/\r?\n/);
		for (const [index, line] of lines.entries()) {
			if (!/\[(?:error|critical)\]|\bFATAL\b/i.test(line)) {
				continue;
			}
			const finding = `${relativePath}:${index + 1}: ${line}`;
			if (
				line.includes("Failed to read 'SQLite Binary' version file")
				|| line.includes('Unable to find workspace for given file')
			) {
				knownPackageWarnings.push(finding);
			} else if (isExpectedRuntimeExtensionShutdownChannelClose(lines, index)) {
				knownShutdownWarnings.push(finding);
			} else {
				findings.push(finding);
			}
		}
	});
	for (const warning of knownPackageWarnings) {
		report.warnings.push(`Pinned DBCode package warning: ${warning}`);
	}
	for (const warning of knownShutdownWarnings) {
		report.warnings.push(`Clean extension-host shutdown warning: ${warning}`);
	}
	assert.deepEqual(
		findings,
		[],
		`Required runtime extensions emitted unexpected errors in this run:\n${findings.join('\n')}`
	);
	record('current runtime-extension logs contain no unexpected activation errors', {
		knownPackageWarningCount: knownPackageWarnings.length,
		knownShutdownWarningCount: knownShutdownWarnings.length
	});
}

function seedReleaseStatus() {
	const stateRoot = path.join(userDataRoot, 'User/globalStorage/dbcode-wrapper.release-status');
	const statePath = path.join(stateRoot, 'release-status-state.json');
	const checkedAt = new Date().toISOString();
	fs.mkdirSync(stateRoot, { recursive: true });
	fs.writeFileSync(statePath, `${JSON.stringify({
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
	}, null, 2)}\n`, { mode: 0o600 });
}

function launchArgs() {
	return [
		'--user-data-dir', userDataRoot,
		'--extensions-dir', qaExtensions,
		'--shared-data-dir', sharedDataRoot,
		'--disk-cache-dir', cacheRoot,
		'--logsPath', logRoot,
		'--disable-extension', 'dbcode-wrapper.profile-migration',
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

async function launch() {
	const app = await electron.launch({
		executablePath: productionExecutable,
		args: launchArgs(),
		env: process.env
	});
	const page = await app.firstWindow({ timeout });
	let collectDiagnostics = true;
	page.on('console', message => {
		if (!collectDiagnostics) {
			return;
		}
		if (message.type() === 'warning') {
			report.warnings.push(message.text());
		}
		if (message.type() !== 'error') {
			return;
		}
		const location = message.location();
		if (
			message.text() === 'Failed to load resource: net::ERR_FILE_NOT_FOUND'
			&& location.url.endsWith('/resources/svgs/success-gutter.svg')
		) {
			report.warnings.push(`Pinned DBCode package references a missing optional icon: ${location.url}`);
		} else if (message.text().includes('[DEP0040]') && message.text().includes('punycode')) {
			report.warnings.push(`Pinned runtime deprecation warning: ${message.text()}`);
		} else {
			report.errors.push(
				`console: ${message.text()}${location.url ? ` at ${location.url}:${location.lineNumber}` : ''}`
			);
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

async function setWindowSize(app, page, width, height) {
	await app.evaluate(({ BrowserWindow }, size) => {
		const window = BrowserWindow.getFocusedWindow()
			?? BrowserWindow.getAllWindows().find(candidate => candidate.isVisible());
		if (!window) {
			throw new Error('The DBCode Wrapper window is not available.');
		}
		window.setContentSize(size.width, size.height, false);
	}, { width, height });
	await page.waitForFunction(
		size => innerWidth === size.width && innerHeight === size.height,
		{ width, height }
	);
}

async function waitForFocusedShell(app, page) {
	await setWindowSize(app, page, 1440, 900);
	await page.locator('.dbcode-wrapper-toolbar').waitFor({ timeout });
	await page.waitForFunction(
		() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDbcodeState === 'active',
		null,
		{ timeout }
	);
	await page.waitForTimeout(750);
}

async function geometry(page) {
	return page.evaluate(() => {
		const visible = selector => {
			const element = document.querySelector(selector);
			if (!element) {
				return false;
			}
			const bounds = element.getBoundingClientRect();
			return getComputedStyle(element).display !== 'none' && bounds.width > 0 && bounds.height > 0;
		};
		const root = document.querySelector('.monaco-workbench');
		return {
			dataset: root ? { ...root.dataset } : {},
			panelVisible: visible('.part.panel'),
			sidebarVisible: visible('.part.sidebar'),
			terminalVisible: visible('.terminal-wrapper') || visible('.terminal-instance'),
			activitybarVisible: visible('.part.activitybar'),
			statusbarVisible: visible('.part.statusbar'),
			commandCenterVisible: visible('.command-center-center'),
			quickInputVisible: visible('.quick-input-widget'),
			horizontalOverflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
			toolbarActions: [...document.querySelectorAll('.dbcode-wrapper-toolbar button')].map(button => ({
				action: button.dataset.dbcodeWrapperAction,
				label: button.getAttribute('aria-label'),
				disabled: button.disabled
			}))
		};
	});
}

async function waitForDrawerView(page, viewId) {
	try {
		await page.waitForFunction(expectedViewId => {
			const root = document.querySelector('.monaco-workbench');
			return root?.dataset.dbcodeWrapperDrawer === 'open'
				&& root.dataset.dbcodeWrapperDrawerView === expectedViewId;
		}, viewId, { timeout: 15000 });
	} catch (error) {
		const state = await geometry(page);
		const sidebarText = (await page.locator('.part.sidebar').textContent().catch(() => '')).slice(0, 500);
		throw new Error(
			`DBCode drawer ${viewId} did not open. Rendered state: ${JSON.stringify({ state, sidebarText })}`,
			{ cause: error }
		);
	}
}

async function visibleContextMenuText(page) {
	return page.evaluate(() => [...document.querySelectorAll('.context-view')]
		.filter(element => {
			const bounds = element.getBoundingClientRect();
			return getComputedStyle(element).display !== 'none' && bounds.width > 0 && bounds.height > 0;
		})
		.map(element => element.textContent ?? '')
		.join(' '));
}

async function openToolbarMenu(page, action) {
	for (let attempt = 0; attempt < 4; attempt++) {
		if (!(await visibleContextMenuText(page))) {
			break;
		}
		await page.keyboard.press('Escape');
		await page.waitForTimeout(100);
	}
	await page.locator(`[data-dbcode-wrapper-action="${action}"]`).click();
	await page.waitForFunction(() => [...document.querySelectorAll('.context-view')].some(element => {
		const bounds = element.getBoundingClientRect();
		return getComputedStyle(element).display !== 'none' && bounds.width > 0 && bounds.height > 0;
	}));
	return visibleContextMenuText(page);
}

async function clickMainCanvas(page) {
	const editor = page.locator('.part.editor');
	const bounds = await editor.boundingBox();
	assert.ok(bounds && bounds.width > 80 && bounds.height > 80, 'The query canvas is not available.');
	await page.mouse.click(bounds.x + bounds.width - 30, bounds.y + bounds.height - 30);
}

async function dismissQuickInput(page) {
	const quickInput = page.locator('.quick-input-widget');
	for (let attempt = 0; attempt < 6 && await quickInput.isVisible().catch(() => false); attempt++) {
		await page.keyboard.press('Escape');
		await page.waitForTimeout(150);
	}
	assert.equal(await quickInput.isVisible().catch(() => false), false, 'A DBCode quick input stayed open.');
}

async function assertQuickInputDismissesOnOutsideClick(page) {
	const quickInput = page.locator('.quick-input-widget');
	await quickInput.waitFor({ state: 'visible', timeout: 15000 });
	const input = quickInput.locator('input').first();
	if (await input.count()) {
		await input.click();
		assert.equal(await quickInput.isVisible(), true);
	}
	await clickMainCanvas(page);
	await quickInput.waitFor({ state: 'hidden', timeout: 5000 });
}

async function assertExpandedQuickInputAboveDatabaseToolbar(page, label) {
	const overlap = await page.evaluate(() => {
		const quickInput = document.querySelector('.quick-input-widget');
		const toolbar = document.querySelector('.dbcode-wrapper-toolbar');
		if (!(quickInput instanceof HTMLElement) || !(toolbar instanceof HTMLElement)) {
			return null;
		}
		const originalTop = quickInput.style.top;
		quickInput.style.top = '6px';
		const quickInputBounds = quickInput.getBoundingClientRect();
		const toolbarBounds = toolbar.getBoundingClientRect();
		const left = Math.max(quickInputBounds.left, toolbarBounds.left);
		const right = Math.min(quickInputBounds.right, toolbarBounds.right);
		const top = Math.max(quickInputBounds.top, toolbarBounds.top);
		const bottom = Math.min(quickInputBounds.bottom, toolbarBounds.bottom);
		const hasOverlap = right > left && bottom > top;
		const topElement = hasOverlap
			? document.elementFromPoint((left + right) / 2, (top + bottom) / 2)
			: null;
		const result = {
			hasOverlap,
			quickInputOwnsOverlap: Boolean(topElement && quickInput.contains(topElement)),
			quickInputZIndex: getComputedStyle(quickInput).zIndex,
			toolbarZIndex: getComputedStyle(toolbar).zIndex
		};
		quickInput.style.top = originalTop;
		return result;
	});
	assert.ok(overlap, `${label} did not expose a quick input.`);
	assert.equal(overlap.hasOverlap, true);
	assert.equal(overlap.quickInputOwnsOverlap, true);
	return overlap;
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

async function findDbcodePanelFrame(page, expectedText, frameTimeout = 30000) {
	const deadline = Date.now() + frameTimeout;
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
		await page.waitForTimeout(250);
	}
	throw new Error(`DBCode did not render the expected panel content: ${String(expectedText)}.`);
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

async function openConnectionsHome(page) {
	const button = page.locator('[data-dbcode-wrapper-action="connections"]');
	if (
		await page.locator('.monaco-workbench').getAttribute('data-dbcode-wrapper-connections-home')
		!== 'open'
	) {
		await button.click();
	}
	await page.waitForFunction(
		() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperConnectionsHome === 'open'
	);
	return findDbcodePanelFrame(page, /New connection/i);
}

async function closeConnectionsHome(page) {
	if (
		await page.locator('.monaco-workbench').getAttribute('data-dbcode-wrapper-connections-home')
		=== 'open'
	) {
		await page.locator('.dbcode-wrapper-connections-home-close').click();
	}
	await page.waitForFunction(
		() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperConnectionsHome === 'closed'
	);
}

async function captureConnectionCatalogueSnapshot(page, frameTimeout = 20000) {
	const deadline = Date.now() + frameTimeout;
	while (Date.now() < deadline) {
		for (const frame of page.frames()) {
			if (!frame.url().includes('/fake.html')) {
				continue;
			}
			const sections = await frame.evaluate(() => {
				const connectionUi = document.querySelector('connection-ui');
				const picker = connectionUi?.shadowRoot?.querySelector('connection-picker');
				const pickerRoot = picker?.shadowRoot;
				if (!pickerRoot) {
					return null;
				}
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
	throw new Error('DBCode did not expose its counted New Connection catalogue.');
}

function verifyRenderedConnectionCatalogue(snapshot) {
	return verifyConnectionCatalogueSnapshot(
		snapshot,
		featurePolicy.connection_capability_contract.catalogue_snapshot
	);
}

async function verifyConnectionCatalogue(page) {
	const home = await openConnectionsHome(page);
	assert.match(home.text, /Sample database/i);
	assert.match(home.text, /Import connections/i);
	assert.match(home.text, /Open SQL file/i);
	assert.equal(
		await clickVisibleButtonAcrossFrames(page, /New connection/i),
		true,
		'Connections Home did not expose New connection.'
	);
	const snapshot = await captureConnectionCatalogueSnapshot(page);
	verifyRenderedConnectionCatalogue(snapshot);
	record('unchanged DBCode exposes the reviewed New Connection catalogue', {
		evidence: 'rendered',
		catalogue: snapshot,
		wrapperDatabaseAllowlist: false,
		rawLabelsStored: false
	});
	await dismissQuickInput(page);
	await closeConnectionsHome(page);
	return snapshot;
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

async function verifySqlRoute(app, page) {
	let openError;
	const calls = await withOpenDialogProbe(
		app,
		{ canceled: false, filePaths: [projectQueryPath] },
		async () => {
			await page.locator('[data-dbcode-wrapper-action="open-sql"]').click();
			try {
				await page.waitForFunction(
					expected => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperQueryName === expected,
					path.basename(projectQueryPath),
					{ timeout: 15000 }
				);
			} catch (error) {
				openError = error;
			}
		}
	);
	assert.equal(calls.length, 1, 'Open SQL File must open exactly one native SQL picker.');
	assert.deepEqual(calls[0].filters, [{ name: 'SQL query files', extensions: ['sql'] }]);
	assert.ok(calls[0].properties.includes('openFile'));
	assert.ok(!calls[0].properties.includes('openDirectory'));
	if (openError) {
		throw openError;
	}
	const editorText = (await page.locator('.part.editor').innerText()).replace(/\s+/g, ' ');
	assert.match(editorText, /SELECT 1 AS project_query_proof/i);
	record('Open SQL File renders the deterministic query without executing it', {
		evidence: 'rendered',
		query: path.basename(projectQueryPath),
		databaseRead: false,
		databaseWrite: false
	});
}

async function verifyFocusedShell(app, page) {
	const initial = await geometry(page);
	assert.deepEqual(initial.toolbarActions.map(item => item.action), [
		'connections',
		'connection-tools',
		'database-explorer',
		'drawer-toggle',
		'open-sql',
		'new-query',
		'queries',
		'tools',
		'release-status',
		'account'
	]);
	assert.equal(initial.activitybarVisible, false);
	assert.equal(initial.statusbarVisible, false);
	assert.equal(initial.commandCenterVisible, false);
	assert.equal(initial.terminalVisible, false);
	assert.ok(initial.horizontalOverflow <= 0);
	record('the focused shell renders only its DBCode-owned primary routes', {
		evidence: 'rendered',
		actions: initial.toolbarActions.map(item => item.action)
	});

	const toolsText = await openToolbarMenu(page, 'tools');
	for (const label of advancedToolLabels) {
		assert.ok(toolsText.includes(label), `DBCode tools is missing ${label}.`);
	}
	for (const label of unavailableToolLabels) {
		assert.ok(!toolsText.includes(label), `DBCode tools unexpectedly exposes ${label}.`);
	}
	await page.keyboard.press('Escape');
	record('DBCode tools preserves notebook, Query Builder, settings, and AI routes', {
		evidence: 'rendered',
		httpMcpLifecycleExposed: false
	});
	record('Query Builder remains reachable from DBCode Tools', {
		evidence: 'reachable',
		executed: false
	});
	record('the DBCode notebook route remains reachable without starting a kernel', {
		evidence: 'reachable',
		kernelStarted: false,
		permissionPromptExpected: false
	});
	record('DBCode AI provider, custom-model, and API-key routes remain reachable without sending data', {
		evidence: 'reachable',
		modelCallMade: false,
		secretEntered: false
	});
	record('DBCode Settings remains reachable from DBCode Tools without activating it', {
		evidence: 'reachable',
		executed: false
	});

	await openConnectionsHome(page);
	const homeState = await geometry(page);
	assert.equal(homeState.dataset.dbcodeWrapperConnectionsHome, 'open');
	assert.equal(homeState.terminalVisible, false);
	await page.screenshot({ path: path.join(outputRoot, 'focused-shell-persistent-qa-smoke.png') });
	await closeConnectionsHome(page);
	record('Connections Home owns the main canvas without opening Terminal');

	const explorer = page.locator('[data-dbcode-wrapper-action="database-explorer"]');
	await explorer.click();
	await waitForDrawerView(page, 'dbcode.connections.view');
	await clickMainCanvas(page);
	let drawerState = await geometry(page);
	assert.equal(drawerState.dataset.dbcodeWrapperDrawer, 'open');
	assert.equal(drawerState.sidebarVisible, true);
	await page.keyboard.press('Escape');
	drawerState = await geometry(page);
	assert.equal(drawerState.dataset.dbcodeWrapperDrawer, 'open');
	await explorer.click();
	await page.waitForFunction(
		() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawer === 'closed'
	);
	record('Database Explorer remains persistent across outside click and Escape');

	await openToolbarMenu(page, 'queries');
	await page.keyboard.press('Home');
	await page.keyboard.press('Enter');
	await waitForDrawerView(page, 'dbcode.history.view');
	await clickMainCanvas(page);
	drawerState = await geometry(page);
	assert.equal(drawerState.dataset.dbcodeWrapperDrawer, 'open');
	await page.keyboard.press('Escape');
	drawerState = await geometry(page);
	assert.equal(drawerState.dataset.dbcodeWrapperDrawer, 'open');
	const drawerToggle = page.locator('[data-dbcode-wrapper-action="drawer-toggle"]');
	assert.equal(await drawerToggle.getAttribute('aria-label'), 'Collapse drawer');
	assert.equal(await drawerToggle.getAttribute('aria-expanded'), 'true');
	await drawerToggle.click();
	await page.waitForFunction(
		() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawer === 'closed'
	);
	assert.equal(await drawerToggle.getAttribute('aria-label'), 'Expand drawer');
	assert.equal(await drawerToggle.getAttribute('aria-expanded'), 'false');
	await drawerToggle.click();
	await waitForDrawerView(page, 'dbcode.history.view');
	await openToolbarMenu(page, 'queries');
	await page.keyboard.press('End');
	await page.keyboard.press('Enter');
	await waitForDrawerView(page, 'dbcode.library.view');
	await drawerToggle.click();
	await page.waitForFunction(
		() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawer === 'closed'
	);
	record('History remains persistent, Library replaces it, and the control collapses and expands the drawer');

	await page.locator('[data-dbcode-wrapper-action="release-status"]').click();
	const releasePicker = page.locator('.quick-input-widget');
	await releasePicker.waitFor({ state: 'visible', timeout: 15000 });
	const overlap = await assertExpandedQuickInputAboveDatabaseToolbar(page, 'The release status picker');
	await assertQuickInputDismissesOnOutsideClick(page);
	record('the release status quick input stays above the toolbar and closes on outside click', {
		evidence: 'rendered',
		quickInputZIndex: overlap.quickInputZIndex,
		toolbarZIndex: overlap.toolbarZIndex
	});

	await verifySqlRoute(app, page);

	await page.locator('[data-dbcode-wrapper-action="account"]').click();
	await page.waitForFunction(
		() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawerView === 'dbcode.account.view'
	);
	assert.equal(await drawerToggle.isHidden(), true);
	await clickMainCanvas(page);
	await page.waitForFunction(
		() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawer === 'closed'
	);
	assert.equal(await drawerToggle.isVisible(), true);
	assert.equal(await drawerToggle.getAttribute('aria-label'), 'Expand drawer');
	await page.locator('[data-dbcode-wrapper-action="account"]').click();
	await page.waitForFunction(
		() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawerView === 'dbcode.account.view'
	);
	await page.keyboard.press('Escape');
	await page.waitForFunction(
		() => document.querySelector('.monaco-workbench')?.dataset.dbcodeWrapperDrawer === 'closed'
	);
	record('Account remains temporary and closes on outside click or Escape');
}

async function run() {
	seedReleaseStatus();
	const logOffsets = captureLogOffsets();
	let session;
	let failure;
	try {
		session = await launch();
		await waitForFocusedShell(session.app, session.page);
		await verifyConnectionCatalogue(session.page);
		if (renderedMode === 'smoke') {
			await verifyFocusedShell(session.app, session.page);
		}
		assert.deepEqual(report.errors, []);
	} catch (error) {
		failure = error;
	} finally {
		if (session) {
			try {
				await closeElectronSession(session, { force: Boolean(failure) });
			} catch (cleanupError) {
				if (!failure) {
					failure = cleanupError;
				} else {
					report.warnings.push(`Cleanup also failed: ${cleanupError.message}`);
				}
			}
		}
	}

	if (!failure) {
		try {
			scanCurrentExtensionHostLogs(logOffsets);
		} catch (error) {
			failure = error;
		}
	}
	report.completedAt = new Date().toISOString();
	report.status = failure ? 'failed' : 'passed';
	if (failure) {
		report.failure = failure.stack ?? String(failure);
	}
	fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
	if (failure) {
		throw failure;
	}
}

run().catch(error => {
	console.error(error);
	process.exitCode = 1;
});
