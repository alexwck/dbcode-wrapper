#!/usr/bin/env node

'use strict';

const {
  engineIsCompatible
} = require('../host/extensions/dbcode-wrapper-profile-migration/openVsxPackageVerifier');

if (process.argv.length !== 4) {
  console.error('Usage: node check_vscode_engine.cjs <Code OSS version> <extension engine range>');
  process.exit(2);
}

const [hostVersion, engineRange] = process.argv.slice(2);
try {
  process.exit(engineIsCompatible(hostVersion, engineRange) ? 0 : 1);
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : 'The Code OSS engine compatibility record is invalid.'
  );
  process.exit(2);
}
