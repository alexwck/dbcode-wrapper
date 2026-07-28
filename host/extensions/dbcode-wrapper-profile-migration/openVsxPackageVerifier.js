'use strict';

const crypto = require('node:crypto');
const path = require('node:path');

const DIGEST_PATTERN = /^[0-9a-f]{64}$/;
const SAFE_ID_PATTERN = /^[a-z0-9][a-z0-9.-]+$/;
const SAFE_KEY_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]+$/;
const SAFE_VERSION_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]+$/;
const REQUIRED_PACKAGE_FIELDS = [
  'role',
  'namespace',
  'name',
  'id',
  'publisher',
  'version',
  'engine',
  'target_platform',
  'published_at',
  'verified_publisher',
  'pre_release',
  'deprecated',
  'registry_api_url',
  'download_url',
  'signature_url',
  'sha256_url',
  'public_key_id',
  'public_key_url',
  'sha256',
  'signature_archive_sha256',
  'public_key_sha256',
  'package_size'
];
const REQUIRED_SIGNATURE_ENTRIES = [
  '.signature.sig',
  '.signature.manifest',
  '.signature.p7s'
];
const REQUIRED_VSIX_ENTRIES = ['extension/package.json'];
const MAXIMUM_REQUIRED_ENTRY_SIZE = 4 * 1024 * 1024;

function fail(message) {
  throw new Error(message);
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function exactKeys(value, expected) {
  return value && typeof value === 'object' && !Array.isArray(value) &&
    JSON.stringify(Object.keys(value).sort()) === JSON.stringify([...expected].sort());
}

function packageIdentity(packageRecord) {
  return `${packageRecord?.id ?? 'unknown package'}@${packageRecord?.version ?? 'unknown version'}`;
}

function parseJson(buffer, label) {
  try {
    if (!Buffer.isBuffer(buffer)) {
      throw new Error('Expected a buffer.');
    }
    return JSON.parse(buffer.toString('utf8'));
  } catch {
    fail(`${label} is not valid JSON.`);
  }
}

function requireOfficialUrl(value, expectedPath, label) {
  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    fail(`${label} is not a valid URL.`);
  }
  if (
    parsed.protocol !== 'https:' ||
    parsed.hostname !== 'open-vsx.org' ||
    parsed.port !== '' ||
    parsed.username !== '' ||
    parsed.password !== '' ||
    parsed.search !== '' ||
    parsed.hash !== '' ||
    parsed.pathname !== expectedPath
  ) {
    fail(`${label} is not the exact official Open VSX URL.`);
  }
}

function loadSemver(providedSemver) {
  if (providedSemver) {
    return providedSemver;
  }
  try {
    return require('semver');
  } catch {
    const pinnedSemver = path.resolve(
      path.dirname(process.execPath),
      '../lib/node_modules/npm/node_modules/semver'
    );
    try {
      return require(pinnedSemver);
    } catch {
      fail('The pinned semantic-version verifier is unavailable.');
    }
  }
}

function engineIsCompatible(
  codeOssVersion,
  engineRange,
  { semver: providedSemver } = {}
) {
  const semver = loadSemver(providedSemver);
  if (
    !semver.valid(codeOssVersion) ||
    !semver.validRange(engineRange, { includePrerelease: true })
  ) {
    fail('The Code OSS or extension engine version is invalid.');
  }
  return semver.satisfies(codeOssVersion, engineRange, { includePrerelease: true });
}

function assertEngineCompatibility(
  codeOssVersion,
  packageRecord,
  dependencies = {}
) {
  const identity = packageIdentity(packageRecord);
  let compatible;
  try {
    compatible = engineIsCompatible(codeOssVersion, packageRecord?.engine, dependencies);
  } catch {
    fail(`The engine compatibility record is invalid for ${identity}.`);
  }
  if (!compatible) {
    fail(`${identity} is not compatible with Code OSS ${codeOssVersion}.`);
  }
}

function validateOpenVsxPublicKey(publicKeyRecord) {
  if (
    !exactKeys(publicKeyRecord, ['id', 'sha256', 'pem']) ||
    !SAFE_KEY_ID_PATTERN.test(publicKeyRecord.id) ||
    !DIGEST_PATTERN.test(publicKeyRecord.sha256) ||
    typeof publicKeyRecord.pem !== 'string' ||
    !publicKeyRecord.pem.includes('BEGIN PUBLIC KEY') ||
    sha256(Buffer.from(publicKeyRecord.pem)) !== publicKeyRecord.sha256
  ) {
    fail('An Open VSX public key record is invalid.');
  }
  return publicKeyRecord;
}

function validateOpenVsxPackageRecord(
  packageRecord,
  codeOssVersion,
  publicKeyDigests
) {
  const identity = packageIdentity(packageRecord);
  if (!exactKeys(packageRecord, REQUIRED_PACKAGE_FIELDS)) {
    fail(`The package record has an unexpected shape for ${identity}.`);
  }
  if (
    !SAFE_ID_PATTERN.test(packageRecord.id) ||
    packageRecord.id !== `${packageRecord.publisher}.${packageRecord.name}` ||
    packageRecord.namespace !== packageRecord.publisher ||
    !SAFE_VERSION_PATTERN.test(packageRecord.version) ||
    typeof packageRecord.role !== 'string' ||
    packageRecord.role.length === 0 ||
    typeof packageRecord.published_at !== 'string' ||
    packageRecord.published_at.length === 0 ||
    packageRecord.target_platform !== 'universal' ||
    packageRecord.verified_publisher !== true ||
    packageRecord.pre_release !== false ||
    packageRecord.deprecated !== false ||
    !DIGEST_PATTERN.test(packageRecord.sha256) ||
    !DIGEST_PATTERN.test(packageRecord.signature_archive_sha256) ||
    !DIGEST_PATTERN.test(packageRecord.public_key_sha256) ||
    !SAFE_KEY_ID_PATTERN.test(packageRecord.public_key_id) ||
    !Number.isSafeInteger(packageRecord.package_size) ||
    packageRecord.package_size <= 0
  ) {
    fail(`The package record is invalid for ${identity}.`);
  }
  if (
    !(publicKeyDigests instanceof Map) ||
    publicKeyDigests.get(packageRecord.public_key_id) !== packageRecord.public_key_sha256
  ) {
    fail(`${identity} is not bound to its approved public key.`);
  }

  assertEngineCompatibility(codeOssVersion, packageRecord);
  requireOfficialUrl(
    packageRecord.registry_api_url,
    `/api/${packageRecord.namespace}/${packageRecord.name}/${packageRecord.version}`,
    `${identity} registry URL`
  );
  const filePrefix = `/api/${packageRecord.namespace}/${packageRecord.name}/${packageRecord.version}/file/`;
  requireOfficialUrl(
    packageRecord.download_url,
    `${filePrefix}${packageRecord.namespace}.${packageRecord.name}-${packageRecord.version}.vsix`,
    `${identity} download URL`
  );
  requireOfficialUrl(
    packageRecord.signature_url,
    `${filePrefix}${packageRecord.namespace}.${packageRecord.name}-${packageRecord.version}.sigzip`,
    `${identity} signature URL`
  );
  requireOfficialUrl(
    packageRecord.sha256_url,
    `${filePrefix}${packageRecord.namespace}.${packageRecord.name}-${packageRecord.version}.sha256`,
    `${identity} SHA-256 URL`
  );
  requireOfficialUrl(
    packageRecord.public_key_url,
    `/api/-/public-key/${packageRecord.public_key_id}`,
    `${identity} public-key URL`
  );
  return packageRecord;
}

function archiveEntryIsSafe(name) {
  if (
    typeof name !== 'string' ||
    name.length === 0 ||
    name.includes('\0') ||
    name.includes('\\') ||
    name.startsWith('/') ||
    /^[A-Za-z]:/.test(name)
  ) {
    return false;
  }
  const segments = name.split('/');
  if (segments.at(-1) === '') {
    segments.pop();
  }
  return segments.length > 0 &&
    segments.every(segment => segment.length > 0 && segment !== '.' && segment !== '..');
}

function archiveEntryIsSymlink(entry) {
  const originSystem = (entry.versionMadeBy ?? 0) >>> 8;
  const unixMode = ((entry.externalFileAttributes ?? 0) >>> 16) & 0xffff;
  return originSystem === 3 && (unixMode & 0o170000) === 0o120000;
}

function readZipEntries(archive, requestedNames, options = {}) {
  let fromBuffer = options.fromBuffer;
  if (!fromBuffer) {
    try {
      ({ fromBuffer } = require('yauzl'));
    } catch {
      return Promise.reject(new Error('The signed package archive verifier is unavailable.'));
    }
  }
  if (
    !Buffer.isBuffer(archive) ||
    !Array.isArray(requestedNames) ||
    requestedNames.length === 0 ||
    new Set(requestedNames).size !== requestedNames.length ||
    requestedNames.some(name => !archiveEntryIsSafe(name))
  ) {
    return Promise.reject(new Error('A signed package archive request is invalid.'));
  }
  const requested = new Set(requestedNames);
  return new Promise((resolve, reject) => {
    const openArchive = (openError, zipFile) => {
      if (openError || !zipFile) {
        reject(new Error('A signed package archive could not be opened.'));
        return;
      }
      let settled = false;
      const entries = new Map();
      const entryNames = new Set();
      const close = () => {
        try {
          zipFile.close();
        } catch {
          // The purpose-level verification error below is enough.
        }
      };
      const rejectOnce = message => {
        if (!settled) {
          settled = true;
          close();
          reject(new Error(message));
        }
      };

      zipFile.on('error', () => {
        rejectOnce('A signed package archive could not be read.');
      });
      zipFile.on('entry', entry => {
        if (settled) {
          return;
        }
        const name = entry?.fileName;
        if (entryNames.has(name) && requested.has(name)) {
          rejectOnce('A signed package archive contains an unsafe required entry.');
          return;
        }
        if (
          !archiveEntryIsSafe(name) ||
          entryNames.has(name) ||
          ((entry.generalPurposeBitFlag ?? 0) & 0x1) !== 0 ||
          archiveEntryIsSymlink(entry)
        ) {
          rejectOnce('A signed package archive contains an unsafe archive entry.');
          return;
        }
        entryNames.add(name);
        if (!requested.has(name)) {
          zipFile.readEntry();
          return;
        }
        if (
          !Number.isSafeInteger(entry.uncompressedSize) ||
          entry.uncompressedSize < 0 ||
          entry.uncompressedSize > MAXIMUM_REQUIRED_ENTRY_SIZE
        ) {
          rejectOnce('A signed package archive contains an unsafe required entry.');
          return;
        }
        zipFile.openReadStream(entry, (streamError, stream) => {
          if (streamError || !stream) {
            rejectOnce('A signed package archive entry could not be opened.');
            return;
          }
          const chunks = [];
          let total = 0;
          stream.on('data', chunk => {
            if (settled) {
              return;
            }
            total += chunk.length;
            if (total > MAXIMUM_REQUIRED_ENTRY_SIZE) {
              rejectOnce('A signed package archive entry is too large.');
              stream.destroy();
              return;
            }
            chunks.push(chunk);
          });
          stream.on('error', () => {
            rejectOnce('A signed package archive entry could not be read.');
          });
          stream.on('end', () => {
            if (settled) {
              return;
            }
            entries.set(name, Buffer.concat(chunks));
            zipFile.readEntry();
          });
        });
      });
      zipFile.on('end', () => {
        if (settled) {
          return;
        }
        if (requestedNames.some(name => !entries.has(name))) {
          rejectOnce('A signed package archive is missing a required entry.');
          return;
        }
        settled = true;
        resolve(entries);
      });
      zipFile.readEntry();
    };
    try {
      fromBuffer(archive, { lazyEntries: true }, openArchive);
    } catch {
      reject(new Error('A signed package archive could not be opened.'));
    }
  });
}

function base64DigestToHex(value) {
  if (typeof value !== 'string' || value.length === 0) {
    fail('The Open VSX signature manifest has an invalid digest.');
  }
  const decoded = Buffer.from(value, 'base64');
  const normalizedInput = value.replace(/=+$/, '');
  const normalizedOutput = decoded.toString('base64').replace(/=+$/, '');
  if (decoded.length !== 32 || normalizedInput !== normalizedOutput) {
    fail('The Open VSX signature manifest has an invalid digest.');
  }
  return decoded.toString('hex');
}

async function verifyOpenVsxPackage(
  {
    codeOssVersion,
    packageRecord,
    acquisition,
    publicKeys
  },
  {
    fromBuffer,
    readZipEntries: providedZipReader
  } = {}
) {
  const identity = packageIdentity(packageRecord);
  if (!Array.isArray(publicKeys) || publicKeys.length === 0) {
    fail(`The approved public key is unavailable for ${identity}.`);
  }
  const publicKeyDigests = new Map();
  for (const publicKey of publicKeys) {
    validateOpenVsxPublicKey(publicKey);
    if (publicKeyDigests.has(publicKey.id)) {
      fail('The Open VSX public key set contains a duplicate key.');
    }
    publicKeyDigests.set(publicKey.id, publicKey.sha256);
  }
  validateOpenVsxPackageRecord(packageRecord, codeOssVersion, publicKeyDigests);

  if (!exactKeys(acquisition, [
    'registryRecord',
    'vsix',
    'signatureArchive',
    'sha256Record',
    'publicKey'
  ])) {
    fail(`The Open VSX acquisition has an unexpected shape for ${identity}.`);
  }
  const registry = acquisition.registryRecord;
  const registryMatches = registry &&
    registry.namespace === packageRecord.namespace &&
    registry.name === packageRecord.name &&
    registry.version === packageRecord.version &&
    registry.engines?.vscode === packageRecord.engine &&
    registry.targetPlatform === packageRecord.target_platform &&
    registry.timestamp === packageRecord.published_at &&
    registry.verified === packageRecord.verified_publisher &&
    registry.preRelease === packageRecord.pre_release &&
    registry.deprecated === packageRecord.deprecated &&
    registry.files?.download === packageRecord.download_url &&
    registry.files?.signature === packageRecord.signature_url &&
    registry.files?.sha256 === packageRecord.sha256_url &&
    registry.files?.publicKey === packageRecord.public_key_url;
  if (!registryMatches) {
    fail(`The official registry record does not match pinned package ${identity}.`);
  }

  if (!Buffer.isBuffer(acquisition.vsix) || sha256(acquisition.vsix) !== packageRecord.sha256) {
    fail(`The VSIX SHA-256 does not match pinned package ${identity}.`);
  }
  if (acquisition.vsix.length !== packageRecord.package_size) {
    fail(`The VSIX size does not match pinned package ${identity}.`);
  }
  if (
    !Buffer.isBuffer(acquisition.signatureArchive) ||
    sha256(acquisition.signatureArchive) !== packageRecord.signature_archive_sha256
  ) {
    fail(`The signature archive does not match pinned package ${identity}.`);
  }
  if (
    !Buffer.isBuffer(acquisition.sha256Record) ||
    acquisition.sha256Record.toString('utf8').trim() !== packageRecord.sha256
  ) {
    fail(`The official SHA-256 record does not match pinned package ${identity}.`);
  }

  const publicKeyRecord = publicKeys.find(key => key.id === packageRecord.public_key_id);
  if (
    !publicKeyRecord ||
    publicKeyRecord.sha256 !== packageRecord.public_key_sha256 ||
    !Buffer.isBuffer(acquisition.publicKey) ||
    sha256(acquisition.publicKey) !== packageRecord.public_key_sha256 ||
    !acquisition.publicKey.equals(Buffer.from(publicKeyRecord.pem))
  ) {
    fail(`The Open VSX public key does not match pinned package ${identity}.`);
  }

  const zipReader = providedZipReader ?? ((archive, names) => (
    readZipEntries(archive, names, { fromBuffer })
  ));
  const signatureEntries = await zipReader(
    acquisition.signatureArchive,
    REQUIRED_SIGNATURE_ENTRIES
  );
  const signature = signatureEntries.get('.signature.sig');
  if (!Buffer.isBuffer(signature) || signature.length !== 64) {
    fail(`The Open VSX signature has an invalid size for ${identity}.`);
  }
  let signatureValid = false;
  try {
    signatureValid = crypto.verify(null, acquisition.vsix, publicKeyRecord.pem, signature);
  } catch {
    signatureValid = false;
  }
  if (!signatureValid) {
    fail(`The Open VSX signature did not verify for ${identity}.`);
  }

  const signatureManifest = parseJson(
    signatureEntries.get('.signature.manifest'),
    'The Open VSX signature manifest'
  );
  const signedDigest = base64DigestToHex(signatureManifest.package?.digests?.sha256);
  if (
    signedDigest !== packageRecord.sha256 ||
    signatureManifest.package?.size !== packageRecord.package_size
  ) {
    fail(`The Open VSX signature manifest does not identify ${identity}.`);
  }

  const vsixEntries = await zipReader(acquisition.vsix, REQUIRED_VSIX_ENTRIES);
  const extensionManifest = parseJson(
    vsixEntries.get('extension/package.json'),
    'The VSIX extension manifest'
  );
  if (
    extensionManifest.publisher !== packageRecord.publisher ||
    extensionManifest.name !== packageRecord.name ||
    extensionManifest.version !== packageRecord.version ||
    extensionManifest.engines?.vscode !== packageRecord.engine
  ) {
    fail(`The VSIX manifest does not identify ${identity}.`);
  }
  return { id: packageRecord.id, version: packageRecord.version };
}

module.exports = {
  DIGEST_PATTERN,
  REQUIRED_PACKAGE_FIELDS,
  SAFE_ID_PATTERN,
  SAFE_VERSION_PATTERN,
  assertEngineCompatibility,
  engineIsCompatible,
  exactKeys,
  readZipEntries,
  requireOfficialUrl,
  sha256,
  validateOpenVsxPackageRecord,
  validateOpenVsxPublicKey,
  verifyOpenVsxPackage
};
