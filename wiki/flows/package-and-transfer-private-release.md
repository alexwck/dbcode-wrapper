---
title: Package and transfer a private release
description: How one exact accepted host build becomes a verified owner-only package for another personal Mac.
type: flow
tags:
  - wiki
  - flow
  - packaging
  - transfer
wiki_profile: public
wiki_depth: standard
source_commit: 2008ff48373c1aac378d0d1ec903e96a88ec1e29
---
## Summary

This flow packages one locally signed, prompt-free accepted host for private use on another Mac owned by the same person. It separates public source, host-only package contents, and private profile state, then verifies the final mounted image independently.

## Trigger

Run only after final acceptance passes for the exact signed app and an annotated source tag points to the immutable commit in its manifest.

## Sequence diagram

```mermaid
sequenceDiagram
  participant Source
  participant Accept as Fast acceptance
  participant Packager
  participant Image as Host-only DMG
  participant Verifier
  participant Target as Personal Mac
  Source->>Accept: Snapshot manifest app rendered report
  Accept-->>Packager: Matching passed report
  Packager->>Image: App guidance metadata checksum
  Image->>Verifier: Mount and inspect independently
  Verifier-->>Target: Verified compatibility facts
  Target->>Target: Install packages and create profile
```

## Steps

1. Confirm the annotated source tag resolves to the manifest's immutable source commit.
2. Confirm the tag's release lock, source snapshot, compiled-host ID, signed app, and manifest agree.
3. Require the prompt-free acceptance report for the exact release-set ID.
4. Verify the app and nested helper signatures.
5. Generate sanitized metadata that states DBCode, licence, and profile contents are not included.
6. Build the DMG, external checksum, and verification receipt under the registered private-release root.
7. Mount the final image read-only and independently recheck contents, digest, signatures, and compatibility record.
8. Transfer only through the owner's private location.
9. On the target Mac, verify the checksum, install the host, then install the pinned external packages into a new Standalone DBCode Profile.
10. Handle Gatekeeper, Safe Storage, licence, or account prompts as normal user setup, outside automated deployment.

## Failure modes

- Source tag, release lock, snapshot, app, manifest, or acceptance report identify different sets.
- The acceptance report came from another app digest or rendered profile run.
- Private paths, credentials, licences, packages, or raw evidence enter the DMG.
- The checksum changes during transfer.
- The target treats the locally signed app as a new identity and asks for approval.
- Packaging or verification writes outside the registered private-release root.

## Related

- [Private Personal Release](../modules/private-personal-release.md)
- [Release Source Snapshot](../modules/release-source-snapshot.md)
- [Verification Harness](../modules/verification-harness.md)
- [Focused host and private profile](../architecture/focused-host-and-private-profile.md)