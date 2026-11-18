# Library ALive

A Roblox library game: pick up books, carry them, and reshelve them on the shelves.
The library is shared by 1–4 players and fully server-authoritative.

## Files

- `LibraryIsALive.rbxl` — the Roblox place (open in Studio). This is an older local snapshot.
- `src/` — readable export of all 18 scripts currently in the place (see `src/README.md`).
- `LibraryGame.md` — full handoff: structure, systems, verification, caveats.
- `SaveSchema.md` — per-player save schema (`ProfileTemplate` + `DataService`).
- `IssueAndPlan.md` — remaining work and priorities.

## Persistence (v1)

Per-player stats persist through `ServerScriptService/LibraryGame/Services/DataService` and
`.../Data/ProfileTemplate`. The shared world library and carried books are session-only.

Testing persistence in Studio requires **Game Settings → Security → Enable Studio Access to API Services**.

## Note

The authoritative Lua source lives inside the place in Roblox Studio. `src/` is a
point-in-time export for readable diffs in Git, not a Rojo project — editing `src/` does
not change the game, and the map geometry only exists in the `.rbxl`/cloud place. To
capture the full place, use Studio's *File → Save to File* and commit the `.rbxl`.
