'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { isDeepStrictEqual } = require('node:util');

const PRODUCT = Object.freeze({
  appName: 'DBCode Wrapper',
  dataFolderName: '.dbcode-wrapper',
  sharedDataFolderName: '.dbcode-wrapper-shared',
  profileSchemaVersion: 1
});
const PATH_NAMES = new Set(['state', 'user_data', 'extensions', 'shared_data', 'backup', 'cache', 'logs']);

function fail(message) {
  throw new Error(message);
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

function profilePaths(profileName, ownerRoot, isolatedStateRoot, isolatedExtensionsRoot) {
  if (profileName === 'default') {
    const userData = path.join(ownerRoot, 'Library/Application Support', PRODUCT.appName);
    return {
      state: path.join(ownerRoot, PRODUCT.dataFolderName),
      user_data: userData,
      extensions: path.join(ownerRoot, PRODUCT.dataFolderName, 'extensions'),
      shared_data: path.join(ownerRoot, PRODUCT.sharedDataFolderName),
      backup: path.join(ownerRoot, 'Library/Application Support', `${PRODUCT.appName} Profile Backups`),
      cache: path.join(userData, 'Cache'),
      logs: path.join(userData, 'logs')
    };
  }
  if (profileName === 'qa') {
    const state = path.join(ownerRoot, 'qa/profile');
    return {
      state,
      user_data: path.join(state, 'user-data'),
      extensions: path.join(state, 'extensions'),
      shared_data: path.join(state, 'shared-data'),
      backup: path.join(ownerRoot, 'qa/profile-backups'),
      cache: path.join(state, 'cache'),
      logs: path.join(state, 'logs')
    };
  }
  if (profileName === 'isolated') {
    const state = checkedRoot(isolatedStateRoot, 'The isolated profile state root');
    if (!contains(ownerRoot, state) || state === ownerRoot) {
      fail('The isolated profile state root must stay below its owner root.');
    }
    const extensions = isolatedExtensionsRoot === undefined
      ? path.join(state, 'extensions')
      : checkedRoot(isolatedExtensionsRoot, 'The isolated profile extension root');
    if (!contains(ownerRoot, extensions)) {
      fail('The isolated profile extension root must stay below its owner root.');
    }
    return {
      state,
      user_data: path.join(state, 'user-data'),
      extensions,
      shared_data: path.join(state, 'shared-data'),
      backup: `${state}-backups`,
      cache: path.join(state, 'cache'),
      logs: path.join(state, 'logs')
    };
  }
  fail(`Unknown Standalone DBCode Profile: ${profileName}`);
}

function createProfileLayout({ profileName, homeDirectory, buildRoot, stateRoot, extensionsRoot }) {
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
    schema_version: 1,
    profile_schema_version: PRODUCT.profileSchemaVersion,
    profile_name: profileName,
    product: {
      app_name: PRODUCT.appName,
      data_folder_name: PRODUCT.dataFolderName,
      shared_data_folder_name: PRODUCT.sharedDataFolderName
    },
    owner,
    permissions: { directory_mode: '0700', file_mode: '0600' },
    uses_natural_paths: profileName === 'default',
    paths: profilePaths(profileName, owner.root, stateRoot, extensionsRoot)
  };
  validateProfileLayout(layout, { homeDirectory, buildRoot });
  return layout;
}

function validateProfileLayout(layout, { homeDirectory, buildRoot } = {}) {
  if (!layout || typeof layout !== 'object' || Array.isArray(layout)) {
    fail('Standalone DBCode Profile layout is invalid.');
  }
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
    schema_version: 1,
    profile_schema_version: PRODUCT.profileSchemaVersion,
    profile_name: layout.profile_name,
    product: {
      app_name: PRODUCT.appName,
      data_folder_name: PRODUCT.dataFolderName,
      shared_data_folder_name: PRODUCT.sharedDataFolderName
    },
    owner: {
      kind: ownerKind,
      root: expectedRoot
    },
    permissions: { directory_mode: '0700', file_mode: '0600' },
    uses_natural_paths: layout.profile_name === 'default',
    paths: profilePaths(
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
  PRODUCT,
  assertSafeMutationPaths,
  contains,
  createProfileLayout,
  parseMatchingLayout,
  validateProfileLayout
};
