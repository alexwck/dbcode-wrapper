# DBCode capability coverage

DBCode owns the database product. The wrapper must keep its working features reachable without copying or rebuilding them.

This page maps the official DBCode documentation to the wrapper's current coverage policy. It is an orientation guide, not a second feature allowlist. The exact installed DBCode package, `host/dbcode-feature-policy.json`, the signed release manifest, and current tests remain authoritative.

## What coverage means

Use these evidence levels:

- `declared`: the exact DBCode package declares the command, view, menu, editor, setting, or tool.
- `reachable`: the focused wrapper leaves at least one working DBCode-owned route to it.
- `rendered`: an isolated app check opens the real surface.
- `live`: a real workflow completes against an appropriate fixture or external service.

Do not call a feature fully covered when the evidence only proves that its route opens. The wrapper normally needs broad declared and reachable coverage, representative rendered coverage, and live coverage only for high-risk or changed features.

## Feature families

### Install, connect, and supported systems

Official docs: [install](https://dbcode.io/docs/get-started/install), [connect](https://dbcode.io/docs/get-started/connect), [run a query](https://dbcode.io/docs/get-started/execute-a-query), and [supported databases](https://dbcode.io/docs/supported-databases).

DBCode's complete New Connection catalogue is authoritative. The wrapper does not keep a database allowlist. It preserves the unchanged New Connection command and records only section counts and label fingerprints for the exact version. PostgreSQL, SQLite, DuckDB, Parquet, and notebooks are representative depth checks.

Coverage: declared, reachable, rendered, and representative live checks.

### Connections

Official features include create, edit, connect, roles, refresh, copy, groups, colours, delete, schema loading, variables, watched folders, folder connections, monitoring, automatic SSL, import, SSH tunnels, and zero-configuration connections. See the [connection docs](https://dbcode.io/docs/connections/create).

The wrapper keeps Connections Home, Database Explorer, import, tunnels, authentication profiles, streams, and DBCode-owned context actions. It does not retest every database or connection action.

Known limits:

- Adding a watched folder is not exposed because DBCode declares it only in the generic file Explorer.
- Binding a connection to a workspace folder has the same generic Explorer dependency.
- A focused folder picker is needed before either route can be called equivalent.

Coverage: broad declared and reachable coverage; representative rendered and live checks; two explicit route gaps.

### Cloud providers and authentication profiles

Official features include cloud-provider connections, OAuth2/OIDC, AWS profiles, command-based credentials, and `pgpass`. See [cloud providers](https://dbcode.io/docs/cloud-providers/connect) and [authentication profiles](https://dbcode.io/docs/authentication-profiles/oauth2).

The wrapper keeps DBCode's Authentication Profiles and connection routes. Real cloud sign-in, external commands, and credential renewal are service-dependent and stay outside the default test path.

Coverage: declared and reachable; rendered profile navigation; live checks only when a release change affects this area.

### Query work

Official features include the SQL editor, visual Query Builder, Universal SQL, schema-aware completion, query parameters, inline AI completion, transaction control, history, history sync and backup, execution plans, stored-routine debugging, run tabs, favourites, the query library, scratch files, formatting, idle timeout, and missing-`WHERE` detection. See the [SQL editor](https://dbcode.io/docs/query/sql-editor), [Query Builder](https://dbcode.io/docs/query/query-builder), and [execution plans](https://dbcode.io/docs/query/execution-plans).

The wrapper keeps New Query, Open SQL, DBCode SQL context actions, History, Library, Scratch Files, Query Builder, DBCode settings, and the installed DBCode release's stored-routine debugger contribution when present. DBCode's Library context menu can open a saved item against a connection selected by the user. The prompt-free release does not claim a rendered or live debugging session; that remains optional user validation.

Keyboard execution, statement selection, and SQL comments remain DBCode behavior. The current official [SQL Editor guide](https://dbcode.io/docs/query/sql-editor) documents `Ctrl+Enter` for running queries, while the [getting-started guide](https://dbcode.io/docs/get-started/execute-a-query) also lists `Ctrl/Cmd+D+E`. DBCode does not document `Cmd+Enter` (`⌘Return`) as a default. The wrapper does not replace these shortcuts. DBCode supports comments and multi-statement SQL files, and current releases include improved statement-boundary and active-statement handling. Select the exact statement when execution scope is unclear, use comment syntax supported by the connected database, and terminate separate statements as that database expects.

Coverage: broad declared and reachable coverage; rendered SQL, Query Builder, History, and Library; live representative query checks; debugger declared and retained without a deployment-time live check.

### Results and data work

Official features include editing, copying, exploring, exporting, importing, comparing and synchronizing, joining and unioning results, relationships, secure sharing, charts, the data inspector, row limits, search, formatters, tab behaviour, backup and restore, saved filters, and streaming. See the [data docs](https://dbcode.io/docs/data/edit).

The wrapper keeps DBCode's table and result grids, their toolbars, and DBCode-owned context actions. DBCode lets the user pin common copy, export, open, share, select-all, and filter actions to a results toolbar from its `+` menu. The wrapper preserves that setting and does not create another toolbar. Focused source contracts protect the wrapper layout, while the fast rendered smoke checks the owning routes without reading or changing a database. Mutations, secure sharing, large copies, backup, restore, and remote streaming remain normal user-directed work.

New results open in DBCode's own result editor below the query. [Inspector](https://dbcode.io/docs/data/inspector) Form, JSON, and Map views describe one selected row. For several rows, use the result grid's [Copy](https://dbcode.io/docs/data/copy) or [Export](https://dbcode.io/docs/data/export) action and choose JSON or JSON Pretty. The official result-grid docs do not describe a full-result JSON or tree toggle, so the wrapper does not add a competing renderer.

Direct CSV, Excel, Parquet, and Avro file opening is a known compatibility gap. DBCode declares its custom data-file editor, but the maintained compatibility policy does not claim that route until the prompt-free gate activates the custom editor on an approved host pair. The wrapper keeps a known failing shortcut hidden, while an optional focused check may prove the route for a later release. Opening the same data through Connections is useful but is not feature-equivalent.

Coverage: broad declared and reachable grid coverage; route-level rendered evidence; direct-file editing is limited; live, destructive, and external workflows are not deployment tests.

### Database Explorer

Official features include creating or editing tables, rename, truncate, drop, relationship diagrams, stored procedures, SQL-file execution, filtering, shortcuts, and quick open. See the [Database Explorer docs](https://dbcode.io/docs/db-explorer/create-or-edit-tables).

The wrapper keeps DBCode-owned Explorer views and object actions, the relationship-diagram route, and the debugger contribution. DBCode owns the cascade option for Drop and Truncate on databases that support it. The fast smoke renders Database Explorer without running DDL, debugger, or destructive data actions.

Coverage: declared and reachable; rendered Explorer navigation; live and destructive actions are normal user work.

### Notebooks

Official features include SQL and Markdown cells, cell-level execution, result tabs, export, per-cell connection locking, and Python. See [notebook basics](https://dbcode.io/docs/notebooks/getting-started) and [Python notebooks](https://dbcode.io/docs/notebooks/python).

The wrapper keeps DBCode's notebook editor, renderer, toolbar, cell menus, export route, and verified Python/Jupyter runtime. The fast smoke verifies that the notebook route remains visible but does not activate it or start a kernel. This avoids DBCode terms and macOS permission prompts during deployment.

Coverage: declared and reachable, with rendered menu evidence. Python execution is normal user work, not a deployment test.

### AI

Official AI features include:

- Query Builder AI;
- Grid AI;
- inline SQL completion;
- execution-plan analysis and query explanations;
- Explore AI insights;
- custom OpenAI-compatible providers;
- GitHub Copilot tools;
- automatic MCP registration;
- MCP tools through the optional HTTP MCP server;
- AI-inferred relationships;
- team AI controls.

The wrapper keeps DBCode's provider, model, API-key, AI settings, Query Builder, result-grid, and MCP-owned routes. It does not add a competing AI client. The policy records `declared`, `reachable`, `rendered`, and `live` evidence separately for each AI feature. Live model calls, real private data, Copilot sign-in, and external MCP clients stay outside default CI.

Current gaps:

- Generic Code OSS Chat is intentionally absent, so DBCode's Copilot language-model tools do not currently have a focused route.
- Automatic MCP registration is retained as its own supported wrapper route. The separate HTTP Start, Stop, OAuth revoke, and external-client workflow is limited and may receive an optional focused check when needed.
- Inline completion, Query Builder AI, Grid AI, Explore AI, and plan analysis are retained with declared or reachable evidence. They are limited because the prompt-free gate does not claim their rendered or live model behaviour.
- Query explanations are named by DBCode team policy, but the current official feature pages do not identify a distinct route.
- Team controls are declared upstream but are not rendered or exercised through a signed-in team account.

See [AI data sharing](../security/ai-data-sharing.md) for payload and privacy details.

Coverage: mixed. Provider and API-key routes are reachable from the rendered DBCode Tools menu, but the smoke does not activate them. Automatic MCP registration is supported and reachable. Inline completion, Query Builder AI, Grid AI, Explore AI, plan analysis, HTTP MCP, Copilot tool access, inferred-relationship writes, query explanations, and team controls are limited at their recorded evidence level. Optional deeper checks do not block deployment. Live AI is not a deployment test.

### Accounts, security, and deployment

Official features include sign-in, team seats, team roles, offline licences, container deployment, password storage, telemetry controls, and security guidance. See [accounts](https://dbcode.io/docs/accounts/sign-in), [security](https://dbcode.io/docs/security), and [telemetry](https://dbcode.io/docs/telemetry).

The wrapper keeps DBCode's account and licence surfaces. It isolates the profile, disables host telemetry and updates in controlled runs, and leaves DBCode credentials and API keys in its supported secret storage. Account activation, Keychain prompts, offline licences, and external deployment remain normal user actions outside automated tests.

Coverage: declared and reachable; rendered account navigation. Automated deployment does not inspect or prove licence state.

### Extension API, SQL reference, and support

DBCode also documents its [VS Code Extension API](https://dbcode.io/docs/api/vscode-extension), [SQL reference](https://dbcode.io/docs/sql), debugging support, FAQ, and help routes.

The API is an integration surface for other extensions, not a wrapper-owned feature. The focused app must not block DBCode extensions that use the supported API, but default CI does not need to build a second client extension. Help and support content remains upstream documentation.

Coverage: preserved by the unchanged extension boundary; no wrapper reimplementation.

## Version-bump review

For each DBCode update:

1. Read the official changelog and the pages for changed features.
2. Compare the exact public contribution digest and maintained feature policy.
3. Confirm every retained route still has a working owner.
4. Add focused evidence only for new, changed, previously limited, or high-risk features.
5. Keep external authentication, mutation, private data, and human permission checks outside the fast source gate.

DBCode documentation pages can lag the changelog. When two official pages disagree, record the uncertainty and validate the pinned version before making a privacy or compatibility promise.
