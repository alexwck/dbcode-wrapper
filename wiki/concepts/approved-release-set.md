---
title: Approved Release Set
description: The exact sourced, built, signed, and evidenced compatibility unit that may be installed or restored.
type: concept
tags:
  - wiki
  - concept
  - release
  - compatibility
wiki_profile: public
wiki_depth: standard
source_commit: 03b41f3106f00d64fffa5307ddd2084981972818
---
## Definition

An Approved Release Set is one exact combination of immutable wrapper source, Code OSS and VSCodium inputs, compiled-host identity, signed DBCode Wrapper app, official DBCode package, pinned notebook packages, profile schema, wrapper extensions, signing identity, and acceptance evidence.

A candidate becomes approved only when these identities and digests match one another. An update notice, matching version label, successful old log, or rendered report from another artifact is not approval.

## Why it matters

DBCode can work on one host and fail on another. A cached host can be corrupt even when its name looks right. A rebuilt app can carry different wrapper code or trigger a new macOS identity. Binding immutable source, verified compilation, final app, and evidence prevents those pieces from drifting apart.

The set is also the rollback reference. Rollback preparation keeps the app, manifest, extensions, and profile evidence together for digest verification and a disposable preview. Installing or restoring the verified set remains an owner-controlled action.

## Where it lives

- Canonical release facts: [`host/release-lock.json`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/release-lock.json)
- Validation and record creation: [`approved-release-set.js`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/extensions/dbcode-wrapper-release-status/approved-release-set.js)
- Signed source and artifact facts: [`script/generate_manifest.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/generate_manifest.sh)
- Final exact-release evidence: [`script/verify_fast_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/verify_fast_release.sh)
- Guarded rollback: [`prepare_release_rollback.sh`](https://github.com/alexwck/dbcode-wrapper/blob/03b41f3106f00d64fffa5307ddd2084981972818/script/prepare_release_rollback.sh), [`verify_release_rollback.sh`](https://github.com/alexwck/dbcode-wrapper/blob/03b41f3106f00d64fffa5307ddd2084981972818/script/verify_release_rollback.sh), and [`preview_release_rollback.sh`](https://github.com/alexwck/dbcode-wrapper/blob/03b41f3106f00d64fffa5307ddd2084981972818/script/preview_release_rollback.sh)

## Related

- [Approved Release Set module](../modules/approved-release-set.md)
- [Release Source Snapshot](../modules/release-source-snapshot.md)
- [Compiled Host Cache](../modules/compiled-host-cache.md)
- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)