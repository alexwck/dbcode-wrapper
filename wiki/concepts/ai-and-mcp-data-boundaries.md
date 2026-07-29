---
title: AI and MCP data boundaries
description: How DBCode AI providers, Copilot, and MCP affect data sharing and tests.
type: concept
tags:
  - wiki
  - concept
  - ai
  - mcp
  - privacy
wiki_profile: public
wiki_depth: standard
source_commit: afc5fe7666bf88007bcf4956f05928e3d93c8e2f
---
## Definition

DBCode owns AI and MCP behaviour. The wrapper keeps those features reachable and documented but does not build another AI client. A local database does not mean AI processing stays local: the selected provider, feature, payload, and client decide where data goes.

The wrapper tracks Query Builder AI, Grid AI, inline completion, plan analysis, Explore AI, Copilot Tools, automatic MCP registration, the optional HTTP MCP server, and inferred relationships separately. Evidence for one does not prove another.

Automatic MCP registration and the HTTP MCP server are different features. Proving registration does not prove that the HTTP server is enabled, OAuth is complete, an external client is connected, or a live tool call is safe.

## Data boundary

- DBCode-hosted AI sends supported requests through DBCode to its provider.
- GitHub Copilot uses the user's GitHub account and policy.
- A custom OpenAI-compatible endpoint receives the payload for the chosen feature. A local endpoint can keep model processing on the device.
- Query Builder AI may send schema and the visual query model.
- Grid AI and Explore AI may send summaries, selected values, or top values.
- Inline completion may send surrounding SQL.
- Plan analysis may send SQL, schema, indexes, and a query plan.
- MCP tools can return schema and query results to an external client and its model.
- DML, DDL, data copy, and inferred-relationship writes require an explicit user action.
- API keys belong in SecretStorage and the operating-system Keychain, never in settings, logs, tests, or Git.

## Safe defaults

- Keep the HTTP MCP server off by default and bound to localhost.
- Use OAuth when a person deliberately permits an external client.
- Use only synthetic schemas and data in tests.
- Check route visibility and disclosure text without entering secrets or calling a model.
- Keep sign-in, OAuth approval, Keychain approval, mutation, data copy, and live providers outside deployment checks.

## Where it lives

- [docs/security/ai-data-sharing.md](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/docs/security/ai-data-sharing.md) — provider and payload guidance.
- [host/dbcode-feature-policy.json](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/dbcode-feature-policy.json) — separate evidence for each AI, Copilot, and MCP capability.
- [host/qa/focused-shell-rendered.cjs](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/qa/focused-shell-rendered.cjs) — prompt-free route checks.

## Related

- [DBCode capability evidence](dbcode-capability-evidence.md)
- [Unmodified Extension Boundary](unmodified-extension-boundary.md)
- [Focused shell and wrapper extensions](../modules/focused-shell-extensions.md)
- [Verification Harness](../modules/verification-harness.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)