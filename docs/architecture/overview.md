# Architecture overview

DBCode Wrapper is a focused macOS product around a compatible Code OSS extension host. It does not reimplement or modify DBCode.

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
- The wrapper owns the standalone application identity, focused navigation, profile isolation, compatibility gates, signing, update approval, rollback, and personal packaging.
- Database Explorer is the focused shell's persistent workspace navigation: editor, canvas, result-grid, and Escape interactions do not dismiss it. Its direct toolbar action toggles it, while another DBCode action can replace it in the shared sidebar. Other DBCode-only drawers remain temporary.

## Deep modules

The maintained architecture concentrates cross-cutting rules behind ten seams:

1. **Release Specification** validates `host/release-lock.json` and returns purpose-level build, extension, profile/product, and identity records. New candidates use the current strict schema. A separate read-only adapter can interpret supported frozen schema-2 and schema-4 records only when the retained build manifest binds their exact lock digest; it never turns historical state into a new candidate or invents approval.
2. **Release Source Snapshot** proves that the complete release input came from one clean immutable Git commit. The build materializes that commit in a temporary checkout and runs compilation and assembly there. The manifest and private package bind the commit, tree, host-and-script digest, and release-lock digest.
3. **Compiled Host Cache** separates expensive Code OSS compilation from release assembly. Its content-addressed input covers upstream revisions, the toolchain, active Release Specification code, compile-time product values, patches, icon, and slimming choices. Cache integrity covers bytes, links, and executable modes. Its receipt records the actual compiler environment. DBCode package metadata and assembly-only wrapper files do not change that ID.
4. **Approved Release Set** owns canonical source and artifact identity, approval records, history lookup, update matching, and rollback compatibility. Its prompt-free approval adapter receives validated purpose records from the Release Specification and Private Personal Release modules, then binds them to the host-only package manifest, independent mounted verification, and an explicit exact-ID confirmation. It writes generated records only; installation and production-profile changes remain separate transitions.
5. **Profile Layout** returns one validated record for every Standalone DBCode Profile path used by shell and JavaScript adapters.
6. **Host Session** owns one application lifecycle: process start, renderer readiness, DBCode readiness, logs, timeout, and complete quit.
7. **Patch Plan** applies the maintained Code OSS and VSCodium overlay by semantic seam and verifies the resulting source tree.
8. **Focused Runtime Setup** derives one public package-and-key record from the Release Specification. On a fresh Finder launch it downloads only that exact DBCode and Python/Jupyter set, verifies every acquisition boundary, installs outside the app with extension-pack dependencies disabled, and reloads only after the managed inventory matches.
9. **Private Personal Release** binds one annotated source tag, approved release lock, signed host manifest, prompt-free automated acceptance report, and host-only DMG. Final acceptance re-enters the manifest's materialized source and reruns the fast source and static-smoke gates instead of trusting detached logs. Its task-level packager and independent verifier share one compatibility-record constructor, while the install-guide renderer remains separate user-facing policy. A separate approval command consumes the final package evidence and writes a three-file approval bundle without launching, installing, or touching the production profile. Older real-profile records remain readable for compatibility, but their manual evidence generators are no longer maintained.
10. **Generated Workspace Retention** registers build, smoke, rendered, historical proof, controlled-upgrade, rollback, cache, acceptance, and private-release roots in one inspectable policy. It measures only deliberately expired output, reports protected and unregistered output without traversing it, and produces only explicit dry-run cleanup plans.

Tests cross the same interfaces as production callers. Compatibility adapters keep established command-line workflows stable while implementation details move behind the seams.

Build and verification workflows resolve or assert their ignored output roots through the Generated Workspace Retention module. The task command reports path, size status, class, reason, owner, and deletion eligibility. Only output deliberately placed under the expired root can be selected for a plan. Rebuildable work, reusable caches, active evidence, private profiles, unknown paths, symlinked paths, broad roots, rollback backups, and final transfer assets remain protected until an owning workflow explicitly records expiry. Protected artifacts are not traversed for size. Callers use the module's normalized absolute path, bootstrap uses a small shell guard before pinned Node exists, and production evidence cannot use the test-only temporary-output gate. Rollback worktrees keep their own validated build directories instead of linking to the main checkout's caches. The first implementation has no mutation mode.

## Connection capability

PostgreSQL, DuckDB, Parquet, SQLite, and Python notebooks are practical fixtures that can be exercised locally. They are not an allowlist. DBCode's official supported-databases catalogue currently contains more than 80 databases, services, cloud targets, and data-file formats. The wrapper must not filter that catalogue or maintain a competing static list.

New DBCode-owned capabilities are recorded without becoming wrapper implementations. DBCode `1.36.4`, for example, adds a stored-routine debugger contribution. The wrapper keeps the DBCode-owned route, but normal deployment does not start a database or wait for a person to drive a debugger. A developer may test that route separately with their own disposable database when needed.

A new DBCode release may add or remove connection types. The release gate therefore uses two independent checks. First, it binds the exact public package contribution digest and the unchanged `dbcode.connections.add` command to the Approved Release Set. Second, an isolated mock-Keychain launch opens DBCode's real New Connection picker and reduces its counted sections and normalized label set to counts and SHA-256 fingerprints. Raw vendor labels never enter Git or the rendered report.

The wrapper passes no arguments into that DBCode-owned entry point and does not transform the catalogue. If the extension version, contribution digest, section shape, item count, or label fingerprint changes, the candidate stops for focused review. PostgreSQL, DuckDB, Parquet, SQLite, and Python remain optional depth checks; they do not define the breadth of supported connections or block normal deployment. Actual connectivity can still depend on the target server or service, network, credentials, operating system, optional drivers, and the exact installed DBCode version.

## Release flow

```text
clean immutable release-source commit
        │
        ▼
materialized temporary checkout
        │
        ▼
release specification → Compiled Host input ID
        │
        ├─ cache hit ───────────────────────┐
        └─ cache miss → prepare → compile ──┤
                                           ▼
                     assemble wrapper records and extensions
                                           │
                                           ▼
                                     sign → manifest
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
prompt-free approval bundle
  (no install or production-profile write)
```

Code OSS runtime, VSCodium packaging, and DBCode updates are discovered separately but packaged as one exact release set. Every release commit creates a new audited source snapshot. Only compilation inputs create a new Compiled Host ID, so a DBCode-only bump can reuse the unchanged host and still receive a new signed artifact, manifest, and acceptance report. Source permissions are reduced to Git's regular-or-executable distinction, so the same clean commit keeps the same ID under a private build umask.

Rendered automation uses one persistent generated QA profile. It does not run first-use migration, profile recovery, Python kernels, SQL execution, model calls, secret entry, or other work that can open a person-controlled prompt. macOS permissions and DBCode sign-in or licence choices remain part of normal app use, outside automated deployment checks.

The first-run setup and Private Personal Release do not weaken that rule. The setup record is generated from the same exact extension specification and is hashed into the signed build manifest. The package command refuses an app without that evidence. It also refuses a lightweight tag, a tag at a different source revision, a changed release lock, a stripped acceptance report, colliding source or artifact filenames, or a DMG at or above GitHub's 2 GiB asset limit.

The DMG verifier does not trust the packager's staging tree. It checks the external checksum, mounts the image below a private temporary root, confirms the volume is read-only, scans the mounted tree, recomputes the app digest, verifies nested signatures and the designated requirement, compares the source tag and full compatibility record, and writes a sanitized receipt. Production task tests exercise both commands through the same interfaces with a synthetic signed app and mock macOS disk-image tools.

## Privacy flow

The public repository contains wrapper-authored source, policies, patches, tests, notices, and sanitized issue evidence. DBCode packages, licences, credentials, profiles, databases, Keychain records, signing secrets, built apps, and DMGs remain outside Git. A Private Personal Release contains only the host application plus focused text guidance and is transferred only between Macs owned by the licence holder. Its generated metadata contains no local home path or temporary path.
