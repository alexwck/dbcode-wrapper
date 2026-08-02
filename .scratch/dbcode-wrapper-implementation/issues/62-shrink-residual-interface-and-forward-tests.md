# 62 — Shrink residual interface and keep tests forward-facing

**What to change:** Remove Host Configuration values that exist only for tests, make those tests read the existing Release Specification purpose records, and remove retired-name source scans while preserving current command, result, stale-log, and old-record behaviour checks.

**Blocked by:** None

**Type:** task

**Status:** claimed

## Comments

- 2026-08-02: Claimed after the user approved both remaining candidates from the architecture review. The agreed test seams are the Release Specification purpose records and the current release command and result behaviour.
- 2026-08-02: This cleanup does not change the DBCode extension, focused shell, profile, build, release flow, update polling, or public product behaviour. It does not require a version bump, host build, app launch, tag, package, publication, or push.
- 2026-08-02: Current stale-log argument rejection and old acceptance-record rejection remain behavioural checks. Only tests that preserve retired names by scanning source are candidates for removal.
- 2026-08-02: Profile-path and release-identity tests now read their existing purpose records. Host Configuration no longer materializes the three test-only values, and the residual retired-name scans are gone. Focused Release Specification, profile-path, identity, acceptance, and single-app checks passed.
- 2026-08-02: The complete prompt-free development gate passed in 22.37 seconds without building or launching the app. Nine Host Session tests passed; the documented sandbox-only process-table fixture was the only skip.

## Work

- [x] Make profile-path and release-identity tests use existing purpose records.
- [x] Remove the three test-only Host Configuration values.
- [x] Remove retired-name source scans while preserving current behavioural checks.
- [x] Keep maintained guidance forward-facing and avoid unnecessary public documentation changes.
- [x] Run focused checks and the complete prompt-free development gate.
- [ ] Run final specification and engineering reviews.
