# Core Poker Observatory

This is a pure Bend2 Core poker simulation, not a JavaScript poker engine. It
contains two deterministic, complete four-AI timelines:

- Texas Hold'em, seed `5`, with two hole cards and a five-card board;
- Omaha, seed `29`, with four hole cards and the mandatory two-hole / three-board
  interpretation used by the reported made hands.

The four seats are Ada Ante (value-oriented), Bluff Beak (loose), Cautious Cora
(tight), and River Rook (aggressive). Bend returns every deal, reveal, AI
action, amount, pot, stack, active/folded flag, current hand description, win
equity, and category/improvement percentages. The viewer exposes the requested
omniscient point of view: all four private hands and all four odds columns stay
visible throughout playback.

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

`main() -> PokerReport`, where the fields are `texas: Timeline` and
`omaha: Timeline`. Each timeline carries `variant`, `seed`, `dealer`, `winner`,
and `steps: List<Step>`. A step carries `phase`, `note`, `actor` (`0..3`, or `4`
for the dealer), `action`, `amount`, `pot`, community `board`, and four
`PlayerView` values. Each player contains identity, personality, active flag,
stack, all private cards, current best-hand text, and nine integer percentages:
win plus high card, pair, two pair, trips, straight, flush, full house, quads.
Cards are IDs `0..51`: rank is `id % 13` (`2` through ace) and suit is
`id / 13` (clubs, diamonds, hearts, spades).

## Probability model and limitations

The deals are genuine no-repeat affine deck permutations. Win and improvement
percentages are deterministic street-by-street estimates authored for these
embedded deals; they are not an exhaustive enumeration of every unseen deck
completion. The four win equities always total 100, and showdown category
probabilities become one-hot. All cards are intentionally known to the viewer,
while the AI narrative acts from its own seat's street information.

This build uses no `#[halts]`. The source is finite apart from structurally
checked Base operations.

When Core gains IO, replace the embedded seeds with an input/randomness seam and
drive `PokerReport` steps from a proper effect loop. Until then this viewer is a
watchable pure simulation by design.
