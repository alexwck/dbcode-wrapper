# 46 — Remove stale maintenance and deepen the release workflow

**What to build:** Remove maintenance modules and guidance with no current caller, make generated-workspace retention independent of historical issue state, and add one small owner-facing interface that derives the normal Host Release paths from the Release Specification.

**Blocked by:** none

**Type:** task

**Status:** resolved

- [x] Remove the unused installed-extension payload verifier, restorer, and their owning tests.
- [x] Remove the stale database-client design reference and keep current behaviour in source, tests, and maintained guides.
- [x] Make Generated Workspace Retention use artifact purpose and explicit expiry instead of a resolved issue status or retired workflow names.
- [x] Add a prompt-free Host Release task interface that derives the release tag and standard paths, records the exact approved history safely, and preserves separate acceptance, package, approval, and explicit publication adapters.
- [x] Rename the maintained rendered QA runner and output files by purpose instead of old ticket numbers.
- [x] Keep automatic update polling, the update-status interface, one generated QA profile, guarded rollback, and protected generated evidence unchanged.
- [x] Keep the root README, agent instructions, implementation map, and active wiki forward-facing and release-neutral.
- [x] Run focused contracts and the complete prompt-free development gate without rebuilding or launching the app.

## Comments

- 2026-07-29: Claimed after the user approved every candidate in the forward-cleanup architecture review. The deletion test found that the installed-payload repair scripts are kept alive only by their own tests. The generated-workspace inventory found no deletion-eligible artifact, so this task changes maintained source and names but does not delete protected output.
- 2026-07-29: Removed the four no-caller payload maintenance files and the stale design-reference folder. Renamed the rendered QA runner and outputs by purpose. Automatic polling, update status, the generated `qa` profile, rollback, and protected generated evidence remain in place.
- 2026-07-29: Generated Workspace Retention now classifies historical directories by current artifact purpose and explicit expiry without reading resolved issue state. Live inventory reported no deletion-eligible path and did not traverse protected artifacts.
- 2026-07-29: `release_host.sh` now provides `plan`, resumable `prepare`, and explicit `publish --publish`. Full acceptance is validated before tagging. Reused approval is bound to the exact manifest, release lock, tag, attestation, record, and generated history before one tracked approval-history change is written.
- 2026-07-29: Focused source, release-task, approval, retention, DBCode, profile, and update-status contracts passed. The final `./script/check_development.sh` completed in 25.85 seconds without rebuilding or launching the app. Eleven Host Session tests passed and one disposable process-table fixture was skipped because the sandbox does not permit it.
- 2026-07-29: Independent requirements and standards reviews found no remaining actionable source findings after full acceptance ordering, exact approval binding, fixture-backed public-command coverage, current resolved-issue wording, and purpose names were corrected.
- 2026-07-29: Refreshed the active OpenKnowledge wiki against source commit `afc5fe7`. The current pages use the owner-facing release task, keep automatic polling and one `qa` profile, remove frozen release details and retired live-fixture guidance, and record the change in the append-only wiki log. OpenKnowledge lint found no problems, the link graph had no dead links, and the overview rendered with its Mermaid diagram.

## Answer

The repository now presents one current maintenance path. No-caller payload repair scripts and the stale design reference are gone. Generated output is classified by artifact purpose and explicit expiry. Rendered QA uses purpose-based names and one persistent generated `qa` profile.

`script/release_host.sh` is the small owner interface for a normal published release in this repository. It shows the plan, validates prompt-free acceptance before tagging, packages and independently verifies the host, records one exact approval-history change, and requires a separate explicit publish action. Automatic Code OSS, VSCodium, and DBCode polling stays read-only. Guarded rollback and protected evidence stay in place.

The root guidance and active wiki are forward-facing and release-neutral. No new `.gitignore` entry was needed because generated builds, profiles, evidence, packages, credentials, and local system files were already covered.
