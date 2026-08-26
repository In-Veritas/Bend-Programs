# Bend-a-Beet

Bend-a-Beet is a deterministic 3D tile-farm simulation written in Bend2 Core.
An embedded seed chooses which cells of a 3 × 8 field contain beets and derives
each beet's water, sugar, fiber, size, magic, and shine. Core then computes
growth, wind, uprooting, bending, world geometry, mesh quality, ray
intersections, sunlight, absorption, specular response, and shadow anchors.
It now also consumes the reusable Bend Engine model/light APIs to derive one
material profile for every tile: four procedural texture classes, a
four-source light rig, fogged color, reflection, fuzz, geometric fur, and soft
shadow controls.

The generated run contains 19 planted beets: 5 break, 11 spring with a
`boioioioing` response, and 3 bend and recover. These counts are consequences
of seed `48823`; they are not JavaScript presets.

## Sequence

1. The field grows for exactly one hundred 50 ms Core frames (20 FPS). Amplified
   seeded wind moves the leaves while the ray tracer recomputes tile and beet
   light samples.
2. At time 5,000 ms, every planted beet enters the same sixteen-frame pull:
   downward loading, soil compression, accelerated release, overshoot, and
   damped rebound.
3. Planted beets are selected in tile order. Each gets fifty 50 ms trajectory
   samples plus a terminal frame before the next beet is bent.
4. Broken beets remain broken. Spring and recovery outcomes return to rest.

The browser has play, pause, restart, step, playback-speed, orbit, tilt, zoom,
and display toggles for fur, facets, fog, and soft shadows. Playback controls
only select members of Core's immutable frame list, while the display toggles
choose how already-computed channels are rasterized. `bend_a_beet_camera.js`
exactly reverses Core's default projection;
`bend_a_beet_webgl.js` then renders those world points through an actual
perspective camera and depth buffer. Neither kind of control provides input to
Bend2 Core. Core now has a general IO loop, but no DOM/WebGL or clock API; a
future browser integration can replace this report adapter while retaining the
three pure libraries.

The visual model now uses an asymmetric ribbed beet hull, branching root
networks, serrated leaf meshes with visible veins, layered soil clods and
petal-like fracture pieces instead of primitive ellipsoids and tubes alone.
Persistent fracture sectors follow the Core break state, wind bends each leaf
surface, and small animated butterflies give the close camera view additional
scale and motion without altering the deterministic farm report.

## Libraries

### `physics.bend`

The physics module uses signed Q10 fixed point (`1024 = 1.0`). Its public entry
points are:

- `attributes_from_seed(seed, tile)`
- `wind_at(seed, elapsed)`
- `beet_response(seed, attributes)`
- `beet_growth(seed, attributes, elapsed)`
- `beet_bend(seed, attributes, elapsed)`

Water, sugar, fiber, size, magic, shine, and a seeded response axis are carried
in every planted beet. Magic affects both the spring decision and number of
boings; fiber, water, sugar, and size affect resistance, flexibility, damping,
impulse, growth, and breaking. Shine is intentionally a material property: it
does not secretly change mass or elasticity.

### `graphics3d.bend`

The graphics module uses signed Q24.8 fixed point (`256 = 1.0`). It defines the
perspective camera, the full 24-tile farm, procedural beet ellipsoids, quadratic
stems, leaf tips, flutter, and broken geometry. The integration converts Q10
physics values with `fixed_from_q10` before calling `beet_procedural`, then uses
`camera_project` for the screen-space report.

Core now derives a `MeshQuality` of 28–35 radial × 14–17 vertical body segments
and 10–13 slices per leaf. The WebGL viewer turns that into true ellipsoid
surfaces, tubular roots, double-sided curved leaves and a 26–33 section stem
cable. The seeded signature rotates and leans each beet differently. Spring
frames deform the continuous tube like a string. A snapped body becomes 2–4
persistent separated 3D sectors; roots, flying dirt, loading, release and
overshoot make the pull read as a physical event.

`Material` now has explicit roughness and shininess. A high-shine beet produces
a tight camera-dependent shader highlight; a low-shine beet absorbs more of
the incident color. Changing the camera therefore changes the reflection, not
the underlying Core attribute.

### Bend Engine adapter

`engine_features.bend` is a small Bend-a-Beet adapter over the reusable
`../Bend Engine/model3d.bend` and `light.bend` sources. Because this Core
revision's import token cannot contain spaces, the tracked `engine` symlink is
the no-space import spelling; it resolves to the original package, not a copied
library. The adapter constructs solid, checker, faceted and seeded-noise
materials with positive reflection and fur-density constructors, then shades
them with ambient, directional, point and spot lights plus linear fog and
explicit shadow controls.

Core computes these 24 profiles once. Repeating the same four-light work inside
all 1,086 × 24 frame cells would add no information and made emission
unnecessarily expensive. Frames retain the time-varying geometry, original ray
samples, and shadow anchors; the viewer joins each tile to its immutable Engine
profile.

The WebGL layer uses the Engine profile rather than inventing material values:
it renders procedural surface variation, optional flat facets, environment
reflection, a fuzzy Fresnel rim, 12–52 actual strand tubes per visible beet,
the point/spot fixtures, depth fog, and up to eight layered soft-shadow samples.

### `raytrace.bend`

The ray tracer uses signed Q24.8 rays, spheres, a horizontal plane, directional
Lambert sunlight and sphere occlusion. It now also computes a view-dependent
Phong-style `SurfaceLight` (diffuse, specular, combined and absorbed channels)
and a world-space `ShadowProjection`. The physical sun and shadow stay fixed in
the farm; the projected shadow and highlight move on screen with the WebGL
camera. Division and square root use structurally terminating bit algorithms.

## Mathematical theorems and closed certificates

The three original libraries retain one supporting theorem each, quantified
over arbitrary input, plus their closed regression certificates. Two larger
proof modules establish semantic properties over arbitrary histories and
scenes. The Engine adapter adds exact arbitrary-list profile alignment and
cardinality. Its focused test also consumes the imported model/light theorem
suites. Core therefore validates 20 general theorems and 35 closed certificates
without runtime proof payloads.

| Library | General theorem | Closed certificates |
| --- | --- | --- |
| Physics | Negating any signed Q10 `Fix` twice returns the original value | 10 exact outcome, growth, bound, arithmetic, and shine facts |
| Graphics | Mapping any finite tile-index list to render primitives preserves its length | 11 exact bridge, grid, camera, mesh, and material facts |
| Ray tracing | Every negative fixed-point ray distance is rejected, for arbitrary `U32` magnitude | 12 exact arithmetic, hit, light, specular, and shadow facts |

`physics_history_proofs.bend` proves, by induction over every finite sequence
of wind, pull, recovery, and fracture commands, that a tracked beet keeps its
identity and planted root. A second arbitrary-history theorem proves fracture
is absorbing: later motion commands cannot make a broken beet active again.

`scene_proofs.bend` uses explicit hypotheses rather than making false physical
claims. A supported surface carries positive reflectance, a supported light
carries positive intensity, and every submitted object/light pair receives an
occlusion evaluation whose result may be clear or occluded. A helper tower
proves pair response validity and cardinality, then the scene summit proves for
arbitrary finite scenes that every declared pair has exactly one response, a
strictly positive reflection witness, and a shadow evaluation. It does not
claim that every evaluation is a visibly dark shadow.

`engine_features.bend` defines a dependent two-list contract: every arbitrary
input list produces an output at the same position that is definitionally the
result of `engine_profile_func` for that exact input. Structural induction proves
the contract and an independent length theorem. Positive reflection and fur
density are represented by constructors, while the imported model/light suites
prove fur-root preservation, vertex/facet cardinalities, texture behavior,
reflection identities, fog identity, and shadow-query cardinality over
arbitrary inputs. Their two fixed texture/light examples remain certificates.

These theorems establish only the properties stated above. The closed
certificates establish only their named fixtures. Neither category claims that
the fixed seed is random or that a browser canvas is formally verified.

## Build and test

From this directory:

```sh
./build.sh
bun test.mjs
```

`build.sh` compiles `bend_a_beet.bend` with the adjacent Bend2 Core checkout and
regenerates `bend_a_beet_data.js`. `test.mjs` independently validates all 1,086
frames, the 3 × 8 address mapping, 20 FPS five-second growth, the sixteen-stage
physical pull, one-at-a-time response groups, elastic direction reversals,
persistent fractures, all three outcomes, final states, projected points,
changing wind geometry, light/shine bounds, Core-selected mesh quality,
camera-unprojection and WebGL depth/specular/shadow contracts, all 24 aligned
Engine profiles, four texture classes, positive reflection/fur channels,
verification
audit presence, and the absence of a whole-book termination escape. It also compiles
and runs all six focused verification entries through Core's generated
JavaScript and native C backends, requiring `True{}` from each.

The focused backend tests are `physics_test.bend`, `graphics3d_test.bend`,
`raytrace_test.bend`, `physics_history_proofs_test.bend`, and
`scene_proofs_test.bend`, and `engine_features_test.bend`. None of the modules
uses I/O, and all are structurally terminating.

No genuine Bend2 Core bug was found while implementing this program, so this
folder intentionally has no `unexpected_behavior` entry.
