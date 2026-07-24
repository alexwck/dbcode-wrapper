# 23 — Discover Code OSS updates independently

**What to build:** Make update discovery track the Code OSS runtime independently from the VSCodium packaging layer and unchanged DBCode extension, so a newly published runtime such as Code OSS `1.130.0` is visible immediately without being mistaken for an approved or installable release.

**Blocked by:** 06, 17, 18

**Type:** task

**Status:** resolved

- [x] The manual and daily read-only checks use the official stable GitHub release records for Code OSS and VSCodium plus the verified stable Open VSX record for DBCode.
- [x] The review surface distinguishes Code OSS runtime availability, VSCodium packaging availability, and DBCode availability with installed and available versions, publication dates, official release notes, and honest readiness states.
- [x] A newer Code OSS release is reported as **Not tested** even when VSCodium and DBCode have no newer release.
- [x] Candidate identity and local approval lookup include the exact Code OSS, VSCodium, and DBCode versions; version availability alone never makes any component ready to install.
- [x] Discovery remains read-only and never downloads, installs, quits, restarts, relaunches, promotes, or changes the active Approved Release Set.
- [x] Stored metadata from the older two-feed contract is safely rejected or migrated before it can hide an independently published Code OSS release.
- [x] Source tests cover Code OSS-only, VSCodium-only, DBCode-only, combined, cached, offline, invalid, skipped, reminded, and approved-candidate states through the release-status service boundary.
- [x] The rebuilt application visibly reports the current official Code OSS release and ticket 08 receives a fresh real-profile update-discovery result.

## Comments

- 23 July 2026: Ticket 08's forced check completed successfully at `2026-07-23T01:36:48Z` and reported VSCodium `1.126.04524` plus DBCode `1.36.2`. Microsoft had already published Code OSS `1.130.0` at `2026-07-22T17:39:17Z`, but the two-feed checker never requested that official record. The network path passed; complete maintained-host discovery failed.
- 23 July 2026: The approved behavior is informational and fail-closed. Code OSS `1.130.0` must become visible as **Not tested**, while installation remains unavailable until one exact Code OSS, VSCodium packaging, DBCode, profile, signed artifact, proof, restart-health, and rollback set has passed the controlled compatibility gate.
- 23 July 2026: The source implementation now uses independent `vscodium`, `codeOss`, and `dbcode` state plus one named three-version release tuple for candidate and approval matching. It rejects the older two-feed cache, records official Code OSS publication metadata in the installed identity, and keeps every discovery route read-only. The new candidate source ID is `code-oss-1.126.0-dbcode-1.36.2-source-6f4bbe57b5aec833717adabec5a2b594ce50dff46448f954adf08f05ced7544f`.
- 23 July 2026: All 33 focused update-service tests and the complete development source suite pass. Independent standards and spec reviews found no remaining source issue. The ticket stays claimed because a clean signed rebuild, rendered review, and fresh real-profile update observation are still required.
- 24 July 2026: The signed application visibly reported Code OSS `1.130.0` as **Not tested**, kept VSCodium `1.126.04524` and DBCode `1.36.2` separate, and did not install anything. The user confirmed update discovery and the complete real-profile acceptance checklist passed, then fully quit the app.

## Answer

DBCode Wrapper now discovers Code OSS, VSCodium packaging, and DBCode independently through their official public records. The accepted signed application showed the current Code OSS release without treating it as approved or installable, and the fresh real-profile acceptance passed.
