---
title: Focused shell and wrapper extensions
description: The host UI and small wrapper extensions that present DBCode as a standalone database application.
type: module
tags:
  - wiki
  - module
  - shell
  - extensions
wiki_profile: public
wiki_depth: standard
source_commit: ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1
---
## Summary

The focused shell removes general IDE navigation and makes DBCode the product surface. It retains the extension-host APIs DBCode needs and adds only narrow wrapper extensions for profile setup, the Python kernel bridge, and release status.

Query storage is part of the product identity. The shell reads the storage namespace and query folder generated from [Release Specification](release-specification.md). It fails when either value is missing instead of falling back to another hard-coded path.

## Responsibilities

- Present Connections, Database Explorer, SQL files, queries, history, library, scratch files, notebooks, Query Builder, settings, AI, and MCP routes through the focused shell.
- Keep DBCode-owned editors, grids, context actions, diagrams, exports, and account surfaces available.
- Keep Database Explorer persistent during editor, canvas, grid, and Escape interactions.
- Dismiss other temporary DBCode drawers consistently when their owning interaction ends.
- Open a file-backed scratch query in the Release Specification's query folder without overwriting it.
- Hide unrelated IDE surfaces and duplicate wrapper actions.
- Provide profile safety, kernel permission, and release status without modifying DBCode.
- Show prompt-prone AI, MCP, notebook, and account routes in smoke checks without activating them.

## Public API / entry points

Most shell behaviour comes from the focused Code OSS patch. VSCodium product preparation writes the validated wrapper identity into `product.json`. Wrapper commands use the `dbcodeWrapper` namespace. DBCode remains a separately installed upstream extension and owns its commands, views, webviews, editors, AI providers, and MCP tools.

The approved DBCode `1.36.4` policy keeps capability status separate from evidence depth. Features exercised by the prompt-free gate carry their actual `declared`, `reachable`, or `rendered` evidence. Optional debugger and AI workflows that were not activated are marked limited instead of being treated as failed or falsely tested.

## Key files

- [`200-final-focused-dbcode-shell.patch`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/patches/code-oss/200-final-focused-dbcode-shell.patch) — focused workbench routing, generated query storage, and dismissal behaviour.
- [`0001-dbcode-wrapper-identity.patch`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/patches/vscodium/0001-dbcode-wrapper-identity.patch) — product identity injection.
- [`dbcode-wrapper-profile-migration`](https://github.com/alexwck/dbcode-wrapper/tree/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/extensions/dbcode-wrapper-profile-migration) — setup, import, generated profile identity, runtime installation, and recovery.
- [`dbcode-wrapper-python-kernel`](https://github.com/alexwck/dbcode-wrapper/tree/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/extensions/dbcode-wrapper-python-kernel) — explicit notebook bridge.
- [`dbcode-wrapper-release-status`](https://github.com/alexwck/dbcode-wrapper/tree/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/extensions/dbcode-wrapper-release-status) — discovery and approved-set status.
- [`host/dbcode-feature-policy.json`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/dbcode-feature-policy.json) — DBCode capability and route policy.

## Dependencies

The shell depends on the pinned Code OSS workbench structure, generated product identity, and DBCode's public contributions. Source contracts protect routing; the single persistent-profile rendered smoke protects real presentation.

## Participates in

- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Trace a DBCode feature](../guides/trace-a-dbcode-feature.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)

## Related

- [Product and upstream boundaries](../architecture/product-and-upstream-boundaries.md)
- [Profile Layout and Setup](profile-layout-and-setup.md)
- [DBCode capability evidence](../concepts/dbcode-capability-evidence.md)
- [AI and MCP data boundaries](../concepts/ai-and-mcp-data-boundaries.md)
- [Verification Harness](verification-harness.md)