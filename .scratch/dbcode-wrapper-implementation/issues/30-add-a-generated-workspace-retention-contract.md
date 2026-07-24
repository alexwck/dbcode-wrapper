# 30 — Add a generated workspace retention contract

**What to build:** Put ignored build, test, acceptance, rollback, cache, and package output behind one inspectable retention contract. The first implementation inventories and explains generated state and produces a dry-run plan; it does not delete material evidence.

**Blocked by:** 29

**Type:** task

**Status:** open

- [ ] One maintained module defines known generated roots and classifies them as active evidence, rollback evidence, final transfer assets, reusable cache, rebuildable work, expired output, or unknown.
- [ ] One task-level command inventories path, size, classification, reason, owning workflow or ticket, and whether deletion is currently allowed.
- [ ] Cleanup is dry-run by default, accepts only explicit classes or exact validated paths, refuses unknown paths, symlink escapes, repository roots, home directories, and active evidence.
- [ ] The accepted app, final DMG, acceptance report, controlled-upgrade receipts, approved rollback backups, and current private profile are protected while the other-owned-Mac ticket remains open.
- [ ] Build, smoke, rendered, proof, controlled-upgrade, rollback, and private-release workflows register or derive their generated roots through the maintained contract instead of relying only on prose.
- [ ] Focused tests cover spaces, relative and absolute paths, unknown entries, symlinks, protected evidence, expired fixtures, and a no-mutation inventory run.
- [ ] `AGENTS.md` and the command guide point cleanup work at the maintained retention command rather than ad hoc deletion.
