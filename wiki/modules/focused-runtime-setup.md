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
source_commit: efe247fc701a9b529e3e6368b6571a44541fc146
---
## Summary

Focused Runtime Setup installs the external extension set required by the product: DBCode plus the pinned Python and Jupyter packages. The packages stay outside the app bundle in the Standalone DBCode Profile. They are not opportunistic marketplace installs; every package, URL, digest, signature, and public key binding comes from the approved release specification.

## Responsibilities

- Validate the generated runtime-extension configuration exactly.
- Require the expected Open VSX API, download, signature, and checksum URLs.
- Download within size and redirect limits.
- Verify the registry record, archive identity, SHA-256 value, Open VSX signature, and approved public key.
- Compare the installed extension inventory with the required pinned set.
- Cache only verified packages in a safe owned directory.
- Install missing packages into the external extension root and report first-run progress.

## Public API / entry points

`runtimeSetup.js` exposes configuration validation, package acquisition and verification, installed-version mapping, missing-package calculation, and the managed-runtime assertion. `runtimeSetupController.js` connects those operations to Code OSS extension management and the setup view.

## Key files

- [`runtimeSetup.js`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/extensions/dbcode-wrapper-profile-migration/runtimeSetup.js) — pure validation and acquisition logic.
- [`runtimeSetupController.js`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/extensions/dbcode-wrapper-profile-migration/runtimeSetupController.js) — installation orchestration.
- [`host/release-lock.json`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/host/release-lock.json) — pinned DBCode and notebook package records.
- [`script/verify_openvsx_package.sh`](https://github.com/alexwck/dbcode-wrapper/blob/efe247fc701a9b529e3e6368b6571a44541fc146/script/verify_openvsx_package.sh) — release-side verification path.

## Dependencies

The module depends on Node crypto and HTTPS, Code OSS extension-management commands, the approved Open VSX public key, and [Profile Layout and Setup](profile-layout-and-setup.md). Kernel access is still a user-granted trust decision; the wrapper does not silently bypass the host permission prompt.

## Participates in

- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Controlled upgrade and rollback](../flows/controlled-upgrade-and-rollback.md)

## Related

- [Unmodified Extension Boundary](../concepts/unmodified-extension-boundary.md)
- [Standalone DBCode Profile](../concepts/standalone-dbcode-profile.md)
- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)
