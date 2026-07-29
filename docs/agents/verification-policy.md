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
- Keep fixtures local, deterministic, small, and free of private data.
- Do not add a full rendered test for behaviour already proved by a source contract unless rendering is the risk.
- Run gate-composition, public-push, host-package, publishing, or deep rollback tests only when a change owns that workflow.
- The focused runtime-setup contract runs the small synthetic Open VSX mutation matrix through both acquisition adapters. The real cached-package verifier runs only when the verifier, an adapter, or the pinned runtime set changes.

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
6. Finish all release-bound changes, then run the complete source gate once from the final exact source.
7. Build and sign once, then run the one persistent-profile rendered smoke.
8. Confirm added or changed DBCode routes remain visible. Render a deeper surface only when doing so is prompt-free.
9. Keep model calls, real credentials, mutation, human prompts, and external-service checks outside deployment.
10. Run `./script/release_host.sh prepare` to accept, tag, package, independently verify, and approve the exact release set.
11. Review and commit its one change to `host/approved-release-history.json`.
12. Run `./script/release_host.sh publish --publish` as a separate explicit action, then verify the public release and its two assets.

Do not run a live model merely because an AI route exists. Do not test every supported database. Do not rebuild an unchanged host for every source assertion. Do not create a new issue or refresh the wiki for a routine version bump unless wrapper behaviour, compatibility, or the release channel changes.

The prompt-free final acceptance command is the only maintained release acceptance path. Retained evidence and rollback records remain protected, but they do not define another test or release workflow.

`build_host.sh` requires one clean immutable release commit and materializes it before reading build inputs. It reuses the Compiled Host when its exact compilation input ID and mode-sensitive app digest match, then performs the smaller extension, release-record, signing, and manifest assembly. A cache hit uses the compiler environment stored in the receipt and skips compiler-only preflights. A documentation, test, historical-adapter, or DBCode-only change still receives a new auditable source snapshot and final manifest, but it does not recompile Code OSS unless a real compilation input changed.

Final acceptance does not accept saved development or static-smoke success logs. It materializes the source snapshot in the signed manifest, reruns the fast development contracts there, and reruns static smoke against the exact signed app. The rendered report is reusable only when its exact release-set ID matches.

The materialized source may reuse the launcher checkout's ignored caches and pinned toolchain. It must not inspect the launcher's mutable `.build/work` tree as if that generated tree belonged to the accepted source.

## Representative rendered coverage

One rendered smoke should cover the wrapper shell and a small set of useful paths:

- Connections and the unchanged New Connection catalogue;
- Database Explorer;
- opening a SQL file without executing it;
- visible Query Builder, notebook, AI, MCP, and DBCode Settings routes without activating them;
- any route added or changed by the candidate.

This proves the wrapper still exposes DBCode. It does not claim live database, kernel, cloud, model, licence, or external-client execution.

## Failure handling

- Put timeouts around GUI startup, shutdown, and external processes.
- Terminate only the isolated process created by the current test.
- Keep the original error when cleanup also has a problem.
- Record sanitized pass or fail evidence in the owning issue.
- Do not turn a normal macOS or DBCode prompt into a test step.
