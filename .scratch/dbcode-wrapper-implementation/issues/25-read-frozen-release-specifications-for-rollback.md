# 25 — Read frozen Release Specifications for rollback

**What to build:** Keep strict validation for every new candidate while allowing a current or rollback release set to read the exact historical Release Specification that was recorded when its signed artifact was built.

**Blocked by:** 17

**Type:** task

**Status:** resolved

- [x] The Release Specification interface has an explicit historical read mode for supported frozen schema-2 and earlier schema-4 records.
- [x] Historical reading validates the immutable host, DBCode package, profile, and product identity fields needed by the controlled-upgrade workflow.
- [x] Missing historical presentation metadata is normalized only in the returned purpose record; schema 2 has one explicit mapping from its pre-versioned profile to baseline profile schema 1, and the archived lock and build manifest remain unchanged.
- [x] `controlled_upgrade.sh prepare-set --role current` may use the historical read mode only after the original build manifest proves the exact release-lock digest.
- [x] Candidate release sets always require the current strict Release Specification and cannot use historical compatibility.
- [x] Source tests cover accepted frozen records, schema-specific malformed records, current-role preparation, candidate rejection, and present, missing, or mismatched manifest-to-lock hash binding.
- [x] Ticket 08 reruns the real compatibility matrix, promotion, restart-health, and rollback rehearsal after this blocker is fixed.

## Comments

- 24 July 2026: Final acceptance found that the stricter Release Specification validator could no longer prepare the retained DBCode 1.36.1 rollback set or the retained pre-final schema-4 set. Their signed apps, manifests, and lock hashes remain valid; the problem is that newer presentation fields were added without a reader for already frozen records. The approved seam keeps new candidates strict and adds a narrow, read-only compatibility path for a hash-bound current or rollback set.
- 24 July 2026: Review tightened the seam before commit. Schema 2 and schema 4 now have separate validation rules, historical preparation requires a present exact manifest lock digest before reading purpose records, and the adapter does not manufacture an approved compatibility state. The schema-2 profile predates explicit profile versioning and maps only to the baseline schema 1 contract.

## Answer

Supported frozen release locks are readable again without weakening new candidates. The historical interface validates schema 2 and schema 4 separately, returns normalized purpose records without editing the retained files, and can be selected only for a current set whose original build manifest contains the exact lock digest.

The real ticket 08 matrix passed all four pairings using the retained pre-final host as the current baseline. The exact candidate was promoted into a disposable installation, passed two restart-health launches with the real Keychain, and rolled back as one complete app, manifest, extension, user-data, and shared-data set.

That matrix and restart-health result remain historical evidence. Their executable controlled-upgrade harnesses were retired after prompt-free schema-3 approval became the maintained release path. Frozen records remain readable, and the guarded rollback preparation, verification, and preview tools remain.
