# Issue tracker: Local Markdown

Issues and specs for this repository live as Markdown files in `.scratch/`.

## Conventions

- One effort per directory: `.scratch/<effort-slug>/`
- A specification is `.scratch/<effort-slug>/spec.md`
- Tickets live at `.scratch/<effort-slug>/issues/<NN>-<slug>.md`
- Number tickets from `01`
- Record triage state with a `Status:` line
- Append conversation history under `## Comments`

## Wayfinding operations

- Map: `.scratch/<effort>/map.md`; keep it limited to current state and open or claimed work
- Child ticket: `.scratch/<effort>/issues/NN-<slug>.md`
- Record the ticket type with `Type: research`, `prototype`, `grilling`, or `task`
- Record progress with `Status: open`, `claimed`, or `resolved`
- Record dependencies with `Blocked by: NN, NN`
- A frontier ticket is open, unblocked, and unclaimed
- Claim a ticket by changing its status to `claimed` before starting work
- Resolve a ticket by adding an `## Answer` and changing its status to `resolved`
- Keep resolved tickets as dated history. Remove them from the map's current-work list instead of repeating their old process as current guidance.
- Record new behaviour in the active ticket. Do not reopen or rewrite an older resolved ticket to make it read like current guidance.
