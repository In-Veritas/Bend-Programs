# Bendy Birds

Bendy Birds is a pure Bend2 Core 3D soft-body projectile game. Six birds model
jello, rubber, fur, stone, bubble and spring behavior. Seven target materials
model glass, ice, wood, brick, metal, jelly and bamboo.

Every browser launch calls the generated Core function
`bendy_browser_shot_func` with the exact integer angle, strength, bird and
current immutable block list. Core computes a 97-frame parabolic trajectory,
terminal impact coordinate, localized 260-unit collision window, material
damage, score and next persistent block state. JavaScript only captures the
controls and rasterizes the returned values. It no longer selects the closest
member of six precomputed previews.

The trajectory stops at its terminal frame. Higher angles increase the arc and
alter horizontal speed; strength increases horizontal speed and material
damage. Only blocks near the calculated impact receive damage, and later shots
consume the prior Core result so destroyed blocks stay destroyed.

The command-line `recalculate.mjs` bridge remains available for inspecting and
serializing a shot outside the browser, but is no longer required for play.

## Rendering overhaul

Birds now use deformable body hulls, paired wing meshes, beaks, eyes, tails and
material-specific details instead of ellipsoids. Targets combine beveled
timbers and masonry, bamboo bundles, gelatinous capsules and rings, glass/ice
crystals, braces and fasteners. Impact debris is a deterministic field of
faceted shards which remains visible with the persistent Core damage state;
flight trails use torus and star geometry. Soft, pulse and twist deformation
make the six bird materials move differently without changing Core collision
semantics.

## Verification

Ten universal theorem families establish:

- arbitrary flight histories preserve bird identity, material and mass;
- individual, arbitrary-list and localized conditional damage preserve every
  block identity/material in exact order;
- broken structures are absorbing under every later impact;
- collision momentum, retained motion and deformation use equality-carrying
  replicated physical factors;
- arbitrary trajectory lengths are constructed with erased dependent proofs;
- for every U32 angle, the arc begins and ends at exactly ground height 120;
  and
- for every angle and strength, terminal x is exactly
  `120 + 96 × horizontal_speed(angle, strength)`.

Four closed showcase checks are separately counted as certificates. This is a
deterministic stylized fixed-point model, not a claim of SI-unit continuum
accuracy.

```sh
BEND2_CORE=/path/to/bend2-core ./build.sh
BEND2_CORE=/path/to/bend2-core bun test.mjs
```

The Core migration exposed a backend defect in an erased recursive proof
continuation. The minimized reproducer and the semantics-preserving named
helper workaround are recorded in
[`unexpected_behavior/`](unexpected_behavior/README.md).
