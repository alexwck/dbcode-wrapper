---
title: Unmodified Extension Boundary
description: The rule that the wrapper hosts and verifies DBCode without copying or changing its proprietary implementation.
type: concept
tags:
  - wiki
  - concept
  - dbcode
  - boundary
wiki_profile: public
wiki_depth: standard
source_commit: efe247fc701a9b529e3e6368b6571a44541fc146
---
## Definition

The Unmodified Extension Boundary means DBCode Wrapper installs the official pinned DBCode package and integrates around it. The project does not patch DBCode's package, copy its proprietary source, replace its database drivers, or reimplement its grids and editors.

The wrapper may adapt the open host, supply focused navigation, validate extension contributions, launch commands, and preserve compatible profile state. DBCode still owns database connectivity and its feature surfaces.

## Why it matters

This boundary keeps the project maintainable and aligned with the purchased licence. It avoids creating a private fork that would need to be merged for every DBCode release. It also keeps support broad: the wrapper's acceptance fixtures do not become an allowlist of databases because connection behavior stays inside DBCode.

When a host change makes a DBCode contribution unavailable, the correct response is to assess host compatibility or adjust the wrapper route—not silently delete the upstream feature or reproduce it in wrapper code.

## Where it lives

- Extension identity and package records: [`host/release-lock.json`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/release-lock.json)
- Capability inventory and retention policy: [`host/dbcode-feature-policy.json`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/dbcode-feature-policy.json)
- Host-side product policy: [`host/slimming-policy.json`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/slimming-policy.json)
- Contract checks: [`script/test_dbcode_contract.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/test_dbcode_contract.sh)

## Related

- [Product and upstream boundaries](../architecture/product-and-upstream-boundaries.md)
- [Focused shell and wrapper extensions](../modules/focused-shell-extensions.md)
- [Trace a DBCode feature](../guides/trace-a-dbcode-feature.md)
