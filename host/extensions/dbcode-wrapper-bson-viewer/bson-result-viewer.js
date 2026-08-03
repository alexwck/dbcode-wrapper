'use strict';

const { createDisplayDocument } = require('./ejson-display');

const DEFAULT_MAX_INPUT_BYTES = 10 * 1024 * 1024;

function requireFunction(value, name) {
  if (typeof value !== 'function') {
    throw new TypeError(`BSON Result Viewer requires ${name}.`);
  }
  return value;
}

function formatByteLimit(bytes) {
  if (bytes >= 1024 * 1024 && bytes % (1024 * 1024) === 0) {
    return `${bytes / (1024 * 1024)} MiB`;
  }
  if (bytes >= 1024 && bytes % 1024 === 0) {
    return `${bytes / 1024} KiB`;
  }
  return `${bytes}-byte`;
}

function assertInputSize(inputBytes, origin, maxInputBytes) {
  if (!Number.isSafeInteger(inputBytes) || inputBytes < 0) {
    throw new Error(`${origin} size could not be read safely.`);
  }
  if (inputBytes > maxInputBytes) {
    throw new Error(`${origin} is larger than the ${formatByteLimit(maxInputBytes)} viewer limit.`);
  }
}

function decodeFile(contents, maxInputBytes) {
  if (typeof contents === 'string') {
    assertInputSize(Buffer.byteLength(contents, 'utf8'), 'BSON result file', maxInputBytes);
    return contents;
  }
  if (!(contents instanceof Uint8Array)) {
    throw new TypeError('The selected BSON result file did not return bytes.');
  }
  assertInputSize(contents.byteLength, 'BSON result file', maxInputBytes);
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(contents);
  } catch {
    throw new Error('The selected BSON result file is not valid UTF-8 text.');
  }
}

function messageFrom(error) {
  return error instanceof Error ? error.message : String(error);
}

function createBsonResultViewer(dependencies) {
  if (!dependencies || typeof dependencies !== 'object') {
    throw new TypeError('BSON Result Viewer dependencies are required.');
  }
  const chooseFile = requireFunction(dependencies.chooseFile, 'chooseFile');
  const getFileSize = requireFunction(dependencies.getFileSize, 'getFileSize');
  const readClipboard = requireFunction(dependencies.readClipboard, 'readClipboard');
  const readFile = requireFunction(dependencies.readFile, 'readFile');
  const showDocument = requireFunction(dependencies.showDocument, 'showDocument');
  const showError = requireFunction(dependencies.showError, 'showError');
  const maxInputBytes = dependencies.maxInputBytes ?? DEFAULT_MAX_INPUT_BYTES;
  if (!Number.isSafeInteger(maxInputBytes) || maxInputBytes <= 0) {
    throw new TypeError('BSON Result Viewer maxInputBytes must be a positive safe integer.');
  }

  async function openText(rawText, origin) {
    if (typeof rawText !== 'string') {
      throw new TypeError(`${origin} did not provide text.`);
    }
    if (rawText.trim().length === 0) {
      throw new Error(`${origin} is empty. Copy or choose a JSON result and try again.`);
    }
    const inputBytes = Buffer.byteLength(rawText, 'utf8');
    assertInputSize(inputBytes, origin, maxInputBytes);
    const document = createDisplayDocument(rawText);
    await showDocument(document, origin);
  }

  async function run(action, origin, errorOrigin) {
    try {
      const rawText = await action();
      if (rawText === undefined) {
        return;
      }
      await openText(rawText, origin);
    } catch (error) {
      await showError(`Could not open ${errorOrigin}: ${messageFrom(error)}`);
    }
  }

  return Object.freeze({
    openClipboard: () => run(readClipboard, 'Copied BSON result', 'copied BSON result'),
    openFile: () => run(async () => {
      const selectedFile = await chooseFile();
      if (selectedFile === undefined) {
        return undefined;
      }
      assertInputSize(await getFileSize(selectedFile), 'BSON result file', maxInputBytes);
      return decodeFile(await readFile(selectedFile), maxInputBytes);
    }, 'BSON result file', 'BSON result file')
  });
}

module.exports = { createBsonResultViewer };
