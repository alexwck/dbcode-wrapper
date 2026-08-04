# 66 — Collapse BSON command registration

**What to change:** Remove the shallow BSON Result Viewer command router and keep both explicit commands registered directly through extension activation, without changing product behaviour.

**Blocked by:** None

**Type:** task

**Status:** claimed

## Comments

- 2026-08-04: Claimed after the user approved every candidate from the post-Issue-65 architecture review.
- 2026-08-04: The maintained test seam is extension activation plus the extension manifest. The activation test will observe both command registrations and routes before the router-only test and private implementation checks are removed.
- 2026-08-04: This cleanup does not change DBCode, the BSON display model, user-visible commands, shortcuts, profile state, update polling, release behaviour, or public documentation.
- 2026-08-04: The activation characterization passed before the refactor. Removing the router then made the activation test fail because production still required the deleted module. Registering both commands in activation restored the focused viewer suite with 11 passing tests.
- 2026-08-04: The complete prompt-free development gate passed in 23.84 seconds without rebuilding or launching the app. No public guide or wiki page changed because the product, privacy contract, architecture guidance, and supported workflow remain the same.

## Work

- [x] Make the activation test cover both explicit command routes.
- [x] Delete the shallow command-router module and register both commands during activation.
- [x] Remove router-only and private implementation checks.
- [x] Run the focused viewer checks and complete prompt-free development gate.
- [ ] Run final specification and engineering reviews.
