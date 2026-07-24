---
title: Choose a verification level
description: How to match the cost and realism of DBCode Wrapper checks to the risk of a change.
type: guide
tags:
  - wiki
  - guide
  - verification
  - risk
wiki_profile: public
wiki_depth: standard
source_commit: fbf29827376fd0ea5867082b78e38862878f42b6
---
## Goal

Run enough evidence to protect the changed boundary without rebuilding and manually exercising the entire app for every edit.

## Steps

1. **Classify the change.** Identify whether it affects only prose, a source contract, the built host, a real profile, an external database, or release switching.
2. **Start narrow.** Run the closest unit or shell contract while developing.
3. **Add the aggregate gate.** Run `./script/check_development.sh` before handing off a source change unless the issue defines a stronger gate.
4. **Add a built-app gate when needed.** Build and inspect the app after patch, extension inventory, product identity, signing, or packaging changes.
5. **Add a rendered gate for UI work.** Check real pixels and interactions after focused-shell, editor, panel, context-menu, notification, or window-layout changes.
6. **Add a real-profile gate for stateful work.** Use the private standalone profile for licence activation, Keychain, credentials, external extensions, first-run, recovery, and relaunch behavior.
7. **Add representative workflows.** Exercise PostgreSQL, SQLite, DuckDB/Parquet, or notebooks according to the boundary changed. Add another supported database when the change touches general connection routing.
8. **Use the full release gate before promotion.** Verify the prepared set, signing, full quit/relaunch, required database matrix, persistence, package sanitization, installed health, and rollback.
9. **Inspect generated output safely.** Use `./script/generated_workspace.sh inventory`; do not measure or clean ignored directories by guessing from their names.
10. **Record honest evidence.** Do not convert a skipped external dependency or manual macOS prompt into a fake pass.

| Change | Minimum useful level |
| --- | --- |
| Wiki or prose only | Link, lint, and source-anchor checks |
| JSON schema or shell/JS helper | Narrow tests plus development aggregate |
| Generated output or retention rule | Retention contract tests, inventory, and a dry-run refusal check |
| Patch or wrapper extension | Development aggregate plus built-app inspection |
| Focused UI | Built app plus rendered interaction check |
| Profile, licence, Keychain, connection, notebook | Real standalone profile plus quit/relaunch |
| Release, signing, promotion, rollback | Full private release and rollback gates |

## Relevant code

- [Verification Harness](../modules/verification-harness.md)
- [Generated Workspace Retention](../modules/generated-workspace-retention.md)
- [`script/check_development.sh`](https://github.com/alexwck/dbcode-wrapper/blob/fbf29827376fd0ea5867082b78e38862878f42b6/script/check_development.sh)
- [`script/verify_release_set_static.sh`](https://github.com/alexwck/dbcode-wrapper/blob/fbf29827376fd0ea5867082b78e38862878f42b6/script/verify_release_set_static.sh)
- [`script/verify_private_release.sh`](https://github.com/alexwck/dbcode-wrapper/blob/fbf29827376fd0ea5867082b78e38862878f42b6/script/verify_private_release.sh)

## Gotchas

- A source test cannot prove a patched Code OSS UI rendered correctly.
- A successful first launch cannot prove secure-storage or profile persistence after a full quit.
- A sample SQLite query cannot prove a stopped PostgreSQL service is reachable.
- The strongest gates use ignored private state and may require the owner to answer macOS permission prompts.
- An ignored directory is not automatically disposable. Cleanup planning must use the maintained retention classification and exact path checks.

## Related

- [Representative acceptance fixtures](../concepts/representative-acceptance-fixtures.md)
- [Build, sign, and launch](../flows/build-sign-and-launch.md)
- [Controlled upgrade and rollback](../flows/controlled-upgrade-and-rollback.md)
