---
title: Focused shell and wrapper extensions
description: The host UI and small first-party extensions that make Code OSS behave as a DBCode desktop application.
type: module
tags:
  - wiki
  - module
  - shell
  - extensions
wiki_profile: public
wiki_depth: standard
source_commit: efe247fc701a9b529e3e6368b6571a44541fc146
---
## Summary

The focused shell removes general IDE navigation and presents database work as the product's main workflow. It retains the Code OSS extension host because DBCode depends on it, then adds only three small wrapper-owned extensions for profile setup, Python-kernel bridging, and release status.

## Responsibilities

- Present Connections, SQL files, new queries, saved queries, and DBCode tools as the primary navigation.
- Keep DBCode's own editor, connection tree, grids, notebooks, exports, diagrams, history, and other database features available.
- Suppress general workbench surfaces that conflict with the standalone database-app goal.
- Provide profile setup and recovery without modifying DBCode.
- Bridge notebook kernel execution through an explicit host permission.
- Show installed and available upstream versions and link to official release notes.
- Avoid duplicate wrapper actions where DBCode already provides the better workflow.

## Public API / entry points

Most shell behavior is applied through the focused Code OSS patch. The first-party extensions register a narrow command surface under the `dbcodeWrapper` namespace. DBCode remains a separately installed upstream extension and owns its database commands and webviews.

## Key files

- [`200-final-focused-dbcode-shell.patch`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/patches/code-oss/200-final-focused-dbcode-shell.patch) — focused workbench UI.
- [`dbcode-wrapper-profile-migration`](https://github.com/alexwck/dbcode-wrapper/tree/efe247fc701a9b529e3e6368b6571a44541fc146/host/extensions/dbcode-wrapper-profile-migration) — setup, import, runtime installation, and recovery.
- [`dbcode-wrapper-python-kernel`](https://github.com/alexwck/dbcode-wrapper/tree/efe247fc701a9b529e3e6368b6571a44541fc146/host/extensions/dbcode-wrapper-python-kernel) — explicit notebook bridge.
- [`dbcode-wrapper-release-status`](https://github.com/alexwck/dbcode-wrapper/tree/efe247fc701a9b529e3e6368b6571a44541fc146/host/extensions/dbcode-wrapper-release-status) — update discovery and approved-set status.
- [`host/dbcode-feature-policy.json`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/dbcode-feature-policy.json) — tracked DBCode capability catalogue.

## Dependencies

The shell depends on the pinned Code OSS workbench structure and DBCode's public extension contributions. This is the most visually sensitive part of an upstream update, so rendered checks matter in addition to source contracts.

## Participates in

- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Trace a DBCode feature](../guides/trace-a-dbcode-feature.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)

## Related

- [Product and upstream boundaries](../architecture/product-and-upstream-boundaries.md)
- [Unmodified Extension Boundary](../concepts/unmodified-extension-boundary.md)
- [Verification Harness](verification-harness.md)
