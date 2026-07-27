---
title: Review an upstream update
description: A fast safe path for evaluating DBCode, Code OSS, VSCodium, or notebook changes as one candidate.
type: guide
tags:
  - wiki
  - guide
  - update
  - compatibility
wiki_profile: public
wiki_depth: standard
source_commit: 2008ff48373c1aac378d0d1ec903e96a88ec1e29
---
## Goal

Turn independently published upstream versions into one reviewed wrapper candidate without rebuilding unchanged inputs or making human prompts part of deployment.

## Steps

1. **Treat discovery as information.** Open official release and changelog pages. Do not install from the notice.
2. **Map the changed surface.** For DBCode, compare its public contributions, settings, menus, views, editors, tools, connection catalogue, and changed documentation. Keep AI, Copilot, automatic MCP registration, HTTP MCP, and inferred relationships separate.
3. **Update canonical records.** Change exact versions, commits, URLs, hashes, signatures, release notes, release status, and feature policy.
4. **Run focused source checks.** Validate the release specification and only the seams affected by the update.
5. **Reconcile host patches only when host inputs changed.** Do not rewrite a patch to hide drift.
6. **Check the compiled-host input ID.** A DBCode-only or assembly-only change should reuse the verified host. A real compile input change requires one new build.
7. **Finish release work, then build once.** Preserve the current accepted app and rollback material.
8. **Run static and one-profile rendered checks.** Confirm the full New Connection catalogue and changed DBCode routes. Do not activate prompts, accounts, kernels, models, mutation, or external services.
9. **Add one focused proof only when needed.** New, changed, limited, or high-risk features can receive a separate safe rendered or live check.
10. **Run final exact-release acceptance.** Approve, package, or promote only matching source, app, manifest, signature, extension, and rendered evidence.

## Relevant code

- [Release Specification](../modules/release-specification.md)
- [Release Source Snapshot](../modules/release-source-snapshot.md)
- [Compiled Host Cache](../modules/compiled-host-cache.md)
- [DBCode capability evidence](../concepts/dbcode-capability-evidence.md)
- [`host/release-lock.json`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/release-lock.json)
- [`host/dbcode-feature-policy.json`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/dbcode-feature-policy.json)

## Gotchas

- VSCodium and Code OSS labels are related but not interchangeable.
- A newer DBCode package can expose a new command while an older host route stays broken.
- One working AI settings route does not prove every AI workflow.
- Automatic MCP registration and the HTTP MCP server require separate evidence.
- Re-signing can cause a new macOS prompt even when code is unchanged.
- Representative database checks do not prove or limit the complete connection catalogue.

## Related

- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Controlled upgrade and rollback](../flows/controlled-upgrade-and-rollback.md)
- [Choose a verification level](choose-a-verification-level.md)