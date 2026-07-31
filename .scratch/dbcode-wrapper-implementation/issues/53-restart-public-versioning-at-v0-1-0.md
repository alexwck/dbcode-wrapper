# 53 — Restart public versioning at v0.1.0

**What to build:** Replace the seven existing GitHub releases and version tags `v0.1.0` through `v0.1.6` with one normal public `v0.1.0` release built from the current source. Preserve Git commit history and retained local release evidence. Keep the pinned VSCodium, Code OSS, and DBCode versions unchanged. Publish only the independently verified host DMG and checksum, with a short plain-English description of the wrapper.

**Blocked by:** none

**Type:** task

**Status:** resolved

- [x] Match every remote release asset to an exact retained local copy before removing any release or tag.
- [x] Reset the wrapper version while preserving Git commit history and historical rollback approvals.
- [x] Update the maintained public release description to explain what the wrapper does.
- [x] Run the prompt-free development, exact-source, rendered, package, and approval gates.
- [x] Remove only GitHub releases and version tags `v0.1.0` through `v0.1.6` after the replacement is ready.
- [x] Publish one normal, non-draft, non-prerelease `v0.1.0` release with only the verified DMG and checksum.
- [x] Verify public downloads, remote refs, latest-release state, retained local evidence, and final clean Git state.

## Comments

- 2026-08-01: Claimed after the user explicitly approved deleting all seven GitHub release records and all seven version tags, preserving Git history and retained local evidence, and restarting the public release line at `v0.1.0` from the current code.
- 2026-08-01: Matched all 21 GitHub release assets to retained local files by exact filename, byte size, and SHA-256 before making any destructive change. The two drafts each have five recoverable assets; each normal release has its recoverable DMG and checksum. No remote release or tag has been removed yet.
- 2026-08-01: Reset the wrapper version to `0.1.0` and bound it to this issue without changing VSCodium `1.126.04524`, Code OSS `1.126.0`, DBCode `1.36.6`, or profile schema 1. Historical Approved Release Sets remain intact for rollback and audit; the new exact `v0.1.0` approval will be appended after acceptance. The maintained publisher now describes the wrapper's focused app, private profile, simplified interface, update status, and verified packaging in plain English.
- 2026-08-01: The prompt-free source gate, exact-source cache-backed build, static signed-host smoke, and all 14 rendered checks passed. The current-user signing identity needed its existing trust reloaded before the sandboxed build could use it; no password or application prompt was accepted by automation. Final acceptance, annotated tagging, host-only packaging, two disk-image checks, independent mounted verification, and approval then passed without installing the app or changing the production profile.
- 2026-08-01: After the replacement was fully approved and committed, removed the seven exact GitHub release records and remote tags `v0.1.0` through `v0.1.6`, then removed the six superseded local tags. Every old tagged commit remains in `main` history and all matched local release evidence remains protected. Published the replacement `v0.1.0` as the only normal release and only version tag. GitHub reports exactly the DMG and checksum, and a fresh anonymous download passed the published checksum.

## Answer

[DBCode Wrapper v0.1.0](https://github.com/alexwck/dbcode-wrapper/releases/tag/v0.1.0) is now the repository's only and latest release. It runs the official, unchanged DBCode extension as a focused macOS database application with its own app identity, private profile, simplified interface, update status, and verified packaging.

The public release contains only the 187,909,991-byte Apple-silicon DMG with SHA-256 `8755b43150f52fe406198d3ca176fd560e7ee41b42f600f42c065393131f47fd` and its checksum. VSCodium remains `1.126.04524`, compatible Code OSS remains `1.126.0`, and DBCode remains `1.36.6`. Git commit history and protected local evidence for the retired releases were preserved.
