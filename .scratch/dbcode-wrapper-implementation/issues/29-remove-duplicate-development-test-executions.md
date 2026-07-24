# 29 — Remove duplicate development test executions

**What to build:** Keep the complete development gate but run the update-status, profile-migration, and Host Session Node test modules only once through their focused contract adapters and pinned Node runtime.

**Blocked by:** 28

**Type:** task

**Status:** open

- [ ] `script/check_development.sh` invokes each focused contract adapter once and does not also invoke its owned Node test directly.
- [ ] The update-status, profile-migration, and Host Session Node test modules still run through their task-level contract adapters with the pinned Node runtime.
- [ ] A focused call-count or trace check proves the three modules are not executed twice.
- [ ] The complete development gate passes with no lost assertions.
