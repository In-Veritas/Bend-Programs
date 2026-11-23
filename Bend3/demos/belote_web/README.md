# Belote

A playable classic French Belote table for BendJogos. You sit South with Luc
as your North partner; Bend3 controls Mireille and Camille, shuffles and deals
the 32-card deck, runs both bidding rounds, enforces every card-play constraint,
chooses the opponents' bids and cards, collects tricks, resolves the contract,
and keeps a match score to 501. The browser is only the table renderer and the
South player's input surface.

The implementation follows the Fédération Française de Belote's [classic
rules summary](https://www.ffbelote.org/regles-officielle-belote/): five cards
before bidding, the turned suit in round one, the other three suits in round
two, mandatory following, cutting when the partner is not master,
overtrumping, the trump order J–9–A–10–K–Q–8–7, ordinary order
A–10–K–Q–J–9–8–7, and the ten-point last trick. A trump king–queen is
automatically announced as Belote/Rebelote and scores 20. To keep the first
edition focused, tierce, cinquante, carré, and other optional declarations are
not included.

## Run and verify

The source targets Bend 2.0.40 (and the current bendlang/bend `bend2/main.ts`,
same CLI) and uses the shared `../HTTP.bend` and `../Compat.bend` modules.
From the Bend-Programs repository root (the server reads
`Bend3/demos/belote_web/index.html` relative to it):

```sh
bend Bend3/demos/belote_web/web_belote.bend --check-only   # ALL PROOFS CHECK
(cd Bend3/demos/belote_web && bend probe.bend)            # prints 1
./Bend3/demos/belote_web/build.sh     # native build into build/ (gitignored)
./Bend3/demos/belote_web/start.sh     # serves http://0.0.0.0:8091
```

`probe.bend` runs the pure deal/ranking probe `test()` (five then eight
cards per seat, all 32 cards dealt exactly once, trump points). Open
`http://localhost:8091` for the standalone table, or
`http://<server-lan-ip>:8090/belote` through BendJogos.

The initial deal and the always-available **New random match** action obtain a
fresh seed from Base's `IO.random_u32`; later hands advance that seed
deterministically. The HTTP regression test also resets the shared table when
it finishes, so testing no longer leaves the next visitor looking at an already
completed hand.

AI bidding and card play advance through `/auto` one seat at a time. The client
waits 650 ms between those Bend-owned transitions, making the other three
players' actions visible instead of resolving every remaining turn inside the
human player's request.

The deterministic deal uses an odd affine permutation of all 32 card indices,
so each hand has no duplicates. The AI is intentionally understandable rather
than expert: it evaluates trump strength during bidding and selects the first
legal card during play. It cannot violate follow, cut, or overtrump rules
because the same Bend legality function gates both human and AI plays.

The browser script has a syntax and surface regression check:

```sh
bun Bend3/demos/belote_web/test_client.mjs
bun Bend3/demos/belote_web/test_server.mjs   # with the server running: one full hand
```

## Hub interface

`web_belote.bend` exposes, for a hub that imports it
(`import ../belote_web/web_belote.bend as Belote`):

- `Belote.Game`, the table state (`is Data`);
- `Belote.init() -> IO(Game)` (fresh random seed) or `Belote.game_empty(seed)`;
- `Belote.route(req, game) -> IO(Game & HTTP.Response)` for standalone-shaped
  paths (`/`, `/state`, `/bid/<n>`, `/play/<card>`, `/auto`, `/next`, `/new`);
- `Belote.route_at("/belote", req, game)`, the same with the mount prefix
  stripped first (`/belote/state` is `/state`, `/belote` is the page).

`main` is only `HTTP.serve(~Game, ~route, "0.0.0.0", 8091, init())`.
`index.html` already prefixes its requests with `/belote` when mounted there.

## Bend 2.0.40 port notes

- Comparisons now answer `Bool`; the old U32-as-boolean `match (a == b)` rows
  became small helpers matching `Bool` parameters, or `Bool.pick`.
- Every counted loop (cards 0..31, suits, ranks, deal indices) counts down a
  `Nat` fuel, so the whole file checks without `@unsafe`.
- The second-round AI fallback suit is now a suit that is legal in round two;
  before, a hand whose only valued suit was the turned one could make the
  forced fourth AI bid repeat an illegal suit forever.
- `game_auto` (unused by any route) was dropped; `/auto` steps exactly one seat.

