# LibraryGame — Handoff: Issue & Plan

## 1. Context
- Place: LibraryGame (saved; TeamCreate version 64).
- Books, trim, slot markers and shelf ids are generated at runtime by server services.
- Source of truth: `ReplicatedStorage.LibraryGame.BookCatalog` (16 books, 8 shelves, 24 slots).
- Runtime generation is intentional; do not bake books into the saved place.

## 2. Issue
- Core handoff checklist is complete and verified in Play mode.
- Game is functionally correct but NOT ready for a viral player base:
  - No persistence — all progress resets when the server closes.
  - No source control / CI / staging place.
  - No analytics or live tuning.
  - ~1,088 book parts at full occupancy, unprofiled under real load.
- Books are invisible in Edit mode (expected: runtime-generated); this confuses new maintainers.

## 3. What needs to be done (priority order)
1. Persistence (highest priority)
   - Add ProfileStore (session locking, autosave, `BindToClose` flush).
   - One key per player: `User_{UserId}`, with `SchemaVersion`.
   - Save only sparse player-authored state: inventory ids + per-shelf `{slot = bookId}` overrides.
   - Regenerate books/trim from BookCatalog on start; never save all 272 books.
   - Use `UpdateAsync` + retry/backoff; never `SetAsync`.
2. Source control & CI
   - Rojo + Wally + Git; pin dependencies.
   - Maintain a staging place separate from live.
   - CI: Luau type check, Selene lint, Jest Lua / Lune tests.
3. Analytics & live-ops
   - Track pickup/drop/shelf events and session length.
   - Tune distances/capacity via ConfigService without republishing.
4. Performance (measure first)
   - Use Creator Hub dashboard, MicroProfiler, Script Profiler, Dev Console.
   - If rendering-bound: merge per-shelf books into MeshPart / ProceduralModel.
   - Keep StreamingEnabled in mind for larger maps.
5. Networking hardening at scale
   - Send deltas, not whole inventories.
   - Use UnreliableRemoteEvent for cosmetic hover/ghost previews.
   - Keep a typed remote module; validate type, NaN, strings, distances.
6. Optional / later
   - Edit-mode preview of generated content (undoable, never saved).
   - Reserved servers / universe split only if private instances are needed.
   - OrderedDataStore + MemoryStore leaderboards only if required.

## 4. Already completed (do not redo)
- Removed `[dbg drag]` prints; only the Bootstrap startup print remains.
- Drag-to-shelf fixed via `ClientUtil.getShelfContaining` plus input/mouse/shelf-bound fallbacks.
- UI overlap fixed (description box vs drop button).
- Play tests: pickup, drag-to-shelf, click-to-place, drop, re-pickup, range/full warnings.
- Scalability probe passed (shelf auto-register, unique markers, catalog growth).
- `LibraryGame.md` updated with final status and caveats.

## 5. Known caveats
- Two-player test not run (only one Studio client available).
- IDE Script Analysis diagnostics not reachable via Studio MCP; sources compiled with `loadstring`.
- Real 0.32 s double-click not reproducible via MCP timing; branch verified with raised window.
- `game.PlaceVersion` read 53 in Edit session despite save at 64; reopen to confirm.
- Screenshot captured but not visually reviewed by agent — human glance recommended.
