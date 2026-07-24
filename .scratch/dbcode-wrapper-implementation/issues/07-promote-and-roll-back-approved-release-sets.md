# 07 — Promote and roll back Approved Release Sets

**What to build:** Give the user a controlled upgrade operation that tests host and DBCode changes in isolation, promotes only a complete approved pair while the app is stopped, and restores the previous complete set if anything fails.

**Blocked by:** 04 — Guide safe first-run profile migration; 06 — Show update availability from official metadata

**Type:** task

**Status:** resolved

- [x] Candidate app, extension, manifest, and cloned-profile directories are separate from the installed set and from normal VS Code.
- [x] The compatibility runner supports current `H0/D0`, new DBCode `H0/D1`, new host `H1/D0`, and intended pair `H1/D1` checks without treating one passing combination as proof of another.
- [x] Static checks verify source and artifact identity, hashes and signatures, architecture, minimum macOS version, DBCode engine range, unchanged package contents, the complete DBCode connection-capability contract, extension allowlist, nested host signature, and required entitlements.
- [x] Runtime checks cover the production database-client redesign, normal Pro activation, PostgreSQL, DuckDB, Parquet, conditional hyphen-path preflight, full quit and relaunch, and absence of bundle mutation or surprise update behaviour.
- [x] Promotion requires explicit confirmation, proves all app processes are stopped, snapshots the current set, and replaces the complete app, exact extension root, manifest, and compatible profile together.
- [x] Restart health checks run before the candidate is accepted, and the immediately previous known-good set remains private and intact until acceptance.
- [x] A practised failure scenario restores the complete previous set without changing user databases, normal VS Code, Keychain secrets, or licence state.
- [x] The implementation contains no privileged or silent automatic updater; failures leave the installed known-good set usable.

## Comments

- 21 July 2026: Claimed after tickets 04 and 06 resolved. The agreed public test seams are the four-combination compatibility runner, stopped-app promotion, restart health acceptance, and complete-set rollback; tests will observe command results and installed-set files rather than private helpers.
- 22 July 2026: Added private release-set preparation and four independent compatibility receipts for `H0/D0`, `H0/D1`, `H1/D0`, and `H1/D1`. Static checks bind the exact source, app, manifest, release lock, external extension inventory, Open VSX packages, engine ranges, architecture, macOS floor, allowlist, signatures, and entitlements. Runtime checks launch and fully quit each isolated pair twice without touching normal editor profiles or enabling updates.
- 22 July 2026: Promotion requires the exact candidate release-set ID and a matrix bound to both descriptor hashes. It rejects non-normalized or overlapping layout paths, stops if any app process remains, takes a private complete snapshot, stages all five targets, and swaps the app, build manifest, extension root, user data, and shared data as one transaction. Restart health must then pass two real-Keychain launches, account restoration, two complete quits, unchanged artifacts, and no update behaviour before acceptance.
- 22 July 2026: Failure-injection tests cover a failure after three swaps, a failure after moving a target but before installing its replacement, and the matching rollback failure. Every case restores the complete active set, leaves no partial transaction directory, and preserves protected normal VS Code, Keychain, and user-database sentinels.
- 22 July 2026: Final review found that DBCode had added SQLite analysis state to its bundled Sakila database. Candidate preparation now restores every signed file from the verified official VSIX inside the isolated copy, preserves required runtime-downloaded native files and host install metadata, rejects unsigned SQLite sidecars, and removes stale WAL, SHM, or journal files when restoring a signed database. The live profile and user databases are not rewritten.
- 22 July 2026: The final sidecar-free DBCode `1.36.2` candidate has extension-root digest `2e7ff115c1082c8525d3556d57ff8e5d13c1b7a0cfd76308acc9dc369cd9260c` and descriptor digest `f1e6f4f72fca4a7e1505abd2951bdf21f85f09174433a44649a572217312c673`. All four real combinations passed. The full disposable promotion used the real macOS Keychain, restored the Pro account without a prompt or Keychain error, launched and quit twice, then rolled back the complete installation to DBCode `1.36.1`. The full development gate also passed.
- 23 July 2026: Ticket 22 added an explicit `connection_capability_contract` result to every static compatibility receipt. Promotion now requires that result for `H1/D1`, so a candidate cannot pass by exercising only the representative PostgreSQL, DuckDB, and Parquet fixtures.
- 24 July 2026: Ticket 26 aligned promotion with final acceptance: all four independent matrix receipts must pass. A failed host-only or DBCode-only pairing now blocks promotion instead of being retained as informational evidence.

## Answer

DBCode Wrapper now has a controlled upgrade and rollback path for complete Approved Release Sets. Host and DBCode updates are still discovered separately, but all four current/candidate combinations must pass before one exact, confirmed app-plus-profile set can be promoted. There is no silent or privileged updater.

The previous working set remains private and complete until the promoted set passes two restart health checks. A failed promotion or rollback restores the active complete set, and a successful rollback restores the previous app, manifest, extensions, user data, and shared data together. The final real rehearsal passed with the lifetime account, PostgreSQL, DuckDB, Parquet, persistence, hyphenated DuckDB path, real Keychain, clean quits, and unchanged signed artifacts.
