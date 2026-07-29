---
title: Release Specification
description: The canonical reader and validator for product identity, pinned dependencies, distribution, profile schema, and release state.
type: module
tags:
  - wiki
  - module
  - release
wiki_profile: public
wiki_depth: standard
source_commit: ca6a58c0be798dfb6438f8326417ebd9ba42a354
---
## Summary

Release Specification is the main read boundary around `host/release-lock.json`. It validates the complete lock before returning smaller records for builds, Compiled Host identity, extensions, profiles, release status, approval, packaging, publication, and rollback.

Current schema 7 keeps the normal GitHub distribution policy and replaces the old responsive result-layout record with one `below` result location. Product and profile identity remain in one validated record.

Released schema-6 locks remain readable only through the historical adapter. Their wide-window `beside` placement is not equivalent to schema 7, so an old responsive host cannot be reused for the new bottom-results contract.

## Responsibilities

- Reject incomplete, malformed, or unsafe current release locks.
- Return purpose-specific JSON records instead of spreading direct `jq` reads across scripts.
- Keep product identity, upstream commits, package digests, profile schema, distribution, toolchain, and release-set identity connected.
- Compare DBCode package identity separately from the host compilation contract.
- Expose only real compile-time values to [Compiled Host Cache](compiled-host-cache.md).
- Read supported frozen locks through a separate read-only historical adapter without turning them into new candidates.

## Public API / entry points

The shell API includes `release_specification_validate`, `release_specification_record`, historical validation and projection, DBCode-payload comparison, and host-build-contract comparison.

Consumers ask for a named record such as `build`, `compiled-host`, `extensions`, `profile`, or `identity`. Profile-only folder and schema changes do not alter the compiled-host record. Query storage values do because the focused shell embeds them.

## Key files

- [script/lib/release_specification.sh](https://github.com/alexwck/dbcode-wrapper/blob/ca6a58c0be798dfb6438f8326417ebd9ba42a354/script/lib/release_specification.sh) — current validation, projections, historical reads, and comparison logic.
- [host/release-lock.json](https://github.com/alexwck/dbcode-wrapper/blob/ca6a58c0be798dfb6438f8326417ebd9ba42a354/host/release-lock.json) — canonical release declaration.
- [script/test_release_specification.sh](https://github.com/alexwck/dbcode-wrapper/blob/ca6a58c0be798dfb6438f8326417ebd9ba42a354/script/test_release_specification.sh) — current, distribution, unsafe-input, historical, and host-reuse contracts.

## Dependencies

The module is shell plus `jq`. Build, source snapshot, cache, runtime setup, profile layout, update status, approval, Host Release, publication, and rollback code consume its projections.

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)
- [Package and publish a Host Release](../flows/package-and-publish-host-release.md)

## Related

- [Release Source Snapshot](release-source-snapshot.md)
- [Compiled Host Cache](compiled-host-cache.md)
- [Profile Layout and Setup](profile-layout-and-setup.md)
- [Approved Release Set](approved-release-set.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)
