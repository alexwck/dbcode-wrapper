---
title: Verification Harness
description: Fast prompt-free checks for wrapper-owned boundaries and release orchestration.
type: module
tags:
  - wiki
  - module
  - verification
  - testing
wiki_profile: public
wiki_depth: standard
source_commit: 37003175d654b33c7ad97222bdb49ee614665f53
---
## Summary

Verification protects wrapper-owned seams without retesting DBCode. The normal development gate is fast, local, deterministic, and prompt-free. A normal release does not repeat a separate manual full gate, build, static smoke, and rendered smoke before preparation; `release_host.sh prepare` owns those stages and final acceptance reruns the exact source and static checks.

No maintained deployment test pauses for a person, starts a real database or kernel, calls an AI provider, signs in, or approves a macOS prompt. Rendered automation uses one persistent generated `qa` profile.

## Responsibilities

- Keep `check_development.sh` below one minute and free of app launches, network calls, questions, and human input.
- Give each test module one maintained runner using the pinned Node runtime.
- Test owner-facing build and release tasks through their public command interfaces.
- Prove writer-first and reader-first checkpoint refusal.
- Prove failed signing, staging, promotion, cleanup, interruption, and live inherited borrowers fail closed.
- Verify release ordering and reject missing or changed resumed assets.
- Exercise public path interfaces with relative, absolute, and space-containing paths.
- Inspect a signed app without launching it when the built-host boundary changes. Static Host Smoke checks the installed-size limit, zero source maps, the exact built-in inventory, no embedded DBCode, and the generated managed-settings copy without reading the private external runtime.
- Keep live product investigations outside the deployment gate.

## Public API / entry points

[check_development.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/check_development.sh) runs the fast source gate. [smoke_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/37003175d654b33c7ad97222bdb49ee614665f53/script/smoke_host.sh) validates a signed app without launching it. [test_focused_shell_rendered.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/test_focused_shell_rendered.sh) owns the one-profile rendered launch. [verify_fast_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/verify_fast_release.sh) reruns final source and static evidence from the manifest source.

## Key files

- [verification-policy.md](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/docs/agents/verification-policy.md) — risk, speed, prompt, and release-task policy.
- [host_slimming.sh](https://github.com/alexwck/dbcode-wrapper/blob/37003175d654b33c7ad97222bdb49ee614665f53/script/lib/host_slimming.sh) — fixture-tested package size and inventory checks used by Static Host Smoke.
- [test_build_host_task.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/test_build_host_task.sh) — signing, lease lifetime, interruption, and promotion coverage.
- [test_release_host_task.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/test_release_host_task.sh) — complete preparation order, exact resume, and explicit publication coverage.
- [test_development_gate_contract.sh](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/script/test_development_gate_contract.sh) — default gate composition.
- [focused-shell-rendered.cjs](https://github.com/alexwck/dbcode-wrapper/blob/2191402c377a4caa9c941af83c6cbcf6c0d41809/host/qa/focused-shell-rendered.cjs) — prompt-free rendered route checks.

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