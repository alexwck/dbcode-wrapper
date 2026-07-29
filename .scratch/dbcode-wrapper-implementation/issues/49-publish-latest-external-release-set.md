# 49 — Publish the latest compatible external release set

**What to build:** Publish the next normal same-repository Host Release using latest stable DBCode `1.36.6` and latest stable VSCodium `1.126.04524` on their compatible Code OSS `1.126.0` runtime. Keep the independently newer Code OSS `1.130.0` visible as available and untested until VSCodium publishes compatible packaging. Keep DBCode unchanged and external, preserve every DBCode-owned route, run the prompt-free release gate, and publish only the verified host DMG and checksum.

**Blocked by:** none

**Type:** task

**Status:** claimed

- [x] Capture the three official stable records, immutable upstream commits, DBCode package metadata, changelog, and public contribution difference.
- [x] Bump the wrapper to `0.1.5` and update the exact Release Specification, feature policy, and maintained documentation.
- [x] Prove whether latest VSCodium can prepare Code OSS `1.130.0`; keep the runtime pin unchanged when doing so would require a broad local VSCodium fork.
- [x] Verify the official DBCode `1.36.6` package, signature, public key, contribution surface, and complete rendered connection catalogue.
- [x] Run the prompt-free development, cold-build, signed static-smoke, and one-profile rendered release gates.
- [x] Create annotated tag `v0.1.5` only after exact-source acceptance passes.
- [x] Package, mount, and independently verify the host-only DMG; record and commit approval without installing the app or changing the production profile.
- [ ] Push `main` and `v0.1.5`, create a normal non-draft, non-prerelease GitHub release, and upload only the DMG and checksum.
- [ ] Verify the public release, asset sizes and downloaded digests, remote refs, latest-release pointer, and final clean Git state.

## Comments

- 2026-07-29: Claimed after the user asked to update all three external sources and publish a new tag. Official discovery reports VSCodium `1.126.04524` as still current, Code OSS `1.130.0`, and verified stable DBCode `1.36.6`. The unchanged VSCodium version is still part of the new exact tuple.
- 2026-07-29: DBCode `1.36.6` adds `dbcode.library.openItemWith` and the `dbcode.grid.toolbarPins` setting to its public contribution surface, and removes the separate `dbcode.item.truncateCascade` command. Its changelog also records MCP OAuth and driver-extraction security hardening, SQL access for MongoDB and Stripe, result-toolbar pinning, library open-against-connection, cascade object actions, and multi-statement editor fixes. These are DBCode-owned capabilities; the wrapper should preserve their routes rather than reimplement them.
- 2026-07-29: Code OSS `1.130.0` was previously held because the latest VSCodium release still targeted `1.126.0` and its official patch stage did not apply to `1.130.0`. This task must retest that boundary from clean pinned sources and may rebase maintained integration only when the resulting build remains reproducible and reviewable.
- 2026-07-29: The clean retest found one stale VSCodium removal path, ten VSCodium patch failures, and failures in all four maintained wrapper patch seams against Code OSS `1.130.0`. Carrying that pair would require a broad local fork of VSCodium's branding, updater, native-module, Copilot-removal, onboarding, and packaging policy. The release candidate therefore keeps Code OSS `1.126.0`; automatic polling continues to show `1.130.0` as available and untested.
- 2026-07-29: The Release Specification now identifies wrapper `0.1.5` and verified stable DBCode `1.36.6` with the exact package, signature, public-key, contribution, size, publication, and release-note records. The candidate feature policy preserves Library Open With Connection, result-toolbar pins, and the existing DBCode-owned routes. The complete prompt-free development source gate passes.
- 2026-07-29: Exact-source build reused verified Compiled Host `compiled-host-bb6836aa899581d0091ff026837380529cdbc8edbde6741560b1c2e3bdf3cdc0`, then signed static smoke passed. The isolated rendered gate verified the official DBCode `1.36.6` registry record, VSIX digest, Ed25519 signature, public key, contribution surface, and the unchanged 12-section, 88-item New Connection catalogue. All 13 focused-shell checks passed without starting a database, notebook kernel, AI model, account flow, or other human gate.
- 2026-07-29: The public wiki now records the latest-compatible host rule and the DBCode contribution-review rule. Its touched pages lint cleanly, its navigation has no dead links, and the only reported orphan is the OpenKnowledge pack skill rather than a public wiki page.
- 2026-07-29: Prompt-free release acceptance passed for source commit `68d43e61f1715a12cf88236abd9ed4221315189d`, then the release task created annotated tag `v0.1.5`. The mounted host-only DMG is 187,964,248 bytes with SHA-256 `ff0f989755ff37f29f692b89c0f63c77a79f01f160b376ac14a65e3c86004a97`; its embedded app digest is `108e6a5ffdee7100928a15abe0626704929172e10259823081e1145f7fb8f0fe`. Approval history now records the exact tuple without changing the installed app or production profile.

## Answer

In progress.
