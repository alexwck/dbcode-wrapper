# 03 — Ship the DBCode-focused redesign

**What to build:** Turn the working custom host into the approved production-facing database-client redesign so the user experiences a dedicated database application while unchanged DBCode and the full compatible host continue to operate internally.

**Blocked by:** 02 — Load unchanged DBCode in an isolated host profile

**Type:** task

**Status:** resolved

## Answer

Apply a small source overlay to the pinned host so its only application artifact is DBCode Wrapper with a DBCode-only redesigned Query Canvas. Keep DBCode `1.36.1` unchanged and continue to render its own editor, Results, Connections, History, Library, account, schema, messages, and licence surfaces. Results start on the right on wide windows, move below automatically on narrow windows, and can also be docked, resized, maximized, and restored by the user. Let project `.sql` files enter that same canvas through a filtered native picker, `⌘O`, Finder, or drag-and-drop without exposing a project Explorer. Keep Code OSS as the hidden compatible engine without building or maintaining a second full-workbench application.

## Comments

- 18 July 2026: The clean rebuild exposed a macOS 26.5 `iconutil` failure even though every generated PNG had the required name and dimensions. The icon build now uses a small standard-library packer that validates every PNG and writes the same standard ICNS chunks deterministically, avoiding a separate package dependency.

- 18 July 2026: The approved project-query flow keeps the database-client redesign intact. `Open SQL File…`, `⌘O`, Finder document opening, and drag-and-drop open `.sql` files as ordinary query tabs. The context bar shows the active filename, while DBCode continues to own connection selection, statement execution, and Results. A filesystem tree, full project Explorer, and generic file picker remain out of the product UI.

- 18 July 2026: The user reopened this ticket after comparing the built app with the approved redesign reference. The implementation proved the right-or-bottom pane behavior but did not carry over the database-tool visual frame inspired by Beekeeper Studio and DataGrip. The correction must match the approved redesign reference at the same viewport, including its compact database context anchored by Connections, query-local actions, restrained result chrome, spacing, borders, typography, and database-first hierarchy without adding fake connection state.

- 18 July 2026: Cleanup removed obsolete proof and predecessor diagnostic home profiles, plus generated prototype runtimes, the 7.6 GB build workspace, test output, dependency caches, screenshots, Finder metadata, and Python caches. The active DBCode Wrapper profiles and final signed app bundle remain intact.

- 18 July 2026: DBCode Wrapper is now the only application artifact, with bundle identifier `io.alexabelle.dbcodewrapper`. The separate full-workbench diagnostic app, profile, identity, and launch path were removed. Code OSS remains the hidden compatible engine, and `host/release-lock.json` is the single source for the wrapper identity and the approved Code OSS and DBCode pair.

- 18 July 2026: The final signed app artifact has SHA-256 `c489eac1dccfe67bd780d28327c9b459a529e939c2fb10c7125a68cd3de36038` and loads verified DBCode `1.36.1`. The full static suite, strict signature check, independent-launch smoke test, and rendered interaction test passed. Rendered checks used an isolated QA profile and mock Keychain and covered redesigned right-side Results by default, real pointer dragging below and back, both resize directions, maximize and restore, drawers, keyboard focus, narrow-window layout, relaunch persistence, overflow, and renderer errors.

- 18 July 2026: The redesign and project-query workflow are separate ordered host overlays. The Database menu is the single native owner of `⌘O`; `Open SQL File…` and the visible redesign action use one SQL-only command. The command captures its Code OSS services before awaiting the picker, then opens the selected files as pinned query tabs without a workspace-trust or Explorer flow. The rendered proof opened `project-query.sql`, blocked a non-SQL drop, and showed only factual state: the active filename and `DBCode active` after DBCode activation.

- 18 July 2026: Fresh approved-reference and final captures were compared at the same 1440×900 viewport. The final frame retains the approved dark database-client hierarchy, DBCode-branded title, Connections-first context bar, query canvas, right-side Results default, and restrained borders and spacing. The isolated profile intentionally leaves the DBCode terms notice visible and has no real result data; the user's earlier real-profile PostgreSQL, DuckDB, Parquet, licence, and persistence proofs remain the data-backed acceptance evidence.

- 18 July 2026: The final real-profile proof passed after a complete quit and relaunch. The user confirmed that the lifetime licence and saved PostgreSQL and DuckDB connections remained available without re-entry. PostgreSQL reported read-only mode and returned 3 rows with amount sum `75.00`; DuckDB and Parquet each returned 3 rows with amount sum `61.50`. The exact signed app, restored DBCode activation log, unchanged normal VS Code and VSCodium profiles, and a non-secret durable-state fingerprint were verified during acceptance. Generated proof data is reproducible and is intentionally not kept in the repository.

- 18 July 2026: The proof deliberately avoids reading credentials or depending on undocumented DBCode storage keys. Fresh observations after relaunch establish connection persistence, while automation verifies the app identity, DBCode package, clean Keychain logs, durable private profile, and proof lifecycle.

- 18 July 2026: The obsolete predecessor Safe Storage service was absent from Keychain. Old predecessor profile directories and the proof PostgreSQL container holding the obsolete test credential were removed. The active app now uses only the DBCode Wrapper profiles and identity.

- 18 July 2026: Query-document entry is intentionally SQL-only. The app does not claim DuckDB, SQLite, Parquet, CSV, or other data-source files as editable documents; those formats enter through DBCode Connections. VSCodium remains the reproducible packaging layer around the Code OSS runtime, and the generated upstream `vscode` work directory remains ignored build data rather than a product folder.

- [x] The normal production launch shows only DBCode concepts and cannot expose the generic Explorer, Source Control, Run and Debug, Extensions, terminal, Command Palette, command center, or unrelated workbench controls.
- [x] Query and Results form the primary canvas, with Results on the right by default on wide windows and automatically below the query on narrow windows.
- [x] The user can move Results below or back to the right using both drag interaction and clearly named controls, resize either orientation, and maximize or restore either pane.
- [x] DBCode Connections opens as an on-demand drawer, and DBCode query tabs, Results, Messages, History, Library, account, connection, schema, and read-only state remain reachable.
- [x] The shell presents DBCode's existing surfaces and does not introduce a second connection manager, SQL editor, result grid, history store, library, or licensing interface.
- [x] The build, release manifest, launch scripts, and tests produce and maintain only DBCode Wrapper, with no second full-workbench app identity.
- [x] Rendered UI automation uses an isolated profile and mock Keychain, while real licence, credential, and persistence checks use only the signed DBCode Wrapper identity.
- [x] Rendered interaction checks cover wide and narrow layouts, docking, resize, focus, drawer behaviour, relaunch restoration, overflow, console errors, and absence of generic IDE chrome.
- [x] The DBCode activation and Required Data Target proof still pass after the presentation patch lands.
- [x] At 1440×900, the rendered DBCode Wrapper visually matches the approved database-client redesign rather than looking like rearranged Code OSS panes; the comparison uses fresh side-by-side captures of the same state.
- [x] `Open SQL File…` and `⌘O` use an SQL-only native picker, the selected files open as query tabs with their real filenames, and no Explorer or generic IDE file flow becomes visible.
