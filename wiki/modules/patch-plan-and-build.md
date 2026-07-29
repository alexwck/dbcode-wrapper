---
title: Patch Plan and build
description: The ordered patch, source-overlay, compilation, and assembly pipeline that produces DBCode Wrapper.
type: module
tags:
  - wiki
  - module
  - build
  - patches
wiki_profile: public
wiki_depth: standard
source_commit: 5f77cbeeb00b79432ca86b95b0d392d68f0d1d27
---
## Summary

The build does not keep a permanent upstream fork. It materializes one clean wrapper commit, applies small ordered patches to pinned upstream files, copies wrapper-owned focused-shell TypeScript and CSS from first-class source, verifies the prepared tree, compiles Code OSS only when compilation inputs changed, then assembles and signs a fresh release.

Fast source checks validate the plan without depending on a stale generated checkout. On a cold build, VSCodium applies official and wrapper patches, materializes the source overlay, and verifies the approved Code OSS tree before compilation starts.

## Responsibilities

- Declare every VSCodium and Code OSS patch in one ordered plan with an exact digest.
- Declare every first-class overlay source, target path, and digest in the same plan.
- Keep small changes to existing upstream files as patches and wrapper-owned new files as normal source.
- Refuse unsafe, linked, missing, changed, or already-present overlay targets.
- Remove temporary patch indexes after success, failure, interruption, and signals.
- Refuse compilation when the prepared Code OSS tree differs from the approved semantic result.
- Reuse only a verified [Compiled Host Cache](compiled-host-cache.md) entry.
- Copy wrapper extensions and generate profile, runtime, and release-status records after compilation.
- Sign the assembled app and generate the exact manifest.

## Public API / entry points

[build_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/script/build_host.sh) creates a [Release Source Snapshot](release-source-snapshot.md) and runs assembly inside the materialized source. [compile_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/script/compile_host.sh) gives VSCodium the Patch Plan, materializer, and verifier. [materialize_code_oss_overlay.sh](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/script/materialize_code_oss_overlay.sh) copies the approved first-class files. [verify_prepared_patch_tree.sh](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/script/verify_prepared_patch_tree.sh) checks the prepared tree before compilation.

## Key files

- [patch-plan.json](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/patches/patch-plan.json) — ordered patches, overlay files, and expected maintained-tree digest.
- [host/code-oss-overlay](https://github.com/alexwck/dbcode-wrapper/tree/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/code-oss-overlay) — wrapper-owned Code OSS source files.
- [host/patches/code-oss](https://github.com/alexwck/dbcode-wrapper/tree/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/patches/code-oss) — small runtime integration patches.
- [host/patches/vscodium](https://github.com/alexwck/dbcode-wrapper/tree/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/patches/vscodium) — build-repository patches and the materialize-then-verify hook.
- [test_patch_plan.sh](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/script/test_patch_plan.sh) — order, digest, path, materialization, tree, and temporary cleanup contracts.
- [slimming-policy.json](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/slimming-policy.json) — active size goals, build choices, and rollback.
- [dated slimming measurement](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/docs/architecture/host-slimming-measurement-2026-07-21.md) — historical size and startup evidence that does not change build identity.

## Dependencies

The pipeline consumes [Release Specification](release-specification.md), [Release Source Snapshot](release-source-snapshot.md), [Compiled Host Cache](compiled-host-cache.md), [Profile Layout and Setup](profile-layout-and-setup.md), [Generated Workspace Retention](generated-workspace-retention.md), pinned upstream sources, and the pinned toolchain.

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)

## Related

- [Product and upstream boundaries](../architecture/product-and-upstream-boundaries.md)
- [Focused shell and wrapper extensions](focused-shell-extensions.md)
- [Verification Harness](verification-harness.md)