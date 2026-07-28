# 31 — Prune superseded generated artifacts safely

**What to build:** After the other-owned-Mac acceptance is complete, use the generated-workspace retention contract to remove superseded QA packages, obsolete screenshots, rebuildable checkouts chosen by the owner, short-path rehearsal leftovers, and expired proof state while preserving the final release and practised rollback.

**Blocked by:** 09, 30

**Type:** task

**Status:** resolved

- [x] The retention inventory is captured before deletion and every selected path is classified as deletable.
- [x] Superseded `qa-1` and `qa-2` Private Personal Release copies are removed only after the final five release assets and their digests are confirmed.
- [x] Accepted but no-longer-needed rendered screenshots and obsolete short-path proof directories are removed through exact validated targets.
- [x] Rebuildable VSCodium and Code OSS worktrees are removed only if the owner accepts the longer next full build; caches remain a separate choice.
- [x] Current acceptance, controlled-upgrade, rollback, final transfer, and sanitized receipt evidence remain valid after cleanup.
- [x] A post-cleanup inventory reports no unknown generated roots and the repository source checks still pass.

## Answer

Generated cleanup is prompt-free but deliberately narrow. Inventory and planning remain read-only by default. `cleanup --path PATH --apply` revalidates and removes one exact expired path; class-wide apply, unknown paths, protected evidence, private profiles, broad paths, unreadable paths, and symbolic links are refused.

The maintained release record already confirms the final five private-transfer assets and their matching filenames, sizes, and SHA-256 digests. No `qa-1` or `qa-2` package copy remained in the current workspace. There was also no separately expired screenshot set. The current single QA profile and current rendered screenshots remain protected.

Exact cleanup removed `.build/q` (2,118 bytes), `.build/smoke-backups` (64 bytes), and `.build/.DS_Store` (8,196 bytes). The historical controlled-upgrade evidence under `.build/u` remains protected. Worktrees and caches remain in place because removing them would slow the next deployment. The post-cleanup inventory reports no unknown roots and an empty expired-output plan.

## Comments

- 2026-07-27: The first current inventory ran without mutation after the other-owned-Mac ticket closed. It found no existing `expired-output` root and kept the accepted app, final package, approval and rollback evidence, one `qa` profile, source snapshots, worktrees, downloads, toolchains, and Compiled Host cache protected.
- 2026-07-27: Four unregistered paths remain: `.build/.DS_Store`, `.build/q`, `.build/u`, and `.build/smoke-backups`. `.DS_Store` and `.build/` are already ignored by Git, so this is a retention-classification problem rather than an ignore-rule gap. No maintained source reference identifies the owners of `q`, `u`, or `smoke-backups`, and the retention contract correctly refuses to traverse or delete unknown roots. They must be identified and deliberately reclassified before an exact cleanup plan can be proposed.
- 2026-07-27: Rebuildable worktrees and reusable caches are not cleanup candidates for the current fast-deployment goal. Removing them would force a longer later build and would not simplify maintained source.
- 2026-07-27: Historical session evidence identified `.build/q` as the retired short-path connection-catalogue profile and `.build/u` as promotion, rollback, installed-set, and restart-health evidence from the old controlled-upgrade flow. The contract now marks `q`, the abandoned empty `smoke-backups` root, and Finder metadata as expired, while protecting `u` without inspecting it. The live inventory reports zero unknown roots.
- 2026-07-27: The expired-output plan is valid and still dry-run only. It selects `.build/q` (2,118 bytes), `.build/smoke-backups` (64 bytes), and `.build/.DS_Store` (8,196 bytes), reports `mutation_performed: false`, and exposes no delete or apply mode. No generated path was removed.
- 2026-07-27: Added exact-path `--apply` behind the same retention checks. Eight focused tests cover file and directory removal, paths with spaces, plan-only class selection, protected neighbours, unknown paths, broad paths, unreadable contents, and symbolic links.
- 2026-07-27: The exact-path command removed only the three planned expired targets. The final release, current QA profile, current screenshots, acceptance evidence, controlled-upgrade evidence, rollback set, worktrees, and caches remain protected. The post-cleanup inventory has zero unknown roots and no remaining expired item. `./script/check_development.sh` passed in 23.98 seconds without rebuilding or launching the app; its existing sandbox-only process-table fixture remained skipped.
