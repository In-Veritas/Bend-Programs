# Bend3 Poker

A genuinely playable four-seat poker room with selectable Texas Hold'em and
Omaha. The dealer is a rotating button/role among those four seats. Seat zero
belongs to the first browser, invitation links can claim any of the other
three seats, and Bend AI fills every seat that has not been claimed.

Bend3 is authoritative for the 52-card shuffle and deal, private-card access,
blinds, turn order, fold/check/call/raise legality, bounded raise-to amounts,
street transitions, pots, five-card evaluation, showdown, chip awards, and the
ten seeded personas. `IO.random_u32()` seeds the initial table; later hands use
a deterministic LCG step so a running table never repeats its original deal.
The ten-person roster ranges from fearless Ada All-In to tight Texas Tern and
is sampled into four distinct personas per hand.

The browser has one deliberate calculation responsibility: its live odds
panel performs deterministic visible-information rollouts. Its own equity and
final hand-category odds use its private cards plus the public board. Opponent
hover balloons sample unknown hole cards and display only estimates derivable
without receiving those cards. Before showdown, `/state/<seat>/<token>` sends
only the authenticated viewer's cards; the regression test checks that wall.

Omaha showdowns always use exactly two of the four hole cards and exactly three
community cards. Texas chooses the best five of seven. The first edition uses
no-limit-style raise-to controls with 10/20 blinds and does not yet implement
side pots; a short stack can call all-in, but a multi-way unequal all-in pot is
awarded as one pot. That limitation is kept visible rather than pretending the
engine implements tournament-grade side-pot accounting.

## Run and verify

The source targets Bend 2.0.40 (and the current bendlang/bend `bend2/main.ts`,
same CLI) and uses the shared `../HTTP.bend` and `../Compat.bend` modules.
From the Bend-Programs repository root (the server reads
`Bend3/demos/poker_web/index.html` relative to it):

```sh
bend Bend3/demos/poker_web/web_poker.bend --check-only   # ALL PROOFS CHECK
(cd Bend3/demos/poker_web && bend probe.bend)           # prints 1
bun Bend3/demos/poker_web/test_client.mjs
./Bend3/demos/poker_web/build.sh     # native build into build/ (gitignored)
./Bend3/demos/poker_web/start.sh     # serves http://0.0.0.0:8092
bun Bend3/demos/poker_web/test_server.mjs
```

`probe.bend` runs `test()` compiled (deal sizes, distinct personas, royal
flush / pair / wheel scores, and an Omaha-vs-Texas board where only Texas
makes the flush). The standalone table listens on `http://localhost:8092`.
BendJogos mounts the same module at `/poker`; its fixed corner switch opens
the Bend2 Core observer at `/core/poker`.

## Hub interface

`web_poker.bend` exposes, for a hub that imports it
(`import ../poker_web/web_poker.bend as Poker`):

- `Poker.Game`, the table state (`is Data`);
- `Poker.init() -> IO(Game)` (fresh random seed) or `Poker.game_empty(seed)`;
- `Poker.route(req, game) -> IO(Game & HTTP.Response)` for standalone-shaped
  paths (`/`, `/state/<seat>/<token>`, `/claim/<seat>`,
  `/action/<seat>/<token>/<kind>/<amount>`, `/new/<seat>/<token>/<variant>`);
- `Poker.route_at("/poker", req, game)`, the same with the mount prefix
  stripped first.

`main` is only `HTTP.serve(~Game, ~route, "0.0.0.0", 8092, init())`.
`index.html` already prefixes its requests when mounted at `/poker`.

## Bend 2.0.40 port notes

- Comparisons answer `Bool`; U32-as-boolean `match` rows became helpers on
  `Bool` parameters or `Bool.pick`. Loops count down `Nat` fuel; `game_auto`
  recurses through a closure (`g => game_auto(f, g)`). No `@unsafe`.
- Omaha scoring now enumerates the six hole pairs and ten board triples as
  lists instead of nested index loops (same result: exactly two plus three).
- A betting round now completes when every seat that can still act (state 0)
  has acted and matched the bet; all-in seats no longer have to "act" again on
  later streets, and a street where nobody can act goes straight to showdown.
  The old rule could leave a hand with an all-in seat circling forever.
- Side pots are still not implemented (see above).
