---
title: Release trust and compatibility
description: How immutable source, cached compilation, exact evidence, approval, and rollback protect a release.
type: architecture
tags:
  - wiki
  - architecture
  - release
  - compatibility
wiki_profile: public
wiki_depth: standard
source_commit: c72b801d36d9c7c2f881fbc74ed4e619ac2b5ec8
---
## Summary

A version number is not enough to approve a release. DBCode Wrapper treats the immutable wrapper source, Code OSS and VSCodium inputs, compiled host, DBCode and notebook packages, profile schema, signed app, and acceptance evidence as one compatibility unit.

The design keeps deployment fast. Every release gets a new auditable source snapshot and final artifact, but unchanged Code OSS compilation can come from a verified content-addressed cache. The default acceptance path is automated and prompt-free.

## Diagram

```mermaid
flowchart LR
  L[Release lock] --> S[Release Source Snapshot]
  S --> C[Compiled Host Cache]
  C --> A[Assemble and sign]
  A --> E[Exact-source and exact-app checks]
  E --> R[Prompt-free acceptance]
  R --> K[Host-only package]
  K --> V[Mounted verification]
  V --> P[Approved Release Set]
  P --> I[Separate install or rollback]
```

## Key components

- [Release Specification](../modules/release-specification.md) validates and projects the canonical lock.
- [Release Source Snapshot](../modules/release-source-snapshot.md) binds one clean commit to the release.
- [Compiled Host Cache](../modules/compiled-host-cache.md) reuses unchanged compilation safely.
- [Approved Release Set](../modules/approved-release-set.md) validates approved history, exact update matches, and prompt-free approval identities.
- [Verification Harness](../modules/verification-harness.md) reruns source contracts and static smoke against the exact release inputs.
- [Private Personal Release](../modules/private-personal-release.md) binds an annotated source tag and final acceptance to the host-only package.

Core transition checks live in [`release_source_snapshot.sh`](https://github.com/alexwck/dbcode-wrapper/blob/c72b801d36d9c7c2f881fbc74ed4e619ac2b5ec8/script/lib/release_source_snapshot.sh), [`compiled_host_cache.sh`](https://github.com/alexwck/dbcode-wrapper/blob/c72b801d36d9c7c2f881fbc74ed4e619ac2b5ec8/script/lib/compiled_host_cache.sh), [`private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/c72b801d36d9c7c2f881fbc74ed4e619ac2b5ec8/script/lib/private_release.sh), and [`approved-release-set.js`](https://github.com/alexwck/dbcode-wrapper/blob/c72b801d36d9c7c2f881fbc74ed4e619ac2b5ec8/host/extensions/dbcode-wrapper-release-status/approved-release-set.js).

## Design decisions

- Update discovery is advisory. It cannot approve or install a release.
- Accepted source tags are immutable and must identify the commit that built the app.
- The compiled-host ID changes only when real compilation inputs change. It keeps Git's executable-file distinction but ignores local read and write permission differences.
- Assembly always creates fresh wrapper records, signature, manifest, and release identity.
- Final acceptance re-enters the manifest's materialized source and reruns development and static checks. Detached success logs are not enough.
- The rendered report is reusable only for the same exact release-set ID.
- Human prompts and external services are normal app-use gates, not deployment tests.
- One persistent generated `qa` profile owns automated GUI checks. The retired manual-proof, four-pair, controlled-promotion, and real-profile health harnesses are historical evidence, not executable release paths.
- Release Specification and Private Personal Release remain the only owners of their full input schemas. Approval consumes their validated purpose records and binds the resulting digests to the package receipt.
- Prompt-free package approval is the single maintained approval writer. The retired prepared-directory validator, member resolver, and proof-based writer are no longer public workflow surfaces.
- Packaging and mounted verification own live app signature checks. Approval consumes the final mounted-package receipt and does not recheck a build-app path or local certificate trust.
- Prompt-free approval writes generated evidence only. It never installs the app or writes the production profile.
- A capability policy becomes approved only when exact host and DBCode package digests match maintained approved history. Features outside the prompt-free evidence are marked limited, not left pending or presented as tested.
- The previous complete set stays protected for rollback. Preparation, digest verification, and disposable preview are maintained; installation or restoration is an owner-controlled action.

## Related

- [Approved Release Set](../concepts/approved-release-set.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)
- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Package and transfer a private release](../flows/package-and-transfer-private-release.md)