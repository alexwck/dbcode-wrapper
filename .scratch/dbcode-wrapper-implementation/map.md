# DBCode Wrapper implementation map

## Destination

Ship a maintainable, DBCode-only Apple-silicon application that runs the unchanged licensed DBCode extension on the smallest proven compatible host. The focused interface, profile migration, controlled update, rollback, slimming, persistent personal signing, architecture modules, complete connection-catalogue boundary, same-Mac acceptance, public source, and verified host-only package are complete. The remaining path uses an authenticated GitHub draft for private transfer and validates the package on another owned Mac.

## Notes

- DBCode remains unchanged and installed outside the signed application bundle.
- The Public Source Repository contains only the wrapper's own source, patches, tests, notices, and project notes. It does not contain a built app, copied DBCode content, licence or account data, credentials, profiles, local databases, signing secrets, or raw real-profile evidence. Sanitized issue notes may retain versions, artifact digests, and pass or fail summaries.
- The Private Personal Release contains the host, not DBCode, licence keys, database credentials, or user profiles. A fresh Finder launch offers one focused action that obtains and verifies the exact approved unchanged DBCode and Python/Jupyter packages from Open VSX into the current-user profile.
- While the source repository is public, a DMG may use an authenticated GitHub draft release as a temporary owned-device transfer only. It must remain a draft, anonymous access must fail, and no workflow may publish it.
- Releases use the current-user self-signed identity and a documented macOS `Open Anyway` step on each owned Mac. The project does not depend on a paid Apple developer membership, Developer ID, or Apple notarization.
- Code OSS is the current extension-host and workbench runtime. VSCodium is its reproducible macOS build and packaging layer, not a second runtime.
- The current signed application is the accepted database-client checkpoint: Connections Home, Database Explorer, automatic DBCode result layout, focused query routes, and no generic Code OSS bottom panel.
- The exact `v0.1.0` source was rebuilt after the focused first-run runtime installer landed, passed renewed full acceptance, and produced a verified host-only DMG without moving the annotated source tag.
- Open work lives in child tickets and is found from their `Status`, `Blocked by`, and `Type` fields rather than being repeated on this map.

## Decisions so far

- [Build the reproducible private macOS host](./issues/01-build-reproducible-private-macos-host-and-smoke-harness.md) — Use VSCodium as the reproducible packaging layer around a pinned Code OSS runtime, then build, sign, and verify an independent Apple-silicon application with private product identity and profiles.
- [Load unchanged DBCode in the isolated host](./issues/02-load-unchanged-dbcode-in-isolated-host-profile.md) — Install the verified official DBCode `1.36.1` package outside the app bundle and use the app's natural private macOS profile paths so scripted and Finder launches share the same licence and connection state.
- [Ship the DBCode-focused redesign](./issues/03-ship-dbcode-focused-redesign.md) — Present DBCode as a dedicated database application, with Results on the right or below and project SQL files opening as query tabs through one SQL-only native command.
- [Clarify the host and streamline ongoing development](./issues/10-clarify-host-and-streamline-development.md) — Keep VSCodium packaging around the Code OSS runtime, make SQL the only query-document entry, remove obsolete exploration material, and batch Appshot feedback before the next full build.
- [Keep the compatible host and slim it before considering a rewrite](./issues/11-decide-minimum-maintainable-dbcode-host.md) — Open VSX distributes DBCode but does not run it; keep the Code OSS extension-host interface, refine the UI with Appshot, then remove only packaged host content proven unnecessary by the complete DBCode compatibility gate.
- [Accept the focused DBCode application shell](./issues/12-refine-database-client-redesign-with-appshot.md) — Use DBCode-owned Connections Home, database navigation, queries, account, tables, and result grids inside a focused shell; hide generic IDE panels and let the window width place new results beside or below the query automatically.
- [Ship the slim compatible Code OSS host](./issues/13-slim-compatible-code-oss-host.md) — Omit source maps and package only SQL, the active color and icon themes, and standard notebook renderers; keep DBCode external and unchanged, with one policy switch that restores every upstream built-in if compatibility ever requires it.
- [Keep advanced DBCode features reachable](./issues/05-keep-advanced-dbcode-features-reachable.md) — Keep seven proven DBCode Tools routes, reveal scratch files through Finder, remove guaranteed-failure and duplicate actions, lock settings to DBCode, and require exact contribution plus rendered checks for every approved host-and-DBCode release set.
- [Guide safe first-run profile migration](./issues/04-guide-safe-first-run-profile-migration.md) — Start with a clean Standalone DBCode Profile, import only reviewed non-secret connection details through DBCode's own workflow, defer a hyphenated DuckDB connection unless its exact read-only preflight succeeds, and provide profile-only backup and recreation that reopens exactly once.
- [Show safe update availability](./issues/06-show-update-availability-from-official-metadata.md) — Check only official stable VSCodium and DBCode metadata, show each component separately, and call an exact pair ready only when a complete local approval binds its source identity to the signed artifact; discovery never installs or promotes anything.
- [Promote and roll back complete approved release sets](./issues/07-promote-and-roll-back-approved-release-sets.md) — Test the four current/new host and DBCode combinations independently, restore official signed payload files only inside the isolated candidate, promote the app and complete private profile as one confirmed transaction, require real-Keychain restart health before acceptance, and retain a practised complete rollback.
- [Accept the same-Mac personal release](./issues/08-produce-same-mac-personal-release-and-run-full-acceptance.md) — Accept the exact signed Apple-silicon app after source, rendered, real-profile, database, update, four-way compatibility, restart-health, rollback, permission, and unchanged-bundle gates pass with no failures or waivers.
- [Preserve documented DBCode capability while keeping the host focused and slim](./issues/14-audit-official-dbcode-feature-coverage.md) — Consolidate only proved duplicate routes; treat direct data files, project-aware workflows, HTTP MCP, advanced SQL actions, and the DBCode debugger as compatibility work, keep Copilot Chat out when HTTP MCP proves the same database tools, and make Python/Jupyter part of the tested base capability.
- [Approve DBCode 1.36.2 with core Python notebooks](./issues/15-approve-dbcode-1-36-2-with-core-python-notebooks.md) — Approve the exact seven-extension DBCode `1.36.2` and Code OSS `1.126.0` release set after rendered, licensed, database, persistence, size, signature, inventory, and rollback gates; retain a runnable DBCode `1.36.1` snapshot while tickets 07 and 08 finish installed rollback and persistent signing.
- [Document and clean the maintainable source tree](./issues/16-document-and-clean-the-maintainable-source-tree.md) — Add the public architecture, maintenance, privacy, verification, and learning contracts before changing release identities.
- [Deepen the Release Specification module](./issues/17-deepen-the-release-specification-module.md) — Validate the lock once and return complete build, extension, profile/product, and release-identity records instead of leaking its JSON layout across scripts.
- [Deepen the Approved Release Set contract](./issues/18-deepen-the-approved-release-set-contract.md) — Centralize canonical release-set identity, validation, safe member resolution, approval lookup, and writing behind shell and JavaScript adapters.
- [Unify the Standalone DBCode Profile layout](./issues/19-unify-the-standalone-dbcode-profile-layout.md) — Derive one validated profile record for shell launch/proof code and JavaScript recovery code.
- [Replace launch helpers with a Host Session module](./issues/20-replace-launch-helpers-with-a-host-session-module.md) — Put launch, renderer and DBCode readiness, logs, timeout, and complete quit behind one policy-driven session interface.
- [Consolidate the Code OSS patch stack by semantic seam](./issues/21-consolidate-the-code-oss-patch-stack.md) — Replace chronological UI patch history with a small semantic plan and prove the final pinned Code OSS tree is unchanged.
- [Preserve every DBCode connection capability](./issues/22-preserve-all-dbcode-connection-capabilities.md) — Keep the unchanged installed DBCode catalogue authoritative; use PostgreSQL, DuckDB, Parquet, SQLite, and notebooks as representative proofs rather than a wrapper allowlist.
- [Discover Code OSS updates independently](./issues/23-discover-code-oss-updates-independently.md) — Check Microsoft, VSCodium, and DBCode separately, show Code OSS `1.130.0` as not tested, and never install or approve a release from discovery alone.
- [Open each component's official release page](./issues/24-open-official-release-pages-from-every-update-row.md) — Keep Open VSX as DBCode's verified metadata source while sending Code OSS and VSCodium rows to their exact GitHub tags and the DBCode row to its exact official changelog version page.
- [Read frozen Release Specifications for rollback](./issues/25-read-frozen-release-specifications-for-rollback.md) — Keep new candidates on the strict current schema while allowing only exact manifest-bound schema-2 and earlier schema-4 current sets through a read-only historical adapter.
- [Require every compatibility pairing before promotion](./issues/26-require-every-compatibility-pairing-before-promotion.md) — Treat all four current/candidate host and DBCode receipts as promotion gates so no failed mixed pairing can be hidden by a passing baseline and intended pair.
- [Canonicalize proof extension inventory](./issues/27-canonicalize-proof-extension-inventory.md) — Record the exact external extension set in canonical ID order so host CLI display ordering cannot make current acceptance evidence look stale.

## Not yet specified

- Any further visual refinements requested after the current Appshot acceptance checkpoint.
- Whether DBCode offers a supported standalone engine, SDK, or service API for licensed customers in the future.

## Out of scope

- Modifying or reverse engineering DBCode.
- Reimplementing DBCode's database engine and features while presenting the result as DBCode.
- Replacing Code OSS with a different host without a bounded size and full-feature compatibility proof.
- A published public application or DMG release, Mac App Store distribution, or application distribution to third parties.
- Paid Apple Developer Program membership, Developer ID distribution signing, and Apple notarization.
