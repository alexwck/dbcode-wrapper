# 34 — Centralize the Private Personal Release acceptance record

**What to build:** Make the Private Personal Release module the sole validator of the maintained prompt-free acceptance record. Remove the superseded same-Mac generator instead of deepening a second schema.

**Blocked by:** none

**Type:** task

**Status:** resolved

- [x] One module owns the schema-3 prompt-free acceptance validation used by approval and packaging.
- [x] The superseded `verify_same_mac_release.sh` generator and its parallel manual evidence shape are removed.
- [x] Package creation and independent DMG verification use the same acceptance validator and package-check vocabulary.
- [x] Focused fixtures cover missing, stale, mismatched, incomplete, and overclaimed evidence.
- [x] A new prompt-free release gate requires one localized contract change rather than producer and consumer copies.
- [x] Older accepted records remain readable where compatibility requires them, without keeping their generator.

## Comments

- 2026-07-27: Resolved through the prompt-free schema-3 acceptance path. The old same-Mac generator was deleted after exact `v0.1.1` approval; retained generated evidence remains protected.

## Answer

The Private Personal Release module now owns the maintained prompt-free acceptance contract. Packaging, independent verification, and approval consume its validated schema-3 record and canonical package checks. The old same-Mac generator is no longer a second source of release truth.

Historical records remain readable for compatibility. They are not regenerated, run during deployment, or used to require a person-controlled prompt.
