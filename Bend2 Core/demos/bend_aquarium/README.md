# Bend Aquarium

Bend Aquarium is a pure Bend2 Core rectangular reef-tank visualizer. Its Core
report contains twelve differently colored tropical fish, twelve coral models,
two bubble makers, a canister filter, heater, two return jets and a suspended
rectangular light.

The four requested coral families are modeled separately:

- *Euphyllia parancora* has branching hammer-shaped tips;
- *E. glabrescens* has long torch tentacles and fluorescent ends;
- *E. ancora* grows a continuous swaying hammer wall; and
- *Corallium rubrum* has rigid red branches with many pale polyps.

Acropora, brain, plate and anemone forms add four more motion profiles. Coral
motion, fish motion and bubble placement consume Core current, phase and wave
values; they are no longer driven by browser wall-clock sine loops. The browser
calls generated `aquarium_frame_at_func(tick, seed)` with a monotonically
increasing tick, so the simulation does not replay the 360-frame fixture.

Lighting now uses the hanging fixture as a bright point source, distinct
species palettes, fluorescent coral tissue, caustics and depth-scaled projected
shadows on the substrate. WebGL still supplies rasterization and camera orbit,
which are outside Core's pure runtime.

## Rendering overhaul

Every fish is now assembled from a shaped body hull, animated tail and fins,
eyes and procedural species markings; eel and manta forms have their own
topology. Corals grow as branching segment networks with polyps, hammer tips,
torch tentacles, plates or anemone crowns instead of colored cylinders. The
tank floor adds an organic substrate, kelp with leaf blades, shells, faceted
stones and a ruined arch. Equipment uses beveled housings, rings and visible
light/flow details, while transparent water, caustics, fog and swaying geometry
tie the scene together.

## Verification

Eight universal theorem families establish:

- one event and every arbitrary tank history preserve the complete live
  equipment identity/kind topology;
- structural induction over arbitrary histories carries the exact forcing law
  for every contained event; the finite one-event case splitter is only its
  local induction lemma and is not counted separately;
- every arbitrary frame count carries an erased dependent length proof;
- structural induction over every arbitrary `List<CoralModel>` proves the
  species-profile transformation emits exactly one motion law per coral, in
  order;
- arbitrary fluid impulse histories preserve particle identity, kind and
  volume;
- arbitrary wave histories preserve cell identity; and
- bubble, fish, filter and wind surface energies superpose in Bend Engine.

Five fixed aquarium checks are certificates. The model proves its discrete
laws; it does not claim Navier–Stokes fidelity or energy conservation in a
damped, filter-driven open system.

```sh
BEND2_CORE=/path/to/bend2-core ./build.sh
BEND2_CORE=/path/to/bend2-core bun test.mjs
```

No Bend checker/backend defect was found during this revision.
