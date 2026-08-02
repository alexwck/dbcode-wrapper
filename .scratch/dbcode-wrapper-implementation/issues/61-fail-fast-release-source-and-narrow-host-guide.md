# 61 — Fail fast on release source and narrow the host guide

**What to change:** Make Host Release preparation reject an unsafe current source before it acquires the distribution checkpoint or starts signing, building, or verification. Keep read-only planning useful, preserve exact same-tag resume and publication, and shorten the host guide to maintained operating instructions with links to the canonical product and architecture docs.

**Blocked by:** None

**Type:** task

**Status:** resolved

## Comments

- 2026-08-02: Claimed after the user approved both candidates from the architecture review. The release change keeps the one maintained release path and does not bump a version, create a tag, package, publish, or change DBCode.
- 2026-08-02: The approved boundary is forward-facing: `plan` reports whether the current source can enter preparation, while `prepare` stops before checkpoint acquisition and all expensive work when the current version tag identifies another commit. An existing annotated tag at the current commit remains resumable, and `publish` continues to use the accepted tagged release set.
- 2026-08-02: No tracked file or folder deletion and no new ignore rule were justified. Current generated paths remain governed by Generated Workspace Retention.
- 2026-08-02: Host Release plan schema 2 now reports the current source and structured preparation readiness. A stale or lightweight tag, off-main source, unclean new source, or unrelated dirty same-tag source stops before checkpoint acquisition and every signing, build, smoke, acceptance, packaging, and approval adapter.
- 2026-08-02: Exact same-tag resume permits only the expected `host/approved-release-history.json` edit. The final tag step rechecks `HEAD` and working-tree state before packaging, so source movement after preflight also fails closed.
- 2026-08-02: The host guide was reduced from 3,078 to 919 words. It keeps build, launch, profile, verification, release, rollback, signing, and prompt boundaries, and links to the canonical product, architecture, capability, privacy, verification, and command guides.
- 2026-08-02: Shell syntax, the change-owned owner-facing release task contract, and the complete prompt-free development gate passed. Host Session reported nine passes and the documented sandbox-only process-table skip. Final specification and engineering reviews reported no findings after three review findings were fixed.
- 2026-08-02: The public wiki was refreshed at source commit `d01539e88c39b72712395899fd206eee40509ab3`. The overview, release-trust architecture, Host Release module, package-and-publish flow, upstream-update guide, and append-only log have zero dead links, all 32 wiki pages pass lint, and the affected diagrams rendered without browser errors.

## Work

- [x] Add a command-level contract for an existing release tag on an older commit.
- [x] Report preparation readiness in the read-only release plan.
- [x] Stop unsafe preparation before checkpoint acquisition, signing, build, or verification.
- [x] Preserve exact same-tag resume and tagged publication behaviour.
- [x] Shorten the host guide and synchronize maintained release guidance.
- [x] Refresh affected wiki pages and validate navigation.
- [x] Run focused checks, the complete prompt-free development gate, and final review.

## Answer

Host Release now fails fast when the current source cannot safely enter preparation. The read-only plan reports the current commit and blocker, and `prepare` stops before the checkpoint lease and expensive work. Exact same-tag resume remains available only for the expected approval-history edit, and the final tag step rechecks the accepted commit before packaging.

The host guide is now a short operating guide instead of a second architecture document. No tracked file, folder, generated path, or ignore rule was removed because the architecture review found no safe candidate. The wrapper remains a focused shell around unchanged DBCode.

The focused release contract, complete prompt-free development gate, final two-lens review, wiki lint and link audit, and rendered wiki check all passed. This issue did not bump a version, build or launch the app, create or move a tag, package, publish, or push.
