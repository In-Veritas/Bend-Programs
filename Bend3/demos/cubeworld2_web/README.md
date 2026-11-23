# CubeWorld 2

CubeWorld 2 is a first-person multiplayer voxel survival game whose shared
world and gameplay rules are written in Bend (ported to Bend 2.0.40). The browser draws the scene and
captures input; Bend owns terrain, player positions, NPC pursuit, attacks,
health, respawns, mining, and construction.

## Features

- A procedural 48×48 world, four times the area of Block World.
- A practical seven-block render distance and a first-person perspective.
- Free mouse-look with horizontal and vertical aiming, exact crosshair
  selection, held movement, and a visible targeted block face.
- Exactly twelve selectable materials: grass, dirt, stone, oak, leaves, sand,
  water, brick, coal, snow, obsidian, and gold.
- Four simultaneous players with shared terrain and unrestricted consensual
  sandbox PvP mechanics.
- Four hostile raiders that select a nearby player, pursue them, and attack in
  melee range. Players can damage and defeat raiders.
- Server-authoritative health, damage, death, and immediate spawn-point
  respawning.
- Keyboard, mouse, touch-drag, and on-screen mobile controls.

## Build and run

Requires the `bend` 2.0.40 CLI on `PATH`. From the repository root:

```sh
bend Bend3/demos/cubeworld2_web/web_cubeworld2.bend --check-only   # ALL PROOFS CHECK
./Bend3/demos/cubeworld2_web/build.sh   # bend ... -o Bend3/demos/cubeworld2_web/build/web_cubeworld2
./Bend3/demos/cubeworld2_web/start.sh   # runs from the repository root
```

The server reads `Bend3/demos/cubeworld2_web/index.html` relative to the
repository root, so always launch it from there (`start.sh` does). With a
freshly started server, `bun Bend3/demos/cubeworld2_web/test_server.mjs`
checks the protocol (generated world against the JS formula, joins, limits,
movement, mining, building, PvP and respawn, real-time raider cadence, a
raider fight) and prints `/state` timings.

Open `http://<server-lan-ip>:8086`. The server binds all interfaces so another
device on the same network can join. State is kept in memory and resets when
the process restarts. Inactive player slots expire after 30 seconds.

The same game is also mounted at `http://<server-lan-ip>:8090/cubeworld2` in
the single-process BendJogos hub. When a BendJogos account is signed in, the
game publishes CubeWorld 2 as that account's current activity.

## Controls

- Hold WASD or arrows to move relative to the view. Q/E turns in steps.
- Click the world once to capture the mouse, then aim horizontally and
  vertically. Escape releases the pointer.
- Left-click, Space, F, or **Attack / Mine** acts only on the entity or block
  face under the crosshair. There is no nearest-target fallback.
- Right-click, R, or **Place Block** places the selected material.
- Number keys 1–9 and 0 or the mouse wheel select materials. All twelve remain
  directly selectable in the scrolling hotbar.
- Touch drag aims on mobile; tapping attacks or mines. On-screen controls
  provide held movement, turning, and building.

Hostile NPC movement and damage advance on a Bend-owned real-time cadence,
rather than once per browser request, so adding another polling player does
not make the game simulation run faster.

## HTTP protocol

All successful game routes return a complete strict-JSON snapshot:

- `GET /state/<player>`
- `GET /join/<player>`
- `GET /move/<player>/<direction>`
- `GET /mine/<player>/<x>/<z>`
- `GET /place/<player>/<x>/<z>/<material>`
- `GET /attack-mob/<player>/<mob-slot>`
- `GET /attack-player/<player>/<target-slot>`
- `GET /leave/<player>`

## Hub interface

`web_cubeworld2.bend` is importable as a module
(`import ../cubeworld2_web/web_cubeworld2.bend as Cube`) and exposes:

- `Cube.Game` — the state type (`is Data`);
- `Cube.init()` — the initial world and raiders (pure);
- `Cube.route(req: HTTP.Request, g: Cube.Game) -> IO(Cube.Game & HTTP.Response)`
  — reads the clock itself (`HTTP.serve` shape);
- `Cube.route_at(req, g, now: U32)` — the same with an explicit clock;
- `Cube.game_advance(g, now)` — steps the raiders if 650 ms have passed
  (`/state` already calls it).

Both routes accept the path with or without the leading `/cubeworld2`
segment, so the hub can pass its request through unchanged. `main` is only
`HTTP.serve(~Game, ~route, "0.0.0.0", 8086, init())`.

## Bend behavior notes

The historical forward-loop scoping behavior and its Bend 2.0.40 retest are
in [`unexpected_behavior/README.md`](unexpected_behavior/README.md). The
2.0.40 port needs no `--no-halt`/`@unsafe`: the server loop is the shared
`../HTTP.bend` toolkit (Nat fuel) and the world is built by Nat-fuelled
structural recursion.
