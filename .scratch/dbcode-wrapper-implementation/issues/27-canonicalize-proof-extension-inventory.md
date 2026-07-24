# 27 — Canonicalize the proof extension inventory

**What to build:** Record the exact installed extension set in deterministic ID order so harmless host CLI output ordering cannot invalidate otherwise current acceptance evidence.

**Blocked by:** 02

**Type:** task

**Status:** resolved

- [x] The proof snapshot sorts the complete `--list-extensions --show-versions` output with the repository's canonical locale.
- [x] Sorting does not remove duplicate lines, so an invalid duplicate inventory still fails exact comparison.
- [x] A focused source test proves an unsorted DBCode and Jupyter inventory becomes the expected canonical record.
- [x] Refreshing manifest metadata canonicalizes both the saved and current inventories, preserves duplicates, keeps the seven passing manual checks, and binds the proof to the exact current manifest.
- [x] The public README, host guide, and implementation map explain why the ordering is canonical.

## Comments

- 24 July 2026: Final ticket 08 verification found all seven expected extensions but rejected the proof because Code OSS listed `ms-toolsai.jupyter` before two lexically earlier Jupyter IDs. The verifier already used canonical sorting; the proof collector now does the same before recording the inventory.
- 24 July 2026: Final review caught the migration edge case: comparing an older unsorted saved inventory directly with a new sorted snapshot would discard valid checks. Comparison now canonicalizes both sides without deduplicating them, and a regression test begins with a passed unsorted proof.

## Answer

Real-profile proof evidence now records the exact DBCode and Python/Jupyter inventory in deterministic ID order. Package identity and count remain strict, while irrelevant CLI display ordering can no longer make an unchanged release set appear stale.
