# Bend Fishing

Bend Fishing is a pure Bend2 Core 3D lagoon game inspired by life-simulation
fishing. The browser converts a water click into integer coordinates and calls
generated `fishing_session_func`. Core chooses exactly one or two fish, their
models, a bite window and 120 water/float frames. A second click passes the
current Core frame to `fishing_reel_func`; Core returns caught/escaped semantics,
a 48-frame line/fish/splash animation and the replacement session seed.

Uncaught fish are rendered only as dark, refracted 3D silhouettes. Their
species palette and geometry are revealed only after `Caught`. JavaScript does
not choose the timing branch or species, and the screen animation does not loop.

## Rendering overhaul

The lagoon now has an irregular shore, layered rocks, individual dock planks
and nail heads, a branching rod, a segmented live line, a woven basket, reeds,
lily pads, flowers and shells. Fish use species-sensitive body, fin, tail,
eye and marking assemblies; eel, manta, shark, puffer and seahorse silhouettes
are structurally distinct. Casts and strikes add mesh ripples, spray and splash
rings driven by the immutable Core frames rather than browser-chosen outcomes.

## Distribution

The species pool is a typed 16-slot value. Its weights are:

- River Bass 3/16;
- Golden Koi, Blue Tuna, Ribbon Eel and Puffer Fish 2/16 each; and
- Moon Jelly, Reef Shark, Coelacanth, Manta Ray and Seahorse 1/16 each.

The fixture exhaustively certifies all 16 selector buckets. Interpreting these
ratios as probabilities requires the explicit assumption that the lower four
bits of supplied keys are uniformly distributed; a deterministic seed function
alone cannot prove an empirical randomness assumption.

## Verification

Eight universal theorem families prove:

- one swim event and every arbitrary swim history preserve identity, species
  and size;
- a proof-carrying arbitrary school step preserves every fish in exact order;
- arbitrary ordinary, bite-cued and reel frame generators carry erased exact
  length proofs;
- Bend Engine fluid histories conserve particle payload while water forcing
  superposes bubble, fish, filter and wind contributions.

`BiteTiming` and `ActiveFish` remain finite, intrinsically constrained program
types, but their constructor-by-constructor reflexivity helpers are deliberately
not counted as mathematical proofs. The one/two pool restriction is enforced
by representability and independently audited by the generated trace tests.

Five closed checks—including the complete 16-slot histogram—are certificates,
not universal proofs. Water optics use the authored 0..255 fixed-point channels
documented by Bend Engine.

```sh
BEND2_CORE=/path/to/bend2-core ./build.sh
BEND2_CORE=/path/to/bend2-core bun test.mjs
```

No Bend checker/backend defect was found during this revision.
