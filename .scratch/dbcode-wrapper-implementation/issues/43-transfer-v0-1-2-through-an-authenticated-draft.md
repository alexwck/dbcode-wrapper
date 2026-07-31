# 43 — Transfer v0.1.2 through an authenticated draft

**What to build:** Put the five verified `v0.1.2` host-only assets in an unpublished authenticated GitHub draft for use on Macs owned by the licence holder. Prove exact upload integrity, owner access, anonymous denial, and the absence of publication automation. Do not publish or install the application.

**Blocked by:** 42

**Type:** task

**Status:** resolved

- [x] The remote annotated `v0.1.2` tag peels to accepted source `2c02a1600a748974e8ca5920567f15ca1e32c774`.
- [x] Exact-ref public readiness and the local DMG checksum pass before upload.
- [x] The GitHub release is `draft: true`, is not a prerelease, and has no publication timestamp.
- [x] Exactly five expected host-only assets are uploaded.
- [x] GitHub's stored sizes and SHA-256 digests match every local asset.
- [x] An authenticated owner download is byte-for-byte identical to the local transfer set.
- [x] Anonymous release listing omits `v0.1.2`, anonymous tag lookup returns 404, and an anonymous direct DMG request returns 404.
- [x] The repository has no GitHub Actions workflow that can publish the draft.
- [x] The draft is not published, and the app and production profile are unchanged.

## Comments

- 2026-07-29: The user requested the `v0.1.2` draft after its public source and annotated tag were pushed. Preflight found a clean synchronized `main`, no existing `v0.1.2` release, no Actions workflows, exactly five local assets, a valid DMG checksum, and a passing exact-ref public-source gate.
- 2026-07-29: The authenticated release record reports `draft: true`, `prerelease: false`, `published_at: null`, and five uploaded assets. The 187,938,101-byte DMG has SHA-256 `6b303a603866d648c643ac1f4aa502f766646c26ffc4bd355025ef0c0a9fc0b4`. GitHub's sizes and SHA-256 values matched all five local files.
- 2026-07-29: An authenticated owner download matched the complete local directory byte-for-byte. A clean anonymous API listing contained zero `v0.1.2` releases, anonymous lookup by tag returned 404, and the direct draft DMG request returned 404. The private draft URL and asset URLs are deliberately not recorded in Git.
- 2026-08-01: The owner later approved public historical access to `v0.1.2`. The remote compatibility manifest, install notes, and verification receipt were removed before publication because they describe the former owner-only transfer; their exact protected local copies remain retained. The normal release contains only the 187,938,101-byte DMG with SHA-256 `6b303a603866d648c643ac1f4aa502f766646c26ffc4bd355025ef0c0a9fc0b4` and its 151-byte checksum. A fresh anonymous download passed, and `make_latest: false` kept `v0.1.6` as the latest release.

## Answer

The original authenticated `v0.1.2` transfer is now superseded by a [public historical release](https://github.com/alexwck/dbcode-wrapper/releases/tag/v0.1.2). The public release contains only the verified DMG and checksum. The compatibility manifest, install and rollback notes, and independent verification receipt remain protected local evidence because they describe the former private-transfer channel. DBCode, profiles, licences, credentials, databases, Keychain material, and signing secrets are not included.

The public download is byte-for-byte identical to the accepted local DMG and checksum. Publishing changed only GitHub release visibility and remote asset selection; no application or profile was installed or changed. `v0.1.6` remains the repository's latest release.
