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
source_commit: 02a3c237d5e7baf9c741e1a1dcd7828730490032
---
## Summary

Profile Layout defines where every Standalone DBCode Profile path may live. Release assembly generates one small identity record from [Release Specification](release-specification.md), and shell and bundled JavaScript validate and use that same record. Assembly also materializes the packaged recovery settings from the one canonical `host/profile/settings.json` file; Static Host Smoke verifies the exact copy.

Profile Setup owns the first-use workflow behind one testable interface. A command router registers Runtime Setup and Profile Setup before startup state is known. When the external runtime is missing, Profile Setup opens that prerequisite instead of producing a missing-command error. Both first-run webviews share one fail-closed content-security, nonce, escaping, and action-message policy. The recovery worker exposes one `run` interface and receives clock, process, filesystem, sleep, and relaunch behaviour through an operating-system adapter.

## Responsibilities

- Load and validate the generated application, bundle, folder, query-storage, and profile-schema identity.
- Derive only the current-user `default` layout and the persistent generated `qa` layout from owned roots.
- Register every visible first-run command before configuration or phase selection.
- Route an unmet runtime prerequisite to Runtime Setup and keep configuration failures sanitized.
- Reject missing, linked, malformed, oversized, unsafe, stale, or mismatched identity and layout data.
- Own start-clean, reviewed import, staging cleanup, DuckDB preflight, completion, cancellation, and recovery order.
- Remove reviewed temporary data after completion, cancellation, close, recovery, or an action failure.
- Recreate only wrapper-owned state after explicit user confirmation.

## Public API / entry points

`loadProfileIdentity`, `validateProfileIdentity`, `createProfileLayout`, `validateProfileLayout`, `assertSafeMutationPaths`, and `parseMatchingLayout` form the identity and path API. `script/profile_layout.cjs` gives shell callers the same implementation and accepts only `default` or `qa`. Recovery is limited to the current-user default profile.

`createFirstRunCommandRouter` owns immediate command registration and prerequisite routing. `ProfileSetup` provides `requiresSetup`, `open`, `dispatch`, and `panelClosed`. `profileRecoveryWorker.run` owns process waiting, recovery outcomes, and relaunch. Production supplies real host and operating-system adapters. Fast tests use controlled adapters and exercise the same public order.

## Key files

- [firstRunCommandRouter.js](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/extensions/dbcode-wrapper-profile-migration/firstRunCommandRouter.js) — always-registered first-run command routing.
- [webviewSafety.js](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/extensions/dbcode-wrapper-profile-migration/webviewSafety.js) — shared trusted HTML/CSS rendering boundary, nonce, CSP, and action messages.
- [profile-identity.json](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/extensions/dbcode-wrapper-profile-migration/profile-identity.json) — generated profile identity.
- [host/profile/settings.json](https://github.com/alexwck/dbcode-wrapper/blob/37003175d654b33c7ad97222bdb49ee614665f53/host/profile/settings.json) — the one tracked managed-settings source.
- [profile-layout.js](https://github.com/alexwck/dbcode-wrapper/blob/37003175d654b33c7ad97222bdb49ee614665f53/host/extensions/dbcode-wrapper-profile-migration/profile-layout.js) — identity loading, path derivation, and validation.
- [profileSetup.js](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/extensions/dbcode-wrapper-profile-migration/profileSetup.js) — setup state and action ordering.
- [profileRecoveryWorker.js](https://github.com/alexwck/dbcode-wrapper/blob/02a3c237d5e7baf9c741e1a1dcd7828730490032/host/extensions/dbcode-wrapper-profile-migration/profileRecoveryWorker.js) — the one recovery worker interface and its operating-system adapter.
- [migration.js](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/extensions/dbcode-wrapper-profile-migration/migration.js), [staging.js](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/extensions/dbcode-wrapper-profile-migration/staging.js), and [profileRecovery.js](https://github.com/alexwck/dbcode-wrapper/blob/37003175d654b33c7ad97222bdb49ee614665f53/host/extensions/dbcode-wrapper-profile-migration/profileRecovery.js) — reviewed import, temporary storage, and safe state movement.

## Dependencies

The module uses [Release Specification](release-specification.md) for identity and schema, [Focused Runtime Setup](focused-runtime-setup.md) for packages, and Code OSS APIs through the host adapter. First launch and recovery are normal user flows, not repeated deployment tests.

## Participates in

- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)

## Related

- [Standalone DBCode Profile](../concepts/standalone-dbcode-profile.md)
- [Focused host and private profile](../architecture/focused-host-and-private-profile.md)
- [Host Session](host-session.md)
- [Verification Harness](verification-harness.md)