---
title: Trace a DBCode feature
description: A practical method for finding DBCode feature ownership, route, evidence level, and privacy boundary.
type: guide
tags:
  - wiki
  - guide
  - dbcode
  - debugging
wiki_profile: public
wiki_depth: standard
source_commit: 2008ff48373c1aac378d0d1ec903e96a88ec1e29
---
## Goal

Find the real owner, route, evidence level, and data boundary of a DBCode feature before changing the wrapper. This avoids deleting upstream capability, duplicating DBCode, or claiming more proof than exists.

## Steps

1. **Name the user action.** State what the person opens, what input it needs, and what success looks like.
2. **Check official orientation.** Find the feature family in [`docs/product/dbcode-capability-coverage.md`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/docs/product/dbcode-capability-coverage.md).
3. **Check maintained policy.** Find its group, route, evidence, and limit in [`host/dbcode-feature-policy.json`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/dbcode-feature-policy.json).
4. **Inspect public package contributions locally.** Check the exact installed package manifest for commands, views, editors, menus, settings, and tools. Do not publish the package or proprietary code.
5. **Trace shell routing.** Search the focused patch and wrapper manifests for the contribution ID.
6. **Name the owner.** Classify it as DBCode-owned, host-owned, or wrapper-owned.
7. **Keep one working route.** Remove only a duplicate or proven-broken wrapper route, never the last DBCode-owned route.
8. **Choose the evidence level.** Use `declared`, `reachable`, `rendered`, or `live` precisely.
9. **Check privacy and mutation.** For AI, Copilot, MCP, query execution, data copy, DML, DDL, or workspace writes, identify the payload and require explicit user action where needed.
10. **Recheck breadth.** Do not turn representative fixtures into a database allowlist.

## Relevant code

- [Focused shell and wrapper extensions](../modules/focused-shell-extensions.md)
- [DBCode capability evidence](../concepts/dbcode-capability-evidence.md)
- [AI and MCP data boundaries](../concepts/ai-and-mcp-data-boundaries.md)
- [`script/test_dbcode_feature_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/test_dbcode_feature_contract.sh)
- [`script/test_focused_shell_rendered.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/test_focused_shell_rendered.sh)

## Gotchas

- A declared command can still fail to register on a host version.
- A visible settings route does not prove inline completion, Query Builder AI, Grid AI, Explore AI, or plan analysis.
- Automatic MCP registration does not prove the optional HTTP MCP server.
- A hidden Code OSS surface may remain reachable through a context menu or shortcut.
- A DBCode result grid should not be duplicated with a generic wrapper Results pane.

## Related

- [Unmodified Extension Boundary](../concepts/unmodified-extension-boundary.md)
- [Representative acceptance fixtures](../concepts/representative-acceptance-fixtures.md)
- [Choose a verification level](choose-a-verification-level.md)