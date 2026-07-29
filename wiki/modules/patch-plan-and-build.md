---
title: Patch Plan and build
description: The ordered patch, compilation, and assembly pipeline that produces DBCode Wrapper.
type: module
tags:
  - wiki
  - module
  - build
  - patches
wiki_profile: public
wiki_depth: standard
source_commit: e02160a3b5363fc4e91c5282f7818ed908624c6d
---
## Summary

The build does not keep a permanent upstream fork. It materializes one clean wrapper commit, applies a small ordered patch plan to pinned upstream sources, compiles Code OSS only when compilation inputs changed, then assembles and signs a fresh DBCode Wrapper release.

Fast source checks validate the maintained patch plan without depending on a stale generated checkout. The real compile step checks the applied Code OSS tree immediately before it calls the upstream build.

## Responsibilities

- Declare every VSCodium and Code OSS patch in one ordered plan with an exact digest.
- Validate each patch and its intended source layer.
- Apply identity, macOS packaging, focused-shell, slimming, and profile/release integration changes.
- Keep unrelated source checks independent of ignored `.build/work` output.
- Refuse compilation when the prepared Code OSS tree differs from the approved semantic result.
- Reuse only a verified [Compiled Host Cache](compiled-host-cache.md) entry.
- Copy wrapper extensions and generate profile, runtime, and release-status records after compilation.
- Sign the assembled app and generate the exact manifest.

## Public API / entry points

[build_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/build_host.sh) creates a [Release Source Snapshot](release-source-snapshot.md) and runs assembly inside the materialized source. [compile_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/compile_host.sh) verifies the applied tree before compilation. [assemble_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/assemble_host.sh) adds release-specific records and signs the final app.

## Key files

- [host/patches/patch-plan.json](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/host/patches/patch-plan.json) — ordered patch inventory and expected maintained-tree digest.
- [host/patches/code-oss](https://github.com/alexwck/dbcode-wrapper/tree/e02160a3b5363fc4e91c5282f7818ed908624c6d/host/patches/code-oss) — runtime and focused-shell patches.
- [host/patches/vscodium](https://github.com/alexwck/dbcode-wrapper/tree/e02160a3b5363fc4e91c5282f7818ed908624c6d/host/patches/vscodium) — build-repository patches.
- [script/test_patch_plan.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/test_patch_plan.sh) — plan and compile-boundary contracts.
- [host/slimming-policy.json](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/host/slimming-policy.json) — kept and removed host capabilities.

## Dependencies

The pipeline consumes [Release Specification](release-specification.md), [Release Source Snapshot](release-source-snapshot.md), [Compiled Host Cache](compiled-host-cache.md), [Profile Layout and Setup](profile-layout-and-setup.md), [Generated Workspace Retention](generated-workspace-retention.md), pinned upstream sources, and the pinned toolchain.

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)

## Related

- [Product and upstream boundaries](../architecture/product-and-upstream-boundaries.md)
- [Focused shell and wrapper extensions](focused-shell-extensions.md)
- [Verification Harness](verification-harness.md)
