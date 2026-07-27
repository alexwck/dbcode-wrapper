---
title: Standalone DBCode Profile
description: The wrapper-owned external state boundary for settings, packages, secure data, logs, and recovery.
type: concept
tags:
  - wiki
  - concept
  - profile
  - isolation
wiki_profile: public
wiki_depth: standard
source_commit: 2008ff48373c1aac378d0d1ec903e96a88ec1e29
---
## Definition

A Standalone DBCode Profile is the complete external state used by DBCode Wrapper. It includes user data, external extensions, shared and secure-storage data, cache, logs, backups, and recovery records under a validated owner root.

It is separate from a normal VS Code profile, project folder, database file, and app bundle. The default personal profile, persistent generated `qa` profile, and explicit isolated profiles share one logical schema but use different owned roots.

## Why it matters

The profile makes the app standalone while keeping the official DBCode package and private state outside public source. Stable paths let a compatible app replacement reuse activation and connection state. Strict ownership checks prevent setup or recovery from touching unrelated editor data.

The generated `qa` profile keeps normal DBCode state between rendered runs. It uses a mock Keychain and never replaces or inspects the personal profile. The default deployment path does not reset it to retest first launch.

Keeping the profile in the release-set model also makes upgrade and rollback honest: app and owned state move together.

## Where it lives

- Layout creation and validation: [`profile-layout.js`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/extensions/dbcode-wrapper-profile-migration/profile-layout.js)
- Setup and recovery: [`extension.js`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/extensions/dbcode-wrapper-profile-migration/extension.js)
- Profile settings: [`host/profile/settings.json`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/profile/settings.json)
- Domain wording: [`CONTEXT.md`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/CONTEXT.md)

## Related

- [Profile Layout and Setup](../modules/profile-layout-and-setup.md)
- [Focused host and private profile](../architecture/focused-host-and-private-profile.md)
- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Verification Harness](../modules/verification-harness.md)