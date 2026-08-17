# Tic-tac-toe — two players over the LAN

Build and start the Bend server from the repository root:

```sh
bun bend-ts/src/bend.ts gabriel_demos/tictactoe_web/web_tictactoe.bend --no-halt -o gabriel_demos/tictactoe_web/web_tictactoe
./gabriel_demos/tictactoe_web/web_tictactoe
```

Open `http://<server-lan-ip>:8082` on two devices connected to the same local
network. For example, if the server address is `192.168.1.40`, both players
open `http://192.168.1.40:8082`. The host firewall must allow incoming
connections to the binary.

The first player chooses X or O. The second player chooses the remaining
symbol, and X takes the first turn. The X and O artwork uses nodes and edges;
the rest of the page is intentionally plain. After a win or draw, both players
must choose Rematch before the server clears the board. Leaving the game frees
that symbol and clears an unfinished round.

The server owns one game and carries an immutable `Game` value through its
accept loop. Every browser request gets one connection and an explicit
`Connection: close` response. Bend's standard HTTP handler keeps HTTP/1.1
connections alive, but this TCP server accepts connections sequentially.
Closing each polling request prevents one browser from blocking the other.

Routes:

- `GET /` — show the page
- `GET /state/<player>` — get the current game state
- `GET /join/<x|o>/<player>` — choose an available symbol
- `GET /move/<player>/<cell>` — place a symbol in square `0..8`
- `GET /again/<player>` — request a rematch
- `GET /leave/<player>` — leave the game

Player identifiers are random browser-session `U32`s. This is a local network
demo, not an authenticated internet service.

## Bend3 issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
