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
source_commit: f1cc5e1bbc50281cd6b86a307054982619ce5f00
---
## Summary

Focused Runtime Setup installs DBCode and the pinned Python and Jupyter packages into the external Standalone DBCode Profile. Packages are not opportunistic marketplace installs: every identity, URL, size, digest, signature, and public-key binding comes from the Release Specification. The Runtime Extension Set projects that purpose record once. Because it generates settings packaged in the signed app, it is part of wrapper source identity. Every setup and release path checks the result through the same verifier.

## Responsibilities

- Project the Release Specification package record once, validate the generated runtime-extension configuration exactly, and select one canonical package record.
- Require official Open VSX API, download, signature, checksum, and public-key URLs.
- Download within size, redirect, and timeout limits during normal setup.
- Route both acquisition paths through one verifier for safe public-key path resolution, registry metadata, Code OSS engine compatibility, package size, digests, approved keys, Ed25519 signatures, signature manifests, safe ZIP entries, and VSIX identity.
- Validate installed extension identities and compare them with the exact pinned set.
- Cache only verified packages in a safe owned directory.
- Install missing packages externally with extension-pack dependency installation disabled.
- Report clear setup progress without copying packages into the app bundle.

## Public API / entry points

`openVsxPackageVerifier.js` owns the runtime record projection, configuration shape, canonical package selection, installed identity, safe public-key path resolution, deep package checks, and safe errors. `runtime_extension_set.cjs` writes or checks the exact public record from purpose-level Release Specification input. `runtimeSetup.js` exposes setup validation, installed-inventory checks, and one acquire-and-verify operation; download and verification helpers stay private. `runtimeSetupController.js` connects that interface to Code OSS extension management and the setup view. `verify_openvsx_package.cjs` is the package-file command adapter. The shell generator and release checks call these maintained interfaces instead of copying package fields or security rules.

## Key files

- [`openVsxPackageVerifier.js`](https://github.com/alexwck/dbcode-wrapper/blob/b3773b5ad1f3f3b0bcd3d7dce39f614bf082ce11/host/extensions/dbcode-wrapper-profile-migration/openVsxPackageVerifier.js) — runtime record projection and shared security verification.
- [`runtime_extension_set.cjs`](https://github.com/alexwck/dbcode-wrapper/blob/b3773b5ad1f3f3b0bcd3d7dce39f614bf082ce11/script/runtime_extension_set.cjs) — exact record writer and checker.
- [`runtimeSetup.js`](https://github.com/alexwck/dbcode-wrapper/blob/b3773b5ad1f3f3b0bcd3d7dce39f614bf082ce11/host/extensions/dbcode-wrapper-profile-migration/runtimeSetup.js) — Finder first-run acquisition and inventory adapter.
- [`runtimeSetupController.js`](https://github.com/alexwck/dbcode-wrapper/blob/b3773b5ad1f3f3b0bcd3d7dce39f614bf082ce11/host/extensions/dbcode-wrapper-profile-migration/runtimeSetupController.js) — installation orchestration.
- [`verify_openvsx_package.cjs`](https://github.com/alexwck/dbcode-wrapper/blob/b3773b5ad1f3f3b0bcd3d7dce39f614bf082ce11/script/verify_openvsx_package.cjs) — package-file adapter.
- [`host/release-lock.json`](https://github.com/alexwck/dbcode-wrapper/blob/b40ed3f8f193a0397fd15d298c68f640abc2afde/host/release-lock.json) — exact DBCode and notebook package records.

## Dependencies

The module depends on Node crypto and HTTPS, Code OSS extension management, approved Open VSX keys, [Release Specification](release-specification.md), and [Profile Layout and Setup](profile-layout-and-setup.md). The default development gate runs a fast synthetic adversarial matrix through the maintained verifier and production acquisition interface. The real cached-package command-adapter gate runs only when verification changes. Rendered deployment checks reuse the generated QA profile; these checks do not request kernel permission or human input.

## Participates in

- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)

## Related

- [Unmodified Extension Boundary](../concepts/unmodified-extension-boundary.md)
- [Standalone DBCode Profile](../concepts/standalone-dbcode-profile.md)
- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)