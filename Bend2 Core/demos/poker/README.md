# Core Poker Observatory

This is a pure Bend poker simulation (ported from bend2-core to the latest
Bend, `bend 2.0.40` from the bendlang/bend source), not a JavaScript poker
engine. It contains two deterministic, complete four-AI timelines:

- Texas Hold'em, seed `5`, with two hole cards and a five-card board;
- Omaha, seed `29`, with four hole cards and the mandatory two-hole / three-board
  interpretation used by the reported made hands.

The four seats are Ada Ante (value-oriented), Bluff Beak (loose), Cautious Cora
(tight), and River Rook (aggressive). Bend returns every deal, reveal, AI
action, amount, pot, stack, active/folded flag, current hand description, win
equity, category/improvement percentages, and a machine-checked verification
audit. The viewer exposes the requested omniscient point of view: all four
private hands and all four odds columns stay visible throughout playback.

## Mathematical theorems and finite certificates

The headline proof lives in `poker_proofs.bend`. It models every chip as an
indivisible token carrying a stable identity and value, while a settlement
action may move any selected token among the four seats and the pot. A local
reassignment lemma (`reassign_payload_preservation_theorem`, lifted to the
action type by `action_payload_preservation_theorem`) proves that one action
preserves the complete ordered identity/value payload. An outer structural
induction (`history_payload_conservation_theorem`) lifts that fact to every
finite betting and payout history. Two corollaries
(`history_chip_count_conservation_theorem`,
`history_chip_value_conservation_theorem`) then prove that arbitrary histories
preserve both chip count and total chip value. `payload_length_theorem` and
`settle_action_congruence` are further supporting lemmas. These are semantic
theorems over arbitrary ledgers and histories, not executions of the two
published hands.

`poker.bend` also contains three supporting general lemmas. For every finite
list of deck indices, mapping the Texas dealer over that list preserves its
length (`texas_cards_length_theorem`); the same holds for the Omaha dealer
(`omaha_cards_length_theorem`). Both are proved by structural induction, with
a recursive hypothesis for an arbitrary tail; the published boards are dealt
through those same mapping functions. A third theorem
(`complete_rounds_balanced_theorem`) proves by induction over an arbitrary
number of complete deal rounds that all four seats receive exactly one card per
round, hence equal card counts.

Separately, Bend checks 78 closed certificates and finite witnesses for the
two authored timelines:

- **Randomness matters:** one strategy held fixed over two runouts produces two
  different winners.
- **Skill matters:** one runout held fixed under two strategies produces two
  different winners.
- **Seat coverage:** each of the four seats has a concrete runout/strategy pair
  for which it wins in the finite authored model.
- **Odds rows are well formed:** all 20 Texas category rows and all 28 Omaha
  category rows sum to exactly 100; the four win equities sum to 100 at every
  one of the 5 Texas and 7 Omaha published stages.
- **State consistency:** folded players have zero win equity, and each declared
  showdown winner has 100% equity.

The runout, strategy, and seat records are witnesses in a finite authored
model, not mathematical proofs of poker fairness. They show that selected
inputs can affect that model's outcome; they do not establish cryptographic
unpredictability, optimal AI play, or fairness of an external random-number
generator.

Likewise, “odds are right” means the authored tables are normalized and agree
with fold/showdown state. The estimates are not derived by exhaustively
enumerating unseen cards, so the certificates do not claim they equal the true
real-world poker probabilities. That distinction is also displayed in the
viewer.

Every claim is a `law` proved by the `def` of the same name; no `@unsafe`,
no `?TODO`. A deliberately broken odds row or a `reassign_chip` that changes a
chip's value makes `--check-only` print SOME PROOFS FAIL (verified during the
port). `--verdict` (the Lean-proved kernel recheck) was not run: Lean is not
installed here.

## Why it is generated JavaScript

`poker.bend` keeps the game as a pure `PokerReport` value, `main_value()`;
the executable `main: IO(Unit)` only prints `Ready{}`. `build.sh` checks the
file and runs `bend poker.bend -o poker.mjs` (an ES module exporting every
non-IO def). It then rewrites only that module's single `export default {`
into a local binding inside an IIFE and publishes the evaluated
`main_value()` as the browser global `BEND2_POKER_DATA` (plus
`BEND2_POKER_META`) in `poker_data.js`, a classic script. `index.html` decodes
that immutable value and handles presentation timing. It does not deal cards,
choose actions, modify stacks, or calculate odds.

`poker_data.js` is intentionally checked in so the page can be served unchanged
at `/core/poker/`; every asset reference is relative. Regenerate it whenever
`poker.bend` changes (needs `bend` and `bun` on `PATH`):

```sh
./build.sh
bun test.mjs
```

The regression test re-checks `poker.bend`, `poker_proofs.bend` and
`poker_proofs_test.bend`, builds the proof entry to generated JavaScript and to
a native binary (both must print `True{}`), and validates the published report
(timelines, chip totals, category/win totals, folded/showdown consistency, and
the audit's 6 theorems / 78 certificates).

Direct verification:

```sh
bend poker.bend --check-only              # ALL PROOFS CHECK
bend poker.bend                           # Ready{}
bend poker_proofs_test.bend               # True{}
bend poker_proofs_test.bend -o /tmp/ppt && /tmp/ppt   # True{}
```

## Output schema

`main_value() -> PokerReport`, where the fields are `texas: Timeline`,
`omaha: Timeline`, and `verification: PokerVerificationAudit`. Each timeline
carries `variant`, `seed`, `dealer`, `winner`, and `steps: List<Step>`. A step
carries `phase`, `note`, `actor` (`0..3`, or `4` for the dealer), `action`,
`amount`, `pot`, community `board`, and four `PlayerView` values. Each player
contains identity, personality, active flag, stack, all private cards, current
best-hand text, and nine integer percentages: win plus high card, pair, two
pair, trips, straight, flush, full house, quads. Cards are IDs `0..51`: rank
is `id % 13` (`2` through ace) and suit is `id / 13` (clubs, diamonds, hearts,
spades).

`PokerVerificationAudit` contains six erased (`-`) quantified theorem
fields—three semantic chip-conservation theorems and three deal-structure
lemmas—and erased finite-certificate fields, followed by human-readable
`title`, `scope`, `fairness`, `unrigged`, `odds`, `limitation`, a
`certified_cases` count (78) and a `general_theorems` count (6). Keeping the
proofs in `main_value`'s result type makes Bend check them whenever the report
is built; the JS export drops erased fields, so only the description reaches
the page.

In JavaScript the value uses Bend's export encoding: constructors are
`{$: "Name", field: value}` with the field names above, `List` is
`{$: "Con", head, tail}` / `{$: "Nil"}`, `Bool` is a JS boolean, and `U32` /
`Nat` are numbers. (The old bend2-core artifact used positional `$0, $1, ...`
fields; the audit is `report.verification`, e.g. `verification.certified_cases`.)

## Probability model and limitations

The deals are no-repeat affine deck permutations. Win and improvement
percentages are deterministic street-by-street estimates authored for these
embedded deals; they are not an exhaustive enumeration of every unseen deck
completion. The finite certificate layer checks that the four published win
equities total 100, that every category distribution totals 100, that folded
seats remain at zero, and that showdown becomes winner-consistent and one-hot.
All cards are intentionally known to the viewer, while the AI narrative acts
from its own seat's street information.

This build is structurally terminating. Finite ADTs make every closed audit
case explicit; they must not be confused with the arbitrary-history
conservation proof.

Latest Bend has argv, files and a clock in IO, but the viewer
is a static page, so this package stays a watchable pure simulation by design;
the interactive HTTP version is `Bend3/demos/poker_web`.

## Port notes (bend2-core c5d69a1 to latest Bend)

- `assert name: forall ...` + untyped `def` became typed `def`s, and every
  theorem/certificate a `law` with an unchanged statement plus its proof.
- Types are `is Data`; lists are `+List<..>` (Base `List<&2, ..>`), so the
  compat `List.length(A, xs)` became Base `List.length(&2, A, xs)`.
- `Sigma<A, x => B>` witnesses are written as dependent pairs
  `&x: A -> B`; the record fields holding proofs stay erased.
- In `poker_proofs.bend`, the ledger is Data, so the history induction shares
  it with a `+chips` binder; the affine-Core replica machinery
  (`chip_copy`, `chip_list_copy`, `ledger_action_copy`, their exactness lemmas
  and `Equal.copy`) became unnecessary and was removed. The step lemma,
  summit and both corollaries keep their exact statements.
- The owner's table fixes are included (Omaha turn-row win equities now total
  100, and the Omaha showdown is its own stage `6`).
