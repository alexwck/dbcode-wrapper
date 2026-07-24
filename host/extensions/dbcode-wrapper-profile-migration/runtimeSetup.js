'use strict';

const crypto = require('node:crypto');
const https = require('node:https');

const DIGEST_PATTERN = /^[0-9a-f]{64}$/;
const SAFE_ID_PATTERN = /^[a-z0-9][a-z0-9.-]+$/;
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

function validateRuntimeConfiguration(configuration) {
  if (!exactKeys(configuration, [
    'schema_version',
    'setup',
    'code_oss_version',
    'application_name',
    'packages',
    'public_keys'
  ])) {
    fail('The focused runtime setup configuration has an unexpected shape.');
  }
  if (
    configuration.schema_version !== 1 ||
    configuration.setup !== 'focused-pinned-official-sources' ||
    typeof configuration.code_oss_version !== 'string' ||
    !/^[0-9]+\.[0-9]+\.[0-9]+$/.test(configuration.code_oss_version) ||
    configuration.application_name !== 'dbcode-wrapper' ||
    !Array.isArray(configuration.packages) ||
    configuration.packages.length === 0 ||
    !Array.isArray(configuration.public_keys) ||
    configuration.public_keys.length === 0
  ) {
    fail('The focused runtime setup configuration is invalid.');
  }

  const keyIds = new Set();
  const keyDigests = new Map();
  for (const key of configuration.public_keys) {
    if (
      !exactKeys(key, ['id', 'sha256', 'pem']) ||
      typeof key.id !== 'string' ||
      key.id.length === 0 ||
      !DIGEST_PATTERN.test(key.sha256) ||
      typeof key.pem !== 'string' ||
      !key.pem.includes('BEGIN PUBLIC KEY') ||
      sha256(Buffer.from(key.pem)) !== key.sha256 ||
      keyIds.has(key.id)
    ) {
      fail('The focused runtime setup contains an invalid or duplicate Open VSX public key.');
    }
    keyIds.add(key.id);
    keyDigests.set(key.id, key.sha256);
  }

  const packageIds = new Set();
  const usedKeyIds = new Set();
  for (const packageRecord of configuration.packages) {
    if (!exactKeys(packageRecord, REQUIRED_PACKAGE_FIELDS)) {
      fail('A focused runtime package has an unexpected shape.');
    }
    if (
      !SAFE_ID_PATTERN.test(packageRecord.id) ||
      packageRecord.id !== `${packageRecord.publisher}.${packageRecord.name}` ||
      packageRecord.namespace !== packageRecord.publisher ||
      !SAFE_VERSION_PATTERN.test(packageRecord.version) ||
      typeof packageRecord.role !== 'string' ||
      packageRecord.role.length === 0 ||
      typeof packageRecord.engine !== 'string' ||
      packageRecord.engine.length === 0 ||
      packageRecord.target_platform !== 'universal' ||
      packageRecord.verified_publisher !== true ||
      packageRecord.pre_release !== false ||
      packageRecord.deprecated !== false ||
      !DIGEST_PATTERN.test(packageRecord.sha256) ||
      !DIGEST_PATTERN.test(packageRecord.signature_archive_sha256) ||
      !DIGEST_PATTERN.test(packageRecord.public_key_sha256) ||
      !Number.isSafeInteger(packageRecord.package_size) ||
      packageRecord.package_size <= 0 ||
      !keyIds.has(packageRecord.public_key_id) ||
      keyDigests.get(packageRecord.public_key_id) !== packageRecord.public_key_sha256 ||
      packageIds.has(packageRecord.id)
    ) {
      fail('A focused runtime package is invalid, duplicated, or not bound to its approved public key.');
    }
    requireOfficialUrl(
      packageRecord.registry_api_url,
      `/api/${packageRecord.namespace}/${packageRecord.name}/${packageRecord.version}`,
      `${packageRecord.id} registry URL`
    );
    const filePrefix = `/api/${packageRecord.namespace}/${packageRecord.name}/${packageRecord.version}/file/`;
    requireOfficialUrl(packageRecord.download_url, `${filePrefix}${packageRecord.namespace}.${packageRecord.name}-${packageRecord.version}.vsix`, `${packageRecord.id} download URL`);
    requireOfficialUrl(packageRecord.signature_url, `${filePrefix}${packageRecord.namespace}.${packageRecord.name}-${packageRecord.version}.sigzip`, `${packageRecord.id} signature URL`);
    requireOfficialUrl(packageRecord.sha256_url, `${filePrefix}${packageRecord.namespace}.${packageRecord.name}-${packageRecord.version}.sha256`, `${packageRecord.id} SHA-256 URL`);
    requireOfficialUrl(packageRecord.public_key_url, `/api/-/public-key/${packageRecord.public_key_id}`, `${packageRecord.id} public-key URL`);
    packageIds.add(packageRecord.id);
    usedKeyIds.add(packageRecord.public_key_id);
  }

  if (!packageIds.has('dbcode.dbcode')) {
    fail('The focused runtime setup does not contain DBCode.');
  }
  if (usedKeyIds.size !== keyIds.size) {
    fail('The focused runtime setup contains an unused Open VSX public key.');
  }
  return configuration;
}

function readZipEntries(archive, requestedNames, options = {}) {
  const fromBuffer = options.fromBuffer ?? require('yauzl').fromBuffer;
  const requested = new Set(requestedNames);
  return new Promise((resolve, reject) => {
    fromBuffer(archive, { lazyEntries: true }, (openError, zipFile) => {
      if (openError) {
        reject(new Error('A signed package archive could not be opened.'));
        return;
      }
      const entries = new Map();
      const failZip = message => {
        zipFile.close();
        reject(new Error(message));
      };
      zipFile.on('error', () => reject(new Error('A signed package archive could not be read.')));
      zipFile.on('entry', entry => {
        if (!requested.has(entry.fileName)) {
          zipFile.readEntry();
          return;
        }
        if (entries.has(entry.fileName) || entry.uncompressedSize > 4 * 1024 * 1024) {
          failZip('A signed package archive contains an unsafe required entry.');
          return;
        }
        zipFile.openReadStream(entry, (streamError, stream) => {
          if (streamError) {
            failZip('A signed package archive entry could not be opened.');
            return;
          }
          const chunks = [];
          let total = 0;
          stream.on('data', chunk => {
            total += chunk.length;
            if (total > 4 * 1024 * 1024) {
              stream.destroy(new Error('A signed package archive entry is too large.'));
              return;
            }
            chunks.push(chunk);
          });
          stream.on('error', () => failZip('A signed package archive entry could not be read.'));
          stream.on('end', () => {
            entries.set(entry.fileName, Buffer.concat(chunks));
            zipFile.readEntry();
          });
        });
      });
      zipFile.on('end', () => {
        if (requestedNames.some(name => !entries.has(name))) {
          reject(new Error('A signed package archive is missing a required entry.'));
          return;
        }
        resolve(entries);
      });
      zipFile.readEntry();
    });
  });
}

function parseJson(buffer, label) {
  try {
    return JSON.parse(buffer.toString('utf8'));
  } catch {
    fail(`${label} is not valid JSON.`);
  }
}

async function verifyPackageAcquisition(
  packageRecord,
  acquisition,
  publicKeys,
  { readZipEntries: zipReader = readZipEntries } = {}
) {
  const registry = acquisition.registryRecord;
  const registryMatches = registry &&
    registry.namespace === packageRecord.namespace &&
    registry.name === packageRecord.name &&
    registry.version === packageRecord.version &&
    registry.engines?.vscode === packageRecord.engine &&
    registry.targetPlatform === packageRecord.target_platform &&
    registry.timestamp === packageRecord.published_at &&
    registry.verified === true &&
    registry.preRelease === false &&
    registry.deprecated === false &&
    registry.files?.download === packageRecord.download_url &&
    registry.files?.signature === packageRecord.signature_url &&
    registry.files?.sha256 === packageRecord.sha256_url &&
    registry.files?.publicKey === packageRecord.public_key_url;
  if (!registryMatches) {
    fail(`The official registry record does not match pinned package ${packageRecord.id}@${packageRecord.version}.`);
  }

  if (!Buffer.isBuffer(acquisition.vsix) || sha256(acquisition.vsix) !== packageRecord.sha256) {
    fail(`The VSIX SHA-256 does not match pinned package ${packageRecord.id}@${packageRecord.version}.`);
  }
  if (acquisition.vsix.length !== packageRecord.package_size) {
    fail(`The VSIX size does not match pinned package ${packageRecord.id}@${packageRecord.version}.`);
  }
  if (
    !Buffer.isBuffer(acquisition.signatureArchive) ||
    sha256(acquisition.signatureArchive) !== packageRecord.signature_archive_sha256
  ) {
    fail(`The signature archive does not match pinned package ${packageRecord.id}@${packageRecord.version}.`);
  }
  if (
    !Buffer.isBuffer(acquisition.sha256Record) ||
    acquisition.sha256Record.toString('utf8').trim() !== packageRecord.sha256
  ) {
    fail(`The official SHA-256 record does not match pinned package ${packageRecord.id}@${packageRecord.version}.`);
  }

  const publicKeyRecord = publicKeys.find(key => key.id === packageRecord.public_key_id);
  if (
    !publicKeyRecord ||
    publicKeyRecord.sha256 !== packageRecord.public_key_sha256 ||
    !Buffer.isBuffer(acquisition.publicKey) ||
    sha256(acquisition.publicKey) !== packageRecord.public_key_sha256 ||
    !acquisition.publicKey.equals(Buffer.from(publicKeyRecord.pem))
  ) {
    fail(`The Open VSX public key does not match pinned package ${packageRecord.id}@${packageRecord.version}.`);
  }

  const signatureEntries = await zipReader(
    acquisition.signatureArchive,
    ['.signature.sig', '.signature.manifest', '.signature.p7s']
  );
  const signature = signatureEntries.get('.signature.sig');
  if (!Buffer.isBuffer(signature) || signature.length !== 64) {
    fail(`The Open VSX signature is invalid for ${packageRecord.id}@${packageRecord.version}.`);
  }
  let signatureValid = false;
  try {
    signatureValid = crypto.verify(null, acquisition.vsix, publicKeyRecord.pem, signature);
  } catch {
    signatureValid = false;
  }
  if (!signatureValid) {
    fail(`The Open VSX signature did not verify for ${packageRecord.id}@${packageRecord.version}.`);
  }

  const signatureManifest = parseJson(signatureEntries.get('.signature.manifest'), 'The Open VSX signature manifest');
  let signedDigest;
  try {
    signedDigest = Buffer.from(signatureManifest.package.digests.sha256, 'base64').toString('hex');
  } catch {
    fail('The Open VSX signature manifest has an invalid digest.');
  }
  if (
    signedDigest !== packageRecord.sha256 ||
    signatureManifest.package?.size !== packageRecord.package_size
  ) {
    fail(`The Open VSX signature manifest does not identify ${packageRecord.id}@${packageRecord.version}.`);
  }

  const vsixEntries = await zipReader(acquisition.vsix, ['extension/package.json']);
  const extensionManifest = parseJson(vsixEntries.get('extension/package.json'), 'The VSIX extension manifest');
  if (
    extensionManifest.publisher !== packageRecord.publisher ||
    extensionManifest.name !== packageRecord.name ||
    extensionManifest.version !== packageRecord.version ||
    extensionManifest.engines?.vscode !== packageRecord.engine
  ) {
    fail(`The VSIX manifest does not identify ${packageRecord.id}@${packageRecord.version}.`);
  }
}

function installedVersionMap(installedExtensions) {
  const versions = new Map();
  for (const extension of installedExtensions) {
    if (
      !extension ||
      !SAFE_ID_PATTERN.test(extension.id) ||
      !SAFE_VERSION_PATTERN.test(extension.version) ||
      versions.has(extension.id)
    ) {
      fail('The installed extension inventory is invalid or duplicated.');
    }
    versions.set(extension.id, extension.version);
  }
  return versions;
}

function missingRuntimePackages(configuration, installedExtensions) {
  validateRuntimeConfiguration(configuration);
  const versions = installedVersionMap(installedExtensions);
  return configuration.packages.filter(packageRecord => versions.get(packageRecord.id) !== packageRecord.version);
}

function assertManagedRuntimeInstalled(configuration, installedExtensions) {
  validateRuntimeConfiguration(configuration);
  const installedVersions = installedVersionMap(installedExtensions);
  const expected = configuration.packages
    .map(packageRecord => `${packageRecord.id}@${packageRecord.version}`)
    .sort();
  const installed = [...installedVersions]
    .map(([id, version]) => `${id}@${version}`)
    .sort();
  if (JSON.stringify(installed) !== JSON.stringify(expected)) {
    fail(`The external extension inventory does not exactly match the pinned runtime. Expected: ${expected.join(', ')}.`);
  }
}

function downloadBuffer(url, maximumBytes, redirectCount = 0, options = {}) {
  const requestBuffer = options.request ?? https.get;
  if (redirectCount === 0) {
    requireOfficialUrl(url, new URL(url).pathname, 'Runtime package download');
  }
  if (!Number.isSafeInteger(maximumBytes) || maximumBytes <= 0) {
    return Promise.reject(new Error('The runtime package download limit is invalid.'));
  }
  return new Promise((resolve, reject) => {
    let settled = false;
    const rejectOnce = error => {
      if (!settled) {
        settled = true;
        reject(error);
      }
    };
    const resolveOnce = value => {
      if (!settled) {
        settled = true;
        resolve(value);
      }
    };
    const request = requestBuffer(url, {
      headers: { 'User-Agent': 'DBCode-Wrapper-Private-Personal-Setup/1' },
      timeout: 30_000
    }, response => {
      if ([301, 302, 303, 307, 308].includes(response.statusCode) && response.headers.location) {
        response.resume();
        if (redirectCount >= 5) {
          rejectOnce(new Error('An official runtime package used too many redirects.'));
          return;
        }
        let redirected;
        try {
          redirected = new URL(response.headers.location, url);
        } catch {
          rejectOnce(new Error('An official runtime package returned an invalid redirect.'));
          return;
        }
        if (redirected.protocol !== 'https:') {
          rejectOnce(new Error('An official runtime package redirected outside HTTPS.'));
          return;
        }
        downloadBuffer(
          redirected.href,
          maximumBytes,
          redirectCount + 1,
          { request: requestBuffer }
        ).then(resolveOnce, rejectOnce);
        return;
      }
      if (response.statusCode !== 200) {
        response.resume();
        rejectOnce(new Error(`An official runtime package request failed with HTTP ${response.statusCode}.`));
        return;
      }
      const chunks = [];
      let total = 0;
      const declaredLength = Number.parseInt(response.headers['content-length'] ?? '', 10);
      if (Number.isFinite(declaredLength) && declaredLength > maximumBytes) {
        response.resume();
        rejectOnce(new Error('An official runtime package exceeded its pinned size limit.'));
        return;
      }
      response.on('data', chunk => {
        total += chunk.length;
        if (total > maximumBytes) {
          rejectOnce(new Error('An official runtime package exceeded its pinned size limit.'));
          request.destroy();
          return;
        }
        chunks.push(chunk);
      });
      response.on('aborted', () => rejectOnce(new Error('An official runtime package download ended early.')));
      response.on('error', () => rejectOnce(new Error('An official runtime package response could not be read.')));
      response.on('end', () => resolveOnce(Buffer.concat(chunks)));
    });
    request.on('timeout', () => {
      rejectOnce(new Error('An official runtime package request timed out.'));
      request.destroy();
    });
    request.on('error', error => rejectOnce(new Error(`An official runtime package could not be downloaded. ${error.message}`)));
  });
}

async function acquireAndVerifyPackage(
  packageRecord,
  publicKeys,
  {
    download = downloadBuffer,
    verify = verifyPackageAcquisition
  } = {}
) {
  const [registryBytes, vsix, signatureArchive, sha256Record, publicKey] = await Promise.all([
    download(packageRecord.registry_api_url, 1024 * 1024),
    download(packageRecord.download_url, packageRecord.package_size),
    download(packageRecord.signature_url, 4 * 1024 * 1024),
    download(packageRecord.sha256_url, 1024),
    download(packageRecord.public_key_url, 64 * 1024)
  ]);
  const acquisition = {
    registryRecord: parseJson(registryBytes, 'The official Open VSX registry record'),
    vsix,
    signatureArchive,
    sha256Record,
    publicKey
  };
  await verify(packageRecord, acquisition, publicKeys);
  return acquisition.vsix;
}

module.exports = {
  acquireAndVerifyPackage,
  assertManagedRuntimeInstalled,
  downloadBuffer,
  missingRuntimePackages,
  readZipEntries,
  sha256,
  validateRuntimeConfiguration,
  verifyPackageAcquisition
};
