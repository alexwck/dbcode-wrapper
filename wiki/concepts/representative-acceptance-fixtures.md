---
title: Representative acceptance fixtures
description: Why a small optional set of live workflows can deepen evidence without slowing normal deployment or limiting DBCode.
type: concept
tags:
  - wiki
  - concept
  - testing
  - fixtures
wiki_profile: public
wiki_depth: standard
source_commit: 2008ff48373c1aac378d0d1ec903e96a88ec1e29
---
## Definition

Representative acceptance fixtures are a small set of real workflows for deeper checks when a changed boundary needs them. PostgreSQL covers a network database and can support stored-routine debugger diagnostics. SQLite covers the bundled sample and grid. DuckDB and Parquet cover local data. Python notebooks cover the pinned Jupyter runtime and explicit kernel permission.

They are not the default deployment gate and they are not a list of supported databases.

## Why it matters

Normal wrapper deployment should not start services, ask for credentials, wait for a kernel, or need a person halfway through. The fast source, static, and one-profile rendered checks protect the wrapper without those dependencies.

A focused live fixture remains useful for a new or changed high-risk feature. For example, DBCode `1.36.4` declares a stored-routine debugger, so the loopback PostgreSQL fixture can support its separate compatibility proof without making debugger use a release prerequisite.

## Where it lives

- PostgreSQL debugger fixture: [`host/proof/postgres-debugger`](https://github.com/alexwck/dbcode-wrapper/tree/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/proof/postgres-debugger)
- Fixture adapter: [`script/lib/postgres_debugger_fixture.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/lib/postgres_debugger_fixture.sh)
- Reusable rendered QA: [`host/qa`](https://github.com/alexwck/dbcode-wrapper/tree/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/qa)
- Connection breadth contract: [`script/test_connection_catalogue_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/test_connection_catalogue_contract.sh)
- Notebook contract: [`script/test_python_notebook_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/test_python_notebook_contract.sh)

## Related

- [Verification Harness](../modules/verification-harness.md)
- [DBCode capability evidence](dbcode-capability-evidence.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)
- [First run, activation, and query](../flows/first-run-activate-and-query.md)