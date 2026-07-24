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
4. The relevant issue under `.scratch/dbcode-wrapper-implementation/issues/`.
5. `host/README.md` and the exact source or test being changed.

## Sources of truth

- Product language and scope: `CONTEXT.md`.
- Pinned versions, digests, product identity, and toolchain: `host/release-lock.json` through the Release Specification module.
- Supported DBCode routes and known compatibility gaps: `host/dbcode-feature-policy.json`.
- Package slimming and its rollback: `host/slimming-policy.json`.
- Current task state and evidence: `.scratch/dbcode-wrapper-implementation/`.
- Exact behaviour: current source and tests.
- Learning material: `docs/` and, after it is generated, `wiki/`. Learning material is derived and never overrides source or tests.

## Working rules learned from implementation

### Preserve DBCode capability

- Before hiding or removing a DBCode command, view, menu, or context-menu action, check the official DBCode documentation, sanitized contribution evidence already captured by maintained policy or tests, `host/dbcode-feature-policy.json`, and rendered behaviour.
- Remove only a duplicate or proven-broken wrapper route. Keep at least one working DBCode-owned route to every retained capability.
- PostgreSQL, DuckDB, Parquet, SQLite, and notebooks are representative acceptance checks, not a connection allowlist. The unchanged DBCode connection catalogue remains authoritative.

### Redesign work

- For shell-wide redesigns, inventory the toolbar, sidebar, editor, result grid, panels, notifications, and right-click actions.
- Walk the user through the proposed keep, move, and remove decisions before implementation.
- Use names that describe the final purpose. Do not keep prototype labels such as `C1` or `C2` in maintained code or documentation.

### Release state and macOS prompts

- Treat update discovery, compatibility testing, approval, installation, and rollback as separate states. Never describe an available or tested version as approved until the complete release-set gate passes.
- An accepted source tag is immutable. Package only when the tag, release lock, build manifest, app digest, and final acceptance evidence identify the same release set.
- Fully quit the DBCode Wrapper App before rebuilding, packaging, or testing profile persistence.
- Keychain, Kernel, Gatekeeper, and Safe Storage prompts are explicit human gates. Do not approve or bypass them automatically.
- A distinct host build may need one new approval. A repeated prompt from the exact unchanged app requires investigation before accepting the test result.
- For an authenticated GitHub draft transfer, verify `draft: true`, no publication timestamp, exact uploaded sizes and digests, authenticated owner access, anonymous denial, and the absence of any workflow that can publish it.

### Paths and temporary work

- Scripts that accept paths must support documented relative paths, absolute paths, and spaces in filenames. Cover those forms with focused automated tests that exercise the script's public interface.
- Keep generated checkouts, proof profiles, screenshots, and temporary evidence under `.build/` or a validated temporary directory. Do not leave `.dbcode-proof-*` folders in the repository root or user home directory.
- Remove only temporary paths created by the current task. Follow the maintained and generated file rules below for all existing evidence.

## Public and private data

Never inspect, copy into Git, or publish a DBCode VSIX or installed package, licence or account data, credentials, Keychain evidence, private profiles, local databases, signing secrets, built applications, DMGs, or raw real-profile evidence. Sanitized version numbers, public metadata, cryptographic digests, and pass or fail summaries are allowed where the issue tracker already requires them.

Do not use OpenKnowledge sync, share links, or another publishing route to bypass `script/check_public_push_readiness.sh`.

## Maintained and generated files

Maintain wrapper sources, policies, tests, wrapper extensions, and patches under `host/` and `script/`. Never hand-edit `dist/`, generated Code OSS/VSCodium checkouts under `.build/`, installed profile content, or rendered test output.

Keep current acceptance evidence, approved rollback backups, the current signed app, and reusable caches until the owning ticket says they can be removed. Rebuildable worktrees, smoke output, and screenshots may be removed only after their evidence is no longer needed.

## Verification

- Documentation-only changes: run `git diff --check` and the relevant public-source contract.
- Source, policy, or patch changes: run focused tests while working and `./script/check_development.sh` before resolving the ticket.
- Built-host changes: run the static host smoke and rendered focused-shell checks.
- Release identity, extension inventory, profile, signing, update, or rollback changes: run the complete release-set gates and record evidence in the issue.

Full builds are expensive. App launches can open GUI windows and trigger real macOS Keychain prompts. Do not rebuild, launch the production profile, approve Keychain access, or delete retained release evidence unless the current task requires it and the user has agreed to that gate.

## Documentation sync

When current behaviour changes, update the root README, the relevant maintained guide or policy, the implementation map, and the current `## Answer` of affected resolved issues. Preserve dated issue comments as historical evidence even when they describe an older state.

If OpenKnowledge is initialized, use its tools only for `wiki/**/*.md`. Keep `.scratch/` as the issue tracker and keep source and tests authoritative.
