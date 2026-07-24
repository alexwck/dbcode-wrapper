# 02 — Load unchanged DBCode in an isolated host profile

**What to build:** Make the private host install and run the exact approved unchanged DBCode release from Open VSX in a fresh Standalone DBCode Profile, then prove the complete licensed database workflow inside that custom host.

**Blocked by:** 01 — Build the reproducible private macOS host and smoke harness

**Status:** resolved

## Answer

Use the app's own natural macOS profile paths for both scripted and Finder launches, with the verified unchanged DBCode package installed outside the signed bundle in its private current-user extension directory. Keep the full diagnostic profile separate under generated build output. The final proof showed DBCode `1.36.1` restoring the lifetime account, saved connections, and PostgreSQL, DuckDB, and Parquet workflows after a complete quit and relaunch.

## Comments

- 18 July 2026: Implementation started against the approved unchanged DBCode `1.36.1` release. The work is split across three public seams: a pinned and verified official Open VSX acquisition, a private current-user host profile containing only DBCode, and an evidence-backed database plus persistence proof.

- 18 July 2026: The final proof passed with DBCode `1.36.1` in the app's natural macOS self-launch profile. A complete quit and Finder-equivalent relaunch restored the signed-in lifetime account and both saved connections without another licence entry. The proof also recorded the active DBCode activation log, confirmed the private directories use mode `700`, and confirmed the normal VS Code and VSCodium profiles did not change.

- 18 July 2026: Pre-commit review reopened the proof gate to bind every observation to the final relaunch, independently verify the database fixtures, reject missing persisted DuckDB or Parquet files, and cover normal-profile state from before initial preparation through finalization.

- 18 July 2026: The strengthened schema-2 proof passed. The user confirmed the expected PostgreSQL, DuckDB, and direct Parquet results on the linked relaunch; DBCode restored the signed-in account and two saved connections; and the harness verified exact fixture summaries, the active DBCode log, private directory modes, and unchanged durable VS Code/VSCodium profile state. The PostgreSQL proof requested its password once after the profile repair and then saved it through DBCode secret storage without putting it in settings.

- [x] The host acquires the exact approved DBCode version from the official Open VSX record and verifies its publisher, stable status, engine range, registry status, SHA-256, and signature before installation.
- [x] DBCode remains outside the signed app bundle in a current-user-only extension directory that contains no unrelated extension.
- [x] Host and extension automatic updates are disabled, and the normal Extensions view is not required for installation or operation.
- [x] The host uses isolated user-data, shared-data, extension, cache, and log roots and leaves the normal VS Code profile unchanged.
- [x] Normal DBCode activation shows the user's lifetime Pro entitlement without copied or manufactured licence state.
- [x] Server-enforced read-only PostgreSQL, persistent DuckDB, and direct Parquet querying return the expected proof results.
- [x] After a complete quit and independently verified relaunch, the entitlement, saved connections, DuckDB state, and successful queries persist.
- [x] The adapted proof harness records the exact host/DBCode pair and produces clear static, runtime, and persistence evidence.
