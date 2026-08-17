# Bend3 Poker

A genuinely playable four-seat poker room with selectable Texas Hold'em and
Omaha. The dealer is a rotating button/role among those four seats. Seat zero
belongs to the first browser, invitation links can claim any of the other
three seats, and Bend AI fills every seat that has not been claimed.

Bend3 is authoritative for the 52-card shuffle and deal, private-card access,
blinds, turn order, fold/check/call/raise legality, bounded raise-to amounts,
street transitions, pots, five-card evaluation, showdown, chip awards, and the
ten seeded personas. `IO.rand_word()` seeds the initial table; later hands use
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

From the Bend3 repository root:

```sh
bun bend-ts/src/bend.ts gabriel_demos/poker_web/web_poker.bend --eval test
node gabriel_demos/poker_web/test_client.mjs
./gabriel_demos/poker_web/build.sh
./gabriel_demos/poker_web/start.sh
node gabriel_demos/poker_web/test_server.mjs
```

The standalone table listens on `http://localhost:8092`. BendJogos mounts the
same module at `/poker`; its fixed corner switch opens the Bend2 Core observer
at `/core/poker`.

## BendJogos integration surface

`generate_modules.mjs` can namespace this file as `Poker`. The hub needs:

- `Poker.Game` in its platform state;
- `Poker.game_empty(seed)` for initialization;
- `Poker.request_route(request, game)` when routing a standalone-shaped path;
- or `Poker.list_route(parts, game)` after the hub has stripped `/poker`;
- `Poker.Routed`, whose fields are the next `Game` and `HTTP.Response`.

The source imports no compiler internals and changes no Bend implementation.
Versioned source/layout observations and the explicit side-pot limitation are
kept in [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
