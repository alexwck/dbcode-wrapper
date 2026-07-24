# 19 — Unify the Standalone DBCode Profile layout

**What to build:** Derive one complete, validated Standalone DBCode Profile layout and make shell and JavaScript code consume that record.

**Blocked by:** 17

**Type:** task

**Status:** resolved

- [x] One interface returns state, user-data, extensions, shared-data, backup, cache, log, and natural-path properties for default and isolated profiles.
- [x] Every path is absolute, remains inside an approved owner or generated root, rejects symlink escapes where mutation occurs, and carries the required private mode.
- [x] Shell launch, preparation, proof, QA, recovery, and JavaScript migration code use the same layout record rather than re-deriving names.
- [x] Existing environment variables remain compatibility adapters for the unchanged extension-host process.
- [x] Default Finder launches and scripted launches continue to share the same licence, connection, and credential state while QA remains isolated.

## Comments

- 23 July 2026: Added one bundled Profile Layout contract with default, fixed QA, and owner-scoped isolated records. Each record includes product identity, profile schema, owner, private directory and file modes, natural-path behaviour, and all profile paths.
- 23 July 2026: Shell preparation, launch, proof, and rendered QA now load the canonical record through a small Node adapter. The profile-recovery extension receives that same record and rejects changed compatibility environment values rather than trusting them as path authorities.
- 23 July 2026: Default launches continue to use the app's natural macOS profile locations, so Finder and scripted launches share the same DBCode licence, connections, and credentials. Fixed and disposable QA launches remain under generated roots and may reference only a separately verified extension directory under the same owner.
- 23 July 2026: Tests cover shell and JavaScript parity, exact release-profile identity, isolated profiles, private modes, alternate roots, unknown profiles, symlink ancestors, unchanged environment transport, and recovery. The complete development source suite passed.

## Answer

The Standalone DBCode Profile is now one validated record instead of several path formulas. Every caller agrees on where DBCode state lives, QA stays isolated, and the unchanged DBCode extension still receives the environment values it expects without making those values trusted configuration.
