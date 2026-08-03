'use strict';

const MAX_NESTING_DEPTH = 200;
const MAX_DISPLAY_NODES = 50_000;
const MIN_DATE_MILLISECONDS = -8640000000000000n;
const MAX_DATE_MILLISECONDS = 8640000000000000n;
const MIN_INT32 = -2147483648n;
const MAX_INT32 = 2147483647n;
const MIN_INT64 = -9223372036854775808n;
const MAX_INT64 = 9223372036854775807n;
const JSON_NUMBER = Symbol('jsonNumber');
const INTEGER_STRING = /^-?(?:0|[1-9]\d*)$/;
const DOUBLE_STRING = /^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?$/;
const DECIMAL128_FINITE = /^[+-]?(?:(\d+)(?:\.(\d*))?|\.(\d+))(?:[eE]([+-]?\d+))?$/;
const OBJECT_ID_STRING = /^[0-9a-fA-F]{24}$/;
const UUID_STRING = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

function exactKeys(value, expected) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }
  const actual = Object.keys(value).sort();
  const sortedExpected = [...expected].sort();
  return actual.length === sortedExpected.length && actual.every((key, index) => key === sortedExpected[index]);
}

function isUint32(value) {
  const lexeme = numberLexeme(value);
  return lexeme !== undefined && lexeme.length <= 10 && /^(?:0|[1-9]\d*)$/.test(lexeme) &&
    BigInt(lexeme) <= 0xffffffffn;
}

function isIntegerStringInRange(value, minimum, maximum) {
  if (typeof value !== 'string' || value.length > 20 || !INTEGER_STRING.test(value)) {
    return false;
  }
  try {
    const integer = BigInt(value);
    return integer >= minimum && integer <= maximum;
  } catch {
    return false;
  }
}

function isDoubleString(value) {
  if (value === 'NaN' || value === 'Infinity' || value === '-Infinity') {
    return true;
  }
  return typeof value === 'string' && DOUBLE_STRING.test(value) && Number.isFinite(Number(value));
}

function isDecimal128String(value) {
  if (value === 'NaN' || value === 'Infinity' || value === '-Infinity') {
    return true;
  }
  if (typeof value !== 'string') {
    return false;
  }
  const match = DECIMAL128_FINITE.exec(value);
  if (!match) {
    return false;
  }

  const whole = match[1] ?? '';
  const fraction = match[2] ?? match[3] ?? '';
  const exponentText = match[4] ?? '0';
  const unsignedExponent = exponentText.replace(/^[+-]/, '').replace(/^0+/, '') || '0';
  if (unsignedExponent.length > 4) {
    return false;
  }

  let exponent = BigInt(exponentText) - BigInt(fraction.length);
  let digits = `${whole}${fraction}`.replace(/^0+/, '');
  if (digits.length === 0) {
    return exponent >= -6176n && exponent <= 6111n;
  }

  let trailingZeroCount = 0;
  while (trailingZeroCount < digits.length && digits[digits.length - trailingZeroCount - 1] === '0') {
    trailingZeroCount += 1;
  }
  if (digits.length > 34) {
    const removable = Math.min(trailingZeroCount, digits.length - 34);
    digits = digits.slice(0, digits.length - removable);
    trailingZeroCount -= removable;
    exponent += BigInt(removable);
    if (digits.length > 34) {
      return false;
    }
  }
  if (exponent < -6176n) {
    const required = -6176n - exponent;
    if (required > BigInt(trailingZeroCount)) {
      return false;
    }
    exponent += required;
  }
  if (exponent > 6111n) {
    const required = exponent - 6111n;
    if (required > BigInt(34 - digits.length)) {
      return false;
    }
    exponent -= required;
  }
  return exponent >= -6176n && exponent <= 6111n;
}

function isObjectIdString(value) {
  return typeof value === 'string' && OBJECT_ID_STRING.test(value);
}

function isUuidString(value) {
  return typeof value === 'string' && UUID_STRING.test(value);
}

function isIsoDateString(value) {
  if (typeof value !== 'string') {
    return false;
  }
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?(Z|[+-]\d{2}:\d{2})$/.exec(value);
  if (!match) {
    return false;
  }
  const [, yearText, monthText, dayText, hourText, minuteText, secondText, , zone] = match;
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const hour = Number(hourText);
  const minute = Number(minuteText);
  const second = Number(secondText);
  const zoneHour = zone === 'Z' ? 0 : Number(zone.slice(1, 3));
  const zoneMinute = zone === 'Z' ? 0 : Number(zone.slice(4, 6));
  if (year < 1970 || month < 1 || month > 12 || day < 1 ||
      day > new Date(Date.UTC(year, month, 0)).getUTCDate() || hour > 23 || minute > 59 || second > 59 ||
      zoneHour > 23 || zoneMinute > 59) {
    return false;
  }
  return !Number.isNaN(Date.parse(value));
}

function isRegularExpressionOptions(value) {
  if (typeof value !== 'string' || !/^[ilmsux]*$/.test(value)) {
    return false;
  }
  return [...value].every((option, index) => index === 0 || value[index - 1] < option);
}

function numberLexeme(value) {
  return value && typeof value === 'object' && value[JSON_NUMBER] === true
    ? value.lexeme
    : undefined;
}

function isNumberValue(value, expected) {
  return numberLexeme(value) === expected;
}

function parseJsonPreservingNumbers(rawText) {
  return JSON.parse(rawText, (_key, value, context) => {
    if (typeof value !== 'number') {
      return value;
    }
    if (!context || typeof context.source !== 'string') {
      throw new Error('The host cannot preserve JSON number precision.');
    }
    return Object.freeze({
      [JSON_NUMBER]: true,
      lexeme: context.source
    });
  });
}

function plural(count, singular, pluralForm = `${singular}s`) {
  return `${count} ${count === 1 ? singular : pluralForm}`;
}

function propertyPath(parentPath, key) {
  return /^[A-Za-z_$][A-Za-z0-9_$]*$/.test(key)
    ? `${parentPath}.${key}`
    : `${parentPath}[${JSON.stringify(key)}]`;
}

function formatDateMilliseconds(value) {
  if (!/^-?\d+$/.test(value)) {
    return value;
  }
  try {
    const milliseconds = BigInt(value);
    if (milliseconds < MIN_DATE_MILLISECONDS || milliseconds > MAX_DATE_MILLISECONDS) {
      return value;
    }
    return new Date(Number(milliseconds)).toISOString();
  } catch {
    return value;
  }
}

function scalar(type, displayValue, copyValue = displayValue) {
  return { type, displayValue: String(displayValue), copyValue: String(copyValue) };
}

function extendedJsonScalar(value) {
  if (exactKeys(value, ['$numberInt']) && isIntegerStringInRange(value.$numberInt, MIN_INT32, MAX_INT32)) {
    return scalar('Int32', value.$numberInt);
  }
  if (exactKeys(value, ['$numberLong']) && isIntegerStringInRange(value.$numberLong, MIN_INT64, MAX_INT64)) {
    return scalar('Int64', value.$numberLong);
  }
  if (exactKeys(value, ['$numberDouble']) && isDoubleString(value.$numberDouble)) {
    return scalar('Double', value.$numberDouble);
  }
  if (exactKeys(value, ['$numberDecimal']) && isDecimal128String(value.$numberDecimal)) {
    return scalar('Decimal128', value.$numberDecimal);
  }
  if (exactKeys(value, ['$oid']) && isObjectIdString(value.$oid)) {
    return scalar('ObjectId', value.$oid);
  }
  if (exactKeys(value, ['$date'])) {
    if (isIsoDateString(value.$date)) {
      return scalar('Date', value.$date);
    }
    if (exactKeys(value.$date, ['$numberLong']) &&
        isIntegerStringInRange(value.$date.$numberLong, MIN_INT64, MAX_INT64)) {
      return scalar('Date', formatDateMilliseconds(value.$date.$numberLong));
    }
  }
  if (exactKeys(value, ['$binary']) && exactKeys(value.$binary, ['base64', 'subType']) &&
      typeof value.$binary.base64 === 'string' && /^[A-Za-z0-9+/]*={0,2}$/.test(value.$binary.base64) &&
      value.$binary.base64.length % 4 === 0 && /^[0-9a-fA-F]{1,2}$/.test(value.$binary.subType)) {
    return scalar('Binary', `${value.$binary.base64} (subtype ${value.$binary.subType})`, value.$binary.base64);
  }
  if (exactKeys(value, ['$timestamp']) && exactKeys(value.$timestamp, ['i', 't']) &&
      isUint32(value.$timestamp.t) && isUint32(value.$timestamp.i)) {
    return scalar('Timestamp', `t: ${numberLexeme(value.$timestamp.t)}, i: ${numberLexeme(value.$timestamp.i)}`);
  }
  if (exactKeys(value, ['$regularExpression']) && exactKeys(value.$regularExpression, ['options', 'pattern']) &&
      typeof value.$regularExpression.pattern === 'string' &&
      isRegularExpressionOptions(value.$regularExpression.options)) {
    return scalar('Regular Expression', `/${value.$regularExpression.pattern}/${value.$regularExpression.options}`);
  }
  if (exactKeys(value, ['$symbol']) && typeof value.$symbol === 'string') {
    return scalar('Symbol', value.$symbol);
  }
  if (exactKeys(value, ['$minKey']) && isNumberValue(value.$minKey, '1')) {
    return scalar('MinKey', 'MinKey');
  }
  if (exactKeys(value, ['$maxKey']) && isNumberValue(value.$maxKey, '1')) {
    return scalar('MaxKey', 'MaxKey');
  }
  if (exactKeys(value, ['$undefined']) && value.$undefined === true) {
    return scalar('Undefined', 'undefined');
  }
  if (exactKeys(value, ['$uuid']) && isUuidString(value.$uuid)) {
    return scalar('UUID', value.$uuid);
  }
  if (exactKeys(value, ['$code']) && typeof value.$code === 'string') {
    return scalar('JavaScript', value.$code);
  }
  if (exactKeys(value, ['$dbPointer']) && exactKeys(value.$dbPointer, ['$id', '$ref']) &&
      typeof value.$dbPointer.$ref === 'string' && exactKeys(value.$dbPointer.$id, ['$oid']) &&
      isObjectIdString(value.$dbPointer.$id.$oid)) {
    return scalar('DBPointer', `${value.$dbPointer.$ref} → ${value.$dbPointer.$id.$oid}`);
  }
  return undefined;
}

function parseEmbeddedDocument(value) {
  const trimmed = value.trim();
  if (!((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']')))) {
    return undefined;
  }
  try {
    const parsed = parseJsonPreservingNumbers(trimmed);
    return parsed && typeof parsed === 'object' ? parsed : undefined;
  } catch {
    return undefined;
  }
}

function createNode(value, key, path, depth, state, embeddedDepth = 0) {
  if (depth > MAX_NESTING_DEPTH) {
    throw new Error(`The JSON nesting depth exceeds the supported limit of ${MAX_NESTING_DEPTH}.`);
  }
  state.nodeCount += 1;
  if (state.nodeCount > MAX_DISPLAY_NODES) {
    throw new Error(`The JSON contains more than the supported ${MAX_DISPLAY_NODES.toLocaleString('en-US')} values.`);
  }

  const common = {
    key,
    path,
    children: []
  };

  const exactNumber = numberLexeme(value);
  if (exactNumber !== undefined) {
    return { ...common, ...scalar('Number', exactNumber) };
  }

  if (exactKeys(value, ['$code', '$scope']) && typeof value.$code === 'string' &&
      value.$scope !== null && typeof value.$scope === 'object' && !Array.isArray(value.$scope) &&
      numberLexeme(value.$scope) === undefined) {
    return {
      ...common,
      ...scalar('JavaScript with Scope', value.$code),
      children: [createNode(value.$scope, '$scope', propertyPath(path, '$scope'), depth + 1, state, embeddedDepth)]
    };
  }

  const bsonScalar = extendedJsonScalar(value);
  if (bsonScalar) {
    return { ...common, ...bsonScalar };
  }

  if (Array.isArray(value)) {
    return {
      ...common,
      type: 'Array',
      displayValue: plural(value.length, 'item'),
      children: value.map((child, index) => createNode(child, `[${index}]`, `${path}[${index}]`, depth + 1, state, embeddedDepth))
    };
  }

  if (value !== null && typeof value === 'object') {
    const entries = Object.entries(value);
    return {
      ...common,
      type: 'Document',
      displayValue: plural(entries.length, 'field'),
      children: entries.map(([childKey, child]) => createNode(child, childKey, propertyPath(path, childKey), depth + 1, state, embeddedDepth))
    };
  }

  if (typeof value === 'string') {
    const node = {
      ...common,
      type: 'String',
      displayValue: value,
      copyValue: value
    };
    const embedded = state.parseEmbedded && embeddedDepth < 5 ? parseEmbeddedDocument(value) : undefined;
    if (embedded !== undefined) {
      node.embeddedJson = createNode(embedded, '{parsed JSON}', `${path}{json}`, depth + 1, state, embeddedDepth + 1);
    }
    return node;
  }

  if (typeof value === 'number') {
    return { ...common, ...scalar('Number', Object.is(value, -0) ? '-0' : value) };
  }
  if (typeof value === 'boolean') {
    return { ...common, ...scalar('Boolean', value) };
  }
  return { ...common, ...scalar('Null', 'null') };
}

function createDisplayDocument(rawText, options = {}) {
  if (typeof rawText !== 'string') {
    throw new TypeError('BSON result input must be text.');
  }
  if (!options || typeof options !== 'object' || Array.isArray(options) ||
      (options.parseEmbedded !== undefined && typeof options.parseEmbedded !== 'boolean')) {
    throw new TypeError('BSON result display options must be an object with an optional parseEmbedded boolean.');
  }
  let value;
  try {
    value = parseJsonPreservingNumbers(rawText);
  } catch {
    throw new Error('The copied BSON result is not valid JSON.');
  }
  const state = { nodeCount: 0, parseEmbedded: options.parseEmbedded === true };
  const root = createNode(value, '$', '$', 0, state);
  return {
    schemaVersion: 1,
    rawText,
    nodeCount: state.nodeCount,
    embeddedJsonIncluded: state.parseEmbedded,
    root
  };
}

module.exports = { createDisplayDocument };
