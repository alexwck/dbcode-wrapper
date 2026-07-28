import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import {
  chmodSync,
  existsSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  readdirSync,
  rmSync,
  symlinkSync,
  writeFileSync
} from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

import retention from './lib/generated-workspace-retention.js';

const {
  assertManagedPath,
  executeCleanup,
  inventoryGeneratedWorkspace,
  planCleanup,
  readOtherOwnedMacTicketOpen,
  resolveManagedPath
} = retention;

const scriptRoot = dirname(fileURLToPath(import.meta.url));
const cli = join(scriptRoot, 'generated_workspace.cjs');

function makeFixture(t) {
  const fixtureRoot = realpathSync(mkdtempSync(join(tmpdir(), 'dbcode retention contract ')));
  t.after(() => rmSync(fixtureRoot, { recursive: true, force: true }));
  const repoRoot = join(fixtureRoot, 'repository with spaces');
  const homeDirectory = join(fixtureRoot, 'home with spaces');
  const issueDirectory = join(
    repoRoot,
    '.scratch/dbcode-wrapper-implementation/issues'
  );
  mkdirSync(issueDirectory, { recursive: true });
  mkdirSync(homeDirectory, { recursive: true });
  writeFileSync(
    join(issueDirectory, '09-publish-public-source-and-private-personal-release.md'),
    '# Other owned Mac\n\n**Status:** claimed\n'
  );

  mkdirSync(join(repoRoot, '.build/expired/session one'), { recursive: true });
  writeFileSync(join(repoRoot, '.build/expired/session one/old.log'), 'expired evidence');
  writeFileSync(join(repoRoot, '.build/.DS_Store'), 'finder metadata');
  mkdirSync(join(repoRoot, '.build/q/old catalogue profile'), { recursive: true });
  writeFileSync(
    join(repoRoot, '.build/q/old catalogue profile/settings.json'),
    '{"retired":true}'
  );
  mkdirSync(join(repoRoot, '.build/u/r/x'), { recursive: true });
  writeFileSync(
    join(repoRoot, '.build/u/r/x/rollback-transaction.json'),
    '{"historical":true}'
  );
  mkdirSync(join(repoRoot, '.build/smoke-backups'), { recursive: true });
  mkdirSync(join(repoRoot, '.build/mystery'), { recursive: true });
  writeFileSync(join(repoRoot, '.build/mystery/unknown.txt'), 'unknown output');
  mkdirSync(join(repoRoot, 'dist/DBCode Wrapper.app'), { recursive: true });
  writeFileSync(join(repoRoot, 'dist/DBCode Wrapper.app/marker'), 'accepted app');
  mkdirSync(join(repoRoot, '.build/cache'), { recursive: true });
  writeFileSync(join(repoRoot, '.build/cache/private-package.vsix'), 'do not inspect');
  mkdirSync(join(repoRoot, 'output/playwright'), { recursive: true });
  writeFileSync(join(repoRoot, 'output/playwright/result.png'), 'rendered evidence');

  return { fixtureRoot, repoRoot, homeDirectory };
}

function snapshotTree(root) {
  const records = [];
  function visit(current) {
    const metadata = lstatSync(current);
    const name = relative(root, current) || '.';
    if (metadata.isSymbolicLink()) {
      records.push([name, 'symlink']);
      return;
    }
    if (metadata.isDirectory()) {
      records.push([name, 'directory']);
      for (const child of readdirSync(current).sort()) {
        visit(join(current, child));
      }
      return;
    }
    records.push([name, 'file', readFileSync(current, 'utf8')]);
  }
  visit(root);
  return records;
}

function inventoryOptions(repoRoot, homeDirectory) {
  return {
    repoRoot,
    homeDirectory,
    otherOwnedMacTicketOpen: true
  };
}

test('inventory explains known, protected, private, expired, and unknown roots without mutation', t => {
  const { repoRoot, homeDirectory } = makeFixture(t);
  const before = snapshotTree(repoRoot);
  const result = inventoryGeneratedWorkspace(inventoryOptions(repoRoot, homeDirectory));
  const after = snapshotTree(repoRoot);

  assert.deepEqual(after, before);
  assert.equal(result.schema_version, 1);
  assert.equal(result.mutation_performed, false);
  assert.equal(result.other_owned_mac_ticket.open, true);

  const expired = result.entries.find(entry => entry.id === 'expired-output');
  assert.equal(expired.path, join(repoRoot, '.build/expired'));
  assert.equal(expired.classification, 'expired-output');
  assert.equal(expired.owner, 'generated-workspace-retention');
  assert.equal(expired.deletion_allowed, true);
  assert.equal(expired.exists, true);
  assert.ok(expired.size_bytes > 0);
  assert.match(expired.reason, /expired/i);

  const retiredCatalogueProfile = result.entries.find(
    entry => entry.id === 'retired-catalogue-profile'
  );
  assert.equal(retiredCatalogueProfile.path, join(repoRoot, '.build/q'));
  assert.equal(retiredCatalogueProfile.classification, 'expired-output');
  assert.equal(retiredCatalogueProfile.owner, 'focused-shell-rendered');
  assert.equal(retiredCatalogueProfile.deletion_allowed, true);
  assert.ok(retiredCatalogueProfile.size_bytes > 0);

  const historicalUpgradeEvidence = result.entries.find(
    entry => entry.id === 'historical-controlled-upgrade-evidence'
  );
  assert.equal(historicalUpgradeEvidence.path, join(repoRoot, '.build/u'));
  assert.equal(historicalUpgradeEvidence.classification, 'active-evidence');
  assert.equal(historicalUpgradeEvidence.owner, 'controlled-upgrade');
  assert.equal(historicalUpgradeEvidence.deletion_allowed, false);
  assert.equal(historicalUpgradeEvidence.size_bytes, null);
  assert.equal(
    historicalUpgradeEvidence.size_status,
    'protected-artifact-not-inspected'
  );

  const retiredSmokeBackups = result.entries.find(
    entry => entry.id === 'retired-smoke-backups'
  );
  assert.equal(retiredSmokeBackups.path, join(repoRoot, '.build/smoke-backups'));
  assert.equal(retiredSmokeBackups.classification, 'expired-output');
  assert.equal(retiredSmokeBackups.owner, 'host-smoke');
  assert.equal(retiredSmokeBackups.deletion_allowed, true);

  const finderMetadata = result.entries.find(
    entry => entry.id === 'finder-metadata'
  );
  assert.equal(finderMetadata.path, join(repoRoot, '.build/.DS_Store'));
  assert.equal(finderMetadata.classification, 'expired-output');
  assert.equal(finderMetadata.owner, 'macos-finder');
  assert.equal(finderMetadata.deletion_allowed, true);

  const acceptedHost = result.entries.find(entry => entry.id === 'accepted-host');
  assert.equal(acceptedHost.classification, 'active-evidence');
  assert.equal(acceptedHost.deletion_allowed, false);
  assert.equal(acceptedHost.size_bytes, null);
  assert.equal(acceptedHost.size_status, 'protected-artifact-not-inspected');
  assert.match(acceptedHost.reason, /other-owned-Mac/i);

  const buildCache = result.entries.find(entry => entry.id === 'build-cache');
  assert.equal(buildCache.classification, 'reusable-cache');
  assert.equal(buildCache.deletion_allowed, false);
  assert.equal(buildCache.size_bytes, null);
  assert.equal(buildCache.size_status, 'protected-artifact-not-inspected');

  const buildWork = result.entries.find(entry => entry.id === 'build-work');
  assert.equal(buildWork.classification, 'rebuildable-work');
  assert.equal(buildWork.deletion_allowed, false);

  const privateProfile = result.entries.find(entry => entry.id === 'current-profile-state');
  assert.equal(privateProfile.classification, 'active-evidence');
  assert.equal(privateProfile.deletion_allowed, false);
  assert.equal(privateProfile.size_bytes, null);
  assert.equal(privateProfile.size_status, 'private-profile-not-inspected');

  const unknown = result.entries.find(entry => entry.path === join(repoRoot, '.build/mystery'));
  assert.equal(unknown.classification, 'unknown');
  assert.equal(unknown.deletion_allowed, false);
  assert.equal(unknown.size_bytes, null);
  assert.equal(unknown.size_status, 'unregistered-path-not-inspected');
  assert.match(unknown.reason, /not registered/i);
});

test('cleanup plans are dry-run only and accept a class or an exact relative or absolute path', t => {
  const { repoRoot, homeDirectory } = makeFixture(t);
  const options = inventoryOptions(repoRoot, homeDirectory);

  const byClass = planCleanup({
    ...options,
    selector: { classification: 'expired-output' }
  });
  assert.equal(byClass.dry_run, true);
  assert.equal(byClass.execution_supported, false);
  assert.equal(byClass.mutation_performed, false);
  assert.deepEqual(
    byClass.items.map(item => item.path),
    [
      join(repoRoot, '.build/expired'),
      join(repoRoot, '.build/q'),
      join(repoRoot, '.build/smoke-backups'),
      join(repoRoot, '.build/.DS_Store')
    ]
  );

  for (const selectedPath of [
    '.build/expired/session one',
    join(repoRoot, '.build/expired/session one')
  ]) {
    const exact = planCleanup({
      ...options,
      selector: { path: selectedPath }
    });
    assert.equal(exact.items.length, 1);
    assert.equal(exact.execution_supported, true);
    assert.equal(exact.items[0].path, join(repoRoot, '.build/expired/session one'));
    assert.equal(exact.items[0].classification, 'expired-output');
    assert.equal(exact.items[0].deletion_allowed, true);
  }
  assert.equal(readFileSync(join(repoRoot, '.build/expired/session one/old.log'), 'utf8'), 'expired evidence');
});

test('cleanup apply removes only one exact validated path at a time', t => {
  const { repoRoot, homeDirectory } = makeFixture(t);
  const options = inventoryOptions(repoRoot, homeDirectory);
  const expiredDirectory = join(repoRoot, '.build/expired/session one');
  const finderMetadata = join(repoRoot, '.build/.DS_Store');
  const protectedEvidence = join(
    repoRoot,
    '.build/u/r/x/rollback-transaction.json'
  );

  assert.throws(
    () => executeCleanup({
      ...options,
      selector: { classification: 'expired-output' }
    }),
    /exact path/i
  );

  const directoryResult = executeCleanup({
    ...options,
    selector: { path: '.build/expired/session one' }
  });
  assert.equal(directoryResult.dry_run, false);
  assert.equal(directoryResult.execution_supported, true);
  assert.equal(directoryResult.mutation_performed, true);
  assert.equal(directoryResult.selection.kind, 'exact-path');
  assert.equal(directoryResult.items.length, 1);
  assert.equal(directoryResult.items[0].path, expiredDirectory);
  assert.equal(directoryResult.items[0].removed, true);
  assert.equal(directoryResult.items[0].exists_after, false);
  assert.equal(existsSync(expiredDirectory), false);

  const fileResult = executeCleanup({
    ...options,
    selector: { path: finderMetadata }
  });
  assert.equal(fileResult.items[0].path, finderMetadata);
  assert.equal(fileResult.items[0].removed, true);
  assert.equal(existsSync(finderMetadata), false);

  assert.equal(
    readFileSync(protectedEvidence, 'utf8'),
    '{"historical":true}'
  );
  assert.equal(existsSync(join(repoRoot, '.build/q')), true);
  assert.equal(existsSync(join(repoRoot, '.build/smoke-backups')), true);
});

test('cleanup rejects unknown, protected, broad, home, and symlinked paths', t => {
  const { fixtureRoot, repoRoot, homeDirectory } = makeFixture(t);
  const options = inventoryOptions(repoRoot, homeDirectory);

  assert.throws(
    () => planCleanup({ ...options, selector: { path: '.build/mystery' } }),
    /unknown/i
  );
  assert.throws(
    () => planCleanup({ ...options, selector: { path: 'dist/DBCode Wrapper.app' } }),
    /active evidence/i
  );
  assert.throws(
    () => planCleanup({ ...options, selector: { classification: 'reusable-cache' } }),
    /reusable cache/i
  );
  assert.throws(
    () => planCleanup({ ...options, selector: { classification: 'rebuildable-work' } }),
    /rebuildable work/i
  );
  assert.throws(
    () => planCleanup({ ...options, selector: { path: repoRoot } }),
    /repository root/i
  );
  assert.throws(
    () => planCleanup({ ...options, selector: { path: homeDirectory } }),
    /home/i
  );

  const outside = join(fixtureRoot, 'outside');
  mkdirSync(outside);
  const linked = join(repoRoot, '.build/expired/linked-output');
  symlinkSync(outside, linked);
  assert.throws(
    () => planCleanup({ ...options, selector: { path: linked } }),
    /symbolic link/i
  );
  assert.throws(
    () => planCleanup({
      ...options,
      selector: { classification: 'expired-output' }
    }),
    /symbolic link/i
  );
});

test('cleanup refuses an expired path when its full contents cannot be validated', t => {
  const { repoRoot, homeDirectory } = makeFixture(t);
  const unreadable = join(repoRoot, '.build/expired/unreadable');
  mkdirSync(unreadable);
  writeFileSync(join(unreadable, 'evidence.log'), 'unreadable evidence');
  chmodSync(unreadable, 0o000);
  try {
    assert.throws(
      () => planCleanup({
        ...inventoryOptions(repoRoot, homeDirectory),
        selector: { path: unreadable }
      }),
      /fully validated/i
    );
    assert.throws(
      () => planCleanup({
        ...inventoryOptions(repoRoot, homeDirectory),
        selector: { classification: 'expired-output' }
      }),
      /fully validated/i
    );
  } finally {
    chmodSync(unreadable, 0o700);
  }
});

test('workflow path assertions use the same roots and permit only validated temporary fixtures', t => {
  const { fixtureRoot, repoRoot, homeDirectory } = makeFixture(t);
  const options = inventoryOptions(repoRoot, homeDirectory);

  assert.equal(
    resolveManagedPath({ ...options, id: 'smoke-evidence' }),
    join(repoRoot, '.build/smoke')
  );
  assert.equal(
    assertManagedPath({
      ...options,
      id: 'controlled-upgrade-evidence',
      candidatePath: '.build/controlled-upgrade/candidate'
    }).path,
    join(repoRoot, '.build/controlled-upgrade/candidate')
  );
  assert.throws(
    () => assertManagedPath({
      ...options,
      id: 'controlled-upgrade-evidence',
      candidatePath: join(fixtureRoot, 'not-temporary')
    }),
    /managed root/i
  );
  assert.equal(
    assertManagedPath({
      ...options,
      id: 'controlled-upgrade-evidence',
      candidatePath: join(fixtureRoot, 'temporary output'),
      allowTemporary: true,
      temporaryRoots: [fixtureRoot]
    }).temporary_fixture,
    true
  );
  assert.throws(
    () => assertManagedPath({
      ...options,
      id: 'controlled-upgrade-evidence',
      candidatePath: fixtureRoot,
      allowTemporary: true,
      temporaryRoots: [fixtureRoot]
    }),
    /temporary root/i
  );

  const lexicalTemporary = join(tmpdir(), 'dbcode-retention-lexical-fixture');
  const physicalTemporary = join(
    realpathSync(tmpdir()),
    'dbcode-retention-physical-fixture'
  );
  for (const temporaryPath of [
    lexicalTemporary,
    physicalTemporary,
    '/tmp/dbcode-retention-standard-alias-fixture'
  ]) {
    assert.equal(
      assertManagedPath({
        ...options,
        id: 'controlled-upgrade-evidence',
        candidatePath: temporaryPath,
        allowTemporary: true
      }).temporary_fixture,
      true
    );
  }

  const environmentWithoutTmpdir = { ...process.env };
  delete environmentWithoutTmpdir.TMPDIR;
  delete environmentWithoutTmpdir.TMP;
  delete environmentWithoutTmpdir.TEMP;
  const withoutTmpdir = spawnSync(process.execPath, [
    cli,
    'assert-path',
    '--repo-root',
    repoRoot,
    '--home',
    homeDirectory,
    '--id',
    'host-release-assets',
    '--path',
    '/private/tmp/dbcode-retention-unset-tmpdir-fixture',
    '--allow-temporary'
  ], {
    cwd: fixtureRoot,
    encoding: 'utf8',
    env: environmentWithoutTmpdir
  });
  assert.equal(withoutTmpdir.status, 0, withoutTmpdir.stderr);
  assert.equal(
    JSON.parse(withoutTmpdir.stdout).path,
    '/private/tmp/dbcode-retention-unset-tmpdir-fixture'
  );
});

test('the task command supports a repository path with spaces and relative or absolute cleanup paths', t => {
  const { fixtureRoot, repoRoot, homeDirectory } = makeFixture(t);
  const ticketFile = join(
    repoRoot,
    '.scratch/dbcode-wrapper-implementation/issues/09-publish-public-source-and-private-personal-release.md'
  );
  assert.equal(readOtherOwnedMacTicketOpen(ticketFile), true);

  const common = [
    '--repo-root',
    relative(fixtureRoot, repoRoot),
    '--home',
    homeDirectory
  ];
  const inventory = JSON.parse(execFileSync(process.execPath, [
    cli,
    'inventory',
    ...common
  ], { cwd: fixtureRoot, encoding: 'utf8' }));
  assert.equal(inventory.other_owned_mac_ticket.open, true);

  for (const selectedPath of [
    '.build/expired/session one',
    join(repoRoot, '.build/expired/session one')
  ]) {
    const plan = JSON.parse(execFileSync(process.execPath, [
      cli,
      'cleanup',
      ...common,
      '--path',
      selectedPath
    ], { cwd: fixtureRoot, encoding: 'utf8' }));
    assert.equal(plan.items[0].path, join(repoRoot, '.build/expired/session one'));
    assert.equal(plan.mutation_performed, false);
  }

  const classApply = spawnSync(process.execPath, [
    cli,
    'cleanup',
    ...common,
    '--class',
    'expired-output',
    '--apply'
  ], { cwd: fixtureRoot, encoding: 'utf8' });
  assert.equal(classApply.status, 1);
  assert.match(classApply.stderr, /exact path/i);

  const applied = JSON.parse(execFileSync(process.execPath, [
    cli,
    'cleanup',
    ...common,
    '--path',
    '.build/expired/session one',
    '--apply'
  ], { cwd: fixtureRoot, encoding: 'utf8' }));
  assert.equal(applied.dry_run, false);
  assert.equal(applied.execution_supported, true);
  assert.equal(applied.mutation_performed, true);
  assert.equal(applied.items[0].removed, true);
  assert.equal(
    existsSync(join(repoRoot, '.build/expired/session one')),
    false
  );

  const asserted = JSON.parse(execFileSync(process.execPath, [
    cli,
    'assert-path',
    ...common,
    '--id',
    'controlled-upgrade-evidence',
    '--path',
    '.build/controlled-upgrade/relative output'
  ], { cwd: fixtureRoot, encoding: 'utf8' }));
  assert.equal(
    asserted.path,
    join(repoRoot, '.build/controlled-upgrade/relative output')
  );

  const fakeTicket = join(fixtureRoot, 'fake resolved issue.md');
  writeFileSync(fakeTicket, '**Status:** resolved\n');
  const overrideAttempt = spawnSync(process.execPath, [
    cli,
    'inventory',
    ...common,
    '--ticket-file',
    fakeTicket
  ], { cwd: fixtureRoot, encoding: 'utf8' });
  assert.equal(overrideAttempt.status, 2);
  assert.match(overrideAttempt.stderr, /Usage:/);
});

test('managed path resolution and the CLI refuse a symlinked registered root', t => {
  const { fixtureRoot, repoRoot, homeDirectory } = makeFixture(t);
  const outside = join(fixtureRoot, 'outside smoke');
  mkdirSync(outside);
  symlinkSync(outside, join(repoRoot, '.build/smoke'));
  const options = inventoryOptions(repoRoot, homeDirectory);

  assert.throws(
    () => resolveManagedPath({ ...options, id: 'smoke-evidence' }),
    /symbolic link/i
  );

  const result = spawnSync(process.execPath, [
    cli,
    'path',
    '--repo-root',
    repoRoot,
    '--home',
    homeDirectory,
    '--id',
    'smoke-evidence'
  ], { cwd: fixtureRoot, encoding: 'utf8' });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /symbolic link/i);
});
