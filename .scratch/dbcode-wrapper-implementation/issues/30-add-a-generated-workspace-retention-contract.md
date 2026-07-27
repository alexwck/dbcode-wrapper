# 30 — Add a generated workspace retention contract

**What to build:** Put ignored build, test, acceptance, rollback, cache, and package output behind one inspectable retention contract. The first implementation inventories and explains generated state and produces a dry-run plan; it does not delete material evidence.

**Blocked by:** 29

**Type:** task

**Status:** resolved

- [x] One maintained module defines known generated roots and classifies them as active evidence, rollback evidence, final transfer assets, reusable cache, rebuildable work, expired output, or unknown.
- [x] One task-level command inventories path, safe size status, classification, reason, owning workflow or ticket, and whether deletion is currently allowed.
- [x] Cleanup is dry-run by default, accepts only explicit classes or exact validated paths, refuses unknown paths, symlink escapes, repository roots, home directories, and active evidence.
- [x] The accepted app, final DMG, acceptance report, controlled-upgrade receipts, approved rollback backups, and current private profile are protected while the other-owned-Mac ticket remains open.
- [x] Build, smoke, rendered, proof, controlled-upgrade, rollback, and private-release workflows register or derive their generated roots through the maintained contract instead of relying only on prose.
- [x] Focused tests cover spaces, relative and absolute paths, unknown entries, symlinks, protected evidence, expired fixtures, and a no-mutation inventory run.
- [x] `AGENTS.md` and the command guide point cleanup work at the maintained retention command rather than ad hoc deletion.

## Answer

Generated state now has one maintained Retention Contract and one public task command. `./script/generated_workspace.sh inventory` reports registered and unknown paths without changing them. Only explicitly registered expired output is measured; protected artifacts, caches, worktrees, unknown paths, and private profile contents are not traversed. `cleanup --class` and `cleanup --path` validate only explicit eligible selections and return a dry-run plan; this implementation has no delete or apply mode.

Build, smoke, rendered, proof, controlled-upgrade, same-Mac acceptance, rollback, private packaging, and independent package-verification callers now resolve their normalized output roots through the same contract. Current release evidence, caches, worktrees, rollback backups, transfer assets, the accepted host, and the private profile remain protected. The current inventory has no unknown root: it protects the historical short-path controlled-upgrade receipts and limits the dry-run plan to Finder metadata, an obsolete short-path catalogue profile, and an abandoned smoke-backup root.

## Comments

- 2026-07-25: The focused retention contract, workflow-registration contract, development-gate ownership contract, profile-path contract, Python-notebook contract, rollback contract, private-release contract, focused-shell contract, and controlled-upgrade contract passed. The live inventory reported every required classification, kept protected and private paths uninspected, performed no mutation, and refused an exact unknown path. `./script/check_development.sh` then passed without rebuilding or launching the app.
- 2026-07-25: Independent specification and code-quality review prompted fixes for the public ticket-state override, protected-artifact traversal, premature cache/worktree expiry, unreadable-tree, managed-root symlink, bootstrap-before-validation, relative-path reuse, macOS temporary-path alias, and unregistered acceptance-receipt gaps. Seven focused module tests and the complete development gate passed after those changes. The live task command reported all seven classifications, 15 protected repository roots without traversal, three protected unknown entries, no existing cleanup candidate, and no mutation.
- 2026-07-25: Final independent specification and code-quality re-reviews found no actionable source findings. The last complete development gate passed after runtime-cache, smoke-staging, rollback-worktree, test-only temporary-output, and private-package staging integration was added. No app build, launch, private profile read, or generated-state deletion was performed.
