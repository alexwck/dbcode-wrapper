#!/usr/bin/env node

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { createRequire } from 'node:module';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

const require = createRequire(import.meta.url);
const { advancePreflight, createMigrationPlan, parseInventory } = require('../host/extensions/dbcode-wrapper-profile-migration/migration.js');
const { createProfileLayout } = require('../host/extensions/dbcode-wrapper-profile-migration/profile-layout.js');
const { deriveRecoveryLayout, recreateStandaloneProfile, requireMatchingRelaunchPath } = require('../host/extensions/dbcode-wrapper-profile-migration/profileRecovery.js');
const profileRecoveryWorker = require('../host/extensions/dbcode-wrapper-profile-migration/profileRecoveryWorker.js');
const { run: runRecoveryWorker } = profileRecoveryWorker;
const { ProfileSetup } = require('../host/extensions/dbcode-wrapper-profile-migration/profileSetup.js');
const {
  START_MIGRATION_COMMAND,
  START_RUNTIME_SETUP_COMMAND,
  createFirstRunCommandRouter
} = require('../host/extensions/dbcode-wrapper-profile-migration/firstRunCommandRouter.js');
const { cleanupReviewedInventory, stageReviewedInventory } = require('../host/extensions/dbcode-wrapper-profile-migration/staging.js');
const { renderProfileSetupHtml } = require('../host/extensions/dbcode-wrapper-profile-migration/view.js');
const {
  escapeHtml,
  renderWebviewDocument
} = require('../host/extensions/dbcode-wrapper-profile-migration/webviewSafety.js');

test('Profile Recovery Worker exposes only its maintained run interface', () => {
  assert.deepEqual(Object.keys(profileRecoveryWorker), ['run']);
});

test('first-run commands register before an activation phase is selected', async () => {
  const commands = new Map();
  const subscriptions = [];
  const errors = [];
  const router = createFirstRunCommandRouter({
    registerCommand(command, handler) {
      commands.set(command, handler);
      return { dispose() {} };
    },
    subscriptions,
    showError: message => errors.push(message)
  });

  assert.deepEqual([...commands.keys()].sort(), [
    START_MIGRATION_COMMAND,
    START_RUNTIME_SETUP_COMMAND
  ].sort());
  assert.equal(subscriptions.length, 2);

  await commands.get(START_MIGRATION_COMMAND)();
  await commands.get(START_RUNTIME_SETUP_COMMAND)();
  assert.deepEqual(errors, [
    'DBCode Wrapper first-run setup is still starting.',
    'DBCode Wrapper first-run setup is still starting.'
  ]);
});

test('Profile Setup routes through the required runtime prerequisite', async () => {
  const commands = new Map();
  const events = [];
  let runtimeRequired = true;
  const router = createFirstRunCommandRouter({
    registerCommand: (command, handler) => {
      commands.set(command, handler);
      return { dispose() {} };
    },
    subscriptions: [],
    showError: message => events.push(['error', message])
  });
  router.setRuntimeSetup({
    requiresSetup: () => runtimeRequired,
    open: () => events.push(['runtime'])
  });
  router.setProfileSetup({
    open: () => events.push(['profile'])
  });

  await commands.get(START_MIGRATION_COMMAND)();
  runtimeRequired = false;
  await commands.get(START_MIGRATION_COMMAND)();
  await commands.get(START_RUNTIME_SETUP_COMMAND)();

  assert.deepEqual(events, [
    ['runtime'],
    ['profile'],
    ['runtime']
  ]);
});

test('first-run command failures stay registered and fail with a sanitized message', async () => {
  const commands = new Map();
  const errors = [];
  const router = createFirstRunCommandRouter({
    registerCommand: (command, handler) => {
      commands.set(command, handler);
      return { dispose() {} };
    },
    subscriptions: [],
    showError: message => errors.push(message)
  });
  router.setUnavailable('DBCode Wrapper cannot verify its focused first-run setup configuration. The external runtime was not changed.');

  await commands.get(START_MIGRATION_COMMAND)();
  await commands.get(START_RUNTIME_SETUP_COMMAND)();

  assert.deepEqual(errors, [
    'DBCode Wrapper cannot verify its focused first-run setup configuration. The external runtime was not changed.',
    'DBCode Wrapper cannot verify its focused first-run setup configuration. The external runtime was not changed.'
  ]);
});

test('first-run webviews share one escaping, CSP, nonce, and action-message policy', () => {
  assert.equal(escapeHtml(`<script data-value="'">&`), '&lt;script data-value=&quot;&#039;&quot;&gt;&amp;');
  const page = renderWebviewDocument({
    title: 'Setup <unsafe>',
    trustedStylesCss: 'body { color: red; }',
    trustedBodyHtml: '<main>Trusted body</main>'
  });
  const nonce = page.match(/script-src 'nonce-([^']+)'/)?.[1];

  assert.ok(nonce);
  assert.match(page, /<title>Setup &lt;unsafe&gt;<\/title>/);
  assert.ok(page.includes(`<script nonce="${nonce}">`));
  assert.match(page, /acquireVsCodeApi/);
  assert.match(page, /button\.dataset\.action/);
});

test('Profile Setup persists start-clean completion before opening connections', async () => {
  const events = [];
  let persistedState;
  const setup = new ProfileSetup({
    closePanel: () => events.push(['close-panel']),
    focusConnections: async () => events.push(['focus-connections']),
    loadState: async () => persistedState,
    now: () => new Date('2026-07-27T18:30:00Z'),
    render: view => events.push(['render', view]),
    saveState: async state => {
      persistedState = state;
      events.push(['save', state]);
    }
  });

  assert.equal(await setup.requiresSetup(), true);
  await setup.open();
  await setup.dispatch('start-fresh');
  assert.equal(await setup.requiresSetup(), false);
  await setup.dispatch('open-connections');

  assert.deepEqual(events, [
    ['render', { kind: 'welcome' }],
    ['save', {
      schemaVersion: 1,
      status: 'complete',
      mode: 'fresh',
      deferredConnectionCount: 0,
      completedAt: '2026-07-27T18:30:00.000Z'
    }],
    ['render', {
      kind: 'complete',
      message: 'A Standalone DBCode Profile is ready. Add connections and activate DBCode normally.'
    }],
    ['focus-connections'],
    ['close-panel']
  ]);
});

test('Profile Setup owns reviewed import, cleanup, preflight, and completion order', async () => {
  const events = [];
  const connections = [
    { name: 'Analytics', type: 'postgresql', host: 'db.internal' },
    { name: 'Deferred DuckDB', type: 'duckdb', path: '/Users/alex/data/deferred-file.duckdb' }
  ];
  const staged = {
    sessionDirectory: '/private/staging/session-reviewed',
    inventoryPath: '/private/staging/session-reviewed/reviewed-connections.csv'
  };
  const setup = new ProfileSetup({
    chooseInventory: async () => ({
      contents: JSON.stringify(connections),
      format: 'json'
    }),
    cleanupInventory: async reviewed => events.push(['cleanup', reviewed]),
    copyText: async value => events.push(['copy', value]),
    dbcodeVersion: () => '1.14.5',
    now: () => new Date('2026-07-27T18:45:00Z'),
    openDbcodeImport: async () => events.push(['open-dbcode-import']),
    render: view => events.push(['render', view]),
    revealPanel: () => events.push(['reveal-panel']),
    saveState: async state => events.push(['save', state]),
    showInfo: async message => events.push(['info', message]),
    stageInventory: async ready => {
      events.push(['stage', ready]);
      return staged;
    }
  });

  await setup.dispatch('choose-file');
  await setup.dispatch('confirm-review');
  await setup.dispatch('copy-path');
  await setup.dispatch('open-import');
  await setup.dispatch('finish-import');
  await setup.dispatch('preflight-passed');

  const plan = {
    ready: [connections[0]],
    preflight: [{
      connection: connections[1],
      kind: 'duckdb-hyphen-path',
      mode: 'read-only'
    }]
  };
  assert.deepEqual(events, [
    ['render', { kind: 'preview', plan }],
    ['stage', plan.ready],
    ['render', { kind: 'import', inventoryPath: staged.inventoryPath }],
    ['copy', staged.inventoryPath],
    ['info', 'The reviewed temporary file path was copied.'],
    ['render', { kind: 'import', inventoryPath: staged.inventoryPath }],
    ['open-dbcode-import'],
    ['reveal-panel'],
    ['render', { kind: 'confirm-import' }],
    ['cleanup', staged],
    ['render', {
      kind: 'preflight',
      dbcodeVersion: '1.14.5',
      connection: connections[1],
      position: 1,
      total: 1
    }],
    ['save', {
      schemaVersion: 1,
      status: 'complete',
      mode: 'imported-with-preflight',
      deferredConnectionCount: 0,
      completedAt: '2026-07-27T18:45:00.000Z'
    }],
    ['render', {
      kind: 'complete',
      message: 'Profile setup is complete and every conditional DuckDB preflight passed.'
    }]
  ]);
});

test('Profile Setup cleans staged data after cancel, action failure, and panel close', async () => {
  const events = [];
  let session = 0;
  let importShouldFail = false;
  const setup = new ProfileSetup({
    chooseInventory: async () => ({
      contents: JSON.stringify([
        { name: 'Analytics', type: 'postgresql', host: 'db.internal' }
      ]),
      format: 'json'
    }),
    cleanupInventory: async staged => events.push(['cleanup', staged.sessionDirectory]),
    openDbcodeImport: async () => {
      if (importShouldFail) {
        throw new Error('DBCode import did not open.');
      }
    },
    render: view => events.push(['render', view.kind]),
    showError: async message => events.push(['error', message]),
    stageInventory: async () => {
      session += 1;
      return {
        sessionDirectory: `/private/staging/session-${session}`,
        inventoryPath: `/private/staging/session-${session}/reviewed-connections.csv`
      };
    }
  });

  await setup.dispatch('choose-file');
  await setup.dispatch('confirm-review');
  await setup.dispatch('cancel');

  await setup.dispatch('choose-file');
  await setup.dispatch('confirm-review');
  importShouldFail = true;
  await setup.dispatch('open-import');

  importShouldFail = false;
  await setup.dispatch('confirm-review');
  await setup.panelClosed();
  await setup.dispatch('confirm-review');

  assert.deepEqual(
    events.filter(([kind]) => ['cleanup', 'error'].includes(kind)),
    [
      ['cleanup', '/private/staging/session-1'],
      ['cleanup', '/private/staging/session-2'],
      ['error', 'This connection inventory was not accepted. DBCode import did not open.'],
      ['cleanup', '/private/staging/session-3']
    ]
  );
  assert.equal(session, 3);
  assert.deepEqual(
    events.filter(([kind]) => kind === 'render').map(([, view]) => view),
    ['preview', 'import', 'welcome', 'preview', 'import', 'preview', 'import']
  );
});

test('Profile Setup keeps the action error when staged cleanup also fails', async () => {
  const errors = [];
  let cleanupAttempts = 0;
  const setup = new ProfileSetup({
    chooseInventory: async () => ({
      contents: JSON.stringify([
        { name: 'Analytics', type: 'postgresql', host: 'db.internal' }
      ]),
      format: 'json'
    }),
    cleanupInventory: async () => {
      cleanupAttempts += 1;
      throw new Error('Temporary file cleanup failed.');
    },
    openDbcodeImport: async () => {
      throw new Error('DBCode import did not open.');
    },
    render: () => undefined,
    showError: async message => errors.push(message),
    stageInventory: async () => ({
      sessionDirectory: '/private/staging/session-cleanup-failure',
      inventoryPath: '/private/staging/session-cleanup-failure/reviewed-connections.csv'
    })
  });

  await setup.dispatch('choose-file');
  await setup.dispatch('confirm-review');
  await setup.dispatch('open-import');

  assert.equal(cleanupAttempts, 1);
  assert.deepEqual(errors, [
    'This connection inventory was not accepted. DBCode import did not open. The temporary reviewed file could not be removed automatically.'
  ]);
});

test('Profile Setup validates recovery, cleans staging, starts the worker, then quits', async () => {
  const events = [];
  const staged = {
    sessionDirectory: '/private/staging/session-recovery',
    inventoryPath: '/private/staging/session-recovery/reviewed-connections.csv'
  };
  const layout = {
    profileLayout: { profileName: 'default' },
    userDataRoot: '/Users/alex/Library/Application Support/DBCode Wrapper',
    extensionsRoot: '/Users/alex/.dbcode-wrapper/extensions',
    sharedDataRoot: '/Users/alex/.dbcode-wrapper-shared',
    backupRoot: '/Users/alex/Library/Application Support/DBCode Wrapper Profile Backups',
    cacheRoot: '/Users/alex/Library/Application Support/DBCode Wrapper/Cache',
    logsRoot: '/Users/alex/Library/Application Support/DBCode Wrapper/logs',
    appBundle: '/Applications/DBCode Wrapper.app'
  };
  const relaunchArgs = [
    '--user-data-dir', layout.userDataRoot,
    '--extensions-dir', layout.extensionsRoot,
    '--shared-data-dir', layout.sharedDataRoot,
    '--disk-cache-dir', layout.cacheRoot,
    '--logsPath', layout.logsRoot
  ];
  const setup = new ProfileSetup({
    chooseInventory: async () => ({
      contents: JSON.stringify([
        { name: 'Analytics', type: 'postgresql', host: 'db.internal' }
      ]),
      format: 'json'
    }),
    cleanupInventory: async reviewed => events.push(['cleanup', reviewed]),
    confirmRecovery: async () => {
      events.push(['confirm-recovery']);
      return true;
    },
    now: () => new Date('2026-07-27T19:00:00Z'),
    quit: async () => events.push(['quit']),
    randomUUID: () => '12345678-1234-1234-1234-123456789abc',
    recoveryContext: () => ({
      layout,
      processPids: [41, 42, 42],
      relaunchArguments: JSON.stringify(relaunchArgs),
      settingsSource: '/Applications/DBCode Wrapper.app/Contents/Resources/app/extensions/dbcode-wrapper-profile-migration/managed-settings.json'
    }),
    render: () => undefined,
    stageInventory: async () => staged,
    startRecovery: async request => events.push(['start-recovery', request])
  });

  await setup.dispatch('choose-file');
  await setup.dispatch('confirm-review');
  await setup.dispatch('recreate-profile');

  assert.deepEqual(events, [
    ['confirm-recovery'],
    ['cleanup', staged],
    ['start-recovery', {
      processPids: [41, 42],
      recoveryId: '20260727T190000000Z-12345678-1234-1234-1234-123456789abc',
      profileLayout: layout.profileLayout,
      userDataRoot: layout.userDataRoot,
      sharedDataRoot: layout.sharedDataRoot,
      backupRoot: layout.backupRoot,
      settingsSource: '/Applications/DBCode Wrapper.app/Contents/Resources/app/extensions/dbcode-wrapper-profile-migration/managed-settings.json',
      appBundle: layout.appBundle,
      relaunchArgs,
      relaunchApplication: true
    }],
    ['quit']
  ]);
});

test('a reviewed JSON inventory exposes only safe connection details', () => {
  assert.deepEqual(parseInventory(JSON.stringify([
    {
      name: 'Analytics',
      type: 'postgresql',
      host: 'db.internal',
      port: 5432,
      database: 'warehouse',
      username: 'analyst',
      ssl: 'require'
    },
    {
      name: 'Local DuckDB',
      type: 'duckdb',
      path: '/Users/alex/data/warehouse.duckdb'
    }
  ]), 'json'), [
    {
      name: 'Analytics',
      type: 'postgresql',
      host: 'db.internal',
      port: 5432,
      database: 'warehouse',
      username: 'analyst',
      ssl: 'require'
    },
    {
      name: 'Local DuckDB',
      type: 'duckdb',
      path: '/Users/alex/data/warehouse.duckdb'
    }
  ]);
});

test('credentials, licence data, and old connection identifiers are rejected without echoing values', () => {
  const unsafeInventories = [
    [{ name: 'Secret password', password: 'do-not-echo-password' }],
    [{ name: 'Old identity', connectionId: 'do-not-echo-id' }],
    [{ name: 'Licence copy', licenseKey: 'do-not-echo-licence' }],
    [{ name: 'Private key', privateKey: '-----BEGIN PRIVATE KEY-----do-not-echo-key' }],
    [{ name: 'Embedded URL', host: 'postgresql://alice:do-not-echo-url@db.internal/main' }],
    [{ name: 'Embedded URL without username', host: 'postgresql://:do-not-echo-empty-user@db.internal/main' }],
    [{ name: 'Padded embedded URL', host: '  postgresql://alice:do-not-echo-padded-url@db.internal/main  ' }],
    [{ name: 'JDBC embedded URL', host: 'jdbc:postgresql://alice:do-not-echo-jdbc-url@db.internal/main' }],
    [{ name: 'Described embedded URL', host: 'use postgresql://alice:do-not-echo-described-url@db.internal/main' }]
  ];

  for (const inventory of unsafeInventories) {
    assert.throws(
      () => parseInventory(JSON.stringify(inventory), 'json'),
      error => /not allowed|embedded credentials/i.test(error.message) && !error.message.includes('do-not-echo')
    );
  }
});

test('malformed JSON is rejected without echoing the selected file contents', () => {
  const protectedFragment = 'do-not-echo-malformed-token';
  assert.throws(
    () => parseInventory(`[{"name":"Analytics","token":"${protectedFragment}"`, 'json'),
    error => error.message === 'The JSON inventory is not valid.' && !error.message.includes(protectedFragment)
  );
});

test('a CSV inventory supports reviewed field aliases and quoted values', () => {
  const csv = [
    'connection_name,database_type,server,port,database_name,user,ssl_mode,file_path',
    '"Reporting, read only",postgresql,db.internal,5432,analytics,reporter,verify-full,',
    'Local DuckDB,duckdb,,,,,,/Users/alex/data/local-data.duckdb'
  ].join('\n');

  assert.deepEqual(parseInventory(csv, 'csv'), [
    {
      name: 'Reporting, read only',
      type: 'postgresql',
      host: 'db.internal',
      port: 5432,
      database: 'analytics',
      username: 'reporter',
      ssl: 'verify-full'
    },
    {
      name: 'Local DuckDB',
      type: 'duckdb',
      path: '/Users/alex/data/local-data.duckdb'
    }
  ]);
});

test('invalid ports, SSL choices, local paths, and nested values are rejected', () => {
  const invalidConnections = [
    { name: 'Bad port', type: 'postgresql', host: 'db.internal', port: 70000 },
    { name: 'Bad SSL', type: 'postgresql', host: 'db.internal', ssl: 'trust-anything' },
    { name: 'Relative file', type: 'duckdb', path: 'data/local.duckdb' },
    { name: 'Remote file', type: 'duckdb', path: 'https://example.com/local.duckdb' },
    { name: 'Unexpanded home file', type: 'duckdb', path: '~/data/local.duckdb' },
    { name: 'Ambiguous target', type: 'duckdb', host: 'db.internal', path: '/Users/alex/data/local.duckdb' },
    { name: 'Nested value', type: 'postgresql', host: { value: 'db.internal' } },
    { name: 'Missing target', type: 'postgresql' }
  ];

  for (const connection of invalidConnections) {
    assert.throws(
      () => parseInventory(JSON.stringify([connection]), 'json'),
      /valid port|supported SSL|absolute local path|plain values|host or local path/i
    );
  }
});

test('only DuckDB filename stems containing hyphens are deferred for a read-only preflight', () => {
  const connections = parseInventory(JSON.stringify([
    { name: 'PostgreSQL', type: 'postgresql', host: 'db.internal' },
    { name: 'Safe DuckDB', type: 'duckdb', path: '/Users/alex/data/warehouse.duckdb' },
    { name: 'Hyphen DuckDB', type: 'DuckDB', path: '/Users/alex/data/prototype-wipe-me.duckdb' },
    { name: 'Hyphen Parquet', type: 'parquet', path: '/Users/alex/data/sales-data.parquet' }
  ]), 'json');

  assert.deepEqual(createMigrationPlan(connections), {
    ready: [connections[0], connections[1], connections[3]],
    preflight: [{
      connection: connections[2],
      kind: 'duckdb-hyphen-path',
      mode: 'read-only'
    }]
  });
  assert.equal(connections[2].path, '/Users/alex/data/prototype-wipe-me.duckdb');
});

test('Profile Setup preserves unfamiliar DBCode connection types instead of using a wrapper allowlist', () => {
  const connections = parseInventory(JSON.stringify([
    { name: 'Future hosted service', type: 'future-cloud-service', host: 'service.example' },
    { name: 'Future local format', type: 'future-local-format', path: '/Users/alex/data/future.data' }
  ]), 'json');

  assert.deepEqual(createMigrationPlan(connections), {
    ready: connections,
    preflight: []
  });
  assert.deepEqual(connections.map(connection => connection.type), ['future-cloud-service', 'future-local-format']);
});

test('DuckDB preflight results are recorded one connection at a time', () => {
  const connections = parseInventory(JSON.stringify([
    { name: 'First DuckDB', type: 'duckdb', path: '/Users/alex/data/first-file.duckdb' },
    { name: 'Second DuckDB', type: 'duckdb', path: '/Users/alex/data/second-file.duckdb' }
  ]), 'json');
  const { preflight } = createMigrationPlan(connections);

  let progress = { completed: 0, deferred: [] };
  progress = advancePreflight(preflight, progress, 'passed');
  assert.deepEqual(progress, { completed: 1, deferred: [] });

  progress = advancePreflight(preflight, progress, 'deferred');
  assert.deepEqual(progress, { completed: 2, deferred: [connections[1]] });
});

test('reviewed import data is owner-only and removed after the migration finishes', async () => {
  const testRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'dbcode-profile-migration-'));
  const stagingRoot = path.join(testRoot, 'staging');
  try {
    const staged = await stageReviewedInventory(stagingRoot, [{
      name: 'Analytics',
      type: 'postgresql',
      host: 'db.internal',
      username: 'analyst',
      ssl: true
    }]);

    assert.equal((await fs.stat(staged.sessionDirectory)).mode & 0o777, 0o700);
    assert.equal((await fs.stat(staged.inventoryPath)).mode & 0o777, 0o600);
    assert.equal(path.basename(staged.inventoryPath), 'reviewed-connections.csv');
    const stagedContents = await fs.readFile(staged.inventoryPath, 'utf8');
    assert.equal(
      stagedContents,
      'name,type,host,port,database,username,ssl,path,connectionType\nAnalytics,postgresql,db.internal,,,analyst,true,,host\n'
    );

    const stagedFileConnection = await stageReviewedInventory(stagingRoot, [{
      name: 'Local Parquet',
      type: 'parquet',
      path: '/Users/alex/data/local.parquet'
    }]);
    assert.match(
      await fs.readFile(stagedFileConnection.inventoryPath, 'utf8'),
      /Local Parquet,parquet,,,,,,\/Users\/alex\/data\/local\.parquet,socket/
    );
    await cleanupReviewedInventory(stagingRoot, stagedFileConnection.sessionDirectory);

    await cleanupReviewedInventory(stagingRoot, staged.sessionDirectory);
    await assert.rejects(fs.stat(staged.sessionDirectory), error => error.code === 'ENOENT');
  } finally {
    await fs.rm(testRoot, { recursive: true, force: true });
  }
});

test('profile recreation backs up only the Standalone DBCode Profile and starts clean managed settings', async () => {
  const testRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'dbcode-profile-recovery-'));
  const userDataRoot = path.join(testRoot, 'wrapper-user-data');
  const sharedDataRoot = path.join(testRoot, 'wrapper-shared-data');
  const backupRoot = path.join(testRoot, 'wrapper-profile-backups');
  const settingsSource = path.join(testRoot, 'managed-settings.json');
  const extensionsRoot = path.join(testRoot, 'wrapper-extensions');
  const normalEditorRoot = path.join(testRoot, 'normal-vscode-profile');
  const databasePath = path.join(testRoot, 'project-data.duckdb');
  try {
    await fs.mkdir(path.join(userDataRoot, 'User/globalStorage/dbcode.dbcode'), { recursive: true });
    await fs.mkdir(path.join(sharedDataRoot, 'sharedStorage'), { recursive: true });
    await fs.mkdir(extensionsRoot, { recursive: true });
    await fs.mkdir(normalEditorRoot, { recursive: true });
    await fs.writeFile(path.join(userDataRoot, 'User/globalStorage/dbcode.dbcode/state.txt'), 'connection-state');
    await fs.writeFile(path.join(sharedDataRoot, 'sharedStorage/state.txt'), 'shared-state');
    await fs.writeFile(path.join(extensionsRoot, 'dbcode.txt'), 'unchanged-extension');
    await fs.writeFile(path.join(normalEditorRoot, 'state.txt'), 'unchanged-normal-editor');
    await fs.writeFile(databasePath, 'unchanged-database');
    await fs.writeFile(settingsSource, '{"telemetry.telemetryLevel":"off"}\n');

    const recovery = await recreateStandaloneProfile({
      userDataRoot,
      sharedDataRoot,
      backupRoot,
      settingsSource,
      recoveryId: '20260721T120000Z-proof'
    });

    assert.equal(recovery.backupDirectory, path.join(backupRoot, '20260721T120000Z-proof'));
    assert.equal(
      await fs.readFile(path.join(recovery.backupDirectory, 'user-data/User/globalStorage/dbcode.dbcode/state.txt'), 'utf8'),
      'connection-state'
    );
    assert.equal(
      await fs.readFile(path.join(recovery.backupDirectory, 'shared-data/sharedStorage/state.txt'), 'utf8'),
      'shared-state'
    );
    assert.equal(await fs.readFile(path.join(userDataRoot, 'User/settings.json'), 'utf8'), '{"telemetry.telemetryLevel":"off"}\n');
    assert.equal((await fs.stat(userDataRoot)).mode & 0o777, 0o700);
    assert.equal((await fs.stat(sharedDataRoot)).mode & 0o777, 0o700);
    assert.equal((await fs.stat(path.join(userDataRoot, 'User/settings.json'))).mode & 0o777, 0o600);
    await assert.rejects(fs.stat(path.join(userDataRoot, 'User/globalStorage/dbcode.dbcode/state.txt')), error => error.code === 'ENOENT');
    assert.equal(await fs.readFile(path.join(extensionsRoot, 'dbcode.txt'), 'utf8'), 'unchanged-extension');
    assert.equal(await fs.readFile(path.join(normalEditorRoot, 'state.txt'), 'utf8'), 'unchanged-normal-editor');
    assert.equal(await fs.readFile(databasePath, 'utf8'), 'unchanged-database');
  } finally {
    await fs.rm(testRoot, { recursive: true, force: true });
  }
});

test('Profile Setup keeps recovery contextual instead of adding another top-level tool', () => {
  const page = renderProfileSetupHtml({ kind: 'complete', message: 'Profile setup is complete.' });
  assert.match(page, /data-action="recreate-profile"/);
  assert.match(page, /Back up and recreate profile/i);
});

test('the recovery worker refuses an empty app process list', async () => {
  const outcome = await runRecoveryWorker({
    processPids: [],
    relaunchArgs: [],
    relaunchApplication: false
  });
  assert.equal(outcome.status, 'failed');
  assert.match(outcome.message, /invalid process list/i);
});

test('an invalid worker request cannot use its unvalidated recovery directory', async () => {
  const testRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'dbcode-invalid-recovery-request-'));
  try {
    const outcome = await runRecoveryWorker({
      processPids: [],
      relaunchArgs: [],
      relaunchApplication: false,
      backupRoot: testRoot
    });
    assert.equal(outcome.status, 'failed');
    await assert.rejects(fs.stat(path.join(testRoot, 'last-recovery.json')), error => error.code === 'ENOENT');
  } finally {
    await fs.rm(testRoot, { recursive: true, force: true });
  }
});

test('the recovery worker run seam owns process waiting, outcomes, and relaunch', async () => {
  const testRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'dbcode-recovery-worker-run-'));
  const userDataRoot = path.join(testRoot, 'user-data');
  const sharedDataRoot = path.join(testRoot, 'shared-data');
  const backupRoot = path.join(testRoot, 'backups');
  const settingsSource = path.join(testRoot, 'managed-settings.json');
  const appBundle = path.join(testRoot, 'DBCode Wrapper.app');
  const appExecutable = path.join(appBundle, 'Contents/MacOS/DBCode Wrapper');
  const externalState = path.join(testRoot, 'outside.json');
  const outcomePath = path.join(backupRoot, 'last-recovery.json');
  const relaunches = [];
  const processStates = [true, false];
  const sleepDurations = [];
  try {
    await fs.mkdir(userDataRoot, { recursive: true });
    await fs.mkdir(sharedDataRoot, { recursive: true });
    await fs.mkdir(backupRoot, { recursive: true });
    await fs.mkdir(path.dirname(appExecutable), { recursive: true });
    await fs.writeFile(settingsSource, '{"telemetry.telemetryLevel":"off"}\n');
    await fs.writeFile(appExecutable, 'fixture executable\n', { mode: 0o600 });
    await fs.writeFile(externalState, 'outside stays unchanged\n');
    await fs.symlink(externalState, outcomePath);

    const outcome = await runRecoveryWorker({
      processPids: [424242],
      recoveryId: '20260802T000000Z-run',
      userDataRoot,
      sharedDataRoot,
      backupRoot,
      settingsSource,
      appBundle,
      relaunchArgs: ['--new-window'],
      relaunchApplication: true
    }, {
      filesystem: fs,
      now: () => new Date('2026-08-02T00:00:00.000Z'),
      randomUUID: () => 'runtime-controlled-id',
      processExists: () => processStates.shift() ?? false,
      sleep: async milliseconds => {
        sleepDurations.push(milliseconds);
      },
      relaunchApplication: async (executable, args) => {
        relaunches.push({ executable, args });
      }
    });

    assert.deepEqual(outcome, {
      schemaVersion: 1,
      status: 'complete',
      backupDirectory: path.join(backupRoot, '20260802T000000Z-run'),
      completedAt: '2026-08-02T00:00:00.000Z'
    });
    assert.deepEqual(relaunches, [{
      executable: appExecutable,
      args: ['--new-window']
    }]);
    assert.deepEqual(sleepDurations, [250]);
    assert.deepEqual(
      JSON.parse(await fs.readFile(outcomePath, 'utf8')),
      outcome
    );
    assert.equal(await fs.readFile(externalState, 'utf8'), 'outside stays unchanged\n');
    assert.equal((await fs.lstat(outcomePath)).isSymbolicLink(), false);
    assert.equal((await fs.stat(outcomePath)).mode & 0o777, 0o600);
  } finally {
    await fs.rm(testRoot, { recursive: true, force: true });
  }
});

test('recovery paths are derived from the active Standalone DBCode Profile instead of environment input', () => {
  const homeDirectory = '/Users/alex';
  const userDataRoot = '/Users/alex/Library/Application Support/DBCode Wrapper';
  const appRoot = '/Applications/DBCode Wrapper.app/Contents/Resources/app';
  const expected = deriveRecoveryLayout({
    userDataRoot,
    homeDirectory,
    appRoot,
    environment: {
      DBCODE_WRAPPER_SHARED_DATA_ROOT: '/Users/alex/.dbcode-wrapper-shared',
      DBCODE_WRAPPER_PROFILE_BACKUP_ROOT: '/Users/alex/Library/Application Support/DBCode Wrapper Profile Backups',
      DBCODE_WRAPPER_APP_BUNDLE: '/Applications/DBCode Wrapper.app'
    }
  });

  const profileLayout = createProfileLayout({
    profileName: 'default',
    homeDirectory,
    buildRoot: '/Users/alex/.dbcode-wrapper-build-not-used'
  });
  assert.deepEqual(expected, {
    profileLayout,
    stateRoot: '/Users/alex/.dbcode-wrapper',
    userDataRoot,
    extensionsRoot: '/Users/alex/.dbcode-wrapper/extensions',
    sharedDataRoot: '/Users/alex/.dbcode-wrapper-shared',
    backupRoot: '/Users/alex/Library/Application Support/DBCode Wrapper Profile Backups',
    cacheRoot: '/Users/alex/Library/Application Support/DBCode Wrapper/Cache',
    logsRoot: '/Users/alex/Library/Application Support/DBCode Wrapper/logs',
    appBundle: '/Applications/DBCode Wrapper.app'
  });
  assert.throws(() => deriveRecoveryLayout({
    userDataRoot,
    homeDirectory,
    appRoot,
    environment: { DBCODE_WRAPPER_SHARED_DATA_ROOT: '/Users/alex/unrelated-folder' }
  }), /does not match the active Standalone DBCode Profile/i);
});

test('profile recovery is limited to the current user default profile', () => {
  const qaUserDataRoot = '/private/tmp/dbcode-wrapper-qa/profile/user-data';
  assert.throws(() => deriveRecoveryLayout({
    userDataRoot: qaUserDataRoot,
    homeDirectory: '/Users/alex',
    appRoot: '/Applications/DBCode Wrapper.app/Contents/Resources/app',
    environment: {
      DBCODE_WRAPPER_QA_RECOVERY: '1',
      DBCODE_WRAPPER_APP_BUNDLE: '/Applications/DBCode Wrapper.app'
    }
  }), /does not match the active Standalone DBCode Profile/i);
});

test('profile recovery rejects alternate and duplicate profile-path arguments', () => {
  const expected = '/private/tmp/dbcode-wrapper-qa/profile/user-data';
  assert.doesNotThrow(() => requireMatchingRelaunchPath(
    [`--user-data-dir=${expected}`],
    '--user-data-dir',
    expected
  ));
  assert.throws(() => requireMatchingRelaunchPath(
    ['--user-data-dir', expected, '--user-data-dir=/Users/alex/Library/Application Support/Code'],
    '--user-data-dir',
    expected
  ), /more than one --user-data-dir argument/i);
  assert.throws(() => requireMatchingRelaunchPath(
    ['--user-data-dir=/Users/alex/Library/Application Support/Code'],
    '--user-data-dir',
    expected
  ), /does not match the active Standalone DBCode Profile/i);
});
