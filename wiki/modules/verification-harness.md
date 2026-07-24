---
title: Verification Harness
description: The layered checks that protect source contracts, the focused host, real profiles, database workflows, and releases.
type: module
tags:
  - wiki
  - module
  - verification
  - testing
wiki_profile: public
wiki_depth: standard
source_commit: efe247fc701a9b529e3e6368b6571a44541fc146
---
## Summary

Verification is layered because no single test can prove the product goal. Fast contract tests protect schemas and patches. Rendered checks protect the focused UI. Real-profile checks protect activation, secure storage, persistence, and relaunch. Database and notebook checks protect representative user workflows. Release checks protect packaging, signing, promotion, and rollback.

## Responsibilities

- Run deterministic unit and shell contract tests during development.
- Verify the public source tree, pinned identities, patch plan, slimming policy, profile layout, and runtime package set.
- Inspect built app contents and signing continuity.
- Launch through [Host Session](host-session.md) and reject fatal extension-host logs.
- Exercise representative PostgreSQL, SQLite, DuckDB, Parquet, and Python notebook paths.
- Confirm DBCode activation, licence persistence, saved credentials, query results, quit, and relaunch.
- Verify candidate preparation, promotion, health, rollback, and private packaging.

Representative fixtures do not narrow product support. The approved DBCode extension remains responsible for every database connection type it supports.

## Public API / entry points

[`check_development.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/check_development.sh) is the broad fast-development entry point. Narrow `test_*` scripts protect individual contracts. `verify_*` scripts inspect built or prepared release artifacts. Manual acceptance steps cover macOS prompts and real external services that cannot be honestly simulated.

## Key files

- [`script/check_development.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/check_development.sh) — aggregate development checks.
- [`script/verify_release_set_static.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/verify_release_set_static.sh) — prepared-set inspection.
- [`script/test_focused_shell_rendered.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/test_focused_shell_rendered.sh) — rendered shell checks.
- [`host/proof`](https://github.com/alexwck/dbcode-wrapper/tree/efe247fc701a9b529e3e6368b6571a44541fc146/host/proof) and [`host/qa`](https://github.com/alexwck/dbcode-wrapper/tree/efe247fc701a9b529e3e6368b6571a44541fc146/host/qa) — representative fixtures and policies.

## Dependencies

Different levels require different tools: Node, shell, `jq`, built app bundles, macOS signing tools, local databases, and the owner's real standalone profile. Tests that need private state must write only to ignored evidence locations.

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Controlled upgrade and rollback](../flows/controlled-upgrade-and-rollback.md)
- [Package and transfer a private release](../flows/package-and-transfer-private-release.md)

## Related

- [Representative acceptance fixtures](../concepts/representative-acceptance-fixtures.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)
