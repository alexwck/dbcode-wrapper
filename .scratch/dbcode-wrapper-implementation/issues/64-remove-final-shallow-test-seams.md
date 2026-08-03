# 64 — Remove final shallow test seams

**What to change:** Remove one unused Approved Release Set helper and three tests that reach below maintained interfaces, while preserving current release identity, Profile Setup behaviour, Host Release validation, packaging, and verification.

**Blocked by:** None

**Type:** task

**Status:** resolved

## Comments

- 2026-08-03: Claimed after the user approved all four candidates from the post-Issue-63 architecture review.
- 2026-08-03: The maintained seams are Profile Setup behaviour and production wiring, `host_release_context_record`, `release_source_set_id`, and the used Approved Release Set validators. Private method spellings, a lower-level Host Release validator, an intermediate identity payload, and an uncalled helper are not maintained interfaces.
- 2026-08-03: Focused Approved Release Set, Profile Setup, Host Release, and Release Identity checks passed on the clean baseline before editing.
- 2026-08-03: This cleanup does not change DBCode, application behaviour, profile state, build inputs, update polling, release behaviour, or public documentation. It does not require a version bump, host build, app launch, tag, package, publication, or push.
- 2026-08-03: Each focused check passed again after its slice. The complete prompt-free development gate passed in 23.06 seconds without rebuilding or launching the app.
- 2026-08-03: No public guide or wiki page changed because product behaviour, architecture guidance, and the supported workflow remain the same.
- 2026-08-03: The first specification review reported no findings. The first engineering review found that Release Identity also required exact-source prompt-free release acceptance evidence before resolution.
- 2026-08-03: Exact-source release validation passed for source commit `6fc24b1b9e5b0ad09dfb0f338d066c8073e0b7eb`. The signed Apple-silicon app passed Static Host Smoke, the persistent generated `qa` profile passed the rendered focused-shell checks, and final prompt-free acceptance matched the build manifest, release lock, rendered report, signed app, and release-set identity. The exact Compiled Host cache entry was absent, so this run built it once as `compiled-host-4f317fbbb74b7ccaf5cb5a6043c32090f1b50db88799b232a2cc1a8ccc962bd8`; that entry is now reusable.
- 2026-08-03: The final specification and engineering reviews reported no findings after the exact-source evidence was recorded.

## Work

- [x] Delete the unused HTTPS validator from Approved Release Set.
- [x] Remove the Profile Setup private-name scan while keeping behaviour and production-wiring checks.
- [x] Route Host Release rejection checks through its maintained context interface.
- [x] Keep Release Identity tests and implementation focused on the final source-set ID.
- [x] Run focused checks and the complete prompt-free development gate.
- [x] Run final specification and engineering reviews.

## Answer

Approved Release Set no longer contains the unused HTTPS helper. Profile Setup keeps its behaviour and production-wiring checks without scanning private method spellings.

Host Release rejection checks now use the same validated context interface as packaging and independent verification. Release Identity exposes only the final source-set ID; its intermediate payload helper and payload-shape test are gone.

Focused checks, the complete prompt-free development gate, Static Host Smoke, the one-profile rendered smoke, final exact-source prompt-free acceptance, and both final review axes passed. Public product and workflow guidance did not need a change.
