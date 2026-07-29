---
title: Host Release
description: The normal public packaging, verification, approval, and publication path for one exact DBCode Wrapper build.
type: module
tags:
  - wiki
  - module
  - release
  - packaging
wiki_profile: public
wiki_depth: standard
source_commit: e02160a3b5363fc4e91c5282f7818ed908624c6d
---
## Summary

Host Release turns one prompt-free accepted wrapper build into a normal published release in this repository. The public assets are the host-only DMG and its checksum. DBCode, notebook packages, licences, credentials, databases, profiles, signing secrets, compatibility metadata, and verification receipts stay outside the public assets.

The module keeps automatic update discovery separate. Polling may refresh the status icon and review view, but only the repository owner starts a version bump, approval, tag, or publication.

## Responsibilities

- Require an annotated source tag at the exact immutable commit that built the app.
- Match the release lock, source snapshot, compiled-host receipt, signed app, manifest, and prompt-free acceptance report.
- Perform one full package-source validation and create one digest-bound release context.
- Accept the staging copy only while its digest, signature, identity, architecture, and required notices still match that context.
- Build one read-only DMG plus local checksum, compatibility, install-and-rollback, and verification files.
- Mount the DMG below a private temporary root and create a separate fully validated context from the mounted app.
- Approve the exact package without installing the app or writing the production profile.
- Publish only the DMG and checksum as a normal GitHub release, then verify public state, sizes, and SHA-256 digests.

## Public API / entry points

[package_host_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/package_host_release.sh) creates the local release set. [verify_host_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/verify_host_release.sh) mounts and independently verifies the DMG. [approve_host_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/approve_host_release.sh) writes prompt-free approval evidence. [publish_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/publish_release.sh) performs the explicit normal publication and checks its public result.

## Key files

- [script/lib/host_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/lib/host_release.sh) — source validation, release-context construction, copy checks, compatibility records, and metadata safety.
- [script/host_release_contract.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/host_release_contract.sh) — validated prompt-free acceptance adapter for approval.
- [script/test_host_release_contract.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/test_host_release_contract.sh) — task-level package, mount, approval, path, and tamper contracts.
- [host/approved-release-history.json](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/host/approved-release-history.json) — maintained approved history bundled with the app.

## Dependencies

The module consumes [Release Specification](release-specification.md), [Release Source Snapshot](release-source-snapshot.md), [Compiled Host Cache](compiled-host-cache.md), [Approved Release Set](approved-release-set.md), [Verification Harness](verification-harness.md), the signed app, macOS packaging tools, Git, and [Generated Workspace Retention](generated-workspace-retention.md).

## Participates in

- [Package and publish a Host Release](../flows/package-and-publish-host-release.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)

## Related

- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)
