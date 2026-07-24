---
title: Approved Release Set
description: The complete versioned and evidenced compatibility unit that may be installed or restored.
type: concept
tags:
  - wiki
  - concept
  - release
  - compatibility
wiki_profile: public
wiki_depth: standard
source_commit: efe247fc701a9b529e3e6368b6571a44541fc146
---
## Definition

An Approved Release Set is one exact combination of DBCode Wrapper host, Code OSS version, VSCodium source, DBCode extension, pinned notebook packages, profile schema, wrapper extensions, signing identity, and acceptance evidence. It is the unit the project can promote, report as current, package, or restore.

A candidate becomes approved only after its declared files and digests match the evidence and an approval record is written. Seeing a newer version in update discovery does not make it approved.

## Why it matters

DBCode can work on one Code OSS version and fail subtly on another. A notebook package can install but lose its kernel bridge. A rebuilt app can look identical but trigger a new Keychain identity. Treating all of these as a set prevents independent version changes from bypassing compatibility checks.

The set also gives rollback a complete target. Restoring only the app while keeping a newer profile or extension directory would produce an untested combination.

## Where it lives

- Canonical release facts: [`host/release-lock.json`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/release-lock.json)
- Validation and record creation: [`approved-release-set.js`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/extensions/dbcode-wrapper-release-status/approved-release-set.js)
- Public approved history: [`host/approved-release-history.json`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/approved-release-history.json)
- Prepare, promote, health, and rollback: [`script/controlled_upgrade.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/controlled_upgrade.sh)

## Related

- [Approved Release Set module](../modules/approved-release-set.md)
- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
- [Controlled upgrade and rollback](../flows/controlled-upgrade-and-rollback.md)
