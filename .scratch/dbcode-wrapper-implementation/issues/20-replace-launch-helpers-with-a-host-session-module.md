# 20 — Replace launch helpers with a Host Session module

**What to build:** Replace repeated process, renderer, DBCode-log, timeout, and quit implementations with one Host Session module that accepts an explicit session policy and returns a structured result.

**Blocked by:** 19

**Type:** task

**Status:** resolved

- [x] One small interface owns application launch, renderer discovery, DBCode activation-log discovery, fatal-log checks, timeout handling, graceful quit, forced cleanup, and structured results.
- [x] Development, isolated smoke, release-pair smoke, real-profile proof, and installed health use the same session implementation with explicit policies.
- [x] Foreground debugging remains a deliberate adapter and never weakens production readiness checks.
- [x] Tests cover process exit, renderer timeout, DBCode timeout, stable renderer requirements, fatal log detection, graceful quit, forced quit, and result serialization without launching the production profile.
- [x] Callers own business evidence and fixture decisions; the Host Session module owns only one application lifecycle.

## Comments

- 23 July 2026: Added a policy-driven Host Session module with a shell adapter and command-line boundary. It validates executable, argument, environment, log, renderer, DBCode, timeout, and completion policy before starting one application lifecycle.
- 23 July 2026: Development launch, isolated host smoke, release-pair smoke, real-profile proof, and installed restart health now use the same start, readiness, fatal-log, graceful-quit, forced-cleanup, and structured-result implementation. The small launch-readiness helper and the repeated process loops were removed.
- 23 July 2026: Host Session records the exact application and renderer processes, fresh host and DBCode logs, readiness observations, exit state, and complete quit outcome. Stop requests recheck the recorded executable before signaling its process tree; broad application-name kills are no longer used.
- 23 July 2026: The real-profile proof retains its business evidence and the smoke and health callers retain their own update, Keychain, profile, and fixture checks. Foreground debugging remains a clearly marked direct-stream adapter only.
- 23 July 2026: Injected lifecycle tests cover early exit, renderer and DBCode timeouts, stable readiness, fatal logs, unexpected observer failure, graceful quit, forced quit, detached sessions, user-driven exit, saved-session stop, and serialization. A disposable fake-host integration check also exercises the real runtime when process-table access is available. The complete development source suite passed.

## Answer

There is one maintained normal launch path. `run_host.sh` states its readiness and completion policy, while the Host Session module starts DBCode Wrapper, finds its logs, and tracks the process lifecycle. The retired compatibility and real-profile health harnesses no longer duplicate this work.
