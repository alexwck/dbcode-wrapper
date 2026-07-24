# 04 — Guide safe first-run profile migration

**What to build:** Give the user a first-launch flow that creates a fresh Standalone DBCode Profile, imports only reviewed non-secret connection details through DBCode's supported importer, and provides a safe way back without touching the existing VS Code setup.

**Blocked by:** 05 — Keep advanced DBCode features reachable without exposing an IDE

**Type:** task

**Status:** resolved

- [x] First launch starts with a fresh Standalone DBCode Profile and never treats the normal VS Code profile, extension state, Settings Sync account, Keychain records, machine identity, or licence state as a copy source.
- [x] A user-selected JSON or CSV inventory is parsed into a preview that allows only connection names, database types, hosts, ports, databases, usernames, SSL choices, and reviewed local file paths.
- [x] Passwords, tokens, embedded-secret URLs, private keys, passphrases, salts, licence data, and old connection identifiers are rejected before staging.
- [x] User confirmation invokes DBCode's declared Import Connections flow directly from focused setup UI while the generic Command Palette remains hidden.
- [x] Unsupported connections are added manually, protected credentials are re-entered through DBCode, and the lifetime Pro licence is activated normally.
- [x] A DuckDB path whose filename stem contains a hyphen receives a read-only exact-version preflight; failure defers only that connection and never renames, moves, or rewrites the database.
- [x] The temporary import data is restricted to the current user and removed after acceptance or cancellation.
- [x] Migration acceptance reruns PostgreSQL, DuckDB, Parquet, activation, and independent-relaunch checks.
- [x] A disposable-profile acceptance completes DBCode's source selection, file selection, field mapping, preview, and confirmation, then proves the reviewed connection was imported.
- [x] A recovery operation backs up and recreates only the Standalone DBCode Profile without changing normal VS Code, Keychain records, or database files.

## Answer

On a fresh Mac, first launch now offers one focused setup action for the exact verified DBCode and Python/Jupyter runtime before opening Profile Setup. After the required reload, the clean Standalone DBCode Profile accepts only reviewed non-secret JSON or CSV connection details, stages them in an owner-only temporary CSV, and passes the final source selection, field mapping, preview, confirmation, and import to unchanged DBCode. Passwords and licence activation stay in DBCode. A hyphenated DuckDB filename is never rewritten: the exact installed DBCode version attempts the stated read-only query and defers only that connection when no result grid is returned.

If a partial import leaves the profile in an unwanted state, Profile Setup can back up and recreate only the Standalone DBCode Profile. Recovery derives and validates its paths, waits for the app and extension host to stop, preserves verified extensions, normal editor data, Keychain records, and database files, then directly reopens exactly one app process on the clean profile. Failed recovery stays closed so its owner-only backup can be inspected.

## Progress

The focused first-launch Profile Setup now starts from a clean Standalone DBCode Profile and accepts only a user-selected JSON or CSV inventory. It previews a small allowlist of non-secret connection fields, rejects protected or nested data before staging, writes ready entries to an owner-only temporary CSV, and hands the final mapping and import to unchanged DBCode. Closing, cancelling, or completing setup removes the staged file.

DuckDB paths with hyphens are kept out of the batch and checked one at a time with the exact installed DBCode version and a read-only statement. Each connection can pass or be deferred independently without changing its database file. Unsupported connections and every protected credential stay in DBCode's normal manual flows.

Automated source, security, packaging, and rendered checks passed. The licensed app then passed a complete initial launch, quit, relaunch, activation, PostgreSQL, DuckDB, Parquet, Keychain, and persistence proof. The manual proof launcher was also corrected so first-run setup has no artificial activation deadline; it still requires a live renderer and a new DBCode activation log from that exact run.

The final disposable-profile acceptance exercised DBCode `1.36.2` itself: CSV source selection, native file selection, nine reviewed field mappings, preview, confirmation, and import all completed. PostgreSQL and Parquet appeared as imported connections. A separate hyphenated DuckDB connection appeared in DBCode, its read-only attempt was safely deferred when DBCode returned no grid, and its SHA-256 stayed unchanged.

The recovery acceptance backed up PostgreSQL, Parquet, and the hyphenated DuckDB connection, recreated owner-only `0700` profile roots with `0600` managed settings, automatically reopened exactly one app process, and proved the new app consumed the recovery outcome. The clean profile contained none of the imported connections, while verified extensions, normal editor data, and database sentinels were unchanged. The complete rendered suite passed 35 checks with no unexpected renderer or extension-host errors.

The final safety review added strict relaunch-path validation. That exposed a rendered-QA mismatch: disposable profiles correctly reused one separately verified extension set, while recovery incorrectly expected an extension folder inside each disposable profile. A focused regression test now covers that layout, overlapping recovery paths remain rejected, and the rebuilt signed app passed the complete rendered suite including clean quit, profile-only backup, and exactly one automatic relaunch. Because this rebuilt artifact differed from the one used for the earlier five manual checks, the ticket temporarily returned to claimed until those checks were repeated against the current artifact.

The rebuilt artifact then completed its independent real-profile relaunch. DBCode stayed licensed without another Keychain prompt, PostgreSQL returned read-only `3 / 75.00`, DuckDB and Parquet each returned `3 / 61.50`, and the saved connections and database state persisted. The proof finalized against artifact SHA-256 `81bc5e92ee19b7df9a045c546761233d4ae62cf119094f8e90a93a9b8fbd270e`.

## Comments

- 21 July 2026: PostgreSQL passed after the proof connection was corrected to the container's host port `55433`; DuckDB and Parquet each returned their expected three-row result.
- 21 July 2026: The first manual run exposed a five-minute proof-harness deadline while the user was still completing setup. The harness now waits without an activation deadline after the app window is live and rejects the run if DBCode never activates before quit.
- 21 July 2026: The user confirmed that Profile Setup did not return after relaunch, DBCode stayed licensed, the Keychain prompt did not repeat, PostgreSQL returned three rows totalling `75.00`, and DuckDB and Parquet each returned three rows totalling `61.50`.
- 21 July 2026: `./script/proof_dbcode.sh finalize` passed and bound the acceptance evidence to the exact signed app, DBCode `1.36.2`, Code OSS `1.126.0`, Standalone DBCode Profile, and active DBCode log.
- 21 July 2026: Final review found that the rendered test proved the DBCode importer handoff but cancelled before file selection, mapping, preview, and import. It also found no practised Standalone DBCode Profile recreation after a partial import. The ticket remains claimed until both checks are implemented and observed.
- 21 July 2026: The disposable-profile test completed DBCode's real CSV source, native file, custom mapping, preview, confirmation, and import flow. It also imported a hyphenated DuckDB entry separately, attempted the exact read-only preflight, deferred it when no grid appeared, and proved the database digest was unchanged.
- 21 July 2026: Contextual recovery backed up all three imported connections, recreated only the Standalone DBCode Profile, preserved external extension, normal-editor, Keychain, and database boundaries, automatically reopened exactly one app process, and consumed its recovery result.
- 21 July 2026: The rebuilt signed artifact passed all 35 rendered checks and the final real-Keychain proof: licence persistence without another prompt, PostgreSQL read-only `3 / 75.00`, DuckDB `3 / 61.50`, Parquet `3 / 61.50`, and persistence after a complete quit and relaunch.
- 21 July 2026: A final proof-state regression check confirmed that regenerated manifest metadata refreshes the recorded manifest hash without discarding evidence for the unchanged signed app and release set. The current manifest is aligned with the passed five-check proof.
- 21 July 2026: Final relaunch-path hardening exposed and fixed a QA-only extension-root mismatch. The focused recovery regression passed, all 19 profile-migration tests passed, the rebuilt app passed static smoke, and the complete rendered suite passed through exact clean quit, profile-only recovery, and one automatic relaunch. The ticket returned to claimed until the current rebuilt artifact repeats the five manual checks.
- 21 July 2026: The user repeated all five checks after a complete quit and independent relaunch of the current rebuilt artifact. Licence and account state persisted without another Keychain prompt; PostgreSQL, DuckDB, Parquet, and persistence passed; `./script/proof_dbcode.sh finalize` and `./script/check_development.sh` both passed. The ticket is resolved.
- 21 July 2026: Implementation commit `904dddb` contains the migration, recovery, safety, proof, and rendered-test changes. The generated manifest now names that commit, static smoke still passes, and the passed proof remains bound to the unchanged artifact SHA-256 `81bc5e92ee19b7df9a045c546761233d4ae62cf119094f8e90a93a9b8fbd270e`.
