---
title: Host Release
description: The owner-facing task for preparing and explicitly publishing one exact wrapper release.
type: module
tags:
  - wiki
  - module
  - release
  - packaging
wiki_profile: public
wiki_depth: standard
source_commit: d01539e88c39b72712395899fd206eee40509ab3
---
## Summary

Host Release turns one committed wrapper source into one approved and normally published release in this repository. The task derives the tag and evidence paths from the [Release Specification](release-specification.md), so the owner does not assemble a long manual checklist.

Only the host DMG and checksum become public. DBCode, runtime packages, licences, credentials, databases, profiles, signing secrets, compatibility records, and verification receipts stay outside public assets.

## Owner commands

```bash
./script/release_host.sh plan
./script/release_host.sh prepare
git add host/approved-release-history.json
git commit -m "chore(release): record approved host release"
./script/release_host.sh publish --publish
```

`plan` is read-only. It reports the current source, exact paths, and a structured preparation state. `prepare` rejects an off-`main` source, an unrelated working-tree change, a lightweight tag, or a version tag at another commit before it takes the `dist/` lease. It then checks signing readiness, builds or reuses the exact host, runs static smoke and one persistent-profile rendered smoke, performs final acceptance, creates or verifies the annotated tag, packages, independently verifies, approves, and writes one tracked history change. `publish --publish` is deliberately separate.

A resumed preparation does not trust directory presence. An annotated tag must still identify the current commit, and only the expected approval-history edit may remain dirty. The final tag step rechecks `HEAD` before packaging. Reuse also validates the exact DMG, checksum, compatibility record, install notes, verification receipt, and approval digests.

## Responsibilities

- Derive the standard tag, current source, preparation state, and generated evidence paths.
- Reject unsafe branch, working-tree, or tag state before checkpoint acquisition.
- Hold or pass one kernel-backed checkpoint lease across every build and reader.
- Stop before assembly when the existing signing identity is not ready.
- Reuse only a complete host and rendered report for the exact release set.
- Validate final prompt-free acceptance before tag creation.
- Package and independently verify the mounted host-only DMG.
- Bind approval to the exact source, manifest, lock, app, package, attestation, and digests.
- Record one idempotent approval-history update for review and commit.
- Publish only after that history change is committed and `--publish` is supplied.
- Verify GitHub's normal release state, asset sizes, and downloaded digests.

## Public API / entry points

[release_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/d01539e88c39b72712395899fd206eee40509ab3/script/release_host.sh) is the owner-facing interface. It coordinates [build_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/build_host.sh), [smoke_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/smoke_host.sh), [test_focused_shell_rendered.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/test_focused_shell_rendered.sh), [verify_fast_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/verify_fast_release.sh), [package_host_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/package_host_release.sh), [verify_host_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/verify_host_release.sh), [approve_host_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/approve_host_release.sh), and [publish_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/publish_release.sh).

## Key files

- [script/lib/dist_checkpoint.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/lib/dist_checkpoint.sh) — full-lifetime kernel lease and recoverable staged promotion.
- [script/lib/host_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/lib/host_release.sh) — release contexts, copy checks, compatibility records, and metadata safety.
- [script/lib/approved_release_set.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/lib/approved_release_set.sh) — exact approval validation and safe history recording.
- [script/test_release_host_task.sh](https://github.com/alexwck/dbcode-wrapper/blob/d01539e88c39b72712395899fd206eee40509ab3/script/test_release_host_task.sh) — preparation order, exact resume, and explicit publication contracts.
- [script/test_build_host_task.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/test_build_host_task.sh) — signing, lease, concurrency, interruption, and promotion contracts.
- [host/approved-release-history.json](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/host/approved-release-history.json) — tracked approved history bundled with the wrapper.

## Dependencies

The task consumes [Release Source Snapshot](release-source-snapshot.md), [Compiled Host Cache](compiled-host-cache.md), [Approved Release Set](approved-release-set.md), [Verification Harness](verification-harness.md), the signed app, macOS packaging tools, Git, GitHub CLI, and [Generated Workspace Retention](generated-workspace-retention.md).

## Participates in

- [Package and publish a Host Release](../flows/package-and-publish-host-release.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)

## Related

- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)