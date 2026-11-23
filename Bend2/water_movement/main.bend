# Water Movement: a fluid-simulation visualizer in Bend 2.0.40.
#
# Several small water tanks ("panels") are simulated side by side, each with
# one of eight algorithm names mapped onto four engines (wave, relax, CA,
# particles), a container (still / stream / sphere) and any of three events
# (rain, rock, fish). The physics is pure; it is shown two ways:
#
#   live   `main` is an App: the sims advance while you watch, and `Wm.view`
#          draws every panel into the window's Image quadtree.
#            bend main.bend -o /tmp/water && /tmp/water        (native, X11)
#            bend web/index.html -o /tmp/wm_dist                (browser)
#   data   `Wm.frames_json()` returns FRAMES snapshots as JSON (the old
#          pipeline); build.mjs imports it from `bend main.bend -o x.mjs`.
#
# Keys: Space pause/resume, . single step while paused, + / - faster or
# slower, R restart, Esc or Close quits. Each panel restarts by itself after
# LOOP_TICKS steps, so the window loops like a gif.
#
# The "command line" is `Wm.args` below: a list of "algo:container:events"
# specs (events comma-separated). Empty means the default 4 x 3 grid:
# Navier-Stokes, SPH, PBF, LBM (one per row) x rain / rock / fish.
#
#   algo      : navier-stokes (ns) | shallow | stable | lbm | ca | sph | pbf | pic
#   container : still | stream | sphere
#   events    : rain , rock , fish  (any combination, or omit)
import Base

# Configuration (the "arguments")
# ===============================

# Edit this. Example:
#   ["sph:sphere:rock", "lbm:stream:rain,fish", "ca:still:rain"]
def Wm.args() -> List<&2, String>:
  []

def Wm.default_specs() -> List<&2, String>:
  ["navier-stokes:still:rain", "navier-stokes:still:rock",
    "navier-stokes:still:fish", "sph:still:rain", "sph:still:rock",
    "sph:still:fish", "pbf:still:rain", "pbf:still:rock", "pbf:still:fish",
    "lbm:still:rain", "lbm:still:rock", "lbm:still:fish"]

# Types
# =====

type Algo is Data:
  Navier{}
  Shallow{}
  Stable{}
  Lbm{}
  Ca{}
  Sph{}
  Pbf{}
  Pic{}

# The four engines the eight names share.
type Eng is Data:
  EWave{}
  ERelax{}
  ECa{}
  EPart{}

type CType is Data:
  Still{}
  Stream{}
  Sphere{}

type Cont is Data:
  Cont{algo: Algo, ctype: CType, rain: Bool, rock: Bool, fish: Bool}

# A particle, in grid-space float coordinates, with its velocity.
type Part is Data:
  Part{x: F32, y: F32, vx: F32, vy: F32}

type Vec is Data:
  Vec{x: F32, y: F32}

type Fish is Data:
  Fpos{fx: U32, fy: U32, right: Bool}

# One tank: height and velocity grids (grid engines) or particles (particle
# engines), its rng and its step count. A grid is a list of GH rows of GW
# cells: plain Data, so the view and the JSON can read it freely.
type Sim is Data:
  Sim{h: List<&2, List<&2, F32>>, v: List<&2, List<&2, F32>>,
    ps: List<&2, Part>, rng: U32, tick: U32}

type Pan is Data:
  Pan{c: Cont, s: Sim}

# The live app: the panels, frames left until the next step, frames per
# step, and whether it is paused.
type World is Data:
  World{pans: List<&2, Pan>, wait: U32, every: U32, paused: Bool}

# Constants
# =========

def Wm.gw() -> U32:
  40

def Wm.gh() -> U32:
  22

def Wm.gwf() -> F32:
  40.0

def Wm.ghf() -> F32:
  22.0

# JSON filmstrip: FRAMES snapshots, FRAME_STEP steps apart.
def Wm.frames() -> Nat:
  30n

def Wm.frame_step() -> Nat:
  2n

# Live: a panel restarts after this many steps.
def Wm.loop_ticks() -> U32:
  240

# Live: display frames per sim step at start (60 Hz / 3 = 20 steps/s).
def Wm.every0() -> U32:
  3

# Wave engine.
def Wm.wave_c2() -> F32:
  0.20

def Wm.wave_damp() -> F32:
  0.99

# Relaxation (LBM): fraction pulled toward the neighbour average.
def Wm.relax_k() -> F32:
  0.22

# Cellular automata: flow fraction and threshold.
def Wm.ca_flow() -> F32:
  0.25

def Wm.ca_thresh() -> F32:
  0.4

# Particle engine.
def Wm.p_grav() -> F32:
  0.05

# Interaction radius. The neighbour search buckets particles by row and
# looks one row up and down, which is exact only while this is at most 1.0.
def Wm.p_rad() -> F32:
  1.0

def Wm.p_damp() -> F32:
  0.92

def Wm.sph_stiff() -> F32:
  0.05

def Wm.pbf_stiff() -> F32:
  0.13

# Rain droplets a particle tank takes before it stops raining.
def Wm.maxp() -> U32:
  80

def Wm.pool_rows() -> U32:
  9

# Events.
def Wm.rock_imp() -> F32:
  9.0

def Wm.rain_imp() -> F32:
  3.0

def Wm.rain_every() -> U32:
  3

def Wm.fish_push_r() -> F32:
  2.6

def Wm.fish_push() -> F32:
  0.16

def Wm.rock_push_r() -> F32:
  3.4

def Wm.rock_push() -> F32:
  0.55

def Wm.rock_r() -> F32:
  2.2

def Wm.rock_fall() -> F32:
  1.0

# Small helpers
# =============

def Wm.pickf(c: Bool, a: F32, b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

def Wm.picku(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def Wm.minf(+a: F32, +b: F32) -> F32:
  Wm.pickf((a < b : F32), a, b)

def Wm.maxf(+a: F32, +b: F32) -> F32:
  Wm.pickf((a < b : F32), b, a)

def Wm.clampf(v: F32, lo: F32, hi: F32) -> F32:
  Wm.maxf(lo, Wm.minf(hi, v))

def Wm.absf(+a: F32) -> F32:
  Wm.pickf((a < 0.0 : F32), (0.0 - a : F32), a)

def Wm.neg(a: F32) -> F32:
  (0.0 - a : F32)

def Wm.clampu(+x: U32, +n: U32) -> U32:
  Wm.picku((x < n : U32), x, (n - 1 : U32))

def Wm.rng_next(s: U32) -> U32:
  (s * 1103515245 + 12345 : U32)

def Wm.rand_unit(r: U32) -> F32:
  (U32.to_f32((r % 2000 : U32)) / 1000.0 - 1.0 : F32)

# A non-negative float to a cell index, clamped to [0, n).
def Wm.cell_of(+v: F32, +n: U32) -> U32:
  Wm.clampu(F32.to_u32(Wm.maxf(0.0, v)), n)

def Wm.engine(a: Algo) -> Eng:
  match a:
    case Navier{}:
      EWave{}
    case Shallow{}:
      EWave{}
    case Stable{}:
      EWave{}
    case Lbm{}:
      ERelax{}
    case Ca{}:
      ECa{}
    case Sph{}:
      EPart{}
    case Pbf{}:
      EPart{}
    case Pic{}:
      EPart{}

# 0 = wave, 1 = relax, 2 = ca, 3 = particles (the JSON "kind").
def Wm.eng_num(e: Eng) -> U32:
  match e:
    case EWave{}:
      0
    case ERelax{}:
      1
    case ECa{}:
      2
    case EPart{}:
      3

def Wm.is_part(e: Eng) -> Bool:
  match e:
    case EPart{}:
      True{}
    case _:
      False{}

def Wm.part_stiff(a: Algo) -> F32:
  match a:
    case Pbf{}:
      Wm.pbf_stiff()
    case _:
      Wm.sph_stiff()

# The fish swims left and right, bouncing off the walls. Side-on particle
# tanks keep it submerged halfway down the pool; top-down grids, mid-plane.
def Wm.fish_y(part: Bool) -> U32:
  match part:
    case True{}:
      (Wm.gh() - Wm.pool_rows() / 2 : U32)
    case False{}:
      (Wm.gh() / 2 : U32)

def Wm.fish_at(fwd: Bool, +ph: U32, +period: U32, fy: U32) -> Fish:
  match fwd:
    case True{}:
      Fpos{(2 + ph : U32), fy, True{}}
    case False{}:
      Fpos{(2 + period - ph : U32), fy, False{}}

def Wm.fish_for(part: Bool, tick: U32) -> Fish:
  +span = (Wm.gw() - 4 : U32)
  +period = (span + span : U32)
  +ph = (tick % period : U32)
  Wm.fish_at((ph < span : U32), ph, period, Wm.fish_y(part))

# The rock: side-on it falls from the top and rests on the floor; top-down
# it sits at the centre, where it landed.
def Wm.rock_pos(part: Bool, tick: U32) -> Vec:
  match part:
    case True{}:
      Vec{(Wm.gwf() * 0.5 : F32), Wm.minf((1.0 + U32.to_f32(tick)
        * Wm.rock_fall() : F32), (Wm.ghf() - 2.0 : F32))}
    case False{}:
      Vec{(Wm.gwf() * 0.5 : F32), (Wm.ghf() * 0.5 : F32)}

# Grids
# =====
# A grid is GH rows of GW cells. A stencil walks three rows at once (the
# one above, the row, the one below) beside an aux row, carrying the cell
# to the left; a wall reflects, so a missing neighbour is the cell itself.

def Wm.zero_row(n: Nat) -> List<&2, F32>:
  List.replicate(F32, n, 0.0)

def Wm.zero() -> List<&2, List<&2, F32>>:
  List.replicate(List<&2, F32>, U32.to_nat(Wm.gh()),
    Wm.zero_row(U32.to_nat(Wm.gw())))

def Wm.headf(xs: List<&2, F32>, d: F32) -> F32:
  match xs:
    case []:
      d
    case h <> t:
      h

def Wm.headr(xs: List<&2, List<&2, F32>>, d: List<&2, F32>) -> List<&2, F32>:
  match xs:
    case []:
      d
    case h <> t:
      h

# One row: k(c, l, r, u, d, a) for every cell.
def Wm.st_row(
  ~k: F32 -> F32 -> F32 -> F32 -> F32 -> F32 -> F32, cur: List<&2, F32>,
  up: List<&2, F32>, dn: List<&2, F32>, aux: List<&2, F32>, left: F32
) -> List<&2, F32>:
  match cur up dn aux:
    case Con{+c, +rest} Con{u, ur} Con{d, dr} Con{a, ar}:
      k(c, left, Wm.headf(rest, c), u, d, a) <> Wm.st_row(~k, rest, ur, dr, ar,
        c)
    case _ _ _ _:
      []

def Wm.st_rows(
  ~k: F32 -> F32 -> F32 -> F32 -> F32 -> F32 -> F32,
  rows: List<&2, List<&2, F32>>, up: List<&2, F32>,
  aux: List<&2, List<&2, F32>>
) -> List<&2, List<&2, F32>>:
  match rows aux:
    case Con{+cur, +rest} Con{a, ar}:
      Wm.st_row(~k, cur, up, Wm.headr(rest, cur), a, Wm.headf(cur, 0.0))
        <> Wm.st_rows(~k, rest, cur, ar)
    case _ _:
      []

def Wm.stencil(
  ~k: F32 -> F32 -> F32 -> F32 -> F32 -> F32 -> F32,
  +g: List<&2, List<&2, F32>>, aux: List<&2, List<&2, F32>>
) -> List<&2, List<&2, F32>>:
  Wm.st_rows(~k, g, Wm.headr(g, []), aux)

# Wave (Navier-Stokes / Shallow Water / Stable Fluids): v += c2 lap(h),
# damped; then h += v.
def Wm.wave_vk(c: F32, l: F32, r: F32, u: F32, d: F32, a: F32) -> F32:
  ((a + Wm.wave_c2() * (l + r + (u + d) - 4.0 * c)) * Wm.wave_damp() : F32)

def Wm.wave_hk(c: F32, l: F32, r: F32, u: F32, d: F32, a: F32) -> F32:
  (c + a : F32)

# Relax (Lattice Boltzmann, BGK-style): pull toward the neighbour average.
def Wm.relax_k1(c0: F32, l: F32, r: F32, u: F32, d: F32, a: F32) -> F32:
  +c = c0
  (c + Wm.relax_k() * ((l + r + (u + d)) / 4.0 - c) : F32)

# Cellular automata: give a fraction of the excess over each lower
# neighbour, take a fraction of each higher neighbour's excess over us.
def Wm.ca_flow1(c: F32, nb: F32) -> F32:
  +d = (c - nb : F32)
  Wm.pickf((Wm.ca_thresh() < d : F32), (Wm.ca_flow() * d : F32), 0.0)

def Wm.ca_k(c0: F32, l0: F32, r0: F32, u0: F32, d0: F32, a: F32) -> F32:
  +c = c0
  +l = l0
  +r = r0
  +u = u0
  +d = d0
  +out = (Wm.ca_flow1(c, l) + Wm.ca_flow1(c, r)
    + (Wm.ca_flow1(c, u) + Wm.ca_flow1(c, d)) : F32)
  +inc = (Wm.ca_flow1(l, c) + Wm.ca_flow1(r, c)
    + (Wm.ca_flow1(u, c) + Wm.ca_flow1(d, c)) : F32)
  (c - out + inc : F32)

# Impulses
# --------

# A soft circular impulse of radius 2 cells: amp * (4 - r2) / 4 for r2 < 4.
def Wm.stamp_add(+r2: F32, amp: F32) -> F32:
  Wm.pickf((r2 < 4.0 : F32), (amp * ((4.0 - r2) / 4.0) : F32), 0.0)

def Wm.udist(+a: U32, +b: U32) -> F32:
  U32.to_f32(Wm.picku((a < b : U32), (b - a : U32), (a - b : U32)))

def Wm.stamp_row(xs: List<&2, F32>, +x: U32, +cx: U32, +ddy: F32, +amp: F32)
  -> List<&2, F32>:
  match xs:
    case []:
      []
    case v <> rest:
      +ddx = Wm.udist(x, cx)
      (v + Wm.stamp_add((ddx * ddx + ddy * ddy : F32), amp) : F32)
        <> Wm.stamp_row(rest, (x + 1 : U32), cx, ddy, amp)

def Wm.stamp_go(g: List<&2, List<&2, F32>>, +y: U32, +cx: U32, +cy: U32,
  +amp: F32) -> List<&2, List<&2, F32>>:
  match g:
    case []:
      []
    case row <> rest:
      Wm.stamp_row(row, 0, cx, Wm.udist(y, cy), amp)
        <> Wm.stamp_go(rest, (y + 1 : U32), cx, cy, amp)

def Wm.stamp(g: List<&2, List<&2, F32>>, cx: U32, cy: U32, amp: F32) ->
  List<&2, List<&2, F32>>:
  Wm.stamp_go(g, 0, cx, cy, amp)

# Rain: every third step, a small impulse near the top.
def Wm.rain_grid(on: Bool, g: List<&2, List<&2, F32>>, rng: U32) ->
  List<&2, List<&2, F32>>:
  match on:
    case True{}:
      Wm.stamp(g, (rng % (Wm.gw() - 2) + 1 : U32), 2, Wm.rain_imp())
    case False{}:
      g

# Fish wake: a small dimple at the fish's cell every step.
def Wm.stamp_fish(g: List<&2, List<&2, F32>>, f: Fish) ->
  List<&2, List<&2, F32>>:
  Fpos{fx, fy, right} = f
  Wm.stamp(g, fx, fy, Wm.neg(0.4))

def Wm.fish_grid(on: Bool, g: List<&2, List<&2, F32>>, tick: U32) ->
  List<&2, List<&2, F32>>:
  match on:
    case True{}:
      Wm.stamp_fish(g, Wm.fish_for(False{}, tick))
    case False{}:
      g

# Stream: a travelling wave forced at the left edge.
def Wm.set_first(xs: List<&2, F32>, v: F32) -> List<&2, F32>:
  match xs:
    case []:
      []
    case h <> t:
      v <> t

def Wm.stream_go(g: List<&2, List<&2, F32>>, +amp: F32) ->
  List<&2, List<&2, F32>>:
  match g:
    case []:
      []
    case row <> rest:
      Wm.set_first(row, amp) <> Wm.stream_go(rest, amp)

def Wm.stream_inflow(ct: CType, g: List<&2, List<&2, F32>>, tick: U32) ->
  List<&2, List<&2, F32>>:
  match ct:
    case Stream{}:
      Wm.stream_go(g, (F32.sin((U32.to_f32(tick) * 0.6 : F32)) * 3.0 : F32))
    case _:
      g

def Wm.grid_substep(e: Eng, +h: List<&2, List<&2, F32>>,
  +v: List<&2, List<&2, F32>>) ->
  List<&2, List<&2, F32>> & List<&2, List<&2, F32>>:
  match e:
    case EWave{}:
      +nv = Wm.stencil(~Wm.wave_vk, h, v)
      (Wm.stencil(~Wm.wave_hk, h, nv), nv)
    case ERelax{}:
      (Wm.stencil(~Wm.relax_k1, h, v), v)
    case _:
      (Wm.stencil(~Wm.ca_k, h, v), v)

# Particles
# =========
# The repulsion acts within P_RAD = 1, so a particle only meets the ones in
# its own row and the rows above and below: every step buckets them by row.

# The push a particle at (dx, dy) from another (d2 = dx^2 + dy^2) gets from
# it, or none past the radius (or right on top of it).
def Wm.contrib(hit: Bool, +dx: F32, +dy: F32, d2: F32, stiff: F32, acc: Vec)
  -> Vec:
  match hit:
    case False{}:
      acc
    case True{}:
      Vec{ax, ay} = acc
      +d = F32.sqrt(d2)
      +push = (stiff * ((Wm.p_rad() - d) / Wm.p_rad()) : F32)
      Vec{(ax + dx / d * push : F32), (ay + dy / d * push : F32)}

def Wm.repulse(ps: List<&2, Part>, +sx: F32, +sy: F32, +stiff: F32,
  acc: Vec) -> Vec:
  match ps:
    case []:
      acc
    case p <> rest:
      Part{px, py, pvx, pvy} = p
      +dx = (sx - px : F32)
      +dy = (sy - py : F32)
      +d2 = (dx * dx + dy * dy : F32)
      Wm.repulse(rest, sx, sy, stiff, Wm.contrib((0.0001 < d2 : F32)
        && (d2 < Wm.p_rad() * Wm.p_rad() : F32), dx, dy, d2, stiff, acc))

def Wm.wall_lo(lo: Bool, high: Bool, p: F32, +v: F32, hi: F32) -> Vec:
  match lo high:
    case True{} _:
      Vec{0.6, (Wm.absf(v) * Wm.p_damp() : F32)}
    case False{} True{}:
      Vec{(hi - 0.6 : F32), (Wm.neg(Wm.absf(v)) * Wm.p_damp() : F32)}
    case False{} False{}:
      Vec{p, v}


# Wall bounce: clamp to the tank and send the velocity back in, damped.
def Wm.wall(+p: F32, +v: F32, +hi: F32) -> Vec:
  Wm.wall_lo((p < 0.6 : F32), (hi - 0.6 < p : F32), p, v, hi)

def Wm.part_of(wx: Vec, wy: Vec) -> Part:
  Vec{nx, nvx} = wx
  Vec{ny, nvy} = wy
  Part{nx, ny, nvx, nvy}

def Wm.part_move(p: Part, f: Vec) -> Part:
  Part{x, y, vx, vy} = p
  Vec{rx, ry} = f
  +vx1 = ((vx + rx) * Wm.p_damp() : F32)
  +vy1 = ((vy + ry + Wm.p_grav()) * Wm.p_damp() : F32)
  Wm.part_of(Wm.wall((x + vx1 : F32), vx1, Wm.gwf()),
    Wm.wall((y + vy1 : F32), vy1, Wm.ghf()))

def Wm.part_one(+p: Part, +a: List<&2, Part>, +b: List<&2, Part>,
  +c: List<&2, Part>, +stiff: F32) -> Part:
  Part{+x, +y, vx, vy} = p
  +z = {Vec{0.0, 0.0} : Vec}
  Wm.part_move(p, Wm.repulse(c, x, y, stiff, Wm.repulse(b, x, y, stiff,
    Wm.repulse(a, x, y, stiff, z))))

# Updates the particles of one row (b) against rows a, b and c, onto tail.
def Wm.upd_row(ps: List<&2, Part>, +a: List<&2, Part>, +b: List<&2, Part>,
  +c: List<&2, Part>, +stiff: F32, tail: List<&2, Part>) -> List<&2, Part>:
  match ps:
    case []:
      tail
    case p <> rest:
      Wm.upd_row(rest, a, b, c, stiff, Wm.part_one(p, a, b, c, stiff) <> tail)

def Wm.headp(xs: List<&2, List<&2, Part>>) -> List<&2, Part>:
  match xs:
    case []:
      []
    case h <> t:
      h

def Wm.upd_rows(rows: List<&2, List<&2, Part>>, +prev: List<&2, Part>,
  +stiff: F32) -> List<&2, Part>:
  match rows:
    case []:
      []
    case Con{+cur, +rest} :
      Wm.upd_row(cur, prev, cur, Wm.headp(rest), stiff,
        Wm.upd_rows(rest, cur, stiff))

def Wm.ins(rows: List<&2, List<&2, Part>>, k: Nat, p: Part) ->
  List<&2, List<&2, Part>>:
  match rows k:
    case [] _:
      []
    case r <> rest 0n:
      (p <> r) <> rest
    case r <> rest 1n+j:
      r <> Wm.ins(rest, j, p)

def Wm.bucket(ps: List<&2, Part>, rows: List<&2, List<&2, Part>>) ->
  List<&2, List<&2, Part>>:
  match ps:
    case []:
      rows
    case p <> rest:
      Part{x, +y, vx, vy} = p
      Wm.bucket(rest, Wm.ins(rows, U32.to_nat(Wm.cell_of(y, Wm.gh())),
        Part{x, y, vx, vy}))

def Wm.empty_rows() -> List<&2, List<&2, Part>>:
  List.replicate(List<&2, Part>, U32.to_nat(Wm.gh()), [])

def Wm.push_if(hit: Bool, p: Part, +dx: F32, +dy: F32, d2: F32, +r: F32,
  s: F32) -> Part:
  match hit:
    case False{}:
      p
    case True{}:
      Part{x, y, vx, vy} = p
      +d = F32.sqrt((d2 + 0.01 : F32))
      +f = (s * ((r - d) / r) : F32)
      Part{x, y, (vx + dx / d * f : F32), (vy + dy / d * f : F32)}


# Push one particle away from a disturber at (cx, cy) within radius r.
def Wm.push_one(+p: Part, +cx: F32, +cy: F32, +r: F32, +s: F32) -> Part:
  Part{+x, +y, +vx, +vy} = p
  +dx = (x - cx : F32)
  +dy = (y - cy : F32)
  +d2 = (dx * dx + dy * dy : F32)
  Wm.push_if((d2 < r * r : F32), p, dx, dy, d2, r, s)

def Wm.push_all(ps: List<&2, Part>, +cx: F32, +cy: F32, +r: F32, +s: F32) ->
  List<&2, Part>:
  match ps:
    case []:
      []
    case p <> rest:
      Wm.push_one(p, cx, cy, r, s) <> Wm.push_all(rest, cx, cy, r, s)

def Wm.push_fish(ps: List<&2, Part>, f: Fish) -> List<&2, Part>:
  Fpos{fx, fy, right} = f
  Wm.push_all(ps, (U32.to_f32(fx) + 0.5 : F32), (U32.to_f32(fy) + 0.5 : F32),
    Wm.fish_push_r(), Wm.fish_push())

def Wm.push_rock(ps: List<&2, Part>, r: Vec) -> List<&2, Part>:
  Vec{rx, ry} = r
  Wm.push_all(ps, rx, ry, Wm.rock_push_r(), Wm.rock_push())

def Wm.fish_parts(on: Bool, ps: List<&2, Part>, tick: U32) -> List<&2, Part>:
  match on:
    case True{}:
      Wm.push_fish(ps, Wm.fish_for(True{}, tick))
    case False{}:
      ps

def Wm.rock_parts(on: Bool, ps: List<&2, Part>, tick: U32) -> List<&2, Part>:
  match on:
    case True{}:
      Wm.push_rock(ps, Wm.rock_pos(True{}, tick))
    case False{}:
      ps

def Wm.rain_drop(drop: Bool, ps: List<&2, Part>, px: F32) -> List<&2, Part>:
  match drop:
    case True{}:
      Part{px, 1.0, 0.0, 0.4} <> ps
    case False{}:
      ps


# Rain on particles: a droplet falls in from the top every few steps, up to
# MAXP droplets.
def Wm.rain_parts(on: Bool, ps: List<&2, Part>, +tick: U32) -> List<&2, Part>:
  match on:
    case True{}:
      +px = (U32.to_f32((tick * 13 % (Wm.gw() - 4) + 2 : U32)) + 0.5 : F32)
      Wm.rain_drop(U32.is_eq((tick % Wm.rain_every() : U32), 0)
        && (tick < Wm.rain_every() * Wm.maxp() : U32), ps, px)
    case False{}:
      ps

def Wm.part_step(ps: List<&2, Part>, +stiff: F32, c: Cont, +tick: U32) ->
  List<&2, Part>:
  Cont{algo, ctype, rain, rock, fish} = c
  moved = Wm.upd_rows(Wm.bucket(ps, Wm.empty_rows()), [], stiff)
  Wm.rock_parts(rock, Wm.fish_parts(fish, Wm.rain_parts(rain, moved, tick),
    tick), tick)

def Wm.bump(row: List<&2, F32>, k: Nat) -> List<&2, F32>:
  match row k:
    case [] _:
      []
    case v <> rest 0n:
      (v + 1.0 : F32) <> rest
    case v <> rest 1n+j:
      v <> Wm.bump(rest, j)


# Splat the particles into a density grid (particles per cell).
def Wm.splat_row(ps: List<&2, Part>, row: List<&2, F32>) -> List<&2, F32>:
  match ps:
    case []:
      row
    case p <> rest:
      Part{x, y, vx, vy} = p
      Wm.splat_row(rest, Wm.bump(row, U32.to_nat(Wm.cell_of(x, Wm.gw()))))

def Wm.splat_rows(rows: List<&2, List<&2, Part>>) -> List<&2, List<&2, F32>> :
  match rows:
    case []:
      []
    case r <> rest:
      Wm.splat_row(r, Wm.zero_row(U32.to_nat(Wm.gw()))) <> Wm.splat_rows(rest)

def Wm.splat(ps: List<&2, Part>) -> List<&2, List<&2, F32>>:
  Wm.splat_rows(Wm.bucket(ps, Wm.empty_rows()))

# One step
# ========

def Wm.grid_events(c: Cont, h: List<&2, List<&2, F32>>, rng: U32,
  +tick: U32) -> List<&2, List<&2, F32>>:
  Cont{algo, ctype, rain, rock, fish} = c
  Wm.stream_inflow(ctype, Wm.fish_grid(fish, Wm.rain_grid(rain
    && U32.is_eq((tick % 3 : U32), 0), h, rng), tick), tick)

def Wm.grid_fin(c: Cont, hv: List<&2, List<&2, F32>> & List<&2, List<&2, F32>>,
  ps: List<&2, Part>, +rng: U32, +tick: U32) -> Sim:
  (h, v) = hv
  Sim{Wm.grid_events(c, h, rng, tick), v, ps, rng, tick}

def Wm.step_eng(e: Eng, +c: Cont, s: Sim) -> Sim:
  match e:
    case EPart{}:
      Cont{algo, ct, rn, rk, fs} = c
      Sim{h, v, ps, rng, tick} = s
      +tick1 = (tick + 1 : U32)
      Sim{h, v, Wm.part_step(ps, Wm.part_stiff(algo), c, tick1),
        Wm.rng_next(rng), tick1}
    case e2:
      Sim{h, v, ps, rng, tick} = s
      Wm.grid_fin(c, Wm.grid_substep(e2, h, v), ps, Wm.rng_next(rng),
        (tick + 1 : U32))

def Wm.step_one(+c: Cont, s: Sim) -> Sim:
  Cont{algo, ct, rn, rk, fs} = c
  Wm.step_eng(Wm.engine(algo), c, s)

def Wm.run_sim(n: Nat, +c: Cont, s: Sim) -> Sim:
  match n:
    case 0n:
      s
    case 1n+p:
      Wm.run_sim(p, c, Wm.step_one(c, s))

# Initial conditions
# ==================

# A disk of droplets for the "sphere" container.
def Wm.disk_go(n: Nat, acc: List<&2, Part>, rng: U32) -> List<&2, Part>:
  match n:
    case 0n:
      acc
    case 1n+p:
      +r1 = Wm.rng_next(rng)
      +r2 = Wm.rng_next(r1)
      +px = (Wm.gwf() * 0.5 + Wm.rand_unit(r1) * 3.0 : F32)
      +py = (Wm.ghf() * 0.4 + Wm.rand_unit(r2) * 3.0 : F32)
      Wm.disk_go(p, Part{px, py, 0.0, 0.0} <> acc, r2)

# A pool of particles, one per cell, filling the lowest POOL_ROWS rows.
def Wm.pool_go(n: Nat, acc: List<&2, Part>, +x: U32, +y: U32) ->
  List<&2, Part>:
  match n:
    case 0n:
      acc
    case 1n+p:
      +last = U32.is_eq(x, (Wm.gw() - 1 : U32))
      Wm.pool_go(p, Part{(U32.to_f32(x) + 0.5 : F32),
        (U32.to_f32(y) + 0.5 : F32), 0.0, 0.0} <> acc,
        Wm.picku(last, 0, (x + 1 : U32)), Wm.picku(last, (y + 1 : U32), y))

def Wm.init_parts(ct: CType) -> List<&2, Part>:
  match ct:
    case Sphere{}:
      Wm.disk_go(60n, [], 7)
    case _:
      Wm.pool_go(U32.to_nat((Wm.pool_rows() * Wm.gw() : U32)), [], 0,
        (Wm.gh() - Wm.pool_rows() : U32))

def Wm.base_grid(ct: CType) -> List<&2, List<&2, F32>>:
  match ct:
    case Sphere{}:
      Wm.stamp(Wm.zero(), (Wm.gw() / 2 : U32), (Wm.gh() / 2 : U32), 7.0)
    case _:
      Wm.zero()

def Wm.init_grid(ct: CType, rock: Bool) -> List<&2, List<&2, F32>>:
  match rock:
    case True{}:
      Wm.stamp(Wm.base_grid(ct), (Wm.gw() / 2 : U32), (Wm.gh() / 2 : U32),
        Wm.rock_imp())
    case False{}:
      Wm.base_grid(ct)

def Wm.init_eng(e: Eng, ct: CType, rock: Bool) -> Sim:
  match e:
    case EPart{}:
      Sim{Wm.zero(), Wm.zero(), Wm.init_parts(ct), 7, 0}
    case _:
      Sim{Wm.init_grid(ct, rock), Wm.zero(), [], 7, 0}

def Wm.init_sim(c: Cont) -> Sim:
  Cont{algo, ctype, rain, rock, fish} = c
  Wm.init_eng(Wm.engine(algo), ctype, rock)

# Names and config parsing
# ========================

def Wm.algo_name(a: Algo) -> String:
  match a:
    case Navier{}:
      "Navier-Stokes"
    case Shallow{}:
      "Shallow Water"
    case Stable{}:
      "Stable Fluids"
    case Lbm{}:
      "Lattice Boltzmann"
    case Ca{}:
      "Cellular Automata"
    case Sph{}:
      "SPH"
    case Pbf{}:
      "PBF"
    case Pic{}:
      "PIC"

def Wm.ctype_name(t: CType) -> String:
  match t:
    case Still{}:
      "still"
    case Stream{}:
      "stream"
    case Sphere{}:
      "sphere"

def Wm.ev_part(on: Bool, s: String) -> String:
  match on:
    case True{}:
      s
    case False{}:
      ""

def Wm.title(c: Cont) -> String:
  Cont{algo, ctype, rain, rock, fish} = c
  Wm.algo_name(algo) ++ " · " ++ Wm.ctype_name(ctype) ++ " · "
    ++ Wm.ev_part(rain, "rain ") ++ Wm.ev_part(rock, "rock ")
    ++ Wm.ev_part(fish, "fish")

def Wm.nth(xs: List<&2, String>, n: Nat) -> String:
  match xs n:
    case [] _:
      ""
    case h <> t 0n:
      h
    case h <> t 1n+j:
      Wm.nth(t, j)

def Wm.has_str(xs: List<&2, String>, +s: String) -> Bool:
  match xs:
    case []:
      False{}
    case h <> t:
      String.eq(h, s) || Wm.has_str(t, s)

# Parsing walks a list of (matches, value) pairs: the first that matches.
def Wm.algo_go(names: List<(Bool & Algo)>) -> Algo:
  match names:
    case []:
      Navier{}
    case h <> t:
      (hit, a) = h
      match hit:
        case True{}:
          a
        case False{}:
          Wm.algo_go(t)

def Wm.algo_of(+s: String) -> Algo:
  Wm.algo_go([(String.eq(s, "navier-stokes"), Navier{}),
    (String.eq(s, "ns"), Navier{}), (String.eq(s, "shallow"), Shallow{}),
    (String.eq(s, "stable"), Stable{}), (String.eq(s, "lbm"), Lbm{}),
    (String.eq(s, "ca"), Ca{}), (String.eq(s, "sph"), Sph{}),
    (String.eq(s, "pbf"), Pbf{}), (String.eq(s, "pic"), Pic{})])

def Wm.ctype_pick(stream: Bool, sphere: Bool) -> CType:
  match stream sphere:
    case True{} _:
      Stream{}
    case False{} True{}:
      Sphere{}
    case False{} False{}:
      Still{}


def Wm.ctype_of(+s: String) -> CType:
  Wm.ctype_pick(String.eq(s, "stream"), String.eq(s, "sphere"))

def Wm.parse_spec(s: String) -> Cont:
  +parts = String.split(s, ':')
  +evs = String.split(Wm.nth(parts, 2n), ',')
  Cont{Wm.algo_of(Wm.nth(parts, 0n)), Wm.ctype_of(Wm.nth(parts, 1n)),
    Wm.has_str(evs, "rain"), Wm.has_str(evs, "rock"),
    Wm.has_str(evs, "fish")}

def Wm.parse_all(specs: List<&2, String>) -> List<&2, Cont>:
  match specs:
    case []:
      []
    case s <> rest:
      Wm.parse_spec(s) <> Wm.parse_all(rest)

def Wm.custom(xs: List<&2, String>) -> Bool:
  match xs:
    case []:
      False{}
    case h <> t:
      True{}

def Wm.specs_of(custom: Bool) -> List<&2, String>:
  match custom:
    case True{}:
      Wm.args()
    case False{}:
      Wm.default_specs()

# Columns per row: the default lays one algorithm per row (3 events);
# anything custom uses two per row. At most four rows are shown.
def Wm.cols() -> U32:
  Wm.picku(Wm.custom(Wm.args()), 2, 3)

def Wm.conts() -> List<&2, Cont>:
  List.take(&2, Cont, Wm.parse_all(Wm.specs_of(Wm.custom(Wm.args()))),
    U32.to_nat((Wm.cols() * 4 : U32)))

def Wm.titles_of(cs: List<&2, Cont>) -> List<&2, String>:
  match cs:
    case []:
      []
    case c <> rest:
      Wm.title(c) <> Wm.titles_of(rest)

def Wm.titles() -> List<&2, String>:
  Wm.titles_of(Wm.conts())

def Wm.init_pans(cs: List<&2, Cont>) -> List<&2, Pan>:
  match cs:
    case []:
      []
    case Con{+c, rest}:
      Pan{c, Wm.init_sim(c)} <> Wm.init_pans(rest)

# JSON (the old pipeline: physics -> frames.json)
# ===============================================
# {"w":W,"h":H,"cols":C,"meta":[{"title":..,"kind":K}],
#  "frames":[{"t":T,"p":[{"g":[L x W*H],"fx","fy","fr","hf","rk","rx","ry","rr"}]}]}
# Each cell is an integer LEVEL 0..40 (grids: height; particles: density).

def Wm.bool01(b: Bool) -> String:
  match b:
    case True{}:
      "1"
    case False{}:
      "0"

def Wm.level(part: Bool, v: F32) -> U32:
  match part:
    case True{}:
      F32.to_u32(Wm.clampf((v * 8.0 : F32), 0.0, 40.0))
    case False{}:
      F32.to_u32(Wm.clampf(((v + 5.0) * 4.0 : F32), 0.0, 40.0))

def Wm.field(e: Eng, h: List<&2, List<&2, F32>>, ps: List<&2, Part>) ->
  List<&2, List<&2, F32>>:
  match e:
    case EPart{}:
      Wm.splat(ps)
    case _:
      h

def Wm.lv_row(xs: List<&2, F32>, +part: Bool, acc: List<&2, String>) ->
  List<&2, String>:
  match xs:
    case []:
      acc
    case v <> rest:
      Wm.lv_row(rest, part, U32.show(Wm.level(part, v)) <> acc)

def Wm.lv_rows(g: List<&2, List<&2, F32>>, +part: Bool, acc: List<&2, String>)
  -> List<&2, String>:
  match g:
    case []:
      acc
    case row <> rest:
      Wm.lv_rows(rest, part, Wm.lv_row(row, part, acc))

def Wm.fish_json(f: Fish, on: Bool) -> String:
  Fpos{fx, fy, right} = f
  ",\"fx\":" ++ U32.show(fx) ++ ",\"fy\":" ++ U32.show(fy) ++ ",\"fr\":"
    ++ Wm.bool01(right) ++ ",\"hf\":" ++ Wm.bool01(on)

def Wm.rock_json(r: Vec, on: Bool) -> String:
  Vec{rx, ry} = r
  ",\"rk\":" ++ Wm.bool01(on) ++ ",\"rx\":" ++ F32.show(rx) ++ ",\"ry\":"
    ++ F32.show(ry) ++ ",\"rr\":" ++ F32.show(Wm.rock_r())

def Wm.pan_json(p: Pan) -> String:
  Pan{c, s} = p
  Cont{algo, ctype, rain, rock, fish} = c
  Sim{h, v, ps, rng, +tick} = s
  +e = Wm.engine(algo)
  +part = Wm.is_part(e)
  "{\"g\":[" ++ String.join(List.reverse(&2, String,
    Wm.lv_rows(Wm.field(e, h, ps), part, [])), ",")
    ++ "]" ++ Wm.fish_json(Wm.fish_for(part, tick), fish)
    ++ Wm.rock_json(Wm.rock_pos(part, tick), rock) ++ "}"

def Wm.pans_json(ps: List<&2, Pan>) -> List<&2, String>:
  match ps:
    case []:
      []
    case p <> rest:
      Wm.pan_json(p) <> Wm.pans_json(rest)

def Wm.tick_of(ps: List<&2, Pan>) -> U32:
  match ps:
    case []:
      0
    case p <> rest:
      Pan{c, s} = p
      Sim{h, v, q, r, t} = s
      t

def Wm.step_pans(+n: Nat, ps: List<&2, Pan>) -> List<&2, Pan>:
  match ps:
    case []:
      []
    case p <> rest:
      Pan{+c, s} = p
      Pan{c, Wm.run_sim(n, c, s)} <> Wm.step_pans(n, rest)

def Wm.frames_go(n: Nat, +ps: List<&2, Pan>) -> List<&2, String>:
  match n:
    case 0n:
      []
    case 1n+k:
      ("{\"t\":" ++ U32.show(Wm.tick_of(ps)) ++ ",\"p\":["
        ++ String.join(Wm.pans_json(ps), ",") ++ "]}")
        <> Wm.frames_go(k, Wm.step_pans(Wm.frame_step(), ps))

def Wm.meta(c: Cont) -> String:
  Cont{+algo, ctype, rain, rock, fish} = c
  "{\"title\":\"" ++ Wm.title(Cont{algo, ctype, rain, rock, fish})
    ++ "\",\"kind\":" ++ U32.show(Wm.eng_num(Wm.engine(algo))) ++ "}"

def Wm.metas(cs: List<&2, Cont>) -> List<&2, String>:
  match cs:
    case []:
      []
    case c <> rest:
      Wm.meta(c) <> Wm.metas(rest)

def Wm.frames_json() -> String:
  +cs = Wm.conts()
  "{\"w\":" ++ U32.show(Wm.gw()) ++ ",\"h\":" ++ U32.show(Wm.gh())
    ++ ",\"cols\":" ++ U32.show(Wm.cols()) ++ ",\"meta\":["
    ++ String.join(Wm.metas(cs), ",")
    ++ "],\"frames\":["
    ++ String.join(Wm.frames_go(Wm.frames(), Wm.init_pans(cs)), ",") ++ "]}"

# Live view
# =========
# The window is a grid of panels, COLS across and up to four down. In 8-px
# blocks: a 2-block margin, then per panel a 2-block header strip, its
# 40 x 22 cells (one block each) and a 2-block gap; 42 blocks per panel
# across, 26 down. A frame is built bottom-up: one leaf Image per block,
# 128 x 128 blocks (the 1024-px quadtree root), merged four by four. A
# block under the fish or the rock is drawn per pixel; any other block is
# one Pix.

type Ovl is Data:
  ORock{cx: F32, cy: F32, r: F32}
  OFish{cx: F32, cy: F32, dir: F32}

# A panel ready to draw: its cell colours (rows), overlays and header tag.
type PView is Data:
  PView{colors: List<&2, List<&2, U32>>, ovs: List<&2, Ovl>, tag: U32}

def Wm.bg() -> U32:
  331028

def Wm.hdr(paused: Bool) -> U32:
  Wm.picku(paused, 3811848, 795186)

def Wm.air() -> U32:
  397851

def Wm.tag(e: Eng) -> U32:
  match e:
    case EWave{}:
      3112895
    case ERelax{}:
      4175528
    case ECa{}:
      10121174
    case EPart{}:
      8380415

def Wm.npanels() -> U32:
  U32.from_nat(List.length(&2, Cont, Wm.conts()))

def Wm.nrows() -> U32:
  +c = Wm.cols()
  U32.max(1, ((Wm.npanels() + c - 1) / c : U32))

def Wm.win_w() -> U32:
  (16 + Wm.cols() * 336 : U32)

def Wm.win_h() -> U32:
  (16 + Wm.nrows() * 208 : U32)

# Colours
# -------

def Wm.nthu(xs: List<&2, U32>, n: Nat) -> U32:
  match xs n:
    case [] _:
      0
    case h <> t 0n:
      h
    case h <> t 1n+j:
      Wm.nthu(t, j)

def Wm.ch(+a: U32, +b: U32, +k: Nat, +u: F32) -> U32:
  +av = U32.to_f32(((a >> k) .&. 255 : U32))
  +bv = U32.to_f32(((b >> k) .&. 255 : U32))
  (F32.to_u32((av + (bv - av) * u : F32)) << k : U32)

def Wm.mix(+a: U32, +b: U32, +u: F32) -> U32:
  (Wm.ch(a, b, 16n, u) .|. Wm.ch(a, b, 8n, u) .|. Wm.ch(a, b, 0n, u) : U32)

# The old page's colour ramps: t in [0, 1) across evenly spaced stops.
def Wm.ramp(t: F32, +stops: List<&2, U32>, +segs: F32) -> U32:
  +f = (Wm.clampf(t, 0.0, 0.9999) * segs : F32)
  +i = F32.to_u32(f)
  Wm.mix(Wm.nthu(stops, U32.to_nat(i)), Wm.nthu(stops, U32.to_nat((i + 1
    : U32))), (f - U32.to_f32(i) : F32))

def Wm.pal_go(n: Nat, +l: U32, +stops: List<&2, U32>, +segs: F32,
  +top: F32) -> List<&2, U32>:
  match n:
    case 0n:
      []
    case 1n+p:
      Wm.ramp((U32.to_f32(l) / top : F32), stops, segs)
        <> Wm.pal_go(p, (l + 1 : U32), stops, segs, top)

# Height field (grids): level / 40 on deep-to-foam blue.
def Wm.hpal() -> List<&2, U32>:
  Wm.pal_go(41n, 0, [400436, 1597598, 5686508, 14875391], 3.0, 40.0)

# Particle density: level / 30 on water blue (level 0 is air).
def Wm.wpal() -> List<&2, U32>:
  Wm.pal_go(41n, 0, [666702, 1731760, 9888255], 2.0, 30.0)

def Wm.cell_color(part: Bool, +l: U32, +hp: List<&2, U32>,
  +wp: List<&2, U32>) -> U32:
  match part:
    case True{}:
      Wm.picku(U32.is_eq(l, 0), Wm.air(), Wm.nthu(wp, U32.to_nat(l)))
    case False{}:
      Wm.nthu(hp, U32.to_nat(l))

def Wm.color_row(xs: List<&2, F32>, +part: Bool, +hp: List<&2, U32>,
  +wp: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case []:
      []
    case v <> rest:
      Wm.cell_color(part, Wm.level(part, v), hp, wp)
        <> Wm.color_row(rest, part, hp, wp)

def Wm.color_rows(g: List<&2, List<&2, F32>>, +part: Bool,
  +hp: List<&2, U32>, +wp: List<&2, U32>) -> List<&2, List<&2, U32>>:
  match g:
    case []:
      []
    case row <> rest:
      Wm.color_row(row, part, hp, wp) <> Wm.color_rows(rest, part, hp, wp)

# Overlays
# --------

def Wm.fish_r() -> F32:
  7.6

def Wm.fish_ovl(on: Bool, f: Fish, +x0: F32, +y0: F32) -> List<&2, Ovl>:
  match on:
    case True{}:
      Fpos{fx, fy, right} = f
      [OFish{(x0 + (U32.to_f32(fx) + 0.5) * 8.0 : F32),
        (y0 + (U32.to_f32(fy) + 0.5) * 8.0 : F32),
        Wm.pickf(right, 1.0, Wm.neg(1.0))}]
    case False{}:
      []

def Wm.rock_ovl(on: Bool, r: Vec, +x0: F32, +y0: F32) -> List<&2, Ovl>:
  match on:
    case True{}:
      Vec{rx, ry} = r
      [ORock{(x0 + (rx + 0.5) * 8.0 : F32), (y0 + (ry + 0.5) * 8.0 : F32),
        (Wm.rock_r() * 8.0 : F32)}]
    case False{}:
      []

def Wm.inside(+px: F32, +py: F32, x0: F32, y0: F32, x1: F32, y1: F32) -> Bool:
  ((x0 < px + 8.0) && (px < x1) && (y0 < py + 8.0) && (py < y1) : F32)

# Whether the block at (px, py) meets the overlay's box.
def Wm.ov_box(o: Ovl, +px: F32, +py: F32) -> Bool:
  match o:
    case ORock{+cx, +cy, r}:
      +e = (r + 1.0 : F32)
      Wm.inside(px, py, (cx - e : F32), (cy - e : F32), (cx + e : F32),
        (cy + e : F32))
    case OFish{+cx, +cy, dir}:
      +ex = (Wm.fish_r() * 1.7 + 1.0 : F32)
      +ey = (Wm.fish_r() * 0.55 + 1.0 : F32)
      Wm.inside(px, py, (cx - ex : F32), (cy - ey : F32), (cx + ex : F32),
        (cy + ey : F32))

def Wm.any_box(ovs: List<&2, Ovl>, +px: F32, +py: F32) -> Bool:
  match ovs:
    case []:
      False{}
    case o <> rest:
      Wm.ov_box(o, px, py) || Wm.any_box(rest, px, py)

def Wm.rock_px(+dx: F32, +dy: F32, +r: F32, under: U32) -> U32:
  +d2 = (dx * dx + dy * dy : F32)
  +hx = (dx + 0.3 * r : F32)
  +hy = (dy + 0.3 * r : F32)
  +hr = (0.34 * r : F32)
  Wm.picku((hx * hx + hy * hy < hr * hr : F32), 8555672,
    Wm.picku((d2 < (r - 0.75) * (r - 0.75) : F32), 5989488,
      Wm.picku((d2 < (r + 0.75) * (r + 0.75) : F32), 2764599, under)))

def Wm.fish_px(+lx: F32, +ly: F32, under: U32) -> U32:
  +r = Wm.fish_r()
  +ry = (r * 0.55 : F32)
  +ex = (lx - 0.45 * r : F32)
  +ey = (ly + 0.12 * r : F32)
  +eye = (ex * ex + ey * ey < 0.13 * r * (0.13 * r) : F32)
  +body = ((lx / r) * (lx / r) + (ly / ry) * (ly / ry) <= 1.0 : F32)
  +tail = (lx <= 0.0 - 0.8 * r : F32) && (0.0 - 1.7 * r <= lx : F32)
    && (Wm.absf(ly) <= ry * ((0.0 - 0.8 * r - lx) / (0.9 * r)) : F32)
  Wm.picku(eye && body, 1057326, Wm.picku(body || tail, 16764749, under))

def Wm.ov_one(o: Ovl, +fx: F32, +fy: F32, under: U32) -> U32:
  match o:
    case ORock{cx, cy, r}:
      Wm.rock_px((fx - cx : F32), (fy - cy : F32), r, under)
    case OFish{cx, cy, +dir}:
      Wm.fish_px(((fx - cx) * dir : F32), (fy - cy : F32), under)

# The pixel at the centre (fx, fy): the first overlay over it, else base.
def Wm.ov_px(ovs: List<&2, Ovl>, +fx: F32, +fy: F32, base: U32) -> U32:
  match ovs:
    case []:
      base
    case o <> rest:
      Wm.ov_one(o, fx, fy, Wm.ov_px(rest, fx, fy, base))

def Wm.detail(+d: Nat, +px: U32, +py: U32, +base: U32, +ovs: List<&2, Ovl>)
  -> Image:
  match d:
    case 0n:
      Pix{Wm.ov_px(ovs, (U32.to_f32(px) + 0.5 : F32),
        (U32.to_f32(py) + 0.5 : F32), base)}
    case 1n+e:
      +h = U32.shln(1, e)
      Qua{Wm.detail(e, px, py, base, ovs),
        Wm.detail(e, (px + h : U32), py, base, ovs),
        Wm.detail(e, px, (py + h : U32), base, ovs),
        Wm.detail(e, (px + h : U32), (py + h : U32), base, ovs)}

def Wm.leaf(hit: Bool, +c: U32, +px: U32, +py: U32, +ovs: List<&2, Ovl>) ->
  Image:
  match hit:
    case True{}:
      Wm.detail(3n, px, py, c, ovs)
    case False{}:
      Pix{c}

# Blocks
# ------

def Wm.bgs(n: Nat) -> List<&2, Image>:
  List.replicate(Image, n, Pix{Wm.bg()})

def Wm.cell_leaves(cs: List<&2, U32>, +bx: U32, +by: U32,
  +ovs: List<&2, Ovl>, tail: List<&2, Image>) -> List<&2, Image>:
  match cs:
    case []:
      tail
    case Con{+c, rest}:
      +px = (bx * 8 : U32)
      +py = (by * 8 : U32)
      Wm.leaf(Wm.any_box(ovs, U32.to_f32(px), U32.to_f32(py)), c, px, py, ovs)
        <> Wm.cell_leaves(rest, (bx + 1 : U32), by, ovs, tail)

def Wm.nthr(xs: List<&2, List<&2, U32>>, n: Nat) -> List<&2, U32>:
  match xs n:
    case [] _:
      []
    case h <> t 0n:
      h
    case h <> t 1n+j:
      Wm.nthr(t, j)

# One panel's 42 blocks of block row k of its band (0-1 header, 2-23 cells,
# 24-25 gap), onto tail.
def Wm.seg(hdr: Bool, cell: Bool, p: PView, +k: U32, +bx: U32, +by: U32,
  +hc: U32, tail: List<&2, Image>) -> List<&2, Image>:
  match hdr cell:
    case True{} _:
      PView{colors, ovs, +tag} = p
      Pix{tag} <> Pix{tag} <> List.append(&2, Image,
        List.replicate(Image, 38n, Pix{hc}), Pix{Wm.bg()} <> Pix{Wm.bg()}
        <> tail)
    case False{} True{}:
      PView{colors, ovs, tag} = p
      Wm.cell_leaves(Wm.nthr(colors, U32.to_nat((k - 2 : U32))), bx, by, ovs,
        Pix{Wm.bg()} <> Pix{Wm.bg()} <> tail)
    case False{} False{}:
      List.append(&2, Image, Wm.bgs(42n), tail)

def Wm.segs(pvs: List<&2, PView>, +k: U32, +bx: U32, +by: U32, +hc: U32) ->
  List<&2, Image>:
  match pvs:
    case []:
      Wm.bgs(U32.to_nat((128 - bx : U32)))
    case p <> rest:
      Wm.seg((k < 2 : U32), (k < 24 : U32), p, k, bx, by, hc,
        Wm.segs(rest, k, (bx + 42 : U32), by, hc))

def Wm.band_rows(n: Nat, +pvs: List<&2, PView>, +k: U32, +by: U32,
  +hc: U32, tail: List<&2, List<&2, Image>>) -> List<&2, List<&2, Image>>:
  match n:
    case 0n:
      tail
    case 1n+p:
      (Pix{Wm.bg()} <> Pix{Wm.bg()} <> Wm.segs(pvs, k, 2, by, hc))
        <> Wm.band_rows(p, pvs, (k + 1 : U32), (by + 1 : U32), hc, tail)

def Wm.pview(p: Pan, +x0: F32, +y0: F32, +hp: List<&2, U32>,
  +wp: List<&2, U32>) -> PView:
  Pan{c, s} = p
  Cont{algo, ctype, rain, rock, fish} = c
  Sim{h, v, ps, rng, +tick} = s
  +e = Wm.engine(algo)
  +part = Wm.is_part(e)
  PView{Wm.color_rows(Wm.field(e, h, ps), part, hp, wp),
    List.append(&2, Ovl, Wm.fish_ovl(fish, Wm.fish_for(part, tick), x0, y0),
      Wm.rock_ovl(rock, Wm.rock_pos(part, tick), x0, y0)), Wm.tag(e)}

def Wm.pviews(n: Nat, ps: List<&2, Pan>, +x0: F32, +y0: F32,
  +hp: List<&2, U32>, +wp: List<&2, U32>) -> List<&2, PView>:
  match n ps:
    case 0n _:
      []
    case _ Nil{}:
      []
    case 1n+k p <> rest:
      Wm.pview(p, x0, y0, hp, wp)
        <> Wm.pviews(k, rest, (x0 + 336.0 : F32), y0, hp, wp)

def Wm.bands(n: Nat, +ps: List<&2, Pan>, +band: U32, +hp: List<&2, U32>,
  +wp: List<&2, U32>, +hc: U32) -> List<&2, List<&2, Image>>:
  match n:
    case 0n:
      []
    case 1n+p:
      +cols = U32.to_nat(Wm.cols())
      +by = (2 + band * 26 : U32)
      +pvs = Wm.pviews(cols, ps, 16.0, U32.to_f32(((by + 2) * 8 : U32)), hp,
        wp)
      Wm.band_rows(26n, pvs, 0, by, hc,
        Wm.bands(p, List.drop(&2, Pan, ps, cols), (band + 1 : U32), hp, wp, hc))

# Merging
# -------

def Wm.merge_pix(same: Bool, +a: U32, b: U32, c: U32, d: U32) -> Image:
  match same:
    case True{}:
      Pix{a}
    case False{}:
      Qua{Pix{a}, Pix{b}, Pix{c}, Pix{d}}

def Wm.merge(a: Image, b: Image, c: Image, d: Image) -> Image:
  match a b c d:
    case Pix{+x} Pix{+y} Pix{+z} Pix{+w}:
      Wm.merge_pix(U32.is_eq(x, y) && U32.is_eq(x, z) && U32.is_eq(x, w), x,
        y, z, w)
    case a2 b2 c2 d2:
      Qua{a2, b2, c2, d2}

def Wm.pair_row(a: List<&2, Image>, b: List<&2, Image>) -> List<&2, Image>:
  match a b:
    case Con{a0, Con{a1, ar}} Con{b0, Con{b1, br}}:
      Wm.merge(a0, a1, b0, b1) <> Wm.pair_row(ar, br)
    case _ _:
      []

def Wm.pair_rows(rows: List<&2, List<&2, Image>>) ->
  List<&2, List<&2, Image>>:
  match rows:
    case Con{r0, Con{r1, rest}}:
      Wm.pair_row(r0, r1) <> Wm.pair_rows(rest)
    case _:
      []

def Wm.first_img(rows: List<&2, List<&2, Image>>) -> Image:
  match rows:
    case Con{Con{i, t}, rest}:
      i
    case _:
      Pix{Wm.bg()}

def Wm.collapse(n: Nat, rows: List<&2, List<&2, Image>>) -> Image:
  match n:
    case 0n:
      Wm.first_img(rows)
    case 1n+p:
      Wm.collapse(p, Wm.pair_rows(rows))

def Wm.draw(w: World) -> Image:
  World{pans, wait, every, paused} = w
  +full = Wm.bgs(128n)
  +top = {[full, full] : List<&2, List<&2, Image>>}
  +body = Wm.bands(4n, pans, 0, Wm.hpal(), Wm.wpal(), Wm.hdr(paused))
  +used = U32.to_nat((2 + Wm.nrows() * 26 : U32))
  Wm.collapse(7n, List.append(&2, List<&2, Image>, top, List.append(&2,
    List<&2, Image>, List.take(&2, List<&2, Image>, body, U32.to_nat((Wm.nrows()
    * 26 : U32))), List.replicate(List<&2, Image>, Nat.sub(128n, used), full))))

# The app
# =======

def Wm.init() -> World:
  World{Wm.init_pans(Wm.conts()), 0, Wm.every0(), False{}}

def Wm.view(w: World) -> World & Image:
  +w2 = w
  (w2, Wm.draw(w2))

# A panel restarts once it has run LOOP_TICKS steps.
def Wm.loop_fin(late: Bool, c: Cont, s: Sim) -> Sim:
  match late:
    case True{}:
      Wm.init_sim(c)
    case False{}:
      s

def Wm.loop_check(+c: Cont, +s: Sim) -> Sim:
  Sim{h, v, ps, rng, tick} = s
  Wm.loop_fin((tick >= Wm.loop_ticks() : U32), c, s)

def Wm.step_live(ps: List<&2, Pan>) -> List<&2, Pan>:
  match ps:
    case []:
      []
    case p <> rest:
      Pan{+c, s} = p
      Pan{c, Wm.loop_check(c, Wm.step_one(c, s))} <> Wm.step_live(rest)

def Wm.restart(ps: List<&2, Pan>) -> List<&2, Pan>:
  match ps:
    case []:
      []
    case p <> rest:
      Pan{+c, s} = p
      Pan{c, Wm.init_sim(c)} <> Wm.restart(rest)

def Wm.fire(due: Bool, w: World) -> World:
  match due:
    case True{}:
      World{pans, wait, +every, paused} = w
      World{Wm.step_live(pans), (every - 1 : U32), every, paused}
    case False{}:
      World{pans, wait, every, paused} = w
      World{pans, (wait - 1 : U32), every, paused}

def Wm.advance(w: World) -> World:
  World{pans, +wait, every, paused} = w
  match paused:
    case True{}:
      World{pans, wait, every, True{}}
    case False{}:
      Wm.fire(U32.is_eq(wait, 0), World{pans, wait, every, False{}})

# Keys: space pause, R restart, . one step, + / = faster, - slower.
def Wm.k_pause(w: World) -> World:
  World{pans, wait, every, paused} = w
  World{pans, 0, every, Bool.not(paused)}

def Wm.k_restart(w: World) -> World:
  World{pans, wait, every, paused} = w
  World{Wm.restart(pans), 0, every, paused}

def Wm.k_once(w: World) -> World:
  World{pans, wait, every, paused} = w
  World{Wm.step_live(pans), 0, every, paused}

def Wm.k_speed(+faster: Bool, w: World) -> World:
  World{pans, wait, +every, paused} = w
  World{pans, 0, Wm.picku(faster, U32.max(1, (every - 1 : U32)),
    U32.min(12, (every + 1 : U32))), paused}

def Wm.key(code: U32, w: World) -> Maybe<World>:
  match code:
    case 27:
      None{}
    case 32:
      Some{Wm.k_pause(w)}
    case 114:
      Some{Wm.k_restart(w)}
    case 46:
      Some{Wm.k_once(w)}
    case 43:
      Some{Wm.k_speed(True{}, w)}
    case 61:
      Some{Wm.k_speed(True{}, w)}
    case 45:
      Some{Wm.k_speed(False{}, w)}
    case _:
      Some{w}

def Wm.event(e: Event, w: World) -> Maybe<World>:
  match e:
    case Key{code, True{}}:
      Wm.key(code, w)
    case Close{}:
      None{}
    case _:
      Some{w}

def Wm.events(events: List<Event>, w: World) -> Maybe<World>:
  match events:
    case []:
      Some{w}
    case e <> rest:
      Maybe.bind(&1, World, World, Wm.event(e, w), w2 => Wm.events(rest, w2))

# The pure frame step the native and the web shells share.
def Wm.step(events: List<Event>, w: World) -> Maybe<World>:
  Maybe.bind(&1, World, World, Wm.events(events, w), w2 => Some{Wm.advance(w2)})

def Wm.tick(events: List<Event>, w: World) -> IO(Maybe<World>):
  IO.pure(Maybe<World>, Wm.step(events, w))

def main() -> IO(Unit):
  App.run(~World, ~App{Wm.view, Wm.tick}, "Water Movement", Wm.win_w(),
    Wm.win_h(), Wm.init())
