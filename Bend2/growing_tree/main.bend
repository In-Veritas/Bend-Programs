# Growing Tree: cellular-automaton tree growth, as a Bend 2 App.
#
# Click (left button) on the empty board to plant a seed: the click row
# becomes the soil line (dashed). Each tick every occupied cell may mutate
# into another kind and/or spawn a child into an empty neighbour; over time
# the structure grows a trunk, branches and leaves above the soil and roots
# below it.
#
# Keys (the web page has the same as buttons):
#   1 play (normal)   2 fast   3 max   p / space pause   r reset   Esc quit
#
#   bend main.bend -o growing_tree && ./growing_tree    native X11 window
#   sh build.sh                                         check, test, web page
#
# Everything below `main` is pure: `Tree.step` folds a frame's events and
# advances the clock, `Tree.view` paints the board into an Image quadtree.
# The browser page (web/index.html) calls the same two defs.
import Base

# Types
# =====

# Cell kinds. On the board a cell is a U32 code: 0 empty, then gt_code.
type GT is Data:
  Seed{}
  Root{}
  Bark{}
  Branch{}
  Leaf{}

type Speed is Data:
  Stopped{}
  Normal{}
  Fast{}
  Unlimited{}

# Whether anything has been planted yet (a second click is ignored).
type Phase is Data:
  Unplanted{}
  Growing{}

# The whole world. `soil` is the row where the seed was planted (the ground
# line) and `tx` its column (the trunk axis); every height rule is relative
# to `soil`. `wait` counts display frames toward the next timer fire.
type State is Data:
  State{
    board: Board, tick: U32, rng: U32, speed: Speed, phase: Phase,
    soil: U32, tx: U32, wait: U32
  }

# Kind counts, for the status line and the headless tests.
type Census is Data:
  Census{seed: U32, root: U32, bark: U32, branch: U32, leaf: U32}

# Constants: tune these freely
# ============================

# Grid size in cells (GH rows, then one HUD row in the native window).
def GW() -> U32:
  46

def GH() -> U32:
  34

def GWn() -> Nat:
  46n

def GHn() -> Nat:
  34n

# Pixels per cell: a power of two, so a cell is one quadtree node.
def PX() -> U32:
  16

# Heights RELATIVE to the soil line (soil - y). A tip this far above the
# soil (or at the top edge) leafs out; aerial cells within TRUNK_H of the
# soil are the trunk zone (spread sideways, harden into bark).
def CANOPY_START() -> U32:
  10

def TRUNK_H() -> U32:
  5

# A child is only placed if its target has FEWER than this many occupied
# 8-neighbours: the anti-blob knob.
def CROWD_LIMIT() -> U32:
  3

# Roots flare sideways only within this many columns of the trunk.
def ROOT_HALF() -> U32:
  5

# Every TRUNK_PUSH_PERIOD ticks the central band (tx +- TRUNK_HALF) is
# shoved up one row with a fresh bark chunk at its base.
def TRUNK_PUSH_PERIOD() -> U32:
  9

def TRUNK_HALF() -> U32:
  1

# Mutation roll cutoffs (out of 100).
def BRANCH_TO_BARK() -> U32:
  50

def BRANCH_TO_LEAF() -> U32:
  45

# Spawn chance (out of 100) per kind.
def spawn_chance(k: GT) -> U32:
  match k:
    case Seed{}:
      70
    case Root{}:
      34
    case Bark{}:
      0
    case Branch{}:
      60
    case Leaf{}:
      0

# Speed table. The old page fired a timer every tick_ms milliseconds; a
# native window shows ~60 frames a second, so the interval is in frames:
# 400 ms = 24 frames, 120 ms = 7 frames, "max" = every frame.
def fire_frames(sp: Speed) -> U32:
  match sp:
    case Stopped{}:
      24
    case Normal{}:
      24
    case Fast{}:
      7
    case Unlimited{}:
      1

def steps_per_fire(sp: Speed) -> Nat:
  match sp:
    case Stopped{}:
      0n
    case Normal{}:
      1n
    case Fast{}:
      6n
    case Unlimited{}:
      40n

# Small helpers
# =============

def sel(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def gt_sel(c: Bool, a: GT, b: GT) -> GT:
  match c:
    case True{}:
      a
    case False{}:
      b

def sat_sub(+a: U32, +b: U32) -> U32:
  sel((a < b : U32), 0, (a - b : U32))

def rng_next(+s: U32) -> U32:
  (s * 1103515245 + 12345 : U32)

def gt_code(k: GT) -> U32:
  match k:
    case Seed{}:
      1
    case Root{}:
      2
    case Bark{}:
      3
    case Branch{}:
      4
    case Leaf{}:
      5

def gt_of(v: U32) -> GT:
  match v:
    case 1:
      Seed{}
    case 2:
      Root{}
    case 3:
      Bark{}
    case 4:
      Branch{}
    case _:
      Leaf{}

def speed_code(sp: Speed) -> U32:
  match sp:
    case Stopped{}:
      3
    case Normal{}:
      0
    case Fast{}:
      1
    case Unlimited{}:
      2

# Board: a 64 x 64 quadtree of cell codes
# =======================================
# A Data quadtree, so the sweep reads it freely (no threading) and the view
# walks it in the same shape as the Image it paints. A BLeaf stands for a
# whole uniform square (the empty board is one BLeaf{0}).

type Board is Data:
  BLeaf{v: U32}
  BNode{tl: Board, tr: Board, bl: Board, br: Board}

def BD() -> Nat:
  6n

def in_bounds(+x: U32, +y: U32) -> Bool:
  ((x < GW()) && (y < GH()) : U32)

def empty_board() -> Board:
  BLeaf{0}

# Which quadrant (0 tl, 1 tr, 2 bl, 3 br) holds (x, y) at a node of 2^(e+1).
def quad(+x: U32, +y: U32, +e: Nat) -> U32:
  (((y >> e) .&. 1) * 2 + ((x >> e) .&. 1) : U32)

def pick4(q: U32, a: Board, b: Board, c: Board, d: Board) -> Board:
  match q:
    case 0:
      a
    case 1:
      b
    case 2:
      c
    case _:
      d

def put4(q: U32, n: Board, a: Board, b: Board, c: Board, d: Board) -> Board:
  match q:
    case 0:
      BNode{n, b, c, d}
    case 1:
      BNode{a, n, c, d}
    case 2:
      BNode{a, b, n, d}
    case _:
      BNode{a, b, c, n}

def bget(+d: Nat, +t: Board, +x: U32, +y: U32) -> U32:
  match d t:
    case _ BLeaf{v}:
      v
    case 0n BNode{a, b, c, dd}:
      0
    case 1n+e BNode{+a, +b, +c, +dd}:
      bget(e, pick4(quad(x, y, e), a, b, c, dd), x, y)

def bset(+d: Nat, t: Board, +x: U32, +y: U32, +v: U32) -> Board:
  match d t:
    case 0n _:
      BLeaf{v}
    case 1n+e BLeaf{+w}:
      +q = quad(x, y, e)
      put4(q, bset(e, BLeaf{w}, x, y, v), BLeaf{w}, BLeaf{w}, BLeaf{w}, BLeaf{w})
    case 1n+e BNode{+a, +b, +c, +dd}:
      +q = quad(x, y, e)
      put4(q, bset(e, pick4(q, a, b, c, dd), x, y, v), a, b, c, dd)

# Out of the grid reads as empty (a wall of nothing), as Grid/get did.
def cell_get.go(ok: Bool, +b: Board, +x: U32, +y: U32) -> U32:
  match ok:
    case True{}:
      bget(BD(), b, x, y)
    case False{}:
      0

def cell_get(+b: Board, +x: U32, +y: U32) -> U32:
  cell_get.go(in_bounds(x, y), b, x, y)

def cell_set(b: Board, +x: U32, +y: U32, +v: U32) -> Board:
  bset(BD(), b, x, y, v)

def set_if(ok: Bool, b: Board, +x: U32, +y: U32, +v: U32) -> Board:
  match ok:
    case True{}:
      cell_set(b, x, y, v)
    case False{}:
      b

def occ_at(+b: Board, +x: U32, +y: U32) -> U32:
  sel(U32.is_eq(cell_get(b, x, y), 0), 0, 1)

# Occupied 8-neighbours (x - 1 at 0 wraps out of the grid: empty).
def count8(+b: Board, +x: U32, +y: U32) -> U32:
  +xl = (x - 1 : U32)
  +xr = (x + 1 : U32)
  +yu = (y - 1 : U32)
  +yd = (y + 1 : U32)
  (occ_at(b, xl, yu) + occ_at(b, x, yu) + occ_at(b, xr, yu) + occ_at(b, xl, y)
    + occ_at(b, xr, y) + occ_at(b, xl, yd) + occ_at(b, x, yd)
    + occ_at(b, xr, yd) : U32)

# Mutation: the new kind of a cell
# ================================

def mutate(kind: GT, +n: U32, +y: U32, +soil: U32, +roll: U32) -> GT:
  match kind:
    case Seed{}:
      # sprouted (a few neighbours): hardens into the trunk base
      gt_sel((n >= 3 : U32), Bark{}, Seed{})
    case Branch{}:
      +aerial = (y < soil : U32)
      +above = sat_sub(soil, y)
      # a tip leafs out high enough above the soil, or at the top edge
      +leafy = (aerial && (n <= 2) && ((above >= CANOPY_START()) || (y <= 1))
        && (roll < BRANCH_TO_LEAF()) : U32)
      # in the trunk zone, well-connected wood darkens into bark
      +barky = (aerial && (above <= TRUNK_H()) && (n >= 3)
        && (roll < BRANCH_TO_BARK()) : U32)
      gt_sel(leafy, Leaf{}, gt_sel(barky, Bark{}, Branch{}))
    case Root{}:
      Root{}
    case Bark{}:
      Bark{}
    case Leaf{}:
      Leaf{}

# Spawning: grow a child into a neighbour
# ======================================

# Above the soil a child is aerial wood, at or below it a root.
def child_for_y(+ny: U32, +soil: U32) -> GT:
  gt_sel((ny < soil : U32), Branch{}, Root{})

def hdist(+x: U32, +tx: U32) -> U32:
  (sat_sub(x, tx) + sat_sub(tx, x) : U32)

# The first threshold p falls under picks its direction, else the last.
def thr(+p: U32, t1: U32, d1: U32, t2: U32, d2: U32, t3: U32, d3: U32,
  t4: U32, d4: U32, d5: U32) -> U32:
  sel((p < t1 : U32), d1, sel((p < t2 : U32), d2, sel((p < t3 : U32), d3,
    sel((p < t4 : U32), d4, d5))))

# Directions: 0 N, 1 NE, 2 E, 3 SE, 4 S, 5 SW, 6 W, 7 NW.
def pick_root(shallow: Bool, near: Bool, +p: U32) -> U32:
  match shallow near:
    case True{} True{}:
      # near the base: flare sideways (thicken the base)
      thr(p, 22, 4, 42, 3, 62, 5, 81, 2, 6)
    case True{} False{}:
      # at the width limit: just descend
      4
    case False{} _:
      # deep: mostly straight down, tapering tendrils
      thr(p, 80, 4, 90, 3, 100, 5, 100, 5, 5)

def pick_wood(trunk: Bool, +p: U32) -> U32:
  match trunk:
    case True{}:
      # trunk zone: spread sideways too, to widen the trunk
      thr(p, 34, 0, 55, 2, 76, 6, 88, 1, 7)
    case False{}:
      # canopy: climb and fork
      thr(p, 40, 0, 64, 1, 88, 7, 94, 2, 6)

def pick_dir(kind: GT, +p: U32, +x: U32, +y: U32, +soil: U32, +tx: U32) -> U32:
  match kind:
    case Root{}:
      pick_root((sat_sub(y, soil) <= 2 : U32), (hdist(x, tx) < ROOT_HALF() : U32), p)
    case Seed{}:
      # builds the base: roots out the sides and down, a little up
      thr(p, 30, 0, 52, 2, 74, 6, 100, 4, 4)
    case _:
      pick_wood((sat_sub(soil, y) <= TRUNK_H() : U32), p)

# The neighbour in direction d, clamped at 0 like U32/saturating_sub.
def step_dir(d: U32, +x: U32, +y: U32) -> U32 & U32:
  match d:
    case 0:
      (x, sat_sub(y, 1))
    case 1:
      ((x + 1 : U32), sat_sub(y, 1))
    case 2:
      ((x + 1 : U32), y)
    case 3:
      ((x + 1 : U32), (y + 1 : U32))
    case 4:
      (x, (y + 1 : U32))
    case 5:
      (sat_sub(x, 1), (y + 1 : U32))
    case 6:
      (sat_sub(x, 1), y)
    case _:
      (sat_sub(x, 1), sat_sub(y, 1))

# Write a child only inside the grid, on an empty cell, and where fewer than
# CROWD_LIMIT neighbours are occupied (keeps the tree thin and branchy).
def try_place(+b: Board, +nx: U32, +ny: U32, +child: U32) -> Board:
  set_if((in_bounds(nx, ny) && U32.is_eq(cell_get(b, nx, ny), 0)
    && (count8(b, nx, ny) < CROWD_LIMIT()) : U32), b, nx, ny, child)

def spawn.place(b: Board, +soil: U32, +rng2: U32, at: U32 & U32) -> Board & U32:
  (nx, +ny) = at
  (try_place(b, nx, ny, gt_code(child_for_y(ny, soil))), rng2)

def spawn.hit(
  hit: Bool, +kind: GT, b: Board, +x: U32, +y: U32, +rng1: U32, +soil: U32,
  +tx: U32
) -> Board & U32:
  match hit:
    case False{}:
      (b, rng1)
    case True{}:
      +rng2 = rng_next(rng1)
      +d = pick_dir(kind, (rng2 % 100 : U32), x, y, soil, tx)
      spawn.place(b, soil, rng2, step_dir(d, x, y))

def spawn.go(
  zero: Bool, +kind: GT, b: Board, +x: U32, +y: U32, +rng: U32, +soil: U32,
  +tx: U32
) -> Board & U32:
  match zero:
    case True{}:
      (b, rng)
    case False{}:
      +rng1 = rng_next(rng)
      spawn.hit(((rng1 % 100) < spawn_chance(kind) : U32), kind, b, x, y, rng1,
        soil, tx)

# A fresh roll; no roll at all for a kind that never spawns.
def maybe_spawn(
  +kind: GT, b: Board, +x: U32, +y: U32, rng: U32, +soil: U32, +tx: U32
) -> Board & U32:
  spawn.go(U32.is_eq(spawn_chance(kind), 0), kind, b, x, y, rng, soil, tx)

# One cell: mutate, write, then maybe spawn (the same roll feeds both).
def decide(
  kind: GT, +b: Board, +x: U32, +y: U32, +rng: U32, +soil: U32, +tx: U32
) -> Board & U32:
  +rng1 = rng_next(rng)
  +nk = mutate(kind, count8(b, x, y), y, soil, (rng1 % 100 : U32))
  maybe_spawn(nk, cell_set(b, x, y, gt_code(nk)), x, y, rng1, soil, tx)

# The sweep: reading order, one buffer (a cell already touched this tick is
# seen by the cells after it), the rng threaded through every cell.
# ======================================================================

def step_cell.go(
  empty: Bool, v: U32, b: Board, +x: U32, +y: U32, rng: U32, +soil: U32,
  +tx: U32
) -> Board & U32:
  match empty:
    case True{}:
      (b, rng)
    case False{}:
      decide(gt_of(v), b, x, y, rng, soil, tx)

def step_cell(+x: U32, +y: U32, +soil: U32, +tx: U32, st: Board & U32) ->
  Board & U32:
  (+b, rng) = st
  +v = cell_get(b, x, y)
  step_cell.go(U32.is_eq(v, 0), v, b, x, y, rng, soil, tx)

def scan_row(n: Nat, +x: U32, +y: U32, +soil: U32, +tx: U32, st: Board & U32)
  -> Board & U32:
  match n:
    case 0n:
      st
    case 1n+p:
      scan_row(p, (x + 1 : U32), y, soil, tx, step_cell(x, y, soil, tx, st))

def scan_grid(n: Nat, +y: U32, +soil: U32, +tx: U32, st: Board & U32) ->
  Board & U32:
  match n:
    case 0n:
      st
    case 1n+p:
      scan_grid(p, (y + 1 : U32), soil, tx, scan_row(GWn(), 0, y, soil, tx, st))

# Trunk push: secondary growth
# ============================

# Shift one column's aerial rows (0 .. soil-1) up by one; the bottom aerial
# row gets a fresh bark chunk. Top-down, so each read is still unshifted.
def shift_col_up(n: Nat, +b: Board, +x: U32, +y: U32, +soil: U32) -> Board:
  match n:
    case 0n:
      b
    case 1n+p:
      +ny = (y + 1 : U32)
      shift_col_up(p,
        cell_set(b, x, y, sel((ny >= soil : U32), 3, cell_get(b, x, ny))), x, ny,
        soil)

def push_band(n: Nat, b: Board, +x: U32, +soil: U32) -> Board:
  match n:
    case 0n:
      b
    case 1n+p:
      push_band(p, shift_col_up(U32.to_nat(soil), b, x, 0, soil), (x + 1 : U32),
        soil)

# Is row 0 empty across the band? Otherwise a push would shove a cell off
# the top edge, so the trunk stops rising.
def band_top_clear(n: Nat, +b: Board, +x: U32) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      U32.is_eq(cell_get(b, x, 0), 0) && band_top_clear(p, b, (x + 1 : U32))

def push_if(ok: Bool, b: Board, n: Nat, +x: U32, +soil: U32) -> Board:
  match ok:
    case True{}:
      push_band(n, b, x, soil)
    case False{}:
      b

def maybe_push(+b: Board, +tick: U32, +soil: U32, +tx: U32) -> Board:
  +lo = sat_sub(tx, TRUNK_HALF())
  +hi = U32.min((tx + TRUNK_HALF() : U32), (GW() - 1 : U32))
  +n = U32.to_nat((hi - lo + 1 : U32))
  +beat = ((tick > 0) && U32.is_eq((tick % TRUNK_PUSH_PERIOD() : U32), 0) : U32)
  push_if(beat && band_top_clear(n, b, lo), b, n, lo, soil)

# Ticks
# =====

def one_tick.fin(
  +tick: U32, speed: Speed, phase: Phase, +soil: U32, +tx: U32, wait: U32,
  st: Board & U32
) -> State:
  (b1, r1) = st
  +t1 = (tick + 1 : U32)
  State{maybe_push(b1, t1, soil, tx), t1, r1, speed, phase, soil, tx, wait}

def one_tick(s: State) -> State:
  State{b, tick, rng, speed, phase, +soil, +tx, wait} = s
  one_tick.fin(tick, speed, phase, soil, tx, wait,
    scan_grid(GHn(), 0, soil, tx, (b, rng)))

def run_ticks(n: Nat, s: State) -> State:
  match n:
    case 0n:
      s
    case 1n+p:
      run_ticks(p, one_tick(s))

# One display frame: count toward the timer; on a fire run its ticks.
def fire(go: Bool, sp: Speed, s: State) -> State:
  match go:
    case True{}:
      State{b, t, r, speed, ph, sl, tx, wait} = s
      run_ticks(steps_per_fire(sp), State{b, t, r, speed, ph, sl, tx, 0})
    case False{}:
      State{b, t, r, speed, ph, sl, tx, wait} = s
      State{b, t, r, speed, ph, sl, tx, (wait + 1 : U32)}

def frame(s: State) -> State:
  State{b, t, r, +speed, ph, sl, tx, +wait} = s
  fire(((wait + 1) >= fire_frames(speed) : U32), speed,
    State{b, t, r, speed, ph, sl, tx, wait})

# Init and planting
# =================

def init() -> State:
  State{empty_board(), 0, 12345, Normal{}, Unplanted{}, 0, 0, 0}

# The whole base at once: a two-cell shoot up (the upper one stays a branch,
# the clean growing tip) and a root on each side at the soil row.
def plant_base(b: Board, +cx: U32, +cy: U32) -> Board:
  b1 = set_if((0 < cy : U32), b, cx, sat_sub(cy, 1), 4)
  b2 = set_if((1 < cy : U32), b1, cx, sat_sub(cy, 2), 4)
  b3 = set_if((0 < cx : U32), b2, sat_sub(cx, 1), cy, 2)
  set_if(in_bounds((cx + 1 : U32), cy), b3, (cx + 1 : U32), cy, 2)

def plant.at(ok: Bool, s: State, +cx: U32, +cy: U32) -> State:
  match ok:
    case True{}:
      State{b, t, r, sp, ph, sl, tx, w} = s
      State{plant_base(cell_set(b, cx, cy, 1), cx, cy), t, r, sp, Growing{}, cy,
        cx, w}
    case False{}:
      s

def plant.phase(ph: Phase, +cx: U32, +cy: U32, s: State) -> State:
  match ph:
    case Unplanted{}:
      plant.at(in_bounds(cx, cy), s, cx, cy)
    case Growing{}:
      s

# Plant at a cell: only on an empty board (phase), only inside the grid.
def plant_cell(+cx: U32, +cy: U32, +s: State) -> State:
  State{b, t, r, sp, ph, sl, tx, w} = s
  plant.phase(ph, cx, cy, s)

# A click in window pixels: pixel -> cell by integer division.
def px_cell(x: F32) -> U32:
  (U32.from_nat(F32.to_nat(x)) / PX() : U32)

def click(x: F32, y: F32, s: State) -> State:
  plant_cell(px_cell(x), px_cell(y), s)

def set_speed(sp: Speed, s: State) -> State:
  State{b, t, r, old, ph, sl, tx, w} = s
  State{b, t, r, sp, ph, sl, tx, w}

# Events
# ======

def key(code: U32, s: State) -> State:
  match code:
    case 49:
      set_speed(Normal{}, s)
    case 50:
      set_speed(Fast{}, s)
    case 51:
      set_speed(Unlimited{}, s)
    case 112:
      set_speed(Stopped{}, s)
    case 32:
      set_speed(Stopped{}, s)
    case 114:
      init()
    case _:
      s

def event(e: Event, s: State) -> Maybe<State>:
  match e:
    case Close{}:
      None{}
    case Key{27, True{}}:
      None{}
    case Key{code, True{}}:
      Some{key(code, s)}
    case Press{id, tool, x, y, time, 0, True{}}:
      Some{click(x, y, s)}
    case _:
      Some{s}

def events(es: List<Event>, s: State) -> Maybe<State>:
  match es:
    case []:
      Some{s}
    case e <> rest:
      Maybe.bind(&1, State, State, event(e, s), s2 => events(rest, s2))

# The app's pure step: this frame's events, then one frame of the clock.
def Tree.step(es: List<Event>, s: State) -> Maybe<State>:
  Maybe.bind(&1, State, State, events(es, s), s2 => Some{frame(s2)})

def Tree.tick(es: List<Event>, s: State) -> IO(Maybe<State>):
  IO.pure(Maybe<State>, Tree.step(es, s))

# Render: the board as an Image quadtree, one node per 16-px cell
# ===============================================================

def color_of(v: U32) -> U32:
  match v:
    case 0:
      16117729
    case 1:
      10510384
    case 2:
      6044186
    case 3:
      7029795
    case 4:
      9137991
    case _:
      4170573

# The soil line: a 2-px dashed line on the top edge of the soil row.
def soil_px(+d: Nat, flat: Bool, +px: U32, +py: U32, +gx: U32, +col: U32) ->
  Image:
  match d flat:
    case 0n _:
      +dash = U32.is_eq(((gx * 16 + px) / 6 % 2 : U32), 0)
      Pix{sel(((py < 2) && dash : U32), 11570519, col)}
    case 1n+e True{}:
      Pix{col}
    case 1n+e False{}:
      +h = U32.shln(1, e)
      +py2 = (py + h : U32)
      Qua{soil_px(e, False{}, px, py, gx, col),
        soil_px(e, False{}, (px + h : U32), py, gx, col),
        soil_px(e, (py2 >= 2 : U32), px, py2, gx, col),
        soil_px(e, (py2 >= 2 : U32), (px + h : U32), py2, gx, col)}

# A swatch: col inset 3 px inside bg (the HUD's legend and speed boxes).
def swatch.flat(+d: Nat, +px: U32, +py: U32) -> U32:
  +s = U32.shln(1, d)
  +inside = ((px >= 3) && (px + s <= 13) && (py >= 3) && (py + s <= 13) : U32)
  +outside = ((px + s <= 3) || (px >= 13) || (py + s <= 3) || (py >= 13) : U32)
  sel(inside, 1, sel(outside, 2, 0))

def swatch(+d: Nat, f: U32, +px: U32, +py: U32, +col: U32, +bg: U32) -> Image:
  match d f:
    case 0n _:
      Pix{col}
    case 1n+e 1:
      Pix{col}
    case 1n+e 2:
      Pix{bg}
    case 1n+e _:
      +h = U32.shln(1, e)
      +px2 = (px + h : U32)
      +py2 = (py + h : U32)
      Qua{swatch(e, swatch.flat(e, px, py), px, py, col, bg),
        swatch(e, swatch.flat(e, px2, py), px2, py, col, bg),
        swatch(e, swatch.flat(e, px, py2), px, py2, col, bg),
        swatch(e, swatch.flat(e, px2, py2), px2, py2, col, bg)}

def HUD_BG() -> U32:
  3813926

def swatch16(+col: U32) -> Image:
  swatch(4n, 0, 0, 0, col, HUD_BG())

# The HUD row under the board: the five kinds' colors (the legend) on the
# left, the four speeds (play, fast, max, pause) on the right, lit = current.
def hud_cell.go(legend: Bool, speedbox: Bool, +x: U32, +k: U32, +spd: U32) ->
  Image:
  match legend speedbox:
    case True{} _:
      swatch16(color_of((x + 1 : U32)))
    case False{} True{}:
      swatch16(sel(U32.is_eq(k, spd), 16765286, 6710886))
    case False{} False{}:
      Pix{HUD_BG()}

def hud_cell(+x: U32, +spd: U32) -> Image:
  +k = (x - 42 : U32)
  hud_cell.go((x < 5 : U32), (k < 4 : U32), x, k, spd)

def board_cell(on_soil: Bool, +x: U32, +v: U32) -> Image:
  match on_soil:
    case True{}:
      soil_px(4n, False{}, 0, 0, x, color_of(v))
    case False{}:
      Pix{color_of(v)}

# One cell (x, y): the HUD row, off the board, or a board cell.
def cell_img(hud: Bool, out: Bool, +t: Board, +x: U32, +y: U32, +sr: U32,
  +spd: U32) -> Image:
  match hud out:
    case True{} _:
      hud_cell(x, spd)
    case False{} True{}:
      Pix{0}
    case False{} False{}:
      board_cell(U32.is_eq(y, sr), x, bget(0n, t, x, y))

def is_leaf(+t: Board) -> Bool:
  match t:
    case BLeaf{v}:
      True{}
    case BNode{a, b, c, d}:
      False{}

def leaf_v(+t: Board) -> U32:
  match t:
    case BLeaf{v}:
      v
    case BNode{a, b, c, d}:
      0

def child(q: U32, +t: Board) -> Board:
  match t:
    case BLeaf{v}:
      t
    case BNode{a, b, c, d}:
      pick4(q, a, b, c, d)

# A square of 2^d cells is one Pix when it is off the board and HUD, or
# one uniform BLeaf wholly on the board with no soil line through it.
def region(+d: Nat, +t: Board, +x0: U32, +y0: U32, +sr: U32) -> U32:
  +s = U32.shln(1, d)
  +out = ((x0 >= GW()) || (y0 > GH()) : U32)
  +inner = (is_leaf(t) && (x0 + s <= GW()) && (y0 + s <= GH())
    && ((sr < y0) || (sr >= y0 + s)) : U32)
  sel(out, 0, sel(inner, color_of(leaf_v(t)), 4294967295))

def draw(+d: Nat, flat: U32, +t: Board, +x0: U32, +y0: U32, +sr: U32, +spd: U32)
  -> Image:
  match d flat:
    case 0n _:
      cell_img(U32.is_eq(y0, GH()), ((x0 >= GW()) || (y0 > GH()) : U32), t, x0,
        y0, sr, spd)
    case 1n+e 4294967295:
      +h = U32.shln(1, e)
      +x1 = (x0 + h : U32)
      +y1 = (y0 + h : U32)
      +a = child(0, t)
      +b = child(1, t)
      +c = child(2, t)
      +dd = child(3, t)
      Qua{draw(e, region(e, a, x0, y0, sr), a, x0, y0, sr, spd),
        draw(e, region(e, b, x1, y0, sr), b, x1, y0, sr, spd),
        draw(e, region(e, c, x0, y1, sr), c, x0, y1, sr, spd),
        draw(e, region(e, dd, x1, y1, sr), dd, x1, y1, sr, spd)}
    case 1n+e color:
      Pix{color}

# The soil row only once something is planted (else off the board).
def soil_row(ph: Phase, +soil: U32) -> U32:
  match ph:
    case Unplanted{}:
      4294967295
    case Growing{}:
      soil

# 64 x 64 cells of 16 px: the 1024-px root over the 736 x 560 window.
def render(+s: State) -> Image:
  State{b, t, r, sp, ph, +sl, tx, w} = s
  +sr = soil_row(ph, sl)
  draw(BD(), region(BD(), b, 0, 0, sr), b, 0, 0, sr, speed_code(sp))

def Tree.view(s: State) -> State & Image:
  +s2 = s
  (s2, render(s2))

def WIN_W() -> U32:
  (GW() * PX() : U32)

def WIN_H() -> U32:
  ((GH() + 1) * PX() : U32)

# Status and census (the web page's text; the tests)
# =================================================

def census.add(v: U32, c: Census) -> Census:
  match v c:
    case 1 Census{a, r, k, h, l}:
      Census{(a + 1 : U32), r, k, h, l}
    case 2 Census{a, r, k, h, l}:
      Census{a, (r + 1 : U32), k, h, l}
    case 3 Census{a, r, k, h, l}:
      Census{a, r, (k + 1 : U32), h, l}
    case 4 Census{a, r, k, h, l}:
      Census{a, r, k, (h + 1 : U32), l}
    case 5 Census{a, r, k, h, l}:
      Census{a, r, k, h, (l + 1 : U32)}
    case _ _:
      c

def census.go(n: Nat, +b: Board, +i: U32, c: Census) -> Census:
  match n:
    case 0n:
      c
    case 1n+p:
      census.go(p, b, (i + 1 : U32),
        census.add(cell_get(b, (i % GW() : U32), (i / GW() : U32)), c))

def census(+b: Board) -> Census:
  census.go(U32.to_nat((GW() * GH() : U32)), b, 0, Census{0, 0, 0, 0, 0})

def Census.show(c: Census) -> String:
  Census{a, r, k, h, l} = c
  "seed " ++ U32.show(a) ++ ", root " ++ U32.show(r) ++ ", trunk "
    ++ U32.show(k) ++ ", branch " ++ U32.show(h) ++ ", leaf " ++ U32.show(l)

def speed_name(sp: Speed) -> String:
  match sp:
    case Stopped{}:
      "paused"
    case Normal{}:
      "play"
    case Fast{}:
      "fast"
    case Unlimited{}:
      "max"

def status.go(ph: Phase, +t: U32, c: Census, sp: Speed) -> String:
  match ph:
    case Unplanted{}:
      "Click the board to plant a seed."
    case Growing{}:
      "Growing - tick " ++ U32.show(t) ++ " (" ++ speed_name(sp) ++ ") - "
        ++ Census.show(c)

# The status line under the toolbar of the web page.
def Tree.status(s: State) -> String:
  State{b, t, r, sp, ph, sl, tx, w} = s
  status.go(ph, t, census(b), sp)

def main() -> IO(Unit):
  App.run(~State, ~App{Tree.view, Tree.tick}, "Growing Tree", WIN_W(), WIN_H(),
    init())
