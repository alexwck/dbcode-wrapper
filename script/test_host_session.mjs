import assert from 'node:assert/strict';
import {
  chmodSync,
  mkdtempSync,
  realpathSync,
  rmSync,
  writeFileSync
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import hostSession from './lib/host-session.js';

const {
  parseSessionResult,
  runHostSession,
  serializeSessionResult,
  stopHostSession,
  validateSessionPolicy,
  createNodeRuntime
} = hostSession;

test('Host Session keeps parsing and validation helpers private', () => {
  assert.equal(hostSession.parseProcessTable, undefined);
  assert.equal(hostSession.validateSessionResult, undefined);
});

function policy(overrides = {}) {
  const base = {
    schema_version: 1,
    session_id: 'unit-session',
    executable: '/private/tmp/DBCode Wrapper.app/Contents/MacOS/DBCode Wrapper',
    arguments: ['--new-window'],
    environment: { DBCODE_WRAPPER_TEST: '1' },
    host_log: '/private/tmp/dbcode-wrapper-session/host.log',
    log_root: '/private/tmp/dbcode-wrapper-session/logs',
    readiness: {
      timeout_seconds: 4,
      poll_interval_ms: 1000,
      renderer: {
        command_contains: ['DBCode Wrapper Helper (Renderer).app', '--type=renderer'],
        stable_observations: 2
      },
      dbcode: {
        required: true,
        log_suffix: '/dbcode.dbcode/DBCode.log',
        patterns: [{ kind: 'literal', value: 'DBCode started' }]
      },
      host_log_patterns: [],
      fatal_host_log_patterns: [{ kind: 'regex', value: 'FATAL:|renderer process gone' }]
    },
    completion: {
      mode: 'quit-after-ready',
      require_dbcode_before_exit: false,
      graceful_timeout_seconds: 2,
      force_timeout_seconds: 1
    }
  };
  return {
    ...base,
    ...overrides,
    readiness: {
      ...base.readiness,
      ...overrides.readiness,
      renderer: { ...base.readiness.renderer, ...overrides.readiness?.renderer },
      dbcode: { ...base.readiness.dbcode, ...overrides.readiness?.dbcode }
    },
    completion: { ...base.completion, ...overrides.completion }
  };
}

function fakeRuntime(options = {}) {
  let tick = 0;
  let alive = true;
  let detached = false;
  const signals = [];
  const rendererAt = options.rendererAt ?? 0;
  const dbcodeAt = options.dbcodeAt ?? 0;
  const hostTextAt = options.hostTextAt ?? (() => options.hostText ?? '');

  return {
    signals,
    get tick() { return tick; },
    get detached() { return detached; },
    now() {
      return new Date(Date.UTC(2026, 6, 23, 0, 0, tick));
    },
    async spawn() {
      return { pid: 4100 };
    },
    async isAlive(pid) {
      if (pid === 4100 && options.exitAt !== undefined && tick >= options.exitAt) {
        alive = false;
      }
      return pid === 4100 ? alive : alive && pid === 4200 && tick >= rendererAt;
    },
    async listProcesses() {
      if (options.processError) {
        throw new Error(options.processError);
      }
      const processes = alive ? [{
        pid: 4100,
        parent_pid: 1,
        command: '/private/tmp/DBCode Wrapper.app/Contents/MacOS/DBCode Wrapper --new-window'
      }] : [];
      if (alive && tick >= rendererAt) {
        processes.push({
          pid: 4200,
          parent_pid: 4100,
          command: 'DBCode Wrapper Helper (Renderer).app --type=renderer'
        });
      }
      return processes;
    },
    async readText(filePath) {
      if (filePath.endsWith('DBCode.log')) {
        return tick >= dbcodeAt ? (options.dbcodeText ?? 'DBCode started') : '';
      }
      return hostTextAt(tick);
    },
    async findFiles() {
      return tick >= dbcodeAt ? ['/private/tmp/dbcode-wrapper-session/logs/a/dbcode.dbcode/DBCode.log'] : [];
    },
    async sleep() {
      tick += 1;
    },
    async signalTree(_pid, signal) {
      signals.push(signal);
      if (signal === 'SIGTERM' && options.ignoreTerm !== true) {
        alive = false;
      }
      if (signal === 'SIGKILL') {
        alive = false;
      }
      return [4100, 4200];
    },
    async waitForExit() {
      while (alive) {
        await this.sleep();
        if (options.externalExitAt !== undefined && tick >= options.externalExitAt) {
          alive = false;
        }
      }
      return options.exitCode ?? 0;
    },
    detach() {
      detached = true;
    },
    async emergencyStop() {
      alive = false;
    }
  };
}

test('session policies are explicit and reject unsafe or unsupported values', () => {
  assert.deepEqual(validateSessionPolicy(policy()), policy());
  assert.throws(
    () => validateSessionPolicy(policy({ executable: 'DBCode Wrapper' })),
    /absolute path/i
  );
  assert.throws(
    () => validateSessionPolicy(policy({ completion: { mode: 'background-magic' } })),
    /completion mode/i
  );
  assert.throws(
    () => validateSessionPolicy(policy({ readiness: { timeout_seconds: 0 } })),
    /timeout/i
  );
});

test('a process exit before readiness returns a structured failure', async () => {
  const result = await runHostSession(policy(), fakeRuntime({ rendererAt: 9, dbcodeAt: 9, exitAt: 1 }));
  assert.equal(result.status, 'failed');
  assert.equal(result.failure.code, 'process-exited');
  assert.equal(result.process.app_pid, 4100);
  assert.equal(result.readiness.ready, false);
});

test('renderer and DBCode timeouts are distinguished', async () => {
  const rendererTimeout = await runHostSession(policy(), fakeRuntime({ rendererAt: 9, dbcodeAt: 9 }));
  assert.equal(rendererTimeout.failure.code, 'renderer-timeout');

  const dbcodeTimeout = await runHostSession(policy(), fakeRuntime({ rendererAt: 0, dbcodeAt: 9 }));
  assert.equal(dbcodeTimeout.failure.code, 'dbcode-timeout');
  assert.equal(dbcodeTimeout.readiness.renderer_ready, true);
});

test('stable renderer and DBCode readiness complete with a graceful quit', async () => {
  const runtime = fakeRuntime({ rendererAt: 1, dbcodeAt: 1 });
  const result = await runHostSession(policy(), runtime);
  assert.equal(result.status, 'complete');
  assert.equal(result.readiness.ready, true);
  assert.equal(result.readiness.stable_observations, 2);
  assert.equal(result.quit.requested, true);
  assert.equal(result.quit.graceful, true);
  assert.equal(result.quit.forced, false);
  assert.deepEqual(runtime.signals, ['SIGTERM']);
});

test('fatal host output fails immediately and triggers cleanup', async () => {
  const runtime = fakeRuntime({ hostText: 'FATAL: helper crashed' });
  const result = await runHostSession(policy(), runtime);
  assert.equal(result.status, 'failed');
  assert.equal(result.failure.code, 'fatal-host-log');
  assert.deepEqual(runtime.signals, ['SIGTERM']);
});

test('an unexpected observer error is structured and still cleans up the app', async () => {
  const result = await runHostSession(policy(), fakeRuntime({ processError: 'process table unavailable' }));
  assert.equal(result.status, 'failed');
  assert.equal(result.failure.code, 'session-error');
  assert.match(result.failure.message, /process table unavailable/);
  assert.equal(result.quit.forced, true);
  assert.equal(result.quit.complete, true);
});

test('a process that ignores graceful quit is forcefully cleaned up', async () => {
  const runtime = fakeRuntime({ ignoreTerm: true });
  const result = await runHostSession(policy({
    readiness: { renderer: { stable_observations: 1 } },
    completion: { graceful_timeout_seconds: 1, force_timeout_seconds: 1 }
  }), runtime);
  assert.equal(result.status, 'complete');
  assert.equal(result.quit.graceful, false);
  assert.equal(result.quit.forced, true);
  assert.deepEqual(runtime.signals, ['SIGTERM', 'SIGKILL']);
});

test('leave-running detaches only after readiness', async () => {
  const runtime = fakeRuntime();
  const result = await runHostSession(policy({
    readiness: { renderer: { stable_observations: 1 } },
    completion: { mode: 'leave-running' }
  }), runtime);
  assert.equal(result.status, 'ready');
  assert.equal(runtime.detached, true);
  assert.equal(result.quit.requested, false);
});

test('wait-for-exit can require DBCode evidence collected before the user quits', async () => {
  const runtime = fakeRuntime({ dbcodeAt: 2, externalExitAt: 3 });
  const result = await runHostSession(policy({
    readiness: {
      renderer: { stable_observations: 1 },
      dbcode: { required: false }
    },
    completion: {
      mode: 'wait-for-exit',
      require_dbcode_before_exit: true
    }
  }), runtime);
  assert.equal(result.status, 'complete');
  assert.equal(result.readiness.dbcode_ready, true);
  assert.equal(result.process.exit_code, 0);
});

test('a saved ready session can be stopped through the same lifecycle module', async () => {
  const runtime = fakeRuntime();
  const ready = await runHostSession(policy({
    readiness: { renderer: { stable_observations: 1 } },
    completion: { mode: 'leave-running' }
  }), runtime);
  const stopped = await stopHostSession(ready, policy(), runtime);
  assert.equal(stopped.status, 'complete');
  assert.equal(stopped.quit.complete, true);
});

test('session result serialization is canonical and rejects changed records', async () => {
  const result = await runHostSession(policy({
    readiness: { renderer: { stable_observations: 1 } },
    completion: { mode: 'leave-running' }
  }), fakeRuntime());
  const serialized = serializeSessionResult(result);
  assert.equal(serialized.endsWith('\n'), true);
  assert.deepEqual(parseSessionResult(serialized), result);
  assert.throws(
    () => parseSessionResult(JSON.stringify({ ...result, status: 'invented' })),
    /session result/i
  );
});

test('the production runtime controls a disposable fake host without touching the app profile', { timeout: 15_000 }, async t => {
  const root = mkdtempSync(join(realpathSync(tmpdir()), 'dbcode-host-session-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const executable = join(root, 'fake-host.sh');
  const rendererScript = join(root, 'fake-renderer.mjs');
  const logRoot = join(root, 'logs');
  const dbcodeLog = join(logRoot, 'run/dbcode.dbcode/DBCode.log');
  writeFileSync(rendererScript, `process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
setInterval(() => {}, 1_000);
`, { mode: 0o600 });
  writeFileSync(executable, `#!/bin/sh
set -eu
fixture_log="$1"
node_executable="$2"
renderer_script="$3"
mkdir -p "$(dirname "$fixture_log")"
printf '%s\n' 'DBCode started' > "$fixture_log"
printf '%s\n' 'fake host ready'
"$node_executable" "$renderer_script" --type=renderer &
renderer_pid=$!
stop_fixture() {
  kill -TERM "$renderer_pid" 2>/dev/null || true
  wait "$renderer_pid" 2>/dev/null || true
  exit 0
}
trap stop_fixture TERM INT
wait "$renderer_pid"
`, { mode: 0o700 });
  chmodSync(executable, 0o700);
  const integrationPolicy = policy({
    session_id: 'production-runtime-fixture',
    executable,
    arguments: [dbcodeLog, process.execPath, rendererScript],
    host_log: join(root, 'host.log'),
    log_root: logRoot,
    readiness: {
      timeout_seconds: 5,
      poll_interval_ms: 100,
      renderer: {
        command_contains: [rendererScript, '--type=renderer'],
        stable_observations: 1
      }
    }
  });
  const result = await runHostSession(integrationPolicy, createNodeRuntime());
  if (result.failure?.message.includes('EPERM')) {
    t.skip('The current sandbox does not permit the fixture process-table check.');
    return;
  }
  assert.equal(result.status, 'complete', serializeSessionResult(result));
  assert.equal(result.readiness.renderer_ready, true);
  assert.equal(result.readiness.dbcode_ready, true);
  assert.equal(result.quit.complete, true);
});
