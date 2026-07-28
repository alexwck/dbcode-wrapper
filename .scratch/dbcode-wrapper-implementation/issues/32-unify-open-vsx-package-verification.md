# 32 — Unify Open VSX package verification

**What to build:** Keep separate scripted and Finder first-run acquisition adapters, but route both through one security-critical verification implementation for registry identity, engine compatibility, package size, digests, public keys, signatures, signature manifests, ZIP safety, and VSIX manifests.

**Blocked by:** 09, 31

**Type:** task

**Status:** resolved

- [x] One deep verification module owns every approved Open VSX package invariant.
- [x] `script/verify_openvsx_package.sh` becomes an adapter and no longer implements an independent verification policy.
- [x] Focused Runtime Setup uses the same verifier without weakening its bounded download, redirect, archive, or private-cache protections.
- [x] Shell and in-app acquisition failures have purpose-level, actionable errors without exposing private paths or package contents.
- [x] Adversarial tests mutate every registry field, digest, size, key, signature, archive entry, signature manifest, and VSIX identity through both adapters.
- [x] The complete runtime-extension, first-run setup, rendered, and development gates pass.

## Answer

Open VSX package verification now has one security-critical implementation. The scripted and Finder first-run paths keep separate acquisition adapters, but both use the same checks and the same safe error contract.

The default development gate uses a fast synthetic matrix and needs no human input. The real cached-package gate remains a focused check for verifier changes. The redundant DBCode-only verifier runner was removed.

## Comments

- 2026-07-28: Claimed after issue 31 closed. A failing focused test proved that scripted preparation rejected an incompatible Code OSS engine while Finder first-run verification accepted the same internally consistent package.
- 2026-07-28: `openVsxPackageVerifier.js` now owns package-record validation, engine compatibility, registry identity, sizes, digests, public-key binding, Ed25519 verification, safe ZIP entry handling, signature manifests, and VSIX identity. Finder setup and the script file adapter keep their existing bounded acquisition and private-cache responsibilities.
- 2026-07-28: The prompt-free synthetic matrix passed through both adapters in about 0.2 seconds. The real cached-package gate accepted all seven locked packages and rejected changed metadata. The redundant DBCode-only verifier runner was removed, and the real-cache gate remains change-owned instead of joining the default development path.
- 2026-07-28: Focused runtime setup, profile migration, runtime-extension, private-release, release-identity, development-gate composition, and the complete development source gate passed. Signed-host static and one-profile rendered evidence remain before resolution.
- 2026-07-28: A full host build from source commit `2e4ffb7c354a976f6938e5f6f79f94e1df9d7baf` completed and published compiled-host cache `compiled-host-b4b90cd2825ec14165f20eb3b969af122012a7f3d881dc4e885aeb0442a69abe`. Static host smoke, the exact packaged runtime-extension verifier, and the prompt-free rendered shell gate passed. The rendered gate reused the isolated `.build/qa` profile, made no model call, started no notebook kernel, entered no secret, and performed no database read or write.
