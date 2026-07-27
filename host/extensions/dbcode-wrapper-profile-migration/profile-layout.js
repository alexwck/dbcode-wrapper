'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { isDeepStrictEqual } = require('node:util');

const PROFILE_IDENTITY_PATH = path.join(__dirname, 'profile-identity.json');
const PROFILE_IDENTITY_KEYS = ['product', 'profile_schema_version', 'schema_version', 'target'];
const PRODUCT_IDENTITY_KEYS = [
  'app_name',
  'application_name',
  'backup_folder_name',
  'bundle_identifier',
  'data_folder_name',
  'extensions_folder_name',
  'query_folder_name',
  'shared_data_folder_name',
  'storage_namespace',
  'user_data_folder_name'
];
const PATH_NAMES = new Set(['state', 'user_data', 'extensions', 'shared_data', 'backup', 'cache', 'logs', 'queries']);
const MAX_PROFILE_IDENTITY_BYTES = 64 * 1024;

function fail(message) {
  throw new Error(message);
}

function exactKeys(value, expected) {
  return value &&
    typeof value === 'object' &&
    !Array.isArray(value) &&
    isDeepStrictEqual(Object.keys(value).sort(), [...expected].sort());
}

function checkedFolderName(value, label) {
  if (
    typeof value !== 'string' ||
    value.length === 0 ||
    value === '.' ||
    value === '..' ||
    /[/\\\u0000-\u001f]/.test(value)
  ) {
    fail(`${label} must be one safe folder name.`);
  }
  return value;
}

function validateProfileIdentity(identity) {
  if (
    !exactKeys(identity, PROFILE_IDENTITY_KEYS) ||
    identity.schema_version !== 1 ||
    !isDeepStrictEqual(identity.target, { architecture: 'arm64', platform: 'darwin' }) ||
    !Number.isSafeInteger(identity.profile_schema_version) ||
    identity.profile_schema_version < 1 ||
    !exactKeys(identity.product, PRODUCT_IDENTITY_KEYS)
  ) {
    fail('Generated Profile Layout identity is invalid.');
  }
  const product = identity.product;
  for (const [field, label] of [
    ['app_name', 'The application name'],
    ['data_folder_name', 'The state folder name'],
    ['user_data_folder_name', 'The user-data folder name'],
    ['extensions_folder_name', 'The extension folder name'],
    ['shared_data_folder_name', 'The shared-data folder name'],
    ['backup_folder_name', 'The backup folder name'],
    ['storage_namespace', 'The storage namespace'],
    ['query_folder_name', 'The query folder name']
  ]) {
    checkedFolderName(product[field], label);
  }
  if (
    typeof product.application_name !== 'string' ||
    !/^[a-z0-9][a-z0-9._-]*$/.test(product.application_name)
  ) {
    fail('The application executable name is invalid.');
  }
  if (
    typeof product.bundle_identifier !== 'string' ||
    !/^[A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z0-9.-]+$/.test(product.bundle_identifier)
  ) {
    fail('The application bundle identifier is invalid.');
  }
  return identity;
}

function loadProfileIdentity(identityPath = PROFILE_IDENTITY_PATH) {
  let metadata;
  try {
    metadata = fs.lstatSync(identityPath);
  } catch (error) {
    if (error?.code === 'ENOENT') {
      fail(`Generated Profile Layout identity is missing: ${identityPath}`);
    }
    throw error;
  }
  if (metadata.isSymbolicLink()) {
    fail('Generated Profile Layout identity must not be a symbolic link.');
  }
  if (!metadata.isFile() || metadata.size > MAX_PROFILE_IDENTITY_BYTES) {
    fail('Generated Profile Layout identity is not a safe regular file.');
  }
  let identity;
  try {
    identity = JSON.parse(fs.readFileSync(identityPath, 'utf8'));
  } catch {
    fail('Generated Profile Layout identity is not valid JSON.');
  }
  return validateProfileIdentity(identity);
}

function checkedRoot(value, label) {
  if (typeof value !== 'string' || !path.isAbsolute(value)) {
    fail(`${label} must be an absolute path.`);
  }
  const resolved = path.resolve(value);
  if (resolved === path.parse(resolved).root) {
    fail(`${label} is too broad.`);
  }
  return resolved;
}

function contains(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative === '' || (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative));
}

function queryPath(userData, product) {
  return path.join(
    userData,
    'User/globalStorage',
    product.storage_namespace,
    product.query_folder_name
  );
}

function profilePaths(identity, profileName, ownerRoot, isolatedStateRoot, isolatedExtensionsRoot) {
  const product = identity.product;
  if (profileName === 'default') {
    const userData = path.join(
      ownerRoot,
      'Library/Application Support',
      product.user_data_folder_name
    );
    return {
      state: path.join(ownerRoot, product.data_folder_name),
      user_data: userData,
      extensions: path.join(ownerRoot, product.data_folder_name, product.extensions_folder_name),
      shared_data: path.join(ownerRoot, product.shared_data_folder_name),
      backup: path.join(ownerRoot, 'Library/Application Support', product.backup_folder_name),
      cache: path.join(userData, 'Cache'),
      logs: path.join(userData, 'logs'),
      queries: queryPath(userData, product)
    };
  }
  if (profileName === 'qa') {
    const state = path.join(ownerRoot, 'qa/profile');
    const userData = path.join(state, 'user-data');
    return {
      state,
      user_data: userData,
      extensions: path.join(state, product.extensions_folder_name),
      shared_data: path.join(state, 'shared-data'),
      backup: path.join(ownerRoot, 'qa/profile-backups'),
      cache: path.join(state, 'cache'),
      logs: path.join(state, 'logs'),
      queries: queryPath(userData, product)
    };
  }
  if (profileName === 'isolated') {
    const state = checkedRoot(isolatedStateRoot, 'The isolated profile state root');
    if (!contains(ownerRoot, state) || state === ownerRoot) {
      fail('The isolated profile state root must stay below its owner root.');
    }
    const extensions = isolatedExtensionsRoot === undefined
      ? path.join(state, product.extensions_folder_name)
      : checkedRoot(isolatedExtensionsRoot, 'The isolated profile extension root');
    if (!contains(ownerRoot, extensions)) {
      fail('The isolated profile extension root must stay below its owner root.');
    }
    const userData = path.join(state, 'user-data');
    return {
      state,
      user_data: userData,
      extensions,
      shared_data: path.join(state, 'shared-data'),
      backup: `${state}-backups`,
      cache: path.join(state, 'cache'),
      logs: path.join(state, 'logs'),
      queries: queryPath(userData, product)
    };
  }
  fail(`Unknown Standalone DBCode Profile: ${profileName}`);
}

function createProfileLayout({
  identity = loadProfileIdentity(),
  profileName,
  homeDirectory,
  buildRoot,
  stateRoot,
  extensionsRoot
}) {
  const approvedIdentity = validateProfileIdentity(identity);
  let owner;
  if (profileName === 'default') {
    owner = { kind: 'current-user-home', root: checkedRoot(homeDirectory, 'The current user home directory') };
  } else if (profileName === 'qa') {
    owner = { kind: 'generated-build-root', root: checkedRoot(buildRoot, 'The generated build root') };
  } else if (profileName === 'isolated') {
    const isolatedStateRoot = checkedRoot(stateRoot, 'The isolated profile state root');
    owner = { kind: 'isolated-generated-root', root: path.dirname(isolatedStateRoot) };
  } else {
    fail(`Unknown Standalone DBCode Profile: ${profileName}`);
  }
  const layout = {
    schema_version: 2,
    profile_schema_version: approvedIdentity.profile_schema_version,
    profile_name: profileName,
    product: { ...approvedIdentity.product },
    owner,
    permissions: { directory_mode: '0700', file_mode: '0600' },
    uses_natural_paths: profileName === 'default',
    paths: profilePaths(approvedIdentity, profileName, owner.root, stateRoot, extensionsRoot)
  };
  validateProfileLayout(layout, { identity: approvedIdentity, homeDirectory, buildRoot });
  return layout;
}

function validateProfileLayout(
  layout,
  { identity = loadProfileIdentity(), homeDirectory, buildRoot } = {}
) {
  if (!layout || typeof layout !== 'object' || Array.isArray(layout)) {
    fail('Standalone DBCode Profile layout is invalid.');
  }
  const approvedIdentity = validateProfileIdentity(identity);
  let expectedRoot;
  let ownerKind;
  let isolatedStateRoot;
  if (layout.profile_name === 'default') {
    expectedRoot = checkedRoot(homeDirectory ?? layout.owner?.root, 'The current user home directory');
    ownerKind = 'current-user-home';
  } else if (layout.profile_name === 'qa') {
    expectedRoot = checkedRoot(buildRoot ?? layout.owner?.root, 'The generated build root');
    ownerKind = 'generated-build-root';
  } else if (layout.profile_name === 'isolated') {
    expectedRoot = checkedRoot(layout.owner?.root, 'The isolated profile owner root');
    isolatedStateRoot = checkedRoot(layout.paths?.state, 'The isolated profile state root');
    ownerKind = 'isolated-generated-root';
  } else {
    fail(`Unknown Standalone DBCode Profile: ${layout.profile_name}`);
  }
  const expected = {
    schema_version: 2,
    profile_schema_version: approvedIdentity.profile_schema_version,
    profile_name: layout.profile_name,
    product: { ...approvedIdentity.product },
    owner: {
      kind: ownerKind,
      root: expectedRoot
    },
    permissions: { directory_mode: '0700', file_mode: '0600' },
    uses_natural_paths: layout.profile_name === 'default',
    paths: profilePaths(
      approvedIdentity,
      layout.profile_name,
      expectedRoot,
      isolatedStateRoot,
      layout.profile_name === 'isolated' ? layout.paths?.extensions : undefined
    )
  };
  if (!isDeepStrictEqual(layout, expected)) {
    fail('Standalone DBCode Profile layout does not match the approved layout.');
  }
  for (const profilePath of Object.values(layout.paths)) {
    if (!path.isAbsolute(profilePath) || !contains(expectedRoot, profilePath)) {
      fail('Standalone DBCode Profile layout contains an unsafe path.');
    }
  }
  return layout;
}

function assertSafeMutationPaths(layout, pathNames) {
  validateProfileLayout(layout);
  if (!Array.isArray(pathNames) || pathNames.length === 0) {
    fail('At least one Standalone DBCode Profile mutation path is required.');
  }
  let ownerMetadata;
  try {
    ownerMetadata = fs.lstatSync(layout.owner.root);
  } catch (error) {
    if (error?.code === 'ENOENT') {
      fail(`Standalone DBCode Profile owner root does not exist: ${layout.owner.root}`);
    }
    throw error;
  }
  if (ownerMetadata.isSymbolicLink()) {
    fail(`Standalone DBCode Profile owner root is a symbolic link: ${layout.owner.root}`);
  }
  if (!ownerMetadata.isDirectory()) {
    fail(`Standalone DBCode Profile owner root is not a directory: ${layout.owner.root}`);
  }
  for (const name of pathNames) {
    if (!PATH_NAMES.has(name)) {
      fail(`Unknown Standalone DBCode Profile path: ${name}`);
    }
    const target = layout.paths[name];
    const relative = path.relative(layout.owner.root, target);
    const parts = relative === '' ? [] : relative.split(path.sep);
    let current = layout.owner.root;
    for (const part of parts) {
      current = path.join(current, part);
      let metadata;
      try {
        metadata = fs.lstatSync(current);
      } catch (error) {
        if (error?.code === 'ENOENT') {
          break;
        }
        throw error;
      }
      if (metadata.isSymbolicLink()) {
        fail(`Standalone DBCode Profile mutation path contains a symbolic link: ${current}`);
      }
    }
  }
  return layout;
}

function parseMatchingLayout(value, expectedLayout) {
  if (value === undefined) {
    return expectedLayout;
  }
  if (typeof value !== 'string' || value.length > 64 * 1024) {
    fail('DBCODE_WRAPPER_PROFILE_LAYOUT_JSON is invalid.');
  }
  let supplied;
  try {
    supplied = JSON.parse(value);
  } catch {
    fail('DBCODE_WRAPPER_PROFILE_LAYOUT_JSON is not valid JSON.');
  }
  validateProfileLayout(supplied);
  if (!isDeepStrictEqual(supplied, expectedLayout)) {
    fail('DBCODE_WRAPPER_PROFILE_LAYOUT_JSON does not match the active Standalone DBCode Profile.');
  }
  return supplied;
}

module.exports = {
  PROFILE_IDENTITY_PATH,
  assertSafeMutationPaths,
  contains,
  createProfileLayout,
  loadProfileIdentity,
  parseMatchingLayout,
  validateProfileIdentity,
  validateProfileLayout
};
