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
const { applicationExecutable, run: runRecoveryWorker, shouldRelaunchApplication, validateWorkerRequest, writeOutcome } = require('../host/extensions/dbcode-wrapper-profile-migration/profileRecoveryWorker.js');
const { cleanupReviewedInventory, stageReviewedInventory } = require('../host/extensions/dbcode-wrapper-profile-migration/staging.js');
const { renderProfileSetupHtml } = require('../host/extensions/dbcode-wrapper-profile-migration/view.js');

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
  await assert.rejects(
    validateWorkerRequest({
      processPids: [],
      relaunchArgs: [],
      relaunchApplication: false
    }),
    /invalid process list/i
  );
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

test('disposable recovery paths stay next to the active QA profile', () => {
  const profileRoot = '/private/tmp/dbcode-wrapper-qa/profile-one';
  const profileLayout = createProfileLayout({
    profileName: 'isolated',
    homeDirectory: '/Users/alex',
    buildRoot: '/private/tmp/dbcode-wrapper-qa',
    stateRoot: profileRoot
  });
  assert.deepEqual(deriveRecoveryLayout({
    userDataRoot: path.join(profileRoot, 'user-data'),
    homeDirectory: '/Users/alex',
    appRoot: '/Applications/DBCode Wrapper.app/Contents/Resources/app',
    environment: {
      DBCODE_WRAPPER_QA_RECOVERY: '1',
      DBCODE_WRAPPER_SHARED_DATA_ROOT: path.join(profileRoot, 'shared-data'),
      DBCODE_WRAPPER_PROFILE_BACKUP_ROOT: `${profileRoot}-backups`,
      DBCODE_WRAPPER_APP_BUNDLE: '/Applications/DBCode Wrapper.app'
    }
  }), {
    profileLayout,
    stateRoot: profileRoot,
    userDataRoot: path.join(profileRoot, 'user-data'),
    extensionsRoot: path.join(profileRoot, 'extensions'),
    sharedDataRoot: path.join(profileRoot, 'shared-data'),
    backupRoot: `${profileRoot}-backups`,
    cacheRoot: path.join(profileRoot, 'cache'),
    logsRoot: path.join(profileRoot, 'logs'),
    appBundle: '/Applications/DBCode Wrapper.app'
  });
});

test('disposable recovery preserves the separately verified QA extension set', () => {
  const profileRoot = '/private/tmp/dbcode-wrapper-qa/ticket-03-persistent';
  const verifiedExtensionsRoot = '/private/tmp/dbcode-wrapper-qa/profile/extensions';
  const layout = deriveRecoveryLayout({
    userDataRoot: path.join(profileRoot, 'user-data'),
    homeDirectory: '/Users/alex',
    appRoot: '/Applications/DBCode Wrapper.app/Contents/Resources/app',
    environment: {
      DBCODE_WRAPPER_QA_RECOVERY: '1',
      DBCODE_WRAPPER_EXTENSIONS_ROOT: verifiedExtensionsRoot,
      DBCODE_WRAPPER_SHARED_DATA_ROOT: path.join(profileRoot, 'shared-data'),
      DBCODE_WRAPPER_PROFILE_BACKUP_ROOT: `${profileRoot}-backups`,
      DBCODE_WRAPPER_APP_BUNDLE: '/Applications/DBCode Wrapper.app'
    }
  });

  assert.equal(layout.extensionsRoot, verifiedExtensionsRoot);
  assert.doesNotThrow(() => requireMatchingRelaunchPath(
    ['--extensions-dir', verifiedExtensionsRoot],
    '--extensions-dir',
    layout.extensionsRoot
  ));
  assert.throws(() => deriveRecoveryLayout({
    userDataRoot: path.join(profileRoot, 'user-data'),
    homeDirectory: '/Users/alex',
    appRoot: '/Applications/DBCode Wrapper.app/Contents/Resources/app',
    environment: {
      DBCODE_WRAPPER_QA_RECOVERY: '1',
      DBCODE_WRAPPER_EXTENSIONS_ROOT: path.join(profileRoot, 'user-data'),
      DBCODE_WRAPPER_SHARED_DATA_ROOT: path.join(profileRoot, 'shared-data'),
      DBCODE_WRAPPER_PROFILE_BACKUP_ROOT: `${profileRoot}-backups`,
      DBCODE_WRAPPER_APP_BUNDLE: '/Applications/DBCode Wrapper.app'
    }
  }), /verified extensions must stay outside profile recovery/i);
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

test('the recovery worker reopens only after a complete recovery and a clean app exit', () => {
  const request = { relaunchApplication: true };
  assert.equal(shouldRelaunchApplication(request, false, { status: 'complete' }), false);
  assert.equal(shouldRelaunchApplication(request, true, { status: 'failed' }), false);
  assert.equal(shouldRelaunchApplication(request, true, { status: 'complete' }), true);
  assert.equal(shouldRelaunchApplication({ relaunchApplication: false }, true, { status: 'complete' }), false);
});

test('the recovery worker relaunches the executable inside the validated app bundle', () => {
  assert.equal(
    applicationExecutable('/Applications/DBCode Wrapper.app'),
    '/Applications/DBCode Wrapper.app/Contents/MacOS/DBCode Wrapper'
  );
});

test('the recovery outcome atomically replaces a stale link without changing its target', async () => {
  const testRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'dbcode-profile-outcome-'));
  const backupRoot = path.join(testRoot, 'backups');
  const externalState = path.join(testRoot, 'outside.json');
  const outcomePath = path.join(backupRoot, 'last-recovery.json');
  try {
    await fs.mkdir(backupRoot);
    await fs.writeFile(externalState, 'outside stays unchanged\n');
    await fs.symlink(externalState, outcomePath);

    await writeOutcome(backupRoot, 'last-recovery.json', { status: 'complete' });

    assert.equal(await fs.readFile(externalState, 'utf8'), 'outside stays unchanged\n');
    assert.equal((await fs.lstat(outcomePath)).isSymbolicLink(), false);
    assert.deepEqual(JSON.parse(await fs.readFile(outcomePath, 'utf8')), { status: 'complete' });
    assert.equal((await fs.stat(outcomePath)).mode & 0o777, 0o600);
  } finally {
    await fs.rm(testRoot, { recursive: true, force: true });
  }
});
