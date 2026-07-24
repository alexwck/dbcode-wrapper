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

## Deep modules

The maintained architecture concentrates cross-cutting rules behind seven seams:

1. **Release Specification** validates `host/release-lock.json` and returns purpose-level build, extension, profile/product, and identity records. New candidates use the current strict schema. A separate read-only adapter can interpret supported frozen schema-2 and schema-4 records only when the retained build manifest binds their exact lock digest; it never turns historical state into a new candidate or invents approval.
2. **Approved Release Set** owns canonical source and artifact identity, approval records, safe member resolution, promotion, and rollback compatibility.
3. **Profile Layout** returns one validated record for every Standalone DBCode Profile path used by shell and JavaScript adapters.
4. **Host Session** owns one application lifecycle: process start, renderer readiness, DBCode readiness, logs, timeout, and complete quit.
5. **Patch Plan** applies the maintained Code OSS and VSCodium overlay by semantic seam and verifies the resulting source tree.
6. **Focused Runtime Setup** derives one public package-and-key record from the Release Specification. On a fresh Finder launch it downloads only that exact DBCode and Python/Jupyter set, verifies every acquisition boundary, installs outside the app with extension-pack dependencies disabled, and reloads only after the managed inventory matches.
7. **Private Personal Release** binds one annotated source tag, approved release lock, signed host manifest, complete same-Mac acceptance report, and host-only DMG. Its task-level packager and independent verifier share one compatibility-record constructor, while the install-guide renderer remains separate user-facing policy.

Tests cross the same interfaces as production callers. Compatibility adapters keep established command-line workflows stable while implementation details move behind the seams.

## Connection capability

PostgreSQL, DuckDB, Parquet, SQLite, and Python notebooks are practical fixtures that can be exercised locally. They are not an allowlist. DBCode's official supported-databases catalogue currently contains more than 80 databases, services, cloud targets, and data-file formats. The wrapper must not filter that catalogue or maintain a competing static list.

A new DBCode release may add or remove connection types. The release gate therefore uses two independent checks. First, it binds the exact public package contribution digest and the unchanged `dbcode.connections.add` command to the Approved Release Set. Second, an isolated mock-Keychain launch opens DBCode's real New Connection picker and reduces its counted sections and normalized label set to counts and SHA-256 fingerprints. Raw vendor labels never enter Git or the rendered report.

The wrapper passes no arguments into that DBCode-owned entry point and does not transform the catalogue. If the extension version, contribution digest, section shape, item count, or label fingerprint changes, the candidate stops for complete release-pair review. PostgreSQL, DuckDB, Parquet, SQLite, and Python remain representative depth checks; they do not define the breadth of supported connections. Actual connectivity can still depend on the target server or service, network, credentials, operating system, optional drivers, and the exact installed DBCode version.

## Release flow

```text
release specification
        │
        ▼
prepare pinned sources and verified extension packages
        │
        ▼
apply semantic patch plan → build → sign → manifest
        │
        ▼
candidate Approved Release Set
        │
        ├─ source and package contracts
        ├─ rendered focused-shell checks
        ├─ representative database and notebook proofs
        ├─ restart and Keychain checks
        └─ promotion and rollback rehearsal
        │
        ▼
approved set promoted as one host, extension inventory, and profile schema
        │
        ▼
annotated source tag → host-only DMG → independent mounted verification
```

Code OSS runtime, VSCodium packaging, and DBCode updates are discovered separately but never promoted separately. Every source or patch change creates a new candidate identity; old proof cannot silently carry forward.

The compatibility matrix runs `H0/D0`, `H0/D1`, `H1/D0`, and `H1/D1` as separate receipts. Promotion fails if any one of those pairings fails. This keeps independently discovered host and DBCode releases independently testable while still installing and rolling back one complete Approved Release Set.

The first-run setup and Private Personal Release do not weaken that rule. The setup record is generated from the same exact extension specification and is hashed into the signed build manifest. The package command refuses an app without that evidence. It also refuses a lightweight tag, a tag at a different source revision, a changed release lock, a stripped acceptance report, colliding source or artifact filenames, or a DMG at or above GitHub's 2 GiB asset limit.

The DMG verifier does not trust the packager's staging tree. It checks the external checksum, mounts the image below a private temporary root, confirms the volume is read-only, scans the mounted tree, recomputes the app digest, verifies nested signatures and the designated requirement, compares the source tag and full compatibility record, and writes a sanitized receipt. Production task tests exercise both commands through the same interfaces with a synthetic signed app and mock macOS disk-image tools.

## Privacy flow

The public repository contains wrapper-authored source, policies, patches, tests, notices, and sanitized issue evidence. DBCode packages, licences, credentials, profiles, databases, Keychain records, signing secrets, built apps, and DMGs remain outside Git. A Private Personal Release contains only the host application plus focused text guidance and is transferred only between Macs owned by the licence holder. Its generated metadata contains no local home path or temporary path.
