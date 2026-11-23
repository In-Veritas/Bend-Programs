# Snake Arena — four players over the LAN

Snake Arena is a small Slither-style game with original visuals. The Bend
server owns movement, food, growth, collisions, respawning, and all four player
slots. Browsers send their desired direction and interpolate server snapshots
for smooth rendering.

Build and run it (Bend 2.0.40, current `bend` CLI) from the repository root,
which its page path is relative to:

```sh
bend Bend3/demos/slither_web/web_slither.bend --check-only   # ALL PROOFS CHECK
bend Bend3/demos/slither_web/web_slither.bend -o Bend3/demos/slither_web/build/web_slither
./Bend3/demos/slither_web/build/web_slither
```

`build/` is gitignored. Open `http://<server-lan-ip>:8083` on up to four devices on the same local
network. The host firewall must allow incoming connections to the binary.

- Desktop: move the pointer or use the arrow/WASD keys.
- Mobile: drag anywhere in the arena to steer.
- Collect food to grow. Touching a wall or any snake body causes a short
  respawn delay.
- A player slot is released after 20 seconds without a request, so abandoned
  mobile sessions do not fill the arena permanently.

Routes (each also answers under the `/snake` prefix):

- `GET /` — show the game
- `GET /state/<player>` — get the current state
- `GET /join/<player>` — take an available slot
- `GET /input/<player>/<heading>` — set heading `0..15` and get the state
- `GET /leave/<player>` — leave the arena

## Hub interface

`web_slither.bend` exposes, for `import ../slither_web/web_slither.bend as Snake`:

- `Snake.Game` — the state type; `Snake.init() -> IO(Snake.Game)` (reads the
  clock and a random food seed)
- `Snake.route_now(req, game, now)` — advances the simulation to `now`
  (monotonic ms, `Clock.now_ms()`), then answers; the hub must NOT call
  `game_advance` itself any more
- `Snake.route(req, game)` — the same, reading the clock itself (what
  `main` serves)

Both accept paths with or without the leading `/snake` (the page always uses
`/snake/...`). `main` is a thin `HTTP.serve(~Game, ~route, "0.0.0.0", 8083, g)`.

## Bend issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
