---
title: Review an upstream update
description: A safe path for evaluating new VSCodium, Code OSS, DBCode, or notebook versions as one candidate release set.
type: guide
tags:
  - wiki
  - guide
  - update
  - compatibility
wiki_profile: public
wiki_depth: standard
source_commit: efe247fc701a9b529e3e6368b6571a44541fc146
---
## Goal

Turn independently published upstream versions into one reviewed DBCode Wrapper candidate without letting update discovery bypass compatibility, profile, or rollback safeguards.

## Steps

1. **Treat discovery as information.** Open the official VSCodium, Code OSS, DBCode, and notebook release pages from the release-status UI. Do not install directly from the notification.
2. **Read the change surface.** Look for Electron or macOS identity changes, extension API changes, workbench file moves, custom editor changes, secure-storage changes, and DBCode contribution changes.
3. **Update the canonical lock.** Change the version, URLs, commits, hashes, signatures, package identities, and release notes in [`host/release-lock.json`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/release-lock.json). Keep DBCode and notebook packages pinned.
4. **Validate the release specification.** Run the release-specification tests before doing an expensive build.
5. **Reconcile the patch plan.** Apply the ordered VSCodium and Code OSS patches to clean pinned sources. Update a patch only after understanding the upstream change; do not hide drift with a broad rewrite.
6. **Build a candidate beside the active release.** Preserve the current approved app and profile.
7. **Run risk-matched checks.** At minimum run development contracts, built-app inspection, focused rendered checks, DBCode activation, and full quit/relaunch. Add database, file, notebook, Keychain, or migration checks according to the changed boundary.
8. **Prepare the candidate set.** Clone the owned profile and restore the exact pinned external packages through the controlled-upgrade path.
9. **Approve only matching evidence.** Record approval when identities, digests, installed inventories, and the required matrix all refer to the same candidate.
10. **Promote atomically and keep rollback.** Switch the complete app/profile set, run installed health, and retain the prior complete set.

## Relevant code

- [Release Specification](../modules/release-specification.md)
- [Patch Plan and build](../modules/patch-plan-and-build.md)
- [`release-status.js`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/extensions/dbcode-wrapper-release-status/release-status.js)
- [`script/controlled_upgrade.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/controlled_upgrade.sh)

## Gotchas

- VSCodium and Code OSS version labels are related but not interchangeable; preserve the exact pinned source identities.
- A newer DBCode package can require a host contribution that the focused patch accidentally removed.
- Re-signing with a different identity can cause macOS Keychain prompts even when app code is unchanged.
- Automated update checks are useful, but automatic public binary releases are outside this repository's current owner-only release model.
- Passing PostgreSQL, DuckDB, and Parquet checks does not prove every supported connection; changes to generic connection plumbing deserve broader sampling.

## Related

- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Controlled upgrade and rollback](../flows/controlled-upgrade-and-rollback.md)
- [Approved Release Set](../concepts/approved-release-set.md)
