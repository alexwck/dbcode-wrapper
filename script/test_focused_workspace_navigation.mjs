import assert from 'node:assert/strict';
import test from 'node:test';

import {
	DBCODE_DRAWER_VIEWS,
	decideDbcodeDrawerTransition,
	isPersistentDbcodeDrawerView
} from '../host/code-oss-overlay/src/vs/workbench/contrib/dbcodeWrapper/browser/dbcodeWrapperDrawerNavigation.ts';

const openState = activeView => ({ open: true, activeView });
const closedState = { open: false, activeView: undefined };

test('Focused Workspace Navigation owns every retained drawer route', () => {
	assert.deepEqual(DBCODE_DRAWER_VIEWS, {
		connections: 'dbcode.connections.view',
		tunnels: 'dbcode.tunnels.view',
		authProfiles: 'dbcode.authProfiles.view',
		streams: 'dbcode.streams.view',
		history: 'dbcode.history.view',
		library: 'dbcode.library.view',
		account: 'dbcode.account.view'
	});

	for (const viewId of Object.values(DBCODE_DRAWER_VIEWS)) {
		assert.equal(isPersistentDbcodeDrawerView(viewId), viewId !== DBCODE_DRAWER_VIEWS.account);
	}
	assert.equal(isPersistentDbcodeDrawerView(undefined), false);
	assert.equal(isPersistentDbcodeDrawerView('dbcode.future.view'), true);
});

test('a route action opens its drawer or collapses the same visible drawer', () => {
	assert.deepEqual(
		decideDbcodeDrawerTransition(closedState, { kind: 'toggle', viewId: DBCODE_DRAWER_VIEWS.history }),
		{ kind: 'open', viewId: DBCODE_DRAWER_VIEWS.history }
	);
	assert.deepEqual(
		decideDbcodeDrawerTransition(openState(DBCODE_DRAWER_VIEWS.library), { kind: 'toggle', viewId: DBCODE_DRAWER_VIEWS.history }),
		{ kind: 'open', viewId: DBCODE_DRAWER_VIEWS.history }
	);
	assert.deepEqual(
		decideDbcodeDrawerTransition(openState(DBCODE_DRAWER_VIEWS.history), { kind: 'toggle', viewId: DBCODE_DRAWER_VIEWS.history }),
		{ kind: 'close' }
	);
});

test('outside, webview, and Escape dismissal close only Account', () => {
	assert.deepEqual(
		decideDbcodeDrawerTransition(openState(DBCODE_DRAWER_VIEWS.account), { kind: 'dismiss' }),
		{ kind: 'close' }
	);
	assert.deepEqual(
		decideDbcodeDrawerTransition(openState(DBCODE_DRAWER_VIEWS.connections), { kind: 'dismiss' }),
		{ kind: 'keep' }
	);
	assert.deepEqual(
		decideDbcodeDrawerTransition(closedState, { kind: 'dismiss' }),
		{ kind: 'keep' }
	);
});
