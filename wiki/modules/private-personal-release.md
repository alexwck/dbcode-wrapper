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
source_commit: ea091613c180550d6e6df9120b2a9b4fe66ffcc2
---
## Summary

A Private Personal Release is a locally produced host-only package for Macs owned by the same person. The public repository supplies build and verification logic. The owner's machine supplies the signed app and private release output. DBCode, notebook packages, licences, credentials, and profile state are installed separately and are not placed in the DMG.

## Responsibilities

- Require an annotated source tag at the exact immutable source commit that built the app.
- Match the tag's release lock, source snapshot, compiled-host receipt, signed app, manifest, and prompt-free acceptance report.
- Verify bundle identity and nested signatures.
- Validate the complete schema-3 acceptance report once and expose a compact validated record to the approval adapter.
- Generate sanitized compatibility metadata without credentials, licences, profile contents, or local paths.
- Build the host-only DMG and external checksum.
- Mount and verify the final image independently before transfer.
- Keep live app signature and architecture checks in packaging and mounted verification.
- Create a generated approval bundle only after the exact acceptance, package, source tag, final receipt, and confirmation agree. Approval does not accept or recheck a build-app path.
- Keep approval separate from installation and production-profile writes.
- Keep final assets protected until the owning workflow releases them.

## Public API / entry points

[`package_private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/script/package_private_release.sh) builds the package. [`verify_private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/script/verify_private_release.sh) mounts and verifies it. [`approve_private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/script/approve_private_release.sh) consumes that final receipt and writes the generated approval bundle without installing. Shared checks and compatibility-record construction live in [`script/lib/private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/script/lib/private_release.sh).

## Key files

- [`script/verify_fast_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/script/verify_fast_release.sh) — exact-source and exact-app acceptance.
- [`script/package_private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/script/package_private_release.sh) — task-level packager.
- [`script/verify_private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/script/verify_private_release.sh) — independent mounted-image verifier.
- [`script/private_release_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/script/private_release_contract.sh) — read-only schema-3 acceptance adapter for the approval writer.
- [`script/approve_private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/script/approve_private_release.sh) — prompt-free approval evidence writer.
- [`script/verify_same_mac_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/script/verify_same_mac_release.sh) — optional owner-machine continuity checks outside normal deployment.

## Dependencies

The module consumes [Release Source Snapshot](release-source-snapshot.md), [Compiled Host Cache](compiled-host-cache.md), [Approved Release Set](approved-release-set.md), [Verification Harness](verification-harness.md), the signed app, macOS packaging tools, and [Generated Workspace Retention](generated-workspace-retention.md).

## Participates in

- [Package and transfer a private release](../flows/package-and-transfer-private-release.md)
- [Controlled upgrade and rollback](../flows/controlled-upgrade-and-rollback.md)

## Related

- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Standalone DBCode Profile](../concepts/standalone-dbcode-profile.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)