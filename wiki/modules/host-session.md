---
title: Host Session
description: The reusable lifecycle module that starts, observes, validates, and stops one DBCode Wrapper process tree.
type: module
tags:
  - wiki
  - module
  - host
  - lifecycle
wiki_profile: public
wiki_depth: standard
source_commit: 37003175d654b33c7ad97222bdb49ee614665f53
---
## Summary

Host Session is the policy-driven boundary for one application lifecycle. It starts the app with explicit profile paths, finds the expected process tree, observes renderer and DBCode readiness, rejects fatal logs, records structured evidence, and performs bounded shutdown.

## Responsibilities

- Validate policy before process or filesystem work.
- Prepare only absolute approved paths without symbolic-link escapes.
- Start the app and identify its renderer and extension-host processes.
- Observe stable renderer, DBCode log, and host-log readiness.
- Reject configured fatal patterns.
- Stop only the matching process tree and confirm exit within timeouts.
- Preserve the original failure when cleanup also fails.
- Serialize one stable result for shell and rendered-test consumers.

## Public API / entry points

The JavaScript API includes policy validation, `runHostSession`, `stopHostSession`, result parsing and validation, path preparation, and the Node runtime adapter. The public `run` and `stopHostSession` operations each validate once; an already validated run reuses its internal shutdown path. [`host_session.sh`](https://github.com/alexwck/dbcode-wrapper/blob/37003175d654b33c7ad97222bdb49ee614665f53/script/lib/host_session.sh) writes policy and starts the one `run` command. The command adapter does not expose separate validate or stop commands.

## Key files

- [`host-session.js`](https://github.com/alexwck/dbcode-wrapper/blob/37003175d654b33c7ad97222bdb49ee614665f53/script/lib/host-session.js) — lifecycle state machine.
- [`host_session.sh`](https://github.com/alexwck/dbcode-wrapper/blob/37003175d654b33c7ad97222bdb49ee614665f53/script/lib/host_session.sh) — shell policy writer and run adapter.
- [`host_session.cjs`](https://github.com/alexwck/dbcode-wrapper/blob/37003175d654b33c7ad97222bdb49ee614665f53/script/host_session.cjs) — the one-command Node adapter.
- [`host/qa/rendered-session-support.cjs`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/qa/rendered-session-support.cjs) — rendered smoke integration.
- [`script/test_host_session_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/37003175d654b33c7ad97222bdb49ee614665f53/script/test_host_session_contract.sh) — public integration contract.

## Dependencies

The core receives an injected runtime so process discovery, time, spawning, files, and logs remain testable. Higher-level run, proof, and rendered scripts supply policy and interpret the result.

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)

## Related

- [Focused host and private profile](../architecture/focused-host-and-private-profile.md)
- [Verification Harness](verification-harness.md)