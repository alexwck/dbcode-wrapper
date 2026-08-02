# 61 — Fail fast on release source and narrow the host guide

**What to change:** Make Host Release preparation reject an unsafe current source before it acquires the distribution checkpoint or starts signing, building, or verification. Keep read-only planning useful, preserve exact same-tag resume and publication, and shorten the host guide to maintained operating instructions with links to the canonical product and architecture docs.

**Blocked by:** None

**Type:** task

**Status:** claimed

## Comments

- 2026-08-02: Claimed after the user approved both candidates from the architecture review. The release change keeps the one maintained release path and does not bump a version, create a tag, package, publish, or change DBCode.
- 2026-08-02: The approved boundary is forward-facing: `plan` reports whether the current source can enter preparation, while `prepare` stops before checkpoint acquisition and all expensive work when the current version tag identifies another commit. An existing annotated tag at the current commit remains resumable, and `publish` continues to use the accepted tagged release set.
- 2026-08-02: No tracked file or folder deletion and no new ignore rule were justified. Current generated paths remain governed by Generated Workspace Retention.

## Work

- [x] Add a command-level contract for an existing release tag on an older commit.
- [x] Report preparation readiness in the read-only release plan.
- [x] Stop unsafe preparation before checkpoint acquisition, signing, build, or verification.
- [x] Preserve exact same-tag resume and tagged publication behaviour.
- [x] Shorten the host guide and synchronize maintained release guidance.
- [ ] Refresh affected wiki pages and validate navigation.
- [ ] Run focused checks, the complete prompt-free development gate, and final review.

## Answer

Pending implementation and verification.
