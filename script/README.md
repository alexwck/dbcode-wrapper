# Command guide

The scripts are adapters around a small set of maintained modules. Prefer the task-level commands below instead of sourcing internal files directly.

## Development

- `check_development.sh` runs the fast default source contract suite. Deep build and release task fixtures, gate-composition, public-push, host-package, publishing, and rollback tests run only when a change owns those workflows.
- `check_public_push_readiness.sh` checks the exact selected Git history for private material and public-source policy. It streams historical Git objects in batches instead of starting a Git process for each object.
- `generated_workspace.sh inventory` reports every registered ignored root with its size status, retention class, owner, reason, and current cleanup eligibility. Only deliberately expired output is measured. `cleanup --class CLASS` and `cleanup --path PATH` return a dry-run plan. `cleanup --path PATH --apply` revalidates and removes one exact expired path without a prompt; class-wide apply is refused.
- `setup_local_signing_identity.sh --status` is the lower-level prompt-free signing diagnostic. Normal build and release tasks call it themselves.
- `build_host.sh [--release-ref REF]` is the standalone development or diagnostic build. It holds the kernel-backed `dist/` checkpoint lease, checks signing status, materializes a clean checked-out Git commit, and runs compilation and assembly from that immutable source.
- `assemble_host.sh` is the internal materialized-source task. It reuses the exact content-addressed Compiled Host when possible, adds wrapper extensions and release records, signs the app, writes the manifest, and promotes the complete staged app and manifest together. Its child process inherits the lease, and fixed candidate and previous paths make interrupted promotion recoverable.
- `compile_host.sh` is the cache-miss task. It checks the compiler toolchain, prepares pinned upstream source, verifies the final tree after VSCodium applies the official and wrapper patches, then runs the expensive Code OSS build. It writes the compiler-environment record without adding release-specific wrapper extensions or signing the final app. Normally `assemble_host.sh` calls it.
- `release_source_snapshot.sh` creates or verifies the immutable Git source record used by the manifest and host-package checks.
- `run_host.sh` launches the last signed host through the normal Standalone DBCode Profile. It passes launch-specific values as one record; Host Session owns the standard readiness, logging, timeout, and shutdown policy.
- `smoke_host.sh [--app APP --manifest FILE]` validates the exact signed bundle and matching manifest without launching it or creating another profile. With no arguments it checks the normal `dist/` pair.
- `test_focused_shell_rendered.sh` runs the unattended focused-shell smoke in one persistent generated QA profile. It verifies retained notebook, Query Builder, and AI routes without activating them, and opens safe wrapper and SQL routes without starting a kernel, executing SQL, calling a model, entering secrets, or accepting terms. Its `--connection-catalogue-only` mode uses the same profile and compares DBCode's rendered New Connection catalogue with the digest-only exact-version snapshot.

## Extension and capability preparation

- `prepare_dbcode.sh` verifies and prepares the complete external runtime-extension inventory.
- `verify_openvsx_package.sh` is the thin file-acquisition adapter for one exact Open VSX package. It calls the same deep verifier as Finder first-run setup. The verifier alone owns package selection, configuration shape, installed identity, and every package security check.
- `test_dbcode_feature_contract.sh` checks unchanged DBCode contributions, New Connection ownership, and the no-allowlist rule against wrapper navigation policy.

## Release sets

- `release_specification.sh` exposes strict build, Compiled Host, extension, profile, and identity records for new candidates, plus an explicit read-only mode for supported manifest-bound rollback records. The adapter does not edit retained records or invent approval.
- The Compiled Host input ID covers only compilation inputs, including the active Release Specification functions and the Patch Plan's build-relevant projection. Plain-English Patch Plan descriptions, DBCode package metadata, release-status content, documentation, tests, and historical readers do not force an unchanged Code OSS host to compile again. Cache validation includes executable modes, and a hit uses the stored compiler environment instead of rerunning compiler-only preflights.
- The Host Release commands below are the only maintained packaging and publication path. Retained evidence remains protected where rollback compatibility requires it.
- `prepare_release_rollback.sh`, `verify_release_rollback.sh`, and `preview_release_rollback.sh` retain and inspect the known-good rollback set.

## Host release

- `release_host.sh plan|prepare|publish --publish` is the normal owner-facing interface. `prepare` holds one kernel-backed `dist/` checkpoint lease and passes it to every build and verification child. It owns prompt-free signing readiness, build or exact reuse, static smoke, one-profile rendered smoke, final acceptance, tagging, packaging, independent verification, and approval. Generated release evidence is keyed by both tag and immutable source commit, so retained evidence for an older use of the same tag stays untouched. A repeated run revalidates the package files and approval digests before reusing them, then leaves one approval-history file to commit. Publication stays separate and explicit.
- `verify_fast_release.sh` runs from the manifest's materialized source, reruns the fast development contracts and static smoke itself, and combines those exact results with the signed app, release identity, and one-profile rendered smoke.
- `generate_runtime_setup_manifest.sh` is the thin writer for the public package-and-key record used by the focused first-run installer. The Runtime Extension Set module owns the record projection, validates the same record during release checks, and is part of wrapper source identity because it shapes the signed app.
- `package_host_release.sh` fully validates the annotated source tag, signed app, release lock, and prompt-free acceptance report once, then creates one digest-bound release context. It uses that context for the five local host-release files and accepts the staging copy only while its digest, signature, identity, architecture, and notices still match.
- `verify_host_release.sh` treats the DMG as untrusted input. It mounts it read-only, creates its own fully validated release context from the mounted app, compares the complete compatibility record, and writes a sanitized receipt.
- `approve_host_release.sh` accepts the current prompt-free acceptance record and the matching final package verification. It writes an attestation, approved record, and merged history under generated acceptance evidence without installing the app or writing the production profile.
- `host_release_contract.sh` exposes the Host Release module's validated prompt-free acceptance record to the approval writer. It does not create evidence or change release state.
- `inspect_host_release_tree.sh` rejects DBCode, extension caches, profiles, licence or activation state, credentials, databases, Keychain exports, signing material, and escaping links.
- `publish_release.sh` is the lower-level publication adapter. It requires an explicit `--publish`, pushes `main` and the annotated tag, creates a normal published GitHub release with only the DMG and checksum, and verifies the public state, server sizes, and SHA-256 digests.
- Host package and public-push commands keep DBCode, profiles, credentials, databases, signing secrets, compatibility manifests, and verification receipts outside Git and public release assets.

For a normal release, finish and commit the source, run `release_host.sh prepare`, review and commit the approval-history change, then run the separate explicit `release_host.sh publish --publish`. Use the lower-level commands only while developing or diagnosing a failure.

Files under `script/lib/` are internal module implementations or compatibility adapters. `host_release.sh` owns source, acceptance, compatibility, and metadata validation; `host_release_guide.sh` owns the user-facing install and rollback text. Their interfaces are documented in `docs/architecture/overview.md` and tested through the task-level commands.

Generated-output workflows resolve or validate their roots through `generated-workspace-retention.js`. Callers use the normalized absolute path returned by the contract, so a relative CLI path cannot be validated in the repository and then used against another working directory. Maintained tests have an explicit temporary-fixture gate; release evidence must stay under its registered root. Historical directories remain protected by artifact purpose without reviving their retired workflow. Never clean `.build/`, `dist/`, or `output/` by guessing from a directory name. Run the inventory and exact-path plan first. Apply only that exact expired path; caches, worktrees, protected evidence, and unknown entries remain refused.
