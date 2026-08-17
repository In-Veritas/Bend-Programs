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

## Generated-JavaScript bridge

Bend2 Core has no implemented IO, browser, clock, or randomness runtime. Seed
`1` is therefore embedded and `main()` returns a `BeloteReport` containing all
36 snapshots. `build.mjs` compiles it with the Core JavaScript backend and
replaces only the emitter's final console-printer footer with a browser global.
`index.html` decodes, schedules, and renders that immutable Bend value; it does
not deal, bid, select cards, or score the hand.

`belote_data.js` is checked in so the relative page can be mounted directly at
`/core/belote/`. Regenerate and verify it with:

```sh
./build.sh
bun test.mjs
```

Or verify the Core entry directly:

```sh
cd /path/to/bend2-core
bun src/main.ts "/path/to/Bend-Programs/Bend2 Core/demos/belote/belote.bend"
bun src/main.ts "/path/to/Bend-Programs/Bend2 Core/demos/belote/belote.bend" --to /tmp/core-belote.js
bun /tmp/core-belote.js
```

The regression test independently reconstructs the legal set at every play,
checks turn order and trick winners, verifies all 162 card points including
`dix de der`, and confirms the Bend report's 47-115 result.

This source uses no `#[halts]`. When Core receives real IO and randomness,
replace the embedded seed/report bridge with an effect-driven hand loop.
