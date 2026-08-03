---
title: Focused shell and wrapper extensions
description: The small host surface that presents unmodified DBCode as a standalone app.
type: module
tags:
  - wiki
  - module
  - shell
  - extensions
wiki_profile: public
wiki_depth: standard
source_commit: 187fa2bf6982b805c49a456a03d6b305a57a56a0
---
## Summary

The focused shell removes general IDE navigation and makes DBCode the product surface. It keeps the extension-host APIs DBCode needs and adds only small wrapper extensions for profile setup, the Python kernel bridge, release status, and an explicit local BSON result viewer.

DBCode stays unmodified. The wrapper does not recreate its database, notebook, AI, MCP, account, or licence features. DBCode attaches Python cells to an already running Jupyter kernel, so the wrapper keeps one explicit Start Python Kernel bridge instead of duplicating the notebook. Wrapper-owned shell TypeScript and CSS live as normal source files; the patch stack contains only the smaller changes to existing Code OSS files.

## Responsibilities

- Present Connections, Database Explorer, SQL files, queries, history, library, scratch files, notebooks, Query Builder, settings, AI, and MCP routes.
- Keep DBCode-owned editors, grids, actions, diagrams, exports, and account surfaces available.
- Open DBCode's own result editor below each query at every window width through its public result-location preference.
- Offer an explicit clipboard or file handoff to a local BSON viewer with Tree, Table, and Raw JSON views, readable values, separate types, and opt-in parsing of embedded JSON strings. The viewer does not access a database, DBCode internals, the network, or persistent storage.
- Keep every DBCode-owned side drawer open during editor, canvas, grid, and Escape interactions. Account remains temporary. One toolbar control collapses the current drawer and restores the last persistent drawer.
- Open file-backed scratch queries in the generated query folder without overwriting existing files.
- Hide unrelated IDE surfaces and duplicate wrapper actions.
- Provide profile safety, explicit user-started Python kernel setup, and release status around DBCode.
- Poll official Code OSS, VSCodium, and DBCode metadata automatically while keeping review actions read-only.
- Show prompt-prone routes in rendered checks without activating them.

## Public API / entry points

The Patch Plan materializes the maintained focused-shell TypeScript and CSS into the pinned Code OSS tree. Small patches register that contribution and connect it to existing title bars and workbench startup. Wrapper commands use the `dbcodeWrapper` namespace. DBCode remains a separately acquired upstream extension and owns its commands, views, webviews, editors, providers, and tools.

The release-status extension imports three official metadata URLs and one status service. The service owns polling, cache, review decisions, and release-set matching behind a small maintained interface. Internal comparison and normalization helpers stay private.

The BSON viewer registers `dbcodeWrapper.openBsonResultFromClipboard` and `dbcodeWrapper.openBsonResultFromFile`. The focused DBCode Tools menu exposes both routes, and macOS also maps Command-Option-J to the explicit clipboard route.

The feature policy keeps capability status separate from evidence depth. A feature may be `declared`, `reachable`, `rendered`, or `live`. Optional AI, MCP, debugger, account, and notebook workflows keep honest limited evidence when the prompt-free gate does not activate them.

## Key files

- [dbcodeWrapper.contribution.ts](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/code-oss-overlay/src/vs/workbench/contrib/dbcodeWrapper/browser/dbcodeWrapper.contribution.ts) — focused workbench routing, query storage, result placement, drawer state, and wrapper commands.
- [dbcodeWrapper.css](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/code-oss-overlay/src/vs/workbench/contrib/dbcodeWrapper/browser/media/dbcodeWrapper.css) — focused workbench presentation.
- [200-final-focused-dbcode-shell.patch](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/patches/code-oss/200-final-focused-dbcode-shell.patch) — small hooks into existing Code OSS files.
- [dbcode-wrapper-profile-migration](https://github.com/alexwck/dbcode-wrapper/tree/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/extensions/dbcode-wrapper-profile-migration) — runtime setup, profile setup, safe import, and recovery.
- [dbcode-wrapper-python-kernel](https://github.com/alexwck/dbcode-wrapper/tree/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/extensions/dbcode-wrapper-python-kernel) — explicit notebook bridge.
- [dbcode-wrapper-release-status](https://github.com/alexwck/dbcode-wrapper/tree/b3773b5ad1f3f3b0bcd3d7dce39f614bf082ce11/host/extensions/dbcode-wrapper-release-status) — official update discovery and read-only review UI.
- [dbcode-wrapper-bson-viewer](https://github.com/alexwck/dbcode-wrapper/tree/187fa2bf6982b805c49a456a03d6b305a57a56a0/host/extensions/dbcode-wrapper-bson-viewer) — bounded Extended JSON parsing and local Tree, Table, and Raw JSON presentation.
- [dbcode-feature-policy.json](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/dbcode-feature-policy.json) — capability and route policy.

## Dependencies

The shell depends on the pinned Code OSS workbench structure, generated product identity, [Patch Plan and build](patch-plan-and-build.md), and DBCode's public contributions. Source contracts protect routing and the generated BSON webview handshake; one persistent-profile rendered check protects real presentation with a synthetic BSON fixture.

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