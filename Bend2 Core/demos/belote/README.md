# Core Belote Observatory

This is a pure, deterministic four-AI classic Belote hand written in Bend
(originally for Bend2 Core, now ported to the latest bendlang/bend). It is an
observer rather than an interactive game: every private card is visible,
played cards fade instead of disappearing, the current trick is shown in the
middle, and playback can run automatically or one step at a time.

`belote.bend` owns the complete result:

- a seeded, disjoint 32-card deal with four eight-card hands;
- first-round bidding and hearts as trump;
- four named AI policies;
- all 32 plays across eight tricks;
- follow-suit, mandatory cut, and mandatory overtrump behavior;
- trump/non-trump rank and point interpretation;
- cumulative points and the contract outcome;
- a machine-checked verification audit (below).

Trick three deliberately makes Mireille cut clubs with a heart and then forces
Noe to overtrump. East-West, the taking team, make the contract with 115 card
points against 47. Announcements are not included.

## Mathematical theorems and finite certificates

`belote_proofs.bend` supplies the semantic proof. It represents every card as
an indivisible token carrying a stable identity and printed point value;
dealing, playing, and collecting a trick may change only that token's zone. A
structural step theorem (`reassign_payload_preservation_theorem`, packaged as
`action_payload_preservation_theorem`) proves one arbitrary move preserves the
full ordered card payload. A second induction
(`history_payload_conservation_theorem`) lifts it to every finite play
history, and card-count and point-mass conservation
(`history_card_count_conservation_theorem`,
`history_card_value_conservation_theorem`) follow as corollaries. Contract
bonuses and penalties are intentionally outside this printed-card invariant.
The file also proves `payload_length_theorem` and the transport law
`apply_event_congruence`.

For every finite `List<Nat>` of play indices,
`play_steps_from_indices_length_theorem` proves by structural induction that
conversion to observer snapshots preserves the list length. Its recursive
branch uses the theorem for an arbitrary tail; it is not an enumeration of the
published hand.

Separately, `belote.bend` carries 119 closed certificates (`law`s over finite
domains, each proven case by case with `{==}`) for its one embedded trace. The
checker normalizes every one of them; the compiled program erases them:

- all 32 deck positions are in range and distinct (32), and all four hands
  contain eight cards (4);
- at each of the 32 plays, the card is still in that actor's hand (32);
- all 32 plays satisfy lead, follow-suit, cut, partner-winning, trump-rise and
  overtrump obligations computed from the current hand and trick table (32);
- all eight trick winners (8) and all eight trick point totals (8) match the
  declared timeline; and
- the scores total 162, the older runtime self-check `rules_valid()` is true,
  and the report contains exactly 36 snapshots (3).

The certificate families cover finite `CheckSeat`, `CheckTrick`, and
`CheckPlay` datatypes. Changing a deal, play, rule, winner, point value, or
timeline length makes the relevant certificate fail to check (verified by
mutating a trick winner and swapping two plays). This is a useful exhaustive
audit of the embedded trace, but it is not a mathematical proof about every
Belote deal or strategy.

The report's `verification: BeloteVerificationAudit` holds every theorem and
certificate in erased (`-`) fields, so building the report demands them all,
plus the human-readable scope text and the counts `certified_cases = 119` and
`general_theorems = 4` (the three conservation theorems and the mapping
lemma).

### Port notes (bend2-core to the latest Bend)

- Every `assert`/`def` pair became a `law` (or a typed `def`) with the same
  statement; no theorem was weakened, nothing is left open, and nothing uses
  `@unsafe`.
- Bend2 Core had no contraction, so the old history proof built two explicit
  replicas of the event and the card list (`card_event_copy`,
  `card_list_copy`, `card_zone_copy`, `card_copy` and their `*_replica_exact`
  / `*_copy_side` lemmas, plus `Equal.copy`) and moved the claim between them
  with `apply_event_congruence`. On the latest Bend these types are `Data`, so
  the proof shares one `+cards` value and composes the induction hypothesis
  with the step lemma directly; the replica lemmas (which said nothing about
  Belote) are gone. The quantity is part of the theorem's type, so the claim
  types read `@+cards: +List<Card> -> ...`.
- Lists are `+List<T>`, measured with Base's `List.length(&2, T, xs)` rather
  than the compat module (whose import alias `List` would shadow Base's
  `List.*`).
- The nested `match`es on computed Bools in the legality checks
  (`play_follows_suit`, `play_trump_rule`) became the equivalent Boolean
  formulas, because a `match` may only inspect a parameter or pattern
  variable. The case split is documented next to `play_trump_rule`.

## Generated-JavaScript bridge

The report has no browser, clock or randomness input, so seed `1` is embedded
and `main_value()` returns a `BeloteReport` containing all 36 snapshots plus
the verification audit. `main() -> IO(Unit)` only forces that value and prints
`Ready{}`. `build.sh` checks the file, runs `bend belote.bend -o belote.mjs`
(an ES module exporting every non-IO def), rewrites that module's single
`export default {` into a local binding inside an IIFE, and publishes
`main_value()` as the browser global `BEND2_BELOTE_DATA` (with
`BEND2_BELOTE_META`) in `belote_data.js`, a classic script. `index.html`
decodes, schedules, and renders that immutable Bend value, including the audit
panel; it does not deal, bid, select cards, or score the hand.

In JavaScript the value uses Bend's export encoding: constructors are
`{$: "Name", field: value}` with the field names of `belote.bend`
(`BeloteReport.steps`, `.verification`, `Step.players`, `Step.table`, ...),
`List` is `{$: "Con", head, tail}` / `{$: "Nil"}`, `Bool` is a JS boolean, and
`U32`/`Nat` are numbers. Erased audit fields do not appear; the audit object
carries `title`, `scope`, `deck`, `legality`, `scoring`, `limitation`,
`certified_cases` and `general_theorems`.

`belote_data.js` is checked in so the relative page can be mounted directly at
`/core/belote/`. Regenerate and verify it with (`bend` and clang on `PATH`):

```sh
./build.sh      # ~2 min: checks (~40 s) then emits the module
bun test.mjs
```

The regression test checks `belote_proofs.bend` and `belote_proofs_test.bend`,
builds the proof entry to JavaScript and to a native binary and requires both
to print `True{}`, then independently reconstructs the legal set at every
play, checks turn order and trick winners, verifies all 162 card points
including `dix de der`, confirms the Bend report's 47-115 result, and requires
the four-theorem / 119-certificate audit emitted from the checked source.

Direct verification:

```sh
bend belote.bend --check-only             # ALL PROOFS CHECK (~40 s)
bend belote_proofs.bend --check-only      # ALL PROOFS CHECK
bend belote.bend                          # Ready{}
bend belote.bend -o /tmp/belote && /tmp/belote             # Ready{}
bend belote_proofs_test.bend              # True{}
```

This source is structurally terminating. If the report receives randomness
plus an application or browser input seam, replace the embedded seed/report
bridge with an effect-driven hand loop.
