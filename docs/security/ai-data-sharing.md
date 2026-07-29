# AI data sharing

DBCode owns AI and MCP behaviour. The wrapper keeps those features reachable, but it must not imply that a local database always means local AI processing.

The exact payload depends on the feature, provider, DBCode version, and user action. Check the pinned version before making a stronger promise than the official documentation supports.

## Providers

- DBCode hosted AI sends supported requests through DBCode to Cloudflare Workers AI over HTTPS.
- GitHub Copilot requests go to GitHub under the user's Copilot account and policy.
- A custom provider receives requests at the configured OpenAI-compatible endpoint. A local endpoint can keep model processing on the device.
- Automatic MCP registration only advertises DBCode's tools to a supported editor. When a client invokes a tool, MCP sends the requested schema, query, or result information to that client and its model. DBCode does not control that model's privacy policy.

Custom-provider API keys use VS Code SecretStorage and the operating-system Keychain. The wrapper must not copy them into settings, logs, tests, or Git.

## Feature payloads

| Feature | Data that may leave DBCode | Important boundary |
| --- | --- | --- |
| Query Builder AI | Schema DDL, the current visual query model, and the user's prompt | The feature page says table rows are not sent. DBCode validates the returned structured model before applying it. |
| Grid AI | Column metadata, supported grid operations, and the user's prompt | Older docs say rows are not sent. Newer changelog behaviour can discuss data and rerun SQL, so do not promise that values never leave without checking the pinned version. |
| Inline SQL completion | Schema plus SQL before and after the cursor | SQL text can contain literals or comments with sensitive values. “Schema only” is not a precise privacy description. |
| Execution-plan analysis | Execution plan, original SQL, referenced schema and indexes, and SQL dialect | `EXPLAIN ANALYZE` can run the real query. Prefer plain `EXPLAIN` for a safe check. |
| Explore AI | A compact profile with types, cardinality, top values, null rates, and correlations | It does not send raw rows, but top values and summaries can still contain real data. Keep the payload-disclosure link visible. |
| Copilot tools | Schema and, after a user-requested query, actual results | Read tools and mutation tools are separate. DML and DDL need explicit user intent. |
| Copilot data copy | Connection details needed by DBCode and rows moving directly between the two databases | Copilot receives counts rather than the copied rows, according to the official docs. |
| MCP query tools | Schema and actual query results returned to the external client | The external client and model set the final privacy boundary. |
| MCP mutation tools | User-directed DML or DDL and its result | Never run these automatically. |
| MCP data copy | Rows moving directly between connections, with counts, duration, and capped errors returned to the client | Treat large or cross-system copies as an explicit manual operation. |
| Inferred relationships | Schema or dbt model details and relationship patterns | Writing relationships can change workspace settings. Require a user-directed action. |

Official references: [AI privacy and security](https://dbcode.io/docs/ai/privacy-and-security), [Query Builder AI](https://dbcode.io/docs/ai/query-builder-ai), [Grid AI](https://dbcode.io/docs/ai/ai-assist), [custom providers](https://dbcode.io/docs/ai/custom-provider), [Copilot tools](https://dbcode.io/docs/ai/copilot-tools), [MCP](https://dbcode.io/docs/ai/mcp), [inline completion](https://dbcode.io/docs/query/inline-completion), [execution plans](https://dbcode.io/docs/query/execution-plans), [Explore](https://dbcode.io/docs/data/explore), and [relationships](https://dbcode.io/docs/data/relationships).

## Security changes without a screen

Some security fixes should not add visible UI. OAuth redirect validation rejects an unregistered callback before a token can be sent. Driver and package extraction checks reject unsafe archive paths before files can escape their intended directory. These are fail-closed boundaries, not user workflows.

The wrapper keeps those DBCode and package-verification checks unchanged. Focused tests should prove the safe state transition and rejection path. Do not add a wrapper dialog or status badge only to make an invisible security boundary appear as a feature.

## MCP defaults

Keep DBCode's HTTP MCP server off by default.

When a person enables it:

- keep it on localhost unless external access is deliberate;
- use OAuth with Authorization Code and PKCE;
- require the OAuth redirect URI to match a URI registered by the client;
- require approval for a new client;
- use no-auth mode only for a trusted local client;
- require OAuth when external connections are allowed;
- keep Start, Stop, token revoke, and external-client checks outside default CI.

Automatic editor registration and the optional HTTP server are separate features. Proving one does not prove the other.

## Test rules

- Use synthetic schemas and deterministic fixture data.
- Do not use a real private database, prompt, query history, credential, or API key.
- Default CI may check commands, settings, route visibility, payload disclosure, and safe state transitions.
- Default CI must not require DBCode sign-in, Copilot sign-in, a paid model, network model calls, OAuth approval, Keychain approval, DML, DDL, data copy, or workspace writes.
- A live AI check should prove wrapper access and user control, not grade the model's answer.
- Never dismiss or approve a security, authentication, mutation, or data-sharing prompt automatically.

## User check before sending

Before using AI or MCP with real data:

1. Identify the provider and account.
2. Read the exact payload disclosure for the feature.
3. Check SQL text, schema comments, and top-value summaries for sensitive content.
4. Confirm whether the action can run SQL, mutate data, copy data, or write workspace settings.
5. Use a local provider when the data must not leave the device.
6. Stop if the pinned DBCode version's behaviour is unclear.
