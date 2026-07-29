---
title: Verification Harness
description: The fast prompt-free checks that protect wrapper source, the signed host, DBCode routes, and Host Releases.
type: module
tags:
  - wiki
  - module
  - verification
  - testing
wiki_profile: public
wiki_depth: standard
source_commit: e02160a3b5363fc4e91c5282f7818ed908624c6d
---
## Summary

Verification protects wrapper-owned seams without retesting the whole DBCode product. The default path is fast, deterministic, and prompt-free: focused source contracts while working, one persistent-profile rendered smoke, exact-source final acceptance, Host Release packaging, and independent mounted verification.

## Responsibilities

- Keep the aggregate source gate below one minute and free of app launches, network calls, questions, or human input.
- Give each test module one maintained runner using the pinned Node runtime.
- Verify release-lock fields, immutable source, cache rules, patches, feature policy, profile identity, signing policy, update status, and public-source safety.
- Inspect the exact signed app without launching it.
- Reuse one generated `qa` profile for rendered shell checks with a mock Keychain.
- Render Connections, the unchanged New Connection catalogue, Database Explorer, SQL-file opening, Query Builder, notebook, AI, MCP, and settings routes without activating prompt-prone work.
- Bind final acceptance to the exact source snapshot, app digest, manifest, signature, extension inventory, and release-set ID.
- Run the focused Host Release contract only when release packaging changes.
- Keep live databases, kernels, models, accounts, OAuth, secrets, mutation, and macOS prompts outside deployment.

## Public API / entry points

[check_development.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/check_development.sh) runs the fast source contracts. [smoke_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/smoke_host.sh) validates a signed app without launching it. [test_focused_shell_rendered.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/test_focused_shell_rendered.sh) owns the single rendered launch. [verify_fast_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/verify_fast_release.sh) reruns final checks from the manifest source.

## Key files

- [docs/agents/verification-policy.md](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/docs/agents/verification-policy.md) — risk, speed, and prompt policy.
- [script/test_fast_release_acceptance_contract.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/test_fast_release_acceptance_contract.sh) — final exact-release acceptance.
- [script/test_host_release_contract.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/test_host_release_contract.sh) — package, mounted verification, approval, and tamper checks.
- [script/test_update_status_contract.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/test_update_status_contract.sh) — automatic polling, read-only status, and exact approval matching.
- [host/qa/rendered-session-support.cjs](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/host/qa/rendered-session-support.cjs) — one-profile rendered session support.

## Dependencies

Source checks need shell, the pinned Node runtime, and local fixtures. Built checks need the signed app and macOS inspection tools. Rendered smoke uses ignored generated profile and evidence roots under [Generated Workspace Retention](generated-workspace-retention.md).

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)
- [Package and publish a Host Release](../flows/package-and-publish-host-release.md)

## Related

- [Profile Layout and Setup](profile-layout-and-setup.md)
- [DBCode capability evidence](../concepts/dbcode-capability-evidence.md)
- [AI and MCP data boundaries](../concepts/ai-and-mcp-data-boundaries.md)
- [Representative acceptance fixtures](../concepts/representative-acceptance-fixtures.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)
