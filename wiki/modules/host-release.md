---
title: Host Release
description: The owner-facing task for preparing and publishing one exact wrapper release.
type: module
tags:
  - wiki
  - module
  - release
  - packaging
wiki_profile: public
wiki_depth: standard
source_commit: afc5fe7666bf88007bcf4956f05928e3d93c8e2f
---
## Summary

Host Release turns one accepted wrapper build into a normal published release in this repository. One task derives the release tag and standard evidence paths from the [Release Specification](release-specification.md), so the owner does not have to assemble a long command by hand.

The public assets are the host-only DMG and checksum. DBCode, notebook packages, licences, credentials, databases, profiles, signing secrets, compatibility records, and verification receipts stay outside the public assets.

Automatic update polling remains separate and read-only. It may report a newer Code OSS, VSCodium, or DBCode version, but only the repository owner starts preparation or publication.

## Owner commands

```bash
./script/release_host.sh plan
./script/release_host.sh prepare
git add host/approved-release-history.json
git commit -m "chore(release): record approved host release"
./script/release_host.sh publish --publish
```

`plan` is read-only. `prepare` validates complete prompt-free acceptance before creating or verifying the annotated tag. It then packages the app, independently verifies the mounted DMG, validates the exact approval, and writes one safe tracked history change. Exact existing evidence may be reused only when all identity and digest checks still pass. Publication is always a separate explicit action.

## Responsibilities

- Derive the tag and standard app, manifest, rendered, acceptance, asset, approval, and history paths.
- Validate complete prompt-free acceptance before tag creation.
- Require an annotated tag at the immutable source commit that built the app.
- Package and independently verify the host-only DMG.
- Bind approval to the manifest, release lock, tag, attestation, approved record, candidate history, timestamps, modes, flags, and SHA-256 digests.
- Record one idempotent approval-history update for review and commit.
- Publish only after the history change is committed and `--publish` is supplied.
- Verify that GitHub created a normal release with the expected public assets and digests.

## Public API / entry points

[release_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/release_host.sh) is the owner-facing interface. It keeps [verify_fast_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/verify_fast_release.sh), [package_host_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/package_host_release.sh), [verify_host_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/verify_host_release.sh), [approve_host_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/approve_host_release.sh), and [publish_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/publish_release.sh) as separate focused adapters.

## Key files

- [script/lib/host_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/lib/host_release.sh) — release contexts, copy checks, compatibility records, and metadata safety.
- [script/lib/approved_release_set.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/lib/approved_release_set.sh) — exact approval validation and safe history recording.
- [script/host_release_contract.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/host_release_contract.sh) — authoritative acceptance-record validation.
- [script/test_release_host_task.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/test_release_host_task.sh) — prompt-free fixture coverage for order, resume, and explicit publication.
- [host/approved-release-history.json](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/approved-release-history.json) — tracked approved history bundled with the wrapper.

## Dependencies

The task consumes [Release Source Snapshot](release-source-snapshot.md), [Compiled Host Cache](compiled-host-cache.md), [Approved Release Set](approved-release-set.md), [Verification Harness](verification-harness.md), the signed app, macOS packaging tools, Git, GitHub CLI, and [Generated Workspace Retention](generated-workspace-retention.md).

## Participates in

- [Package and publish a Host Release](../flows/package-and-publish-host-release.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)

## Related

- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)