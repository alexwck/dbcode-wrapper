'use strict';

const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const {
	closeElectronSession,
	preparePersistentQaSettings
} = require('./rendered-session-support.cjs');

class FakeChild extends EventEmitter {
	constructor(exitOnSignal = null) {
		super();
		this.exitCode = null;
		this.signalCode = null;
		this.exitOnSignal = exitOnSignal;
		this.signals = [];
	}

	kill(signal) {
		this.signals.push(signal);
		if (signal === this.exitOnSignal) {
			this.signalCode = signal;
			queueMicrotask(() => this.emit('exit', null, signal));
		}
		return true;
	}
}

function sessionFor(child, close = async () => undefined) {
	let diagnosticsStopped = false;
	return {
		session: {
			stopDiagnostics: () => {
				diagnosticsStopped = true;
			},
			app: {
				close,
				process: () => child
			}
		},
		diagnosticsStopped: () => diagnosticsStopped
	};
}

test('the persistent rendered profile gets deterministic QA settings without losing managed settings', () => {
	const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'dbcode-rendered-settings-'));
	const settingsPath = path.join(fixtureRoot, 'settings.json');
	const scratchFilesPath = path.join(fixtureRoot, 'scratch-files');
	try {
		fs.writeFileSync(settingsPath, `${JSON.stringify({
			'window.titleBarStyle': 'custom',
			'dbcode.resultLocation': 'beside'
		}, null, 2)}\n`, { mode: 0o600 });

		assert.equal(preparePersistentQaSettings(settingsPath, scratchFilesPath), true);
		assert.deepEqual(JSON.parse(fs.readFileSync(settingsPath, 'utf8')), {
			'window.titleBarStyle': 'custom',
			'dbcode.resultLocation': 'beside',
			'window.menuStyle': 'custom',
			'workbench.list.openMode': 'doubleClick',
			'dbcode.scratchFiles.path': scratchFilesPath
		});
		assert.equal(fs.statSync(settingsPath).mode & 0o777, 0o600);
		assert.equal(preparePersistentQaSettings(settingsPath, scratchFilesPath), false);
	} finally {
		fs.rmSync(fixtureRoot, { recursive: true, force: true });
	}
});

test('a normal close does not signal the isolated child', async () => {
	const child = new FakeChild();
	const fixture = sessionFor(child);

	await closeElectronSession(fixture.session, { gracePeriodMs: 5, killPeriodMs: 5 });

	assert.equal(fixture.diagnosticsStopped(), true);
	assert.deepEqual(child.signals, []);
});

test('a failed normal close falls back to TERM for the exact isolated child', async () => {
	const child = new FakeChild('SIGTERM');
	const fixture = sessionFor(child, async () => {
		throw new Error('close failed');
	});

	await closeElectronSession(fixture.session, { gracePeriodMs: 5, killPeriodMs: 5 });

	assert.deepEqual(child.signals, ['SIGTERM']);
});

test('a child that ignores TERM is killed and awaited', async () => {
	const child = new FakeChild('SIGKILL');
	const fixture = sessionFor(child);

	await closeElectronSession(fixture.session, {
		force: true,
		gracePeriodMs: 5,
		killPeriodMs: 5
	});

	assert.deepEqual(child.signals, ['SIGTERM', 'SIGKILL']);
});

test('cleanup reports a child that survives both exact signals', async () => {
	const child = new FakeChild();
	const fixture = sessionFor(child);

	await assert.rejects(
		closeElectronSession(fixture.session, {
			force: true,
			gracePeriodMs: 5,
			killPeriodMs: 5
		}),
		/isolated DBCode Wrapper child did not exit/
	);
	assert.deepEqual(child.signals, ['SIGTERM', 'SIGKILL']);
});
