# 71 — Deepen focused navigation and remove inert source

Type: task
Status: resolved
Blocked by: none

## Goal

Concentrate DBCode drawer transition rules behind one internal module, remove inert signed-host source, and align generated-skill ignores and current learning material without changing DBCode-owned behaviour.

## Scope

- Keep the Code OSS focused-shell contribution as the adapter and move only persistent and temporary drawer decisions behind one small maintained interface.
- Preserve every visible DBCode route, route-owned collapse and restore, Account-only outside-click and Escape dismissal, bottom query results, automatic update polling, and the status UI.
- Remove the unused QA release-link capture, dead brand CSS, empty extension lifecycle exports, and unconsumed result-location presentation state.
- Add six exact OpenKnowledge skill-projection ignore rules. Do not add a broad agent-directory ignore.
- Refresh only the affected forward-facing agent and wiki guidance.
- Do not remove a complete tracked folder or inspect or delete unknown generated roots.

## Comments

- 2026-08-05: The user approved every evidence-backed candidate from the visual architecture review.
- 2026-08-05: The current prompt-free development gate passed in 27.16 seconds, so this issue does not reduce or parallelize the default test set.
- 2026-08-05: Focused shell, Patch Plan, update status, BSON viewer, Python notebook, and public-source contracts passed. The complete prompt-free development gate then passed without rebuilding or launching the app.
- 2026-08-05: `README.md` already describes the current single-action drawer behaviour, so this internal cleanup does not add another public workflow.
- 2026-08-05: Source commit `5664f1c` added the focused navigation policy, removed inert signed-host source, updated the Patch Plan, and added the six exact generated-skill ignore rules.
- 2026-08-05: Wiki commit `037abbf` refreshed the current drawer guidance. OpenKnowledge reported 0 problems across 32 documents and 0 dead links; the live preview showed the new route-owned collapse and restore wording and no retired shared-control wording.
- 2026-08-05: A clean immutable build from `037abbf` completed with 0 Code OSS TypeScript errors and promoted the signed app. Static Host Smoke passed, including identity, architecture, signature, manifest, installed-size, source-map, built-in inventory, packaged-settings, and no-embedded-DBCode checks.
- 2026-08-05: The persistent `qa` profile rendered smoke passed. Database Explorer, History, and Library stayed open while work moved elsewhere and their own actions collapsed and restored them; Account remained temporary. Query results stayed at the bottom, update status remained reachable, and no unexpected activation error appeared.
- 2026-08-05: Final specification and standards reviews found no remaining product, architecture, regression, wiki, lint, or dead-link findings.

## Work

- [x] Add a focused drawer-navigation interface test.
- [x] Implement the internal drawer-navigation module and keep Code OSS calls in the contribution adapter.
- [x] Remove inert production and source-test paths.
- [x] Update the Patch Plan projection and digests.
- [x] Add the exact ignore rules and refresh current guidance.
- [x] Run focused checks and the complete prompt-free development gate.
- [x] Complete final review and record the answer.

## Answer

Focused Workspace Navigation now owns the small set of drawer transition decisions. The Code OSS contribution remains the adapter that performs the actual work. Every non-Account DBCode drawer stays open while the user works elsewhere and uses its own action to collapse or restore. Account remains temporary.

Unused QA release-link capture code, dead brand CSS, empty lifecycle exports, and unconsumed result-location state are gone. The six generated OpenKnowledge skill projections now have exact public ignore rules. Current agent and wiki guidance describes only the supported behaviour.

No complete tracked folder was removed because none passed the deletion test. Unknown generated roots were not inspected or deleted. The complete prompt-free source gate, clean immutable build, Static Host Smoke, persistent-profile rendered smoke, OpenKnowledge checks, live preview, and final two-axis review all passed. The architecture is good enough at this boundary; another refactor or a smaller default test set is not justified by current evidence.
