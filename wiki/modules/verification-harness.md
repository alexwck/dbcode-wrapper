---
title: Verification Harness
description: The fast prompt-free checks that protect wrapper source, the signed host, DBCode routes, and releases.
type: module
tags:
  - wiki
  - module
  - verification
  - testing
wiki_profile: public
wiki_depth: standard
source_commit: f18e06ebeffa3620c76d5da3ca36ffc1697f7d9f
---
## Summary

Verification protects wrapper-owned seams without retesting the whole DBCode product. The default path is fast, deterministic, and prompt-free: focused source contracts, one static signed-host smoke, and one persistent-profile rendered smoke. Deeper live checks run only when a changed feature needs them.

## Responsibilities

- Keep the aggregate source gate below one minute and free of app launches, network calls, questions, or human input.
- Give each test module one maintained runner using the pinned Node runtime.
- Verify release locks, immutable source, compiled-host cache rules, patches, feature policy, profile paths, signing policy, and public-source safety.
- Inspect the exact signed app without launching it.
- Reuse one generated `qa` profile for rendered shell checks with a mock Keychain.
- Render Connections, the unchanged New Connection catalogue, Database Explorer, SQL-file opening, Query Builder, notebook, AI, MCP, and settings routes without activating prompt-prone work.
- Bind final acceptance to the exact source snapshot, app digest, manifest, signature, extension inventory, and release-set ID, using the normalized path returned by source materialization.

Representative fixtures do not narrow DBCode support. Live databases, kernels, models, accounts, OAuth, secrets, mutation, and macOS prompts stay outside the normal deployment path.

## Public API / entry points

[`check_development.sh`](https://github.com/alexwck/dbcode-wrapper/blob/f18e06ebeffa3620c76d5da3ca36ffc1697f7d9f/script/check_development.sh) runs the fast source contracts. [`smoke_host.sh`](https://github.com/alexwck/dbcode-wrapper/blob/f18e06ebeffa3620c76d5da3ca36ffc1697f7d9f/script/smoke_host.sh) inspects a signed app. [`test_focused_shell_rendered.sh`](https://github.com/alexwck/dbcode-wrapper/blob/f18e06ebeffa3620c76d5da3ca36ffc1697f7d9f/script/test_focused_shell_rendered.sh) owns the single rendered launch. [`verify_fast_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/f18e06ebeffa3620c76d5da3ca36ffc1697f7d9f/script/verify_fast_release.sh) materializes the manifest source, uses its normalized returned path, and runs final exact-release acceptance.

## Key files

- [`docs/agents/verification-policy.md`](https://github.com/alexwck/dbcode-wrapper/blob/f18e06ebeffa3620c76d5da3ca36ffc1697f7d9f/docs/agents/verification-policy.md) — risk and prompt policy.
- [`host/qa/rendered-session-support.cjs`](https://github.com/alexwck/dbcode-wrapper/blob/f18e06ebeffa3620c76d5da3ca36ffc1697f7d9f/host/qa/rendered-session-support.cjs) — one-profile rendered session support.
- [`host/qa/ticket-03-rendered.cjs`](https://github.com/alexwck/dbcode-wrapper/blob/f18e06ebeffa3620c76d5da3ca36ffc1697f7d9f/host/qa/ticket-03-rendered.cjs) — focused UI checks.
- [`script/test_fast_release_acceptance_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/f18e06ebeffa3620c76d5da3ca36ffc1697f7d9f/script/test_fast_release_acceptance_contract.sh) — final acceptance and normalized-path contract.

## Dependencies

Source checks need shell, the pinned Node runtime, and local fixtures. Built checks need the signed app and macOS inspection tools. The rendered smoke uses only its ignored generated profile and evidence roots under [Generated Workspace Retention](generated-workspace-retention.md).

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Controlled upgrade and rollback](../flows/controlled-upgrade-and-rollback.md)
- [Package and transfer a private release](../flows/package-and-transfer-private-release.md)

## Related

- [DBCode capability evidence](../concepts/dbcode-capability-evidence.md)
- [AI and MCP data boundaries](../concepts/ai-and-mcp-data-boundaries.md)
- [Representative acceptance fixtures](../concepts/representative-acceptance-fixtures.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)