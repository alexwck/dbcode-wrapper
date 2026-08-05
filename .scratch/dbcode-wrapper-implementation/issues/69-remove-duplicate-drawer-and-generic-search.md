# 69 — Remove duplicate drawer and generic search controls

**What to change:** Remove the dedicated Collapse/Expand drawer action because existing DBCode navigation and drawer chrome already close and restore the same views. Keep persistent DBCode drawers, keep Account temporary, and hard-hide the generic Code OSS title-bar command center even if profile state drifts.

**Blocked by:** None

**Type:** task

**Status:** resolved

## Comments

- 2026-08-04: Claimed after the installed UI showed an Expand drawer action that duplicated Database Explorer and a visible but non-functional search control.
- 2026-08-04: Source history confirms the drawer action was wrapper-owned. The strongest search diagnosis is Code OSS's command center: the focused shell disables pointer interaction in that title row, while managed settings normally keep the command center hidden. The fix must make the focused presentation independent of mutable profile state.
- 2026-08-04: The focused regression first failed in 0.5 seconds because persistent menu routes still opened drawers without toggling them. Database Explorer already used the desired route-owned toggle.
- 2026-08-04: Removed the shared drawer button and last-drawer state. Database Explorer, Tunnels, Authentication Profiles, Active Streams, History, and Library now use their own existing actions to collapse and restore the visible drawer. Drawer persistence and Account dismissal did not change.
- 2026-08-04: The focused shell now hides the complete Code OSS command-center element with CSS as well as keeping its managed setting disabled. DBCode-owned search and the BSON Result Viewer search remain unchanged.
- 2026-08-04: The focused shell and Patch Plan contracts passed. `./script/check_development.sh` passed without rebuilding or launching the app, and the rendered test source now expects no shared drawer action, no visible command center, route-owned History and Library toggles, and unchanged temporary Account behaviour.
- 2026-08-04: This changes the Compiled Host input. The next signed Host build must run Static Host Smoke and the one-profile rendered smoke before release; the currently installed app was not rebuilt in this issue.

## Work

- [x] Add a focused regression signal for the duplicate drawer action and generic command center.
- [x] Remove only the redundant wrapper action while preserving drawer persistence and Account dismissal.
- [x] Hard-hide the generic command center without hiding DBCode-owned search or the BSON Result Viewer search.
- [x] Update forward-facing behaviour documentation.
- [x] Run the focused shell contract and complete prompt-free development gate.
- [x] Record rendered verification requirements for the next signed Host build.

## Answer

The focused shell no longer creates a separate Collapse or Expand drawer action. Each persistent DBCode route now owns both directions: choose the visible route again to collapse its drawer, then choose it again to restore it. Choosing another route still replaces the visible drawer, while Account remains temporary and closes on outside click or Escape.

The generic Code OSS title-bar command center is now hidden by the focused presentation even if mutable profile state enables it. This removes the visible but non-functional search control without changing DBCode-owned search or the local BSON Result Viewer search.

The focused regression, Patch Plan contract, JavaScript syntax check, public-source checks, and complete prompt-free development gate passed. The source change will appear in the next signed Host build; that build still needs Static Host Smoke and the maintained one-profile rendered smoke.
