# 36 — Derive Profile Layout identity from the Release Specification

**What to build:** Remove Profile Layout's parallel hard-coded product identity. Generate one validated profile and product record from the Release Specification and use it through both shell and bundled JavaScript adapters.

**Blocked by:** 35

**Type:** task

**Status:** resolved

- [x] Application name, bundle identifier, user-data folder, extension folder, shared-data folder, backup folder, query folder, storage namespace, and profile schema originate from one Release Specification record.
- [x] The bundled Profile Layout implementation consumes generated validated data and no longer owns a competing `PRODUCT` constant.
- [x] Shell and JavaScript callers resolve identical records for normal, QA, isolated, migration, recovery, and rollback use.
- [x] Tampered, missing, stale, or mismatched generated identity fails before any profile mutation or application launch.
- [x] Focused fixture tests can vary a product/profile record without repeating production literals.
- [x] Profile, migration, Host Session, rollback, rendered-support, and development gates pass. The retired proof harness is not restored.

## Comments

- 2026-07-27: Release Specification schema 5 now owns every product value used by Profile Layout. Assembly generates `profile-identity.json`; shell and bundled JavaScript load the same record, and static smoke regenerates and compares it before a rendered launch. The focused shell reads its query namespace and folder from the compiled product record instead of repeating `dbcode-wrapper/queries`.
- 2026-07-27: Focused tests cover normal, persistent QA, isolated, migration, recovery, and rollback use; alternate fixture identity; relative, absolute, and spaced generator paths; missing, linked, malformed, unsafe, stale, and mismatched identity; and shell/JavaScript parity. Rollback derives the retained app and bundle identity from its own current or historical Release Specification.
- 2026-07-27: Profile-only folder and schema changes stay outside the Compiled Host cache key. The storage namespace and query folder remain compile inputs because the focused shell embeds them. `./script/check_development.sh` passed in 23.67 seconds without rebuilding or launching the app. Its only skip was the existing sandbox-only process-table fixture. The focused rollback contract also passed.

## Answer

Profile Layout no longer keeps a second product constant. The Release Specification owns the application, bundle, profile-folder, query-storage, and profile-schema values. Release assembly writes one small generated record, and both shell and JavaScript adapters validate and use it.

Missing, linked, malformed, unsafe, stale, or changed identity now fails closed. The fast development gate remains prompt-free and took 23.67 seconds. No extra GUI profile, manual proof, full build, or app launch was added for this source change.
