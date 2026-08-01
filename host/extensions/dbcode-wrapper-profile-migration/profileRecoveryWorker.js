'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs/promises');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { recreateStandaloneProfile, validateLayout } = require('./profileRecovery');

function createNodeRuntime() {
  return Object.freeze({
    filesystem: fs,
    now: () => new Date(),
    randomUUID: () => crypto.randomUUID(),
    processExists(pid) {
      try {
        process.kill(pid, 0);
        return true;
      } catch (error) {
        return error?.code === 'EPERM';
      }
    },
    sleep: milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds)),
    relaunchApplication(appExecutable, relaunchArgs) {
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
  });
}

function validateRuntime(runtime) {
  if (
    !runtime ||
    typeof runtime !== 'object' ||
    !runtime.filesystem ||
    typeof runtime.filesystem.lstat !== 'function' ||
    typeof runtime.filesystem.mkdir !== 'function' ||
    typeof runtime.filesystem.chmod !== 'function' ||
    typeof runtime.filesystem.writeFile !== 'function' ||
    typeof runtime.filesystem.rename !== 'function' ||
    typeof runtime.filesystem.rm !== 'function' ||
    typeof runtime.now !== 'function' ||
    typeof runtime.randomUUID !== 'function' ||
    typeof runtime.processExists !== 'function' ||
    typeof runtime.sleep !== 'function' ||
    typeof runtime.relaunchApplication !== 'function'
  ) {
    throw new Error('Profile recovery worker runtime is invalid.');
  }
  return runtime;
}

function runtimeNowIso(runtime) {
  const now = runtime.now();
  if (!(now instanceof Date) || Number.isNaN(now.getTime())) {
    throw new Error('Profile recovery worker clock is invalid.');
  }
  return now.toISOString();
}

async function waitForProcessesToExit(pids, runtime, timeoutMs = 10 * 60 * 1000) {
  const deadline = runtime.now().getTime() + timeoutMs;
  while (pids.some(pid => runtime.processExists(pid))) {
    if (runtime.now().getTime() >= deadline) {
      throw new Error('DBCode Wrapper did not quit, so profile recreation was cancelled.');
    }
    await runtime.sleep(250);
  }
}

async function writeOutcome(backupRoot, name, contents, runtime) {
  const runtimeFs = runtime.filesystem;
  if (typeof backupRoot !== 'string' || !path.isAbsolute(backupRoot) || path.resolve(backupRoot) === path.parse(path.resolve(backupRoot)).root) {
    throw new Error('Profile recovery received an invalid outcome directory.');
  }
  if (typeof name !== 'string' || path.basename(name) !== name || name.length === 0) {
    throw new Error('Profile recovery received an invalid outcome filename.');
  }
  await runtimeFs.mkdir(backupRoot, { recursive: true, mode: 0o700 });
  const backupMetadata = await runtimeFs.lstat(backupRoot);
  if (backupMetadata.isSymbolicLink() || !backupMetadata.isDirectory()) {
    throw new Error('The profile recovery outcome directory must be a real directory.');
  }
  await runtimeFs.chmod(backupRoot, 0o700);
  const destination = path.join(backupRoot, name);
  const temporary = path.join(
    backupRoot,
    `.${name}.${process.pid}.${runtime.randomUUID()}.tmp`
  );
  try {
    await runtimeFs.writeFile(temporary, `${JSON.stringify(contents, null, 2)}\n`, { encoding: 'utf8', flag: 'wx', mode: 0o600 });
    await runtimeFs.chmod(temporary, 0o600);
    await runtimeFs.rename(temporary, destination);
    await runtimeFs.chmod(destination, 0o600);
  } finally {
    await runtimeFs.rm(temporary, { force: true }).catch(() => undefined);
  }
}

async function validateWorkerRequest(request, runtime) {
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
    const appMetadata = await runtime.filesystem.lstat(normalized.appBundle);
    if (appMetadata.isSymbolicLink() || !appMetadata.isDirectory()) {
      throw new Error('Profile recovery requires the real DBCode Wrapper application bundle.');
    }
    normalized.appExecutable = applicationExecutable(normalized.appBundle);
    const executableMetadata = await runtime.filesystem.lstat(normalized.appExecutable);
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

function shouldRelaunchApplication(request, processesExited, outcome) {
  return request?.relaunchApplication !== false && processesExited && outcome?.status === 'complete';
}

async function run(request, runtime = createNodeRuntime()) {
  const workerRuntime = validateRuntime(runtime);
  let validatedRequest;
  let outcome;
  let processesExited = false;
  try {
    validatedRequest = await validateWorkerRequest(request, workerRuntime);
    await waitForProcessesToExit(validatedRequest.processPids, workerRuntime);
    processesExited = true;
    const recovery = await recreateStandaloneProfile(validatedRequest);
    outcome = {
      schemaVersion: 1,
      status: 'complete',
      backupDirectory: recovery.backupDirectory,
      completedAt: runtimeNowIso(workerRuntime)
    };
    await writeOutcome(validatedRequest.backupRoot, 'last-recovery.json', outcome, workerRuntime);
  } catch (error) {
    outcome = {
      schemaVersion: 1,
      status: 'failed',
      message: error instanceof Error ? error.message : 'Profile recreation failed.',
      failedAt: runtimeNowIso(workerRuntime)
    };
    if (validatedRequest) {
      await writeOutcome(
        validatedRequest.backupRoot,
        'last-recovery.json',
        outcome,
        workerRuntime
      ).catch(() => undefined);
    }
  } finally {
    if (shouldRelaunchApplication(validatedRequest, processesExited, outcome)) {
      await workerRuntime.relaunchApplication(
        validatedRequest.appExecutable,
        validatedRequest.relaunchArgs
      ).catch(async error => {
        await writeOutcome(validatedRequest.backupRoot, 'last-recovery.json', {
          ...outcome,
          relaunchWarning: error.message
        }, workerRuntime).catch(() => undefined);
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

module.exports = { run };
