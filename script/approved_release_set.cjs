#!/usr/bin/env node

'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const contract = require('../host/extensions/dbcode-wrapper-release-status/approved-release-set');

function usage() {
  console.error(`Usage:
  ./script/approved_release_set.cjs validate-set FILE
  ./script/approved_release_set.cjs member FILE MEMBER
  ./script/approved_release_set.cjs validate-approved FILE
  ./script/approved_release_set.cjs validate-history FILE
  ./script/approved_release_set.cjs history-record HISTORY ID
  ./script/approved_release_set.cjs write-prompt-free-approval COMPATIBILITY MANIFEST RELEASE_LOCK \
    ATTESTATION ACCEPTANCE VERIFICATION BASE_HISTORY RECORD OUTPUT_HISTORY
  ./script/approved_release_set.cjs write-approval CANDIDATE MANIFEST ATTESTATION PROOF GATE RECORD HISTORY`);
  process.exit(2);
}

function fileSha256(filePath, label) {
  const value = contract.readPlainJsonFile(filePath, label);
  const digest = crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
  return { value, digest };
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
    case 'validate-set': {
      if (args.length !== 1) usage();
      const record = contract.readPlainJsonFile(args[0], 'Prepared release-set record');
      contract.validatePreparedReleaseSet(record);
      break;
    }
    case 'member': {
      if (args.length !== 2) usage();
      console.log(contract.resolvePreparedMember(args[0], args[1]));
      break;
    }
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
      const record = contract.createPromptFreeApprovedRecord({
        compatibility: compatibility.value,
        manifest: manifest.value,
        releaseLock: releaseLock.value,
        acceptance: acceptance.value,
        verification: verification.value,
        attestation: attestation.value,
        compatibilitySha256: compatibility.digest,
        manifestSha256: manifest.digest,
        releaseLockSha256: releaseLock.digest,
        acceptanceSha256: acceptance.digest,
        verificationSha256: verification.digest,
        attestationSha256: attestation.digest
      });
      const nextHistory = contract.upsertApprovedHistory(baseHistory, record);
      writeJsonAtomically(recordPath, record);
      writeJsonAtomically(outputHistoryPath, nextHistory);
      console.log(recordPath);
      break;
    }
    case 'write-approval': {
      if (args.length !== 7) usage();
      const [candidatePath, manifestPath, attestationPath, proofPath, gatePath, recordPath, historyPath] = args;
      const candidate = fileSha256(candidatePath, 'Candidate release-set record');
      const manifest = fileSha256(manifestPath, 'Candidate build manifest');
      const attestation = fileSha256(attestationPath, 'Approval attestation');
      const proof = fileSha256(proofPath, 'Candidate proof');
      const gate = fileSha256(gatePath, 'Compatibility gate receipt');
      const record = contract.createApprovedRecord({
        candidateSet: candidate.value,
        manifest: manifest.value,
        attestation: attestation.value,
        candidateSetSha256: candidate.digest,
        manifestSha256: manifest.digest,
        attestationSha256: attestation.digest,
        proofSha256: proof.digest,
        gateReceiptSha256: gate.digest
      });
      let history = { schema_version: 2, approved_release_sets: [] };
      if (fs.existsSync(historyPath)) {
        history = contract.readPlainJsonFile(historyPath, 'Approved Release Set history');
      }
      const nextHistory = contract.upsertApprovedHistory(history, record);
      writeJsonAtomically(recordPath, record);
      writeJsonAtomically(historyPath, nextHistory);
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
