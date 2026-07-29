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
source_commit: 5f77cbeeb00b79432ca86b95b0d392d68f0d1d27
---
## Summary

The first personal launch turns an empty owned profile into a usable DBCode environment. Runtime Setup and Profile Setup are registered immediately. If the package set is missing, either setup route leads to the verified runtime prerequisite before Profile Setup offers fresh or reviewed-import choices.

This is normal app setup, not the automated deployment test. Deployment checks prove command reachability and safe routing without entering secrets, accepting terms, starting a kernel, or waiting for a person.

## Trigger

Run after a clean personal installation, on another owned Mac, or after an explicitly confirmed profile recreation.

## Sequence diagram

```mermaid
sequenceDiagram
  participant Owner
  participant Host as DBCode Wrapper
  participant Router as First run router
  participant Runtime as Runtime Setup
  participant Profile as Profile Setup
  participant DBCode
  participant Secure as macOS secure storage
  Owner->>Host: Launch personal profile
  Host->>Router: Register both setup commands
  Owner->>Router: Open Profile Setup
  Router->>Runtime: Open missing prerequisite
  Runtime-->>Router: External runtime ready after reload
  Router->>Profile: Open fresh or import choice
  Owner->>DBCode: Activate and add connection
  DBCode->>Secure: Store protected state
  Secure-->>Owner: Ask when approval is required
  Owner->>DBCode: Run query or notebook
  DBCode-->>Owner: Grid or notebook output
```

## Steps

1. [Profile Layout and Setup](../modules/profile-layout-and-setup.md) validates personal paths and registers both setup routes.
2. [Focused Runtime Setup](../modules/focused-runtime-setup.md) acquires and verifies DBCode plus pinned Python and Jupyter packages when they are missing.
3. Profile Setup uses the shared fail-closed webview policy and offers a fresh profile or reviewed import.
4. The owner enters their DBCode licence. It is never embedded in source or the host-only package.
5. DBCode creates connections from its complete supported catalogue.
6. The owner handles any Keychain, Safe Storage, account, or kernel prompt.
7. Queries and notebooks run in DBCode-owned surfaces when the owner chooses.

## Failure modes

- Runtime configuration fails; both commands remain registered and show a sanitized error.
- Open VSX metadata, digest, signature, archive identity, or public-key binding fails.
- The extension root is outside the owned profile or its installed inventory is not exact.
- A required user permission is denied.
- A database, network, credential, file, or account is unavailable.
- DBCode contributions are incompatible with the host.

## Related

- [Standalone DBCode Profile](../concepts/standalone-dbcode-profile.md)
- [Prompt-free acceptance boundary](../concepts/representative-acceptance-fixtures.md)
- [AI and MCP data boundaries](../concepts/ai-and-mcp-data-boundaries.md)
- [Trace a DBCode feature](../guides/trace-a-dbcode-feature.md)