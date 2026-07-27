# 35 — Deepen Profile Setup orchestration

**What to build:** Put Profile Setup state transitions and action ordering behind one testable module while keeping VS Code APIs, DBCode commands, file selection, clipboard access, time, process spawning, and quit behaviour as adapters.

**Blocked by:** 34

**Type:** task

**Status:** resolved

- [x] One Profile Setup module owns start-clean, reviewed import, staging cleanup, conditional DuckDB preflight, completion, cancellation, recovery request, worker handoff, and quit ordering.
- [x] The wrapper extension is a thin VS Code and DBCode command adapter rather than the state-machine implementation.
- [x] Fast tests exercise the real action sequence, including cleanup after every cancellation and failure boundary.
- [x] Recovery still moves only the Standalone DBCode Profile paths, never extensions, Keychain data, ordinary editor profiles, or database files.
- [x] Existing prompt-free migration, recovery, first-run, and persistence checks pass without adding generic workbench UI.

## Comments

- 2026-07-27: `profileSetup.js` now owns the workflow and receives one adapter for VS Code, DBCode, file, clipboard, time, process, and quit operations. Five focused orchestration tests cover start-clean persistence, reviewed import and DuckDB preflight, cancel and failure cleanup, cleanup failure reporting, and recovery handoff order.
- 2026-07-27: `./script/check_development.sh` passed in 21.01 seconds without rebuilding or launching the app. The current verification policy keeps first-use migration and recovery out of the rendered deployment smoke, so this ticket uses their prompt-free source contracts instead of adding a second profile or a human gate.

## Answer

Profile Setup now has one testable workflow module. The extension only connects that module to VS Code, unchanged DBCode commands, the filesystem, clipboard, clock, recovery worker, and quit command.

The workflow deletes its reviewed temporary file on completion, cancel, close, recovery, and action failure. If deletion itself fails, the original action error remains visible and the staged path is kept so closing the panel can retry cleanup. Recovery still passes only the validated Standalone DBCode Profile paths to the existing worker.
