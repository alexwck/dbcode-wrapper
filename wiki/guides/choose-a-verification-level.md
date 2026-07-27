---
title: Choose a verification level
description: How to use the smallest prompt-free check that protects a DBCode Wrapper change.
type: guide
tags:
  - wiki
  - guide
  - verification
  - risk
wiki_profile: public
wiki_depth: standard
source_commit: 2008ff48373c1aac378d0d1ec903e96a88ec1e29
---
## Goal

Protect the changed wrapper seam without rebuilding or manually exercising the whole DBCode product on every edit.

## Steps

1. **Classify the change.** Is it prose, one source contract, a compiled-host input, assembly-only content, focused UI, DBCode version, or packaging?
2. **Start narrow.** Run the owning focused test while editing.
3. **Run the source aggregate once.** Use `./script/check_development.sh` before resolving a source change. It must stay below one minute and never launch, use the network, ask a question, or wait for a person.
4. **Build once when needed.** Finish release-bound changes first. Reuse the compiled host when its exact input ID is unchanged.
5. **Inspect the signed app.** Run static smoke for host, identity, inventory, signing, update, or package changes.
6. **Use one rendered profile.** Run the persistent `qa` profile smoke for shell or DBCode version changes. Do not reset it or create disposable profiles.
7. **Add only changed-feature depth.** Use an optional database, file, debugger, notebook, AI, or MCP proof when that exact boundary changed and the proof can be run safely.
8. **Run final exact-release acceptance.** Re-enter the manifest's source, rerun development and static checks, and use only a rendered report with the same release-set ID.
9. **Keep human gates out of deployment.** Keychain, Kernel, Gatekeeper, licence, sign-in, OAuth, secrets, mutation, and external services are normal user actions.
10. **Record honest evidence.** A skipped or unrun live workflow is not a pass.

| Change | Minimum useful check |
| --- | --- |
| Wiki or prose | Link, lint, source anchors, and `git diff --check` |
| Policy, helper, or patch source | Focused test, then development aggregate |
| Compilation input | Development aggregate, one build, static smoke |
| Assembly-only or DBCode-only release input | Reuse verified host, assemble, static smoke |
| Focused shell or DBCode version | Static smoke plus one-profile rendered smoke |
| Private package | Exact-release acceptance plus package checks |
| Live database, notebook, AI, MCP, or mutation | Separate focused proof only when the changed boundary requires it |

## Relevant code

- [Verification Harness](../modules/verification-harness.md)
- [Compiled Host Cache](../modules/compiled-host-cache.md)
- [`docs/agents/verification-policy.md`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/docs/agents/verification-policy.md)
- [`script/check_development.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/check_development.sh)
- [`script/verify_fast_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/2008ff48373c1aac378d0d1ec903e96a88ec1e29/script/verify_fast_release.sh)

## Gotchas

- Source tests cannot prove a patched UI rendered.
- Route visibility does not prove a live DBCode workflow.
- Old smoke logs do not prove the current app.
- A rendered report from another release-set ID cannot be reused.
- An ignored directory is not automatically disposable; use [Generated Workspace Retention](../modules/generated-workspace-retention.md).

## Related

- [DBCode capability evidence](../concepts/dbcode-capability-evidence.md)
- [Representative acceptance fixtures](../concepts/representative-acceptance-fixtures.md)
- [Build, sign, and launch](../flows/build-sign-and-launch.md)