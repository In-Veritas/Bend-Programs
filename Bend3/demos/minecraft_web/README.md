# Block World

Block World is a small multiplayer voxel sandbox written in Bend3. The Bend
server owns the terrain, player positions, mining, and block placement; the
browser only handles input and draws an isometric view of that shared state.

It deliberately keeps the Minecraft-like idea compact:

- one procedural 24×24 world with a render distance of six columns;
- grass, dirt, stone, wood, and leaf blocks;
- hills and three small trees;
- four simultaneous players with distinct colors;
- shared movement, mining, and placement on desktop and mobile.

## Play through BendJogos

Build and start the unified hub from the repository root:

```sh
./gabriel_demos/bendjogos_web/build.sh
./gabriel_demos/bendjogos_web/start.sh
```

Open `http://<server-lan-ip>:8090/minecraft`. The game, social features, and
all other hub games use that single Bend process and port.

## Run by itself

```sh
./gabriel_demos/minecraft_web/build.sh
./gabriel_demos/minecraft_web/start.sh
```

Then open `http://<server-lan-ip>:8085` on devices connected to the same LAN.

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

When hosted by BendJogos, each route is prefixed with `/minecraft`.

## Bend3 behavior notes

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md) for the
versioned reproduction of the mutual-recursion/whole-book-scoping requirement,
the minimal reproduction, and the observed unified-build cost.
