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
source_commit: ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1
---
## Summary

The build does not keep a permanent upstream fork. It materializes one clean wrapper commit, applies a small ordered patch plan to pinned upstream sources, compiles Code OSS only when compilation inputs changed, then assembles and signs a fresh DBCode Wrapper release.

Compilation and assembly have different identity inputs. Query storage values are compiled into the host. Profile-only folders and schema are generated during assembly, so they do not force a Code OSS rebuild.

## Responsibilities

- Declare every VSCodium and Code OSS patch in one ordered plan with an exact digest.
- Validate each patch and its intended source layer.
- Apply identity, macOS packaging, focused-shell, slimming, and profile/release integration changes.
- Build only the required macOS desktop target.
- Reuse only a verified [Compiled Host Cache](compiled-host-cache.md) entry.
- Copy wrapper extensions and generate profile, runtime, and release-status records after compilation.
- Sign the assembled app and generate the exact manifest.

## Public API / entry points

[`build_host.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/script/build_host.sh) is the public build entry point. It creates a [Release Source Snapshot](release-source-snapshot.md) and runs [`assemble_host.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/script/assemble_host.sh) inside the materialized source. Assembly calls [`compile_host.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/script/compile_host.sh) only on a cache miss, then runs [`generate_profile_identity.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/script/generate_profile_identity.sh) before signing.

## Key files

- [`host/patches/patch-plan.json`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/patches/patch-plan.json) — ordered patch inventory and exact digests.
- [`host/patches/code-oss`](https://github.com/alexwck/dbcode-wrapper/tree/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/patches/code-oss) — runtime and focused-shell patches.
- [`host/patches/vscodium`](https://github.com/alexwck/dbcode-wrapper/tree/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/patches/vscodium) — build-repository patches.
- [`host/slimming-policy.json`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/slimming-policy.json) — kept and removed host capabilities.

## Dependencies

The pipeline consumes [Release Specification](release-specification.md), [Release Source Snapshot](release-source-snapshot.md), [Compiled Host Cache](compiled-host-cache.md), [Profile Layout and Setup](profile-layout-and-setup.md), [Generated Workspace Retention](generated-workspace-retention.md), pinned upstream sources, and the pinned toolchain.

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)

## Related

- [Product and upstream boundaries](../architecture/product-and-upstream-boundaries.md)
- [Focused shell and wrapper extensions](focused-shell-extensions.md)
- [Verification Harness](verification-harness.md)