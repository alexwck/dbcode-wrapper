# 05 — Keep advanced DBCode features reachable without exposing an IDE

**What to build:** Preserve focused entry points for DBCode's wider feature set so the app remains about DBCode rather than silently losing useful DBCode capabilities or reopening a general-purpose code workbench.

**Blocked by:** 13 — Slim the compatible Code OSS host

**Type:** task

**Status:** resolved

- [x] A compatibility matrix inventories DBCode's declared Connections, History, Library, notebooks, notebook renderer, custom data editor, diagrams, account, AI tools, MCP provider, commands, settings, and other DBCode-owned contributions for the exact approved version.
- [x] Every supported DBCode surface has a focused menu, button, context action, file association, or direct launch route that does not require the generic Command Palette or Extensions view.
- [x] Representative notebook, custom-editor or data-file, diagram, History, Library, and settings workflows activate and render through unchanged DBCode.
- [x] AI and MCP entry points remain available where the user configures and licenses them, without creating a second AI or MCP implementation in the shell.
- [x] DBCode commands that are unsafe or meaningless in the focused product are explicitly unavailable in production rather than leaking unrelated host surfaces.
- [x] Rendered and runtime checks prove that advanced DBCode workflows do not expose generic IDE navigation or activate unrelated extensions.
- [x] Any DBCode contribution that cannot work without crossing the Unmodified Extension Boundary is recorded as an explicit compatibility failure and does not trigger modification or reverse engineering of DBCode.

## Comments

- 20 July 2026: Reopened after the user found that `Open Scratch Files Folder` raises a native macOS “No application found to open URL” alert and that the knowingly incompatible `Open Data File…` route is still presented as a normal tool. Audit every DBCode Tools entry, keep only working non-duplicate routes, and verify each retained action in the rendered app.
- 20 July 2026: The user confirmed that the licensed DBCode Entity Relationship Diagram for the sample SQLite `actor` table rendered, then closed the app for the final clean rebuild.
- The independently authored contribution policy covers all 16 contribution categories declared by `dbcode.dbcode@1.36.1`, including 170 commands and 78 settings. The release lock pins a canonical contribution digest, and every DBCode preparation validates the locally installed public manifest against that digest and policy without storing copied vendor manifest content in the repository.
- 20 July 2026: The completed audit keeps exactly six Tools routes: New DBCode Notebook, Query Builder, DBCode-only settings, AI provider choice, AI API-key setup, and Show Scratch Files in Finder. The wrapper now resolves `dbcode.scratchFiles.path`, creates it when needed, and asks macOS Finder to reveal it without changing DBCode. The signed app completed an unmocked Finder request, created the configured directory, and showed no native error sheet in the captured app window.
- 20 July 2026: Removed `Open Data File…` because this approved extension-host pair cannot register DBCode's declared custom editor; Connections and DBCode table grids already cover data entry. Also removed the duplicate AI model route, ineffective manual MCP lifecycle controls, and the non-working duplicate Notebook and Query Builder tree shortcuts. DBCode's automatic MCP provider, MCP settings, diagrams, object actions, notebook, Query Builder, History, Library, table editors, and result grids remain available where they work.
- The final signed app passed 25 rendered checks with no recorded errors. The run covered the exact six-item Tools inventory, each retained workflow, removed-route absence, locked DBCode-only settings, Connections Home, Database Explorer, notebook, Query Builder, diagram access, History, Library, table and query grids, SQL-only opening, wide and narrow layouts, isolated extensions, relaunch, and the unmocked Finder evidence.
- The signed app remains 461,668 KiB with four reviewed built-ins and no source maps. DBCode stays external and unchanged. The rebuilt artifact SHA-256 is `40bd69a7f410834b3f3dc6475876d678c49b3e858bb489dcb36bcb730d17ce38`.
- `script/check_development.sh`, `script/test_host_contract.sh`, `script/test_host_slimming_contract.sh`, `script/test_dbcode_feature_contract.sh`, `script/test_dbcode_verifier.sh`, `script/smoke_host.sh`, strict code-sign verification, the size audit, and the complete rendered suite passed.

## Answer

Keep DBCode's advanced features available through seven proven Tools routes plus DBCode-owned contextual actions. Tools contains New DBCode Notebook, Start Python Kernel, Query Builder, DBCode Settings, AI provider choice, AI API-key setup, and Show Scratch Files in Finder. The wrapper owns only the safe Finder bridge, kernel preparation adapter, and focused navigation; notebooks, Query Builder, diagrams, History, Library, Account, AI, automatic MCP integration, table editors, exports, and result grids remain owned and rendered by the unchanged DBCode extension.

Do not show a command that always fails or repeats a better existing route. Data sources enter through Connections and DBCode's table grid, model selection stays inside the provider flow and settings, and MCP stays automatic in this release. The generic Command Palette, Extensions view, Explorer, Chat, unrestricted settings, ineffective manual MCP controls, and duplicate tree shortcuts remain unavailable.

The smaller package does not remove DBCode or extension-host APIs, so slimming by itself does not add an update problem. Independent DBCode and Code OSS updates can still change their compatibility. Treat each exact host-and-DBCode pair as one Approved Release Set: compare the locally installed public contributions and complete connection catalogue with the pinned compatibility record, rebuild, and pass the source, package, rendered, licence, representative database, persistence, size, and signature gates before promotion. PostgreSQL, DuckDB, Parquet, and SQLite are fixtures rather than an allowlist. If a removed built-in becomes necessary, restore the `all_built_ins` policy and retest that pair. [Issue 06](./06-show-update-availability-from-official-metadata.md) reports host and DBCode availability separately; [issue 07](./07-promote-and-roll-back-approved-release-sets.md) promotes or restores only complete tested pairs.
