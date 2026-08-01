---
title: Compiled Host Cache
description: The content-addressed cache that reuses unchanged Code OSS compilation across wrapper releases.
type: module
tags:
  - wiki
  - module
  - build
  - cache
wiki_profile: public
wiki_depth: standard
source_commit: b9d88955e313bff25e2abb14d96fc986e80e7f7a
---
## Summary

Compiled Host Cache separates expensive Code OSS compilation from smaller release assembly. It gives the exact compilation inputs a content-addressed ID, verifies cached app bytes, file modes, and symbolic links, and records the compiler environment in a receipt.

The key distinguishes profile-only identity from values compiled into the host. User-data, extension, backup-folder, profile-schema, and dated slimming-evidence changes can reuse the host. Query storage invalidates it because the focused shell reads that value from the compiled product record. Changes to the active Release Specification projection also invalidate the cache deliberately.

## Responsibilities

- Hash upstream revisions, toolchain pins, compile-time product values, the first-class Code OSS overlay, small patches, icon, active slimming policy, compilation code, and Git's regular-or-executable file state.
- Exclude DBCode packages, profile-only names, profile schema, documentation, tests, dated measurements, and assembly-only files from the compilation ID.
- Include query-storage names and other values embedded in the Code OSS or VSCodium output.
- Publish a compiled app and environment receipt atomically.
- Verify the cached app digest, file modes, links, identity, and receipt before reuse.
- Preserve an invalid existing entry for investigation, then rebuild it.
- Report `hit` or `miss-built` in the final manifest.

## Flow

```mermaid
flowchart LR
  I[Compilation inputs] --> D[Compiled Host input ID]
  D --> C{Valid cache entry}
  C -->|yes| H[Reuse host]
  C -->|no| B[Compile once]
  B --> P[Publish verified entry]
  P --> H
  H --> A[Assemble release]
```

## Public API / entry points

[compile_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/script/compile_host.sh) prepares and compiles the upstream host. [assemble_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/script/assemble_host.sh) resolves or creates the cache entry, then copies it into the release bundle before assembly and signing.

## Key files

- [compiled_host_cache.sh](https://github.com/alexwck/dbcode-wrapper/blob/b9d88955e313bff25e2abb14d96fc986e80e7f7a/script/lib/compiled_host_cache.sh) — input ID, normalized source modes, active projection digest, receipt, integrity, resolution, and publication.
- [patch-plan.json](https://github.com/alexwck/dbcode-wrapper/blob/b9d88955e313bff25e2abb14d96fc986e80e7f7a/host/patches/patch-plan.json) — patch and first-class overlay identity.
- [release_specification_records.jq](https://github.com/alexwck/dbcode-wrapper/blob/b9d88955e313bff25e2abb14d96fc986e80e7f7a/script/lib/release_specification_records.jq) — the active compile-time product projection.
- [test_compiled_host_cache_contract.sh](https://github.com/alexwck/dbcode-wrapper/blob/b9d88955e313bff25e2abb14d96fc986e80e7f7a/script/test_compiled_host_cache_contract.sh) — reuse, invalidation, permission, tamper, and path checks.

## Dependencies

The cache consumes a verified [Release Source Snapshot](release-source-snapshot.md), [Release Specification](release-specification.md), [Patch Plan and build](patch-plan-and-build.md), active slimming policy, and the pinned toolchain. Its ignored entries are protected reusable output under [Generated Workspace Retention](generated-workspace-retention.md).

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)

## Related

- [Profile Layout and Setup](profile-layout-and-setup.md)
- [Verification Harness](verification-harness.md)
- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)