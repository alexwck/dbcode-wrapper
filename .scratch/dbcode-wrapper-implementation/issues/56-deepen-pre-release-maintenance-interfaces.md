# 56 — Deepen pre-release maintenance interfaces

**What to change:** Keep routine wrapper work fast by moving deep build and release fixture checks out of the default source gate, shrinking unused module exports, materializing Host Configuration once, removing the retired Patch Plan migration proof, and deleting obsolete forward-facing guidance and expired generated output.

**Blocked by:** None

**Type:** maintenance

**Status:** resolved

## Answer

Routine wrapper checks are smaller without losing the deeper workflow coverage. The default development gate no longer runs the build-task and release-task fixture suites. Both suites remain maintained and passed independently because this change owned those workflows. The complete default gate passed in 21.83 seconds, compared with the earlier 41.16-second baseline.

Host Configuration now validates the Release Specification once and extracts its complete checked shell snapshot once. Existing purpose records and shell variables remain unchanged. The active record projection is part of the Compiled Host identity, so this source change deliberately causes one cold build at the next release.

The Patch Plan now contains only its six current entries, overlay records, and prepared-tree digest. Sixteen unused CommonJS exports were removed while their internal implementations stayed in place. Current documentation explains the supported workflow in plain English; obsolete ground-up-host research was removed after its lasting decision was captured in Issue 11 and maintained architecture guidance.

No `.gitignore` change was needed. Generated, private, build, release, QA, and evidence roots are already covered by the existing policy and the public-source contract passed. The guarded cleanup removed the exact 64-byte `.build/expired` root, and the empty top-level `issues/` directory was removed. No cache, profile, signed app, release asset, rollback data, or QA evidence was touched.

Verification passed: focused Release Specification, Patch Plan, Compiled Host Cache, runtime setup, update status, profile migration, Host Session, generated workspace, and gate-composition contracts; the change-owned build and release task suites; shell syntax checks; the complete prompt-free development gate; public-source checks; OpenKnowledge lint; zero dead links; and a running wiki preview. The production process-table fixture remained skipped under the current sandbox, as expected; its other Host Session contracts passed.

- [x] Keep prompt-free contract coverage in the default development gate and move expensive build/release fixture tests to their owning changes.
- [x] Remove unused CommonJS exports without removing their private implementations.
- [x] Validate the Release Specification once and materialize all Host Configuration values in one extraction.
- [x] Keep the current semantic Patch Plan and prepared-tree proof while removing its one-time migration proof.
- [x] Remove obsolete research and rewrite maintained guidance in forward-looking plain English.
- [x] Apply only the approved exact-path generated cleanup.
- [x] Run focused contracts and the complete prompt-free development gate.
- [x] Review and commit the changes in dependency order.
