# Snake Arena — four players over the LAN

Snake Arena is a small Slither-style game with original visuals. The Bend
server owns movement, food, growth, collisions, respawning, and all four player
slots. Browsers send their desired direction and interpolate server snapshots
for smooth rendering.

Build and run it from the repository root:

```sh
bun bend-ts/src/bend.ts gabriel_demos/slither_web/web_slither.bend --no-halt -o gabriel_demos/slither_web/web_slither
./gabriel_demos/slither_web/web_slither
```

Open `http://<server-lan-ip>:8083` on up to four devices on the same local
network. The host firewall must allow incoming connections to the binary.

- Desktop: move the pointer or use the arrow/WASD keys.
- Mobile: drag anywhere in the arena to steer.
- Collect food to grow. Touching a wall or any snake body causes a short
  respawn delay.
- A player slot is released after 20 seconds without a request, so abandoned
  mobile sessions do not fill the arena permanently.

Routes:

- `GET /` — show the game
- `GET /state/<player>` — get the current state
- `GET /join/<player>` — take an available slot
- `GET /input/<player>/<heading>` — set heading `0..15` and get the state
- `GET /leave/<player>` — leave the arena

## Bend3 issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
