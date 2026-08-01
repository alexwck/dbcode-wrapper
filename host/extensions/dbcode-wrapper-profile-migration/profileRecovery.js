'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');
const {
  assertSafeMutationPaths,
  contains,
  createProfileLayout,
  parseMatchingLayout,
  validateProfileLayout
} = require('./profile-layout');

function checkedPath(label, value) {
  if (typeof value !== 'string' || !path.isAbsolute(value)) {
    throw new Error(`${label} must be an absolute path.`);
  }
  const resolved = path.resolve(value);
  if (resolved === path.parse(resolved).root) {
    throw new Error(`${label} is too broad for profile recovery.`);
  }
  return resolved;
}

function requireMatchingEnvironmentPath(environment, name, expected) {
  const supplied = environment?.[name];
  if (supplied === undefined) {
    return;
  }
  if (typeof supplied !== 'string' || !path.isAbsolute(supplied) || path.resolve(supplied) !== expected) {
    throw new Error(`${name} does not match the active Standalone DBCode Profile.`);
  }
}

function requireMatchingRelaunchPath(relaunchArgs, flag, expected) {
  const values = [];
  for (let index = 0; index < relaunchArgs.length; index++) {
    const argument = relaunchArgs[index];
    if (argument === flag) {
      values.push(relaunchArgs[index + 1]);
    } else if (argument.startsWith(`${flag}=`)) {
      values.push(argument.slice(flag.length + 1));
    }
  }
  if (values.length > 1) {
    throw new Error(`Profile recovery received more than one ${flag} argument.`);
  }
  if (values.length === 1) {
    const supplied = values[0];
    if (typeof supplied !== 'string' || !path.isAbsolute(supplied) || path.resolve(supplied) !== expected) {
      throw new Error(`${flag} does not match the active Standalone DBCode Profile.`);
    }
  }
}

function deriveRecoveryLayout({ userDataRoot, homeDirectory, appRoot, environment = {} }) {
  const resolvedUserDataRoot = checkedPath('The Standalone DBCode Profile user-data directory', userDataRoot);
  const resolvedHomeDirectory = checkedPath('The current user home directory', homeDirectory);
  const resolvedAppRoot = checkedPath('The DBCode Wrapper application root', appRoot);
  const appBundle = path.resolve(resolvedAppRoot, '../../..');
  if (path.extname(appBundle) !== '.app') {
    throw new Error('Profile recovery could not identify the DBCode Wrapper application bundle safely.');
  }

  let profileLayout = createProfileLayout({
    profileName: 'default',
    homeDirectory: resolvedHomeDirectory,
    buildRoot: path.join(resolvedHomeDirectory, '.dbcode-wrapper-build-not-used')
  });
  profileLayout = parseMatchingLayout(environment.DBCODE_WRAPPER_PROFILE_LAYOUT_JSON, profileLayout);
  const { state, user_data: expectedUserDataRoot, extensions: extensionsRoot, shared_data: sharedDataRoot,
    backup: backupRoot, cache: cacheRoot, logs: logsRoot } = profileLayout.paths;
  if (resolvedUserDataRoot !== expectedUserDataRoot) {
    throw new Error('The user-data directory does not match the active Standalone DBCode Profile.');
  }
  for (const recoveryPath of [resolvedUserDataRoot, sharedDataRoot, backupRoot]) {
    if (contains(extensionsRoot, recoveryPath) || contains(recoveryPath, extensionsRoot)) {
      throw new Error('The verified extensions must stay outside profile recovery.');
    }
  }

  requireMatchingEnvironmentPath(environment, 'DBCODE_WRAPPER_EXTENSIONS_ROOT', extensionsRoot);
  requireMatchingEnvironmentPath(environment, 'DBCODE_WRAPPER_SHARED_DATA_ROOT', sharedDataRoot);
  requireMatchingEnvironmentPath(environment, 'DBCODE_WRAPPER_PROFILE_BACKUP_ROOT', backupRoot);
  requireMatchingEnvironmentPath(environment, 'DBCODE_WRAPPER_APP_BUNDLE', appBundle);
  return {
    profileLayout,
    stateRoot: state,
    userDataRoot: resolvedUserDataRoot,
    extensionsRoot,
    sharedDataRoot,
    backupRoot,
    cacheRoot,
    logsRoot,
    appBundle
  };
}

async function rejectSymlink(target, label, allowMissing = false) {
  try {
    const metadata = await fs.lstat(target);
    if (metadata.isSymbolicLink()) {
      throw new Error(`${label} must not be a symbolic link.`);
    }
    return metadata;
  } catch (error) {
    if (allowMissing && error?.code === 'ENOENT') {
      return undefined;
    }
    throw error;
  }
}

function validateLayout(options) {
  const { userDataRoot, sharedDataRoot, backupRoot, settingsSource, recoveryId, profileLayout } = options;
  const layout = {
    userDataRoot: checkedPath('The Standalone DBCode Profile user-data directory', userDataRoot),
    sharedDataRoot: checkedPath('The Standalone DBCode Profile shared-data directory', sharedDataRoot),
    backupRoot: checkedPath('The Standalone DBCode Profile recovery directory', backupRoot),
    settingsSource: checkedPath('The managed settings template', settingsSource),
    directoryMode: 0o700,
    fileMode: 0o600
  };
  if (profileLayout !== undefined) {
    validateProfileLayout(profileLayout);
    if (
      layout.userDataRoot !== profileLayout.paths.user_data ||
      layout.sharedDataRoot !== profileLayout.paths.shared_data ||
      layout.backupRoot !== profileLayout.paths.backup
    ) {
      throw new Error('Profile recovery paths do not match the active Standalone DBCode Profile layout.');
    }
    assertSafeMutationPaths(profileLayout, ['user_data', 'shared_data', 'backup']);
    layout.profileLayout = profileLayout;
    layout.directoryMode = Number.parseInt(profileLayout.permissions.directory_mode, 8);
    layout.fileMode = Number.parseInt(profileLayout.permissions.file_mode, 8);
  }
  if (layout.userDataRoot === layout.sharedDataRoot || contains(layout.userDataRoot, layout.sharedDataRoot) || contains(layout.sharedDataRoot, layout.userDataRoot)) {
    throw new Error('Standalone DBCode Profile user data and shared data must be separate directories.');
  }
  for (const target of [layout.userDataRoot, layout.sharedDataRoot]) {
    if (contains(target, layout.backupRoot) || contains(layout.backupRoot, target)) {
      throw new Error('The recovery directory must stay outside the profile directories being recreated.');
    }
    if (contains(target, layout.settingsSource)) {
      throw new Error('The managed settings template must stay outside the profile directories being recreated.');
    }
  }
  if (typeof recoveryId !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9._-]{5,100}$/.test(recoveryId)) {
    throw new Error('The recovery identifier is not safe.');
  }
  layout.recoveryId = recoveryId;
  layout.backupDirectory = path.join(layout.backupRoot, recoveryId);
  return layout;
}

async function recreateStandaloneProfile(options) {
  const layout = validateLayout(options);
  const settingsMetadata = await rejectSymlink(layout.settingsSource, 'The managed settings template');
  if (!settingsMetadata.isFile()) {
    throw new Error('The managed settings template must be a regular file.');
  }
  const settingsContents = await fs.readFile(layout.settingsSource);
  await rejectSymlink(layout.backupRoot, 'The Standalone DBCode Profile recovery directory', true);

  const targets = [
    { label: 'user-data', path: layout.userDataRoot },
    { label: 'shared-data', path: layout.sharedDataRoot }
  ];
  for (const target of targets) {
    const metadata = await rejectSymlink(target.path, `The Standalone DBCode Profile ${target.label} directory`, true);
    if (metadata && !metadata.isDirectory()) {
      throw new Error(`The Standalone DBCode Profile ${target.label} path must be a directory.`);
    }
    target.exists = Boolean(metadata);
  }

  await fs.mkdir(layout.backupRoot, { recursive: true, mode: layout.directoryMode });
  await fs.chmod(layout.backupRoot, layout.directoryMode);
  await fs.mkdir(layout.backupDirectory, { mode: layout.directoryMode });

  const moved = [];
  const created = [];
  try {
    for (const target of targets) {
      if (target.exists) {
        const destination = path.join(layout.backupDirectory, target.label);
        await fs.rename(target.path, destination);
        moved.push({ ...target, destination });
      }
    }

    await fs.mkdir(layout.userDataRoot, { recursive: true, mode: layout.directoryMode });
    created.push(layout.userDataRoot);
    await fs.chmod(layout.userDataRoot, layout.directoryMode);
    const userSettingsRoot = path.join(layout.userDataRoot, 'User');
    await fs.mkdir(userSettingsRoot, { mode: layout.directoryMode });
    const settingsDestination = path.join(userSettingsRoot, 'settings.json');
    await fs.writeFile(settingsDestination, settingsContents, { flag: 'wx', mode: layout.fileMode });
    await fs.chmod(settingsDestination, layout.fileMode);

    await fs.mkdir(layout.sharedDataRoot, { recursive: true, mode: layout.directoryMode });
    created.push(layout.sharedDataRoot);
    await fs.chmod(layout.sharedDataRoot, layout.directoryMode);

    const manifestPath = path.join(layout.backupDirectory, 'recovery.json');
    await fs.writeFile(manifestPath, `${JSON.stringify({
      schemaVersion: 1,
      recoveryId: layout.recoveryId,
      profile: 'Standalone DBCode Profile',
      backedUp: moved.map(item => ({ label: item.label, originalPath: item.path }))
    }, null, 2)}\n`, { encoding: 'utf8', flag: 'wx', mode: layout.fileMode });
    await fs.chmod(manifestPath, layout.fileMode);
  } catch (error) {
    const rollbackFailures = [];
    for (const createdPath of created.reverse()) {
      await fs.rm(createdPath, { recursive: true, force: true }).catch(rollbackError => rollbackFailures.push(rollbackError));
    }
    for (const item of moved.reverse()) {
      await fs.rename(item.destination, item.path).catch(rollbackError => rollbackFailures.push(rollbackError));
    }
    if (rollbackFailures.length > 0) {
      throw new Error(`Profile recreation stopped and could not restore every moved folder. The owner-only recovery data remains at ${layout.backupDirectory}.`);
    }
    await fs.rm(layout.backupDirectory, { recursive: true, force: true }).catch(() => undefined);
    throw error;
  }

  return {
    backupDirectory: layout.backupDirectory,
    userDataRoot: layout.userDataRoot,
    sharedDataRoot: layout.sharedDataRoot
  };
}

module.exports = { deriveRecoveryLayout, recreateStandaloneProfile, requireMatchingRelaunchPath, validateLayout };
