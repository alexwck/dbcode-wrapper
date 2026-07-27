---
title: Approval and guarded rollback
description: The prompt-free approval path and the explicit owner-controlled path for inspecting or restoring a known-good release.
type: flow
tags:
  - wiki
  - flow
  - approval
  - rollback
wiki_profile: public
wiki_depth: standard
source_commit: 03b41f3106f00d64fffa5307ddd2084981972818
---
## Summary

Update discovery reports candidates but never installs them. A release becomes approved only after exact-source checks, one persistent-profile rendered check, host-only packaging, and independent mounted verification all identify the same release set. Approval writes generated records; it does not install the app or change the personal profile.

The previous known-good release stays protected. Rollback tools can prepare it from approved history, verify its digests and signature, and preview it with a disposable profile. Installing or restoring it is a separate owner-controlled action.

## Trigger

Start this flow when an upstream update is ready for review, or when the owner needs to inspect a known-good rollback set.

## Sequence diagram

```mermaid
sequenceDiagram
  participant Status as Update Status
  participant Build
  participant Verify
  participant Package
  participant History as Approval History
  participant Owner
  Status-->>Build: Candidate versions selected
  Build->>Verify: Exact source, app, and manifest
  Verify->>Package: Prompt-free acceptance
  Package->>Package: Mount and verify host-only image
  Package-->>History: Exact package receipt
  History-->>Owner: Approved release available
  alt owner chooses installation
    Owner->>Owner: Install separately
  else rollback is needed
    History-->>Owner: Prepare, verify, and preview known-good set
    Owner->>Owner: Restore separately
  end
```

## Steps

1. Review official changes and update the release lock, feature policy, and patches.
2. Finish release work, then build once from a clean immutable source commit.
3. Reuse the [Compiled Host Cache](../modules/compiled-host-cache.md) when compilation inputs are unchanged.
4. Run exact-source development checks, static smoke, and the matching one-profile rendered smoke.
5. Package and independently verify the host-only image.
6. Write approval only when source, app, extension, acceptance, and package identities match exactly.
7. Keep installation separate from approval and production-profile changes.
8. For rollback, prepare the known-good set from approved history, verify every retained digest and signature, and optionally preview it without replacing the current app.
9. Fully quit the app before any owner-controlled install or restore.

The retired four-pair compatibility, controlled-promotion, manual proof, and real-profile health harnesses are historical evidence only. They are not deployment steps and their generated output remains protected.

## Failure modes

- Discovery has a newer version but no approved release set.
- Source, cache receipt, app, manifest, rendered evidence, or package receipt identify different releases.
- The package includes DBCode, profile data, credentials, or another forbidden private asset.
- Approval would replace an existing generated bundle or write the installed app or production profile.
- A rollback set does not match approved history, its build manifest, signature, or stored digests.
- A rollback path is outside its registered protected root.

## Related

- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Approved Release Set](../modules/approved-release-set.md)
- [Private Personal Release](../modules/private-personal-release.md)
- [Generated Workspace Retention](../modules/generated-workspace-retention.md)
- [Review an upstream update](../guides/review-an-upstream-update.md)