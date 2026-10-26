# The Lounge (Roblox billiards)

An 8-ball pool hall for Roblox, built entirely from code with
[Rojo](https://rojo.space/). Walk up to the table, press **E** to join (two
players play 8-ball; one player practises), aim with the mouse or a finger,
hold to build power, let go to shoot. Click the white ball in the corner (or
use the arrow keys) to hit high for follow, low for draw, or left and right
for english.

## Layout

- `src/shared/Physics.luau`: the table, simulated. Pure Luau (no Roblox APIs),
  so the server runs it for real and the test runner runs the same file.
- `src/shared/Rules.luau`: 8-ball rules (fouls, groups, ball in hand, the 8).
- `src/shared/Config.luau`: every number the table, physics and rules share.
  Table units are inches on a 9-foot table; studs only appear in the world.
- `src/shared/Net.luau`: the four remotes.
- `src/server/World.luau`: builds the lounge, the table and the balls.
- `src/server/init.server.luau`: the referee. Owns the balls, turns and rules.
- `src/client/init.client.luau`: camera, aiming guide, ball in hand, playback, HUD.

## Security

The client sends only an angle and a power (or where to put the cue ball in
hand). The server checks it is that player's turn, simulates the shot itself
and sends the frames to everyone. Nobody can pocket a ball by editing their
own copy of the table.

## Build and test

```
rojo build default.project.json -o dist/TheLounge.rbxlx
cd tools/luau-run && cargo build --release && cd ../..
tools/luau-run/target/release/luau-run tests/run.luau        # 176 checks
tools/luau-run/target/release/luau-run --check $(find src -name '*.luau')
```

Open `dist/TheLounge.rbxlx` in Roblox Studio and press Play (or Test with two
players under Test > Clients and Servers).

## Not yet

- Never run inside Roblox Studio yet: the physics and rules are tested, the
  world, camera and input are untested until somebody presses Play.
- Spin is a simple model: follow and draw act at the first contact, english
  at the cushions. No squirt, swerve or throw. Balls slide rather than roll,
  so numbers sit on top. No sounds.
- 9-ball mode, a ranked ladder, cue skins (the place to sell Robux items).
