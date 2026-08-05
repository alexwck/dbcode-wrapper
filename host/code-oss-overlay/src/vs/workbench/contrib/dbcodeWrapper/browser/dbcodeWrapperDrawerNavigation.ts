/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

export const DBCODE_DRAWER_VIEWS = Object.freeze({
	connections: 'dbcode.connections.view',
	tunnels: 'dbcode.tunnels.view',
	authProfiles: 'dbcode.authProfiles.view',
	streams: 'dbcode.streams.view',
	history: 'dbcode.history.view',
	library: 'dbcode.library.view',
	account: 'dbcode.account.view'
} as const);

export type DbcodeDrawerViewId = typeof DBCODE_DRAWER_VIEWS[keyof typeof DBCODE_DRAWER_VIEWS];

export interface DbcodeDrawerState {
	readonly open: boolean;
	readonly activeView: string | undefined;
}

export type DbcodeDrawerIntent =
	| { readonly kind: 'toggle'; readonly viewId: DbcodeDrawerViewId }
	| { readonly kind: 'dismiss' };

export type DbcodeDrawerTransition =
	| { readonly kind: 'open'; readonly viewId: DbcodeDrawerViewId }
	| { readonly kind: 'close' }
	| { readonly kind: 'keep' };

export function isPersistentDbcodeDrawerView(viewId: string | undefined): boolean {
	return Boolean(viewId && viewId !== DBCODE_DRAWER_VIEWS.account);
}

export function decideDbcodeDrawerTransition(state: DbcodeDrawerState, intent: DbcodeDrawerIntent): DbcodeDrawerTransition {
	if (intent.kind === 'toggle') {
		return state.open && state.activeView === intent.viewId
			? { kind: 'close' }
			: { kind: 'open', viewId: intent.viewId };
	}

	return state.open && state.activeView && !isPersistentDbcodeDrawerView(state.activeView)
		? { kind: 'close' }
		: { kind: 'keep' };
}
