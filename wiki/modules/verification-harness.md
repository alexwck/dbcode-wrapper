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
source_commit: 5f77cbeeb00b79432ca86b95b0d392d68f0d1d27
---
## Summary

Verification protects wrapper-owned seams without retesting DBCode. The normal development gate is fast, local, deterministic, and prompt-free. Static host, rendered, package, update, and rollback checks run only when their boundary changes or a release needs them.

No maintained deployment test pauses for a person, starts a real database or kernel, calls an AI provider, signs in to an account, or approves a macOS prompt. Rendered automation uses one persistent generated `qa` profile.

## Responsibilities

- Keep `check_development.sh` below one minute and free of app launches, network calls, questions, and human input.
- Give each test module one maintained runner using the pinned Node runtime.
- Prove a visible wrapper command is registered before startup state is known and routes missing prerequisites safely.
- Verify temporary-file cleanup after success and failure.
- Exercise public path interfaces with relative, absolute, and space-containing paths.
- Verify release identity, source snapshots, cache rules, patches, feature policy, profile identity, update status, and public-source safety.
- Inspect a signed app without launching it when the built-host boundary changes.
- Render DBCode routes without activating databases, kernels, models, sign-in, mutation, or prompt-prone services.
- Keep live product investigations outside the deployment gate.

## Public API / entry points

[check_development.sh](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/script/check_development.sh) runs the fast source gate. [smoke_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/script/smoke_host.sh) validates a signed app without launching it. [test_focused_shell_rendered.sh](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/script/test_focused_shell_rendered.sh) owns the one-profile rendered launch. [verify_fast_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/script/verify_fast_release.sh) validates final evidence from the manifest source.

## Key files

- [verification-policy.md](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/docs/agents/verification-policy.md) — risk, speed, prompt, path, and temporary-file policy.
- [test_patch_plan.sh](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/script/test_patch_plan.sh) — prepared-tree, materializer path, and cleanup contracts.
- [test_profile_migration.mjs](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/script/test_profile_migration.mjs) — command routing and first-run safety contracts.
- [test_update_status_contract.sh](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/script/test_update_status_contract.sh) — automatic polling, read-only status, and approval matching.
- [focused-shell-rendered.cjs](https://github.com/alexwck/dbcode-wrapper/blob/5f77cbeeb00b79432ca86b95b0d392d68f0d1d27/host/qa/focused-shell-rendered.cjs) — prompt-free rendered route checks.

## Dependencies

Source checks need shell, the pinned Node runtime, and local synthetic fixtures. Built checks need the signed app and macOS inspection tools. Rendered checks use ignored profile and evidence roots managed by [Generated Workspace Retention](generated-workspace-retention.md).

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