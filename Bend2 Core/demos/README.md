# Bend3 demo port status

> **Toolchain note (2026-11).** The old bend2-core compiler is gone. This page
> merges the owner's latest Core assessment (bend2-core `c5d69a1`, below) with
> the port of these packages to the latest Bend (bendlang/bend source,
> `bend 2.0.40`):
>
> - [`poker/`](poker/) and [`belote/`](belote/) are ported, **including** the
>   owner's newer theorem towers and certificates (poker: 3 conservation
>   theorems + 3 deal lemmas + 78 certificates; belote: 3 conservation
>   theorems + 1 mapping lemma + 119 certificates). `bend X.bend --check-only`,
>   `bend X_proofs.bend --check-only` and `bend X_proofs_test.bend
>   --check-only` all print ALL PROOFS CHECK, with no `@unsafe` and no
>   `?TODO`; `./build.sh && bun test.mjs` passes in each package.
> - The other six observers and `Bend Engine/` are the owner's bend2-core
>   versions; their latest-Bend ports are tracked in their own READMEs.
> - The "blocking Core facilities" table is the bend2-core assessment. The
>   latest Bend has argv, a clock, files, TCP/UDP/HTTP, windows and audio, so
>   it no longer describes the current language; the interactive versions
>   live (and are ported) under `Bend3/demos/`.

No complete *interactive* Bend3 demo is currently reproduced as a direct Core
application. Core revision `c5d69a1` runs `IO<T>` mains and supplies print,
environment, files, TCP and UDP on the interpreter, JavaScript and C backends.
The remaining boundary is narrower but still material: there is no standard
clock, argv, HTTP/JSON, DOM, window, WebGL, audio or browser-event layer. The
original interactive packages remain in `Bend3/demos/`; the Core packages below
keep gameplay/simulation data in Bend and use JavaScript only for presentation
and input.

| Bend3 package | Blocking Core facilities |
|---|---|
| `Clock.bend` | no standard monotonic-clock operation |
| `bar_bench`, `elements` | Cocoa/window/input presentation and frame timing |
| `bar_bench_web`, `elements_web` | HTTP serving plus browser graphics/events |
| `tictactoe_web` | HTTP protocol/server loop plus browser events |
| `slither_web`, `agar_web` | clocked simulation, HTTP protocol and browser events |
| `minecraft_web`, `cubeworld2_web` | clocked simulation, HTTP protocol and WebGL input/presentation |
| `club_corvid_web` | clock, HTTP/JSON/Bytes conveniences, browser audio and events |
| `duck_hunt_web` | HTTP protocol plus browser graphics/audio/input |
| `bend_obfuscator_web` | HTTP protocol; transformation itself is browser JavaScript |
| `bendjogos_web` and `social.bend` | the server/browser facilities above plus password and LAN policy integration |

Eight pure simulation/viewer ports deliberately stay inside that boundary:

| Core package | What the Bend program computes | Browser responsibility |
|---|---|---|
| [`poker/`](poker/) | Four-AI Texas and Omaha timelines, cards, actions, stacks, best hands, per-player odds, 3 arbitrary-history chip-conservation theorems, 3 deal lemmas, and 78 closed table certificates | Select a variant, inspect the verification audit, and advance or autoplay the immutable report |
| [`belote/`](belote/) | A seeded four-AI deal, bidding, 32 rules-checked plays, tricks, points, contract result, 3 arbitrary-history card-conservation theorems, 1 mapping lemma, and 119 closed trace certificates | Inspect the verification audit and advance or autoplay the immutable report |
| [`bend_a_beet/`](bend_a_beet/) | A seeded 3 × 8 farm, five seconds of 20 FPS growth, high-poly geometry, Engine textures/fur/fuzz/reflection/four-source lighting/fog/soft shadows, a 16-stage physical uproot, and dense one-at-a-time responses backed by 7 semantic theorems, 13 support lemmas, and 35 closed certificates | Render true perspective WebGL, select display layers, orbit the camera, and navigate the immutable 1,086-frame report |
| [`bendio_3d_land/`](bendio_3d_land/) | A keyed 18-platform course with 17 physically constrained jumps, 612 non-looping frames, and 5 general theorem families | Ask the generated Core function for a level and select director, chase, side, first-person, or orbit POV |
| [`bendy_birds/`](bendy_birds/) | Six soft-body bird materials, seven destructible block materials, persistent damage, exact user-selected angle/power recomputation, 10 general theorem families, and 4 certificates | Pass bird, angle, power, and current state to the generated pure Core function and render its new 97-frame result |
| [`bend_fishing/`](bend_fishing/) | One or two occult fish drawn from a weighted ten-species pool, live cast/reel transitions, 120 waiting frames, 48 reel frames, 8 general theorem families, and 5 certificates | Convert cast and reel clicks into arguments to generated pure Core functions, then render the returned state and animation |
| [`bend_aquarium/`](bend_aquarium/) | Twelve independently colored reef fish, twelve moving coral colonies across eight forms, an unbounded Core frame function, fluid/light coupling, 8 general theorem families, and 5 certificates | Orbit, zoom, pause, and request later states from the generated pure Core function |
| [`bend_landscape/`](bend_landscape/) | An indefinitely scrolling keyed Sea/Land/Sky world with whales, rocks, fish and schools, trees, humans, birds, clouds and weather; 12 structural/arithmetic proof families and 6 certificates | Retain Core's boundary state, request successive chunks, and render the bounded rolling window in high-detail WebGL |

All eight simulation kernels are affine Core programs with no hidden host-side
game logic. Their executable entrypoints use IO only to satisfy the current
compiler contract; browser builds export the pure report/query functions.
BendJogos serves and draws those generated values on its `/core` pages.

Poker's main theorem tower models point-valued chip identities and proves that
one arbitrary ownership transfer preserves the full payload, then lifts that
fact to every finite betting/payout history. Chip-count and total-value
conservation are corollaries. It also proves two list-length properties over arbitrary
deal-index lists, plus equal per-seat card counts after any number of complete
rounds by induction on the round count. Its finite witnesses and table
certificates show selected runout/strategy changes, seat coverage,
normalization, and fold/showdown consistency only for the authored model; they
are not general poker fairness or probability theorems.

Belote uses the same semantic shape for cards: arbitrary dealing, play, and
trick-collection histories preserve every card identity and printed point
value, hence card count and point mass. Its finite certificate domains cover every deck position, seat, trick,
and play in its embedded hand. The checked claims establish a disjoint in-range
deal, card ownership, full follow/cut/trump/overtrump legality, exact winners
and points, and the 36-snapshot report shape. They certify this deterministic
hand, not every possible Belote deal or strategy. A separate structural
theorem proves snapshot mapping preserves the length of every finite
input-index list.

Bend-a-Beet splits its implementation into independent physics, 3D graphics,
and ray-tracing libraries. Their erased audits retain one supporting theorem
and closed certificates each. Two larger proof modules establish that arbitrary
motion histories preserve beet identity/root and make fracture absorbing, and
that every declared positive surface/light pair in an arbitrary finite scene
gets exactly one positive-reflection response plus a shadow evaluation. The
required positivity hypotheses and the clear-or-occluded result are explicit;
the theorem does not falsely claim that every object is visibly shadowed. A
third adapter theorem tower proves exact alignment and cardinality for arbitrary
lists of Bend Engine profiles and consumes the imported model/light theorem
suites. Core derives each beet's shine, surface response, mesh quality,
procedural texture, fogged four-light color, reflection, fuzz, fur controls,
soft-shadow parameters and world-space shadow anchor. The browser playback,
display-layer, and orbit-camera
controls are not Core inputs; they only select and reproject precomputed frames
through a depth-tested WebGL renderer. Core's new general IO loop does not make
those DOM/WebGL/clock controls part of the proved computation.

## Reusable Bend Engine

[`Bend Engine/`](Bend%20Engine/) is not an observer page. It is a pure reusable
library package with focused generated-backend entries:

- Model3D, lighting and ray tracing provide a 104-vertex/192-triangle beet
  mesh, UVs/normals, four procedural texture kinds, reflection/fuzz/104 fur
  strands, four light kinds, explicit shadow queries, fog and sphere/plane/
  triangle tracing.
- Physics provides Q10 force and torque accumulation, damped semi-implicit
  integration, contacts, six joint kinds, recursive articulation, pinned
  bodies and iterative ragdolls.
- AI provides perception, memory, goals/utility, legal-by-construction
  decisions, deterministic planning, NPC squads, world turns and histories.
- Fluids provides Q10 particles and wave cells, buoyancy/drag samples, water
  optics, and bubble/fish/filter/wind surface forcing. Its 8 universal theorem
  families cover arbitrary particle and wave histories, exact list alignment,
  dry buoyancy, and forcing superposition.

The rendering audit has 4 semantic headline claims, 3 structural Claim helpers,
14 reusable universal theorems and 5 certificates. Physics has 12 universal
theorems/claims and 3 certificates. AI has 8 semantic claim families, 5 helpers
and 3 certificates. Fluids has 8 universal theorem families. The four focused entries pass generated JavaScript and
native C at `c5d69a1` with mandatory structural termination.

The remaining Bend3 packages would require new observer designs or additional
clock, protocol and presentation integrations. They are deliberately not
presented as working ports merely because Core now has general IO.

## Generated poker/belote assets (latest Bend)

`build.sh` in each package runs `bend X.bend -o X.mjs` and wraps that ES
module into the classic browser script `X_data.js`, publishing the evaluated
`main_value()` as `BEND2_POKER_DATA` / `BEND2_BELOTE_DATA` (plus `*_META`).
Values use Bend's `{$: "Name", field: value}` export encoding (the bend2-core
artifacts used positional `$0, $1, ...`), and erased proof fields are absent,
so each report's `verification` audit reaches the page as its text and
counts only. BendJogos (`Bend3/demos/bendjogos_web/sync_core.mjs`) copies
these files unchanged.

| Generated asset | SHA-256 (latest Bend) |
|---|---|
| `poker/poker_data.js` | `269c6ad683c915685cc4007789a08290fbdd60d900f80ca2a581758e7dcd1bd7` |
| `belote/belote_data.js` | `9ab8665bb00774991f383a0a4d24247a920b07bb1bad5c67229984e7333253ed` |

The poker build takes a few seconds; the belote build about two minutes,
because checking its 119 closed certificates normalizes the whole hand.
Rebuild and verify from each package directory with
`./build.sh && bun test.mjs`.
