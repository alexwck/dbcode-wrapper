# 14 — Audit official DBCode feature coverage

**What to research:** Cross-check the focused, slim DBCode Wrapper against DBCode's official documentation so consolidation removes only duplicate routes, not documented DBCode capability.

**Blocked by:** 05, 13

**Type:** research

**Status:** resolved

## Comments

- 20 July 2026: Claimed for a primary-source audit of the current DBCode documentation, the locally installed public package manifest for `dbcode.dbcode@1.36.1`, the focused feature policy, slimming policy, maintained host patches, and rendered acceptance coverage. No removal is justified merely because a route is awkward; every gap must distinguish missing capability from consolidated navigation, host-version incompatibility, or intentional product scope.
- 20 July 2026: Resolved after inventorying every product-workflow section in the live documentation and comparing it with the approved wrapper. The audit found that most DBCode-owned views, context actions, grids, and webviews remain present, but it also found several real compatibility gaps that must not be described as harmless duplicate removal.
- 20 July 2026: A final link check followed all 115 unique official DBCode and Open VSX references in this audit; every URL returned HTTP 200. The current signed app was also measured directly at `461,668 KiB`.

## Short answer

Keep the focused DBCode desktop design and keep the slim base package. The current approach has not removed DBCode's core connection, query, explorer, table-grid, result-grid, notebook, account, licence, or DBCode-native AI code. The external DBCode extension is installed separately and is not slimmed.

However, the wrapper must not claim complete DBCode feature parity yet. Four documented capability areas need an explicit compatibility decision:

1. The manual HTTP MCP server is a separate feature from automatic editor registration. Hiding its controls leaves external MCP clients without a proved route.
2. Watched Folders, Folder Connections, Zero Config discovery, and the Project Library depend on an opened workspace or folder. The wrapper currently opens individual SQL files but has no focused Open Query Folder or Project route.
3. Direct CSV, Excel, Parquet, and Avro opening is documented functionality. The current `1.36.1` plus Code OSS `1.126.0` provider-registration failure is a version-pair compatibility gap, not proof that Connections is feature-equivalent.
4. Python notebook cells require the external Jupyter extension. The user has decided that this is a core DBCode Wrapper capability, so the approved release set must install and verify its Jupyter and Python runtime extensions automatically rather than offering an optional package.

There are two further high-risk areas:

- Current `1.36.2` documentation adds Universal SQL and a stored-routine Debugger. Universal SQL is intrinsic DBCode editor/connection behavior. The Debugger explicitly uses the native VS Code debugging UI, so blanket removal of the debug surface would break that DBCode feature.
- The shell hides all SQL editor title actions. Execute and Explain have other visible routes, but Analyze, Dry Run, Compiled SQL, and Export need exact rendered proof before the title actions can be treated as duplicates.

The right rule is: consolidate navigation only after the remaining route has been shown to complete the same DBCode job. If a documented feature uniquely depends on a generic host surface, provide a focused DBCode-owned replacement or an optional compatibility package instead of restoring the full IDE.

## Audit boundary

The official [DBCode documentation](https://dbcode.io/docs) was checked on 20 July 2026. Its home page identifies the current documentation as `1.36.2`. The audit began from the approved `dbcode.dbcode@1.36.1` baseline; [issue 15](./15-approve-dbcode-1-36-2-with-core-python-notebooks.md) now evaluates `1.36.2` with Code OSS `1.126.0` and VSCodium packaging `1.126.04524` as one release set.

That version difference matters:

- The `1.36.1` documentation navigation and locally inspected public package manifest do not list Universal SQL or the stored-routine Debugger.
- The current `1.36.2` navigation does list both. Their direct pages were present in navigation but intermittently unavailable through the documentation fetcher, so their current documentation is a release-candidate requirement, not proof that the approved `1.36.1` app already contains them.
- [Open VSX](https://open-vsx.org/extension/dbcode/dbcode) now reports `1.36.2` as the current DBCode release. A public-manifest comparison found the same canonical contribution hash as `1.36.1`, which is encouraging but does not prove runtime compatibility. The complete `1.36.2` host pair still needs controlled QA.
- Child documentation pages have mixed version footers and update dates. A page may describe an older or newer DBCode release than the navigation around it.

Repository evidence used:

- The verified DBCode `1.36.2` public package manifest declares 170 commands, 8 DBCode views, DBCode notebook and renderer contributions, custom data-file selectors, 12 language-model tools, an MCP provider, and 78 DBCode settings. The release lock records only its canonical contribution digest; exact vendor manifest content remains local.
- [Focused feature policy](../../../host/dbcode-feature-policy.json): the intended routes and known limits.
- [Slimming policy](../../../host/slimming-policy.json): source-map removal, the seven retained/first-party built-ins, removed built-ins, separate external-runtime measurements, and rollback.
- [Host README](../../../host/README.md): the product route contract and exact-pair update gate.
- [Rendered acceptance script](../../../host/qa/ticket-03-rendered.cjs) and [latest rendered report](../../../output/playwright/ticket-03-rendered-report.json): 25 passed checks with no unexpected renderer or console errors.
- [Shell simplification patch](../../../host/patches/code-oss/0270-dbcode-wrapper-shell-simplification.patch) and [advanced-feature patch](../../../host/patches/code-oss/0290-dbcode-wrapper-advanced-features.patch): the host surfaces hidden, retained, or replaced.

## Classification key

- **Fully retained:** a focused route exists and the real workflow has passed rendered or licensed QA.
- **Contextually retained:** the public DBCode command, view, grid, webview, or context route is still present, but this exact workflow has not received deep end-to-end proof.
- **Consolidated overlap:** a duplicate route was removed while a proved route still performs the same DBCode job.
- **Intentional base limit:** the feature needs a non-DBCode product dependency or conflicts with the personal desktop scope. It may belong in an optional package.
- **Potentially lost / at risk:** no proved, capability-equivalent route remains. Do not call this duplicate functionality.
- **Not applicable:** documentation or deployment support rather than a capability expected in the personal macOS app.

## Official feature coverage

### Getting started

Official pages: [Install](https://dbcode.io/docs/get-started/install), [Connect](https://dbcode.io/docs/get-started/connect), [Execute a Query](https://dbcode.io/docs/get-started/execute-a-query), and [Install Visual Studio Code](https://dbcode.io/docs/get-started/install-vscode).

| Documented workflow | Current wrapper route | Classification | Evidence and remaining work |
| --- | --- | --- | --- |
| Install DBCode | First launch installs the exact locked Open VSX release outside the bundle. | Fully retained | Source, checksum, signature, extension status, licence, quit, and relaunch gates exist. |
| Connect to a database | Connections Home and Database Explorer. | Fully retained | New connection, sample connection, PostgreSQL, DuckDB, SQLite sample, and persistence have passed. |
| Execute a query | New query, Open SQL, DBCode code lens, DBCode keybindings, and SQL context menu. | Fully retained | PostgreSQL, DuckDB, and sample SQLite execution have passed. |
| Install VS Code | Not needed by this product. | Not applicable | The wrapper is the host. The user should not need a second IDE. |

### Connections and database access

| Official features | Current wrapper route | Classification | Evidence and remaining work |
| --- | --- | --- | --- |
| [Create](https://dbcode.io/docs/connections/create), [Edit](https://dbcode.io/docs/connections/edit), [Connect/disconnect](https://dbcode.io/docs/connections/connect), [Refresh](https://dbcode.io/docs/connections/refresh), [Copy](https://dbcode.io/docs/connections/copy), [Group](https://dbcode.io/docs/connections/group), [Color](https://dbcode.io/docs/connections/color), and [Delete](https://dbcode.io/docs/connections/delete) | Connections Home, Database Explorer, and DBCode-owned tree actions. | Contextually retained; create/connect are fully retained | The wrapper does not filter these DBCode tree actions. Create/connect/sample are rendered. The rest need representative context-menu tests, especially deletion. |
| [Roles](https://dbcode.io/docs/connections/roles), [schema loading](https://dbcode.io/docs/connections/schema), [variables](https://dbcode.io/docs/connections/variables), and [automatic SSL](https://dbcode.io/docs/connections/auto-ssl) | DBCode connection forms, settings, and tree actions. | Contextually retained | These are DBCode-owned configuration and driver behavior. They were not removed, but database-specific enforcement is not covered by the current PostgreSQL/DuckDB smoke tests. |
| [Import connections](https://dbcode.io/docs/connections/import) | Connections Home > Import connections. | Fully retained at route level | The real import workflow opens. Azure Data Studio, CSV, JSON, pgAdmin-style JSON, and custom mapping need fixture tests before all formats are called proved. |
| [Monitoring](https://dbcode.io/docs/connections/monitoring) | Database Explorer connection context > Server Monitor. | Contextually retained | `dbcode.server.monitor` is still contributed and not filtered. Sessions, locks, replication, system information, cancel, and kill need a supported server fixture. |
| [SSH and command tunnels](https://dbcode.io/docs/connections/ssh-tunnels) | Connections menu > Tunnels. | Fully retained at route level | The real Tunnels view opens. SSH, Cloud SQL/Auth Proxy, AWS SSM, and `kubectl port-forward` execution are untested. |
| [Watched Folders](https://dbcode.io/docs/connections/watched-folders) | Existing watched folders remain manageable in Database Explorer, but adding one is declared only on the generic Explorer folder context. | Potentially lost / at risk | This is real DBCode functionality for recursively discovering SQLite, DuckDB, Access, Parquet, Excel, and Avro files. Add a focused folder picker or DBCode-owned route; do not restore the whole Explorer solely for this. |
| [Folder Connections](https://dbcode.io/docs/connections/folder-connections) | No focused folder/project route. Per-file connection selection still works. | Potentially lost / at risk | Per-file selection is not equivalent to portable folder-to-connection bindings in `dbcode.connectionBindings`. Add a focused query-folder route and binding UI if this workflow is retained. |
| [Zero Config](https://dbcode.io/docs/connections/zero-config) | No focused Open Query Folder/Project route. | Potentially lost / at risk | Discovery of `.env`, `web.config`, `.ddev/config.yaml`, and other project files needs a workspace root. Opening individual SQL files does not prove it. |

### Cloud providers and authentication profiles

Official pages: [connect a cloud provider](https://dbcode.io/docs/cloud-providers/connect), [supported cloud providers](https://dbcode.io/docs/cloud-providers/supported-providers), [Aiven](https://dbcode.io/docs/cloud-providers/supported-providers/aiven), [Azure](https://dbcode.io/docs/cloud-providers/supported-providers/azure), [Cloudflare](https://dbcode.io/docs/cloud-providers/supported-providers/cloudflare), [Neon](https://dbcode.io/docs/cloud-providers/supported-providers/neon), [Supabase](https://dbcode.io/docs/cloud-providers/supported-providers/supabase), [Turso](https://dbcode.io/docs/cloud-providers/supported-providers/turso), [OAuth/OIDC](https://dbcode.io/docs/authentication-profiles/oauth2), [AWS](https://dbcode.io/docs/authentication-profiles/aws), [command credentials](https://dbcode.io/docs/authentication-profiles/command), and [`.pgpass`](https://dbcode.io/docs/authentication-profiles/pgpass).

| Current wrapper coverage | Classification | Evidence and remaining work |
| --- | --- | --- |
| Cloud providers enter through Connections; Authentication Profiles has its own focused connection-management view. DBCode keeps credentials in host SecretStorage. | Contextually retained | The Authentication Profiles view and native Keychain persistence are proved. Each cloud login, browser handoff, command profile, AWS chain, and `.pgpass` route needs a representative test. Removed Code OSS GitHub/Microsoft providers do not remove DBCode's web authentication, but any DBCode route that explicitly selects a host provider needs checking. |

### Supported databases, services, and data files

The current [supported database catalog](https://dbcode.io/docs/supported-databases) contains 90 named integrations:

Aerospike; Amazon Athena; Amazon DocumentDB; Amazon DynamoDB; Apache CouchDB; Apache Derby; Apache Doris; Apache Druid; Apache Hive; Apache Iceberg; Apache Impala; Apache Kafka; Apache Pinot; Avro; Azure SQL; Azure Synapse; BigQuery; Bunny Database; Cassandra; ChromaDB (Preview); ClickHouse; Cloudflare D1; Cloudflare R2 SQL; CockroachDB; Couchbase (Preview); CSV; Cube; Dameng (Preview); Databricks; Dataverse; DuckDB; DuckLake; Elasticsearch; Exasol (Preview); Excel; Firebase; Firebird (Preview); Google Spanner; Greenplum; H2; IBM DB2; IBM i; InfluxDB; KingbaseES; LanceDB (Preview); libSQL; MariaDB; Memcached; Memgraph; Microsoft Access; Microsoft Fabric; Milvus (Preview); MongoDB; MotherDuck; MySQL; Neo4j; Netezza; OpenSearch; Oracle; Parquet; PGlite; Pinecone (Preview); PostgreSQL; PostHog (Preview); Qdrant (Preview); QuestDB; RabbitMQ; RavenDB; Redis; Redshift; RisingWave; Salesforce; SAP ASE/Sybase; SAP HANA (Preview); ScyllaDB; SingleStore; Snowflake; SQL Server; SQLite; StarRocks; Stripe (Preview); SurrealDB; Teradata (Preview); TiDB; Timescale; Trino; TypeDB (Preview); Vertica; Weaviate (Preview); and YugabyteDB.

| Documented capability | Current wrapper coverage | Classification | Evidence and remaining work |
| --- | --- | --- | --- |
| All 90 connection providers | The unchanged external DBCode extension supplies its drivers and provider forms through Connections. | Contextually retained | Slimming removes Code OSS built-ins, not DBCode's package or drivers. PostgreSQL, DuckDB, SQLite, and Parquet are proved. The remaining providers are not proved and some need browser OAuth, commands, local files, or server-specific features. |
| [DuckDB](https://dbcode.io/docs/supported-databases/duckdb) connection and direct querying of CSV, Parquet, and JSON | Connections and the SQL editor. | Fully retained for DuckDB and Parquet query proof; contextual for CSV/JSON | The current proof covers DuckDB and Parquet. CSV and JSON direct-query fixtures should be added. |
| [CSV](https://dbcode.io/docs/supported-databases/csv) direct grid, inline editing, DuckDB SQL, and export | The declared custom editor fails to register with the approved host pair. Connections is offered as a fallback. | Potentially lost / at risk | A generic connection is not proved equivalent to opening an arbitrary CSV, editing it, and exporting Excel/Parquet/JSON. Retest with `1.36.2`; keep the route hidden only while it is a guaranteed failure. |
| [Excel](https://dbcode.io/docs/supported-databases/excel) `.xlsx`/`.xls`, multiple sheets, inline editing, DuckDB SQL, and export | Same custom-editor compatibility gap. The `1.36.1` public selector lists `.xlsx` but not `.xls`. | Potentially lost / at risk | Test both formats, sheet selection, edits, and exports. The selector/docs mismatch is unresolved. |
| [Parquet](https://dbcode.io/docs/supported-databases/parquet) direct grid, metadata/statistics, DuckDB SQL, and export | Parquet can be queried through DuckDB, but direct custom-editor opening is not registered in the approved pair. | Potentially lost / at risk | Query success does not prove the documented direct grid, metadata, statistics, or CSV/Excel/JSON exports. The page itself is marked `1.36.2`, so retest the new pair. |
| [Avro](https://dbcode.io/docs/supported-databases/avro) direct grid, schema, DuckDB SQL, and export | Same custom-editor compatibility gap. | Potentially lost / at risk | Test direct opening, schema view, SQL, and exports. |
| Standalone JSON file viewer | No official page exists. | Not applicable | JSON is documented as a query/import/export format, not as a standalone custom editor. |

### SQL editing, execution, and query management

| Official features | Current wrapper route | Classification | Evidence and remaining work |
| --- | --- | --- | --- |
| [SQL editor](https://dbcode.io/docs/query/sql-editor), [autocomplete](https://dbcode.io/docs/query/autocomplete), [parameters](https://dbcode.io/docs/query/query-parameters), and [inline completion](https://dbcode.io/docs/query/inline-completion) | Query canvas, SQL code lens, DBCode keybindings, SQL context menu, and DBCode settings. | Fully retained for editing/execution; contextual for parameters and completion | A real query executes with DBCode's grid. Add rendered checks for autocomplete, all parameter prefixes, linting, connection switching, and inline completion. |
| [Visual Query Builder](https://dbcode.io/docs/query/query-builder) | DBCode Tools > Query Builder. | Consolidated overlap | The focused route opens the real DBCode connection chooser. Only the unreliable duplicate database-tree shortcut is hidden. Test joins, grouping, HAVING, live SQL, execution, and explain before calling the whole builder proved. |
| [Transaction control](https://dbcode.io/docs/query/transaction-control) | DBCode editor status/code lens and DBCode transaction settings. | Contextually retained | Autocommit, commit, rollback, error rollback, and long-transaction warnings depend on the driver and need a PostgreSQL transaction fixture. |
| [History](https://dbcode.io/docs/query/history) and [encrypted History Sync](https://dbcode.io/docs/query/history-sync) | Queries > History and DBCode History settings. | Fully retained at route level; sync contextual | The History view opens. Enable, record, filter, reload, delete, failed-query logging, encrypted sync, offline merge, and snapshot restore need proof. |
| [Execution plans](https://dbcode.io/docs/query/execution-plans) | Explain code lens/context route and DBCode result view. | Fully retained for route; actual analysis contextual | The code lens was visible in the licensed app and diagrams rendered. Explain, Analyze, plan visualization, and optional AI analysis need end-to-end assertions. |
| Analyze, Dry Run, Compiled SQL, and Export editor commands | Their `1.36.1` commands are declared only as SQL editor title actions or context commands. The wrapper hides the whole SQL editor title-action area. | Potentially lost / at risk | Prove an equivalent code-lens or SQL-context route for each command. If none exists, expose focused DBCode actions rather than restoring generic editor chrome. |
| [Multi-statement Run Tab](https://dbcode.io/docs/query/run-tab) | DBCode result editor/webview. | Contextually retained | The webview is unchanged, but progress, cancellation, per-statement results, overflow, DDL/DML output, and notebook behavior are untested. |
| [Favorites](https://dbcode.io/docs/query/favorites) | Database Explorer DBCode context actions. | Contextually retained | `dbcode.connection.addFavorite` and `removeFavorite` remain contributed. Add a rendered add/remove/open check. |
| [Library](https://dbcode.io/docs/query/library) | Queries > Library and Add to DBCode Library in the SQL context menu. | Fully retained for personal items; project scope at risk | The Library view and Add action are retained. Appshots showed Project Library reporting no workspace, so project files such as `.sql`, `.qb.json`, `.explore.json`, and `.file.json` need a focused Open Query Folder/Project route. |
| [Scratch files](https://dbcode.io/docs/query/scratch-files) | Persistent startup `scratch.sql`, DBCode Scratch settings, and Show Scratch Files in Finder. | Consolidated overlap | The broken external file-URL action was replaced by a native Finder reveal. Path, rotation, deletion, and connection-specific behavior remain DBCode-owned; only Finder reveal has direct proof. |
| [SQL formatting](https://dbcode.io/docs/query/sql-formatting), [idle timeout](https://dbcode.io/docs/query/idle-timeout), and [missing-WHERE detection](https://dbcode.io/docs/query/missing-where-detection) | DBCode-filtered settings and SQL editor behavior. | Contextually retained | All corresponding settings remain in the locally verified `1.36.1` public manifest. Add formatting, reconnect/idle, and guarded mutation fixtures. |
| [DB Explorer Quick Open](https://dbcode.io/docs/db-explorer/quick-open) | DBCode's `Ctrl+Cmd+O` keybinding remains declared. | Contextually retained | This is distinct from the hidden generic Quick Open. Add a direct keybinding test before treating it as fully retained. |
| [Universal SQL](https://dbcode.io/docs/query/universal-sql) | Not present in the pinned `1.36.1` documentation navigation or locally verified public manifest. | New-version candidate | Treat it as intrinsic DBCode connection/editor behavior when evaluating `1.36.2`; it should not require a generic IDE surface. Test MongoDB and Stripe translation paths if those providers are in scope. |
| [Stored-routine Debugger](https://dbcode.io/docs/query/debugger) | Current focused shell blocks the generic debug panel and removes debug built-ins. | Potentially lost / at risk in `1.36.2` | Official documentation uses breakpoints, Run and Debug, call stack, variables, and watches. Provide a contextual DBCode debugger surface or an optional compatibility package; do not dismiss this as unrelated IDE functionality. |

### Result grids, editing, import, export, and analysis

| Official features | Current wrapper route | Classification | Evidence and remaining work |
| --- | --- | --- | --- |
| [Edit](https://dbcode.io/docs/data/edit), [copy](https://dbcode.io/docs/data/copy), [row limits](https://dbcode.io/docs/data/rowlimits), [search](https://dbcode.io/docs/data/search), [formatters](https://dbcode.io/docs/data/formatters), [tab behavior](https://dbcode.io/docs/data/tab-behavior), [saved filters](https://dbcode.io/docs/data/saved-filters), and [keyboard shortcuts](https://dbcode.io/docs/data/keyboard-shortcuts) | DBCode's own result/table grid and grid settings. | Contextually retained | The real grid, Columns, Inspector, Export/Share, and AI surfaces render. Cell save, null, insert/delete, validation, JavaScript/lookup formatter, filter persistence, and keyboard operations need action-level tests. |
| [Explore](https://dbcode.io/docs/data/explore), [visualize](https://dbcode.io/docs/data/visualize), [Inspector](https://dbcode.io/docs/data/inspector), and [relationships](https://dbcode.io/docs/data/relationships) | DBCode grid toolbar/tabs and Database Explorer context actions. | Contextually retained | The wrapper does not alter DBCode webviews. Profiling, dimensions/measures, charts, drill-down, inferred relationships, and Open as SQL remain unproved. |
| [Export](https://dbcode.io/docs/data/export) | DBCode grid Export/Share tab and object context actions. | Contextually retained | Test CSV, XLSX, HTML, interactive web, JSON, pretty JSON, Markdown, Parquet, SQL `IN`, SQL `INSERT`, and XML. Do not replace this with a generic file save route. |
| [Import](https://dbcode.io/docs/data/import) | Database Explorer table context > Import Data. | Contextually retained | Test CSV/JSON, new and existing tables, mapping, preview, duplicates, bad-row handling, and complex JSON behavior. |
| [Compare](https://dbcode.io/docs/data/compare), [join](https://dbcode.io/docs/data/join), and [union](https://dbcode.io/docs/data/union) | DBCode object/grid context actions. | Contextually retained | Cross-engine synchronization, generated/applied INSERT/UPDATE/DELETE, heterogeneous joins, and name-aligned unions need fixtures. |
| [Secure Share](https://dbcode.io/docs/data/share) | DBCode Export/Share tab. | Contextually retained | Passphrase encryption and retrieval are untested. This is not equivalent to normal export. |
| [Backup and Restore](https://dbcode.io/docs/data/backup-restore) | Database Explorer database context actions. | Contextually retained | Commands remain contributed. Add safe fixtures for supported engines before exposing destructive restore as proved. |
| [Streaming](https://dbcode.io/docs/data/streaming) | Active Streams appears conditionally in the Connections menu and DBCode contributes pause/resume/stop/reveal. | Contextually retained | The conditional view is preserved. PostgreSQL LISTEN/NOTIFY, MongoDB, Redis, SurrealDB, Firestore, RavenDB, Kafka, and RabbitMQ streams need provider-specific tests. |

### Database Explorer and object management

Official pages: [create/edit tables](https://dbcode.io/docs/db-explorer/create-or-edit-tables), [rename](https://dbcode.io/docs/db-explorer/rename-table), [truncate](https://dbcode.io/docs/db-explorer/truncate-table), [drop](https://dbcode.io/docs/db-explorer/drop-table), [ER diagrams](https://dbcode.io/docs/db-explorer/entity-relationship-diagram), [stored procedures](https://dbcode.io/docs/db-explorer/stored-procedures), [execute a SQL file](https://dbcode.io/docs/db-explorer/execute-sql-file), [filter](https://dbcode.io/docs/db-explorer/filter), [keyboard shortcuts](https://dbcode.io/docs/db-explorer/keyboard-shortcuts), and [Quick Open](https://dbcode.io/docs/db-explorer/quick-open).

| Current wrapper coverage | Classification | Evidence and remaining work |
| --- | --- | --- |
| Database Explorer is a focused DBCode-only drawer. Its object context actions remain except the three explicitly documented duplicate or generic-Explorer routes. | Contextually retained; ER diagram fully retained at route level | A real SQLite tree/table and ER diagram have passed. Create/edit, rename, truncate, drop, stored-routine edit/conflict handling, filtering, and keyboard navigation need safe fixtures. ERD multi-schema layout, PDF/PNG/web export, and encrypted share are untested. |
| Execute SQL File remains on a selected database. Open SQL File remains in the wrapper toolbar. | Not overlapping; retain both | Execute SQL File immediately runs a chosen script against the selected database and shows sequential statement results. Open SQL File opens a query for review/edit/selection. They serve different jobs and should not be consolidated. |

### Notebooks

Official pages: [getting started](https://dbcode.io/docs/notebooks/getting-started), [exporting](https://dbcode.io/docs/notebooks/exporting), [cell locking](https://dbcode.io/docs/notebooks/cell-locking), and [Python integration](https://dbcode.io/docs/notebooks/python).

| Documented capability | Current wrapper coverage | Classification | Evidence and remaining work |
| --- | --- | --- | --- |
| SQL and Markdown cells; run one/all/above/below; multiple results; join cell results | DBCode Tools > New DBCode Notebook, DBCode notebook host, renderer, toolbar, and cell menus. | Fully retained at route level; contextual at workflow level | A real `.dbcnb` notebook opens and renders. Cell execution, result joining, Markdown, and save/reload need action-level tests. |
| Notebook export to PDF, web, Markdown, or encrypted share; hide query cells | DBCode notebook Export/Share toolbar action. | Contextually retained | `dbcode.notebook.export` remains contributed. Test every format and hidden-query option. |
| Cell locking to connection, database, and schema | DBCode notebook cell UI. | Contextually retained | The DBCode notebook webview is unchanged, but locking and reconnect behavior need proof. |
| Python cells, Jupyter kernels, external notebook kernels, and SQL-to-pandas `-- @var` | No Jupyter extension is bundled and the generic Extensions surface is absent. | Required compatibility work | Official docs require the Jupyter extension. Install a pinned and verified Jupyter/Python runtime set automatically as part of every approved release pair. Keep it outside the signed app bundle with DBCode so the focused app does not expose an extension marketplace. The built-in `ipynb` extension alone is not equivalent. |

### AI and MCP

Official pages: [AI Query Builder](https://dbcode.io/docs/ai/query-builder-ai), [Data Grid AI Assist](https://dbcode.io/docs/ai/ai-assist), [Copilot tools](https://dbcode.io/docs/ai/copilot-tools), [MCP](https://dbcode.io/docs/ai/mcp), [custom provider](https://dbcode.io/docs/ai/custom-provider), [models and configuration](https://dbcode.io/docs/ai/models-and-configuration), and [privacy and security](https://dbcode.io/docs/ai/privacy-and-security).

| Documented capability | Current wrapper coverage | Classification | Evidence and remaining work |
| --- | --- | --- | --- |
| Natural-language Query Builder changes and result-grid sort/filter/group/chart | Focused Query Builder, DBCode grid AI tab, provider chooser, API-key prompt, and DBCode AI settings. | Contextually retained; provider routes fully retained | Real provider and key prompts open and the DBCode grid AI tab renders. Actual prompt execution and every grid/builder mutation need controlled AI tests. |
| DBCode-hosted, GitHub Copilot, OpenAI-compatible, Ollama, LM Studio, and hosted providers | DBCode provider flow and filtered settings. | Contextually retained | Provider selection and custom-key storage routes remain. Network/model response, hosted fallback disablement, and local endpoints are untested. |
| Twelve Copilot tools for connections, schemas, queries, and data copy | Generic Copilot Chat is intentionally absent. The official Copilot-tools page says the same database tools are also available through MCP. | Consolidated overlap once HTTP MCP is proved; currently at risk with HTTP controls hidden | Prefer DBCode's HTTP MCP route for external AI clients over bundling a generic Chat workbench. This preserves the database-tool capability and the focused desktop goal. Until the HTTP MCP gate passes, neither route is proved in the wrapper. |
| Automatic MCP registration for VS Code/Cursor chat | DBCode still declares its MCP provider, but the wrapper has no generic Chat UI. | Intentional base limit / no in-app consumer | Automatic registration alone provides no visible wrapper workflow. It may still matter to a compatible external host, but that is not proved here. |
| Local HTTP MCP server for Claude Desktop, Claude Code, Copilot CLI, dev containers, LAN, and editors without auto-registration | Settings remain, but Start, Stop, and Revoke OAuth Tokens are hidden after one failed isolated audit. | Potentially lost / at risk | Official docs explicitly say HTTP is a separate path from automatic registration, disabled by default, and started with `DBCode: MCP Start HTTP Server`. Restore focused controls only after exact-pair testing proves start, stop, OAuth approval/revoke, port, localhost, and external-connection behavior. Do not rely on auto-registration as a fallback. |
| AI privacy and security | DBCode settings and provider-specific prompts. | Contextually retained | Record that schema and, for query tools, actual values may leave the machine. The local-first database connection model does not make AI execution local-only. |

### Security, telemetry, account, licence, teams, and deployment

Official pages: [security](https://dbcode.io/docs/security), [password storage](https://dbcode.io/docs/security/password-storage), [telemetry](https://dbcode.io/docs/telemetry), [sign in](https://dbcode.io/docs/accounts/sign-in), [team seats](https://dbcode.io/docs/accounts/team-seats), [team roles](https://dbcode.io/docs/accounts/team-roles), [offline licence](https://dbcode.io/docs/accounts/offline-license), and [container deployment](https://dbcode.io/docs/accounts/container-deployment).

| Documented capability | Current wrapper coverage | Classification | Evidence and remaining work |
| --- | --- | --- | --- |
| Direct/local database connections, TLS, SSL, SSH, and secret storage choices | Connections, Tunnels, Authentication Profiles, and native macOS SecretStorage/Keychain. | Fully retained for native secret persistence; contextual for protocols | Real licence and connection persistence passed with the renamed Keychain identity. TLS modes, encrypted settings, session-only, never-save, and tunnel transports need checks. |
| Telemetry preference | DBCode-filtered settings. | Contextually retained | The setting remains. QA's `--disable-telemetry` is test isolation, not evidence of the production preference behavior. |
| Web sign-in, lifetime entitlement, and offline activation | Account view and DBCode-owned authentication/licence commands. | Fully retained for web lifetime entitlement; contextual for offline activation | The user's licence survives quit/relaunch. Offline machine-bound activation needs a controlled test. |
| VS Code GitHub/Microsoft sign-in option | Host GitHub and Microsoft authentication built-ins were removed. DBCode web sign-in remains. | Intentional base limit / route-specific risk | Web Google/Microsoft/GitHub/email and the current licence route cover the personal app. If host-provider sign-in is promised, restore only the needed provider after testing. |
| Team seats and roles | Account view commands remain, but the product is a personal wrapper. | Not required for the primary personal goal; contextually retained | Do not remove the DBCode Account actions without checking a licensed team account. Team feature restrictions are product policy, not database security. |
| Container deployment | This deliverable is a signed personal macOS desktop app. | Not applicable to the base app | Container activation tokens and environment-based licensing belong to a separate deployment target, not the desktop bundle. |

### Reference, API, updates, and support

Official pages: [SQL reference](https://dbcode.io/docs/sql), [VS Code Extension API](https://dbcode.io/docs/api/vscode-extension), [changelog](https://dbcode.io/docs/changelog), [debugging](https://dbcode.io/docs/help-support/debug), [FAQ](https://dbcode.io/docs/help-support/faq), and [getting help](https://dbcode.io/docs/help-support/getting-help).

| Documentation area | Classification | Notes |
| --- | --- | --- |
| SQL function and keyword reference | Not a separate wrapper surface | DBCode's language services and provider dialect support are the product capability. Do not inventory every SQL function as a separate desktop route. |
| VS Code Extension API | Contextually retained as a host integration, not a normal personal workflow | Code OSS still supplies the extension host, but no third-party extensions are bundled or installable through the focused UI. If external extensions using DBCode's API are in scope later, add an explicit compatibility tier. |
| Changelog and update information | External documentation | The wrapper's own exact-pair updater should link release notes and test the host plus extension as one candidate. DBCode does not document the wrapper's update behavior. |
| Debug, FAQ, and support | External support | Keep links available from DBCode surfaces. Do not add a permanent full-workbench diagnostic app; use a pinned stock host as a disposable comparison and the focused wrapper's foreground diagnostic launch when needed. |

## What the slimming pass actually changes

The signed DBCode `1.36.2` candidate measures `462,012 KiB`, down from the `937,596 KiB` baseline by `50.72%`. Its indicative archive is `166,455,145` bytes, down `37.11%`. The reduction comes from omitting Code OSS source maps and reducing 93 upstream built-ins to six reviewed built-ins plus one small first-party bridge:

- `sql`
- `theme-defaults`
- `theme-seti`
- `notebook-renderers`
- `python`
- `ipynb`
- `dbcode-wrapper-python-kernel` (first-party focused bridge)

The exact seven-extension external runtime remains separate at `251,480 KiB`, including `161,464 KiB` for unchanged DBCode `1.36.2`. It keeps DBCode, Jupyter, Jupyter's four declared notebook helpers, and Python. The optional Python debugger and environment-manager pack members are excluded because DBCode Python cells do not use them and the Open VSX environment-manager combination failed at runtime. The external set is never copied into or modified by the slimming policy. Therefore DBCode's database drivers, commands, menus, views, settings, grids, webviews, and notebook code remain external and intact.

Slimming still affects compatibility when a DBCode feature depends on a host built-in or generic host surface:

- Python notebooks need Jupyter and Python support; issue 15 now pins and verifies that runtime and retains only the two small declarative built-ins plus a focused kernel bridge inside the app.
- The `1.36.2` stored-routine Debugger needs native debug UI and may need debug services currently removed or hidden.
- Copilot tools need Copilot Chat.
- Host GitHub/Microsoft authentication routes need their authentication providers.
- Project-aware workflows need a workspace/folder route even though they do not require a large built-in extension.

Do not restore all 93 built-ins by default. Add or restore only the dependency required by a proved DBCode workflow. Keep the existing `all_built_ins` mode as a diagnostic rollback to determine whether a removed built-in caused a regression.

## Focused remediation order and required compatibility gates

Work in this order so the primary database-desktop workflows are protected before optional integrations:

1. **Update-pair gate:** build `DBCode 1.36.2 + the selected Code OSS host`, compare the public manifest, then run all source, packaging, signature, licence, connection, query, persistence, and rendered gates. The matching contribution hash is not runtime proof.
2. **Direct data-file gate:** open CSV, XLSX, XLS, Parquet, and Avro directly; verify grid, metadata/schema, inline edit where documented, DuckDB SQL, and each documented export family.
3. **Workspace gate:** add a focused Open Query Folder/Project route; verify Project Library, Zero Config, Watched Folders, and Folder Connections without exposing the general Explorer.
4. **Advanced SQL gate:** verify Explain, Analyze, Dry Run, Compiled SQL, Export, parameters, transactions, plans, multi-statement Run Tab, formatting, idle reconnect, and missing-WHERE protection through focused routes.
5. **Data-grid gate:** verify edit, copy, import, export, explore, compare, join, union, share, inspector, search, formatters, filters, backup/restore, and one supported streaming provider.
6. **MCP gate:** separately verify automatic registration and the HTTP server. Test Start, Stop, OAuth, revoke, localhost, configured port, and one external client. These two transports are not substitutes.
7. **Dependency gate:** treat Python/Jupyter as mandatory, version-locked runtime extensions and prove a DBCode Python cell against a real kernel. Decide separately whether host auth providers and the DBCode Debugger need focused or compatibility-tier support. Keep generic Copilot Chat out of the base app if HTTP MCP proves the same DBCode database tools.
8. **Provider sampling gate:** keep PostgreSQL, DuckDB, SQLite, and Parquet, then add one cloud OAuth provider, one document database, one key-value/stream service, and one file-backed provider. Re-run the exact sample whenever the host/DBCode pair changes.

## Documentation uncertainties

- The docs home says “60+” supported databases, another search description says “86+,” while the current navigation contains 90 named integrations.
- The cloud-provider index visibly lists fewer providers than the live official child pages.
- JSON is documented for import/export and DuckDB querying, but no standalone JSON viewer page exists.
- Current navigation lists Universal SQL, Debugger, Data Keyboard Shortcuts, and Team Roles, but some of those pages returned a cache miss during the audit.
- Plan availability is scattered across pages. Monitoring, editing, transactions, execution plans, streaming, roles, and debugging vary by driver or licence.
- Child pages carry mixed footer versions and update dates. No feature should be attributed to `1.36.1` solely because it appears in the current `1.36.2` navigation.

## Answer

The project should continue as a focused DBCode desktop app on a slim Code OSS host. That direction gives the user DBCode's real connection, query, explorer, grid, notebook, account, licence, and native AI experiences without presenting a full IDE.

It is safe to remove an overlapping shell route only when the remaining route has been proved to perform the same DBCode job. The current Query Builder shortcut consolidation, native Finder replacement for scratch files, automatic result layout, and removal of the duplicate Results panel meet that rule. Open SQL File and Execute SQL File do not overlap and should both remain.

The audit does not approve permanent removal of HTTP MCP controls, Watched Folders, Folder Connections, Zero Config/project workflows, direct data-file handling, or advanced editor actions. Those are real documented DBCode capabilities with no proved equivalent route. The correct redesign is a focused DBCode route or a separately tested compatibility tier, not a restored full Explorer, Command Palette, Chat, Debug workbench, or extension marketplace.

Python notebooks are part of the base DBCode Wrapper capability. Their Jupyter and Python extensions must be installed automatically, pinned, verified, and tested as part of the release set; users must not need an extension marketplace or optional compatibility package. A Python interpreter and kernel remain execution environments selected by the user, just as databases remain external execution targets. Generic Copilot Chat can stay out: once the HTTP MCP route is restored and proved, it provides the same documented DBCode database tools to external AI clients without reopening an IDE chat workbench. The stored-routine Debugger must be treated differently: it is a DBCode `1.36.2` feature that depends on debug UI, so a contextual debugger design or compatibility tier is needed before the wrapper claims that feature.

The package-size work is maintainable because it leaves DBCode itself unchanged and locks the host plus extension as one tested release set. It does not guarantee compatibility with future releases. Every update must be promoted as a complete pair only after the feature gates above pass, with the known-good pair retained for rollback.
