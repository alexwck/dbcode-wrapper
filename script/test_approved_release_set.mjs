import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

import approvedReleaseSet from '../host/extensions/dbcode-wrapper-release-status/approved-release-set.js';

const scriptRoot = dirname(fileURLToPath(import.meta.url));
const contractCli = join(scriptRoot, 'approved_release_set.cjs');
const sha = character => character.repeat(64);
const commit = character => character.repeat(40);
const sourceSetId = `code-oss-1.127.0-dbcode-1.37.0-source-${sha('a')}`;
const artifactSha = sha('b');
const releaseSetId = `${sourceSetId}-artifact-${artifactSha}`;

function preparedSet(overrides = {}) {
  return {
    schema_version: 1,
    role: 'candidate',
    prepared_at_utc: '2026-07-23T00:00:00Z',
    release: { release_set_id: releaseSetId, source_set_id: sourceSetId },
    source: { repository_revision: commit('c') },
    target: { platform: 'darwin', architecture: 'arm64' },
    host: {
      app_sha256: artifactSha,
      build_manifest_sha256: sha('d'),
      code_oss_version: '1.127.0'
    },
    dbcode: {
      id: 'dbcode.dbcode',
      version: '1.37.0',
      vsix_sha256: sha('e'),
      signature_archive_sha256: sha('f')
    },
    profile: {
      schema_version: 2,
      user_data_sha256: sha('1'),
      source_extensions_sha256: sha('2'),
      extensions_sha256: sha('2'),
      shared_data_sha256: sha('3'),
      installed_extensions: ['dbcode.dbcode@1.37.0'],
      restored_signed_payloads: []
    },
    evidence: { proof_sha256: sha('4') },
    paths: {
      app: 'DBCode Wrapper.app',
      build_manifest: 'build-manifest.json',
      release_lock: 'release-lock.json',
      user_data: 'profile/user-data',
      extensions: 'profile/extensions',
      shared_data: 'profile/shared-data',
      proof: 'evidence/proof-state.json'
    },
    ...overrides
  };
}

function completeApproval(overrides = {}) {
  return {
    schema_version: 2,
    id: releaseSetId,
    source_set_id: sourceSetId,
    compatibility_status: 'approved',
    source_commit: commit('c'),
    target: { platform: 'darwin', architecture: 'arm64' },
    profile: { schema_version: 2 },
    manifest: {
      schema_version: 6,
      build_manifest_sha256: sha('d'),
      candidate_manifest_sha256: sha('d'),
      approval_attestation_sha256: sha('5'),
      artifact_sha256: artifactSha,
      shell_patch_revision: sha('6'),
      overlay_sha256: sha('7'),
      source_snapshot_sha256: sha('8'),
      compiled_host_input_id: `compiled-host-${sha('9')}`,
      packaging_status: 'built-and-signed'
    },
    host: {
      vscodium_tag: '1.127.0',
      vscodium_commit: commit('8'),
      code_oss_tag: '1.127.0',
      code_oss_commit: commit('9')
    },
    dbcode: {
      id: 'dbcode.dbcode',
      version: '1.37.0',
      vsix_sha256: sha('e'),
      signature_archive_sha256: sha('f')
    },
    approval: {
      approved_at: '2026-07-23T00:05:00Z',
      validation_issue: '18-deepen-the-approved-release-set-contract',
      proof_sha256: sha('4'),
      gate_receipt_sha256: sha('0')
    },
    ...overrides
  };
}

function installedIdentity() {
  return {
    schemaVersion: 1,
    compatibilityStatus: 'candidate',
    profileSchemaVersion: 1,
    sourceSetId: `code-oss-1.126.0-dbcode-1.36.2-source-${sha('a')}`,
    target: { platform: 'darwin', architecture: 'arm64' },
    host: {
      version: '1.126.04524',
      codeOssVersion: '1.126.0',
      vscodiumCommit: commit('1'),
      codeOssCommit: commit('2'),
      publishedAt: '2026-07-01T00:00:00Z',
      releaseNotesUrl: 'https://github.com/VSCodium/vscodium/releases/tag/1.126.04524',
      codeOssPublishedAt: '2026-06-24T12:49:34Z',
      codeOssReleaseNotesUrl: 'https://github.com/microsoft/vscode/releases/tag/1.126.0'
    },
    dbcode: {
      version: '1.36.2',
      sha256: sha('3'),
      publishedAt: '2026-07-01T00:00:00Z',
      releaseNotesUrl: 'https://dbcode.io/docs/changelog/1.36.2'
    }
  };
}

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

function cliAccepts(command, path) {
  try {
    execFileSync(process.execPath, [contractCli, command, path], { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

test('shell and JavaScript adapters accept and reject the same records', t => {
  const root = mkdtempSync(join(tmpdir(), 'dbcode-approved-release-set-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const fixtures = [
    ['valid', completeApproval(), true],
    ['bad-hash', completeApproval({ manifest: { ...completeApproval().manifest, artifact_sha256: 'bad' } }), false],
    ['missing-evidence', completeApproval({ approval: { approved_at: '2026-07-23T00:05:00Z' } }), false],
    ['wrong-pair', completeApproval({ dbcode: { ...completeApproval().dbcode, version: '9.9.9' } }), false]
  ];

  for (const [name, record, expected] of fixtures) {
    const fixture = join(root, `${name}.json`);
    writeJson(fixture, record);
    const jsAccepted = (() => {
      try {
        approvedReleaseSet.validateApprovedRecord(record, { allowLegacy: false });
        return true;
      } catch {
        return false;
      }
    })();
    assert.equal(jsAccepted, expected, `${name} JavaScript decision`);
    assert.equal(cliAccepts('validate-approved', fixture), expected, `${name} shell decision`);
  }
});

test('prepared release members stay inside the prepared directory', t => {
  const root = mkdtempSync(join(tmpdir(), 'dbcode-prepared-release-set-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const setFile = join(root, 'release-set.json');
  const app = join(root, 'DBCode Wrapper.app');
  mkdirSync(app);
  writeJson(setFile, preparedSet());

  approvedReleaseSet.validatePreparedReleaseSet(preparedSet());
  assert.equal(approvedReleaseSet.resolvePreparedMember(setFile, 'app'), realpathSync(app));
  assert.equal(
    execFileSync(process.execPath, [contractCli, 'member', setFile, 'app'], { encoding: 'utf8' }).trim(),
    realpathSync(app)
  );

  const unsafe = preparedSet({ paths: { ...preparedSet().paths, app: '../Outside.app' } });
  assert.throws(() => approvedReleaseSet.validatePreparedReleaseSet(unsafe), /path/i);
  const link = join(root, 'linked-app');
  symlinkSync(app, link);
  writeJson(setFile, preparedSet({ paths: { ...preparedSet().paths, app: 'linked-app' } }));
  assert.throws(() => approvedReleaseSet.resolvePreparedMember(setFile, 'app'), /symlink/i);
});

test('legacy history remains readable but never becomes update-ready', () => {
  const legacy = {
    id: 'code-oss-1.126.0-dbcode-1.36.1',
    compatibility_status: 'approved',
    source_commit: commit('1'),
    target: { platform: 'darwin', architecture: 'arm64' },
    profile: { schema_version: 1 },
    manifest: {
      schema_version: 2,
      build_manifest_sha256: sha('2'), artifact_sha256: sha('3'),
      shell_patch_revision: sha('4'), overlay_sha256: sha('5'),
      packaging_status: 'built-and-signed'
    },
    host: {
      vscodium_tag: '1.126.04524', vscodium_commit: commit('6'),
      code_oss_tag: '1.126.0', code_oss_commit: commit('7')
    },
    dbcode: {
      id: 'dbcode.dbcode', version: '1.36.1',
      vsix_sha256: sha('8'), signature_archive_sha256: sha('9')
    }
  };
  const history = { schema_version: 2, approved_release_sets: [legacy, completeApproval()] };
  assert.equal(approvedReleaseSet.validateApprovedHistory(history).records[0].kind, 'legacy');
  const previous = completeApproval();
  previous.schema_version = 1;
  previous.manifest.schema_version = 5;
  delete previous.manifest.source_snapshot_sha256;
  delete previous.manifest.compiled_host_input_id;
  assert.equal(approvedReleaseSet.validateApprovedRecord(previous).kind, 'previous');
  assert.equal(
    approvedReleaseSet.findApprovedCandidate([previous], installedIdentity(), {
      vscodiumVersion: '1.127.0',
      codeOssVersion: '1.127.0',
      dbcodeVersion: '1.37.0'
    }),
    undefined
  );
  assert.equal(
    approvedReleaseSet.findApprovedCandidate(history.approved_release_sets, installedIdentity(), {
      vscodiumVersion: '1.126.04524',
      codeOssVersion: '1.126.0',
      dbcodeVersion: '1.36.1'
    }),
    undefined
  );
  assert.equal(
    approvedReleaseSet.findApprovedCandidate(history.approved_release_sets, installedIdentity(), {
      vscodiumVersion: '1.127.0',
      codeOssVersion: '1.127.0',
      dbcodeVersion: '1.37.0'
    })?.id,
    releaseSetId
  );
});

test('history validation rejects unsupported schemas and duplicate identities', () => {
  assert.throws(
    () => approvedReleaseSet.validateApprovedHistory({ schema_version: 99, approved_release_sets: [] }),
    /schema/i
  );
  assert.throws(
    () => approvedReleaseSet.validateApprovedHistory({
      schema_version: 2,
      approved_release_sets: [completeApproval(), completeApproval()]
    }),
    /duplicate/i
  );
});

test('installed identity accepts only official release-note locations', () => {
  const badHost = installedIdentity();
  badHost.host.releaseNotesUrl = 'https://example.com/vscodium';
  assert.throws(() => approvedReleaseSet.validateInstalledReleaseSet(badHost), /release notes/i);

  const badDbcode = installedIdentity();
  badDbcode.dbcode.releaseNotesUrl = 'https://dbcode.io/docs/changelog/1.36.3';
  assert.throws(() => approvedReleaseSet.validateInstalledReleaseSet(badDbcode), /release notes/i);

  const badCodeOss = installedIdentity();
  badCodeOss.host.codeOssReleaseNotesUrl = 'https://github.com/microsoft/vscode/releases/tag/1.125.0';
  assert.throws(() => approvedReleaseSet.validateInstalledReleaseSet(badCodeOss), /release notes/i);
});

test('approval construction binds the candidate, manifest, proof, gate, and attestation', () => {
  const candidate = preparedSet();
  const manifest = {
    schema_version: 6,
    release: {
      release_set_id: releaseSetId,
      source_set_id: sourceSetId,
      validation_issue: '18-deepen-the-approved-release-set-contract'
    },
    source: {
      repository_revision: commit('c'),
      release_lock_sha256: sha('1'),
      shell_patch_revision: sha('6'), overlay_sha256: sha('7'),
      snapshot: {
        schema_version: 1,
        mode: 'immutable-git-commit',
        repository_revision: commit('c'),
        tree_oid: commit('a'),
        snapshot_sha256: sha('8'),
        host_script_sha256: sha('7'),
        release_lock_sha256: sha('1')
      },
      compiled_host: {
        schema_version: 2,
        input_id: `compiled-host-${sha('9')}`,
        app_digest_algorithm: 'sha256-files-modes-links-v1'
      },
      vscodium: { tag: '1.127.0', commit: commit('8') },
      code_oss: { tag: '1.127.0', commit: commit('9') }
    },
    packaging: { status: 'built-and-signed' },
    artifact: { sha256: artifactSha }
  };
  const attestation = {
    schema_version: 1,
    approved_at: '2026-07-23T00:05:00Z',
    release_set_id: releaseSetId,
    candidate_set_sha256: sha('a'),
    candidate_manifest_sha256: sha('d'),
    proof_sha256: sha('4'),
    gate_receipt_sha256: sha('0'),
    confirmation: 'exact-release-set-id',
    automatic_install: false,
    privileged_install: false
  };
  const record = approvedReleaseSet.createApprovedRecord({
    candidateSet: candidate,
    manifest,
    attestation,
    candidateSetSha256: sha('a'),
    manifestSha256: sha('d'),
    attestationSha256: sha('5'),
    proofSha256: sha('4'),
    gateReceiptSha256: sha('0')
  });
  assert.equal(record.id, releaseSetId);
  assert.equal(record.manifest.approval_attestation_sha256, sha('5'));
  assert.equal(record.manifest.source_snapshot_sha256, sha('8'));
  assert.equal(record.manifest.compiled_host_input_id, `compiled-host-${sha('9')}`);
  assert.equal(record.approval.gate_receipt_sha256, sha('0'));
});
