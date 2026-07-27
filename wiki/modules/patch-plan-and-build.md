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
source_commit: 2008ff48373c1aac378d0d1ec903e96a88ec1e29
---
## Summary

The build does not keep a permanent fork of the upstream tree. It materializes one clean wrapper commit, applies a small ordered patch plan to pinned upstream sources, compiles Code OSS only when compilation inputs changed, then assembles and signs a fresh DBCode Wrapper release.

## Responsibilities

- Declare every VSCodium and Code OSS patch in one ordered plan.
- Validate each patch and its intended source layer.
- Apply identity, macOS packaging, focused-shell, slimming, and profile/release integration changes.
- Build only the required macOS desktop target.
- Separate expensive compilation from wrapper extension and release-record assembly.
- Reuse only a verified [Compiled Host Cache](compiled-host-cache.md) entry.
- Copy wrapper extensions and generate runtime and release records after compilation.
- Sign the assembled app and generate the exact manifest.

## Public API / entry points

[`build_host.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/build_host.sh) is the public build entry point. It creates a [Release Source Snapshot](release-source-snapshot.md) and runs [`assemble_host.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/assemble_host.sh) inside the materialized source. Assembly calls [`compile_host.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/compile_host.sh) only on a cache miss.

## Key files

- [`host/patches/patch-plan.json`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/patches/patch-plan.json) — ordered patch inventory.
- [`host/patches/code-oss`](https://github.com/alexwck/dbcode-wrapper/tree/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/patches/code-oss) — runtime and focused-shell patches.
- [`host/patches/vscodium`](https://github.com/alexwck/dbcode-wrapper/tree/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/patches/vscodium) — build-repository patches.
- [`host/slimming-policy.json`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/slimming-policy.json) — kept and removed host capabilities.

## Dependencies

The pipeline consumes [Release Specification](release-specification.md), [Release Source Snapshot](release-source-snapshot.md), [Compiled Host Cache](compiled-host-cache.md), [Generated Workspace Retention](generated-workspace-retention.md), pinned upstream sources, and the pinned toolchain.

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)

## Related

- [Product and upstream boundaries](../architecture/product-and-upstream-boundaries.md)
- [Focused shell and wrapper extensions](focused-shell-extensions.md)
- [Verification Harness](verification-harness.md)