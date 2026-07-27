#!/usr/bin/env node

import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';

const require = createRequire(import.meta.url);
const {
  CACHE_TTL_MS,
  CODE_OSS_METADATA_URL,
  DBCODE_METADATA_URL,
  REMINDER_DELAY_MS,
  VSCODIUM_METADATA_URL,
  applyDecision,
  candidateKey,
  createReleaseStatusService,
  deriveStatus,
  normalizeCodeOssRelease,
  normalizeOpenVsxRecord,
  normalizeVscodiumRelease,
  recordPrompt,
  shouldUseCache
} = require('../host/extensions/dbcode-wrapper-release-status/release-status.js');

const NOW = Date.parse('2026-07-21T00:00:00Z');
const INSTALLED_HOST = '1.126.04524';
const INSTALLED_CODE_OSS = '1.126.0';
const INSTALLED_DBCODE = '1.36.2';
const SOURCE_ID_SHA = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

function vscodiumRelease(version = INSTALLED_HOST) {
  return {
    version,
    publishedAt: '2026-07-07T13:01:09Z',
    releaseNotesUrl: `https://github.com/VSCodium/vscodium/releases/tag/${version}`
  };
}

function dbcodeRelease(version = INSTALLED_DBCODE) {
  return {
    version,
    publishedAt: '2026-07-20T04:51:39.562360Z',
    releaseNotesUrl: `https://dbcode.io/docs/changelog/${version}`
  };
}

function codeOssRelease(version = INSTALLED_CODE_OSS) {
  return {
    version,
    publishedAt: '2026-06-24T12:49:34Z',
    releaseNotesUrl: `https://github.com/microsoft/vscode/releases/tag/${version}`
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
  const codeOssTag = vscodiumVersion === INSTALLED_HOST ? '1.126.0' : '1.127.0';
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

function statusFor({
  vscodiumVersion = INSTALLED_HOST,
  codeOssVersion = INSTALLED_CODE_OSS,
  dbcodeVersion = INSTALLED_DBCODE,
  approvedReleaseSets = [],
  state = {},
  source = 'network'
} = {}) {
  return deriveStatus({
    installed: installed(),
    available: {
      vscodium: vscodiumRelease(vscodiumVersion),
      codeOss: codeOssRelease(codeOssVersion),
      dbcode: dbcodeRelease(dbcodeVersion)
    },
    approvedReleaseSets,
    state,
    source,
    now: NOW
  });
}

function createServiceHarness({
  vscodiumVersion = INSTALLED_HOST,
  codeOssVersion = INSTALLED_CODE_OSS,
  dbcodeVersion = INSTALLED_DBCODE,
  approvedReleaseSets = [],
  initialState,
  now = () => NOW
} = {}) {
  let storedState = initialState;
  const requests = [];
  const service = createReleaseStatusService({
    installed: installed(),
    approvedReleaseSets,
    now,
    loadState: async () => storedState,
    saveState: async state => { storedState = state; },
    fetchJson: async url => {
      requests.push(url);
      if (url === VSCODIUM_METADATA_URL) {
        return {
          tag_name: vscodiumVersion,
          published_at: vscodiumRelease(vscodiumVersion).publishedAt,
          html_url: vscodiumRelease(vscodiumVersion).releaseNotesUrl,
          draft: false,
          prerelease: false
        };
      }
      if (url === CODE_OSS_METADATA_URL) {
        return {
          tag_name: codeOssVersion,
          published_at: codeOssRelease(codeOssVersion).publishedAt,
          html_url: codeOssRelease(codeOssVersion).releaseNotesUrl,
          draft: false,
          prerelease: false
        };
      }
      return {
        namespace: 'dbcode',
        name: 'dbcode',
        verified: true,
        preRelease: false,
        deprecated: false,
        version: dbcodeVersion,
        timestamp: dbcodeRelease(dbcodeVersion).publishedAt,
        files: {}
      };
    }
  });
  return {
    service,
    requests,
    storedState: () => storedState
  };
}

test('normalizes only the official VSCodium stable release record', () => {
  assert.deepEqual(normalizeVscodiumRelease({
    tag_name: '1.127.00001',
    published_at: '2026-07-22T12:00:00Z',
    html_url: 'https://github.com/VSCodium/vscodium/releases/tag/1.127.00001',
    draft: false,
    prerelease: false
  }), {
    version: '1.127.00001',
    publishedAt: '2026-07-22T12:00:00Z',
    releaseNotesUrl: 'https://github.com/VSCodium/vscodium/releases/tag/1.127.00001'
  });

  assert.throws(() => normalizeVscodiumRelease({
    tag_name: '1.127.00001',
    published_at: '2026-07-22T12:00:00Z',
    html_url: 'https://github.com/VSCodium/vscodium/releases/tag/1.126.00000',
    draft: false,
    prerelease: false
  }), /official VSCodium/i);
});

test('normalizes only the official Code OSS stable release record', () => {
  assert.deepEqual(normalizeCodeOssRelease({
    tag_name: '1.130.0',
    published_at: '2026-07-22T17:39:17Z',
    html_url: 'https://github.com/microsoft/vscode/releases/tag/1.130.0',
    draft: false,
    prerelease: false
  }), {
    version: '1.130.0',
    publishedAt: '2026-07-22T17:39:17Z',
    releaseNotesUrl: 'https://github.com/microsoft/vscode/releases/tag/1.130.0'
  });

  assert.throws(() => normalizeCodeOssRelease({
    tag_name: '1.130.0',
    published_at: '2026-07-22T17:39:17Z',
    html_url: 'https://github.com/microsoft/vscode/releases/tag/1.129.0',
    draft: false,
    prerelease: false
  }), /official Code OSS/i);
});

test('normalizes only the official DBCode Open VSX record', () => {
  assert.deepEqual(normalizeOpenVsxRecord({
    namespace: 'dbcode',
    name: 'dbcode',
    verified: true,
    preRelease: false,
    deprecated: false,
    version: '1.36.3',
    timestamp: '2026-07-22T13:00:00Z',
    files: {
      changelog: 'https://open-vsx.org/api/dbcode/dbcode/1.36.3/file/changelog.md'
    }
  }), {
    version: '1.36.3',
    publishedAt: '2026-07-22T13:00:00Z',
    releaseNotesUrl: 'https://dbcode.io/docs/changelog/1.36.3'
  });

  assert.throws(() => normalizeOpenVsxRecord({
    namespace: 'someone-else',
    name: 'dbcode',
    version: '9.9.9',
    timestamp: '2026-07-22T13:00:00Z',
    files: {}
  }), /official DBCode/i);

  for (const rejected of [
    { verified: false, preRelease: false, deprecated: false },
    { verified: true, preRelease: true, deprecated: false },
    { verified: true, preRelease: false, deprecated: true }
  ]) {
    assert.throws(() => normalizeOpenVsxRecord({
      namespace: 'dbcode',
      name: 'dbcode',
      version: '1.36.3',
      timestamp: '2026-07-22T13:00:00Z',
      files: {},
      ...rejected
    }), /verified stable release/i);
  }
});

test('reports no update when all three official versions match the installed set', () => {
  const status = statusFor();
  assert.equal(status.kind, 'current');
  assert.equal(status.updatesAvailable, false);
  assert.equal(status.shouldPrompt, false);
  assert.equal(status.vscodium.readiness, 'Current');
  assert.equal(status.dbcode.readiness, 'Current');
});

test('reports a newer Code OSS runtime while VSCodium packaging and DBCode remain current', () => {
  const status = statusFor({ codeOssVersion: '1.130.0' });

  assert.equal(status.kind, 'update-available');
  assert.equal(
    status.candidateKey,
    'vscodium@1.126.04524|code-oss@1.130.0|dbcode@1.36.2'
  );
  assert.equal(status.codeOss.installedVersion, INSTALLED_CODE_OSS);
  assert.equal(status.codeOss.availableVersion, '1.130.0');
  assert.equal(status.codeOss.updateAvailable, true);
  assert.equal(status.codeOss.readiness, 'Not tested');
  assert.equal(status.vscodium.updateAvailable, false);
  assert.equal(status.dbcode.updateAvailable, false);
  assert.equal(status.readyToInstall, false);
  assert.equal(status.shouldPrompt, true);
});

test('the service boundary keeps all three update inputs independent', async () => {
  const cases = [
    {
      name: 'Code OSS only',
      versions: { codeOssVersion: '1.130.0' },
      expected: { vscodium: false, codeOss: true, dbcode: false }
    },
    {
      name: 'VSCodium only',
      versions: { vscodiumVersion: '1.127.00001' },
      expected: { vscodium: true, codeOss: false, dbcode: false }
    },
    {
      name: 'DBCode only',
      versions: { dbcodeVersion: '1.36.3' },
      expected: { vscodium: false, codeOss: false, dbcode: true }
    },
    {
      name: 'combined',
      versions: { vscodiumVersion: '1.127.00001', codeOssVersion: '1.130.0', dbcodeVersion: '1.36.3' },
      expected: { vscodium: true, codeOss: true, dbcode: true }
    }
  ];

  for (const scenario of cases) {
    const harness = createServiceHarness(scenario.versions);
    const status = await harness.service.check({ force: true });
    assert.equal(status.vscodium.updateAvailable, scenario.expected.vscodium, `${scenario.name} VSCodium state`);
    assert.equal(status.codeOss.updateAvailable, scenario.expected.codeOss, `${scenario.name} Code OSS state`);
    assert.equal(status.dbcode.updateAvailable, scenario.expected.dbcode, `${scenario.name} DBCode state`);
    assert.equal(status.readyToInstall, false, `${scenario.name} must remain untested`);
    assert.deepEqual(harness.requests, [VSCODIUM_METADATA_URL, CODE_OSS_METADATA_URL, DBCODE_METADATA_URL]);
  }
});

test('reports a VSCodium-only update as untested packaging input', () => {
  const status = statusFor({ vscodiumVersion: '1.127.00001' });
  assert.equal(status.kind, 'update-available');
  assert.equal(status.vscodium.updateAvailable, true);
  assert.equal(status.vscodium.readiness, 'Not tested');
  assert.equal(status.dbcode.updateAvailable, false);
  assert.equal(status.dbcode.readiness, 'Current');
  assert.equal(status.readyToInstall, false);
  assert.equal(status.shouldPrompt, true);
});

test('reports a DBCode-only update separately from the runtime and packaging', () => {
  const status = statusFor({ dbcodeVersion: '1.36.3' });
  assert.equal(status.kind, 'update-available');
  assert.equal(status.vscodium.updateAvailable, false);
  assert.equal(status.dbcode.updateAvailable, true);
  assert.equal(status.dbcode.readiness, 'Not tested');
  assert.equal(status.shouldPrompt, true);
});

test('reports simultaneous VSCodium and DBCode updates as one exact release set', () => {
  const status = statusFor({ vscodiumVersion: '1.127.00001', dbcodeVersion: '1.36.3' });
  assert.equal(status.candidateKey, candidateKey({
    vscodiumVersion: '1.127.00001',
    codeOssVersion: INSTALLED_CODE_OSS,
    dbcodeVersion: '1.36.3'
  }));
  assert.equal(status.vscodium.updateAvailable, true);
  assert.equal(status.dbcode.updateAvailable, true);
  assert.equal(status.readyToInstall, false);
});

test('an older feed entry never replaces an installed component in the release set', () => {
  const approvedReleaseSets = [approvedReleaseSet(INSTALLED_HOST, '1.36.3')];
  const status = statusFor({
    vscodiumVersion: '1.125.00001',
    dbcodeVersion: '1.36.3',
    approvedReleaseSets
  });

  assert.equal(status.candidateKey, candidateKey({
    vscodiumVersion: INSTALLED_HOST,
    codeOssVersion: INSTALLED_CODE_OSS,
    dbcodeVersion: '1.36.3'
  }));
  assert.equal(status.vscodium.updateAvailable, false);
  assert.equal(status.dbcode.updateAvailable, true);
  assert.equal(status.readyToInstall, true);
  assert.equal(status.vscodium.availableVersion, INSTALLED_HOST);
  assert.equal(status.vscodium.availablePublishedAt, installed().host.publishedAt);
  assert.equal(status.vscodium.availableReleaseNotesUrl, installed().host.releaseNotesUrl);
});

test('skipping a candidate suppresses only that exact release tuple', () => {
  const first = statusFor({ dbcodeVersion: '1.36.3' });
  const prompted = recordPrompt({}, first, NOW);
  const skipped = applyDecision(prompted, 'skip', first, NOW);

  assert.equal(statusFor({ dbcodeVersion: '1.36.3', state: skipped }).shouldPrompt, false);
  assert.equal(statusFor({ dbcodeVersion: '1.36.4', state: skipped }).shouldPrompt, true);
});

test('remind later suppresses the same candidate until the reminder is due', () => {
  const first = statusFor({ dbcodeVersion: '1.36.3' });
  const reminded = applyDecision(recordPrompt({}, first, NOW), 'remind', first, NOW);

  const before = deriveStatus({
    installed: installed(),
    available: { vscodium: vscodiumRelease(), codeOss: codeOssRelease(), dbcode: dbcodeRelease('1.36.3') },
    approvedReleaseSets: [],
    state: reminded,
    source: 'network',
    now: NOW + REMINDER_DELAY_MS - 1
  });
  const due = deriveStatus({
    installed: installed(),
    available: { vscodium: vscodiumRelease(), codeOss: codeOssRelease(), dbcode: dbcodeRelease('1.36.3') },
    approvedReleaseSets: [],
    state: reminded,
    source: 'network',
    now: NOW + REMINDER_DELAY_MS
  });

  assert.equal(before.shouldPrompt, false);
  assert.equal(due.shouldPrompt, true);
  const promptedAgain = recordPrompt(reminded, due, NOW + REMINDER_DELAY_MS);
  assert.equal(deriveStatus({
    installed: installed(),
    available: { vscodium: vscodiumRelease(), codeOss: codeOssRelease(), dbcode: dbcodeRelease('1.36.3') },
    approvedReleaseSets: [],
    state: promptedAgain,
    source: 'network',
    now: NOW + REMINDER_DELAY_MS + 1
  }).shouldPrompt, false);
});

test('an invalid reminder timestamp cannot suppress an update forever', () => {
  const update = statusFor({ dbcodeVersion: '1.36.3' });
  const state = applyDecision(recordPrompt({}, update, NOW), 'remind', update, NOW);
  state.reminder.after = 'not-a-date';
  const status = statusFor({
    dbcodeVersion: '1.36.3',
    state
  });

  assert.equal(status.shouldPrompt, true);
});

test('an offline registry is visible but never creates a new prompt', () => {
  const status = deriveStatus({
    installed: installed(),
    available: undefined,
    approvedReleaseSets: [],
    state: {},
    source: 'offline',
    now: NOW
  });

  assert.equal(status.kind, 'offline');
  assert.equal(status.shouldPrompt, false);
  assert.equal(status.updatesAvailable, false);
});

test('invalid metadata is visible but never treated as an update', () => {
  const status = deriveStatus({
    installed: installed(),
    available: undefined,
    approvedReleaseSets: [],
    state: {},
    source: 'invalid',
    now: NOW
  });

  assert.equal(status.kind, 'invalid');
  assert.equal(status.shouldPrompt, false);
  assert.equal(status.readyToInstall, false);
});

test('missing Code OSS metadata never reports the release set as current', () => {
  const status = deriveStatus({
    installed: installed(),
    available: { vscodium: vscodiumRelease(), dbcode: dbcodeRelease() },
    approvedReleaseSets: [],
    state: {},
    source: 'network',
    now: NOW
  });

  assert.equal(status.kind, 'offline');
  assert.equal(status.updatesAvailable, false);
  assert.equal(status.shouldPrompt, false);
});

test('an exact locally approved release set becomes ready without calling it installed', () => {
  const approvedReleaseSets = [approvedReleaseSet()];
  const status = statusFor({
    vscodiumVersion: '1.127.00001',
    codeOssVersion: '1.127.0',
    dbcodeVersion: '1.36.3',
    approvedReleaseSets
  });

  assert.equal(status.kind, 'update-available');
  assert.equal(status.readyToInstall, true);
  assert.equal(status.vscodium.readiness, 'Ready to install');
  assert.equal(status.codeOss.readiness, 'Ready to install');
  assert.equal(status.dbcode.readiness, 'Ready to install');
});

test('the service rejects an approval whose Code OSS version does not match', async () => {
  const approvedReleaseSets = [approvedReleaseSet()];
  const mismatched = createServiceHarness({
    vscodiumVersion: '1.127.00001',
    codeOssVersion: '1.128.0',
    dbcodeVersion: '1.36.3',
    approvedReleaseSets
  });
  const exact = createServiceHarness({
    vscodiumVersion: '1.127.00001',
    codeOssVersion: '1.127.0',
    dbcodeVersion: '1.36.3',
    approvedReleaseSets
  });

  assert.equal((await mismatched.service.check({ force: true })).readyToInstall, false);
  assert.equal((await exact.service.check({ force: true })).readyToInstall, true);
});

test('an approved candidate may advance to a newer compatible profile schema', () => {
  const candidate = approvedReleaseSet();
  candidate.profile.schema_version = 2;
  const status = statusFor({
    vscodiumVersion: '1.127.00001',
    codeOssVersion: '1.127.0',
    dbcodeVersion: '1.36.3',
    approvedReleaseSets: [candidate]
  });

  assert.equal(status.readyToInstall, true);
  assert.equal(status.approvedReleaseSetId, candidate.id);
});

test('a partial version-only history record is never treated as an approved release set', () => {
  const status = statusFor({
    vscodiumVersion: '1.127.00001',
    dbcodeVersion: '1.36.3',
    approvedReleaseSets: [{
      id: 'not-an-exact-release-set',
      host: { vscodium_tag: '1.127.00001' },
      dbcode: { version: '1.36.3' }
    }]
  });

  assert.equal(status.readyToInstall, false);
  assert.equal(status.vscodium.readiness, 'Not tested');
});

test('an approval without its exact attestation digest is never ready to install', () => {
  const candidate = approvedReleaseSet();
  delete candidate.manifest.approval_attestation_sha256;
  const status = statusFor({
    vscodiumVersion: '1.127.00001',
    dbcodeVersion: '1.36.3',
    approvedReleaseSets: [candidate]
  });

  assert.equal(status.readyToInstall, false);
});

test('an approval id that is unrelated to its source and artifact is never ready to install', () => {
  const candidate = approvedReleaseSet();
  candidate.id = 'completely-unrelated-id';
  candidate.manifest.schema_version = 999;
  const status = statusFor({
    vscodiumVersion: '1.127.00001',
    dbcodeVersion: '1.36.3',
    approvedReleaseSets: [candidate]
  });

  assert.equal(status.readyToInstall, false);
});

test('the installed identity must include its canonical candidate source id', () => {
  const invalidInstalled = installed();
  delete invalidInstalled.sourceSetId;

  assert.throws(() => deriveStatus({
    installed: invalidInstalled,
    available: { vscodium: vscodiumRelease(), codeOss: codeOssRelease(), dbcode: dbcodeRelease() },
    now: NOW
  }), /installed release-set identity/i);
});

test('the installed identity rejects unsupported targets and non-official release metadata', () => {
  const invalidInstalled = installed();
  invalidInstalled.target = { platform: 'banana', architecture: 'toaster' };
  invalidInstalled.host.publishedAt = 'not-a-date';
  invalidInstalled.host.releaseNotesUrl = 'https://evil.example/host';
  invalidInstalled.dbcode.releaseNotesUrl = 'https://evil.example/dbcode';

  assert.throws(() => deriveStatus({
    installed: invalidInstalled,
    available: { vscodium: vscodiumRelease(), codeOss: codeOssRelease(), dbcode: dbcodeRelease() },
    now: NOW
  }), /installed release-set identity/i);
});

test('the installed identity requires official Code OSS publication metadata', () => {
  const invalidInstalled = installed();
  delete invalidInstalled.host.codeOssPublishedAt;

  assert.throws(() => deriveStatus({
    installed: invalidInstalled,
    available: {
      vscodium: vscodiumRelease(),
      codeOss: codeOssRelease(),
      dbcode: dbcodeRelease()
    },
    now: NOW
  }), /installed release-set identity/i);
});

test('local approval prompts again for a previously reviewed candidate but still respects an explicit skip', () => {
  const untested = statusFor({ vscodiumVersion: '1.127.00001', codeOssVersion: '1.127.0', dbcodeVersion: '1.36.3' });
  const reviewed = applyDecision(recordPrompt({}, untested, NOW), 'review', untested, NOW);
  const skipped = applyDecision(recordPrompt({}, untested, NOW), 'skip', untested, NOW);
  const approvedReleaseSets = [approvedReleaseSet()];

  assert.equal(statusFor({
    vscodiumVersion: '1.127.00001',
    codeOssVersion: '1.127.0',
    dbcodeVersion: '1.36.3',
    approvedReleaseSets,
    state: reviewed
  }).shouldPrompt, true);
  assert.equal(statusFor({
    vscodiumVersion: '1.127.00001',
    codeOssVersion: '1.127.0',
    dbcodeVersion: '1.36.3',
    approvedReleaseSets,
    state: skipped
  }).shouldPrompt, false);
});

test('a newly written complete approval is observed while official metadata remains cached', async () => {
  let storedState;
  let approvedReleaseSets = [];
  let requestCount = 0;
  const service = createReleaseStatusService({
    installed: installed(),
    loadApprovedReleaseSets: async () => approvedReleaseSets,
    now: () => NOW,
    loadState: async () => storedState,
    saveState: async state => { storedState = state; },
    fetchJson: async url => {
      requestCount++;
      if (url === VSCODIUM_METADATA_URL) {
        return {
          tag_name: '1.127.00001',
          published_at: '2026-07-22T12:00:00Z',
          html_url: 'https://github.com/VSCodium/vscodium/releases/tag/1.127.00001',
          draft: false,
          prerelease: false
        };
      }
      if (url === CODE_OSS_METADATA_URL) {
        return {
          tag_name: '1.127.0',
          published_at: '2026-07-22T12:30:00Z',
          html_url: codeOssRelease('1.127.0').releaseNotesUrl,
          draft: false,
          prerelease: false
        };
      }
      return {
        namespace: 'dbcode',
        name: 'dbcode',
        verified: true,
        preRelease: false,
        deprecated: false,
        version: '1.36.3',
        timestamp: '2026-07-22T13:00:00Z',
        files: {}
      };
    }
  });

  const untested = await service.check();
  assert.equal(untested.readyToInstall, false);
  await service.markPrompted(untested);
  await service.decide('review', untested);
  approvedReleaseSets = [approvedReleaseSet()];

  const ready = await service.check();
  assert.equal(ready.readyToInstall, true);
  assert.equal(ready.approvedReleaseSetId, approvedReleaseSet().id);
  assert.equal(ready.shouldPrompt, true);
  assert.equal(requestCount, 3, 'Approval changes must reuse the daily official-metadata cache.');
});

test('skip and remind decisions are enforced through the service boundary', async () => {
  const skipped = createServiceHarness({ dbcodeVersion: '1.36.3' });
  const skippedStatus = await skipped.service.check({ force: true });
  await skipped.service.markPrompted(skippedStatus);
  await skipped.service.decide('skip', skippedStatus);
  assert.equal((await skipped.service.check()).shouldPrompt, false);

  let clock = NOW;
  const reminded = createServiceHarness({ dbcodeVersion: '1.36.3', now: () => clock });
  const remindedStatus = await reminded.service.check({ force: true });
  await reminded.service.markPrompted(remindedStatus);
  await reminded.service.decide('remind', remindedStatus);
  assert.equal((await reminded.service.check()).shouldPrompt, false);
  clock += REMINDER_DELAY_MS;
  assert.equal((await reminded.service.check({ force: true })).shouldPrompt, true);
});

test('metadata cache is valid for one day and expires immediately after it', () => {
  const cache = { checkedAt: new Date(NOW).toISOString() };
  assert.equal(shouldUseCache(cache, NOW + CACHE_TTL_MS), true);
  assert.equal(shouldUseCache(cache, NOW + CACHE_TTL_MS + 1), false);
});

test('the service sends only empty public metadata requests and reuses its daily cache', async () => {
  let storedState;
  const requests = [];
  const service = createReleaseStatusService({
    installed: installed(),
    approvedReleaseSets: [],
    now: () => NOW,
    loadState: async () => storedState,
    saveState: async state => { storedState = state; },
    fetchJson: async (...argumentsReceived) => {
      requests.push(argumentsReceived);
      if (argumentsReceived[0] === VSCODIUM_METADATA_URL) {
        return {
          tag_name: INSTALLED_HOST,
          published_at: '2026-07-07T13:01:09Z',
          html_url: `https://github.com/VSCodium/vscodium/releases/tag/${INSTALLED_HOST}`,
          draft: false,
          prerelease: false
        };
      }
      if (argumentsReceived[0] === CODE_OSS_METADATA_URL) {
        return {
          tag_name: INSTALLED_CODE_OSS,
          published_at: codeOssRelease().publishedAt,
          html_url: codeOssRelease().releaseNotesUrl,
          draft: false,
          prerelease: false
        };
      }
      return {
        namespace: 'dbcode',
        name: 'dbcode',
        verified: true,
        preRelease: false,
        deprecated: false,
        version: INSTALLED_DBCODE,
        timestamp: '2026-07-20T04:51:39.562360Z',
        files: {}
      };
    }
  });

  assert.equal((await service.check()).kind, 'current');
  assert.equal((await service.check()).kind, 'current');
  assert.deepEqual(requests, [
    [VSCODIUM_METADATA_URL],
    [CODE_OSS_METADATA_URL],
    [DBCODE_METADATA_URL]
  ]);
  assert.equal(storedState.schemaVersion, 2);
  assert.equal(storedState.lastCheckResult, 'success');
  assert.deepEqual(Object.keys(storedState).sort(), [
    'decisions',
    'lastCheckAt',
    'lastCheckResult',
    'metadataCache',
    'schemaVersion'
  ]);
});

test('a legacy two-feed cache is refreshed without losing update decisions', async () => {
  const checkedAt = new Date(NOW).toISOString();
  let storedState = {
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
  };
  const requests = [];
  const service = createReleaseStatusService({
    installed: installed(),
    now: () => NOW,
    loadState: async () => storedState,
    saveState: async state => { storedState = state; },
    fetchJson: async url => {
      requests.push(url);
      if (url === VSCODIUM_METADATA_URL) {
        return {
          tag_name: INSTALLED_HOST,
          published_at: vscodiumRelease().publishedAt,
          html_url: vscodiumRelease().releaseNotesUrl,
          draft: false,
          prerelease: false
        };
      }
      if (url === CODE_OSS_METADATA_URL) {
        return {
          tag_name: INSTALLED_CODE_OSS,
          published_at: codeOssRelease().publishedAt,
          html_url: codeOssRelease().releaseNotesUrl,
          draft: false,
          prerelease: false
        };
      }
      return {
        namespace: 'dbcode',
        name: 'dbcode',
        verified: true,
        preRelease: false,
        deprecated: false,
        version: INSTALLED_DBCODE,
        timestamp: dbcodeRelease().publishedAt,
        files: {}
      };
    }
  });

  assert.equal((await service.check()).kind, 'current');
  assert.deepEqual(requests, [VSCODIUM_METADATA_URL, CODE_OSS_METADATA_URL, DBCODE_METADATA_URL]);
  assert.equal(storedState.schemaVersion, 2);
  assert.deepEqual(storedState.decisions.skippedCandidates, ['vscodium@old|dbcode@old']);
  assert.equal(storedState.metadataCache.available.codeOss.version, INSTALLED_CODE_OSS);
});

test('the service records offline and invalid checks without inventing updates', async () => {
  let offlineState;
  const offline = createReleaseStatusService({
    installed: installed(),
    approvedReleaseSets: [],
    now: () => NOW,
    loadState: async () => offlineState,
    saveState: async state => { offlineState = state; },
    fetchJson: async () => { throw new Error('network down'); }
  });
  assert.equal((await offline.check()).kind, 'offline');
  assert.equal(offlineState.lastCheckResult, 'offline');

  let invalidState;
  const invalid = createReleaseStatusService({
    installed: installed(),
    approvedReleaseSets: [],
    now: () => NOW,
    loadState: async () => invalidState,
    saveState: async state => { invalidState = state; },
    fetchJson: async url => url === VSCODIUM_METADATA_URL ? {} : {
      namespace: 'dbcode',
      name: 'dbcode',
      verified: true,
      preRelease: false,
      deprecated: false,
      version: INSTALLED_DBCODE,
      timestamp: '2026-07-20T04:51:39.562360Z',
      files: {}
    }
  });
  assert.equal((await invalid.check()).kind, 'invalid');
  assert.equal(invalidState.lastCheckResult, 'invalid');
});

test('corrupt cached metadata is discarded before it can open a non-official release URL', async () => {
  const checkedAt = new Date(NOW).toISOString();
  let requestCount = 0;
  let storedState = {
    schemaVersion: 2,
    decisions: { skippedCandidates: [] },
    lastCheckAt: checkedAt,
    lastCheckResult: 'success',
    metadataCache: {
      checkedAt,
      available: {
        vscodium: {
          version: INSTALLED_HOST,
          publishedAt: '2026-07-07T13:01:09Z',
          releaseNotesUrl: 'https://github.com/VSCodium/vscodium/releases/tag/1.125.00000'
        },
        codeOss: codeOssRelease(),
        dbcode: dbcodeRelease()
      }
    }
  };
  const service = createReleaseStatusService({
    installed: installed(),
    now: () => NOW,
    loadState: async () => storedState,
    saveState: async state => { storedState = state; },
    fetchJson: async url => {
      requestCount++;
      if (url === VSCODIUM_METADATA_URL) {
        return {
          tag_name: INSTALLED_HOST,
          published_at: '2026-07-07T13:01:09Z',
          html_url: `https://github.com/VSCodium/vscodium/releases/tag/${INSTALLED_HOST}`,
          draft: false,
          prerelease: false
        };
      }
      if (url === CODE_OSS_METADATA_URL) {
        return {
          tag_name: INSTALLED_CODE_OSS,
          published_at: codeOssRelease().publishedAt,
          html_url: codeOssRelease().releaseNotesUrl,
          draft: false,
          prerelease: false
        };
      }
      return {
        namespace: 'dbcode',
        name: 'dbcode',
        verified: true,
        preRelease: false,
        deprecated: false,
        version: INSTALLED_DBCODE,
        timestamp: '2026-07-20T04:51:39.562360Z',
        files: {}
      };
    }
  });

  const status = await service.check();
  assert.equal(status.kind, 'current');
  assert.equal(status.vscodium.availableReleaseNotesUrl.startsWith('https://github.com/VSCodium/'), true);
  assert.equal(requestCount, 3);
});
