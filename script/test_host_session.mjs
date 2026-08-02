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
  runHostSession,
  serializeSessionResult,
  createNodeRuntime
} = hostSession;

test('Host Session exposes one maintained run interface and its two runtime adapters', () => {
  assert.deepEqual(Object.keys(hostSession).sort(), [
    'createNodeRuntime',
    'runHostSession',
    'serializeSessionResult'
  ]);
});

function launchRecord(overrides = {}) {
  return {
    session_id: 'unit-session',
    app_name: 'DBCode Wrapper',
    executable: '/private/tmp/DBCode Wrapper.app/Contents/MacOS/DBCode Wrapper',
    arguments: ['--new-window'],
    environment: { DBCODE_WRAPPER_TEST: '1' },
    host_log: '/private/tmp/dbcode-wrapper-session/host.log',
    log_root: '/private/tmp/dbcode-wrapper-session/logs',
    timeout_seconds: 4,
    ...overrides
  };
}

function fakeRuntime(options = {}) {
  let tick = 0;
  let alive = true;
  const signals = [];
  const rendererAt = options.rendererAt ?? 0;
  const dbcodeAt = options.dbcodeAt ?? 0;
  const hostTextAt = options.hostTextAt ?? (() => options.hostText ?? '');

  return {
    signals,
    get tick() { return tick; },
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
        return tick >= dbcodeAt ? (options.dbcodeText ?? 'DBCode starting...') : '';
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
    async emergencyStop() {
      alive = false;
    }
  };
}

test('the run interface owns policy defaults and rejects unsafe launch records', async () => {
  let policy;
  const result = await runHostSession(
    launchRecord(),
    fakeRuntime({ externalExitAt: 2 }),
    { onPolicy(value) { policy = value; } }
  );
  assert.equal(result.status, 'complete');
  assert.deepEqual(policy, {
    schema_version: 2,
    session_id: 'unit-session',
    executable: launchRecord().executable,
    arguments: ['--new-window'],
    environment: { DBCODE_WRAPPER_TEST: '1' },
    host_log: launchRecord().host_log,
    log_root: launchRecord().log_root,
    readiness: {
      timeout_seconds: 4,
      poll_interval_ms: 1000,
      renderer: {
        command_contains: ['DBCode Wrapper Helper (Renderer).app', '--type=renderer'],
        stable_observations: 1
      },
      dbcode: {
        required: true,
        log_suffix: '/dbcode.dbcode/DBCode.log',
        patterns: [{ kind: 'literal', value: 'DBCode starting...' }]
      },
      host_log_patterns: [],
      fatal_host_log_patterns: [{
        kind: 'regex',
        value: 'Library not loaded:|not valid for use in process|renderer process gone|GPU process isn.t usable|FATAL:'
      }]
    },
    completion: {
      graceful_timeout_seconds: 10,
      force_timeout_seconds: 5
    }
  });
  await assert.rejects(
    runHostSession(launchRecord({ executable: 'DBCode Wrapper' }), fakeRuntime()),
    /absolute path/i
  );
  await assert.rejects(
    runHostSession(launchRecord({ timeout_seconds: 0 }), fakeRuntime()),
    /timeout/i
  );
  await assert.rejects(
    runHostSession({ ...launchRecord(), completion: {} }, fakeRuntime()),
    /launch record/i
  );
});

test('a process exit before readiness returns a structured failure', async () => {
  const result = await runHostSession(
    launchRecord(),
    fakeRuntime({ rendererAt: 9, dbcodeAt: 9, exitAt: 1 })
  );
  assert.equal(result.status, 'failed');
  assert.equal(result.failure.code, 'process-exited');
  assert.equal(result.process.app_pid, 4100);
  assert.equal(result.readiness.ready, false);
});

test('renderer and DBCode timeouts remain distinct', async () => {
  const rendererTimeout = await runHostSession(
    launchRecord(),
    fakeRuntime({ rendererAt: 9, dbcodeAt: 9 })
  );
  assert.equal(rendererTimeout.failure.code, 'renderer-timeout');

  const dbcodeTimeout = await runHostSession(
    launchRecord(),
    fakeRuntime({ rendererAt: 0, dbcodeAt: 9 })
  );
  assert.equal(dbcodeTimeout.failure.code, 'dbcode-timeout');
  assert.equal(dbcodeTimeout.readiness.renderer_ready, true);
});

test('stable renderer and DBCode readiness wait for the user to close the app', async () => {
  const runtime = fakeRuntime({ rendererAt: 1, dbcodeAt: 1, externalExitAt: 3 });
  const result = await runHostSession(launchRecord(), runtime);
  assert.equal(result.status, 'complete');
  assert.equal(result.readiness.ready, true);
  assert.equal(result.readiness.stable_observations, 1);
  assert.equal(result.quit.requested, false);
  assert.equal(result.quit.graceful, true);
  assert.equal(result.quit.forced, false);
  assert.deepEqual(runtime.signals, []);
});

test('fatal host output fails immediately and triggers graceful cleanup', async () => {
  const runtime = fakeRuntime({ hostText: 'FATAL: helper crashed' });
  const result = await runHostSession(launchRecord(), runtime);
  assert.equal(result.status, 'failed');
  assert.equal(result.failure.code, 'fatal-host-log');
  assert.deepEqual(runtime.signals, ['SIGTERM']);
});

test('failure cleanup uses a forced stop only when graceful cleanup is ignored', async () => {
  const runtime = fakeRuntime({ hostText: 'FATAL: helper crashed', ignoreTerm: true });
  const result = await runHostSession(launchRecord(), runtime);
  assert.equal(result.status, 'failed');
  assert.equal(result.quit.graceful, false);
  assert.equal(result.quit.forced, true);
  assert.deepEqual(runtime.signals, ['SIGTERM', 'SIGKILL']);
});

test('an unexpected observer error is structured and still cleans up the app', async () => {
  const result = await runHostSession(
    launchRecord(),
    fakeRuntime({ processError: 'process table unavailable' })
  );
  assert.equal(result.status, 'failed');
  assert.equal(result.failure.code, 'session-error');
  assert.match(result.failure.message, /process table unavailable/);
  assert.equal(result.quit.forced, true);
  assert.equal(result.quit.complete, true);
});

test('session result serialization is canonical and rejects changed records', async () => {
  const result = await runHostSession(
    launchRecord(),
    fakeRuntime({ externalExitAt: 2 })
  );
  const serialized = serializeSessionResult(result);
  assert.equal(serialized.endsWith('\n'), true);
  assert.deepEqual(JSON.parse(serialized), result);
  assert.throws(
    () => serializeSessionResult({ ...result, status: 'invented' }),
    /session result/i
  );
});

test('the production runtime controls a disposable fake host without touching the app profile', { timeout: 15_000 }, async t => {
  const root = mkdtempSync(join(realpathSync(tmpdir()), 'dbcode-host-session-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const executable = join(root, 'fake-host.sh');
  const rendererScript = join(root, 'DBCode Wrapper Helper (Renderer).app');
  const logRoot = join(root, 'logs');
  const dbcodeLog = join(logRoot, 'run/dbcode.dbcode/DBCode.log');
  writeFileSync(rendererScript, `setInterval(() => {}, 1_000);\n`, { mode: 0o600 });
  writeFileSync(executable, `#!/bin/sh
set -eu
fixture_log="$1"
node_executable="$2"
renderer_script="$3"
mkdir -p "$(dirname "$fixture_log")"
printf '%s\n' 'DBCode starting...' > "$fixture_log"
printf '%s\n' 'fake host ready'
"$node_executable" "$renderer_script" --type=renderer &
renderer_pid=$!
sleep 2
kill -TERM "$renderer_pid" 2>/dev/null || true
wait "$renderer_pid" 2>/dev/null || true
`, { mode: 0o700 });
  chmodSync(executable, 0o700);
  const result = await runHostSession(launchRecord({
    session_id: 'production-runtime-fixture',
    executable,
    arguments: [dbcodeLog, process.execPath, rendererScript],
    host_log: join(root, 'host.log'),
    log_root: logRoot,
    timeout_seconds: 5
  }), createNodeRuntime());
  if (result.failure?.message.includes('EPERM')) {
    t.skip('The current sandbox does not permit the fixture process-table check.');
    return;
  }
  assert.equal(result.status, 'complete', serializeSessionResult(result));
  assert.equal(result.readiness.renderer_ready, true);
  assert.equal(result.readiness.dbcode_ready, true);
  assert.equal(result.quit.complete, true);
});
