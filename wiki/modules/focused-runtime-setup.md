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
source_commit: 764d76e94cc08ff43fd82c9b922b6d738a49bee7
---
## Summary

Focused Runtime Setup installs DBCode and the pinned Python and Jupyter packages into the external Standalone DBCode Profile. Packages are not opportunistic marketplace installs: every identity, URL, size, digest, signature, and public-key binding comes from the Release Specification. Finder first-run setup and the release script use one shared verifier, so they cannot drift into different security policies.

## Responsibilities

- Validate the generated runtime-extension configuration exactly and select one canonical package record.
- Require official Open VSX API, download, signature, checksum, and public-key URLs.
- Download within size, redirect, and timeout limits during normal setup.
- Route both acquisition paths through one verifier for safe public-key path resolution, registry metadata, Code OSS engine compatibility, package size, digests, approved keys, Ed25519 signatures, signature manifests, safe ZIP entries, and VSIX identity.
- Validate installed extension identities and compare them with the exact pinned set.
- Cache only verified packages in a safe owned directory.
- Install missing packages externally with extension-pack dependency installation disabled.
- Report clear setup progress without copying packages into the app bundle.

## Public API / entry points

`openVsxPackageVerifier.js` owns configuration shape, canonical package selection, installed identity, safe public-key path resolution, deep package checks, and safe errors. `runtimeSetup.js` owns Finder first-run acquisition, private caching, and inventory. `runtimeSetupController.js` connects that adapter to Code OSS extension management and the setup view. `verify_openvsx_package.cjs` is the release-side file adapter. Neither acquisition adapter copies the package field list or a security rule.

## Key files

- [`openVsxPackageVerifier.js`](https://github.com/alexwck/dbcode-wrapper/blob/764d76e94cc08ff43fd82c9b922b6d738a49bee7/host/extensions/dbcode-wrapper-profile-migration/openVsxPackageVerifier.js) — shared security-critical verification.
- [`runtimeSetup.js`](https://github.com/alexwck/dbcode-wrapper/blob/764d76e94cc08ff43fd82c9b922b6d738a49bee7/host/extensions/dbcode-wrapper-profile-migration/runtimeSetup.js) — Finder first-run acquisition and inventory adapter.
- [`runtimeSetupController.js`](https://github.com/alexwck/dbcode-wrapper/blob/b40ed3f8f193a0397fd15d298c68f640abc2afde/host/extensions/dbcode-wrapper-profile-migration/runtimeSetupController.js) — installation orchestration.
- [`verify_openvsx_package.cjs`](https://github.com/alexwck/dbcode-wrapper/blob/764d76e94cc08ff43fd82c9b922b6d738a49bee7/script/verify_openvsx_package.cjs) — release-side file adapter.
- [`host/release-lock.json`](https://github.com/alexwck/dbcode-wrapper/blob/b40ed3f8f193a0397fd15d298c68f640abc2afde/host/release-lock.json) — exact DBCode and notebook package records.

## Dependencies

The module depends on Node crypto and HTTPS, Code OSS extension management, approved Open VSX keys, [Release Specification](release-specification.md), and [Profile Layout and Setup](profile-layout-and-setup.md). The default development gate runs a fast synthetic adversarial matrix through both adapters. The real cached-package gate runs only when verification changes. Rendered deployment checks reuse the generated QA profile; these checks do not request kernel permission or human input.

## Participates in

- [First run, activation, and query](../flows/first-run-activate-and-query.md)
- [Approval and guarded rollback](../flows/approval-and-guarded-rollback.md)

## Related

- [Unmodified Extension Boundary](../concepts/unmodified-extension-boundary.md)
- [Standalone DBCode Profile](../concepts/standalone-dbcode-profile.md)
- [Release trust and compatibility](../architecture/release-trust-and-compatibility.md)