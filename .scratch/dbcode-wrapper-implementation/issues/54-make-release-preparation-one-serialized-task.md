# 54 — Make release preparation one serialized task

**What to build:** Make the normal `release_host.sh prepare` action own prompt-free signing readiness, exact-source build or reuse, static smoke, the one persistent-profile rendered smoke, final acceptance, tagging, packaging, independent verification, and approval. Keep publication separate and explicit. Protect `dist/` with one build checkpoint so another build or verifier cannot read or replace it halfway through work, and stage a candidate before replacing the last complete checkpoint.

**Blocked by:** none

**Type:** task

**Status:** claimed

- [x] Add public-interface contracts for complete prepare ordering, exact evidence reuse, and lock refusal.
- [x] Make standalone builds fail signing readiness before assembly.
- [x] Serialize build, smoke, rendered, acceptance, and packaging access to `dist/`.
- [x] Stage a complete signed app and manifest before replacing the existing checkpoint.
- [x] Keep one persistent generated `qa` profile and a separate explicit publication action.
- [x] Update forward-facing architecture, command, verification, and agent guidance.
- [x] Run focused tests, the prompt-free development gate, and final review.

## Comments

- 2026-08-01: Claimed after the user approved every candidate from the architecture and cleanup review. The confirmed public test seams are `script/release_host.sh prepare` and `script/build_host.sh`; tests will observe command ordering, resume behaviour, prompt-free signing failure, and checkpoint-lock refusal through those task interfaces.
- 2026-08-01: Public-interface tests were written around the owner tasks, then the implementation was completed until they passed. `prepare` now owns signing readiness, exact build reuse, static smoke, one persistent-profile rendered smoke, final acceptance, tag, package, independent verification, approval, and exact evidence resume. Publication remains a separate explicit action.
- 2026-08-01: `dist/` now uses one kernel-backed lease inherited by build and verification children. Standalone readers hold it for their full lifetime. Fixed candidate and previous paths make promotion recoverable after interruption. The contracts cover writer-first and reader-first refusal, failed signing, failed stage permissions, failed promotion, failed cleanup, and a live child that retains the lease after its parent is killed.
- 2026-08-01: During fixture development, one mock initially derived its generated root from the caller and touched the ignored real build manifest. Work stopped immediately, the exact prior manifest was restored and checked by digest, and fixture stubs now derive and assert their own root. No built app, profile, DBCode package, credential, or private evidence entered Git.
- 2026-08-01: Generated-workspace inventory found no new ignore gap. `.build/`, `dist/`, `output/`, application packages, profiles, databases, and signing outputs were already covered. The existing 64-byte expired generated path was not created by this task and was left untouched.
- 2026-08-01: Focused build, release, retention, public-source, and Host Release contracts passed. The complete prompt-free development gate passed in about 28 seconds with one existing sandbox-only process-table fixture skipped. No app build, GUI launch, production profile, Keychain approval, database, model, or other human gate was used.
- 2026-08-01: Two independent recursive reviews found and drove fixes for package-resume validation, point-in-time reader checks, interrupted promotion, partial lock metadata, live child ownership, stage cleanup, conditional shell error handling, and fixture process cleanup. Both final recursive reviews reported no remaining actionable findings.
