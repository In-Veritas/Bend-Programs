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

From the Bend3 repository root:

```sh
bun bend-ts/src/bend.ts gabriel_demos/belote_web/web_belote.bend --eval test
./gabriel_demos/belote_web/build.sh
./gabriel_demos/belote_web/start.sh
```

The pure probe must print `1`. Open `http://localhost:8091` for the standalone
table, or `http://<server-lan-ip>:8090/belote` through BendJogos.

The initial deal and the always-available **New random match** action obtain a
fresh seed from Bend3's `IO.rand_word`; later hands advance that seed
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
node gabriel_demos/belote_web/test_client.mjs
```
