# Water Movement — fluid visualizer

A **Bend2** program that simulates water with several fluid algorithms. The
simulation is a **pure** program (no IO, no inline HTML/JS): `main` returns the
result as **JSON**. A separate browser page renders that data and loops it like
a gif.

```
  main.bend  (pure: physics → JSON)  →  frames.json  →  water.html  (animation)
```

- Source: [`main.bend`](./main.bend) · renderer/build: [`build.mjs`](./build.mjs) · launcher: [`play.sh`](./play.sh)

---

## 1. Running it

```sh
sh demo/water_movement/play.sh
```

That compiles `main.bend`, runs it once, writes **`frames.json`** (the saved
simulation data) and a standalone **`water.html`**, and opens the HTML. The page
animates the water on a canvas — colored cells, a swimming fish, **auto-looping**
(play/pause + a speed slider are provided).

The split is the whole point: Bend does only the *physics* (pure, deterministic,
prints data); all the *visualization and the looping* live in `build.mjs` /
`water.html`, completely outside the Bend program. You can rebuild the renderer
without touching the simulation, or feed `frames.json` to a different renderer.

To inspect the raw JSON the program prints:

```sh
bun run bend/src/CLI.ts demo/water_movement/main.bend -o /tmp/water.js && bun /tmp/water.js
```

With the default configuration you get a **4 × 3 grid of panels** — each of
**Navier–Stokes, SPH, PBF, LBM** (one algorithm per row), still water, shown
with **each event on its own** (rain · rock · fish, the three columns). Grid
methods are drawn as a **top-down** height field (blue shading); particle
methods (SPH/PBF) as a **side-on** pool that fills the bottom.

---

## 2. Arguments

A pure program can't read `argv`, so the "command line" is the **`args`** value
at the top of `main.bend` — a `List(String)` of container specs:

```
algo : container : events
```

- **algo** — `navier-stokes` (or `ns`) · `shallow` · `stable` · `lbm` · `ca` ·
  `sph` · `pbf` · `pic`
- **container** — `still` · `stream` · `sphere`
- **events** — any comma-separated combination of `rain` , `rock` , `fish`
  (or omit)

Edit `args` to compare setups, e.g.

```
args : List(String) = ["sph:sphere:rock", "lbm:stream:rain,fish", "ca:still:rain"]
```

If `args` is empty (`[]`), the default grid is shown: **Navier–Stokes, SPH, PBF,
LBM** × **rain / rock / fish** (12 panels, one algorithm per row).

---

## 3. Algorithms

Eight methods were requested; several are mathematically close, so (as invited)
they share an engine here. There are **four real engines**, and the eight names
map onto them:

| Name | Engine | Behaviour |
|------|--------|-----------|
| **Navier–Stokes** | grid **wave** | wave equation `v += c²∇²h ; h += v` with damping → ripples |
| **Shallow Water** | grid **wave** | same height-field family |
| **Stable Fluids** | grid **wave** | same height-field family |
| **Lattice Boltzmann** | grid **relax** | BGK-style relaxation toward the local average → smooth, diffusive spreading |
| **Cellular Automata** | grid **CA** | water flows from each cell to lower neighbours past a threshold → blocky redistribution |
| **SPH** | **particles** | particles with a smoothing-radius repulsion + gravity; settle into a pool |
| **PBF** | **particles** | same particles, stiffer (position-based-flavoured) packing |
| **PIC** | **particles** | same particle engine |

So the genuinely distinct visuals are: **wave** (concentric ripples), **relax**
(smooth blur), **CA** (blocky), and **particles** (a settling pool). The default
panel set (NS / SPH / PBF / LBM) shows three of these families at once.

---

## 4. Container types (initial conditions)

- **still** — calm water at rest (grids start flat; particles start as a pool
  filling the lower tank).
- **stream** — a travelling wave is injected at the left edge each step, so a
  current flows across grid engines.
- **sphere** — a raised circular dome of water at the centre that collapses into
  ripples (grids) / a disk of particles (particle engines).

---

## 5. Events

- **rock** — a **visible rock** (gray disk) drops into the tank at the start. On
  particle engines it falls from the top, splashes through the surface, shoves
  the water out of the way and sinks to the floor; on grid engines it sits at the
  centre and sends out ripples (a tall central impulse at `t = 0`).
- **rain** — small impulses fall near the surface every few steps, dimpling the
  height field.
- **fish** — a fish swims back and forth and **disturbs the water on every
  engine**: a wake-dimple on the grids, and a push that shoves nearby particles
  on SPH/PBF. (It is only drawn where it can interact; here that's everywhere.)

---

## 6. How it works

- The field is a `Grid(F32)` (`base/Data/Grid`, Array-backed). Each step rebuilds
  a fresh grid by reading neighbours from the previous one — a pure functional
  update. Borders are **reflective** (tank walls).
- Particle engines hold a `List(Part)` (float position + velocity). Each step
  applies gravity, pairwise repulsion within `P_RAD` (O(n²), but n is small),
  wall bounces, and the **fish/rock pushes** (those disturbers shove nearby
  particles); for rendering the particles are **splatted** into a density grid.
- For output the program serializes each panel's field to **integer levels
  0..40** per cell (grids: height; particles: density via the splat), plus the
  fish and rock positions — as JSON. Keeping it to small ints keeps the data
  compact and lets the renderer colour it freely.
- Everything is sized to stay light: `40 × 22` grids, a few hundred particles,
  `FRAMES = 30` frames `FRAME_STEP = 2` sim-steps apart. All the tuning lives in
  the constants block near the top of `main.bend` (`WAVE_C2`, `RELAX_K`,
  `CA_FLOW`, `P_RAD`, `POOL_ROWS`, `ROCK_*`, `FISH_*`, `FRAMES`, grid size, …).

**Animation.** A pure program can't loop over time, so instead of one snapshot
it emits **`FRAMES`** of them (the sims advanced `FRAME_STEP` steps between each)
in the JSON. `build.mjs` runs the program once, writes `frames.json`, and embeds
the data into `water.html`; the page draws the frames on a canvas and loops them
(`requestAnimationFrame`). So the simulation is computed once, purely, and the
*playback* — the timing, the colours, the looping — is the only IO/visual work,
done entirely in the renderer. Raise `FRAMES`/`FRAME_STEP` or change `args` and
re-run `play.sh` to explore.
