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
source_commit: f1cc5e1bbc50281cd6b86a307054982619ce5f00
---
## Summary

Release Source Snapshot makes each build start from one clean immutable Git commit. The launcher records the commit, tree, wrapper-source digest, and release-lock digest, then materializes that exact commit in a temporary checkout. Compilation, assembly, final verification, and Host Release packaging all use or verify the same record.

This prevents an uncommitted file or later working-tree edit from quietly changing the app after review. Materialization returns a normalized physical path, and callers use that path.

The wrapper-source digest includes production assembly adapters that can change signed app bytes, including the Runtime Extension Set. Test-only helpers are outside that identity.

## Responsibilities

- Resolve a release ref to one Git commit and tree.
- Refuse dirty source when the selected release commit is the current checkout.
- Record the release-lock digest and host-and-script input digest.
- Include every production assembly adapter that can change the signed app, and exclude test-only helpers.
- Materialize the exact commit in a narrow temporary directory.
- Recheck the record before and after expensive build stages.
- Bind the snapshot to the signed manifest, acceptance report, source tag, and Host Release.

## Flow

```mermaid
flowchart LR
  R[Release ref] --> S[Snapshot record]
  S --> M[Materialized checkout]
  M --> B[Compile or reuse host]
  B --> A[Assemble and sign]
  A --> V[Exact source verification]
  V --> P[Host Release]
```

## Public API / entry points

[build_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/build_host.sh) creates and materializes the record before assembly. [release_source_snapshot.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/release_source_snapshot.sh) exposes the task-level record command.

## Key files

- [script/lib/release_source_snapshot.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/lib/release_source_snapshot.sh) — record, verification, and materialization logic.
- [script/lib/source_digest.sh](https://github.com/alexwck/dbcode-wrapper/blob/03c571b8056a0ce65cab3779ae2d231e8820563c/script/lib/source_digest.sh) — exact production wrapper and assembly-adapter input set.
- [script/test_release_source_snapshot_contract.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/test_release_source_snapshot_contract.sh) — clean-source, path, and tamper checks.
- [script/generate_manifest.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/generate_manifest.sh) — copies the verified snapshot into the signed build manifest.

## Dependencies

The module depends on Git, [Release Specification](release-specification.md), and narrow temporary paths. It feeds [Compiled Host Cache](compiled-host-cache.md), [Approved Release Set](approved-release-set.md), and [Host Release](host-release.md).

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)
- [Package and publish a Host Release](../flows/package-and-publish-host-release.md)

## Related

- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Patch Plan and build](patch-plan-and-build.md)
- [Verification Harness](verification-harness.md)
