---
title: Private Personal Release
description: The owner-only packaging and verification path for one exact accepted DBCode Wrapper build.
type: module
tags:
  - wiki
  - module
  - release
  - packaging
wiki_profile: public
wiki_depth: standard
source_commit: 2008ff48373c1aac378d0d1ec903e96a88ec1e29
---
## Summary

A Private Personal Release is a locally produced host-only package for Macs owned by the same person. The public repository supplies build and verification logic. The owner's machine supplies the signed app and private release output. DBCode, notebook packages, licences, credentials, and profile state are installed separately and are not placed in the DMG.

## Responsibilities

- Require an annotated source tag at the exact immutable source commit that built the app.
- Match the tag's release lock, source snapshot, compiled-host receipt, signed app, manifest, and prompt-free acceptance report.
- Verify bundle identity and nested signatures.
- Require an acceptance report for the same release-set ID and app digest.
- Generate sanitized compatibility metadata without credentials, licences, profile contents, or local paths.
- Build the host-only DMG and external checksum.
- Mount and verify the final image independently before transfer.
- Keep final assets protected until the owning workflow releases them.

## Public API / entry points

[`package_private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/package_private_release.sh) builds the package. [`verify_private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/verify_private_release.sh) mounts and verifies it. Shared checks and compatibility-record construction live in [`script/lib/private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/lib/private_release.sh).

## Key files

- [`script/verify_fast_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/verify_fast_release.sh) — exact-source and exact-app acceptance.
- [`script/package_private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/package_private_release.sh) — task-level packager.
- [`script/verify_private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/verify_private_release.sh) — independent mounted-image verifier.
- [`script/verify_same_mac_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/verify_same_mac_release.sh) — owner-machine continuity checks.

## Dependencies

The module consumes [Release Source Snapshot](release-source-snapshot.md), [Compiled Host Cache](compiled-host-cache.md), [Approved Release Set](approved-release-set.md), [Verification Harness](verification-harness.md), the signed app, macOS packaging tools, and [Generated Workspace Retention](generated-workspace-retention.md).

## Participates in

- [Package and transfer a private release](../flows/package-and-transfer-private-release.md)
- [Controlled upgrade and rollback](../flows/controlled-upgrade-and-rollback.md)

## Related

- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Standalone DBCode Profile](../concepts/standalone-dbcode-profile.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)