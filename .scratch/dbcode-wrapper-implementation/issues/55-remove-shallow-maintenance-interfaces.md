# 55 — Remove shallow maintenance interfaces

**What to build:** Retire the orphan host-size audit, keep one managed profile-settings source, reduce Profile Layout to `default` and `qa`, and narrow the Host Session command adapter without changing DBCode-owned behaviour or the prompt-free release path.

**Blocked by:** none

**Type:** task

**Status:** claimed

- [ ] Move packaged host size and exact built-in inventory checks into Static Host Smoke.
- [ ] Remove the generic isolated profile mode and the unused QA recovery switch.
- [ ] Generate the profile-migration extension settings from `host/profile/settings.json`.
- [ ] Keep only the Host Session `run` command adapter.
- [ ] Update forward-facing documentation and the implementation map.
- [ ] Run focused tests, the prompt-free development gate, and final review.

## Comments

- 2026-08-01: Claimed after the user approved all four maintenance candidates. The confirmed public test seams are Static Host Smoke, the Profile Layout module and CLI, assembled extension settings, and the Host Session `run` command. Tests will cover those observable interfaces before their old implementation paths are removed.
- 2026-08-01: Each focused contract failed against the old interface before implementation, then passed after the cleanup. The complete prompt-free development gate passed in about 36 seconds with one existing sandbox-only process-table fixture skipped. No app build, GUI launch, profile mutation, Keychain prompt, database, network request, or human gate was used.
- 2026-08-01: Independent review found that the first Static Host Smoke loop could follow a linked extension directory and did not fail separately on malformed package JSON. It also found weak fixture coverage and repeated Host Session policy validation. The checks now reject linked or invalid extension roots and manifests through a small smoke-owned module, a fast synthetic fixture exercises every slimming outcome, and each Host Session public operation validates its policy once.
