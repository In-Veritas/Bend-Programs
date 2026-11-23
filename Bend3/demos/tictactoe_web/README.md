# Tic-tac-toe — two players over the LAN

Build and start the Bend server (Bend 2.0.40, current `bend` CLI) from the
repository root, which its page path is relative to:

```sh
bend Bend3/demos/tictactoe_web/web_tictactoe.bend --check-only   # ALL PROOFS CHECK
bend Bend3/demos/tictactoe_web/web_tictactoe.bend -o Bend3/demos/tictactoe_web/build/web_tictactoe
./Bend3/demos/tictactoe_web/build/web_tictactoe
```

`build/` is gitignored. Open `http://<server-lan-ip>:8082` on two devices connected to the same local
network. For example, if the server address is `192.168.1.40`, both players
open `http://192.168.1.40:8082`. The host firewall must allow incoming
connections to the binary.

The first player chooses X or O. The second player chooses the remaining
symbol, and X takes the first turn. The X and O artwork uses nodes and edges;
the rest of the page is intentionally plain. After a win or draw, both players
must choose Rematch before the server clears the board. Leaving the game frees
that symbol and clears an unfinished round.

The server owns one game: `../HTTP.bend` (`HTTP.serve`) folds every request
into the `Game` value in arrival order and answers each with
`Connection: close`; one reader per connection means an idle browser never
blocks the other.

Routes (each also answers under the `/tic` prefix, which the page uses):

- `GET /` — show the page
- `GET /state/<player>` — get the current game state
- `GET /join/<x|o>/<player>` — choose an available symbol
- `GET /move/<player>/<cell>` — place a symbol in square `0..8`
- `GET /again/<player>` — request a rematch
- `GET /leave/<player>` — leave the game

Player identifiers are random browser-session `U32`s. This is a local network
demo, not an authenticated internet service.

## Hub interface

`web_tictactoe.bend` exposes, for `import ../tictactoe_web/web_tictactoe.bend as Tic`:

- `Tic.Game` — the state type; `Tic.init() -> Tic.Game`
- `Tic.route(req: HTTP.Request, game: Tic.Game) -> IO(Tic.Game & HTTP.Response)` —
  accepts the request path with or without the leading `/tic`, so the hub can
  pass `/tic/...` requests unchanged.

`main` is only `HTTP.serve(~Game, ~route, "0.0.0.0", 8082, init())`.

## Bend issues and unexpected behavior and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
