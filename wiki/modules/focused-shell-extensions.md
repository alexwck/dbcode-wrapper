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
source_commit: afc5fe7666bf88007bcf4956f05928e3d93c8e2f
---
## Summary

The focused shell removes general IDE navigation and makes DBCode the product surface. It keeps the extension-host APIs DBCode needs and adds only small wrapper extensions for profile setup, the Python kernel bridge, and release status.

DBCode stays unmodified. The wrapper does not recreate its database, notebook, AI, MCP, account, or licence features.

## Responsibilities

- Present Connections, Database Explorer, SQL files, queries, history, library, scratch files, notebooks, Query Builder, settings, AI, and MCP routes.
- Keep DBCode-owned editors, grids, actions, diagrams, exports, and account surfaces available.
- Keep Database Explorer stable during editor, canvas, grid, and Escape interactions.
- Open file-backed scratch queries in the generated query folder without overwriting existing files.
- Hide unrelated IDE surfaces and duplicate wrapper actions.
- Provide profile safety, kernel permission, and release status around DBCode.
- Poll official Code OSS, VSCodium, and DBCode metadata automatically while keeping review actions read-only.
- Show prompt-prone routes in rendered checks without activating them.

## Public API / entry points

Most shell behaviour comes from the focused Code OSS patch. VSCodium preparation writes validated wrapper identity into `product.json`. Wrapper commands use the `dbcodeWrapper` namespace. DBCode remains a separately acquired upstream extension and owns its commands, views, webviews, editors, providers, and tools.

The current feature policy keeps capability status separate from evidence depth. A feature may be `declared`, `reachable`, `rendered`, or `live`. Optional AI, MCP, debugger, account, and notebook workflows are marked with honest limited evidence when the prompt-free gate does not activate them.

## Key files

- [200-final-focused-dbcode-shell.patch](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/patches/code-oss/200-final-focused-dbcode-shell.patch) — focused workbench routing, query storage, and dismissal behaviour.
- [0001-dbcode-wrapper-identity.patch](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/patches/vscodium/0001-dbcode-wrapper-identity.patch) — product identity injection.
- [dbcode-wrapper-profile-migration](https://github.com/alexwck/dbcode-wrapper/tree/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/extensions/dbcode-wrapper-profile-migration) — setup, import, profile identity, runtime installation, and recovery.
- [dbcode-wrapper-python-kernel](https://github.com/alexwck/dbcode-wrapper/tree/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/extensions/dbcode-wrapper-python-kernel) — explicit notebook bridge.
- [dbcode-wrapper-release-status](https://github.com/alexwck/dbcode-wrapper/tree/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/extensions/dbcode-wrapper-release-status) — official update discovery, read-only review UI, and approved-set status.
- [host/dbcode-feature-policy.json](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/dbcode-feature-policy.json) — capability and route policy.
- [host/qa/focused-shell-rendered.cjs](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/qa/focused-shell-rendered.cjs) — maintained rendered route runner.

## Dependencies

The shell depends on the pinned Code OSS workbench structure, generated product identity, and DBCode's public contributions. Source contracts protect routing; one persistent-profile rendered check protects real presentation.

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