# Water Movement — ASCII fluid-simulation visualizer in Bend2.
#
# Unlike the other demos, this is NOT an App and uses NO IO and NO inline
# HTML/JS. It is a pure program: `main : String` runs the simulations and
# returns the result as JSON (FRAMES frames of per-cell levels + fish info).
#
# To build and watch it (the wrapper does the only IO — running this program,
# saving frames.json, and writing a standalone water.html that animates it in a
# browser, auto-looping like a gif):
#
#   sh demo/water_movement/play.sh        # opens demo/water_movement/water.html
#
# To just print the raw JSON:
#
#   bun run bend/src/CLI.ts demo/water_movement/main.bend -o /tmp/w.js && bun /tmp/w.js
#
# Arguments. Because a pure program can't read argv, the "command line" is the
# `args` value below — a List of container specs "algo:container:events"
# (events comma-separated). Edit it to compare setups. If it is empty, four
# default containers are shown: Navier–Stokes, SPH, PBF and LBM, all still
# water with a swimming fish.
#
#   algo      : navier-stokes | sph | pbf | lbm | shallow | ca | pic | stable
#   container : still | stream | sphere
#   events    : rain , rock , fish  (any combination, or omit)
#
# Each container is simulated on its own small grid and laid out two per row.

# ============================================================
# Configuration (the "arguments")
# ============================================================

# Edit this. Example:
#   args : List(String) = ["sph:sphere:rock", "lbm:stream:rain,fish"]
args : List(String) = []

# Default: every algorithm × each event individually, still water, one
# algorithm per row (3 columns = rain / rock / fish).
def default_specs() -> List(String):
  [ "navier-stokes:still:rain", "navier-stokes:still:rock", "navier-stokes:still:fish",
    "sph:still:rain",           "sph:still:rock",           "sph:still:fish",
    "pbf:still:rain",           "pbf:still:rock",           "pbf:still:fish",
    "lbm:still:rain",           "lbm:still:rock",           "lbm:still:fish" ]

# ============================================================
# Types
# ============================================================

type Algo {
  navier{}    # grid wave (Navier–Stokes family)
  shallow{}   # grid wave (Shallow Water)
  stable{}    # grid wave (Stable Fluids family)
  lbm{}       # grid relaxation (Lattice Boltzmann, BGK-style)
  ca{}        # cellular automata
  sph{}       # particles (Smoothed Particle Hydrodynamics)
  pbf{}       # particles (Position-Based Fluids)
  pic{}       # particles (Particle-in-Cell)
}

type CType {
  still{}
  stream{}
  sphere{}
}

# A configured container.
type Cont {
  cont{algo: Algo, ctype: CType, rain: Bool, rock: Bool, fish: Bool}
}

# A particle (grid-space float coords + velocity).
type Part {
  part{x: F32, y: F32, vx: F32, vy: F32}
}

# Simulation state: height/velocity grids (grid engines) OR particles
# (particle engines), plus a per-sim rng and tick.
type Sim {
  sim{h: Grid(F32), v: Grid(F32), ps: List(Part), rng: U32, tick: U32}
}

type Vec {
  vec{x: F32, y: F32}
}

type Fish {
  fpos{fx: U32, fy: U32, right: Bool}
}

# ============================================================
# Constants
# ============================================================

W : U32 = 40          # grid width per panel
H : U32 = 22          # grid height per panel
WF : F32 = 40.0
HF : F32 = 22.0

# The program is pure, so it can't animate by itself. Instead it emits FRAMES
# snapshots (the sim advanced FRAME_STEP steps between each) as JSON; the
# browser renderer (built by play.sh / build.mjs) loops through them.
FRAMES     : U32 = 30
FRAME_STEP : U32 = 2

# Wave engine.
WAVE_C2   : F32 = 0.20
WAVE_DAMP : F32 = 0.99
# Relaxation (LBM) engine — fraction pulled toward the neighbor average.
RELAX_K : F32 = 0.22
# Cellular automata — flow fraction and threshold.
CA_FLOW : F32 = 0.25
CA_THRESH : F32 = 0.4

# Particle engine.
P_GRAV  : F32 = 0.05
P_RAD   : F32 = 1.0     # interaction radius
P_DAMP  : F32 = 0.92
SPH_STIFF : F32 = 0.05
PBF_STIFF : F32 = 0.13
MAXP : U32 = 80
POOL_ROWS : U32 = 9     # bottom rows the particle pool fills

# Events.
ROCK_IMP : F32 = 9.0
RAIN_IMP : F32 = 3.0
RAIN_EVERY : U32 = 3      # a raindrop falls every this many ticks
# A swimming fish and a sinking rock shove nearby particles (so they react
# on the particle engines too).
FISH_PUSH_R : F32 = 2.6
FISH_PUSH   : F32 = 0.16
ROCK_PUSH_R : F32 = 3.4
ROCK_PUSH   : F32 = 0.55
ROCK_R      : F32 = 2.2   # rock radius in cells (drawing + grid impulse)
ROCK_FALL   : F32 = 1.0   # rock fall speed (cells/tick) before it rests

# ============================================================
# Small helpers
# ============================================================

def bor(a: Bool, b: Bool) -> Bool:
  match a:
    case true{}:
      true{}
    case false{}:
      b

def rng_next(s: U32) -> U32:
  (s * 1103515245) + 12345

def rand_unit(r: U32) -> F32:
  F32/div(U32/to_f32(r % 2000), 1000.0) - 1.0

def clampf(v: F32, lo: F32, hi: F32) -> F32:
  F32/max(lo, F32/min(hi, v))

def clampu(x: U32, n: U32) -> U32:
  if U32/lt(x, n):
    x
  else:
    U32/saturating_sub(n, 1)

def cont_algo(c: Cont) -> Algo:
  match c:
    case cont{a, _, _, _, _}:
      a

def has_fish(c: Cont) -> Bool:
  match c:
    case cont{_, _, _, _, fish}:
      fish

def has_rock(c: Cont) -> Bool:
  match c:
    case cont{_, _, _, rock, _}:
      rock

def has_rain(c: Cont) -> Bool:
  match c:
    case cont{_, _, rain, _, _}:
      rain

# Fish depth depends on the view: grid engines are top-down (mid plane);
# particle engines are side-on, so the fish swims SUBMERGED in the pool (about
# halfway down it) rather than floating on the surface.
def fish_y(ek: U32) -> U32:
  match U32/eq(ek, 3):
    case true{}:
      U32/saturating_sub(H, POOL_ROWS // 2)
    case false{}:
      H // 2

# Fish position from the tick (swims left/right, bouncing off the walls).
def fish_for(ek: U32, tick: U32) -> Fish:
  span = U32/saturating_sub(W, 4);
  period = span + span;
  ph = tick % period;
  if U32/lt(ph, span):
    fpos{2 + ph, fish_y(ek), true{}}
  else:
    fpos{2 + U32/saturating_sub(period, ph), fish_y(ek), false{}}

# Rock position. Side-on (particles): it falls from the top and rests on the
# floor. Top-down (grids): it sits at the centre (where it landed).
def rock_pos(ek: U32, tick: U32) -> Vec:
  match U32/eq(ek, 3):
    case true{}:
      vec{WF * 0.5, F32/min(1.0 + (U32/to_f32(tick) * ROCK_FALL), HF - 2.0)}
    case false{}:
      vec{WF * 0.5, HF * 0.5}

# ============================================================
# Grid helpers
# ============================================================

def gget(g: Grid(F32), x: U32, y: U32) -> F32:
  match Grid/get(F32, 0.0, g, x, y):
    case some{v}:
      v
    case none{}:
      0.0

def cl_lo(x: U32) -> U32:
  U32/saturating_sub(x, 1)

def cl_hi(x: U32, n: U32) -> U32:
  if U32/lt(x + 1, n):
    x + 1
  else:
    U32/saturating_sub(n, 1)

# 4-neighbor average (reflective walls).
def avg4(g: Grid(F32), x: U32, y: U32) -> F32:
  l = gget(g, cl_lo(x), y);
  r = gget(g, cl_hi(x, W), y);
  u = gget(g, x, cl_lo(y));
  d = gget(g, x, cl_hi(y, H));
  F32/div(((l + r) + (u + d)), 4.0)

# Discrete Laplacian (reflective walls).
def lap(g: Grid(F32), x: U32, y: U32) -> F32:
  c = gget(g, x, y);
  l = gget(g, cl_lo(x), y);
  r = gget(g, cl_hi(x, W), y);
  u = gget(g, x, cl_lo(y));
  d = gget(g, x, cl_hi(y, H));
  ((l + r) + (u + d)) - (4.0 * c)

def zero_grid() -> Grid(F32):
  Grid/fill(F32, W, H, 0.0)

# ============================================================
# Engine: WAVE (Navier–Stokes / Shallow Water / Stable Fluids family)
# ============================================================

def wave_v(oldh: Grid(F32), oldv: Grid(F32), acc: Grid(F32), x: U32, y: U32) -> Grid(F32):
  if U32/gte(y, H):
    acc
  else:
    if U32/gte(x, W):
      wave_v(oldh, oldv, acc, 0, y + 1)
    else:
      nv = (gget(oldv, x, y) + (WAVE_C2 * lap(oldh, x, y))) * WAVE_DAMP;
      wave_v(oldh, oldv, Grid/set(F32, acc, x, y, nv), x + 1, y)

def wave_h(oldh: Grid(F32), newv: Grid(F32), acc: Grid(F32), x: U32, y: U32) -> Grid(F32):
  if U32/gte(y, H):
    acc
  else:
    if U32/gte(x, W):
      wave_h(oldh, newv, acc, 0, y + 1)
    else:
      nh = gget(oldh, x, y) + gget(newv, x, y);
      wave_h(oldh, newv, Grid/set(F32, acc, x, y, nh), x + 1, y)

def wave_step(h: Grid(F32), v: Grid(F32)) -> Sim:
  nv = wave_v(h, v, zero_grid(), 0, 0);
  nh = wave_h(h, nv, zero_grid(), 0, 0);
  sim{nh, nv, [], 0, 0}

# ============================================================
# Engine: RELAX (Lattice Boltzmann, BGK-style diffusion)
# ============================================================

def relax_go(oldh: Grid(F32), acc: Grid(F32), x: U32, y: U32) -> Grid(F32):
  if U32/gte(y, H):
    acc
  else:
    if U32/gte(x, W):
      relax_go(oldh, acc, 0, y + 1)
    else:
      c  = gget(oldh, x, y);
      nh = c + (RELAX_K * (avg4(oldh, x, y) - c));
      relax_go(oldh, Grid/set(F32, acc, x, y, nh), x + 1, y)

# ============================================================
# Engine: CELLULAR AUTOMATA (height redistribution toward neighbors)
# ============================================================

def ca_flow1(c: F32, nb: F32) -> F32:
  d = c - nb;
  if F32/lt(CA_THRESH, d):
    CA_FLOW * d
  else:
    0.0

def ca_go(oldh: Grid(F32), acc: Grid(F32), x: U32, y: U32) -> Grid(F32):
  if U32/gte(y, H):
    acc
  else:
    if U32/gte(x, W):
      ca_go(oldh, acc, 0, y + 1)
    else:
      c  = gget(oldh, x, y);
      fl = ca_flow1(c, gget(oldh, cl_lo(x), y));
      fr = ca_flow1(c, gget(oldh, cl_hi(x, W), y));
      fu = ca_flow1(c, gget(oldh, x, cl_lo(y)));
      fd = ca_flow1(c, gget(oldh, x, cl_hi(y, H)));
      # received from neighbors (they give us their excess over us)
      gl = ca_flow1(gget(oldh, cl_lo(x), y), c);
      gr = ca_flow1(gget(oldh, cl_hi(x, W), y), c);
      gu = ca_flow1(gget(oldh, x, cl_lo(y)), c);
      gd = ca_flow1(gget(oldh, x, cl_hi(y, H)), c);
      out = (((fl + fr) + (fu + fd)));
      inc = (((gl + gr) + (gu + gd)));
      nh = (c - out) + inc;
      ca_go(oldh, Grid/set(F32, acc, x, y, nh), x + 1, y)

# ============================================================
# Engine: PARTICLES (SPH / PBF / PIC)
# ============================================================

def repulse_go(sx: F32, sy: F32, ps: List(Part), stiff: F32, ax: F32, ay: F32) -> Vec:
  match ps:
    case []:
      vec{ax, ay}
    case hd<>tl:
      match hd:
        case part{px, py, _, _}:
          dx = sx - px;
          dy = sy - py;
          d2 = (dx * dx) + (dy * dy);
          hit = Bool/and(F32/lt(0.0001, d2), F32/lt(d2, P_RAD * P_RAD));
          match hit:
            case false{}:
              repulse_go(sx, sy, tl, stiff, ax, ay)
            case true{}:
              d = F32/sqrt(d2);
              push = stiff * (F32/div(P_RAD - d, P_RAD));
              ux = F32/div(dx, d);
              uy = F32/div(dy, d);
              repulse_go(sx, sy, tl, stiff, ax + (ux * push), ay + (uy * push))

# Horizontal wall bounce.
def pwx(nx: F32, vx: F32) -> Vec:
  if F32/lt(nx, 0.6):
    vec{0.6, F32/abs(vx) * P_DAMP}
  else:
    if F32/lt(WF - 0.6, nx):
      vec{WF - 0.6, (0.0 - F32/abs(vx)) * P_DAMP}
    else:
      vec{nx, vx}

def pwy(ny: F32, vy: F32) -> Vec:
  if F32/lt(ny, 0.6):
    vec{0.6, F32/abs(vy) * P_DAMP}
  else:
    if F32/lt(HF - 0.6, ny):
      vec{HF - 0.6, (0.0 - F32/abs(vy)) * P_DAMP}
    else:
      vec{ny, vy}

def part_update(self: Part, all: List(Part), stiff: F32) -> Part:
  match self:
    case part{x, y, vx, vy}:
      match repulse_go(x, y, all, stiff, 0.0, 0.0):
        case vec{rx, ry}:
          vx1 = (vx + rx) * P_DAMP;
          vy1 = ((vy + ry) + P_GRAV) * P_DAMP;
          match pwx(x + vx1, vx1):
            case vec{nx, nvx}:
              match pwy(y + vy1, vy1):
                case vec{ny, nvy}:
                  part{nx, ny, nvx, nvy}

# Push one particle away from a disturber at (cx, cy) within radius r.
def push_one(p: Part, cx: F32, cy: F32, r: F32, s: F32) -> Part:
  match p:
    case part{x, y, vx, vy}:
      dx = x - cx;
      dy = y - cy;
      d2 = (dx * dx) + (dy * dy);
      if F32/lt(d2, r * r):
        d  = F32/sqrt(d2 + 0.01);
        ux = F32/div(dx, d);
        uy = F32/div(dy, d);
        f  = s * (F32/div(r - d, r));
        part{x, y, vx + (ux * f), vy + (uy * f)}
      else:
        p

def push_all(ps: List(Part), cx: F32, cy: F32, r: F32, s: F32) -> List(Part):
  List/map(Part, Part, ps, (p) => push_one(p, cx, cy, r, s))

def apply_fish_parts(on: Bool, ps: List(Part), tick: U32) -> List(Part):
  match on:
    case false{}:
      ps
    case true{}:
      match fish_for(3, tick):
        case fpos{fx, fy, _}:
          push_all(ps, U32/to_f32(fx) + 0.5, U32/to_f32(fy) + 0.5, FISH_PUSH_R, FISH_PUSH)

def apply_rock_parts(on: Bool, ps: List(Part), tick: U32) -> List(Part):
  match on:
    case false{}:
      ps
    case true{}:
      match rock_pos(3, tick):
        case vec{rx, ry}:
          push_all(ps, rx, ry, ROCK_PUSH_R, ROCK_PUSH)

# Rain on particles: drop a new droplet in from the top every few ticks.
def add_rain_part(on: Bool, ps: List(Part), tick: U32) -> List(Part):
  match on:
    case false{}:
      ps
    case true{}:
      if U32/eq(tick % RAIN_EVERY, 0):
        px = U32/to_f32(((tick * 13) % U32/saturating_sub(W, 4)) + 2) + 0.5;
        part{px, 1.0, 0.0, 0.4} <> ps
      else:
        ps

def part_step(ps: List(Part), stiff: F32, fish_on: Bool, rock_on: Bool, rain_on: Bool, tick: U32) -> List(Part):
  base = List/map(Part, Part, ps, (p) => part_update(p, ps, stiff));
  rained = add_rain_part(rain_on, base, tick);
  apply_rock_parts(rock_on, apply_fish_parts(fish_on, rained, tick), tick)

# Splat particles into a density grid for rendering.
def splat_go(ps: List(Part), acc: Grid(F32)) -> Grid(F32):
  match ps:
    case []:
      acc
    case hd<>tl:
      match hd:
        case part{x, y, _, _}:
          cx = clampu(F32/to_u32(x), W);
          cy = clampu(F32/to_u32(y), H);
          splat_go(tl, Grid/set(F32, acc, cx, cy, gget(acc, cx, cy) + 1.0))

# ============================================================
# Engine dispatch
# ============================================================

# 0 = wave, 1 = relax, 2 = ca, 3 = particles.
def engine_kind(a: Algo) -> U32:
  match a:
    case navier{}:
      0
    case shallow{}:
      0
    case stable{}:
      0
    case lbm{}:
      1
    case ca{}:
      2
    case sph{}:
      3
    case pbf{}:
      3
    case pic{}:
      3

def part_stiff(a: Algo) -> F32:
  match a:
    case pbf{}:
      PBF_STIFF
    case _:
      SPH_STIFF

# ============================================================
# Events
# ============================================================

# A soft circular impulse added to a height grid (radius ~2 cells).
def stamp_add(r2: F32, amp: F32) -> F32:
  if F32/lt(r2, 4.0):
    amp * (F32/div(4.0 - r2, 4.0))
  else:
    0.0

def stamp_go(g: Grid(F32), cx: U32, cy: U32, amp: F32, x: U32, y: U32) -> Grid(F32):
  if U32/gte(y, H):
    g
  else:
    if U32/gte(x, W):
      stamp_go(g, cx, cy, amp, 0, y + 1)
    else:
      ddx = U32/to_f32(U32/saturating_sub(x, cx) + U32/saturating_sub(cx, x));
      ddy = U32/to_f32(U32/saturating_sub(y, cy) + U32/saturating_sub(cy, y));
      r2  = (ddx * ddx) + (ddy * ddy);
      g2  = Grid/set(F32, g, x, y, gget(g, x, y) + stamp_add(r2, amp));
      stamp_go(g2, cx, cy, amp, x + 1, y)

def stamp(g: Grid(F32), cx: U32, cy: U32, amp: F32) -> Grid(F32):
  stamp_go(g, cx, cy, amp, 0, 0)

# Rain: occasionally add a small impulse near the top.
def rain_grid(g: Grid(F32), rng: U32, tick: U32) -> Grid(F32):
  if U32/eq(tick % 3, 0):
    cx = (rng % U32/saturating_sub(W, 2)) + 1;
    stamp(g, cx, 2, RAIN_IMP)
  else:
    g

# Fish wake on a grid: a small dimple at the fish cell each step.
def fish_grid(g: Grid(F32), ek: U32, tick: U32) -> Grid(F32):
  match fish_for(ek, tick):
    case fpos{fx, fy, _}:
      stamp(g, fx, fy, 0.0 - 0.4)

# ============================================================
# Per-step update for one container.
# ============================================================

def grid_substep(ek: U32, h: Grid(F32), v: Grid(F32)) -> Sim:
  match ek:
    case 0:
      wave_step(h, v)
    case 1:
      sim{relax_go(h, zero_grid(), 0, 0), v, [], 0, 0}
    case _:
      sim{ca_go(h, zero_grid(), 0, 0), v, [], 0, 0}

# Stream: inject a travelling wave at the left edge.
def stream_col(g: Grid(F32), amp: F32, y: U32) -> Grid(F32):
  if U32/gte(y, H):
    g
  else:
    stream_col(Grid/set(F32, g, 0, y, amp), amp, y + 1)

def stream_inflow(ct: CType, g: Grid(F32), tick: U32) -> Grid(F32):
  match ct:
    case stream{}:
      stream_col(g, F32/sin(U32/to_f32(tick) * 0.6) * 3.0, 0)
    case _:
      g

def apply_rain(on: Bool, h: Grid(F32), rng: U32, tick: U32) -> Grid(F32):
  match on:
    case true{}:
      rain_grid(h, rng, tick)
    case false{}:
      h

def apply_fish(on: Bool, h: Grid(F32), ek: U32, tick: U32) -> Grid(F32):
  match on:
    case true{}:
      fish_grid(h, ek, tick)
    case false{}:
      h

# Apply events to a height grid after the physics substep.
def grid_events(c: Cont, h: Grid(F32), rng: U32, tick: U32) -> Grid(F32):
  match c:
    case cont{algo, ctype, rain, _, fish}:
      stream_inflow(ctype, apply_fish(fish, apply_rain(rain, h, rng, tick), engine_kind(algo), tick), tick)

def step_one(c: Cont, s: Sim) -> Sim:
  match s:
    case sim{h, v, ps, rng, tick}:
      a = cont_algo(c);
      ek = engine_kind(a);
      rng1 = rng_next(rng);
      tick1 = tick + 1;
      match U32/eq(ek, 3):
        case true{}:
          ps1 = part_step(ps, part_stiff(a), has_fish(c), has_rock(c), has_rain(c), tick1);
          sim{h, v, ps1, rng1, tick1}
        case false{}:
          match grid_substep(ek, h, v):
            case sim{h1, v1, _, _, _}:
              h2 = grid_events(c, h1, rng1, tick1);
              sim{h2, v1, ps, rng1, tick1}

def run_sim(c: Cont, n: U32, s: Sim) -> Sim:
  if U32/eq(n, 0):
    s
  else:
    run_sim(c, U32/saturating_sub(n, 1), step_one(c, s))

# ============================================================
# Initial conditions
# ============================================================

def disk_go(acc: List(Part), n: U32, rng: U32) -> List(Part):
  if U32/eq(n, 0):
    acc
  else:
    r1 = rng_next(rng);
    r2 = rng_next(r1);
    px = (WF * 0.5) + (rand_unit(r1) * 3.0);
    py = (HF * 0.4) + (rand_unit(r2) * 3.0);
    disk_go(part{px, py, 0.0, 0.0} <> acc, U32/saturating_sub(n, 1), r2)

# A pool of particles filling the lower part of the tank.
def pool_go(acc: List(Part), x: U32, y: U32) -> List(Part):
  if U32/gte(y, H):
    acc
  else:
    if U32/gte(x, W):
      pool_go(acc, 0, y + 1)
    else:
      px = U32/to_f32(x) + 0.5;
      py = U32/to_f32(y) + 0.5;
      pool_go(part{px, py, 0.0, 0.0} <> acc, x + 1, y)

# The particle pool, or a droplet disk for the "sphere" container. (The rock's
# effect is applied dynamically each step as it falls — see apply_rock_parts.)
def init_particles(ct: CType) -> List(Part):
  match ct:
    case sphere{}:
      disk_go([], 60, 7)
    case _:
      pool_go([], 0, U32/saturating_sub(H, POOL_ROWS))

def base_grid(ct: CType) -> Grid(F32):
  match ct:
    case sphere{}:
      stamp(zero_grid(), W // 2, H // 2, 7.0)
    case _:
      zero_grid()

def init_grid(ct: CType, rock: Bool) -> Grid(F32):
  match rock:
    case true{}:
      stamp(base_grid(ct), W // 2, H // 2, ROCK_IMP)
    case false{}:
      base_grid(ct)

def init_sim(c: Cont) -> Sim:
  match c:
    case cont{algo, ctype, _, rock, _}:
      match U32/eq(engine_kind(algo), 3):
        case true{}:
          sim{zero_grid(), zero_grid(), init_particles(ctype), 7, 0}
        case false{}:
          sim{init_grid(ctype, rock), zero_grid(), [], 7, 0}

# ============================================================
# Rendering — the field a panel shows, and its title/colour metadata.
# (Pixels are drawn by the external browser renderer; here we only produce
# the numbers + labels it consumes.)
# ============================================================

def field_of(c: Cont, s: Sim) -> Grid(F32):
  match s:
    case sim{h, _, ps, _, _}:
      match U32/eq(engine_kind(cont_algo(c)), 3):
        case true{}:
          splat_go(ps, zero_grid())
        case false{}:
          h

def algo_name(a: Algo) -> String:
  match a:
    case navier{}:
      "Navier-Stokes"
    case shallow{}:
      "Shallow Water"
    case stable{}:
      "Stable Fluids"
    case lbm{}:
      "Lattice Boltzmann"
    case ca{}:
      "Cellular Automata"
    case sph{}:
      "SPH"
    case pbf{}:
      "PBF"
    case pic{}:
      "PIC"

def ctype_name(t: CType) -> String:
  match t:
    case still{}:
      "still"
    case stream{}:
      "stream"
    case sphere{}:
      "sphere"

def ev_part(on: Bool, s: String) -> String:
  match on:
    case true{}:
      s
    case false{}:
      ""

def ev_name(c: Cont) -> String:
  match c:
    case cont{_, _, rain, rock, fish}:
      (ev_part(rain, "rain ") ++ ev_part(rock, "rock ")) ++ ev_part(fish, "fish")

# ============================================================
# Config parsing
# ============================================================

def nth(xs: List(String), i: U32) -> String:
  match xs:
    case []:
      ""
    case h<>t:
      if U32/eq(i, 0):
        h
      else:
        nth(t, U32/saturating_sub(i, 1))

def has_str(xs: List(String), s: String) -> Bool:
  match xs:
    case []:
      false{}
    case h<>t:
      if String/eq(h, s):
        true{}
      else:
        has_str(t, s)

def algo_of(s: String) -> Algo:
  if bor(String/eq(s, "navier-stokes"), String/eq(s, "ns")):
    navier{}
  else:
    if String/eq(s, "shallow"):
      shallow{}
    else:
      if String/eq(s, "stable"):
        stable{}
      else:
        if String/eq(s, "lbm"):
          lbm{}
        else:
          if String/eq(s, "ca"):
            ca{}
          else:
            if String/eq(s, "sph"):
              sph{}
            else:
              if String/eq(s, "pbf"):
                pbf{}
              else:
                if String/eq(s, "pic"):
                  pic{}
                else:
                  navier{}

def ctype_of(s: String) -> CType:
  if String/eq(s, "stream"):
    stream{}
  else:
    if String/eq(s, "sphere"):
      sphere{}
    else:
      still{}

def parse_spec(s: String) -> Cont:
  parts = String/split(s, ':');
  a  = algo_of(nth(parts, 0));
  t  = ctype_of(nth(parts, 1));
  evs = String/split(nth(parts, 2), ',');
  cont{a, t, has_str(evs, "rain"), has_str(evs, "rock"), has_str(evs, "fish")}

def parse_all(specs: List(String)) -> List(Cont):
  List/map(String, Cont, specs, parse_spec)

def effective_specs() -> List(String):
  match args:
    case []:
      default_specs()
    case _:
      args

# ============================================================
# Main
# ============================================================

def init_all(cs: List(Cont)) -> List(Sim):
  List/map(Cont, Sim, cs, init_sim)

# Advance every container by FRAME_STEP steps.
def step_all(cs: List(Cont), ss: List(Sim)) -> List(Sim):
  List/zip_with(Cont, Sim, Sim, cs, ss, (c) => (s) => run_sim(c, FRAME_STEP, s))

# Build the whole filmstrip: FRAMES snapshots joined by FRAME_SEP.
# ============================================================
# JSON output (consumed by the external browser renderer)
#
# Shape:
#   {"w":30,"h":15,
#    "meta":[{"title":"...","kind":K}, ...],          // per panel (K=engine)
#    "frames":[ {"t":T,"p":[ {"g":[L,...W*H],"fx":,"fy":,"fr":,"hf":} , ... ]} , ... ]}
# Each cell is an integer LEVEL 0..40 (grid: height; particles: density), so the
# data stays small and the renderer is free to colour it however it likes.
# ============================================================

def drop1(s: String) -> String:
  match s:
    case []:
      ""
    case _<>t:
      t

def bool01(b: Bool) -> String:
  match b:
    case true{}:
      "1"
    case false{}:
      "0"

def cell_level(ek: U32, v: F32) -> U32:
  match U32/eq(ek, 3):
    case true{}:
      F32/to_u32(clampf(v * 8.0, 0.0, 40.0))
    case false{}:
      F32/to_u32(clampf((v + 5.0) * 4.0, 0.0, 40.0))

# One grid serialized as ",L,L,..." (leading comma stripped by the caller).
def lv_row(g: Grid(F32), ek: U32, y: U32, x: U32) -> String:
  if U32/gte(x, W):
    ""
  else:
    ("," ++ U32/show(cell_level(ek, gget(g, x, y)))) ++ lv_row(g, ek, y, x + 1)

def lv_rows(g: Grid(F32), ek: U32, y: U32) -> String:
  if U32/gte(y, H):
    ""
  else:
    lv_row(g, ek, y, 0) ++ lv_rows(g, ek, y + 1)

def grid_json(g: Grid(F32), ek: U32) -> String:
  "[" ++ (drop1(lv_rows(g, ek, 0)) ++ "]")

def panel_frame_json(c: Cont, s: Sim) -> String:
  match s:
    case sim{_, _, _, _, tk}:
      ek = engine_kind(cont_algo(c));
      match fish_for(ek, tk):
        case fpos{fx, fy, right}:
          match rock_pos(ek, tk):
            case vec{rx, ry}:
              fsh = (",\"fx\":" ++ U32/show(fx)) ++ ((",\"fy\":" ++ U32/show(fy)) ++ ((",\"fr\":" ++ bool01(right)) ++ (",\"hf\":" ++ bool01(has_fish(c)))));
              rck = (",\"rk\":" ++ bool01(has_rock(c))) ++ ((",\"rx\":" ++ F32/show(rx)) ++ ((",\"ry\":" ++ F32/show(ry)) ++ ((",\"rr\":" ++ F32/show(ROCK_R)) ++ "}")));
              "{\"g\":" ++ (grid_json(field_of(c, s), ek) ++ (fsh ++ rck))

def tick_of(ss: List(Sim)) -> U32:
  match ss:
    case []:
      0
    case h<>_:
      match h:
        case sim{_, _, _, _, tk}:
          tk

def pcsv(cs: List(Cont), ss: List(Sim)) -> String:
  match cs:
    case []:
      ""
    case c<>cr:
      match ss:
        case []:
          ""
        case s<>sr:
          ("," ++ panel_frame_json(c, s)) ++ pcsv(cr, sr)

def frame_json(cs: List(Cont), ss: List(Sim)) -> String:
  ("{\"t\":" ++ U32/show(tick_of(ss))) ++ ((",\"p\":[" ++ drop1(pcsv(cs, ss))) ++ "]}")

def frames_json(cs: List(Cont), ss: List(Sim), n: U32) -> String:
  if U32/eq(n, 0):
    ""
  else:
    ("," ++ frame_json(cs, ss)) ++ frames_json(cs, step_all(cs, ss), U32/saturating_sub(n, 1))

def title_str(c: Cont) -> String:
  match c:
    case cont{algo, ctype, _, _, _}:
      ((algo_name(algo) ++ " · ") ++ ctype_name(ctype)) ++ (" · " ++ ev_name(c))

def panel_meta(c: Cont) -> String:
  match c:
    case cont{algo, _, _, _, _}:
      ("{\"title\":\"" ++ title_str(c)) ++ ("\",\"kind\":" ++ (U32/show(engine_kind(algo)) ++ "}"))

def mgo(cs: List(Cont)) -> String:
  match cs:
    case []:
      ""
    case c<>cr:
      ("," ++ panel_meta(c)) ++ mgo(cr)

def meta_json(cs: List(Cont)) -> String:
  "[" ++ (drop1(mgo(cs)) ++ "]")

# Columns per row: the no-args default lays one algorithm per row (3 events),
# anything custom uses two per row.
def cols_count() -> U32:
  match args:
    case []:
      3
    case _:
      2

main : String =
  cs = parse_all(effective_specs());
  ss0 = init_all(cs);
  ("{\"w\":" ++ U32/show(W)) ++ ((",\"h\":" ++ U32/show(H)) ++ ((",\"cols\":" ++ U32/show(cols_count())) ++ ((",\"meta\":" ++ meta_json(cs)) ++ ((",\"frames\":[" ++ drop1(frames_json(cs, ss0, FRAMES))) ++ "]}"))))
