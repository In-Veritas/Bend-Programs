# Cell Arena — four players over the LAN

Cell Arena is a small Agar-style game with original visuals. The Bend server
owns all player movement, food, mass, player-vs-player consumption, respawns,
and four browser sessions.

Build and run it from the repository root:

```sh
bun bend-ts/src/bend.ts gabriel_demos/agar_web/web_agar.bend --no-halt -o gabriel_demos/agar_web/web_agar
./gabriel_demos/agar_web/web_agar
```

Open `http://<server-lan-ip>:8084` on up to four devices on the same local
network.

- Desktop: move the pointer or use arrow/WASD keys.
- Mobile: drag anywhere in the arena.
- Food adds mass. A cell can absorb another player when it is at least three
  mass larger and reaches that player.
- Inactive slots are released after 20 seconds.

## Bend3 issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
