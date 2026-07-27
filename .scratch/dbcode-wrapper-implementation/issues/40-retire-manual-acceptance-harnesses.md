# 40 — Retire manual acceptance harnesses

**What to build:** Remove the superseded proof recorder, same-Mac acceptance generator, debugger fixture, four-pair compatibility runner, controlled promotion, real-profile health harness, and manual launch mode now that the normal release path is prompt-free and uses one generated `qa` profile. Preserve approved history, guarded rollback tools, and retained generated evidence.

**Blocked by:** 38

**Type:** task

**Status:** resolved

- [x] The tracked proof recorder, historical same-Mac verifier, PostgreSQL debugger fixture, four-pair runner, controlled-promotion workflow, real-profile health harness, and their owning tests are removed.
- [x] `run_host.sh` has one normal monitored mode plus explicit foreground debugging; it has no manual-proof mode.
- [x] Schema-3 prompt-free acceptance, package verification, approval, current approved history, and guarded rollback preparation, verification, and preview remain intact.
- [x] Existing proof, controlled-upgrade, acceptance, rollback, and package output stays protected by the Generated Workspace Retention contract and is not inspected or deleted.
- [x] Public and agent documentation describes live database, debugger, kernel, account, and macOS prompts as normal-use or optional diagnostics, not maintained release tests.
- [x] Focused contracts and the complete development gate pass without launching or rebuilding the app.

## Comments

- 2026-07-27: Claimed after `v0.1.1` entered approved history. The default development and release gates are already prompt-free, so this ticket removes only unused manual evidence generators and keeps their accepted historical output protected.
- 2026-07-27: The old controlled-upgrade contract no longer matched the maintained approval schema and also depended on extra runtime profiles plus manual proof. It was removed with its four-pair and real-profile health harnesses instead of repairing a second release system. The current rollback prepare, verify, and preview tools remain.
- 2026-07-27: `test_dbcode_contract.sh`, `test_host_session_contract.sh`, `test_generated_workspace_contract.sh`, `test_development_gate_contract.sh`, `test_release_rollback_contract.sh`, `test_private_release_contract.sh`, `test_public_source_tree_contract.sh`, `git diff --check`, and the complete `check_development.sh` gate passed. The Host Session suite had one expected sandbox-only process-table skip. No app was built or launched, no private profile was read or written, and no retained generated evidence was removed.

## Answer

The maintained release path now has one prompt-free acceptance schema and one persistent automated GUI profile: `.build/qa/profile`. It does not ask a person to sign in, approve macOS access, run a database or debugger, start a kernel, call an AI model, or enter a secret.

The old manual proof, same-Mac, debugger-fixture, four-pair, controlled-promotion, and real-profile health harnesses are gone. The approved history, prompt-free package and approval flow, protected historical evidence, and guarded rollback prepare, verify, and preview tools remain.
