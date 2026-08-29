# Heavenpillar

An original Roblox cultivation (xianxia) MMORPG. Rise through 144 stages
of cultivation, from a mortal in the Azure Vale to a True Immortal, by
meditating, fighting, training, creating your own techniques, mastering
them, writing them into manuals, and passing them to disciples.

Built entirely from code: the whole game (world included) builds from a
clean checkout with [Rojo](https://rojo.space/).

## Structure

- `src/shared/` — data and pure math both sides use: the 144-stage realm
  ladder (`Realms`), technique components and math, items, the remote
  registry (`Net`), the animation slot table (`Animations`).
- `src/server/Systems/` — one module per service: data persistence,
  cultivation, combat, techniques, disciples, inventory, NPC beasts, and
  the world builder (`World/Terrain` heightfield + `World/Vale`
  handcrafted layer + `World/Flora`).
- `src/client/` — controllers for movement, combat input and VFX,
  cultivation, HUD, technique window, bag, dao panel, updates.

## Build

```
rojo build default.project.json -o dist/Heavenpillar.rbxlx
```

CI typechecks with luau-lsp, builds on every push, and publishes to
Roblox automatically when `ROBLOX_API_KEY`, `ROBLOX_UNIVERSE_ID` and
`ROBLOX_PLACE_ID` are set as repository secrets.

## Animations

No animation asset ids are invented. Every animation slot lives in
`src/shared/Animations.luau` as `REPLACE_ME`; the game plays fully
without them and each animation appears the moment its uploaded id is
pasted in. The slot list in that file is the commission list for an
animator.

## Security model

The client sends intents; the server owns every outcome: damage, qi,
xp, stages, items, currency, techniques, mastery, manuals, bonds. All
remotes are declared in one registry, rate-limited, and type-checked at
the boundary.
