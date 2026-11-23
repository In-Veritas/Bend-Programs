# Bend2 Core ports

Ports of Gabriel's Bend3 programs, and the owner's observer demos, that were
first written for the experimental `bend2-core` affine dependent core (last
checked by the owner against `bend2-core` commit
`c5d69a14608b93896b5046e310d501903235d6c8` on 2026-08-26). That compiler is
gone; its descendant is the latest Bend (bendlang/bend source, `bend 2.0.40`),
and `programs/`, `demos/poker/` and `demos/belote/` are ported to it,
including all of the owner's later improvements. See [GUIDE.md](GUIDE.md) for
the Core-to-Bend differences, the porting rules and the mathematical
proof-writing workflow.

## Layout

- `programs/` contains fourteen ports of Gabriel's Bend3 programs plus the
  CHIP-8 emulator in `programs/chip8/`. Each computational program's
  `main_value` is a compact `Bool` self-check and its `IO(Unit)` `main` prints
  `True{}` when the expected result was reproduced. `gabs1` prints its original
  line; `gabs4` (argv + files) runs too: the owner's Core still listed it as
  unsupported for lack of argv, see `programs/UNSUPPORTED.md`.
- `demos/README.md` records the port decision for every Bend3 demo package and
  the status of the eight Core observer demos.
- `unexpected_behavior/` keeps the Core-era U32 constant C-emission report,
  retested on the latest Bend (no longer reproduces).

## Run

With the `bend` CLI on `PATH`:

```sh
cd "Bend2 Core/programs"
bend insertion_sort.bend --check-only          # ALL PROOFS CHECK
bend insertion_sort.bend                       # True{}
bend insertion_sort.bend -o /tmp/insertion_sort && /tmp/insertion_sort
bend insertion_sort.bend -o /tmp/insertion_sort.js && bun /tmp/insertion_sort.js
bend gabs4.bend fixtures/reference.txt fixtures/other.txt
```

Every program checks with `ALL PROOFS CHECK` and uses neither the old
`#[halts]` license nor `@unsafe`. All entries print the same output through
`bend FILE`, a native build and the JS build: `True{}` for the computational
programs, `-` for `nat_proofs.bend` (it checks four induction laws and passes
the erased `add_n_z` instance to its IO wrapper), and the original text for
`gabs1`/`gabs4`. `tournament.bend` runs in about two seconds (Core's
normalizer did not finish it in 18 minutes).

The CHIP-8 emulator's `main` is an IO shell: with no argument it prints its
`main_value()` self-check of the bundled smoke ROM from `rom.bend` (`True{}`),
the owner's behaviour; given a `.ch8` file it runs it and prints the
framebuffer. See its [README](programs/chip8/README.md).

## Demos

The Poker observer in `demos/poker/` exercises the dependent proof surface
with a multi-lemma theorem that arbitrary finite betting/payout histories
preserve every discrete chip identity and value; chip-count and total-value
conservation are corollaries. Three supporting deal lemmas cover arbitrary
index lists and round counts. Its outcome, seat, and odds checks remain
separately identified as 78 finite certificates for the published model, not
general poker theorems. The generated viewer exposes that distinction; the JS
export drops the erased theorem and certificate payloads.

The Belote observer in `demos/belote/` proves that arbitrary finite card-zone
histories preserve every card identity and printed point value; card-count and
point-mass conservation are corollaries. A supporting list-length lemma covers
arbitrary play-index lists. Its 119 finite certificates cover every deck
position, seat, trick, and play in the embedded hand: deal integrity, card
ownership, complete play legality, exact winners, points, and report shape.

Both are ported to the latest Bend: every Core `assert` theorem is a `law`
with the same statement, the old affine copy/replica lemmas became `+`
binders, and `bend X.bend --check-only`, `bend X_proofs.bend --check-only`,
`./build.sh` and `bun test.mjs` pass in each package.

The owner also added, for bend2-core `c5d69a1`, `demos/bend_a_beet/` (a 3D
seeded farm simulation with physics, graphics and ray-tracing libraries, seven
semantic theorems, thirteen support lemmas and 35 certificates),
`demos/Bend Engine/` (a reusable pure library for models, lighting/ray
tracing, rigid-body/ragdoll physics, NPC AI and fluids, with four focused
audits), and five Engine-backed simulations (Bendio 3D Land, Bendy Birds, Bend
Fishing, Bend Aquarium, Bend Landscape; 43 general theorem families and 24
closed certificates in total). Those packages are ported separately; their own
READMEs record their latest-Bend status. The Bendy Birds
`unexpected_behavior/` MRE was retested in current syntax and no longer
reproduces.
