---
title: Trace a DBCode feature
description: A practical method for finding whether a visible database feature belongs to DBCode, the focused host, or wrapper integration.
type: guide
tags:
  - wiki
  - guide
  - dbcode
  - debugging
wiki_profile: public
wiki_depth: standard
source_commit: efe247fc701a9b529e3e6368b6571a44541fc146
---
## Goal

Find the real owner and integration path of a visible DBCode feature before changing the wrapper. This avoids removing an upstream capability, duplicating DBCode behavior, or patching the wrong layer.

## Steps

1. **Name the user action.** Describe what the owner clicks, what data it needs, and what successful output looks like. Avoid vague names such as “the results panel.”
2. **Check the capability policy.** Find the feature or its section in [`host/dbcode-feature-policy.json`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/dbcode-feature-policy.json). This tells you whether it is a tracked DBCode contribution or a wrapper route.
3. **Inspect the approved extension locally.** In the ignored standalone extension directory, inspect the installed package manifest for contributed commands, views, editors, notebooks, menus, and configuration. Do not copy proprietary implementation into the public repository or wiki.
4. **Trace host routing.** Search the focused shell patch and wrapper extension manifests for the command or view ID. The shell should expose a route only when it improves the standalone database workflow.
5. **Identify the boundary.** Classify the behavior as DBCode-owned, host-owned, or wrapper-owned. Database drivers, grids, and DBCode webviews normally remain DBCode-owned. Profile safety and release status are wrapper-owned.
6. **Prefer one route.** If DBCode already provides the stronger UI, route the focused shell to it and remove a weaker duplicate wrapper surface.
7. **Choose evidence.** Run the narrow source contract, a rendered check when layout changes, and a real workflow when activation, secure storage, data files, connections, or notebooks are involved.
8. **Recheck broad support.** Ensure the change does not turn representative PostgreSQL, DuckDB, or Parquet checks into a database allowlist.

## Relevant code

- [Focused shell and wrapper extensions](../modules/focused-shell-extensions.md)
- [`200-final-focused-dbcode-shell.patch`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/patches/code-oss/200-final-focused-dbcode-shell.patch)
- [`script/test_dbcode_feature_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/test_dbcode_feature_contract.sh)
- [`script/test_focused_shell_rendered.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/test_focused_shell_rendered.sh)

## Gotchas

- A command can exist in a manifest but still fail to register on a particular host version.
- A hidden Code OSS surface can remain reachable through context menus or keyboard shortcuts unless both presentation and command routing are checked.
- DBCode may render results in its own editor grid; adding a separate generic Results pane can create overlapping responsibilities.
- Local inspection of the licensed package is appropriate for compatibility work, but publishing its source or bundled package is outside the project boundary.

## Related

- [Unmodified Extension Boundary](../concepts/unmodified-extension-boundary.md)
- [Representative acceptance fixtures](../concepts/representative-acceptance-fixtures.md)
- [Choose a verification level](choose-a-verification-level.md)
