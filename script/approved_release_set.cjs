#!/usr/bin/env node

'use strict';

const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const contract = require('../host/extensions/dbcode-wrapper-release-status/approved-release-set');
const releaseSpecificationScript = path.join(__dirname, 'release_specification.sh');
const privateReleaseContractScript = path.join(__dirname, 'private_release_contract.sh');
const VALIDATOR_TIMEOUT_MS = 30_000;

function usage() {
  console.error(`Usage:
  ./script/approved_release_set.cjs validate-approved FILE
  ./script/approved_release_set.cjs validate-history FILE
  ./script/approved_release_set.cjs history-record HISTORY ID
  ./script/approved_release_set.cjs prompt-free-verification-checks
  ./script/approved_release_set.cjs write-prompt-free-approval COMPATIBILITY MANIFEST RELEASE_LOCK \
    ATTESTATION ACCEPTANCE VERIFICATION BASE_HISTORY RECORD OUTPUT_HISTORY`);
  process.exit(2);
}

function fileSha256(filePath, label) {
  const value = contract.readPlainJsonFile(filePath, label);
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

function writeJsonAtomically(filePath, value) {
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
  fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600, flag: 'wx' });
  fs.renameSync(temporary, filePath);
}

function main(argv) {
  const [command, ...args] = argv;
  switch (command) {
    case 'validate-approved': {
      if (args.length !== 1) usage();
      const record = contract.readPlainJsonFile(args[0], 'Approved Release Set record');
      contract.validateApprovedRecord(record, { allowLegacy: false });
      break;
    }
    case 'validate-history': {
      if (args.length !== 1) usage();
      const history = contract.readPlainJsonFile(args[0], 'Approved Release Set history');
      contract.validateApprovedHistory(history);
      break;
    }
    case 'history-record': {
      if (args.length !== 2) usage();
      const history = contract.readPlainJsonFile(args[0], 'Approved Release Set history');
      contract.validateApprovedHistory(history);
      const record = history.approved_release_sets.find(entry => entry.id === args[1]);
      if (!record) process.exit(3);
      process.stdout.write(`${JSON.stringify(record)}\n`);
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
        'Private-release compatibility manifest'
      );
      const manifest = fileSha256(manifestPath, 'Candidate build manifest');
      const releaseLock = fileSha256(releaseLockPath, 'Candidate Release Specification');
      const attestation = fileSha256(attestationPath, 'Prompt-free approval attestation');
      const acceptance = fileSha256(acceptancePath, 'Prompt-free acceptance report');
      const verification = fileSha256(
        verificationPath,
        'Private-release verification receipt'
      );
      const baseHistory = contract.readPlainJsonFile(
        baseHistoryPath,
        'Base Approved Release Set history'
      );
      const releaseSpecification = validatedReleaseSpecification(releaseLockPath);
      const acceptanceValidation = readValidatedJson(
        privateReleaseContractScript,
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
