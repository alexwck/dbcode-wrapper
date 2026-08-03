#!/usr/bin/env node

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const require = createRequire(import.meta.url);
const { createDisplayDocument } = require('../host/extensions/dbcode-wrapper-bson-viewer/ejson-display.js');
const bsonResultViewer = require('../host/extensions/dbcode-wrapper-bson-viewer/bson-result-viewer.js');
const { createBsonResultViewer } = bsonResultViewer;
const viewerWebview = require('../host/extensions/dbcode-wrapper-bson-viewer/viewer-webview.js');
const { renderViewerDocument } = viewerWebview;
const bsonViewerCommands = require('../host/extensions/dbcode-wrapper-bson-viewer/command-router.js');
const { registerBsonViewerCommands } = bsonViewerCommands;
const bsonViewerManifest = require('../host/extensions/dbcode-wrapper-bson-viewer/package.json');

function nodeAt(document, path) {
  const pending = [document.root];
  while (pending.length > 0) {
    const node = pending.shift();
    if (node.path === path) {
      return node;
    }
    pending.push(...node.children);
    if (node.embeddedJson) {
      pending.push(node.embeddedJson);
    }
  }
  assert.fail(`Missing display node: ${path}`);
}

test('canonical Extended JSON becomes readable values with separate BSON types', () => {
  const source = JSON.stringify([{
    requestedamount: { $numberInt: '0' },
    sequence: { $numberLong: '9223372036854775807' },
    ratio: { $numberDouble: '0.0' },
    price: { $numberDecimal: '1234567890.0123456789' },
    minimumDecimal: { $numberDecimal: '1E-6176' },
    maximumDecimal: { $numberDecimal: '9.999999999999999999999999999999999E+6144' },
    createdOn: { $date: { $numberLong: '946684800000' } },
    documentId: { $oid: '000000000000000000000123' },
    numericString: '0',
    escaped: '{"nested":{"$numberInt":"2"}}'
  }], null, 2);

  const document = createDisplayDocument(source);

  assert.equal(document.rawText, source);
  assert.equal('canonicalValue' in document.root, false);
  assert.equal(document.root.copyValue, undefined);
  assert.equal(nodeAt(document, '$[0].requestedamount').copyValue, '0');
  assert.deepEqual(
    ['requestedamount', 'sequence', 'ratio', 'price', 'minimumDecimal', 'maximumDecimal', 'documentId', 'numericString']
      .map(key => {
        const node = nodeAt(document, `$[0].${key}`);
        return [key, node.displayValue, node.type];
      }),
    [
      ['requestedamount', '0', 'Int32'],
      ['sequence', '9223372036854775807', 'Int64'],
      ['ratio', '0.0', 'Double'],
      ['price', '1234567890.0123456789', 'Decimal128'],
      ['minimumDecimal', '1E-6176', 'Decimal128'],
      ['maximumDecimal', '9.999999999999999999999999999999999E+6144', 'Decimal128'],
      ['documentId', '000000000000000000000123', 'ObjectId'],
      ['numericString', '0', 'String']
    ]
  );
  assert.equal(nodeAt(document, '$[0].createdOn').displayValue, '2000-01-01T00:00:00.000Z');
  assert.equal(nodeAt(document, '$[0].createdOn').type, 'Date');
  assert.equal(nodeAt(document, '$[0].escaped').type, 'String');
  assert.equal(nodeAt(document, '$[0].escaped').displayValue, '{"nested":{"$numberInt":"2"}}');
  assert.equal(document.embeddedJsonIncluded, false);
  assert.equal(nodeAt(document, '$[0].escaped').embeddedJson, undefined);

  const parsedDocument = createDisplayDocument(source, { parseEmbedded: true });
  assert.equal(parsedDocument.embeddedJsonIncluded, true);
  assert.equal(nodeAt(parsedDocument, '$[0].escaped').embeddedJson.type, 'Document');
  assert.equal(nodeAt(parsedDocument, '$[0].escaped{json}.nested').type, 'Int32');
  assert.equal(nodeAt(parsedDocument, '$[0].escaped{json}.nested').displayValue, '2');
});

test('JSON stored inside strings is parsed only after the optional mode is requested', () => {
  const source = JSON.stringify({
    escaped: JSON.stringify(Array.from({ length: 50_000 }, () => 0))
  });

  const document = createDisplayDocument(source);
  assert.equal(document.nodeCount, 2);
  assert.equal(document.embeddedJsonIncluded, false);
  assert.equal(nodeAt(document, '$.escaped').embeddedJson, undefined);
  assert.throws(
    () => createDisplayDocument(source, { parseEmbedded: true }),
    /more than the supported 50,000 values/
  );
});

test('ordinary JSON numbers retain their exact source spelling without precision loss', () => {
  const document = createDisplayDocument(
    '{"safeBoundary":9007199254740991,"unsafeInteger":9007199254740993,"decimal":0.1234567890123456789,"negativeZero":-0,"exponent":1e+30}'
  );

  assert.deepEqual(
    ['safeBoundary', 'unsafeInteger', 'decimal', 'negativeZero', 'exponent']
      .map(key => {
        const node = nodeAt(document, `$.${key}`);
        return [key, node.displayValue, node.copyValue, node.type];
      }),
    [
      ['safeBoundary', '9007199254740991', '9007199254740991', 'Number'],
      ['unsafeInteger', '9007199254740993', '9007199254740993', 'Number'],
      ['decimal', '0.1234567890123456789', '0.1234567890123456789', 'Number'],
      ['negativeZero', '-0', '-0', 'Number'],
      ['exponent', '1e+30', '1e+30', 'Number']
    ]
  );
});

test('other BSON scalars are typed only when the whole object is an exact Extended JSON wrapper', () => {
  const document = createDisplayDocument(JSON.stringify({
    binary: { $binary: { base64: 'AQID', subType: '00' } },
    oneDigitBinarySubtype: { $binary: { base64: 'AQID', subType: '0' } },
    timestamp: { $timestamp: { t: 42, i: 7 } },
    expression: { $regularExpression: { pattern: '^safe$', options: 'i' } },
    script: { $code: 'return value;', $scope: { value: 3 } },
    minimum: { $minKey: 1 },
    maximum: { $maxKey: 1 },
    uuid: { $uuid: '8f14e45f-ea1d-4a8c-9f2d-f2f80dfd7280' },
    oneDigitFractionDate: { $date: '2024-01-01T00:00:00.1Z' },
    twoDigitFractionDate: { $date: '2024-01-01T00:00:00.12Z' },
    malformedTimestamp: { $timestamp: { t: -1, i: 7 } },
    outOfRangeInt32: { $numberInt: '2147483648' },
    outOfRangeInt64: { $numberLong: '9223372036854775808' },
    invalidDouble: { $numberDouble: 'not-a-double' },
    invalidDecimal128: { $numberDecimal: 'not-a-decimal' },
    outOfRangeDecimal128: { $numberDecimal: '1E+6145' },
    invalidObjectId: { $oid: 'not-an-object-id' },
    invalidDate: { $date: 'not-a-date' },
    normalizedInvalidDate: { $date: '2024-02-30T00:00:00.000Z' },
    invalidBinary: { $binary: { base64: '***', subType: 'zz' } },
    invalidRegularExpression: { $regularExpression: { pattern: '^value$', options: 'z' } },
    duplicatedRegularExpressionOptions: { $regularExpression: { pattern: '^value$', options: 'ii' } },
    unsortedRegularExpressionOptions: { $regularExpression: { pattern: '^value$', options: 'mi' } },
    invalidUuid: { $uuid: 'not-a-uuid' },
    invalidScopedCode: { $code: 'return value;', $scope: 3 },
    ordinaryObject: { $numberInt: '4', explanation: 'not a wrapper' },
    malformedWrapper: { $numberInt: 4 }
  }));

  assert.deepEqual(
    ['binary', 'oneDigitBinarySubtype', 'timestamp', 'expression', 'script', 'minimum', 'maximum', 'uuid', 'oneDigitFractionDate', 'twoDigitFractionDate', 'malformedTimestamp', 'outOfRangeInt32', 'outOfRangeInt64', 'invalidDouble', 'invalidDecimal128', 'outOfRangeDecimal128', 'invalidObjectId', 'invalidDate', 'normalizedInvalidDate', 'invalidBinary', 'invalidRegularExpression', 'duplicatedRegularExpressionOptions', 'unsortedRegularExpressionOptions', 'invalidUuid', 'invalidScopedCode', 'ordinaryObject', 'malformedWrapper']
      .map(key => [key, nodeAt(document, `$.${key}`).type]),
    [
      ['binary', 'Binary'],
      ['oneDigitBinarySubtype', 'Binary'],
      ['timestamp', 'Timestamp'],
      ['expression', 'Regular Expression'],
      ['script', 'JavaScript with Scope'],
      ['minimum', 'MinKey'],
      ['maximum', 'MaxKey'],
      ['uuid', 'UUID'],
      ['oneDigitFractionDate', 'Date'],
      ['twoDigitFractionDate', 'Date'],
      ['malformedTimestamp', 'Document'],
      ['outOfRangeInt32', 'Document'],
      ['outOfRangeInt64', 'Document'],
      ['invalidDouble', 'Document'],
      ['invalidDecimal128', 'Document'],
      ['outOfRangeDecimal128', 'Document'],
      ['invalidObjectId', 'Document'],
      ['invalidDate', 'Document'],
      ['normalizedInvalidDate', 'Document'],
      ['invalidBinary', 'Document'],
      ['invalidRegularExpression', 'Document'],
      ['duplicatedRegularExpressionOptions', 'Document'],
      ['unsortedRegularExpressionOptions', 'Document'],
      ['invalidUuid', 'Document'],
      ['invalidScopedCode', 'Document'],
      ['ordinaryObject', 'Document'],
      ['malformedWrapper', 'Document']
    ]
  );
  assert.equal(nodeAt(document, '$.timestamp').displayValue, 't: 42, i: 7');
  assert.equal(nodeAt(document, '$.script.$scope.value').displayValue, '3');
});

test('display-model limits fail clearly before pathological JSON creates an unbounded node tree', () => {
  const tooManyValues = JSON.stringify(Array.from({ length: 50_001 }, () => 0));
  assert.throws(
    () => createDisplayDocument(tooManyValues),
    /more than the supported 50,000 values/
  );

  let tooDeep = '0';
  for (let depth = 0; depth < 201; depth += 1) {
    tooDeep = `[${tooDeep}]`;
  }
  assert.throws(
    () => createDisplayDocument(tooDeep),
    /nesting depth exceeds the supported limit of 200/
  );
});

test('BSON Result Viewer opens only explicit clipboard and file input', async () => {
  assert.deepEqual(Object.keys(bsonResultViewer), ['createBsonResultViewer']);

  const source = '[{"amount":{"$numberInt":"12"}}]';
  const events = [];
  let selectedFile;
  const viewer = createBsonResultViewer({
    chooseFile: async () => selectedFile,
    getFileSize: async file => {
      events.push(['stat-file', file]);
      return Buffer.byteLength(source);
    },
    readClipboard: async () => source,
    readFile: async file => {
      events.push(['read-file', file]);
      return Buffer.from(source);
    },
    showDocument: async (document, origin) => {
      events.push(['show', origin, nodeAt(document, '$[0].amount').displayValue]);
    },
    showError: async message => events.push(['error', message])
  });

  assert.deepEqual(Object.keys(viewer).sort(), ['openClipboard', 'openFile']);
  assert.deepEqual(events, []);

  await viewer.openClipboard();
  assert.deepEqual(events, [['show', 'Copied BSON result', '12']]);

  selectedFile = '/private/synthetic/result.json';
  await viewer.openFile();
  assert.deepEqual(events, [
    ['show', 'Copied BSON result', '12'],
    ['stat-file', selectedFile],
    ['read-file', selectedFile],
    ['show', 'BSON result file', '12']
  ]);
});

test('viewer rejects empty, malformed, oversized, and invalid UTF-8 input without rendering it', async () => {
  const events = [];
  let clipboardText = '   ';
  let selectedFile;
  let fileContents = Buffer.from('{}');
  const viewer = createBsonResultViewer({
    chooseFile: async () => selectedFile,
    getFileSize: async () => fileContents.byteLength,
    maxInputBytes: 12,
    readClipboard: async () => clipboardText,
    readFile: async () => fileContents,
    showDocument: async () => events.push(['show']),
    showError: async message => events.push(['error', message])
  });

  await viewer.openClipboard();
  clipboardText = '{]';
  await viewer.openClipboard();
  clipboardText = '{"value":"too long"}';
  await viewer.openClipboard();
  await viewer.openFile();
  selectedFile = '/private/synthetic/invalid.json';
  fileContents = Uint8Array.from([0xff]);
  await viewer.openFile();

  assert.deepEqual(events, [
    ['error', 'Could not open copied BSON result: Copied BSON result is empty. Copy or choose a JSON result and try again.'],
    ['error', 'Could not open copied BSON result: The copied BSON result is not valid JSON.'],
    ['error', 'Could not open copied BSON result: Copied BSON result is larger than the 12-byte viewer limit.'],
    ['error', 'Could not open BSON result file: The selected BSON result file is not valid UTF-8 text.']
  ]);
});

test('viewer enforces the selected-file limit before reading and again after a size race', async () => {
  const events = [];
  const selectedFile = '/private/synthetic/oversized.json';
  let reportedSize = 13;
  const viewer = createBsonResultViewer({
    chooseFile: async () => selectedFile,
    getFileSize: async file => {
      events.push(['stat-file', file]);
      return reportedSize;
    },
    maxInputBytes: 12,
    readClipboard: async () => '{}',
    readFile: async file => {
      events.push(['read-file', file]);
      return Buffer.alloc(13, 0x20);
    },
    showDocument: async () => events.push(['show']),
    showError: async message => events.push(['error', message])
  });

  await viewer.openFile();

  assert.deepEqual(events, [
    ['stat-file', selectedFile],
    ['error', 'Could not open BSON result file: BSON result file is larger than the 12-byte viewer limit.']
  ]);

  events.length = 0;
  reportedSize = 2;
  await viewer.openFile();
  assert.deepEqual(events, [
    ['stat-file', selectedFile],
    ['read-file', selectedFile],
    ['error', 'Could not open BSON result file: BSON result file is larger than the 12-byte viewer limit.']
  ]);
});

test('viewer webview exposes tree, table, raw, search, and parsed-string controls without embedding result data', () => {
  assert.deepEqual(Object.keys(viewerWebview), ['renderViewerDocument']);
  const page = renderViewerDocument();
  const nonce = page.match(/script-src 'nonce-([^']+)'/)?.[1];

  assert.ok(nonce);
  assert.match(page, /default-src 'none'/);
  assert.ok(page.includes(`<script nonce="${nonce}">`));
  assert.match(page, />Tree</);
  assert.match(page, />Table</);
  assert.match(page, />Raw JSON</);
  assert.match(page, /Search path, value, or type/);
  assert.match(page, /Parse JSON strings/);
  assert.match(page, /acquireVsCodeApi/);
  assert.match(page, /textContent/);
  assert.match(page, /details\.dataset\.populated/);
  assert.match(page, /details\.addEventListener\('toggle'/);
  assert.match(page, /TABLE_ROW_LIMIT = 5_000/);
  assert.match(page, /filtered\.slice\(0, TABLE_ROW_LIMIT\)/);
  assert.match(page, /TREE_NODE_LIMIT = 5_000/);
  assert.match(page, /renderedNodes >= TREE_NODE_LIMIT/);
  assert.match(page, /Tree shows up to/);
  assert.match(page, /type: 'parseEmbedded'/);
  assert.match(page, /message\.type === 'embeddedParseFailed'/);
  assert.match(page, /message\.type === 'copySucceeded'/);
  assert.doesNotMatch(page, /query: search\.value/);
  assert.doesNotMatch(page, /requestedamount|000000000000000000000123/);
});

test('clipboard and file commands register synchronously and route only explicit actions', async () => {
  assert.deepEqual(Object.keys(bsonViewerCommands), ['registerBsonViewerCommands']);
  const commands = new Map();
  const subscriptions = [];
  const events = [];

  registerBsonViewerCommands({
    registerCommand(command, handler) {
      commands.set(command, handler);
      return { dispose() {} };
    },
    subscriptions,
    viewer: {
      openClipboard: async () => events.push('clipboard'),
      openFile: async () => events.push('file')
    }
  });

  assert.deepEqual([...commands.keys()].sort(), [
    'dbcodeWrapper.openBsonResultFromClipboard',
    'dbcodeWrapper.openBsonResultFromFile'
  ]);
  assert.equal(subscriptions.length, 2);
  assert.deepEqual(events, []);

  await commands.get('dbcodeWrapper.openBsonResultFromClipboard')();
  await commands.get('dbcodeWrapper.openBsonResultFromFile')();
  assert.deepEqual(events, ['clipboard', 'file']);
});

test('extension installs the webview ready listener before loading its document', async () => {
  const extensionUrl = new URL('../host/extensions/dbcode-wrapper-bson-viewer/extension.js', import.meta.url);
  const extensionRequire = createRequire(extensionUrl);
  const extensionModule = { exports: {} };
  const extensionSource = readFileSync(extensionUrl, 'utf8');
  const commands = new Map();
  const messages = [];
  const errors = [];
  const selectedFile = { fsPath: '/private/synthetic/result.ejson' };
  let readyHandler;
  let readyDelivered = false;
  let html = '';

  const webview = {
    get html() {
      return html;
    },
    set html(value) {
      html = value;
      if (readyHandler) {
        readyDelivered = true;
        void readyHandler({ type: 'ready' });
      }
    },
    async postMessage(message) {
      if (readyDelivered) {
        messages.push(message);
      }
      return readyDelivered;
    },
    onDidReceiveMessage(handler) {
      readyHandler = handler;
      return { dispose() {} };
    }
  };
  const panel = {
    webview,
    reveal() {},
    onDidDispose() {
      return { dispose() {} };
    },
    dispose() {}
  };
  const vscode = {
    ViewColumn: { Active: 1 },
    commands: {
      registerCommand(command, handler) {
        commands.set(command, handler);
        return { dispose() {} };
      }
    },
    env: {
      clipboard: {
        readText: async () => '',
        writeText: async () => {}
      }
    },
    window: {
      createWebviewPanel: () => panel,
      showOpenDialog: async () => [selectedFile],
      showErrorMessage: async message => errors.push(message)
    },
    workspace: {
      fs: {
        stat: async () => ({ size: 35 }),
        readFile: async () => Buffer.from('[{"amount":{"$numberInt":"12"}}]')
      }
    }
  };
  const load = vm.runInNewContext(
    `(function (require, module, exports, __dirname, __filename) { ${extensionSource}\n})`,
    { Buffer, TextDecoder }
  );
  load(
    specifier => specifier === 'vscode' ? vscode : extensionRequire(specifier),
    extensionModule,
    extensionModule.exports,
    fileURLToPath(new URL('.', extensionUrl)),
    fileURLToPath(extensionUrl)
  );

  extensionModule.exports.activate({ subscriptions: [] });
  await commands.get('dbcodeWrapper.openBsonResultFromFile')();

  assert.equal(readyDelivered, true);
  assert.equal(errors.length, 0);
  assert.equal(messages.some(message => message.type === 'document'), true);
  assert.match(html, /BSON Result Viewer/);
});

test('viewer manifest keeps both commands inside the focused shell and gives clipboard input one shortcut', () => {
  assert.equal(bsonViewerManifest.publisher, 'dbcode-wrapper');
  assert.equal(bsonViewerManifest.name, 'bson-result-viewer');
  assert.equal(bsonViewerManifest.main, './extension.js');
  assert.deepEqual([...bsonViewerManifest.activationEvents].sort(), [
    'onCommand:dbcodeWrapper.openBsonResultFromClipboard',
    'onCommand:dbcodeWrapper.openBsonResultFromFile'
  ]);
  assert.deepEqual(
    bsonViewerManifest.contributes.commands.map(command => command.command).sort(),
    [
      'dbcodeWrapper.openBsonResultFromClipboard',
      'dbcodeWrapper.openBsonResultFromFile'
    ]
  );
  assert.ok(bsonViewerManifest.contributes.menus.commandPalette.every(item => item.when === 'false'));
  assert.deepEqual(bsonViewerManifest.contributes.keybindings, [{
    command: 'dbcodeWrapper.openBsonResultFromClipboard',
    key: 'ctrl+alt+j',
    mac: 'cmd+alt+j',
    when: '!inputFocus'
  }]);
});
