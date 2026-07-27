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
source_commit: ea091613c180550d6e6df9120b2a9b4fe66ffcc2
---
## Summary

The focused shell removes general IDE navigation and makes DBCode the product surface. It retains the extension-host APIs DBCode needs and adds only narrow wrapper extensions for profile setup, the Python kernel bridge, and release status.

## Responsibilities

- Present Connections, Database Explorer, SQL files, queries, history, library, scratch files, notebooks, Query Builder, settings, AI, and MCP routes through the focused shell.
- Keep DBCode-owned editors, grids, context actions, diagrams, exports, and account surfaces available.
- Keep Database Explorer persistent during editor, canvas, grid, and Escape interactions.
- Dismiss other temporary DBCode drawers consistently when their owning interaction ends.
- Hide unrelated IDE surfaces and duplicate wrapper actions.
- Provide profile safety, kernel permission, and release status without modifying DBCode.
- Show prompt-prone AI, MCP, notebook, and account routes in smoke checks without activating them.

## Public API / entry points

Most shell behaviour comes from the focused Code OSS patch. Wrapper commands use the `dbcodeWrapper` namespace. DBCode remains a separately installed upstream extension and owns its commands, views, webviews, editors, AI providers, and MCP tools.

The approved DBCode `1.36.4` policy keeps capability status separate from evidence depth. Features exercised by the prompt-free gate carry their actual `declared`, `reachable`, or `rendered` evidence. Optional debugger and AI workflows that were not activated are marked limited instead of being treated as failed or falsely tested.

## Key files

- [`200-final-focused-dbcode-shell.patch`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/host/patches/code-oss/200-final-focused-dbcode-shell.patch) — focused workbench routing and dismissal behaviour.
- [`dbcode-wrapper-profile-migration`](https://github.com/alexwck/dbcode-wrapper/tree/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/host/extensions/dbcode-wrapper-profile-migration) — setup, import, runtime installation, and recovery.
- [`dbcode-wrapper-python-kernel`](https://github.com/alexwck/dbcode-wrapper/tree/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/host/extensions/dbcode-wrapper-python-kernel) — explicit notebook bridge.
- [`dbcode-wrapper-release-status`](https://github.com/alexwck/dbcode-wrapper/tree/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/host/extensions/dbcode-wrapper-release-status) — discovery and approved-set status.
- [`host/dbcode-feature-policy.json`](https://github.com/alexwck/dbcode-wrapper/blob/ea091613c180550d6e6df9120b2a9b4fe66ffcc2/host/dbcode-feature-policy.json) — DBCode capability and route policy.

## Dependencies

The shell depends on the pinned Code OSS workbench structure and DBCode's public contributions. Source contracts protect routing; the single persistent-profile rendered smoke protects real presentation.

## Participates in

- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Trace a DBCode feature](../guides/trace-a-dbcode-feature.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)

## Related

- [Product and upstream boundaries](../architecture/product-and-upstream-boundaries.md)
- [DBCode capability evidence](../concepts/dbcode-capability-evidence.md)
- [AI and MCP data boundaries](../concepts/ai-and-mcp-data-boundaries.md)
- [Verification Harness](verification-harness.md)