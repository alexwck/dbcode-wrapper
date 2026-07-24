# Public repository and release boundary

Research date: 22 July 2026

This is project guidance based on the current published terms, not legal advice.

## Decision

The wrapper source can be published in a public GitHub repository after a public-history and licence cleanup. Publishing the repository does **not** require publishing the DMG.

A public host-only DMG is technically possible, but it is public distribution: anyone can download it. It must contain no DBCode package or extracted DBCode content, no licence or activation material, no profile or credential data, and no signing private key. Each device must obtain the unchanged DBCode extension separately from its official Open VSX source and activate it normally.

The current host-only architecture substantially reduces the DBCode licence risk, but it does not remove two uncertainties:

1. DBCode's agreement does not expressly discuss a third-party wrapper distributed to the public.
2. The software licence does not grant an express right to use DBCode branding. A public project named `DBCode Wrapper` needs a prominent unofficial-project disclaimer and a distinct icon, and must not use DBCode's logo or website graphics.

For the user's current goal, the recommended order is:

1. Publish a cleaned, source-only public repository.
2. Keep published release assets empty while the public-content and binary-content gates are implemented.
3. If an owned Mac must receive the DMG before then, use an authenticated **draft** release as a temporary transfer, keep it as a draft, and prove anonymous access fails.
4. Publish a DMG later only after it passes the host-only inspection below. If the intent remains installation only on personally owned Macs, a private asset channel remains the lower-risk durable choice even when the source repository is public.

## Why the source and DMG are different

GitHub says a public repository is visible to everyone, anyone can fork it, and Actions history and logs are public. GitHub Releases are visible to everyone with read access; a public resource's release asset can be downloaded without authentication. A published release in a public repository is therefore not a private personal transfer. GitHub allows up to 1,000 assets per release, with each asset below 2 GiB.

- [GitHub: repository visibility and its consequences](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility)
- [GitHub: about releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
- [GitHub: release assets API](https://docs.github.com/en/rest/releases/assets)

### Draft releases in a public repository

GitHub's official API documentation says published releases are available to everyone, while **only users with push access receive listings for draft releases**. GitHub's repository-role table likewise reserves viewing draft releases to write, maintain, and admin roles. A draft DMG in a public source repository is therefore access-controlled rather than publicly listed, provided it is never published.

- [GitHub: REST API endpoints for releases](https://docs.github.com/en/rest/releases/releases)
- [GitHub: repository roles and draft-release access](https://docs.github.com/en/organizations/managing-user-access-to-your-organizations-repositories/managing-repository-roles/repository-roles-for-an-organization)

For this project, a draft release is acceptable as a temporary personal transfer if all of these are true:

- The other owned Mac signs in as the repository owner or another account with push access.
- The release remains `draft: true`; a pre-release is **not** private once published.
- An unauthenticated request cannot list the release or download its asset, and an authenticated owner download succeeds.
- The DMG passes the same host-only, secret, licence, and checksum gates required for any other upload.
- No automation is allowed to turn the draft into a published release.

A draft is not the preferred long-term release channel. GitHub presents it as a staging state before publication, and the release form makes publication a direct action. One accidental `Publish release` makes the asset public. A separate private repository or other authenticated private storage has the clearer durable access model. If a draft is used, call it an **authenticated draft transfer**, not a published Private Personal Release.

## DBCode boundary

DBCode grants the licensee a non-exclusive, non-transferable right to download, install, and use the extension on unlimited devices. A lifetime licence includes future released versions. The same agreement forbids modifying, adapting, reverse engineering, decompiling, or disassembling the proprietary extension, and forbids distributing, sublicensing, or transferring it to third parties without prior written consent.

This gives the project a clear rule:

- Public wrapper source may identify `dbcode.dbcode`, use DBCode's documented extension API, and describe compatibility.
- The repository, Git history, source archives, DMG, and release attachments must not contain a DBCode VSIX, installed extension directory, extracted source or UI files, copied webview assets, or a patched DBCode package.
- The build must not download DBCode during DMG creation and then embed it. Installation must happen outside the app bundle on each device from the official Open VSX publication.
- Normal licence enforcement remains DBCode's responsibility. The wrapper must not copy activation state or make a pre-activated profile.

DBCode documents a supported API through `@dbcode/vscode-api` and the `dbcode.dbcode` extension identifier. It also says every VSCodium release is published to Open VSX and recommends normal gallery installation. These are safer public integration points than copied package internals.

- [DBCode License Agreement](https://dbcode.io/legal/license-agreement)
- [DBCode VS Code Extension API](https://dbcode.io/docs/api/vscode-extension)
- [DBCode installation in VSCodium](https://dbcode.io/vscodium)

Licence and credential material must stay device-local. DBCode's offline process creates a machine key and installs a machine-bound licence on that machine. DBCode also documents macOS Keychain as the secure store for passwords, client secrets, and tokens, while settings JSON is for non-sensitive configuration.

- [DBCode offline licence activation](https://dbcode.io/docs/accounts/offline-license)
- [DBCode authentication-profile storage](https://dbcode.io/docs/authentication-profiles)
- [DBCode password storage](https://dbcode.io/docs/security/password-storage)

DBCode's website terms reserve its site text, graphics, logos, and images and allow site content only for personal, non-commercial use. Do not copy its logo, website screenshots, or marketing graphics into the public repository or DMG. Use an original icon and a plain disclaimer such as:

> Unofficial wrapper compatible with the DBCode extension. Not affiliated with or endorsed by Recut LLC. DBCode is installed separately from its official distribution and is governed by its own licence.

- [DBCode Terms and Conditions](https://dbcode.io/legal/terms-and-conditions)

## Code OSS and VSCodium boundary

Code OSS is MIT-licensed. Its licence allows use, modification, publication, and distribution, provided the Microsoft copyright and MIT permission notice remain in copies or substantial portions. Microsoft distinguishes Code OSS from the separately licensed Visual Studio Code product, and identifies the Visual Studio Code product name and icons as trademarked distribution assets. The wrapper's distinct product name, bundle identifier, and original icon are therefore important.

- [Code OSS MIT licence](https://github.com/microsoft/vscode/blob/main/LICENSE.txt)
- [Microsoft: Code OSS compared with the Visual Studio Code product](https://github.com/microsoft/vscode/wiki/Differences-between-the-repository-and-Visual-Studio-Code)
- [Code OSS third-party notices](https://github.com/microsoft/vscode/blob/main/ThirdPartyNotices.txt)

VSCodium's build scripts and binaries are also MIT-licensed. VSCodium explicitly describes its downstream build path and says its binaries are MIT-licensed. Preserve the VSCodium copyright and MIT notice for copied or modified build material.

- [VSCodium project and distribution explanation](https://github.com/VSCodium/vscodium)
- [VSCodium MIT licence](https://github.com/VSCodium/vscodium/blob/master/LICENSE)
- [VSCodium downstream build documentation](https://github.com/VSCodium/vscodium/blob/master/docs/howto-build.md)

The owner selected an All Rights Reserved root `LICENSE` for this repository's original wrapper code and documentation. Code OSS and VSCodium MIT notices remain separate for upstream-derived material. The root restriction must not be presented as replacing or relicensing content the project does not own.

- [GitHub: licensing a repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)

The current app bundle already retains Code OSS's `LICENSE.txt`, `ThirdPartyNotices.txt`, Chromium licences, and dependency licences. The public DMG gate should assert that those files remain present after slimming and packaging.

## Current repository findings

The following findings come from a read-only scan of the current tree and all reachable local Git history at commit `6088e5d`:

- No DBCode VSIX, app bundle, DMG, signing private key file, or recognisable private-key marker was found in reachable history.
- Runtime profiles, build output, `dist/`, environment files, logs, and proof profiles are ignored by `.gitignore`.
- `host/keys/openvsx-14ccb407-4e79-41ed-be5a-6d608325c45a.pem` is a pinned **public** Open VSX verification key, not a signing private key.
- The repository now has an explicit All Rights Reserved root `LICENSE` and a separate upstream-notice file.
- The tree at the start of this audit contained two exact snapshots copied from DBCode's package manifest. They have now been replaced in the working tree by a canonical digest plus an independently authored compatibility policy. The old snapshots remain reachable in local Git history until the approved public-history preparation is performed.
- Reachable deleted history contains a DBCode website comparison screenshot, a Beekeeper Studio screenshot, and a copied Codicon font. A normal push of the current branch would publish those old blobs even though they are no longer in the working tree. The DBCode screenshot conflicts with the conservative site-content boundary above; the other third-party files also need their own permission and attribution review.
- A current tracked-file scan originally found one personal absolute path in a research note; that working-tree reference has been sanitized. The old path remains part of the current private history, so the exact public history must still exclude it. Public-history preparation should also remove email addresses, screenshots, internal notes, and machine-specific observations that the owner does not want indexed permanently.

The safest first public push is a reviewed clean-history mirror or a deliberately squashed initial public commit, rather than pushing the full private development history. If the existing history is retained, remove proprietary and private material with a history rewrite before publication. GitHub warns that sensitive history remains a problem until it is removed and that exposed secrets must first be revoked or rotated.

- [GitHub: removing sensitive data from repository history](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
- [GitHub: push protection](https://docs.github.com/en/code-security/concepts/secret-security/push-protection)

## Required gates before a public source push

- [x] Decide and add the outbound licence for original wrapper code.
- [ ] Add Code OSS and VSCodium MIT notices and preserve all binary third-party notices.
- [x] Replace the exact DBCode contribution snapshots in the current tree with a digest and independently authored policy.
- [ ] Remove the old DBCode contribution snapshots from the history that will be pushed publicly.
- [ ] Remove or separately justify all third-party screenshots, fonts, logos, and site content from public history.
- [x] Add an exact-ref gate that scans complete reachable history for forbidden files, private-key and common live-token patterns, personal paths, and unapproved author or committer emails. Do not treat `.gitignore` as a history scrubber.
- [x] Add the unofficial-project and separate-DBCode-install disclaimer to the public README.
- [ ] Enable GitHub secret scanning and push protection; never bypass a real finding.
- [ ] Review any Actions workflow and logs as public data before enabling it.

## Additional gates before a public DMG

- [ ] Build the DMG only from the cleaned public source and approved Code OSS/VSCodium inputs.
- [ ] Fail packaging if the app or mounted DMG contains `dbcode.dbcode`, a `.vsix`, an external extensions cache, DBCode global storage, a user profile, Keychain export, activation material, licence data, connection data, database files, or a private key.
- [ ] Prove DBCode is downloaded separately on the installed Mac from the locked official Open VSX URL and installed outside the app bundle.
- [ ] Retain Code OSS, VSCodium, Electron/Chromium, and dependency licence notices in the final app.
- [ ] Publish SHA-256 and compatibility metadata that contain no local paths, account identifiers, profile data, or secrets.
- [ ] State clearly that the app is unofficial, self-signed, not notarized by Apple, and does not include DBCode.
- [ ] Verify the asset is below GitHub's 2 GiB per-file limit and understand that anyone can download it.

## Remaining uncertainty

The published DBCode agreement clearly prohibits distributing the extension, but it neither expressly permits nor prohibits distributing a separate host that obtains DBCode later. The host-only approach is therefore materially safer, not a vendor endorsement or a legal guarantee. The use of the DBCode name in a publicly distributed application is also not expressly licensed. If this uncertainty becomes unacceptable, use a neutral wrapper name or ask `legal@dbcode.io` specifically about public host-only distribution and naming.
