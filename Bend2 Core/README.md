# Bend2 Core ports

Ports of Gabriel's Bend3 programs to the experimental `bend2-core` affine
dependent core. They were migrated and checked against `bend2-core` commit
`c5d69a14608b93896b5046e310d501903235d6c8` on 2026-08-26. See
[GUIDE.md](GUIDE.md) for Core's main characteristics, the
Bend3 differences, porting rules, and the detailed mathematical proof-writing
workflow.

## Layout

- `programs/` contains thirteen runnable Gabriel ports plus the pure CHIP-8
  emulator in `programs/chip8/`. Computational `main_value` functions remain
  compact self-checks; their `IO<Unit>` mains print `True{}` when the expected
  result was reproduced. `gabs1` exercises the new standard IO runtime.
- `programs/UNSUPPORTED.md` records `gabs4`, whose command-line argument input
  still has no Core API.
- `demos/README.md` records the port decision for every Bend3 demo package.

## Run

From the sibling `bend2-core` checkout:

```sh
bun bend2/comp.ts "../Bend-Programs/Bend2 Core/programs/insertion_sort.bend"
bun bend2/comp.ts "../Bend-Programs/Bend2 Core/programs/insertion_sort.bend" --to /tmp/insertion_sort.js
bun /tmp/insertion_sort.js
```

For `tournament.bend`, always use `--to`: direct normalization expands the
structural implementations of U32 arithmetic and copying and was still using
CPU after 18 minutes, while generated JS and C both finish immediately with
`True{}`.

All runnable entries check during emission and execute through generated
JavaScript and C. Computational entries print `True{}` through both backends;
`nat_proofs.bend` checks its erased equality witness and deliberately prints
`-` from its IO wrapper. `gabs1.bend` prints its original text.

The CHIP-8 emulator interprets a hexadecimal ROM string imported from its own
`rom.bend`, and its Core-generated C compiles to a native executable. See its
[README](programs/chip8/README.md) for the temporary embedded-ROM bridge. Core
now has standard IO and file operations, but not an argument API or interactive
key source, so the bridge remains the deterministic test boundary.

The Poker observer in `demos/poker/` exercises Core's dependent proof surface
with a multi-lemma theorem that arbitrary finite betting/payout histories
preserve every discrete chip identity and value; chip-count and total-value
conservation are corollaries. Three supporting deal lemmas cover arbitrary
index lists and round counts. Its outcome, seat, and odds checks remain
separately identified as
78 finite certificates for the published model, not general poker theorems.
The generated viewer exposes that distinction while the JS backend erases
theorem and certificate payloads.

The Belote observer in `demos/belote/` proves that arbitrary finite card-zone
histories preserve every card identity and printed point value; card-count and
point-mass conservation are corollaries. A supporting list-length lemma covers
arbitrary play-index lists. Its 119 finite
certificates cover every deck position, seat, trick, and play in the embedded
hand: deal integrity, card ownership, complete play legality, exact winners,
points, and report shape.

`demos/bend_a_beet/` is a 3D seeded farm simulation built from separate
physics, graphics, and ray-tracing Core libraries. Its generated 1,086-frame
report covers five seconds of growth, simultaneous uprooting, and individual
break, spring, or recovery responses. It also consumes Bend Engine material and
light APIs for four procedural texture classes, ambient/directional/point/spot
lighting, fog, reflection, fuzz, fur and soft shadows. It carries seven semantic
Core theorems, thirteen supporting original/Engine library lemmas, and 35
closed certificates; see its README for their exact scope and the browser
boundary.

`demos/Bend Engine/` is the reusable pure library package for high-detail
models, lighting/ray tracing, rigid-body/ragdoll physics, deterministic NPC
AI, and particle/wave fluids with water optics. Its four focused audits prove semantic properties over arbitrary object/
light lists, meshes, articulation trees, physics histories, worlds, plans and
AI histories, particle fields, and wave histories. Closed rendering, physics and AI examples remain explicitly
separate certificates. The combined harness validates generated JavaScript and
native C at the pinned Core revision.

Five additional Engine-backed simulations live under `demos/`: Bendio 3D Land
is a keyed, procedurally generated autonomous platformer with selectable camera
POVs; Bendy Birds is a soft-body/destruction game whose generated Core function
uses the selected bird, angle, power, and prior state; Bend Fishing accepts cast
and reel coordinates through pure Core calls and keeps only one or two occult
fish active; Bend Aquarium couples varied fish and moving coral with bubbles,
filter flow, water optics, and a hanging light; and Bend Landscape generates an
unbounded keyed Sea/Land/Sky world from explicit boundary state. Their focused
audits total 43 general theorem families and 24 closed certificates. Numeric
bounds use proof-carrying arithmetic witnesses, while transition properties are
lifted over arbitrary histories by structural induction; finite constructor
splitters are not counted as headline proofs.
