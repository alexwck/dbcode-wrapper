# DBCode Wrapper

This context defines the language for exploring a separate macOS experience for a licensed DBCode user.

## Language

**DBCode Wrapper App**:
An unofficial public macOS host for the official, unchanged DBCode extension. It presents DBCode through its own icon and application lifecycle while using a compatible Code OSS extension host. A published wrapper release contains only the host; each user obtains DBCode separately from its official source and needs a valid DBCode licence.
_Avoid_: official DBCode app, DBCode fork, commercial DBCode product, bundled DBCode app

**Public Source Repository**:
The GitHub repository containing the wrapper's own source, patches, tests, project notes, and normal published host-only releases. It never contains or distributes a DBCode package, licence or account data, credentials, profiles, local databases, signing secrets, or raw real-profile evidence. Sanitized issue notes may retain versions, artifact digests, and pass or fail summaries.
_Avoid_: bundled DBCode, secret-bearing repository, implied DBCode licence

**Public Host Release**:
A normal published GitHub release containing the self-signed Apple-silicon wrapper-host DMG and its checksum. DBCode is not bundled; each user obtains the unchanged extension from its official source under their own licence. The user verifies the checksum and may need macOS Privacy & Security > Open Anyway because the host is not signed with Developer ID and is not notarized.
_Avoid_: official DBCode release, bundled DBCode, Apple-trusted signing, Apple notarization, disabled Gatekeeper

**Standalone DBCode Experience**:
The user launches DBCode through its own macOS app, Dock icon, window, and application lifecycle without first opening VS Code. The internal technology may still use a compatible extension host.
_Avoid_: native rewrite, VS Code-free implementation

**DBCode-Focused Shell**:
The normal visible application exposes DBCode database functionality only. Any compatible extension host remains internal and does not present a general code workbench, Extensions view, Command Palette, or unrelated coding tools.
_Avoid_: reduced VS Code IDE, general-purpose IDE, reimplemented DBCode interface

**Standalone DBCode Profile**:
The app's private DBCode settings, connection state, and normal license activation. Existing state enters it only through a DBCode-supported migration path; protected credentials are re-entered securely.
_Avoid_: permanently shared VS Code profile, copied license state, extracted credentials

**Controlled DBCode Upgrade**:
An intentional move to a newer Approved Release Set after Code OSS, VSCodium packaging, DBCode, and profile compatibility are checked, with a known path back to the last working set. One or more upstream versions may stay unchanged.
_Avoid_: silent extension update, irreversible upgrade

**Approved Release Set**:
One exact wrapper build with its Code OSS runtime and VSCodium packaging revisions, one exact unchanged DBCode version, and their compatible Standalone DBCode Profile version after the Prompt-Free Release Gate passes. Approval records the exact accepted package without installing it or changing the profile. A later install and any rollback still move the complete set together even though Code OSS, VSCodium, and DBCode releases are discovered separately.
_Avoid_: independently promoted versions, assumed compatibility, always-latest pairing

**Release Source Snapshot**:
The clean immutable Git commit used to build and identify one candidate. The build materializes this commit and reads wrapper inputs there, so later changes in the launcher checkout cannot affect the app.
_Avoid_: dirty working tree, moving branch, uncommitted release input

**Compiled Host**:
The reusable application base produced from one exact set of Code OSS, VSCodium, toolchain, patch, icon, product, and slimming inputs. Its receipt covers bytes, links, executable modes, and the actual compiler environment. It does not yet contain release-specific wrapper extensions or records and is not signed as the final app.
_Avoid_: finished release, DBCode package, accepted signed app

**Prompt-Free Release Gate**:
The automated release check for wrapper-owned behaviour. It combines source contracts, static signed-app checks, and one rendered run in the generated QA profile. It never waits for a database, kernel, model, account, secret, macOS approval, or another person.
_Avoid_: full DBCode product test, real-profile proof, prompt-driven deployment

**Upgrade Prompt**:
A notice that a newer Code OSS runtime, VSCodium packaging release, or DBCode release is available and invites the user to begin a Controlled DBCode Upgrade. It never installs an update silently.
_Avoid_: automatic update, forced upgrade

**Unmodified Extension Boundary**:
The wrapper host may be published because DBCode is not bundled. Each user obtains the official unchanged extension separately under their own valid licence. The project must not modify, mirror, redistribute, reverse engineer, or bypass the licensing of DBCode.
_Avoid_: patched extension, licence bypass, reconstructed DBCode, redistributed DBCode
