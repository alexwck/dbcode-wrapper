---
title: Approved Release Set
description: Validation and history logic that binds a compatible app, profile, packages, and proof into one approved unit.
type: module
tags:
  - wiki
  - module
  - release
  - approval
wiki_profile: public
wiki_depth: standard
source_commit: efe247fc701a9b529e3e6368b6571a44541fc146
---
## Summary

The Approved Release Set module turns a prepared candidate into a durable compatibility record. It validates canonical identities, artifact references, digests, installed extension inventories, evidence, and approval metadata. A matching version string alone cannot satisfy this contract.

## Responsibilities

- Validate prepared candidate records before testing or promotion.
- Validate current and supported legacy approval-history records.
- Resolve prepared member paths safely below the release-set root.
- Create a compact approved record from a candidate and its attestation.
- Upsert an approved record without silently retaining an older record with the same identity.
- Match an installed release and discovered candidate against approved history.

## Public API / entry points

The JavaScript API exposes validators for prepared, approved, history, and installed records; member-path resolution; candidate lookup; approved-record creation; and history upsert. Shell consumers use [`approved_release_set.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/lib/approved_release_set.sh) as the command-line adapter.

## Key files

- [`approved-release-set.js`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/extensions/dbcode-wrapper-release-status/approved-release-set.js) — canonical schema and transformation logic.
- [`host/approved-release-history.json`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/approved-release-history.json) — public approval history safe to bundle.
- [`script/test_approved_release_set.mjs`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/test_approved_release_set.mjs) — schema and matching tests.

## Dependencies

The module consumes projections from [Release Specification](release-specification.md), prepared release-set files, build manifests, evidence digests, and profile inventories. The release-status extension and controlled-upgrade script are major consumers.

## Participates in

- [Controlled upgrade and rollback](../flows/controlled-upgrade-and-rollback.md)
- [Package and transfer a private release](../flows/package-and-transfer-private-release.md)

## Related

- [Approved Release Set concept](../concepts/approved-release-set.md)
- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Verification Harness](verification-harness.md)
