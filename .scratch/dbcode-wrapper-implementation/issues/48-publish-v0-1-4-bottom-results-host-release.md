# 48 — Publish v0.1.4 bottom-results Host Release

**What to build:** Publish the committed bottom-query-results wrapper change as the next normal same-repository Host Release. Bump only the wrapper version to `0.1.4`; keep DBCode `1.36.4`, Code OSS `1.126.0`, VSCodium `1.126.04524`, and profile schema 1 unchanged. Reuse the exact Compiled Host cache when valid, run the prompt-free release gate, publish only the host DMG and checksum, and verify the public release.

**Blocked by:** none

**Type:** task

**Status:** resolved

- [x] Bump the wrapper version to `0.1.4` in the Release Specification and commit one clean immutable release source.
- [x] Run or reuse the exact Compiled Host and complete prompt-free release acceptance without human-driven tests.
- [x] Create annotated tag `v0.1.4` only after acceptance identifies the exact source commit.
- [x] Package and independently verify the host-only DMG without bundling DBCode or private profile data.
- [x] Record and commit the exact approved release set without installing the app or changing the production profile.
- [x] Push `main` and `v0.1.4`, create a normal non-draft, non-prerelease GitHub release, and upload only the DMG and checksum.
- [x] Verify the public release state, asset names, server sizes, downloaded digests, final Git state, and current latest-release pointer.

## Comments

- 2026-07-29: Claimed after the user asked to publish the committed bottom-results change. This is a wrapper-only release: upstream versions, the DBCode package, profile schema, connection catalogue, AI/MCP boundary, and product scope remain unchanged.
- 2026-07-29: The repository is clean on `main` and the Host Release plan is available. GitHub CLI is installed, but its saved token is currently invalid; local preparation can continue, while the final push and publication require renewed authentication.
- 2026-07-29: The first cold build stopped before compilation because `compile_host.sh` inspected the maintained Code OSS paths before VSCodium applied the wrapper patches. A focused regression now requires VSCodium to run the tree verifier after preparation and before compilation. The patch-plan and source-only host contracts pass with the corrected order.
- 2026-07-29: The next source guard found that the new VSCodium hook hunk used the wrong pinned Windows-script context. The patch now uses the exact pinned source line, and the host contract applies the maintained VSCodium patch stage to a temporary Git index backed by the pinned source cache. This catches applicability errors without rebuilding, changing a generated checkout, or contacting a service. Code OSS patches still validate against the VSCodium-prepared tree at the real cold-build boundary.
- 2026-07-29: The corrected cold build completed and static and rendered checks passed. Release preparation then stopped before tagging because the owner task looked for the rendered report under the profile/evidence root while the maintained runner writes it under the registered rendered-output root. The task and its focused contract now share the runner's generated-workspace path instead of copying evidence.
- 2026-07-29: Exact-source acceptance then exposed one test-only assumption: the owner-task contract expected rendered output below the temporary materialized source instead of the launcher repository selected by `DBCODE_WRAPPER_GENERATED_REPO_ROOT`. The contract now derives its expectation through Generated Workspace Retention and includes an alternate-root regression. The task's runtime path was already correct.
- 2026-07-29: Final source `a11ed22edf823d77f209ba0b6bc035cc544fa559` passed public-source readiness, the complete development gate, static smoke, all 13 rendered checks, and exact-source prompt-free release acceptance. The build reused Compiled Host `compiled-host-bb6836aa899581d0091ff026837380529cdbc8edbde6741560b1c2e3bdf3cdc0`. The signed app SHA-256 is `e08c746216f19e5380231bd8741e8cc83c598293df1c49b67f2f74ad61c8f65e`.
- 2026-07-29: Annotated tag `v0.1.4` peels to the accepted source. The host-only DMG was verified before and after a read-only mount. Its public size is 187,925,334 bytes and its SHA-256 is `16762cadc20fa2d8c529dddd907c3f81cd6509b75b39f2d342f295f2905be9ca`. The 157-byte checksum asset has SHA-256 `b63f28755b1552f3da757f98862c0be748c67ff7f936175b03f09ef267bde2ff`.
- 2026-07-29: GitHub reports `v0.1.4` as the current latest release, published at `2026-07-29T12:02:30Z`, with `draft: false` and `prerelease: false`. Only the verified DMG and checksum are attached. Remote `main` contains approval commit `ba8bbae87483dbf41b353ae0ea7b5ea225abb89d`, and the release did not install the app or change the production profile.

## Answer

Published [DBCode Wrapper v0.1.4](https://github.com/alexwck/dbcode-wrapper/releases/tag/v0.1.4) as the normal public Host Release in the same repository. It keeps DBCode `1.36.4`, Code OSS `1.126.0`, VSCodium `1.126.04524`, and profile schema 1 unchanged. The release contains only the independently verified Apple-silicon DMG and its checksum.
