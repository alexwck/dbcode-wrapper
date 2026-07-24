'use strict';

const path = require('node:path');

const REVIEWED_FIELDS = ['name', 'type', 'host', 'port', 'database', 'username', 'ssl', 'path'];
const FIELD_ALIASES = new Map([
  ['name', 'name'],
  ['connection_name', 'name'],
  ['connectionname', 'name'],
  ['type', 'type'],
  ['database_type', 'type'],
  ['db_type', 'type'],
  ['driver', 'type'],
  ['host', 'host'],
  ['server', 'host'],
  ['hostname', 'host'],
  ['port', 'port'],
  ['database', 'database'],
  ['database_name', 'database'],
  ['dbname', 'database'],
  ['username', 'username'],
  ['user', 'username'],
  ['user_name', 'username'],
  ['ssl', 'ssl'],
  ['ssl_mode', 'ssl'],
  ['sslmode', 'ssl'],
  ['path', 'path'],
  ['file_path', 'path'],
  ['filepath', 'path'],
  ['filename', 'path']
]);
const EMBEDDED_CREDENTIAL_URL = /(?:[a-z][a-z0-9+.-]*:)+\/\/[^/@\s]*@/i;
const SECRET_VALUE = /-----BEGIN [^-]*PRIVATE KEY-----|(?:password|passphrase|token|secret|private[_ -]?key|licen[cs]e|salt)\s*[:=]/i;
const SSL_CHOICES = new Set(['disable', 'allow', 'prefer', 'require', 'verify-ca', 'verify-full']);

function fieldKey(value) {
  return value.trim().toLowerCase().replace(/[\s-]+/g, '_');
}

function assertSafeValue(value) {
  if (!['string', 'number', 'boolean'].includes(typeof value)) {
    throw new Error('Connection details must use plain values.');
  }
  if (typeof value === 'string') {
    const reviewedValue = value.trim();
    if (EMBEDDED_CREDENTIAL_URL.test(reviewedValue) || SECRET_VALUE.test(reviewedValue)) {
      throw new Error('The inventory contains embedded credentials or protected data.');
    }
  }
}

function validateConnection(connection) {
  for (const field of ['name', 'type', 'host', 'database', 'username']) {
    if (connection[field] !== undefined && (typeof connection[field] !== 'string' || connection[field].trim() === '' || /[\u0000-\u001f]/.test(connection[field]))) {
      throw new Error('Connection text details must be non-empty plain values.');
    }
  }
  if (!Number.isInteger(connection.port) || connection.port < 1 || connection.port > 65535) {
    if (connection.port !== undefined) {
      throw new Error('A connection port must be a valid port from 1 to 65535.');
    }
  }
  if (connection.ssl !== undefined) {
    if (typeof connection.ssl === 'string') {
      connection.ssl = connection.ssl.trim().toLowerCase();
    }
    if (typeof connection.ssl !== 'boolean' && !SSL_CHOICES.has(connection.ssl)) {
      throw new Error('A connection must use a supported SSL choice.');
    }
  }
  if (connection.path !== undefined) {
    if (typeof connection.path !== 'string' || !path.isAbsolute(connection.path) || connection.path.includes('://') || /[\u0000-\u001f]/.test(connection.path)) {
      throw new Error('A connection file must use an absolute local path.');
    }
  }
  if (typeof connection.type !== 'string' || Number(Boolean(connection.host)) + Number(Boolean(connection.path)) !== 1) {
    throw new Error('Every connection needs a database type and exactly one host or local path.');
  }
}

function normalizeConnection(connection) {
  const normalized = {};
  for (const [sourceField, sourceValue] of Object.entries(connection)) {
    const field = FIELD_ALIASES.get(fieldKey(sourceField));
    if (!field || !REVIEWED_FIELDS.includes(field)) {
      throw new Error('The inventory contains a field that is not allowed.');
    }
    if (Object.hasOwn(normalized, field)) {
      throw new Error('The inventory maps more than one field to the same connection detail.');
    }
    assertSafeValue(sourceValue);
    if (sourceValue === '') {
      continue;
    }
    normalized[field] = field === 'port' && typeof sourceValue === 'string'
      ? Number(sourceValue)
      : field === 'ssl' && typeof sourceValue === 'string' && ['true', 'false'].includes(sourceValue.trim().toLowerCase())
        ? sourceValue.trim().toLowerCase() === 'true'
      : typeof sourceValue === 'string'
        ? sourceValue.trim()
        : sourceValue;
  }
  validateConnection(normalized);
  return normalized;
}

function parseCsv(contents) {
  const rows = [];
  let row = [];
  let field = '';
  let quoted = false;
  for (let index = 0; index < contents.length; index++) {
    const character = contents[index];
    if (quoted) {
      if (character === '"' && contents[index + 1] === '"') {
        field += '"';
        index++;
      } else if (character === '"') {
        quoted = false;
      } else {
        field += character;
      }
    } else if (character === '"' && field === '') {
      quoted = true;
    } else if (character === ',') {
      row.push(field);
      field = '';
    } else if (character === '\n' || character === '\r') {
      if (character === '\r' && contents[index + 1] === '\n') {
        index++;
      }
      row.push(field);
      rows.push(row);
      row = [];
      field = '';
    } else {
      field += character;
    }
  }
  if (quoted) {
    throw new Error('The CSV inventory has an unterminated quoted value.');
  }
  if (field !== '' || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  const nonEmptyRows = rows.filter(candidate => candidate.some(value => value.trim() !== ''));
  if (nonEmptyRows.length < 2) {
    throw new Error('The CSV inventory must contain a header and at least one connection.');
  }
  const headers = nonEmptyRows[0].map(value => value.trim());
  return nonEmptyRows.slice(1).map(values => {
    if (values.length !== headers.length) {
      throw new Error('Every CSV row must have the same number of fields as its header.');
    }
    return Object.fromEntries(headers.map((header, index) => [header, values[index].trim()]));
  });
}

function parseInventory(contents, format) {
  let parsed;
  if (format === 'json') {
    try {
      parsed = JSON.parse(contents);
    } catch {
      throw new Error('The JSON inventory is not valid.');
    }
  } else if (format === 'csv') {
    parsed = parseCsv(contents);
  } else {
    throw new Error('Only JSON and CSV connection inventories are supported.');
  }
  if (!Array.isArray(parsed)) {
    throw new Error('The inventory must be an array of connections.');
  }
  return parsed.map(connection => {
    if (!connection || typeof connection !== 'object' || Array.isArray(connection)) {
      throw new Error('Every connection must be an object.');
    }
    return normalizeConnection(connection);
  });
}

function createMigrationPlan(connections) {
  const ready = [];
  const preflight = [];
  for (const connection of connections) {
    const filename = connection.path ? path.posix.basename(connection.path) : '';
    const extensionIndex = filename.lastIndexOf('.');
    const stem = extensionIndex > 0 ? filename.slice(0, extensionIndex) : filename;
    if (connection.type.toLowerCase() === 'duckdb' && stem.includes('-')) {
      preflight.push({ connection, kind: 'duckdb-hyphen-path', mode: 'read-only' });
    } else {
      ready.push(connection);
    }
  }
  return { ready, preflight };
}

function advancePreflight(preflight, progress, outcome) {
  if (!['passed', 'deferred'].includes(outcome)) {
    throw new Error('A DuckDB preflight result must be passed or deferred.');
  }
  const current = preflight[progress.completed];
  if (!current) {
    throw new Error('There is no pending DuckDB preflight connection.');
  }
  return {
    completed: progress.completed + 1,
    deferred: outcome === 'deferred'
      ? [...progress.deferred, current.connection]
      : [...progress.deferred]
  };
}

module.exports = { REVIEWED_FIELDS, advancePreflight, createMigrationPlan, parseInventory };
