# 29 — Remove duplicate development test executions

**What to build:** Keep the complete development gate but run the update-status, profile-migration, and Host Session Node test modules only once through their focused contract adapters and pinned Node runtime.

**Blocked by:** 28

**Type:** task

**Status:** resolved

- [x] `script/check_development.sh` invokes each focused contract adapter once and does not also invoke its owned Node test directly.
- [x] The update-status, profile-migration, and Host Session Node test modules still run through their task-level contract adapters with the pinned Node runtime.
- [x] A focused call-count or trace check proves the three modules are not executed twice.
- [x] The complete development gate passes with no lost assertions.

## Answer

The development gate now leaves Approved Release Set and update-status Node tests to the update-status adapter, profile-layout and migration Node tests to the profile-migration adapter, and Host Session Node tests to the Host Session adapter. Each adapter remains the only owner of those executions and uses the Node runtime pinned by the Release Specification.

`script/test_development_gate_contract.sh` checks that the development gate calls each adapter exactly once, never names an adapter-owned Node test directly, and retains every exact pinned-Node invocation inside its adapter.

Verification:

- The new development-gate contract first failed against the duplicate direct execution and then passed after the orchestration change.
- All three focused contract adapters passed.
- `script/check_development.sh` passed completely with no lost assertions.

## Comments

- 2026-07-25: Claimed as the next dependency-ordered repository-maintenance ticket after issue 28.
- 2026-07-25: Resolved after the focused call-count contract, all three task-level adapters, and the complete development gate passed.
