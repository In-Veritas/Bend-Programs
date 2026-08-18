# Core Poker Observatory

This is a pure Bend2 Core poker simulation, not a JavaScript poker engine. It
contains two deterministic, complete four-AI timelines:

- Texas Hold'em, seed `5`, with two hole cards and a five-card board;
- Omaha, seed `29`, with four hole cards and the mandatory two-hole / three-board
  interpretation used by the reported made hands.

The four seats are Ada Ante (value-oriented), Bluff Beak (loose), Cautious Cora
(tight), and River Rook (aggressive). Bend returns every deal, reveal, AI
action, amount, pot, stack, active/folded flag, current hand description, win
equity, category/improvement percentages, and a machine-checked proof audit.
The viewer exposes the requested omniscient point of view: all four private
hands and all four odds columns stay visible throughout playback.

## Hand-written proofs

Core's proof-generation path is not used. Every witness and equality proof in
`poker.bend` is written explicitly and checked with the rest of the program.
There are 78 finite cases and witnesses across these claims:

- **Randomness matters:** one strategy held fixed over two runouts produces two
  different winners.
- **Skill matters:** one runout held fixed under two strategies produces two
  different winners.
- **Not rigged:** each of the four seats has a concrete runout/strategy pair
  for which it wins. Formally, the finite winner function is surjective.
- **Odds rows are well formed:** all 20 Texas category rows and all 28 Omaha
  category rows sum to exactly 100; the four win equities sum to 100 at every
  one of the 5 Texas and 7 Omaha published stages.
- **State consistency:** folded players have zero win equity, and each declared
  showdown winner has 100% equity.

The fairness theorem is intentionally a finite model of the game inputs, since
this no-IO build can replay only its two fixed timelines. It proves that both a
random input and a skill input can affect the model's outcome; it does not
prove cryptographic unpredictability, optimal AI play, or fairness of an
external random-number generator.

Likewise, “odds are right” means the authored tables are normalized and agree
with fold/showdown state. The estimates are not derived by exhaustively
enumerating unseen cards, so the proof does not claim they equal the true
real-world poker probabilities. That distinction is also displayed in the
viewer.

## Why it is generated JavaScript

Bend2 Core has no implemented input, clock, DOM, filesystem, or HTTP runtime.
`poker.bend` therefore returns a `PokerReport` value. The Core JavaScript
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

Set `BEND2_CORE=/path/to/bend2-core` if the compiler is not the workspace
sibling. Direct verification is:

```sh
cd /path/to/bend2-core
bun src/main.ts "/path/to/Bend-Programs/Bend2 Core/demos/poker/poker.bend" --to /tmp/poker.js
bun /tmp/poker.js
```

## Output schema

`main() -> PokerReport`, where the fields are `texas: Timeline`,
`omaha: Timeline`, and `proofs: ProofAudit`. Each timeline carries `variant`,
`seed`, `dealer`, `winner`, and `steps: List<Step>`. A step carries `phase`,
`note`, `actor` (`0..3`, or `4` for the dealer), `action`, `amount`, `pot`,
community `board`, and four `PlayerView` values. Each player contains identity,
personality, active flag, stack, all private cards, current best-hand text, and
nine integer percentages: win plus high card, pair, two pair, trips, straight,
flush, full house, quads. Cards are IDs `0..51`: rank is `id % 13` (`2` through
ace) and suit is `id / 13` (clubs, diamonds, hearts, spades).

`ProofAudit` contains erased proof fields followed by human-readable theorem
scope and a checked-case count. Direct Core evaluation can show the witnesses;
the JS backend erases proof values and retains only the audit description used
by the page. The erased fields on the constructor ensure `main` itself is built
with the checked proof terms rather than merely displaying unrelated labels.

## Probability model and limitations

The deals are no-repeat affine deck permutations. Win and improvement
percentages are deterministic street-by-street estimates authored for these
embedded deals; they are not an exhaustive enumeration of every unseen deck
completion. The proof layer checks that the four win equities always total 100,
that every category distribution totals 100, that folded seats remain at zero,
and that showdown becomes winner-consistent and one-hot. All cards are
intentionally known to the viewer, while the AI narrative acts from its own
seat's street information.

This build uses no `#[halts]`. The source is finite apart from structurally
checked Base operations. The proof model uses finite ADTs so each constructor
case is explicit and reduction has the structural information it needs.

When Core gains IO, replace the embedded seeds with an input/randomness seam and
drive `PokerReport` steps from a proper effect loop. Until then this viewer is a
watchable pure simulation by design.
