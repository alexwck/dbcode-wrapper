# 36 — Derive Profile Layout identity from the Release Specification

**What to build:** Remove Profile Layout's parallel hard-coded product identity. Generate one validated profile and product record from the Release Specification and use it through both shell and bundled JavaScript adapters.

**Blocked by:** 35

**Type:** task

**Status:** open

- [ ] Application name, bundle identifier, user-data folder, extension folder, shared-data folder, backup folder, query folder, storage namespace, and profile schema originate from one Release Specification record.
- [ ] The bundled Profile Layout implementation consumes generated validated data and no longer owns a competing `PRODUCT` constant.
- [ ] Shell and JavaScript callers resolve identical records for normal, isolated, proof, migration, recovery, and rollback profiles.
- [ ] Tampered, missing, stale, or mismatched generated identity fails before any profile mutation or application launch.
- [ ] Focused fixture tests can vary a product/profile record without repeating production literals.
- [ ] Profile, migration, Host Session, proof, rollback, rendered, and development gates pass.
