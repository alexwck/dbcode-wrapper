# 45 — Concentrate release validation with update discovery

**What to build:** Keep automatic VSCodium, Code OSS, and DBCode polling plus the current update-status interface, while reducing repeated Host Release validation and narrowing the wide compatibility-metadata writer without weakening independent package verification.

**Blocked by:** none

**Type:** task

**Status:** resolved

- [x] Keep the shipped release-status extension, automatic polling, status icon, review screen, notifications, official links, and read-only boundary unchanged.
- [x] Measure repeated app digests, source validation, tree inspection, disk-image mounting, and compatibility-metadata work before changing the Host Release module.
- [x] Replace the wide compatibility writer input list with one validated release context owned by the Host Release module.
- [x] Reuse only content-bound values inside one trusted packaging run. Independently inspect and verify every copied tree and mounted disk image.
- [x] Keep publication owner-driven: update discovery never changes the release lock, creates a tag, or publishes a release.
- [x] Run focused Host Release contracts and the complete prompt-free development gate without launching the app.

## Comments

- 2026-07-29: The user approved release-validation consolidation but explicitly chose to retain automatic polling and the update-status UI. An update remains a read-only signal; the owner can ask Codex to prepare, tag, and publish a tested wrapper release.
- 2026-07-29: Before this change, the packager performed two full signed-app and acceptance validations plus a source-tag validation. The independent verifier performed another source-tag validation and another full signed-app validation. The compatibility writer also took 17 positional inputs. A real accepted-app timing reached its signing check after 2.85 seconds, where the local certificate trust state stopped it; no prompt was opened or approved.
- 2026-07-29: The packager now creates one validated, digest-bound release context. It checks the staged copy against that exact context instead of rerunning source and acceptance validation. The mounted-DMG verifier still creates its own context from untrusted mounted bytes. The compatibility writer now takes four inputs: output, time, context, and package record.
- 2026-07-29: The final `script/test_host_release_contract.sh` passed in 16.14 seconds. The final `./script/check_development.sh` passed in 23.51 seconds without rebuilding or launching the app; all 33 update-status tests passed, and the known Host Session process-table fixture remained skipped because the sandbox does not permit it. OpenKnowledge lint found no problems in the six changed public Markdown files.
- 2026-07-29: Maintained public guidance now describes only the current Host Release path. README examples are version-neutral, AGENTS no longer catalogues retired release tools, and detailed historical transfer instructions are no longer part of active public guidance. Historical issue comments and retained evidence remain unchanged.
- 2026-07-29: The forward-documentation cleanup passed `git diff --check` and `script/test_public_source_tree_contract.sh`. OpenKnowledge lint found no problems across all 32 wiki documents, the Overview links every maintained wiki page, the two log-only forward pointers keep append-only history valid, the wiki-only dead-link audit found zero dead links, and the rendered Overview preview passed. The final exact-ref readiness gate runs after the documentation commit exists.

## Answer

Automatic polling and the update-status UI remain unchanged and read-only. Host Release packaging performs one full validation, carries its result in one checked context, and accepts only an exact copied app. Independent mounted-DMG verification remains a full check. Maintained documentation presents this as the single forward release path without weakening the public package boundary or moving publication authority into the app.
