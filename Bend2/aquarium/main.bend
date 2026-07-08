# Aquarium — a tiny aquatic ecosystem in Bend2.
#
# An open-topped glass tank of water with an animated wavy surface. Click — or
# hold — above the waterline to pour orange eggs. They fall through the air, then
# sink. An egg left untouched long enough hatches into a fry. Fry school
# together and eat eggs; juveniles eat fry; adults hunt fry and juveniles.
# A fish may eat once per second, and may only set off to chase another FISH once
# every ten seconds. Grow an adult too big for the tank and the side walls
# shatter. Your score is the number of ADULT fish alive at that moment.
#
# Unlike growing_tree (a discrete cellular grid), the aquarium lives in
# CONTINUOUS space: every creature is a record with floating-point position
# and velocity, updated each frame by simple steering forces.

# ============================================================
# Types
# ============================================================

# Life stage. `egg` is the food you pour in.
type Stage {
  egg{}
  fry{}
  juvenile{}
  adult{}
}

# One creature. Eggs and fish share the same record so the world is a
# single flat list we can map/fold over uniformly.
#   x,y    : center position in pixels (front face of the cube)
#   vx,vy  : velocity in px/frame
#   size   : abstract scale used for sprite size AND the prey size-cap
#   timer  : eggs -> frames sinking (hatch countdown);
#            fish  -> frames since its last meal (the 1-second eat cooldown)
#   hu     : fish -> frames since its last FISH meal (the 10-second hunt clock)
#   fed    : fry -> eggs eaten; juveniles -> fish eaten (drives maturing)
#   rng    : per-creature random seed, so each one wanders differently
#   face   : true = facing right (sprite mirrored)
type Ent {
  ent{
    stage: Stage,
    x: F32, y: F32,
    vx: F32, vy: F32,
    size: F32,
    timer: U32,
    hu: U32,
    fed: U32,
    rng: U32,
    face: Bool,
  }
}

# A 2D vector return value (Bend has no tuples in expression position).
type Vec {
  vec{x: F32, y: F32}
}

# Result of a "nearest matching entity" search.
type Near {
  near{ok: Bool, x: F32, y: F32, d: F32}
}

# Fry swarm accumulator (count + summed positions + summed velocities).
type Swarm {
  sw{n: U32, sx: F32, sy: F32, vx: F32, vy: F32}
}

# Entity paired with its index, for the eating-assignment pass.
type IEnt {
  ient{i: U32, e: Ent}
}

# A granted meal: predator index `pi` ate prey whose life stage is `ps`
# (the stage decides growth, maturation, and an adult's feeding-cycle cost).
type Grant {
  grant{pi: U32, ps: Stage}
}

# Accumulator for the claim pass: which prey indices are consumed, and the
# list of granted meals.
type ClaimAcc {
  cacc{consumed: List(U32), grants: List(Grant)}
}

# Output of one eating pass.
type EatRes {
  eres{ents: List(Ent), broke: Bool, score: U32}
}

# Whole-game phase. `phase_over` remembers the score (adult fish) and the
# tick the tank broke, so the shatter animation can play from there.
type Phase {
  phase_start{}
  phase_play{}
  phase_over{score: U32, at: U32}
}

# Top-level state. `pouring` + (pour_x, pour_y) drive hold-to-pour.
type State {
  state{
    ents: List(Ent),
    tick: U32,
    rng: U32,
    phase: Phase,
    pouring: Bool,
    pour_x: F32,
    pour_y: F32,
  }
}

# Events.
type Event {
  press{x: U32, y: U32}
  release{}
  move{x: U32, y: U32}
  tick_ev{}
}

# ============================================================
# Forward declarations
# ============================================================

css : String

# ============================================================
# Constants (tune freely)
# ============================================================

# Cube front-face size, in pixels. Sim coordinates live in [0,WF]x[0,HF].
WF : F32 = 560.0
HF : F32 = 380.0
# Iso-depth of the cube (thickness of the side walls).
DZ : U32 = 30

# Surface (waterline) y, and the sandy floor y.
WATER_Y : F32 = 72.0
FLOOR   : F32 = 374.0

# Frame timer interval (ms). ~22 frames/second.
FRAME_MS : U32 = 45
# Frames that count as time. Egg hatches after ~7s; a fish may only eat once
# per second; a juvenile/adult only sets off to chase a fish once per ~10s.
HATCH_TICKS  : U32 = 150
EAT_COOLDOWN : U32 = 22
HUNT_PERIOD  : U32 = 220

# Air physics: gentle gravity, capped fall speed.
AIR_GRAV    : F32 = 0.06
AIR_MAXFALL : F32 = 2.2
# Water physics: slow terminal sink speed.
SINK_SPEED : F32 = 0.5

# Growth / lifecycle thresholds. Every meal adds a little SIZE (so a fish
# visibly grows each time it eats, not only when it changes stage), and a
# stage only advances after several meals.
PREY_RATIO   : F32 = 0.5    # a predator can only eat prey at most HALF its size
FRY_BORN   : F32 = 3.0    # size of a freshly hatched fry (~ an egg)
FRY_GROW   : F32 = 1.3    # size gained per egg a fry eats
FRY_MEALS  : U32 = 12     # eggs a fry must eat to mature
JUV_GROW     : F32 = 2.0    # size gained per fry a juvenile eats
JUV_MEALS    : U32 = 5      # fry a juvenile must eat to mature
ADULT_MUL    : F32 = 1.10   # size grows 10% for each fish an adult eats
BREAK_SIZE   : F32 = 135.0  # an adult this big shatters the tank

# Adult feeding cycle. An adult feeds (eating prey worth these many units each)
# until it has consumed CYCLE_CAP units, then waits HUNT_PERIOD (~10s) before
# the next cycle. 5 fry (2 each) = 2 juveniles (5) = 1 adult (10) = one cycle.
FRY_COST : U32 = 2
JUV_COST   : U32 = 5
ADULT_COST : U32 = 10
CYCLE_CAP  : U32 = 10

# Swim tuning.
STEER   : F32 = 0.25   # how hard we turn toward a target
DEPTH_K : F32 = 0.008  # pull toward the stage's preferred depth band
WANDER  : F32 = 0.14   # random jitter (breaks infinite-loop chases)
BOB_AMP : F32 = 0.05   # vertical bobbing amplitude (gentle)
BOB_F   : F32 = 0.08   # bobbing frequency (slow)
MARGIN   : F32 = 12.0  # wall keep-out
SURF_PAD : F32 = 12.0  # fish stay this far below the surface
EAT_PAD  : F32 = 4.0   # slack added to the eat-contact radius
MAX_VY   : F32 = 1.5   # cap on vertical speed (so fish rise/sink gently)

# Collision: fish may overlap a little, but past COLLIDE_FRAC of their combined
# radii they repel (bigger shoves smaller), and the smaller one veers aside to
# pick another path. Predator/prey pairs are skipped — that overlap is a meal.
COLLIDE_FRAC : F32 = 0.78
COLL_STR     : F32 = 0.6
VEER         : F32 = 0.5

# Fry swarming (boids): within SWARM_R2 (squared px) fry steer toward the
# group centroid (cohesion) and match its heading (alignment).
SWARM_R2 : F32 = 4096.0
COHESION : F32 = 0.012
ALIGN    : F32 = 0.06

# Spawning.
SPAWN_N : U32 = 4    # eggs dropped on a tap
POUR_N  : U32 = 2    # eggs added each frame while holding

# Animation: swap sprite frame every this many ticks.
FRAME_TICKS : U32 = 6

# Wave: number of surface segments and their look.
N_WAVE  : U32 = 56
SEG_W   : U32 = 10            # WF / N_WAVE
WAVE_AMP   : F32 = 5.0
WAVE_SPEED : F32 = 0.18
WAVE_FREQ  : F32 = 0.5

# Tank-break animation.
OVER_GRAV   : F32 = 0.55   # gravity on the falling fish
DRAIN_SPEED : F32 = 13.0   # how fast the water level drops per frame
SHARD_SPEED : F32 = 6.5    # how fast glass shards fly off
OVER_PANEL_DELAY : U32 = 24  # frames before the game-over text appears

# Colors.
COL_EGG   : String = "#ff9a44"
COL_BROWN : String = "#7a4a1a"   # fry
COL_GREEN : String = "#1b7a3a"   # juvenile (dark green)
COL_DBLUE : String = "#1e478f"   # adult (dark blue)

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

# Uniform-ish random float in [-1, 1) from a seed.
def rand_unit(r: U32) -> F32:
  F32/div(U32/to_f32(r % 2000), 1000.0) - 1.0

def clampf(v: F32, lo: F32, hi: F32) -> F32:
  F32/max(lo, F32/min(hi, v))

# Clamp >=0 and render as a pixel string.
def px_of(f: F32) -> String:
  U32/show(F32/to_u32(F32/max(0.0, f))) ++ "px"

# Render a (possibly negative / fractional) number for CSS transforms.
def fshow(f: F32) -> String:
  F32/show(f)

# ============================================================
# Entity accessors
# ============================================================

def e_stage(e: Ent) -> Stage:
  match e:
    case ent{s, _, _, _, _, _, _, _, _, _, _}:
      s

def e_x(e: Ent) -> F32:
  match e:
    case ent{_, x, _, _, _, _, _, _, _, _, _}:
      x

def e_y(e: Ent) -> F32:
  match e:
    case ent{_, _, y, _, _, _, _, _, _, _, _}:
      y

def e_vx(e: Ent) -> F32:
  match e:
    case ent{_, _, _, vx, _, _, _, _, _, _, _}:
      vx

def e_vy(e: Ent) -> F32:
  match e:
    case ent{_, _, _, _, vy, _, _, _, _, _, _}:
      vy

def e_size(e: Ent) -> F32:
  match e:
    case ent{_, _, _, _, _, sz, _, _, _, _, _}:
      sz

def e_timer(e: Ent) -> U32:
  match e:
    case ent{_, _, _, _, _, _, t, _, _, _, _}:
      t

def e_hu(e: Ent) -> U32:
  match e:
    case ent{_, _, _, _, _, _, _, h, _, _, _}:
      h

def e_rng(e: Ent) -> U32:
  match e:
    case ent{_, _, _, _, _, _, _, _, _, r, _}:
      r

def is_egg(e: Ent) -> Bool:
  match e_stage(e):
    case egg{}:
      true{}
    case _:
      false{}

def is_fish(e: Ent) -> Bool:
  match e_stage(e):
    case egg{}:
      false{}
    case _:
      true{}

def is_fry(e: Ent) -> Bool:
  match e_stage(e):
    case fry{}:
      true{}
    case _:
      false{}

def is_juv(e: Ent) -> Bool:
  match e_stage(e):
    case juvenile{}:
      true{}
    case _:
      false{}

def is_adult(e: Ent) -> Bool:
  match e_stage(e):
    case adult{}:
      true{}
    case _:
      false{}

# Count entities matching a selector: 1=fry 2=juvenile 3=adult else=any fish.
def sel_match(e: Ent, sel: U32) -> Bool:
  match sel:
    case 1:
      is_fry(e)
    case 2:
      is_juv(e)
    case 3:
      is_adult(e)
    case _:
      is_fish(e)

def count_stage(es: List(Ent), sel: U32) -> U32:
  match es:
    case []:
      0
    case h<>t:
      match sel_match(h, sel):
        case true{}:
          1 + count_stage(t, sel)
        case false{}:
          count_stage(t, sel)

# ============================================================
# Per-stage numeric profiles
# ============================================================

def stage_spd(st: Stage) -> F32:
  match st:
    case egg{}:
      0.0
    case fry{}:
      3.0
    case juvenile{}:
      2.8
    case adult{}:
      2.6

def stage_maxspd(st: Stage) -> F32:
  match st:
    case egg{}:
      0.0
    case fry{}:
      4.2
    case juvenile{}:
      4.0
    case adult{}:
      3.8

# Preferred depth band center: fry near the top, juveniles mid,
# adults near the floor. Just a tendency, not a hard wall.
def zone_y(st: Stage) -> F32:
  band = HF - WATER_Y;
  match st:
    case egg{}:
      WATER_Y
    case fry{}:
      WATER_Y + band * 0.16
    case juvenile{}:
      WATER_Y + band * 0.5
    case adult{}:
      WATER_Y + band * 0.82

# Sprite font size (px, as float). A single continuous mapping from `size`
# for every fish stage, so a creature grows smoothly with every meal.
def fontpx_f(e: Ent) -> F32:
  match e_stage(e):
    case egg{}:
      6.0
    case _:
      F32/max(9.0, 6.0 + (e_size(e) * 0.85))

def fontpx_str(e: Ent) -> String:
  U32/show(F32/to_u32(fontpx_f(e))) ++ "px"

# Physical radius for contact / separation tests.
def radius(e: Ent) -> F32:
  match e_stage(e):
    case egg{}:
      3.0
    case _:
      fontpx_f(e) * 0.5

# ============================================================
# Predation rules
# ============================================================

# Life-stage tiers: who may eat whom (before the size check).
#   fry    -> eggs
#   juvenile -> eggs (no growth) + fry (grows)
#   adult    -> ANY fish (fry, juveniles, even other adults)
def tier_ok(pred: Stage, prey: Stage) -> Bool:
  match pred:
    case egg{}:
      false{}
    case fry{}:
      match prey:
        case egg{}:
          true{}
        case _:
          false{}
    case juvenile{}:
      match prey:
        case egg{}:
          true{}
        case fry{}:
          true{}
        case _:
          false{}
    case adult{}:
      match prey:
        case egg{}:
          false{}
        case _:
          true{}                              # any fish — including other adults

# Can `pred` eat `prey`? Right tier AND prey is at most HALF the predator's size.
def can_eat(pred: Ent, prey: Ent) -> Bool:
  Bool/and(tier_ok(e_stage(pred), e_stage(prey)), F32/lte(e_size(prey), e_size(pred) * PREY_RATIO))

# Off the 1-second eat cooldown?
def can_act(e: Ent) -> Bool:
  U32/gte(e_timer(e), EAT_COOLDOWN)

# In hunt mode? (Only chases / eats other fish once per ~10 seconds.)
def hunting(e: Ent) -> Bool:
  U32/gte(e_hu(e), HUNT_PERIOD)

# How many feeding-cycle units a prey of this stage is worth to an adult.
def stage_cost(st: Stage) -> U32:
  match st:
    case egg{}:
      0
    case fry{}:
      FRY_COST
    case juvenile{}:
      JUV_COST
    case adult{}:
      ADULT_COST

# ============================================================
# Targeting: find the nearest entity matching a mode.
#   mode 0 = an egg;  mode 1 = an edible prey fish.
# ============================================================

def cand_ok(self: Ent, c: Ent, mode: U32) -> Bool:
  match mode:
    case 0:
      is_egg(c)
    case _:
      Bool/and(is_fish(c), can_eat(self, c))

def better(acc: Near, d: F32, x: F32, y: F32) -> Near:
  match acc:
    case near{ok, ax, ay, ad}:
      match ok:
        case false{}:
          near{true{}, x, y, d}
        case true{}:
          if F32/lt(d, ad):
            near{true{}, x, y, d}
          else:
            acc

def nw_go(self: Ent, world: List(Ent), mode: U32, acc: Near) -> Near:
  match world:
    case []:
      acc
    case h<>t:
      match cand_ok(self, h, mode):
        case false{}:
          nw_go(self, t, mode, acc)
        case true{}:
          dx = e_x(self) - e_x(h);
          dy = e_y(self) - e_y(h);
          d2 = (dx * dx) + (dy * dy);
          nw_go(self, t, mode, better(acc, d2, e_x(h), e_y(h)))

def nearest(self: Ent, world: List(Ent), mode: U32) -> Near:
  nw_go(self, world, mode, near{false{}, 0.0, 0.0, 0.0})

# Return `a` if it found something, otherwise fall back to `b`.
def prefer(a: Near, b: Near) -> Near:
  match a:
    case near{ok, _, _, _}:
      match ok:
        case true{}:
          a
        case false{}:
          b

# What should this creature swim toward right now? Fry and juveniles graze
# eggs; a juvenile or adult only sets off after a fish while it is in hunt mode
# (and then keeps feeding until its cycle is done, for adults).
def target_of(self: Ent, world: List(Ent)) -> Near:
  match e_stage(self):
    case egg{}:
      near{false{}, 0.0, 0.0, 0.0}
    case fry{}:
      nearest(self, world, 0)
    case juvenile{}:
      match hunting(self):
        case true{}:
          prefer(nearest(self, world, 1), nearest(self, world, 0))   # hunt fry, else graze eggs
        case false{}:
          nearest(self, world, 0)               # graze the nearest egg
    case adult{}:
      match hunting(self):
        case true{}:
          nearest(self, world, 1)
        case false{}:
          near{false{}, 0.0, 0.0, 0.0}

# ============================================================
# Fry swarming (cohesion + alignment among nearby fry).
# ============================================================

def swarm_go(self: Ent, world: List(Ent), acc: Swarm) -> Swarm:
  match world:
    case []:
      acc
    case h<>t:
      match is_fry(h):
        case false{}:
          swarm_go(self, t, acc)
        case true{}:
          dx = e_x(h) - e_x(self);
          dy = e_y(h) - e_y(self);
          d2 = (dx * dx) + (dy * dy);
          near = Bool/and(F32/lt(0.01, d2), F32/lt(d2, SWARM_R2));
          match near:
            case false{}:
              swarm_go(self, t, acc)
            case true{}:
              match acc:
                case sw{n, sx, sy, vx, vy}:
                  swarm_go(self, t, sw{n + 1, sx + e_x(h), sy + e_y(h), vx + e_vx(h), vy + e_vy(h)})

def swarm(self: Ent, world: List(Ent)) -> Vec:
  match is_fry(self):
    case false{}:
      vec{0.0, 0.0}
    case true{}:
      match swarm_go(self, world, sw{0, 0.0, 0.0, 0.0, 0.0}):
        case sw{n, sx, sy, vx, vy}:
          match U32/eq(n, 0):
            case true{}:
              vec{0.0, 0.0}
            case false{}:
              fn  = U32/to_f32(n);
              cx  = F32/div(sx, fn);
              cy  = F32/div(sy, fn);
              avx = F32/div(vx, fn);
              avy = F32/div(vy, fn);
              coh_x = (cx - e_x(self)) * COHESION;
              coh_y = (cy - e_y(self)) * COHESION;
              ali_x = (avx - e_vx(self)) * ALIGN;
              ali_y = (avy - e_vy(self)) * ALIGN;
              vec{coh_x + ali_x, coh_y + ali_y}

# ============================================================
# Collision: gentle repulsion + the smaller fish veers aside. Predator/prey
# pairs are skipped (that overlap turns into a meal in the eating pass).
# ============================================================

def veer_sign(rg: U32) -> F32:
  match U32/eq(rg % 2, 0):
    case true{}:
      1.0
    case false{}:
      0.0 - 1.0

# The smaller fish veers perpendicular to break a head-on collision.
def veer_amt(self: Ent, h: Ent) -> F32:
  match F32/lt(e_size(self), e_size(h)):
    case true{}:
      VEER * veer_sign(e_rng(self))
    case false{}:
      0.0

def coll_go(self: Ent, world: List(Ent), ax: F32, ay: F32) -> Vec:
  match world:
    case []:
      vec{ax, ay}
    case h<>t:
      match e_stage(h):
        case egg{}:
          coll_go(self, t, ax, ay)
        case _:
          eating = bor(can_eat(self, h), can_eat(h, self));
          match eating:
            case true{}:
              coll_go(self, t, ax, ay)           # this overlap is a meal, not a bump
            case false{}:
              dx  = e_x(self) - e_x(h);
              dy  = e_y(self) - e_y(h);
              d2  = (dx * dx) + (dy * dy);
              lim = (radius(self) + radius(h)) * COLLIDE_FRAC;
              hit = Bool/and(F32/lt(0.01, d2), F32/lt(d2, lim * lim));
              match hit:
                case false{}:
                  coll_go(self, t, ax, ay)
                case true{}:
                  d    = F32/sqrt(d2);
                  ux   = F32/div(dx, d);
                  uy   = F32/div(dy, d);
                  w    = F32/div(e_size(h), e_size(self) + e_size(h));
                  push = COLL_STR * (w * F32/div(lim - d, lim));
                  vsg  = veer_amt(self, h);
                  coll_go(self, t, ax + (ux * push) + ((0.0 - uy) * vsg), ay + (uy * push) + (ux * vsg))

def coll_vec(self: Ent, world: List(Ent)) -> Vec:
  coll_go(self, world, 0.0, 0.0)

# ============================================================
# Steering toward the chosen target.
# ============================================================

def steer(st: Stage, x: F32, y: F32, vx: F32, vy: F32, tg: Near) -> Vec:
  spd = stage_spd(st);
  match tg:
    case near{ok, tx, ty, _}:
      match ok:
        case false{}:
          vec{vx, vy}
        case true{}:
          dx  = tx - x;
          dy  = ty - y;
          d   = F32/sqrt((dx * dx) + (dy * dy) + 0.001);
          dvx = F32/div(dx, d) * spd;
          dvy = F32/div(dy, d) * spd;
          vec{vx + ((dvx - vx) * STEER), vy + ((dvy - vy) * STEER)}

def cap_speed(vx: F32, vy: F32, maxs: F32) -> Vec:
  sp2 = (vx * vx) + (vy * vy);
  if F32/lt(sp2, maxs * maxs):
    vec{vx, vy}
  else:
    sp = F32/sqrt(sp2 + 0.0001);
    k  = F32/div(maxs, sp);
    vec{vx * k, vy * k}

def wx(nx: F32, vx: F32) -> Vec:
  if F32/lt(nx, MARGIN):
    vec{MARGIN, F32/abs(vx)}
  else:
    if F32/lt(WF - MARGIN, nx):
      vec{WF - MARGIN, 0.0 - F32/abs(vx)}
    else:
      vec{nx, vx}

def wy(ny: F32, vy: F32) -> Vec:
  lo = WATER_Y + SURF_PAD;
  if F32/lt(ny, lo):
    vec{lo, F32/abs(vy)}
  else:
    if F32/lt(HF - MARGIN, ny):
      vec{HF - MARGIN, 0.0 - F32/abs(vy)}
    else:
      vec{ny, vy}

# ============================================================
# Per-entity update (motion + hatching).
# ============================================================

def near_ok(n: Near) -> Bool:
  match n:
    case near{ok, _, _, _}:
      ok

# Depth-band pull, applied ONLY when the fish has no target.
def depth_bias(st: Stage, y: F32, has_target: Bool) -> F32:
  match has_target:
    case true{}:
      0.0
    case false{}:
      (zone_y(st) - y) * DEPTH_K

def egg_update(e: Ent, tick: U32) -> Ent:
  match e:
    case ent{_, x, y, vx, vy, sz, tm, hh, fd, rg, fc}:
      if F32/lt(y, WATER_Y):
        nvy = F32/min(vy + AIR_GRAV, AIR_MAXFALL);
        nx  = clampf(x + vx, 4.0, WF - 4.0);
        ny  = y + nvy;
        ent{egg{}, nx, ny, vx, nvy, sz, 0, hh, fd, rg, fc}
      else:
        nvy = vy + ((SINK_SPEED - vy) * 0.1);
        ph  = (U32/to_f32(tick) * 0.2) + (U32/to_f32(rg % 100) * 0.1);
        wob = F32/sin(ph) * 0.6;
        nx  = clampf(x + wob, 4.0, WF - 4.0);
        ny  = F32/min(y + nvy, FLOOR);
        ntm = tm + 1;
        if U32/gte(ntm, HATCH_TICKS):
          face = U32/eq(rg % 2, 0);
          ent{fry{}, nx, ny, rand_unit(rg) * 0.8, 0.0 - 0.2, FRY_BORN, 0, 0, 0, rng_next(rg), face}
        else:
          ent{egg{}, nx, ny, vx, nvy, sz, ntm, hh, fd, rg, fc}

def fish_update(e: Ent, world: List(Ent), tick: U32) -> Ent:
  match e:
    case ent{st, x, y, vx, vy, sz, tm, hh, fd, rg, fc}:
      tg = target_of(e, world);
      match steer(st, x, y, vx, vy, tg):
        case vec{svx, svy}:
          bvy = svy + depth_bias(st, y, near_ok(tg));
          r1  = rng_next(rg);
          r2  = rng_next(r1);
          wvx = svx + (rand_unit(r1) * WANDER);
          wvy0 = bvy + (rand_unit(r2) * WANDER);
          ph   = (U32/to_f32(tick) * BOB_F) + (U32/to_f32(rg % 100) * 0.1);
          wvy  = wvy0 + (F32/sin(ph) * BOB_AMP);
          match swarm(e, world):
            case vec{swx, swy}:
              match coll_vec(e, world):
                case vec{cxx, cyy}:
                  cvx = wvx + swx + cxx;
                  cvy = wvy + swy + cyy;
                  match cap_speed(cvx, cvy, stage_maxspd(st)):
                    case vec{kvx, kvy0}:
                      kvy = clampf(kvy0, 0.0 - MAX_VY, MAX_VY);
                      match wx(x + kvx, kvx):
                        case vec{nx, nvx}:
                          match wy(y + kvy, kvy):
                            case vec{ny, nvy}:
                              face = F32/lt(0.0, nvx);
                              ent{st, nx, ny, nvx, nvy, sz, tm + 1, hh + 1, fd, rng_next(r2), face}

def update_ent(e: Ent, world: List(Ent), tick: U32) -> Ent:
  match e_stage(e):
    case egg{}:
      egg_update(e, tick)
    case _:
      fish_update(e, world, tick)

def move_all(ents: List(Ent), tick: U32) -> List(Ent):
  List/map(Ent, Ent, ents, (e) => update_ent(e, ents, tick))

# Velocity once a falling body has landed.
def landed_vy(rest: Bool, nvy: F32) -> F32:
  match rest:
    case true{}:
      0.0
    case false{}:
      nvy

# Game-over physics: the water is gone, so everything falls and lands.
def fall_ent(e: Ent) -> Ent:
  match e:
    case ent{st, x, y, vx, vy, sz, tm, hh, fd, rg, fc}:
      nvy  = F32/min(vy + OVER_GRAV, 7.0);
      ny   = F32/min(y + nvy, FLOOR);
      nvx  = vx * 0.94;
      nx   = clampf(x + nvx, 6.0, WF - 6.0);
      rest = F32/lte(FLOOR, ny);
      fvy  = landed_vy(rest, nvy);
      ent{st, nx, ny, nvx, fvy, sz, tm, hh, fd, rg, fc}

def fall_all(ents: List(Ent)) -> List(Ent):
  List/map(Ent, Ent, ents, fall_ent)

# ============================================================
# Eating: assign each predator at most one prey, prey to one predator.
# ============================================================

def u32_mem(x: U32, xs: List(U32)) -> Bool:
  match xs:
    case []:
      false{}
    case h<>t:
      if U32/eq(h, x):
        true{}
      else:
        u32_mem(x, t)

def enum_go(es: List(Ent), i: U32) -> List(IEnt):
  match es:
    case []:
      []
    case h<>t:
      ient{i, h} <> enum_go(t, i + 1)

def enumerate(es: List(Ent)) -> List(IEnt):
  enum_go(es, 0)

def lookup_ent(iw: List(IEnt), j: U32) -> Ent:
  match iw:
    case []:
      ent{egg{}, 0.0, 0.0, 0.0, 0.0, 1.0, 0, 0, 0, 0, true{}}   # unreachable default
    case h<>t:
      match h:
        case ient{i, e}:
          if U32/eq(i, j):
            e
          else:
            lookup_ent(t, j)

def within_range(se: Ent, c: Ent) -> Bool:
  dx = e_x(se) - e_x(c);
  dy = e_y(se) - e_y(c);
  d2 = (dx * dx) + (dy * dy);
  r  = radius(se) + radius(c) + EAT_PAD;
  F32/lt(d2, r * r)

# May `se` actually eat `c` right now? Right tier + size, AND — if `c` is a
# fish — the predator must be in its 10-second hunt window. Eggs anytime.
def edible(se: Ent, c: Ent) -> Bool:
  base = can_eat(se, c);
  match is_fish(c):
    case true{}:
      Bool/and(base, hunting(se))
    case false{}:
      base

def fp_go(si: U32, se: Ent, iw: List(IEnt), consumed: List(U32), acc: Near) -> Near:
  match iw:
    case []:
      acc
    case h<>t:
      match h:
        case ient{j, c}:
          skip = bor(U32/eq(j, si), bor(u32_mem(j, consumed), bor(Bool/not(edible(se, c)), Bool/not(within_range(se, c)))));
          match skip:
            case true{}:
              fp_go(si, se, t, consumed, acc)
            case false{}:
              dx = e_x(se) - e_x(c);
              dy = e_y(se) - e_y(c);
              d2 = (dx * dx) + (dy * dy);
              fp_go(si, se, t, consumed, better(acc, d2, U32/to_f32(j), 0.0))

def find_prey(si: U32, se: Ent, iw: List(IEnt), consumed: List(U32)) -> Near:
  fp_go(si, se, iw, consumed, near{false{}, 0.0, 0.0, 0.0})

# A predator may claim a meal only if it is a fish AND off its eat cooldown.
def claim(iw_all: List(IEnt), rest: List(IEnt), acc: ClaimAcc) -> ClaimAcc:
  match rest:
    case []:
      acc
    case h<>t:
      match h:
        case ient{i, e}:
          ready = Bool/and(is_fish(e), can_act(e));
          match ready:
            case false{}:
              claim(iw_all, t, acc)
            case true{}:
              match acc:
                case cacc{cons, gr}:
                  match find_prey(i, e, iw_all, cons):
                    case near{ok, jx, _, _}:
                      match ok:
                        case false{}:
                          claim(iw_all, t, acc)
                        case true{}:
                          j  = F32/to_u32(jx);
                          pe = lookup_ent(iw_all, j);
                          claim(iw_all, t, cacc{j <> cons, grant{i, e_stage(pe)} <> gr})

def grant_for(i: U32, gr: List(Grant)) -> Maybe(Stage):
  match gr:
    case []:
      none{}
    case h<>t:
      match h:
        case grant{pi, ps}:
          if U32/eq(pi, i):
            some{ps}
          else:
            grant_for(i, t)

# Apply growth/promotion to a predator that ate prey of stage `ps` this frame.
# Size grows on every meal and the 1-second `timer` always resets.
#   fry     : +FRY_GROW per egg; matures after FRY_MEALS.
#   juvenile  : +JUV_GROW per fry; matures after JUV_MEALS; hunt clock resets
#               each meal (so it hunts one fry per ~10s).
#   adult     : grows ×ADULT_MUL per fish and accumulates the prey's cycle cost
#               in `fed`; the 10-second hunt clock `hu` resets ONLY when the
#               cycle fills (CYCLE_CAP) — so an adult feeds repeatedly (5 fry
#               / 2 juveniles / 1 adult) and only THEN cools down for ~10s.
def grow_ent(e: Ent, ps: Stage) -> Ent:
  match e:
    case ent{st, x, y, vx, vy, sz, tm, hh, fd, rg, fc}:
      match st:
        case fry{}:
          nf = fd + 1;
          ns = sz + FRY_GROW;
          if U32/gte(nf, FRY_MEALS):
            ent{juvenile{}, x, y, vx, vy, ns, 0, 0, 0, rg, fc}
          else:
            ent{fry{}, x, y, vx, vy, ns, 0, hh, nf, rg, fc}
        case juvenile{}:
          match ps:
            case fry{}:
              # ate a fry: grow, count toward adulthood, reset the hunt clock
              nf = fd + 1;
              ns = sz + JUV_GROW;
              if U32/gte(nf, JUV_MEALS):
                ent{adult{}, x, y, vx, vy, ns, 0, 0, 0, rg, fc}
              else:
                ent{juvenile{}, x, y, vx, vy, ns, 0, 0, nf, rg, fc}
            case _:
              # ate an egg: just consume it — no growth, no maturation
              ent{juvenile{}, x, y, vx, vy, sz, 0, hh, fd, rg, fc}
        case adult{}:
          ns    = sz * ADULT_MUL;
          ncost = fd + stage_cost(ps);
          if U32/gte(ncost, CYCLE_CAP):
            ent{adult{}, x, y, vx, vy, ns, 0, 0, 0, rg, fc}     # cycle full: cool down ~10s
          else:
            ent{adult{}, x, y, vx, vy, ns, 0, hh, ncost, rg, fc} # keep feeding this cycle
        case egg{}:
          e

def rebuild(iw: List(IEnt), consumed: List(U32), gr: List(Grant)) -> List(Ent):
  match iw:
    case []:
      []
    case h<>t:
      match h:
        case ient{i, e}:
          if u32_mem(i, consumed):
            rebuild(t, consumed, gr)            # eaten this frame: gone
          else:
            match grant_for(i, gr):
              case none{}:
                e <> rebuild(t, consumed, gr)
              case some{ps}:
                grow_ent(e, ps) <> rebuild(t, consumed, gr)

def any_broken(es: List(Ent)) -> Bool:
  match es:
    case []:
      false{}
    case h<>t:
      match e_stage(h):
        case adult{}:
          if F32/gte(e_size(h), BREAK_SIZE):
            true{}
          else:
            any_broken(t)
        case _:
          any_broken(t)

def do_eat(ents: List(Ent)) -> EatRes:
  iw = enumerate(ents);
  match claim(iw, iw, cacc{[], []}):
    case cacc{consumed, gr}:
      ents2 = rebuild(iw, consumed, gr);
      eres{ents2, any_broken(ents2), count_stage(ents2, 3)}   # score = adults

# ============================================================
# One simulation step.
# ============================================================

def one_tick(s: State) -> State:
  match s:
    case state{ents, tick, rng, phase, pouring, pourx, poury}:
      match phase:
        case phase_play{}:
          tick1 = tick + 1;
          match do_eat(ents):
            case eres{ents_e, broke, score}:
              match broke:
                case true{}:
                  state{ents_e, tick1, rng, phase_over{score, tick1}, false{}, pourx, poury}
                case false{}:
                  state{move_all(ents_e, tick1), tick1, rng, phase, pouring, pourx, poury}
        case phase_over{score, at}:
          tick1 = tick + 1;
          state{fall_all(ents), tick1, rng, phase_over{score, at}, false{}, pourx, poury}
        case phase_start{}:
          s

# ============================================================
# Spawning eggs
# ============================================================

type Spawn {
  sp{ents: List(Ent), rng: U32}
}

def add_eggs(n: U32, ents: List(Ent), x: F32, y: F32, rng: U32) -> Spawn:
  if U32/eq(n, 0):
    sp{ents, rng}
  else:
    r1 = rng_next(rng);
    r2 = rng_next(r1);
    ox = rand_unit(r1) * 14.0;
    vx = rand_unit(r2) * 0.4;
    ex = clampf(x + ox, 6.0, WF - 6.0);
    ey = clampf(y, 4.0, WATER_Y - 4.0);        # eggs always enter above water
    ne = ent{egg{}, ex, ey, vx, 0.2, 1.0, 0, 0, 0, r2, true{}} :: Ent;
    add_eggs(U32/saturating_sub(n, 1), ne <> ents, x, y, r2)

def list_len(es: List(Ent)) -> U32:
  List/length(Ent, es)

# Pour eggs only when the source is ABOVE the waterline and we are under the cap.
# Eggs only enter above the waterline. (No entity cap — the world is unbounded.)
def spawn_eggs_at(n: U32, ents: List(Ent), x: F32, y: F32, rng: U32) -> Spawn:
  match F32/lt(y, WATER_Y):
    case true{}:
      add_eggs(n, ents, x, y, rng)
    case false{}:
      sp{ents, rng}

# While the mouse is held over the air, keep trickling eggs in.
def pour_step(s: State) -> State:
  match s:
    case state{ents, tick, rng, phase, pouring, pourx, poury}:
      match phase:
        case phase_play{}:
          match pouring:
            case true{}:
              match spawn_eggs_at(POUR_N, ents, pourx, poury, rng):
                case sp{e2, r2}:
                  state{e2, tick, r2, phase, pouring, pourx, poury}
            case false{}:
              s
        case _:
          s

# ============================================================
# Init + events
# ============================================================

init : App/Update(State, Event) =
  update{state{[], 0, 777, phase_start{}, false{}, 0.0, 0.0}, none{}}

def press_event(ptr: HTML/Pointer) -> Event:
  match ptr:
    case pointer{_, x, y, _, _}:
      press{I32/to_u32(x), I32/to_u32(y)}

def move_event(ptr: HTML/Pointer) -> Event:
  match ptr:
    case pointer{_, x, y, _, _}:
      move{I32/to_u32(x), I32/to_u32(y)}

def release_event(ptr: HTML/Pointer) -> Event:
  release{}

def on_event(e: Event, s: State) -> App/Update(State, Event):
  match e:
    case press{px, py}:
      fx = U32/to_f32(px);
      fy = U32/to_f32(py);
      match s:
        case state{ents, tick, rng, phase, _, _, _}:
          match phase:
            case phase_play{}:
              match spawn_eggs_at(SPAWN_N, ents, fx, fy, rng):
                case sp{e2, r2}:
                  update{state{e2, tick, r2, phase_play{}, true{}, fx, fy}, none{}}
            case _:
              match spawn_eggs_at(SPAWN_N, [], fx, fy, rng):
                case sp{e2, r2}:
                  update{state{e2, 0, r2, phase_play{}, true{}, fx, fy}, none{}}
    case move{px, py}:
      fx = U32/to_f32(px);
      fy = U32/to_f32(py);
      match s:
        case state{ents, tick, rng, phase, pouring, _, _}:
          update{state{ents, tick, rng, phase, pouring, fx, fy}, none{}}
    case release{}:
      match s:
        case state{ents, tick, rng, phase, _, pourx, poury}:
          update{state{ents, tick, rng, phase, false{}, pourx, poury}, none{}}
    case tick_ev{}:
      update{pour_step(one_tick(s)), none{}}

# ============================================================
# Rendering
# ============================================================

def color_body(st: Stage) -> String:
  match st:
    case egg{}:
      COL_EGG
    case fry{}:
      COL_BROWN
    case juvenile{}:
      COL_GREEN
    case adult{}:
      COL_DBLUE

def pick2(idx: U32, a: String, b: String) -> String:
  match idx:
    case 0:
      a
    case _:
      b

def transform_of(fc: Bool) -> String:
  match fc:
    case true{}:
      "translate(-50%,-50%) scaleX(-1)"
    case false{}:
      "translate(-50%,-50%)"

# Live sprite glyphs. The tail flaps (frame swap) on every stage.
def fish_inner(st: Stage, idx: U32) -> List(HTML(Event)):
  match st:
    case fry{}:
      [text{pick2(idx, "o<", "o«")}]
    case juvenile{}:
      [text{pick2(idx, "(O<", "(O«")}]
    case adult{}:
      [text{pick2(idx, "(.* )<3", "(.* )«3")}]
    case egg{}:
      []

# Dead (game-over) glyphs: X eyes, no animation.
def dead_inner(st: Stage) -> List(HTML(Event)):
  match st:
    case fry{}:
      [text{"x<"}]
    case juvenile{}:
      [text{"(X<"}]
    case adult{}:
      [text{"(X )<3"}]
    case egg{}:
      []

def inner_for(st: Stage, idx: U32, dead: Bool) -> List(HTML(Event)):
  match dead:
    case true{}:
      dead_inner(st)
    case false{}:
      fish_inner(st, idx)

def egg_dot(e: Ent) -> HTML(Event):
  match e:
    case ent{_, x, y, _, _, _, _, _, _, _, _}:
      <div
        style:position={"absolute"}
        style:left={px_of(x - 3.0)}
        style:top={px_of(y - 3.0)}
        style:width={"6px"}
        style:height={"6px"}
        style:border-radius={"50%"}
        style:background={COL_EGG}
        style:box-shadow={"0 0 5px #ffb066"}
        style:pointer-events={"none"}
      />

def fish_sprite(e: Ent, tick: U32, dead: Bool) -> HTML(Event):
  match e:
    case ent{st, x, y, _, _, _, _, _, _, rg, fc}:
      idx   = (((tick // FRAME_TICKS) + rg) % 2);
      inner = inner_for(st, idx, dead);
      <div
        style:position={"absolute"}
        style:left={px_of(x)}
        style:top={px_of(y)}
        style:transform={transform_of(fc)}
        style:font-size={fontpx_str(e)}
        style:font-family={"monospace"}
        style:font-weight={"bold"}
        style:color={color_body(st)}
        style:white-space={"nowrap"}
        style:line-height={"1"}
        style:pointer-events={"none"}
        style:user-select={"none"}
      >
        {...inner}
      </div>

def sprite(e: Ent, tick: U32, dead: Bool) -> HTML(Event):
  match e_stage(e):
    case egg{}:
      egg_dot(e)
    case _:
      fish_sprite(e, tick, dead)

def render_sprites(ents: List(Ent), tick: U32, dead: Bool) -> List(HTML(Event)):
  List/map(Ent, HTML(Event), ents, (e) => sprite(e, tick, dead))

# --- Wavy water surface (drops by `drop` px while draining) ----------------

def wave_surface_y(i: U32, tick: U32, drop: F32) -> F32:
  ph = (U32/to_f32(tick) * WAVE_SPEED) + (U32/to_f32(i) * WAVE_FREQ);
  WATER_Y + drop + (F32/sin(ph) * WAVE_AMP)

def wave_seg(i: U32, tick: U32, drop: F32) -> HTML(Event):
  sy = wave_surface_y(i, tick, drop);
  <div
    style:position={"absolute"}
    style:left={U32/show(i * SEG_W) ++ "px"}
    style:top={px_of(sy)}
    style:width={U32/show(SEG_W + 1) ++ "px"}
    style:height={px_of(HF - sy)}
    style:background={"linear-gradient(180deg, rgba(120,205,235,0.55), rgba(40,120,175,0.78))"}
    style:pointer-events={"none"}
  />

def wave_crest(i: U32, tick: U32, drop: F32) -> HTML(Event):
  sy = wave_surface_y(i, tick, drop);
  <div
    style:position={"absolute"}
    style:left={U32/show(i * SEG_W) ++ "px"}
    style:top={px_of(sy)}
    style:width={U32/show(SEG_W + 1) ++ "px"}
    style:height={"3px"}
    style:background={"rgba(225,248,255,0.8)"}
    style:pointer-events={"none"}
  />

def wave_go(i: U32, tick: U32, drop: F32) -> List(HTML(Event)):
  if U32/gte(i, N_WAVE):
    []
  else:
    wave_seg(i, tick, drop) <> (wave_crest(i, tick, drop) <> wave_go(i + 1, tick, drop))

def waves(tick: U32, drop: F32) -> List(HTML(Event)):
  wave_go(0, tick, drop)

# --- Cube side walls (open top; they shatter on game over) -----------------

# Transform for a side wall: identity while playing, flung outward + spinning
# during the break (sgn = -1 left, +1 right).
def wall_tf(phase: Phase, tick: U32, sgn: F32) -> String:
  match phase:
    case phase_over{_, at}:
      t   = U32/to_f32(U32/saturating_sub(tick, at));
      dx  = sgn * (t * 8.0);
      dy  = t * 3.0;
      rot = sgn * (t * 3.0);
      "translate(" ++ fshow(dx) ++ "px, " ++ fshow(dy) ++ "px) rotate(" ++ fshow(rot) ++ "deg)"
    case _:
      "none"

def wall_opacity(phase: Phase, tick: U32) -> String:
  match phase:
    case phase_over{_, at}:
      t = U32/to_f32(U32/saturating_sub(tick, at));
      fshow(clampf(1.0 - (t * 0.03), 0.0, 1.0))
    case _:
      "1"

def cube_left(phase: Phase, tick: U32) -> HTML(Event):
  <div
    style:position={"absolute"}
    style:left={"0px"}
    style:top={"0px"}
    style:width={"620px"}
    style:height={"380px"}
    style:background={"rgba(110,175,210,0.38)"}
    style:clip-path={"polygon(0px 16px, 30px 0px, 30px 380px, 0px 364px)"}
    style:transform-origin={"15px 190px"}
    style:transform={wall_tf(phase, tick, 0.0 - 1.0)}
    style:opacity={wall_opacity(phase, tick)}
    style:pointer-events={"none"}
  />

def cube_right(phase: Phase, tick: U32) -> HTML(Event):
  <div
    style:position={"absolute"}
    style:left={"0px"}
    style:top={"0px"}
    style:width={"620px"}
    style:height={"380px"}
    style:background={"rgba(60,130,175,0.42)"}
    style:clip-path={"polygon(590px 0px, 620px 16px, 620px 364px, 590px 380px)"}
    style:transform-origin={"605px 190px"}
    style:transform={wall_tf(phase, tick, 1.0)}
    style:opacity={wall_opacity(phase, tick)}
    style:pointer-events={"none"}
  />

# --- Tank-break shards ----------------------------------------------------

def shard(sx: F32, sy: F32, dx: F32, dy: F32, ofr: U32) -> HTML(Event):
  t   = U32/to_f32(ofr);
  x   = sx + (dx * t * SHARD_SPEED);
  y   = sy + (dy * t * SHARD_SPEED) + (t * t * 0.10);
  rot = U32/show(F32/to_u32(t * 9.0));
  <div
    style:position={"absolute"}
    style:left={px_of(x)}
    style:top={px_of(y)}
    style:width={"18px"}
    style:height={"18px"}
    style:background={"rgba(214,242,255,0.85)"}
    style:clip-path={"polygon(0% 0%, 100% 40%, 35% 100%)"}
    style:transform={"rotate(" ++ rot ++ "deg)"}
    style:box-shadow={"0 0 6px rgba(200,240,255,0.7)"}
    style:pointer-events={"none"}
  />

def shards(ofr: U32) -> List(HTML(Event)):
  [ shard(280.0, 180.0, 0.0 - 1.0, 0.0 - 0.8, ofr),
    shard(280.0, 180.0, 1.0,       0.0 - 0.8, ofr),
    shard(280.0, 180.0, 0.0 - 1.3, 0.2,       ofr),
    shard(280.0, 180.0, 1.3,       0.2,       ofr),
    shard(180.0, 120.0, 0.0 - 0.9, 0.0 - 1.0, ofr),
    shard(380.0, 120.0, 0.9,       0.0 - 1.0, ofr),
    shard(120.0, 200.0, 0.0 - 1.4, 0.0 - 0.3, ofr),
    shard(440.0, 200.0, 1.4,       0.0 - 0.3, ofr),
    shard(220.0, 250.0, 0.0 - 0.7, 0.6,       ofr),
    shard(340.0, 250.0, 0.7,       0.6,       ofr),
    shard(280.0, 100.0, 0.1,       0.0 - 1.4, ofr),
    shard(300.0, 300.0, 0.4,       0.7,       ofr) ] :: List(HTML(Event))

def break_fx(phase: Phase, tick: U32) -> List(HTML(Event)):
  match phase:
    case phase_over{_, at}:
      shards(U32/saturating_sub(tick, at))
    case _:
      []

# How far the water level has dropped (0 unless the tank is draining).
def drain_drop(phase: Phase, tick: U32) -> F32:
  match phase:
    case phase_over{_, at}:
      U32/to_f32(U32/saturating_sub(tick, at)) * DRAIN_SPEED
    case _:
      0.0

# --- Overlays -------------------------------------------------------------

def hidden() -> HTML(Event):
  <div style:display={"none"}/>

def overlay_panel(title: String, sub: String, note: String) -> HTML(Event):
  <div
    style:position={"absolute"}
    style:left={"0px"}
    style:top={"0px"}
    style:width={"560px"}
    style:height={"380px"}
    style:display={"flex"}
    style:flex-direction={"column"}
    style:align-items={"center"}
    style:justify-content={"center"}
    style:background={"rgba(8,26,40,0.55)"}
    style:color={"#eaffff"}
    style:text-align={"center"}
    style:pointer-events={"none"}
  >
    <div style:font-size={"30px"} style:font-weight={"800"} style:margin-bottom={"10px"} style:text-shadow={"0 2px 8px #000a"}>
      {text{title}}
    </div>
    <div style:font-size={"17px"} style:font-weight={"700"} style:opacity={"0.95"}>
      {text{sub}}
    </div>
    <div style:font-size={"13px"} style:opacity={"0.8"} style:margin-top={"6px"}>
      {text{note}}
    </div>
  </div>

def start_overlay(phase: Phase) -> HTML(Event):
  match phase:
    case phase_start{}:
      overlay_panel("🐠  Aquarium", "Click or hold above the water to pour eggs", "Grow an adult big enough to break the tank")
    case _:
      hidden()

def over_overlay(phase: Phase, ents: List(Ent), tick: U32) -> HTML(Event):
  match phase:
    case phase_over{score, at}:
      ready = U32/gte(U32/saturating_sub(tick, at), OVER_PANEL_DELAY);
      match ready:
        case false{}:
          hidden()
        case true{}:
          la = count_stage(ents, 1);
          ju = count_stage(ents, 2);
          sub  = "Score: " ++ U32/show(score) ++ " adult fish";
          note = "(also " ++ U32/show(la) ++ " fry and " ++ U32/show(ju) ++ " juveniles)  ·  click to play again";
          overlay_panel("💥  The tank shattered!", sub, note)
    case _:
      hidden()

# --- HUD / rules ----------------------------------------------------------

def hud(s: State) -> HTML(Event):
  match s:
    case state{ents, _, _, _, _, _, _}:
      txt = "Adults: " ++ U32/show(count_stage(ents, 3)) ++ "   ·   juveniles: " ++ U32/show(count_stage(ents, 2)) ++ "   ·   fry: " ++ U32/show(count_stage(ents, 1));
      <div style="margin:0 0 8px 0; color:#cfeaf5; font-size:14px; font-weight:600;">
        {text{txt}}
      </div>

def rules_panel() -> HTML(Event):
  <div style="margin-top:12px; max-width:600px; padding:12px 14px; background:#0b2233; border:1px solid #16465e; border-radius:10px; color:#bfe0ef; font-size:13px; line-height:1.55;">
    <div style="font-weight:700; color:#7fdfff; margin-bottom:4px;">{text{"How it works"}}</div>
    <div>{text{"• Click — or hold — above the waterline to pour eggs. They fall in, then sink."}}</div>
    <div>{text{"• An egg left alone hatches into a fry  o<  — fry school together and eat eggs."}}</div>
    <div>{text{"• A grown fry becomes a juvenile  (O< ;  it eats 5 fry to become an adult  (.* )<3  (eggs don't grow it)."}}</div>
    <div>{text{"• A fish eats once per second, and only sets off to hunt another fish once every ten seconds."}}</div>
    <div>{text{"• Adults eat ANY fish up to half their size — even other adults — and keep growing to shatter the tank."}}</div>
    <div style="margin-top:4px; opacity:0.8;">{text{"Your score is the number of ADULT fish alive when it breaks."}}</div>
  </div>

# --- Top-level render -----------------------------------------------------

def over_dead(phase: Phase) -> Bool:
  match phase:
    case phase_over{_, _}:
      true{}
    case _:
      false{}

# Attributes of the interactive water box. The `pointer_move` listener is only
# attached while POURING — otherwise plain hovering would fire a `move` event
# (and a full re-render) on every mouse motion, which lags the whole scene.
def face_attrs(pouring: Bool) -> List(HTML/Attr(Event)):
  base = [
    on{pointer_down{press_event}},
    on{pointer_up{release_event}},
    on{pointer_leave{release_event}},
    style{"position", "absolute"},
    style{"left", "30px"},
    style{"top", "0px"},
    style{"width", "560px"},
    style{"height", "380px"},
    style{"overflow", "visible"},
    style{"background", "linear-gradient(180deg, rgba(190,232,246,0.16), rgba(110,185,222,0.30))"},
    style{"border-left", "2px solid rgba(150,200,225,0.8)"},
    style{"border-right", "2px solid rgba(150,200,225,0.8)"},
    style{"border-bottom", "2px solid rgba(150,200,225,0.8)"},
    style{"box-shadow", "inset 0 0 40px rgba(20,70,110,0.4)"},
    style{"cursor", "crosshair"}
  ] :: List(HTML/Attr(Event));
  match pouring:
    case true{}:
      on{pointer_move{move_event}} <> base
    case false{}:
      base

def front_face(pouring: Bool, inside: List(HTML(Event))) -> HTML(Event):
  node{"div", face_attrs(pouring), inside}

def render(s: State) -> HTML(Event):
  match s:
    case state{ents, tick, _, phase, pouring, _, _}:
      dead    = over_dead(phase);
      sprites = render_sprites(ents, tick, dead);
      wv      = waves(tick, drain_drop(phase, tick));
      fx      = break_fx(phase, tick);
      overlays = [start_overlay(phase), over_overlay(phase, ents, tick)] :: List(HTML(Event));
      inside0 = List/append(HTML(Event), wv, sprites);
      inside1 = List/append(HTML(Event), inside0, fx);
      inside  = List/append(HTML(Event), inside1, overlays);
      <div style="font-family: system-ui, sans-serif; padding:16px; background:#06121b; min-height:100vh;" every_ms={FRAME_MS, tick_ev{}}>
        <style>{text{css}}</style>
        <div style="color:#7fdfff; font-size:22px; font-weight:800; margin-bottom:8px;">{text{"Aquarium"}}</div>
        {hud(s)}
        <div
          style:position={"relative"}
          style:width={"620px"}
          style:height={"380px"}
        >
          {cube_left(phase, tick)}
          {cube_right(phase, tick)}
          {front_face(pouring, inside)}
        </div>
        {rules_panel()}
      </div>

css : String = "
  body { margin: 0; }
"

def debug(s: State) -> String:
  match s:
    case state{ents, tick, _, _, _, _, _}:
      "tick=" ++ U32/show(tick) ++ " adults=" ++ U32/show(count_stage(ents, 3)) ++ " n=" ++ U32/show(list_len(ents))

main : App = app{State, Event, init, render, on_event, debug}
