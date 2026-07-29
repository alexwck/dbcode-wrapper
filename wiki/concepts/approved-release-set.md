---
title: Approved Release Set
description: The exact compatibility unit that may be published, installed, or restored.
type: concept
tags:
  - wiki
  - concept
  - release
  - compatibility
wiki_profile: public
wiki_depth: standard
source_commit: afc5fe7666bf88007bcf4956f05928e3d93c8e2f
---
## Definition

An Approved Release Set is one exact combination of immutable wrapper source, Code OSS and VSCodium inputs, Compiled Host identity, signed DBCode Wrapper app, official external packages, profile schema, wrapper extensions, signing identity, acceptance evidence, final package receipt, and approval record.

A candidate becomes approved only when all identities, flags, timestamps, and digests match. An update notice, version label, old log, or report from another artifact is not approval. Approval does not install the app or change the production profile.

## Why it matters

Each part can drift independently. A cached host can be corrupt, a rebuilt app can have new bytes, and a package can differ from its staging copy. Exact binding prevents a release from mixing evidence from different builds.

The owner task records the approved set as one small tracked history change. The owner reviews and commits that change before publication. Publication then exposes only the verified host DMG and checksum. The same approved history identifies protected rollback material.

## Where it lives

- Canonical release facts: [host/release-lock.json](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/release-lock.json)
- Owner task: [script/release_host.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/release_host.sh)
- Validation and record creation: [approved-release-set.js](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/host/extensions/dbcode-wrapper-release-status/approved-release-set.js)
- Deep shell validation and safe history update: [approved_release_set.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/lib/approved_release_set.sh)
- Final exact-release evidence: [script/verify_fast_release.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/verify_fast_release.sh)
- Guarded rollback: [prepare_release_rollback.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/prepare_release_rollback.sh), [verify_release_rollback.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/verify_release_rollback.sh), and [preview_release_rollback.sh](https://github.com/alexwck/dbcode-wrapper/blob/afc5fe7666bf88007bcf4956f05928e3d93c8e2f/script/preview_release_rollback.sh)

## Related

- [Approved Release Set module](../modules/approved-release-set.md)
- [Host Release](../modules/host-release.md)
- [Release Source Snapshot](../modules/release-source-snapshot.md)
- [Compiled Host Cache](../modules/compiled-host-cache.md)
- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)