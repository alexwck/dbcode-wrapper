# 17 — Deepen the Release Specification module

**What to build:** Replace direct knowledge of `host/release-lock.json` throughout callers with one validated Release Specification module that returns complete purpose-level records.

**Blocked by:** 16

**Type:** task

**Status:** resolved

- [x] One small interface validates a release lock and returns complete build, extension-inventory, profile/product, and release-identity records.
- [x] Existing shell workflows consume the purpose-level records through compatibility adapters rather than growing one getter per JSON field.
- [x] The lock schema and its error messages have one test surface with malformed, incomplete, and valid fixtures.
- [x] Build, preparation, manifest, proof, update, and verification callers no longer need to understand unrelated release-lock sections.
- [x] The generated records preserve the exact current release identity and fail closed on unsupported schemas or unsafe values.

## Comments

- 23 July 2026: Implemented `script/release_specification.sh` and its internal module with exactly five commands: validate, build, extensions, profile, and identity. `host_config.sh` is now the shell adapter and exports task-level values from complete records; the old arbitrary `lock_value` interface was removed.
- 23 July 2026: Manifest generation, installed status, release identity, extension verification and preparation, controlled-upgrade preparation, host smoke, proof, signing, and source contracts now consume purpose-level records. Controlled-upgrade fixtures were upgraded to full valid Release Specifications instead of relying on partial lock-shaped test objects.
- 23 July 2026: Valid, malformed, incomplete, symlinked, and unknown-purpose cases pass their focused contract. Canonical source-set identity remains stable for the unchanged specification and changes for a valid build-affecting product change. The complete development source suite passed without rebuilding the app.
- 24 July 2026: Ticket 25 added a separate historical reader for retained schema-2 and earlier schema-4 rollback locks. It is available only to the current-set preparation path after an exact build-manifest lock binding; current candidates remain strict.

## Answer

`host/release-lock.json` now has one validation and interpretation seam. Callers ask for a complete record for their purpose instead of knowing arbitrary paths through the lock. New candidates use the current strict schema. Supported frozen rollback records use a separate read-only, manifest-bound path that keeps their archived files unchanged, applies only the explicit legacy profile mapping, and never invents approval.
