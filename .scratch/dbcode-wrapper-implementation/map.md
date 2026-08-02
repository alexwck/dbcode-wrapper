# DBCode Wrapper implementation map

## Destination

Maintain a small Apple-silicon host for the official unchanged DBCode extension. The wrapper owns application identity, a focused shell, private profile handling, compatibility checks, prompt-free verification, rollback, and host-only publication. DBCode owns database, notebook, AI, MCP, account, and licence behaviour.

## Current state

- The normal release channel is a published GitHub Host Release containing only the independently verified DMG and checksum.
- The exact wrapper and upstream versions live only in `host/release-lock.json` and generated release evidence.
- Automatic Code OSS, VSCodium, and DBCode polling remains read-only. It reports updates but cannot change a pin, create a tag, approve or install a candidate, publish a release, or change a profile.
- Routine deployment uses the fast source gate, an exact Compiled Host cache, static smoke, and one persistent generated `qa` profile.
- `script/release_host.sh plan` reports release-source readiness without changing state. `prepare` rejects blocked source state before checkpoint acquisition, then owns signing readiness, exact build or reuse, static smoke, one persistent-profile rendered smoke, final acceptance, tagging, packaging, independent verification, and approval. Publication remains a separate explicit action.
- Generated output is classified by artifact purpose and explicit expiry. Historical output stays protected without making its retired process current again.
- The Public Source Repository never includes DBCode, private profiles, credentials, databases, signing secrets, built apps, raw real-profile evidence, or local release receipts.

## Maintained modules

- [Architecture overview](../../docs/architecture/overview.md) — current seams and data flow.
- [Release Specification](../../host/release-lock.json) — exact build, upstream, profile, product, and distribution input.
- [DBCode feature policy](../../host/dbcode-feature-policy.json) — supported routes and compatibility gaps.
- [Verification policy](../../docs/agents/verification-policy.md) — the smallest prompt-free gate for each change.
- [Host guide](../../host/README.md) — build, launch, verification, release, rollback, signing, and prompt boundaries.
- [Command guide](../../script/README.md) — maintained task commands and lower-level adapters.
- [Generated Workspace Retention](../../script/lib/generated-workspace-retention.js) — ignored artifact classification and exact-path cleanup.

## Current work

No issue is open or claimed.

## History

Resolved issues under `issues/`, including [Issue 62](issues/62-shrink-residual-interface-and-forward-tests.md), [Issue 61](issues/61-fail-fast-release-source-and-narrow-host-guide.md), [Issue 60](issues/60-tighten-release-identity-and-forward-tests.md), [Issue 59](issues/59-deepen-remaining-wrapper-seams.md), [Issue 58](issues/58-finish-fast-release-architecture-cleanup.md), [Issue 57](issues/57-deepen-remaining-maintenance-interfaces.md), [Issue 56](issues/56-deepen-pre-release-maintenance-interfaces.md), and [Issue 55](issues/55-remove-shallow-maintenance-interfaces.md), preserve dated decisions and evidence. They are not part of the normal reading path and do not define another current build, test, release, or rollback workflow. Git history and the append-only wiki log retain earlier process detail.

## Out of scope

- Modifying, redistributing, or reverse engineering DBCode.
- Reimplementing DBCode features in the wrapper.
- Replacing Code OSS without a bounded compatibility proof.
- Presenting the app as an official DBCode product.
- Automatic update installation or publication.
- Paid Developer ID signing, Apple notarization, or Mac App Store distribution.
