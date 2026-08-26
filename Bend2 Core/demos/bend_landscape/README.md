# Bend Landscape

Bend Landscape is a pure, keyed Bend2 Core world generator and a WebGL
side-scrolling visualizer. It does not replay a fixed report: the browser keeps
the `Boundary` returned by Core and passes it to
`landscape_next_chunk_func(key, index, boundary)` whenever it needs more world.
The Core calculation can therefore extend to any finite requested distance.

Each 900-unit chunk contains three intentionally separated sectors:

- the sea has two physically bounded whales, three sea rocks, five individual
  fish chosen from twelve species, two four-to-twelve-member schools whose
  individual members are Core values, a smooth water level and one through
  five layers of sand;
- the land has five trees drawn from eight growth forms, three hills and a
  one-, two- or three-person party with skin, body, clothing, personality and
  contextual behavior constructors; and
- the sky has rain-dependent birds drawn from eight species plus three clouds.
  Clouds form, charge, become rain-ready, rain, shrink and dissipate. Wind,
  tide, sunlight and rain are part of the boundary handed to the next chunk.

The viewer expands the Core descriptions into high-detail WebGL geometry,
shadows, fog, transparent moving water, rain, whale spray, fruit, tools,
species-specific fish palettes and optional synthesized bird calls. Sea floors
and islands use custom terrain meshes; whales have shaped bodies, fins and
tails; fish, branching trees, articulated people and tools, wild birds and
layered clouds are reusable animated assemblies. Rocks, shells, vegetation,
rain segments and foam rings make each sector read as a place rather than a row
of primitives. Camera, rasterization, DOM events and Web Audio remain
presentation boundaries. The choices of bird call, entity state and scene
parameters come from Core; the oscillator and individual members used to
depict a Core school are browser projections.

## Mathematical verification

`LandscapeVerification` stores twelve reusable erased theorem fields. The
finite state-machine cases are not presented as the final mathematical proof.
They construct typed one-step transitions; structural induction then lifts
those laws over an arbitrary horizon:

1. `tide_history_claim_func(fuel, phase)` proves for arbitrary `fuel` and
   starting phase that the result has exactly `fuel` transitions. Every
   transition carries equations tying it to the real next-phase and height
   functions plus a constructive `distance + slack = 12` witness;
2. the corresponding arbitrary terrain-history induction carries the exact
   next terrain/height equations and `distance + slack = 36` witnesses;
3. the arbitrary cloud-history induction carries the exact next phase and the
   rain and sunlight computed from that phase at every recursive step;
4. every live sand-layer value carries erased witnesses `layers = 1 + extra`
   and `extra + slack = 4`, which mathematically places it in 1–5 without a
   post-hoc enumeration proof;
5. whale emergence carries `percent = 10 + extra` and
   `extra + slack = 20`, proving both the 10% lower bound and 30% upper bound;
6. whale spout volume carries `volume + slack = 110`;
7. school size carries `members = 4 + extra` and `extra + slack = 8`;
8. a human party carries a list-length equality, `count = 1 + extra`, and
   `extra + slack = 2`;
9. structural induction generates an arbitrary requested number of actual
   `SchoolMember` values together with an exact dependent list-length proof;
10. a second structural induction transforms every member of an arbitrary
    school under an arbitrary current/flee/dive impulse while congruence proves
    preservation of the complete ordered member-identity payload;
11. induction over arbitrary `SchoolHistory` composes the step theorem with
    equality transitivity, preserving that payload for every finite behavior
    history; and
12. structural induction over arbitrary `fuel`, key, index and boundary proves
    `landscape_verified_chunks_func` returns a list whose length is exactly
    `fuel`.

The proofs for items 4–8 are projections of evidence carried by the generated
values, rather than a `match` that lists every accepted number and returns
reflexivity. In other words, an invalid value is unconstructible without also
forging an erased arithmetic equality that the checker rejects.

Six closed self-checks are called certificates, not mathematical proofs. The
JavaScript test additionally audits long generated traces, boundary continuity,
spacing metadata and the exact 6/4/4/1/1 grey/slate/blue/white/black whale-color
histogram over a complete 16-key residue class. Interpreting that histogram as
a probability distribution requires uniformly distributed low four input-key
bits; the theorem does not manufacture that premise.

The physical statements are deliberately discrete model laws. They establish
bounds and transition coherence for this generator, not biological accuracy,
continuum fluid mechanics or a proof that every aesthetically plausible scene
exists.

## Approaches that did not work

These are Core constraints or unfinished proof engineering, not Bend bugs:

- A single quantified equality between an arbitrary compound `Boundary` and
  the copied boundary embedded in its generated chunk did not reduce directly.
  Because Core is affine, such a theorem needs equality-carrying copy lemmas for
  each of the six enum components followed by a six-field congruence tower.
  The runtime still constructs both values from the same exhaustive structural
  copies, and the browser audit checks continuity over generated traces, but the
  current erased proof suite does not claim this compound theorem.
- Writing the decimal natural literal `7319n` inside this already large book
  exhausted the JavaScript checker's recursive conversion stack. The default
  fixture uses `731n`; arbitrary browser keys are `U32` runtime inputs. This is
  the same practical cost of structurally encoded `Nat` constants described in
  the Core guide, not evidence of a semantic checker defect.
- A proof of physical whale buoyancy would require mass, displaced volume and
  density premises that this aesthetic generator does not model. The proven
  claim is the generator's conservative 10–30% emergence bound.

No Bend parser, checker, compiler or backend defect was found while building
this package, so it intentionally has no `unexpected_behavior/` directory.

```sh
BEND2_CORE=/path/to/bend2-core ./build.sh
BEND2_CORE=/path/to/bend2-core bun test.mjs
```
