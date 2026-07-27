---
title: Profile Layout and Setup
description: The generated identity, safe paths, and testable workflow for Standalone DBCode Profile setup and recovery.
type: module
tags:
  - wiki
  - module
  - profile
  - setup
wiki_profile: public
wiki_depth: standard
source_commit: ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1
---
## Summary

Profile Layout defines where every Standalone DBCode Profile path may live. It no longer owns a second hard-coded product constant. Release assembly generates one small identity record from [Release Specification](release-specification.md), and shell and bundled JavaScript validate and use that same record.

Profile Setup owns the first-use workflow behind one testable interface. The host extension only adapts that workflow to VS Code, unchanged DBCode commands, files, the clipboard, time, process spawning, and quit.

## Responsibilities

- Load and validate the generated application, bundle, folder, query-storage, and profile-schema identity.
- Derive `default`, persistent `qa`, and explicit `isolated` layouts from owned roots.
- Include user data, extensions, shared data, cache, logs, backups, and query storage in one record.
- Reject missing, linked, malformed, oversized, unsafe, stale, or mismatched identity and layout data.
- Check mutation targets before setup, migration, backup, or recovery.
- Own start-clean, reviewed import, staging cleanup, DuckDB preflight, completion, cancellation, and recovery order.
- Remove reviewed temporary data after completion, cancellation, close, recovery, or an action failure.
- Recreate only wrapper-owned state after explicit user confirmation.

## Public API / entry points

`loadProfileIdentity`, `validateProfileIdentity`, `createProfileLayout`, `validateProfileLayout`, `assertSafeMutationPaths`, and `parseMatchingLayout` form the identity and path API. `script/profile_layout.cjs` gives shell callers the same implementation.

`ProfileSetup` provides `requiresSetup`, `open`, `dispatch`, and `panelClosed`. Production supplies one host adapter. Fast tests supply an in-memory adapter and exercise the same action order.

## Key files

- [`profile-identity.json`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/extensions/dbcode-wrapper-profile-migration/profile-identity.json) — generated profile identity used by source tests and the bundled extension.
- [`script/generate_profile_identity.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/script/generate_profile_identity.sh) — safe deterministic generator used during assembly.
- [`profile-layout.js`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/extensions/dbcode-wrapper-profile-migration/profile-layout.js) — identity loading, path derivation, and validation.
- [`profileSetup.js`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/extensions/dbcode-wrapper-profile-migration/profileSetup.js) — setup state and action ordering.
- [`script/lib/profile_paths.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/script/lib/profile_paths.sh) — shell adapter for the generated layout.
- [`migration.js`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/extensions/dbcode-wrapper-profile-migration/migration.js), [`staging.js`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/extensions/dbcode-wrapper-profile-migration/staging.js), and [`profileRecovery.js`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/extensions/dbcode-wrapper-profile-migration/profileRecovery.js) — reviewed import, temporary storage, and safe state movement.

## Dependencies

The module uses [Release Specification](release-specification.md) for identity and schema, [Focused Runtime Setup](focused-runtime-setup.md) for packages, and Code OSS APIs through the host adapter. First-launch and recovery work are normal user flows, not repeated deployment tests.

## Participates in

- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)

## Related

- [Standalone DBCode Profile](../concepts/standalone-dbcode-profile.md)
- [Focused host and private profile](../architecture/focused-host-and-private-profile.md)
- [Host Session](host-session.md)
- [Verification Harness](verification-harness.md)