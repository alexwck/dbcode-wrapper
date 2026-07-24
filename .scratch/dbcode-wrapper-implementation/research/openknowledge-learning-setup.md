# OpenKnowledge setup for learning DBCode Wrapper

Date: 2026-07-25

## Recommendation

Set up OpenKnowledge, but use it only to produce and explore a **public codebase wiki** under `wiki/`. Do not use its Software lifecycle starter pack and do not replace the local Markdown issue tracker.

Keep OpenKnowledge's own configuration, generated templates, project skill, MCP registration, runtime data, and Git integration local to each owned Mac. Commit only the reviewed `wiki/**/*.md` learning pages. This gives the owner the useful architecture map, diagrams, backlinks, search, and guided learning path without adding a second issue system or mixing OpenKnowledge-owned files into the public source repository.

The clean public Git history and annotated `v0.1.0` baseline now exist, so setup may proceed without creating an immediately obsolete freshness anchor. OpenKnowledge's Codebase wiki records a `source_commit` in `wiki/OVERVIEW.md` and uses it to determine what changed during later refreshes ([Codebase wiki](https://openknowledge.ai/docs/workflows/codebase-wiki)).

## Why this repository benefits

This is no longer a small wrapper with one obvious entry point. The public tree has more than 190 maintained files, with most implementation and verification behaviour under `script/` and `host/`. Important behaviour is spread across:

- the host architecture and operating workflow in [`host/README.md`](../../../host/README.md);
- the stable product language and boundaries in [`CONTEXT.md`](../../../CONTEXT.md);
- source and runtime pins in `host/release-lock.json`;
- release, profile, update, signing, migration, and proof scripts under `script/`;
- three wrapper extensions under `host/extensions/`;
- the Code OSS and VSCodium patch series under `host/patches/`;
- current decisions and implementation history in the [implementation map](../map.md) and 15 local issue files.

The long host README is useful as an operating reference, but it is not an easy learning route through those relationships. A codebase wiki is designed to add an overview, architecture pages, module pages, end-to-end flows, concepts, task guides, diagrams, and links to the files the agent actually read. OpenKnowledge's official pack also distinguishes `public` from `internal` audience and `tour`, `standard`, and `exhaustive` depth ([Codebase wiki](https://openknowledge.ai/docs/workflows/codebase-wiki)).

For this repository, choose:

- audience: `public`;
- depth: `standard`;
- one additional owner-focused guide: `wiki/guides/learning-path.md`.

`standard` is deep enough to expose the architecture and important flows without creating a page for every small shell helper. The learning-path guide can then tell the owner what to read, run, and trace in order.

## What OpenKnowledge adds

OpenKnowledge stores knowledge as ordinary Markdown or MDX, with an editor for the owner and MCP tools for agents ([Overview](https://openknowledge.ai/docs/get-started/overview)). Its agent search works over live files, backlinks, link context, and version history rather than a detached generated index. Its write path reports broken links and orphans, and the Codebase wiki workflow finishes with a link-graph audit ([Agentic search](https://openknowledge.ai/docs/reference/agentic-search)).

For learning this project, that supports questions such as:

- Why are Code OSS and VSCodium both present?
- What is inside the application, and what stays in the private profile?
- How does one Code OSS and DBCode pair become an Approved Release Set?
- Which checks prevent two independently updated components from being promoted together without testing?
- What happens from `build_host.sh` through signing, launch, proof, approval, packaging, and rollback?
- Which parts belong to unchanged DBCode and which parts are wrapper-owned?

The MCP surface supplies ranked search, link-graph inspection, history, read-only file commands, attributed Markdown writes, checkpoints, and conflict handling ([MCP reference](https://openknowledge.ai/docs/reference/mcp)). This is useful for navigating and maintaining the wiki. It is not a source-code index or a replacement for reading the implementation. The official Codebase wiki workflow says agents read source code with native file tools, then author the wiki through OpenKnowledge ([Codebase wiki](https://openknowledge.ai/docs/workflows/codebase-wiki)).

## Proposed wiki shape

Let the pack survey the current public commit and confirm the page list with the owner before it writes anything. A sensible starting shape is:

```text
wiki/
  OVERVIEW.md
  log.md
  architecture/
    product-and-upstream-boundaries.md
    host-and-private-profile.md
    release-set-trust-model.md
  modules/
    build-and-patch-overlay.md
    focused-code-oss-shell.md
    profile-and-extension-management.md
    update-approval-and-rollback.md
    verification-and-proof-harness.md
  flows/
    build-sign-and-launch.md
    install-activate-and-query.md
    controlled-upgrade-and-rollback.md
    public-source-and-private-release.md
  concepts/
    approved-release-set.md
    unmodified-extension-boundary.md
    standalone-dbcode-profile.md
  guides/
    learning-path.md
    trace-a-wrapper-feature.md
```

The learning path should be active rather than purely descriptive. For example:

1. Read the big-picture diagram and explain the external DBCode boundary in the owner's own words.
2. Trace `script/build_host.sh` into the source preparation, patch, package, and signing steps.
3. Pick one visible action and follow it from a Code OSS patch into a wrapper extension or DBCode command.
4. Trace one approved release identity from `host/release-lock.json` through its automated checks and real-profile proof.
5. Compare a source contract test, an isolated rendered test, and a real-Keychain acceptance check and explain why all three exist.

That makes the wiki a curriculum for the real codebase rather than a static summary.

## Keep the local issue tracker

The existing contract is clear: work lives under `.scratch/`, and tickets use the conventions in [`docs/agents/issue-tracker.md`](../../../docs/agents/issue-tracker.md). Keep that system as the single source of truth for status, dependencies, claims, evidence, comments, and answers.

Do **not** seed OpenKnowledge's Software lifecycle pack. That pack creates `proposals/`, `decisions/`, `specs/`, `postmortems/`, and `guides/` with its own lifecycle and project skill ([Software lifecycle](https://openknowledge.ai/docs/workflows/software-lifecycle)). In this repository, it would overlap with the existing map, issues, comments, answers, and domain records without solving a current problem.

Use this separation:

| Concern | Source of truth |
| --- | --- |
| Current task state and evidence | `.scratch/dbcode-wrapper-implementation/` |
| Stable product language and boundaries | `CONTEXT.md` |
| Exact behaviour | Current source, policies, and tests |
| How the pieces fit and how to learn them | `wiki/` |

The wiki should distil current behaviour. It should not copy full issue discussions or use an old ticket as authority when the code and current contracts disagree. The issue history can still be opened with normal repository tools when the owner wants to understand how a decision evolved.

## Minimal, privacy-conscious setup

The locally installed `ok` command reported version `0.34.0` during this review, while the official GitHub "latest release" link resolved to `0.32.0` ([official OpenKnowledge repository](https://github.com/inkeep/open-knowledge/releases/latest)). The two distribution channels therefore do not currently present one simple version order. Do not upgrade or downgrade blindly. Use the installed CLI only after confirming the required flags with `ok init --help` and `ok seed --help`, then preview every repository write with a dry run.

After the clean public baseline commit exists:

```sh
ok init \
  --content-dir . \
  --scope user \
  --local-only \
  --no-skills

ok seed --pack codebase-wiki --dry-run
```

Review the dry-run file list and accept it only when it creates `wiki/OVERVIEW.md`, not `wiki/wiki/OVERVIEW.md`. Then seed the pack and ask the agent to generate the Codebase wiki with `public` audience and `standard` depth. `--no-skills` prevents installation of optional user-global skill bundles; the Codebase wiki pack still supplies its project workflow locally. The CLI documents `--content-dir`, editor registration scope, local-only configuration, skill controls, dry-run seeding, preview, and config validation ([CLI reference](https://openknowledge.ai/docs/reference/cli)).

This layout is intentionally narrow:

- `content.dir: .` matches the Codebase wiki workflow's repository-root assumption, so its built-in `wiki/` path resolves once rather than becoming `wiki/wiki/`.
- A local `.okignore` hides `.scratch/` and maintained Markdown outside `wiki/` from OpenKnowledge search and agent tools. Source code remains available through normal repository tools.
- `--scope user` avoids committing MCP configuration for every supported editor when this is currently a one-owner project.
- `--local-only` uses OpenKnowledge's supported per-clone Git exclusion for its configuration. The public wiki Markdown remains ordinary tracked content.
- `--no-skills` avoids installing unrelated global skill bundles. The seeded codebase workflow remains local to this project.

OpenKnowledge documents that `ok init` may create `.ok/`, `.okignore`, editor MCP entries, global skills, local runtime state, a shadow Git repository, home-directory state, and credential-store records depending on the chosen options. Its local-only and project/user-scope controls are the supported way to constrain that footprint ([What OpenKnowledge writes](https://openknowledge.ai/docs/reference/what-open-knowledge-writes)). Run `ok diagnose` after setup to inspect what was created.

Do not add `.ok/` to the repository's normal `.gitignore` as a substitute for the supported local-only mode. Keeping the choice in OpenKnowledge's per-clone config avoids silently changing the repository's public ignore policy. Confirm the result with:

```sh
ok config-sharing status
ok config validate
ok preview
git status --short
```

Only `wiki/**/*.md` and an intentional README or AGENTS instruction should be staged for the public repository.

## Privacy and public-source rules

OpenKnowledge does not replace this repository's privacy gates.

- `.okignore` controls search and agent visibility. It does not stop Git from tracking or publishing a file. OpenKnowledge separately honours `.gitignore`, but `.gitignore` remains the Git boundary ([Ignore patterns](https://openknowledge.ai/docs/features/ignore-patterns)).
- `script/check_public_push_readiness.sh` must still inspect the exact public ref after every wiki generation or refresh.
- A `public` wiki audience reduces the chance of internal details appearing, but generated prose and links still require human review.
- Do not put licence keys, database credentials, profile contents, raw Keychain evidence, private paths, private release URLs, or unpublished DMG details in the wiki.
- Keep semantic search disabled. It is off by default; enabling it sends queries and matching content to the configured embeddings provider ([Configuration](https://openknowledge.ai/docs/reference/configuration)).
- Do not enable OpenKnowledge GitHub sync, share links, or `ok auth login` for this setup. Use the repository's normal reviewed Git workflow so a wiki edit cannot bypass the exact-ref publication gate. The CLI's `ok sync`, `ok pull`, and `ok push` operate on the Git remote ([CLI reference](https://openknowledge.ai/docs/reference/cli)).
- OpenKnowledge states that normal project data stays local by default, while GitHub sync, sharing, semantic search, and submitted diagnostic bundles cause data to leave the machine. Its desktop app also performs update checks and a one-time first-launch share-link check ([What OpenKnowledge writes](https://openknowledge.ai/docs/reference/what-open-knowledge-writes)).

OpenKnowledge itself is GPL-3.0-or-later software ([official repository](https://github.com/inkeep/open-knowledge)). Keeping its configuration, copied project skill, and pack templates local avoids introducing another third-party licence surface into the All Rights Reserved public source tree. Generated wiki pages still require public-source review and are covered by the repository's existing licence decision.

## Maintenance cost

The setup cost is moderate once: update the tool, initialize locally, dry-run the pack, agree the coverage, generate the wiki, review every page, fix link findings, and pass the public-ref check.

Ongoing cost is small if refreshes are tied to meaningful changes rather than every commit:

- refresh after a host/DBCode release-set change;
- refresh after a patch changes the focused shell or visible workflow;
- refresh after profile, update, rollback, signing, or release architecture changes;
- skip refreshes for comments, test-fixture wording, and other changes that do not alter the architecture or learning path;
- run the link audit and public-ref gate after every refresh.

The official pack refreshes from `source_commit` and updates only affected pages after significant merges ([Codebase wiki](https://openknowledge.ai/docs/workflows/codebase-wiki)). The wiki therefore needs a named owner and refresh discipline, but it does not need to become a release or CI dependency. The DBCode Wrapper build, app package, source contracts, and release-set approval must continue to work when OpenKnowledge is not installed.

## Suggested future repository instructions

If the owner approves this setup, make small follow-up edits rather than embedding the whole policy everywhere:

- In `README.md`, add an optional **Learn the architecture** section linking to `wiki/OVERVIEW.md` and state that OpenKnowledge is optional developer documentation tooling, not an app dependency.
- In `AGENTS.md`, state that code and tests are authoritative; read `wiki/OVERVIEW.md` before architecture work; use OpenKnowledge tools only for `wiki/**/*.md`; keep `.scratch/` as the issue tracker; and never use OpenKnowledge sync to bypass the public-push gate.
- Keep the setup commands in one short learning guide rather than duplicating them across README, AGENTS, and host documentation.

## Decision

OpenKnowledge is worthwhile here because the codebase has enough build, host, profile, compatibility, signing, and release machinery that a linked architectural learning path adds real value. The minimal setup is a locally managed OpenKnowledge Codebase wiki whose reviewed Markdown pages are public. It should complement the source and the existing local Markdown tracker, not become another task system, another release dependency, or another Git publisher.
