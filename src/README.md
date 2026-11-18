# `src/` — exported scripts snapshot

These `.luau` files are an **export of the scripts inside the Roblox place**
(`LibraryIsALive.rbxl` / the cloud Team Create place), not a live Rojo project.

- **Authoritative source is still the place in Roblox Studio.** Editing a file here does
  not change the game. Re-export after changing scripts in Studio.
- **Scripts only.** Maps, parts, GUIs, remote instances, Lighting, and Terrain are not
  captured here. For the full place, use Studio's *File → Save to File* and commit the
  `.rbxl` instead.
- **Names are derived, not real filenames.** Roblox has no file extensions, so they are
  inferred from the class name:

  | Roblox class | Extension |
  | --- | --- |
  | `ModuleScript` | `.luau` |
  | `Script` | `.server.luau` |
  | `LocalScript` | `.client.luau` |

- **Paths mirror the DataModel**, so a file maps back to an instance by replacing the
  folder separators with dots:

  | File | Instance |
  | --- | --- |
  | `ServerScriptService/LibraryGame/Services/DataService.luau` | `game.ServerScriptService.LibraryGame.Services.DataService` |
  | `ServerScriptService/LibraryGame/Bootstrap.server.luau` | `game.ServerScriptService.LibraryGame.Bootstrap` |
  | `ReplicatedStorage/LibraryGame/Config.luau` | `game.ReplicatedStorage.LibraryGame.Config` |
  | `StarterPlayer/StarterPlayerScripts/LibraryGame/Bootstrap.client.luau` | `game.StarterPlayer.StarterPlayerScripts.LibraryGame.Bootstrap` |

  Folder names map directly to `Folder` instances (`LibraryGame`, `Services`, `Data`,
  `Controllers`).

## Layout

```
src/
├─ ReplicatedStorage/LibraryGame/          shared modules (Config, BookCatalog, BookVisuals, Net)
├─ ServerScriptService/LibraryGame/        Bootstrap (Script) + Validate + Data/ + Services/
└─ StarterPlayer/StarterPlayerScripts/LibraryGame/
   ├─ Bootstrap.client.luau                LocalScript entry point
   └─ Controllers/                         UI and interaction controllers
```

## Notes

- `Bootstrap.server.luau` and `Bootstrap.client.luau` share a name because they live under
  different services; the extension is what distinguishes them.
- The exported text is byte-identical to the Studio `Source`, including tabs and CRLF-free
  line endings.
- Two documented entry points: the server `Bootstrap` (requires `Services/*`, calls
  `DataService.init()` first) and the client `Bootstrap.client` (requires `Controllers/*`).
