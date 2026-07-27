# Command guide

The scripts are adapters around a small set of maintained modules. Prefer the task-level commands below instead of sourcing internal files directly.

## Development

- `check_development.sh` runs the fast default source contract suite. Gate-composition, public-push, private-package, deep rollback, controlled-upgrade, debugger-fixture, and historical acceptance tests run only when a change owns those workflows.
- `generated_workspace.sh inventory` reports every registered ignored root with its size status, retention class, owner, reason, and current cleanup eligibility. Only deliberately expired output is measured. `cleanup --class CLASS` and `cleanup --path PATH` validate an explicit eligible selection and return a dry-run plan only; there is no delete or apply mode.
- `build_host.sh [--release-ref REF]` requires a clean checked-out Git commit, materializes that commit in a temporary checkout, and runs compilation and assembly from that immutable source.
- `assemble_host.sh` is the internal materialized-source task. It reuses the exact content-addressed Compiled Host when possible, adds wrapper extensions and release records, signs the app, and writes the manifest.
- `compile_host.sh` is the cache-miss task. It checks the compiler toolchain, prepares pinned upstream source, applies the patch plan, runs the expensive Code OSS build, and writes the compiler-environment record without adding release-specific wrapper extensions or signing the final app. Normally `assemble_host.sh` calls it.
- `release_source_snapshot.sh` creates or verifies the immutable Git source record used by the manifest and private package checks.
- `run_host.sh` launches the last signed host through the normal Standalone DBCode Profile.
- `smoke_host.sh [--app APP --manifest FILE]` validates the exact signed bundle and matching manifest without launching it or creating another profile. With no arguments it checks the normal `dist/` pair.
- `test_focused_shell_rendered.sh` runs the unattended focused-shell smoke in one persistent generated QA profile. It verifies retained notebook, Query Builder, and AI routes without activating them, and opens safe wrapper and SQL routes without starting a kernel, executing SQL, calling a model, entering secrets, or accepting terms. Its `--connection-catalogue-only` mode uses the same profile and compares DBCode's rendered New Connection catalogue with the digest-only exact-version snapshot.

## Extension and capability preparation

- `prepare_dbcode.sh` verifies and prepares the complete external runtime-extension inventory.
- `verify_openvsx_package.sh` verifies one exact Open VSX package.
- `test_dbcode_feature_contract.sh` checks unchanged DBCode contributions, New Connection ownership, and the no-allowlist rule against wrapper navigation policy.

## Release sets

- `release_specification.sh` exposes strict build, Compiled Host, extension, profile, and identity records for new candidates, plus an explicit historical read mode for manifest-bound frozen rollback records. Historical schema 2 maps its pre-versioned profile to baseline profile schema 1; the adapter does not edit the archive or invent approval.
- The Compiled Host input ID covers only compilation inputs, including the active Release Specification functions. DBCode package metadata, release-status content, documentation, tests, and historical readers do not force an unchanged Code OSS host to compile again. Cache validation includes executable modes, and a hit uses the stored compiler environment instead of rerunning compiler-only preflights.
- `check_release_combination.sh` and `smoke_release_pair.sh` evaluate one isolated host and DBCode combination.
- `controlled_upgrade.sh` retains the older complete-set promotion and rollback workflow for existing records. It is not part of the normal prompt-free package path.
- `check_installed_release_health.sh` verifies the promoted application and private profile after restart.
- `prepare_release_rollback.sh`, `verify_release_rollback.sh`, and `preview_release_rollback.sh` retain and inspect the known-good rollback set.

## Personal release

- `verify_fast_release.sh` runs from the manifest's materialized source, reruns the fast development contracts and static smoke itself, and combines those exact results with the signed app, release identity, and one-profile rendered smoke.
- `generate_runtime_setup_manifest.sh` turns the Release Specification into the public package-and-key record used by the focused first-run installer.
- `package_private_release.sh` creates the exact five host-only Private Personal Release assets after an annotated source tag, signed app, release lock, and either the prompt-free acceptance report or a compatible older acceptance report agree.
- `verify_private_release.sh` treats the DMG as untrusted input, mounts it read-only, checks its source and acceptance identity, scans its contents, verifies the app and metadata, and writes a sanitized receipt.
- `approve_private_release.sh` accepts only schema-3 prompt-free acceptance and the matching final package verification. It writes an attestation, approved record, and merged history under generated acceptance evidence without installing the app or writing the production profile.
- `inspect_private_release_tree.sh` rejects DBCode, extension caches, profiles, licence or activation state, credentials, databases, Keychain exports, signing material, and escaping links.
- Personal package and public-push commands keep DBCode, profiles, credentials, databases, and signing secrets outside Git and outside the host-only package.

Files under `script/lib/` are internal module implementations or compatibility adapters. `private_release.sh` owns source, acceptance, compatibility, and metadata validation; `private_release_guide.sh` owns the user-facing install and rollback text. Their interfaces are documented in `docs/architecture/overview.md` and tested through the task-level commands.

Generated-output workflows resolve or validate their roots through `generated-workspace-retention.js`. Callers use the normalized absolute path returned by the contract, so a relative CLI path cannot be validated in the repository and then used against another working directory. Maintained tests have an explicit temporary-fixture gate; production acceptance, upgrade, and package evidence must stay under its registered root. Never clean `.build/`, `dist/`, or `output/` by guessing from a directory name. Run the inventory first; caches, worktrees, and unknown entries remain protected until their owner explicitly records expiry.
