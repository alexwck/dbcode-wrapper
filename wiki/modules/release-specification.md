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
source_commit: 03b41f3106f00d64fffa5307ddd2084981972818
---
## Summary

Release Specification is the main read boundary around `host/release-lock.json`. It validates the full lock before projecting smaller records for build, compiled-host identity, extensions, profile, release status, approval, packaging, and rollback. Each consumer receives only the facts it owns.

## Responsibilities

- Reject incomplete or malformed current release locks.
- Read supported frozen lock shapes through a separate historical adapter.
- Produce purpose-specific JSON records without duplicating `jq` interpretations across scripts.
- Compare DBCode payload identity separately from the host compilation contract.
- Keep product identity, upstream commits, package digests, profile schema, target, toolchain, and release-set base identity connected.
- Expose the exact compile-time record used by [Compiled Host Cache](compiled-host-cache.md).

## Public API / entry points

The shell API includes `release_specification_validate`, `release_specification_record`, historical validation and projection, `release_specification_same_dbcode_payload`, and `release_specification_same_host_build_contract`.

Consumers source the library and request a named record such as `build`, `compiled-host`, `extensions`, or `profile` instead of reading the lock directly.

## Key files

- [`script/lib/release_specification.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/lib/release_specification.sh) — validation, projection, and comparison logic.
- [`host/release-lock.json`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/release-lock.json) — canonical release declaration.
- [`script/test_release_specification.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/test_release_specification.sh) — current and historical contract tests.

## Dependencies

The module is shell plus `jq`. Build, source snapshot, cache, runtime setup, update status, prompt-free approval, private release, and rollback readers consume its projections.

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)
- [Package and transfer a private release](../flows/package-and-transfer-private-release.md)

## Related

- [Release Source Snapshot](release-source-snapshot.md)
- [Compiled Host Cache](compiled-host-cache.md)
- [Approved Release Set](approved-release-set.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)