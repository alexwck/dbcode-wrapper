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
source_commit: 2008ff48373c1aac378d0d1ec903e96a88ec1e29
---
## Summary

The Approved Release Set module turns a prepared candidate into a durable compatibility record. It validates canonical source and artifact identities, digests, installed extension inventories, acceptance evidence, and approval metadata. Matching version strings alone cannot satisfy the contract.

## Responsibilities

- Validate prepared candidate, approved history, and installed records.
- Bind the release-set ID to the source-set ID and exact signed app digest.
- Require the immutable source-snapshot digest and compiled-host input ID for current approvals.
- Resolve candidate member paths safely below the release-set root.
- Create one compact approved record from a candidate and matching evidence.
- Upsert history without silently retaining another record with the same identity.
- Match installed and discovered candidates against approved history.
- Keep legacy records readable without letting them define a new candidate.

## Public API / entry points

The JavaScript API exposes record validators, safe member resolution, candidate lookup, approved-record creation, and history upsert. Shell consumers use [`approved_release_set.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/lib/approved_release_set.sh).

## Key files

- [`approved-release-set.js`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/extensions/dbcode-wrapper-release-status/approved-release-set.js) — canonical schema and transformation logic.
- [`host/approved-release-history.json`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/approved-release-history.json) — public history safe to bundle.
- [`script/test_approved_release_set.mjs`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/test_approved_release_set.mjs) — schema and identity tests.

## Dependencies

The module consumes [Release Specification](release-specification.md), [Release Source Snapshot](release-source-snapshot.md), [Compiled Host Cache](compiled-host-cache.md), build manifests, acceptance digests, and profile inventories.

## Participates in

- [Controlled upgrade and rollback](../flows/controlled-upgrade-and-rollback.md)
- [Package and transfer a private release](../flows/package-and-transfer-private-release.md)

## Related

- [Approved Release Set concept](../concepts/approved-release-set.md)
- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Verification Harness](verification-harness.md)