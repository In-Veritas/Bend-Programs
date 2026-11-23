# Bend Engine

Bend Engine is a reusable, pure Bend2 Core package for model generation,
lighting and ray queries, rigid-body/ragdoll physics, deterministic game AI,
and particle/wave fluids with water optics. It distills the reusable lessons from Bend-a-Beet, which now consumes the
model/light APIs through its checked `engine_features.bend` adapter. There is no
IO, window, or browser layer here: games import the data and functions and
choose their own host presentation.

The package targets `bend2-core` commit `c5d69a1`, is strict-affine, and uses
structural recursion.

## Modules

| File | Purpose |
| --- | --- |
| `model3d.bend` | Signed Q24.8 vectors, indexed vertices and triangle facets, UVs and normals, procedural solid/checker/facet/noise textures, optical material channels, and explicit fur strands. The supplied beet mesh contains 104 vertices, 192 triangle facets, and 104 vertex-anchored strands. |
| `light.bend` | Ambient, directional, point, and spot lights; range and cone falloff; shadow controls and ray-query boundaries; diffuse/specular/reflection/fuzz channels; light rigs; and linear or exponential fog. |
| `raytrace.bend` | Pure nearest-hit tracing for spheres, horizontal planes, and indexed-mesh triangles, including fixed-point Möller-Trumbore intersection and conversion of hits into `Light.Visibility`. |
| `physics.bend` | Signed Q10 rigid bodies, force and torque accumulation, damped semi-implicit integration, static sphere/plane response, ball/hinge/fixed/cone-twist joint projection, recursive articulations, pinned bodies, and iterative ragdoll histories. |
| `ai.bend` | Perception and memory, goals and inspectable utility scores, legality-carrying decisions, finite plans, deterministic squad/NPC updates, arbitrary plan execution, and replayable world histories. |
| `fluids.bend` | Q10 fluid particles, arbitrary impulse histories, damped wave cells, buoyancy/drag samples, bubble/fish/filter/wind surface forcing, and water refraction/Fresnel/absorption/caustic material controls. |
| `bend_engine_webgl.js` | Shared WebGL2 presentation boundary with validated arbitrary indexed meshes, lazy GPU mesh registration, 29 built-in complex meshes, animated multi-part creatures/scenery, procedural PBR-style materials, correct normal transforms, transparency sorting, water/glass, caustics, fog, and selectable cameras. |
| `*_verification.bend` | Universally quantified semantic claims and their helper-lemma towers. |
| `*_test.bend` | Generated-backend entries. Closed examples here are regression certificates, not mathematical proofs. |
| `test.mjs`, `build.sh` | Revision-pinned JavaScript and native-C validation. |

Typical imports are file-relative and merge into the Core declaration book:

```bend
import ./model3d.bend as Model3D
import ./light.bend as Light
import ./raytrace.bend as Raytrace
import ./physics.bend as Physics
import ./ai.bend as AI
import ./fluids.bend as Fluids
```

## WebGL geometry boundary

The browser layer is no longer limited to scaled spheres, boxes, cones and
cylinders. `makeMesh` validates arbitrary indexed position/normal/UV data,
recomputes missing normals, and `registerMesh` adds named geometry lazily to a
renderer. A scene object may also carry a mesh directly. Built-ins include
beveled solids, rocks, islands, arches, capsules, tori, crystals, branches,
ropes, leaves, wings, fins, fish/bird/whale bodies, manta rays and stars.

Reusable assemblies build animated characters, birds, fish, whales, branching
trees and corals, clouds and oriented segments from those meshes. Vertex motion
supports waves, wind, soft-body deformation, pulsing and twisting; the shader
adds hemisphere and multi-light response, specular/fresnel reflection,
subsurface and emissive controls, procedural surfaces, rim light, fog and
caustics. These facilities are presentation code: Core still owns the scene and
simulation values supplied to them.

## What is actually proved

The audit deliberately separates mathematical theorems from closed
certificates. A theorem accepts arbitrary values, lists, plans, trees, or
histories and is proved by constructor analysis, algebraic congruence, or
structural induction. A certificate only normalizes a selected fixture and is
useful for regression coverage; it is never presented as a proof of the whole
program.

The headline rendering claims establish semantic invariants over arbitrary
inputs:

- shadow-query construction covers the Cartesian object/light domain with an
  exact object-count times light-count cardinality and a per-pair assignment
  specification. Actual `List<Light.Light>` positions identify lights; their
  payloads need not be copied. Structural successor nodes establish occurrence
  coverage even though the exposed U32 query labels may wrap for lists longer
  than the U32 domain;
- mesh generation preserves every fur anchor in order, emits one strand for
  every generated vertex, and expands every arbitrary quad into exactly two
  triangle facets;
- a supported reflection sample has a nonzero reflection-strength witness when
  the caller supplies explicit proofs of nonzero reflectance, positive incident
  light, and clear visibility.

The rendering tower also contains reusable algebraic and inductive lemmas for
signed negation, facet winding, vertex/fur cardinality, fur-root preservation,
quad expansion, clear visibility, disabled fog, reflection, shadow-query
cardinality, empty scenes, nearest-hit identity, and negative-distance
rejection. The fixed beet, sphere, and triangle checks remain certificates.

The rendering inventory is four semantic headline claims, three structural
Claim/Assert helpers, fourteen reusable library theorems, and five closed
certificates.

The physics headline theorem derives `ArticulationShape` from the live ragdoll
tree itself. The shape records every child/sibling constructor and every ball,
hinge-axis, fixed, or cone-twist joint. Proof-carrying integration and
constraint functions preserve this actual shape through one step and by
induction through every finite `StepHistory`. Separate arbitrary-input
theorems establish pinned-body invariance, pinned-history invariance, cleared
force, body-count preservation, and joint-kind preservation. The three sample
contact/ragdoll checks are certificates only.

The physics audit contains twelve universally quantified theorems or
proof-carrying claims and three closed certificates.

The AI proof tower connects the public semantics end to end:

- every `Decision` satisfies the explicit observation/action legality
  relation, and every planner result is therefore legal;
- arbitrary plan execution returns a proof-carrying `Verified3` result whose
  three erased fields establish preservation of the live squad's IDs and
  count and legality of the plan actually executed;
- executing the one-step plan produced for any world, goal, and observation
  returns the same combined ID/count/legality guarantee;
- structural induction over every finite `PlanHistory` composes those
  certified outputs once per frame and preserves IDs/count while proving the
  whole recorded history legal;
- equal initial worlds and equal histories produce equal simulations.

Planner determinism and per-agent identity/memory laws are also arbitrary-input
claims. The selected gather, danger-priority, and reference-history runs are
certificates only. The AI audit contains eight semantic claims, five helper
lemmas, and three closed certificates.

The fluids audit contains eight universal theorem families. It proves full
particle identity/kind/volume preservation for one impulse, arbitrary impulse
histories, and exact arbitrary particle/input lists; wave-cell identity through
arbitrary histories; zero buoyancy under the explicit dry constructor; and
exact superposition of the independently represented bubble, fish, filter, and
wind surface contributions. Optical formulas and buoyancy samples are
executable model components; the library does not claim a continuum-fluid
solution.

## Physical and semantic hypotheses

The claims are intentionally precise rather than broader than the
implementation:

- Model and ray coordinates use signed Q24.8; physics uses signed Q10. Their
  magnitudes are `U32`, so callers must keep intermediate products within the
  intended fixed-point range if wraparound would be unacceptable.
- Vector dot products used as Lambert or cone factors assume caller-supplied
  directions and normals use the expected Q0.8 normalization. The library does
  not silently normalize arbitrary vectors.
- Optical, fog, shadow, fur, and color channels conventionally occupy 0..255.
  Lighting clamps color operations, while model material data preserves the
  values authored by the caller.
- Positive reflection is conditional. It is not claimed for zero-reflectance,
  back-facing, or occluded pairs. A shadow query is not itself a visible
  shadow: `raytrace.bend` must resolve it against the caller's scene before the
  light code consumes `Visibility`.
- Point-light range must be nonzero where attenuation division is required;
  linear fog is authored with `finish > start`; and a soft spot band needs a
  nonzero softness. These are caller-side physical-domain preconditions.
- Reflection is a deterministic single-ray/fuzz sample. The package does not
  claim recursive global illumination, energy conservation, photorealism, or
  that its procedural fur is a strand-level collision simulation.
- A `PinnedBody` is the explicit infinite-mass hypothesis used by the pinned
  invariance proof. Ragdoll theorems preserve topology and joint kinds; they do
  not assert momentum conservation for damped, contact-corrected, constrained
  motion.
- AI legality is the declared game model: waiting and patrolling are total;
  gathering requires a perceived resource, fleeing requires injury or danger,
  and engaging requires a perceived enemy. Plans align with agents by list
  position. The engine is deterministic utility/behavior logic, not a learning
  system or an implicit pathfinder.

## Build and validate

From this directory:

```sh
./build.sh
```

To select a clean checkout explicitly:

```sh
BEND2_CORE=/path/to/bend2-core ./build.sh
```

The harness refuses a compiler revision other than `c5d69a1`, rejects the
removed `#[halts]` spelling in any package source, then compiles and runs the
rendering, physics, AI, and fluids entries through generated JavaScript and generated C
(built with `clang`). Every focused entry must return `True{}`. Core's native
driver may print its normal `fnv:` and statistics banner after that value; the
harness checks the first result line and the process status.

## Bend issues

No genuine parser/checker/compiler/Base/backend contradiction was found while
building this package, so it intentionally has no `unexpected_behavior/`
directory. Language syntax and declaration-order restrictions are not treated
as bugs. If future work finds a reproducible Bend defect, add only a minimized
reproducer and log that clearly separates it from an engine design or test
failure.
