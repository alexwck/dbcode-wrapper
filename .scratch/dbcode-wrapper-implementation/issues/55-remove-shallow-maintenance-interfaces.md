# 55 — Remove shallow maintenance interfaces

**What to build:** Retire the orphan host-size audit, keep one managed profile-settings source, reduce Profile Layout to `default` and `qa`, and narrow the Host Session command adapter without changing DBCode-owned behaviour or the prompt-free release path.

**Blocked by:** none

**Type:** task

**Status:** resolved

- [x] Move packaged host size and exact built-in inventory checks into Static Host Smoke.
- [x] Remove the generic isolated profile mode and the unused QA recovery switch.
- [x] Generate the profile-migration extension settings from `host/profile/settings.json`.
- [x] Keep only the Host Session `run` command adapter.
- [x] Update forward-facing documentation and the implementation map.
- [x] Run focused tests, the prompt-free development gate, and final review.

## Comments

- 2026-08-01: Claimed after the user approved all four maintenance candidates. The confirmed public test seams are Static Host Smoke, the Profile Layout module and CLI, assembled extension settings, and the Host Session `run` command. Tests will cover those observable interfaces before their old implementation paths are removed.
- 2026-08-01: Each focused contract failed against the old interface before implementation, then passed after the cleanup. The complete prompt-free development gate passed in about 36 seconds with one existing sandbox-only process-table fixture skipped. No app build, GUI launch, profile mutation, Keychain prompt, database, network request, or human gate was used.
- 2026-08-01: Independent review found that the first Static Host Smoke loop could follow a linked extension directory and did not fail separately on malformed package JSON. It also found weak fixture coverage and repeated Host Session policy validation. The checks now reject linked or invalid extension roots and manifests through a small smoke-owned module, a fast synthetic fixture exercises every slimming outcome, and each Host Session public operation validates its policy once.
- 2026-08-01: Both recursive reviews were clear after the fixes. The final complete development gate passed with the same one sandbox-only process-table fixture skipped. The public/standard wiki was refreshed at source commit `3700317`; 32 wiki documents have zero lint errors, zero warnings, and zero dead links, and `ok preview` passed. No generated evidence, profile, package, built app, or protected retention root was removed.

## Answer

- Static Host Smoke now owns installed size, source-map, exact built-in inventory, embedded DBCode, and packaged managed-settings checks. A fast synthetic fixture covers those outcomes without inspecting a private runtime.
- Profile Layout now exposes only the normal current-user profile and the persistent generated `qa` profile. Recovery derives only the current-user profile.
- `host/profile/settings.json` is the one maintained settings source. Assembly creates the extension copy, and smoke testing requires the packaged copy to match exactly.
- The Host Session command adapter now exposes only `run --policy FILE --output FILE`. Each public lifecycle operation validates its policy once; internal shutdown remains in the JavaScript module.

The orphan audit script and duplicate tracked settings file are gone. No new ignore rule is needed, and no generated or protected folder was removed. The complete prompt-free development gate stays below one minute and needs no app launch or human input.
