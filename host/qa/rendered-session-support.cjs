'use strict';

const fs = require('node:fs');
const path = require('node:path');

function preparePersistentQaSettings(settingsPath, scratchFilesPath) {
	const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
	const expected = {
		'window.menuStyle': 'custom',
		'workbench.list.openMode': 'doubleClick',
		'dbcode.scratchFiles.path': scratchFilesPath
	};
	if (Object.entries(expected).every(([key, value]) => settings[key] === value)) {
		return false;
	}

	Object.assign(settings, expected);
	const temporaryPath = path.join(
		path.dirname(settingsPath),
		`.${path.basename(settingsPath)}.rendered-qa-${process.pid}.tmp`
	);
	try {
		fs.writeFileSync(temporaryPath, `${JSON.stringify(settings, null, 2)}\n`, { mode: 0o600 });
		fs.renameSync(temporaryPath, settingsPath);
		fs.chmodSync(settingsPath, 0o600);
	} finally {
		fs.rmSync(temporaryPath, { force: true });
	}
	return true;
}

function childHasExited(child) {
	return child.exitCode !== null || child.signalCode !== null;
}

function waitForChildExit(child, timeoutMs) {
	if (childHasExited(child)) {
		return Promise.resolve(true);
	}
	return new Promise(resolve => {
		const onExit = () => {
			clearTimeout(timer);
			resolve(true);
		};
		const timer = setTimeout(() => {
			child.off('exit', onExit);
			resolve(childHasExited(child));
		}, timeoutMs);
		child.once('exit', onExit);
	});
}

async function closeElectronSession(
	session,
	{
		force = false,
		gracePeriodMs = 5000,
		killPeriodMs = 5000
	} = {}
) {
	session.stopDiagnostics();
	if (!force) {
		try {
			await session.app.close();
			return;
		} catch {
			// Fall back to the exact isolated child process below.
		}
	}

	const child = session.app.process();
	if (childHasExited(child)) {
		return;
	}
	child.kill('SIGTERM');
	if (await waitForChildExit(child, gracePeriodMs)) {
		return;
	}
	child.kill('SIGKILL');
	if (await waitForChildExit(child, killPeriodMs)) {
		return;
	}
	throw new Error('The isolated DBCode Wrapper child did not exit after TERM and KILL.');
}

module.exports = {
	closeElectronSession,
	preparePersistentQaSettings
};
