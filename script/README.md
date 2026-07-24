# Command guide

The scripts are adapters around a small set of maintained modules. Prefer the task-level commands below instead of sourcing internal files directly.

## Development

- `check_development.sh` runs the complete fast source contract suite.
- `generated_workspace.sh inventory` reports every registered ignored root with its size status, retention class, owner, reason, and current cleanup eligibility. Only deliberately expired output is measured. `cleanup --class CLASS` and `cleanup --path PATH` validate an explicit eligible selection and return a dry-run plan only; there is no delete or apply mode.
- `build_host.sh` prepares pinned sources, applies the patch plan, builds, packages, signs, and writes the manifest.
- `run_host.sh` launches the last signed host through the normal Standalone DBCode Profile.
- `smoke_host.sh` validates the signed bundle and an isolated independent launch.
- `test_focused_shell_rendered.sh` exercises the focused DBCode interface in isolated generated state. Its `--connection-catalogue-only` mode quickly compares DBCode's complete rendered New Connection catalogue with the digest-only exact-version snapshot.

## Extension and capability preparation

- `prepare_dbcode.sh` verifies and prepares the complete external runtime-extension inventory.
- `verify_openvsx_package.sh` verifies one exact Open VSX package.
- `test_dbcode_feature_contract.sh` checks unchanged DBCode contributions, New Connection ownership, and the no-allowlist rule against wrapper navigation policy.

## Release sets

- `release_specification.sh` exposes strict purpose records for new candidates and an explicit historical read mode for manifest-bound frozen rollback records. Historical schema 2 maps its pre-versioned profile to baseline profile schema 1; the adapter does not edit the archive or invent approval.
- `check_release_combination.sh` and `smoke_release_pair.sh` evaluate one isolated host and DBCode combination.
- `controlled_upgrade.sh` prepares, gates, promotes, or rolls back a complete Approved Release Set. Its four-way matrix requires every current/candidate host and DBCode pairing to pass before promotion.
- `check_installed_release_health.sh` verifies the promoted application and private profile after restart.
- `prepare_release_rollback.sh`, `verify_release_rollback.sh`, and `preview_release_rollback.sh` retain and inspect the known-good rollback set.

## Licensed proof and personal release

- `proof_dbcode.sh` records real-profile activation, credentials, representative data targets, persistence, and identity evidence.
- `verify_same_mac_release.sh` builds the final same-Mac acceptance receipt.
- `generate_runtime_setup_manifest.sh` turns the Release Specification into the public package-and-key record used by the focused first-run installer.
- `package_private_release.sh` creates the exact five host-only Private Personal Release assets only after an annotated source tag, signed app, release lock, and complete same-Mac acceptance agree.
- `verify_private_release.sh` treats the DMG as untrusted input, mounts it read-only, checks its source and acceptance identity, scans its contents, verifies the app and metadata, and writes a sanitized receipt.
- `inspect_private_release_tree.sh` rejects DBCode, extension caches, profiles, licence or activation state, credentials, databases, Keychain exports, signing material, and escaping links.
- Personal package and public-push commands keep DBCode, profiles, credentials, databases, and signing secrets outside Git and outside the host-only package.

Files under `script/lib/` are internal module implementations or compatibility adapters. `private_release.sh` owns source, acceptance, compatibility, and metadata validation; `private_release_guide.sh` owns the user-facing install and rollback text. Their interfaces are documented in `docs/architecture/overview.md` and tested through the task-level commands.

Generated-output workflows resolve or validate their roots through `generated-workspace-retention.js`. Callers use the normalized absolute path returned by the contract, so a relative CLI path cannot be validated in the repository and then used against another working directory. Maintained tests have an explicit temporary-fixture gate; production acceptance, upgrade, and package evidence must stay under its registered root. Never clean `.build/`, `dist/`, or `output/` by guessing from a directory name. Run the inventory first; caches, worktrees, and unknown entries remain protected until their owner explicitly records expiry.
