---
title: Patch Plan and build
description: The immutable-source build, staged assembly, and safe checkpoint pipeline.
type: module
tags:
  - wiki
  - module
  - build
  - patches
wiki_profile: public
wiki_depth: standard
source_commit: 2191402c377a4caa9c941af83c6cbcf6c0d41809
---
## Summary

The build does not keep a permanent upstream fork. It materializes one clean wrapper commit, applies small ordered patches to pinned upstream files, copies wrapper-owned focused-shell source, verifies the prepared tree, compiles Code OSS only when compilation inputs changed, then assembles and signs a fresh host.

A standalone build checks the existing signing identity before assembly. It holds one kernel-backed `dist/` lease, creates the complete app and manifest at a fixed private candidate path, and promotes them together. If work stops halfway through, a fixed previous path lets the next owner restore or retain the last complete checkpoint.

## Responsibilities

- Check signing readiness without changing trust or asking for input.
- Materialize one clean [Release Source Snapshot](release-source-snapshot.md).
- Declare every VSCodium patch, Code OSS patch, and first-class overlay in one ordered plan.
- Refuse unsafe, linked, missing, changed, or already-present overlay targets.
- Verify the prepared Code OSS tree before compilation.
- Reuse only a verified [Compiled Host Cache](compiled-host-cache.md) entry.
- Generate wrapper extensions, profile identity, runtime records, and release status after compilation.
- Sign the staged app and write its exact manifest before changing `dist/`.
- Keep the previous complete checkpoint recoverable across failure, signal, or abrupt parent exit.

## Public API / entry points

[build_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/build_host.sh) owns standalone build preparation and immutable-source materialization. [assemble_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/assemble_host.sh) reuses or creates the compiled host and promotes one complete checkpoint. [compile_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/compile_host.sh) gives VSCodium the Patch Plan, overlay materializer, and prepared-tree verifier.

## Key files

- [script/lib/dist_checkpoint.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/lib/dist_checkpoint.sh) — kernel lease plus fixed candidate and previous checkpoint recovery.
- [patch-plan.json](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/host/patches/patch-plan.json) — ordered patches, overlay files, and expected maintained-tree digest.
- [host/code-oss-overlay](https://github.com/alexwck/dbcode-wrapper/tree/2191402c377a4caa9c941af83c6cbcf6c0d41809/host/code-oss-overlay) — wrapper-owned Code OSS source files.
- [host/patches/code-oss](https://github.com/alexwck/dbcode-wrapper/tree/2191402c377a4caa9c941af83c6cbcf6c0d41809/host/patches/code-oss) — small runtime integration patches.
- [host/patches/vscodium](https://github.com/alexwck/dbcode-wrapper/tree/2191402c377a4caa9c941af83c6cbcf6c0d41809/host/patches/vscodium) — build-repository patches and the materialize-then-verify hook.
- [script/test_build_host_task.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/test_build_host_task.sh) — owner-task failure, concurrency, and recovery coverage.
- [slimming-policy.json](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/host/slimming-policy.json) — active size goals, build choices, and rollback.

## Dependencies

The pipeline consumes [Release Specification](release-specification.md), [Release Source Snapshot](release-source-snapshot.md), [Compiled Host Cache](compiled-host-cache.md), [Profile Layout and Setup](profile-layout-and-setup.md), [Generated Workspace Retention](generated-workspace-retention.md), pinned upstream sources, and the pinned toolchain.

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Package and publish a Host Release](../flows/package-and-publish-host-release.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)

## Related

- [Product and upstream boundaries](../architecture/product-and-upstream-boundaries.md)
- [Focused shell and wrapper extensions](focused-shell-extensions.md)
- [Verification Harness](verification-harness.md)