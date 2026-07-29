# Learning path

Use this guide to learn the real codebase instead of reading files at random.

## 1. Explain the product boundary

Read `README.md`, `CONTEXT.md`, and `docs/architecture/overview.md`. Explain in your own words why VSCodium, Code OSS, Open VSX, DBCode, and the wrapper all appear, and which one owns each responsibility.

## 2. Trace a build

Start at `script/build_host.sh`. Follow the Release Source Snapshot into `script/assemble_host.sh` and the Compiled Host input ID. On the cache-miss path, continue into `script/compile_host.sh`, source preparation, the patch plan, and package slimming. Return to `assemble_host.sh` for wrapper extension assembly, signing, and `dist/build-manifest.json`. Explain which changes require Code OSS compilation and which need only release assembly.

## 3. Trace a visible DBCode action

Choose Connections, New Query, Query Builder, a table grid, or a notebook. Follow its focused-shell route into an unchanged DBCode command or view. Confirm that the wrapper supplies navigation rather than database behaviour.

## 4. Trace a profile

Start at the Profile Layout interface. Follow the record into the normal app profile, the persistent generated `qa` profile, preparation, launch, migration, recovery, and the JavaScript recovery adapter. Identify which paths are durable, which are generated, and which remain in macOS Keychain.

## 5. Trace an Approved Release Set

Start with `host/release-lock.json`. Follow the Release Specification into the immutable source snapshot, Compiled Host identity, source-set identity, build manifest, prompt-free acceptance, approval history, package identity, and rollback notes. Then inspect `script/release_host.sh` to see how the owner-facing task derives those paths while keeping publication explicit. Explain why a version string alone cannot authorize an update.

## 6. Compare verification levels

Find one example of each:

- a fast source contract;
- the static signed-host smoke;
- a rendered focused-shell check using the persistent QA profile and mock Keychain;
- a prompt-free release acceptance report;
- an independently mounted Host Release package check.

Explain which failure each level can see that the previous level cannot.

## 7. Study connection preservation

Open DBCode's current supported-databases documentation, then inspect `host/dbcode-feature-policy.json`, `host/qa/connection-catalogue-contract.cjs`, and the rendered connection-capability check. Confirm that the wrapper does not copy that vendor catalogue into an allowlist. Run `./script/test_focused_shell_rendered.sh --connection-catalogue-only` after a signed build and compare its digest-only result with the policy. PostgreSQL, DuckDB, Parquet, and SQLite are representative fixtures; the installed unchanged DBCode catalogue remains authoritative.

## 8. Trace generated state

Run `./script/generated_workspace.sh inventory`, then trace one registered root from `script/lib/generated-workspace-retention.js` into its owning build, smoke, rendered, acceptance, rollback, or Host Release workflow. Explain why unknown output, caches, and worktrees stay protected until their owner records expiry, and why the cleanup command produces a plan without deleting anything. Confirm that protected artifacts and private profile contents are not traversed for size.

## 9. Make one safe change

Pick a documentation or source-contract improvement. Identify its owning module and test seam, make the smallest change, run the narrow test, then run `./script/check_development.sh`. Record the evidence in the local Markdown issue before resolving it.

## 10. Review AI and MCP boundaries

Read `docs/product/dbcode-capability-coverage.md` and `docs/security/ai-data-sharing.md`. Choose one AI feature and explain its provider, possible payload, user gate, wrapper route, and current evidence level. Confirm that automatic MCP registration is not treated as proof of the optional HTTP MCP server.

## 11. Keep verification fast

Read `docs/agents/verification-policy.md`. For one recent change, identify the focused test, the one final source gate, and any signed-host check. Explain why automated deployment must avoid actions that need a person or external approval.
