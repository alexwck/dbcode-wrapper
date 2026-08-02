#!/usr/bin/env node

'use strict';

const fs = require('node:fs');
const path = require('node:path');
const {
  createNodeRuntime,
  runHostSession,
  serializeSessionResult
} = require('./lib/host-session');

function usage() {
  console.error('Usage: ./script/host_session.cjs run --launch FILE --policy FILE --output FILE');
  process.exit(2);
}

function options(args) {
  const parsed = {};
  while (args.length > 0) {
    const name = args.shift();
    if (!name?.startsWith('--') || args.length === 0) {
      usage();
    }
    const key = name.slice(2);
    if (Object.hasOwn(parsed, key)) {
      usage();
    }
    parsed[key] = args.shift();
  }
  return parsed;
}

function readPlainFile(filePath, label) {
  if (typeof filePath !== 'string' || !path.isAbsolute(filePath)) {
    throw new Error(`${label} must be an absolute path.`);
  }
  const metadata = fs.lstatSync(filePath);
  if (!metadata.isFile() || metadata.isSymbolicLink()) {
    throw new Error(`${label} must be a plain file.`);
  }
  return fs.readFileSync(filePath, 'utf8');
}

function readLaunchRecord(filePath) {
  let launchRecord;
  try {
    launchRecord = JSON.parse(readPlainFile(filePath, 'Host Session launch record'));
  } catch (error) {
    if (error instanceof SyntaxError) {
      throw new Error('Host Session launch record is not valid JSON.');
    }
    throw error;
  }
  return launchRecord;
}

function writeRecord(outputPath, contents, label) {
  if (typeof outputPath !== 'string' || !path.isAbsolute(outputPath)) {
    throw new Error(`${label} must be an absolute path.`);
  }
  const parent = path.dirname(outputPath);
  const parentMetadata = fs.lstatSync(parent);
  if (!parentMetadata.isDirectory() || parentMetadata.isSymbolicLink()) {
    throw new Error(`${label} parent must be a plain directory.`);
  }
  if (fs.existsSync(outputPath) && fs.lstatSync(outputPath).isSymbolicLink()) {
    throw new Error(`${label} must not be a symbolic link.`);
  }
  const temporary = path.join(parent, `.${path.basename(outputPath)}.${process.pid}.tmp`);
  try {
    fs.writeFileSync(temporary, contents, { encoding: 'utf8', flag: 'wx', mode: 0o600 });
    fs.renameSync(temporary, outputPath);
    fs.chmodSync(outputPath, 0o600);
  } finally {
    fs.rmSync(temporary, { force: true });
  }
}

async function main([command, ...args]) {
  const parsed = options(args);
  if (
    command !== 'run' ||
    !parsed.launch ||
    !parsed.policy ||
    !parsed.output ||
    Object.keys(parsed).length !== 3
  ) {
    usage();
  }
  const launchRecord = readLaunchRecord(parsed.launch);
  const runtime = createNodeRuntime();
  const stopOnSignal = signal => {
    runtime.emergencyStopAll();
    process.exit(signal === 'SIGINT' ? 130 : 143);
  };
  process.once('SIGINT', stopOnSignal);
  process.once('SIGTERM', stopOnSignal);
  const result = await runHostSession(launchRecord, runtime, {
    onPolicy(policy) {
      writeRecord(parsed.policy, `${JSON.stringify(policy, null, 2)}\n`, 'Host Session policy');
    },
    onReady(readyResult) {
      writeRecord(parsed.output, serializeSessionResult(readyResult), 'Host Session output');
      console.error(`Host Session ${readyResult.session_id} is ready.`);
    }
  });
  process.removeListener('SIGINT', stopOnSignal);
  process.removeListener('SIGTERM', stopOnSignal);
  writeRecord(parsed.output, serializeSessionResult(result), 'Host Session output');
  if (result.status === 'failed') {
    console.error(`${result.failure.code}: ${result.failure.message}`);
    process.exitCode = 1;
  }
}

main(process.argv.slice(2)).catch(error => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
