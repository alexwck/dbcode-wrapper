# 28 — Establish the learning wiki and repository hygiene

**What to build:** Make the public repository easier to learn without adding another task system or changing the accepted application. Tighten the README, agent rules, ignore policy, and current OpenKnowledge decision; initialize OpenKnowledge locally at the repository root; generate and verify a public, standard-depth codebase wiki under `wiki/`; and remove only harmless repository junk.

**Blocked by:**

**Type:** task

**Status:** resolved

- [x] `README.md` has a short learning section that links the maintained learning path, implementation map, and `wiki/OVERVIEW.md`, and states that OpenKnowledge is optional documentation tooling rather than an application or release dependency.
- [x] Exact release-specific connection counts live with maintained compatibility evidence rather than in the public landing-page explanation; the README still explains the no-allowlist boundary.
- [x] `AGENTS.md` tells agents to use the wiki for orientation only, check its `source_commit`, keep source and tests authoritative, preserve `.scratch/` as the issue tracker, refresh after meaningful architecture changes, use OpenKnowledge tools for `wiki/**/*.md`, and run link and public-source gates after refresh.
- [x] `.gitignore` covers notebook checkpoints, DMG checksum sidecars, and exported Code OSS profiles without ignoring `wiki/`, `.scratch/`, all of `.codex/`, or OpenKnowledge configuration through a broad repository rule.
- [x] The OpenKnowledge research decision reflects the current repository size, public-history state, installed CLI behaviour, repository-root corpus, and the risk of producing `wiki/wiki`.
- [x] OpenKnowledge uses repository-root content scope, user-scoped MCP registration, local-only configuration, no global skill installation, no GitHub sync or sharing, and no semantic search.
- [x] `ok seed --pack codebase-wiki --dry-run` is inspected before seeding and the accepted layout has `wiki/OVERVIEW.md`, not `wiki/wiki/OVERVIEW.md`.
- [x] The generated wiki uses public audience and standard depth, links only source files actually inspected, records the current `source_commit`, and includes architecture, modules, flows, concepts, and a practical owner learning guide.
- [x] OpenKnowledge preview, template validation, and the final link graph report zero dead links and complete overview navigation before the editor is opened.
- [x] `.DS_Store` files and the pre-existing empty `.codex/environments/` directory are removed without touching retained build, acceptance, rollback, release, profile, or current local skill state.
- [x] Documentation checks, the public source-tree contract, and the exact public-ref readiness gate appropriate to the resulting commit pass.

## Answer

The repository now has one public, standard-depth learning wiki rooted at [`wiki/OVERVIEW.md`](../../../wiki/OVERVIEW.md). It explains the product boundaries, focused host and profile, release trust, nine maintained modules, four end-to-end flows, four core concepts, and three practical learning guides. Every page is anchored to source commit `efe247fc701a9b529e3e6368b6571a44541fc146` and uses immutable public source links.

OpenKnowledge is configured only as local documentation tooling. Its corpus is the repository root with maintained Markdown outside `wiki/` excluded locally. User-scoped MCP registration, local-only configuration, disabled Git auto-sync, no authentication, no sharing, no semantic search, and no diagnostic upload preserve the public-source boundary. The seeded project skills remain local and ignored.

The README, agent instructions, ignore policy, and setup research now agree on that model. The old empty `.codex/environments/` folder and discovered `.DS_Store` files were removed. The current `.codex/skills/` content is a relevant local OpenKnowledge projection, not obsolete repository junk, so it was retained outside Git.

Verification:

- OpenKnowledge configuration validation passed.
- All 25 wiki documents passed lint with zero errors and zero warnings.
- The link graph reported zero dead wiki links; the overview links every generated page.
- The live preview rendered the overview Mermaid diagram and a source-linked module page.
- `git diff --check` passed.
- `script/test_public_source_tree_contract.sh` passed.
- `script/test_public_push_readiness.sh` passed.
- The exact prospective public ref passed `script/check_public_push_readiness.sh`; the resulting commit is checked again before any push.

## Comments

- 2026-07-25: Claimed after the owner approved the complete repository-health and learning recommendation. This ticket intentionally does not rebuild or modify the accepted DBCode Wrapper App.
- 2026-07-25: Resolved after the public wiki, local-only OpenKnowledge setup, focused repository hygiene, rendered preview, link audit, and public-source gates passed.
