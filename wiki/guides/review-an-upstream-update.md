---
title: Review an upstream update
description: A fast path from public update notice to one reviewed release.
type: guide
tags:
  - wiki
  - guide
  - update
  - compatibility
wiki_profile: public
wiki_depth: standard
source_commit: afc5fe7666bf88007bcf4956f05928e3d93c8e2f
---
## Goal

Turn independently published Code OSS, VSCodium, DBCode, or notebook updates into one reviewed wrapper release without rebuilding unchanged inputs or adding human prompts to deployment.

Automatic polling and the status UI report official public information. They do not change pins, approve a candidate, create a tag, publish, or install anything.

## Steps

1. **Review the notice.** Open the official release page from the status view.
2. **Map the changed surface.** For DBCode, compare public contributions, settings, menus, views, editors, tools, connection catalogue, and changed documentation. Review AI, Copilot, automatic MCP registration, HTTP MCP, and inferred relationships separately.
3. **Update canonical records.** Change exact versions, commits, URLs, hashes, signatures, release notes, wrapper version, and only the compatibility policy that changed.
4. **Run focused source checks.** Validate the Release Specification and affected wrapper seams.
5. **Reconcile host patches only when host inputs changed.**
6. **Check the Compiled Host ID.** A DBCode-only or assembly-only update should reuse the verified host.
7. **Build and sign once.** Keep the accepted app and rollback material.
8. **Run only required built checks.** Use static smoke and the one generated `qa` profile. Show changed routes without starting databases, kernels, models, mutation, accounts, or external services.
9. **Inspect the release plan.** Run `./script/release_host.sh plan`.
10. **Prepare the release.** Run `./script/release_host.sh prepare`. It validates acceptance before tag creation and can reuse exact evidence after full validation.
11. **Review and commit approval history.** Commit the single `host/approved-release-history.json` change.
12. **Publish explicitly.** Run `./script/release_host.sh publish --publish` and let it verify the normal public release.

## Relevant code

- [Release Specification](../modules/release-specification.md)
- [Release Source Snapshot](../modules/release-source-snapshot.md)
- [Compiled Host Cache](../modules/compiled-host-cache.md)
- [DBCode capability evidence](../concepts/dbcode-capability-evidence.md)
- [Host Release](../modules/host-release.md)
- [host/release-lock.json](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/release-lock.json)
- [host/dbcode-feature-policy.json](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/dbcode-feature-policy.json)

## Gotchas

- VSCodium packaging and Code OSS runtime labels are related but not interchangeable.
- An available version is not a tested or approved release.
- One AI route does not prove every AI workflow.
- Automatic MCP registration and the HTTP MCP server require separate evidence.
- Re-signing can cause a new macOS prompt even when source is unchanged.
- Representative checks do not prove or limit the complete connection catalogue.

## Related

- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Package and publish a Host Release](../flows/package-and-publish-host-release.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)
- [Choose a verification level](choose-a-verification-level.md)