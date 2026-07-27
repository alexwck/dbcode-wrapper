# 39 — Separate host compilation from release assembly

**What to build:** Make a DBCode-only version bump reuse the unchanged compiled Code OSS host. Keep expensive upstream compilation separate from the smaller work that injects release metadata and wrapper extensions, signs the app, and writes the manifest.

**Blocked by:** None. Candidate 38 provides the retained live timing fixture.

**Type:** task

**Status:** in progress

- [x] Define the exact inputs that affect upstream host compilation and the separate inputs that affect release assembly.
- [x] Accepted release builds read every wrapper input from one clean immutable source ref, never from a mutable working tree.
- [x] Reuse a compiled host only when its complete input digest matches.
- [x] A DBCode-only bump can update the pinned external package record, assemble, sign, and verify a candidate without running the Code OSS build again.
- [x] Documentation, tests, and historical compatibility adapters do not invalidate an unchanged compiled host.
- [x] The source tag, release lock, manifest, app digest, and acceptance report still identify one auditable release set.
- [x] A cache miss, damaged cached host, changed patch, changed upstream revision, changed compile-time slimming choice, or changed compile-time wrapper code falls back to a complete build.
- [x] Focused tests prove cache hits and misses without downloading upstream source or launching the app.
- [ ] Record before-and-after times for a DBCode-only bump and a full host change.

## Comments

- 2026-07-27: The immutable source-set digest is already narrower than the repository, but the build manifest also records a broad digest of `host/` and `script/`, and private packaging requires the annotated source tag to identify the manifest's exact Git commit. The build still reads wrapper inputs from the mutable working tree, so the tag and release lock alone do not prove that every built wrapper file came from that tag. The current `build_host.sh` also recreates the VSCodium worktree and runs the complete upstream build before the smaller copy, metadata, signing, and manifest steps. One immutable release-source boundary should fix the reproducibility gap and make test-only, documentation, historical-adapter, and DBCode-only changes proportionate to their real effect on the wrapper.
- 2026-07-27: `release_source_snapshot.sh` now proves one clean immutable Git source, while `compile_host.sh` and the Compiled Host cache isolate the expensive upstream build. `build_host.sh` reuses only an app whose content-addressed input ID and app digest validate, retains an ordinary damaged entry for investigation, and then performs release-specific extension, record, signing, and manifest assembly. The manifest, prompt-free acceptance report, approved-release record, compatibility manifest, and private verification receipt carry the source snapshot and Compiled Host identity. The prompt-free development gate passed in about 14 seconds without a build or app launch. Live cache-hit and full-build timing remains before this ticket can close.
- 2026-07-27: Independent review found that checking a clean checkout before assembly did not remove the later mutation window. The release launcher now materializes the recorded commit and runs both compilation and assembly from that checkout while keeping generated output in the main repository's ignored roots. The cache key includes the active Release Specification functions, cached app validation includes executable modes, and schema-2 receipts preserve the actual compiler environment. Manifest schema 6 and approval schema 2 make those new fields explicit; older approvals remain readable but cannot become update-ready. The complete prompt-free source gate passed in about 19 seconds after these fixes.
- 2026-07-27: Final review found that release acceptance still trusted detached development and static-smoke log lines. It now re-enters the manifest's materialized source, reruns both fast gates itself, and binds their execution to the source snapshot, release-set ID, signed app digest, and manifest digest. Generated-path validation also rejects symbolic-link ancestors before cache or distribution writes.
- 2026-07-27: The first live timing run completed a full build in 585.89 seconds and reused it in 90.36 seconds without a prompt, but static smoke exposed an unstable input ID. The private snapshot checkout used `600/700` permissions while the normal checkout used `644/755`, even though Git tracked the same files. Compiled Host input schema 2 now reduces source modes to Git's regular-or-executable distinction. A focused regression changes ambient permissions without changing the ID and still proves that removing a tracked executable bit changes the ID. Fresh candidate timing and acceptance remain required after this source fix.
- 2026-07-27: Corrected live timing measured 617.11 seconds for the cache miss and 93.19 seconds for the exact cache hit. Static smoke then passed in 3.96 seconds and the one-profile rendered smoke passed in 14.03 seconds without a prompt. Final acceptance stopped before its gates because the launcher ignored the normalized path returned by `release_source_snapshot_materialize`; on macOS, `/var/...` and its physical `/private/var/...` form compared as different strings. The verifier now uses the returned normalized path, with focused contracts covering both the helper result and the caller.
