#!/usr/bin/env node

'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');
const {
  resolveOpenVsxPublicKeyPath,
  selectOpenVsxPackageRecord,
  verifyOpenVsxPackage
} = require('../host/extensions/dbcode-wrapper-profile-migration/openVsxPackageVerifier');

const ACQUISITION_FILES = [
  ['registryRecord', 'registry.json', 'registry metadata'],
  ['vsix', 'package.vsix', 'VSIX'],
  ['signatureArchive', 'signature.sigzip', 'signature archive'],
  ['sha256Record', 'package.sha256', 'SHA-256 record'],
  ['publicKey', 'openvsx-public-key.pem', 'downloaded public key']
];

function fail(message) {
  throw new Error(message);
}

async function readPlainFile(fileSystem, filePath, purpose, identity) {
  let metadata;
  try {
    metadata = await fileSystem.lstat(filePath);
  } catch {
    fail(`The Open VSX acquisition is missing ${purpose} for ${identity}.`);
  }
  if (!metadata.isFile() || metadata.isSymbolicLink()) {
    fail(`The Open VSX acquisition has unsafe ${purpose} for ${identity}.`);
  }
  try {
    return await fileSystem.readFile(filePath);
  } catch {
    fail(`The Open VSX acquisition could not read ${purpose} for ${identity}.`);
  }
}

async function verifyPackageRoot(
  {
    packageId,
    packageRoot,
    codeOssVersion,
    packages,
    keyRoot
  },
  {
    fileSystem = fs,
    fromBuffer,
    readZipEntries
  } = {}
) {
  const packageRecord = selectOpenVsxPackageRecord(packages, packageId);
  const identity = `${packageRecord.id}@${packageRecord.version}`;
  const resolvedPackageRoot = path.resolve(packageRoot);
  let rootMetadata;
  try {
    rootMetadata = await fileSystem.lstat(resolvedPackageRoot);
  } catch {
    fail(`The Open VSX acquisition root is missing for ${identity}.`);
  }
  if (!rootMetadata.isDirectory() || rootMetadata.isSymbolicLink()) {
    fail(`The Open VSX acquisition root is unsafe for ${identity}.`);
  }

  const acquisition = {};
  for (const [field, fileName, purpose] of ACQUISITION_FILES) {
    acquisition[field] = await readPlainFile(
      fileSystem,
      path.join(resolvedPackageRoot, fileName),
      purpose,
      identity
    );
  }
  try {
    acquisition.registryRecord = JSON.parse(acquisition.registryRecord.toString('utf8'));
  } catch {
    fail(`The Open VSX registry metadata is not valid JSON for ${identity}.`);
  }

  const pinnedKeyPath = resolveOpenVsxPublicKeyPath(keyRoot, packageRecord);
  const pinnedPublicKey = await readPlainFile(
    fileSystem,
    pinnedKeyPath,
    'pinned public key',
    identity
  );

  return verifyOpenVsxPackage(
    {
      codeOssVersion,
      packageRecord,
      acquisition,
      publicKeys: [{
        id: packageRecord.public_key_id,
        sha256: packageRecord.public_key_sha256,
        pem: pinnedPublicKey.toString('utf8')
      }]
    },
    {
      fromBuffer,
      readZipEntries
    }
  );
}

async function main(argv) {
  if (argv.length !== 6) {
    console.error(
      'Usage: node verify_openvsx_package.cjs <extension-id> <package-root> ' +
      '<Code OSS version> <package-set-json> <key-root> <yauzl-module>'
    );
    return 2;
  }
  const [
    packageId,
    packageRoot,
    codeOssVersion,
    packagesJson,
    keyRoot,
    yauzlModule
  ] = argv;
  let packages;
  try {
    packages = JSON.parse(packagesJson);
  } catch {
    console.error('The Release Specification package set is not valid JSON.');
    return 1;
  }
  let fromBuffer;
  try {
    ({ fromBuffer } = require(path.resolve(yauzlModule)));
  } catch {
    console.error('The signed host ZIP verifier is unavailable.');
    return 1;
  }
  try {
    const result = await verifyPackageRoot(
      {
        packageId,
        packageRoot,
        codeOssVersion,
        packages,
        keyRoot
      },
      { fromBuffer }
    );
    console.log(
      `Verified ${result.id}@${result.version}: official stable record, ` +
      'manifest, SHA-256, and Ed25519 signature.'
    );
    return 0;
  } catch (error) {
    console.error(
      error instanceof Error
        ? error.message
        : 'The Open VSX package could not be verified.'
    );
    return 1;
  }
}

module.exports = {
  verifyPackageRoot
};

if (require.main === module) {
  main(process.argv.slice(2)).then(code => {
    process.exitCode = code;
  });
}
