# 47 — Open query results below the editor

**What to build:** Make DBCode's own query result editor open below the query by default at every supported window width. Keep DBCode responsible for execution, comments, result grids, Inspector, export, and copy behavior.

**Blocked by:** none

**Type:** task

**Status:** claimed

- [x] Change the maintained result-location contract from beside-on-wide to below at every width.
- [x] Keep one managed profile and preserve DBCode's own result editor, grids, messages, Inspector, and context actions.
- [x] Explain the documented keyboard execution, SQL comment, and result-to-JSON routes in plain English.
- [x] Update the public product and host guidance without keeping the old responsive-placement process.
- [x] Run focused prompt-free contracts and the complete development gate without rebuilding or launching the app.

## Comments

- 2026-07-29: Claimed after the user asked for bottom query results and practical guidance about keyboard execution, SQL comments, and viewing several returned rows as JSON or a tree.
- 2026-07-29: Started with failing focused-shell and profile-setting contracts, then changed the wrapper to set DBCode's public `dbcode.resultLocation` preference to `below` once during shell restore. Window-width changes now affect only the compact shell layout.
- 2026-07-29: Moved the current Release Specification to schema 7. The exact released v0.1.3 schema-6 lock remains readable through the historical adapter, but its responsive result placement cannot be reused as the new host contract.
- 2026-07-29: Official DBCode guidance confirms keyboard execution, selected-statement execution, and SQL comments. Inspector JSON is row-based; Copy and Export provide JSON or JSON Pretty for several rows. No wrapper execution command or competing result renderer was added.
- 2026-07-29: The focused patch-plan, Release Specification, focused-shell, managed-profile, and fast-release acceptance contracts pass without a build, app launch, human prompt, or external service.
- 2026-07-29: `./script/check_development.sh` passed in 27.24 seconds without rebuilding or launching the app. Eleven Host Session tests passed; one sandbox-only process-table fixture was skipped as designed.

## Answer

In progress.
