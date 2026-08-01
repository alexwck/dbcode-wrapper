'use strict';

const { spawn, execFileSync } = require('node:child_process');
const fs = require('node:fs');
const fsp = require('node:fs/promises');
const path = require('node:path');

const COMPLETION_MODES = new Set(['leave-running', 'wait-for-exit', 'quit-after-ready']);
const RESULT_STATUSES = new Set(['ready', 'complete', 'failed']);
const SIGNALS = Object.freeze({ graceful: 'SIGTERM', force: 'SIGKILL' });

function fail(message) {
  throw new Error(message);
}

function isRecord(value) {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value);
}

function requireExactKeys(value, keys, label) {
  if (!isRecord(value) || JSON.stringify(Object.keys(value).sort()) !== JSON.stringify([...keys].sort())) {
    fail(`${label} is invalid.`);
  }
}

function requireAbsolutePath(value, label) {
  if (typeof value !== 'string' || !path.isAbsolute(value) || path.resolve(value) === path.parse(path.resolve(value)).root) {
    fail(`${label} must be a safe absolute path.`);
  }
}

function requireInteger(value, minimum, maximum, label) {
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    fail(`${label} must be an integer from ${minimum} to ${maximum}.`);
  }
}

function validatePattern(pattern, label) {
  requireExactKeys(pattern, ['kind', 'value'], label);
  if (!['literal', 'regex'].includes(pattern.kind) || typeof pattern.value !== 'string' || pattern.value.length === 0 || pattern.value.length > 1000) {
    fail(`${label} is invalid.`);
  }
  if (pattern.kind === 'regex') {
    try {
      new RegExp(pattern.value);
    } catch {
      fail(`${label} contains an invalid regular expression.`);
    }
  }
}

function validatePatterns(patterns, label) {
  if (!Array.isArray(patterns) || patterns.length > 50) {
    fail(`${label} must be an array with at most 50 entries.`);
  }
  patterns.forEach((pattern, index) => validatePattern(pattern, `${label}[${index}]`));
}

function validateSessionPolicy(policy) {
  requireExactKeys(policy, [
    'schema_version',
    'session_id',
    'executable',
    'arguments',
    'environment',
    'host_log',
    'log_root',
    'readiness',
    'completion'
  ], 'Host Session policy');
  if (policy.schema_version !== 1) {
    fail('Host Session policy uses an unsupported schema version.');
  }
  if (typeof policy.session_id !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9._-]{2,100}$/.test(policy.session_id)) {
    fail('Host Session identifier is invalid.');
  }
  requireAbsolutePath(policy.executable, 'Host Session executable');
  requireAbsolutePath(policy.host_log, 'Host Session host log');
  requireAbsolutePath(policy.log_root, 'Host Session log root');
  if (!Array.isArray(policy.arguments) || policy.arguments.length > 500 || policy.arguments.some(argument => typeof argument !== 'string')) {
    fail('Host Session arguments are invalid.');
  }
  if (!isRecord(policy.environment) || Object.entries(policy.environment).some(([name, value]) => (
    !/^[A-Za-z_][A-Za-z0-9_]*$/.test(name) || typeof value !== 'string' || value.length > 64 * 1024
  ))) {
    fail('Host Session environment is invalid.');
  }

  requireExactKeys(policy.readiness, [
    'timeout_seconds',
    'poll_interval_ms',
    'renderer',
    'dbcode',
    'host_log_patterns',
    'fatal_host_log_patterns'
  ], 'Host Session readiness policy');
  requireInteger(policy.readiness.timeout_seconds, 1, 600, 'Host Session readiness timeout');
  requireInteger(policy.readiness.poll_interval_ms, 10, 5000, 'Host Session poll interval');
  requireExactKeys(policy.readiness.renderer, ['command_contains', 'stable_observations'], 'Host Session renderer policy');
  if (
    !Array.isArray(policy.readiness.renderer.command_contains) ||
    policy.readiness.renderer.command_contains.length === 0 ||
    policy.readiness.renderer.command_contains.some(value => typeof value !== 'string' || value.length === 0)
  ) {
    fail('Host Session renderer command match is invalid.');
  }
  requireInteger(policy.readiness.renderer.stable_observations, 1, 20, 'Host Session stable renderer observations');
  requireExactKeys(policy.readiness.dbcode, ['required', 'log_suffix', 'patterns'], 'Host Session DBCode policy');
  if (typeof policy.readiness.dbcode.required !== 'boolean') {
    fail('Host Session DBCode requirement must be true or false.');
  }
  if (
    typeof policy.readiness.dbcode.log_suffix !== 'string' ||
    !policy.readiness.dbcode.log_suffix.startsWith('/') ||
    !policy.readiness.dbcode.log_suffix.endsWith('/dbcode.dbcode/DBCode.log')
  ) {
    fail('Host Session DBCode log suffix is invalid.');
  }
  validatePatterns(policy.readiness.dbcode.patterns, 'Host Session DBCode patterns');
  validatePatterns(policy.readiness.host_log_patterns, 'Host Session host-log patterns');
  validatePatterns(policy.readiness.fatal_host_log_patterns, 'Host Session fatal host-log patterns');

  requireExactKeys(policy.completion, [
    'mode',
    'require_dbcode_before_exit',
    'graceful_timeout_seconds',
    'force_timeout_seconds'
  ], 'Host Session completion policy');
  if (!COMPLETION_MODES.has(policy.completion.mode)) {
    fail('Host Session completion mode is invalid.');
  }
  if (typeof policy.completion.require_dbcode_before_exit !== 'boolean') {
    fail('Host Session post-exit DBCode requirement must be true or false.');
  }
  requireInteger(policy.completion.graceful_timeout_seconds, 1, 60, 'Host Session graceful quit timeout');
  requireInteger(policy.completion.force_timeout_seconds, 1, 30, 'Host Session forced quit timeout');
  return policy;
}

function patternMatches(text, pattern) {
  if (pattern.kind === 'literal') {
    return text.includes(pattern.value);
  }
  return new RegExp(pattern.value).test(text);
}

function matchesAll(text, patterns) {
  return patterns.every(pattern => patternMatches(text, pattern));
}

function matchesAny(text, patterns) {
  return patterns.some(pattern => patternMatches(text, pattern));
}

function descendantsOf(processes, rootPid) {
  const descendants = new Set([rootPid]);
  let changed = true;
  while (changed) {
    changed = false;
    for (const processRecord of processes) {
      if (descendants.has(processRecord.parent_pid) && !descendants.has(processRecord.pid)) {
        descendants.add(processRecord.pid);
        changed = true;
      }
    }
  }
  descendants.delete(rootPid);
  return descendants;
}

function findRenderer(processes, appPid, commandParts) {
  const descendants = descendantsOf(processes, appPid);
  return processes.find(processRecord => (
    descendants.has(processRecord.pid) && commandParts.every(part => processRecord.command.includes(part))
  ));
}

async function findDbcodeLog(policy, runtime, startedAtMs) {
  const candidates = await runtime.findFiles(policy.log_root, {
    suffix: policy.readiness.dbcode.log_suffix,
    modified_after_ms: startedAtMs
  });
  for (const candidate of candidates.sort()) {
    const contents = await runtime.readText(candidate);
    if (matchesAll(contents, policy.readiness.dbcode.patterns)) {
      return candidate;
    }
  }
  return null;
}

function isoNow(runtime) {
  return runtime.now().toISOString();
}

function initialResult(policy, appPid, runtime) {
  return {
    schema_version: 1,
    session_id: policy.session_id,
    status: 'failed',
    started_at: isoNow(runtime),
    ready_at: null,
    ended_at: null,
    process: {
      app_pid: appPid,
      renderer_pid: null,
      executable: policy.executable,
      parent_pid: null,
      command: null,
      exit_code: null
    },
    evidence: {
      host_log: policy.host_log,
      dbcode_log: null
    },
    readiness: {
      ready: false,
      renderer_ready: false,
      dbcode_ready: false,
      host_log_ready: policy.readiness.host_log_patterns.length === 0,
      stable_observations: 0
    },
    quit: {
      requested: false,
      graceful: false,
      forced: false,
      complete: false
    },
    failure: null
  };
}

function setFailure(result, code, message, runtime) {
  result.status = 'failed';
  result.failure = { code, message };
  result.ended_at = isoNow(runtime);
  return result;
}

async function waitUntilStopped(processIds, timeoutSeconds, pollIntervalMs, runtime) {
  const identifiers = Array.isArray(processIds) ? processIds : [processIds];
  const attempts = Math.max(1, Math.ceil((timeoutSeconds * 1000) / pollIntervalMs));
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    if (!(await Promise.all(identifiers.map(pid => runtime.isAlive(pid)))).some(Boolean)) {
      return true;
    }
    await runtime.sleep(pollIntervalMs);
  }
  return !(await Promise.all(identifiers.map(pid => runtime.isAlive(pid)))).some(Boolean);
}

async function assertMatchingLiveProcess(result, policy, runtime) {
  if (!(await runtime.isAlive(result.process.app_pid))) {
    return false;
  }
  const processes = await runtime.listProcesses();
  const current = processes.find(processRecord => processRecord.pid === result.process.app_pid);
  if (!current || !current.command.includes(policy.executable)) {
    fail('Host Session process no longer matches the recorded executable.');
  }
  result.process.parent_pid = current.parent_pid;
  result.process.command = current.command;
  return true;
}

async function stopValidatedHostSession(sessionResult, policy, runtime) {
  const result = parseSessionResult(serializeSessionResult(sessionResult));
  if (result.session_id !== policy.session_id || result.process.executable !== policy.executable) {
    fail('Host Session result does not match the stop policy.');
  }
  result.quit.requested = true;
  if (!(await assertMatchingLiveProcess(result, policy, runtime))) {
    result.quit.complete = true;
    result.quit.graceful = true;
    result.status = 'complete';
    result.failure = null;
    result.ended_at = isoNow(runtime);
    return result;
  }

  const signaledProcessIds = await runtime.signalTree(result.process.app_pid, SIGNALS.graceful);
  const processIds = Array.isArray(signaledProcessIds) && signaledProcessIds.length > 0
    ? signaledProcessIds
    : [result.process.app_pid];
  if (await waitUntilStopped(
    processIds,
    policy.completion.graceful_timeout_seconds,
    policy.readiness.poll_interval_ms,
    runtime
  )) {
    result.quit.graceful = true;
    result.quit.complete = true;
    result.status = 'complete';
    result.failure = null;
    result.ended_at = isoNow(runtime);
    return result;
  }

  await runtime.signalTree(result.process.app_pid, SIGNALS.force);
  result.quit.forced = true;
  if (await waitUntilStopped(
    processIds,
    policy.completion.force_timeout_seconds,
    policy.readiness.poll_interval_ms,
    runtime
  )) {
    result.quit.complete = true;
    result.status = 'complete';
    result.failure = null;
    result.ended_at = isoNow(runtime);
    return result;
  }
  return setFailure(result, 'quit-timeout', 'The DBCode Wrapper process did not stop after forced cleanup.', runtime);
}

async function stopHostSession(sessionResult, policy, runtime = createNodeRuntime()) {
  validateSessionPolicy(policy);
  return stopValidatedHostSession(sessionResult, policy, runtime);
}

async function cleanupFailedSession(result, policy, runtime) {
  if (await runtime.isAlive(result.process.app_pid)) {
    const failure = result.failure;
    const endedAt = result.ended_at;
    const stopped = await stopValidatedHostSession(result, policy, runtime);
    result.quit = stopped.quit;
    result.failure = failure;
    result.ended_at = endedAt;
    result.status = 'failed';
  }
  return result;
}

async function readinessObservation(policy, result, runtime, startedAtMs) {
  const hostText = await runtime.readText(policy.host_log);
  if (matchesAny(hostText, policy.readiness.fatal_host_log_patterns)) {
    return { fatal: true };
  }
  const processes = await runtime.listProcesses();
  const renderer = findRenderer(
    processes,
    result.process.app_pid,
    policy.readiness.renderer.command_contains
  );
  const rendererReady = Boolean(renderer && await runtime.isAlive(renderer.pid));
  const dbcodeLog = await findDbcodeLog(policy, runtime, startedAtMs);
  const dbcodeReady = Boolean(dbcodeLog);
  const hostLogReady = matchesAll(hostText, policy.readiness.host_log_patterns);
  const appProcess = processes.find(processRecord => processRecord.pid === result.process.app_pid);
  return { fatal: false, appProcess, renderer, rendererReady, dbcodeLog, dbcodeReady, hostLogReady };
}

async function collectPostExitDbcode(policy, result, runtime, startedAtMs) {
  const dbcodeLog = await findDbcodeLog(policy, runtime, startedAtMs);
  result.evidence.dbcode_log = dbcodeLog;
  result.readiness.dbcode_ready = Boolean(dbcodeLog);
  return Boolean(dbcodeLog);
}

async function runStartedHostSession(policy, runtime, hooks, startedAtMs, child, result) {
  const deadline = startedAtMs + policy.readiness.timeout_seconds * 1000;

  while (runtime.now().getTime() <= deadline) {
    if (!(await runtime.isAlive(child.pid))) {
      result.process.exit_code = await runtime.waitForExit(child.pid);
      return setFailure(result, 'process-exited', 'DBCode Wrapper exited before the session became ready.', runtime);
    }
    const observation = await readinessObservation(policy, result, runtime, startedAtMs);
    if (observation.fatal) {
      setFailure(result, 'fatal-host-log', 'DBCode Wrapper reported a fatal host or renderer error.', runtime);
      return cleanupFailedSession(result, policy, runtime);
    }
    result.process.renderer_pid = observation.renderer?.pid ?? null;
    result.process.parent_pid = observation.appProcess?.parent_pid ?? result.process.parent_pid;
    result.process.command = observation.appProcess?.command ?? result.process.command;
    result.readiness.renderer_ready = observation.rendererReady;
    result.evidence.dbcode_log = observation.dbcodeLog;
    result.readiness.dbcode_ready = observation.dbcodeReady;
    result.readiness.host_log_ready = observation.hostLogReady;
    const readyNow = observation.rendererReady &&
      observation.hostLogReady &&
      (!policy.readiness.dbcode.required || observation.dbcodeReady);
    result.readiness.stable_observations = readyNow
      ? result.readiness.stable_observations + 1
      : 0;
    if (result.readiness.stable_observations >= policy.readiness.renderer.stable_observations) {
      result.readiness.ready = true;
      result.ready_at = isoNow(runtime);
      break;
    }
    await runtime.sleep(policy.readiness.poll_interval_ms);
  }

  if (!result.readiness.ready) {
    const code = !result.readiness.renderer_ready
      ? 'renderer-timeout'
      : policy.readiness.dbcode.required && !result.readiness.dbcode_ready
        ? 'dbcode-timeout'
        : 'readiness-timeout';
    setFailure(result, code, 'DBCode Wrapper did not satisfy its readiness policy before the timeout.', runtime);
    return cleanupFailedSession(result, policy, runtime);
  }
  result.status = 'ready';
  if (typeof hooks.onReady === 'function') {
    await hooks.onReady(result);
  }

  if (policy.completion.mode === 'leave-running') {
    runtime.detach(child.pid);
    return result;
  }
  if (policy.completion.mode === 'quit-after-ready') {
    return stopValidatedHostSession(result, policy, runtime);
  }

  result.process.exit_code = await runtime.waitForExit(child.pid);
  result.quit.complete = true;
  result.quit.graceful = true;
  if (policy.completion.require_dbcode_before_exit &&
      !(await collectPostExitDbcode(policy, result, runtime, startedAtMs))) {
    return setFailure(result, 'dbcode-not-observed', 'DBCode did not activate before the application closed.', runtime);
  }
  result.status = 'complete';
  result.failure = null;
  result.ended_at = isoNow(runtime);
  return result;
}

async function runHostSession(policy, runtime = createNodeRuntime(), hooks = {}) {
  validateSessionPolicy(policy);
  const startedAtMs = runtime.now().getTime();
  const child = await runtime.spawn(policy);
  if (!child || !Number.isInteger(child.pid) || child.pid < 1) {
    fail('Host Session launcher did not return a valid process identifier.');
  }
  const result = initialResult(policy, child.pid, runtime);
  try {
    return await runStartedHostSession(policy, runtime, hooks, startedAtMs, child, result);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    setFailure(result, 'session-error', `Host Session could not observe or control the application. ${detail}`, runtime);
    result.quit.requested = true;
    result.quit.forced = true;
    try {
      await runtime.emergencyStop(child.pid);
      const knownProcessIds = [result.process.app_pid, result.process.renderer_pid].filter(Number.isInteger);
      result.quit.complete = await waitUntilStopped(
        knownProcessIds,
        policy.completion.force_timeout_seconds,
        policy.readiness.poll_interval_ms,
        runtime
      );
    } catch {
      result.quit.complete = false;
    }
    return result;
  }
}

function validateSessionResult(result) {
  requireExactKeys(result, [
    'schema_version', 'session_id', 'status', 'started_at', 'ready_at', 'ended_at',
    'process', 'evidence', 'readiness', 'quit', 'failure'
  ], 'Host Session result');
  if (result.schema_version !== 1 || !RESULT_STATUSES.has(result.status)) {
    fail('Host Session result is invalid.');
  }
  if (typeof result.session_id !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9._-]{2,100}$/.test(result.session_id)) {
    fail('Host Session result has an invalid identifier.');
  }
  for (const [name, value] of Object.entries({
    started_at: result.started_at,
    ready_at: result.ready_at,
    ended_at: result.ended_at
  })) {
    if (value !== null && (typeof value !== 'string' || Number.isNaN(Date.parse(value)))) {
      fail(`Host Session result has an invalid ${name}.`);
    }
  }
  requireExactKeys(result.process, [
    'app_pid', 'renderer_pid', 'executable', 'parent_pid', 'command', 'exit_code'
  ], 'Host Session process result');
  requireInteger(result.process.app_pid, 1, Number.MAX_SAFE_INTEGER, 'Host Session application PID');
  if (result.process.renderer_pid !== null) {
    requireInteger(result.process.renderer_pid, 1, Number.MAX_SAFE_INTEGER, 'Host Session renderer PID');
  }
  requireAbsolutePath(result.process.executable, 'Host Session result executable');
  if (result.process.parent_pid !== null) {
    requireInteger(result.process.parent_pid, 0, Number.MAX_SAFE_INTEGER, 'Host Session parent PID');
  }
  if (result.process.command !== null && typeof result.process.command !== 'string') {
    fail('Host Session process command is invalid.');
  }
  if (result.process.exit_code !== null && !Number.isInteger(result.process.exit_code)) {
    fail('Host Session exit code is invalid.');
  }
  requireExactKeys(result.evidence, ['host_log', 'dbcode_log'], 'Host Session evidence');
  requireAbsolutePath(result.evidence.host_log, 'Host Session result host log');
  if (result.evidence.dbcode_log !== null) {
    requireAbsolutePath(result.evidence.dbcode_log, 'Host Session result DBCode log');
  }
  requireExactKeys(result.readiness, [
    'ready', 'renderer_ready', 'dbcode_ready', 'host_log_ready', 'stable_observations'
  ], 'Host Session readiness result');
  if (['ready', 'renderer_ready', 'dbcode_ready', 'host_log_ready'].some(name => typeof result.readiness[name] !== 'boolean')) {
    fail('Host Session readiness result is invalid.');
  }
  requireInteger(result.readiness.stable_observations, 0, 20, 'Host Session stable observation count');
  requireExactKeys(result.quit, ['requested', 'graceful', 'forced', 'complete'], 'Host Session quit result');
  if (Object.values(result.quit).some(value => typeof value !== 'boolean')) {
    fail('Host Session quit result is invalid.');
  }
  if (result.failure !== null) {
    requireExactKeys(result.failure, ['code', 'message'], 'Host Session failure');
    if (typeof result.failure.code !== 'string' || typeof result.failure.message !== 'string') {
      fail('Host Session failure is invalid.');
    }
  }
  if ((result.status === 'failed') !== (result.failure !== null)) {
    fail('Host Session result status and failure do not agree.');
  }
  return result;
}

function serializeSessionResult(result) {
  validateSessionResult(result);
  return `${JSON.stringify(result)}\n`;
}

function parseSessionResult(value) {
  let result;
  try {
    result = JSON.parse(value);
  } catch {
    fail('Host Session result is not valid JSON.');
  }
  return validateSessionResult(result);
}

function parseProcessTable(output) {
  const records = [];
  for (const line of output.split('\n')) {
    const match = line.match(/^\s*(\d+)\s+(\d+)\s+(.*)$/);
    if (match) {
      records.push({ pid: Number(match[1]), parent_pid: Number(match[2]), command: match[3] });
    }
  }
  return records;
}

function assertNoSymlinkAncestors(target, label) {
  const resolved = path.resolve(target);
  const root = path.parse(resolved).root;
  const parts = path.relative(root, resolved).split(path.sep).filter(Boolean);
  let current = root;
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
      fail(`${label} contains a symbolic link: ${current}`);
    }
  }
}

async function prepareRuntimePaths(policy) {
  assertNoSymlinkAncestors(policy.executable, 'Host Session executable');
  const executableMetadata = await fsp.lstat(policy.executable);
  if (!executableMetadata.isFile() || (executableMetadata.mode & 0o111) === 0) {
    fail('Host Session executable must be an executable plain file.');
  }
  assertNoSymlinkAncestors(path.dirname(policy.host_log), 'Host Session host-log parent');
  assertNoSymlinkAncestors(policy.log_root, 'Host Session log root');
  assertNoSymlinkAncestors(policy.host_log, 'Host Session host log');
  await fsp.mkdir(path.dirname(policy.host_log), { recursive: true, mode: 0o700 });
  await fsp.mkdir(policy.log_root, { recursive: true, mode: 0o700 });
  await fsp.chmod(path.dirname(policy.host_log), 0o700);
  await fsp.chmod(policy.log_root, 0o700);
  try {
    const hostLogMetadata = await fsp.lstat(policy.host_log);
    if (!hostLogMetadata.isFile() || hostLogMetadata.isSymbolicLink()) {
      fail('Host Session host log must be a plain file.');
    }
  } catch (error) {
    if (error?.code !== 'ENOENT') {
      throw error;
    }
  }
}

function createNodeRuntime() {
  const children = new Map();
  return {
    now: () => new Date(),
    async spawn(policy) {
      await prepareRuntimePaths(policy);
      const hostLogFd = fs.openSync(policy.host_log, 'w', 0o600);
      fs.fchmodSync(hostLogFd, 0o600);
      const child = spawn(policy.executable, policy.arguments, {
        detached: policy.completion.mode === 'leave-running',
        env: { ...process.env, ...policy.environment },
        stdio: ['ignore', hostLogFd, hostLogFd]
      });
      fs.closeSync(hostLogFd);
      const exit = new Promise(resolve => {
        child.once('error', error => resolve({ code: 1, signal: null, error }));
        child.once('exit', (code, signal) => resolve({ code, signal }));
      });
      await new Promise((resolve, reject) => {
        child.once('spawn', resolve);
        child.once('error', reject);
      });
      children.set(child.pid, { child, exit });
      return { pid: child.pid };
    },
    async isAlive(pid) {
      try {
        process.kill(pid, 0);
        return true;
      } catch (error) {
        if (error?.code === 'ESRCH') {
          return false;
        }
        throw error;
      }
    },
    async listProcesses() {
      return parseProcessTable(execFileSync('/bin/ps', [
        '-ax', '-o', 'pid=', '-o', 'ppid=', '-o', 'command='
      ], { encoding: 'utf8' }));
    },
    async readText(filePath) {
      try {
        return await fsp.readFile(filePath, 'utf8');
      } catch (error) {
        if (error?.code === 'ENOENT') {
          return '';
        }
        throw error;
      }
    },
    async findFiles(root, { suffix, modified_after_ms: modifiedAfterMs }) {
      const found = [];
      async function visit(directory) {
        const entries = await fsp.readdir(directory, { withFileTypes: true }).catch(error => {
          if (error?.code === 'ENOENT') {
            return [];
          }
          throw error;
        });
        for (const entry of entries) {
          if (entry.isSymbolicLink()) {
            continue;
          }
          const candidate = path.join(directory, entry.name);
          if (entry.isDirectory()) {
            await visit(candidate);
          } else if (entry.isFile() && candidate.endsWith(suffix)) {
            const metadata = await fsp.stat(candidate);
            if (metadata.mtimeMs >= modifiedAfterMs) {
              found.push(candidate);
            }
          }
          if (found.length > 1000) {
            fail('Host Session found too many log files.');
          }
        }
      }
      await visit(root);
      return found;
    },
    sleep(milliseconds) {
      return new Promise(resolve => setTimeout(resolve, milliseconds));
    },
    async signalTree(pid, signal) {
      const processes = await this.listProcesses();
      const descendants = [...descendantsOf(processes, pid)];
      for (const descendant of descendants.reverse()) {
        try {
          process.kill(descendant, signal);
        } catch (error) {
          if (error?.code !== 'ESRCH') {
            throw error;
          }
        }
      }
      try {
        process.kill(pid, signal);
      } catch (error) {
        if (error?.code !== 'ESRCH') {
          throw error;
        }
      }
      return [...descendants, pid];
    },
    async waitForExit(pid) {
      const tracked = children.get(pid);
      if (tracked) {
        const outcome = await tracked.exit;
        return outcome.code ?? (outcome.signal ? 128 : 0);
      }
      while (await this.isAlive(pid)) {
        await this.sleep(250);
      }
      return null;
    },
    detach(pid) {
      children.get(pid)?.child.unref();
    },
    async emergencyStop(pid) {
      try {
        process.kill(pid, 'SIGTERM');
      } catch (error) {
        if (error?.code !== 'ESRCH') {
          throw error;
        }
      }
    },
    emergencyStopAll() {
      for (const { child } of children.values()) {
        try {
          process.kill(child.pid, 'SIGTERM');
        } catch (error) {
          if (error?.code !== 'ESRCH') {
            throw error;
          }
        }
      }
    }
  };
}

module.exports = {
  createNodeRuntime,
  parseSessionResult,
  runHostSession,
  serializeSessionResult,
  stopHostSession,
  validateSessionPolicy
};
