# 33 — Concentrate atomic release-set switching

**What to build:** Replace the duplicated promotion and rollback five-member filesystem swap loops with one atomic switch implementation behind the Approved Release Set seam. Promotion and rollback keep their distinct policy and journal states but share move, failure, reverse recovery, and cleanup behaviour.

**Blocked by:** 32

**Type:** task

**Status:** resolved

## Superseded acceptance

The original transaction checklist no longer applies because ticket 40 removed the controlled-promotion, real-profile health, and four-pair compatibility workflows.

- [x] The maintained tree contains no controlled-promotion or installed-set swap loop to centralize.
- [x] Prompt-free approval writes generated records only; it does not install the app or change the production profile.
- [x] Guarded rollback remains limited to preparing, verifying, and previewing a known-good set from isolated generated data.
- [x] Retained historical promotion and rollback evidence remains protected and is not inspected or deleted.
- [x] Focused rollback and development-gate composition contracts pass without building or launching the app.

## Comments

- 2026-07-28: Audited after issue 32 closed. Commit `03b41f3` removed `controlled_upgrade.sh`, its five-member switching loops, real-profile health checks, four-pair compatibility runner, and owning tests. Current source has no promotion path or second rollback move loop.
- 2026-07-28: `test_release_rollback_contract.sh` and `test_development_gate_contract.sh` passed. No app was built or launched, no personal profile was read or changed, and no retained evidence was removed.

## Answer

No atomic switching module was added. There is no maintained promotion transaction to deduplicate.

The current release path approves an exact package without installing it. Guarded rollback prepares, verifies, and previews an isolated known-good set, while installation or restoration remains a separate user-controlled action. Adding a production-profile transaction engine here would restore authority and test machinery that the prompt-free release cleanup deliberately removed.

If an automated installer is wanted later, it needs a new task based on the current product boundary and current evidence model.
