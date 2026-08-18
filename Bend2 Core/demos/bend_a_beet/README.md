# Bend-a-Beet

Bend-a-Beet is a deterministic 3D tile-farm simulation written in Bend2 Core.
An embedded seed chooses which cells of a 3 × 8 field contain beets and derives
each beet's water, sugar, fiber, size, magic, and shine. Core then computes
growth, wind, uprooting, bending, world geometry, mesh quality, ray
intersections, sunlight, absorption, specular response, and shadow anchors.

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

The browser has play, pause, restart, step, playback-speed, orbit, tilt, and
zoom controls. Playback controls only select members of Core's immutable frame
list. `bend_a_beet_camera.js` exactly reverses Core's proven default projection;
`bend_a_beet_webgl.js` then renders those world points through an actual
perspective camera and depth buffer. Neither kind of control provides input to
Bend2 Core. When Core receives an implemented I/O boundary, this report adapter
should become a live clock/input loop while retaining the three pure libraries.

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

### `raytrace.bend`

The ray tracer uses signed Q24.8 rays, spheres, a horizontal plane, directional
Lambert sunlight and sphere occlusion. It now also computes a view-dependent
Phong-style `SurfaceLight` (diffuse, specular, combined and absorbed channels)
and a world-space `ShadowProjection`. The physical sun and shadow stay fixed in
the farm; the projected shadow and highlight move on screen with the WebGL
camera. Division and square root use structurally terminating bit algorithms.

## Proofs

Every library includes erased Core proofs and makes its test consume the proof
suite, so a successful check validates the theorems without carrying proof
payloads into the generated runtime.

| Library | Checked facts |
| --- | --- |
| Physics (10) | Exact break, spring, and recovery paths; zero growth; both clamp branches; bounded response; division/remainder; exact shine channel |
| Graphics (11) | Q10 bridges; 24 = 8 × 3 grid; endpoints/visibility; camera-axis projection; exact high mesh and shiny material |
| Ray tracing (12) | Division, roots, fixed multiplication, hits/misses, shadow/clear/farm light; exact specular response and ground projection |

The proofs establish concrete library contracts. They do not claim that the
fixed seed is random or that a browser canvas is formally verified.

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
camera-unprojection and WebGL depth/specular/shadow contracts, proof-suite
presence, and the absence of a whole-book termination escape.

The three focused backend tests are `physics_test.bend`,
`graphics3d_test.bend`, and `raytrace_test.bend`. None of the modules uses I/O
or `#[halts]`.

No genuine Bend2 Core bug was found while implementing this program, so this
folder intentionally has no `unexpected_behavior` entry.
