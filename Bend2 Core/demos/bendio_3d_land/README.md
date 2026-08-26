# Bendio 3D Land

Bendio 3D Land is a pure Bend2 Core procedural 3D platformer driven by an NPC.
The browser sends the chosen 32-bit key to the generated Core function
`bendio_report_seed_func`; Core then constructs 18 platforms and a complete
17-jump traversal. Each jump contains 36 frames, so a level has 612 distinct
frames and stops at its final landing instead of wrapping into a short loop.

Platform gaps are 610–779 Core units. Altitude, lateral offset, dimensions and
one of six materials are derived from the evolving key. Every jump interpolates
between the actual generated anchors and adds the nonnegative discrete parabola
`t × (35 − t)`. Explicit endpoint branches avoid division truncation at the
takeoff and landing. The browser selects director, chase, side, first-person or
orbit POV; it does not invent terrain or movement.

## Rendering overhaul

Platforms are now sculpted floating-island meshes with irregular rock skirts,
not stacks of boxes. Material biomes add procedural branching trees and roots,
ruined arches and vine ropes, lava crystals and emissive shards, cloud-glass
structures, faceted mineral clusters, torus coins and star goals. The player is
an articulated multi-part character whose limbs, clothes and accessories move
with the Core trajectory. Mesh detail, wind/twist motion, fresnel highlights,
fog and transparent materials all come from the shared Bend Engine WebGL layer.

## Proofs

The verification bundle contains five universal theorem families:

- `VerifiedPlatforms<count>` is built by structural induction and carries the
  generated platform list plus an erased proof that its length is exactly any
  arbitrary requested `count`;
- `VerifiedSegments<count>` does the same for arbitrary generated courses;
- `VerifiedFrames<count>` does the same for arbitrary jump durations and
  arbitrary six-coordinate geometry;
- the endpoint theorem proves, for every `JumpGeometry`, that frame zero is the
  exact source and frame 35 is the exact target; and
- the seed transition theorem proves the exact deterministic transition used by
  every procedural step.

Four closed checks certify the published fixture. They are regression
certificates, not substitutes for the quantified results above. Generated JS
and C erase all proof fields.

## Core limitations encountered

An initial key mixer used the usual decimal constants `1664525` and
`1013904223` through `U32.from_nat`. Core represents `Nat` structurally, so
checking those literals expanded into millions of constructors and was not a
practical browser build. The generator therefore uses the small U32 mixer
`seed × 73 + 41`. This is a performance limitation of the representation, not
a checker bug.

A post-hoc theorem attempting to unfold the entire platform constructor through
its unused material branch also became impractical for arbitrary symbolic U32
keys. The accepted design constructs values and erased cardinality witnesses
together. The exact numeric interval facts are additionally checked on the
published fixture; Core's current Base does not provide the general modular
arithmetic order lemmas needed to promote every `mod` interval to a compact
symbolic theorem without developing a much larger arithmetic library.

```sh
BEND2_CORE=/path/to/bend2-core ./build.sh
BEND2_CORE=/path/to/bend2-core bun test.mjs
```

The package targets Core revision `c5d69a1`; its simulation remains pure and
structurally terminating. The executable wrapper uses only standard output.
