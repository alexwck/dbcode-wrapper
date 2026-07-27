---
title: Profile Layout and Setup
description: The safe path and testable workflow for Standalone DBCode Profile setup, import, and recovery.
type: module
tags:
  - wiki
  - module
  - profile
  - setup
wiki_profile: public
wiki_depth: standard
source_commit: e20a9a13c697b331902ce83a84cbb7505c0dc3fc
---
## Summary

Profile Layout defines where each Standalone DBCode Profile may live. Profile Setup owns the first-use workflow behind one testable interface. The host extension only adapts that workflow to VS Code, unchanged DBCode commands, files, the clipboard, time, process spawning, and quit.

## Responsibilities

- Derive `default`, `qa`, and `isolated` layouts from explicit owner roots.
- Keep one stable generated `qa` layout for rendered deployment checks.
- Validate serialized layouts and reject unknown, broad, escaped, or linked paths.
- Check mutation targets before setup, migration, backup, or recovery.
- Keep user data, extensions, shared data, cache, logs, and backups in one owned layout.
- Own start-clean, reviewed import, staging cleanup, DuckDB preflight, completion, cancellation, and recovery order.
- Remove reviewed temporary data after completion, cancellation, close, recovery, or an action failure.
- Recreate only wrapper-owned state after explicit user confirmation.

## Public API / entry points

`createProfileLayout`, `validateProfileLayout`, `assertSafeMutationPaths`, and `parseMatchingLayout` form the path API.

`ProfileSetup` provides `requiresSetup`, `open`, `dispatch`, and `panelClosed`. Production supplies one host adapter. Fast tests supply an in-memory adapter and exercise the same action order.

## Key files

- [`profile-layout.js`](https://github.com/alexwck/dbcode-wrapper/blob/e20a9a13c697b331902ce83a84cbb7505c0dc3fc/host/extensions/dbcode-wrapper-profile-migration/profile-layout.js) — path derivation and validation.
- [`profileSetup.js`](https://github.com/alexwck/dbcode-wrapper/blob/e20a9a13c697b331902ce83a84cbb7505c0dc3fc/host/extensions/dbcode-wrapper-profile-migration/profileSetup.js) — setup state and action ordering.
- [`extension.js`](https://github.com/alexwck/dbcode-wrapper/blob/e20a9a13c697b331902ce83a84cbb7505c0dc3fc/host/extensions/dbcode-wrapper-profile-migration/extension.js) — VS Code, DBCode, file, clipboard, process, and quit adapters.
- [`migration.js`](https://github.com/alexwck/dbcode-wrapper/blob/e20a9a13c697b331902ce83a84cbb7505c0dc3fc/host/extensions/dbcode-wrapper-profile-migration/migration.js), [`staging.js`](https://github.com/alexwck/dbcode-wrapper/blob/e20a9a13c697b331902ce83a84cbb7505c0dc3fc/host/extensions/dbcode-wrapper-profile-migration/staging.js), and [`profileRecovery.js`](https://github.com/alexwck/dbcode-wrapper/blob/e20a9a13c697b331902ce83a84cbb7505c0dc3fc/host/extensions/dbcode-wrapper-profile-migration/profileRecovery.js) — reviewed import, temporary storage, and safe state movement.
- [`managed-settings.json`](https://github.com/alexwck/dbcode-wrapper/blob/e20a9a13c697b331902ce83a84cbb7505c0dc3fc/host/extensions/dbcode-wrapper-profile-migration/managed-settings.json) — focused defaults.

## Dependencies

The module uses [Release Specification](release-specification.md) for identity and schema, [Focused Runtime Setup](focused-runtime-setup.md) for packages, and Code OSS APIs through the host adapter. First-launch and recovery work are normal user flows, not repeated deployment tests.

## Participates in

- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)

## Related

- [Standalone DBCode Profile](../concepts/standalone-dbcode-profile.md)
- [Focused host and private profile](../architecture/focused-host-and-private-profile.md)
- [Host Session](host-session.md)
