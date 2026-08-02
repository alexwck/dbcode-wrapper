#!/usr/bin/env node

'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');
const { isDeepStrictEqual } = require('node:util');
const {
  createOpenVsxRuntimeConfiguration,
  resolveOpenVsxPublicKeyPath
} = require('../host/extensions/dbcode-wrapper-profile-migration/openVsxPackageVerifier');

function fail(message) {
  throw new Error(message);
}

function parseExtensionRecord(value) {
  try {
    return JSON.parse(value);
  } catch {
    fail('The Release Specification extension record is not valid JSON.');
  }
}

async function readPlainFile(filePath, label) {
  let metadata;
  try {
    metadata = await fs.lstat(filePath);
  } catch {
    fail(`${label} is missing.`);
  }
  if (!metadata.isFile() || metadata.isSymbolicLink()) {
    fail(`${label} is unsafe.`);
  }
  return fs.readFile(filePath);
}

async function loadPublicKeys(extensionRecord, keyRoot) {
  if (!Array.isArray(extensionRecord?.packages) || extensionRecord.packages.length === 0) {
    fail('The Release Specification package set is empty.');
  }
  const keyDigests = new Map();
  for (const packageRecord of extensionRecord.packages) {
    const existing = keyDigests.get(packageRecord?.public_key_id);
    if (existing && existing !== packageRecord.public_key_sha256) {
      fail('The Release Specification binds one Open VSX key to different digests.');
    }
    keyDigests.set(packageRecord?.public_key_id, packageRecord?.public_key_sha256);
  }

  const publicKeys = [];
  for (const [id, sha256] of [...keyDigests].sort(([left], [right]) => (
    left === right ? 0 : left < right ? -1 : 1
  ))) {
    const keyPath = resolveOpenVsxPublicKeyPath(keyRoot, { public_key_id: id });
    const pem = await readPlainFile(keyPath, `The pinned Open VSX public key ${id}`);
    publicKeys.push({ id, sha256, pem: pem.toString('utf8') });
  }
  return publicKeys;
}

async function expectedConfiguration(extensionRecordJson, applicationName, keyRoot) {
  const extensionRecord = parseExtensionRecord(extensionRecordJson);
  return createOpenVsxRuntimeConfiguration({
    extensionRecord,
    applicationName,
    publicKeys: await loadPublicKeys(extensionRecord, keyRoot)
  });
}

async function writeConfiguration(outputPath, configuration) {
  if (typeof outputPath !== 'string' || !path.isAbsolute(outputPath)) {
    fail('The focused runtime setup manifest path must be absolute.');
  }
  const parent = path.dirname(outputPath);
  await fs.mkdir(parent, { recursive: true, mode: 0o700 });
  const parentMetadata = await fs.lstat(parent);
  if (!parentMetadata.isDirectory() || parentMetadata.isSymbolicLink()) {
    fail('The focused runtime setup manifest parent is unsafe.');
  }
  try {
    const outputMetadata = await fs.lstat(outputPath);
    if (outputMetadata.isSymbolicLink()) {
      fail('The focused runtime setup manifest must not replace a symbolic link.');
    }
  } catch (error) {
    if (error?.code !== 'ENOENT') {
      throw error;
    }
  }

  const temporary = path.join(parent, `.${path.basename(outputPath)}.${process.pid}.tmp`);
  try {
    await fs.writeFile(temporary, `${JSON.stringify(configuration, null, 2)}\n`, {
      encoding: 'utf8',
      flag: 'wx',
      mode: 0o600
    });
    await fs.chmod(temporary, 0o644);
    await fs.rename(temporary, outputPath);
  } finally {
    await fs.rm(temporary, { force: true }).catch(() => undefined);
  }
}

async function run(args) {
  if (args.length !== 5) {
    fail('Usage: runtime_extension_set.cjs write|check FILE APPLICATION_NAME EXTENSION_RECORD_JSON KEY_ROOT');
  }
  const [command, filePath, applicationName, extensionRecordJson, keyRoot] = args;
  if (!['write', 'check'].includes(command) || !filePath || !applicationName || !extensionRecordJson || !keyRoot) {
    fail('Usage: runtime_extension_set.cjs write|check FILE APPLICATION_NAME EXTENSION_RECORD_JSON KEY_ROOT');
  }
  const expected = await expectedConfiguration(extensionRecordJson, applicationName, keyRoot);
  if (command === 'write') {
    await writeConfiguration(filePath, expected);
    return;
  }

  let actual;
  try {
    actual = JSON.parse((await readPlainFile(filePath, 'The focused runtime setup manifest')).toString('utf8'));
  } catch (error) {
    if (error instanceof SyntaxError) {
      fail('The focused runtime setup manifest is not valid JSON.');
    }
    throw error;
  }
  if (!isDeepStrictEqual(actual, expected)) {
    fail('The focused runtime setup manifest does not match the Release Specification.');
  }
}

run(process.argv.slice(2)).catch(error => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
