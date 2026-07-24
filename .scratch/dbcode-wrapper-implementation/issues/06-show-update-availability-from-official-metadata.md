# 06 — Show update availability from official metadata

**What to build:** Let the user see when a new host or DBCode release exists and whether that exact candidate has been tested, without allowing discovery to become a silent or assumed upgrade.

**Blocked by:** 05 — Keep advanced DBCode features reachable without exposing an IDE

**Type:** task

**Status:** resolved

- [x] The installed release candidate or Approved Release Set is represented by a manifest containing the exact host source and patch revisions, runtime versions, DBCode identity and digest, profile schema, architecture, entitlements, signature identity, packaging result, and compatibility status.
- [x] Metadata checks use only the official VSCodium GitHub release feed and official Open VSX DBCode record, are cached to roughly once per day, and send no database, connection, credential, path, licence, or profile data.
- [x] Host and DBCode releases are displayed separately with installed and available versions, publication dates, official release notes, and clear **Not tested** or **Ready to install** states.
- [x] The Upgrade Prompt provides Review, Remind Later, and Skip This Version actions and deduplicates notices across launches.
- [x] Discovery never silently downloads, installs, quits, restarts, relaunches, or marks a release compatible.
- [x] A new upstream VSCodium release is treated as input for a new custom-host build and can never replace the focused shell with stock VSCodium.
- [x] Automated state tests cover no update, host-only update, DBCode-only update, both updates, skipped version, reminder, offline registry, invalid metadata, and tested-candidate transitions.

## Comments

- 21 July 2026: Added a focused release-status bridge and native shell entry point. The toolbar reports the current pair at a glance, while **Check for Updates** and the status icon open one review list with separate Host and DBCode rows, installed and available versions, publication dates, official notes, and compatibility state.
- 21 July 2026: Official discovery uses only VSCodium's stable GitHub release record and DBCode's verified, non-prerelease, non-deprecated Open VSX record. The request carries no private profile data. Successful, offline, and invalid checks are cached for roughly one day; manual refresh bypasses the cache.
- 21 July 2026: Review, Remind Later, and Skip This Version are local decisions stored atomically in the private profile. A reminder becomes due after three days, skip applies only to the exact host-and-DBCode version pair, and a later local approval can promote the same reviewed candidate from **Not tested** to **Ready to install** without another network request.
- 21 July 2026: Approval lookup is fail-closed. The installed identity is restricted to the exact `darwin-arm64` product, official release metadata, complete source commits and digests, and a full SHA-256 source identity. A ready candidate must use known schema 5, match the target and versions, contain complete proof and approval digests, and bind its canonical source identity to the full signed artifact digest.
- 21 July 2026: The rebuilt signed app remains a `candidate`; this ticket reads complete approval records but never writes one. Issue 07 owns the four-way compatibility gate, promotion, installation, and rollback of exact release sets.
- 21 July 2026: The final artifact is 462,060 KiB installed and 166,471,309 bytes in the indicative archive, with 8 built-ins and no source maps. Its SHA-256 is `f5f90a88156fdc80c841df36701856d677bbce7049154271aa73fa8035eb0913`.
- 21 July 2026: The patched Code OSS tree typechecked with zero errors. Static identity/signature smoke, all development contracts, 25 update-state tests, 5 clean-shutdown log-policy tests, and the complete isolated rendered suite passed. Rendered QA showed `Host 1.126.04524, DBCode 1.36.2: current`, separate dated release rows, and no regression in Connections, SQL queries, result grids, DBCode tools, or Python notebooks.
- 23 July 2026: Issue 23 deepens this resolved two-feed foundation after live acceptance proved that it could not see a newer Microsoft Code OSS release. The new contract keeps Code OSS runtime, VSCodium packaging, and DBCode discovery separate while preserving the same read-only approval boundary.

## Answer

DBCode Wrapper's update bridge now checks three official stable records after issue 23 deepened the original two-feed implementation: Microsoft Code OSS, VSCodium packaging, and verified DBCode on Open VSX. It presents each role separately, tells the user whether one exact three-version release set is **Not tested** or **Ready to install**, links only to official release notes, and supports Review, Remind Later, Skip This Version, and manual refresh without exposing the extension marketplace or a generic IDE updater.

Discovery is informational and safe: it never downloads or installs an update, closes or restarts the app, or creates a compatibility approval. A new Code OSS or VSCodium release always means a new focused DBCode Wrapper build. A candidate becomes **Ready to install** only when issue 07 has recorded a complete local approval for that exact source, signed artifact, target, Code OSS version, VSCodium packaging version, DBCode version, and profile schema.
