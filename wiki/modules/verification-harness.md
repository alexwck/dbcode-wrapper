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
source_commit: ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1
---
## Summary

Verification protects wrapper-owned seams without retesting the whole DBCode product. The default path is fast, deterministic, and prompt-free: focused source contracts, one static signed-host smoke, and one persistent-profile rendered smoke. Optional deeper diagnostics are separate developer work and never block deployment.

## Responsibilities

- Keep the aggregate source gate below one minute and free of app launches, network calls, questions, or human input.
- Give each test module one maintained runner using the pinned Node runtime.
- Verify current release-lock fields, immutable source, cache rules, patches, feature policy, profile identity and paths, signing policy, and public-source safety.
- Compare the tracked and packaged Profile Layout identity with a fresh Release Specification projection.
- Validate product query-storage fields and generated profile identity during static smoke before any rendered launch.
- Inspect the exact signed app without launching it.
- Reuse one generated `qa` profile for rendered shell checks with a mock Keychain.
- Render Connections, the unchanged New Connection catalogue, Database Explorer, SQL-file opening, Query Builder, notebook, AI, MCP, and settings routes without activating prompt-prone work.
- Bind final acceptance to the exact source snapshot, app digest, manifest, signature, extension inventory, and release-set ID.

Representative fixtures do not narrow DBCode support. Live databases, kernels, models, accounts, OAuth, secrets, mutation, and macOS prompts stay outside the normal deployment path.

The manual proof recorder, same-Mac generator, debugger fixture, four-pair runner, controlled promotion, and real-profile health harness are removed. Their accepted generated output remains protected under the retention policy.

## Public API / entry points

[`check_development.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/script/check_development.sh) runs the fast source contracts. [`smoke_host.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/script/smoke_host.sh) validates a signed app without launching it. [`test_focused_shell_rendered.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/script/test_focused_shell_rendered.sh) owns the single rendered launch. [`verify_fast_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/script/verify_fast_release.sh) reruns final checks from the manifest source.

## Key files

- [`docs/agents/verification-policy.md`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/docs/agents/verification-policy.md) — risk and prompt policy.
- [`script/test_profile_migration_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/script/test_profile_migration_contract.sh) — identity generation, shell/JavaScript parity, setup, migration, and recovery checks.
- [`host/qa/rendered-session-support.cjs`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/qa/rendered-session-support.cjs) — one-profile rendered session support.
- [`host/qa/ticket-03-rendered.cjs`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/host/qa/ticket-03-rendered.cjs) — focused UI checks.
- [`script/test_fast_release_acceptance_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/ddaa6a0b7b906af9994221e98ca8f0a0ef3c93b1/script/test_fast_release_acceptance_contract.sh) — final exact-release acceptance contract.

## Dependencies

Source checks need shell, the pinned Node runtime, and local fixtures. Built checks need the signed app and macOS inspection tools. The rendered smoke uses only its ignored generated profile and evidence roots under [Generated Workspace Retention](generated-workspace-retention.md).

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)
- [Package and transfer a private release](../flows/package-and-transfer-private-release.md)

## Related

- [Profile Layout and Setup](profile-layout-and-setup.md)
- [DBCode capability evidence](../concepts/dbcode-capability-evidence.md)
- [AI and MCP data boundaries](../concepts/ai-and-mcp-data-boundaries.md)
- [Representative acceptance fixtures](../concepts/representative-acceptance-fixtures.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)