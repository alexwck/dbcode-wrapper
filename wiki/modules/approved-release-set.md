---
title: Approved Release Set
description: Validation, matching, and prompt-free approval logic for exact release history.
type: module
tags:
  - wiki
  - module
  - release
  - approval
wiki_profile: public
wiki_depth: standard
source_commit: e02160a3b5363fc4e91c5282f7818ed908624c6d
---
## Summary

The Approved Release Set module validates durable approval history and turns a fully verified prompt-free Host Release package into an approved compatibility record. Matching version strings alone cannot satisfy the contract. The writer receives validated records from the [Release Specification](release-specification.md) and [Host Release](host-release.md) modules, then binds them to the exact package receipt and a no-install attestation.

Maintained history includes public release `v0.1.3`, with unchanged DBCode `1.36.4` on Code OSS `1.126.0` and VSCodium packaging `1.126.04524`. Approval did not install the app or write the production profile.

## Responsibilities

- Validate approved history and installed release-set records.
- Bind release-set identity to immutable source, compiled-host input, signed app digest, external package inventory, and profile schema.
- Find exact discovered candidates without treating update metadata as approval.
- Create one compact approved record only from validated prompt-free acceptance and mounted-package evidence.
- Require the exact package-check set, release-set confirmation, and no-install attestation.
- Keep canonical package-check names shared by producer and consumer.
- Upsert history without silently retaining a duplicate identity.
- Keep legacy records readable without letting them define a new candidate.

## Public API / entry points

The JavaScript API exposes approved-record and history validators, exact candidate lookup, package-check vocabulary, prompt-free record creation, and history upsert. Shell consumers use [approved_release_set.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/lib/approved_release_set.sh). [approve_host_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/approve_host_release.sh) is the task-level approval command. It consumes final package evidence instead of accepting a build-app path.

## Key files

- [approved-release-set.js](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/host/extensions/dbcode-wrapper-release-status/approved-release-set.js) — history, exact matching, approval records, and package checks.
- [approved_release_set.cjs](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/approved_release_set.cjs) — bounded shell-to-JavaScript adapter.
- [host/approved-release-history.json](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/host/approved-release-history.json) — public history safe to bundle.
- [script/test_approved_release_set.mjs](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/test_approved_release_set.mjs) — history, exact-match, approval, and legacy contracts.

## Dependencies

The module consumes [Release Source Snapshot](release-source-snapshot.md), [Compiled Host Cache](compiled-host-cache.md), build manifests, acceptance digests, package receipts, and profile inventories.

## Participates in

- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)
- [Package and publish a Host Release](../flows/package-and-publish-host-release.md)

## Related

- [Approved Release Set concept](../concepts/approved-release-set.md)
- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Verification Harness](verification-harness.md)
