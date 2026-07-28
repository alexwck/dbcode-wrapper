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

## Answer

The exact `v0.1.2` host-only package is available to the authenticated repository owner through an unpublished GitHub draft. The draft contains exactly the DMG, checksum, compatibility manifest, install and rollback notes, and independent verification receipt. DBCode, profiles, licences, credentials, databases, Keychain material, and signing secrets are not included.

The upload is byte-for-byte identical to the accepted local package. Anonymous access failed through listing, tag lookup, and direct asset lookup. The draft remains unpublished, and no application or profile was installed or changed.
