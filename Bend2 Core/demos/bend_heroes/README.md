# Bend Heroes

Bend Heroes is a deterministic, reduced Heroes-style strategy game written as
a pure Bend2 Core state machine and rendered in WebGL2 with the repository's
Bend Engine. Castle, Necropolis, and Inferno are the deliberately retained
factions; campaigns, networking, and audio are outside this package's chosen
scope. It uses the browser feedback protocol requested for interactive Core
programs:

```text
initial Game
  -> browser command
  -> heroes_browser_step_func(Game, command, arg0, arg1)
  -> next immutable Game
  -> browser command
  -> ...
```

The checked-in `heroes_data.js` is generated from `heroes.bend`. The browser
passes each returned `Game` constructor unchanged into the next generated Core
call. Movement, economy, combat, random rolls, progression, calendar, and
victory are never reimplemented in JavaScript. New-game seeds enter Core and
the resulting value is the complete authoritative state.

## Bend Engine presentation

The browser projects immutable Core values through the shared
`Bend Engine/bend_engine_webgl.js` renderer. It provides an orbitable 3D
adventure map, animated procedural terrain and sites, distinct Castle,
Necropolis, and Inferno town views, a 15 × 11 tactical battle scene, procedural
creature representations, clickable adjacent-tile beacons, and action/spell
feedback. All geometry,
materials, lighting, fog, camera work, and animation are presentation-only;
none of them can advance or alter the game.

The build copies the shared renderer verbatim into this self-contained web
package. No original Heroes III artwork, models, sounds, or other proprietary
assets are included.

## Playable rules

Each new game lets Red choose Castle, Necropolis, or Inferno; Blue receives the
next rival in the Castle → Necropolis → Inferno cycle. The result is a
two-force game on a 9 × 7 adventure map. Both sides remain controllable for
hot-seat play, while Core-owned strategic and tactical actions can drive them.
It implements these interlocking systems from `heroes_properties.md`:

- sequential Red and Blue turns, day/week/month time, daily income, movement
  and mana refresh, and weekly creature growth;
- eight-direction movement with 141% diagonal cost, plus Grass, Dirt, Rough,
  Swamp, Water, and Rock terrain and their configured movement costs;
- persistent one-shot gold, wood, shrine, and artifact sites, plus capturable
  Sawmill and Gold Mine ownership and daily income;
- Castle, Necropolis, and Inferno towns with hall and fort lines, one
  construction per town per day, prerequisite-ordered tier 1–7 dwellings,
  accumulated stock, recruitment, seven resources, and seven army slots;
- all seven base creatures of each retained faction, with attack, defense,
  damage, health, speed, growth, cost, numeric range, shots, flight, and
  retaliation capacity;
- one representative persistent hero per retained faction, with primary
  statistics, mana, movement, canonical
  experience thresholds through level 10, deterministic level gains, armies,
  and map position;
- an odd-column 15 × 11 hex battlefield with Core-owned deployment formations,
  deterministic interior obstacles, speed-bounded movement, occupancy checks,
  numeric melee/ranged reach, ammunition capability, long-range half damage,
  melee-only retaliation, and removal of destroyed stacks from formation;
- seeded per-creature damage rolls, attack/defense scaling and caps, exact
  first-creature health across casualties, 20%-defense Defend, Magic Arrow,
  Retreat, rewards, and healed surviving stacks after victory;
- deterministic enemy tactical responses that attack when in reach and advance
  otherwise, plus town investment and route-following strategic AI steps for
  either active side;
- neutral bridge guardians, enemy-town garrisons, town capture, and scenario
  victory; and
- browser save/load and undo as serialization/value selection only. These host
  conveniences never run a game transition outside Core.

The command protocol is:

| Code | Meaning | `arg0` | `arg1` |
| ---: | --- | --- | --- |
| 0–3 | North, East, South, West | ignored | ignored |
| 4 | End turn | ignored | ignored |
| 5 | Advance hall | ignored | ignored |
| 6 | Advance fort | ignored | ignored |
| 7 | Build dwelling | tier 1–7 | ignored |
| 8 | Recruit | tier 1–7 | amount |
| 9–12 | North-east, South-east, South-west, North-west | ignored | ignored |
| 20 | Attack | own slot 0–6 | enemy slot 0–6 |
| 21 | Defend | own slot 0–6 | attacking enemy slot 0–6 |
| 22 | Magic Arrow | ignored | enemy target slot 0–6 |
| 23 | Retreat | ignored | ignored |
| 24 | Move combat stack | own slot 0–6 | destination `row * 15 + column` |
| 30 | Strategic AI step | ignored | ignored |

Unknown or phase-inappropriate commands return an explanatory notice while
preserving the relevant game values.

## Fidelity boundary

The mechanics above are implemented in Core rather than approximated by the
viewer. This is intentionally a reduced complete gameplay loop, not a
byte-for-byte implementation of Heroes of Might and Magic III: Shadow of
Death. Features outside the selected scope include:

- the other factions, upgraded and neutral creatures, and the complete hero,
  artifact, spell, skill, building, and adventure-object catalogues;
- per-round speed queues, Wait, decrementing shot/retaliation counters,
  double-wide creatures, statuses, morale, luck, war machines, and siege
  machinery;
- multiple heroes and towns per player, meetings and exchanges, garrisons,
  taverns, fog of war, boats, quests, Grail, campaigns, general map loading,
  multiplayer transport, audio, and networking; and
- the original game's complete data and edge-case compatibility suite.

Those reductions are ordinary application scope, not Bend issues, so the
package intentionally has no `unexpected_behavior/` directory.

Creature records and combat-formula checks were cross-checked against VCMI's
open-source [Castle data](https://github.com/vcmi/vcmi/blob/develop/config/creatures/castle.json),
[Necropolis data](https://github.com/vcmi/vcmi/blob/develop/config/creatures/necropolis.json),
and [damage calculator](https://github.com/vcmi/vcmi/blob/develop/lib/battle/DamageCalculator.cpp).
VCMI is a validation reference, not a runtime dependency.

## Build and verify

Use the synchronized Bend2 Core checkout at revision `c5d69a1`:

```sh
BEND2_CORE=/path/to/bend2-core ./build.sh
BEND2_CORE=/path/to/bend2-core bun test.mjs
```

`build.mjs` stages browser roots, invokes `bun bend2/comp.ts`, regenerates
`heroes_data.js`, and synchronizes the Bend Engine renderer. `test.mjs`
validates all 63 adventure cells, all three playable faction pairings and
Inferno recruitment, strategic AI routes, 165-hex battlefield rules, numeric
range, legal and illegal tactical movement, enemy movement, retaliation
behavior, first-creature health, persistent pickups, construction,
recruitment, turn/day income, complete guardian and town battles, progression,
artifact pickup, victory, equal-seed determinism, renderer boundaries,
generated JavaScript execution, C emission, clang build, and native execution.
The Bend book is structurally terminating.

Serve this directory with any static HTTP server and open `index.html`; no
application server or package installation is required after generation.

## Files

- `heroes.bend` — authoritative pure game state and transitions;
- `heroes_tactics.bend` — reusable hex geometry, formations, obstacles,
  movement, range, retaliation, and tactical planning;
- `gameplay_audit.md` — fixed bugs, deliberate reductions, and Bend-issue
  classification from the implementation pass;
- `build.mjs` / `build.sh` — reproducible browser artifact generation;
- `heroes_data.js` — checked-in generated Bend2 Core JavaScript;
- `bend_engine_webgl.js` — synchronized shared Bend Engine renderer;
- `heroes_viewer.js` — input, state feedback, Core-value projection, save/load,
  and undo;
- `index.html` — graphical web application shell;
- `test.mjs` — gameplay and JS/C backend validation; and
- `heroes_properties.md` — supplied full-game replication reference.
