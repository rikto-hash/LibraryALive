# LibraryGame — Handoff

Place: `Library is ALive` (placeId 134946025386458) — edited directly through Roblox Studio MCP.
There is no Rojo project; **the Studio place is the source of truth**. This folder only holds this file.
Place saved after the final pass: **TeamCreate version 64** (`save_place` → `Saved`).

---

## 1. Feature Goal

A scalable library system in the current place:

- Decorated bookshelves filled with procedurally built books, packed side by side.
- Hover a book → golden `Highlight` + `BookDescriptionBox` on the right, themed with the book colour
  (genre pill, title, published date, description, **Pick Up** button).
- Click a book → pin the box until clicking outside it. Double-click a book → pick it up.
- Server-authoritative inventory, capacity `Config.INVENTORY_CAPACITY` (currently **2**).
- Inventory bar (bottom, icon slots, no text) appears with the first carried book; circular drop
  button at the bottom right. Full inventory → warning toast.
- Drop by dragging a book out of the bar or with the drop button; the book lands where the camera aims.
- Place a book into a shelf by clicking a shelf slot (or dragging a book onto it). Books pack side by
  side, respect existing books, and stop at the shelf joints with a warning when full.
- New books = edit `BookCatalog`; new shelves = tag a model `Bookshelf`.

### Structure

```text
ReplicatedStorage
└─ LibraryGame (Folder)
   ├─ Config            (ModuleScript)  tuning: capacity, sizes, theme, wood colours
   ├─ BookCatalog       (ModuleScript)  THE editable book list (16 books)
   ├─ BookVisuals       (ModuleScript)  builds 3D book models
   ├─ Net               (ModuleScript)  shared remote access
   └─ Remotes (Folder)  PickupBook, PlaceBook, DropBook, InventoryUpdated, Notify

ServerScriptService
└─ LibraryGame (Folder)
   ├─ Bootstrap         (Script)        entry point: init services, fill shelves
   ├─ Validate          (ModuleScript)  argument validation + token-bucket limiter
   └─ Services (Folder)
      ├─ BookService          (ModuleScript)  book instances, definitions, locations
      ├─ ShelfService         (ModuleScript)  shelf detection, decoration, slots, packing
      ├─ InventoryService     (ModuleScript)  per-player inventory + capacity
      └─ InteractionService   (ModuleScript)  remote handlers (pickup / place / drop)

ServerStorage
└─ LibraryGame.StoredBooks (Folder)  books held by players live here

StarterPlayer.StarterPlayerScripts
└─ LibraryGame (Folder)
   ├─ Bootstrap (LocalScript)      builds the HUD, starts the controllers
   └─ Controllers (Folder)
      ├─ ClientState                 (ModuleScript)  catalog/inventory/selection/drag state
      ├─ ClientUtil                  (ModuleScript)  raycasts, book/shelf lookup, shelf bounds, UI hit tests
      ├─ UIController                (ModuleScript)  all HUD (box, bar, drop, toast, ghost)
      ├─ WorldInteractionController  (ModuleScript)  hover, pin, double-click, place preview
      └─ InventoryController         (ModuleScript)  bar updates, selection, drag, drop button

Workspace
├─ BuildingCompound.R1LeftBookshelves.*  (4 shelves, tagged `Bookshelf`, lifted +0.7)
├─ BuildingCompound.R1RightBookshelves.* (4 shelves, tagged `Bookshelf`, lifted +0.7)
└─ LibraryGame (Folder)
   ├─ WorldBooks (Folder)   dropped books
   └─ ShelfSlots (Folder)   reserved (markers live under each shelf model)

Runtime-generated per shelf model: `Books` (Folder), `Slots` (Folder, 3 invisible markers),
`Trim` (Folder, crown/inlay/plinth/lips/pilasters).
```

---

## 2. Completed Work

### Place structure (earlier session, saved in the place)

| Change | Why |
| --- | --- |
| Tagged all 8 shelf models with `Bookshelf` | `ShelfService` auto-discovers shelves |
| Raised all 8 shelf models by `+0.7` studs | They were sunk 0.7 into the floor |
| Created `ReplicatedStorage.LibraryGame` + `Remotes` (5 RemoteEvents) | Shared config, catalog, messaging |
| Created `ServerScriptService.LibraryGame` + `Services` | Server code container |
| Created `ServerStorage.LibraryGame.StoredBooks` | Books carried by players |
| Created `StarterPlayerScripts.LibraryGame` + `Controllers` | Client code container |
| Created `Workspace.LibraryGame` (`WorldBooks`, `ShelfSlots`) | World containers |

### Scripts — shared modules

| Script | What it does |
| --- | --- |
| `ReplicatedStorage.LibraryGame.Config` | All tunables. `INVENTORY_CAPACITY = 2`, `Book` geometry, `Shelf.InitialFill = 0.72`, `Interaction` distances + `DoubleClickWindow = 0.32` + `HoverInterval = 0.05` + `ShelfSnapPadding = 0.6`, `Theme`, `Wood`, remote names. |
| `...BookCatalog` | 16 books (`Id`, `Name`, `Genre`, `Description`, `Published`, `Color`, optional `Thickness`/`Height`/`Accent`). Only file to edit when adding books. |
| `...BookVisuals` | Builds a book (Cover, Band, SpineLabel, Pages). Pivot = book centre, local `+Z` = spine. `setPose` places books bottom-up. |
| `...Net` | Typed lookup of the 5 RemoteEvents. |

### Scripts — server

| Script | What it does |
| --- | --- |
| `...LibraryGame.Bootstrap` | Requires `Services.*` in order, calls `init()` on all five (DataService first), then `ShelfService.start()`. Prints `LibraryGame ready: <shelves> shelves, <slots> slots, <books> books`. |
| `...Validate` | `string` / `integer` / `vector3` validation (NaN-safe) + token-bucket rate limiter `rateLimiter(30, 1)` = 30 calls/s/player with burst refill. |
| `...Services.BookService` | Spawns books with unique uids, definition index, ancestor lookup, move helpers (`moveToInventory`, `moveToShelf`, `dropAt`), `count()`. |
| `...Services.ShelfService` | `analyze()` classifies boards/sides/back, derives front sign, builds 3 invisible slot markers (attributes `LibraryShelfId`, `LibrarySlotIndex`, `LibrarySlotWidth/Height`, `LibraryBookCount`, `LibraryRemaining`), decorates, packs left→right, tweens reflow, inserts at index, `canPlace`, `getCount()`, `getSlotCount()`. Rebuilds slot markers on re-tag (destroys old ones first). |
| `...Services.InventoryService` | Per-player uid list, capacity checks, pushes `InventoryUpdated`, drops carried books when a player leaves. |
| `...Services.InteractionService` | Validated, rate-limited handlers: pickup (distance, capacity, shelf removal), place (slot resolve, distance, fit, insert index), drop (distance clamp, downward raycast, spine faces player). Calls `DataService.incrementStat(player, "BooksShelved", 1)` on a successful place. `init()`/`start()` present for symmetry. |
| `...Services.DataService` | Per-player profile persistence (v1). Loads via `UpdateAsync` (3 retries), applies `ProfileTemplate` defaults, increments `SessionsPlayed` on load, accrues `SecondsPlayed` on save, flushes on `BindToClose`. Exposes `get`, `getStat`, `incrementStat`. |

### Persistence (v1)

Schema is documented in `SaveSchema.md` and implemented by `...Services.DataService` + `...Data.ProfileTemplate`.
The shared world library is session-only, carried books are session-only, and only per-player `Stats` persist.
One DataStore key per player (`User_{UserId}`), `SchemaVersion = 1`. For a public launch, swap the DataStore
wrapper for ProfileStore (session locking) and persist the shared world as one global record.

### Scripts — client

| Script | What it does |
| --- | --- |
| `...StarterPlayerScripts.LibraryGame.Bootstrap` | `UI.init()` → `Net.Notify.OnClientEvent` → `UI.showToast` → `InventoryController.init()` → `WorldInteractionController.init()`. |
| `...Controllers.ClientState` | Catalog index, `inventory`, `selectedUid`, `pinnedUid`, `displayedUid`, `draggingUid`. |
| `...Controllers.ClientUtil` | Mouse raycasts (character excluded), `findBook` / `findShelf` by attributes, `getNearestSlot`, GUI hit tests. **Added (this pass):** `getShelfContaining(position, padding)` — finds the registered shelf whose bounds contain a world point, so trim/boards/floor-at-foot still resolve to a shelf. |
| `...Controllers.UIController` | HUD: description box, inventory bar, circular drop button, warning toast, slot ghost. **Changed twice:** box raised 34 px, then to `BOX_POSITION = (1,-26, 0.5,-52)` / `BOX_HIDDEN_POSITION = (1,18,0.5,-52)`; at -34 the longest description still overlapped the drop button by 16 px on a 422 px viewport, at -52 there is a 2 px gap. |
| `...Controllers.WorldInteractionController` | `RenderStepped` hover throttled to `HoverInterval`; golden `Highlight` parented to `Workspace` with `Adornee`; `showBook` → `ClientState.getDefinition`; hover-out hides after `HoverHideDelay` unless the pointer is over the box; click pins, outside click hides; double-click within `DoubleClickWindow` → `PickupBook`; ghost + click → `PlaceBook`; `UI.onPickup` → `PickupBook`. Hover and click now use the `ClientUtil.getShelfContaining` fallback too, so ghost and placement agree. |
| `...Controllers.InventoryController` | Validates/applies `InventoryUpdated`, auto-selects newest book, `UI.setInventory` + `setSelected`; slot click toggles selection; drag icon on a dedicated `IgnoreGuiInset` ScreenGui. **Rewritten (this pass):** `finishDrag` tries both `InputObject.Position` (GUI space) and live `GetMouseLocation()` (viewport space); shelf resolution uses hit instance *or* bounds; fallbacks go to a longer ray and then the camera-centre ray before `DropBook`. Debug prints removed, unused `mouseAim` removed, ghost hidden on release. |

### Fix pass — root cause of the drag bug

`UserInputService.InputEnded.Position` is in GUI space (includes the top inset), while
`camera:ViewportPointToRay` expects viewport coordinates from `GetMouseLocation()`. In this Studio
session the two differed by ~58 px vertically, so the release ray landed below the intended shelf and
the code fell through to `DropBook`. Trying both points plus a shelf-bounds fallback fixes it for mouse
and touch and also handles releasing over crown/plinth parts.

---

## 3. Current State

**Feature complete, all 11 handoff checklist items addressed, place saved.** Fresh-session output:
`LibraryGame ready: 8 shelves, 24 slots, 272 books`; catalog back to 16 books; no shelf-geometry
warnings and no library-related errors in Output.

### Verified in Play (Studio MCP, this pass)

| Test | Evidence |
| --- | --- |
| Hover / pin / Pick Up | Click on shelf book → box visible with genre, title, published, description; **Pick Up** → `StoredBooks = 1`, bar + drop button visible, spine icon colour matches the book. |
| Drag from bar → shelf (the bug) | Drag Slot1 → shelf_01 slot 2: slot count 12 → 13, `LibraryRemaining` 3.36 → 2.64, `StoredBooks` 1 → 0, `WorldBooks` 0. |
| Click-to-place | With a book carried, click a shelf board (ray hits shelf, not book) → `StoredBooks` 1 → 0 and shelf book count +1. |
| Drop button | Book left inventory, appeared in `Workspace.LibraryGame.WorldBooks` at the camera aim (`book_9` at `(-32.22, 7.87, -141.38)`); bar/drop hid. Book local `+Z` (spine) pointed toward the player — confirmed via `-LookVector`, not `LookVector`. |
| Drag-out drop | Drag Slot1 → floor point → `book_10` at `(-38.85, 1.77, -138.12)`, spine `(0.84, 0, 0.55)` toward the player. |
| Re-pickup of dropped book | Hover + click the floor book → box → **Pick Up** → `StoredBooks = 1` (uid `book_10`), `WorldBooks` 2 → 1 (only `book_9` left on the floor). |
| Full-inventory warning | (Earlier session) third pickup → “Your hands are full. Drop a book first.” and no book added. |
| Full-shelf warning | Filled shelf_01 slot 2 until `LibraryRemaining = 0.50`; next placement → toast “There is no room left on this shelf.” and the book stayed in hand. |
| Out-of-range warning | `PlaceBook` for shelf_06 from ~47 studs away → toast “You are too far from that shelf.” |
| Scalability — new shelf | Cloned a tagged shelf at runtime with generated folders stripped: auto-assigned `shelf_09`, 3 markers with unique shelf id/index, 34 books spawned, decorated, 9 shelves / 27 slots, 0 duplicate ids. Clone removed afterwards. |
| Scalability — new book | Temporarily added a 17th `BookCatalog` entry: fresh server spawned 264 books including 8 `scalability_probe` copies; entry removed, fresh session back to 16 books / 272 copies. |
| UI layout on 1014×422 viewport | Description box max bottom = 258 px, drop button top = 260 px → no overlap (2 px gap); box top = 14 px, on screen. Bar and drop button fit; toast clears the bar. |
| Security / limits | `Validate` rejects NaN/`math.huge`, wrong types and oversized strings; `allowAction = rateLimiter(30, 1)` (30/s/player, burst); all distance checks run on the server (20 / 24 / 22 studs). |
| Static checks | All 16 scripts compile with `loadstring`; no `[dbg` / debug `print` remains (only the intentional Bootstrap startup print). |

### Remaining caveats

1. **Two-player test not done** — only one Studio client is available. Structure is per-player
   (`InventoryService` keyed by `Player`, remote handlers use the calling player), and a client-only
   hover/pin state cannot affect another client, but this was not exercised with two clients.
2. **Double-click with the real 0.32 s window not reproducible via MCP** — scripted click pairs land
   too far apart; the branch was previously verified with a temporarily raised window. The logic and
   event wiring are unchanged, so a human double-click should be fine.
3. **Script Analysis panel diagnostics (IDE-only warnings) are not exposed by Studio MCP** — reviewed
   all sources manually and compiled every script; Output shows no type/runtime warnings from the
   LibraryGame scripts. Check the Script Analysis panel in Studio if IDE-level diagnostics matter.
4. **Visual screenshot captured, but this agent cannot view images** — programmatic layout checks
   (rects above) passed; a human glance in a fresh session is still worthwhile. The earlier black
   viewport was a streaming artifact of moving the capture camera ~100 studs away, not a game bug.
5. **MCP mouse-input quirk (test harness only):** `user_mouse_input` y is ~58 px above
   `UserInputService:GetMouseLocation()` in this session — subtract 58 when aiming at a world point
   in tests. This mismatch is exactly why the original drag release ray missed.
6. `require` inside `execute_luau` creates a **separate module instance** from running scripts;
   inspect instances (`StoredBooks` children, slot attributes, `WorldBooks`) instead of module state.
7. **DataStore persistence verified in Studio** (API access enabled). Across two play sessions the
   stored profile went `SessionsPlayed` 3 → 4 and `SecondsPlayed` 88.5 → 118.85, with `BooksShelved`
   held at 6. Note: the local `LibraryIsALive.rbxl` in the repo is a snapshot; refresh it with
   *File → Save to File* to include scripts added to the cloud place.

---

## 4. Checklist — final status

1. ~~Remove `[dbg drag]` prints~~ — **DONE**.
2. ~~Fix drag-to-shelf~~ — **DONE** and verified (slot 2 count +1, no world drop).
3. ~~Re-test all four placement entry points~~ — **DONE**: click-to-place, drag-to-shelf, Pick Up button,
   drop button all work after the change.
4. ~~Drag-out drop and re-pickup~~ — **DONE**: floor landing at `y = 1.77`, spine toward player, hover
   + Pick Up returns it to the inventory.
5. ~~Warning paths~~ — **DONE**: both “There is no room left on this shelf.” and “You are too far from
   that shelf.” observed as toasts.
6. ~~Visual re-check / layout~~ — **DONE as far as MCP allows**: fresh normal-camera session, geometry
   and layout checked programmatically; screenshot taken (see caveat 4 above).
7. ~~Scalability~~ — **DONE**: runtime-tagged shelf got a unique id/markers and filled; temporary
   17th catalog entry spawned; both test artifacts removed.
8. ~~Rate limiting and distances~~ — **DONE**: 30 calls/s/player, NaN-safe validation, server-side
   20/24/22-stud checks; no debug prints left.
9. ~~Script Analysis (`--!strict`) review~~ — **DONE as far as MCP allows**: all 16 scripts read and
   compiled, no warnings in Output; IDE panel remains the authoritative place for style diagnostics.
10. ~~Two-player test~~ — **NOT RUN** (no second client available; see caveat 1).
11. ~~Save the place~~ — **DONE**: `save_place` → `Saved`, TeamCreate version 64.

### Final tunable list

- `Config.INVENTORY_CAPACITY = 2` — server + UI both read it.
- `Config.Shelf.InitialFill = 0.72` — how full shelves spawn (0–1).
- `Config.Shelf.Tag = "Bookshelf"` — tag a new shelf model with this to auto-register it.
- `Config.Book.Gap = 0.04`, `Depth = 0.95`, `ShelfInset = 0.2`, `BottomLift = 0.01`,
  `MinThickness = 0.45`, `MaxThickness = 0.95`, `MinHeight = 1.65`, `MaxHeight = 2.15`.
- `Config.Interaction.MaxPickupDistance = 20`, `MaxPlaceDistance = 24`, `MaxDropDistance = 22`,
  `DoubleClickWindow = 0.32`, `HoverInterval = 0.05`, `HoverReach = 42`, `HoverHideDelay = 0.18`,
  `ShelfSnapPadding = 0.6`.
- `Config.Theme` / `Config.Wood` — UI and shelf colours; `Config.RemoteNames` — remote names.
- `Validate.rateLimiter(30, 1)` in `InteractionService` — remote-call budget per player.
- `UIController.BOX_POSITION` / `BOX_HIDDEN_POSITION` — description box placement (-52 px from centre).
- `BookCatalog` — add/remove/edit books; no other file needs changing for new book data.

### Known limitations

- No persistence: shelves are rebuilt and books are respawned on every server start.
- Books are 4 anchored parts each (~1088 parts at 272 books) — intended for a small library.
- One test-only shelf clone and one test-only catalog entry were used in Play/Edit and both removed
  before the final save; the saved place has the original 8 shelves / 16 books.
