# 35 — Deepen Profile Setup orchestration

**What to build:** Put Profile Setup state transitions and action ordering behind one testable module while keeping VS Code APIs, DBCode commands, file selection, clipboard access, time, process spawning, and quit behaviour as adapters.

**Blocked by:** 34

**Type:** task

**Status:** open

- [ ] One Profile Setup module owns start-clean, reviewed import, staging cleanup, conditional DuckDB preflight, completion, cancellation, recovery request, worker handoff, and quit ordering.
- [ ] The wrapper extension is a thin VS Code and DBCode command adapter rather than the state-machine implementation.
- [ ] Fast tests exercise the real action sequence, including cleanup after every cancellation and failure boundary.
- [ ] Recovery still moves only the Standalone DBCode Profile paths, never extensions, Keychain data, ordinary editor profiles, or database files.
- [ ] Existing rendered migration, recovery, first-run, and persistence checks pass without adding generic workbench UI.
