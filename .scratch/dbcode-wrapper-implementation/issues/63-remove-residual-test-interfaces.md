# 63 — Remove residual test interfaces

**What to change:** Remove the last retired diagnostic-app name checks and narrow the First Run Command Router to its production interface while preserving current single-app identity, command registration, prerequisite routing, and safe failure behaviour.

**Blocked by:** None

**Type:** task

**Status:** resolved

## Comments

- 2026-08-03: Claimed after the user approved both candidates from the post-Issue-62 architecture review.
- 2026-08-03: The maintained seams are current single-app identity behaviour and the First Run Command Router factory plus observed command registration and routing. Retired names, test-only exports, and private method spellings are not maintained interfaces.
- 2026-08-03: This cleanup does not change DBCode, Profile Setup, Runtime Setup, the focused shell, profile state, build, update polling, release behaviour, or public documentation. It does not require a version bump, host build, app launch, tag, package, publication, or push.
- 2026-08-03: Both focused characterization checks passed before editing. The router interface test then failed only on the two test-only exports and passed after their removal. The focused single-app and Profile Setup contracts passed after each slice.
- 2026-08-03: The complete prompt-free development gate passed without rebuilding or launching the app. Nine Host Session tests passed; the documented sandbox-only process-table fixture was the only skip.
- 2026-08-03: No public guide or wiki page changed because wrapper behaviour, architecture guidance, and the supported workflow remain the same.
- 2026-08-03: Final specification and engineering reviews reported no findings. The change preserves current identity and first-run behaviour while removing only historical or test-only interface knowledge.

## Work

- [x] Record passing focused characterization checks.
- [x] Remove retired diagnostic-app name checks while preserving current identity assertions.
- [x] Export only the First Run Command Router factory.
- [x] Keep behaviour-level registration and routing tests; remove redundant private-name scans.
- [x] Run focused checks and the complete prompt-free development gate.
- [x] Run final specification and engineering reviews.

## Answer

The single-app contract now checks only current identity behaviour. It no longer preserves names from the removed diagnostic app.

The First Run Command Router now exposes only its production factory. Its behaviour test reads the visible command IDs from the extension manifest and still proves early registration, runtime prerequisites, normal routing, and safe failure. The shell contract keeps one check that the extension adapter creates the router instead of scanning its private methods.

Focused characterization, red-green interface, single-app, Profile Setup, complete prompt-free development, public-source, and diff checks passed. Both final review axes found no issues. Public product and workflow guidance did not need a change.
