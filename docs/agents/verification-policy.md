# Verification policy

The wrapper should be quick to build and release. Tests should protect wrapper-owned behaviour without retesting the whole DBCode product.

## Default rule

Use the narrowest check that can catch the change.

| Change | Required check | Human input |
| --- | --- | --- |
| Wording or documentation only | `git diff --check` and the relevant public-source contract | None |
| One source module, policy, or patch | Its focused test while working | None |
| Completed source change | `./script/check_development.sh` once before resolving the issue | None |
| Signed-host shell change | Static host smoke, then the one-profile rendered smoke | None |
| DBCode or runtime version change | Contribution comparison, changed-feature checks, and the one-profile rendered smoke | None |
| Release packaging and publishing | Automated release identity, static smoke, one-profile rendered smoke, package checks, and public asset verification | None |

The fast source gate should stay comfortably below one minute on the normal development machine. It must not launch the app, use the network, ask a question, or wait for a person. A large timing increase is a regression to investigate, even when the tests still pass.

## Test ownership

- Each test module has one maintained runner.
- Shell runners use the pinned Node runtime instead of whichever `node` happens to be on `PATH`.
- Move a test and remove its old runner in the same change.
- Test public script interfaces when path handling or command behaviour is the contract.
- A visible wrapper command needs a focused source test proving it is registered before startup state is known and routes missing prerequisites safely.
- Keep fixtures local, deterministic, small, and free of private data.
- Do not add a full rendered test for behaviour already proved by a source contract unless rendering is the risk.
- Run deep build and release task fixtures, gate-composition, public-push, host-package, publishing, or deep rollback tests only when a change owns that workflow.
- The focused runtime-setup contract runs the small synthetic Open VSX mutation matrix through the shared verifier. Small composition and path checks cover the production setup and package-file adapters. The real cached-package verifier runs only when the verifier, an adapter, or the pinned runtime set changes.

## Prompts and external services

An automated run must never stop for a click, password, approval, account, or external service.

Kernel, Keychain, Safe Storage, Gatekeeper, OAuth, sign-in, licence, debugger, mutation, and external data-sharing prompts belong to normal app use. They are not automated test steps and are not required halfway through deployment. Never intercept or approve them automatically.

The rendered smoke avoids actions that can open these prompts. It verifies that notebook, Query Builder, and AI routes remain visible without activating them. It opens a SQL file but does not read or change a database.

Use one persistent generated `qa` profile. Keep its normal DBCode state between runs. Do not reset it, create disposable profiles, or test first-launch migration and recovery in the default deployment path.

## Fast DBCode version bumps

DBCode is unchanged upstream software. A version bump should verify the wrapper boundary:

1. Read the official changelog and changed feature pages.
2. Compare the exact package manifest, contributions, settings, menus, views, editors, tools, and connection-catalogue fingerprint.
3. Update the candidate Release Specification and only the compatibility policy that changed.
4. Reuse verified source, package, and Compiled Host caches by digest.
5. Run focused source checks for changed wrapper seams.
6. Confirm added or changed DBCode routes remain visible. Add a deeper check only when it is prompt-free and the changed surface needs it.
7. Keep model calls, real credentials, mutation, human prompts, and external-service checks outside deployment.
8. Finish and commit the exact release source.
9. Run `./script/release_host.sh prepare`. It owns the prompt-free signing check, build or exact reuse, static smoke, one persistent-profile rendered smoke, final acceptance, tag, package, independent verification, and approval.
10. Review and commit its one change to `host/approved-release-history.json`.
11. Run `./script/release_host.sh publish --publish` as a separate explicit action, then verify the public release and its two assets.

Do not run a live model merely because an AI route exists. Do not test every supported database. Do not rebuild an unchanged host for every source assertion. Do not create a new issue or refresh the wiki for a routine version bump unless wrapper behaviour, compatibility, or the release channel changes.

Do not add a standalone complete source gate, build, static smoke, or rendered smoke before `prepare` unless you are developing or investigating a failure. `prepare` owns those stages and reuses a complete exact Host or rendered report when it already matches. Final acceptance still reruns the source gate and static smoke from the manifest's materialized source so release evidence cannot rely on detached earlier logs.

The prompt-free final acceptance command is the only maintained release acceptance path. Retained evidence and rollback records remain protected, but they do not define another test or release workflow.

`build_host.sh` requires one clean immutable release commit and materializes it before reading build inputs. It checks the existing signing identity without prompting, then reuses the Compiled Host when its exact compilation input ID and mode-sensitive app digest match. The smaller assembly writes the complete signed app and manifest to one fixed private candidate and promotes them together, so a failed candidate leaves the last complete `dist/` checkpoint unchanged. The operating system holds the lease until the last inherited process exits. Fixed candidate and previous paths let the next owner recover an interrupted promotion without PID files or stale-lock guessing. A cache hit uses the compiler environment stored in the receipt and skips compiler-only preflights. A documentation, test, historical-adapter, or DBCode-only change still receives a new auditable source snapshot and final manifest, but it does not recompile Code OSS unless a real compilation input changed.

Final acceptance does not accept saved development or static-smoke success logs. It materializes the source snapshot in the signed manifest, reruns the fast development contracts there, and reruns static smoke against the exact signed app. The rendered report is reusable only when its exact release-set ID matches.

The materialized source may reuse the launcher checkout's ignored caches and pinned toolchain. It must not inspect the launcher's mutable `.build/work` tree as if that generated tree belonged to the accepted source.

## Representative rendered coverage

One rendered smoke should cover the wrapper shell and a small set of useful paths:

- Connections and the unchanged New Connection catalogue;
- persistent DBCode drawer collapse and restore, plus temporary Account dismissal;
- opening a SQL file without executing it;
- visible Query Builder, notebook, AI, MCP, and DBCode Settings routes without activating them;
- any route added or changed by the candidate.

This proves the wrapper still exposes DBCode. It does not claim live database, kernel, cloud, model, licence, or external-client execution.

## Failure handling

- Put timeouts around GUI startup, shutdown, and external processes.
- Keep `dist/` behind the maintained checkpoint lease. A reader must fail when another command owns it, and only a complete staged app and manifest may replace the last checkpoint.
- On resume, revalidate the exact DMG, checksum, compatibility record, notes, verification receipt, and approval digests. A directory's presence is not completion evidence.
- Terminate only the isolated process created by the current test.
- Keep the original error when cleanup also has a problem.
- Give every temporary file one owner and test cleanup on failure as well as success.
- Record sanitized pass or fail evidence in the owning issue.
- Do not turn a normal macOS or DBCode prompt into a test step.
