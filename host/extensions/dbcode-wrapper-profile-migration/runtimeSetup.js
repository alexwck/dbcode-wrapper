'use strict';

const https = require('node:https');
const {
  requireOfficialUrl,
  validateInstalledOpenVsxExtension,
  validateOpenVsxRuntimeConfiguration,
  verifyOpenVsxPackage
} = require('./openVsxPackageVerifier');

function fail(message) {
  throw new Error(message);
}

const validateRuntimeConfiguration = validateOpenVsxRuntimeConfiguration;

function parseJson(buffer, label) {
  try {
    return JSON.parse(buffer.toString('utf8'));
  } catch {
    fail(`${label} is not valid JSON.`);
  }
}

function installedVersionMap(installedExtensions) {
  const versions = new Map();
  for (const extension of installedExtensions) {
    validateInstalledOpenVsxExtension(extension);
    if (
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
  codeOssVersion,
  {
    request = https.get,
    verify = verifyOpenVsxPackage
  } = {}
) {
  const download = (url, maximumBytes) => downloadBuffer(
    url,
    maximumBytes,
    0,
    { request }
  );
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
  await verify({ codeOssVersion, packageRecord, acquisition, publicKeys });
  return acquisition.vsix;
}

module.exports = {
  acquireAndVerifyPackage,
  assertManagedRuntimeInstalled,
  missingRuntimePackages,
  validateRuntimeConfiguration
};
