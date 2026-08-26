# Core Poker Observatory

This is a pure Bend2 Core poker simulation, not a JavaScript poker engine. It
contains two deterministic, complete four-AI timelines:

- Texas Hold'em, seed `5`, with two hole cards and a five-card board;
- Omaha, seed `29`, with four hole cards and the mandatory two-hole / three-board
  interpretation used by the reported made hands.

The four seats are Ada Ante (value-oriented), Bluff Beak (loose), Cautious Cora
(tight), and River Rook (aggressive). Bend returns every deal, reveal, AI
action, amount, pot, stack, active/folded flag, current hand description, win
equity, category/improvement percentages, and a machine-checked verification
audit.
The viewer exposes the requested omniscient point of view: all four private
hands and all four odds columns stay visible throughout playback.

## Mathematical theorems and finite certificates

The headline proof lives in `poker_proofs.bend`. It models every chip as an
indivisible token carrying a stable identity and value, while a settlement
action may move any selected token among the four seats and the pot. A local
reassignment lemma proves that one action preserves the complete ordered
identity/value payload. An outer structural induction lifts that fact to every
finite betting and payout history. Two corollaries then prove that arbitrary
histories preserve both chip count and total chip value. These are semantic
theorems over arbitrary ledgers and histories, not executions of the two
published hands.

`poker.bend` also contains three supporting general lemmas. For every finite
`List<Nat>` of deck indices, mapping the Texas dealer over that list preserves
its length; the same holds for the Omaha dealer. Both are proved by structural
induction, with a recursive hypothesis for an arbitrary tail. A third theorem
proves by induction over an arbitrary number of complete deal rounds that all
four seats receive exactly one card per round, hence equal card counts.

Separately, Core checks 78 closed certificates and finite witnesses for the
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

## Why it is generated JavaScript

Bend2 Core now has standard IO, files and sockets, but no browser input, DOM,
clock, HTTP/JSON convenience layer or randomness source. `poker.bend` therefore
keeps a pure `PokerReport` value. The Core JavaScript
backend evaluates that value, and `build.mjs` changes only the generated
program's print footer into a browser global named `BEND2_POKER_DATA`.
`index.html` decodes that immutable value and handles presentation timing. It
does not deal cards, choose actions, modify stacks, or calculate odds.

`poker_data.js` is intentionally checked in so the page can be served unchanged
at `/core/poker/`; every asset reference is relative. Regenerate it whenever
`poker.bend` changes:

```sh
./build.sh
bun test.mjs
```

The regression test checks `poker_proofs_test.bend` through both generated
JavaScript and clang-built native C; both erased proof entries must return
`True{}`.

Set `BEND2_CORE=/path/to/bend2-core` if the compiler is not the workspace
sibling. Direct verification is:

```sh
cd /path/to/bend2-core
bun bend2/comp.ts "/path/to/Bend-Programs/Bend2 Core/demos/poker/poker.bend" --to /tmp/poker.js
bun /tmp/poker.js
```

## Output schema

`main_value() -> PokerReport`, where the fields are `texas: Timeline`,
`omaha: Timeline`, and `verification: PokerVerificationAudit`. Each timeline carries `variant`,
`seed`, `dealer`, `winner`, and `steps: List<Step>`. A step carries `phase`,
`note`, `actor` (`0..3`, or `4` for the dealer), `action`, `amount`, `pot`,
community `board`, and four `PlayerView` values. Each player contains identity,
personality, active flag, stack, all private cards, current best-hand text, and
nine integer percentages: win plus high card, pair, two pair, trips, straight,
flush, full house, quads. Cards are IDs `0..51`: rank is `id % 13` (`2` through
ace) and suit is `id / 13` (clubs, diamonds, hearts, spades).

`PokerVerificationAudit` contains six erased quantified theorem fields—three
semantic chip-conservation theorems and three deal-structure lemmas—and
erased finite-certificate fields, followed by human-readable scope, a
certificate count, and a general-theorem count. The JS backend erases those
values and retains only the audit description used by the page. Keeping them
in `main_value`'s result type ensures Core checks them during the build; the
executable `main: IO(Unit)` only forces that value and reports readiness.

## Probability model and limitations

The deals are no-repeat affine deck permutations. Win and improvement
percentages are deterministic street-by-street estimates authored for these
embedded deals; they are not an exhaustive enumeration of every unseen deck
completion. The finite certificate layer checks that the four published win
equities total 100, that every category distribution totals 100, that folded
seats remain at zero, and that showdown becomes winner-consistent and one-hot.
All cards are intentionally known to the viewer, while the AI narrative acts
from its own seat's street information.

This build is structurally terminating. The source is finite apart from
structurally checked Base operations. Finite ADTs make every closed audit case explicit;
they must not be confused with the arbitrary-history conservation proof.

If Core gains a randomness source and a browser/application input seam, replace
the embedded seeds and drive `PokerReport` steps from that boundary. Standard
IO alone does not make this observer interactive.
