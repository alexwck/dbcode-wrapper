# 58 — Finish fast-release architecture cleanup

**What to change:** Keep routine DBCode Wrapper releases fast by making the Patch Plan own build-relevant Compiled Host identity, removing three shallow interface leftovers, narrowing Host Configuration toward purpose-level records, and testing Profile Recovery through its maintained worker seam.

**Blocked by:** None

**Type:** task

**Status:** resolved

## Comments

- 2026-08-02: Claimed after the user approved all four candidates from the fresh architecture review. No tracked file or folder is being removed. Generated evidence stays protected, DBCode remains unchanged and external, and the normal prompt-free release path remains the only supported path.
- 2026-08-02: The confirmed test seams are: Compiled Host input identity derived through the Patch Plan; the maintained Generated Workspace Retention and connection-catalogue export surfaces plus current Profile Layout behaviour; existing shell task behaviour while Host Configuration becomes narrower; and Profile Recovery through its `run` worker path with operating-system behaviour behind an adapter.
- 2026-08-02: Implemented the four approved seams. The Patch Plan now projects only build-relevant fields into Compiled Host identity. Package details remain inside `RELEASE_EXTENSION_SPEC`. Profile Recovery exposes one `run` interface with controlled operating-system behaviour in tests. The two unused CommonJS exports and the retired Profile Layout helper-name assertion are gone.
- 2026-08-02: Focused contracts passed, including the 15.09-second Host Release fixture. The complete prompt-free development gate passed in 20.96 seconds with its documented sandbox-only process-table test skipped. No build, app launch, private package inspection, or human prompt was needed.
- 2026-08-02: Standards and spec review found a deleted-name blacklist and incomplete process-wait coverage. Both were corrected before the final gate. The repeated local reads from the extension record remain explicit because a generic accessor would add a shallow interface without reducing release work.
- 2026-08-02: Refreshed the five affected public wiki pages against source commit `02a3c237d5e7baf9c741e1a1dcd7828730490032`. All 32 wiki documents lint clean, the link graph has zero dead links, and the preview starts successfully. The two old-path forward pointers remain outside current navigation so historical log links resolve without presenting a retired workflow as current guidance.
- 2026-08-02: Final review found five changed-file links that still pointed to older source snapshots. They now point to the exact implementation commit; both review axes otherwise passed.

## Work

- [x] Make descriptive Patch Plan wording irrelevant to the Compiled Host input ID while retaining every build-relevant field.
- [x] Remove the unused `contains` and `NORMALIZATION` exports and the retired-helper-name assertion.
- [x] Replace broad Host Configuration globals with purpose-level records where current callers justify the seam.
- [x] Make Profile Recovery tests exercise `run` instead of exported implementation helpers.
- [x] Keep public and architecture documentation forward-facing and in plain English.
- [x] Run focused red-green checks, the complete prompt-free development gate, and two-axis review.

## Answer

All four approved cleanup candidates are complete. Routine releases no longer recompile Code OSS for descriptive Patch Plan edits, package data stays in one extension record, Profile Recovery is tested through its maintained worker boundary, and the remaining shallow exports and historical name assertion are removed.

No tracked file or folder and no new ignore rule was justified by this review. The remaining architecture is good enough for a thin DBCode wrapper. A signed host build and release preparation remain separate release-time gates.
