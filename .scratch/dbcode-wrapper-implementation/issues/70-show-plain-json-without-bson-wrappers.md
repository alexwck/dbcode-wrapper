# 70 — Show plain JSON without BSON wrappers

**What to change:** Keep Tree as the default BSON Result Viewer mode. Replace the Raw JSON presentation with readable key-value JSON that removes supported BSON type wrappers while Tree and Table continue to show separate type information.

**Blocked by:** None

**Type:** task

**Status:** resolved

## Comments

- 2026-08-04: Claimed after the user confirmed that Tree should remain the default and asked for the JSON tab to show key-value pairs without BSON type wrappers.
- 2026-08-04: The existing public display-model seam will own the plain JSON text. Exact ordinary JSON numbers must keep their source spelling, valid Extended JSON scalars must become readable JSON values, and embedded JSON strings must remain opt-in.
- 2026-08-04: Focused review found that turning off `Parse JSON strings` must restore the original string presentation after an expanded document has loaded. The display model now retains both plain forms, and the rendered route covers switching in both directions.
- 2026-08-04: The focused BSON Result Viewer contract passed all 12 tests. `./script/check_development.sh`, `git diff --cached --check`, and `git diff --check` also passed. The rendered acceptance route was updated for the next built-host check; this source change did not rebuild or launch the app.

## Work

- [x] Add focused display-model coverage for plain JSON without supported BSON type wrappers and exact numeric values.
- [x] Keep Tree as the initial view and replace Raw JSON with the readable JSON presentation.
- [x] Preserve opt-in embedded JSON expansion and the local in-memory privacy boundary.
- [x] Update maintained product and host guidance.
- [x] Run focused viewer checks and the complete prompt-free development gate.

## Answer

Tree remains the default and Tree/Table keep their separate BSON type information. The third tab is now `JSON`; it shows readable key-value JSON such as `"requestedamount": 0` without supported Extended JSON type wrappers. Exact number spelling is preserved, ordinary strings such as `"0"` remain strings, and `Parse JSON strings` stays optional and reversible. Clipboard/file input remains explicit, in memory, and disconnected from databases, DBCode internals, persistence, and the network.
