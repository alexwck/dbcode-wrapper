# 31 — Prune superseded generated artifacts safely

**What to build:** After the other-owned-Mac acceptance is complete, use the generated-workspace retention contract to remove superseded QA packages, obsolete screenshots, rebuildable checkouts chosen by the owner, short-path rehearsal leftovers, and expired proof state while preserving the final release and practised rollback.

**Blocked by:** 09, 30

**Type:** task

**Status:** claimed

- [x] The retention inventory is captured before deletion and every selected path is classified as deletable.
- [ ] Superseded `qa-1` and `qa-2` Private Personal Release copies are removed only after the final five release assets and their digests are confirmed.
- [ ] Accepted but no-longer-needed rendered screenshots and obsolete short-path proof directories are removed through exact validated targets.
- [ ] Rebuildable VSCodium and Code OSS worktrees are removed only if the owner accepts the longer next full build; caches remain a separate choice.
- [ ] Current acceptance, controlled-upgrade, rollback, final transfer, and sanitized receipt evidence remain valid after cleanup.
- [ ] A post-cleanup inventory reports no unknown generated roots and the repository source checks still pass.

## Comments

- 2026-07-27: The first current inventory ran without mutation after the other-owned-Mac ticket closed. It found no existing `expired-output` root and kept the accepted app, final package, approval and rollback evidence, one `qa` profile, source snapshots, worktrees, downloads, toolchains, and Compiled Host cache protected.
- 2026-07-27: Four unregistered paths remain: `.build/.DS_Store`, `.build/q`, `.build/u`, and `.build/smoke-backups`. `.DS_Store` and `.build/` are already ignored by Git, so this is a retention-classification problem rather than an ignore-rule gap. No maintained source reference identifies the owners of `q`, `u`, or `smoke-backups`, and the retention contract correctly refuses to traverse or delete unknown roots. They must be identified and deliberately reclassified before an exact cleanup plan can be proposed.
- 2026-07-27: Rebuildable worktrees and reusable caches are not cleanup candidates for the current fast-deployment goal. Removing them would force a longer later build and would not simplify maintained source.
- 2026-07-27: Historical session evidence identified `.build/q` as the retired short-path connection-catalogue profile and `.build/u` as promotion, rollback, installed-set, and restart-health evidence from the old controlled-upgrade flow. The contract now marks `q`, the abandoned empty `smoke-backups` root, and Finder metadata as expired, while protecting `u` without inspecting it. The live inventory reports zero unknown roots.
- 2026-07-27: The expired-output plan is valid and still dry-run only. It selects `.build/q` (2,118 bytes), `.build/smoke-backups` (64 bytes), and `.build/.DS_Store` (8,196 bytes), reports `mutation_performed: false`, and exposes no delete or apply mode. No generated path was removed.
