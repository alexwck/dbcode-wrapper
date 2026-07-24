# 01 — Build the reproducible private macOS host and smoke harness

**What to build:** Produce a repeatable Apple-silicon build that uses VSCodium as the packaging layer around the pinned Code OSS runtime. The user can launch it as its own macOS application, while developers can inspect that same app in diagnostic mode without creating a second full-workbench product.

**Blocked by:** None — can start immediately

**Status:** resolved

## Comments

- 18 July 2026: Implementation started on the current Apple-silicon Mac. The repository is documentation-only with no baseline commit, so this ticket will establish the thin upstream overlay, reproducible build entrypoint, smoke harness, and first scoped commit.

- 18 July 2026: `./script/build_host.sh` built `darwin-arm64` with VSCodium packaging `1.126.04524` (`4015f2d0191311733aa5dbb2abde8101dce63eef`) around Code OSS `1.126.0` (`7e7950df89d055b5a378379db9ee14290772148a`) using locked Node `24.15.0`, npm `11.12.1`, Python `3.12.1`, Apple clang `21.0.0`, and macOS SDK `26.5`.

- 18 July 2026: The review found that the first smoke gate accepted a renderer crash and allowed upstream shared storage. The final implementation gives the product a private shared-data identity, passes an isolated shared-data directory, fingerprints the normal VSCodium shared-data root, and requires a live renderer for three consecutive checks with no fatal helper, GPU, or renderer messages.

- 18 July 2026: Strict nested signature verification passed. The live coexistence proof launched beside VS Code/VSCodium PIDs `28806` and `58620`, kept a stable renderer, used isolated user-data, extension, and shared-data directories, and left normal profiles unchanged.

- 18 July 2026: The manifest records Electron `42.2.0`, Node `24.15.0`, Chromium `148.0.7778.97`, Code OSS `1.126.0`, the source and overlay digests, identity, entitlements, architecture, SQL document association, and final application digest.

- [x] One documented command resolves the exact upstream tag and commit, uses the locked toolchain, builds the `darwin-arm64` application, and reports the source and runtime versions used.
- [x] The application has the DBCode Wrapper name, icon, bundle identifier, URL scheme, and SQL query-document association rather than reusing VSCodium's product identity.
- [x] The build keeps the complete compatible desktop extension host internally and has an explicit development-only diagnostic launch mode for the same DBCode-focused app.
- [x] Nested code is ad hoc signed from the inside out for same-Mac development, and strict signature verification passes after the final bundle is produced.
- [x] A smoke check proves independent launch, correct architecture and identity, no dependency on a running VS Code process, and no access to the normal VS Code profile.
- [x] The build manifest captures the packaging and runtime sources, shell patch revision, toolchain, Electron/Node/Chromium/Code OSS versions, architecture, bundle identity, entitlements, and application digest.
