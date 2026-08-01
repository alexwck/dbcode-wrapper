# 11 — Decide the minimum maintainable DBCode host

**What to decide:** Determine whether the unchanged licensed DBCode Open VSX extension can run in a substantially smaller ground-up macOS application without recreating Code OSS, and identify the safest size-reduction path before refining the remaining UI, migration, update, and release work.

**Blocked by:** None

**Type:** research

**Status:** resolved

## Answer

Keep Code OSS as the hidden compatible runtime and VSCodium as its build and packaging layer. Open VSX is only the package registry; it cannot run DBCode by itself.

The unchanged DBCode extension expects the VS Code Extension API. Code OSS supplies the extension host, editors, views, webviews, commands, notebooks, storage, secrets, and workbench coordination behind that interface. Replacing it with a small custom adapter would recreate a large and changing platform surface.

Keep size work inside the maintained slimming policy, semantic Patch Plan, and static Host checks. Do not treat old measurements or prototype experiments as a deletion list. A different host becomes worth reconsidering only if DBCode provides a supported standalone engine, SDK, or service API.

## Comments

- 18 July 2026: The research used public platform documentation and the installed DBCode manifest only. It did not inspect or reverse engineer DBCode implementation code.
- 18 July 2026: Download size and installed size were separated. Ordinary compression gave an indicative app archive near 253 MiB, while the current installed app remains 916 MiB; release ZIP or DMG measurements still belong to a packaging ticket.

- [x] Measure the current installed app, Electron framework, Code OSS application, bundled extensions, source maps, and separately installed DBCode extension so download size and installed size are not confused.
- [x] Use the public DBCode manifest and official platform documentation to identify the host interfaces required by the unchanged extension without inspecting or reverse engineering its implementation.
- [x] Compare a slimmed Code OSS host, a different compatible extension host, a custom VS Code API host, and a ground-up database client in terms of compatibility, size, maintenance, licensing boundaries, and UI control.
- [x] State which parts of the current VSCodium and Code OSS setup are packaging, runtime, replaceable payload, or required compatibility infrastructure.
- [x] Make an explicit architecture decision and use it to reorder or rewrite the still-open Appshot, feature, migration, update, rollback, and release tickets.
- [x] Keep DBCode unchanged and do not turn this research ticket into host implementation.
