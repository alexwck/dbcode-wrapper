'use strict';

const assert = require('node:assert/strict');
const { isExpectedRuntimeExtensionShutdownChannelClose } = require('./extension-host-log-policy.cjs');

function shutdownLog(extensionPath, exitCode = 0) {
	return [
		'2026-07-27 00:59:58.998 [info] Extension host terminating: received terminate message from renderer',
		'2026-07-27 00:59:59.012 [error] Error: Channel has been closed',
		'\tat Object.appendLine (extensionHostProcess.js:137:3726)',
		`\tat P.logOutputMessage (${extensionPath}:2:2100381)`,
		'\tat ChildProcess.<anonymous> (extension.js:2:2317508)',
		`2026-07-27 00:59:59.015 [info] Extension host with pid 22619 exiting with code ${exitCode}`
	];
}

for (const extensionPath of [
	'/private/profile/extensions/dbcode.dbcode-1.36.4/out/extension/extension.js',
	'/private/profile/extensions/ms-python.python-2026.4.0/out/client/extension.js'
]) {
	const lines = shutdownLog(extensionPath);
	assert.equal(isExpectedRuntimeExtensionShutdownChannelClose(lines, 1), true);
}

assert.equal(
	isExpectedRuntimeExtensionShutdownChannelClose(
		shutdownLog('/private/profile/extensions/unrelated.extension-1.0.0/out/extension.js'),
		1
	),
	false
);
assert.equal(
	isExpectedRuntimeExtensionShutdownChannelClose(
		shutdownLog('/private/profile/extensions/ms-python.python-2026.4.0/out/client/extension.js', 1),
		1
	),
	false
);
assert.equal(
	isExpectedRuntimeExtensionShutdownChannelClose(
		shutdownLog('/private/profile/extensions/ms-python.python-2026.4.0/out/client/extension.js').filter(line => !line.includes('terminating')),
		0
	),
	false
);

console.log('Extension-host log policy checks passed.');
