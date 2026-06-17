# Growing Tree — cellular-automaton style tree growth in Bend2.
#
# Click an empty board to plant a seed. Each tick, occupied cells
# may mutate to other kinds and/or spawn new cells into empty
# 4-neighbors. Over time the structure resembles a tree.
#
# Toolbar: pause / play / fast-forward / reset.

# ============================================================
# Types
# ============================================================

# Cell kinds.
type GT {
  seed{}
  root{}
  bark{}
  branch{}
  leaf{}
}

# Cell content: either empty or one kind.
Cell : Type = Maybe(GT)

# Speed setting.
type Speed {
  stopped{}
  normal{}
  fast{}
  unlimited{}
}

# Whether anything has been planted yet.
type Phase {
  phase_empty{}
  phase_growing{}
}

# Threaded "board + rng" state passed through the per-tick sweep.
type Step {
  step_st{board: Grid(Cell), rng: U32}
}

# Whole game state. `soil` is the row where the seed was planted: the
# ground line. Everything above it is aerial (trunk/branch/leaf), below it
# is roots. All the height logic is relative to `soil`, so the tree looks
# right no matter where you click.
type State {
  state{
    board: Grid(Cell),
    tick: U32,
    rng: U32,
    speed: Speed,
    phase: Phase,
    soil: U32,
    tx: U32,
  }
}

# Events.
type Event {
  click{x: U32, y: U32}
  tick_ev{}
  set_speed{s: Speed}
  reset{}
}

# ============================================================
# Forward declarations (Bend resolves names in scope order; predeclare
# anything referenced before its definition).
# ============================================================

css : String

# ============================================================
# Constants — tune these freely
# ============================================================

# Grid dimensions in cells.
GW : U32 = 46
GH : U32 = 34

# Render size per cell (pixels).
PX : U32 = 14

# Tick interval in milliseconds for "normal" play.
NORMAL_MS : U32 = 400

# Simulation steps per timer fire when in fast mode.
FAST_STEPS : U32 = 6

# Spawn probability (out of 100) for each kind.
# High base chances, but the density gate (CROWD_LIMIT) keeps growth thin
# and branchy instead of filling a solid disk.
def spawn_chance(k: GT) -> U32:
  match k:
    case seed{}:
      70
    case root{}:
      34
    case bark{}:
      0
    case branch{}:
      60
    case leaf{}:
      0

# Heights measured RELATIVE to the soil line (soil - y, in cells).
# A tip this far above the soil (or at the very top edge) leafs out — so
# the crown forms relative to where you planted, not at a fixed row.
CANOPY_START : U32 = 10
# Aerial cells within this height of the soil are the "trunk zone": they
# spread sideways (thicken) and harden into dark bark.
TRUNK_H : U32 = 5

# A child is only placed if its target has FEWER than this many occupied
# 8-neighbors. This is the anti-blob knob: lower = thinner, more tree-like.
CROWD_LIMIT : U32 = 3

# Roots may flare out sideways only within this many columns of the trunk
# (`tx`). Past it they stop widening and just descend — so the base never
# expands horizontally forever.
ROOT_HALF : U32 = 5

# Trunk "push": every TRUNK_PUSH_PERIOD ticks, a compact bark chunk appears
# at the base of the central column band and shoves everything above it up
# by one row — so the trunk thickens and rises over time, like real
# secondary growth. TRUNK_HALF is the half-width of that central band.
TRUNK_PUSH_PERIOD : U32 = 9
TRUNK_HALF : U32 = 1

# Mutation roll cutoffs (out of 100). Tweak to taste.
BRANCH_TO_BARK : U32 = 50
BRANCH_TO_LEAF : U32 = 45

# ============================================================
# RNG — linear congruential, lives in state
# ============================================================

# Advance the RNG one step.
def rng_next(s: U32) -> U32:
  (s * 1103515245) + 12345

# ============================================================
# Equality and counting helpers for GT
# ============================================================

# Short-circuit boolean OR (Bool/or may not exist in this prelude).
def bor(a: Bool, b: Bool) -> Bool:
  match a:
    case true{}:
      true{}
    case false{}:
      b

# Equality on GT (no derived eq for ADTs).
def gt_eq(a: GT, b: GT) -> Bool:
  match a b:
    case seed{} seed{}:
      true{}
    case root{} root{}:
      true{}
    case bark{} bark{}:
      true{}
    case branch{} branch{}:
      true{}
    case leaf{} leaf{}:
      true{}
    case _ _:
      false{}

# Count how many neighbors are occupied (any kind).
def count_occupied(ns: List(Cell)) -> U32:
  match ns:
    case []:
      0
    case h<>t:
      rest = count_occupied(t);
      match h:
        case none{}:
          rest
        case some{_}:
          rest + 1

# Count cells of a given kind in a neighbor list.
def count_kind(ns: List(Cell), target: GT) -> U32:
  match ns:
    case []:
      0
    case h<>t:
      rest = count_kind(t, target);
      match h:
        case none{}:
          rest
        case some{k}:
          match gt_eq(k, target):
            case true{}:
              rest + 1
            case false{}:
              rest

# ============================================================
# Grid helpers — wrap the verbose Grid API
# ============================================================

def board_get(b: Grid(Cell), x: U32, y: U32) -> Cell:
  match Grid/get(Cell, none{}, b, x, y):
    case none{}:
      none{}              # out of bounds: treat as empty wall
    case some{c}:
      c

def board_set(b: Grid(Cell), x: U32, y: U32, v: Cell) -> Grid(Cell):
  Grid/set(Cell, b, x, y, v)

def board_neighbors8(b: Grid(Cell), x: U32, y: U32) -> List(Cell):
  Grid/neighbors_eight(Cell, none{}, b, x, y)

def board_empty(b: Grid(Cell), x: U32, y: U32) -> Bool:
  match board_get(b, x, y):
    case none{}:
      true{}
    case some{_}:
      false{}

# ============================================================
# Direction stepping (clamped at 0; > GW/GH detected via bounds check later)
# ============================================================

# 0=N 1=E 2=S 3=W. Returns (nx, ny).
# Encoded as a pair via Step (we only need the new coords for `board_set`,
# so we use a dedicated lightweight pair type).
type Coord {
  coord{nx: U32, ny: U32}
}

# 8 directions: 0=N 1=NE 2=E 3=SE 4=S 5=SW 6=W 7=NW.
# Diagonals let branches fork into V shapes instead of growing in a slab.
def step_dir(x: U32, y: U32, d: U32) -> Coord:
  match d:
    case 0:
      coord{x, U32/saturating_sub(y, 1)}
    case 1:
      coord{x + 1, U32/saturating_sub(y, 1)}
    case 2:
      coord{x + 1, y}
    case 3:
      coord{x + 1, y + 1}
    case 4:
      coord{x, y + 1}
    case 5:
      coord{U32/saturating_sub(x, 1), y + 1}
    case 6:
      coord{U32/saturating_sub(x, 1), y}
    case _:
      coord{U32/saturating_sub(x, 1), U32/saturating_sub(y, 1)}

# ============================================================
# Mutation: pure function from kind + context to new kind (or same).
# Returns the new kind to write into the cell.
# ============================================================

def maybe_mutate(kind: GT, ns: List(Cell), y: U32, soil: U32, roll: U32) -> GT:
  n_occ     = count_occupied(ns);
  aerial    = U32/lt(y, soil);                  # above the soil line?
  above_amt = U32/saturating_sub(soil, y);      # how far above the soil
  match kind:
    case seed{}:
      # The planted origin: sprouts shoots (up and down) over its first
      # ticks, then once it has a few neighbors hardens into the trunk base.
      if U32/gte(n_occ, 3):
        bark{}
      else:
        seed{}
    case branch{}:
      is_tip = U32/lte(n_occ, 2);
      # A tip leafs out once it is high enough above the soil, OR when it
      # hits the very top edge (so a tree planted high still gets a crown
      # instead of just two leaves).
      high_or_top = bor(U32/gte(above_amt, CANOPY_START), U32/lte(y, 1));
      if Bool/and(aerial, Bool/and(is_tip, Bool/and(high_or_top, U32/lt(roll, BRANCH_TO_LEAF)))):
        leaf{}
      else:
        # Trunk zone (low and aerial): well-connected wood thickens into bark.
        in_trunk = Bool/and(aerial, U32/lte(above_amt, TRUNK_H));
        if Bool/and(in_trunk, Bool/and(U32/gte(n_occ, 3), U32/lt(roll, BRANCH_TO_BARK))):
          bark{}
        else:
          branch{}
    case root{}:
      # Roots stay roots — they never resurface into the aerial tree.
      root{}
    case bark{}:
      bark{}
    case leaf{}:
      leaf{}

# ============================================================
# Spawning: try to place a child cell in one random empty neighbor.
# Returns updated board + advanced rng (wrapped in `Step`).
# ============================================================

# The child kind, decided by WHERE it lands: above the soil line it is
# aerial wood (branch); at or below the soil it is a root. So a seed (or
# anything) spawning sideways AT the soil row drops a root next to the
# trunk base, connecting roots and bark instead of leaving a gap.
def child_for_y(ny: U32, soil: U32) -> GT:
  if U32/lt(ny, soil):
    branch{}
  else:
    root{}

# |x - tx| without a signed type.
def hdist(x: U32, tx: U32) -> U32:
  U32/saturating_sub(x, tx) + U32/saturating_sub(tx, x)

# Choose a growth direction (0..7) biased by kind and position.
def pick_dir(kind: GT, rng: U32, x: U32, y: U32, soil: U32, tx: U32) -> U32:
  p = rng % 100;
  match kind:
    case root{}:
      depth = U32/saturating_sub(y, soil);   # 0 at the soil line, grows down
      match U32/lte(depth, 2):
        case true{}:
          # Near the base: flare SIDEWAYS to thicken the base — but only
          # within ROOT_HALF of the trunk. Past that, stop widening and
          # just descend, so the base never spreads horizontally forever.
          match U32/lt(hdist(x, tx), ROOT_HALF):
            case true{}:
              if U32/lt(p, 22):
                4                              # S
              else:
                if U32/lt(p, 42):
                  3                            # SE
                else:
                  if U32/lt(p, 62):
                    5                          # SW
                  else:
                    if U32/lt(p, 81):
                      2                        # E
                    else:
                      6                        # W
            case false{}:
              # At the width limit: descend straight down.
              4                                # S
        case false{}:
          # Deep down: strong VERTICAL descent (mostly straight S) → tapering
          # tendrils that reach far down. Roots never grow upward.
          if U32/lt(p, 80):
            4                                  # S
          else:
            if U32/lt(p, 90):
              3                                # SE
            else:
              5                                # SW
    case seed{}:
      # The trunk shoot is planted explicitly (plant_base), so the seed
      # mainly builds the base: roots out the sides (E/W) and down (S),
      # plus some reinforcement up (N).
      if U32/lt(p, 30):
        0                                      # N
      else:
        if U32/lt(p, 52):
          2                                    # E
        else:
          if U32/lt(p, 74):
            6                                  # W
          else:
            4                                  # S
    case _:
      above_amt = U32/saturating_sub(soil, y);
      match U32/lte(above_amt, TRUNK_H):
        case true{}:
          # Trunk zone: spread sideways too, to widen the trunk.
          if U32/lt(p, 34):
            0
          else:
            if U32/lt(p, 55):
              2
            else:
              if U32/lt(p, 76):
                6
              else:
                if U32/lt(p, 88):
                  1
                else:
                  7
        case false{}:
          # Up in the canopy: climb and fork.
          if U32/lt(p, 40):
            0
          else:
            if U32/lt(p, 64):
              1
            else:
              if U32/lt(p, 88):
                7
              else:
                if U32/lt(p, 94):
                  2
                else:
                  6

# Try to write a child cell at the target coord. No-op if out of bounds,
# occupied, or too crowded (density gate — keeps the structure branchy).
def try_place(board: Grid(Cell), nx: U32, ny: U32, child: GT, rng: U32) -> Step:
  if Grid/in_bounds(GW, GH, nx, ny):
    match board_empty(board, nx, ny):
      case true{}:
        crowd = count_occupied(board_neighbors8(board, nx, ny));
        if U32/lt(crowd, CROWD_LIMIT):
          step_st{board_set(board, nx, ny, some{child}), rng}
        else:
          step_st{board, rng}            # too crowded — don't fill it in
      case false{}:
        step_st{board, rng}
  else:
    step_st{board, rng}

# Spawn attempt for a single cell. May or may not write to a neighbor.
def maybe_spawn(kind: GT, board: Grid(Cell), x: U32, y: U32, rng: U32, soil: U32, tx: U32) -> Step:
  chance = spawn_chance(kind);
  if U32/eq(chance, 0):
    step_st{board, rng}
  else:
    rng1 = rng_next(rng);
    roll = rng1 % 100;
    if U32/gte(roll, chance):
      step_st{board, rng1}
    else:
      rng2 = rng_next(rng1);
      d    = pick_dir(kind, rng2, x, y, soil, tx);
      match step_dir(x, y, d):
        case coord{nx, ny}:
          try_place(board, nx, ny, child_for_y(ny, soil), rng2)

# ============================================================
# Per-cell decision: mutation then spawning.
# ============================================================

def decide(kind: GT, board: Grid(Cell), x: U32, y: U32, rng: U32, soil: U32, tx: U32) -> Step:
  ns       = board_neighbors8(board, x, y);
  rng1     = rng_next(rng);
  roll     = rng1 % 100;
  new_kind = maybe_mutate(kind, ns, y, soil, roll);
  board1   = board_set(board, x, y, some{new_kind});
  maybe_spawn(new_kind, board1, x, y, rng1, soil, tx)

# ============================================================
# Sweep the whole grid: nested recursion over y then x.
# ============================================================

def step_cell(board: Grid(Cell), x: U32, y: U32, rng: U32, soil: U32, tx: U32) -> Step:
  match board_get(board, x, y):
    case none{}:
      step_st{board, rng}              # empty cell — skip
    case some{kind}:
      decide(kind, board, x, y, rng, soil, tx)

def scan_row(board: Grid(Cell), y: U32, x: U32, rng: U32, soil: U32, tx: U32) -> Step:
  if U32/gte(x, GW):
    step_st{board, rng}
  else:
    match step_cell(board, x, y, rng, soil, tx):
      case step_st{b1, r1}:
        scan_row(b1, y, x + 1, r1, soil, tx)

def scan_grid(board: Grid(Cell), y: U32, rng: U32, soil: U32, tx: U32) -> Step:
  if U32/gte(y, GH):
    step_st{board, rng}
  else:
    match scan_row(board, y, 0, rng, soil, tx):
      case step_st{b1, r1}:
        scan_grid(b1, y + 1, r1, soil, tx)

# ============================================================
# Trunk push: a compact bark chunk appears at the base of the central
# band and shoves the aerial structure above it up by one row.
# ============================================================

# Value that lands in (x, y) after a one-row upward shift: pull the cell
# from just below (y+1); but the bottom aerial row gets a fresh bark chunk.
def shifted_val(orig: Grid(Cell), x: U32, next_y: U32, soil: U32) -> Cell:
  if U32/gte(next_y, soil):
    some{bark{}}
  else:
    board_get(orig, x, next_y)

# Shift one column's aerial cells (rows 0..soil-1) up by one row.
def shift_col_up(orig: Grid(Cell), acc: Grid(Cell), x: U32, y: U32, soil: U32) -> Grid(Cell):
  if U32/gte(y, soil):
    acc
  else:
    next_y = y + 1;
    acc1   = board_set(acc, x, y, shifted_val(orig, x, next_y, soil));
    shift_col_up(orig, acc1, x, next_y, soil)

# Push every column in the band [x_lo, x_hi] up by one row.
def push_band(orig: Grid(Cell), acc: Grid(Cell), soil: U32, x_lo: U32, x_hi: U32) -> Grid(Cell):
  if U32/lt(x_hi, x_lo):
    acc
  else:
    acc1 = shift_col_up(orig, acc, x_lo, 0, soil);
    push_band(orig, acc1, soil, x_lo + 1, x_hi)

# Clamp a column index to the last valid column.
def clamp_hi(v: U32) -> U32:
  if U32/lt(v, GW):
    v
  else:
    U32/saturating_sub(GW, 1)

# Is the top row (y=0) empty across the whole band? If not, a push would
# shove an occupied cell off the top edge — so we stop pushing.
def band_top_clear(board: Grid(Cell), x_lo: U32, x_hi: U32) -> Bool:
  if U32/lt(x_hi, x_lo):
    true{}
  else:
    match board_empty(board, x_lo, 0):
      case true{}:
        band_top_clear(board, x_lo + 1, x_hi)
      case false{}:
        false{}

# Every TRUNK_PUSH_PERIOD ticks, grow the central trunk upward — but only
# while the band's top row is clear. Once the tree has been pushed up to
# the screen edge, the trunk stops rising (and stops shoving things off).
def maybe_push(board: Grid(Cell), tick: U32, soil: U32, tx: U32) -> Grid(Cell):
  x_lo = U32/saturating_sub(tx, TRUNK_HALF);
  x_hi = clamp_hi(tx + TRUNK_HALF);
  on_beat = Bool/and(U32/lt(0, tick), U32/eq(tick % TRUNK_PUSH_PERIOD, 0));
  if Bool/and(on_beat, band_top_clear(board, x_lo, x_hi)):
    push_band(board, board, soil, x_lo, x_hi)
  else:
    board

# Run one full tick.
def one_tick(s: State) -> State:
  match s:
    case state{board, tick, rng, speed, phase, soil, tx}:
      match scan_grid(board, 0, rng, soil, tx):
        case step_st{board1, rng1}:
          tick1  = tick + 1;
          board2 = maybe_push(board1, tick1, soil, tx);
          state{board2, tick1, rng1, speed, phase, soil, tx}

# Run N ticks (for fast-forward mode).
def run_ticks(n: U32, s: State) -> State:
  if U32/eq(n, 0):
    s
  else:
    run_ticks(U32/saturating_sub(n, 1), one_tick(s))

# How many ticks should fire per timer event?
def steps_per_fire(sp: Speed) -> U32:
  match sp:
    case stopped{}:
      0
    case normal{}:
      1
    case fast{}:
      FAST_STEPS
    case unlimited{}:
      40

# Timer interval (ms) per speed. "unlimited" uses the smallest interval so
# the runtime fires as fast as it can; combined with a big steps_per_fire
# that runs the simulation at the machine's processing limit.
def tick_ms(sp: Speed) -> U32:
  match sp:
    case stopped{}:
      NORMAL_MS
    case normal{}:
      NORMAL_MS
    case fast{}:
      120
    case unlimited{}:
      1

# ============================================================
# Init
# ============================================================

def empty_board() -> Grid(Cell):
  Grid/fill(Cell, GW, GH, none{})

init : App/Update(State, Event) =
  update{state{empty_board(), 0, 12345, normal{}, phase_empty{}, 0, 0}, none{}}

# ============================================================
# Event handling
# ============================================================

# Convert a pixel-space click to grid coords, then plant a seed.
# Write v at (x, y) only if `ok`.
def set_if(b: Grid(Cell), ok: Bool, x: U32, y: U32, v: Cell) -> Grid(Cell):
  match ok:
    case true{}:
      board_set(b, x, y, v)
    case false{}:
      b

# Plant the whole base around the seed: a TWO-cell trunk shoot going up,
# and a root on each side at the soil row. Two cells matter: the lower
# shoot sits among the dense base (seed + side roots) and will harden into
# bark, but the upper shoot has only one neighbor, so it stays a branch and
# is the clean growing tip. This guarantees a connected base
# ([root][trunk][root]) AND a tree that actually grows up.
def plant_base(b: Grid(Cell), cx: U32, cy: U32) -> Grid(Cell):
  b1 = set_if(b,  U32/lt(0, cy),                 cx, U32/saturating_sub(cy, 1), some{branch{}});
  b2 = set_if(b1, U32/lt(1, cy),                 cx, U32/saturating_sub(cy, 2), some{branch{}});
  b3 = set_if(b2, U32/lt(0, cx),                 U32/saturating_sub(cx, 1), cy, some{root{}});
  set_if(b3, Grid/in_bounds(GW, GH, cx + 1, cy), cx + 1, cy,                    some{root{}})

def plant_seed(s: State, px: U32, py: U32) -> State:
  match s:
    case state{board, tick, rng, speed, _, _, _}:
      cx = px // PX;
      cy = py // PX;
      if Grid/in_bounds(GW, GH, cx, cy):
        # Record cy as the soil line and cx as the trunk column, so all
        # growth (and the trunk push) is measured from where you clicked.
        b1 = board_set(board, cx, cy, some{seed{}});
        b2 = plant_base(b1, cx, cy);
        state{b2, tick, rng, speed, phase_growing{}, cy, cx}
      else:
        s

def on_event(e: Event, s: State) -> App/Update(State, Event):
  match e:
    case click{px, py}:
      match s:
        case state{_, _, _, _, phase_empty{}, _, _}:
          update{plant_seed(s, px, py), none{}}
        case _:
          update{s, none{}}                     # already growing
    case tick_ev{}:
      match s:
        case state{_, _, _, sp, _, _, _}:
          update{run_ticks(steps_per_fire(sp), s), none{}}
    case set_speed{new}:
      match s:
        case state{b, t, r, _, ph, sl, tx}:
          update{state{b, t, r, new, ph, sl, tx}, none{}}
    case reset{}:
      update{state{empty_board(), 0, 12345, normal{}, phase_empty{}, 0, 0}, none{}}

# ============================================================
# Render — one div per non-empty cell, absolutely positioned.
# ============================================================

# Hex color string for each kind.
def color_of(k: GT) -> String:
  match k:
    case seed{}:
      "#a06030"
    case root{}:
      "#5c3a1a"
    case bark{}:
      "#6b4423"
    case branch{}:
      "#8b6f47"
    case leaf{}:
      "#3fa34d"

def cell_div(x: U32, y: U32, k: GT) -> HTML(Event):
  <div
    style:position={"absolute"}
    style:left={U32/show(x * PX) ++ "px"}
    style:top={U32/show(y * PX) ++ "px"}
    style:width={U32/show(PX) ++ "px"}
    style:height={U32/show(PX) ++ "px"}
    style:background={color_of(k)}
  />

# Emit divs for one row (only the occupied cells).
def render_row(board: Grid(Cell), y: U32, x: U32) -> List(HTML(Event)):
  if U32/gte(x, GW):
    []
  else:
    rest = render_row(board, y, x + 1);
    match board_get(board, x, y):
      case none{}:
        rest
      case some{k}:
        cell_div(x, y, k) <> rest

# Concatenate all rows.
def render_cells(board: Grid(Cell), y: U32) -> List(HTML(Event)):
  if U32/gte(y, GH):
    []
  else:
    List/append(HTML(Event), render_row(board, y, 0), render_cells(board, y + 1))

# Toolbar button.
def tb_button(label: String, ev: Event) -> HTML(Event):
  <button
    on_click={ev}
    style="margin-right:6px; padding:6px 10px; font-size:14px;"
  >
    {text{label}}
  </button>

def status_text(s: State) -> String:
  match s:
    case state{_, tick, _, _, phase_empty{}, _, _}:
      "Click the canvas to plant a seed."
    case state{_, tick, _, _, phase_growing{}, _, _}:
      "Growing — tick " ++ U32/show(tick)

# Map a pointer event to a click, extracting element-local x/y.
def click_event(ptr: HTML/Pointer) -> Event:
  match ptr:
    case pointer{_, x, y, _, _}:
      click{I32/to_u32(x), I32/to_u32(y)}

# One swatch + label entry of the color legend.
def legend_item(k: GT, label: String) -> HTML(Event):
  <span style="display:inline-flex; align-items:center; margin-right:14px;">
    <span
      style:display={"inline-block"}
      style:width={"13px"}
      style:height={"13px"}
      style:background={color_of(k)}
      style:border={"1px solid #00000022"}
      style:border-radius={"3px"}
      style:margin-right={"5px"}
    />
    {text{label}}
  </span>

# The whole color legend row.
def legend() -> HTML(Event):
  <div style="margin-bottom:10px; font-size:13px; color:#444;">
    {legend_item(seed{},   "seed")}
    {legend_item(root{},   "root")}
    {legend_item(bark{},   "trunk")}
    {legend_item(branch{}, "branch")}
    {legend_item(leaf{},   "leaf")}
  </div>

# A dotted horizontal line marking the soil, at the row where the seed was
# planted. Drawn only once something has been planted.
def soil_line(ph: Phase, soil: U32) -> HTML(Event):
  match ph:
    case phase_empty{}:
      <span/>
    case phase_growing{}:
      <div
        style:position={"absolute"}
        style:left={"0px"}
        style:top={U32/show(soil * PX) ++ "px"}
        style:width={"100%"}
        style:height={"0px"}
        style:border-top={"2px dashed #b08d57"}
        style:pointer-events={"none"}
      />

# Top-level render.
def render(s: State) -> HTML(Event):
  match s:
    case state{board, _, _, speed, phase, soil, _}:
      cells = render_cells(board, 0);
      <div style="font-family: system-ui, sans-serif; padding:12px;" every_ms={tick_ms(speed), tick_ev{}}>
        <style>{text{css}}</style>
        <div style="margin-bottom:8px;">
          {tb_button("▶ Play",  set_speed{normal{}})}
          {tb_button("⏩ Fast", set_speed{fast{}})}
          {tb_button("⏭ Max",  set_speed{unlimited{}})}
          {tb_button("⏸ Pause", set_speed{stopped{}})}
          {tb_button("⟲ Reset", reset{})}
        </div>
        <div style="margin-bottom:8px; color:#666;">{text{status_text(s)}}</div>
        {legend()}
        <div
          on_pointer_down={click_event}
          style:position={"relative"}
          style:width={U32/show(GW * PX) ++ "px"}
          style:height={U32/show(GH * PX) ++ "px"}
          style:background={"#f5efe1"}
          style:border={"1px solid #c8bda6"}
          style:cursor={"crosshair"}
        >
          {soil_line(phase, soil)}
          {...cells}
        </div>
      </div>

css : String = "
  button { cursor: pointer; border: 1px solid #aaa; background:#fafafa; border-radius:4px; }
  button:hover { background:#eee; }
"

# Debug line shown by text-mode runners.
def debug(s: State) -> String:
  match s:
    case state{_, tick, rng, _, _, _, _}:
      "tick=" ++ U32/show(tick) ++ " rng=" ++ U32/show(rng)

# Entry point.
main : App = app{State, Event, init, render, on_event, debug}
