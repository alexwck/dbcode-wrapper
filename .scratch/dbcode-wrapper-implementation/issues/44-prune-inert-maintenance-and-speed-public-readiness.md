# 44 — Prune inert maintenance and speed public readiness

**What to build:** Remove maintained files that no release, build, or product route uses; strengthen the public-source privacy guard for DBCode-openable local data; and make the exact-ref public-readiness scan materially faster without weakening its full-history checks.

**Blocked by:** none

**Type:** task

**Status:** resolved

- [x] Remove the unused database proof fixtures left after the manual acceptance harnesses were retired.
- [x] Remove the unused Python-kernel preparation helper without removing the DBCode notebook route or required Python/Jupyter packages.
- [x] Remove the unused manual signing-continuity recorder without changing normal signing or manifest checks.
- [x] Ignore and reject common local database, spreadsheet, notebook, package-signature, and checksum artifacts that do not belong in wrapper source.
- [x] Scan exact Git history in one bounded pass while preserving checks for secrets, personal paths, unsafe file types, commit messages, and annotated tags.
- [x] Run focused contracts, the public source-tree gate, and the complete prompt-free development gate without building or launching the app.

## Comments

- 2026-07-29: Claimed as the no-regret cleanup after the normal `v0.1.3` Host Release. The earlier manual-harness cleanup deliberately kept accepted generated evidence, but the four tracked database proof fixtures and two preparation or continuity helpers now have no production or release caller. See [ticket 40](./40-retire-manual-acceptance-harnesses.md).
- 2026-07-29: The exact-ref public-readiness gate passed on `main` but took 22.59 seconds. This ticket may change how Git objects are streamed, but it must keep the same rejection contract and exact-ref scope described in the [verification policy](../../../docs/agents/verification-policy.md).
- 2026-07-29: Removed the six unused proof, QA-kernel, and signing-continuity files together with their dead compatibility branches. Notebook support, the unchanged DBCode route, Python/Jupyter runtime packages, normal local signing, and prompt-free schema-3 release acceptance remain maintained.
- 2026-07-29: Added ignored and rejected patterns for common local database, spreadsheet, notebook, checksum, and package-signature files. Added local OpenKnowledge state to the tracked ignore policy.
- 2026-07-29: Replaced one Git process per historical object with bounded `git cat-file --batch-check` and `--batch` streams. The synthetic full-history contract, public source-tree contract, focused release contracts, and `git diff --check` passed.
- 2026-07-29: `./script/check_development.sh` passed in 21.97 seconds without rebuilding or launching the app. Eleven Host Session tests passed and the known fixture process-table check was skipped because the sandbox does not permit it.
- 2026-07-29: The public-readiness gate passed against exact commit `00a9b9b83dfe18b1b9e5b7ae25c26355d97aabdf` in 0.25 seconds, down from 22.59 seconds. The generated-workspace inventory found no deletion-eligible path, so retained application, acceptance, rollback, profile, cache, and screenshot evidence was not deleted.

## Answer

The maintained source no longer carries retired human-assisted QA or signing paths. Routine version tests derive their current expectations from `host/release-lock.json`, stale generated patch trees fail only at the real compile boundary, and exact-ref public readiness keeps its privacy contract while completing in a fraction of a second. Larger removals that change the update surface or rollback contract remain explicit product decisions.
