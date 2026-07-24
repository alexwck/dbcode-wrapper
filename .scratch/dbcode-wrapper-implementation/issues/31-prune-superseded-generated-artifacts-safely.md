# 31 — Prune superseded generated artifacts safely

**What to build:** After the other-owned-Mac acceptance is complete, use the generated-workspace retention contract to remove superseded QA packages, obsolete screenshots, rebuildable checkouts chosen by the owner, short-path rehearsal leftovers, and expired proof state while preserving the final release and practised rollback.

**Blocked by:** 09, 30

**Type:** task

**Status:** open

- [ ] The retention inventory is captured before deletion and every selected path is classified as deletable.
- [ ] Superseded `qa-1` and `qa-2` Private Personal Release copies are removed only after the final five release assets and their digests are confirmed.
- [ ] Accepted but no-longer-needed rendered screenshots and obsolete short-path proof directories are removed through exact validated targets.
- [ ] Rebuildable VSCodium and Code OSS worktrees are removed only if the owner accepts the longer next full build; caches remain a separate choice.
- [ ] Current acceptance, controlled-upgrade, rollback, final transfer, and sanitized receipt evidence remain valid after cleanup.
- [ ] A post-cleanup inventory reports no unknown generated roots and the repository source checks still pass.
