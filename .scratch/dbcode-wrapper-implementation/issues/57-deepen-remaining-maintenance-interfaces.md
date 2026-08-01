# 57 — Deepen remaining maintenance interfaces

**What to change:** Keep the wrapper small and easy to release by shrinking the Update Status export surface, concentrating normal Host Session policy construction, deepening the shared Open VSX verifier without weakening security, and removing tests that preserve only retired file or ticket names.

**Blocked by:** None

**Type:** task

**Status:** claimed

## Comments

- 2026-08-01: Claimed after the user approved every candidate in the architecture review. The worktree was clean, the public-source contract passed, no new ignore rule was needed, and Generated Workspace Retention reported no deletion-eligible path. This task changes maintained interfaces and tests only; it does not remove protected generated output, alter DBCode, change update polling, or add a human release gate.
- 2026-08-01: Focused red-green contracts now bind the smaller Update Status interface, the purpose-level Host Session launch record, and the shared Open VSX configuration, selection, installed-identity, and package-security boundary. The current product, privacy, prompt-free notebook, signing, profile, slimming, and single-app invariants still pass after removing name-only history checks.
- 2026-08-01: The locked-package verifier accepted every pinned package and rejected tampered metadata. The complete prompt-free development gate passed in 20.96 seconds without rebuilding or launching the app; its one process-table fixture was skipped because this sandbox cannot inspect that disposable fixture process.

## Work

- [ ] Remove unused Update Status exports without changing polling, cache, decision, or review behaviour.
- [ ] Replace the 16-value Host Session policy writer interface with one purpose-level launch record.
- [ ] Keep Finder and script acquisition adapters while concentrating Open VSX package-record and security validation in the shared verifier.
- [ ] Remove name-only graveyard assertions and replace stale ticket wording with current product language.
- [ ] Update maintained architecture and command guidance in forward plain English.
- [ ] Run focused contracts, the complete prompt-free development gate, and final two-axis review.
