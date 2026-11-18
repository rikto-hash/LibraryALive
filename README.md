# Library ALive

A Roblox library game: pick up books, carry them, and reshelve them on the shelves.
The library is shared by 1–4 players and fully server-authoritative.

## Files

- `LibraryIsALive.rbxl` — the Roblox place (open in Studio).
- `LibraryGame.md` — full handoff: structure, systems, verification, caveats.
- `SaveSchema.md` — per-player save schema (`ProfileTemplate` + `DataService`).
- `IssueAndPlan.md` — remaining work and priorities.

## Persistence (v1)

Per-player stats persist through `ServerScriptService/LibraryGame/Services/DataService` and
`.../Data/ProfileTemplate`. The shared world library and carried books are session-only.

Testing persistence in Studio requires **Game Settings → Security → Enable Studio Access to API Services**.

## Note

The Lua source currently lives inside the `.rbxl` place file. A future step is to move the
scripts to disk with Rojo so Git can track script changes as readable diffs.
