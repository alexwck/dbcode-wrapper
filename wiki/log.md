---
title: Wiki Log
description: Append-only audit trail of wiki generation and refresh runs.
---

# Wiki Log

Append-only audit trail. Add one dated entry per generation or refresh run, recording the profile, the `source_commit` it was anchored to, and the coverage. The codebase-wiki skill describes the entry shape.

## 2026-07-25: generate

- Profile: public/standard
- source_commit: efe247f
- Coverage: overview; 3 architecture areas; 9 modules; 4 flows; 4 concepts; 3 guides
- Pages: [Overview](./OVERVIEW.md), [Product and upstream boundaries](./architecture/product-and-upstream-boundaries.md), [Focused host and private profile](./architecture/focused-host-and-private-profile.md), [Release trust and compatibility](./architecture/release-trust-and-compatibility.md), [Release Specification](./modules/release-specification.md), [Approved Release Set module](./modules/approved-release-set.md), [Profile Layout and Setup](./modules/profile-layout-and-setup.md), [Host Session](./modules/host-session.md), [Patch Plan and build](./modules/patch-plan-and-build.md), [Focused Runtime Setup](./modules/focused-runtime-setup.md), [Focused shell and wrapper extensions](./modules/focused-shell-extensions.md), [Private Personal Release](./modules/private-personal-release.md), [Verification Harness](./modules/verification-harness.md), [Build sign and launch](./flows/build-sign-and-launch.md), [First run activation and query](./flows/first-run-activate-and-query.md), [Controlled upgrade and rollback](./flows/controlled-upgrade-and-rollback.md), [Package and transfer a private release](./flows/package-and-transfer-private-release.md), [Approved Release Set concept](./concepts/approved-release-set.md), [Standalone DBCode Profile](./concepts/standalone-dbcode-profile.md), [Unmodified Extension Boundary](./concepts/unmodified-extension-boundary.md), [Representative acceptance fixtures](./concepts/representative-acceptance-fixtures.md), [Trace a DBCode feature](./guides/trace-a-dbcode-feature.md), [Choose a verification level](./guides/choose-a-verification-level.md), [Review an upstream update](./guides/review-an-upstream-update.md)
