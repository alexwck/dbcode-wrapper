# 16 — Document and clean the maintainable source tree

**What to build:** Make the public source tree easy to understand and safe to maintain before changing its release, profile, launch, and patch architecture.

**Type:** task

**Status:** resolved

- [x] The root README explains the architecture, upstream roles, repository layout, current status, verification ladder, private-data boundary, and learning route without duplicating the host operating guide.
- [x] `AGENTS.md` records the reading order, authoritative files, privacy rules, maintained-source rules, verification tiers, documentation sync rules, and generated-data retention rules.
- [x] Architecture and learning guides explain the current seams and how to trace a wrapper feature through source, build, release, and proof.
- [x] `.gitignore` covers local editors, generated Codex environments, Python environments and caches, macOS metadata, private signing material, database sidecars and backups, and private transfer archives while retaining the tracked public Open VSX verification key.
- [x] Generated `.codex` launch configuration, stale manifest copies, and macOS metadata introduced during development are removed without deleting current release evidence, rollback backups, the signed app, or reusable build inputs.
- [x] Current host documentation, the implementation map, and current issue Answers no longer describe resolved ticket 07 work, ad-hoc signing, six tool routes, or PostgreSQL/DuckDB/Parquet as the complete connection-support list.

## Comments

- 23 July 2026: Claimed after the user approved the documentation and hygiene recommendation together with the five architecture candidates. This ticket changes source guidance and safe local clutter only; it does not rebuild or relabel the app.
- 23 July 2026: Added the architecture overview, active learning path, script and patch guides, expanded README and agent contract, privacy-focused ignore rules, and the OpenKnowledge setup research. Removed the generated Codex full-build action, obsolete duplicate manifest, and identified `.DS_Store` files while retaining every release, rollback, proof, cache, worktree, and current-app artifact. `git diff --check` and the public source-tree contract passed.

## Answer

The repository now explains what VSCodium, Code OSS, Open VSX, DBCode, and the wrapper each own; where maintainers should start; what remains private; which files are authoritative; and which verification gate applies to a change. Generated local editor state, private package/signing/database material, and common macOS clutter are excluded. The implementation tracker now carries tickets 17–22 in dependency order, and all current documentation treats the live database fixtures as representative evidence rather than the product support list.
