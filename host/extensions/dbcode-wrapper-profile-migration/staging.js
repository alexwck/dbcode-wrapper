'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs/promises');
const path = require('node:path');
const { REVIEWED_FIELDS, parseInventory } = require('./migration');
const STAGED_FIELDS = [...REVIEWED_FIELDS, 'connectionType'];

function csvValue(value) {
  const text = value === undefined ? '' : String(value);
  return /[",\r\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

function reviewedCsv(connections) {
  return `${[
    STAGED_FIELDS.join(','),
    ...connections.map(connection => {
      const staged = {
        ...connection,
        connectionType: connection.path ? 'socket' : 'host'
      };
      return STAGED_FIELDS.map(field => csvValue(staged[field])).join(',');
    })
  ].join('\n')}\n`;
}

function checkedSessionDirectory(stagingRoot, sessionDirectory) {
  const root = path.resolve(stagingRoot);
  const session = path.resolve(sessionDirectory);
  if (path.dirname(session) !== root || !path.basename(session).startsWith('session-')) {
    throw new Error('Refusing to use a migration staging path outside the private staging folder.');
  }
  return { root, session };
}

async function stageReviewedInventory(stagingRoot, connections) {
  const reviewed = parseInventory(JSON.stringify(connections), 'json');
  const root = path.resolve(stagingRoot);
  await fs.mkdir(root, { recursive: true, mode: 0o700 });
  await fs.chmod(root, 0o700);

  const session = path.join(root, `session-${crypto.randomUUID()}`);
  await fs.mkdir(session, { mode: 0o700 });
  const inventoryPath = path.join(session, 'reviewed-connections.csv');
  await fs.writeFile(inventoryPath, reviewedCsv(reviewed), {
    encoding: 'utf8',
    flag: 'wx',
    mode: 0o600
  });
  await fs.chmod(inventoryPath, 0o600);
  return { sessionDirectory: session, inventoryPath };
}

async function cleanupReviewedInventory(stagingRoot, sessionDirectory) {
  const { session } = checkedSessionDirectory(stagingRoot, sessionDirectory);
  await fs.rm(session, { recursive: true, force: true });
}

module.exports = { cleanupReviewedInventory, stageReviewedInventory };
