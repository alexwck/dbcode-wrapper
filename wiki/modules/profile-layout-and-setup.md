---
title: Profile Layout and Setup
description: The path, migration, recovery, and first-run module for the isolated Standalone DBCode Profile.
type: module
tags:
  - wiki
  - module
  - profile
  - setup
wiki_profile: public
wiki_depth: standard
source_commit: efe247fc701a9b529e3e6368b6571a44541fc146
---
## Summary

Profile Layout defines where each Standalone DBCode Profile is allowed to live. Profile Setup uses that contract to prepare a fresh profile, review an import, install verified runtime packages, recover owned state, and open DBCode connections without touching unrelated editor profiles.

## Responsibilities

- Derive the `default`, `qa`, and `isolated` layouts from explicit owner roots.
- Validate serialized layouts and reject unknown or escaped paths.
- Check mutation targets before setup, migration, backup, or recovery.
- Keep user data, extension data, shared data, cache, logs, and backups in one owned layout.
- Guide first-run setup and optional connection import.
- Recreate only the wrapper-owned profile when recovery is explicitly confirmed.

## Public API / entry points

`createProfileLayout`, `validateProfileLayout`, `assertSafeMutationPaths`, and `parseMatchingLayout` form the path API. The extension activates the Profile Setup controller and commands. Migration, staging, runtime setup, and recovery helpers handle narrower operations behind that controller.

## Key files

- [`profile-layout.js`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/extensions/dbcode-wrapper-profile-migration/profile-layout.js) — path derivation and validation.
- [`extension.js`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/extensions/dbcode-wrapper-profile-migration/extension.js) — first-run, import, and recovery orchestration.
- [`migration.js`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/extensions/dbcode-wrapper-profile-migration/migration.js) and [`profileRecovery.js`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/extensions/dbcode-wrapper-profile-migration/profileRecovery.js) — safe state movement.
- [`managed-settings.json`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/extensions/dbcode-wrapper-profile-migration/managed-settings.json) — focused default settings.

## Dependencies

The module depends on [Release Specification](release-specification.md) for identity and profile schema, [Focused Runtime Setup](focused-runtime-setup.md) for package installation, and Code OSS extension APIs for commands, storage, and relaunch.

## Participates in

- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Controlled upgrade and rollback](../flows/controlled-upgrade-and-rollback.md)

## Related

- [Standalone DBCode Profile](../concepts/standalone-dbcode-profile.md)
- [Focused host and private profile](../architecture/focused-host-and-private-profile.md)
- [Host Session](host-session.md)
