---
title: Verification Harness
description: Fast prompt-free checks for wrapper-owned boundaries.
type: module
tags:
  - wiki
  - module
  - verification
  - testing
wiki_profile: public
wiki_depth: standard
source_commit: afc5fe7666bf88007bcf4956f05928e3d93c8e2f
---
## Summary

Verification protects wrapper-owned seams without retesting DBCode. The normal development gate is fast, local, deterministic, and prompt-free. Static host, rendered, package, update, and rollback checks run only when their boundary changes or a release needs them.

No maintained deployment test pauses for a person, starts a real database or kernel, calls an AI provider, signs in to an account, or approves a macOS prompt.

## Responsibilities

- Keep `check_development.sh` below one minute and free of app launches, network calls, questions, and human input.
- Give each test module one maintained runner using the pinned Node runtime.
- Verify release identity, source snapshots, cache rules, patches, feature policy, profile identity, update status, and public-source safety.
- Inspect a signed app without launching it when the built-host boundary changes.
- Reuse one generated `qa` profile for rendered shell checks.
- Render DBCode routes without activating databases, kernels, models, sign-in, mutation, or prompt-prone services.
- Bind final acceptance to the exact source, app digest, manifest, signature, extension inventory, rendered report, and release-set ID.
- Test the owner release task with local fixtures for order, exact resume, failure before tag, and explicit publication.
- Keep live product investigations outside the deployment gate.

## Public API / entry points

[check_development.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/check_development.sh) runs the fast source gate. [smoke_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/smoke_host.sh) validates a signed app without launching it. [test_focused_shell_rendered.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/test_focused_shell_rendered.sh) owns the one-profile rendered launch. [verify_fast_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/verify_fast_release.sh) validates final evidence from the manifest source.

## Key files

- [docs/agents/verification-policy.md](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/docs/agents/verification-policy.md) — risk, speed, and prompt policy.
- [script/test_release_host_task.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/test_release_host_task.sh) — public owner-task contract.
- [script/test_fast_release_acceptance_contract.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/test_fast_release_acceptance_contract.sh) — final exact-release acceptance.
- [script/test_update_status_contract.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/test_update_status_contract.sh) — automatic polling, read-only status, and approval matching.
- [host/qa/focused-shell-rendered.cjs](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/qa/focused-shell-rendered.cjs) — prompt-free rendered route checks.
- [host/qa/rendered-session-support.cjs](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/qa/rendered-session-support.cjs) — shared one-profile session support.

## Dependencies

Source checks need shell, the pinned Node runtime, and local fixtures. Built checks need the signed app and macOS inspection tools. Rendered checks use ignored profile and evidence roots managed by [Generated Workspace Retention](generated-workspace-retention.md).

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)
- [Package and publish a Host Release](../flows/package-and-publish-host-release.md)

## Related

- [Profile Layout and Setup](profile-layout-and-setup.md)
- [DBCode capability evidence](../concepts/dbcode-capability-evidence.md)
- [AI and MCP data boundaries](../concepts/ai-and-mcp-data-boundaries.md)
- [Prompt-free acceptance boundary](../concepts/representative-acceptance-fixtures.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)