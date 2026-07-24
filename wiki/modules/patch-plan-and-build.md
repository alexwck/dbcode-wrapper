---
title: Patch Plan and build
description: The ordered patch contract and build pipeline that turn pinned VSCodium and Code OSS sources into DBCode Wrapper.
type: module
tags:
  - wiki
  - module
  - build
  - patches
wiki_profile: public
wiki_depth: standard
source_commit: efe247fc701a9b529e3e6368b6571a44541fc146
---
## Summary

The build does not maintain a permanent fork of the full upstream tree. It checks out pinned upstream sources, applies a small ordered patch plan, configures slimming, copies first-party wrapper extensions, writes generated release records, and produces the macOS app bundle.

## Responsibilities

- Declare every VSCodium and Code OSS patch in one ordered plan.
- Validate patch files and their intended source layer before application.
- Apply product identity, macOS packaging, focused-shell, slimming, and release/profile integration changes.
- Set the built-in extension allowlist from the slimming policy.
- Copy wrapper-owned extensions into the host.
- Generate runtime package and release-status data from the canonical release specification.
- Build only the required desktop target, excluding server, remote, and tunnel products that are outside the app goal.

## Public API / entry points

[`patch_plan.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/lib/patch_plan.sh) is the shared plan reader and validator. [`build_host.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/build_host.sh) is the build entry point.

## Key files

- [`host/patches/patch-plan.json`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/patches/patch-plan.json) — ordered patch inventory.
- [`host/patches/vscodium`](https://github.com/alexwck/dbcode-wrapper/tree/efe247fc701a9b529e3e6368b6571a44541fc146/host/patches/vscodium) — build-repository patches.
- [`host/patches/code-oss`](https://github.com/alexwck/dbcode-wrapper/tree/efe247fc701a9b529e3e6368b6571a44541fc146/host/patches/code-oss) — runtime and focused-shell patches.
- [`host/slimming-policy.json`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/slimming-policy.json) — kept and removed host capabilities.

## Dependencies

The build consumes [Release Specification](release-specification.md), the upstream source checkouts, VSCodium's build tooling, the wrapper icon and entitlements, and first-party extensions. Signing and release packaging are later stages.

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)

## Related

- [Product and upstream boundaries](../architecture/product-and-upstream-boundaries.md)
- [Focused shell extensions](focused-shell-extensions.md)
- [Verification Harness](verification-harness.md)
