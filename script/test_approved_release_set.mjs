import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync
} from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

import approvedReleaseSet from '../host/extensions/dbcode-wrapper-release-status/approved-release-set.js';

const scriptRoot = dirname(fileURLToPath(import.meta.url));
const contractCli = join(scriptRoot, 'approved_release_set.cjs');
const hostReleaseContract = join(scriptRoot, 'host_release_contract.sh');
const CONTRACT_CLI_TIMEOUT_MS = 30_000;
const sha = character => character.repeat(64);
const commit = character => character.repeat(40);
const sourceSetId = `code-oss-1.127.0-dbcode-1.37.0-source-${sha('a')}`;
const artifactSha = sha('b');
const releaseSetId = `${sourceSetId}-artifact-${artifactSha}`;
const releaseLockTemplate = JSON.parse(
  readFileSync(join(scriptRoot, '..', 'host', 'release-lock.json'), 'utf8')
);

test('Approved Release Set exposes only its maintained interface', () => {
  assert.deepEqual(Object.keys(approvedReleaseSet).sort(), [
    'createPromptFreeApprovedRecord',
    'findApprovedCandidate',
    'promptFreeVerificationChecks',
    'upsertApprovedHistory',
    'validateApprovedHistory',
    'validateApprovedRecord',
    'validateInstalledReleaseSet'
  ]);
});

function promptFreeReleaseSpecification() {
  const releaseLock = structuredClone(releaseLockTemplate);
  releaseLock.release = {
    wrapper_version: '0.2.0',
    release_set_base_id: 'code-oss-1.127.0-dbcode-1.37.0',
    compatibility_status: 'candidate',
    profile_schema_version: 2,
    validation_issue: '18-deepen-the-approved-release-set-contract'
  };
  releaseLock.upstream.vscodium = {
    ...releaseLock.upstream.vscodium,
    tag: '1.127.0',
    commit: commit('8'),
    release_notes_url: 'https://github.com/VSCodium/vscodium/releases/tag/1.127.0'
  };
  releaseLock.upstream.code_oss = {
    ...releaseLock.upstream.code_oss,
    tag: '1.127.0',
    commit: commit('9'),
    release_notes_url: 'https://github.com/microsoft/vscode/releases/tag/1.127.0'
  };
  releaseLock.runtime.code_oss_version = '1.127.0';
  releaseLock.extension.dbcode = {
    ...releaseLock.extension.dbcode,
    version: '1.37.0',
    release_notes_url: 'https://dbcode.io/docs/changelog/1.37.0',
    registry_api_url: 'https://open-vsx.org/api/dbcode/dbcode/1.37.0',
    download_url: 'https://open-vsx.org/api/dbcode/dbcode/1.37.0/file/dbcode.dbcode-1.37.0.vsix',
    signature_url: 'https://open-vsx.org/api/dbcode/dbcode/1.37.0/file/dbcode.dbcode-1.37.0.sigzip',
    sha256_url: 'https://open-vsx.org/api/dbcode/dbcode/1.37.0/file/dbcode.dbcode-1.37.0.sha256',
    sha256: sha('e'),
    signature_archive_sha256: sha('f')
  };
  return releaseLock;
}

function releasePackages(releaseLock) {
  return [
    { ...releaseLock.extension.dbcode, role: 'database-client' },
    ...releaseLock.extension.python_notebooks.packages
  ];
}

function releaseSpecificationRecords(releaseLock) {
  return {
    build: {
      schema_version: 1,
      target: structuredClone(releaseLock.target),
      upstream: structuredClone(releaseLock.upstream),
      toolchain: structuredClone(releaseLock.toolchain),
      runtime: structuredClone(releaseLock.runtime),
      release: structuredClone(releaseLock.release),
      distribution: structuredClone(releaseLock.distribution),
      product: structuredClone(releaseLock.product)
    },
    extensions: {
      schema_version: 1,
      host_code_oss_version: releaseLock.runtime.code_oss_version,
      dbcode: structuredClone(releaseLock.extension.dbcode),
      python_notebooks: structuredClone(releaseLock.extension.python_notebooks),
      packages: releasePackages(releaseLock)
    },
    profile: {
      schema_version: 1,
      target: structuredClone(releaseLock.target),
      profile_schema_version: releaseLock.release.profile_schema_version,
      product: structuredClone(releaseLock.product)
    }
  };
}

function promptFreeAcceptanceValidation() {
  return {
    schema_version: 1,
    status: 'validated',
    acceptance_schema_version: 3,
    acceptance_sha256: sha('4'),
    build_manifest_sha256: sha('d'),
    release_lock_sha256: sha('1'),
    release_set_id: releaseSetId
  };
}

function manifestRuntimeExtensions(releaseLock) {
  return releasePackages(releaseLock).map(packageRecord => ({
    role: packageRecord.role,
    id: packageRecord.id,
    version: packageRecord.version,
    target_platform: packageRecord.target_platform,
    verified_publisher: packageRecord.verified_publisher,
    vsix_sha256: packageRecord.sha256,
    signature_archive_sha256: packageRecord.signature_archive_sha256,
    public_key_id: packageRecord.public_key_id,
    public_key_sha256: packageRecord.public_key_sha256,
    install_location: 'external-private-profile',
    required: true
  }));
}

function externalRuntimePackages(releaseLock) {
  return releasePackages(releaseLock).map(packageRecord => ({
    id: packageRecord.id,
    version: packageRecord.version,
    target_platform: packageRecord.target_platform,
    vsix_sha256: packageRecord.sha256,
    signature_archive_sha256: packageRecord.signature_archive_sha256,
    public_key_id: packageRecord.public_key_id,
    public_key_sha256: packageRecord.public_key_sha256
  }));
}

function candidateManifest(releaseLock = promptFreeReleaseSpecification()) {
  return {
    schema_version: 6,
    release: {
      wrapper_version: releaseLock.release.wrapper_version,
      release_set_id: releaseSetId,
      source_set_id: sourceSetId,
      compatibility_status: releaseLock.release.compatibility_status,
      validation_issue: '18-deepen-the-approved-release-set-contract'
    },
    source: {
      repository_revision: commit('c'),
      release_lock_sha256: sha('1'),
      shell_patch_revision: sha('6'),
      overlay_sha256: sha('7'),
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
      vscodium: {
        tag: releaseLock.upstream.vscodium.tag,
        commit: releaseLock.upstream.vscodium.commit
      },
      code_oss: {
        tag: releaseLock.upstream.code_oss.tag,
        commit: releaseLock.upstream.code_oss.commit
      }
    },
    runtime: {
      code_oss: releaseLock.runtime.code_oss_version,
      host: releaseLock.upstream.vscodium.tag,
      electron: releaseLock.runtime.electron_version
    },
    runtime_extensions: manifestRuntimeExtensions(releaseLock),
    packaging: {
      status: 'built-and-signed',
      installed_kib: 1024
    },
    artifact: {
      app_name: releaseLock.product.app_name,
      application_name: releaseLock.product.application_name,
      platform: 'darwin',
      architecture: 'arm64',
      bundle_identifier: releaseLock.product.bundle_identifier,
      signature_kind: 'certificate',
      signature_requirement: 'designated => fixture',
      signature_scope: 'current-user-private-use',
      signing_certificate_common_name:
        releaseLock.product.signing.identity_common_name,
      signing_certificate_sha1: commit('d'),
      signing_certificate_sha256: sha('c'),
      sha256: artifactSha
    }
  };
}

function promptFreeCompatibility(releaseLock, manifest) {
  return {
    schema_version: 1,
    scope: 'public-host-release',
    transfer: {
      channel: 'github-published-release',
      draft_required: false,
      public_download: true,
      owned_devices_only: false
    },
    source: {
      tag: 'v0.2.0',
      repository_revision: manifest.source.repository_revision,
      tree_oid: manifest.source.snapshot.tree_oid,
      snapshot_sha256: manifest.source.snapshot.snapshot_sha256,
      release_lock_sha256: sha('1'),
      compiled_host_input_id: manifest.source.compiled_host.input_id
    },
    release: {
      wrapper_version: releaseLock.release.wrapper_version,
      release_set_id: releaseSetId,
      source_set_id: sourceSetId,
      code_oss_version: releaseLock.runtime.code_oss_version,
      vscodium_version: releaseLock.upstream.vscodium.tag,
      dbcode_version: releaseLock.extension.dbcode.version,
      architecture: 'arm64',
      minimum_macos: '12.0'
    },
    app: {
      filename: 'DBCode Wrapper.app',
      sha256: artifactSha,
      bundle_identifier: releaseLock.product.bundle_identifier,
      signature: {
        kind: 'current-user-self-signed-certificate',
        designated_requirement: manifest.artifact.signature_requirement,
        developer_id: false,
        notarized: false
      }
    },
    disk_image: {
      filename: 'DBCode-Wrapper-fixture.dmg',
      sha256: sha('b'),
      size_bytes: 1024,
      read_only: true
    },
    external_runtime: {
      bundled: false,
      setup: 'focused-pinned-official-sources',
      source: 'official-open-vsx',
      packages: externalRuntimePackages(releaseLock)
    },
    evidence: {
      build_manifest_sha256: sha('d'),
      release_lock_sha256: sha('1'),
      final_acceptance_sha256: sha('4'),
      final_acceptance_status: 'passed'
    },
    claims: {
      unofficial_wrapper: true,
      dbcode_included: false,
      licence_or_profile_included: false,
      public_application_release: true,
      apple_identified_or_notarized: false
    }
  };
}

function promptFreeAcceptance(releaseLock, manifest) {
  return {
    schema_version: 3,
    status: 'passed',
    completed_at_utc: '2026-07-27T16:00:00Z',
    scope: 'current-user-private-use',
    source: {
      repository_revision: manifest.source.repository_revision,
      tree_oid: manifest.source.snapshot.tree_oid,
      snapshot_sha256: manifest.source.snapshot.snapshot_sha256,
      compiled_host_input_id: manifest.source.compiled_host.input_id
    },
    release: {
      release_set_id: releaseSetId,
      app_name: releaseLock.product.app_name,
      bundle_identifier: releaseLock.product.bundle_identifier,
      platform: 'darwin',
      architecture: 'arm64',
      app_sha256: artifactSha,
      installed_size_kib: manifest.packaging.installed_kib,
      code_oss_version: releaseLock.runtime.code_oss_version,
      dbcode: {
        id: releaseLock.extension.dbcode.id,
        version: releaseLock.extension.dbcode.version,
        vsix_sha256: releaseLock.extension.dbcode.sha256
      },
      installed_extensions: releasePackages(releaseLock)
        .map(entry => `${entry.id}@${entry.version}`)
        .sort()
    },
    signing: {
      kind: 'certificate',
      scope: 'current-user-private-use',
      designated_requirement: manifest.artifact.signature_requirement,
      certificate: {
        sha1: manifest.artifact.signing_certificate_sha1,
        sha256: manifest.artifact.signing_certificate_sha256
      }
    },
    automation: {
      profile_name: 'qa',
      persistent_profile: true,
      person_controlled_actions: 'not-invoked',
      kernel_started: false,
      sql_executed: false,
      model_called: false,
      secret_entered: false
    },
    gates: {
      development_contracts: 'passed',
      strict_signature_and_manifest: 'passed',
      signed_app_one_profile_launch: 'passed',
      dbcode_focused_rendered_interface: 'passed',
      exact_external_extension_inventory: 'passed',
      prompt_free_automation: 'passed',
      bundle_unchanged_after_use: 'passed'
    },
    gate_execution: {
      source_snapshot_sha256: manifest.source.snapshot.snapshot_sha256,
      release_set_id: releaseSetId,
      app_sha256: artifactSha,
      build_manifest_sha256: sha('d'),
      development_runner: 'script/check_development.sh',
      static_smoke_runner: 'script/smoke_host.sh'
    },
    rendered_evidence: {
      check_count: 13,
      known_warning_count: 1,
      unexpected_error_count: 0
    },
    evidence_sha256: {
      build_manifest: sha('d'),
      release_lock: sha('1'),
      rendered_report: sha('2'),
      development_log: sha('3'),
      smoke_log: sha('6')
    },
    failures: [],
    waivers: [],
    private_use_risks: ['one', 'two', 'three', 'four', 'five'],
    distribution_claims: {
      developer_id: false,
      notarized: false,
      public_distribution_ready: false,
      intel_support: false,
      multi_user_support: false,
      official_dbcode_endorsement: false
    }
  };
}

function promptFreeVerification(compatibility) {
  return {
    schema_version: 1,
    status: 'passed',
    release_set_id: releaseSetId,
    source: {
      tag: compatibility.source.tag,
      repository_revision: compatibility.source.repository_revision,
      tree_oid: compatibility.source.tree_oid,
      snapshot_sha256: compatibility.source.snapshot_sha256,
      compiled_host_input_id: compatibility.source.compiled_host_input_id
    },
    disk_image: {
      filename: compatibility.disk_image.filename,
      sha256: compatibility.disk_image.sha256
    },
    evidence: {
      build_manifest_sha256: sha('d'),
      release_lock_sha256: sha('1'),
      final_acceptance_sha256: sha('4'),
      checksum_sha256: sha('2'),
      compatibility_manifest_sha256: sha('a'),
      install_and_rollback_sha256: sha('3')
    },
    checks: Object.fromEntries(
      approvedReleaseSet.promptFreeVerificationChecks().map(name => [name, 'passed'])
    ),
    failures: []
  };
}

function promptFreeAttestation(sourceTag) {
  return {
    schema_version: 2,
    approved_at: '2026-07-27T16:00:00Z',
    release_set_id: releaseSetId,
    source_tag: sourceTag,
    compatibility_manifest_sha256: sha('a'),
    candidate_manifest_sha256: sha('d'),
    release_lock_sha256: sha('1'),
    acceptance_sha256: sha('4'),
    verification_sha256: sha('0'),
    confirmation: 'exact-release-set-id',
    approval_mode: 'prompt-free-public-host-release',
    automatic_install: false,
    privileged_install: false,
    production_profile_written: false,
    installed_app_changed: false
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

function fileSha256(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

function runContractCli(command, path) {
  const result = spawnSync(process.execPath, [contractCli, command, path], {
    encoding: 'utf8',
    timeout: CONTRACT_CLI_TIMEOUT_MS,
    killSignal: 'SIGTERM'
  });
  if (result.error) {
    if (result.error.code === 'ETIMEDOUT') {
      throw new Error(
        `${command} timed out after ${CONTRACT_CLI_TIMEOUT_MS} ms.`
      );
    }
    throw result.error;
  }
  if (result.signal) {
    throw new Error(`${command} stopped after signal ${result.signal}.`);
  }
  if (!Number.isInteger(result.status)) {
    throw new Error(`${command} did not return an exit status.`);
  }
  return result;
}

function cliAccepts(command, path) {
  return runContractCli(command, path).status === 0;
}

function cliFailure(command, path) {
  const result = runContractCli(command, path);
  assert.notEqual(result.status, 0, `${command} unexpectedly accepted ${path}`);
  return result.stderr.trim();
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

test('command adapter rejects missing, symlinked, and malformed JSON before release validation', t => {
  const root = mkdtempSync(join(tmpdir(), 'dbcode-approved-release-files-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const target = join(root, 'target.json');
  const linked = join(root, 'linked.json');
  const malformed = join(root, 'malformed.json');
  writeJson(target, completeApproval());
  symlinkSync(target, linked);
  writeFileSync(malformed, '{not-json}\n');

  assert.equal(
    cliFailure('validate-approved', join(root, 'missing.json')),
    'Approved Release Set record is missing.'
  );
  assert.equal(
    cliFailure('validate-approved', linked),
    'Approved Release Set record is missing or symlinked.'
  );
  assert.equal(
    cliFailure('validate-approved', malformed),
    'Approved Release Set record is not valid JSON.'
  );
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

test('prompt-free approval binds accepted package evidence without installing it', t => {
  const releaseLock = promptFreeReleaseSpecification();
  const manifest = candidateManifest(releaseLock);
  const compatibility = promptFreeCompatibility(releaseLock, manifest);
  const acceptance = promptFreeAcceptance(releaseLock, manifest);
  const verification = promptFreeVerification(compatibility);
  const attestation = promptFreeAttestation(compatibility.source.tag);
  const cliVerificationChecks = JSON.parse(
    execFileSync(process.execPath, [
      contractCli,
      'prompt-free-verification-checks'
    ], { encoding: 'utf8' })
  );
  assert.deepEqual(cliVerificationChecks, verification.checks);

  const inputs = {
    compatibility: { value: compatibility, digest: sha('a') },
    manifest: { value: manifest, digest: sha('d') },
    releaseLock: { value: releaseLock, digest: sha('1') },
    acceptance: { value: acceptance, digest: sha('4') },
    verification: { value: verification, digest: sha('0') },
    attestation: { value: attestation, digest: sha('5') },
    releaseSpecification: releaseSpecificationRecords(releaseLock),
    acceptanceValidation: promptFreeAcceptanceValidation()
  };
  const record = approvedReleaseSet.createPromptFreeApprovedRecord(inputs);

  assert.equal(record.id, releaseSetId);
  assert.equal(record.profile.schema_version, 2);
  assert.equal(record.approval.mode, 'prompt-free-public-host-release');
  assert.equal(record.approval.source_tag, 'v0.2.0');
  assert.equal(record.approval.proof_sha256, sha('4'));
  assert.equal(record.approval.gate_receipt_sha256, sha('0'));
  assert.equal(record.approval.production_profile_written, false);
  assert.equal(record.approval.installed_app_changed, false);

  const mismatchedHost = structuredClone(compatibility);
  mismatchedHost.release.code_oss_version = '9.9.9';
  assert.throws(
    () => approvedReleaseSet.createPromptFreeApprovedRecord({
      ...inputs,
      compatibility: { ...inputs.compatibility, value: mismatchedHost }
    }),
    /exact candidate release set/i
  );

  const mismatchedDbcode = structuredClone(compatibility);
  mismatchedDbcode.release.dbcode_version = '9.9.9';
  assert.throws(
    () => approvedReleaseSet.createPromptFreeApprovedRecord({
      ...inputs,
      compatibility: { ...inputs.compatibility, value: mismatchedDbcode }
    }),
    /candidate release set|Release Specification/i
  );

  const writablePackage = structuredClone(compatibility);
  writablePackage.disk_image.read_only = false;
  assert.throws(
    () => approvedReleaseSet.createPromptFreeApprovedRecord({
      ...inputs,
      compatibility: { ...inputs.compatibility, value: writablePackage }
    }),
    /disk-image/i
  );

  const staleAcceptance = {
    ...promptFreeAcceptanceValidation(),
    acceptance_sha256: sha('f')
  };
  assert.throws(
    () => approvedReleaseSet.createPromptFreeApprovedRecord({
      ...inputs,
      acceptanceValidation: staleAcceptance
    }),
    /validated prompt-free acceptance/i
  );

  const incompleteVerification = structuredClone(verification);
  delete incompleteVerification.checks.private_data_absent;
  assert.throws(
    () => approvedReleaseSet.createPromptFreeApprovedRecord({
      ...inputs,
      verification: { ...inputs.verification, value: incompleteVerification }
    }),
    /verification/i
  );

  const installingAttestation = {
    ...attestation,
    installed_app_changed: true
  };
  assert.throws(
    () => approvedReleaseSet.createPromptFreeApprovedRecord({
      ...inputs,
      attestation: { ...inputs.attestation, value: installingAttestation }
    }),
    /attestation/i
  );

  const root = mkdtempSync(join(tmpdir(), 'dbcode-prompt-free-approval-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const lockPath = join(root, 'release-lock.json');
  const manifestPath = join(root, 'build-manifest.json');
  const acceptancePath = join(root, 'acceptance.json');
  const compatibilityPath = join(root, 'compatibility.json');
  const verificationPath = join(root, 'verification.json');
  const attestationPath = join(root, 'attestation.json');
  const historyPath = join(root, 'base-history.json');
  const recordPath = join(root, 'approved-release-set.json');
  const outputHistoryPath = join(root, 'approved-release-sets.json');

  writeJson(lockPath, releaseLock);
  const cliLockSha = fileSha256(lockPath);
  const cliManifest = structuredClone(manifest);
  cliManifest.source.release_lock_sha256 = cliLockSha;
  cliManifest.source.snapshot.release_lock_sha256 = cliLockSha;
  writeJson(manifestPath, cliManifest);
  const cliManifestSha = fileSha256(manifestPath);
  const cliAcceptance = structuredClone(acceptance);
  cliAcceptance.gate_execution.build_manifest_sha256 = cliManifestSha;
  cliAcceptance.evidence_sha256.build_manifest = cliManifestSha;
  cliAcceptance.evidence_sha256.release_lock = cliLockSha;
  writeJson(acceptancePath, cliAcceptance);
  const cliAcceptanceSha = fileSha256(acceptancePath);
  const cliCompatibility = structuredClone(compatibility);
  cliCompatibility.source.release_lock_sha256 = cliLockSha;
  cliCompatibility.evidence.build_manifest_sha256 = cliManifestSha;
  cliCompatibility.evidence.release_lock_sha256 = cliLockSha;
  cliCompatibility.evidence.final_acceptance_sha256 = cliAcceptanceSha;
  writeJson(compatibilityPath, cliCompatibility);
  const cliCompatibilitySha = fileSha256(compatibilityPath);
  const cliVerification = structuredClone(verification);
  cliVerification.evidence.build_manifest_sha256 = cliManifestSha;
  cliVerification.evidence.release_lock_sha256 = cliLockSha;
  cliVerification.evidence.final_acceptance_sha256 = cliAcceptanceSha;
  cliVerification.evidence.compatibility_manifest_sha256 = cliCompatibilitySha;
  writeJson(verificationPath, cliVerification);
  const cliVerificationSha = fileSha256(verificationPath);
  const cliAttestation = {
    ...attestation,
    compatibility_manifest_sha256: cliCompatibilitySha,
    candidate_manifest_sha256: cliManifestSha,
    release_lock_sha256: cliLockSha,
    acceptance_sha256: cliAcceptanceSha,
    verification_sha256: cliVerificationSha
  };
  writeJson(attestationPath, cliAttestation);
  writeJson(historyPath, { schema_version: 2, approved_release_sets: [] });

  const readAcceptanceRecord = (manifestInput, lockInput, acceptanceInput, options = {}) =>
    JSON.parse(execFileSync('/bin/bash', [
      hostReleaseContract,
      'prompt-free-acceptance-record',
      manifestInput,
      lockInput,
      acceptanceInput
    ], { encoding: 'utf8', ...options }));
  const absoluteAcceptanceRecord = readAcceptanceRecord(
    manifestPath,
    lockPath,
    acceptancePath
  );
  assert.equal(absoluteAcceptanceRecord.status, 'validated');
  assert.equal(absoluteAcceptanceRecord.acceptance_sha256, cliAcceptanceSha);
  assert.deepEqual(
    readAcceptanceRecord(
      'build-manifest.json',
      'release-lock.json',
      'acceptance.json',
      { cwd: root }
    ),
    absoluteAcceptanceRecord
  );

  const spacedInputRoot = join(root, 'input records with spaces');
  const spacedManifestPath = join(spacedInputRoot, 'build manifest.json');
  const spacedLockPath = join(spacedInputRoot, 'release lock.json');
  const spacedAcceptancePath = join(spacedInputRoot, 'acceptance report.json');
  writeJson(spacedManifestPath, cliManifest);
  writeJson(spacedLockPath, releaseLock);
  writeJson(spacedAcceptancePath, cliAcceptance);
  assert.deepEqual(
    readAcceptanceRecord(
      spacedManifestPath,
      spacedLockPath,
      spacedAcceptancePath
    ),
    absoluteAcceptanceRecord
  );

  const cliArguments = [
    contractCli,
    'write-prompt-free-approval',
    compatibilityPath,
    manifestPath,
    lockPath,
    attestationPath,
    acceptancePath,
    verificationPath,
    historyPath,
    recordPath,
    outputHistoryPath
  ];
  const incompleteAcceptancePath = join(root, 'incomplete-acceptance.json');
  const incompleteAcceptance = structuredClone(cliAcceptance);
  delete incompleteAcceptance.gates;
  writeJson(incompleteAcceptancePath, incompleteAcceptance);
  assert.throws(
    () => execFileSync(
      process.execPath,
      cliArguments.map(value =>
        value === acceptancePath ? incompleteAcceptancePath : value
      ),
      { stdio: 'pipe' }
    ),
    /Command failed/
  );

  const incompleteLockPath = join(root, 'incomplete-release-lock.json');
  const incompleteReleaseLock = structuredClone(releaseLock);
  delete incompleteReleaseLock.product.signing;
  writeJson(incompleteLockPath, incompleteReleaseLock);
  assert.throws(
    () => execFileSync(
      process.execPath,
      cliArguments.map(value => value === lockPath ? incompleteLockPath : value),
      { stdio: 'pipe' }
    ),
    /Command failed/
  );

  execFileSync(process.execPath, cliArguments);

  const writtenRecord = JSON.parse(readFileSync(recordPath, 'utf8'));
  const writtenHistory = JSON.parse(readFileSync(outputHistoryPath, 'utf8'));
  assert.equal(writtenRecord.id, releaseSetId);
  assert.equal(writtenRecord.approval.mode, 'prompt-free-public-host-release');
  assert.deepEqual(writtenHistory.approved_release_sets, [writtenRecord]);

  const validateRecordedApprovalArguments = [
    contractCli,
    'validate-recorded-approval',
    manifestPath,
    lockPath,
    attestationPath,
    recordPath,
    outputHistoryPath,
    compatibility.source.tag
  ];
  execFileSync(process.execPath, validateRecordedApprovalArguments);
  const mismatchedRecordedApprovalPath = join(root, 'mismatched-recorded-approval.json');
  writeJson(mismatchedRecordedApprovalPath, {
    ...writtenRecord,
    source_commit: 'f'.repeat(40)
  });
  assert.throws(
    () => execFileSync(
      process.execPath,
      validateRecordedApprovalArguments.map(value =>
        value === recordPath ? mismatchedRecordedApprovalPath : value
      ),
      { stdio: 'pipe' }
    ),
    /Command failed/
  );
  for (const [name, approval] of [
    ['mode', {
      ...writtenRecord.approval,
      mode: 'prompt-free-private-release'
    }],
    ['timestamp', {
      ...writtenRecord.approval,
      approved_at: '2026-08-01T00:00:00Z'
    }]
  ]) {
    const mismatchedRecord = { ...writtenRecord, approval };
    const mismatchedRecordPath = join(root, `mismatched-${name}-record.json`);
    const mismatchedHistoryPath = join(root, `mismatched-${name}-history.json`);
    writeJson(mismatchedRecordPath, mismatchedRecord);
    writeJson(mismatchedHistoryPath, {
      ...writtenHistory,
      approved_release_sets: [mismatchedRecord]
    });
    assert.throws(
      () => execFileSync(
        process.execPath,
        validateRecordedApprovalArguments.map(value => {
          if (value === recordPath) return mismatchedRecordPath;
          if (value === outputHistoryPath) return mismatchedHistoryPath;
          return value;
        }),
        { stdio: 'pipe' }
      ),
      /Command failed/
    );
  }

  const trackedHistoryPath = join(root, 'tracked-approved-release-history.json');
  const staleCandidatePath = join(root, 'stale-approved-release-history.json');
  writeJson(trackedHistoryPath, { schema_version: 2, approved_release_sets: [] });
  writeJson(staleCandidatePath, { schema_version: 2, approved_release_sets: [] });
  const recordHistoryArguments = [
    contractCli,
    'record-approved-history',
    trackedHistoryPath,
    recordPath,
    outputHistoryPath,
    trackedHistoryPath
  ];
  execFileSync(process.execPath, recordHistoryArguments);
  assert.deepEqual(
    JSON.parse(readFileSync(trackedHistoryPath, 'utf8')),
    writtenHistory
  );
  execFileSync(process.execPath, recordHistoryArguments);
  assert.throws(
    () => execFileSync(
      process.execPath,
      recordHistoryArguments.map(value =>
        value === outputHistoryPath ? staleCandidatePath : value
      ),
      { stdio: 'pipe' }
    ),
    /Command failed/
  );
});
