# Core Belote Observatory

This is a pure, deterministic four-AI classic Belote hand written in Bend
(2.0.40). It is an observer rather than an interactive game: every private card is
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

## Generated-JavaScript bridge

The program is pure: seed `1` is embedded and `main()` returns a
`BeloteReport` containing all 36 snapshots. `build.sh` checks it with Bend
2.0.40, runs `bend belote.bend -o belote.mjs` (an ES module exporting every
non-IO def), rewrites only its single `export default {` into a local binding
inside an IIFE, and publishes the evaluated report as the browser global
`BEND2_BELOTE_DATA` in `belote_data.js`, a classic script. Values use Bend's
export encoding: `{$: "Name", field: value}` constructors, `List` as
`{$: "Con", head, tail}` / `{$: "Nil"}`, JS booleans and numbers.
`index.html` decodes, schedules, and renders that immutable Bend value; it does
not deal, bid, select cards, or score the hand.

`belote_data.js` is checked in so the relative page can be mounted directly at
`/core/belote/`. Regenerate and verify it with (`bend` and `bun` on `PATH`):

```sh
./build.sh
bun test.mjs
```

Or verify the Bend entry directly:

```sh
bend belote.bend --check-only   # ALL PROOFS CHECK
bend belote.bend                # normalizes and prints the BeloteReport (~4 s)
```

The regression test independently reconstructs the legal set at every play,
checks turn order and trick winners, verifies all 162 card points including
`dix de der`, and confirms the Bend report's 47-115 result.

The test also checks every trick's winner and running score against the Bend
snapshots (eight tricks). The source uses no `@unsafe`: recursion is
structural (list descent or Nat fuel), and `rules_valid` recomputes the
cut/overtrump legality and the eight trick totals inside Bend, so the report's
`valid` field is `True`. A later version could replace the embedded seed with
Bend's IO and drive the hand from an effect loop.
