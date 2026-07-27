# 41 — Remove the retired prepared-release API

**What to build:** Remove the prepared release-set validator, member resolver, and legacy approval writer left behind by the retired controlled-upgrade workflow. Keep current approved-history validation, update lookup, prompt-free approval, and rollback history intact.

**Blocked by:** 40

**Type:** task

**Status:** resolved

- [x] The JavaScript module no longer exports the prepared-set validator, member resolver, relative-member validator, or legacy approval constructor.
- [x] The CLI and shell adapters expose only maintained history, lookup, validation, package-check, and prompt-free approval operations.
- [x] The obsolete prepared-set and legacy approval fixtures are removed from the existing focused test runner.
- [x] Public architecture and current issue answers describe approval and guarded rollback without a retired promotion API.
- [x] Focused contracts and the complete development gate pass without launching or rebuilding the app.

## Comments

- 2026-07-27: Claimed after ticket 40 removed every caller of the prepared-set API. Repository-wide reference checks found only the API's own adapters and tests.
- 2026-07-27: Removed the unused JavaScript exports, CLI commands, shell adapters, fixtures, and tests for the retired workflow. A negative regression test now keeps those entry points absent.
- 2026-07-27: `./script/test_update_status_contract.sh`, `./script/test_private_release_contract.sh`, `./script/test_release_rollback_contract.sh`, `./script/test_public_source_tree_contract.sh`, and `./script/check_development.sh` passed. The complete gate finished without rebuilding or launching the app; its one skipped check was the expected sandbox process-table fixture.

## Answer

The Approved Release Set module now has one current API. It validates approved history, finds exact update matches, supplies the package checks used by prompt-free approval, and writes prompt-free approval records. The old prepared-set validator, path resolver, and proof-based writer are gone because no maintained workflow called them.
