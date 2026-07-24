# 21 — Consolidate the Code OSS patch stack by semantic seam

**What to build:** Replace the chronological Code OSS patch conversation with a small semantic patch plan while proving that the resulting Code OSS tree is behaviourally identical.

**Blocked by:** 18, 20

**Type:** task

**Status:** resolved

- [x] Code OSS patches are grouped by real seam: product identity and macOS packaging, final focused DBCode shell, host slimming policy, and small release/profile integrations.
- [x] Repeated edits to the focused-shell TypeScript and CSS files are represented once in their final form instead of being replayed through historical UI iterations.
- [x] A patch-plan manifest defines order, purpose, touched areas, and expected digests without making historical filenames part of the product interface.
- [x] A clean pinned Code OSS checkout accepts the consolidated plan and produces the same maintained source tree as the chronological plan before the old files are removed.
- [x] Source contracts verify the applied tree and semantic outcomes rather than requiring obsolete chronological patch names.
- [x] The release identity intentionally changes once, and current candidate evidence is invalidated rather than silently reused.

## Comments

- 23 July 2026: Replaced 13 chronological Code OSS patches with four semantic patches. The patch plan now owns the exact VSCodium and Code OSS order, purpose, file ownership, and SHA-256 for every maintained patch. Source preparation rejects unlisted, missing, reordered, malformed, or changed patches before touching an upstream checkout.
- 23 July 2026: Reconstructed the real pinned VSCodium-before-wrapper baseline, replayed the historical stack, replayed the semantic stack, and compared all 13 maintained Code OSS paths byte for byte. Both patch-stage trees produced `695610f58337f09b2cd533fd6569a86ec017e810f3b63f3568fd6e2648f948ae`. The completed VSCodium preparation tree produced the separately recorded digest `073d30a9e34d75f93293c86e794eb16fc69bce03c90daba3493f77bc19c8615f` after its deterministic copyright substitution.
- 23 July 2026: Clean source preparation copied only the four manifest-listed Code OSS patches. Focused-shell contracts were changed to inspect the final semantic source, which removed stale checks for result-position controls and intermediate surfaces that the approved UI had already deleted.

## Answer

The wrapper now has a short, reviewable patch stack. Each maintained Code OSS file belongs to one semantic patch, the application order is data rather than a filename glob, and the recorded equivalence proof prevents the cleanup from changing the product by accident.
