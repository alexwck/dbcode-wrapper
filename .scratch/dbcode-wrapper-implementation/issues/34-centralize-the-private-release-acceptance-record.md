# 34 — Centralize the Private Personal Release acceptance record

**What to build:** Make the Private Personal Release module the sole constructor and validator of the same-Mac acceptance record. The acceptance verifier gathers facts, while packaging and independent verification consume one validated schema.

**Blocked by:** 33

**Type:** task

**Status:** open

- [ ] One module owns the acceptance schema, required evidence hashes, gates, manual evidence, signing claims, risks, failures, waivers, and distribution claims.
- [ ] `verify_same_mac_release.sh` gathers and supplies validated facts without hand-building a parallel record shape.
- [ ] Package creation and independent DMG verification use the same acceptance validator.
- [ ] Tests create valid fixtures through the module and use focused mutations for missing, stale, mismatched, or overclaimed evidence.
- [ ] A new release gate requires one localized contract change rather than edits in producer, consumer, and copied fixtures.
- [ ] Same-Mac acceptance and Private Personal Release contract suites pass unchanged in meaning.
