# Latest upstream release-set check

Research date: 29 July 2026

Live metadata checked at `2026-07-29T13:35:21Z`.

## Answer

The latest stable public records are:

| Input | Current wrapper pin | Latest stable record | Publication | Immutable identity |
| --- | --- | --- | --- | --- |
| Code OSS | `1.126.0` | `1.130.0` | `2026-07-22T17:39:17Z` | commit `1b6a188127eeaf9194f945eb6eb89a657e93c54c` |
| VSCodium | `1.126.04524` | `1.126.04524` | `2026-07-07T13:01:09Z` | commit `4015f2d0191311733aa5dbb2abde8101dce63eef` |
| DBCode | `1.36.4` | `1.36.6` | `2026-07-29T06:55:37.890939Z` | verified Open VSX version plus the package digests below |

This is **not** a compatible three-version upgrade. VSCodium has not published a stable build for Code OSS `1.130.0`; its latest release still says that it updates VS Code to `1.126.0`. The repository has already proved that VSCodium `1.126.04524` cannot prepare Code OSS `1.130.0` because VSCodium's own branding patch fails against that tree. See [issue 38](../issues/38-approve-dbcode-1-36-4-and-hold-code-oss-1-130.md).

The safe next release candidate is therefore:

- keep Code OSS `1.126.0`;
- keep VSCodium `1.126.04524`;
- update the unchanged external DBCode extension to `1.36.6`;
- keep reporting Code OSS `1.130.0` as available but not tested;
- reuse the exact Compiled Host if its content-addressed checks still pass.

This respects the wrapper boundary. DBCode owns every feature listed below. The wrapper should update its exact package and compatibility records, preserve the changed DBCode routes, run the prompt-free source, static, rendered, and release gates, and publish only the host DMG and checksum.

## Official release records

### Code OSS

The official Microsoft GitHub latest-release record reports:

- version and tag: `1.130.0`;
- release ID: `358202500`;
- commit: `1b6a188127eeaf9194f945eb6eb89a657e93c54c`;
- Git tree: `f796245e1336739091b65fe9f3353c9e615c8022`;
- created: `2026-07-22T14:55:04Z`;
- published: `2026-07-22T17:39:17Z`;
- stable: `draft: false`, `prerelease: false`;
- source archive routes: the versioned GitHub tarball and zipball;
- Electron declared by the tagged source: `42.6.0`.

Sources: [official latest-release API](https://api.github.com/repos/microsoft/vscode/releases/latest), [official tag reference](https://api.github.com/repos/microsoft/vscode/git/ref/tags/1.130.0), [release](https://github.com/microsoft/vscode/releases/tag/1.130.0), [release notes](https://code.visualstudio.com/updates/v1_130), and [tagged package manifest](https://raw.githubusercontent.com/microsoft/vscode/1.130.0/package.json).

The GitHub release record says `immutable: false`, so the wrapper should continue pinning the commit rather than trusting only the tag name.

### VSCodium

The official VSCodium GitHub latest-release record reports:

- version and tag: `1.126.04524`;
- release ID: `350287538`;
- commit: `4015f2d0191311733aa5dbb2abde8101dce63eef`;
- source archive asset ID: `469177533`;
- source archive size: `11,052,928` bytes;
- source archive SHA-256: `62a3775aa20d44e970ac62d9c243c6957c57679dac872c8088c5b22ba0d586e1`;
- created: `2026-07-07T12:30:40Z`;
- published: `2026-07-07T13:01:09Z`;
- stable: `draft: false`, `prerelease: false`;
- release description: update VS Code to `1.126.0`.

Sources: [official latest-release API](https://api.github.com/repos/VSCodium/vscodium/releases/latest), [official stable release list](https://api.github.com/repos/VSCodium/vscodium/releases?per_page=10), [official tag reference](https://api.github.com/repos/VSCodium/vscodium/git/ref/tags/1.126.04524), [release](https://github.com/VSCodium/vscodium/releases/tag/1.126.04524), and [source archive](https://github.com/VSCodium/vscodium/releases/download/1.126.04524/VSCodium-1.126.04524-src.tar.gz).

There is no newer stable VSCodium record in the first ten official releases. Keeping this pin is already "latest" for the stable VSCodium feed.

### DBCode

The verified stable Open VSX record reports:

- extension: `dbcode.dbcode`;
- version: `1.36.6`;
- target: `universal`;
- engine: `^1.95.0`;
- published: `2026-07-29T06:55:37.890939Z`;
- stable and verified: `preRelease: false`, `verified: true`;
- deprecated: `false`;
- package size: `43,933,611` bytes;
- package SHA-256: `ec0923b51ce53bda0c11a2559e2646833eb727f39efd9e61114becf122e3b949`;
- package storage version ID: `1XBJk0ucsYbq.WzutBDfLIW3wlK.q.LD`;
- package storage ETag: `a8f0a0184e7be00284b6cdfc18111487`;
- signature archive size: `50,409` bytes;
- signature archive SHA-256: `234873cca677864a8e26f15e85b88179ca85b6f8a9bbd54f5aef908d8c6e2fc9`;
- signature storage version ID: `FV.ej6YxewutSC0AsJsV.oE3hQex_wtj`;
- public key ID: `14ccb407-4e79-41ed-be5a-6d608325c45a`;
- public key SHA-256: `ef5759c51be559f00443ab7d568d26304430bdd422592bfa63e6ac584bfe983b`;
- sorted compact public `contributes` SHA-256: `1a3093dbf560203b193a6e8298ca7198abae7246c4833aba2403d6baa23c93d3`.

Versioned sources: [Open VSX metadata](https://open-vsx.org/api/dbcode/dbcode/1.36.6), [official DBCode changelog](https://dbcode.io/docs/changelog/1.36.6), [public package manifest](https://open-vsx.org/api/dbcode/dbcode/1.36.6/file/package.json), [official SHA-256 record](https://open-vsx.org/api/dbcode/dbcode/1.36.6/file/dbcode.dbcode-1.36.6.sha256), [signature](https://open-vsx.org/api/dbcode/dbcode/1.36.6/file/dbcode.dbcode-1.36.6.sigzip), and [public key](https://open-vsx.org/api/-/public-key/14ccb407-4e79-41ed-be5a-6d608325c45a).

For comparison, DBCode `1.36.5` was published at `2026-07-27T08:36:41.867291Z`, was also stable and verified, and used the same `^1.95.0` engine. Its package SHA-256 was `170bbda0f6182c8086459631dc1c1716bff64b986e0e28fb68041ac95325f607`.

## DBCode changes after 1.36.4

The two new DBCode releases are `1.36.5` and `1.36.6`. The lists below include every item in their official changelog.

### DBCode 1.36.5

Changed upstream:

- CouchDB moved out of Preview.
- Databricks improved suggestions and validation for joins, DML, and DDL.
- DuckLake moved out of Preview.
- Exasol moved out of Preview.
- Apache Kafka moved out of Preview.
- MCP OAuth now redirects only to a URI registered by the client.
- MongoDB can use plain SQL `SELECT`, `INSERT`, `UPDATE`, and `DELETE` alongside its shell syntax.
- Oracle added Thin-mode debugging for supported standalone procedures and functions.
- downloaded driver packages cannot unpack files outside their installation folder;
- Salesforce moved out of Preview.
- the published SBOM now covers every supported platform.
- Stripe supports SQL `SELECT` with pushed-down filters.

Fixed upstream:

- grid writes no longer break on backslashes in PostgreSQL arrays, RavenDB, and InfluxDB values;
- capped Databricks CloudFetch results no longer over-buffer;
- Excel export no longer creates corrupt files when a sheet name contains a quote;
- cloud-host detection now matches a full domain suffix;
- SQL completion and diagnostics are faster in large files;
- PostgreSQL Integrated Kerberos authentication on Windows can complete an SSPI continuation round.

Source: [DBCode 1.36.5 changelog](https://dbcode.io/docs/changelog/1.36.5).

### DBCode 1.36.6

Changed upstream:

- the free tier now includes visual data editing, transaction control, read-only connections and roles, missing-WHERE detection, unlimited history, Favorites and Library, and the MCP server;
- the free tier also includes query parameters, view and routine definitions, file editing, post-connection SQL, saved filters, authentication profiles, `.sql` file execution, folder connections and watched folders, notebook connection locking, Python injection, transpose, column expansion, formatters, quick script, and scratch files;
- DB Explorer Drop and Truncate offer a cascade option where the database supports it;
- a Library item can be opened against a connection selected by the user;
- copy, export, open, share, select-all, and clear-filter/sort actions can be pinned to the results toolbar from its `+` button.

Fixed upstream:

- the SQL editor reuses statement boundaries and ignores stale active-statement updates;
- a multi-object Drop refreshes the DB Explorer tree even when part of the batch fails;
- row-limited Databricks queries regained fast downloads without unbounded memory use;
- Favorites appear only below the database where they were added;
- autocomplete stays on the current statement in multi-statement SQL;
- editor connection idle timeout does not release a connection while a query is still running;
- PostgreSQL partitions appear outside the search path and when a partition is itself partitioned.

Source: [DBCode 1.36.6 changelog](https://dbcode.io/docs/changelog/1.36.6).

## Public contribution comparison

The public contribution digest is unchanged from DBCode `1.36.4` to `1.36.5`:

- `1.36.4`: `8564abd6d8e7c33489a634c64f50decaf22a59192c87574f11b5b09ab9e8c937`;
- `1.36.5`: `8564abd6d8e7c33489a634c64f50decaf22a59192c87574f11b5b09ab9e8c937`.

DBCode `1.36.6` changes that digest to `1a3093dbf560203b193a6e8298ca7198abae7246c4833aba2403d6baa23c93d3`. The public manifest shows three contribution-level changes:

- added command `dbcode.library.openItemWith`, available from DBCode's Library item context menu;
- added application setting `dbcode.grid.toolbarPins`;
- removed the separate `dbcode.item.truncateCascade` command and menu contribution as cascade handling moved into DBCode's current Drop and Truncate flow.

The debugger type, SQL breakpoint contribution, keybindings, contribution families, and VS Code engine range did not change. DBCode still declares `Ctrl+Enter` on macOS for normal SQL execution; it does not declare `Cmd+Enter`.

Sources: the official public manifests for [1.36.4](https://open-vsx.org/api/dbcode/dbcode/1.36.4/file/package.json), [1.36.5](https://open-vsx.org/api/dbcode/dbcode/1.36.5/file/package.json), and [1.36.6](https://open-vsx.org/api/dbcode/dbcode/1.36.6/file/package.json).

## What to consider in this wrapper

### Required for a DBCode 1.36.6 candidate

1. Update the Release Specification with the exact Open VSX record, size, package digest, signature digest, public key, contribution digest, publication time, and versioned changelog URL.
2. Update the DBCode feature policy from `1.36.4` to `1.36.6`.
3. Add `dbcode.library.openItemWith` to the retained Library capability and keep its DBCode-owned context-menu route.
4. Record `dbcode.grid.toolbarPins` under the existing results-and-table-editor capability. The wrapper should preserve DBCode's `+` menu and pinned toolbar actions; it should not create another results renderer.
5. Remove any exact compatibility expectation for the retired `dbcode.item.truncateCascade` contribution. Keep DBCode's current Drop and Truncate commands and never automate their destructive actions.
6. Regenerate the rendered New Connection catalogue fingerprint for the exact `1.36.6` package. Several database drivers changed from Preview to stable, so the previous `1.36.4` catalogue record cannot be assumed.
7. Run the existing prompt-free route checks for Library, Database Explorer, results placement, SQL editor, AI/MCP settings, and the full unchanged connection catalogue. Do not add database, debugger, OAuth, licence, or destructive human gates.

### Useful product implications

- **Results toolbar:** this is the most visible new feature for the focused wrapper. It makes common DBCode actions easier to reach in the result grid below the editor. Preserve it. It does not document a full-result JSON or tree-view toggle, so it does not justify a wrapper-owned JSON renderer.
- **SQL statement handling:** the statement-boundary, stale-active-statement, and multi-statement autocomplete fixes are directly relevant to editing files with several statements. They may reduce the earlier comment and active-statement problems, but the changelog does not specifically promise that every comment-related execution error is fixed.
- **Library:** "Open With Connection" belongs in DBCode's existing Queries > Library surface. No new wrapper menu is needed if the DBCode tree context menu remains reachable.
- **MCP security:** the registered-redirect restriction is a useful upstream hardening. The wrapper should still keep the HTTP MCP server off by default, localhost-bound, OAuth-protected when enabled, and outside automated external-client tests.
- **Driver extraction security:** this protects DBCode-managed runtime driver downloads. It is separate from the wrapper's Open VSX package verifier and does not require a second wrapper implementation.
- **Free tier:** more DBCode-owned capabilities may work without a paid plan. The wrapper should not infer account or licence state, remove the Account surface, or add licence-dependent deployment tests.
- **Database and debugger changes:** MongoDB SQL, Stripe SQL, Oracle Thin debugging, stable driver promotions, Databricks improvements, and PostgreSQL fixes should remain available through DBCode's unchanged catalogue and object actions. They do not need wrapper-specific screens or live release blockers.

### Host decision

Do not pin Code OSS `1.130.0` beside VSCodium `1.126.04524`. That pairing is not an official VSCodium release and has already failed real source preparation in this repository. A DBCode-only bump keeps Code OSS and VSCodium unchanged, so it should reuse the verified Compiled Host and keep deployment short.

When VSCodium publishes a stable release that packages Code OSS `1.130.0` or later, treat that as a separate host candidate. It will require a cold compile, semantic patch review, final prepared-tree verification, signed-host smoke, and the one-profile rendered check.

## Uncertainty and limits

- This is a point-in-time check. Any feed can publish another release after `2026-07-29T13:35:21Z`.
- GitHub marks both latest release objects as mutable. The exact commits are the durable source identities.
- The DBCode assessment uses its official changelog and public Open VSX manifest. It does not inspect the proprietary VSIX or DBCode implementation.
- Public contribution evidence proves declared routes, not their complete live workflows.
- The latest Open VSX record and DBCode changelog agree on `1.36.6`. Final release preparation must fetch and independently verify the exact versioned records again rather than trusting this research note as approval.
