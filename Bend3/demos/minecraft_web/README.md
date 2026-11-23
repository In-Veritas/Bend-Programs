# Block World

Block World is a small multiplayer voxel sandbox written in Bend (ported to
Bend 2.0.40). The Bend
server owns the terrain, player positions, mining, and block placement; the
browser only handles input and draws an isometric view of that shared state.

It deliberately keeps the Minecraft-like idea compact:

- one procedural 24×24 world with a render distance of six columns;
- grass, dirt, stone, wood, and leaf blocks;
- hills and three small trees;
- four simultaneous players with distinct colors;
- shared movement, mining, and placement on desktop and mobile.

## Run by itself

Requires the `bend` 2.0.40 CLI on `PATH`. From the repository root:

```sh
bend Bend3/demos/minecraft_web/web_minecraft.bend --check-only   # ALL PROOFS CHECK
./Bend3/demos/minecraft_web/build.sh   # bend ... -o Bend3/demos/minecraft_web/build/web_minecraft
./Bend3/demos/minecraft_web/start.sh   # runs from the repository root
```

Then open `http://<server-lan-ip>:8085` on devices connected to the same LAN.
The server reads `Bend3/demos/minecraft_web/index.html` relative to the
repository root, so always launch it from there (`start.sh` does).

With a freshly started server, `bun Bend3/demos/minecraft_web/test_server.mjs`
checks the whole protocol (the generated world against the JS formula, joins,
the four-player limit, movement, mining, placing, max height, leaving) and
prints `/state` timings.

## Play through BendJogos

The unified hub (`Bend3/demos/bendjogos_web/`) serves the game at
`http://<server-lan-ip>:8090/minecraft`; see "Hub interface" below.

## Controls

- Move with WASD, the arrow keys, or the on-screen direction pad.
- In Mine mode, click or tap a nearby column to remove its top block.
- Select a material in the hotbar, then click or tap a nearby column to place
  it. Right-click also switches to Place mode.
- Number keys 1–5 select grass, dirt, stone, wood, and leaves.

The player and world stores are intentionally in memory. They reset whenever
the Bend process restarts, and an inactive player slot expires after 30
seconds. A browser tab receives a random session identity; this demo does not
connect gameplay identity to a BendJogos account.

## Protocol

The browser uses small JSON snapshots over these routes:

- `GET /state/<player>`
- `GET /join/<player>`
- `GET /move/<player>/<direction>`
- `GET /mine/<player>/<x>/<z>`
- `GET /place/<player>/<x>/<z>/<block>`
- `GET /leave/<player>`

When hosted by BendJogos, each route is prefixed with `/minecraft`. The
standalone server also accepts the prefixed form.

## Hub interface

`web_minecraft.bend` is importable as a module
(`import ../minecraft_web/web_minecraft.bend as Mine`) and exposes:

- `Mine.Game` — the state type (`is Data`);
- `Mine.init()` — the initial world (pure);
- `Mine.route(req: HTTP.Request, g: Mine.Game) -> IO(Mine.Game & HTTP.Response)`
  — reads the clock itself (`HTTP.serve` shape);
- `Mine.route_at(req, g, now: U32)` — the same with an explicit clock.

Both routes accept the path with or without the leading `/minecraft`
segment, so the hub can pass its request through unchanged (no prefix
rewriting needed). `main` is only `HTTP.serve(~Game, ~route, "0.0.0.0", 8085,
init())`.

## Bend behavior notes

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md) for the
versioned reproduction of the old mutual-recursion/whole-book-scoping
requirement and its Bend 2.0.40 retest. The 2.0.40 port has no `@unsafe`:
the server loop is the shared `../HTTP.bend` toolkit (Nat fuel), the world is
built by Nat-fuelled structural recursion, and every conditional is a `match`
on a parameter (`Bool` helper defs) or a `Bool.pick`.
