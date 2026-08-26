# Core Belote Observatory

This is a pure, deterministic four-AI classic Belote hand written in Bend2
Core. It is an observer rather than an interactive game: every private card is
visible, played cards fade instead of disappearing, the current trick is shown
in the middle, and playback can run automatically or one step at a time.

`belote.bend` owns the complete result:

- a seeded, disjoint 32-card deal with four eight-card hands;
- first-round bidding and hearts as trump;
- four named AI policies;
- all 32 plays across eight tricks;
- follow-suit, mandatory cut, and mandatory overtrump behavior;
- trump/non-trump rank and point interpretation;
- cumulative points and the contract outcome.

Trick three deliberately makes Mireille cut clubs with a heart and then forces
Noe to overtrump. East-West, the taking team, make the contract with 115 card
points against 47. Announcements are not included.

## Mathematical theorems and finite certificates

`belote_proofs.bend` supplies the semantic proof. It represents every card as
an indivisible token carrying a stable identity and printed point value;
dealing, playing, and collecting a trick may change only that token's zone. A
structural step theorem proves one arbitrary move preserves the full ordered
card payload. A second induction lifts it to every finite play history, and
card-count and point-mass conservation follow as corollaries. Contract bonuses
and penalties are intentionally outside this printed-card invariant.

For every finite `List<Nat>` of play indices,
`play_steps_from_indices_length_theorem_func` proves by structural induction
that conversion to observer snapshots preserves the list length. Its recursive
branch uses the theorem for an arbitrary tail; it is not an enumeration of the
published hand.

Separately, `belote.bend` carries 119 closed certificates for its one embedded
trace. Core checks them with the rest of the book and the JavaScript backend
erases their witnesses:

- all 32 deck positions are in range and distinct, and all four hands contain
  eight cards;
- at each of the 32 plays, the card is still in that actor's hand;
- all 32 plays satisfy lead, follow-suit, cut, partner-winning, trump-rise and
  overtrump obligations computed from the current hand and trick table;
- all eight trick winners and all eight trick point totals match the declared
  timeline; and
- the scores total 162, the older runtime self-check is true, and the report
  contains exactly 36 snapshots.

The certificate families cover finite `CheckSeat`, `CheckTrick`, and
`CheckPlay` datatypes. Changing a deal, play, rule, winner, point value, or
timeline length makes the relevant certificate fail to type-check. This is a
useful exhaustive audit of the embedded trace, but it is not a mathematical
proof about every Belote deal or strategy.

## Generated-JavaScript bridge

Bend2 Core now has standard IO, files and sockets, but no browser, clock or
randomness API. Seed `1` is therefore embedded and `main_value()` returns a
`BeloteReport` containing all 36 snapshots plus a verification-audit summary.
`build.mjs` compiles it with the Core
JavaScript backend and replaces only the emitter's final console-printer footer
with a browser global.
`index.html` decodes, schedules, and renders that immutable Bend value; it does
not deal, bid, select cards, or score the hand.

`belote_data.js` is checked in so the relative page can be mounted directly at
`/core/belote/`. Regenerate and verify it with:

```sh
./build.sh
bun test.mjs
```

The regression test checks `belote_proofs_test.bend` through both generated
JavaScript and clang-built native C; both erased proof entries must return
`True{}`.

Or verify the Core entry directly:

```sh
cd /path/to/bend2-core
bun bend2/comp.ts "/path/to/Bend-Programs/Bend2 Core/demos/belote/belote.bend"
bun bend2/comp.ts "/path/to/Bend-Programs/Bend2 Core/demos/belote/belote.bend" --to /tmp/core-belote.js
bun /tmp/core-belote.js
```

The regression test independently reconstructs the legal set at every play,
checks turn order and trick winners, verifies all 162 card points including
`dix de der`, confirms the Bend report's 47-115 result, and requires the
four-theorem/119-certificate audit emitted from the checked Core source. Three
of those theorems are the arbitrary-history conservation summit and its
observable corollaries; the fourth is the snapshot-mapping lemma.

This source is structurally terminating. If Core receives randomness plus an
application or browser input seam, replace the embedded seed/report bridge with an
effect-driven hand loop.
