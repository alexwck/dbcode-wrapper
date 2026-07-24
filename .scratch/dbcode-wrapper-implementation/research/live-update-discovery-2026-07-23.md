# Live update-discovery check

Research date: 23 July 2026

Live metadata checked at `2026-07-23T01:44:27Z`.

## Answer

The pre-ticket-23 `Check for Updates…` implementation worked against its two configured feeds, but its host check was **not complete enough for the project's separate-update goal**.

The wrapper is built from VSCodium `1.126.04524`, whose Code OSS input is `1.126.0`, and DBCode `1.36.2`. Microsoft's official Code OSS repository now reports stable `1.130.0`, published `2026-07-22T17:39:17Z`. However, the official VSCodium latest-release API still reports stable tag `1.126.04524`, published `2026-07-07T13:01:09Z`. The official VSCodium release list and tag list contain no `1.130` build. The official Open VSX record reports verified stable DBCode `1.36.2`, published `2026-07-20T04:51:39.562360Z`.

- [Official Code OSS latest-release API](https://api.github.com/repos/microsoft/vscode/releases/latest)
- [Code OSS 1.130.0 release](https://github.com/microsoft/vscode/releases/tag/1.130.0)
- [Official VSCodium latest-release API](https://api.github.com/repos/VSCodium/vscodium/releases/latest)
- [Official VSCodium release list](https://api.github.com/repos/VSCodium/vscodium/releases?per_page=10)
- [Official VSCodium tag list](https://api.github.com/repos/VSCodium/vscodium/tags?per_page=20)
- [VSCodium 1.126.04524 release](https://github.com/VSCodium/vscodium/releases/tag/1.126.04524)
- [Official DBCode Open VSX record](https://open-vsx.org/api/dbcode/dbcode)
- [DBCode 1.36.2 Open VSX record](https://open-vsx.org/api/dbcode/dbcode/1.36.2)

The reported `1.130.0` version is real, but it is an upstream Code OSS release rather than a currently published VSCodium package. The wrapper must not treat it as ready to install: its host patches and DBCode pairing have not been built or tested against it. It should nevertheless make this upstream gap visible instead of calling every host layer current.

The implementation examined during this research fetched only the VSCodium latest-release endpoint and the DBCode Open VSX endpoint. It never fetched Microsoft's Code OSS release endpoint. Consequently, it could not discover `1.130.0` until VSCodium published a newer package. This was a monitoring gap, not evidence that the forced network request failed.

## Expected application display

With the pre-ticket-23 code, a working manual check forced fresh requests to its two configured endpoints and opened a picker titled **DBCode Wrapper is current** with:

- `Host — 1.126.04524 (current) · Current`
- `DBCode — 1.36.2 (current) · Current`

Choosing either row should open its official release notes. The check is deliberately read-only: it never installs VSCodium, Code OSS, or DBCode. If either request cannot be completed, the application should show the offline warning instead of inventing an update.

That display accurately describes the VSCodium package and DBCode extension feeds, but it is misleading for the complete host dependency. The improved display should distinguish three states:

- `Host package — VSCodium 1.126.04524 · Current package`
- `Code OSS upstream — 1.126.0 → 1.130.0 · Available, not built or tested`
- `DBCode — 1.36.2 · Current`

There is still no approved update to install. The useful action is to notify the owner that a new host input exists and needs a new wrapper build and complete Approved Release Set verification.

For ticket 08, record the current result in two parts:

- **Pass:** the manual command completed a fresh official metadata check and correctly found no newer VSCodium package or DBCode extension.
- **Gap:** it did not report the independently published Code OSS `1.130.0` source release, so complete update discovery for the maintained host dependency is not yet proven.

Keep installation blocked until matching VSCodium packaging exists and the resulting Code OSS, wrapper patches, DBCode version, profile, signed artifact, and rollback set pass the complete compatibility gates.

This diagnosis followed the pre-ticket-23 implementation in [`release-status.js`](../../../host/extensions/dbcode-wrapper-release-status/release-status.js) and [`extension.js`](../../../host/extensions/dbcode-wrapper-release-status/extension.js). The manual command passed `force: true`, so it bypassed the normal 24-hour metadata cache. The local pin remained authoritative in [`release-lock.json`](../../../host/release-lock.json).

## Verification

The current ticket 08 run recorded a successful forced metadata refresh at `2026-07-23T01:36:48Z`. Its sanitized result was VSCodium `1.126.04524` and DBCode `1.36.2`, which matches the live official feeds above.

`./script/test_update_status_contract.sh` passed all 31 release-set and update-status checks on 23 July 2026, including matching-version, host-only update, DBCode-only update, offline, invalid-metadata, cache, and approved-pair behaviour. Those tests prove the present two-feed contract; they do not cover independent Code OSS discovery.
