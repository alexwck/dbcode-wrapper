# 58 — Finish fast-release architecture cleanup

**What to change:** Keep routine DBCode Wrapper releases fast by making the Patch Plan own build-relevant Compiled Host identity, removing three shallow interface leftovers, narrowing Host Configuration toward purpose-level records, and testing Profile Recovery through its maintained worker seam.

**Blocked by:** None

**Type:** task

**Status:** claimed

## Comments

- 2026-08-02: Claimed after the user approved all four candidates from the fresh architecture review. No tracked file or folder is being removed. Generated evidence stays protected, DBCode remains unchanged and external, and the normal prompt-free release path remains the only supported path.
- 2026-08-02: The confirmed test seams are: Compiled Host input identity derived through the Patch Plan; the maintained Generated Workspace Retention and connection-catalogue export surfaces plus current Profile Layout behaviour; existing shell task behaviour while Host Configuration becomes narrower; and Profile Recovery through its `run` worker path with operating-system behaviour behind an adapter.

## Work

- [ ] Make descriptive Patch Plan wording irrelevant to the Compiled Host input ID while retaining every build-relevant field.
- [ ] Remove the unused `contains` and `NORMALIZATION` exports and the retired-helper-name assertion.
- [ ] Replace broad Host Configuration globals with purpose-level records where current callers justify the seam.
- [ ] Make Profile Recovery tests exercise `run` instead of exported implementation helpers.
- [ ] Keep public and architecture documentation forward-facing and in plain English.
- [ ] Run focused red-green checks, the complete prompt-free development gate, and two-axis review.

## Answer

Pending.
