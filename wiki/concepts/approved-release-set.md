---
title: Approved Release Set
description: The exact sourced, built, signed, packaged, and evidenced compatibility unit that may be published, installed, or restored.
type: concept
tags:
  - wiki
  - concept
  - release
  - compatibility
wiki_profile: public
wiki_depth: standard
source_commit: e02160a3b5363fc4e91c5282f7818ed908624c6d
---
## Definition

An Approved Release Set is one exact combination of immutable wrapper source, Code OSS and VSCodium inputs, Compiled Host identity, signed DBCode Wrapper app, official DBCode and notebook packages, profile schema, wrapper extensions, signing identity, acceptance evidence, and final package receipt.

A candidate becomes approved only when these identities and digests match. An update notice, matching version label, old success log, or rendered report from another artifact is not approval. Approval does not install the app or change the production profile.

## Why it matters

DBCode can work on one host and fail on another. A cached host can be corrupt even when its name looks right. A rebuilt app or transferred DMG can carry different bytes. Binding immutable source, verified compilation, final app, mounted package, and evidence prevents those pieces from drifting apart.

The approved set is also the publication and rollback reference. Publication exposes only its verified host DMG and checksum. Rollback keeps the retained app, manifest, extensions, and profile evidence together for separate owner-controlled verification and restoration.

## Where it lives

- Canonical release facts: [host/release-lock.json](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/host/release-lock.json)
- Validation and record creation: [approved-release-set.js](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/host/extensions/dbcode-wrapper-release-status/approved-release-set.js)
- Signed source and artifact facts: [script/generate_manifest.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/generate_manifest.sh)
- Final exact-release evidence: [script/verify_fast_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/verify_fast_release.sh)
- Host-only package: [script/lib/host_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/lib/host_release.sh)
- Guarded rollback: [prepare_release_rollback.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/prepare_release_rollback.sh), [verify_release_rollback.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/verify_release_rollback.sh), and [preview_release_rollback.sh](https://github.com/alexwck/dbcode-wrapper/blob/e02160a3b5363fc4e91c5282f7818ed908624c6d/script/preview_release_rollback.sh)

## Related

- [Approved Release Set module](../modules/approved-release-set.md)
- [Host Release](../modules/host-release.md)
- [Release Source Snapshot](../modules/release-source-snapshot.md)
- [Compiled Host Cache](../modules/compiled-host-cache.md)
- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
