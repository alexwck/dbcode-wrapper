# 47 — Open query results below the editor

**What to build:** Make DBCode's own query result editor open below the query by default at every supported window width. Keep DBCode responsible for execution, comments, result grids, Inspector, export, and copy behavior.

**Blocked by:** none

**Type:** task

**Status:** resolved

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
- 2026-07-29: Refreshed the affected OpenKnowledge overview, focused-shell module, Release Specification module, and append-only log against source commit `ca6a58c`. All 32 wiki documents lint cleanly, the dead-link count is zero, and the rendered overview was inspected.

## Answer

DBCode's own result editor now defaults below the query at every window width. The wrapper uses DBCode's public result-location setting, keeps one managed profile, and does not add another Results panel or renderer. The change will appear in the next wrapper build or release; the currently installed app was not rebuilt or launched for this source change.

DBCode does not document `Cmd+Enter` (`⌘Return`) as a default shortcut. Its SQL Editor guide documents `Ctrl+Enter`, and its getting-started guide also lists `Ctrl/Cmd+D+E`. The wrapper leaves these upstream shortcuts unchanged.

SQL comments and multi-statement files are supported. If commenting out one line still causes an error, the likely causes are an uncommented remainder of a multi-line statement, comment syntax that the connected database does not accept, missing statement terminators, or the wrong execution selection. Select the exact statement and comment the complete statement using that database's syntax.

Inspector JSON remains a view of the selected row. For several rows, use DBCode's Copy or Export action and choose JSON or JSON Pretty. DBCode does not document a full-result JSON or tree toggle, so the wrapper does not add a competing renderer.
