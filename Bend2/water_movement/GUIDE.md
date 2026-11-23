# Water Movement — fluid visualizer

A **Bend** program (Bend 2.0.40) that simulates water with several fluid
algorithms. The physics is **pure** and is shown two ways from the same
functions:

```
  main.bend ─┬─ main = App.run: live window (native X11) ─── Wm.step / Wm.view
             ├─ web/index.html → water.html: live browser page ─ (same defs)
             └─ Wm.frames_json() → frames.json: the old pure "physics → JSON" filmstrip
```

- Source: [`main.bend`](./main.bend) · headless checks: [`test.bend`](./test.bend)
  · web shell: [`web/index.html`](./web/index.html) · build: [`build.mjs`](./build.mjs),
  [`play.sh`](./play.sh)

---

## 1. Running it

Needs `bend` 2.0.40+ (and `bun` for the web/JSON build). From this folder:

```sh
bend main.bend --check-only                 # ALL PROOFS CHECK
bend main.bend -o /tmp/water && /tmp/water  # native window (X11; libx11-dev)
sh play.sh                                  # rebuild water.html + frames.json, open the page
bend test.bend -o /tmp/water_test && /tmp/water_test   # headless PASS/FAIL checks
```

The window and the page show the **4 × 3 grid of panels** (one algorithm per
row: **Navier–Stokes, SPH, PBF, LBM**; one event per column: **rain · rock ·
fish**), running live. Each panel has a header strip whose left tag is
coloured by engine (blue wave, teal relax, violet CA, cyan particles); the web
page writes the panel titles over those strips.

Keys (window and page): **Space** pause/resume (headers turn amber), **.** one
step while paused, **+ / -** faster/slower (frames per sim step, 20 steps/s at
start on a 60 Hz display), **R** restart, **Esc** (or closing the window)
quits. Every panel restarts by itself after `LOOP_TICKS` = 240 steps, so the
scene loops like the old gif.

On a machine with a CUDA GPU, run the native binary as
`/tmp/water +RTS --gpu off -RTS`: Base's `App.run` hands every frame to the GPU
over PCIe, which made the window ~3× slower here (54 vs 186 frames in 5 s on a
Quadro RTX 3000; reported in `bugs/app-run-cuda-default-3x-slower`).

`water.html` is the **single-file web build** of the live app: `build.mjs`
bundles `web/index.html` (which imports `../main.bend`; the bend bundler
compiles it to JS) with `bend web/index.html -o <dir>` and inlines the chunk
with `web/inline.mjs`. The page calls the pure `Wm.view` / `Wm.step` every
animation frame and paints the returned `Image` quadtree on a canvas exactly as
the native window does (~9 ms a frame in a headless run).

`frames.json` keeps the original pipeline's data: `Wm.frames_json()` is a pure
def, called from the ES module `bend main.bend -o x.mjs` writes; it returns
`FRAMES` = 30 snapshots `FRAME_STEP` = 2 steps apart, in the same JSON shape as
before (`w`, `h`, `cols`, `meta[{title, kind}]`, `frames[{t, p[{g, fx, fy, fr,
hf, rk, rx, ry, rr}]}]`). Grid panels reproduce the previous Bend2 output
cell for cell; particle panels match until the last frames, where the summation
order of the new neighbour search moves a few cells by one level. The native
binary and the JS build produce byte-identical JSON.

---

## 2. Arguments

The "command line" is the **`Wm.args`** def at the top of `main.bend` — a
`List<&2, String>` of container specs:

```
algo : container : events
```

- **algo** — `navier-stokes` (or `ns`) · `shallow` · `stable` · `lbm` · `ca` ·
  `sph` · `pbf` · `pic`
- **container** — `still` · `stream` · `sphere`
- **events** — any comma-separated combination of `rain` , `rock` , `fish`
  (or omit)

Edit `Wm.args` to compare setups, e.g.

```
def Wm.args() -> List<&2, String>:
  ["sph:sphere:rock", "lbm:stream:rain,fish", "ca:still:rain"]
```

If it is empty (`[]`), the default grid is shown: **Navier–Stokes, SPH, PBF,
LBM** × **rain / rock / fish** (12 panels, three per row). Custom specs are
laid out two per row; at most four rows are shown (extra specs are dropped).

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

- A grid is a list of `GH` = 22 rows of `GW` = 40 `F32` cells (plain `Data`,
  so the view and the JSON read it freely). Each engine step is a **stencil**:
  it walks three rows at once (above, the row, below) beside an aux row,
  carrying the left neighbour, and builds the new grid — a pure functional
  update. Borders are **reflective** (a missing neighbour is the cell itself).
  The wave engine runs two passes (`v += c²∇²h` damped, then `h += v`).
- Particle engines hold a `List<&2, Part>` (float position + velocity). Each
  step buckets the particles by row and lets each one feel only the rows above,
  at and below it — exact, because the repulsion radius `P_RAD` is 1 cell —
  then applies gravity, wall bounces, rain droplets (at most `MAXP` = 80) and
  the **fish/rock pushes**. For drawing they are **splatted** into a density
  grid.
- `Wm.view` turns the state into the frame. The window is laid out in 8-px
  blocks: a 2-block margin, then per panel a 2-block header, its 40 × 22 cells
  (one block each) and a 2-block gap. Each block is one `Pix` (colour from the
  old page's ramps: height for grids, water density over dark air for
  particles); a block under the fish or the rock is drawn per pixel (yellow
  fish with its tail behind it and an eye; grey rock with an outline and a
  highlight). The 128 × 128 blocks are merged four by four, bottom-up, into the
  1024-px `Image` quadtree, collapsing same-colour quads.
- Levels for the JSON are integers 0..40 per cell (grids: `(h + 5) · 4`;
  particles: `density · 8`), as before.
- All tuning lives in the constants block near the top of `main.bend`
  (`Wm.wave_c2`, `Wm.relax_k`, `Wm.ca_flow`, `Wm.p_rad`, `Wm.pool_rows`,
  `Wm.rock_*`, `Wm.fish_*`, `Wm.frames`, `Wm.frame_step`, `Wm.loop_ticks`,
  `Wm.every0`, grid size, …).

**Porting notes (Bend 2.0.40).** The old program was a value `main : String`
for the HTML-emitting Bend2. The port keeps the physics but: grids moved from
`Grid(F32)` to lists of rows (an `Array` is affine and cannot be shared by the
view, and reading one needs a continuation per read); every loop is structural
recursion or `Nat` fuel (no `@unsafe`); helpers are defined above their callers
(no forward references or mutual recursion); `if` became `match` on `Bool`
through small helper defs; and the old `List/map(ps, p => part_update(p, ps))`
(O(n²)) became the row-bucketed neighbour search. `test.bend` checks the
engines headlessly (finite values, conservation for relax/CA, ripples from the
rock, particles inside the tank and settling, rain, fish wake and path, rock
fall, looping, the JSON header).
