# 32 — Unify Open VSX package verification

**What to build:** Keep separate scripted and Finder first-run acquisition adapters, but route both through one security-critical verification implementation for registry identity, engine compatibility, package size, digests, public keys, signatures, signature manifests, ZIP safety, and VSIX manifests.

**Blocked by:** 09, 31

**Type:** task

**Status:** open

- [ ] One deep verification module owns every approved Open VSX package invariant.
- [ ] `script/verify_openvsx_package.sh` becomes an adapter and no longer implements an independent verification policy.
- [ ] Focused Runtime Setup uses the same verifier without weakening its bounded download, redirect, archive, or private-cache protections.
- [ ] Shell and in-app acquisition failures have purpose-level, actionable errors without exposing private paths or package contents.
- [ ] Adversarial tests mutate every registry field, digest, size, key, signature, archive entry, signature manifest, and VSIX identity through both adapters.
- [ ] The complete runtime-extension, first-run setup, rendered, and development gates pass.
