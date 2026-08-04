# 67 — Localize Approved Release Set file reading

**What to change:** Move plain JSON file checking, reading, and parsing out of the Approved Release Set module and into its existing command adapter without changing release behaviour or error messages.

**Blocked by:** None

**Type:** task

**Status:** claimed

## Comments

- 2026-08-04: Claimed after the user selected the only candidate from the post-Issue-66 architecture review.
- 2026-08-04: The user confirmed that missing, symlinked, and malformed JSON must keep their exact current safety behaviour and error messages before release validation begins.
- 2026-08-04: The maintained test seam is the `approved_release_set.cjs` command interface with local temporary files. Approved Release Set remains responsible for release records and validation, while its only command adapter owns filesystem input and output.
- 2026-08-04: This cleanup does not change DBCode, update polling, release records, profile state, application behaviour, version pins, or public documentation.
- 2026-08-04: Test-first characterization preserved the exact missing, symlinked, and malformed-file errors. The focused Approved Release Set tests passed 7 of 7, and the owning update-status contract passed 7 Approved Release Set tests plus 15 Update Status tests.
- 2026-08-04: The complete prompt-free development gate passed in 24.34 seconds without rebuilding or launching the app.

## Work

- [x] Characterize missing, symlinked, and malformed JSON through the command interface.
- [x] Move plain JSON file reading into the command adapter.
- [x] Remove filesystem knowledge from the Approved Release Set interface.
- [x] Run focused checks and the complete prompt-free development gate.
- [ ] Run final specification and engineering reviews.
