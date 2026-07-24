#!/usr/bin/env node

'use strict';

const os = require('node:os');
const path = require('node:path');
const {
  assertManagedPath,
  inventoryGeneratedWorkspace,
  planCleanup,
  readOtherOwnedMacTicketOpen,
  resolveManagedPath
} = require('./lib/generated-workspace-retention');

const DEFAULT_ISSUE = '.scratch/dbcode-wrapper-implementation/issues/09-publish-public-source-and-private-personal-release.md';

function usage() {
  console.error(`Usage:
  ./script/generated_workspace.cjs inventory [COMMON OPTIONS]
  ./script/generated_workspace.cjs cleanup (--class CLASS | --path PATH) [COMMON OPTIONS]
  ./script/generated_workspace.cjs path --id ID [COMMON OPTIONS]
  ./script/generated_workspace.cjs assert-path --id ID --path PATH [--allow-temporary] [COMMON OPTIONS]

Common options:
  --repo-root DIR
  --home DIR`);
  process.exit(2);
}

function parseOptions(args) {
  const parsed = {};
  while (args.length > 0) {
    const name = args.shift();
    if (name === '--allow-temporary') {
      if (parsed.allowTemporary) {
        usage();
      }
      parsed.allowTemporary = true;
      continue;
    }
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

function commonOptions(parsed) {
  const repoRoot = path.resolve(parsed['repo-root'] ?? path.join(__dirname, '..'));
  const homeDirectory = path.resolve(parsed.home ?? os.homedir());
  const ticketFile = path.resolve(repoRoot, DEFAULT_ISSUE);
  return {
    repoRoot,
    homeDirectory,
    otherOwnedMacTicketOpen: readOtherOwnedMacTicketOpen(ticketFile)
  };
}

function rejectUnknownOptions(parsed, allowed) {
  const allowedSet = new Set(allowed);
  const unknown = Object.keys(parsed).filter(key => !allowedSet.has(key));
  if (unknown.length > 0) {
    usage();
  }
}

function writeJson(value) {
  process.stdout.write(`${JSON.stringify(value, null, 2)}\n`);
}

function main([command, ...args]) {
  const parsed = parseOptions(args);
  const commonKeys = ['repo-root', 'home'];
  if (command === 'inventory') {
    rejectUnknownOptions(parsed, commonKeys);
    writeJson(inventoryGeneratedWorkspace(commonOptions(parsed)));
    return;
  }
  if (command === 'cleanup') {
    rejectUnknownOptions(parsed, [...commonKeys, 'class', 'path']);
    const hasClass = typeof parsed.class === 'string';
    const hasPath = typeof parsed.path === 'string';
    if (hasClass === hasPath) {
      usage();
    }
    writeJson(planCleanup({
      ...commonOptions(parsed),
      selector: hasClass
        ? { classification: parsed.class }
        : { path: parsed.path }
    }));
    return;
  }
  if (command === 'path') {
    rejectUnknownOptions(parsed, [...commonKeys, 'id']);
    if (!parsed.id) {
      usage();
    }
    process.stdout.write(`${resolveManagedPath({
      ...commonOptions(parsed),
      id: parsed.id
    })}\n`);
    return;
  }
  if (command === 'assert-path') {
    rejectUnknownOptions(parsed, [...commonKeys, 'id', 'path', 'allowTemporary']);
    if (!parsed.id || !parsed.path) {
      usage();
    }
    writeJson(assertManagedPath({
      ...commonOptions(parsed),
      id: parsed.id,
      candidatePath: parsed.path,
      allowTemporary: parsed.allowTemporary === true
    }));
    return;
  }
  usage();
}

try {
  main(process.argv.slice(2));
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
