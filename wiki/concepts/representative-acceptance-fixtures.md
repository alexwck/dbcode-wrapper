---
title: Representative acceptance fixtures
description: Why a small set of real database and notebook workflows proves integration without limiting DBCode's supported connections.
type: concept
tags:
  - wiki
  - concept
  - testing
  - fixtures
wiki_profile: public
wiki_depth: standard
source_commit: efe247fc701a9b529e3e6368b6571a44541fc146
---
## Definition

Representative acceptance fixtures are a deliberately small set of real workflows used to test different integration boundaries. PostgreSQL proves a network database and saved password path. SQLite proves DBCode's bundled sample and table grid. DuckDB plus Parquet proves local database and data-file behavior. The Python notebook proves the pinned Jupyter runtime and explicit kernel permission.

They are evidence targets, not a list of the only databases the product supports.

## Why it matters

Running every supported database on every change would be slow, expensive, and still would not guarantee complete coverage. A representative set gives fast, repeatable evidence across the risky boundaries: networking, secure storage, local files, custom editors, grids, extension activation, notebooks, persistence, and relaunch.

The feature catalogue and unmodified-extension boundary keep broader support intact. A change that alters connection routing or DBCode contributions needs wider checks than a documentation-only change.

## Where it lives

- PostgreSQL proof and seed: [`host/proof`](https://github.com/alexwck/dbcode-wrapper/tree/efe247fc701a9b529e3e6368b6571a44541fc146/host/proof)
- Reusable QA files and catalogues: [`host/qa`](https://github.com/alexwck/dbcode-wrapper/tree/efe247fc701a9b529e3e6368b6571a44541fc146/host/qa)
- Database feature contract: [`script/test_dbcode_feature_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/test_dbcode_feature_contract.sh)
- Connection catalogue contract: [`script/test_connection_catalogue_contract.mjs`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/test_connection_catalogue_contract.mjs)
- Notebook contract: [`script/test_python_notebook_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/test_python_notebook_contract.sh)

## Related

- [Verification Harness](../modules/verification-harness.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)
- [First run, activation, and query](../flows/first-run-activate-and-query.md)
