---
title: Generated Workspace Retention
description: The safety contract for ignored build, test, release, and rollback output.
type: module
tags:
  - wiki
  - module
  - retention
  - safety
wiki_profile: public
wiki_depth: standard
source_commit: afc5fe7666bf88007bcf4956f05928e3d93c8e2f
---
## Summary

Generated Workspace Retention is the safety boundary for ignored build, test, cache, release, rollback, and evidence output. It is not a general disk cleaner.

Each registered root is classified by its current artifact purpose and explicit expiry. Retention does not depend on an old issue number, a resolved task, or a retired workflow name. Protected and unknown paths are reported without traversing them.

The current inventory has no deletion-eligible path. Reusable caches, worktrees, the persistent QA profile, signed apps, current Host Release assets, evidence, and rollback material remain protected.

## Responsibilities

- Register rebuildable work, reusable caches, active evidence, retained evidence, rollback evidence, release assets, explicitly expired output, and unknown output.
- Resolve standard paths for build, rendered, acceptance, package, and release-task callers.
- Normalize relative paths, absolute paths, and paths containing spaces before callers use them.
- Refuse broad roots, home roots, symbolic links, paths outside the safety root, and unregistered targets.
- Avoid reading or measuring private profiles and protected artifacts.
- Measure only output explicitly registered as expired.
- Keep cleanup as a dry run unless one exact validated expired path is supplied with `--apply`.
- Refuse class-wide apply and revalidate an exact target immediately before removal.

## Classification and decision flow

```mermaid
flowchart LR
  C[Caller] --> R[Registered artifact purpose]
  R --> N[Normalized absolute path]
  I[Inventory] --> P[Class reason owner expiry]
  S[Exact cleanup selection] --> G[Safety checks]
  G --> D[Dry run plan]
  D -->|exact path and apply| V[Repeat validation]
  V --> X[Remove one expired target]
  G -->|protected unknown broad or link| F[Refuse]
```

## Public API / entry points

[generated_workspace.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/generated_workspace.sh) provides inventory, path resolution, dry-run planning, and exact-path apply. [generated_workspace.cjs](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/generated_workspace.cjs) is the task interface. [generated-workspace-retention.js](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/lib/generated-workspace-retention.js) owns the registry and safety decisions.

## Design decisions

- Purpose and explicit expiry determine retention.
- Reusable compiled hosts stay protected because deleting them can turn a quick release into a full build.
- Current release output and rollback evidence have protected roots.
- Protected artifacts use an uninspected size status.
- Cleanup mutation is limited to one exact validated expired path.

## Participates in

- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)
- [Package and publish a Host Release](../flows/package-and-publish-host-release.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)

## Related

- [Compiled Host Cache](compiled-host-cache.md)
- [Patch Plan and build](patch-plan-and-build.md)
- [Verification Harness](verification-harness.md)
- [Focused host and private profile](../architecture/focused-host-and-private-profile.md)