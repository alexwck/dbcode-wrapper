#!/usr/bin/env node

import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';

const require = createRequire(import.meta.url);
const releaseStatus = require('../host/extensions/dbcode-wrapper-release-status/release-status.js');
const {
  CODE_OSS_METADATA_URL,
  DBCODE_METADATA_URL,
  VSCODIUM_METADATA_URL,
  createReleaseStatusService
} = releaseStatus;

const NOW = Date.parse('2026-07-21T00:00:00Z');
const DAY_MS = 24 * 60 * 60 * 1000;
const INSTALLED_HOST = '1.126.04524';
const INSTALLED_CODE_OSS = '1.126.0';
const INSTALLED_DBCODE = '1.36.2';
const SOURCE_ID_SHA = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

test('Update Status exposes only its maintained service interface', () => {
  assert.deepEqual(Object.keys(releaseStatus).sort(), [
    'CODE_OSS_METADATA_URL',
    'DBCODE_METADATA_URL',
    'VSCODIUM_METADATA_URL',
    'createReleaseStatusService'
  ]);
});

function vscodiumRelease(version = INSTALLED_HOST) {
  return {
    version,
    publishedAt: '2026-07-07T13:01:09Z',
    releaseNotesUrl: `https://github.com/VSCodium/vscodium/releases/tag/${version}`
  };
}

function codeOssRelease(version = INSTALLED_CODE_OSS) {
  return {
    version,
    publishedAt: '2026-06-24T12:49:34Z',
    releaseNotesUrl: `https://github.com/microsoft/vscode/releases/tag/${version}`
  };
}

function dbcodeRelease(version = INSTALLED_DBCODE) {
  return {
    version,
    publishedAt: '2026-07-20T04:51:39.562360Z',
    releaseNotesUrl: `https://dbcode.io/docs/changelog/${version}`
  };
}

function vscodiumPayload(version = INSTALLED_HOST) {
  const release = vscodiumRelease(version);
  return {
    tag_name: version,
    published_at: release.publishedAt,
    html_url: release.releaseNotesUrl,
    draft: false,
    prerelease: false
  };
}

function codeOssPayload(version = INSTALLED_CODE_OSS) {
  const release = codeOssRelease(version);
  return {
    tag_name: version,
    published_at: release.publishedAt,
    html_url: release.releaseNotesUrl,
    draft: false,
    prerelease: false
  };
}

function dbcodePayload(version = INSTALLED_DBCODE) {
  const release = dbcodeRelease(version);
  return {
    namespace: 'dbcode',
    name: 'dbcode',
    verified: true,
    preRelease: false,
    deprecated: false,
    version,
    timestamp: release.publishedAt,
    files: {}
  };
}

function installed() {
  return {
    schemaVersion: 1,
    sourceSetId: `code-oss-1.126.0-dbcode-1.36.2-source-${SOURCE_ID_SHA}`,
    compatibilityStatus: 'candidate',
    profileSchemaVersion: 1,
    target: { platform: 'darwin', architecture: 'arm64' },
    host: {
      ...vscodiumRelease(),
      vscodiumCommit: '1111111111111111111111111111111111111111',
      codeOssVersion: INSTALLED_CODE_OSS,
      codeOssPublishedAt: codeOssRelease().publishedAt,
      codeOssReleaseNotesUrl: codeOssRelease().releaseNotesUrl,
      codeOssCommit: '2222222222222222222222222222222222222222'
    },
    dbcode: {
      ...dbcodeRelease(),
      sha256: 'c9db33e12cae2e59b37d01593ea7c6748ba5c48b6d2efff50868061213508003'
    }
  };
}

function approvedReleaseSet(vscodiumVersion = '1.127.00001', dbcodeVersion = '1.36.3') {
  const codeOssTag = vscodiumVersion === INSTALLED_HOST ? INSTALLED_CODE_OSS : '1.127.0';
  const artifactSha = '3333333333333333333333333333333333333333333333333333333333333333';
  const sourceSetId = `code-oss-${codeOssTag}-dbcode-${dbcodeVersion}-source-${SOURCE_ID_SHA}`;
  return {
    schema_version: 2,
    id: `${sourceSetId}-artifact-${artifactSha}`,
    source_set_id: sourceSetId,
    compatibility_status: 'approved',
    source_commit: '1111111111111111111111111111111111111111',
    target: { platform: 'darwin', architecture: 'arm64' },
    profile: { schema_version: 1 },
    manifest: {
      schema_version: 6,
      build_manifest_sha256: '2222222222222222222222222222222222222222222222222222222222222222',
      candidate_manifest_sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      approval_attestation_sha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      artifact_sha256: artifactSha,
      shell_patch_revision: '4444444444444444444444444444444444444444444444444444444444444444',
      overlay_sha256: '5555555555555555555555555555555555555555555555555555555555555555',
      source_snapshot_sha256: '8888888888888888888888888888888888888888888888888888888888888888',
      compiled_host_input_id: `compiled-host-${'9'.repeat(64)}`,
      packaging_status: 'built-and-signed'
    },
    host: {
      vscodium_tag: vscodiumVersion,
      vscodium_commit: '6666666666666666666666666666666666666666',
      code_oss_tag: codeOssTag,
      code_oss_commit: '7777777777777777777777777777777777777777'
    },
    dbcode: {
      id: 'dbcode.dbcode',
      version: dbcodeVersion,
      vsix_sha256: '8888888888888888888888888888888888888888888888888888888888888888',
      signature_archive_sha256: '9999999999999999999999999999999999999999999999999999999999999999'
    },
    approval: {
      approved_at: '2026-07-22T15:00:00Z',
      validation_issue: 'release-candidate-proof',
      proof_sha256: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      gate_receipt_sha256: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd'
    }
  };
}

function createServiceHarness({
  vscodiumVersion = INSTALLED_HOST,
  codeOssVersion = INSTALLED_CODE_OSS,
  dbcodeVersion = INSTALLED_DBCODE,
  approvedReleaseSets: initialApprovedReleaseSets = [],
  initialState,
  installedRelease = installed(),
  initialNow = NOW,
  fetchFailure = false
} = {}) {
  let storedState = initialState;
  let approvedReleaseSets = initialApprovedReleaseSets;
  let clock = initialNow;
  const requests = [];
  const payloads = {
    vscodium: vscodiumPayload(vscodiumVersion),
    codeOss: codeOssPayload(codeOssVersion),
    dbcode: dbcodePayload(dbcodeVersion)
  };
  const service = createReleaseStatusService({
    installed: installedRelease,
    loadApprovedReleaseSets: async () => approvedReleaseSets,
    now: () => clock,
    loadState: async () => storedState,
    saveState: async state => { storedState = state; },
    fetchJson: async (...args) => {
      requests.push(args);
      if (fetchFailure) {
        throw new Error('network down');
      }
      if (args[0] === VSCODIUM_METADATA_URL) {
        return structuredClone(payloads.vscodium);
      }
      if (args[0] === CODE_OSS_METADATA_URL) {
        return structuredClone(payloads.codeOss);
      }
      return structuredClone(payloads.dbcode);
    }
  });
  return {
    service,
    requests,
    payloads,
    state: () => storedState,
    setNow(value) { clock = value; },
    setApprovedReleaseSets(value) { approvedReleaseSets = value; }
  };
}

async function checkedStatus(options = {}) {
  const harness = createServiceHarness(options);
  return harness.service.check({ force: true });
}

test('official metadata is normalized only through the service', async () => {
  const valid = await checkedStatus({
    vscodiumVersion: '1.127.00001',
    codeOssVersion: '1.130.0',
    dbcodeVersion: '1.36.3'
  });
  assert.equal(valid.vscodium.availableReleaseNotesUrl, 'https://github.com/VSCodium/vscodium/releases/tag/1.127.00001');
  assert.equal(valid.codeOss.availableReleaseNotesUrl, 'https://github.com/microsoft/vscode/releases/tag/1.130.0');
  assert.equal(valid.dbcode.availableReleaseNotesUrl, 'https://dbcode.io/docs/changelog/1.36.3');

  const invalidCases = [
    harness => { harness.payloads.vscodium.html_url = 'https://github.com/VSCodium/vscodium/releases/tag/1.126.00000'; },
    harness => { harness.payloads.codeOss.html_url = 'https://github.com/microsoft/vscode/releases/tag/1.129.0'; },
    harness => { harness.payloads.dbcode.namespace = 'someone-else'; },
    harness => { harness.payloads.dbcode.preRelease = true; }
  ];
  for (const mutate of invalidCases) {
    const harness = createServiceHarness();
    mutate(harness);
    const status = await harness.service.check({ force: true });
    assert.equal(status.kind, 'invalid');
    assert.equal(status.updatesAvailable, false);
    assert.equal(status.shouldPrompt, false);
  }
});

test('matching metadata reports the installed release set as current', async () => {
  const status = await checkedStatus();
  assert.equal(status.kind, 'current');
  assert.equal(status.updatesAvailable, false);
  assert.equal(status.shouldPrompt, false);
  assert.equal(status.vscodium.readiness, 'Current');
  assert.equal(status.codeOss.readiness, 'Current');
  assert.equal(status.dbcode.readiness, 'Current');
});

test('the service keeps all three update inputs independent', async () => {
  const cases = [
    [{ codeOssVersion: '1.130.0' }, [false, true, false]],
    [{ vscodiumVersion: '1.127.00001' }, [true, false, false]],
    [{ dbcodeVersion: '1.36.3' }, [false, false, true]],
    [{ vscodiumVersion: '1.127.00001', codeOssVersion: '1.130.0', dbcodeVersion: '1.36.3' }, [true, true, true]]
  ];
  for (const [versions, expected] of cases) {
    const status = await checkedStatus(versions);
    assert.deepEqual(
      [status.vscodium.updateAvailable, status.codeOss.updateAvailable, status.dbcode.updateAvailable],
      expected
    );
    assert.equal(status.readyToInstall, false);
    assert.equal(status.shouldPrompt, true);
  }
  const codeOssOnly = await checkedStatus({ codeOssVersion: '1.130.0' });
  assert.equal(
    codeOssOnly.candidateKey,
    'vscodium@1.126.04524|code-oss@1.130.0|dbcode@1.36.2'
  );
});

test('older feed records never replace installed components', async () => {
  const status = await checkedStatus({
    vscodiumVersion: '1.125.00001',
    dbcodeVersion: '1.36.3',
    approvedReleaseSets: [approvedReleaseSet(INSTALLED_HOST, '1.36.3')]
  });
  assert.equal(status.vscodium.updateAvailable, false);
  assert.equal(status.vscodium.availableVersion, INSTALLED_HOST);
  assert.equal(status.dbcode.updateAvailable, true);
  assert.equal(status.readyToInstall, true);
  assert.equal(
    status.candidateKey,
    'vscodium@1.126.04524|code-oss@1.126.0|dbcode@1.36.3'
  );
});

test('only an exact complete approval becomes ready to install', async () => {
  const exact = approvedReleaseSet();
  exact.profile.schema_version = 2;
  const exactStatus = await checkedStatus({
    vscodiumVersion: '1.127.00001',
    codeOssVersion: '1.127.0',
    dbcodeVersion: '1.36.3',
    approvedReleaseSets: [exact]
  });
  assert.equal(exactStatus.readyToInstall, true);
  assert.equal(exactStatus.approvedReleaseSetId, exact.id);
  assert.equal(exactStatus.vscodium.readiness, 'Ready to install');

  const mismatchedCodeOss = await checkedStatus({
    vscodiumVersion: '1.127.00001',
    codeOssVersion: '1.128.0',
    dbcodeVersion: '1.36.3',
    approvedReleaseSets: [approvedReleaseSet()]
  });
  assert.equal(mismatchedCodeOss.readyToInstall, false);

  const invalidCandidates = [
    { id: 'not-an-exact-release-set', host: { vscodium_tag: '1.127.00001' }, dbcode: { version: '1.36.3' } },
    (() => { const value = approvedReleaseSet(); delete value.manifest.approval_attestation_sha256; return value; })(),
    (() => { const value = approvedReleaseSet(); value.id = 'unrelated-id'; return value; })()
  ];
  for (const candidate of invalidCandidates) {
    const status = await checkedStatus({
      vscodiumVersion: '1.127.00001',
      codeOssVersion: '1.127.0',
      dbcodeVersion: '1.36.3',
      approvedReleaseSets: [candidate]
    });
    assert.equal(status.readyToInstall, false);
  }
});

test('installed identity validation remains inside the service path', async () => {
  const invalidInstalledSets = [
    (() => { const value = installed(); delete value.sourceSetId; return value; })(),
    (() => { const value = installed(); value.target = { platform: 'banana', architecture: 'toaster' }; return value; })(),
    (() => { const value = installed(); delete value.host.codeOssPublishedAt; return value; })(),
    (() => { const value = installed(); value.dbcode.releaseNotesUrl = 'https://evil.example/dbcode'; return value; })()
  ];
  for (const installedRelease of invalidInstalledSets) {
    const harness = createServiceHarness({ installedRelease });
    await assert.rejects(
      harness.service.check({ force: true }),
      /Installed /i
    );
  }
});

test('skip applies only to the exact candidate through the service', async () => {
  const harness = createServiceHarness({ dbcodeVersion: '1.36.3' });
  const first = await harness.service.check({ force: true });
  await harness.service.markPrompted(first);
  await harness.service.decide('skip', first);
  assert.equal((await harness.service.check({ force: true })).shouldPrompt, false);

  harness.payloads.dbcode.version = '1.36.4';
  harness.payloads.dbcode.timestamp = '2026-07-23T00:00:00Z';
  assert.equal((await harness.service.check({ force: true })).shouldPrompt, true);
});

test('remind later becomes due at the stored time and prompting records it again', async () => {
  const harness = createServiceHarness({ dbcodeVersion: '1.36.3' });
  const first = await harness.service.check({ force: true });
  await harness.service.markPrompted(first);
  await harness.service.decide('remind', first);
  assert.equal((await harness.service.check({ force: true })).shouldPrompt, false);

  const dueAt = Date.parse(harness.state().decisions.reminder.after);
  harness.setNow(dueAt);
  const due = await harness.service.check({ force: true });
  assert.equal(due.shouldPrompt, true);
  await harness.service.markPrompted(due);
  harness.setNow(dueAt + 1);
  assert.equal((await harness.service.check({ force: true })).shouldPrompt, false);

  harness.state().decisions.reminder = {
    candidateKey: due.candidateKey,
    readyToInstall: false,
    after: 'not-a-date'
  };
  assert.equal((await harness.service.check({ force: true })).shouldPrompt, true);
});

test('new approval state is observed while official metadata remains cached', async () => {
  const reviewed = createServiceHarness({
    vscodiumVersion: '1.127.00001',
    codeOssVersion: '1.127.0',
    dbcodeVersion: '1.36.3'
  });
  const untested = await reviewed.service.check();
  await reviewed.service.markPrompted(untested);
  await reviewed.service.decide('review', untested);
  reviewed.setApprovedReleaseSets([approvedReleaseSet()]);
  const ready = await reviewed.service.check();
  assert.equal(ready.readyToInstall, true);
  assert.equal(ready.shouldPrompt, true);
  assert.equal(reviewed.requests.length, 3);

  const skipped = createServiceHarness({
    vscodiumVersion: '1.127.00001',
    codeOssVersion: '1.127.0',
    dbcodeVersion: '1.36.3'
  });
  const skippedStatus = await skipped.service.check();
  await skipped.service.markPrompted(skippedStatus);
  await skipped.service.decide('skip', skippedStatus);
  skipped.setApprovedReleaseSets([approvedReleaseSet()]);
  assert.equal((await skipped.service.check()).shouldPrompt, false);
});

test('the daily cache uses empty public requests and expires just after one day', async () => {
  const harness = createServiceHarness();
  assert.equal((await harness.service.check()).kind, 'current');
  assert.equal((await harness.service.check()).kind, 'current');
  harness.setNow(NOW + DAY_MS);
  assert.equal((await harness.service.check()).kind, 'current');
  assert.equal(harness.requests.length, 3);
  harness.setNow(NOW + DAY_MS + 1);
  assert.equal((await harness.service.check()).kind, 'current');
  assert.equal(harness.requests.length, 6);
  assert.equal(harness.requests.every(args => args.length === 1), true);
  assert.deepEqual(harness.requests.slice(0, 3), [
    [VSCODIUM_METADATA_URL],
    [CODE_OSS_METADATA_URL],
    [DBCODE_METADATA_URL]
  ]);
  assert.equal(harness.state().schemaVersion, 2);
  assert.equal(harness.state().lastCheckResult, 'success');
});

test('a legacy two-feed cache is refreshed without losing decisions', async () => {
  const checkedAt = new Date(NOW).toISOString();
  const harness = createServiceHarness({
    initialState: {
      schemaVersion: 1,
      decisions: { skippedCandidates: ['vscodium@old|dbcode@old'] },
      lastCheckAt: checkedAt,
      lastCheckResult: 'success',
      metadataCache: {
        checkedAt,
        available: {
          host: vscodiumRelease(),
          dbcode: dbcodeRelease()
        }
      }
    }
  });
  assert.equal((await harness.service.check()).kind, 'current');
  assert.equal(harness.requests.length, 3);
  assert.equal(harness.state().schemaVersion, 2);
  assert.deepEqual(harness.state().decisions.skippedCandidates, ['vscodium@old|dbcode@old']);
  assert.equal(harness.state().metadataCache.available.codeOss.version, INSTALLED_CODE_OSS);
});

test('offline and invalid checks never invent updates', async () => {
  const offline = createServiceHarness({ fetchFailure: true });
  const offlineStatus = await offline.service.check();
  assert.equal(offlineStatus.kind, 'offline');
  assert.equal(offlineStatus.updatesAvailable, false);
  assert.equal(offline.state().lastCheckResult, 'offline');

  const invalid = createServiceHarness();
  invalid.payloads.codeOss = {};
  const invalidStatus = await invalid.service.check();
  assert.equal(invalidStatus.kind, 'invalid');
  assert.equal(invalidStatus.updatesAvailable, false);
  assert.equal(invalid.state().lastCheckResult, 'invalid');
});

test('corrupt cached metadata is discarded before a release link is exposed', async () => {
  const checkedAt = new Date(NOW).toISOString();
  const harness = createServiceHarness({
    initialState: {
      schemaVersion: 2,
      decisions: { skippedCandidates: [] },
      lastCheckAt: checkedAt,
      lastCheckResult: 'success',
      metadataCache: {
        checkedAt,
        available: {
          vscodium: {
            version: INSTALLED_HOST,
            publishedAt: vscodiumRelease().publishedAt,
            releaseNotesUrl: 'https://github.com/VSCodium/vscodium/releases/tag/1.125.00000'
          },
          codeOss: codeOssRelease(),
          dbcode: dbcodeRelease()
        }
      }
    }
  });
  const status = await harness.service.check();
  assert.equal(status.kind, 'current');
  assert.equal(status.vscodium.availableReleaseNotesUrl, vscodiumRelease().releaseNotesUrl);
  assert.equal(harness.requests.length, 3);
});

test('unsupported decisions fail through the service interface', async () => {
  const harness = createServiceHarness({ dbcodeVersion: '1.36.3' });
  const status = await harness.service.check({ force: true });
  await assert.rejects(harness.service.decide('invented', status), /unsupported update decision/i);
});
