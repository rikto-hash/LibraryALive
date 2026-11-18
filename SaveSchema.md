# LibraryGame — Save Schema

## Model
- The library is **shared**: one library per server; all players (1–4) see and edit the same shelves.
- The server is authoritative; clients only request changes.
- **v1:** the world library is session-only (regenerated from BookCatalog each server start).
- **v1:** each player's **Stats** persist; carried books are session-only.

## Rules
- Store ids, never instances or runtime uids.
- Store only what changed (sparse tables).
- Always include `SchemaVersion`; migrate old data, never wipe it.
- One DataStore key per player: `User_{UserId}`.
- Use `UpdateAsync`, never `SetAsync`; wrap calls in pcall with retries.
- Never save the 272 book models, trim, or slot markers — regenerate them.

## Player profile (persisted)
```lua
{
    SchemaVersion = 1,
    Stats = {
        BooksShelved   = 0,
        SessionsPlayed = 0,
        SecondsPlayed  = 0,
    },
}
```

## World library (in-memory in v1; optional global save later)
```lua
{
    SchemaVersion = 1,
    Placements = {
        -- [shelfId] = { [slot] = bookId }
        shelf_01 = { [1] = "book_05", [2] = "book_11" },
        shelf_02 = { [3] = "book_05" },
    },
}
```
- Only slots the players changed are listed; an empty slot is simply absent.
- v1 does not persist this. If added later, save ONE global record (reserved server or lock) — never per player.

## Migration
- On load: if `data.SchemaVersion < 1`, run migrations in order, then save.
- To add a field: update `ProfileTemplate`, bump its `SchemaVersion`, add a migration step.
