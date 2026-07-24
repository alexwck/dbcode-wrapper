# 11 — Decide the minimum maintainable DBCode host

**What to decide:** Determine whether the unchanged licensed DBCode Open VSX extension can run in a substantially smaller ground-up macOS application without recreating Code OSS, and identify the safest size-reduction path before refining the remaining UI, migration, update, and release work.

**Blocked by:** None

**Type:** research

**Status:** resolved

## Answer

Keep Code OSS as the hidden compatible runtime and VSCodium as its build and packaging layer. Open VSX is only the package registry; it cannot run DBCode by itself.

In design terms, the unchanged DBCode module is an implementation that expects the VS Code Extension API interface. Code OSS supplies the deep host module behind that interface: the Node extension host, editors, views, webviews, commands, custom editors, notebooks, storage, secrets, and workbench coordination. The Open VSX package boundary is a good seam because DBCode and the host can still be versioned and tested separately. Replacing that deep module with a small custom adapter would recreate a large and continually changing part of Code OSS with worse leverage and locality.

The current installed footprint is about 916 MiB for the signed app plus 262 MiB for the expanded external DBCode extension. Inside the app, Electron is about 265 MiB and the Code OSS application is 627 MiB. That Code OSS payload includes 163 MiB across 94 built-in extensions and roughly 350 MiB of source maps across the application. Those are measured opportunities for a controlled slimming prototype, not a safe deletion list. The unchanged DBCode package itself remains outside that work.

Monaco alone cannot run VS Code extensions. A native AppKit or SwiftUI shell would therefore need to recreate the extension host and DBCode's contributed views, custom editor, notebook, renderer, storage, and secret services. Eclipse Theia is the only credible alternative host worth a bounded comparison because it implements the VS Code extension interface, but it still uses Electron for desktop and officially records some API areas as stubbed. Switching now would add another compatibility track without proven size savings.

A truly ground-up DBCode app becomes maintainable only if DBCode supplies a supported standalone engine, SDK, or service API. The public API currently documented by DBCode is an API for other VS Code extensions, not a standalone database engine.

The next dependency order is therefore Appshot redesign refinement, compatible-host slimming, advanced DBCode feature reachability, profile migration and update discovery, controlled promotion and rollback, then the Private Personal Release for the user's own Macs. See [the complete feasibility report](../research/ground-up-desktop-host-feasibility.md).

## Comments

- 18 July 2026: The research used public platform documentation and the installed DBCode manifest only. It did not inspect or reverse engineer DBCode implementation code.
- 18 July 2026: Download size and installed size were separated. Ordinary compression gave an indicative app archive near 253 MiB, while the current installed app remains 916 MiB; release ZIP or DMG measurements still belong to a packaging ticket.

- [x] Measure the current installed app, Electron framework, Code OSS application, bundled extensions, source maps, and separately installed DBCode extension so download size and installed size are not confused.
- [x] Use the public DBCode manifest and official platform documentation to identify the host interfaces required by the unchanged extension without inspecting or reverse engineering its implementation.
- [x] Compare a slimmed Code OSS host, a different compatible extension host, a custom VS Code API host, and a ground-up database client in terms of compatibility, size, maintenance, licensing boundaries, and UI control.
- [x] State which parts of the current VSCodium and Code OSS setup are packaging, runtime, replaceable payload, or required compatibility infrastructure.
- [x] Make an explicit architecture decision and use it to reorder or rewrite the still-open Appshot, feature, migration, update, rollback, and release tickets.
- [x] Keep DBCode unchanged and do not turn this research ticket into host implementation.
