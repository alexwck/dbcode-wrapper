# Ground-up DBCode desktop host feasibility

Date: 18 July 2026

## Question

Can DBCode Wrapper keep the official, unchanged DBCode `1.36.1` package from Open VSX but replace Code OSS/VSCodium with a much smaller desktop application built from the ground up?

## Short answer

Not as a direct swap.

Open VSX stores and distributes the DBCode extension; it does not run it. DBCode is an implementation of the VS Code extension interface. It still needs a compatible extension host and the workbench services that provide editors, views, custom editors, notebooks, webviews, commands, storage, secrets and other APIs.

A new native or Monaco-based shell would therefore have to recreate a large part of that host contract. That is likely to cost more to maintain than the current Code OSS overlay. The practical next step is to measure and slim the current Code OSS package, while keeping the unchanged extension and the approved Code OSS/DBCode release pair. A truly ground-up app becomes sensible only if DBCode publishes or supplies a supported standalone engine, SDK or process API.

## Evidence

### The package needs a VS Code-compatible runtime

The public DBCode installation guide lists Visual Studio Code as a requirement and describes DBCode as a database IDE that lives inside VS Code and compatible forks. The Open VSX listing identifies it as a database client for VS Code, Cursor and Windsurf and says it requires VS Code `^1.95.0`.

- [DBCode installation guide](https://dbcode.io/docs/get-started/install)
- [DBCode on Open VSX](https://open-vsx.org/extension/DBCode/dbcode)
- [Open VSX describes itself as an extension registry](https://open-vsx.org/about)

The locally installed, unmodified `package.json` under the user's private DBCode Wrapper extension directory confirms the important host contract without inspecting DBCode implementation code:

- Node entry point through `main`; there is no browser entry point.
- VS Code engine requirement `^1.95.0`.
- Activation at startup, for SQL, and for its notebook and renderer.
- 170 declared commands.
- Contributions for activity-bar and panel views, a custom editor, a notebook, a notebook renderer, settings, menus, keybindings, language-model tools and an MCP server provider.

Microsoft documents that a `main` extension runs in a Node.js extension host, while a browser extension needs a `browser` entry point. It also documents that workbench extensions use host-provided views, webviews and other UI services. This means DBCode is more than a SQL language service that could be attached to an editor widget.

- [VS Code Extension Host](https://code.visualstudio.com/api/advanced-topics/extension-host)
- [VS Code extension manifest](https://code.visualstudio.com/api/references/extension-manifest)
- [VS Code extension capabilities](https://code.visualstudio.com/api/extension-capabilities/overview)

### Monaco is an editor, not an extension host

Microsoft's Monaco FAQ directly says a VS Code extension does not run in Monaco. The narrow exception is an extension based entirely on a JavaScript language server. DBCode's manifest shows that it is not in that category: its main product surfaces are views, custom editors, notebooks, renderers and commands.

- [Monaco Editor FAQ](https://github.com/microsoft/monaco-editor#faq)

### Code OSS provides a deep, high-leverage module

Microsoft describes Code OSS as layered and modular internally. The `workbench` layer hosts Monaco, notebooks and custom editors; the `workbench/api` layer provides both sides of the VS Code extension API; and the desktop `code` layer stitches the workbench, extension host, Electron processes and command line together.

- [Code OSS source organisation](https://github.com/microsoft/vscode/wiki/source-code-organization)

VSCodium is not a separate editor engine from which a few database parts can be extracted. Its own project describes itself as build scripts and configuration that turn Microsoft's Code OSS repository into freely licensed binaries. In the current project, VSCodium is therefore the build and packaging layer; Code OSS is the runtime implementation DBCode uses.

- [VSCodium project description](https://github.com/VSCodium/vscodium)

This is the important design boundary:

- **Interface:** the documented VS Code extension API and contribution points.
- **Implementation:** unchanged DBCode `1.36.1`.
- **Host module:** the Code OSS extension host plus workbench services.
- **Current seam:** the release lock and small Code OSS overlay.

Code OSS has high leverage because one host module satisfies many DBCode features. Replacing it with a small custom host would reduce locality: every missing API or UI behaviour could require a new adapter in another part of the app. The official documentation does not present the desktop extension host/workbench as a small supported SDK. Based on that documented architecture, copying selected Code OSS internals would still create a custom Code OSS fork, but with more missing pieces and more compatibility work.

### The current size has several separate causes

Local read-only measurements of the signed app give this baseline:

| Item | Installed/on-disk size | Notes |
| --- | ---: | --- |
| `DBCode Wrapper.app` | 916 MiB | Current signed app bundle, measured with `du -sh`. |
| Electron framework | 265 MiB | Almost all of the app's 266 MiB `Frameworks` directory. |
| Code OSS `Resources/app` | 627 MiB | Includes 315 MiB `out`, 148 MiB `node_modules`, and 163 MiB built-in extensions. |
| External DBCode `1.36.1` | 262 MiB | Installed outside the app; logical file size is 259.4 MiB. |
| Combined current footprint | about 1.15 GiB | App plus expanded DBCode extension. |

The DBCode VSIX itself is 43,262,773 bytes, or about 41.3 MiB, according to [`host/release-lock.json`](../../../host/release-lock.json). Expansion after installation explains why its installed size is much larger.

Download size is different from installed size. Streaming the current app through ordinary `tar` plus `gzip -6` produced a 264,916,298-byte archive, or about 252.6 MiB. That is only an indicative compression measurement, not a release artifact; a signed ZIP or DMG will differ. Adding the separate DBCode VSIX gives an indicative first-download total near 294 MiB, while the installed total remains about 1.15 GiB.

Electron itself embeds Chromium and Node.js. A new Electron or desktop Theia application would therefore retain a substantial runtime baseline even if its JavaScript application were smaller.

- [Electron prerequisites and embedded runtime](https://www.electronjs.org/docs/latest/tutorial/tutorial-prerequisites)

## Options

| Option | Can run unchanged DBCode? | Likely size result | Maintenance result |
| --- | --- | --- | --- |
| Keep Code OSS and remove proven-unused content | Yes | Moderate reduction is plausible. The 163 MiB built-in-extension directory is an upper bound, not a safe removal list. Electron and DBCode remain. | Lowest risk. Keeps the existing stable extension API seam and release-pair tests. |
| Build a custom Eclipse Theia desktop product | Possibly, after a full proof | Unknown. Theia desktop also uses Electron, so it does not remove the 265 MiB class of runtime cost or the 262 MiB expanded DBCode package. | High migration cost. Theia says some VS Code API parts are stubbed, so every DBCode feature needs testing. It also adds a new upstream compatibility track. |
| Build a Monaco, SwiftUI or AppKit shell and load the VSIX | No, not directly | The shell could be smaller, but the unchanged extension would not run. | Very high. It requires implementing or adapting the extension host, workbench API, views, notebooks, custom editors, storage and secrets. |
| Run a headless extension host behind a new native UI | Not with the public contract alone | Unknown | Very high. DBCode contributes UI through VS Code APIs, and extensions cannot directly control the host DOM. A new bridge would effectively recreate workbench behaviour. |
| Use a supported DBCode standalone engine/SDK | Yes, if DBCode offers one | Best chance of a genuinely smaller native app | Potentially good, because the vendor-defined API would be a stable seam. No such public standalone interface was found in the reviewed DBCode or Open VSX documentation. |
| Reimplement the database features | No; it would be a different product | Potentially smaller after a large rewrite | Largest scope and upkeep. It abandons the value of the purchased DBCode implementation and is outside this project's unchanged-extension boundary. |

Theia is the only credible alternative host worth a bounded experiment because it deliberately supports VS Code extensions and lets adopters compose custom products. However, its own documentation warns that some APIs are only stubbed, and its desktop target is Electron. It should not replace the current host unless a prototype passes the complete DBCode feature matrix and demonstrates a material installed-size reduction.

- [Theia extension compatibility and stubs](https://theia-ide.org/docs/user_install_vscode_extensions/)
- [Composing a custom Theia desktop application](https://theia-ide.org/docs/composing_applications/)

## Recommendation

Keep Code OSS as the hidden compatibility engine for now. Do not start a ground-up desktop rewrite before Appshot feedback.

Create one bounded size-reduction ticket with these gates:

1. Define a target for both compressed download size and installed size.
2. Produce a reproducible bundle inventory.
3. Remove only built-in extensions and resources proven unnecessary for DBCode.
4. After each removal group, verify activation, licence persistence, Keychain use, PostgreSQL, DuckDB, Parquet, SQL files, query results, connections, history, library, account, custom editors, notebooks and update compatibility.
5. Keep a rollback list and compare the actual signed app and compressed release sizes.

In parallel, one small vendor question is worthwhile: ask whether DBCode offers a supported standalone SDK, service process or documented host API for licensed customers. If the answer is yes, reassess a native shell around that supported seam. If the answer is no, the current Code OSS wrapper is the maintainable architecture, and UI work should continue as a focused database-client redesign rather than as a new editor platform.

## Confidence and remaining unknowns

Confidence is high that Open VSX plus Monaco cannot run the unchanged extension by itself. Confidence is medium that slimming Code OSS will produce a user-visible installed-size reduction; the local inventory shows opportunity, but safe removals depend on real DBCode feature tests. The exact Theia compatibility and packaged size remain unknown until a bounded prototype is built, so Theia should be treated as a comparison experiment, not the new default architecture.
