# 22 — Preserve every DBCode connection capability

**What to build:** Guarantee that DBCode Wrapper preserves every database, service, cloud provider, and data-file connection contributed by the installed unchanged DBCode version, while retaining bounded representative live proofs.

**Blocked by:** 18, 21

**Type:** task

**Status:** resolved

- [x] The wrapper does not maintain an allowlist of database types and does not filter, rename, intercept, or suppress connection types contributed by unchanged DBCode.
- [x] A version-bound capability snapshot is derived from the locally verified public DBCode contribution surface or rendered connection catalogue without committing copied proprietary package content.
- [x] A changed DBCode catalogue triggers review and acceptance instead of being treated as an unsupported wrapper feature.
- [x] Connections Home, connection creation, import, cloud providers, authentication profiles, tunnels, Database Explorer, connection-specific object actions, and contextual grids remain reachable through focused DBCode routes.
- [x] PostgreSQL, DuckDB, Parquet, SQLite sample, and Python notebook checks remain representative automated or licensed proofs; they are not described as the complete supported list.
- [x] Release acceptance states honestly that actual connectivity also depends on the database server, operating system, credentials, network, optional native drivers, and the installed DBCode version.

## Comments

- 23 July 2026: Added after the user clarified that testing PostgreSQL, DuckDB, and Parquet must not limit the product to those targets. DBCode's current official supported-databases page documents more than 80 databases, services, and data-file targets. The durable wrapper rule is contribution preservation, not a copied static vendor list.
- 23 July 2026: Resolved with schema 2 of `host/dbcode-feature-policy.json`. The wrapper declares no database allowlist or catalogue transformations, passes no arguments to DBCode's owned `dbcode.connections.add` entry point, and keeps Connections Home, import, Tunnels, Authentication Profiles, Database Explorer, and DBCode-owned object actions in the focused route contract.
- 23 July 2026: The isolated mock-Keychain catalogue proof rendered DBCode `1.36.2` with 88 unique choices across 12 counted sections. Git records only item and section counts plus label-set SHA-256 `12660fb76f4cb48095ffd84ef239a71aa7c4245a3078d762131862b4468c178b` and section-shape SHA-256 `36ecc94561bcf7b31f8768ee4ee519d1fc0e2211a9ae2eeb261f81ccfda35327`; it does not store the vendor labels.
- 23 July 2026: `node --test script/test_connection_catalogue_contract.mjs`, `node --test script/test_profile_migration.mjs`, `./script/test_dbcode_feature_contract.sh --source-only`, `./script/test_focused_shell_contract.sh`, and `./script/test_same_mac_release_contract.sh` passed. The exact installed public DBCode manifest also passed during `./script/test_focused_shell_rendered.sh --connection-catalogue-only`, and the rendered snapshot matched the reviewed policy.
- 23 July 2026: Approved Release Set static receipts now carry a separate `connection_capability_contract` result, and `H1/D1` promotion requires it. The complete development suite and controlled-upgrade contracts pass. The full isolated rendered proof also passed all 36 checks against the signed app, including the 88-choice catalogue fingerprint, Python notebook execution, focused connection routes, profile migration, relaunch, and recovery.

## Answer

Every connection choice offered by the exact unchanged DBCode release remains in scope. The named PostgreSQL, DuckDB, Parquet, SQLite, and Python checks test representative depth only. The complete New Connection picker supplies breadth: its exact-version count and fingerprints must match before the personal release can pass. A future DBCode catalogue change stops for review; the wrapper does not discard the new or changed choice.
