# 60 — Tighten release identity and forward-facing tests

**What to change:** Correct the wrapper source identity so every production input that shapes the signed app invalidates reuse, remove redundant test-only adapters and historical-name checks where current behaviour is already proved, and keep the Python Kernel Bridge only when the pinned DBCode workflow still needs it.

**Blocked by:** None

**Type:** task

**Status:** resolved

## Comments

- 2026-08-02: Claimed after the user approved all candidates from the current architecture review. The work keeps the existing release path, one persistent generated QA profile, prompt-free development gate, and unchanged external DBCode extension.
- 2026-08-02: The [maintained capability coverage](https://github.com/alexwck/dbcode-wrapper/blob/main/docs/product/dbcode-capability-coverage.md) records the current Python workflow: DBCode attaches to an already running Jupyter kernel, and the wrapper's focused action starts a user-selected kernel first. Removing the bridge would remove working capability, so it stays unless upstream behaviour changes and a later live check proves the complete direct route.
- 2026-08-02: Release identity now includes the production Runtime Extension Set adapter. The test-only engine checker and implementation-only Runtime Setup exports are gone. Package verification, engine compatibility, bounded downloads, archive safety, signatures, and exact runtime acquisition remain covered through maintained interfaces.
- 2026-08-02: Retired workflow-name scans were removed from the normal contracts. Positive checks still require results below the query, one persistent generated QA profile, prompt-free notebook routing, the current Host Session, and the supported DBCode Tools menu.
- 2026-08-02: All focused checks passed. The complete prompt-free development gate passed in 23.19 seconds without building or launching the app. Nine Host Session lifecycle tests passed and the documented sandbox-only process-table fixture was the only skip.
- 2026-08-02: Review found one useful boundary to restore: small file-adapter fixtures now exercise the public package-verification command with absolute, relative, spaced, and linked paths. The deeper archive mutation matrix stays on the maintained verifier. The final specification and engineering reviews reported no findings.
- 2026-08-02: The maintained wiki was refreshed at source commit `f1cc5e1bbc50281cd6b86a307054982619ce5f00`. Its overview, release identity, runtime setup, focused-shell, verification, and append-only log pages have zero dead links, and the overview rendered correctly in the local preview.
- 2026-08-02: Exact-source release validation passed for source commit `66cd2130fd20f52796991a10a959e88608a36fd6`. The signed Apple-silicon app passed Static Host Smoke, the only automated GUI profile passed the rendered focused-shell checks, and final prompt-free acceptance matched the build manifest, release lock, rendered report, signed app, and release-set identity. The Compiled Host was built once because the exact cache entry was absent (`miss-built`); the resulting content-addressed cache is now reusable.

## Work

- [x] Include the production Runtime Extension Set adapter in wrapper source identity.
- [x] Remove the test-only engine checker and keep engine compatibility inside the Open VSX Package Verifier.
- [x] Narrow Runtime Setup test-only exports where security behaviour remains covered through a maintained interface.
- [x] Remove redundant retired-name scans while keeping positive current-behaviour, prompt-free, profile, and privacy checks.
- [x] Reassess the Python Kernel Bridge against the pinned upstream workflow and retain it because DBCode still requires a running Jupyter kernel.
- [x] Keep maintained documentation forward-facing and in plain English.
- [x] Run focused checks, the complete prompt-free development gate, and final review.

## Answer

The wrapper source digest now covers every maintained production input that shapes the signed app. Redundant test-only adapters, private exports, retired-name scans, and the obsolete engine checker were removed. Public command-level fixtures preserve the important path and link safety checks without returning the larger test matrix to the normal development gate.

The Python Kernel Bridge remains because the pinned DBCode workflow still connects to a running Jupyter kernel rather than starting one itself. No folder needed removal, and no new ignore rule was justified: generated output already belongs to the maintained Generated Workspace Retention policy.

Focused checks, the complete prompt-free development gate, two-lens review, wiki validation, a signed exact-source build, Static Host Smoke, one-profile rendered smoke, and final prompt-free acceptance all passed. This issue did not create a tag, package a release, publish, or push.
