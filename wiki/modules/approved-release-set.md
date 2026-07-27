---
title: Approved Release Set
description: Validation and history logic that binds exact source, app, packages, profile, and proof into one approved unit.
type: module
tags:
  - wiki
  - module
  - release
  - approval
wiki_profile: public
wiki_depth: standard
source_commit: 03b41f3106f00d64fffa5307ddd2084981972818
---
## Summary

The Approved Release Set module turns a prepared candidate or a fully verified prompt-free package into a durable compatibility record. Matching version strings alone cannot satisfy the contract. The prompt-free path first gets validated purpose records from the Release Specification and Private Personal Release modules, then binds them to the exact package receipt and a no-install attestation.

Maintained history now contains exact private release `v0.1.1`, with DBCode `1.36.4` on Code OSS `1.126.0`. Its record says explicitly that approval did not install the app or write the production profile.

## Responsibilities

- Validate prepared candidate, approved history, and installed records.
- Bind the release-set ID to the source-set ID and exact signed app digest.
- Require the immutable source-snapshot digest and compiled-host input ID for current approvals.
- Resolve candidate member paths safely below the release-set root.
- Create one compact approved record from a candidate and matching evidence.
- Accept prompt-free approval only after the owning modules validate the complete release lock and schema-3 acceptance report.
- Require the exact mounted-package check set, exact release-set confirmation, and an attestation that installation and profile writes did not occur.
- Provide the package verifier's canonical check names so producer and consumer cannot drift.
- Upsert history without silently retaining another record with the same identity.
- Match installed and discovered candidates against approved history.
- Keep legacy records readable without letting them define a new candidate.

## Public API / entry points

The JavaScript API exposes record validators, safe member resolution, candidate lookup, approved-record creation, and history upsert. Shell consumers use [`approved_release_set.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/script/lib/approved_release_set.sh). [`approve_private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/script/approve_private_release.sh) is the task-level prompt-free approval command. It consumes the final package receipt instead of accepting or rechecking a build-app path.

## Key files

- [`approved-release-set.js`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/host/extensions/dbcode-wrapper-release-status/approved-release-set.js) — canonical approved-record logic and package-check vocabulary.
- [`approved_release_set.cjs`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/script/approved_release_set.cjs) — bounded adapter that obtains validated purpose records before writing.
- [`host/approved-release-history.json`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/host/approved-release-history.json) — public history safe to bundle.
- [`script/test_approved_release_set.mjs`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/script/test_approved_release_set.mjs) — schema, bypass, path, and identity tests.

## Dependencies

The module consumes [Release Specification](release-specification.md), [Release Source Snapshot](release-source-snapshot.md), [Compiled Host Cache](compiled-host-cache.md), build manifests, acceptance digests, and profile inventories.

## Participates in

- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)
- [Package and transfer a private release](../flows/package-and-transfer-private-release.md)

## Related

- [Approved Release Set concept](../concepts/approved-release-set.md)
- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Verification Harness](verification-harness.md)