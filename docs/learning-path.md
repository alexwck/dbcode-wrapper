# Learning path

Use this guide to learn the real codebase instead of reading files at random.

## 1. Explain the product boundary

Read `README.md`, `CONTEXT.md`, and `docs/architecture/overview.md`. Explain in your own words why VSCodium, Code OSS, Open VSX, DBCode, and the wrapper all appear, and which one owns each responsibility.

## 2. Trace a build

Start at `script/build_host.sh`. Follow source preparation, the patch plan, package slimming, application packaging, signing, and `dist/build-manifest.json`. Note which inputs come from the Release Specification and which files are generated.

## 3. Trace a visible DBCode action

Choose Connections, New Query, Query Builder, a table grid, or a notebook. Follow its focused-shell route into an unchanged DBCode command or view. Confirm that the wrapper supplies navigation rather than database behaviour.

## 4. Trace a profile

Start at the Profile Layout interface. Follow the record into preparation, launch, migration, recovery, proof, and the JavaScript recovery adapter. Identify which paths are durable, which are generated, and which remain in macOS Keychain.

## 5. Trace an Approved Release Set

Start with `host/release-lock.json`. Follow the Release Specification into source-set identity, build manifest, compatibility checks, proof receipts, approval history, installed health, and rollback. Explain why a version string alone cannot authorize an update.

## 6. Compare verification levels

Find one example of each:

- a fast source contract;
- a rendered focused-shell check using an isolated mock Keychain;
- an isolated release-pair check;
- a real-profile licensed proof;
- an installed health or rollback check.

Explain which failure each level can see that the previous level cannot.

## 7. Study connection preservation

Open DBCode's current supported-databases documentation, then inspect `host/dbcode-feature-policy.json`, `host/qa/connection-catalogue-contract.cjs`, and the rendered connection-capability check. Confirm that the wrapper does not copy that vendor catalogue into an allowlist. Run `./script/test_focused_shell_rendered.sh --connection-catalogue-only` after a signed build and compare its digest-only result with the policy. PostgreSQL, DuckDB, Parquet, and SQLite are representative fixtures; the installed unchanged DBCode catalogue remains authoritative.

## 8. Trace generated state

Run `./script/generated_workspace.sh inventory`, then trace one registered root from `script/lib/generated-workspace-retention.js` into its owning build, proof, rendered, upgrade, rollback, or private-release workflow. Explain why unknown output, caches, and worktrees stay protected until their owner records expiry, and why the cleanup command produces a plan without deleting anything. Confirm that protected artifacts and private profile contents are not traversed for size.

## 9. Make one safe change

Pick a documentation or source-contract improvement. Identify its owning module and test seam, make the smallest change, run the narrow test, then run `./script/check_development.sh`. Record the evidence in the local Markdown issue before resolving it.
