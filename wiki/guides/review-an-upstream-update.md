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
source_commit: d01539e88c39b72712395899fd206eee40509ab3
---
## Goal

Turn independently published Code OSS, VSCodium, DBCode, or notebook updates into one reviewed wrapper release without rebuilding unchanged inputs or adding human prompts to deployment.

Automatic polling and the status UI report official public information. They do not change pins, approve a candidate, create a tag, publish, or install anything.

## Steps

1. **Review the notice.** Open the official release page from the status view.
2. **Map the changed surface.** For DBCode, compare public contributions, settings, menus, views, editors, tools, connection catalogue, and changed documentation. Treat added commands or settings and removed routes as compatibility-policy changes. Review AI, Copilot, automatic MCP registration, HTTP MCP, and inferred relationships separately.
3. **Update canonical records.** Change exact versions, commits, URLs, hashes, signatures, release notes, wrapper version, and only the compatibility policy that changed.
4. **Run focused source checks.** Validate the Release Specification and affected wrapper seams.
5. **Choose the latest compatible host pair.** Reconcile host patches only when host inputs changed. If the newest Code OSS no longer matches the newest VSCodium build machinery, keep the latest pair that passes clean preparation and patch checks. The status UI can still report a newer available version.
6. **Check the Compiled Host ID.** A DBCode-only or assembly-only update should reuse the verified host.
7. **Inspect the release plan.** Run `./script/release_host.sh plan`. It reports the current source and any branch, working-tree, or tag blocker without changing state.
8. **Prepare the release once.** Run `./script/release_host.sh prepare`. It fails before checkpoint acquisition when the source is unsafe, then owns signing, build or exact reuse, static smoke, one generated-`qa`-profile rendered smoke, final acceptance, tag creation, packaging, independent verification, approval, and history recording.
9. **Review and commit approval history.** Commit the single `host/approved-release-history.json` change.
10. **Publish explicitly.** Run `./script/release_host.sh publish --publish` and let it verify the normal public release.

## Relevant code

- [Release Specification](../modules/release-specification.md)
- [Release Source Snapshot](../modules/release-source-snapshot.md)
- [Compiled Host Cache](../modules/compiled-host-cache.md)
- [DBCode capability evidence](../concepts/dbcode-capability-evidence.md)
- [Host Release](../modules/host-release.md)
- [host/release-lock.json](https://github.com/alexwck/dbcode-wrapper/blob/2dbaee59ad243e222541fbea3b5efcc1873a26df/host/release-lock.json)
- [host/dbcode-feature-policy.json](https://github.com/alexwck/dbcode-wrapper/blob/2dbaee59ad243e222541fbea3b5efcc1873a26df/host/dbcode-feature-policy.json)

## Gotchas

- A plan blocked by an existing version tag at another commit needs a committed wrapper version bump. Never move or replace the published tag.
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