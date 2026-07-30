# 52 — Publish the wrapper maintenance release

**What to build:** Publish DBCode Wrapper `v0.1.6` from the completed first-run, persistent-drawer, focused-shell source, and maintenance cleanup work. Keep the external release set unchanged at VSCodium `1.126.04524`, compatible Code OSS `1.126.0`, and unchanged DBCode `1.36.6`. Run the prompt-free Host Release workflow and publish only the independently verified host DMG and checksum.

**Blocked by:** none

**Type:** task

**Status:** claimed

- [x] Confirm the source tree is clean, identify the six commits since `v0.1.5`, and derive `v0.1.6`.
- [x] Bump the wrapper version and validation issue without changing the external release set.
- [ ] Run the prompt-free development and exact-source release gates.
- [ ] Create annotated tag `v0.1.6` only after exact-source acceptance passes.
- [ ] Package, mount, and independently verify the host-only DMG; record and commit approval without changing the production profile.
- [ ] Push `main` and `v0.1.6`, create a normal non-draft, non-prerelease GitHub release, and upload only the DMG and checksum.
- [ ] Verify the public release, asset sizes and downloaded digests, remote refs, latest-release pointer, and final clean Git state.

## Comments

- 2026-07-30: Claimed after the user asked to publish the completed wrapper work as a new release. Local `main` is six commits ahead of published `v0.1.5`. The release plan still derives `v0.1.5`, so the new wrapper-only release is `v0.1.6`; VSCodium, Code OSS, and DBCode pins remain unchanged.
- 2026-07-30: GitHub CLI is installed, but its saved token is invalid. Local build, acceptance, package, tag, and approval work can continue; the final explicit publication step requires `gh auth login -h github.com`.
- 2026-07-30: The Release Specification derives `v0.1.6`, and the only release-lock changes are the wrapper version and validation issue. The complete prompt-free development source gate passed without rebuilding or launching the app; one sandbox-only Host Session fixture was skipped while the maintained gate completed successfully.

## Answer

In progress.
