# Three Paths (working title)

A Roblox cultivation game: three path cities around Heavenpillar Mountain, a
mine-and-forge underworld beneath it, a qi/realm progression, player-designed
techniques, and Destiny spins across 124 races of Chinese myth.

All of it — world included — is generated from the Luau source in this repo.
Nothing is hand-placed in Studio, so a clean checkout builds the whole game.

## Quickest preview (no plugins)

1. Download `dist/ThreePaths.rbxlx` from this repo.
2. Double-click it; Roblox Studio opens the place.
3. Press Play. The world builds itself at server start.

That file is a committed build for convenience and may lag the source; CI
rebuilds a fresh one on every push (see below).

## Dev loop (live sync)

1. Clone the repo; install [Rokit](https://github.com/rojo-rbx/rokit) or
   Aftman, then run `rokit install` (or `aftman install`) here to get the
   pinned Rojo.
2. In Studio, install the Rojo plugin: `rojo plugin install`.
3. Run `rojo serve` in the repo, open your place in Studio, click the Rojo
   plugin, Connect. Edits to `src/` appear live.

## Deploy pipeline (the Vercel analogy)

`.github/workflows/build-and-deploy.yml` runs on every push to `main`:
typecheck (luau-lsp, strict), `rojo build`, upload the place file as an
artifact — and, once secrets are set, publish straight to the live Roblox
place through the official Open Cloud API. Push to `main` = game updated.

One-time setup, after publishing the place from Studio once
(File > Publish to Roblox):

1. On [create.roblox.com](https://create.roblox.com), open Creator Dashboard >
   the experience; note the **Universe ID** and start place's **Place ID**.
2. Creator Dashboard > Open Cloud > API Keys: create a key with the
   `universe-places:write` scope, scoped to that experience.
3. In this GitHub repo: Settings > Secrets and variables > Actions, add
   `ROBLOX_API_KEY`, `ROBLOX_UNIVERSE_ID`, `ROBLOX_PLACE_ID`.

Until the secrets exist the workflow still typechecks and builds; the publish
step skips itself politely.

## Layout

| Path | Syncs to | Purpose |
|---|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` | `Net` (all remotes), `Types`, `Config`, `StatCalc`, `TechniqueMath`, `RateLimit`, `Trove`, and `Data/` (realms, paths, races, talents, elements, forms, ores, items, missions) |
| `src/server/` | `ServerScriptService.Server` | Bootstrap + `Systems/` (data, qi, paths, destiny, techniques, combat, mining, forge, world builder + `World/`) |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` | Bootstrap + `Controllers/` (menu, HUD, casting/VFX, technique forge, destiny, inventory, crafting, dialogue, meditation) + `Modules/` (UiKit, ClientState, ClientSettings) |

Game design details: `docs/DESIGN.md`.

## Conventions

- `--!strict` everywhere; CI fails on any luau-lsp finding.
- Services via `game:GetService()`; `task.*` only, never legacy `wait/spawn/delay`.
- The server is authoritative for everything that matters. Remotes exist only
  in `src/shared/Net.luau`; declare a name there before using it.
- A feature is a ModuleScript in `Systems/` (server) or `Controllers/`
  (client) with optional `Init()`/`Start()`; the bootstrappers wire it up.
- All world geometry goes through `World/BuildKit.luau`.
