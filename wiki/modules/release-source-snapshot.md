---
title: Release Source Snapshot
description: The immutable Git source record that binds each release build to one clean reviewed commit.
type: module
tags:
  - wiki
  - module
  - release
  - source
wiki_profile: public
wiki_depth: standard
source_commit: f18e06ebeffa3620c76d5da3ca36ffc1697f7d9f
---
## Summary

Release Source Snapshot makes each build start from one clean immutable Git commit. The launcher records the commit, tree, wrapper-source digest, and release-lock digest, then materializes that exact commit in a temporary checkout. Compilation, assembly, final verification, and private packaging all use or verify the same record.

This prevents an uncommitted file or a later working-tree edit from quietly changing the app after review. Materialization returns the checkout's normalized physical path, and callers use that value so macOS path aliases cannot split one source identity into two strings.

## Responsibilities

- Resolve a release ref to one Git commit and tree.
- Refuse dirty source when the selected release commit is the current checkout.
- Record the release-lock digest and the digest of host and script inputs.
- Materialize the exact commit in a narrow temporary directory and return its normalized absolute path.
- Recheck the record before and after expensive build stages.
- Bind the snapshot to the signed manifest, acceptance report, source tag, and private package.

## Flow

```mermaid
flowchart LR
  R[Release ref] --> S[Snapshot record]
  S --> M[Materialized checkout]
  M --> B[Compile or reuse host]
  B --> A[Assemble and sign]
  A --> V[Exact-source verification]
  V --> P[Private package]
```

## Public API / entry points

[`build_host.sh`](https://github.com/alexwck/dbcode-wrapper/blob/f18e06ebeffa3620c76d5da3ca36ffc1697f7d9f/script/build_host.sh) creates and materializes the record before it delegates to assembly. [`release_source_snapshot.sh`](https://github.com/alexwck/dbcode-wrapper/blob/f18e06ebeffa3620c76d5da3ca36ffc1697f7d9f/script/release_source_snapshot.sh) exposes the task-level record command.

## Key files

- [`script/lib/release_source_snapshot.sh`](https://github.com/alexwck/dbcode-wrapper/blob/f18e06ebeffa3620c76d5da3ca36ffc1697f7d9f/script/lib/release_source_snapshot.sh) — record, verification, digest, and normalized materialization logic.
- [`script/test_release_source_snapshot_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/f18e06ebeffa3620c76d5da3ca36ffc1697f7d9f/script/test_release_source_snapshot_contract.sh) — clean-source, normalized path, and tamper checks.
- [`script/generate_manifest.sh`](https://github.com/alexwck/dbcode-wrapper/blob/f18e06ebeffa3620c76d5da3ca36ffc1697f7d9f/script/generate_manifest.sh) — copies the verified snapshot into the signed build manifest.

## Dependencies

The module depends on Git, the canonical [Release Specification](release-specification.md), and narrow temporary paths. It feeds the [Compiled Host Cache](compiled-host-cache.md), [Approved Release Set](approved-release-set.md), and [Private Personal Release](private-personal-release.md).

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Controlled upgrade and rollback](../flows/controlled-upgrade-and-rollback.md)
- [Package and transfer a private release](../flows/package-and-transfer-private-release.md)

## Related

- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Patch Plan and build](patch-plan-and-build.md)
- [Verification Harness](verification-harness.md)