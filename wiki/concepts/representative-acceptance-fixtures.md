---
title: Prompt-free acceptance boundary
description: Why deployment checks avoid human prompts and external services.
type: concept
tags:
  - wiki
  - concept
  - testing
  - acceptance
wiki_profile: public
wiki_depth: standard
source_commit: afc5fe7666bf88007bcf4956f05928e3d93c8e2f
---
## Definition

The maintained acceptance boundary checks wrapper-owned source, policy, static host state, and rendered routes without needing a person or an external service halfway through.

PostgreSQL, DuckDB, Parquet, SQLite, and notebooks are representative route and compatibility checks. They are not a connection allowlist, and the default deployment gate does not start their services, ask for credentials, wait for a kernel, or approve a permission prompt.

## Why it matters

DBCode Wrapper is a thin host. Retesting every database, AI provider, account, kernel, and operating-system prompt would make releases slow while duplicating DBCode's own product testing.

A real live workflow may still be useful when investigating a specific changed boundary. That is an explicit product investigation with synthetic data, not a maintained release test and not evidence for unrelated features.

## Maintained evidence

- Fast source gate: [script/check_development.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/check_development.sh)
- Rendered route runner: [host/qa/focused-shell-rendered.cjs](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/qa/focused-shell-rendered.cjs)
- Connection breadth contract: [script/test_connection_catalogue_contract.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/test_connection_catalogue_contract.sh)
- Notebook contract: [script/test_python_notebook_contract.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/test_python_notebook_contract.sh)
- Risk and prompt policy: [docs/agents/verification-policy.md](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/docs/agents/verification-policy.md)

## Related

- [Verification Harness](../modules/verification-harness.md)
- [DBCode capability evidence](dbcode-capability-evidence.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)
- [First run, activation, and query](../flows/first-run-activate-and-query.md)