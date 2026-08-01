'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs/promises');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { recreateStandaloneProfile, validateLayout } = require('./profileRecovery');

function processExists(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return error?.code === 'EPERM';
  }
}

async function waitForProcessesToExit(pids, timeoutMs = 10 * 60 * 1000) {
  const deadline = Date.now() + timeoutMs;
  while (pids.some(processExists)) {
    if (Date.now() >= deadline) {
      throw new Error('DBCode Wrapper did not quit, so profile recreation was cancelled.');
    }
    await new Promise(resolve => setTimeout(resolve, 250));
  }
}

async function writeOutcome(backupRoot, name, contents) {
  if (typeof backupRoot !== 'string' || !path.isAbsolute(backupRoot) || path.resolve(backupRoot) === path.parse(path.resolve(backupRoot)).root) {
    throw new Error('Profile recovery received an invalid outcome directory.');
  }
  if (typeof name !== 'string' || path.basename(name) !== name || name.length === 0) {
    throw new Error('Profile recovery received an invalid outcome filename.');
  }
  await fs.mkdir(backupRoot, { recursive: true, mode: 0o700 });
  const backupMetadata = await fs.lstat(backupRoot);
  if (backupMetadata.isSymbolicLink() || !backupMetadata.isDirectory()) {
    throw new Error('The profile recovery outcome directory must be a real directory.');
  }
  await fs.chmod(backupRoot, 0o700);
  const destination = path.join(backupRoot, name);
  const temporary = path.join(backupRoot, `.${name}.${process.pid}.${crypto.randomUUID()}.tmp`);
  try {
    await fs.writeFile(temporary, `${JSON.stringify(contents, null, 2)}\n`, { encoding: 'utf8', flag: 'wx', mode: 0o600 });
    await fs.chmod(temporary, 0o600);
    await fs.rename(temporary, destination);
    await fs.chmod(destination, 0o600);
  } finally {
    await fs.rm(temporary, { force: true }).catch(() => undefined);
  }
}

async function validateWorkerRequest(request) {
  if (!request || typeof request !== 'object' || Array.isArray(request)) {
    throw new Error('Profile recovery received an invalid request.');
  }
  if (!Array.isArray(request.processPids) || request.processPids.length === 0 || request.processPids.some(pid => !Number.isInteger(pid) || pid < 1)) {
    throw new Error('Profile recovery received an invalid process list.');
  }
  if (!Array.isArray(request.relaunchArgs) || request.relaunchArgs.some(argument => typeof argument !== 'string')) {
    throw new Error('Profile recovery received invalid relaunch arguments.');
  }
  const layout = validateLayout(request);
  const normalized = {
    processPids: [...new Set(request.processPids)],
    recoveryId: layout.recoveryId,
    profileLayout: layout.profileLayout,
    userDataRoot: layout.userDataRoot,
    sharedDataRoot: layout.sharedDataRoot,
    backupRoot: layout.backupRoot,
    settingsSource: layout.settingsSource,
    appBundle: request.appBundle,
    relaunchArgs: [...request.relaunchArgs],
    relaunchApplication: request.relaunchApplication !== false
  };
  if (normalized.relaunchApplication) {
    if (typeof request.appBundle !== 'string' || !path.isAbsolute(request.appBundle) || path.extname(request.appBundle) !== '.app') {
      throw new Error('Profile recovery received an invalid application bundle.');
    }
    normalized.appBundle = path.resolve(request.appBundle);
    const appMetadata = await fs.lstat(normalized.appBundle);
    if (appMetadata.isSymbolicLink() || !appMetadata.isDirectory()) {
      throw new Error('Profile recovery requires the real DBCode Wrapper application bundle.');
    }
    normalized.appExecutable = applicationExecutable(normalized.appBundle);
    const executableMetadata = await fs.lstat(normalized.appExecutable);
    if (executableMetadata.isSymbolicLink() || !executableMetadata.isFile()) {
      throw new Error('Profile recovery requires the real DBCode Wrapper application executable.');
    }
  }
  Object.freeze(normalized.processPids);
  Object.freeze(normalized.relaunchArgs);
  return Object.freeze(normalized);
}

function applicationExecutable(appBundle) {
  const resolvedBundle = path.resolve(appBundle);
  return path.join(resolvedBundle, 'Contents', 'MacOS', path.basename(resolvedBundle, '.app'));
}

function reopenApplication(appExecutable, relaunchArgs) {
  return new Promise((resolve, reject) => {
    const environment = { ...process.env };
    delete environment.ELECTRON_RUN_AS_NODE;
    const child = spawn(appExecutable, relaunchArgs, {
      detached: true,
      stdio: 'ignore',
      env: environment
    });
    child.once('error', reject);
    child.once('spawn', () => {
      child.unref();
      resolve();
    });
  });
}

function shouldRelaunchApplication(request, processesExited, outcome) {
  return request?.relaunchApplication !== false && processesExited && outcome?.status === 'complete';
}

async function run(request) {
  let validatedRequest;
  let outcome;
  let processesExited = false;
  try {
    validatedRequest = await validateWorkerRequest(request);
    await waitForProcessesToExit(validatedRequest.processPids);
    processesExited = true;
    const recovery = await recreateStandaloneProfile(validatedRequest);
    outcome = {
      schemaVersion: 1,
      status: 'complete',
      backupDirectory: recovery.backupDirectory,
      completedAt: new Date().toISOString()
    };
    await writeOutcome(validatedRequest.backupRoot, 'last-recovery.json', outcome);
  } catch (error) {
    outcome = {
      schemaVersion: 1,
      status: 'failed',
      message: error instanceof Error ? error.message : 'Profile recreation failed.',
      failedAt: new Date().toISOString()
    };
    if (validatedRequest) {
      await writeOutcome(validatedRequest.backupRoot, 'last-recovery.json', outcome).catch(() => undefined);
    }
  } finally {
    if (shouldRelaunchApplication(validatedRequest, processesExited, outcome)) {
      await reopenApplication(validatedRequest.appExecutable, validatedRequest.relaunchArgs).catch(async error => {
        await writeOutcome(validatedRequest.backupRoot, 'last-recovery.json', {
          ...outcome,
          relaunchWarning: error.message
        }).catch(() => undefined);
      });
    }
  }
  return outcome;
}

if (require.main === module) {
  let request;
  try {
    request = JSON.parse(process.argv[2]);
  } catch {
    process.stderr.write('Profile recovery worker received an invalid request.\n');
    process.exit(2);
  }

  run(request)
    .then(outcome => {
      if (outcome.status !== 'complete') {
        process.stderr.write(`${outcome.message}\n`);
        process.exitCode = 1;
      }
    })
    .catch(error => {
      process.stderr.write(`${error instanceof Error ? error.message : 'Profile recovery worker failed.'}\n`);
      process.exitCode = 1;
    });
}

module.exports = { applicationExecutable, run, shouldRelaunchApplication, validateWorkerRequest, writeOutcome };
