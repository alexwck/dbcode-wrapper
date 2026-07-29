# DBCode Wrapper

DBCode Wrapper is an unofficial macOS host for running the official, unchanged DBCode extension as a focused database application. This is not an official DBCode product, fork, or endorsement.

## What it does

```text
VSCodium build and packaging tools
              │
              ▼
Pinned Code OSS runtime + reviewed wrapper patches
              │
              ▼
      DBCode Wrapper.app
              │ loads from the current user's private profile
              ▼
Unchanged DBCode + required Python/Jupyter extensions
```

Code OSS is the extension host and application runtime. VSCodium supplies the reproducible macOS build and packaging flow. Open VSX supplies independently verified extension packages. DBCode supplies the database, notebook, AI, MCP, account, and licence features. The wrapper owns only the application identity, focused shell, private profile, compatibility checks, and host-only packaging.

Database Explorer stays open while the user works in a query editor, the main canvas, or a DBCode result grid. Its toolbar action toggles it, and another DBCode action may replace it when that action uses the same sidebar. Temporary DBCode drawers still dismiss on an outside click or Escape.

New DBCode query results open below the query at every window width. DBCode still owns the result editor, grid, Inspector, copy, and export behavior; the wrapper does not add a second Results panel.

## Public source and releases

This repository contains the wrapper source, reviewed patches, policies, tests, documentation, and normal published host-only releases. DBCode is not included. Each user needs a valid DBCode licence and obtains the official unchanged extension from its approved Open VSX source into their private profile.

Published releases contain only the wrapper host. DBCode packages, licences, accounts, credentials, profiles, databases, signing secrets, and raw real-profile evidence stay outside Git and outside release assets. Only sanitized versions, public metadata, cryptographic digests, and pass or fail summaries may appear in project history.

Use the [latest published Host Release](https://github.com/alexwck/dbcode-wrapper/releases/latest) for downloads. The exact wrapper, Code OSS, VSCodium, and DBCode versions for a source revision live in [`host/release-lock.json`](host/release-lock.json). Maintained guidance does not duplicate those changing values.

The app targets Apple silicon. It is self-signed and is not identified or notarized by Apple. Verify the published checksum before opening it. macOS may then require System Settings → Privacy & Security → Open Anyway.

On a fresh Mac, the app offers one focused setup action. It obtains only the pinned DBCode and Python/Jupyter packages, verifies their public records, engine compatibility, sizes, SHA-256 digests, public key, signatures, safe archive entries, and manifests, then installs them outside the app in the current user's private profile.

## Updates and compatibility

The app automatically checks the official stable Code OSS, VSCodium, and DBCode records separately. The status icon and review view report what is available and link to official release notes. Discovery cannot change a version pin, approve or install a candidate, create a tag, publish a release, or change a profile. The repository owner starts every version bump and release.

The [DBCode capability coverage guide](docs/product/dbcode-capability-coverage.md) maps official feature families to wrapper evidence and known gaps. The [AI data-sharing guide](docs/security/ai-data-sharing.md) explains what AI and MCP features may send outside a database. DBCode's installed contributions and [`host/dbcode-feature-policy.json`](host/dbcode-feature-policy.json) remain authoritative.

PostgreSQL, DuckDB, Parquet, SQLite, and Python notebooks are representative optional checks, not a connection allowlist. The wrapper must preserve the complete connection catalogue contributed by the installed unchanged DBCode version.

## Repository guide

- `host/` contains the release specification, compatibility policy, wrapper extensions, reviewed patches, and host guide.
- `script/` contains the prompt-free build, verification, release, rollback, and generated-workspace commands.
- `docs/` contains maintained architecture, product, security, learning, and agent guidance.
- `wiki/` contains optional derived learning material.
- `.scratch/` contains the local issue history and any current claimed task.
- `.build/`, `dist/`, and `output/` are ignored generated state. Use the maintained retention command instead of deleting them by directory name.

## Development

Read [the architecture overview](docs/architecture/overview.md), then [the learning path](docs/learning-path.md). The generated [codebase wiki](wiki/OVERVIEW.md) adds linked orientation, but source, policies, and tests always win when it is stale.

Run the prompt-free source gate:

```sh
./script/check_development.sh
```

Build or reuse the exact Compiled Host from a clean committed source:

```sh
./script/build_host.sh
```

On a cold build, the wrapper checks the final patched Code OSS tree before compilation starts.

Signed-host changes also run static smoke and the one persistent-profile rendered check. The rendered check opens representative DBCode routes without starting a database or kernel, calling a model, entering a secret, signing in, activating a licence, or approving a macOS prompt.

Inspect ignored generated state with:

```sh
./script/generated_workspace.sh inventory
```

Cleanup is a dry run unless one exact validated expired path is supplied with `--apply`. Protected evidence, private profiles, caches, worktrees, release assets, broad roots, and symbolic links are refused.

## Release

The owner-facing task derives the release tag and standard paths from the Release Specification:

```sh
./script/release_host.sh plan
./script/release_host.sh prepare
./script/release_host.sh publish --publish
```

`prepare` runs final prompt-free acceptance, creates or verifies the annotated source tag, packages and independently verifies the host-only DMG, and records approval. If a run is interrupted, it reuses complete exact evidence instead of repeating that work. It leaves one reviewable change in `host/approved-release-history.json`; commit that file before publication. The separate `publish --publish` action pushes `main` and the tag, creates a normal GitHub release with only the DMG and checksum, then verifies the public state, sizes, and digests.

The detailed build and diagnostic commands remain in [the host guide](host/README.md) and [the command guide](script/README.md).

## Rights and third-party software

DBCode remains proprietary software governed by DBCode's own terms. Code OSS, VSCodium, Python/Jupyter extensions, and other third-party software retain their own licences and notices. This repository and its host-only releases do not grant a DBCode licence or redistribute DBCode.

The original wrapper code and documentation remain under the repository's All Rights Reserved [`LICENSE`](LICENSE). Publishing a host-only release does not make this an official DBCode product or grant rights to DBCode.
