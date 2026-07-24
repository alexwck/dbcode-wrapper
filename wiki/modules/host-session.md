---
title: Host Session
description: The reusable lifecycle module that starts, observes, validates, and stops a DBCode Wrapper process tree.
type: module
tags:
  - wiki
  - module
  - host
  - lifecycle
wiki_profile: public
wiki_depth: standard
source_commit: efe247fc701a9b529e3e6368b6571a44541fc146
---
## Summary

Host Session replaces scattered launch helpers with one policy-driven lifecycle boundary. It starts the app with explicit profile paths, finds the expected process tree, observes readiness and fatal logs, records structured evidence, and performs a bounded shutdown.

## Responsibilities

- Validate a session policy before any process or filesystem action.
- Prepare only absolute, approved runtime paths without symlink escapes.
- Start the app and identify its live renderer and extension-host processes.
- Observe DBCode readiness and configured fatal patterns.
- Stop the matching process tree and confirm it exited within the timeout.
- Serialize and validate a stable session result for shell and test consumers.
- Clean up a partially started session after failure.

## Public API / entry points

The JavaScript surface includes policy validation, `runHostSession`, `stopHostSession`, result validation and serialization, runtime-path preparation, and a Node runtime adapter. [`host_session.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/lib/host_session.sh) supplies shell commands for policy creation, run, and stop.

## Key files

- [`host-session.js`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/lib/host-session.js) — core lifecycle state machine.
- [`host_session.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/lib/host_session.sh) — shell adapter.
- [`test_host_session.mjs`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/test_host_session.mjs) — unit tests with injected runtime behavior.
- [`test_host_session_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/test_host_session_contract.sh) — integration contract.

## Dependencies

The core accepts an injected runtime, which keeps process discovery, clocks, spawning, filesystem work, and logging testable. Higher-level proof and release scripts supply the policy and interpret the result.

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)

## Related

- [Focused host and private profile](../architecture/focused-host-and-private-profile.md)
- [Verification Harness](verification-harness.md)
