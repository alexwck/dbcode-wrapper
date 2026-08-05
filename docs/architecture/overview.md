# Architecture overview

DBCode Wrapper is a focused macOS product around a compatible Code OSS extension host. It does not modify DBCode or replace DBCode's query and live-result workflows. One explicit local BSON Result Viewer presents JSON that the user chooses to copy or open.

## Product and upstream roles

```text
VSCodium                    Wrapper repository
macOS build machinery       identity, patches, policy, tests
          \                 /
           \               /
            pinned Code OSS
          extension-host runtime
                    │
                    ▼
          DBCode Wrapper.app
                    │
                    ▼
       private current-user profile
      ┌─────────────┼─────────────┐
      │             │             │
 unchanged DBCode  Python/Jupyter  user state
 database client   runtime         and Keychain
```

- VSCodium is a reproducible build and packaging adapter. It is not a second application runtime.
- Code OSS is the runtime needed by the unchanged extension.
- Open VSX is the verified package source for DBCode and the required Python/Jupyter runtime extensions.
- DBCode owns database connections, dialects, object browsing, editors, results, notebooks, AI, MCP, account, and licensing.
- The wrapper owns the standalone application identity, focused navigation, profile isolation, the explicit local BSON Result Viewer, compatibility gates, signing, update approval, rollback, and host-only packaging and publishing.
- Every DBCode view in the focused sidebar is persistent workspace navigation: editor, canvas, result-grid, and Escape interactions do not dismiss it. Choosing the action for the visible drawer again collapses it, and choosing it again restores it. Another DBCode action can replace the current view. Account is the only temporary drawer and still closes on an outside click or Escape.
- DBCode's own live result editor opens below the query at every window width. The wrapper sets the public result-location preference and does not create another live result panel. The separate local BSON Result Viewer accepts only explicit clipboard or file input and never calls DBCode or a database.

## Deep modules

The maintained architecture concentrates cross-cutting rules behind twelve seams:

1. **Release Specification** validates `host/release-lock.json` and returns purpose-level build, extension, profile/product, and identity records. Host Configuration keeps DBCode and Python/Jupyter package details inside the extension record instead of exposing a second set of package globals. Its profile record owns the application, bundle, profile-folder, query-storage, and profile-schema identity. New candidates use the current strict schema. A separate read-only adapter can interpret supported frozen records only when the retained build manifest binds their exact lock digest; it never turns retained state into a new candidate or invents approval.
2. **Release Source Snapshot** proves that the complete release input came from one clean immutable Git commit. The build materializes that commit in a temporary checkout and runs compilation and assembly there. The manifest and host package bind the commit, tree, host-and-script digest, and release-lock digest. The wrapper source digest covers production assembly adapters, including the Runtime Extension Set, and excludes test-only helpers.
3. **Compiled Host Cache** separates expensive Code OSS compilation from release assembly. Its content-addressed input covers upstream revisions, the toolchain, active Release Specification code, compile-time product values, the first-class Code OSS overlay, small upstream patches, icon, and active slimming choices. The Patch Plan supplies a canonical build-relevant projection, so changes to its plain-English purpose and touched-area descriptions do not invalidate unchanged compiled bytes. Cache integrity covers bytes, links, and executable modes. Its receipt records the actual compiler environment. DBCode package metadata, profile-only names, the profile schema, dated slimming measurements, and assembly-only wrapper files do not change that ID. Query storage names do because the focused shell embeds them in the compiled product record.
4. **Approved Release Set** owns canonical source and artifact identity, approval records, history lookup, update matching, and rollback compatibility. Its prompt-free approval adapter receives validated purpose records from the Release Specification and Host Release modules, then binds them to the host-only package manifest, independent mounted verification, and an explicit exact-ID confirmation. It writes generated records only; installation and production-profile changes remain separate transitions. The read-only Update Status service keeps polling, cache, review decisions, and release-set matching behind one small maintained interface.
5. **Profile Layout** consumes one generated Release Specification identity and returns the same validated Standalone DBCode Profile record to shell and JavaScript adapters. It supports only the current-user `default` profile and one persistent generated `qa` profile. It fails closed when the identity is missing, linked, malformed, unsafe, stale, or different from the active layout.
6. **Profile Setup** owns the first-use action order, reviewed import plan, temporary-file cleanup, DuckDB preflight, completion state, cancellation, and recovery handoff. A small command router registers Runtime Setup and Profile Setup before startup state is known, then sends Profile Setup to its required runtime prerequisite when needed. Both first-run webviews share one content-security, nonce, escaping, and action-message policy. The host adapter alone calls VS Code, DBCode, the clipboard, the filesystem, time, process spawning, and quit commands. The Profile Recovery Worker exposes one `run` interface; process waiting, clock, random identity, outcome files, and relaunch stay behind its operating-system adapter.
7. **Host Session** owns one application lifecycle: process start, renderer readiness, DBCode readiness, logs, timeout, normal user exit, and failure cleanup. The normal shell launcher passes one record containing only launch-specific values. Host Session creates and validates the stable policy beside the lifecycle that executes it. Its command adapter exposes only `run`; saved-session stop modes and policy helpers are not separate interfaces.
8. **Patch Plan** applies the maintained Code OSS and VSCodium changes by semantic seam. Small diffs against existing upstream files remain patches. Wrapper-owned focused-shell TypeScript and CSS live under `host/code-oss-overlay/` as normal source files. VSCodium applies official and wrapper patches, materializes those source files, and then verifies the approved prepared-tree digest before Code OSS compilation starts. The same module owns the canonical build-relevant projection consumed by the Compiled Host Cache; descriptive plan wording remains outside that identity.
9. **Focused Runtime Setup** derives one public package-and-key record from the Release Specification. Its Open VSX Package Verifier owns the runtime record projection, canonical package selection, installed identity, registry identity, engine compatibility, sizes, digests, key binding, Ed25519 signatures, archive safety, signature manifests, and VSIX identity. One Runtime Extension Set adapter writes or checks that exact record. Finder setup, assembly, release verification, and scripted preparation pass purpose-level records to these interfaces; they do not repeat the package field list or security rules. On a fresh Finder launch the setup downloads only the exact DBCode and Python/Jupyter set, installs verified packages outside the app with extension-pack dependencies disabled, and reloads only after the managed inventory matches.
10. **Host Release** binds one annotated source tag, approved release lock, signed host manifest, prompt-free automated acceptance report, and host-only DMG. `script/release_host.sh` is the owner-facing task: `plan` reports the current source, derived paths, and structured preparation readiness; `prepare` rejects blocked branch, unrelated working-tree changes, or tag state before taking the checkpoint lease, then holds that kernel-backed lease while it checks signing, builds or reuses the exact Host, runs static and one-profile rendered smoke, performs final acceptance, tags, packages, independently verifies, and approves; `publish --publish` is the separate explicit publication step. Build and verification children inherit the lease, so it remains held until the last user exits. Assembly writes a complete signed app and manifest to a fixed candidate under `.build/assembly` before replacing `dist/`; a fixed previous path lets the next owner recover an interrupted promotion. Standalone readers hold the same lease for their full lifetime. Final acceptance re-enters the manifest's materialized source and reruns the fast source and static-smoke gates instead of trusting detached logs. A resumed task revalidates all five package files and the approval's compatibility and verification digests instead of trusting directory presence. The packager performs one full validation and creates a digest-bound release context for metadata. Its staging copy may reuse that context only while the app digest, signature, identity, architecture, and notices still match. The independent verifier does not trust that shortcut: it mounts the DMG and creates its own fully validated context. Both paths share one compatibility-record constructor, while the install-guide renderer remains separate user-facing policy. A separate approval command consumes the final package evidence without launching, installing, or touching the production profile. The publisher uploads only the DMG and checksum as a normal GitHub release, then verifies public state, sizes, and digests. Read-only compatibility adapters support retained rollback records without defining another release path.
11. **Generated Workspace Retention** registers build coordination, staged assembly, source work, smoke, rendered, retained evidence, rollback, cache, acceptance, current Host Release, expired, and unknown roots in one inspectable policy. Each root is classified by its current artifact purpose and explicit expiry, not by an old issue or workflow name. The module measures only deliberately expired output, reports protected and unregistered output without traversing it, and keeps cleanup as a dry run by default. An explicit apply can remove one exact validated expired path without a prompt; it cannot apply a class.
12. **Local BSON Result Viewer** owns one lossless display-model interface for explicitly supplied JSON. Its pure parser recognizes exact MongoDB Extended JSON wrappers, preserves the original raw text in memory, keeps ordinary strings distinct, records readable values with separate BSON or JSON types, and produces plain key-value JSON without supported BSON type wrappers. A thin host adapter reads the clipboard or one selected file only after the matching command, enforces input and node limits, and sends the model to a nonce-protected webview. The webview uses text nodes for result data, keeps search text and input out of persisted state, clears its in-memory payload on close, opens in Tree mode, and also provides bounded Table and JSON modes. It does not inspect DBCode, connect to a database, poll, use the network, send telemetry, or write results.

Tests cross the same interfaces as production callers. Compatibility adapters keep established command-line workflows stable while implementation details move behind the seams.

Active slimming and rollback controls remain machine-readable in `host/slimming-policy.json`. Static Host Smoke enforces the installed-size limit, zero source maps, the exact built-in inventory, and the absence of embedded DBCode without inspecting the private external runtime. Dated size, file-count, and startup measurements live in [`host-slimming-measurement-2026-07-21.md`](https://github.com/alexwck/dbcode-wrapper/blob/37003175d654b33c7ad97222bdb49ee614665f53/docs/architecture/host-slimming-measurement-2026-07-21.md), so historical observations cannot change a Compiled Host identity.

Build and verification workflows resolve or assert their ignored output roots through the Generated Workspace Retention module. The task command reports path, size status, class, reason, owner, and deletion eligibility. Only output explicitly registered as expired, including descendants of the expired root, can be selected for a plan. Apply requires one exact path. It repeats path, link, and size validation immediately before removal and reports whether the path is gone. Rebuildable work, reusable caches, active evidence, private profiles, unknown paths, symlinked paths, broad roots, rollback backups, final transfer assets, and class-wide selections remain protected. Protected artifacts are not traversed for size. Callers use the module's normalized absolute path, bootstrap uses a small shell guard before pinned Node exists, and production evidence cannot use the test-only temporary-output gate. Rollback worktrees keep their own validated build directories instead of linking to the main checkout's caches.

## Connection capability

PostgreSQL, DuckDB, Parquet, SQLite, and Python notebooks are practical fixtures that can be exercised locally. They are not an allowlist. DBCode's official supported-databases catalogue currently contains more than 80 databases, services, cloud targets, and data-file formats. The wrapper must not filter that catalogue or maintain a competing static list.

New DBCode-owned capabilities are recorded without becoming wrapper implementations. If a DBCode release adds a stored-routine debugger contribution, for example, the wrapper keeps the DBCode-owned route. Normal deployment does not start a database or wait for a person to drive that debugger. A developer may test the route separately with their own disposable database when needed.

A new DBCode release may add or remove connection types. The release gate therefore uses two independent checks. First, it binds the exact public package contribution digest and the unchanged `dbcode.connections.add` command to the Approved Release Set. Second, an isolated mock-Keychain launch opens DBCode's real New Connection picker and reduces its counted sections and normalized label set to counts and SHA-256 fingerprints. Raw vendor labels never enter Git or the rendered report.

The wrapper passes no arguments into that DBCode-owned entry point and does not transform the catalogue. If the extension version, contribution digest, section shape, item count, or label fingerprint changes, the candidate stops for focused review. PostgreSQL, DuckDB, Parquet, SQLite, and Python remain optional depth checks; they do not define the breadth of supported connections or block normal deployment. Actual connectivity can still depend on the target server or service, network, credentials, operating system, optional drivers, and the exact installed DBCode version.

## Release flow

```text
current release-source commit and version-tag state
        │
        ▼
read-only plan reports preparation readiness
        │
        ▼
prepare validates main, cleanliness, and tag identity
        │
        ▼
release_host.sh prepare acquires one dist checkpoint lease
        │
        ├─ prompt-free signing-status check
        │
        ▼
materialized temporary checkout
        │
        ▼
release specification → Compiled Host input ID
        │
        ├─ cache hit → reuse exact Compiled Host
        └─ cache miss → prepare and compile Code OSS
        │
        ▼
assemble wrapper records and extensions in a private stage
        │
        ▼
sign → manifest → promote complete app + manifest to dist/
        │
        ▼
candidate Approved Release Set
        │
        ├─ source and package contracts
        ├─ static signed-host smoke
        └─ one-profile rendered focused-shell smoke
        │
        ▼
prompt-free acceptance report
        │
        ▼
annotated source tag → host-only DMG → independent mounted verification
        │
        ▼
prompt-free approval
  (no install or production-profile write)
        │
        ▼
commit the one approval-history change
        │
        ▼
normal GitHub release: DMG + checksum
        │
        ▼
verify public state, server sizes, and digests
```

Code OSS runtime, VSCodium packaging, and DBCode updates are discovered separately but packaged as one exact release set. Every release commit creates a new audited source snapshot. Only compilation inputs create a new Compiled Host ID, so a DBCode-only bump can reuse the unchanged host and still receive a new signed artifact, manifest, and acceptance report. Source permissions are reduced to Git's regular-or-executable distinction, so the same clean commit keeps the same ID under a private build umask.

Rendered automation uses one persistent generated QA profile. It does not run first-use migration, profile recovery, Python kernels, SQL execution, model calls, secret entry, or other work that can open a person-controlled prompt. macOS permissions and DBCode sign-in or licence choices remain part of normal app use, outside automated deployment checks.

The first-run setup and Host Release do not weaken that rule. The setup record is generated from the same exact extension specification and is hashed into the signed build manifest. The package command refuses an app without that evidence. It also refuses a lightweight tag, a tag at a different source revision, a changed release lock, a stripped acceptance report, colliding source or artifact filenames, or a DMG at or above GitHub's 2 GiB asset limit.

The DMG verifier does not trust the packager's staging tree. It checks the external checksum, mounts the image below a private temporary root, confirms the volume is read-only, scans the mounted tree, recomputes the app digest, verifies nested signatures and the designated requirement, compares the source tag and full compatibility record, and writes a sanitized receipt. Production task tests exercise both commands through the same interfaces with a synthetic signed app and mock macOS disk-image tools.

## Privacy flow

The public repository contains wrapper-authored source, policies, patches, tests, notices, and sanitized issue evidence. DBCode packages, licences, credentials, profiles, databases, Keychain records, signing secrets, built apps, and DMGs remain outside Git. A normal published release contains only the independently verified host DMG and checksum. DBCode stays external and is obtained from its official source by each user under their own licence. Compatibility manifests, verification receipts, and other generated evidence remain local and contain no local home path or temporary path.

The Local BSON Result Viewer adds no automatic data flow. A user must choose the clipboard command or select one local file. The host parses that text locally and passes a display model to its own webview; closing the panel releases the current payload. Only the view mode and parsed-string preference may persist. Raw input, displayed values, file paths, and search text are not stored, logged, sent through telemetry, or transmitted over the network.
