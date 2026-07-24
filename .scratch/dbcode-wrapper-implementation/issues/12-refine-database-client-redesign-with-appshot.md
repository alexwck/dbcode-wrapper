# 12 — Refine the database-client redesign with Appshot

**What to build:** Use the user's Appshot feedback on the current signed application to turn the approved database-client direction into precise visual and interaction requirements, then apply the accepted batch without exposing a general-purpose IDE.

**Blocked by:** 11 — Decide the minimum maintainable DBCode host

**Type:** prototype

**Status:** resolved

## Appshot audit — 18 July 2026

### Audit scope

The supplied `project-query.sql` and `scratch.sql` Appshot captures cover the main wide-window query workspace, the empty Connections drawer, the top database context bar, and an empty Results surface. They do not yet cover a narrow window, populated Results, or the secondary drawers after selection.

### User goal and accessibility target

Every visible action should have one clear purpose, the macOS window controls must never cover application controls, and DBCode features should remain reachable without presenting the complete multi-section extension sidebar. Icon-only controls still need reliable tooltips, accessible names, keyboard focus, and visible selected states.

### Strengths

- Query and Results remain the dominant workspace.
- The current query name and DBCode activation state are visible without generic IDE navigation.
- Connections, SQL opening, query creation, History, Library, and Account already have focused routes in the top bar.

### UX risks and accepted changes

1. **Window controls overlap Connections.** The macOS close, minimise, and maximise controls sit over the first application action. Reserve a native-control safe area at the left of the context bar, or place the native controls entirely in the separate title row. The Connections target must begin after that reserved area at every window width.
2. **Results placement is over-labelled.** Keep the right and below layout icons, remove the visible `Results right` and `Results below` text, and retain their tooltip, accessible name, selected state, and narrow-window disabled state.
3. **The drawer does not match the chosen action.** Connections currently exposes connection tools plus Library, History, and Account even though those have their own top-bar actions. Connections should show only Connections and its related Tunnels, Authentication Profiles, and conditional Streams sections. History, Library, and Account should each show only their own DBCode view.
4. **The six-dot control is unclear.** It is the drag handle for moving Results between right and below. Remove it from the global context bar and preserve direct manipulation by making the Results surface or its own header the drag source. The two placement icons remain available as explicit alternatives.

### Accessibility risks

- The Appshot accessibility tree exposes several icon controls only as generic buttons. The rebuilt app must prove that every icon-only action has a useful accessible name rather than relying on its graphic.
- The editor reports that screen-reader-optimised mode is not active. Screenshot evidence cannot establish editor accessibility, keyboard order, tooltip behaviour, or spoken state changes; those require rendered interaction and assistive-technology checks.
- The traffic-light overlap can obstruct the Connections pointer target and makes the visible target smaller than intended.

### Evidence limits

The exact native-window-control position varies with the packaged Electron window and must be checked in a signed macOS build. The two supplied captures do not prove narrow-window reflow, populated drawer height, populated Results, drag behaviour, or keyboard operation.

- [x] Appshot feedback is captured against realistic DBCode states at wide and narrow window sizes, including Connections, a project SQL query, Results, and at least one secondary DBCode surface.
- [x] Use the product-design audit skill to group the evidence by visual hierarchy, navigation, density, interaction, accessibility, and database-workflow impact before proposing changes.
- [x] Use the design-taste frontend skill only after the findings are accepted, so implementation rules are concrete and do not drift into generic dashboard or IDE styling.
- [x] Requirements use descriptive product language and observable behaviour; vague prototype shorthand does not appear in active design, source, tests, or tickets.
- [x] The main canvas remains query plus movable Results, project `.sql` files remain query documents, and database or data files continue to enter through DBCode Connections or its custom data editor.
- [x] Connections, History, Library, Account, messages, notebooks, custom editors, and other retained surfaces remain DBCode-owned functionality rather than shell reimplementations.
- [x] Codebase changes stay local to named shell seams, with visual layout, query entry, and DBCode command routing kept separate enough to update and test independently.
- [x] Fast source and contract checks run during the feedback batch; one full signed build and rendered interaction pass runs after the batch is accepted.
- [x] The user accepts fresh Appshot evidence from the rebuilt app before host slimming or profile-migration work begins.

## Implementation evidence — 18 July 2026

- **Design read:** Preserve the dense database-client workspace for one licensed user, use restrained native developer-tool styling, and build on DBCode and Code OSS rather than introducing a generic dashboard or a second design system. The relevant design dials were low visual variance, low motion, and high information density.
- The signed checkpoint is `dist/DBCode Wrapper.app`. Its manifest pins VSCodium `1.126.04524`, Code OSS `1.126.0`, and unchanged external DBCode `1.36.1`, with Apple-silicon architecture, bundle identifier `io.alexabelle.dbcodewrapper`, and artifact SHA-256 `e849aa78024dbce92f8ccf3c7c45618961ecfa73aa249e822090b7cdf4767ac7`.
- The focused-shell source contracts first exposed the Results visibility fault: the DBCode Results iframe existed, but the rendered centre-point hit a covering `div`. The scoped visibility repair was then applied and the complete rendered check passed.
- The rendered check opened a real isolated DBCode sample database, ran `SELECT 1 AS project_query_proof` from `project-query.sql`, and verified the visible `project_query_proof` column and one result row inside DBCode's own Results webview.
- Native wide and narrow captures prove that the macOS traffic lights no longer cover Connections, the Results placement controls are icon-only, narrow layout places Results below the query, and populated Results remain visible.
- Connections now exposes only Connections, Tunnels, Authentication Profiles, and conditional Streams. History, Library, and Account each expose only their matching DBCode-owned drawer view.
- The unclear global six-dot handle is gone. The Results header is the drag surface, while the two icon controls remain keyboard-accessible alternatives with names, tooltips, selected state, and narrow-window disabled state.
- The test moved Results both ways by dragging its header, resized both dock positions, maximised and restored both surfaces, forced narrow-window reflow, restored the preferred right dock after widening, and proved dock persistence across relaunch.
- `output/playwright/ticket-03-rendered-report.json` finished with `status: passed` and no errors. The pinned DBCode package still emits its known missing `out/` prefix warning for the query-success gutter icon; query execution and populated Results are unaffected.
- `script/check_development.sh` passed all source, profile, overlay, and focused-shell contracts after the final patches. The full host build, extension typechecks, strict code signing, and rendered interaction run also passed.

## Appshot audit — 19 July 2026

### Audit scope

The supplied `Sample - SQLite/main/actor` and `DBCode Wrapper` captures cover a populated DBCode table editor, an Account-only drawer, the two-row macOS title area, an empty SQL Results panel beside a non-query surface, and the generic Code OSS panel context menu.

### User goal and accessibility target

The shell should explain itself through placement rather than duplicate labels. Native window controls belong beside the window title, each DBCode route should expose only its own actions, and SQL Results should appear only when a SQL query can produce them. Contextual controls need clear names, keyboard focus, and a visible restore state.

### Strengths

- The actor table is DBCode's real data editor and already provides a complete browse, filter, edit, export, and pagination surface.
- The Account route now contains only the DBCode Account view.
- Query and Results layout choices remain reachable without reopening generic workbench navigation.

### UX risks and accepted direction

1. **The traffic lights are vertically tied to the 82-pixel custom title area.** Keep the existing 30-pixel native title row, place the macOS controls inside it beside the centred window title, and let the database toolbar use its full width below.
2. **The toolbar repeats editor information.** Remove the inert `Query` badge and active editor name because the native window title and editor tab already provide that context. Keep the DBCode activation status because it describes whether the licensed feature surface is available.
3. **The sidebar overflow reopens hidden sections.** Remove the generic `Views and More Actions...` control while preserving direct DBCode actions such as refresh or sign out.
4. **Two adjacent full-screen icons have no local context.** Move query expand/restore into the query editor header and Results expand/restore into the Results header. Use the same expand/restore icon family only after placement makes the affected surface unambiguous.
5. **Notifications look detached from the wrapper.** Continue using Code OSS's accessible notification service, but style its toast container with the wrapper's raised surface, border, radius, spacing, and shadow tokens.
6. **A DBCode table grid and an empty SQL Results panel appear together.** The table grid is already the result surface. Give DBCode table, custom-editor, notebook, Account, and other non-SQL content the full main canvas; automatically restore the Results panel only for SQL query documents. Do not move or reimplement DBCode's grid.
7. **The Results header context menu exposes generic IDE panels.** Suppress that menu in the focused production shell. Do not retain the generic Terminal: it is a full Code OSS terminal rather than a DBCode database feature. A future database-specific console would need its own explicit product requirement.

### Accessibility risks and evidence limits

- Moving controls must preserve their accessible names, tooltips, keyboard order, pressed state, and dynamic `Expand` or `Restore` wording.
- Hiding non-SQL Results must not trap focus in the hidden panel or silently discard a query result when returning to a SQL tab.
- Appshot proves visible hierarchy and exposed menu items, but native traffic-light position, focus behaviour, context-menu suppression, notifications, and automatic surface switching require a rebuilt signed app and rendered interaction checks.

### Second refinement batch

- [x] macOS traffic lights occupy the 30-pixel native title row and no longer consume database-toolbar space.
- [x] The toolbar contains no inert Query badge or duplicate editor name.
- [x] Sidebar routes expose no generic section-switching overflow while retained DBCode actions still work.
- [x] Query and Results each own one contextual expand/restore control with accessible dynamic state.
- [x] Notification toasts use the wrapper's existing visual tokens without replacing the Code OSS notification service.
- [x] SQL documents show movable Results; DBCode table and other non-SQL surfaces use the full main canvas and restore Results when a SQL document becomes active again.
- [x] Right-clicking the Results header does not expose Problems, Output, Debug Console, Terminal, Ports, or other generic panel choices.
- [x] Fresh native wide and narrow captures, a populated SQL result, a populated table editor, keyboard checks, relaunch persistence, static contracts, strict signing, and the complete rendered test pass.
- [ ] The user accepts the second Appshot refinement batch before issue 12 is resolved.

## Second refinement implementation evidence — 19 July 2026

- The ordered `0250-dbcode-wrapper-contextual-surfaces.patch` keeps the native 30-pixel title row, removes duplicate query labels, moves expand and restore controls into their owned surfaces, styles the existing notification service, and synchronises SQL and non-SQL surface visibility.
- The initial rendered regression showed that a visible generic Code OSS panel could prevent DBCode Results from opening. The fix now checks for DBCode's actual Results surface rather than treating any visible panel as Results.
- A strengthened rendered check caught the still-visible sidebar overflow. Code OSS identifies this action as `toolbar-more`, and its label is nested inside the action item; the final rule targets that real structure while preserving Account refresh and sign-out actions.
- Review of the first implementation pass found two timing and ownership gaps: History, Library, or Account could leave SQL Results visible, and an older asynchronous Results open could finish after a fast SQL-to-table switch. The final surface synchronisation now treats secondary DBCode routes as the active workspace and rechecks the editor context after every asynchronous Results open.
- The signed bundle at `dist/DBCode Wrapper.app` has artifact SHA-256 `2532c111d7b5bf45adf2c3b069f4ff44c8a4ec4a36eaf41d251257e33dc1f0b3`, bundle identifier `io.alexabelle.dbcodewrapper`, and a verified stable local-development designated requirement.
- The complete rendered run passed 21 checks with no renderer errors. It executed `SELECT 1 AS project_query_proof`, verified one populated result row, opened the populated `actor` table, proved that the table uses the full canvas without empty SQL Results, and proved that returning to the SQL tab restores its populated Results.
- The rendered run also proved native window-control placement, icon-only dock controls, tooltip text and natural keyboard order, contextual expand and restore state, drag and resize in both dock positions, narrow-window reflow, persisted dock choice, notification styling, sidebar overflow removal, secondary-route Results ownership, rapid SQL-to-table switching, and suppression of the generic Results context menu.
- Fresh evidence is in `output/playwright/ticket-03-signed-window-wide.png`, `ticket-03-sample-results.png`, `ticket-03-sample-actor-table.png`, `ticket-03-narrow.png`, and `ticket-03-rendered-report.json`.
- `script/check_development.sh`, `script/smoke_host.sh --static-only`, JavaScript and shell syntax checks, strict code-sign verification, manifest digest verification, and `git diff --check` passed after the final selector correction.

## Three-surface refinement requirements — 19 July 2026

### Responsibilities

1. **Connections Home** uses DBCode's unchanged card-based panel view for creating a connection, importing connections, opening the sample database, and opening a SQL file. The top Connections action opens this as the primary connection entry rather than opening the database tree.
2. **Database Explorer** keeps DBCode's unchanged connection, schema, table, and view tree. It is hidden by default and opens only when the user asks to browse database objects.
3. **Query Results** use DBCode's unchanged result grid beside or below the SQL query. The wrapper must not open a second panel and label it Results.

### Third refinement batch

- [x] Connections Home, Database Explorer, and Query Results are three distinct DBCode-owned surfaces.
- [x] Connections opens the card-based DBCode Home in the main canvas and toggles it closed without exposing generic panel controls.
- [x] Database Explorer has one clearly named toolbar action and is the only route that opens the connection tree drawer.
- [x] Opening a query, secondary DBCode route, or Database Explorer closes Connections Home cleanly.
- [x] SQL execution opens DBCode's own result grid beside the query by default, with a direct choice to place new results below it.
- [x] The wrapper no longer creates a Results header, Results drag surface, Results maximize controls, or automatic Results panel lifecycle.
- [x] Fresh signed wide and narrow captures prove the new surface ownership, including card-based connection creation, schema browsing, and populated query output.
- [x] Fast contracts, strict signing, the complete rendered interaction check, and a final code review pass.

## Third refinement implementation evidence — 19 July 2026

- The ordered `0260-dbcode-wrapper-connections-home.patch` changes only the focused Code OSS shell. The pinned external DBCode `1.36.1` package remains unchanged and supplies Connections Home, Database Explorer, query execution, and result grids through its public commands, views, and `dbcode.resultLocation` setting.
- Connections now opens DBCode's card-based Home as a full main-canvas surface. Database Explorer separately opens only the connection tree drawer. Opening SQL, Explorer, History, Library, or Account closes Home before routing to the requested DBCode-owned surface. Pressing Connections a second time closes Home, and a drawer left open at quit is hidden on the next launch.
- The wrapper's duplicate Results panel lifecycle, title, drag handle, docking, resize, and maximise controls were removed. A new SQL result opens through DBCode beside the query by default, or below it when selected; the selected public DBCode setting survives relaunch and is not overwritten by profile merging.
- The signed app exercised Home's New connection, Import connections, Sample database, and Open SQL file handoffs, opened the sample SQLite database, ran `SELECT 1 AS project_query_proof;`, and rendered one real result row. Exact geometry proved the DBCode grid beside the query at `x=720` in a 1440-pixel-wide window and below the query at `y=491` in a 900-pixel-high window. The populated `actor` table also remained a DBCode-owned editor beside Database Explorer.
- Fresh wide and narrow evidence is in `output/playwright/ticket-03-connections-home.png`, `ticket-03-database-explorer.png`, `ticket-03-results-beside.png`, `ticket-03-results-below.png`, `ticket-03-sample-actor-table.png`, and `ticket-03-narrow-connections-home.png`.
- The rebuilt signed bundle has artifact SHA-256 `2501aa4f0564ac8f1169523c32d0268ce6ee7276f470e500af71b52be28ce818`. `output/playwright/ticket-03-rendered-report.json` passed all 15 checks with no errors. Relaunch produced one bounded early `dbcode.panelView` registration warning while the hidden Home view waited for DBCode activation; Home subsequently opened normally and the warning did not repeat.
- The focused-shell release metadata now records DBCode's public result locations as `beside` and `below`, replacing the removed wrapper-panel position fields. Source, profile, overlay, syntax, focused-shell, single-app identity, signing, and signed rendered checks passed.
- The third refinement code review found no unresolved blocking issue. Fresh Appshot evidence is ready for the user's final visual acceptance; this issue remains claimed until that review is complete.

## Complete shell audit and approved final batch — 19 July 2026

This batch follows the complete signed-shell audit recorded in the Figma board [DBCode Wrapper — Approved Shell Simplification Audit](https://www.figma.com/design/o7uOYAmSmwHTcuH4CXX9oP/DBCode-Wrapper-%E2%80%94-Approved-Shell-Simplification-Audit). It covers DBCode-owned Home and data grids, database navigation, SQL workflow, secondary routes, notifications, and the context menus available through right-click.

The work stays as one final implementation batch inside issue 12. The changes share the same focused-shell seam and rendered acceptance path, so splitting them would create overlapping patches and repeated Code OSS builds without producing independently useful releases. Issue 13 remains blocked until this batch passes and issue 12 is resolved.

### Approved responsibilities

1. **Connections Home** remains DBCode's unchanged card-based connection entry and becomes the clear home for connection management.
2. **Database Explorer** shows database objects only. Tunnels and Authentication Profiles remain unchanged DBCode views but move under the Connections workflow rather than appearing as explorer sections.
3. **SQL queries and results** use DBCode's unchanged query and result editors. The wrapper exposes no result-position controls, duplicate Results panel, or competing result grid.
4. **Queries** groups DBCode History and Library as related saved-query routes. **Account** moves to the right side because it is application identity and licensing, not database navigation.
5. **Contextual actions** stay local to the surface they affect. Empty overflow actions, generic split controls, and duplicate query-title actions disappear. The SQL editor gets only the small database-relevant context menu it needs; DBCode grid menus remain unchanged.

### Final refinement batch

- [x] The two top-right result-position controls are removed with no replacement control or alternate shell route that exposes the same setting.
- [x] A new SQL result opens in one useful DBCode result editor beside the query on a wide window and below it when narrow space makes a side-by-side layout unusable.
- [x] Empty or stale editor groups are cleaned up without closing a populated result, losing query state, trapping focus, or affecting DBCode table, custom-editor, notebook, Account, or Connections Home surfaces.
- [x] Database Explorer contains only the connection, schema, table, view, type, and other database-object tree content needed for browsing.
- [x] Tunnels and Authentication Profiles remain reachable through the Connections workflow without changing or reimplementing their DBCode-owned views.
- [x] History and Library are grouped under one Queries route, while Account is available from the right side of the database toolbar.
- [x] Empty ellipses, generic editor-group split actions, duplicate query-title actions, and other shell controls without a DBCode-focused purpose are absent from the normal application.
- [ ] The SQL editor exposes a minimal database-relevant context menu. DBCode table and result-grid context menus, tabs, side tools, and webviews remain unchanged.
- [ ] Connections Home, the narrow Connections layout, DBCode table and result grids, grid side tools, notifications, History, Library, Account, and retained advanced DBCode surfaces remain reachable and visually intact.
- [x] The pinned external DBCode package and its digest remain unchanged; the wrapper does not patch, copy into the signed bundle, or reimplement DBCode functionality.
- [x] Fast contracts cover the new information architecture and absence of removed controls before the expensive build begins.
- [ ] One fresh signed wide-and-narrow acceptance run covers SQL query execution, populated DBCode results, stale-group cleanup, database browsing, connection management, context menus, keyboard focus, notification presentation, relaunch persistence, and absence of generic IDE chrome.
- [ ] PostgreSQL, DuckDB, Parquet, licence persistence, saved connections, signing, manifest integrity, and renderer-error checks still pass for the rebuilt application.
- [ ] The user accepts fresh Appshot evidence from the rebuilt application before issue 12 is resolved and issue 13 becomes the frontier.

## Comments

- 19 July 2026: The user chose the three-surface model after confirming that DBCode already renders query output in its own table grid and that its card-based connection entry is preferable to the empty connection-tree drawer. Connections Home is the primary entry, Database Explorer is the contextual tree, and Query Results use DBCode's own grid beside or below the query.

- 19 July 2026: The user approved the complete shell audit and confirmed that it should land as one final batch in this claimed ticket. The result-position icons will be removed rather than replaced, the wrapper will manage one useful result layout automatically, database navigation will be simplified around Connections, Explorer, Queries, and Account, and unchanged DBCode remains the ownership boundary.

- 20 July 2026: The user reported that the generic bottom pane had returned with Problems, Output, Debug Console, Terminal, Ports, and DBCode tabs, with Terminal selected. The accepted focused shell must never show that pane by default or let a generic Code OSS panel replace DBCode Connections Home.

- 20 July 2026: The user confirmed that the rebuilt normal-profile application looks good after the generic panel fix. This is the final visual acceptance for issue 12.

## Final refinement implementation evidence — 19 July 2026

- The ordered `0270-dbcode-wrapper-shell-simplification.patch` contains the complete final shell change: it removes result-position controls and redundant editor actions, groups Connections and Queries routes, moves Account to the right, filters the core SQL editor context menu, and accumulates rapid close events so every newly empty editor group is checked.
- The same single patch gives DBCode a managed `beside` value before extension activation, waits for DBCode to register the setting, serialises responsive updates through a visible ready state, and shows Active Streams only while DBCode's own `dbcode.hasActiveStreams` condition is active. Keeping this work in one overlay limits the Code OSS update surface.
- The pinned external package is still unchanged `dbcode.dbcode@1.36.1` with VSIX SHA-256 `e50554b0f83d105216216708202d39afd89878cdadf3b1d55eaad34b2338078c`. It remains installed in the external private profile rather than copied into the signed app.
- The final signed app has artifact SHA-256 `f2564f6c10bb41f3a400acaf503759e958c1414531179b86d9ea87e3d5b6da0a`, bundle identifier `io.alexabelle.dbcodewrapper`, and a valid stable local-development designated requirement.
- `output/playwright/ticket-03-rendered-report.json` passed 19 checks with no renderer or console errors. A real DBCode query rendered beside its SQL editor at `x=720` in a 1440-pixel window, then below it at `y=441` in a 900-pixel window. The run also covered populated sample-table browsing, Connections Home, Explorer, Tunnels, Authentication Profiles, History, Library, Account, notifications, empty-group cleanup, conditional Streams visibility, and relaunch behavior.
- Fresh visual evidence is in `output/playwright/ticket-03-connections-home.png`, `ticket-03-database-explorer.png`, `ticket-03-history.png`, `ticket-03-results-beside.png`, `ticket-03-results-below.png`, `ticket-03-sample-actor-table.png`, `ticket-03-narrow-connections-home.png`, and the signed wide and narrow captures.
- macOS Playwright did not surface Monaco's SQL context menu from synthetic right-click or keyboard context-menu gestures. Static source contracts prove that the wrapper keeps only DBCode commands plus Cut, Copy, Paste, and Select All, and the pinned DBCode manifest proves the retained commands still exist. A real mouse right-click remains part of user acceptance. Active Streams is likewise conditionally retained but cannot be visually exercised without a live stream.
- `script/check_development.sh`, `script/smoke_host.sh`, JavaScript syntax, strict signing, manifest integrity, and the complete signed rendered flow pass. PostgreSQL, DuckDB, Parquet, licence persistence, saved connections, and final visual acceptance remain unchecked because they require the user's normal profile and credentials after this rebuild.
- The final review found and closed two timing edges before packaging: close events from several editor groups are now accumulated instead of replacing one another, and automatic result-layout changes expose a settled ready state only after DBCode's observable setting has updated. The complete patch was regenerated as one overlay and compiled with zero TypeScript errors.

## Generic panel acceptance fix — 20 July 2026

- The old signed application failed a new rendered regression: while Connections Home was open, the Code OSS Problems shortcut removed the real DBCode Home view but left the wrapper's internal `Connections Home open` state set. A later panel restore could then be trusted as Connections Home and expose Terminal, matching the user's screenshot.
- The focused shell now checks the panel's actual visible container and DBCode view before allowing it to remain open. It clears stale Connections Home state, hides any generic panel after startup or an asynchronous surface change, and blocks the standard panel shortcuts for Problems, Output, Debug Console, Terminal, and the generic panel toggle.
- The regression that failed on the old binary now passes on the rebuilt signed application. The complete rendered run passed all 19 checks with no recorded errors, including Connections Home ownership, real DBCode query results, the populated sample table, wide and narrow layouts, empty-group cleanup, and relaunch with the sidebar and generic panel hidden.
- `script/check_development.sh` and `script/smoke_host.sh` pass. Code OSS compiled with zero errors, strict signing passed, and the rebuilt `dist/DBCode Wrapper.app` has artifact SHA-256 `a06598ce777c5e01469f6c4ece927725d9238387ee4420217aee8f7175e2caf6`.
- The external `dbcode.dbcode@1.36.1` package remains unchanged. The user accepted the normal-profile shell; the credential-backed compatibility matrix remains a required gate for issue 13's host-slimming changes.

## Answer

Keep the unchanged licensed DBCode extension on the pinned Code OSS host, but present it as a focused database application. The accepted shell uses DBCode Connections Home for connection entry, Database Explorer for database objects, Queries for History and Library, Account on the right, and DBCode's own result editors beside or below SQL automatically. Generic IDE navigation, duplicate Results controls, empty editor groups, and the Code OSS bottom panel stay out of the normal application.

The user accepted the rebuilt normal-profile application on 20 July 2026. Issue 13 now owns the next compatibility gate: measure and slim the host only where a complete signed rebuild still preserves licence and Keychain persistence, saved connections, PostgreSQL, DuckDB, Parquet, project SQL files, result grids, and retained DBCode surfaces.
