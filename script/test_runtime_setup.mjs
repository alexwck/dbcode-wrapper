#!/usr/bin/env node

import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { EventEmitter } from 'node:events';
import fs from 'node:fs/promises';
import { createRequire } from 'node:module';
import os from 'node:os';
import path from 'node:path';
import { Readable } from 'node:stream';
import test from 'node:test';

const require = createRequire(import.meta.url);
const {
  acquireAndVerifyPackage,
  assertManagedRuntimeInstalled,
  downloadBuffer,
  missingRuntimePackages,
  readZipEntries,
  validateRuntimeConfiguration,
  verifyPackageAcquisition
} = require('../host/extensions/dbcode-wrapper-profile-migration/runtimeSetup.js');
const {
  RuntimeSetupController,
  extensionInventory,
  parseCliInventory
} = require('../host/extensions/dbcode-wrapper-profile-migration/runtimeSetupController.js');
const { renderRuntimeSetupHtml } = require('../host/extensions/dbcode-wrapper-profile-migration/runtimeSetupView.js');

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
  const readZipEntries = async (archive, names) => {
    if (archive === signatureArchive) {
      assert.deepEqual(names.sort(), ['.signature.manifest', '.signature.p7s', '.signature.sig']);
      return new Map([
        ['.signature.sig', signature],
        ['.signature.manifest', signatureManifest],
        ['.signature.p7s', Buffer.from('unused compatibility record')]
      ]);
    }
    assert.equal(archive, vsix);
    assert.deepEqual(names, ['extension/package.json']);
    return new Map([['extension/package.json', extensionManifest]]);
  };
  return { acquisition, configuration, packageRecord, readZipEntries };
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
        fixtureBody: fixtureEntry.body
      });
    });
    zipFile.openReadStream = (entry, streamCallback) => {
      streamCallback(null, Readable.from([entry.fixtureBody]));
    };
    callback(null, zipFile);
  };
}

test('runtime setup accepts one exact pinned Open VSX package', async () => {
  const { acquisition, configuration, packageRecord, readZipEntries } = fixture();
  assert.deepEqual(validateRuntimeConfiguration(configuration), configuration);
  await assert.doesNotReject(verifyPackageAcquisition(
    packageRecord,
    acquisition,
    configuration.public_keys,
    { readZipEntries }
  ));
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
  const { acquisition, configuration, packageRecord, readZipEntries } = fixture();
  await assert.rejects(
    verifyPackageAcquisition(
      packageRecord,
      {
        ...acquisition,
        registryRecord: { ...acquisition.registryRecord, version: '1.36.3' }
      },
      configuration.public_keys,
      { readZipEntries }
    ),
    /registry record/i
  );
  await assert.rejects(
    verifyPackageAcquisition(
      packageRecord,
      { ...acquisition, vsix: Buffer.from('changed package') },
      configuration.public_keys,
      { readZipEntries }
    ),
    /VSIX.*SHA-256/i
  );
});

test('runtime downloads follow bounded HTTPS redirects and reject oversized responses', async () => {
  const officialUrl = 'https://open-vsx.org/api/fixture/package/1.0.0';
  const redirectedUrl = 'https://cdn.example.invalid/fixture';
  const request = fakeHttps(new Map([
    [officialUrl, {
      statusCode: 302,
      headers: { location: redirectedUrl }
    }],
    [redirectedUrl, {
      statusCode: 200,
      headers: { 'content-length': '7' },
      body: Buffer.from('fixture')
    }]
  ]));
  assert.equal(
    (await downloadBuffer(officialUrl, 7, 0, { request })).toString('utf8'),
    'fixture'
  );

  const oversizedRequest = fakeHttps(new Map([
    [officialUrl, {
      statusCode: 200,
      headers: { 'content-length': '8' },
      body: Buffer.from('oversize')
    }]
  ]));
  await assert.rejects(
    downloadBuffer(officialUrl, 7, 0, { request: oversizedRequest }),
    /exceeded its pinned size limit/i
  );

  const streamedOversizeRequest = fakeHttps(new Map([
    [officialUrl, {
      statusCode: 200,
      body: Buffer.from('oversize')
    }]
  ]));
  await assert.rejects(
    downloadBuffer(officialUrl, 7, 0, { request: streamedOversizeRequest }),
    /exceeded its pinned size limit/i
  );

  const downgradeRequest = fakeHttps(new Map([
    [officialUrl, {
      statusCode: 302,
      headers: { location: 'http://open-vsx.org/insecure' }
    }]
  ]));
  await assert.rejects(
    downloadBuffer(officialUrl, 7, 0, { request: downgradeRequest }),
    /outside HTTPS/i
  );

  const redirectRoutes = new Map();
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
    downloadBuffer(officialUrl, 7, 0, { request: fakeHttps(redirectRoutes) }),
    /too many redirects/i
  );
});

test('runtime ZIP reading enforces the requested entry set and size limit', async () => {
  const archive = Buffer.from('synthetic archive');
  const entries = await readZipEntries(
    archive,
    ['one.json', 'two.sig'],
    {
      fromBuffer: fakeZip([
        { name: 'ignored.txt', body: Buffer.from('ignored') },
        { name: 'one.json', body: Buffer.from('{}') },
        { name: 'two.sig', body: Buffer.alloc(64) }
      ])
    }
  );
  assert.equal(entries.get('one.json').toString('utf8'), '{}');
  assert.equal(entries.get('two.sig').length, 64);

  await assert.rejects(
    readZipEntries(
      archive,
      ['large.json'],
      {
        fromBuffer: fakeZip([{
          name: 'large.json',
          body: Buffer.from('{}'),
          size: (4 * 1024 * 1024) + 1
        }])
      }
    ),
    /unsafe required entry/i
  );

  await assert.rejects(
    readZipEntries(
      archive,
      ['large.json'],
      {
        fromBuffer: fakeZip([{
          name: 'large.json',
          body: Buffer.alloc((4 * 1024 * 1024) + 1),
          size: 2
        }])
      }
    ),
    /could not be read|too large/i
  );

  await assert.rejects(
    readZipEntries(
      archive,
      ['duplicate.json'],
      {
        fromBuffer: fakeZip([
          { name: 'duplicate.json', body: Buffer.from('{}') },
          { name: 'duplicate.json', body: Buffer.from('{}') }
        ])
      }
    ),
    /unsafe required entry/i
  );

  await assert.rejects(
    readZipEntries(
      archive,
      ['missing.json'],
      { fromBuffer: fakeZip([]) }
    ),
    /missing a required entry/i
  );
});

test('runtime acquisition composes all five pinned downloads before verification', async () => {
  const { acquisition, configuration, packageRecord } = fixture();
  const downloads = new Map([
    [packageRecord.registry_api_url, Buffer.from(JSON.stringify(acquisition.registryRecord))],
    [packageRecord.download_url, acquisition.vsix],
    [packageRecord.signature_url, acquisition.signatureArchive],
    [packageRecord.sha256_url, acquisition.sha256Record],
    [packageRecord.public_key_url, acquisition.publicKey]
  ]);
  const calls = [];
  let verified = false;
  const result = await acquireAndVerifyPackage(
    packageRecord,
    configuration.public_keys,
    {
      download: async (url, maximumBytes) => {
        calls.push([url, maximumBytes]);
        return downloads.get(url);
      },
      verify: async (record, downloaded, publicKeys) => {
        assert.equal(record, packageRecord);
        assert.deepEqual(downloaded, acquisition);
        assert.equal(publicKeys, configuration.public_keys);
        verified = true;
      }
    }
  );
  assert.equal(result, acquisition.vsix);
  assert.equal(verified, true);
  assert.deepEqual(calls, [
    [packageRecord.registry_api_url, 1024 * 1024],
    [packageRecord.download_url, packageRecord.package_size],
    [packageRecord.signature_url, 4 * 1024 * 1024],
    [packageRecord.sha256_url, 1024],
    [packageRecord.public_key_url, 64 * 1024]
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

test('startup checks only the exact external profile inventory', () => {
  const extensionsRoot = '/private/profile/extensions';
  assert.deepEqual(
    extensionInventory([
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
    ], extensionsRoot),
    [{ id: 'dbcode.dbcode', version: '1.36.2' }]
  );
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
    assert.deepEqual(parseCliInventory('dbcode.dbcode@1.36.2\n'), [
      { id: 'dbcode.dbcode', version: '1.36.2' }
    ]);
  } finally {
    await fs.rm(testRoot, { recursive: true, force: true });
  }
});
