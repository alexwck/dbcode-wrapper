---
title: DBCode capability evidence
description: The evidence levels used to preserve DBCode features without turning the wrapper into a second product.
type: concept
tags:
  - wiki
  - concept
  - dbcode
  - verification
wiki_profile: public
wiki_depth: standard
source_commit: 2dbaee59ad243e222541fbea3b5efcc1873a26df
---
## Definition

DBCode capability evidence records how strongly the wrapper has checked an upstream feature:

- `declared`: the exact DBCode package declares its command, view, menu, editor, setting, or tool.
- `reachable`: the focused shell leaves at least one working DBCode-owned route.
- `rendered`: an isolated app check opens the real surface.
- `live`: a real workflow completes against a suitable fixture or service.

These levels must stay separate. Opening a route does not prove a full workflow, and one working AI setting does not prove every AI feature.

Capability status is separate from evidence depth. `supported` means the wrapper keeps the DBCode-owned route without a known wrapper gap. `limited` records an intentional gap or a workflow outside the prompt-free evidence. Once a policy is approved, it cannot keep a pending `requires-validation` state; unexercised optional work becomes an honest limit instead of a deployment blocker.

## Why it matters

The wrapper should preserve DBCode without copying it or running slow tests against the whole product. Broad declared and reachable checks protect feature breadth. A small rendered smoke protects the shell. Optional live diagnostics are reserved for new, changed, limited, or high-risk features and do not block deployment.

For each DBCode bump, compare added and removed public contributions before approval. Preserve new DBCode-owned commands and settings through existing routes, and update the compatibility policy instead of recreating the feature in wrapper code.

The exact New Connection catalogue remains authoritative. PostgreSQL, SQLite, DuckDB, Parquet, and notebooks are representative checks, not a wrapper database allowlist.

## Where it lives

- [`host/dbcode-feature-policy.json`](https://github.com/alexwck/dbcode-wrapper/blob/2dbaee59ad243e222541fbea3b5efcc1873a26df/host/dbcode-feature-policy.json) — maintained feature groups, routes, evidence, and explicit limits.
- [`docs/product/dbcode-capability-coverage.md`](https://github.com/alexwck/dbcode-wrapper/blob/2dbaee59ad243e222541fbea3b5efcc1873a26df/docs/product/dbcode-capability-coverage.md) — public orientation by official DBCode feature family.
- [`script/test_dbcode_feature_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2dbaee59ad243e222541fbea3b5efcc1873a26df/script/test_dbcode_feature_contract.sh) — contribution, approved-history, and policy contract.
- [`script/test_connection_catalogue_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2dbaee59ad243e222541fbea3b5efcc1873a26df/script/test_connection_catalogue_contract.sh) — unchanged catalogue evidence.

## Current boundary

The policy tracks connections, query work, grids, Explorer, notebooks, accounts, settings, data files, debugging, AI, Copilot, and MCP separately. Known gaps stay explicit instead of being hidden behind a broad “supported” claim.

## Related

- [Product and upstream boundaries](../architecture/product-and-upstream-boundaries.md)
- [Unmodified Extension Boundary](unmodified-extension-boundary.md)
- [AI and MCP data boundaries](ai-and-mcp-data-boundaries.md)
- [Trace a DBCode feature](../guides/trace-a-dbcode-feature.md)
- [Representative acceptance fixtures](representative-acceptance-fixtures.md)