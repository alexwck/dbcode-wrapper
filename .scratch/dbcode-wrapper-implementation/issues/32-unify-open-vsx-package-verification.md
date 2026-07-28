# 32 — Unify Open VSX package verification

**What to build:** Keep separate scripted and Finder first-run acquisition adapters, but route both through one security-critical verification implementation for registry identity, engine compatibility, package size, digests, public keys, signatures, signature manifests, ZIP safety, and VSIX manifests.

**Blocked by:** 09, 31

**Type:** task

**Status:** open

- [x] One deep verification module owns every approved Open VSX package invariant.
- [x] `script/verify_openvsx_package.sh` becomes an adapter and no longer implements an independent verification policy.
- [x] Focused Runtime Setup uses the same verifier without weakening its bounded download, redirect, archive, or private-cache protections.
- [x] Shell and in-app acquisition failures have purpose-level, actionable errors without exposing private paths or package contents.
- [x] Adversarial tests mutate every registry field, digest, size, key, signature, archive entry, signature manifest, and VSIX identity through both adapters.
- [ ] The complete runtime-extension, first-run setup, rendered, and development gates pass.

## Comments

- 2026-07-28: Claimed after issue 31 closed. A failing focused test proved that scripted preparation rejected an incompatible Code OSS engine while Finder first-run verification accepted the same internally consistent package.
- 2026-07-28: `openVsxPackageVerifier.js` now owns package-record validation, engine compatibility, registry identity, sizes, digests, public-key binding, Ed25519 verification, safe ZIP entry handling, signature manifests, and VSIX identity. Finder setup and the script file adapter keep their existing bounded acquisition and private-cache responsibilities.
- 2026-07-28: The prompt-free synthetic matrix passed through both adapters in about 0.2 seconds. The real cached-package gate accepted all seven locked packages and rejected changed metadata. The redundant DBCode-only verifier runner was removed, and the real-cache gate remains change-owned instead of joining the default development path.
- 2026-07-28: Focused runtime setup, profile migration, runtime-extension, private-release, release-identity, development-gate composition, and the complete development source gate passed. Signed-host static and one-profile rendered evidence remain before resolution.
