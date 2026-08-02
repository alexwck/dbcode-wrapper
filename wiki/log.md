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

## 2026-07-27: refresh

- Profile: public/standard
- source_commit: d06cd2a (was c72b801)
- Coverage: zero unknown generated roots; protected historical controlled-upgrade evidence; explicit dry-run targets for Finder metadata, the retired catalogue profile, and the abandoned smoke-backup root; retained caches and worktrees for fast deployment
- Pages: [Overview](./OVERVIEW.md) and [Generated Workspace Retention](./modules/generated-workspace-retention.md)

## 2026-07-27: refresh

- Profile: public/standard
- source_commit: e20a9a1 (was d06cd2a)
- Coverage: one testable Profile Setup workflow; thin VS Code and DBCode host adapter; prompt-free action-order, cleanup, persistence, DuckDB preflight, and recovery-handoff checks
- Pages: [Overview](./OVERVIEW.md), [Focused host and private profile](./architecture/focused-host-and-private-profile.md), and [Profile Layout and Setup](./modules/profile-layout-and-setup.md)

## 2026-07-27: refresh

- Profile: public/standard
- source_commit: ddaa6a0 (was e20a9a1)
- Coverage: Release Specification schema 5; generated profile identity; shell and JavaScript path parity; query-storage product identity; profile-only Compiled Host reuse; static identity checks; historical rollback identity
- Pages: [Overview](./OVERVIEW.md), [Focused host and private profile](./architecture/focused-host-and-private-profile.md), [Release trust and compatibility](./architecture/release-trust-and-compatibility.md), [Standalone DBCode Profile](./concepts/standalone-dbcode-profile.md), [Release Specification](./modules/release-specification.md), [Compiled Host Cache](./modules/compiled-host-cache.md), [Profile Layout and Setup](./modules/profile-layout-and-setup.md), [Focused shell and wrapper extensions](./modules/focused-shell-extensions.md), [Patch Plan and build](./modules/patch-plan-and-build.md), [Verification Harness](./modules/verification-harness.md), [Build sign and launch](./flows/build-sign-and-launch.md), and [Approval and guarded rollback](./flows/approval-and-guarded-rollback.md)

## 2026-07-28: refresh

- Profile: public/standard
- source_commit: b9186c1 (was ddaa6a0)
- Coverage: prompt-free exact-path cleanup; plan-only class selection; removed Finder metadata, the retired catalogue profile, and the abandoned smoke-backup root; retained QA evidence, screenshots, caches, worktrees, release assets, rollback evidence, and historical upgrade evidence
- Pages: [Overview](./OVERVIEW.md) and [Generated Workspace Retention](./modules/generated-workspace-retention.md)

## 2026-07-28: refresh

- Profile: public/standard
- source_commit: b40ed3f (was b9186c1)
- Coverage: one Open VSX verifier shared by Finder first-run and release-script adapters; complete package, engine, signature, manifest, and ZIP checks; fast prompt-free synthetic matrix; focused real-cache verification
- Pages: [Overview](./OVERVIEW.md) and [Focused Runtime Setup](./modules/focused-runtime-setup.md)

## 2026-07-28: refresh

- Profile: public/standard
- source_commit: 80fdddd (was b40ed3f)
- Coverage: exact `v0.1.2` approval; prompt-free cached deployment; materialized-source isolation from foreign generated worktrees; no installation or production-profile write
- Pages: [Overview](./OVERVIEW.md), [Release trust and compatibility](./architecture/release-trust-and-compatibility.md), [Approved Release Set](./modules/approved-release-set.md), [Verification Harness](./modules/verification-harness.md), and [Package and transfer a private release](./flows/package-and-transfer-private-release.md)

## 2026-07-29: refresh

- Profile: public/standard
- source_commit: c0126c5 (was 80fdddd)
- Coverage: authenticated unpublished `v0.1.2` draft transfer; exact five-asset integrity; owner download verification; anonymous denial; no publication workflow; no installation or profile change
- Pages: [Overview](./OVERVIEW.md), [Private Personal Release](./modules/private-personal-release.md), and [Package and transfer a private release](./flows/package-and-transfer-private-release.md)

## 2026-07-29: refresh

- Profile: public/standard
- source_commit: e02160a (was c0126c5)
- Coverage: normal same-repository `v0.1.3` Host Release; automatic read-only update polling; schema-6 public distribution policy; one digest-bound package context; independent mounted-DMG validation; compile-bound patch-tree checks; protected current Host Release assets; retained historical `v0.1.2` draft pages
- Pages: [Overview](./OVERVIEW.md), [Release trust and compatibility](./architecture/release-trust-and-compatibility.md), [Approved Release Set concept](./concepts/approved-release-set.md), [Approval and guarded rollback](./flows/approval-and-guarded-rollback.md), [Package and publish a Host Release](./flows/package-and-publish-host-release.md), [Historical private transfer](./flows/package-and-transfer-private-release.md), [Review an upstream update](./guides/review-an-upstream-update.md), [Approved Release Set module](./modules/approved-release-set.md), [Focused shell and wrapper extensions](./modules/focused-shell-extensions.md), [Generated Workspace Retention](./modules/generated-workspace-retention.md), [Host Release](./modules/host-release.md), [Patch Plan and build](./modules/patch-plan-and-build.md), [Historical Private Personal Release](./modules/private-personal-release.md), [Release Source Snapshot](./modules/release-source-snapshot.md), [Release Specification](./modules/release-specification.md), and [Verification Harness](./modules/verification-harness.md)

## 2026-07-29: refresh

- Profile: public/standard
- source_commit: e02160a (unchanged; documentation-only cleanup)
- Coverage: current Host Release; automatic read-only update polling; one prompt-free `qa` profile; retired release details removed from active public guidance; forward pointers retained for append-only log links
- Pages: [Overview](./OVERVIEW.md), [Release trust and compatibility](./architecture/release-trust-and-compatibility.md), [Approval and guarded rollback](./flows/approval-and-guarded-rollback.md), [Package and publish a Host Release](./flows/package-and-publish-host-release.md), [Review an upstream update](./guides/review-an-upstream-update.md), [Generated Workspace Retention](./modules/generated-workspace-retention.md), [Host Release](./modules/host-release.md), and [Verification Harness](./modules/verification-harness.md)

## 2026-07-29: refresh

- Profile: public/standard
- source_commit: afc5fe7 (was e02160a)
- Coverage: thin-wrapper boundary; automatic read-only upstream polling; one owner-facing Host Release task; acceptance before tag; exact evidence resume; tracked approval history; explicit normal publication; artifact-purpose retention; one prompt-free `qa` profile; AI and MCP data boundaries; retired live fixture guidance
- Pages: [Overview](./OVERVIEW.md), [Release trust and compatibility](./architecture/release-trust-and-compatibility.md), [AI and MCP data boundaries](./concepts/ai-and-mcp-data-boundaries.md), [Approved Release Set concept](./concepts/approved-release-set.md), [Prompt-free acceptance boundary](./concepts/representative-acceptance-fixtures.md), [Approval and guarded rollback](./flows/approval-and-guarded-rollback.md), [Package and publish a Host Release](./flows/package-and-publish-host-release.md), [Review an upstream update](./guides/review-an-upstream-update.md), [Approved Release Set module](./modules/approved-release-set.md), [Focused shell and wrapper extensions](./modules/focused-shell-extensions.md), [Generated Workspace Retention](./modules/generated-workspace-retention.md), [Host Release](./modules/host-release.md), and [Verification Harness](./modules/verification-harness.md)

## 2026-07-29: refresh

- Profile: public/standard
- source_commit: ca6a58c (was afc5fe7)
- Coverage: DBCode query results below the editor at every width; one public result-location preference; no wrapper result renderer; Release Specification schema 7; exact read-only schema-6 compatibility; old responsive hosts excluded from reuse
- Pages: [Overview](./OVERVIEW.md), [Focused shell and wrapper extensions](./modules/focused-shell-extensions.md), and [Release Specification](./modules/release-specification.md)

## 2026-07-29: refresh

- Profile: public/standard
- source_commit: 3da4fca (was ca6a58c)
- Coverage: cold-build patch verification after VSCodium preparation and before Code OSS compilation; focused regression for approved and changed prepared trees
- Pages: [Overview](./OVERVIEW.md) and [Patch Plan and build](./modules/patch-plan-and-build.md)

## 2026-07-29: refresh

- Profile: public/standard
- source_commit: d316203 (was 3da4fca)
- Coverage: exact pinned VSCodium patch applicability through a temporary Git index; corrected source context for the post-preparation verifier hook
- Pages: [Overview](./OVERVIEW.md) and [Patch Plan and build](./modules/patch-plan-and-build.md)

## 2026-07-29: refresh

- Profile: public/standard
- source_commit: 2dbaee5 (was d316203)
- Coverage: DBCode 1.36.6 feature-policy review; added and removed public contributions; latest-compatible VSCodium and Code OSS pairing; unchanged compiled-host reuse; prompt-free rendered acceptance
- Pages: [Overview](./OVERVIEW.md), [DBCode capability evidence](./concepts/dbcode-capability-evidence.md), [Review an upstream update](./guides/review-an-upstream-update.md), and [Release Specification](./modules/release-specification.md)

## 2026-07-29: refresh

- Profile: public/standard
- source_commit: 34275d9 (was 2dbaee5)
- Coverage: persistent DBCode side drawers; Account-only outside-click and Escape dismissal; one collapse and restore control; prompt-free rendered coverage for Explorer, History, Library, and Account
- Pages: [Overview](./OVERVIEW.md) and [Focused shell and wrapper extensions](./modules/focused-shell-extensions.md)

## 2026-07-30: refresh

- Profile: public/standard
- source_commit: 5f77cbe (was 34275d9)
- Coverage: always-reachable first-run commands; shared webview safety; first-class focused-shell TypeScript and CSS; materialize-then-verify Patch Plan; active slimming policy separated from complete dated evidence; success-and-failure temporary cleanup; relative, absolute, and spaced path contracts; invisible fail-closed security boundaries
- Pages: [Overview](./OVERVIEW.md), [Focused shell and wrapper extensions](./modules/focused-shell-extensions.md), [Profile Layout and Setup](./modules/profile-layout-and-setup.md), [Patch Plan and build](./modules/patch-plan-and-build.md), [Compiled Host Cache](./modules/compiled-host-cache.md), [Verification Harness](./modules/verification-harness.md), [First run, activation, and query](./flows/first-run-activate-and-query.md), and [AI and MCP data boundaries](./concepts/ai-and-mcp-data-boundaries.md)

## 2026-08-01: refresh

- Profile: public/standard
- source_commit: 8b6a9c8 (was 5f77cbe)
- Coverage: restarted public version line; one normal `v0.1.0` release from current source; retained Git history and protected local release evidence; unchanged fast owner-facing release path
- Pages: [Overview](./OVERVIEW.md)

## 2026-08-01: refresh

- Profile: public/standard
- source_commit: 2191402 (was 8b6a9c8)
- Coverage: one serialized prompt-free release preparation task; signing readiness before assembly; full-lifetime kernel checkpoint lease; recoverable staged app and manifest promotion; exact package and approval resume; one persistent `qa` profile; separate explicit publication; build-coordination and assembly retention roots
- Pages: [Overview](./OVERVIEW.md), [Release trust and compatibility](./architecture/release-trust-and-compatibility.md), [Host Release](./modules/host-release.md), [Patch Plan and build](./modules/patch-plan-and-build.md), [Generated Workspace Retention](./modules/generated-workspace-retention.md), [Verification Harness](./modules/verification-harness.md), [Build sign and launch](./flows/build-sign-and-launch.md), and [Package and publish a Host Release](./flows/package-and-publish-host-release.md)

## 2026-08-01: refresh

- Profile: public/standard
- source_commit: 3700317 (was 2191402)
- Coverage: Static Host Smoke owns package size, source maps, exact built-in inventory, embedded-DBCode exclusion, and generated managed settings; Profile Layout keeps only `default` and persistent `qa`; profile recovery is current-user only; Host Session exposes one run command and validates once per public operation
- Pages: [Overview](./OVERVIEW.md), [Profile Layout and Setup](./modules/profile-layout-and-setup.md), [Standalone DBCode Profile](./concepts/standalone-dbcode-profile.md), [Host Session](./modules/host-session.md), [Patch Plan and build](./modules/patch-plan-and-build.md), and [Verification Harness](./modules/verification-harness.md)

## 2026-08-01: refresh

- Profile: public/standard
- source_commit: b9d8895 (was 3700317)
- Coverage: faster default source gate; change-owned deep build and release fixtures; one checked Host Configuration extraction; current-only semantic Patch Plan; smaller CommonJS interfaces; consistent private Standalone DBCode Profile language
- Pages: [Overview](./OVERVIEW.md), [Product and upstream boundaries](./architecture/product-and-upstream-boundaries.md), [Release Specification](./modules/release-specification.md), [Patch Plan and build](./modules/patch-plan-and-build.md), [Compiled Host Cache](./modules/compiled-host-cache.md), and [Verification Harness](./modules/verification-harness.md)

## 2026-08-01: refresh

- Profile: public/standard
- source_commit: 764d76e (was b9d8895)
- Coverage: smaller read-only Update Status interface; one purpose-level Host Session launch record; verifier-owned runtime configuration, canonical package selection, installed identity, safe public-key path, and package security; current-interface tests without deleted-name lists; 21.45-second prompt-free development gate
- Pages: [Overview](./OVERVIEW.md), [Host Session](./modules/host-session.md), [Focused Runtime Setup](./modules/focused-runtime-setup.md), [Focused shell and wrapper extensions](./modules/focused-shell-extensions.md), and [Verification Harness](./modules/verification-harness.md)

## 2026-08-02: refresh

- Profile: public/standard
- source_commit: 02a3c23 (was 764d76e)
- Coverage: build-relevant Patch Plan projection without wording-only recompilation; package details kept inside the extension purpose record; Profile Recovery tested through its one `run` interface and operating-system adapter; current maintained exports; 20.96-second prompt-free development gate
- Pages: [Overview](./OVERVIEW.md), [Compiled Host Cache](./modules/compiled-host-cache.md), [Patch Plan and build](./modules/patch-plan-and-build.md), [Profile Layout and Setup](./modules/profile-layout-and-setup.md), and [Release Specification](./modules/release-specification.md)

## 2026-08-02: refresh

- Profile: public/standard
- source_commit: b3773b5 (was 02a3c23)
- Coverage: one Runtime Extension Set projection and checker; one purpose-level Host Session run lifecycle; production-interface tests without test-only exports or modes; small Update Status service interface; 21.66-second prompt-free development gate
- Pages: [Overview](./OVERVIEW.md), [Focused Runtime Setup](./modules/focused-runtime-setup.md), [Host Session](./modules/host-session.md), [Focused shell and wrapper extensions](./modules/focused-shell-extensions.md), and [Verification Harness](./modules/verification-harness.md)

## 2026-08-02: refresh

- Profile: public/standard
- source_commit: f1cc5e1 (was b3773b5)
- Coverage: production Runtime Extension Set included in wrapper source identity; test-only engine checker removed; smaller maintained Runtime Setup and package-file interfaces; current-behaviour tests without retired workflow-name scans; Python Kernel Bridge retained for DBCode's running-kernel workflow; complete prompt-free development gate passed
- Pages: [Overview](./OVERVIEW.md), [Release Source Snapshot](./modules/release-source-snapshot.md), [Focused Runtime Setup](./modules/focused-runtime-setup.md), [Focused shell and wrapper extensions](./modules/focused-shell-extensions.md), and [Verification Harness](./modules/verification-harness.md)

## 2026-08-02: refresh

- Profile: public/standard
- source_commit: d01539e (was f1cc5e1)
- Coverage: read-only release preparation readiness; source validation before checkpoint acquisition; exact approval-history-only same-tag resume; final HEAD revalidation; one owner-facing preparation gate; shorter host operations guide
- Pages: [Overview](./OVERVIEW.md), [Release trust and compatibility](./architecture/release-trust-and-compatibility.md), [Host Release](./modules/host-release.md), [Package and publish a Host Release](./flows/package-and-publish-host-release.md), and [Review an upstream update](./guides/review-an-upstream-update.md)
