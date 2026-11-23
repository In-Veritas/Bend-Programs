# Cell Arena — four players over the LAN

Cell Arena is a small Agar-style game with original visuals. The Bend server
owns all player movement, food, mass, player-vs-player consumption, respawns,
and four browser sessions.

Build and run it (Bend 2.0.40, current `bend` CLI) from the repository root,
which its page path is relative to:

```sh
bend Bend3/demos/agar_web/web_agar.bend --check-only   # ALL PROOFS CHECK
bend Bend3/demos/agar_web/web_agar.bend -o Bend3/demos/agar_web/build/web_agar
./Bend3/demos/agar_web/build/web_agar
```

`build/` is gitignored. Open `http://<server-lan-ip>:8084` on up to four devices on the same local
network.

- Desktop: move the pointer or use arrow/WASD keys.
- Mobile: drag anywhere in the arena.
- Food adds mass. A cell can absorb another player when it is at least three
  mass larger and reaches that player.
- Inactive slots are released after 20 seconds.

## Hub interface

`web_agar.bend` exposes, for `import ../agar_web/web_agar.bend as Cells`:

- `Cells.Game` — the state type; `Cells.init() -> IO(Cells.Game)` (reads the
  clock and a random food seed)
- `Cells.route_now(req, game, now)` — advances the simulation to `now`
  (monotonic ms, `Clock.now_ms()`), then answers; the hub must NOT call
  `game_advance` itself any more
- `Cells.route(req, game)` — the same, reading the clock itself (what
  `main` serves)

Both accept paths with or without the leading `/cells` (the page always uses
`/cells/...`). `main` is a thin `HTTP.serve(~Game, ~route, "0.0.0.0", 8084, g)`.

## Bend issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
