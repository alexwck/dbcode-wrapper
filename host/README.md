# DBCode Wrapper host

This directory is the small private overlay used to build the standalone macOS host. Code OSS is the application runtime. VSCodium supplies the repeatable macOS packaging scripts around that runtime. The project does not vendor either upstream source tree and never modifies DBCode.

## Build

On the approved Apple-silicon Mac, run:

```sh
./script/build_host.sh
```

That one command verifies the locked system toolchain, downloads and checks the pinned Node.js archive, resolves the exact VSCodium packaging and Code OSS runtime commits, applies the reviewed patch plan, creates the original icon, builds `darwin-arm64`, signs nested code from the inside out with the current user's persistent private signing identity, and writes:

- `dist/DBCode Wrapper.app`
- `dist/build-manifest.json`

The normal app uses the approved database-client redesign with three clear surfaces. `Connections` opens DBCode's card-based connection Home in the main canvas, while its adjacent menu keeps Profile Setup, Tunnels, Authentication Profiles, and conditional Active Streams inside connection management. `Database Explorer` shows only DBCode's connection and database-object tree. `Queries` groups DBCode History and Library, and Account stays on the right side of the database toolbar. SQL execution opens DBCode's own result editor beside the query in a wide window and below it in a narrow window. This placement is automatic: there are no result-position controls and no second Results panel. The wrapper removes empty editor regions and redundant Code OSS title actions without changing DBCode query tabs, messages, table editors, result grids, or webviews. Working DBCode-owned context actions remain available; the two non-working duplicate tree shortcuts are documented below.

`DBCode tools` keeps seven advanced routes without reopening the generic IDE: New DBCode Notebook, Start Python Kernel, Query Builder, DBCode-only settings, AI provider choice, AI API-key setup, and Show Scratch Files in Finder. It also provides `Check for Updates…`, which is a wrapper release action rather than a DBCode feature. Python and Jupyter are mandatory members of the locked runtime set, while the interpreter and kernel remain user-selected execution environments. The Finder action resolves DBCode's configured scratch path and uses the native Finder reveal API, avoiding the extension's broken external file-URL route. The notebook and Query Builder commands live only in this menu because the duplicate DBCode database-tree shortcuts do not provide a reliable forwarded-context contract. Model choice remains in DBCode's provider flow and settings. DBCode's automatic MCP provider and MCP settings remain available, while the manual HTTP lifecycle remains a separate compatibility gate.

On a fresh Finder launch, the focused first-run bridge runs before Profile Setup. It offers one explicit action for the exact seven-package Approved Release Set: unchanged DBCode plus the required Python/Jupyter runtime. Each package is obtained from its pinned Open VSX URLs and checked against the approved stable registry record, package size, SHA-256 record, embedded public key, Ed25519 signature, signature manifest, and VSIX manifest. Only verified VSIX files enter an owner-only cache, and the host CLI installs them into the Standalone DBCode Profile with extension-pack dependencies disabled. The exact installed versions are checked before the app offers one reload. This route does not expose an extension marketplace or silently choose a newer package.

After that reload, Profile Setup makes the Standalone DBCode Profile explicit. The user may start clean or choose a JSON or CSV connection inventory for review. The wrapper accepts only names, database types, hosts, ports, database names, usernames, SSL choices, and reviewed absolute local paths. It rejects credentials, secret-bearing URLs, private keys, licence data, and old connection identifiers before creating an owner-only temporary CSV. DBCode's unchanged Import Connections flow still owns source selection, custom field mapping, preview, confirmation, and the final import. Passwords are re-entered only through DBCode, and the lifetime Pro licence is activated normally in DBCode Account. Unsupported mappings are left out and added manually. Cancelling, finishing, or closing Profile Setup removes the temporary file.

A DuckDB filename stem containing a hyphen is never renamed to work around parser behaviour. Profile Setup leaves that connection out of the batch file and shows the exact installed DBCode version plus the read-only statement `SELECT 1 AS dbcode_wrapper_read_only_preflight;`. A passing check accepts that connection; a failure defers only that connection without moving or rewriting the database.

Profile Setup also contains the contextual `Back up and recreate profile…` recovery action. After explicit confirmation, DBCode Wrapper quits, waits for its app and extension-host processes to stop, moves only its user data and shared data into an owner-only backup, creates a fresh Standalone DBCode Profile with the managed settings, and reopens the app. The successful worker launches the executable inside the already validated app bundle so the exact profile paths survive the restart. The normal backup location is `~/Library/Application Support/DBCode Wrapper Profile Backups/<recovery-id>`. Recovery derives these locations from the active Standalone DBCode Profile and rejects mismatched inherited paths. Verified extensions under `~/.dbcode-wrapper/extensions`, normal VS Code or VSCodium data, macOS Keychain records, and database files are outside the moved paths. Temporary reviewed import data is deleted before recovery starts. If recreation fails, the operation restores moved profile folders when possible and otherwise keeps the owner-only backup with a failure notice instead of deleting it. A failed recovery stays closed; the user can inspect the backup before launching again.

`Open Data File…` is not presented as a working tool because the prior DBCode pair declared a custom data-file editor without registering its provider with Code OSS `1.126.0`. Connections remains available, but it is not claimed as feature-equivalent to direct CSV, Excel, Parquet, or Avro opening. Direct-file support stays as a separate 1.36.2 compatibility gate rather than being silently removed or falsely presented as working. Diagrams, table editors, export actions, History, Library, and other working object-specific commands stay on the DBCode object or grid where they make sense. The generic Command Palette, Extensions view, unrestricted settings, Explorer, Chat, and unrelated editor menus remain unavailable.

The independently authored focused-route policy lives in `host/dbcode-feature-policy.json`. The release lock records a canonical SHA-256 of the approved DBCode release's public contributions without checking copied vendor manifest content into this repository. After the official package is installed locally, `script/test_dbcode_feature_contract.sh` compares its public `package.json` with that digest and the policy. The rendered catalogue gate then opens DBCode's unchanged `dbcode.connections.add` workflow, confirms every counted New Connection item is present, and compares only counts and SHA-256 fingerprints with the exact-version snapshot. The wrapper keeps no database allowlist, supplies no database-type arguments, and does not store the raw vendor label list. A changed DBCode version, public contribution surface, or rendered catalogue therefore cannot silently reuse the current compatibility claim.

If no query is restored, the app opens `dbcode-wrapper/queries/scratch.sql` inside the current profile's global-storage folder. It creates that file only when missing and never overwrites its contents, so DBCode starts with a normal file-backed SQL editor without showing a connection prompt.

Project query files stay inside the redesigned query canvas. Use `Open SQL File…`, `⌘O`, Finder's Open With command, or drag an `.sql` file onto the app. The native picker and macOS document association accept SQL files only and open each selected file as a pinned query tab with its real filename. DuckDB, SQLite, Parquet, CSV, and other database or data files enter through DBCode Connections because they are data sources, not query documents. The wrapper does not expose a filesystem Explorer or generic project workbench.

The source and toolchain pins live in `host/release-lock.json`. The smaller app is not inherently more fragile: it removes source maps and unneeded built-ins, not DBCode or the extension-host APIs it uses. The real risk is changing DBCode or Code OSS independently. Production must therefore treat the exact Code OSS runtime, VSCodium packaging, and DBCode versions as one approved release set, rebuild it, compare the public contribution and connection-capability contracts, and pass the source, packaging, rendered, licence, representative database, persistence, size, and signature gates before promotion. PostgreSQL, DuckDB, Parquet, and the SQLite sample are bounded live fixtures, not a wrapper allowlist; every connection type contributed by the exact unchanged DBCode package must remain reachable. If a candidate DBCode version needs a removed built-in, `host/slimming-policy.json` provides the `all_built_ins` rollback before that release set can be approved.

Every new build is labelled `candidate`. Its canonical source-set ID covers the complete purpose-level Release Specification, wrapper sources, semantic patch plan, build scripts, mandatory runtime-extension digests, target, and profile schema. The external build manifest then adds the signed app digest to form the exact release-set ID, so two separately produced artifacts cannot overwrite one another's approval record. Building or running a proof never changes that candidate label. New candidates must pass the current strict Release Specification. Retained schema-2 and earlier schema-4 rollback sets may use the read-only historical adapter only when their original manifest contains the exact lock digest; the adapter keeps archived files unchanged, maps the pre-versioned schema-2 profile to baseline profile schema 1, and never creates an approval. The controlled-upgrade workflow owns the complete host/DBCode compatibility matrix and is the only workflow allowed to publish an approved local record or promote the app.

The build disables VSCodium's independent updater. A small status icon beside `DBCode active`, plus `DBCode tools` → `Check for Updates…`, reads three public records: Microsoft's official stable Code OSS GitHub release, the official stable VSCodium GitHub release, and DBCode's verified stable Open VSX record. Automatic checks reuse complete three-feed metadata for one day; the explicit menu action checks again immediately. An older two-feed cache is discarded and refreshed. Neither route sends profile, path, licence, database, connection, or credential data. The review view lists the Code OSS runtime, VSCodium packaging, and DBCode separately with installed and available versions, publication dates, and honest readiness states. Selecting a row opens the exact Microsoft or VSCodium GitHub tag, or the exact version page in DBCode's official changelog. Open VSX remains the verified source for DBCode's version and publication date.

A candidate is `Ready to install` only when its exact three-version release set has a complete local Approved Release Set record: target architecture, profile schema, Code OSS and VSCodium source commits, wrapper source and patch-plan digests, signed artifact, candidate-manifest and approval-attestation digests, DBCode package and signature digests, completed proof and automated-gate receipts, and approved compatibility state must all be present. Version strings alone are never enough. The app reads the history bundled with its build plus an optional private-profile approval file at `User/globalStorage/dbcode-wrapper.release-status/approved-release-sets.json`. The controlled-upgrade workflow can publish a completed approval without replacing the running app or waiting for the daily public-metadata cache to expire. Update discovery itself can only read that record. A transition from `Not tested` to `Ready to install` creates a new notice unless the user explicitly skipped that release set.

Review, Remind Later, and Skip This Version affect only local notice state. Manual review does not also raise the automatic prompt, and every completed check refreshes the status icon even when it started from the native macOS menu. Discovery never downloads, installs, quits, restarts, or relaunches the app. Promotion and rollback operate only on complete tested release sets. The matrix records `H0/D0`, `H0/D1`, `H1/D0`, and `H1/D1` separately, and all four must pass before promotion. This cannot guarantee that upstream releases never break compatibility, but it makes a mismatch visible before installation and keeps the known-good release available.

During a build, VSCodium requires the Code OSS checkout to be named `vscode` inside its generated work directory. That generated path is an upstream build contract, not a second product or permanent project folder. It lives under ignored `.build/` data and can be deleted at any time; the next full build recreates it.

The build follows VSCodium's official macOS flow: [VSCodium build documentation](https://github.com/VSCodium/vscodium/blob/master/docs/howto-build.md) and [stable macOS workflow](https://github.com/VSCodium/vscodium/blob/master/.github/workflows/stable-macos.yml).

## Run and verify

### Ongoing development without rebuilding

To run the last signed build immediately, use:

```sh
./script/run_host.sh
```

This command does not build VSCodium or Code OSS. It is the right loop for Appshot review and other feedback against the current signed checkpoint. Source-overlay changes are intentionally batched and become visible only after the next `./script/build_host.sh` checkpoint. A full build remains required before calling a changed host release verified.

Run the fast source contracts after each development change:

```sh
./script/check_development.sh
```

These checks do not compile or repackage the app. They catch overlay, identity, profile, query-entry, and redesign contract mistakes while changes are being batched.

That scripted launch uses the normal isolated profile and prepares the exact external runtime before opening the app. A normal Finder launch uses the in-app focused first-run bridge described above instead. Both routes use the same private paths:

- `~/Library/Application Support/DBCode Wrapper` for user data and logs
- `~/.dbcode-wrapper/extensions` for the exact verified DBCode, Jupyter, and Python runtime set
- `~/.dbcode-wrapper-shared` for shared storage

Because scripted and Finder launches use the same paths, the DBCode licence and saved connections remain available when the app is opened directly.

For production-shell diagnostics, run the same DBCode Wrapper bundle in the foreground with developer tools, extension-host inspection, and verbose logs. This does not restore the general Code OSS workbench:

```sh
./script/run_host.sh --debug
```

If DBCode behavior needs comparison with a general workbench, use a pinned stock VSCodium or VS Code installation as an external, disposable control. It is not part of this build, release manifest, update pair, or Keychain identity.

Run the static and independent-launch proof:

```sh
./script/smoke_host.sh
```

The smoke proof starts the app's own executable with a real SQL query path plus dedicated user-data, extension, and shared-data directories. It waits for a live renderer, verifies that the native host resolved the query path, rejects fatal helper or renderer errors, verifies that the app is a separate process even when VS Code or VSCodium is open, and confirms that the normal VS Code and VSCodium profiles did not change.

After a successful build, run the rendered production interaction checks:

```sh
./script/test_focused_shell_rendered.sh
```

The rendered check covers first-launch Profile Setup, private staging and cleanup, DBCode's real CSV source selection, file selection, custom field mapping, preview, confirmation, and imported connections, conditional DuckDB preflight, contextual profile backup and recreation, the DBCode-only chrome, card-based Connections Home, database-only Explorer, grouped connection and query routes, every retained Tools action, duplicate-route removal, native Database menus, DBCode-filtered settings, a real DBCode notebook with Python kernel execution, Query Builder, the diagram route, History, Library, the retained SQL context-command contract, empty-group cleanup, a real sample database and table, automatic wide and narrow DBCode result layouts, relaunch behavior, overflow, browser errors, and required extension-host logs. It installs the exact runtime set into `.build/qa/profile`, uses only generated user-data folders, and enables Chromium's mock Keychain so native password dialogs cannot block UI automation or reach the real macOS Keychain. Recovery assertions preserve external extension, normal-editor, and database sentinels while checking the old DBCode connections in the owner-only backup, their absence from the fresh profile, and exactly one automatic relaunch after successful recovery. The test handles DBCode's normal first-use Jupyter permission itself and proves the permission does not repeat. It never reads or writes the production profile. It writes ignored screenshots and a JSON report under `output/playwright/`.

During an update review, the narrower command below runs only the exact-version New Connection catalogue gate. It still uses an isolated generated profile and mock Keychain, and writes its separate ignored report to `output/playwright/ticket-22-connection-catalogue-report.json` without replacing the full rendered report. A pass proves catalogue preservation breadth; it does not replace the full rendered, representative live-database, notebook, licence, credential, persistence, and restart gates.

```sh
./script/test_focused_shell_rendered.sh --connection-catalogue-only
```

Run the licensed database and persistence proof with:

```sh
./script/proof_dbcode.sh launch
./script/proof_dbcode.sh quit
./script/proof_dbcode.sh relaunch
./script/proof_dbcode.sh record <check> <passed|failed> <observation>
./script/proof_dbcode.sh finalize
```

Finalization requires a complete initial launch, a linked quit, a relaunch, and seven fresh observations from that relaunch: activation, protected-credential re-entry, read-only update discovery, PostgreSQL, DuckDB, Parquet, and persistence. Use those exact check names with `record`: `activation`, `credential_reentry`, `update_discovery`, `postgresql`, `duckdb`, `parquet`, and `persistence`. These database checks are representative live fixtures; the separate contribution-preservation contract protects the complete connection catalogue exposed by the installed DBCode version. This is the real-Keychain gate; it must not use `--use-mock-keychain`. Once a live renderer exists, a manual proof session has no activation deadline, so first-run setup and Keychain approval are not interrupted. Closing without a new DBCode activation log still fails the run. The harness independently hashes the launched signed app, binds the proof to the exact release-set ID and candidate-manifest digest, checks focused-shell product state, verifies the fixture contents, and records the exact host, canonical ID-sorted extension inventory, profile roots, and active DBCode log. Regenerating only the manifest metadata refreshes that recorded manifest hash without discarding proof for the unchanged signed app and release set. This single-pair proof is evidence only; it does not mark the candidate approved or bypass the controlled compatibility matrix.

The Private Personal Release uses a persistent current-user self-signed identity. Strict signature checks prove artifact integrity, but the identity has no Apple Team ID and is not trusted by Gatekeeper. Automated UI tests never authorize it against the real Keychain. The real credential gate proves that **Always Allow** does not repeat when the exact same signed artifact quits and relaunches, and that the licence and saved credentials persist. Testing two distinct signed builds showed that a Code OSS host rebuild can still require one new Safe Storage approval because macOS records the new code hash; an external DBCode-only update does not change the host signature. Installation on another owned Mac therefore includes checksum verification and macOS **Open Anyway**, and each distinct downloaded host release may need that manual approval again. The project does not use paid Developer ID signing or Apple notarization and must not claim those protections.

The previous approved release remains addressable in `host/approved-release-history.json`. `./script/prepare_release_rollback.sh code-oss-1.126.0-dbcode-1.36.1` retains its exact app, manifest, extension root, and private profile under ignored build data; the verifier checks every digest and the preview command opens that set from a disposable profile without replacing the current app. The controlled-upgrade workflow also owns atomic activation, restart health checking, and complete restoration so host and extension versions cannot be mixed.
