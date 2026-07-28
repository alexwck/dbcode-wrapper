# 42 — Prepare the v0.1.2 wrapper-only Private Personal Release

**What to build:** Turn the completed wrapper maintenance since `v0.1.1` into one prompt-free `v0.1.2` candidate. Keep DBCode `1.36.4`, Code OSS `1.126.0`, VSCodium `1.126.04524`, and profile schema 1 unchanged. Reuse the verified Compiled Host, assemble and sign once, verify the exact source and package, and keep transfer and installation outside this task.

**Blocked by:** 32, 33, 41

**Type:** task

**Status:** claimed

- [ ] One clean immutable candidate commit contains every release-bound wrapper and documentation change.
- [ ] The host build uses the exact verified Compiled Host cache and does not recompile unchanged Code OSS.
- [ ] Static host smoke, exact runtime-package verification, and the one-profile rendered smoke pass.
- [ ] Schema-3 prompt-free acceptance binds the candidate source, release lock, signed app, extension inventory, and rendered report.
- [ ] Annotated tag `v0.1.2` identifies the exact accepted source commit.
- [ ] The host-only package contains exactly the five expected private-transfer assets and passes independent mounted verification.
- [ ] Prompt-free approval adds the exact `v0.1.2` release set to generated approved history without installing the app or changing the production profile.
- [ ] Exact-ref public readiness passes for the candidate source and final documentation commit.
- [ ] No source, tag, package, draft release, or application is pushed, uploaded, published, or installed by this task.

## Comments

- 2026-07-28: Claimed after all prior implementation tickets resolved. This is a wrapper-only patch candidate: upstream versions, profile schema, DBCode package, capability policy, and product scope remain unchanged. The expected path is cached assembly, prompt-free acceptance, local packaging, and generated approval evidence.
