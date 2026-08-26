# Bend Heroes

Bend Heroes is a deterministic Castle-versus-Necropolis strategy scenario
written as a pure Bend2 Core state machine and rendered in WebGL2 with the
repository's Bend Engine. It uses the browser feedback protocol requested for
interactive Core programs:

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
adventure map, animated procedural terrain and sites, separate Castle and
Necropolis town views, a tactical battle scene, creature representations,
clickable adjacent-tile beacons, and attack/spell feedback. All geometry,
materials, lighting, fog, camera work, and animation are presentation-only;
none of them can advance or alter the game.

The build copies the shared renderer verbatim into this self-contained web
package. No original Heroes III artwork, models, sounds, or other proprietary
assets are included.

## Playable rules

The included scenario is a two-player hot-seat game on a 9 × 7 map. It
implements these interlocking systems from `heroes_properties.md`:

- sequential Red and Blue turns, day/week/month time, daily income, movement
  and mana refresh, and weekly creature growth;
- eight-direction movement with 141% diagonal cost, plus Grass, Dirt, Rough,
  Swamp, Water, and Rock terrain and their configured movement costs;
- persistent one-shot gold, wood, shrine, and artifact sites, plus capturable
  Sawmill and Gold Mine ownership and daily income;
- Castle and Necropolis towns with hall and fort lines, one construction per
  town per day, prerequisite-ordered tier 1–7 dwellings, accumulated stock,
  recruitment, seven resources, and seven army slots;
- all seven base Castle creatures and all seven base Necropolis creatures with
  canonical attack, defense, damage, health, speed, growth, cost, and shooter
  flags;
- two persistent heroes with primary statistics, mana, movement, canonical
  experience thresholds through level 10, deterministic level gains, armies,
  and map position;
- seeded per-creature damage rolls, attack/defense scaling and caps, exact
  first-creature health across casualties, no invented ranged modifier,
  20%-defense Defend, Magic Arrow, Retreat, rewards, and healed surviving
  stacks after victory;
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
| 22 | Magic Arrow | own response slot 0–6 | enemy target slot 0–6 |
| 23 | Retreat | ignored | ignored |

Unknown or phase-inappropriate commands return an explanatory notice while
preserving the relevant game values.

## Fidelity boundary

The mechanics above are implemented in Core rather than approximated by the
viewer, but this package is not yet a byte-for-byte implementation of the
entire Heroes of Might and Magic III: Shadow of Death product. Full parity
would also require:

- seven more factions, upgrades, neutral creatures, the complete hero,
  artifact, spell, skill, building, and adventure-object catalogues;
- a positional 15 × 11 hex battlefield with speed queue, Wait, obstacles,
  retaliation state, shots, double-wide creatures, statuses, morale, luck,
  war machines, and siege machinery;
- multiple heroes and towns per player, meetings and exchanges, garrisons,
  taverns, fog of war, boats, quests, Grail, AI, campaigns, map loading, and
  multiplayer transport; and
- the original game's complete data and edge-case compatibility suite.

Current battle commands therefore resolve a selected stack exchange plus one
deterministic enemy response instead of replaying the original positional
battle loop. This limitation is ordinary application scope, not a Bend issue,
so the package intentionally has no `unexpected_behavior/` directory.

## Ranged-duel proof boundary

`heroes_ranged_law.bend` proves, by structural induction rather than closed
case enumeration, that a ranged stack always survives and defeats an immobile
melee stack at a separation of at least two tiles when every volley deals at
least two damage. The theorem is universal over additional distance,
additional damage, both stack values, and every finite structural defender
health. Equality witnesses read the real `CreatureStats.ranged` flag, so an
arbitrary stack cannot be admitted under the wrong role.

The positional and immobility premises live in the separate proof adapter
because `heroes.bend` has no combat-grid position or combat-movement state.
Consequently this is a proved law for that explicit adapter, not a false claim
that the current `combat_attack_func` already implements positional combat.
The same module proves the concrete audit result that
`ranged_percent_func(True{}, p)` and `ranged_percent_func(False{}, p)` are both
definitionally equal to `p` for every `U32` percentage. A refinement theorem
from the adapter to the runtime therefore remains impossible until the
documented positional-combat scope is implemented.

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
validates all 63 map cells, cardinal and diagonal movement, first-creature
health, persistent pickups, construction, recruitment, turn/day income, a
complete guardian battle, progression, artifact pickup, town-capture victory,
equal-seed determinism, renderer boundaries, generated JavaScript execution,
C emission, clang build, native execution, and the universally quantified
ranged-duel proof module. The Bend books are structurally terminating.

Serve this directory with any static HTTP server and open `index.html`; no
application server or package installation is required after generation.

## Files

- `heroes.bend` — authoritative pure game state and transitions;
- `heroes_ranged_law.bend` — universal external ranged-duel law and concrete
  runtime ranged-flag audit;
- `heroes_ranged_law_test.bend` — higher-order proof consumer exercised by the
  interpreter and generated backends;
- `build.mjs` / `build.sh` — reproducible browser artifact generation;
- `heroes_data.js` — checked-in generated Bend2 Core JavaScript;
- `bend_engine_webgl.js` — synchronized shared Bend Engine renderer;
- `heroes_viewer.js` — input, state feedback, Core-value projection, save/load,
  and undo;
- `index.html` — graphical web application shell;
- `test.mjs` — gameplay and JS/C backend validation; and
- `heroes_properties.md` — supplied full-game replication reference.
