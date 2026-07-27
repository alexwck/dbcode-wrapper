---
title: Unmodified Extension Boundary
description: The rule that the wrapper hosts and verifies DBCode without copying or changing its implementation.
type: concept
tags:
  - wiki
  - concept
  - dbcode
  - boundary
wiki_profile: public
wiki_depth: standard
source_commit: 2008ff48373c1aac378d0d1ec903e96a88ec1e29
---
## Definition

The Unmodified Extension Boundary means DBCode Wrapper installs the official pinned DBCode package and integrates around it. The project does not patch DBCode, copy proprietary source, replace its database drivers, or rebuild its editors, grids, notebooks, AI, or MCP tools.

The wrapper may adapt the open host, supply focused navigation, validate public extension contributions, launch commands, and preserve compatible profile state. DBCode still owns database and AI product behaviour.

## Why it matters

This keeps the wrapper small, maintainable, and aligned with the purchased licence. It avoids a private fork that must be merged for every DBCode release and keeps deployment focused on the integration boundary.

When a DBCode contribution becomes unavailable, first test host compatibility and routing. Do not silently delete the feature or reproduce it in wrapper code. Record an honest limit until a focused route works.

The same rule applies to AI and MCP. The wrapper exposes DBCode-owned routes and privacy guidance; it does not add another model client or claim a live workflow from route visibility alone.

## Where it lives

- [`host/release-lock.json`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/release-lock.json) — official package identity and digests.
- [`host/dbcode-feature-policy.json`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/dbcode-feature-policy.json) — capability routes, evidence, and known limits.
- [`docs/product/dbcode-capability-coverage.md`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/docs/product/dbcode-capability-coverage.md) — public feature-family map.
- [`script/test_dbcode_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/test_dbcode_contract.sh) — package and boundary checks.

## Related

- [Product and upstream boundaries](../architecture/product-and-upstream-boundaries.md)
- [DBCode capability evidence](dbcode-capability-evidence.md)
- [AI and MCP data boundaries](ai-and-mcp-data-boundaries.md)
- [Trace a DBCode feature](../guides/trace-a-dbcode-feature.md)