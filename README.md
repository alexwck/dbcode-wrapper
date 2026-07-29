# DBCode Wrapper

DBCode Wrapper is an unofficial macOS host for running the official, unchanged DBCode extension as a focused database application. This is not an official DBCode product, fork, or endorsement.

## Architecture at a glance

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
              │
              ▼
Licence, connections, credentials, queries, and local data
remain device-local and outside the application bundle
```

Code OSS is the extension host and application runtime. VSCodium supplies the reproducible macOS build and packaging flow around that runtime. Open VSX supplies independently verified extension packages. DBCode supplies the database functionality and remains unchanged. The wrapper owns the product identity, focused shell, profile isolation, release compatibility checks, and personal packaging.

Database Explorer is persistent workspace navigation. Clicking a query editor, the main canvas, or a DBCode result grid keeps it open. Its own toolbar action toggles it closed, and another DBCode action may replace it when that action uses the same sidebar. Temporary DBCode drawers still dismiss on an outside click or Escape.

## Public source and host releases

This repository contains the wrapper source, Code OSS patches, build scripts, tests, project notes, and normal published host-only releases. DBCode is not included. Each user needs a valid DBCode licence, and the app obtains the pinned unchanged extension from its official Open VSX source into that user's private profile.

Published releases contain only the wrapper host. DBCode packages, licence or account data, database credentials, user profiles, local databases, signing identities, and raw real-profile evidence stay outside Git and outside release assets. Sanitized issue notes may record versions, artifact digests, and pass or fail summaries.

The current app targets Apple silicon. It is self-signed and is not identified or notarized by Apple. Verify the published checksum before opening it. macOS may then require System Settings > Privacy & Security > Open Anyway.

A fresh Mac does not need the source repository or an extension screen. The app presents one focused first-run action that obtains only the exact pinned DBCode and Python/Jupyter packages from Open VSX, verifies their public records, engine compatibility, sizes, SHA-256 digests, public key, signatures, safe archive entries, and manifests, and installs them in that user's private profile. Scripted preparation and the Finder first-run action use the same package verifier. DBCode itself, the licence, credentials, connections, and profiles remain outside the app and outside the DMG.

## Repository guide

- `host/` contains release policy, the maintained Code OSS and VSCodium patch overlay, wrapper extensions, test fixtures, and the detailed host guide.
- `script/` contains build, verification, profile, release, upgrade, rollback, packaging, and publishing commands.
- `docs/` contains architecture, design, learning, security, product coverage, and agent guidance.
- `.scratch/` is the local Markdown issue tracker and implementation history.
- `.build/`, `dist/`, and `output/` are generated locally and never belong in the public source repository. Inspect or plan cleanup through `./script/generated_workspace.sh`; do not remove these paths ad hoc.

The legacy `v0.1.2` package remains an unpublished owner-only draft. It will not be republished because its immutable metadata records a private transfer. [`v0.1.3`](https://github.com/alexwck/dbcode-wrapper/releases/tag/v0.1.3) is the first normal public host release. It keeps DBCode `1.36.4`, Code OSS `1.126.0`, and VSCodium packaging `1.126.04524` for Apple silicon. Code OSS `1.130.0` remains visible as **Not tested** until compatible VSCodium packaging exists. These are compatibility statements for exact release sets, not permanent promises about future upstream versions. PostgreSQL, DuckDB, Parquet, SQLite, and Python notebooks are useful optional checks, not a deployment allowlist. Every connection type contributed by the installed unchanged DBCode version must remain available.

The [DBCode capability coverage guide](docs/product/dbcode-capability-coverage.md) maps the official feature families to wrapper evidence and known gaps. The [AI data-sharing guide](docs/security/ai-data-sharing.md) explains what AI and MCP features may send outside the database. These guides describe the wrapper boundary; the installed DBCode version and maintained feature policy remain authoritative.

Update discovery automatically polls the official stable Code OSS, VSCodium, and DBCode records separately, and keeps the status icon and review view current. It only reports availability and links to official release notes. When it finds an update, the repository owner starts the version bump and release workflow. Discovery cannot change the release lock, approve a candidate, create a tag, publish a release, or install a component. A release is ready only when the exact source tag, release lock, signed app, extension inventory, automated source checks, static smoke, and one-profile rendered smoke agree.

The normal release gate is prompt-free. It does not sign in, activate a licence, start a database, run a debugger or Python kernel, call an AI model, enter a secret, or approve a macOS prompt. New or changed DBCode capabilities receive focused source or rendered checks when they can run unattended. Deeper live checks are optional diagnostics and do not block deployment.

Acceptance evidence stores the exact external extension inventory in deterministic ID order. A harmless change in the host CLI's display order therefore cannot make an unchanged package set look stale.

The isolated rendered release gate records only connection-section counts and deterministic SHA-256 fingerprints, not a copied list of vendor connection names. The wrapper has no database allowlist and passes no database-type argument into DBCode's New Connection action. A changed count or fingerprint creates a new release candidate that must be reviewed with its exact host; it is not treated as a connection that the wrapper may silently omit. Exact release-specific counts live in the maintained compatibility policy and acceptance evidence.

## Development

The complete architecture, prerequisites, build commands, verification steps, and optional live diagnostics are documented in [host/README.md](host/README.md).

### Learn the codebase

Start with [the architecture overview](docs/architecture/overview.md), then use [the learning path](docs/learning-path.md) to trace the real code in a deliberate order. The generated [codebase wiki](wiki/OVERVIEW.md) adds linked module, flow, concept, and task guides, while the [implementation map](.scratch/dbcode-wrapper-implementation/map.md) records why the current design exists and what remains open.

The wiki is derived learning material. Check the `source_commit` in its overview before relying on it, and prefer current source, policies, and tests whenever they disagree. OpenKnowledge is optional documentation tooling: it is not required to build, run, verify, update, or package DBCode Wrapper.

The maintained patch plan is documented in [host/patches/README.md](host/patches/README.md), and [script/README.md](script/README.md) groups the command-line workflows by responsibility.

Use the narrowest useful verification level:

1. Documentation-only changes: `git diff --check` and the public source-tree contract.
2. Source and policy changes: `./script/check_development.sh`.
3. Signed host changes: static smoke and the one-profile rendered focused-shell smoke.
4. Release-set changes: automated identity, package, and prompt-free acceptance checks.

The maintained [verification policy](docs/agents/verification-policy.md) keeps deployment checks fast and unattended.

The rendered check reuses one persistent generated QA profile. It opens representative DBCode routes but does not start a Python kernel, execute SQL, call a model, enter secrets, accept terms, or wait for a person.

Build a release candidate only from a clean committed source tree:

```sh
./script/build_host.sh
```

The command copies the exact commit to a temporary release-source checkout before it reads build inputs. The first run compiles the pinned Code OSS host. Later runs reuse that verified Compiled Host when its exact compilation inputs have not changed. The cache key records whether a source file is executable, but ignores local permission differences that Git does not track. A cache hit also skips compiler-only tool checks. A DBCode-only version bump or profile-only identity change still gets new wrapper records, signing, a manifest, and acceptance evidence without compiling Code OSS again.

Exact-source checks may reuse ignored caches and toolchains from the launcher checkout. They never use its mutable `.build/work` tree as source evidence. Source checks always describe the materialized release commit.

Run the source contract suite with:

```sh
./script/check_development.sh
```

Inspect ignored build, test, acceptance, rollback, cache, and package state with:

```sh
./script/generated_workspace.sh inventory
```

The inventory reports each registered path, size status, retention class, owner, reason, and current cleanup eligibility. It measures only deliberately expired output. Protected release artifacts, caches, worktrees, unknown paths, and private profile contents are not traversed or measured. Cleanup is a dry run by default:

```sh
./script/generated_workspace.sh cleanup --class expired-output
./script/generated_workspace.sh cleanup --path ".build/expired/example with spaces"
```

After reviewing the inventory and exact-path plan, remove one expired target without a prompt:

```sh
./script/generated_workspace.sh cleanup \
  --path ".build/expired/example with spaces" \
  --apply
```

`--apply` accepts one exact path only. It cannot apply a whole class. Unknown paths, symbolic links, repository and home roots, active evidence, caches, worktrees, the accepted app, current profile, final transfer assets, acceptance receipts, controlled-upgrade evidence, and rollback backups remain refused until their owning workflow explicitly records expiry.

Before any public push, inspect the exact ref that will be published rather than only the current files:

```sh
./script/check_public_push_readiness.sh \
  --repository . \
  --ref <public-ref> \
  --approved-author-email <public-email> \
  --private-home-name <local-account-name> \
  --approved-license-sha256 <approved-license-file-sha256>
```

The exact `LICENSE` file reserves all rights in the original wrapper code. This gate accepts only its approved SHA-256 and the GitHub noreply address selected for the public commit; it rejects any different licence or author identity.

Create the prompt-free acceptance report from the exact signed app and rendered result. The command materializes the manifest's source commit, reruns the fast development contracts from that source, and reruns static smoke against that exact app:

```sh
./script/verify_fast_release.sh \
  --app "dist/DBCode Wrapper.app" \
  --manifest dist/build-manifest.json \
  --release-lock host/release-lock.json \
  --rendered-report <rendered-report> \
  --output .build/acceptance/fast-release/final-acceptance-report.json
```

After an annotated source tag, its exact signed app, and that automated acceptance report agree, create the five local host-release files:

```sh
./script/package_host_release.sh \
  --app "dist/DBCode Wrapper.app" \
  --manifest dist/build-manifest.json \
  --release-lock host/release-lock.json \
  --acceptance .build/acceptance/fast-release/v0.1.3/final-acceptance-report.json \
  --source-repository . \
  --source-tag v0.1.3 \
  --output-dir .build/host-release/v0.1.3
```

The package command produces one read-only DMG, its SHA-256 file, a compatibility manifest, install and rollback notes, and an independent verification receipt. It refuses a source tag that does not identify the manifest's exact source revision, incomplete automated evidence, an app without focused first-run runtime setup, a DMG at or above GitHub's 2 GiB asset limit, or any bundled DBCode package, profile, extension cache, licence state, credential, database, Keychain export, or signing secret. All five files stay outside Git. Only the DMG and checksum are public release assets; the compatibility and verification evidence remains local.

After the mounted package verification passes, record the exact package as approved:

```sh
./script/approve_host_release.sh \
  --manifest dist/build-manifest.json \
  --release-lock host/release-lock.json \
  --acceptance .build/acceptance/fast-release/v0.1.3/final-acceptance-report.json \
  --dmg <host-release.dmg> \
  --compatibility <compatibility-manifest.json> \
  --verification <verification-receipt.json> \
  --source-repository . \
  --source-tag v0.1.3 \
  --history host/approved-release-history.json \
  --confirm-release-set <exact-release-set-id> \
  --output-dir .build/acceptance/fast-release/v0.1.3-approval
```

Approval writes an attestation, one Approved Release Set record, and the merged approved history under ignored generated output. It does not launch or install the app, approve a macOS prompt, or write the Standalone DBCode Profile. Installation remains a separate user-controlled step.

Publish the approved candidate as a normal release in this repository:

```sh
./script/publish_release.sh \
  --source-repository . \
  --source-tag v0.1.3 \
  --release-lock host/release-lock.json \
  --assets-dir .build/host-release/v0.1.3 \
  --publish
```

The publisher pushes `main` and the annotated tag, uploads only the DMG and checksum, and then checks the public release state, asset sizes, and SHA-256 digests. It does not create a draft or prerelease.

## Rights and third-party software

DBCode remains proprietary software governed by DBCode's own terms. Code OSS, VSCodium, Python/Jupyter extensions, and other third-party components retain their respective licences and notices. This repository and its host-only releases do not grant a DBCode licence and do not redistribute the DBCode extension.

The original wrapper code and documentation remain under the repository's All Rights Reserved [`LICENSE`](LICENSE). Publishing a host-only release does not make this an official DBCode product or grant rights to DBCode.
