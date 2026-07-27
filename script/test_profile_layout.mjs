import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

import profileLayout from '../host/extensions/dbcode-wrapper-profile-migration/profile-layout.js';

const scriptRoot = dirname(fileURLToPath(import.meta.url));
const cli = join(scriptRoot, 'profile_layout.cjs');
const homeDirectory = '/Users/alex';
const buildRoot = '/Users/alex/Documents/Development/dbcode/.build';

function cliRecord(profileName, ...profileArgs) {
  return JSON.parse(execFileSync(process.execPath, [
    cli,
    'record',
    profileName,
    homeDirectory,
    buildRoot,
    ...profileArgs
  ], { encoding: 'utf8' }));
}

test('shell and JavaScript adapters return the same complete default layout', () => {
  const identity = profileLayout.loadProfileIdentity();
  const expected = profileLayout.createProfileLayout({
    profileName: 'default',
    homeDirectory,
    buildRoot
  });
  assert.equal('PRODUCT' in profileLayout, false);
  assert.deepEqual(cliRecord('default'), expected);
  assert.deepEqual(expected, {
    schema_version: 2,
    profile_schema_version: 1,
    profile_name: 'default',
    product: identity.product,
    owner: { kind: 'current-user-home', root: homeDirectory },
    permissions: { directory_mode: '0700', file_mode: '0600' },
    uses_natural_paths: true,
    paths: {
      state: '/Users/alex/.dbcode-wrapper',
      user_data: '/Users/alex/Library/Application Support/DBCode Wrapper',
      extensions: '/Users/alex/.dbcode-wrapper/extensions',
      shared_data: '/Users/alex/.dbcode-wrapper-shared',
      backup: '/Users/alex/Library/Application Support/DBCode Wrapper Profile Backups',
      cache: '/Users/alex/Library/Application Support/DBCode Wrapper/Cache',
      logs: '/Users/alex/Library/Application Support/DBCode Wrapper/logs',
      queries: '/Users/alex/Library/Application Support/DBCode Wrapper/User/globalStorage/dbcode-wrapper/queries'
    }
  });
});

test('a fixture identity changes profile and query paths without production literals', () => {
  const identity = structuredClone(profileLayout.loadProfileIdentity());
  identity.profile_schema_version = 3;
  identity.product = {
    app_name: 'Data Shell',
    application_name: 'data-shell',
    bundle_identifier: 'com.example.datashell',
    data_folder_name: '.data-shell',
    user_data_folder_name: 'Data Shell Data',
    extensions_folder_name: 'addons',
    shared_data_folder_name: '.data-shell-shared',
    backup_folder_name: 'Data Shell Backups',
    storage_namespace: 'data-shell',
    query_folder_name: 'saved-queries'
  };

  const layout = profileLayout.createProfileLayout({
    identity,
    profileName: 'default',
    homeDirectory,
    buildRoot
  });

  assert.equal(layout.profile_schema_version, 3);
  assert.deepEqual(layout.product, identity.product);
  assert.equal(layout.paths.user_data, '/Users/alex/Library/Application Support/Data Shell Data');
  assert.equal(layout.paths.extensions, '/Users/alex/.data-shell/addons');
  assert.equal(layout.paths.shared_data, '/Users/alex/.data-shell-shared');
  assert.equal(layout.paths.backup, '/Users/alex/Library/Application Support/Data Shell Backups');
  assert.equal(layout.paths.queries, '/Users/alex/Library/Application Support/Data Shell Data/User/globalStorage/data-shell/saved-queries');
  assert.equal(profileLayout.validateProfileLayout(layout, { identity, homeDirectory, buildRoot }), layout);
  assert.throws(
    () => profileLayout.validateProfileLayout(layout, { homeDirectory, buildRoot }),
    /identity|approved layout/i
  );
});

test('missing, linked, malformed, or unsafe generated identity fails closed', t => {
  const root = mkdtempSync(join(tmpdir(), 'dbcode-profile-identity-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const missing = join(root, 'missing.json');
  const malformed = join(root, 'malformed.json');
  const unsafe = join(root, 'unsafe.json');
  const linked = join(root, 'linked.json');
  writeFileSync(malformed, '{');
  writeFileSync(unsafe, JSON.stringify({
    ...profileLayout.loadProfileIdentity(),
    product: {
      ...profileLayout.loadProfileIdentity().product,
      data_folder_name: '../escape'
    }
  }));
  symlinkSync(unsafe, linked);

  assert.throws(() => profileLayout.loadProfileIdentity(missing), /missing|identity/i);
  assert.throws(() => profileLayout.loadProfileIdentity(linked), /symbolic link|identity/i);
  assert.throws(() => profileLayout.loadProfileIdentity(malformed), /JSON|identity/i);
  assert.throws(() => profileLayout.loadProfileIdentity(unsafe), /folder|identity/i);
});

test('QA layout is complete, private, and isolated inside generated output', () => {
  const layout = profileLayout.createProfileLayout({
    profileName: 'qa',
    homeDirectory,
    buildRoot
  });
  assert.deepEqual(cliRecord('qa'), layout);
  assert.equal(layout.owner.kind, 'generated-build-root');
  assert.equal(layout.owner.root, buildRoot);
  assert.equal(layout.uses_natural_paths, false);
  assert.equal(layout.paths.state, `${buildRoot}/qa/profile`);
  assert.equal(layout.paths.user_data, `${buildRoot}/qa/profile/user-data`);
  assert.equal(layout.paths.extensions, `${buildRoot}/qa/profile/extensions`);
  assert.equal(layout.paths.shared_data, `${buildRoot}/qa/profile/shared-data`);
  assert.equal(layout.paths.backup, `${buildRoot}/qa/profile-backups`);
  assert.equal(layout.paths.cache, `${buildRoot}/qa/profile/cache`);
  assert.equal(layout.paths.logs, `${buildRoot}/qa/profile/logs`);
  assert.equal(layout.paths.queries, `${buildRoot}/qa/profile/user-data/User/globalStorage/dbcode-wrapper/queries`);
  profileLayout.validateProfileLayout(layout, { homeDirectory, buildRoot });
});

test('isolated layouts keep every path below one generated owner', () => {
  const stateRoot = `${buildRoot}/runtime/session-one`;
  const extensionsRoot = `${buildRoot}/runtime/verified-extensions`;
  const layout = profileLayout.createProfileLayout({
    profileName: 'isolated',
    homeDirectory,
    buildRoot,
    stateRoot,
    extensionsRoot
  });
  assert.deepEqual(cliRecord('isolated', stateRoot, extensionsRoot), layout);
  assert.equal(layout.owner.root, `${buildRoot}/runtime`);
  assert.equal(layout.paths.state, stateRoot);
  assert.equal(layout.paths.extensions, extensionsRoot);
  assert.equal(layout.paths.backup, `${stateRoot}-backups`);
});

test('layout validation rejects alternate roots, broad paths, and unknown profiles', () => {
  const layout = profileLayout.createProfileLayout({ profileName: 'default', homeDirectory, buildRoot });
  assert.throws(
    () => profileLayout.validateProfileLayout({
      ...layout,
      paths: { ...layout.paths, shared_data: '/Users/another-user/data' }
    }, { homeDirectory, buildRoot }),
    /layout/i
  );
  assert.throws(
    () => profileLayout.createProfileLayout({ profileName: 'default', homeDirectory: '/', buildRoot }),
    /home/i
  );
  assert.throws(
    () => profileLayout.createProfileLayout({ profileName: 'diagnostic', homeDirectory, buildRoot }),
    /unknown/i
  );
});

test('mutation checks reject a symlinked ancestor before creating profile data', t => {
  const root = mkdtempSync(join(tmpdir(), 'dbcode-profile-layout-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const realHome = join(root, 'real-home');
  const linkedHome = join(root, 'linked-home');
  mkdirSync(realHome);
  symlinkSync(realHome, linkedHome);
  const layout = profileLayout.createProfileLayout({
    profileName: 'default',
    homeDirectory: linkedHome,
    buildRoot: join(root, 'build')
  });
  assert.throws(
    () => profileLayout.assertSafeMutationPaths(layout, ['user_data']),
    /symbolic link/i
  );
});

test('the layout record can be passed through an environment value only when unchanged', () => {
  const layout = profileLayout.createProfileLayout({ profileName: 'default', homeDirectory, buildRoot });
  assert.deepEqual(profileLayout.parseMatchingLayout(JSON.stringify(layout), layout), layout);
  const reordered = {
    paths: layout.paths,
    uses_natural_paths: layout.uses_natural_paths,
    permissions: layout.permissions,
    owner: layout.owner,
    product: layout.product,
    profile_name: layout.profile_name,
    profile_schema_version: layout.profile_schema_version,
    schema_version: layout.schema_version
  };
  assert.deepEqual(profileLayout.parseMatchingLayout(JSON.stringify(reordered), layout), reordered);
  assert.throws(
    () => profileLayout.parseMatchingLayout(JSON.stringify({
      ...layout,
      paths: { ...layout.paths, extensions: '/tmp/other-extensions' }
    }), layout),
    /does not match/i
  );
});
