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
- Pages: [Overview](./OVERVIEW.md), [Product and upstream boundaries](./architecture/product-and-upstream-boundaries.md), [Focused host and private profile](./architecture/focused-host-and-private-profile.md), [Release trust and compatibility](./architecture/release-trust-and-compatibility.md), [Release Specification](./modules/release-specification.md), [Approved Release Set module](./modules/approved-release-set.md), [Profile Layout and Setup](./modules/profile-layout-and-setup.md), [Host Session](./modules/host-session.md), [Patch Plan and build](./modules/patch-plan-and-build.md), [Focused Runtime Setup](./modules/focused-runtime-setup.md), [Focused shell and wrapper extensions](./modules/focused-shell-extensions.md), [Private Personal Release](./modules/private-personal-release.md), [Verification Harness](./modules/verification-harness.md), [Build sign and launch](./flows/build-sign-and-launch.md), [First run activation and query](./flows/first-run-activate-and-query.md), [Controlled upgrade and rollback](flows/approval-and-guarded-rollback.md), [Package and transfer a private release](./flows/package-and-transfer-private-release.md), [Approved Release Set concept](./concepts/approved-release-set.md), [Standalone DBCode Profile](./concepts/standalone-dbcode-profile.md), [Unmodified Extension Boundary](./concepts/unmodified-extension-boundary.md), [Representative acceptance fixtures](./concepts/representative-acceptance-fixtures.md), [Trace a DBCode feature](./guides/trace-a-dbcode-feature.md), [Choose a verification level](./guides/choose-a-verification-level.md), [Review an upstream update](./guides/review-an-upstream-update.md)

## 2026-07-25: refresh

- Profile: public/standard
- source_commit: fbf2982 (previously efe247f)
- Coverage: generated workspace retention; build output ownership; protected profile state; verification evidence; controlled upgrade, rollback, and private-release artifacts
- Created: [Generated Workspace Retention](./modules/generated-workspace-retention.md)
- Updated: [Overview](./OVERVIEW.md), [Focused host and private profile](./architecture/focused-host-and-private-profile.md), [Release trust and compatibility](./architecture/release-trust-and-compatibility.md), [Patch Plan and build](./modules/patch-plan-and-build.md), [Private Personal Release](./modules/private-personal-release.md), [Verification Harness](./modules/verification-harness.md), [Build sign and launch](./flows/build-sign-and-launch.md), [Controlled upgrade and rollback](flows/approval-and-guarded-rollback.md), [Package and transfer a private release](./flows/package-and-transfer-private-release.md), and [Choose a verification level](./guides/choose-a-verification-level.md)

## 2026-07-27: refresh

- Profile: public/standard
- source_commit: 2008ff4 (was fbf2982)
- Coverage: immutable release source; compiled-host reuse; fast prompt-free verification; DBCode feature evidence; AI and MCP privacy; focused-shell routes; exact private packaging
- Created: [Release Source Snapshot](./modules/release-source-snapshot.md), [Compiled Host Cache](./modules/compiled-host-cache.md), [DBCode capability evidence](./concepts/dbcode-capability-evidence.md), and [AI and MCP data boundaries](./concepts/ai-and-mcp-data-boundaries.md)
- Updated: [Overview](./OVERVIEW.md), all [architecture pages](./architecture/product-and-upstream-boundaries.md), the affected [release modules](./modules/release-specification.md), [focused shell](./modules/focused-shell-extensions.md), [verification](./modules/verification-harness.md), [build and release flows](./flows/build-sign-and-launch.md), and [update and feature guides](./guides/review-an-upstream-update.md)

## 2026-07-27: refresh

- Profile: public/standard
- source_commit: 8e15736 (was 2008ff4)
- Coverage: stable Compiled Host identity across normal and private-permission checkouts
- Pages: [Overview](./OVERVIEW.md), [Release trust and compatibility](./architecture/release-trust-and-compatibility.md), [Compiled Host Cache](./modules/compiled-host-cache.md), and [Build sign and launch](./flows/build-sign-and-launch.md)

## 2026-07-27: refresh

- Profile: public/standard
- source_commit: f18e06e (was 8e15736)
- Coverage: normalized materialized-source paths for exact release acceptance
- Pages: [Overview](./OVERVIEW.md), [Release Source Snapshot](./modules/release-source-snapshot.md), [Verification Harness](./modules/verification-harness.md), and [Build sign and launch](./flows/build-sign-and-launch.md)

## 2026-07-27: refresh

- Profile: public/standard
- source_commit: 8a70d5c (was f18e06e)
- Coverage: current VSCodium release-lock field in exact acceptance
- Pages: [Overview](./OVERVIEW.md) and [Verification Harness](./modules/verification-harness.md)

## 2026-07-27: refresh

- Profile: public/standard
- source_commit: f18fc4e (was 8a70d5c)
- Coverage: prompt-free private approval; authoritative release and acceptance validation; mounted-package evidence; approval and installation separation
- Pages: [Overview](./OVERVIEW.md), [Release trust and compatibility](./architecture/release-trust-and-compatibility.md), [Approved Release Set](./modules/approved-release-set.md), [Private Personal Release](./modules/private-personal-release.md), and [Package and transfer a private release](./flows/package-and-transfer-private-release.md)

## 2026-07-27: refresh

- Profile: public/standard
- source_commit: ea09161 (was f18fc4e)
- Coverage: exact `v0.1.1` approved history; mounted-package receipt as the approval boundary; approved DBCode `1.36.4` capability policy; honest limited evidence for optional debugger and AI workflows; approval without installation
- Pages: [Overview](./OVERVIEW.md), [Release trust and compatibility](./architecture/release-trust-and-compatibility.md), [Approved Release Set](./modules/approved-release-set.md), [Private Personal Release](./modules/private-personal-release.md), [Verification Harness](./modules/verification-harness.md), [Focused shell and wrapper extensions](./modules/focused-shell-extensions.md), [DBCode capability evidence](./concepts/dbcode-capability-evidence.md), and [Package and transfer a private release](./flows/package-and-transfer-private-release.md)

## 2026-07-27: refresh

- Profile: public/standard
- source_commit: 03b41f3 (was ea09161)
- Coverage: one persistent automated `qa` profile; prompt-free schema-3 acceptance; retired manual proof, debugger fixture, four-pair compatibility, controlled-promotion, and real-profile health harnesses; protected historical evidence; guarded rollback preparation, verification, and preview
- Renamed: `controlled-upgrade-and-rollback.md` to [Approval and guarded rollback](./flows/approval-and-guarded-rollback.md)
- Updated: [Overview](./OVERVIEW.md), [Release trust and compatibility](./architecture/release-trust-and-compatibility.md), [Approved Release Set concept](./concepts/approved-release-set.md), [DBCode capability evidence](./concepts/dbcode-capability-evidence.md), [Approved Release Set module](./modules/approved-release-set.md), [Private Personal Release](./modules/private-personal-release.md), [Release Specification](./modules/release-specification.md), [Verification Harness](./modules/verification-harness.md), and [Review an upstream update](./guides/review-an-upstream-update.md)

## 2026-07-27: refresh

- Profile: public/standard
- source_commit: c72b801 (was 03b41f3)
- Coverage: one maintained prompt-free approval writer; retired prepared-set validator, member resolver, and proof-based writer; unchanged approved-history, update-matching, and guarded-rollback paths
- Pages: [Overview](./OVERVIEW.md), [Release trust and compatibility](./architecture/release-trust-and-compatibility.md), [Approved Release Set concept](./concepts/approved-release-set.md), and [Approved Release Set module](./modules/approved-release-set.md)