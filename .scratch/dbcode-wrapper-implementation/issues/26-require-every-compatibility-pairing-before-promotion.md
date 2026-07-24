# 26 — Require every compatibility pairing before promotion

**What to build:** Make the controlled-upgrade promotion rule match final acceptance by requiring every independently tested current/candidate host and DBCode pairing to pass.

**Blocked by:** 07

**Type:** task

**Status:** resolved

- [x] The matrix still runs `H0/D0`, `H0/D1`, `H1/D0`, and `H1/D1` as four independent receipts.
- [x] `promotion_ready` and matrix status are true only when all four receipts pass.
- [x] Promotion rejects a matrix if any pairing failed, mutated its bundle, or observed surprise update behaviour.
- [x] A focused source test forces one mixed pairing to fail and proves that the matrix and promotion fail closed.
- [x] The public README, architecture overview, host guide, command guide, implementation map, and ticket 07 answer describe the same rule.

## Comments

- 24 July 2026: Ticket 08 final verification already required all four pairings to pass, while the controlled-upgrade matrix itself treated only `H0/D0` and `H1/D1` as promotion blockers. The real final matrix passed all four, so tightening this rule changes no accepted evidence; it removes the policy mismatch before release.

## Answer

Every current/candidate host and DBCode pairing is now a promotion gate, not an informational side result. A failure in the host-only, DBCode-only, baseline, or intended combined pairing leaves the matrix failed and prevents promotion of the candidate Approved Release Set.
