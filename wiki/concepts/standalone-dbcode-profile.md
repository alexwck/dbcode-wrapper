---
title: Standalone DBCode Profile
description: The wrapper-owned external state boundary that holds settings, extensions, secure data, logs, and recovery material.
type: concept
tags:
  - wiki
  - concept
  - profile
  - isolation
wiki_profile: public
wiki_depth: standard
source_commit: efe247fc701a9b529e3e6368b6571a44541fc146
---
## Definition

A Standalone DBCode Profile is the complete external state used by DBCode Wrapper. It includes user data, external extensions, shared and secure-storage data, cache, logs, backups, and recovery records under a validated owner root.

It is not the same as a normal VS Code profile, a project folder, a database file, or the app bundle. The default personal, QA, and isolated variants follow the same logical schema but use different owned roots.

## Why it matters

The profile is what makes the app standalone while leaving the licensed DBCode package unmodified and outside public source. Stable paths let a compatible app replacement reuse the same activation and connection state. Strict ownership checks prevent setup or recovery from touching normal editor data.

Keeping the whole profile in the release-set model also makes upgrades and rollback honest: app and state move together, rather than creating an untested mixture.

## Where it lives

- Layout creation and validation: [`profile-layout.js`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/extensions/dbcode-wrapper-profile-migration/profile-layout.js)
- Setup and recovery orchestration: [`extension.js`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/extensions/dbcode-wrapper-profile-migration/extension.js)
- Profile settings: [`host/profile/settings.json`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/profile/settings.json)
- Domain wording: [`CONTEXT.md`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/CONTEXT.md)

## Related

- [Profile Layout and Setup](../modules/profile-layout-and-setup.md)
- [Focused host and private profile](../architecture/focused-host-and-private-profile.md)
- [First run, activation, and query](../flows/first-run-activate-and-query.md)
