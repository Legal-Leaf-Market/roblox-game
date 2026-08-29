# Three Paths: design notes

What exists in v0.2 and why. Every number here lives in `src/shared/Data/`
or `src/shared/Config.luau`; this file is the map, not the source.

## The world

Programmatically built by `WorldBuilder` at server start:

- **Heavenpillar Mountain** at the center: six climbable tiers with ramps
  and a summit meditation platform.
- **Three cities** ringed around it, one per path: White Cloud City
  (orthodox, north), Freewind City (unorthodox, southeast), Blackfire City
  (demonic, southwest). Each has walls, homes, lanterns, a team spawn, a
  pledge shrine, and training dummies outside the gate. City interiors are
  safe zones; no damage in or out.
- **The Deep Mines** under the mountain: a surface gate south of the peak
  drops down a shaft into the Mining Hall (black iron, cold iron, spirit
  stone) and, through a doorway, the Deepforge Hall (meteoric iron, star
  silver, profound gold, immortal jade), where Grandmaster Khadun keeps the
  Spirit Forge.
- A neutral **Wayfarer's Rest** spawn between the mountain and the cities.

## Progression: qi, realms, breakthroughs

Eight realms from Body Tempering to Immortal Ascension (`Data/Realms.luau`).
Qi regenerates on a 1s tick, several times faster while meditating (key G);
meditation also grants cultivation xp and ends if you move. Crossing a
realm's xp threshold triggers a breakthrough: full qi, a golden pillar, and
free Destiny spins. Casting techniques also grants a little xp: practice is
cultivation.

## Paths

Pledged once at a city shrine, permanent, sets team and respawn city.
Orthodox regenerates qi faster; unorthodox cools down faster; demonic hits
harder. Each path also unlocks a private element (radiance / venom / shadow).

## Techniques: the player is the designer

A technique = **form** (14 across movement/sword/blade/bow) + **element**
(9) + **power** (0-10) + a player-chosen name. `TechniqueMath` derives
damage, qi cost, cooldown, ranges, required realm and design cost, shared by
the preview UI and the server, so the preview is the contract. Weapon-
category techniques need the matching weapon equipped. Casting is fully
server-authoritative (cost, cooldown, hitboxes, projectile simulation);
movement techniques are applied client-side after the server charges them,
because the client owns its character's physics. Elemental side effects:
burn, slow, shock, knockback, gust, poison, self-heal, lifesteal.

## Destiny: 124 races + talents, on spins

Everyone starts as a Mortal Human. Race spins roll over a 124-entry bestiary
of Chinese myth (`Data/Races.luau`) across six rarities (common 51.5% ...
mythic 0.5%); duplicates refund spirit stones. Race stats derive from
rarity x archetype through one function, so the bestiary can't drift into
124 balance problems. Some races carry an elemental affinity that bypasses
path locks (a Ghostkin can weave shadow without walking the demonic path).
Talents (`Data/Talents.luau`, 41 entries, same rarity ladder) are passive
physiques; up to 3 equipped. Spins come from starting grants, breakthroughs,
dwarf missions, or spirit stones.

## Sects, lineage, and mastery (v0.3)

Sects persist across servers in their own DataStore with a unique filtered
name and five ranks: Sect Leader, Vice Sect Leader, Elder, Inner Disciple,
Outer Disciple. Leader/Vice manage ranks; leadership transfers by Crown.
Master-disciple bonds are separate from sects: offered and accepted in
person, up to 5 disciples. Each disciple breakthrough adds +1x to the
master's qi gain (capped, tunable in Config; the mailbox store credits
offline masters). Techniques gain mastery by being cast (10 levels: +2%
damage, -1% cooldown each); at Mastery 10 an art can be passed down, but
only master to disciple, and the copy starts unmastered. Movement layer:
Shift sprint on a client-side stamina pool, Q dash (2s), and Qi Step (O),
a server-authoritative qi drain for extra speed with a replicated foot
glow.

## Economy: mine, forge, design

Ore nodes deplete and respawn on timers; spirit stone nodes pay currency
directly. Khadun's six-mission chain (the last repeats) pays stones and
spins. The Spirit Forge crafts 8 weapons and 5 robes from ore
(`Data/Items.luau`); weapons multiply technique damage and gate categories,
robes absorb a fraction of damage. Designing a technique costs stones, so
the loop closes: mine -> forge/design -> fight/train -> break through.

## Security posture

Server authority everywhere: all rolls, costs, cooldowns, damage and
distances are validated server-side; remotes are declared in one registry,
rate-limited, and type-checked on arrival; identifiers never come from the
client. Known accepted gap for v0.2: no positional anti-cheat beyond
distance checks on interactions.

## Not yet built (obvious next steps)

- Mobs/beasts beyond training dummies; boss at the summit.
- Sect/party systems, trading, leaderboards.
- Weapon models in hand, character cosmetics per race, sound design.
- Positional anti-cheat, session locking on the DataStore.
- Monetization (game passes, paid spins) — deliberately absent until the
  loop is proven fun.
