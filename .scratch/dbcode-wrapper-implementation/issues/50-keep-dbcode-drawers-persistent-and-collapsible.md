# 50 — Keep DBCode drawers persistent and collapsible

**What to build:** Keep every DBCode-owned side drawer open while the user works elsewhere, matching Database Explorer. Account remains temporary and still closes on an outside click or Escape. Add one clear wrapper-owned control that collapses the active persistent drawer and restores the last persistent drawer without changing DBCode.

**Blocked by:** none

**Type:** task

**Status:** claimed

- [ ] Tunnels, Authentication Profiles, Streams, History, Library, Database Explorer, and future DBCode views in the same focused sidebar remain open across canvas clicks, result-grid focus, and Escape.
- [ ] Account remains temporary and closes on an outside click or Escape.
- [ ] A visible Collapse drawer control hides the active persistent drawer.
- [ ] The same control becomes Expand drawer and restores the last persistent DBCode view.
- [ ] Opening another DBCode drawer replaces the current drawer.
- [ ] Focused source tests and the one-profile rendered smoke cover the new rule without opening a database, account flow, model, kernel, or macOS prompt.
- [ ] Maintained product, architecture, host, feature-policy, and derived wiki guidance describe only the new rule.

## Comments

- 2026-07-29: Claimed after the user asked to stop outside-click dismissal for DBCode drawers, keep Account as the exception, and add a collapse and expand CTA.

## Answer

Pending implementation and verification.
