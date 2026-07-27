---
title: Profile Layout and Setup
description: The safe path, normal setup, import, and recovery module for Standalone DBCode Profiles.
type: module
tags:
  - wiki
  - module
  - profile
  - setup
wiki_profile: public
wiki_depth: standard
source_commit: 2008ff48373c1aac378d0d1ec903e96a88ec1e29
---
## Summary

Profile Layout defines where each Standalone DBCode Profile may live. Profile Setup uses that contract for normal first use, reviewed import, verified runtime installation, and explicit recovery without touching unrelated editor profiles.

## Responsibilities

- Derive `default`, `qa`, and `isolated` layouts from explicit owner roots.
- Keep one stable generated `qa` layout for rendered deployment checks.
- Validate serialized layouts and reject unknown, broad, escaped, or linked paths.
- Check mutation targets before setup, migration, backup, or recovery.
- Keep user data, extensions, shared data, cache, logs, and backups in one owned layout.
- Guide normal first-run setup and optional connection import.
- Recreate only wrapper-owned state after explicit user confirmation.

## Public API / entry points

`createProfileLayout`, `validateProfileLayout`, `assertSafeMutationPaths`, and `parseMatchingLayout` form the path API. The wrapper extension provides setup, import, runtime, and recovery controllers behind that boundary.

## Key files

- [`profile-layout.js`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/extensions/dbcode-wrapper-profile-migration/profile-layout.js) — path derivation and validation.
- [`extension.js`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/extensions/dbcode-wrapper-profile-migration/extension.js) — setup, import, and recovery orchestration.
- [`migration.js`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/extensions/dbcode-wrapper-profile-migration/migration.js) and [`profileRecovery.js`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/extensions/dbcode-wrapper-profile-migration/profileRecovery.js) — safe state movement.
- [`managed-settings.json`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/extensions/dbcode-wrapper-profile-migration/managed-settings.json) — focused defaults.

## Dependencies

The module uses [Release Specification](release-specification.md) for identity and schema, [Focused Runtime Setup](focused-runtime-setup.md) for packages, and Code OSS APIs for commands, storage, and relaunch. First-launch and recovery work are normal user flows, not repeated deployment tests.

## Participates in

- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)

## Related

- [Standalone DBCode Profile](../concepts/standalone-dbcode-profile.md)
- [Focused host and private profile](../architecture/focused-host-and-private-profile.md)
- [Host Session](host-session.md)