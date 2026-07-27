---
title: AI and MCP data boundaries
description: How DBCode AI providers, Copilot tools, and MCP clients affect data sharing and test scope.
type: concept
tags:
  - wiki
  - concept
  - ai
  - mcp
  - privacy
wiki_profile: public
wiki_depth: standard
source_commit: 2008ff48373c1aac378d0d1ec903e96a88ec1e29
---
## Definition

DBCode owns AI and MCP behaviour. The wrapper keeps those features reachable but does not add another AI client. A local database does not guarantee local AI processing: the provider, feature, payload, client, and pinned DBCode version determine where data goes.

Automatic MCP registration and DBCode's optional HTTP MCP server are separate features. Proving automatic registration does not prove the HTTP server, OAuth, an external client, or a live tool call.

## Data boundary

- DBCode hosted AI sends supported requests through DBCode to its hosted provider.
- GitHub Copilot uses the user's GitHub account and policy.
- A custom OpenAI-compatible endpoint receives the configured feature payload. A local endpoint can keep model processing on the device.
- MCP query tools can return schema and query results to the external client and its model.
- DML, DDL, data copy, and inferred-relationship writes require an explicit user action.
- API keys stay in SecretStorage and the operating-system Keychain. They never belong in settings, logs, tests, or Git.

Feature payloads differ. Query Builder AI may send schema and the visual query model. Inline completion may send surrounding SQL. Plan analysis may send SQL, schema, indexes, and a plan. Explore AI may send summaries and top values. These can contain sensitive information even when raw rows are not sent.

## Safe defaults

- Keep the HTTP MCP server off by default and bound to localhost.
- Use OAuth when a person deliberately permits an external client.
- Use only synthetic schemas and data in tests.
- Check route visibility and disclosure text without entering secrets or calling a model.
- Keep sign-in, OAuth approval, Keychain approval, mutation, data copy, and live providers outside default deployment checks.

## Where it lives

- [`docs/security/ai-data-sharing.md`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/docs/security/ai-data-sharing.md) — provider and payload guidance.
- [`host/dbcode-feature-policy.json`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/dbcode-feature-policy.json) — separate evidence for each AI, Copilot, and MCP capability.
- [`host/qa/ticket-03-rendered.cjs`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/qa/ticket-03-rendered.cjs) — prompt-free route checks.

## Related

- [DBCode capability evidence](dbcode-capability-evidence.md)
- [Unmodified Extension Boundary](unmodified-extension-boundary.md)
- [Focused shell and wrapper extensions](../modules/focused-shell-extensions.md)
- [Verification Harness](../modules/verification-harness.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)