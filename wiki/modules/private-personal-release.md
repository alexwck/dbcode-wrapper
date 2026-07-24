---
title: Private Personal Release
description: The owner-only packaging and verification path for moving a signed DBCode Wrapper build to another personal Mac.
type: module
tags:
  - wiki
  - module
  - release
  - packaging
wiki_profile: public
wiki_depth: standard
source_commit: efe247fc701a9b529e3e6368b6571a44541fc146
---
## Summary

A Private Personal Release is a locally produced, owner-only package. The public repository supplies the build and verification logic; the owner's machine supplies the built app, local signing continuity, approved profile contents, and private release evidence. The package is designed for installation on Macs owned by the same person, without requiring public distribution or Apple notarization.

## Responsibilities

- Confirm the source tag, release lock, build manifest, and built app agree.
- Verify app signing and the expected bundle identity.
- Confirm DBCode and notebook packages live in the external profile, not inside the app bundle.
- Generate a sanitized compatibility manifest without credentials, licences, or machine-specific profile contents.
- Package the app and the minimum private installation material.
- Verify the mounted or extracted release before installation.
- Preserve enough identity and evidence for later health checks and rollback.

## Public API / entry points

[`package_private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/package_private_release.sh) is the packaging command. [`verify_private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/verify_private_release.sh) verifies a package. Shared validation and manifest functions live in `script/lib/private_release.sh`.

## Key files

- [`script/lib/private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/lib/private_release.sh) — source, app, manifest, signing, and sanitization checks.
- [`script/package_private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/package_private_release.sh) — release builder.
- [`script/verify_private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/verify_private_release.sh) — release verifier.
- [`script/verify_same_mac_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/verify_same_mac_release.sh) — owner-machine continuity checks.

## Dependencies

The module consumes [Release Specification](release-specification.md), [Approved Release Set](approved-release-set.md), the signed app, the controlled profile layout, macOS packaging tools, and completed acceptance evidence.

## Participates in

- [Package and transfer a private release](../flows/package-and-transfer-private-release.md)
- [Controlled upgrade and rollback](../flows/controlled-upgrade-and-rollback.md)

## Related

- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Standalone DBCode Profile](../concepts/standalone-dbcode-profile.md)
- [Choose a verification level](../guides/choose-a-verification-level.md)
