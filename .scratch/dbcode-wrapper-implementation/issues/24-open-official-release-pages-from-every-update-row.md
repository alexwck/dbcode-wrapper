# 24 — Open official release pages from every update row

**What to build:** Make every row in the read-only update review open the matching official version page: Microsoft for Code OSS, VSCodium's GitHub release for the packaging layer, and DBCode's own changelog for the extension.

**Blocked by:** 23

**Type:** task

**Status:** resolved

- [x] Selecting the Code OSS row opens the exact official Microsoft GitHub release tag.
- [x] Selecting the VSCodium row opens the exact official VSCodium GitHub release tag.
- [x] Selecting the DBCode row opens the exact version page in DBCode's official changelog.
- [x] Open VSX remains the verified source of DBCode version and publication metadata; changing the reading destination does not weaken metadata validation.
- [x] Cached and installed release records reject unrelated release-note hosts and malformed version links.
- [x] Rendered QA observes the external URL requested by each row without opening a browser or relying on a manual visual check.
- [x] The complete development checks pass and the rebuilt signed application preserves the read-only update boundary.

## Comments

- 24 July 2026: The user confirmed the accepted update-discovery build passed, then asked for VSCodium and DBCode rows to behave like Code OSS. DBCode's official changelog exposes version pages at `https://dbcode.io/docs/changelog/<version>`, while the VSCodium release destination remains its exact GitHub tag.
- 24 July 2026: Commits `12297f0` and `064fbf7` added the official link contracts and a rendered QA capture that stays inside the disposable `.build/qa` profile. Normal application launches still use Code OSS's external-browser handoff.
- 24 July 2026: The complete development suite, static signed-app smoke test, and full rendered regression passed. The rendered proof observed exactly one official URL for each row and reported no unexpected renderer or extension-host errors.

## Answer

The update review now uses one consistent action for all three components:

- Code OSS `1.126.0` opens `https://github.com/microsoft/vscode/releases/tag/1.126.0`.
- VSCodium `1.126.04524` opens `https://github.com/VSCodium/vscodium/releases/tag/1.126.04524`.
- DBCode `1.36.2` opens `https://dbcode.io/docs/changelog/1.36.2`.

Open VSX remains the trusted source for DBCode version and publication metadata. Only the human-readable destination changed to DBCode's official version changelog.

The final signed application was rebuilt from source revision `064fbf7ae7dc27b2d415346ff953f984933fd679`. Its source-set identity is `code-oss-1.126.0-dbcode-1.36.2-source-6b9ab1d761aed668f3209c0a447c3f5103a7cb098108addffec7ef74701ee5ad`, and its application SHA-256 is `06fe1ac3ad3e200cb12effa0b7536c7fdd9bddf63d0b36d64b1f01d51cbd59e2`.
