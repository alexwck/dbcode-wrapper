# DBCode Wrapper

This context defines the language for exploring a separate macOS experience for a licensed DBCode user.

## Language

**DBCode Wrapper App**:
An unofficial macOS application prepared only for the license holder's personal use. It wraps the compatible Code OSS extension host needed by unchanged DBCode, while presenting only DBCode functionality through its own icon and application lifecycle. Its wrapper source may be visible in a Public Source Repository, but the built application may be copied only between Macs owned by the license holder. It is not made publicly downloadable, shared with other people, or resold.
_Avoid_: official DBCode app, DBCode fork, commercial DBCode product, redistributed DBCode app

**Public Source Repository**:
A publicly visible GitHub repository containing the wrapper's own source, patches, tests, and project notes. It contains no built application, DBCode package, licence or account data, credentials, profiles, local databases, signing secrets, or raw real-profile evidence. Sanitized issue notes may retain versions, artifact digests, and pass or fail summaries. Public source visibility does not turn the DBCode Wrapper App into a public release.
_Avoid_: public binary release, bundled DBCode, secret-bearing repository, implied DBCode licence

**Private Personal Release**:
A host-only DMG transferred through a private channel so the license holder can install the DBCode Wrapper App on Apple-silicon Macs they own. The user verifies its checksum and approves the self-signed app through macOS Privacy & Security. DBCode, licence material, credentials, and user profiles are never included in the release.
_Avoid_: public release, third-party distribution, bundled DBCode, paid Apple signing, Apple notarization, disabled Gatekeeper

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
One exact wrapper build with its Code OSS runtime and VSCodium packaging revisions, one exact unchanged DBCode version, and their compatible Standalone DBCode Profile version after the Prompt-Free Release Gate passes. The set is installed and rolled back together even though Code OSS, VSCodium, and DBCode releases are discovered separately.
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
The DBCode Wrapper App may host the legitimately licensed extension for the license holder's private use, but must not modify it, reverse engineer it, bypass its licensing, or share it with others. Written vendor permission is not a project gate.
_Avoid_: patched extension, license bypass, reconstructed DBCode, redistributed DBCode
