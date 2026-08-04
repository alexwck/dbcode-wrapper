# DBCode Wrapper host

This directory contains the maintained overlay used to build the standalone macOS host. Code OSS is the application runtime. VSCodium supplies the repeatable macOS build and packaging tools. DBCode remains an unchanged external extension and is never bundled in the app.

For product scope and privacy, read the [root README](https://github.com/alexwck/dbcode-wrapper/blob/main/README.md). For module boundaries and data flow, read the [architecture overview](https://github.com/alexwck/dbcode-wrapper/blob/main/docs/architecture/overview.md). The [capability coverage guide](https://github.com/alexwck/dbcode-wrapper/blob/main/docs/product/dbcode-capability-coverage.md) and [AI data-sharing guide](https://github.com/alexwck/dbcode-wrapper/blob/main/docs/security/ai-data-sharing.md) describe the DBCode-owned feature surface.

## Build

Commit the complete input so the working tree is clean, then run:

```sh
./script/build_host.sh
```

The build checks the existing signing identity without asking for input. It stops before assembly when that identity is not ready. It then records the checked-out commit, materializes that immutable source in a temporary checkout, and reads build inputs from the materialized source.

The build reuses the exact content-addressed Compiled Host when its Code OSS, VSCodium, toolchain, overlay, patch, product, icon, and active slimming inputs match. A DBCode-only or profile-only update can therefore skip Code OSS compilation. On a cache miss, the task prepares the pinned upstream sources, verifies the final patched tree, and compiles the Apple-silicon host.

Assembly adds the current wrapper extensions and release records, signs nested code from the inside out, and promotes these two outputs together:

- `dist/DBCode Wrapper.app`
- `dist/build-manifest.json`

Build and verification tasks share one kernel-backed `dist/` checkpoint lease. A complete candidate is staged before it replaces the previous checkpoint. If a process stops during promotion, the next owner can restore or retain the last complete pair.

Do not edit `dist/`, generated upstream checkouts, compiled caches, or packaged extension files by hand. Inspect generated state with:

```sh
./script/generated_workspace.sh inventory
```

Cleanup is a dry run unless one exact validated expired path is supplied with `--apply`. Reusable caches, active evidence, release assets, private profiles, broad roots, and symbolic links remain protected.

The source and toolchain pins live in `host/release-lock.json`. Active package slimming and rollback choices live in `host/slimming-policy.json`. Managed profile settings live in `host/profile/settings.json`. The independent wrapper route policy lives in `host/dbcode-feature-policy.json`.

## Run

Launch the last signed checkpoint without rebuilding:

```sh
./script/run_host.sh
```

Use the foreground diagnostic mode for developer tools, extension-host inspection, and verbose logs:

```sh
./script/run_host.sh --debug
```

Both commands use the current user's Standalone DBCode Profile:

- `~/Library/Application Support/DBCode Wrapper` for user data and logs
- `~/.dbcode-wrapper/extensions` for verified DBCode and Python/Jupyter extensions
- `~/.dbcode-wrapper-shared` for shared storage

The automated rendered check uses one separate persistent generated `qa` profile under `.build/`. It never uses the production profile.

## View BSON results

DBCode continues to own query execution and its live result grid. When MongoDB output copied as JSON or JSON Pretty contains canonical Extended JSON wrappers, choose **DBCode tools → Open Copied BSON Result** or press `⌘⌥J`. Choose **Open BSON Result File…** for one saved `.json` or `.ejson` file. The wrapper-owned viewer opens in Tree mode, separates readable values from BSON types in Tree and Table, presents key-value JSON without supported BSON type wrappers in JSON mode, searches by path/value/type, and can optionally expand JSON stored inside strings.

Both routes are explicit and local. They do not inspect DBCode, query a database, monitor the clipboard, use the network, send telemetry, or persist result data. The viewer rejects a selected file larger than 10 MiB before reading it and accepts at most 50,000 display values. Tree and Table each materialize at most 5,000 matching values at once, so use search and lazy tree branches to inspect a larger accepted document.

Profile Setup, Runtime Setup, profile recovery, focused navigation, live query results, local BSON display, update reporting, and other user-facing behavior are described in the [root README](https://github.com/alexwck/dbcode-wrapper/blob/main/README.md), [architecture overview](https://github.com/alexwck/dbcode-wrapper/blob/main/docs/architecture/overview.md), and [capability coverage guide](https://github.com/alexwck/dbcode-wrapper/blob/main/docs/product/dbcode-capability-coverage.md). DBCode owns database, notebook, AI, MCP, account, licence, query, and live-result behavior. The wrapper exposes those routes without reimplementing them and keeps its BSON viewer as a separate explicit-input display adapter.

## Verify

Run the prompt-free source gate while developing:

```sh
./script/check_development.sh
```

It checks maintained source contracts without compiling, repackaging, launching the app, or waiting for a person.

After a host build, run Static Host Smoke:

```sh
./script/smoke_host.sh
```

Static smoke checks the signed bundle and matching manifest, application identity, installed-size limit, zero source maps, exact built-in inventory, packaged settings, SQL association, runtime setup record, release identity, and the rule that DBCode stays external.

Run the one-profile rendered smoke when the built shell changes:

```sh
./script/test_focused_shell_rendered.sh
```

For an upstream DBCode review, the same runner has a narrower catalogue mode:

```sh
./script/test_focused_shell_rendered.sh --connection-catalogue-only
```

Rendered automation uses a mock Keychain. It does not start Python, execute SQL, call a model, accept DBCode terms, sign in, activate a licence, enter a secret, reset the profile, or approve a macOS prompt. Those remain user-controlled actions.

The [verification policy](https://github.com/alexwck/dbcode-wrapper/blob/main/docs/agents/verification-policy.md) explains which smallest gate belongs to each type of change. The [command guide](https://github.com/alexwck/dbcode-wrapper/blob/main/script/README.md) documents task-level commands and lower-level diagnostic adapters.

## Release

Use the owner-facing task:

```sh
./script/release_host.sh plan
./script/release_host.sh prepare
./script/release_host.sh publish --publish
```

`plan` is read-only. It describes the current commit, exact evidence paths, and a structured `preparation` state. For a new tag, preparation requires a clean `main` checkout. If the version tag already exists, it must be annotated and identify the current commit. An exact same-tag run remains resumable after `prepare` leaves its expected approval-history edit.

`prepare` checks that source state before it acquires the `dist/` checkpoint lease or starts signing, building, smoke, acceptance, packaging, or verification. It then owns the complete prompt-free preparation gate and creates the annotated tag only after acceptance passes. The task leaves one tracked change in `host/approved-release-history.json`.

Review and commit that one approval-history change, then run the separate explicit `publish --publish` action. Publication uses the accepted tagged release set, pushes `main` and the tag, publishes only the host DMG and checksum, and verifies the public state, server sizes, and SHA-256 digests.

Use lower-level release commands only for development or diagnosis. They are not extra deployment steps.

For a known-good rollback set, run `./script/prepare_release_rollback.sh <release-id>`, then `./script/verify_release_rollback.sh <release-id>`. Use `./script/preview_release_rollback.sh <release-id>` to open the verified set from a disposable profile without replacing the current app or profile. Installation remains a separate user-controlled action.

## Signing and user prompts

The public Host Release uses a persistent current-user self-signed identity. Strict signature checks prove artifact integrity, but the identity has no Apple Team ID and is not trusted by Gatekeeper. Verify the published checksum before opening the app; macOS may require **Open Anyway**. Normal use may also ask for Safe Storage, DBCode sign-in, licence, OAuth, database, or model access.

Automated tests report these boundaries but never approve, bypass, or wait for them.
