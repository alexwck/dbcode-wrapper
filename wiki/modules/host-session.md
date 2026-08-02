---
title: Host Session
description: The lifecycle module that runs, observes, and records one DBCode Wrapper process tree.
type: module
tags:
  - wiki
  - module
  - host
  - lifecycle
wiki_profile: public
wiki_depth: standard
source_commit: b3773b5ad1f3f3b0bcd3d7dce39f614bf082ce11
---
## Summary

Host Session is the boundary for one application lifecycle. It accepts only launch-specific values, creates and validates the stable policy, starts the app with explicit profile paths, observes renderer and DBCode readiness, records structured evidence, waits for normal user exit, and performs bounded failure cleanup.

## Responsibilities

- Build and validate the policy from one purpose-level launch record.
- Keep renderer, DBCode log, timeout, and failure-cleanup defaults inside the module.
- Prepare only absolute approved paths without symbolic-link escapes.
- Start the app and identify its renderer and extension-host processes.
- Observe stable renderer, DBCode log, and host-log readiness.
- Reject configured fatal patterns.
- Wait for normal user exit after readiness.
- Clean up only the matching process tree after failure and preserve the original failure.
- Serialize one stable result for shell and rendered-test consumers.

## Public API / entry points

The maintained JavaScript interface is `runHostSession`, `serializeSessionResult`, and the production `createNodeRuntime` adapter. [`host_session.sh`](https://github.com/alexwck/dbcode-wrapper/blob/b3773b5ad1f3f3b0bcd3d7dce39f614bf082ce11/script/lib/host_session.sh) passes one launch record with the application name, executable, arguments, environment, log paths, session ID, and timeout to the one `run` command. Policy construction, validation, result parsing, path preparation, and failure cleanup stay private. There is no saved-session stop command or test-only completion mode.

## Key files

- [`host-session.js`](https://github.com/alexwck/dbcode-wrapper/blob/b3773b5ad1f3f3b0bcd3d7dce39f614bf082ce11/script/lib/host-session.js) — policy and lifecycle state machine.
- [`host_session.sh`](https://github.com/alexwck/dbcode-wrapper/blob/b3773b5ad1f3f3b0bcd3d7dce39f614bf082ce11/script/lib/host_session.sh) — purpose-level shell adapter.
- [`host_session.cjs`](https://github.com/alexwck/dbcode-wrapper/blob/b3773b5ad1f3f3b0bcd3d7dce39f614bf082ce11/script/host_session.cjs) — the one-command Node adapter.
- [`host/qa/rendered-session-support.cjs`](https://github.com/alexwck/dbcode-wrapper/blob/b3773b5ad1f3f3b0bcd3d7dce39f614bf082ce11/host/qa/rendered-session-support.cjs) — rendered smoke integration.
- [`script/test_host_session_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/b3773b5ad1f3f3b0bcd3d7dce39f614bf082ce11/script/test_host_session_contract.sh) — launch-record, path, command, and lifecycle contract.

## Dependencies

The core receives an injected runtime so process discovery, time, spawning, files, and logs remain testable. The normal shell launcher supplies only launch-specific values. Host Session owns the stable policy, and rendered adapters interpret the structured result.

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)

## Related

- [Focused host and private profile](../architecture/focused-host-and-private-profile.md)
- [Verification Harness](verification-harness.md)