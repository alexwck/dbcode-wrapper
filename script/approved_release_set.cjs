#!/usr/bin/env node

'use strict';

const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const { isDeepStrictEqual } = require('node:util');
const contract = require('../host/extensions/dbcode-wrapper-release-status/approved-release-set');
const releaseSpecificationScript = path.join(__dirname, 'release_specification.sh');
const hostReleaseContractScript = path.join(__dirname, 'host_release_contract.sh');
const VALIDATOR_TIMEOUT_MS = 30_000;

function usage() {
  console.error(`Usage:
  ./script/approved_release_set.cjs validate-approved FILE
  ./script/approved_release_set.cjs validate-history FILE
  ./script/approved_release_set.cjs validate-recorded-approval MANIFEST RELEASE_LOCK \
    ATTESTATION RECORD HISTORY SOURCE_TAG
  ./script/approved_release_set.cjs history-record HISTORY ID
  ./script/approved_release_set.cjs record-approved-history CURRENT RECORD CANDIDATE OUTPUT
  ./script/approved_release_set.cjs prompt-free-verification-checks
  ./script/approved_release_set.cjs write-prompt-free-approval COMPATIBILITY MANIFEST RELEASE_LOCK \
    ATTESTATION ACCEPTANCE VERIFICATION BASE_HISTORY RECORD OUTPUT_HISTORY`);
  process.exit(2);
}

function readPlainJsonFile(filePath, label) {
  let fileInfo;
  try {
    fileInfo = fs.lstatSync(filePath);
  } catch {
    throw new Error(`${label} is missing.`);
  }
  if (!fileInfo.isFile() || fileInfo.isSymbolicLink()) {
    throw new Error(`${label} is missing or symlinked.`);
  }
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    throw new Error(`${label} is not valid JSON.`);
  }
}

function fileSha256(filePath, label) {
  const value = readPlainJsonFile(filePath, label);
  const digest = crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
  return { value, digest };
}

function readValidatedJson(scriptPath, args, label) {
  const result = spawnSync('/bin/bash', [scriptPath, ...args], {
    encoding: 'utf8',
    maxBuffer: 4 * 1024 * 1024,
    timeout: VALIDATOR_TIMEOUT_MS,
    killSignal: 'SIGTERM'
  });
  if (result.error) {
    if (result.error.code === 'ETIMEDOUT') {
      throw new Error(`${label} validation timed out after ${VALIDATOR_TIMEOUT_MS} ms.`);
    }
    throw result.error;
  }
  if (result.signal) {
    throw new Error(`${label} validator stopped after signal ${result.signal}.`);
  }
  if (result.status !== 0) {
    const reason = result.stderr.trim();
    throw new Error(reason || `${label} validation failed.`);
  }
  try {
    return JSON.parse(result.stdout);
  } catch {
    throw new Error(`${label} validator returned invalid JSON.`);
  }
}

function validatedReleaseSpecification(releaseLockPath) {
  return {
    build: readValidatedJson(
      releaseSpecificationScript,
      ['build', releaseLockPath],
      'Release Specification build record'
    ),
    extensions: readValidatedJson(
      releaseSpecificationScript,
      ['extensions', releaseLockPath],
      'Release Specification extension record'
    ),
    profile: readValidatedJson(
      releaseSpecificationScript,
      ['profile', releaseLockPath],
      'Release Specification profile record'
    )
  };
}

function writeJsonAtomically(filePath, value, mode = 0o600) {
  const parent = path.dirname(filePath);
  const name = path.basename(filePath);
  fs.mkdirSync(parent, { recursive: true, mode: 0o700 });
  let existing;
  try {
    existing = fs.lstatSync(filePath);
  } catch {
    existing = undefined;
  }
  if (existing?.isSymbolicLink()) {
    throw new Error(`Refusing a symlinked JSON output: ${filePath}`);
  }
  const temporary = path.join(parent, `.${name}.${process.pid}.tmp`);
  fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode, flag: 'wx' });
  fs.renameSync(temporary, filePath);
}

function validateRecordedApproval({
  manifestPath,
  releaseLockPath,
  attestationPath,
  recordPath,
  historyPath,
  sourceTag
}) {
  const manifest = fileSha256(manifestPath, 'Candidate build manifest');
  const releaseLock = fileSha256(releaseLockPath, 'Candidate Release Specification');
  const attestation = fileSha256(
    attestationPath,
    'Prompt-free approval attestation'
  );
  const record = readPlainJsonFile(
    recordPath,
    'Approved Release Set record'
  );
  const history = readPlainJsonFile(
    historyPath,
    'Candidate Approved Release Set history'
  );
  contract.validateApprovedRecord(record, { allowLegacy: false });
  contract.validateApprovedHistory(history);

  const releaseSetId = manifest.value.release?.release_set_id;
  const sourceCommit = manifest.value.source?.snapshot?.repository_revision;
  const exactHistoryRecords = history.approved_release_sets.filter(
    entry => entry.id === releaseSetId
  );
  if (
    attestation.value.schema_version !== 2 ||
    attestation.value.release_set_id !== releaseSetId ||
    attestation.value.source_tag !== sourceTag ||
    attestation.value.candidate_manifest_sha256 !== manifest.digest ||
    attestation.value.release_lock_sha256 !== releaseLock.digest ||
    attestation.value.confirmation !== 'exact-release-set-id' ||
    attestation.value.approval_mode !== 'prompt-free-public-host-release' ||
    attestation.value.automatic_install !== false ||
    attestation.value.privileged_install !== false ||
    attestation.value.production_profile_written !== false ||
    attestation.value.installed_app_changed !== false ||
    record.id !== releaseSetId ||
    record.source_commit !== sourceCommit ||
    record.manifest.build_manifest_sha256 !== manifest.digest ||
    record.manifest.candidate_manifest_sha256 !== manifest.digest ||
    record.manifest.approval_attestation_sha256 !== attestation.digest ||
    record.approval.approved_at !== attestation.value.approved_at ||
    record.approval.validation_issue !== manifest.value.release?.validation_issue ||
    record.approval.mode !== attestation.value.approval_mode ||
    record.approval.source_tag !== sourceTag ||
    record.approval.compatibility_manifest_sha256 !==
      attestation.value.compatibility_manifest_sha256 ||
    record.approval.release_lock_sha256 !== releaseLock.digest ||
    record.approval.proof_sha256 !== attestation.value.acceptance_sha256 ||
    record.approval.gate_receipt_sha256 !== attestation.value.verification_sha256 ||
    record.approval.production_profile_written !==
      attestation.value.production_profile_written ||
    record.approval.installed_app_changed !==
      attestation.value.installed_app_changed ||
    exactHistoryRecords.length !== 1 ||
    !isDeepStrictEqual(exactHistoryRecords[0], record)
  ) {
    throw new Error(
      'The recorded approval does not bind the exact manifest, release lock, tag, and approved history.'
    );
  }
}

function main(argv) {
  const [command, ...args] = argv;
  switch (command) {
    case 'validate-approved': {
      if (args.length !== 1) usage();
      const record = readPlainJsonFile(args[0], 'Approved Release Set record');
      contract.validateApprovedRecord(record, { allowLegacy: false });
      break;
    }
    case 'validate-history': {
      if (args.length !== 1) usage();
      const history = readPlainJsonFile(args[0], 'Approved Release Set history');
      contract.validateApprovedHistory(history);
      break;
    }
    case 'validate-recorded-approval': {
      if (args.length !== 6) usage();
      validateRecordedApproval({
        manifestPath: args[0],
        releaseLockPath: args[1],
        attestationPath: args[2],
        recordPath: args[3],
        historyPath: args[4],
        sourceTag: args[5]
      });
      break;
    }
    case 'history-record': {
      if (args.length !== 2) usage();
      const history = readPlainJsonFile(args[0], 'Approved Release Set history');
      contract.validateApprovedHistory(history);
      const record = history.approved_release_sets.find(entry => entry.id === args[1]);
      if (!record) process.exit(3);
      process.stdout.write(`${JSON.stringify(record)}\n`);
      break;
    }
    case 'record-approved-history': {
      if (args.length !== 4) usage();
      const [currentPath, recordPath, candidatePath, outputPath] = args;
      const current = readPlainJsonFile(
        currentPath,
        'Current Approved Release Set history'
      );
      const record = readPlainJsonFile(
        recordPath,
        'New Approved Release Set record'
      );
      const candidate = readPlainJsonFile(
        candidatePath,
        'Candidate Approved Release Set history'
      );
      contract.validateApprovedHistory(current);
      contract.validateApprovedRecord(record, { allowLegacy: false });
      contract.validateApprovedHistory(candidate);

      const existing = current.approved_release_sets.find(entry => entry.id === record.id);
      if (existing) {
        if (!isDeepStrictEqual(existing, record) || !isDeepStrictEqual(current, candidate)) {
          throw new Error(
            'The recorded approval differs from the exact current Approved Release Set history.'
          );
        }
      } else {
        const expected = contract.upsertApprovedHistory(current, record);
        if (!isDeepStrictEqual(expected, candidate)) {
          throw new Error(
            'The generated approval is not exactly one safe addition to the tracked history.'
          );
        }
      }

      if (
        path.resolve(outputPath) !== path.resolve(currentPath) ||
        !isDeepStrictEqual(current, candidate)
      ) {
        writeJsonAtomically(outputPath, candidate, 0o644);
      }
      break;
    }
    case 'prompt-free-verification-checks': {
      if (args.length !== 0) usage();
      const checks = Object.fromEntries(
        contract.promptFreeVerificationChecks().map(name => [name, 'passed'])
      );
      process.stdout.write(`${JSON.stringify(checks)}\n`);
      break;
    }
    case 'write-prompt-free-approval': {
      if (args.length !== 9) usage();
      const [
        compatibilityPath,
        manifestPath,
        releaseLockPath,
        attestationPath,
        acceptancePath,
        verificationPath,
        baseHistoryPath,
        recordPath,
        outputHistoryPath
      ] = args;
      const compatibility = fileSha256(
        compatibilityPath,
        'Host-release compatibility manifest'
      );
      const manifest = fileSha256(manifestPath, 'Candidate build manifest');
      const releaseLock = fileSha256(releaseLockPath, 'Candidate Release Specification');
      const attestation = fileSha256(attestationPath, 'Prompt-free approval attestation');
      const acceptance = fileSha256(acceptancePath, 'Prompt-free acceptance report');
      const verification = fileSha256(
        verificationPath,
        'Host-release verification receipt'
      );
      const baseHistory = readPlainJsonFile(
        baseHistoryPath,
        'Base Approved Release Set history'
      );
      const releaseSpecification = validatedReleaseSpecification(releaseLockPath);
      const acceptanceValidation = readValidatedJson(
        hostReleaseContractScript,
        [
          'prompt-free-acceptance-record',
          manifestPath,
          releaseLockPath,
          acceptancePath
        ],
        'Prompt-free acceptance report'
      );
      const record = contract.createPromptFreeApprovedRecord({
        compatibility,
        manifest,
        releaseLock,
        acceptance,
        verification,
        attestation,
        releaseSpecification,
        acceptanceValidation
      });
      const nextHistory = contract.upsertApprovedHistory(baseHistory, record);
      writeJsonAtomically(recordPath, record);
      writeJsonAtomically(outputHistoryPath, nextHistory);
      console.log(recordPath);
      break;
    }
    default:
      usage();
  }
}

try {
  main(process.argv.slice(2));
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
