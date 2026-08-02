#!/usr/bin/env node

import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import crypto from 'node:crypto';
import { EventEmitter } from 'node:events';
import fs from 'node:fs/promises';
import { createRequire } from 'node:module';
import os from 'node:os';
import path from 'node:path';
import { Readable } from 'node:stream';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const SCRIPT_ROOT = path.dirname(fileURLToPath(import.meta.url));
const runtimeSetup = require('../host/extensions/dbcode-wrapper-profile-migration/runtimeSetup.js');
const {
  acquireAndVerifyPackage,
  assertManagedRuntimeInstalled,
  missingRuntimePackages,
  validateRuntimeConfiguration
} = runtimeSetup;
const openVsxPackageVerifier = require('../host/extensions/dbcode-wrapper-profile-migration/openVsxPackageVerifier.js');
const {
  createOpenVsxRuntimeConfiguration,
  selectOpenVsxPackageRecord,
  validateInstalledOpenVsxExtension,
  validateOpenVsxRuntimeConfiguration,
  verifyOpenVsxPackage
} = openVsxPackageVerifier;
const runtimeSetupController = require('../host/extensions/dbcode-wrapper-profile-migration/runtimeSetupController.js');
const {
  RuntimeSetupController
} = runtimeSetupController;
const { renderRuntimeSetupHtml } = require('../host/extensions/dbcode-wrapper-profile-migration/runtimeSetupView.js');

test('runtime setup exposes only its maintained verifier interface', () => {
  assert.deepEqual(Object.keys(openVsxPackageVerifier).sort(), [
    'createOpenVsxRuntimeConfiguration',
    'requireOfficialUrl',
    'resolveOpenVsxPublicKeyPath',
    'selectOpenVsxPackageRecord',
    'validateInstalledOpenVsxExtension',
    'validateOpenVsxRuntimeConfiguration',
    'verifyOpenVsxPackage'
  ]);
});

test('runtime setup exposes only its maintained setup interface', () => {
  assert.deepEqual(Object.keys(runtimeSetup).sort(), [
    'acquireAndVerifyPackage',
    'assertManagedRuntimeInstalled',
    'missingRuntimePackages',
    'validateRuntimeConfiguration'
  ]);
});

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function fixture() {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
  const publicKeyPem = publicKey.export({ type: 'spki', format: 'pem' });
  const vsix = Buffer.from('synthetic verified VSIX');
  const signatureArchive = Buffer.from('synthetic signature archive');
  const signature = crypto.sign(null, vsix, privateKey);
  const packageRecord = {
    role: 'database-client',
    namespace: 'dbcode',
    name: 'dbcode',
    id: 'dbcode.dbcode',
    publisher: 'dbcode',
    version: '1.36.2',
    engine: '^1.95.0',
    target_platform: 'universal',
    published_at: '2026-07-20T04:51:39.562360Z',
    verified_publisher: true,
    pre_release: false,
    deprecated: false,
    registry_api_url: 'https://open-vsx.org/api/dbcode/dbcode/1.36.2',
    download_url: 'https://open-vsx.org/api/dbcode/dbcode/1.36.2/file/dbcode.dbcode-1.36.2.vsix',
    signature_url: 'https://open-vsx.org/api/dbcode/dbcode/1.36.2/file/dbcode.dbcode-1.36.2.sigzip',
    sha256_url: 'https://open-vsx.org/api/dbcode/dbcode/1.36.2/file/dbcode.dbcode-1.36.2.sha256',
    public_key_id: 'fixture-key',
    public_key_url: 'https://open-vsx.org/api/-/public-key/fixture-key',
    sha256: sha256(vsix),
    signature_archive_sha256: sha256(signatureArchive),
    public_key_sha256: sha256(publicKeyPem),
    package_size: vsix.length
  };
  const configuration = {
    schema_version: 1,
    setup: 'focused-pinned-official-sources',
    code_oss_version: '1.126.0',
    application_name: 'dbcode-wrapper',
    packages: [packageRecord],
    public_keys: [{
      id: packageRecord.public_key_id,
      sha256: packageRecord.public_key_sha256,
      pem: publicKeyPem.toString('utf8')
    }]
  };
  const registryRecord = {
    namespace: packageRecord.namespace,
    name: packageRecord.name,
    version: packageRecord.version,
    engines: { vscode: packageRecord.engine },
    targetPlatform: packageRecord.target_platform,
    timestamp: packageRecord.published_at,
    verified: true,
    preRelease: false,
    deprecated: false,
    files: {
      download: packageRecord.download_url,
      signature: packageRecord.signature_url,
      sha256: packageRecord.sha256_url,
      publicKey: packageRecord.public_key_url
    }
  };
  const signatureManifest = Buffer.from(JSON.stringify({
    package: {
      digests: { sha256: Buffer.from(packageRecord.sha256, 'hex').toString('base64') },
      size: packageRecord.package_size
    }
  }));
  const extensionManifest = Buffer.from(JSON.stringify({
    publisher: packageRecord.publisher,
    name: packageRecord.name,
    version: packageRecord.version,
    engines: { vscode: packageRecord.engine }
  }));
  const acquisition = {
    registryRecord,
    vsix,
    signatureArchive,
    sha256Record: Buffer.from(`${packageRecord.sha256}\n`),
    publicKey: Buffer.from(publicKeyPem)
  };
  const signatureEntries = [
    { name: '.signature.sig', body: signature },
    { name: '.signature.manifest', body: signatureManifest },
    { name: '.signature.p7s', body: Buffer.from('unused compatibility record') }
  ];
  const vsixEntries = [
    { name: 'extension/package.json', body: extensionManifest }
  ];
  const readZipEntries = async (archive, names) => {
    if (archive === signatureArchive) {
      assert.deepEqual(names.sort(), ['.signature.manifest', '.signature.p7s', '.signature.sig']);
      return new Map(signatureEntries.map(entry => [entry.name, entry.body]));
    }
    assert.equal(archive, vsix);
    assert.deepEqual(names, ['extension/package.json']);
    return new Map(vsixEntries.map(entry => [entry.name, entry.body]));
  };
  const fromBuffer = (archive, options, callback) => {
    if (archive.equals(acquisition.signatureArchive)) {
      fakeZip(signatureEntries)(archive, options, callback);
      return;
    }
    if (archive.equals(acquisition.vsix)) {
      fakeZip(vsixEntries)(archive, options, callback);
      return;
    }
    callback(new Error('Unexpected synthetic archive.'));
  };
  return {
    acquisition,
    codeOssVersion: configuration.code_oss_version,
    configuration,
    fromBuffer,
    packageRecord,
    pinnedPublicKey: Buffer.from(publicKeyPem),
    readZipEntries,
    signatureEntries,
    vsixEntries
  };
}

function fakeHttps(routes) {
  return (url, _options, callback) => {
    const request = new EventEmitter();
    request.destroy = error => {
      if (error) {
        queueMicrotask(() => request.emit('error', error));
      }
    };
    queueMicrotask(() => {
      const route = routes.get(url);
      if (!route) {
        request.emit('error', new Error(`Unexpected fixture URL: ${url}`));
        return;
      }
      const response = new EventEmitter();
      response.statusCode = route.statusCode;
      response.headers = route.headers ?? {};
      response.resume = () => undefined;
      callback(response);
      queueMicrotask(() => {
        if (route.body) {
          response.emit('data', route.body);
        }
        response.emit('end');
      });
    });
    return request;
  };
}

function fakeZip(entries) {
  return (_archive, options, callback) => {
    assert.equal(options.lazyEntries, true);
    const zipFile = new EventEmitter();
    let index = 0;
    zipFile.close = () => undefined;
    zipFile.readEntry = () => queueMicrotask(() => {
      if (index >= entries.length) {
        zipFile.emit('end');
        return;
      }
      const fixtureEntry = entries[index];
      index += 1;
      zipFile.emit('entry', {
        fileName: fixtureEntry.name,
        uncompressedSize: fixtureEntry.size ?? fixtureEntry.body.length,
        externalFileAttributes: fixtureEntry.externalFileAttributes,
        generalPurposeBitFlag: fixtureEntry.generalPurposeBitFlag,
        versionMadeBy: fixtureEntry.versionMadeBy,
        fixtureBody: fixtureEntry.body
      });
    });
    zipFile.openReadStream = (entry, streamCallback) => {
      streamCallback(null, Readable.from([entry.fixtureBody]));
    };
    callback(null, zipFile);
  };
}

function runPackageFileAdapter(args, cwd) {
  return new Promise(resolve => {
    execFile(
      process.execPath,
      [path.join(SCRIPT_ROOT, 'verify_openvsx_package.cjs'), ...args],
      {
        cwd,
        killSignal: 'SIGKILL',
        maxBuffer: 1024 * 1024,
        timeout: 5_000
      },
      (error, stdout, stderr) => {
        resolve({
          code: error?.code ?? 0,
          stderr,
          stdout
        });
      }
    );
  });
}

function packageFileAdapterZipStub(state) {
  const archives = Object.fromEntries([
    [state.acquisition.signatureArchive, state.signatureEntries],
    [state.acquisition.vsix, state.vsixEntries]
  ].map(([archive, entries]) => [
    archive.toString('base64'),
    entries.map(entry => ({
      body: entry.body.toString('base64'),
      name: entry.name
    }))
  ]));
  return `'use strict';
const { EventEmitter } = require('node:events');
const { Readable } = require('node:stream');
const archives = ${JSON.stringify(archives)};
exports.fromBuffer = (archive, options, callback) => {
  const encodedEntries = archives[archive.toString('base64')];
  if (!encodedEntries || options?.lazyEntries !== true) {
    callback(new Error('Unexpected synthetic archive.'));
    return;
  }
  const entries = encodedEntries.map(entry => ({
    body: Buffer.from(entry.body, 'base64'),
    fileName: entry.name
  }));
  const zipFile = new EventEmitter();
  let index = 0;
  zipFile.close = () => undefined;
  zipFile.readEntry = () => queueMicrotask(() => {
    if (index >= entries.length) {
      zipFile.emit('end');
      return;
    }
    const entry = entries[index++];
    zipFile.emit('entry', {
      fileName: entry.fileName,
      uncompressedSize: entry.body.length,
      fixtureBody: entry.body
    });
  });
  zipFile.openReadStream = (entry, streamCallback) => {
    streamCallback(null, Readable.from([entry.fixtureBody]));
  };
  callback(null, zipFile);
};
`;
}

async function populatePackageFileAdapterFixture(testRoot, state) {
  const packageRoot = path.join(testRoot, 'package with spaces');
  const keyRoot = path.join(testRoot, 'approved keys');
  const zipModule = path.join(testRoot, 'synthetic-yauzl.cjs');
  await Promise.all([
    fs.mkdir(packageRoot, { recursive: true }),
    fs.mkdir(keyRoot, { recursive: true })
  ]);
  await Promise.all([
    fs.writeFile(
      path.join(packageRoot, 'registry.json'),
      JSON.stringify(state.acquisition.registryRecord)
    ),
    fs.writeFile(path.join(packageRoot, 'package.vsix'), state.acquisition.vsix),
    fs.writeFile(
      path.join(packageRoot, 'signature.sigzip'),
      state.acquisition.signatureArchive
    ),
    fs.writeFile(path.join(packageRoot, 'package.sha256'), state.acquisition.sha256Record),
    fs.writeFile(path.join(packageRoot, 'openvsx-public-key.pem'), state.acquisition.publicKey),
    fs.writeFile(
      path.join(keyRoot, `openvsx-${state.packageRecord.public_key_id}.pem`),
      state.pinnedPublicKey
    ),
    fs.writeFile(zipModule, packageFileAdapterZipStub(state))
  ]);
  return {
    args: [
      state.packageRecord.id,
      packageRoot,
      state.codeOssVersion,
      JSON.stringify([state.packageRecord]),
      keyRoot,
      zipModule
    ],
    packageRoot,
    relativeArgs: [
      state.packageRecord.id,
      path.basename(packageRoot),
      state.codeOssVersion,
      JSON.stringify([state.packageRecord]),
      path.basename(keyRoot),
      path.basename(zipModule)
    ],
    testRoot
  };
}

async function createPackageFileAdapterFixture(state) {
  const testRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'dbcode Open VSX adapter '));
  try {
    return await populatePackageFileAdapterFixture(testRoot, state);
  } catch (error) {
    try {
      await fs.rm(testRoot, { recursive: true, force: true });
    } catch {
      // The fixture-creation error is the useful failure to report.
    }
    throw error;
  }
}

function acquisitionRoutes(state, overrides = new Map()) {
  const routes = new Map([
    [state.packageRecord.registry_api_url, {
      statusCode: 200,
      body: Buffer.from(JSON.stringify(state.acquisition.registryRecord))
    }],
    [state.packageRecord.download_url, {
      statusCode: 200,
      body: state.acquisition.vsix
    }],
    [state.packageRecord.signature_url, {
      statusCode: 200,
      body: state.acquisition.signatureArchive
    }],
    [state.packageRecord.sha256_url, {
      statusCode: 200,
      body: state.acquisition.sha256Record
    }],
    [state.packageRecord.public_key_url, {
      statusCode: 200,
      body: state.acquisition.publicKey
    }]
  ]);
  for (const [url, route] of overrides) {
    routes.set(url, route);
  }
  return routes;
}

async function verifyThroughMaintainedInterface(state, verifierOptions) {
  return verifyOpenVsxPackage(
    {
      codeOssVersion: state.codeOssVersion,
      packageRecord: state.packageRecord,
      acquisition: state.acquisition,
      publicKeys: state.configuration.public_keys
    },
    verifierOptions ?? { fromBuffer: state.fromBuffer }
  );
}

async function assertMaintainedVerifierRejects(mutate, expected, label) {
  const state = fixture();
  mutate(state);
  await assert.rejects(
    verifyThroughMaintainedInterface(state),
    expected,
    `The maintained Open VSX verifier accepted ${label}`
  );
}

function replaceArchiveEntry(entries, name, body) {
  const entry = entries.find(candidate => candidate.name === name);
  assert.ok(entry, `Missing synthetic archive entry: ${name}`);
  entry.body = body;
}

test('runtime setup accepts one exact pinned Open VSX package', async () => {
  const state = fixture();
  assert.deepEqual(
    validateOpenVsxRuntimeConfiguration(state.configuration),
    state.configuration
  );
  assert.deepEqual(validateRuntimeConfiguration(state.configuration), state.configuration);
  await assert.doesNotReject(verifyThroughMaintainedInterface(state));
});

test('the package-file adapter accepts plain files and rejects linked inputs', async () => {
  const adapterFixture = await createPackageFileAdapterFixture(fixture());
  try {
    const accepted = await runPackageFileAdapter(adapterFixture.args);
    assert.equal(accepted.code, 0, accepted.stderr);
    assert.match(accepted.stdout, /Verified dbcode\.dbcode@1\.36\.2/);

    const acceptedRelative = await runPackageFileAdapter(
      adapterFixture.relativeArgs,
      adapterFixture.testRoot
    );
    assert.equal(acceptedRelative.code, 0, acceptedRelative.stderr);

    const linkedRoot = path.join(adapterFixture.testRoot, 'linked package root');
    await fs.symlink(adapterFixture.packageRoot, linkedRoot, 'dir');
    const linkedRootResult = await runPackageFileAdapter([
      ...adapterFixture.args.slice(0, 1),
      linkedRoot,
      ...adapterFixture.args.slice(2)
    ]);
    assert.equal(linkedRootResult.code, 1);
    assert.match(linkedRootResult.stderr, /acquisition root is unsafe/i);

    const vsixPath = path.join(adapterFixture.packageRoot, 'package.vsix');
    const plainVsixPath = path.join(adapterFixture.testRoot, 'plain-package.vsix');
    await fs.rename(vsixPath, plainVsixPath);
    await fs.symlink(plainVsixPath, vsixPath);
    const linkedArtifactResult = await runPackageFileAdapter(adapterFixture.args);
    assert.equal(linkedArtifactResult.code, 1);
    assert.match(linkedArtifactResult.stderr, /unsafe VSIX/i);
  } finally {
    await fs.rm(adapterFixture.testRoot, { recursive: true, force: true });
  }
});

test('the shared verifier selects one canonical package record', () => {
  const { configuration, packageRecord } = fixture();
  assert.deepEqual(
    selectOpenVsxPackageRecord(configuration.packages, packageRecord.id),
    packageRecord
  );
  assert.throws(
    () => selectOpenVsxPackageRecord(
      [...configuration.packages, packageRecord],
      packageRecord.id
    ),
    /no unique package/i
  );
});

test('the shared verifier validates installed Open VSX identities', () => {
  assert.deepEqual(
    validateInstalledOpenVsxExtension({ id: 'dbcode.dbcode', version: '1.36.6' }),
    { id: 'dbcode.dbcode', version: '1.36.6' }
  );
  assert.throws(
    () => validateInstalledOpenVsxExtension({ id: '../dbcode', version: '1.36.6' }),
    /installed extension inventory/i
  );
});

test('runtime setup binds every embedded public key to the package digest', () => {
  const { configuration } = fixture();
  const replacementKey = crypto.generateKeyPairSync('ed25519').publicKey
    .export({ type: 'spki', format: 'pem' });
  const changedConfiguration = {
    ...configuration,
    public_keys: [{
      id: configuration.public_keys[0].id,
      sha256: sha256(replacementKey),
      pem: replacementKey.toString('utf8')
    }]
  };
  assert.throws(
    () => validateRuntimeConfiguration(changedConfiguration),
    /not bound to its approved public key/i
  );
});

test('runtime setup rejects registry or package bytes that differ from the pinned set', async () => {
  const changedRegistry = fixture();
  changedRegistry.acquisition.registryRecord = {
    ...changedRegistry.acquisition.registryRecord,
    version: '1.36.3'
  };
  await assert.rejects(
    verifyThroughMaintainedInterface(changedRegistry),
    /registry record/i
  );

  const changedPackage = fixture();
  changedPackage.acquisition.vsix = Buffer.from('changed package');
  await assert.rejects(
    verifyThroughMaintainedInterface(changedPackage),
    /VSIX.*SHA-256/i
  );
});

test('runtime setup rejects a pinned package that needs a newer Code OSS host', async () => {
  const { acquisition, configuration, packageRecord, readZipEntries } = fixture();
  const incompatibleEngine = '^1.127.0';
  const incompatiblePackage = {
    ...packageRecord,
    engine: incompatibleEngine
  };
  const incompatibleAcquisition = {
    ...acquisition,
    registryRecord: {
      ...acquisition.registryRecord,
      engines: { vscode: incompatibleEngine }
    }
  };
  const incompatibleZipReader = async (archive, names) => {
    const entries = await readZipEntries(archive, names);
    if (archive !== acquisition.vsix) {
      return entries;
    }
    return new Map([[
      'extension/package.json',
      Buffer.from(JSON.stringify({
        publisher: incompatiblePackage.publisher,
        name: incompatiblePackage.name,
        version: incompatiblePackage.version,
        engines: { vscode: incompatibleEngine }
      }))
    ]]);
  };

  await assert.rejects(verifyOpenVsxPackage(
    {
      codeOssVersion: configuration.code_oss_version,
      packageRecord: incompatiblePackage,
      acquisition: incompatibleAcquisition,
      publicKeys: configuration.public_keys
    },
    { readZipEntries: incompatibleZipReader }
  ),
    /not compatible with Code OSS/i
  );
});

test('the maintained Open VSX verifier accepts the exact package', async () => {
  await assert.doesNotReject(verifyThroughMaintainedInterface(fixture()));
});

test('the maintained Open VSX verifier rejects every changed registry invariant', async () => {
  const mutations = [
    ['namespace', state => { state.acquisition.registryRecord.namespace = 'changed'; }],
    ['name', state => { state.acquisition.registryRecord.name = 'changed'; }],
    ['version', state => { state.acquisition.registryRecord.version = '9.9.9'; }],
    ['engine', state => { state.acquisition.registryRecord.engines.vscode = '^9.0.0'; }],
    ['target platform', state => { state.acquisition.registryRecord.targetPlatform = 'darwin-arm64'; }],
    ['timestamp', state => { state.acquisition.registryRecord.timestamp = '2026-01-01T00:00:00Z'; }],
    ['verified publisher', state => { state.acquisition.registryRecord.verified = false; }],
    ['pre-release status', state => { state.acquisition.registryRecord.preRelease = true; }],
    ['deprecation status', state => { state.acquisition.registryRecord.deprecated = true; }],
    ['download URL', state => { state.acquisition.registryRecord.files.download += '.changed'; }],
    ['signature URL', state => { state.acquisition.registryRecord.files.signature += '.changed'; }],
    ['SHA-256 URL', state => { state.acquisition.registryRecord.files.sha256 += '.changed'; }],
    ['public-key URL', state => { state.acquisition.registryRecord.files.publicKey += '.changed'; }]
  ];
  for (const [label, mutate] of mutations) {
    await assertMaintainedVerifierRejects(mutate, /registry record/i, label);
  }
});

test('the maintained Open VSX verifier rejects changed digests, sizes, and keys', async () => {
  const replacementKey = () => crypto.generateKeyPairSync('ed25519').publicKey
    .export({ type: 'spki', format: 'pem' });
  const mutations = [
    ['pinned VSIX digest', state => { state.packageRecord.sha256 = '0'.repeat(64); }, /VSIX SHA-256/i],
    [
      'pinned signature-archive digest',
      state => { state.packageRecord.signature_archive_sha256 = '0'.repeat(64); },
      /signature archive/i
    ],
    [
      'pinned public-key digest',
      state => { state.packageRecord.public_key_sha256 = '0'.repeat(64); },
      /public key/i
    ],
    [
      'unsafe public-key identity',
      state => { state.packageRecord.public_key_id = '../fixture-key'; },
      /public.key|package record/i
    ],
    ['downloaded VSIX bytes', state => { state.acquisition.vsix = Buffer.from('changed'); }, /VSIX SHA-256/i],
    [
      'downloaded signature archive',
      state => { state.acquisition.signatureArchive = Buffer.from('changed'); },
      /signature archive/i
    ],
    [
      'official SHA-256 record',
      state => { state.acquisition.sha256Record = Buffer.from(`${'0'.repeat(64)}\n`); },
      /official SHA-256 record/i
    ],
    [
      'downloaded public key',
      state => { state.acquisition.publicKey = replacementKey(); },
      /public key/i
    ],
    [
      'pinned public key',
      state => {
        const pem = replacementKey();
        state.pinnedPublicKey = Buffer.from(pem);
        state.configuration.public_keys[0].pem = pem.toString('utf8');
      },
      /public key/i
    ],
    [
      'pinned package size',
      state => { state.packageRecord.package_size += 1; },
      /VSIX size/i
    ]
  ];
  for (const [label, mutate, expected] of mutations) {
    await assertMaintainedVerifierRejects(mutate, expected, label);
  }
});

test('the maintained Open VSX verifier rejects changed signatures and signature manifests', async () => {
  const mutations = [
    [
      'wrong-length Ed25519 signature',
      state => replaceArchiveEntry(
        state.signatureEntries,
        '.signature.sig',
        Buffer.alloc(63)
      ),
      /signature.*invalid size/i
    ],
    [
      'invalid Ed25519 signature',
      state => replaceArchiveEntry(
        state.signatureEntries,
        '.signature.sig',
        Buffer.alloc(64)
      ),
      /signature did not verify/i
    ],
    [
      'invalid signature manifest JSON',
      state => replaceArchiveEntry(
        state.signatureEntries,
        '.signature.manifest',
        Buffer.from('{')
      ),
      /signature manifest.*JSON/i
    ],
    [
      'signature-manifest digest',
      state => replaceArchiveEntry(
        state.signatureEntries,
        '.signature.manifest',
        Buffer.from(JSON.stringify({
          package: {
            digests: { sha256: Buffer.alloc(32).toString('base64') },
            size: state.packageRecord.package_size
          }
        }))
      ),
      /signature manifest does not identify/i
    ],
    [
      'signature-manifest size',
      state => replaceArchiveEntry(
        state.signatureEntries,
        '.signature.manifest',
        Buffer.from(JSON.stringify({
          package: {
            digests: {
              sha256: Buffer.from(state.packageRecord.sha256, 'hex').toString('base64')
            },
            size: state.packageRecord.package_size + 1
          }
        }))
      ),
      /signature manifest does not identify/i
    ]
  ];
  for (const [label, mutate, expected] of mutations) {
    await assertMaintainedVerifierRejects(mutate, expected, label);
  }
});

test('the maintained Open VSX verifier rejects unsafe or incomplete archives', async () => {
  const mutations = [
    [
      'parent traversal entry',
      state => state.signatureEntries.push({
        name: '../outside',
        body: Buffer.from('unsafe')
      })
    ],
    [
      'duplicate required entry',
      state => state.signatureEntries.push({
        name: '.signature.sig',
        body: Buffer.alloc(64)
      })
    ],
    [
      'duplicate unrelated entry',
      state => state.signatureEntries.push(
        { name: 'extra.txt', body: Buffer.from('one') },
        { name: 'extra.txt', body: Buffer.from('two') }
      )
    ],
    [
      'encrypted entry',
      state => {
        state.signatureEntries[0].generalPurposeBitFlag = 1;
      }
    ],
    [
      'symbolic-link entry',
      state => state.signatureEntries.push({
        name: 'link',
        body: Buffer.from('target'),
        versionMadeBy: 3 << 8,
        externalFileAttributes: 0o120777 << 16
      })
    ],
    [
      'missing signature entry',
      state => {
        state.signatureEntries.splice(
          state.signatureEntries.findIndex(entry => entry.name === '.signature.p7s'),
          1
        );
      }
    ],
    [
      'oversized required entry',
      state => {
        const manifest = state.signatureEntries.find(
          entry => entry.name === '.signature.manifest'
        );
        manifest.size = (4 * 1024 * 1024) + 1;
      }
    ],
    [
      'oversized streamed entry',
      state => {
        const manifest = state.signatureEntries.find(
          entry => entry.name === '.signature.manifest'
        );
        manifest.body = Buffer.alloc((4 * 1024 * 1024) + 1);
        manifest.size = 2;
      }
    ]
  ];
  for (const [label, mutate] of mutations) {
    await assertMaintainedVerifierRejects(mutate, /archive|entry|required/i, label);
  }
});

test('the maintained verifier sanitizes archive-reader failures', async () => {
  const privatePath = '/private/example/package.sigzip';
  await assert.rejects(
    verifyThroughMaintainedInterface(fixture(), {
      fromBuffer: () => {
        throw new Error(privatePath);
      }
    }),
    error => {
      assert.match(error.message, /archive could not be opened/i);
      assert.doesNotMatch(error.message, new RegExp(privatePath));
      return true;
    }
  );
});

test('the maintained Open VSX verifier rejects every changed VSIX identity field', async () => {
  const mutations = [
    ['publisher', manifest => { manifest.publisher = 'changed'; }],
    ['name', manifest => { manifest.name = 'changed'; }],
    ['version', manifest => { manifest.version = '9.9.9'; }],
    ['engine', manifest => { manifest.engines.vscode = '^9.0.0'; }]
  ];
  for (const [label, mutateManifest] of mutations) {
    await assertMaintainedVerifierRejects(
      state => {
        const entry = state.vsixEntries.find(
          candidate => candidate.name === 'extension/package.json'
        );
        const manifest = JSON.parse(entry.body.toString('utf8'));
        mutateManifest(manifest);
        entry.body = Buffer.from(JSON.stringify(manifest));
      },
      /VSIX manifest does not identify/i,
      `VSIX ${label}`
    );
  }
});

test('runtime downloads follow bounded HTTPS redirects and reject oversized responses', async () => {
  const state = fixture();
  const officialUrl = state.packageRecord.download_url;
  const redirectedUrl = 'https://cdn.example.invalid/fixture';
  const acquire = request => acquireAndVerifyPackage(
    state.packageRecord,
    state.configuration.public_keys,
    state.codeOssVersion,
    { request, verify: async () => undefined }
  );
  const redirectedRoutes = acquisitionRoutes(state, new Map([
    [officialUrl, { statusCode: 302, headers: { location: redirectedUrl } }],
    [redirectedUrl, {
      statusCode: 200,
      headers: { 'content-length': String(state.acquisition.vsix.length) },
      body: state.acquisition.vsix
    }]
  ]));
  assert.deepEqual(
    await acquire(fakeHttps(redirectedRoutes)),
    state.acquisition.vsix
  );

  const oversizedRoutes = acquisitionRoutes(state, new Map([
    [officialUrl, {
      statusCode: 200,
      headers: { 'content-length': String(state.packageRecord.package_size + 1) },
      body: Buffer.alloc(state.packageRecord.package_size + 1)
    }]
  ]));
  await assert.rejects(
    acquire(fakeHttps(oversizedRoutes)),
    /exceeded its pinned size limit/i
  );

  const streamedOversizeRoutes = acquisitionRoutes(state, new Map([
    [officialUrl, {
      statusCode: 200,
      body: Buffer.alloc(state.packageRecord.package_size + 1)
    }]
  ]));
  await assert.rejects(
    acquire(fakeHttps(streamedOversizeRoutes)),
    /exceeded its pinned size limit/i
  );

  const downgradeRoutes = acquisitionRoutes(state, new Map([
    [officialUrl, {
      statusCode: 302,
      headers: { location: 'http://open-vsx.org/insecure' }
    }]
  ]));
  await assert.rejects(
    acquire(fakeHttps(downgradeRoutes)),
    /outside HTTPS/i
  );

  const redirectRoutes = acquisitionRoutes(state);
  redirectRoutes.set(officialUrl, {
    statusCode: 302,
    headers: { location: 'https://redirect.example.invalid/1' }
  });
  for (let index = 1; index <= 5; index += 1) {
    redirectRoutes.set(`https://redirect.example.invalid/${index}`, {
      statusCode: 302,
      headers: { location: `https://redirect.example.invalid/${index + 1}` }
    });
  }
  await assert.rejects(
    acquire(fakeHttps(redirectRoutes)),
    /too many redirects/i
  );
});

test('runtime acquisition composes all five pinned downloads before verification', async () => {
  const state = fixture();
  const calls = [];
  let verified = false;
  const fixtureRequest = fakeHttps(acquisitionRoutes(state));
  const request = (url, options, callback) => {
    calls.push(url);
    return fixtureRequest(url, options, callback);
  };
  const result = await acquireAndVerifyPackage(
    state.packageRecord,
    state.configuration.public_keys,
    state.codeOssVersion,
    {
      request,
      verify: async input => {
        assert.equal(input.packageRecord, state.packageRecord);
        assert.deepEqual(input.acquisition, state.acquisition);
        assert.equal(input.publicKeys, state.configuration.public_keys);
        assert.equal(input.codeOssVersion, state.codeOssVersion);
        verified = true;
      }
    }
  );
  assert.deepEqual(result, state.acquisition.vsix);
  assert.equal(verified, true);
  assert.deepEqual(calls, [
    state.packageRecord.registry_api_url,
    state.packageRecord.download_url,
    state.packageRecord.signature_url,
    state.packageRecord.sha256_url,
    state.packageRecord.public_key_url
  ]);
});

test('runtime setup derives work only from exact installed versions', () => {
  const { configuration } = fixture();
  assert.deepEqual(missingRuntimePackages(configuration, []), configuration.packages);
  assert.deepEqual(
    missingRuntimePackages(configuration, [{ id: 'dbcode.dbcode', version: '1.36.2' }]),
    []
  );
  assert.throws(
    () => assertManagedRuntimeInstalled(configuration, [{ id: 'dbcode.dbcode', version: '1.36.1' }]),
    /does not exactly match the pinned runtime/i
  );
  assert.doesNotThrow(
    () => assertManagedRuntimeInstalled(configuration, [{ id: 'dbcode.dbcode', version: '1.36.2' }])
  );
  assert.throws(
    () => assertManagedRuntimeInstalled(configuration, [
      { id: 'dbcode.dbcode', version: '1.36.2' },
      { id: 'unrelated.extension', version: '9.9.9' }
    ]),
    /does not exactly match/i
  );
});

test('startup checks only the exact external profile inventory through the controller', () => {
  const { configuration } = fixture();
  const extensionsRoot = '/private/profile/extensions';
  const vscode = {
    env: { appRoot: '/Applications/DBCode Wrapper.app/Contents/Resources/app' },
    extensions: {
      all: [
      {
        id: 'DBCode.DBCode',
        extensionPath: `${extensionsRoot}/dbcode.dbcode-1.36.2`,
        packageJSON: { version: '1.36.2' }
      },
      {
        id: 'vscode.sql',
        extensionPath: '/Applications/DBCode Wrapper.app/Contents/Resources/app/extensions/sql',
        packageJSON: { version: '1.0.0' }
      }
      ]
    }
  };
  const controller = new RuntimeSetupController({
    context: { globalStorageUri: { fsPath: '/private/profile/storage' } },
    vscode,
    layout: {
      userDataRoot: '/private/profile/user-data',
      extensionsRoot,
      sharedDataRoot: '/private/profile/shared-data'
    },
    configuration
  });
  assert.equal(controller.requiresSetup(), false);
  vscode.extensions.all[0].extensionPath = '/Applications/DBCode Wrapper.app/Contents/Resources/app/extensions/dbcode';
  assert.equal(controller.requiresSetup(), true);
});

test('first run presents one focused setup action without a marketplace', () => {
  const page = renderRuntimeSetupHtml({
    kind: 'welcome',
    packageCount: 7,
    dbcodeVersion: '1.36.2'
  });
  assert.match(page, /Set up DBCode Wrapper/);
  assert.match(page, /seven pinned packages|7 pinned packages/i);
  assert.match(page, /data-action="install-runtime"/);
  assert.doesNotMatch(page, /marketplace|browse extensions|search extensions/i);
});

test('a failed setup reports an incomplete verified set instead of claiming no change', () => {
  const page = renderRuntimeSetupHtml({
    kind: 'failure',
    message: 'The official package request timed out.'
  });
  assert.match(page, /setup is incomplete/i);
  assert.match(page, /installed by this setup came from the same verified set/i);
  assert.doesNotMatch(page, /was not changed/i);
});

test('the focused controller installs verified files with the exact private profile arguments', async () => {
  const { configuration } = fixture();
  const testRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'dbcode-runtime-controller-'));
  const appRoot = path.join(testRoot, 'DBCode Wrapper.app/Contents/Resources/app');
  const cli = path.join(appRoot, 'bin/dbcode-wrapper');
  const globalStorage = path.join(testRoot, 'user-data/User/globalStorage/dbcode-wrapper.profile-migration');
  const calls = [];
  let html = '';
  try {
    await fs.mkdir(path.dirname(cli), { recursive: true });
    await fs.writeFile(cli, '#!/bin/sh\nexit 0\n', { mode: 0o700 });
    await fs.mkdir(globalStorage, { recursive: true });
    const panel = {
      webview: {
        set html(value) { html = value; },
        get html() { return html; },
        onDidReceiveMessage() {}
      },
      onDidDispose() {},
      reveal() {}
    };
    const vscode = {
      ViewColumn: { Active: 1 },
      env: { appRoot },
      extensions: { all: [] },
      window: { createWebviewPanel: () => panel },
      commands: { executeCommand: async () => undefined }
    };
    const controller = new RuntimeSetupController({
      context: {
        extensionPath: testRoot,
        globalStorageUri: { fsPath: globalStorage },
        subscriptions: []
      },
      vscode,
      layout: {
        userDataRoot: path.join(testRoot, 'user-data'),
        extensionsRoot: path.join(testRoot, 'extensions'),
        sharedDataRoot: path.join(testRoot, 'shared-data')
      },
      configuration,
      acquirePackage: async () => Buffer.from('verified fixture VSIX'),
      executeCli: async (_executable, args) => {
        calls.push(args);
        return args.includes('--list-extensions') ? 'dbcode.dbcode@1.36.2\n' : '';
      }
    });

    controller.open();
    await controller.install();

    assert.equal(calls.length, 2);
    assert.ok(calls[0].includes('--install-extension'));
    assert.ok(calls[0].includes('--do-not-include-pack-dependencies'));
    assert.ok(calls[0].includes('--force'));
    assert.deepEqual(
      calls[0].slice(0, 8),
      [
        '--user-data-dir', path.join(testRoot, 'user-data'),
        '--extensions-dir', path.join(testRoot, 'extensions'),
        '--shared-data-dir', path.join(testRoot, 'shared-data'),
        '--disable-updates',
        '--install-extension'
      ]
    );
    assert.match(html, /DBCode Wrapper is ready/);
    controller.executeCli = async (_executable, args) => (
      args.includes('--list-extensions') ? 'not-an-extension-record\n' : ''
    );
    await controller.install();
    assert.match(html, /invalid installed-extension inventory/i);
  } finally {
    await fs.rm(testRoot, { recursive: true, force: true });
  }
});
