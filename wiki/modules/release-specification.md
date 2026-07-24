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
source_commit: efe247fc701a9b529e3e6368b6571a44541fc146
---
## Summary

Release Specification is the main read boundary around `host/release-lock.json`. It validates the whole lock before projecting smaller records for build, extension, profile, release-status, upgrade, and packaging consumers. This prevents each script from interpreting the same release facts differently.

## Responsibilities

- Reject incomplete or malformed current release locks.
- Read older supported lock shapes through a separate historical path.
- Produce purpose-specific JSON records without exposing unrelated fields.
- Compare whether two specifications carry the same DBCode payload or the same host build contract.
- Keep product identity, upstream versions, package digests, profile schema, and release-set identity connected.

## Public API / entry points

The shell functions include `release_specification_validate`, `release_specification_record`, `release_specification_historical_validate`, `release_specification_historical_record`, `release_specification_same_dbcode_payload`, and `release_specification_same_host_build_contract`.

Consumers source the library and request a named record instead of querying the lock directly. New consumers should follow that pattern.

## Key files

- [`script/lib/release_specification.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/lib/release_specification.sh) — validation, projection, and comparison logic.
- [`host/release-lock.json`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/release-lock.json) — the canonical release declaration.
- [`script/test_release_specification.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/test_release_specification.sh) — contract tests for accepted and rejected shapes.

## Dependencies

The module is shell plus `jq`. Its output is consumed by the build, runtime setup, update status, controlled-upgrade, and private-release paths.

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Controlled upgrade and rollback](../flows/controlled-upgrade-and-rollback.md)
- [Package and transfer a private release](../flows/package-and-transfer-private-release.md)

## Related

- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Approved Release Set](approved-release-set.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)
