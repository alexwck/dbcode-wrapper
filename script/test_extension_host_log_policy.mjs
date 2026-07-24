#!/usr/bin/env node

import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';

const require = createRequire(import.meta.url);
const { isExpectedDbcodeShutdownChannelClose } = require('../host/qa/extension-host-log-policy.cjs');

const cleanShutdownLines = [
	'2026-07-21 10:55:10.401 [info] Extension host terminating: received terminate message from renderer',
	'2026-07-21 10:55:10.448 [error] Error: Channel has been closed',
	'\tat Object.appendLine (extensionHostProcess.js:137:3726)',
	'\tat v.logOutputMessage (/qa/extensions/dbcode.dbcode-1.36.2/out/extension/extension.js:1:8265290)',
	'\tat v.error (/qa/extensions/dbcode.dbcode-1.36.2/out/extension/extension.js:1:8265111)',
	'\tat ChildProcess.<anonymous> (/qa/extensions/dbcode.dbcode-1.36.2/out/extension/extension.js:1:8317013)',
	'2026-07-21 10:55:10.454 [info] Extension host with pid 88766 exiting with code 0'
];

test('accepts only the DBCode child-process log race during a clean extension-host shutdown', () => {
	assert.equal(isExpectedDbcodeShutdownChannelClose(cleanShutdownLines, 1), true);
});

test('rejects a channel-close error that did not follow a renderer shutdown request', () => {
	const lines = cleanShutdownLines.slice(1);
	assert.equal(isExpectedDbcodeShutdownChannelClose(lines, 0), false);
});

test('rejects a channel-close error that did not come from the DBCode child-process logger', () => {
	const lines = cleanShutdownLines.map(line => line.replace('dbcode.dbcode-1.36.2', 'another.extension-1.0.0'));
	assert.equal(isExpectedDbcodeShutdownChannelClose(lines, 1), false);
});

test('rejects a channel-close error when the extension host exits unsuccessfully', () => {
	const lines = cleanShutdownLines.map(line => line.replace('exiting with code 0', 'exiting with code 1'));
	assert.equal(isExpectedDbcodeShutdownChannelClose(lines, 1), false);
});

test('rejects other errors during a clean shutdown', () => {
	const lines = cleanShutdownLines.with(1, '2026-07-21 10:55:10.448 [error] Error: DBCode activation failed');
	assert.equal(isExpectedDbcodeShutdownChannelClose(lines, 1), false);
});
