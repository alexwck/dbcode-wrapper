# 65 — Add a local BSON result viewer

**What to change:** Add a small wrapper-owned viewer that turns explicitly pasted or opened MongoDB Extended JSON into a readable tree and table while preserving BSON type information and the original raw JSON.

**Blocked by:** None

**Type:** task

**Status:** resolved

## Comments

- 2026-08-03: Claimed after the user confirmed this is a regular workflow, rejected field projection as the normal answer, and approved the local companion design.
- 2026-08-03: This is a deliberate narrow exception to the current "no second results renderer" boundary. DBCode still owns query execution and its result grid. The wrapper viewer receives data only through an explicit clipboard or file action and does not inspect DBCode internals, connect to a database, monitor the clipboard, use the network, send telemetry, or persist result data.
- 2026-08-03: Fixtures and automated checks must use small synthetic values only. They must not include the private sample data supplied during the design discussion.
- 2026-08-03: The implemented display model recognizes exact canonical Extended JSON wrappers, keeps ordinary strings distinct, retains the original raw text, and bounds accepted input at 10 MiB, 50,000 display values, 200 levels, 5,000 rendered tree nodes, and 5,000 rendered table rows. The tree renders deeper branches lazily.
- 2026-08-03: The focused viewer, feature-policy, slimming, patch-plan, and focused-shell checks passed after the final safety changes. The complete prompt-free development gate also passed without rebuilding or launching the app.
- 2026-08-03: A hardening pass replaced a copied identifier and timestamp with clearly synthetic fixture values before commit. No private record value from the design discussion remains in the viewer fixtures or tests.
- 2026-08-03: The first specification and engineering reviews found five gaps: embedded JSON was parsed before opt-in, oversized files were read before their size check, ordinary JSON numbers could lose source precision, malformed wrappers could receive BSON labels, and copy feedback was optimistic. The implementation now defers embedded parsing until requested, checks file size before and after reading, preserves each ordinary number's exact JSON lexeme, validates supported wrapper encodings, and waits for clipboard acknowledgement before showing success.
- 2026-08-03: The focused checks and complete prompt-free development gate passed again after the review fixes. Independent re-review is pending before the rendered app gate.
- 2026-08-03: Engineering re-review found four remaining Extended JSON edge cases and one missing race test. Validation now follows the documented Decimal128 exponent and precision bounds, rejects normalized invalid calendar dates, accepts one- or two-digit binary subtypes, and requires supported regular-expression options in strict alphabetical order. The file test now also proves that a file growing after the preflight check is rejected before parsing or rendering.
- 2026-08-03: The focused checks and complete prompt-free development gate passed after the final edge-case fixes. Final independent re-review remains pending before the signed build and rendered app gate.
- 2026-08-03: Final engineering review requested compatibility with valid ISO date strings containing one or two fractional-second digits. The validator now accepts one-to-three digits while retaining explicit calendar and time-range checks, and the complete prompt-free development gate passes on that final source.
- 2026-08-04: Final specification and engineering re-reviews found no actionable gaps. The remaining acceptance risk was limited to the signed app's static and rendered behavior.
- 2026-08-04: The first rendered run exposed two integration defects that source-only checks had not caught: the initial webview payload could race its ready listener, and an embedded `\n` escape became an invalid literal newline in the generated script. The presenter now installs its listener before loading HTML, and the fast suite compiles the generated webview JavaScript before acceptance.
- 2026-08-04: The final source at `49c7d5b2c97afb27f90126e93f5b5f3657882eba` passed 12 focused viewer tests and the complete prompt-free development gate. The signed build reused the exact Compiled Host, Static Host Smoke passed, and the one-profile rendered gate proved Tree, Table, Raw JSON, BSON type labels, optional embedded JSON, and search against the synthetic fixture without a database read or write, network use, or clipboard read.

## Work

- [x] Define a lossless Extended JSON display model that unwraps canonical BSON wrappers for display, keeps ordinary strings unchanged, and records each value's BSON or JSON type.
- [x] Add explicit clipboard and file commands, input-size limits, clear invalid-input errors, and a focused-shell route with a keyboard shortcut.
- [x] Add a local webview with tree, table, and raw modes; path/value/type search; copy-value actions; and optional expansion of JSON stored inside strings.
- [x] Package the viewer as a reviewed first-party extension without changing or redistributing DBCode.
- [x] Update the public product, privacy, architecture, capability, host, and current-work guidance.
- [x] Run focused checks, the complete prompt-free development gate, and final specification and engineering reviews.

## Answer

Implemented and accepted. DBCode continues to own query execution and its live results. The wrapper now offers an explicit, local-only handoff from copied or selected Extended JSON into a readable Tree, Table, or Raw JSON view. Canonical BSON wrappers show a readable value beside a separate type, ordinary strings stay strings, embedded JSON remains opt-in, and no payload is persisted or read from DBCode internals.
