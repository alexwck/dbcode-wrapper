# 57 — Deepen remaining maintenance interfaces

**What to change:** Keep the wrapper small and easy to release by shrinking the Update Status export surface, concentrating normal Host Session policy construction, deepening the shared Open VSX verifier without weakening security, and removing tests that preserve only retired file or ticket names.

**Blocked by:** None

**Type:** task

**Status:** resolved

## Comments

- 2026-08-01: Claimed after the user approved every candidate in the architecture review. The worktree was clean, the public-source contract passed, no new ignore rule was needed, and Generated Workspace Retention reported no deletion-eligible path. This task changes maintained interfaces and tests only; it does not remove protected generated output, alter DBCode, change update polling, or add a human release gate.
- 2026-08-01: Focused red-green contracts now bind the smaller Update Status interface, the purpose-level Host Session launch record, and the shared Open VSX configuration, selection, installed-identity, and package-security boundary. The current product, privacy, prompt-free notebook, signing, profile, slimming, and single-app invariants still pass after removing name-only history checks.
- 2026-08-01: The locked-package verifier accepted every pinned package and rejected tampered metadata. The complete prompt-free development gate passed in 20.96 seconds without rebuilding or launching the app; its one process-table fixture was skipped because this sandbox cannot inspect that disposable fixture process.
- 2026-08-01: Two-axis review found one copied public-key identity rule in the script adapter and one weak fatal-pattern assertion. Safe public-key path resolution now belongs to the shared verifier, both acquisition adapters reject unsafe identities, and the Host Session contract binds the exact fatal pattern. The reviewers found no remaining code, product, privacy, prompt, or documentation issue.
- 2026-08-01: The final prompt-free development gate passed in 21.45 seconds. The refreshed public/standard wiki is stamped to source commit `764d76e`, has zero dead links and zero lint problems across 32 wiki documents, and is available through the OpenKnowledge preview. The only graph orphan is the installed OpenKnowledge skill outside `wiki/`.

## Work

- [x] Remove unused Update Status exports without changing polling, cache, decision, or review behaviour.
- [x] Replace the 16-value Host Session policy writer interface with one purpose-level launch record.
- [x] Keep Finder and script acquisition adapters while concentrating Open VSX package-record and security validation in the shared verifier.
- [x] Remove name-only graveyard assertions and replace stale ticket wording with current product language.
- [x] Update maintained architecture and command guidance in forward plain English.
- [x] Run focused contracts, the complete prompt-free development gate, and final two-axis review.

## Answer

The wrapper now keeps four smaller, current maintenance boundaries. Update Status exposes only its maintained service surface while automatic polling and review behaviour remain unchanged. The normal Host Session caller passes one launch record, and Host Session owns stable readiness and shutdown policy. The shared Open VSX verifier owns configuration shape, canonical package selection, installed identity, safe public-key paths, and every package trust rule while Finder and script acquisition remain separate. Tests protect current behaviour and safety rules instead of remembering deleted helper names.

No tracked production file or folder was safe to remove, no generated path was eligible for cleanup, and no `.gitignore` rule was needed. DBCode remains unchanged and external. The normal prompt-free development gate still completes in about 21 seconds, and release preparation remains the one serialized owner-facing path.
