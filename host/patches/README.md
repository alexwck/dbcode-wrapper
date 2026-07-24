# Maintained patch overlay

The patch overlay changes the pinned upstream source without vendoring a Code OSS or VSCodium checkout.

Patches are maintained by semantic seam, not by the chronology of UI experiments:

1. product identity and macOS packaging;
2. the final focused DBCode shell;
3. host slimming policy;
4. small release and profile integrations.

[`patch-plan.json`](patch-plan.json) defines each patch's order, purpose, owned files, and digest. `script/prepare_source.sh` validates and applies only that plan to clean pinned checkouts. An unlisted patch, a changed patch digest, duplicate file ownership, or a mismatched upstream commit fails before source preparation starts.

The Code OSS stage has four maintained seams:

1. macOS product packaging;
2. the final focused DBCode shell;
3. host slimming policy;
4. small release, profile, and DBCode integrations.

The migration proof in the manifest records the 13-patch historical stack and the digest of all 13 maintained source paths. Replaying the four semantic patches produced the same patch-stage digest. The manifest separately records the final prepared-tree digest because VSCodium performs one deterministic copyright substitution after patch application. Source contracts inspect the final tree and semantic outcomes rather than depending on obsolete experiment names.

Never edit the generated checkout under `.build/work/` as the source of truth. Make the change in the maintained patch, apply it to a clean pinned checkout, and verify the final tree before updating its expected digest.
