# 13 — Slim the compatible Code OSS host

**What to build:** Reduce DBCode Wrapper's download and installed size by removing only production host content proven unnecessary, while keeping the unchanged DBCode package and the complete host interfaces its database features use.

**Blocked by:** 12 — Refine the database-client redesign with Appshot

**Type:** prototype

**Status:** resolved

- 20 July 2026 baseline: the signed app is 937,596 KiB installed; its Electron framework is 270,980 KiB; the Code OSS application is 642,436 KiB; and built-ins are 167,336 KiB. There are 93 actual built-in extensions plus the shared `extensions/node_modules` directory. The earlier count of 94 treated that dependency directory as an extension.
- The app contains 826 source maps using 358,596 KiB of allocated space and 364,904,314 logical bytes. The normal external `dbcode.dbcode@1.36.1` installation is separate from the app at 271,444 KiB; its official VSIX remains 43,262,773 bytes.
- The paired indicative `COPYFILE_DISABLE=1 tar -czf` baseline is 264,659,573 bytes. Excluding maps in that same read-only experiment produced 196,286,440 bytes and projected the installed app at 579,000 KiB.
- Acceptance goals set before the build change: no more than 614,400 KiB installed and no more than 200,000,000 bytes in the same indicative archive measurement. Installed and compressed results will continue to be reported separately.
- The reproducible measurements and goals live in [`host/slimming-policy.json`](../../../host/slimming-policy.json) and [`script/audit_host_size.sh`](../../../script/audit_host_size.sh).
- The signed map-free checkpoint is 578,720 KiB installed and 196,232,104 bytes in the same indicative archive. It contains zero `.map` files, keeps all 93 built-ins for the next independent experiment, passes strict signature and manifest checks, launches in an isolated profile, and passes the complete rendered DBCode-focused shell suite.
- The final signed allowlisted app is 461,656 KiB installed and 166,381,053 bytes in the indicative archive. Against the original baseline, that removes 475,940 KiB installed (50.76%) and 98,278,520 archive bytes (37.13%). Against the map-free checkpoint, it removes another 117,064 KiB installed (20.23%) and 29,851,051 archive bytes (15.21%).
- Electron remains unchanged at 270,980 KiB. The packaged Code OSS application falls from 642,436 KiB to 167,036 KiB, while built-ins fall from 93 extensions plus shared dependencies at 167,336 KiB to four declarative extensions at 352 KiB with no shared `extensions/node_modules`.
- The retained built-ins are `sql`, `theme-defaults`, `theme-seti`, and `notebook-renderers`. The policy groups every removed extension by its former language, preview, source-control, debug, task, host-authentication, notebook, or alternative-theme responsibility and gives every group the same tested `all_built_ins` rollback.
- Three isolated post-slim smoke runs, including signature and manifest checks, completed in 7.18, 7.32, and 6.98 seconds (7.18-second median) and reached stable renderers. No controlled pre-slim timing was captured, so this ticket makes no startup speed-up claim.
- Failed experiments were contained before release: filtering only the application stream left 305 dependency source maps, so the build seam now filters both streams; the first allowlist packaging run referenced a later local path and failed before producing an app, so the maintained patch now resolves the extension root directly. The rebuilt and signed artifact passed afterward.
- The official external `dbcode.dbcode@1.36.1` package remains outside the app with the same 43,262,773-byte VSIX and verified SHA-256 and Ed25519 signature. Static checks, three launch smokes, the complete rendered shell suite, real macOS Keychain restoration, licence persistence, saved connections, read-only PostgreSQL, DuckDB, Parquet, project SQL, automatic result placement, secondary DBCode surfaces, complete quit, and relaunch all passed.

- [x] Record reproducible baselines for the signed app, Electron, Code OSS application, built-in extensions, source maps, separately expanded DBCode extension, and an indicative compressed artifact.
- [x] Set separate, measurable goals for download size and installed size before changing the package; do not present compression savings as installed-size savings.
- [x] Configure the production build to omit unneeded source maps and debug-only resources at their build seam rather than deleting files from an already signed application.
- [x] Replace the current 94 bundled Code OSS extensions with the smallest tested allowlist; every retained or removed group has a written runtime reason and a rollback path.
- [x] Preserve the Node extension host, editor, webview, view, command, custom-editor, notebook, storage, secret, file, and workbench services required by the public DBCode manifest and acceptance matrix.
- [x] Do not modify, strip, repackage, or embed the external DBCode extension. Its official digest and signature must remain unchanged.
- [x] A complete signed rebuild passes static contracts, strict signature checks, activation, licence and Keychain persistence, PostgreSQL, DuckDB, Parquet, project SQL files, Results docking, relaunch, and representative DBCode secondary surfaces.
- [x] Report the achieved size reduction, startup effect, removed content, retained content, failed experiments, and comparison with the previous signed checkpoint.
- [x] If slimming cannot achieve a material improvement safely, retain the compatible payload and record the result; do not switch to Theia or a custom host inside this ticket.

## Answer

Keep the compatible Code OSS extension host, but package it with source maps disabled and only the four tested built-ins needed by the DBCode-focused product: SQL registration, the active color theme, the active file-icon theme, and standard notebook output renderers. DBCode remains the unchanged, signed external Open VSX package.

The signed app is 461,656 KiB installed and 166,381,053 bytes in the indicative archive, reductions of 50.76% and 37.13% from the original signed baseline. The complete automated suite and the real credential-backed quit-and-relaunch proof passed. If a future DBCode or Code OSS update needs a removed built-in, change the policy mode to `all` and rebuild; this leaves the DBCode profile, licence, saved connections, and secrets untouched.
