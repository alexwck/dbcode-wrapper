---
title: Focused Runtime Setup
description: The verified installer for DBCode and the pinned Python notebook extension set in the external profile.
type: module
tags:
  - wiki
  - module
  - runtime
  - open-vsx
wiki_profile: public
wiki_depth: standard
source_commit: 2008ff48373c1aac378d0d1ec903e96a88ec1e29
---
## Summary

Focused Runtime Setup installs DBCode and the pinned Python and Jupyter packages into the external Standalone DBCode Profile. Packages are not opportunistic marketplace installs: every identity, URL, size, digest, signature, and public-key binding comes from the Release Specification.

## Responsibilities

- Validate the generated runtime-extension configuration exactly.
- Require official Open VSX API, download, signature, checksum, and public-key URLs.
- Download within size, redirect, and timeout limits during normal setup.
- Verify registry metadata, archive identity, SHA-256, signature, and approved public key.
- Compare installed extensions with the exact pinned set.
- Cache only verified packages in a safe owned directory.
- Install missing packages externally with extension-pack dependency installation disabled.
- Report clear setup progress without copying packages into the app bundle.

## Public API / entry points

`runtimeSetup.js` owns configuration, acquisition, verification, and inventory logic. `runtimeSetupController.js` connects those checks to Code OSS extension management and the setup view.

## Key files

- [`runtimeSetup.js`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/extensions/dbcode-wrapper-profile-migration/runtimeSetup.js) — pure validation and acquisition logic.
- [`runtimeSetupController.js`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/extensions/dbcode-wrapper-profile-migration/runtimeSetupController.js) — installation orchestration.
- [`host/release-lock.json`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/host/release-lock.json) — exact DBCode and notebook package records.
- [`script/verify_openvsx_package.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/verify_openvsx_package.sh) — release-side package verification.

## Dependencies

The module depends on Node crypto and HTTPS, Code OSS extension management, approved Open VSX keys, [Release Specification](release-specification.md), and [Profile Layout and Setup](profile-layout-and-setup.md). Default development and rendered deployment checks use local contracts and an existing QA profile; they do not download packages or request kernel permission.

## Participates in

- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)

## Related

- [Unmodified Extension Boundary](../concepts/unmodified-extension-boundary.md)
- [Standalone DBCode Profile](../concepts/standalone-dbcode-profile.md)
- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)