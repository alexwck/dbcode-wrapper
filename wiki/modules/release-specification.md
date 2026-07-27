---
title: Release Specification
description: The canonical reader and validator for product identity, pinned dependencies, profile schema, and release state.
type: module
tags:
  - wiki
  - module
  - release
wiki_profile: public
wiki_depth: standard
source_commit: ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1
---
## Summary

Release Specification is the main read boundary around `host/release-lock.json`. It validates the complete lock before returning smaller records for builds, Compiled Host identity, extensions, profiles, release status, approval, packaging, and rollback.

Schema 5 makes the profile identity explicit. The application name, executable name, bundle identifier, user-data folder, extension folder, shared-data folder, backup folder, storage namespace, query folder, and profile schema now come from one validated profile record. Folder, executable, URL-scheme, and bundle values are checked before build or profile code can use them.

## Responsibilities

- Reject incomplete, malformed, or unsafe current release locks.
- Read supported frozen schema-2 and schema-4 locks through a separate historical adapter.
- Return purpose-specific JSON records instead of spreading direct `jq` reads across scripts.
- Compare DBCode package identity separately from the host compilation contract.
- Keep product identity, upstream commits, package digests, profile schema, target, toolchain, and release-set identity connected.
- Expose only real compile-time values to [Compiled Host Cache](compiled-host-cache.md).

## Public API / entry points

The shell API includes `release_specification_validate`, `release_specification_record`, historical validation and projection, `release_specification_same_dbcode_payload`, and `release_specification_same_host_build_contract`.

Consumers ask for a named record such as `build`, `compiled-host`, `extensions`, `profile`, or `identity`. Profile-only folder and schema changes do not alter the compiled-host record. Query storage values do because the focused shell embeds them in its product record.

## Key files

- [`script/lib/release_specification.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/script/lib/release_specification.sh) — current validation, projections, historical reads, and comparison logic.
- [`host/release-lock.json`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/release-lock.json) — canonical release declaration.
- [`script/test_release_specification.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/script/test_release_specification.sh) — current, unsafe-input, historical, and host-reuse contracts.

## Dependencies

The module is shell plus `jq`. Build, source snapshot, cache, runtime setup, profile layout, update status, prompt-free approval, private release, and rollback code consume its projections.

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)
- [Package and transfer a private release](../flows/package-and-transfer-private-release.md)

## Related

- [Release Source Snapshot](release-source-snapshot.md)
- [Compiled Host Cache](compiled-host-cache.md)
- [Profile Layout and Setup](profile-layout-and-setup.md)
- [Approved Release Set](approved-release-set.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)