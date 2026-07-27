# DBCode Wrapper host

This directory is the small private overlay used to build the standalone macOS host. Code OSS is the application runtime. VSCodium supplies the repeatable macOS packaging scripts around that runtime. The project does not vendor either upstream source tree and never modifies DBCode.

## Build

Commit the complete release input so the working tree is clean. On the approved Apple-silicon Mac, run:

```sh
./script/build_host.sh
```

That command records the checked-out Git commit as the immutable Release Source Snapshot, copies that commit to a temporary clean checkout, and reads all build and assembly inputs there. It then calculates a Compiled Host input ID from the exact Code OSS, VSCodium, toolchain, patch, product, icon, and slimming inputs. It keeps Git's executable-file distinction but ignores local read and write permission differences.

On a cache miss, it checks the compiler toolchain, prepares the pinned upstream sources, and compiles `darwin-arm64`. On a cache hit, including a DBCode-only version bump, it reuses the verified unchanged host without rerunning compiler-only preflights. It then adds the current wrapper extensions and release records, signs nested code from the inside out with the current user's persistent private signing identity, and writes:

- `dist/DBCode Wrapper.app`
- `dist/build-manifest.json`

Changed cached bytes, links, or executable modes fail validation. A normal damaged directory is retained under the ignored cache for investigation and rebuilt. The cache receipt keeps the environment that performed the compilation, so the final manifest does not mislabel the later assembly machine as the compiler. The manifest records schema 6, the source snapshot, Compiled Host input ID, cache result, and signed app digest.

The normal app uses the approved database-client redesign with three clear surfaces. `Connections` opens DBCode's card-based connection Home in the main canvas, while its adjacent menu keeps Profile Setup, Tunnels, Authentication Profiles, and conditional Active Streams inside connection management. `Database Explorer` shows only DBCode's connection and database-object tree. It remains open while the user works in a query editor, the main canvas, or a DBCode result grid. Only its own toolbar action toggles it closed; another DBCode action replaces it when that action uses the same sidebar. Temporary DBCode drawers dismiss on an outside click or Escape. `Queries` groups DBCode History and Library, and Account stays on the right side of the database toolbar. SQL execution opens DBCode's own result editor beside the query in a wide window and below it in a narrow window. This placement is automatic: there are no result-position controls and no second Results panel. The wrapper removes empty editor regions and redundant Code OSS title actions without changing DBCode query tabs, messages, table editors, result grids, or webviews. Working DBCode-owned context actions remain available; the two non-working duplicate tree shortcuts are documented below.

`DBCode tools` keeps the advanced DBCode routes without reopening the generic IDE: New DBCode Notebook, Start Python Kernel, Query Builder, DBCode-only settings, AI provider choice, Custom Model settings, Custom Model API-key setup, and Show Scratch Files in Finder. It also provides `Check for Updates…`, which is a wrapper release action rather than a DBCode feature. Python and Jupyter are mandatory members of the locked runtime set, while the interpreter and kernel remain user-selected execution environments. The Finder action resolves DBCode's configured scratch path and uses the native Finder reveal API, avoiding the extension's broken external file-URL route. The notebook and Query Builder commands live only in this menu because the duplicate DBCode database-tree shortcuts do not provide a reliable forwarded-context contract. Model choice remains in DBCode's provider flow and settings. DBCode's automatic MCP provider and MCP settings remain available, while the manual HTTP lifecycle remains a separate compatibility gate.

On a fresh Finder launch, the focused first-run bridge runs before Profile Setup. It offers one explicit action for the exact seven-package Approved Release Set: unchanged DBCode plus the required Python/Jupyter runtime. Each package is obtained from its pinned Open VSX URLs and checked against the approved stable registry record, package size, SHA-256 record, embedded public key, Ed25519 signature, signature manifest, and VSIX manifest. Only verified VSIX files enter an owner-only cache, and the host CLI installs them into the Standalone DBCode Profile with extension-pack dependencies disabled. The exact installed versions are checked before the app offers one reload. This route does not expose an extension marketplace or silently choose a newer package.

After that reload, Profile Setup makes the Standalone DBCode Profile explicit. The user may start clean or choose a JSON or CSV connection inventory for review. The wrapper accepts only names, database types, hosts, ports, database names, usernames, SSL choices, and reviewed absolute local paths. It rejects credentials, secret-bearing URLs, private keys, licence data, and old connection identifiers before creating an owner-only temporary CSV. DBCode's unchanged Import Connections flow still owns source selection, custom field mapping, preview, confirmation, and the final import. Passwords are re-entered only through DBCode, and the lifetime Pro licence is activated normally in DBCode Account. Unsupported mappings are left out and added manually. Cancelling, finishing, or closing Profile Setup removes the temporary file.

A DuckDB filename stem containing a hyphen is never renamed to work around parser behaviour. Profile Setup leaves that connection out of the batch file and shows the exact installed DBCode version plus the read-only statement `SELECT 1 AS dbcode_wrapper_read_only_preflight;`. A passing check accepts that connection; a failure defers only that connection without moving or rewriting the database.

Profile Setup also contains the contextual `Back up and recreate profile…` recovery action. After explicit confirmation, DBCode Wrapper quits, waits for its app and extension-host processes to stop, moves only its user data and shared data into an owner-only backup, creates a fresh Standalone DBCode Profile with the managed settings, and reopens the app. The successful worker launches the executable inside the already validated app bundle so the exact profile paths survive the restart. The normal backup location is `~/Library/Application Support/DBCode Wrapper Profile Backups/<recovery-id>`. Recovery derives these locations from the active Standalone DBCode Profile and rejects mismatched inherited paths. Verified extensions under `~/.dbcode-wrapper/extensions`, normal VS Code or VSCodium data, macOS Keychain records, and database files are outside the moved paths. Temporary reviewed import data is deleted before recovery starts. If recreation fails, the operation restores moved profile folders when possible and otherwise keeps the owner-only backup with a failure notice instead of deleting it. A failed recovery stays closed; the user can inspect the backup before launching again.

`Open Data File…` is not presented as a working tool because the prior DBCode pair declared a custom data-file editor without registering its provider with Code OSS `1.126.0`. Connections remains available, but it is not claimed as feature-equivalent to direct CSV, Excel, Parquet, or Avro opening. Direct-file support stays as a separate DBCode `1.36.4` candidate compatibility gate rather than being silently removed or falsely presented as working. Diagrams, table editors, export actions, History, Library, and other working object-specific commands stay on the DBCode object or grid where they make sense. The generic Command Palette, Extensions view, unrestricted settings, Explorer, Chat, and unrelated editor menus remain unavailable.

The independently authored focused-route policy lives in `host/dbcode-feature-policy.json`. The release lock records a canonical SHA-256 of the approved DBCode release's public contributions without checking copied vendor manifest content into this repository. After the official package is installed locally, `script/test_dbcode_feature_contract.sh` compares its public `package.json` with that digest and the policy. The rendered catalogue gate then opens DBCode's unchanged `dbcode.connections.add` workflow, confirms every counted New Connection item is present, and compares only counts and SHA-256 fingerprints with the exact-version snapshot. The wrapper keeps no database allowlist, supplies no database-type arguments, and does not store the raw vendor label list. A changed DBCode version, public contribution surface, or rendered catalogue therefore cannot silently reuse the current compatibility claim.

If no query is restored, the app opens `dbcode-wrapper/queries/scratch.sql` inside the current profile's global-storage folder. It creates that file only when missing and never overwrites its contents, so DBCode starts with a normal file-backed SQL editor without showing a connection prompt.

Project query files stay inside the redesigned query canvas. Use `Open SQL File…`, `⌘O`, Finder's Open With command, or drag an `.sql` file onto the app. The native picker and macOS document association accept SQL files only and open each selected file as a pinned query tab with its real filename. DuckDB, SQLite, Parquet, CSV, and other database or data files enter through DBCode Connections because they are data sources, not query documents. The wrapper does not expose a filesystem Explorer or generic project workbench.

The source and toolchain pins live in `host/release-lock.json`. The smaller app removes source maps and unneeded built-ins, not DBCode or the extension-host APIs it uses. Production treats the exact Code OSS runtime, VSCodium packaging, DBCode version, extension inventory, and signed app as one release set. The normal gate checks source policy, package identity, signatures, the focused shell, and the unchanged New Connection catalogue without using a live account, database, kernel, model, or secret. PostgreSQL, DuckDB, Parquet, and SQLite fixtures remain available for focused diagnostics, but they are not a wrapper allowlist or a deployment requirement. If a candidate DBCode version needs a removed built-in, `host/slimming-policy.json` provides the `all_built_ins` rollback.

Every new build is labelled `candidate`. Its source-set ID covers the Release Specification, wrapper sources, semantic patch plan, build scripts, mandatory runtime-extension digests, target, and profile schema. The build manifest adds the signed app digest to form the exact release-set ID. New candidates use the current strict Release Specification. Frozen older release records remain readable through a read-only historical adapter, but they do not define the current deployment process.

The build disables VSCodium's independent updater. A small status icon beside `DBCode active`, plus `DBCode tools` → `Check for Updates…`, reads three public records: Microsoft's official stable Code OSS GitHub release, the official stable VSCodium GitHub release, and DBCode's verified stable Open VSX record. Automatic checks reuse complete three-feed metadata for one day; the explicit menu action checks again immediately. An older two-feed cache is discarded and refreshed. Neither route sends profile, path, licence, database, connection, or credential data. The review view lists the Code OSS runtime, VSCodium packaging, and DBCode separately with installed and available versions, publication dates, and honest readiness states. Selecting a row opens the exact Microsoft or VSCodium GitHub tag, or the exact version page in DBCode's official changelog. Open VSX remains the verified source for DBCode's version and publication date.

A candidate is `Ready to install` only when its exact release set has a prompt-free acceptance report bound to the source tag, release lock, build manifest, app digest, signature, extension inventory, development checks, static smoke, and one-profile rendered smoke. Version strings alone are never enough. The app reads the approved history bundled with its build plus an optional private-profile record. Update discovery can read that state but cannot approve or install a release.

Review, Remind Later, and Skip This Version affect only local notice state. Manual review does not also raise the automatic prompt, and every completed check refreshes the status icon even when it started from the native macOS menu. Discovery never downloads, installs, quits, restarts, or relaunches the app. The previous known-good package remains available for rollback.

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

Run the static signed-host smoke:

```sh
./script/smoke_host.sh
```

The smoke verifies the signed bundle, application identity, SQL document association, runtime setup manifest, extension inventory, release identity, and source digests without launching the app or creating another profile. The rendered check below owns the single automated application launch.

After a successful build, run the rendered production interaction checks:

```sh
./script/test_focused_shell_rendered.sh
```

This command reuses one persistent generated profile at `.build/qa/profile`. It checks the focused shell, Connections Home, the exact-version New Connection catalogue, Database Explorer behaviour, retained DBCode Tools routes, SQL-file opening, drawer dismissal, renderer errors, and current extension-host logs. It does not activate terms-gated DBCode commands, reset the profile, or run first-launch migration and recovery.

The smoke deliberately does not start Python, execute SQL, call a model, enter an API key, accept DBCode terms, sign in, or approve a macOS prompt. Those are normal user actions, not deployment tests. The command uses Chromium's mock Keychain and never reads or writes the production profile. Screenshots and JSON reports stay in ignored generated output.

During an update review, the narrower command below runs only the exact-version New Connection catalogue gate. It uses the same persistent QA profile and mock Keychain, and writes a separate ignored report without replacing the normal rendered report. A pass proves catalogue preservation breadth; it does not claim live database, kernel, licence, credential, or external-service behaviour.

```sh
./script/test_focused_shell_rendered.sh --connection-catalogue-only
```

The normal deployment path ends with `verify_fast_release.sh`, which re-enters the manifest's exact source and reruns the automated source and static-smoke gates before using the matching one-profile rendered report. It does not require licence, Keychain, database, debugger, or persistence observations.

The Private Personal Release uses a persistent current-user self-signed identity. Strict signature checks prove artifact integrity, but the identity has no Apple Team ID and is not trusted by Gatekeeper. Automated tests never authorize it against the real Keychain. Installation on another owned Mac therefore includes checksum verification and macOS **Open Anyway**, and normal use may ask for Safe Storage approval. These prompts are setup choices, not deployment tests. The project does not use paid Developer ID signing or Apple notarization and must not claim those protections.

The previous approved release remains addressable in `host/approved-release-history.json`. `./script/prepare_release_rollback.sh code-oss-1.126.0-dbcode-1.36.1` retains its exact app, manifest, extension root, and private profile under ignored build data; the verifier checks every digest and the preview command opens that set from a disposable profile without replacing the current app. The controlled-upgrade workflow also owns atomic activation, restart health checking, and complete restoration so host and extension versions cannot be mixed.
