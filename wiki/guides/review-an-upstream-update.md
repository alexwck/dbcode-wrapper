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
source_commit: e02160a3b5363fc4e91c5282f7818ed908624c6d
---
## Goal

Turn independently published upstream versions into one reviewed wrapper candidate without rebuilding unchanged inputs or making human prompts part of deployment.

Automatic polling and the status UI remain useful. They report official public information; they do not update pins, approve a candidate, create a tag, publish a release, or install anything.

## Steps

1. **Review the notice.** Open the official Code OSS, VSCodium, or DBCode release page from the status view.
2. **Map the changed surface.** For DBCode, compare public contributions, settings, menus, views, editors, tools, connection catalogue, and changed documentation. Keep AI, Copilot, automatic MCP registration, HTTP MCP, and inferred relationships separate.
3. **Update canonical records.** Change exact versions, commits, URLs, hashes, signatures, release notes, wrapper version, and only the compatibility policy that changed.
4. **Run focused source checks.** Validate the release specification and affected wrapper seams.
5. **Reconcile host patches only when host inputs changed.** Stale applied-tree output fails at compilation, not during unrelated source checks.
6. **Check the Compiled Host ID.** A DBCode-only or assembly-only change should reuse the verified host.
7. **Finish release work, then build once.** Preserve the accepted app and rollback material.
8. **Run static and one-profile rendered checks.** Confirm the full connection catalogue and changed DBCode routes without activating prompts, kernels, models, mutation, or external services.
9. **Run exact-source final acceptance.**
10. **Package, approve, and publish.** Use [Host Release](../modules/host-release.md), publish only the DMG and checksum, then verify the public result.

## Relevant code

- [Release Specification](../modules/release-specification.md)
- [Release Source Snapshot](../modules/release-source-snapshot.md)
- [Compiled Host Cache](../modules/compiled-host-cache.md)
- [DBCode capability evidence](../concepts/dbcode-capability-evidence.md)
- [host/release-lock.json](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/host/release-lock.json)
- [host/dbcode-feature-policy.json](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/host/dbcode-feature-policy.json)

## Gotchas

- VSCodium packaging and Code OSS runtime labels are related but not interchangeable.
- An available version is not a tested or approved release.
- One working AI settings route does not prove every AI workflow.
- Automatic MCP registration and the HTTP MCP server require separate evidence.
- Re-signing can cause a new macOS prompt even when code is unchanged.
- Representative database checks do not prove or limit the complete connection catalogue.

## Related

- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Package and publish a Host Release](../flows/package-and-publish-host-release.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)
- [Choose a verification level](choose-a-verification-level.md)
