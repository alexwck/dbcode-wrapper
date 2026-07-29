# 50 — Keep DBCode drawers persistent and collapsible

**What to build:** Keep every DBCode-owned side drawer open while the user works elsewhere, matching Database Explorer. Account remains temporary and still closes on an outside click or Escape. Add one clear wrapper-owned control that collapses the active persistent drawer and restores the last persistent drawer without changing DBCode.

**Blocked by:** none

**Type:** task

**Status:** resolved

- [x] Tunnels, Authentication Profiles, Streams, History, Library, Database Explorer, and future DBCode views in the same focused sidebar remain open across canvas clicks, result-grid focus, and Escape.
- [x] Account remains temporary and closes on an outside click or Escape.
- [x] A visible Collapse drawer control hides the active persistent drawer.
- [x] The same control becomes Expand drawer and restores the last persistent DBCode view.
- [x] Opening another DBCode drawer replaces the current drawer.
- [x] Focused source tests and the one-profile rendered smoke cover the new rule without opening a database, account flow, model, kernel, or macOS prompt.
- [x] Maintained product, architecture, host, feature-policy, and derived wiki guidance describe only the new rule.

## Comments

- 2026-07-29: Claimed after the user asked to stop outside-click dismissal for DBCode drawers, keep Account as the exception, and add a collapse and expand CTA.
- 2026-07-29: Implemented the generic persistent-drawer rule in the focused Code OSS shell. The wrapper remembers the last persistent DBCode view for the current app session, exposes one Collapse drawer or Expand drawer control, and leaves Account as the only temporary drawer.
- 2026-07-29: Verification passed with the focused source contract, `check_development.sh`, a clean host rebuild, static host smoke, and the prompt-free one-profile rendered smoke. The rendered run covered Database Explorer, History, Library replacement, collapse and restore, outside canvas clicks, Escape, and Account dismissal. It did not open a live database, execute SQL, start a kernel, call an AI model, or enter an account flow.

## Answer

All focused-shell DBCode drawers now stay open when the user clicks the canvas, focuses another DBCode surface, or presses Escape. Account is the only exception and remains temporary.

The toolbar shows **Collapse drawer** while a persistent drawer is open. After collapse, it becomes **Expand drawer** and restores the last persistent DBCode view used in the current app session. Opening a different drawer replaces the current one.
