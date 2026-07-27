---
title: First run, activation, and query
description: How normal user setup installs packages, activates DBCode, creates connections, and runs real work.
type: flow
tags:
  - wiki
  - flow
  - first-run
  - query
wiki_profile: public
wiki_depth: standard
source_commit: 2008ff48373c1aac378d0d1ec903e96a88ec1e29
---
## Summary

The first personal launch turns an empty owned profile into a usable DBCode environment. It verifies and installs the pinned external package set, then lets the owner handle licence, connection, secure-storage, query, and notebook choices.

This is normal app setup, not the automated deployment test. Deployment checks preserve route visibility without entering secrets, accepting terms, starting a kernel, or waiting for a person.

## Trigger

Run after a clean personal installation, on another owned Mac, or after an explicitly confirmed profile recreation.

## Sequence diagram

```mermaid
sequenceDiagram
  participant Owner
  participant Host as DBCode Wrapper
  participant Setup as Profile Setup
  participant Runtime as Runtime Setup
  participant DBCode
  participant Secure as macOS secure storage
  participant Data as Database or data file
  Owner->>Host: Launch personal profile
  Host->>Setup: Detect missing package set
  Setup->>Runtime: Install exact verified packages
  Runtime-->>Setup: External runtime ready
  Setup-->>Owner: Fresh or import choice
  Owner->>DBCode: Activate and add connection
  DBCode->>Secure: Store protected state
  Secure-->>Owner: Ask when approval is required
  Owner->>DBCode: Run query or notebook
  DBCode->>Data: Execute selected work
  Data-->>DBCode: Results
  DBCode-->>Owner: Grid or notebook output
```

## Steps

1. [Profile Layout and Setup](../modules/profile-layout-and-setup.md) validates personal paths.
2. [Focused Runtime Setup](../modules/focused-runtime-setup.md) acquires and verifies DBCode plus pinned Python and Jupyter packages.
3. The owner chooses a fresh profile or reviews an import.
4. The owner enters their DBCode licence. It is never embedded in source or the host-only package.
5. DBCode creates connections from its complete supported catalogue.
6. The owner handles any Keychain, Safe Storage, account, or kernel prompt.
7. Queries and notebooks run in DBCode-owned surfaces when the owner chooses.
8. A full quit and relaunch can confirm personal persistence when needed.

## Failure modes

- Open VSX metadata, digest, signature, archive identity, or public-key binding fails.
- The extension root is outside the owned profile or its installed inventory is not exact.
- A required user permission is denied.
- A database, network, credential, file, or account is unavailable.
- DBCode contributions are incompatible with the host.
- Personal state works only before quit.

## Related

- [Standalone DBCode Profile](../concepts/standalone-dbcode-profile.md)
- [Representative acceptance fixtures](../concepts/representative-acceptance-fixtures.md)
- [AI and MCP data boundaries](../concepts/ai-and-mcp-data-boundaries.md)
- [Trace a DBCode feature](../guides/trace-a-dbcode-feature.md)