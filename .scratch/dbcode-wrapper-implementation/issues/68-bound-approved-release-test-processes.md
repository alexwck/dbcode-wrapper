# 68 — Bound Approved Release Set test processes

**What to change:** Add a bounded process policy to the Approved Release Set command-interface test helper so a stalled child cannot hang the prompt-free development gate, without changing production or command behaviour.

**Blocked by:** None

**Type:** task

**Status:** resolved

## Comments

- 2026-08-04: Claimed after the post-refactor review found that the new failure helper launched the command adapter without the timeout required by the verification policy.
- 2026-08-04: The maintained seam remains the existing `approved_release_set.cjs` command interface. This fix changes only its test process runner and must keep expected command rejection separate from timeout, spawn, and signal failures.
- 2026-08-04: The two command assertions now share one runner with a 30-second timeout and `SIGTERM`. Timeout, spawn, signal, and missing-status failures stop the test as infrastructure errors; an ordinary nonzero exit remains an expected command rejection.
- 2026-08-04: The focused update-status contract passed 7 Approved Release Set tests and 15 Update Status tests. The complete prompt-free development gate also passed without rebuilding or launching the app.
- 2026-08-04: Final specification and engineering reviews reported no findings. They confirmed that production and command behaviour remain unchanged and that the earlier duplicated process-launch policy is gone.

## Work

- [x] Give the shared test command runner a bounded timeout and termination signal.
- [x] Keep ordinary command acceptance and expected rejection behaviour unchanged.
- [x] Run the focused update-status contract and complete prompt-free development gate.
- [x] Run final specification and engineering reviews.

## Answer

The Approved Release Set command-interface test now uses one shared bounded process runner. It stops a stalled command after 30 seconds with `SIGTERM` and reports timeout, spawn, signal, or missing-status failures as test infrastructure problems instead of treating them as ordinary invalid release records.

The focused Approved Release Set and Update Status contracts, complete prompt-free development gate, and both final review axes passed. Production, release, and command behaviour did not change.
