# 42 — Prepare the v0.1.2 wrapper-only Private Personal Release

**What to build:** Turn the completed wrapper maintenance since `v0.1.1` into one prompt-free `v0.1.2` candidate. Keep DBCode `1.36.4`, Code OSS `1.126.0`, VSCodium `1.126.04524`, and profile schema 1 unchanged. Reuse the verified Compiled Host, assemble and sign once, verify the exact source and package, and keep transfer and installation outside this task.

**Blocked by:** 32, 33, 41

**Type:** task

**Status:** resolved

- [x] One clean immutable candidate commit contains every release-bound wrapper and documentation change.
- [x] The host build uses the exact verified Compiled Host cache and does not recompile unchanged Code OSS.
- [x] Static host smoke, exact runtime-package verification, and the one-profile rendered smoke pass.
- [x] Schema-3 prompt-free acceptance binds the candidate source, release lock, signed app, extension inventory, and rendered report.
- [x] Annotated tag `v0.1.2` identifies the exact accepted source commit.
- [x] The host-only package contains exactly the five expected private-transfer assets and passes independent mounted verification.
- [x] Prompt-free approval adds the exact `v0.1.2` release set to generated approved history without installing the app or changing the production profile.
- [x] Exact-ref public readiness passes for the candidate source and final documentation commit.
- [x] No source, tag, package, draft release, or application is pushed, uploaded, published, or installed by this task.

## Comments

- 2026-07-28: Claimed after all prior implementation tickets resolved. This is a wrapper-only patch candidate: upstream versions, profile schema, DBCode package, capability policy, and product scope remain unchanged. The expected path is cached assembly, prompt-free acceptance, local packaging, and generated approval evidence.
- 2026-07-28: The first exact-source build from `16ef6b12e1575792773decbc6b152bd300dad205` reused Compiled Host `compiled-host-b4b90cd2825ec14165f20eb3b969af122012a7f3d881dc4e885aeb0442a69abe` and assembled and signed in about 84 seconds without compiling Code OSS. Static smoke, locked runtime-package verification, and all 13 one-profile rendered checks passed.
- 2026-07-28: Schema-3 acceptance then correctly stopped because the materialized source's patch-plan test inspected the launcher checkout's mutable generated Code OSS tree. The test now ignores generated work from another checkout, and a focused regression proves that deliberately stale foreign generated source cannot affect exact-source proof. The focused contract and complete prompt-free development gate pass. The candidate must be committed and rebuilt before acceptance continues.
- 2026-07-28: Final source `2c02a1600a748974e8ca5920567f15ca1e32c774` passed exact-ref public readiness and reused the same Compiled Host in about 85 seconds. Static smoke passed in about 4 seconds, the locked runtime verifier passed in about 2.5 seconds, all 13 rendered checks passed in about 11 seconds, and exact-source schema-3 acceptance passed in about 41 seconds with zero failures and zero waivers.
- 2026-07-28: Annotated local tag `v0.1.2` peels to the accepted source. Packaging took about 58 seconds, produced exactly five host-only assets, and ran the independent mounted verifier. Prompt-free approval took about 1.3 seconds and added the release set to generated history with both `production_profile_written` and `installed_app_changed` false. Nothing was pushed, uploaded, published, or installed.
- 2026-07-28: The minimal cached deployment path is about 196 seconds from assembly through rendered smoke, exact-source acceptance, verified packaging, and approval. The separate static smoke and unchanged-package verifier added about 6.5 seconds here as explicit ticket evidence; acceptance and packaging already own the repeated static and mounted checks, so those repetitions should remain diagnostic rather than becoming default deployment steps.
- 2026-07-28: Maintained approval commit `80fdddd0bae6cd06edffbf64063124c2d2afd7d1` passed exact-ref public readiness. The public/standard wiki was refreshed through OpenKnowledge: 30 wiki documents lint clean, the overview reaches every other wiki page, the graph has zero dead links, and `ok preview` succeeds. The final ticket and wiki commit is checked again as an exact ref after it is created.
- 2026-08-01: The owner later approved the unchanged `v0.1.2` host for public historical access. The original private approval and five-file local package remain unchanged evidence; the public GitHub release exposes only the DMG and checksum and does not replace the current public-release workflow.

## Answer

Release `v0.1.2` was locally accepted, tagged, packaged, verified, and approved through the private-transfer workflow, then briefly published for historical access by the repository owner. Its GitHub release record and tag were retired during the later public-version reset, while its accepted commit and protected local evidence remain available. It used unchanged DBCode `1.36.4`, Code OSS `1.126.0`, VSCodium packaging `1.126.04524`, and profile schema 1. The accepted source is `2c02a1600a748974e8ca5920567f15ca1e32c774`, the signed app digest is `a023a794b6e1d5a41cee8f37845048d9665c385c1a4822f572a7c9bdb4ffef67`, and the build reused Compiled Host `compiled-host-b4b90cd2825ec14165f20eb3b969af122012a7f3d881dc4e885aeb0442a69abe`.

The default cached release path took about 196 seconds and required no person-controlled test. Final acceptance owns the static check, and packaging owns mounted verification, so separate repetitions remain diagnostic. The approval changed neither the installed application nor the Standalone DBCode Profile. The later publication changed only GitHub release visibility and retained only the DMG and checksum as public assets.
