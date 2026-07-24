# 10 — Clarify the host and streamline ongoing development

**What to build:** Make the repository say exactly which layer does what, keep query-document entry separate from database-source entry, remove superseded exploration material, and document a development loop that does not rebuild the packaged host for every review.

**Blocked by:** 03 — Ship the DBCode-focused redesign

**Type:** task

**Status:** resolved

## Answer

Keep VSCodium as the reproducible packaging layer around the Code OSS runtime. A direct Code OSS package would still pay the main compile cost while making this project maintain the macOS product configuration, packaging, update removal, signing, and release behavior that VSCodium already supplies. The `vscode` directory that appears inside generated work data is the exact name VSCodium expects for its Code OSS checkout; it is required during a build, ignored, and safe to delete.

Keep query-document entry SQL-only. DBCode's support for many database types belongs in Connections; a `.duckdb`, `.sqlite`, `.parquet`, or `.csv` file is a connection or data target rather than query text. If DBCode later declares another query-document format, add it deliberately instead of treating every supported database file as an editor document.

For ongoing UI review, launch the last signed checkpoint with `./script/run_host.sh` and run `./script/check_development.sh` after source changes. Batch Appshot feedback and perform one complete `./script/build_host.sh` when the visual batch is accepted. The source-only checks are deliberately not a release substitute.

## Comments

- 18 July 2026: Removed the superseded exploration effort, which contained duplicate research and three throwaway prototypes that were no longer referenced. Preserved one approved visual reference under `docs/design/`, renamed the active issue effort for DBCode Wrapper, and renamed the tracked runtime overlay folder to `host/patches/code-oss/`.

- 18 July 2026: Active source, tests, and tickets now use descriptive database-client redesign language. The release lock and generated manifest schema name Code OSS directly instead of calling the open-source runtime VS Code.

- 18 July 2026: `./script/check_development.sh` passed all fast host, DBCode, profile, proof-state, and redesign source contracts without compiling or repackaging the app. The existing signed app remains the last verified checkpoint and will be rebuilt once after the upcoming Appshot feedback batch.

- [x] SQL is the only query-document picker and macOS document association; database and data files enter through DBCode Connections.
- [x] Documentation identifies Code OSS as the runtime and VSCodium as its reproducible macOS packaging layer.
- [x] The required generated `vscode` checkout is clearly described as ignored VSCodium build data rather than a second product folder.
- [x] Ongoing Appshot and feedback review can launch the last signed app without rebuilding, while release verification still requires a complete build.
- [x] Vague prototype labels are replaced with descriptive database-client redesign language in active source, tests, and tickets.
- [x] Superseded exploration material is removed and the active local issue effort uses the DBCode Wrapper name.
