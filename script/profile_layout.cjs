#!/usr/bin/env node

'use strict';

const layoutContract = require('../host/extensions/dbcode-wrapper-profile-migration/profile-layout');

function usage() {
  console.error(`Usage:
  ./script/profile_layout.cjs record default|qa HOME BUILD_ROOT
  ./script/profile_layout.cjs check-record PROFILE_LAYOUT_JSON PATH_NAME...`);
  process.exit(2);
}

function main([command, ...args]) {
  if (command === 'check-record') {
    const [layoutJson, ...pathNames] = args;
    if (!layoutJson || pathNames.length === 0) {
      usage();
    }
    let layout;
    try {
      layout = JSON.parse(layoutJson);
    } catch {
      throw new Error('Standalone DBCode Profile layout is not valid JSON.');
    }
    layoutContract.assertSafeMutationPaths(layout, pathNames);
    return;
  }

  const [profileName, homeDirectory, buildRoot, ...profileArgs] = args;
  if (command !== 'record' || !profileName || !homeDirectory || !buildRoot || profileArgs.length > 0) {
    usage();
  }
  const layout = layoutContract.createProfileLayout({
    profileName,
    homeDirectory,
    buildRoot
  });
  process.stdout.write(`${JSON.stringify(layout)}\n`);
}

try {
  main(process.argv.slice(2));
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
