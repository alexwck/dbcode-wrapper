# 49 — Publish the latest external release set

**What to build:** Publish the next normal same-repository Host Release using the latest official stable record from each external source: VSCodium `1.126.04524`, Code OSS `1.130.0`, and DBCode `1.36.6`. Keep DBCode unchanged and external. Rebase only the wrapper and VSCodium build integration needed for that exact host, preserve every DBCode-owned route, run the prompt-free release gate, and publish only the verified host DMG and checksum.

**Blocked by:** none

**Type:** task

**Status:** claimed

- [ ] Capture the three official stable records, immutable upstream commits, DBCode package metadata, changelog, and public contribution difference.
- [ ] Bump the wrapper to `0.1.5` and update the exact Release Specification, patch plan, feature policy, and maintained documentation.
- [ ] Prove the latest VSCodium packaging flow can prepare Code OSS `1.130.0`, or adapt only the maintained wrapper integration without bypassing an upstream safety check.
- [ ] Verify the official DBCode `1.36.6` package, signature, public key, contribution surface, and complete rendered connection catalogue.
- [ ] Run the prompt-free development, cold-build, signed static-smoke, and one-profile rendered release gates.
- [ ] Create annotated tag `v0.1.5` only after exact-source acceptance passes.
- [ ] Package, mount, and independently verify the host-only DMG; record and commit approval without installing the app or changing the production profile.
- [ ] Push `main` and `v0.1.5`, create a normal non-draft, non-prerelease GitHub release, and upload only the DMG and checksum.
- [ ] Verify the public release, asset sizes and downloaded digests, remote refs, latest-release pointer, and final clean Git state.

## Comments

- 2026-07-29: Claimed after the user asked to update all three external sources and publish a new tag. Official discovery reports VSCodium `1.126.04524` as still current, Code OSS `1.130.0`, and verified stable DBCode `1.36.6`. The unchanged VSCodium version is still part of the new exact tuple.
- 2026-07-29: DBCode `1.36.6` adds `dbcode.library.openItemWith` and the `dbcode.grid.toolbarPins` setting to its public contribution surface, and removes the separate `dbcode.item.truncateCascade` command. Its changelog also records MCP OAuth and driver-extraction security hardening, SQL access for MongoDB and Stripe, result-toolbar pinning, library open-against-connection, cascade object actions, and multi-statement editor fixes. These are DBCode-owned capabilities; the wrapper should preserve their routes rather than reimplement them.
- 2026-07-29: Code OSS `1.130.0` was previously held because the latest VSCodium release still targeted `1.126.0` and its official patch stage did not apply to `1.130.0`. This task must retest that boundary from clean pinned sources and may rebase maintained integration only when the resulting build remains reproducible and reviewable.

## Answer

In progress.
