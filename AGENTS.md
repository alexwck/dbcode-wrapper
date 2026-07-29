# Agent instructions

Use simple plain English whenever possible without sacrificing engineering quality.

## Agent skills

### Issue tracker

Issues are tracked as local Markdown files under `.scratch/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the standard triage label vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repository. See `docs/agents/domain.md`.

## Reading order

Before changing behaviour, read:

1. `README.md` for the public product and privacy contract.
2. `CONTEXT.md` for the project's domain language.
3. `docs/architecture/overview.md` for the maintained seams and data flow.
4. `wiki/OVERVIEW.md`, when present and current, for derived orientation and links.
5. The current open or claimed issue under `.scratch/dbcode-wrapper-implementation/issues/`, when one exists.
6. `host/README.md` and the exact source or test being changed.

## Sources of truth

- Product language and scope: `CONTEXT.md`.
- Pinned versions, digests, product identity, and toolchain: `host/release-lock.json` through the Release Specification module.
- Supported DBCode routes and known compatibility gaps: `host/dbcode-feature-policy.json`.
- Official feature-family orientation: `docs/product/dbcode-capability-coverage.md`.
- AI and MCP payload guidance: `docs/security/ai-data-sharing.md`.
- Active package slimming and rollback: `host/slimming-policy.json`. Dated size and startup measurements live in linked evidence under `docs/architecture/`.
- Current task state: the open or claimed issue linked from `.scratch/dbcode-wrapper-implementation/map.md`. Resolved issues are dated history.
- Exact behaviour: current source and tests.
- Learning material: `docs/` and, after it is generated, `wiki/`. Learning material is derived and never overrides source or tests.

## Working rules learned from implementation

### Preserve DBCode capability

- Before hiding or removing a DBCode command, view, menu, or context-menu action, check the official DBCode documentation, sanitized contribution evidence already captured by maintained policy or tests, `host/dbcode-feature-policy.json`, and rendered behaviour.
- Remove only a duplicate or proven-broken wrapper route. Keep at least one working DBCode-owned route to every retained capability.
- Register every visible wrapper command before startup prerequisites are resolved. If a prerequisite is missing, route the command to the required setup or a safe error; never leave a visible action pointing to an unregistered command.
- PostgreSQL, DuckDB, Parquet, SQLite, and notebooks are representative acceptance checks, not a connection allowlist. The unchanged DBCode connection catalogue remains authoritative.
- DBCode owns database, notebook, AI, MCP, account, and licence behaviour. The wrapper pins, verifies, integrates, and exposes those features without recreating or redistributing them.
- Treat the DBCode documentation as a capability map, not a backlog for reimplementing DBCode inside the wrapper.
- Add wrapper-owned behaviour only for application identity, profile isolation, packaging and verification, or exposing a DBCode-owned route. Prefer DBCode's implementation whenever it already owns the workflow.
- Record capability evidence as `declared`, `reachable`, `rendered`, or `live`. Opening a route does not prove the complete workflow.
- During a DBCode version bump, compare the official changelog, public extension contributions, maintained feature policy, and rendered behaviour. Give deeper checks to added or changed surfaces.

### AI, MCP, and data privacy

- Track Query Builder AI, Grid AI, inline completion, plan analysis, Explore AI, Copilot Tools, automatic MCP registration, HTTP MCP, and inferred relationships separately.
- Automatic MCP registration and the HTTP MCP server are separate capabilities. Keep HTTP MCP off by default, bound to localhost, and protected by OAuth unless a person deliberately chooses otherwise.
- A local database connection does not mean AI data remains local. Record what each AI feature sends and which provider receives it.
- Never use real private data in AI, Copilot, or MCP tests. DML, DDL, data copy, and workspace relationship writes require an explicit user action.
- Security hardening can be intentionally invisible. Preserve upstream redirect validation, archive extraction checks, and other fail-closed boundaries without adding a wrapper screen merely to make the change visible. Verify the boundary through focused contracts.

### Redesign work

- For shell-wide redesigns, inventory the toolbar, sidebar, editor, result grid, panels, notifications, and right-click actions.
- Walk the user through the proposed keep, move, and remove decisions before implementation.
- Use names that describe the final purpose. Do not keep prototype labels such as `C1` or `C2` in maintained code or documentation.

### Release state and macOS prompts

- Keep automatic update polling, the status icon, review actions, and notifications read-only. They may report public Code OSS, VSCodium, and DBCode records, but they must not change version pins, approve or install a candidate, create a tag, or publish a release.
- Treat update discovery, compatibility testing, approval, installation, and rollback as separate states. Never describe an available or tested version as approved until the complete release-set gate passes.
- Build an accepted release from a clean immutable source ref. Materialize that commit and read compilation and assembly inputs from the materialized source, not from the launcher checkout after a cleanliness check.
- Reuse the exact Compiled Host when its content-addressed inputs match. A DBCode-only bump must not recompile unchanged Code OSS.
- Automated tests must never wait for Keychain, Kernel, Gatekeeper, Safe Storage, sign-in, licence, OAuth, or another person-controlled prompt. Do not approve or bypass those prompts automatically.
- Use one persistent generated `qa` profile for rendered checks. It is separate from the user's Standalone DBCode Profile and is the only automated GUI profile.
- Final acceptance must rerun the fast source and static-smoke gates from the manifest's materialized source. Never accept detached success logs from an earlier source or app.
- Package and approve only when the annotated tag, release lock, build manifest, signed app, final acceptance report, and independent mounted verification identify the same release set.
- Use `script/release_host.sh` as the normal owner-facing release interface. `prepare` may create the annotated tag only after acceptance passes and leaves one tracked approval-history change to commit. Publication remains the separate explicit `publish --publish` action.
- Publish a normal GitHub release with only the host DMG and checksum, then verify the public state, publication timestamp, exact server sizes, and SHA-256 digests.
- Never upload DBCode, profiles, compatibility evidence, verification receipts, or other local release evidence. DBCode remains external and each user obtains it from its official source under their own licence.
- Keep one maintained release path. Before retaining or removing a helper, search current product, build, release, rollback, test, and documentation callers. When a helper survives only through its own test, remove the helper and that test together.
- Keep routine version bumps short: do not create a new issue, refresh the wiki, or rewrite architecture documents unless wrapper behaviour, compatibility, or the release channel changes. Run focused checks while editing and the complete source gate once from the final exact source.

### Paths and temporary work

- Scripts that accept paths must support documented relative paths, absolute paths, and spaces in filenames. Cover those forms with focused automated tests that exercise the script's public interface.
- When a path contract returns a normalized absolute output path, the caller must use that returned value. Do not validate a relative path against the repository and then use the original value against the process working directory.
- Keep generated checkouts, the generated QA profile, screenshots, and temporary evidence under `.build/` or a validated temporary directory. Do not leave temporary evidence folders in the repository root or user home directory.
- Use `./script/generated_workspace.sh inventory` and a cleanup plan before changing generated state. Apply cleanup only to one exact validated expired path. Do not replace the retention contract with ad hoc `rm` commands.
- Classify generated output by its current artifact purpose and explicit expiry. Do not make retention depend on a resolved issue status or emit a retired workflow as current guidance.
- Every temporary file needs one owning function or script and cleanup on success, failure, interruption, and signal paths. A failing test must not leave a temporary Git index or similar generated file behind.
- Add a narrow ignore rule only for a proven generated file family, and add or update the public-source contract in the same change. Do not use a broad ignore rule to hide an unclear file.
- Remove only temporary paths created by the current task. Follow the maintained and generated file rules below for all existing evidence.

## Public and private data

Never inspect, copy into Git, or publish a DBCode VSIX or installed package, licence or account data, credentials, Keychain evidence, private profiles, local databases, signing secrets, or raw real-profile evidence. A normal public release may contain only the independently verified host-only DMG and its checksum. Keep compatibility manifests, verification receipts, other generated evidence, and every DBCode package outside public release assets. Sanitized version numbers, public metadata, cryptographic digests, and pass or fail summaries are allowed where the issue tracker already requires them.

Do not use OpenKnowledge sync, share links, or another publishing route to bypass `script/check_public_push_readiness.sh`.

## Maintained and generated files

Maintain wrapper sources, policies, tests, wrapper extensions, and patches under `host/` and `script/`. Focused-shell TypeScript and CSS live as first-class source under `host/code-oss-overlay/`; the Patch Plan materializes them into Code OSS and verifies the prepared tree. Never hand-edit `dist/`, generated Code OSS/VSCodium checkouts under `.build/`, installed profile content, or rendered test output.

Keep current acceptance evidence, approved rollback backups, the current signed app, and reusable caches until the owning workflow explicitly records their expiry. Rebuildable worktrees, smoke output, and screenshots may be removed only after their evidence is no longer needed.

The Generated Workspace Retention module is the source of truth for ignored build, test, acceptance, rollback, cache, and package roots. Cleanup is a dry run unless one exact validated path is passed with `--apply`; a class cannot be applied. Only deliberately expired output can be removed. Unknown paths, private profiles, active evidence, reusable caches, rebuildable work, symbolic links, broad roots, and protected release assets are not cleanup candidates. Do not traverse protected or unknown roots merely to calculate their size.

## Verification

- Follow `docs/agents/verification-policy.md` when choosing the smallest useful gate.
- Documentation-only changes: run `git diff --check` and the relevant public-source contract.
- Source, policy, or patch changes: run the owning focused tests while working and `./script/check_development.sh` once before resolving the ticket.
- Gate-composition, public-push, host-package, publishing, and deep rollback tests are change-owned checks, not part of the default development path.
- Built-host changes: run the static host smoke and the one-profile rendered focused-shell smoke.
- Release identity, extension inventory, profile, signing, update, or rollback changes: run the relevant automated release-set checks and the prompt-free acceptance command, then record evidence in the issue.
- Every test module has one maintained runner. Use the pinned Node runtime, and remove an old runner in the same change that moves its test.

Full builds are expensive. Prefer `build_host.sh`, which reuses an exact Compiled Host and performs only release assembly when the inputs match. App launches can open GUI windows and trigger real macOS Keychain prompts. Do not force a rebuild, launch the production profile, approve Keychain access, or delete retained release evidence unless the current task requires it and the user has agreed to that gate.

## Documentation sync

When wrapper behaviour changes, update the root README, the relevant maintained guide or policy, the implementation map, and the active issue. Resolve that issue with a final `## Answer`. Do not reopen or rewrite an older resolved issue to describe new behaviour; it remains dated history. A routine version bump updates only the Release Specification, changed compatibility policy, public release notes, and required evidence.

- Keep maintained public documentation forward-facing. Describe the one supported workflow instead of cataloguing removed scripts or retired release paths. Keep historical detail in dated issue comments, the append-only wiki log, and Git history.
- Use simple plain English in public documentation. Keep `README.md` focused on the product, privacy boundary, update status, current release flow, and the shortest useful commands.
- Do not hardcode the current wrapper or upstream versions in maintained guidance. Read them from the Release Specification or link to the latest published release. Version-specific compatibility evidence and release notes may name exact versions.
- Keep operational detail behind the host, command, architecture, and verification guides instead of copying it into the root README.
- Keep research under `.scratch/` only while a current issue or maintained guide links to it. Once its lasting decision is captured in maintained guidance or a resolved issue, remove the unlinked research and rely on Git history for recovery.
- A historical or generated visual is not a current source of truth. Remove it when maintained source, tests, or product guidance has moved on.

## OpenKnowledge

When OpenKnowledge is initialized:

- Use `wiki/OVERVIEW.md` and its linked pages for orientation, but check its `source_commit` before relying on it. Source, policies, and tests remain authoritative.
- Use OpenKnowledge tools for reads, searches, creates, edits, moves, and deletions under `wiki/**/*.md`. Use normal repository tools for source code and for Markdown outside `wiki/`.
- Keep `.scratch/` as the only issue tracker. Do not seed another proposal, decision, specification, or task lifecycle.
- Refresh the wiki after meaningful changes to architecture, modules, product flows, profile handling, or verification. A routine version bump, tag, or published-release record does not need a wiki refresh unless it changes one of those subjects. Do not refresh it for wording-only or fixture-only changes.
- After generation or refresh, require complete overview navigation, zero dead links, `ok preview`, and the public source-tree and exact-ref readiness gates.
- Do not use OpenKnowledge GitHub sync, share links, authentication, semantic search, or diagnostic uploads for this repository.
- OpenKnowledge must remain optional. Builds, tests, releases, and application startup must work when it is not installed.
