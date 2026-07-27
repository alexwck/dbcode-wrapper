# 18 — Deepen the Approved Release Set contract

**What to build:** Put Approved Release Set record validation, canonical identity, safe member resolution, approval lookup, and writing behind one deep module with shell and JavaScript adapters.

**Blocked by:** 17

**Type:** task

**Status:** resolved

- [x] One canonical record contract owns schema validation, source-set and artifact identity rules, compatibility state, complete approval evidence, and safe relative member paths.
- [x] Promotion, rollback, static verification, compatibility checking, installed status, and update readiness use that contract rather than duplicating record shapes.
- [x] Shell and JavaScript adapters produce the same decisions from the same valid and invalid fixtures.
- [x] Unsafe paths, malformed hashes, incomplete approval evidence, mismatched host/DBCode pairs, and unsupported schema versions fail closed.
- [x] Existing approved history and controlled-upgrade workflows remain readable through a deliberate migration or compatibility adapter.

## Comments

- 23 July 2026: Added one Approved Release Set contract beside the bundled update service, plus a Node command adapter and a small shell adapter. The same module now validates prepared set records, resolves members without escaping or following symlinks, validates complete approvals and history, selects update-ready pairs, and writes approval records and registries.
- 23 July 2026: Promotion, rollback preparation and verification, static and runtime compatibility gates, installed release identity, and update readiness now use this contract. The prior shell path resolvers, record builder, registry updater, and JavaScript approval validator were removed.
- 23 July 2026: Complete approvals use record schema 1 and canonical source-plus-artifact IDs. The existing schema-2 history container and its earlier DBCode 1.36.1 rollback record remain readable through an explicit legacy adapter, but legacy records cannot become update-ready.
- 23 July 2026: Cross-adapter fixtures cover valid records, unsafe paths, symlinked members, malformed hashes, missing evidence, mismatched host/DBCode identity, duplicate IDs, and unsupported history schemas. The full development source suite and complete controlled-upgrade flow passed.

## Answer

There is now one place that decides whether a release set is structurally safe, exactly identified, fully approved, and eligible for an update. Shell automation and the in-app update service receive the same answer from the same code, while the retained older rollback record stays available only for its deliberate legacy purpose.

Prompt-free private approval now enters through the same module boundary. Its adapter asks the Release Specification and Private Personal Release modules for validated purpose records, then the central writer binds those records to the exact runtime inventory, package receipt, and no-install attestation before it can create or upsert an approval. The package verifier reads its required check vocabulary from this module so the producer and approval validator cannot drift.

The prepared-set validator, member resolver, and older proof-based approval writer were retired with the controlled-upgrade workflow. The maintained module now exposes only approved-history validation, installed and candidate matching, package-check vocabulary, and prompt-free approval.
