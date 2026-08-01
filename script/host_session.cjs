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
  console.error('Usage: ./script/host_session.cjs run --policy FILE --output FILE');
  process.exit(2);
}

function options(args) {
  const parsed = {};
  while (args.length > 0) {
    const name = args.shift();
    if (!name?.startsWith('--') || args.length === 0) {
      usage();
    }
    parsed[name.slice(2)] = args.shift();
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

function readPolicy(filePath) {
  let policy;
  try {
    policy = JSON.parse(readPlainFile(filePath, 'Host Session policy'));
  } catch (error) {
    if (error instanceof SyntaxError) {
      throw new Error('Host Session policy is not valid JSON.');
    }
    throw error;
  }
  return policy;
}

function writeResult(outputPath, result) {
  if (typeof outputPath !== 'string' || !path.isAbsolute(outputPath)) {
    throw new Error('Host Session output must be an absolute path.');
  }
  const parent = path.dirname(outputPath);
  const parentMetadata = fs.lstatSync(parent);
  if (!parentMetadata.isDirectory() || parentMetadata.isSymbolicLink()) {
    throw new Error('Host Session output parent must be a plain directory.');
  }
  if (fs.existsSync(outputPath) && fs.lstatSync(outputPath).isSymbolicLink()) {
    throw new Error('Host Session output must not be a symbolic link.');
  }
  const temporary = path.join(parent, `.${path.basename(outputPath)}.${process.pid}.tmp`);
  fs.writeFileSync(temporary, serializeSessionResult(result), { encoding: 'utf8', flag: 'wx', mode: 0o600 });
  fs.renameSync(temporary, outputPath);
  fs.chmodSync(outputPath, 0o600);
}

async function main([command, ...args]) {
  const parsed = options(args);
  if (command !== 'run' || !parsed.policy || !parsed.output || Object.keys(parsed).length !== 2) {
    usage();
  }
  const policy = readPolicy(parsed.policy);
  const runtime = createNodeRuntime();
  const stopOnSignal = signal => {
    runtime.emergencyStopAll();
    process.exit(signal === 'SIGINT' ? 130 : 143);
  };
  process.once('SIGINT', stopOnSignal);
  process.once('SIGTERM', stopOnSignal);
  const result = await runHostSession(policy, runtime, {
    onReady(readyResult) {
      writeResult(parsed.output, readyResult);
      console.error(`Host Session ${readyResult.session_id} is ready.`);
    }
  });
  process.removeListener('SIGINT', stopOnSignal);
  process.removeListener('SIGTERM', stopOnSignal);
  writeResult(parsed.output, result);
  if (result.status === 'failed') {
    console.error(`${result.failure.code}: ${result.failure.message}`);
    process.exitCode = 1;
  }
}

main(process.argv.slice(2)).catch(error => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
