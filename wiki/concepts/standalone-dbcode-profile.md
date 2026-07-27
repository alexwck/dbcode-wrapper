---
title: Standalone DBCode Profile
description: The wrapper-owned external state boundary for settings, packages, secure data, queries, logs, and recovery.
type: concept
tags:
  - wiki
  - concept
  - profile
  - isolation
wiki_profile: public
wiki_depth: standard
source_commit: ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1
---
## Definition

A Standalone DBCode Profile is the complete external state used by DBCode Wrapper. It includes user data, external extensions, shared and secure-storage data, query storage, cache, logs, backups, and recovery records under a validated owner root.

Its application, bundle, folder, query-storage, and schema identity comes from one generated [Release Specification](../modules/release-specification.md) record. The default personal profile, persistent generated `qa` profile, and explicit isolated profiles use the same logical identity with different owned roots.

## Why it matters

The profile makes the app standalone while keeping the official DBCode package and private state outside public source. Stable paths let a compatible app replacement reuse activation and connection state. Strict ownership and identity checks prevent setup or recovery from touching unrelated editor data.

The generated `qa` profile keeps normal DBCode state between rendered runs. It uses a mock Keychain and never replaces or inspects the personal profile. The default deployment path does not reset it to retest first launch.

Keeping the profile in the release-set model also makes upgrade and rollback honest: the retained app reads identity from its own current or historical Release Specification instead of assuming today's names.

## Where it lives

- Generated identity: [`profile-identity.json`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/extensions/dbcode-wrapper-profile-migration/profile-identity.json)
- Layout creation and validation: [`profile-layout.js`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/extensions/dbcode-wrapper-profile-migration/profile-layout.js)
- Setup and recovery: [`profileSetup.js`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/extensions/dbcode-wrapper-profile-migration/profileSetup.js)
- Shell path adapter: [`script/lib/profile_paths.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/script/lib/profile_paths.sh)
- Profile settings: [`host/profile/settings.json`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/profile/settings.json)

## Related

- [Profile Layout and Setup](../modules/profile-layout-and-setup.md)
- [Focused host and private profile](../architecture/focused-host-and-private-profile.md)
- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Verification Harness](../modules/verification-harness.md)