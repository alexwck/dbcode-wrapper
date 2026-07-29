---
title: Approved Release Set
description: Exact approval validation, update matching, and tracked release history.
type: module
tags:
  - wiki
  - module
  - release
  - approval
wiki_profile: public
wiki_depth: standard
source_commit: afc5fe7666bf88007bcf4956f05928e3d93c8e2f
---
## Summary

The Approved Release Set module validates durable release history and turns a fully verified Host Release package into one approved compatibility record. Matching version strings, a route check, or an old success report is not enough.

The module now validates the complete recorded approval before the owner task changes tracked history. It checks the manifest, release lock, annotated tag, attestation, approved record, candidate history, approval mode and time, validation issue, release-set confirmation, install and profile flags, privileged-action flags, and SHA-256 bindings.

## Responsibilities

- Validate current approved history and installed release-set records.
- Bind source, compiled-host input, app digest, package inventory, profile schema, acceptance, mounted package, and approval.
- Find exact discovered candidates without treating update metadata as approval.
- Validate the generated record and candidate history before any tracked file changes.
- Record one approval in `host/approved-release-history.json` atomically and idempotently.
- Keep the tracked file reviewable and safe to bundle.
- Reject duplicates, mismatched identity, altered timestamps, unsafe modes, install claims, profile changes, privileged actions, or digest drift.
- Keep older readable history separate from new candidate creation.

## Public API / entry points

Shell consumers use [approved_release_set.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/lib/approved_release_set.sh). The owner-facing [release_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/release_host.sh) calls exact validation and history recording after mounted-package approval.

The JavaScript API in [approved-release-set.js](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/extensions/dbcode-wrapper-release-status/approved-release-set.js) owns history validation, exact candidate matching, approval records, and the shared package-check vocabulary.

## Key files

- [script/approved_release_set.cjs](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/approved_release_set.cjs) — bounded shell-to-JavaScript adapter.
- [host/approved-release-history.json](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/approved-release-history.json) — public tracked history.
- [script/test_approved_release_set.mjs](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/test_approved_release_set.mjs) — history, exact-match, approval, and legacy contracts.
- [script/test_release_host_task.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/test_release_host_task.sh) — owner-task ordering, exact reuse, and publication contracts.

## Dependencies

The module consumes [Release Source Snapshot](release-source-snapshot.md), [Compiled Host Cache](compiled-host-cache.md), build manifests, acceptance digests, package receipts, profile inventories, and [Host Release](host-release.md) evidence.

## Participates in

- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)
- [Package and publish a Host Release](../flows/package-and-publish-host-release.md)

## Related

- [Approved Release Set concept](../concepts/approved-release-set.md)
- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Verification Harness](verification-harness.md)