# Aquarium - a tiny aquatic ecosystem in Bend 2.
#
# An open-topped glass tank of water with an animated wavy surface. Click - or
# hold - above the waterline to pour orange eggs. They fall through the air,
# then sink. An egg left untouched long enough hatches into a fry. Fry school
# together and eat eggs; juveniles eat fry; adults hunt any fish up to half
# their size. A fish may eat once per second, and may only set off to chase
# another FISH once every ten seconds. Grow an adult too big for the tank and
# the side walls shatter. Your score is the number of ADULT fish alive then.
#
# Unlike growing_tree (a discrete cellular grid), the aquarium lives in
# CONTINUOUS space: every creature is a record with floating-point position
# and velocity, updated each tick by simple steering forces.
#
# The program is an `App`: `Aq.view` draws the state as an `Image` quadtree,
# `Aq.step` folds a frame's events and advances the simulation on a 45 ms
# clock (about 22 ticks per second, whatever the display rate). Both are pure,
# so the browser page (web/index.html) and test.bend call them directly.
#
#   bend main.bend -o aquarium && ./aquarium     # native X11 window, 620 x 380
#   sh build.sh                                  # check, tests, web build
import Base

# ============================================================
# Types
# ============================================================

# Life stage. `Egg` is the food you pour in.
type Stage is Data:
  Egg{}
  Fry{}
  Juv{}
  Adult{}

# One creature. Eggs and fish share the same record so the world is a
# single flat list we can fold over uniformly.
#   x,y    : center position in pixels of the front face
#   vx,vy  : velocity in px/tick
#   size   : abstract scale used for sprite size AND the prey size-cap
#   timer  : eggs -> ticks sinking (hatch countdown);
#            fish -> ticks since its last meal (the 1-second eat cooldown)
#   hu     : fish -> ticks since its last FISH meal (the 10-second hunt clock)
#   fed    : fry -> eggs eaten; juveniles -> fry eaten; adults -> cycle units
#   rng    : per-creature random seed, so each one wanders differently
#   face   : True = facing right
type Ent is Data:
  Ent{stage: Stage, x: F32, y: F32, vx: F32, vy: F32, size: F32, timer: U32,
    hu: U32, fed: U32, rng: U32, face: Bool}

type V2 is Data:
  V2{x: F32, y: F32}

# Result of a "nearest matching entity" search.
type Near is Data:
  Near{ok: Bool, x: F32, y: F32, d: F32}

# Result of a prey search: the prey's index `j` at squared distance `d`.
type Pick is Data:
  Pick{ok: Bool, j: U32, d: F32}

# Fry swarm accumulator (count + summed positions + summed velocities).
type Swarm is Data:
  Sw{n: U32, sx: F32, sy: F32, vx: F32, vy: F32}

# Entity paired with its index, for the eating-assignment pass.
type IEnt is Data:
  IEnt{i: U32, e: Ent}

# A granted meal: predator index `pi` ate prey whose life stage is `ps`.
type Grant is Data:
  Grant{pi: U32, ps: Stage}

# Claim pass accumulator: consumed prey indices and granted meals.
type Claim is Data:
  Claim{consumed: +List<U32>, grants: +List<Grant>}

# Output of one eating pass.
type EatRes is Data:
  EatRes{ents: +List<Ent>, broke: Bool, score: U32}

# Whole-game phase. `Over` remembers the score (adult fish) and the tick the
# tank broke, so the shatter animation can play from there.
type Phase is Data:
  Start{}
  Play{}
  Over{score: U32, at: U32}

# Top-level state. `pouring` + (px, py) drive hold-to-pour; `clock` is the
# millisecond time of the last simulation tick (0 = not started); `told`
# records that the game-over line was printed.
type Aq is Data:
  Aq{ents: +List<Ent>, tick: U32, rng: U32, phase: Phase, pouring: Bool,
    px: F32, py: F32, clock: U32, told: Bool}

type Spawn is Data:
  Spawn{ents: +List<Ent>, rng: U32}

# ============================================================
# Constants (tune freely)
# ============================================================

# Cube front-face size, in pixels. Sim coordinates live in [0,WF]x[0,HF].
def WF() -> F32:
  560.0

def HF() -> F32:
  380.0

# Iso-depth of the cube (thickness of the side walls): the front face sits
# at x = DZ in the 620 x 380 window.
def DZ() -> F32:
  30.0

# Surface (waterline) y, and the sandy floor y.
def WATER_Y() -> F32:
  72.0

def FLOOR() -> F32:
  374.0

# Simulation tick interval (ms). ~22 ticks/second.
def FRAME_MS() -> U32:
  45

# At most this many ticks catch up in one frame.
def MAX_CATCHUP() -> U32:
  3

# Ticks that count as time. Egg hatches after ~7s; a fish may only eat once
# per second; a juvenile/adult only sets off to chase a fish once per ~10s.
def HATCH_TICKS() -> U32:
  150

def EAT_COOLDOWN() -> U32:
  22

def HUNT_PERIOD() -> U32:
  220

# Air physics: gentle gravity, capped fall speed.
def AIR_GRAV() -> F32:
  0.06

def AIR_MAXFALL() -> F32:
  2.2

# Water physics: slow terminal sink speed.
def SINK_SPEED() -> F32:
  0.5

# Growth / lifecycle thresholds.
def PREY_RATIO() -> F32:
  0.5

def FRY_BORN() -> F32:
  3.0

def FRY_GROW() -> F32:
  1.3

def FRY_MEALS() -> U32:
  12

def JUV_GROW() -> F32:
  2.0

def JUV_MEALS() -> U32:
  5

def ADULT_MUL() -> F32:
  1.1

def BREAK_SIZE() -> F32:
  135.0

# Adult feeding cycle: 5 fry (2 each) = 2 juveniles (5) = 1 adult (10).
def FRY_COST() -> U32:
  2

def JUV_COST() -> U32:
  5

def ADULT_COST() -> U32:
  10

def CYCLE_CAP() -> U32:
  10

# Swim tuning.
def STEER() -> F32:
  0.25

def DEPTH_K() -> F32:
  0.008

def WANDER() -> F32:
  0.14

def BOB_AMP() -> F32:
  0.05

def BOB_F() -> F32:
  0.08

def MARGIN() -> F32:
  12.0

def SURF_PAD() -> F32:
  12.0

def EAT_PAD() -> F32:
  4.0

def MAX_VY() -> F32:
  1.5

# Collision: overlap limit, push strength, smaller-fish veer.
def COLLIDE_FRAC() -> F32:
  0.78

def COLL_STR() -> F32:
  0.6

def VEER() -> F32:
  0.5

# Fry swarming (boids): radius squared, cohesion and alignment.
def SWARM_R2() -> F32:
  4096.0

def COHESION() -> F32:
  0.012

def ALIGN() -> F32:
  0.06

# Spawning: eggs per tap, eggs per held tick (no entity cap).
def SPAWN_N() -> Nat:
  4n

def POUR_N() -> Nat:
  2n

# Animation: swap the tail frame every this many ticks.
def FRAME_TICKS() -> U32:
  6

# Wave: number of surface segments and their look.
def N_WAVE() -> Nat:
  56n

def SEG_W() -> F32:
  10.0

def WAVE_AMP() -> F32:
  5.0

def WAVE_SPEED() -> F32:
  0.18

def WAVE_FREQ() -> F32:
  0.5

# Tank-break animation.
def OVER_GRAV() -> F32:
  0.55

def DRAIN_SPEED() -> F32:
  13.0

def SHARD_SPEED() -> F32:
  6.5

def OVER_PANEL_DELAY() -> U32:
  24

# Colors (0xRRGGBB).
def COL_EGG() -> U32:
  16751172

def COL_BROWN() -> U32:
  8014362

def COL_GREEN() -> U32:
  1800762

def COL_DBLUE() -> U32:
  1984399

# ============================================================
# Small helpers
# ============================================================

def pickf(c: Bool, a: F32, b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

def picku(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def rng_next(s: U32) -> U32:
  (s * 1103515245 + 12345 : U32)

# Uniform-ish random float in [-1, 1) from a seed.
def rand_unit(r: U32) -> F32:
  (U32.to_f32((r % 2000 : U32)) / 1000.0 - 1.0 : F32)

def clampf(v: F32, lo: F32, hi: F32) -> F32:
  F32.max(lo, F32.min(hi, v))

def neg(x: F32) -> F32:
  (0.0 - x : F32)

# ============================================================
# Entity accessors
# ============================================================

def Ent.stage(e: Ent) -> Stage:
  Ent{s, _, _, _, _, _, _, _, _, _, _} = e
  s

def Ent.x(e: Ent) -> F32:
  Ent{_, x, _, _, _, _, _, _, _, _, _} = e
  x

def Ent.y(e: Ent) -> F32:
  Ent{_, _, y, _, _, _, _, _, _, _, _} = e
  y

def Ent.vx(e: Ent) -> F32:
  Ent{_, _, _, vx, _, _, _, _, _, _, _} = e
  vx

def Ent.vy(e: Ent) -> F32:
  Ent{_, _, _, _, vy, _, _, _, _, _, _} = e
  vy

def Ent.size(e: Ent) -> F32:
  Ent{_, _, _, _, _, sz, _, _, _, _, _} = e
  sz

def Ent.timer(e: Ent) -> U32:
  Ent{_, _, _, _, _, _, t, _, _, _, _} = e
  t

def Ent.hu(e: Ent) -> U32:
  Ent{_, _, _, _, _, _, _, h, _, _, _} = e
  h

def Ent.fed(e: Ent) -> U32:
  Ent{_, _, _, _, _, _, _, _, f, _, _} = e
  f

def Ent.rng(e: Ent) -> U32:
  Ent{_, _, _, _, _, _, _, _, _, r, _} = e
  r

def Stage.is_egg(s: Stage) -> Bool:
  match s:
    case Egg{}:
      True{}
    case _:
      False{}

def Stage.is_fry(s: Stage) -> Bool:
  match s:
    case Fry{}:
      True{}
    case _:
      False{}

def Stage.is_juv(s: Stage) -> Bool:
  match s:
    case Juv{}:
      True{}
    case _:
      False{}

def Stage.is_adult(s: Stage) -> Bool:
  match s:
    case Adult{}:
      True{}
    case _:
      False{}

def is_egg(e: Ent) -> Bool:
  Stage.is_egg(Ent.stage(e))

def is_fish(e: Ent) -> Bool:
  Bool.not(is_egg(e))

def is_fry(e: Ent) -> Bool:
  Stage.is_fry(Ent.stage(e))

def is_juv(e: Ent) -> Bool:
  Stage.is_juv(Ent.stage(e))

def is_adult(e: Ent) -> Bool:
  Stage.is_adult(Ent.stage(e))

# Count entities matching a selector: 1=fry 2=juvenile 3=adult 4=egg else=any
# fish.
def sel_match(+e: Ent, sel: U32) -> Bool:
  match sel:
    case 1:
      is_fry(e)
    case 2:
      is_juv(e)
    case 3:
      is_adult(e)
    case 4:
      is_egg(e)
    case _:
      is_fish(e)

def count_stage(+es: +List<Ent>, +sel: U32) -> U32:
  match es:
    case []:
      0
    case h <> t:
      (Bool.to_u32(sel_match(h, sel)) + count_stage(t, sel) : U32)

def count_all(+es: +List<Ent>) -> U32:
  match es:
    case []:
      0
    case h <> t:
      (1 + count_all(t) : U32)

# ============================================================
# Per-stage numeric profiles
# ============================================================

def stage_spd(st: Stage) -> F32:
  match st:
    case Egg{}:
      0.0
    case Fry{}:
      3.0
    case Juv{}:
      2.8
    case Adult{}:
      2.6

def stage_maxspd(st: Stage) -> F32:
  match st:
    case Egg{}:
      0.0
    case Fry{}:
      4.2
    case Juv{}:
      4.0
    case Adult{}:
      3.8

# Preferred depth band center: fry near the top, juveniles mid, adults near
# the floor. Just a tendency, not a hard wall.
def zone_frac(st: Stage) -> F32:
  match st:
    case Egg{}:
      0.0
    case Fry{}:
      0.16
    case Juv{}:
      0.5
    case Adult{}:
      0.82

def zone_y(st: Stage) -> F32:
  (WATER_Y() + (HF() - WATER_Y()) * zone_frac(st) : F32)

# Sprite scale (px): one continuous mapping from `size` for every fish stage,
# so a creature grows smoothly with every meal. Eggs are 6 px.
def scale_of(st: Stage, sz: F32) -> F32:
  match st:
    case Egg{}:
      6.0
    case _:
      F32.max(9.0, (6.0 + sz * 0.85 : F32))

def fontpx(+e: Ent) -> F32:
  scale_of(Ent.stage(e), Ent.size(e))

# Physical radius for contact / separation tests.
def radius_of(st: Stage, sz: F32) -> F32:
  match st:
    case Egg{}:
      3.0
    case _:
      (scale_of(Fry{}, sz) * 0.5 : F32)

def radius(+e: Ent) -> F32:
  radius_of(Ent.stage(e), Ent.size(e))

# ============================================================
# Predation rules
# ============================================================

# Life-stage tiers: who may eat whom (before the size check).
#   fry      -> eggs
#   juvenile -> eggs (no growth) + fry (grows)
#   adult    -> ANY fish (fry, juveniles, even other adults)
def tier_ok(pred: Stage, +prey: Stage) -> Bool:
  match pred:
    case Egg{}:
      False{}
    case Fry{}:
      Stage.is_egg(prey)
    case Juv{}:
      Stage.is_egg(prey) || Stage.is_fry(prey)
    case Adult{}:
      Bool.not(Stage.is_egg(prey))

# Can `pred` eat `prey`? Right tier AND prey at most HALF the predator's size.
def can_eat(+pred: Ent, +prey: Ent) -> Bool:
  tier_ok(Ent.stage(pred), Ent.stage(prey))
    && (Ent.size(prey) <= Ent.size(pred) * PREY_RATIO() : F32)

# Off the 1-second eat cooldown?
def can_act(+e: Ent) -> Bool:
  (Ent.timer(e) >= EAT_COOLDOWN() : U32)

# In hunt mode? (Only chases / eats other fish once per ~10 seconds.)
def hunting(+e: Ent) -> Bool:
  (Ent.hu(e) >= HUNT_PERIOD() : U32)

# How many feeding-cycle units a prey of this stage is worth to an adult.
def stage_cost(st: Stage) -> U32:
  match st:
    case Egg{}:
      0
    case Fry{}:
      FRY_COST()
    case Juv{}:
      JUV_COST()
    case Adult{}:
      ADULT_COST()

# ============================================================
# Targeting: find the nearest entity matching a mode.
#   eggs = True: an egg;  eggs = False: an edible prey fish.
# ============================================================

def cand_ok(eggs: Bool, +self: Ent, +c: Ent) -> Bool:
  match eggs:
    case True{}:
      is_egg(c)
    case False{}:
      is_fish(c) && can_eat(self, c)

def Near.pick(c: Bool, a: Near, b: Near) -> Near:
  match c:
    case True{}:
      a
    case False{}:
      b

def Near.better(acc: Near, +d: F32, +x: F32, +y: F32) -> Near:
  Near{+ok, ax, ay, +ad} = acc
  Near.pick(Bool.not(ok) || (d < ad : F32), Near{True{}, x, y, d},
    Near{ok, ax, ay, ad})

def Near.ok(n: Near) -> Bool:
  Near{ok, _, _, _} = n
  ok

def nw_try(ok: Bool, +self: Ent, +h: Ent, acc: Near) -> Near:
  match ok:
    case False{}:
      acc
    case True{}:
      +dx = (Ent.x(self) - Ent.x(h) : F32)
      +dy = (Ent.y(self) - Ent.y(h) : F32)
      Near.better(acc, (dx * dx + dy * dy : F32), Ent.x(h), Ent.y(h))

def nw_go(+world: +List<Ent>, +eggs: Bool, +self: Ent, acc: Near) -> Near:
  match world:
    case []:
      acc
    case h <> t:
      nw_go(t, eggs, self, nw_try(cand_ok(eggs, self, h), self, h, acc))

def nearest(+self: Ent, +world: +List<Ent>, eggs: Bool) -> Near:
  nw_go(world, eggs, self, Near{False{}, 0.0, 0.0, 0.0})

# Return `a` if it found something, otherwise fall back to `b`.
def prefer(+a: Near, b: Near) -> Near:
  Near.pick(Near.ok(a), a, b)

def target_hunt(st: Stage, hunt: Bool, +self: Ent, +world: +List<Ent>) -> Near:
  match st:
    case Egg{}:
      Near{False{}, 0.0, 0.0, 0.0}
    case Fry{}:
      nearest(self, world, True{})
    case Juv{}:
      match hunt:
        case True{}:
          prefer(nearest(self, world, False{}), nearest(self, world, True{}))
        case False{}:
          nearest(self, world, True{})
    case Adult{}:
      match hunt:
        case True{}:
          nearest(self, world, False{})
        case False{}:
          Near{False{}, 0.0, 0.0, 0.0}

# What should this creature swim toward right now? Fry and juveniles graze
# eggs; a juvenile or adult only sets off after a fish while it is in hunt
# mode (and then keeps feeding until its cycle is done, for adults).
def target_of(+self: Ent, +world: +List<Ent>) -> Near:
  target_hunt(Ent.stage(self), hunting(self), self, world)

# ============================================================
# Fry swarming (cohesion + alignment among nearby fry).
# ============================================================

def sw_try(ok: Bool, +h: Ent, acc: Swarm) -> Swarm:
  match ok:
    case False{}:
      acc
    case True{}:
      Sw{n, sx, sy, vx, vy} = acc
      Sw{(n + 1 : U32), (sx + Ent.x(h) : F32), (sy + Ent.y(h) : F32),
        (vx + Ent.vx(h) : F32), (vy + Ent.vy(h) : F32)}

def sw_near(+self: Ent, +h: Ent) -> Bool:
  +dx = (Ent.x(h) - Ent.x(self) : F32)
  +dy = (Ent.y(h) - Ent.y(self) : F32)
  +d2 = (dx * dx + dy * dy : F32)
  is_fry(h) && (0.01 < d2 : F32) && (d2 < SWARM_R2() : F32)

def swarm_go(+world: +List<Ent>, +self: Ent, acc: Swarm) -> Swarm:
  match world:
    case []:
      acc
    case h <> t:
      swarm_go(t, self, sw_try(sw_near(self, h), h, acc))

def swarm_fin(acc: Swarm, +self: Ent) -> V2:
  Sw{+n, sx, sy, vx, vy} = acc
  +fn = pickf(U32.is_eq(n, 0), 1.0, U32.to_f32(n))
  +k = pickf(U32.is_eq(n, 0), 0.0, 1.0)
  +cohx = ((sx / fn - Ent.x(self)) * COHESION() : F32)
  +cohy = ((sy / fn - Ent.y(self)) * COHESION() : F32)
  +alix = ((vx / fn - Ent.vx(self)) * ALIGN() : F32)
  +aliy = ((vy / fn - Ent.vy(self)) * ALIGN() : F32)
  V2{((cohx + alix) * k : F32), ((cohy + aliy) * k : F32)}

def swarm_if(fry: Bool, +self: Ent, +world: +List<Ent>) -> V2:
  match fry:
    case False{}:
      V2{0.0, 0.0}
    case True{}:
      swarm_fin(swarm_go(world, self, Sw{0, 0.0, 0.0, 0.0, 0.0}), self)

def swarm(+self: Ent, +world: +List<Ent>) -> V2:
  swarm_if(is_fry(self), self, world)

# ============================================================
# Collision: gentle repulsion + the smaller fish veers aside. Predator/prey
# pairs are skipped (that overlap turns into a meal in the eating pass).
# ============================================================

def veer_amt(+self: Ent, +h: Ent) -> F32:
  pickf((Ent.size(self) < Ent.size(h) : F32),
    (VEER() * pickf(U32.is_eq((Ent.rng(self) % 2 : U32), 0), 1.0, neg(1.0)) : F32),
    0.0)

def coll_push(hit: Bool, +self: Ent, +h: Ent, +dx: F32, +dy: F32, +d2: F32,
  +lim: F32) -> V2:
  match hit:
    case False{}:
      V2{0.0, 0.0}
    case True{}:
      +d = F32.sqrt(d2)
      +ux = (dx / d : F32)
      +uy = (dy / d : F32)
      +w = (Ent.size(h) / (Ent.size(self) + Ent.size(h)) : F32)
      +push = (COLL_STR() * (w * ((lim - d) / lim)) : F32)
      +vsg = veer_amt(self, h)
      V2{(ux * push + neg(uy) * vsg : F32), (uy * push + ux * vsg : F32)}

def coll_calc(+self: Ent, +h: Ent) -> V2:
  +dx = (Ent.x(self) - Ent.x(h) : F32)
  +dy = (Ent.y(self) - Ent.y(h) : F32)
  +d2 = (dx * dx + dy * dy : F32)
  +lim = ((radius(self) + radius(h)) * COLLIDE_FRAC() : F32)
  coll_push((0.01 < d2 : F32) && (d2 < lim * lim : F32), self, h, dx, dy, d2,
    lim)

def coll_one(skip: Bool, +self: Ent, +h: Ent) -> V2:
  match skip:
    case True{}:
      V2{0.0, 0.0}
    case False{}:
      coll_calc(self, h)

def V2.add(a: V2, b: V2) -> V2:
  V2{ax, ay} = a
  V2{bx, by} = b
  V2{(ax + bx : F32), (ay + by : F32)}

def V2.x(v: V2) -> F32:
  V2{x, _} = v
  x

def V2.y(v: V2) -> F32:
  V2{_, y} = v
  y

def coll_go(+world: +List<Ent>, +self: Ent, acc: V2) -> V2:
  match world:
    case []:
      acc
    case h <> t:
      +skip = is_egg(h) || can_eat(self, h) || can_eat(h, self)
      coll_go(t, self, V2.add(acc, coll_one(skip, self, h)))

def coll_vec(+self: Ent, +world: +List<Ent>) -> V2:
  coll_go(world, self, V2{0.0, 0.0})

# ============================================================
# Steering toward the chosen target.
# ============================================================

def steer_go(ok: Bool, +st: Stage, +x: F32, +y: F32, +vx: F32, +vy: F32,
  +tx: F32, +ty: F32) -> V2:
  match ok:
    case False{}:
      V2{vx, vy}
    case True{}:
      +spd = stage_spd(st)
      +dx = (tx - x : F32)
      +dy = (ty - y : F32)
      +d = F32.sqrt((dx * dx + dy * dy + 0.001 : F32))
      +dvx = (dx / d * spd : F32)
      +dvy = (dy / d * spd : F32)
      V2{(vx + (dvx - vx) * STEER() : F32), (vy + (dvy - vy) * STEER() : F32)}

def steer(+st: Stage, +x: F32, +y: F32, +vx: F32, +vy: F32, tg: Near) -> V2:
  Near{ok, tx, ty, _} = tg
  steer_go(ok, st, x, y, vx, vy, tx, ty)

def cap_go(fast: Bool, +vx: F32, +vy: F32, +sp2: F32, +maxs: F32) -> V2:
  match fast:
    case False{}:
      V2{vx, vy}
    case True{}:
      +k = (maxs / F32.sqrt((sp2 + 0.0001 : F32)) : F32)
      V2{(vx * k : F32), (vy * k : F32)}

def cap_speed(+vx: F32, +vy: F32, +maxs: F32) -> V2:
  +sp2 = (vx * vx + vy * vy : F32)
  cap_go(Bool.not((sp2 < maxs * maxs : F32)), vx, vy, sp2, maxs)

# Bounce off a wall: clamp the position and point the velocity back inside.
def bounce(+n: F32, +v: F32, +lo: F32, +hi: F32) -> V2:
  V2{clampf(n, lo, hi),
    pickf((n < lo : F32), F32.abs(v), pickf((hi < n : F32), neg(F32.abs(v)), v))}

def wx(+nx: F32, +vx: F32) -> V2:
  bounce(nx, vx, MARGIN(), (WF() - MARGIN() : F32))

def wy(+ny: F32, +vy: F32) -> V2:
  bounce(ny, vy, (WATER_Y() + SURF_PAD() : F32), (HF() - MARGIN() : F32))

# ============================================================
# Per-entity update (motion + hatching).
# ============================================================

# Depth-band pull, applied ONLY when the fish has no target.
def depth_bias(has_target: Bool, +st: Stage, +y: F32) -> F32:
  match has_target:
    case True{}:
      0.0
    case False{}:
      ((zone_y(st) - y) * DEPTH_K() : F32)

def hatch(go: Bool, +nx: F32, +ny: F32, +vx: F32, +nvy: F32, +sz: F32,
  +ntm: U32, +hh: U32, +fd: U32, +rg: U32, +fc: Bool) -> Ent:
  match go:
    case True{}:
      Ent{Fry{}, nx, ny, (rand_unit(rg) * 0.8 : F32), neg(0.2), FRY_BORN(), 0,
        0, 0, rng_next(rg), U32.is_eq((rg % 2 : U32), 0)}
    case False{}:
      Ent{Egg{}, nx, ny, vx, nvy, sz, ntm, hh, fd, rg, fc}

def egg_go(air: Bool, +e: Ent, +tick: U32) -> Ent:
  match air:
    case True{}:
      Ent{_, x, y, vx, vy, sz, tm, hh, fd, rg, fc} = e
      +nvy = F32.min((vy + AIR_GRAV() : F32), AIR_MAXFALL())
      Ent{Egg{}, clampf((x + vx : F32), 4.0, (WF() - 4.0 : F32)), (y + nvy : F32),
        vx, nvy, sz, 0, hh, fd, rg, fc}
    case False{}:
      Ent{_, x, y, vx, vy, sz, tm, hh, fd, rg, fc} = e
      +nvy = (vy + (SINK_SPEED() - vy) * 0.1 : F32)
      +ph = (U32.to_f32(tick) * 0.2 + U32.to_f32((rg % 100 : U32)) * 0.1 : F32)
      +nx = clampf((x + F32.sin(ph) * 0.6 : F32), 4.0, (WF() - 4.0 : F32))
      +ntm = (tm + 1 : U32)
      hatch((ntm >= HATCH_TICKS() : U32), nx, F32.min((y + nvy : F32), FLOOR()),
        vx, nvy, sz, ntm, hh, fd, rg, fc)

def egg_update(+e: Ent, +tick: U32) -> Ent:
  egg_go((Ent.y(e) < WATER_Y() : F32), e, tick)

def fish_update(+e: Ent, +world: +List<Ent>, +tick: U32) -> Ent:
  Ent{st, x, y, vx, vy, sz, tm, hh, fd, rg, fc} = e
  +tg = target_of(e, world)
  +sv = steer(st, x, y, vx, vy, tg)
  +bvy = (V2.y(sv) + depth_bias(Near.ok(tg), st, y) : F32)
  +r1 = rng_next(rg)
  +r2 = rng_next(r1)
  +wvx = (V2.x(sv) + rand_unit(r1) * WANDER() : F32)
  +ph = (U32.to_f32(tick) * BOB_F() + U32.to_f32((rg % 100 : U32)) * 0.1 : F32)
  +wvy = (bvy + rand_unit(r2) * WANDER() + F32.sin(ph) * BOB_AMP() : F32)
  +sw = swarm(e, world)
  +cv = coll_vec(e, world)
  +kv = cap_speed((wvx + V2.x(sw) + V2.x(cv) : F32),
    (wvy + V2.y(sw) + V2.y(cv) : F32), stage_maxspd(st))
  +kvx = V2.x(kv)
  +kvy = clampf(V2.y(kv), neg(MAX_VY()), MAX_VY())
  +bx = wx((x + kvx : F32), kvx)
  +by = wy((y + kvy : F32), kvy)
  Ent{st, V2.x(bx), V2.x(by), V2.y(bx), V2.y(by), sz, (tm + 1 : U32),
    (hh + 1 : U32), fd, rng_next(r2), (0.0 < V2.y(bx) : F32)}

def update_ent(egg: Bool, +e: Ent, +world: +List<Ent>, +tick: U32) -> Ent:
  match egg:
    case True{}:
      egg_update(e, tick)
    case False{}:
      fish_update(e, world, tick)

def move_go(+es: +List<Ent>, +world: +List<Ent>, +tick: U32) -> +List<Ent>:
  match es:
    case []:
      []
    case h <> t:
      update_ent(is_egg(h), h, world, tick) <> move_go(t, world, tick)

def move_all(+ents: +List<Ent>, +tick: U32) -> +List<Ent>:
  move_go(ents, ents, tick)

# Game-over physics: the water is gone, so everything falls and lands.
def fall_ent(+e: Ent) -> Ent:
  Ent{st, x, y, vx, vy, sz, tm, hh, fd, rg, fc} = e
  +nvy = F32.min((vy + OVER_GRAV() : F32), 7.0)
  +ny = F32.min((y + nvy : F32), FLOOR())
  +nvx = (vx * 0.94 : F32)
  Ent{st, clampf((x + nvx : F32), 6.0, (WF() - 6.0 : F32)), ny, nvx,
    pickf((FLOOR() <= ny : F32), 0.0, nvy), sz, tm, hh, fd, rg, fc}

def fall_all(+es: +List<Ent>) -> +List<Ent>:
  match es:
    case []:
      []
    case h <> t:
      fall_ent(h) <> fall_all(t)

# ============================================================
# Eating: assign each predator at most one prey, prey to one predator.
# ============================================================

def u32_mem(+xs: +List<U32>, +x: U32) -> Bool:
  match xs:
    case []:
      False{}
    case h <> t:
      U32.is_eq(h, x) || u32_mem(t, x)

def enum_go(+es: +List<Ent>, +i: U32) -> +List<IEnt>:
  match es:
    case []:
      []
    case h <> t:
      IEnt{i, h} <> enum_go(t, (i + 1 : U32))

def enumerate(+es: +List<Ent>) -> +List<IEnt>:
  enum_go(es, 0)

def within_range(+se: Ent, +c: Ent) -> Bool:
  +dx = (Ent.x(se) - Ent.x(c) : F32)
  +dy = (Ent.y(se) - Ent.y(c) : F32)
  +r = (radius(se) + radius(c) + EAT_PAD() : F32)
  (dx * dx + dy * dy < r * r : F32)

# May `se` actually eat `c` right now? Right tier + size, AND - if `c` is a
# fish - the predator must be in its 10-second hunt window. Eggs anytime.
def edible(+se: Ent, +c: Ent) -> Bool:
  can_eat(se, c) && (is_egg(c) || hunting(se))

def Pick.pick(c: Bool, a: Pick, b: Pick) -> Pick:
  match c:
    case True{}:
      a
    case False{}:
      b

# Keep the nearer of the best so far and candidate j at squared distance d.
def Pick.better(acc: Pick, +j: U32, +d: F32) -> Pick:
  Pick{+ok, aj, +ad} = acc
  Pick.pick(Bool.not(ok) || (d < ad : F32), Pick{True{}, j, d}, Pick{ok, aj, ad})

def fp_try(skip: Bool, +se: Ent, +j: U32, +c: Ent, acc: Pick) -> Pick:
  match skip:
    case True{}:
      acc
    case False{}:
      +dx = (Ent.x(se) - Ent.x(c) : F32)
      +dy = (Ent.y(se) - Ent.y(c) : F32)
      Pick.better(acc, j, (dx * dx + dy * dy : F32))

def fp_go(+iw: +List<IEnt>, +si: U32, +se: Ent, +consumed: +List<U32>,
  acc: Pick) -> Pick:
  match iw:
    case []:
      acc
    case h <> t:
      IEnt{+j, +c} = h
      +skip = U32.is_eq(j, si) || u32_mem(consumed, j)
        || Bool.not(edible(se, c)) || Bool.not(within_range(se, c))
      fp_go(t, si, se, consumed, fp_try(skip, se, j, c, acc))

# The nearest in-range, edible, unclaimed prey of predator `si`.
def find_prey(+si: U32, +se: Ent, +iw: +List<IEnt>, +consumed: +List<U32>) ->
  Pick:
  fp_go(iw, si, se, consumed, Pick{False{}, 0, 0.0})

def stage_or(c: Bool, a: Stage, b: Stage) -> Stage:
  match c:
    case True{}:
      a
    case False{}:
      b


def stage_at(+iw: +List<IEnt>, +j: U32) -> Stage:
  match iw:
    case []:
      Egg{}
    case h <> t:
      IEnt{+i, +e} = h
      stage_or(U32.is_eq(i, j), Ent.stage(e), stage_at(t, j))

def claim_got(p: Pick, +i: U32, +iw_all: +List<IEnt>, acc: Claim) -> Claim:
  Pick{ok, +j, _} = p
  match ok:
    case False{}:
      acc
    case True{}:
      Claim{cons, gr} = acc
      Claim{j <> cons, Grant{i, stage_at(iw_all, j)} <> gr}

def claim_one(ready: Bool, +i: U32, +e: Ent, +iw_all: +List<IEnt>, acc: Claim) ->
  Claim:
  match ready:
    case False{}:
      acc
    case True{}:
      Claim{+cons, +gr} = acc
      claim_got(find_prey(i, e, iw_all, cons), i, iw_all, Claim{cons, gr})

# Predators are folded in list order; a predator may claim a meal only if it
# is a fish AND off its eat cooldown, and only prey nobody claimed yet.
def claim(+rest: +List<IEnt>, +iw_all: +List<IEnt>, acc: Claim) -> Claim:
  match rest:
    case []:
      acc
    case h <> t:
      IEnt{+i, +e} = h
      claim(t, iw_all, claim_one(is_fish(e) && can_act(e), i, e, iw_all, acc))

def grant_or(c: Bool, ps: Stage, rest: Maybe<Stage>) -> Maybe<Stage>:
  match c:
    case True{}:
      Some{ps}
    case False{}:
      rest


def grant_for(+gr: +List<Grant>, +i: U32) -> Maybe<Stage>:
  match gr:
    case []:
      None{}
    case h <> t:
      Grant{+pi, +ps} = h
      grant_or(U32.is_eq(pi, i), ps, grant_for(t, i))

def Ent.pick(c: Bool, a: Ent, b: Ent) -> Ent:
  match c:
    case True{}:
      a
    case False{}:
      b

# Apply growth/promotion to a predator that ate prey of stage `ps`.
# Size grows on every meal and the 1-second `timer` always resets.
#   fry      : +FRY_GROW per egg; matures after FRY_MEALS.
#   juvenile : +JUV_GROW per fry; matures after JUV_MEALS; hunt clock resets
#              each fry (so it hunts one fry per ~10s). An egg: no growth.
#   adult    : grows x ADULT_MUL per fish and accumulates the prey's cycle
#              cost in `fed`; the hunt clock `hu` resets ONLY when the cycle
#              fills (CYCLE_CAP): 5 fry / 2 juveniles / 1 adult per ~10s.
def grow_ent(+e: Ent, +ps: Stage) -> Ent:
  Ent{st, +x, +y, +vx, +vy, +sz, tm, +hh, +fd, +rg, +fc} = e
  match st:
    case Fry{}:
      +nf = (fd + 1 : U32)
      +ns = (sz + FRY_GROW() : F32)
      Ent.pick((nf >= FRY_MEALS() : U32),
        Ent{Juv{}, x, y, vx, vy, ns, 0, 0, 0, rg, fc},
        Ent{Fry{}, x, y, vx, vy, ns, 0, hh, nf, rg, fc})
    case Juv{}:
      +nf = (fd + 1 : U32)
      +ns = (sz + JUV_GROW() : F32)
      Ent.pick(Stage.is_fry(ps),
        Ent.pick((nf >= JUV_MEALS() : U32),
          Ent{Adult{}, x, y, vx, vy, ns, 0, 0, 0, rg, fc},
          Ent{Juv{}, x, y, vx, vy, ns, 0, 0, nf, rg, fc}),
        Ent{Juv{}, x, y, vx, vy, sz, 0, hh, fd, rg, fc})
    case Adult{}:
      +ns = (sz * ADULT_MUL() : F32)
      +nc = (fd + stage_cost(ps) : U32)
      Ent.pick((nc >= CYCLE_CAP() : U32),
        Ent{Adult{}, x, y, vx, vy, ns, 0, 0, 0, rg, fc},
        Ent{Adult{}, x, y, vx, vy, ns, 0, hh, nc, rg, fc})
    case Egg{}:
      Ent{Egg{}, x, y, vx, vy, sz, tm, hh, fd, rg, fc}

def apply_grant(m: Maybe<Stage>, +e: Ent) -> Ent:
  match m:
    case None{}:
      e
    case Some{ps}:
      grow_ent(e, ps)

def keep_ent(eaten: Bool, +e: Ent, +rest: +List<Ent>) -> +List<Ent>:
  match eaten:
    case True{}:
      rest
    case False{}:
      e <> rest

def rebuild(+iw: +List<IEnt>, +consumed: +List<U32>, +gr: +List<Grant>) ->
  +List<Ent>:
  match iw:
    case []:
      []
    case h <> t:
      IEnt{+i, +e} = h
      keep_ent(u32_mem(consumed, i), apply_grant(grant_for(gr, i), e),
        rebuild(t, consumed, gr))

def any_broken(+es: +List<Ent>) -> Bool:
  match es:
    case []:
      False{}
    case h <> t:
      is_adult(h) && (Ent.size(h) >= BREAK_SIZE() : F32) || any_broken(t)

def eat_fin(acc: Claim, +iw: +List<IEnt>) -> EatRes:
  Claim{consumed, gr} = acc
  +es = rebuild(iw, consumed, gr)
  EatRes{es, any_broken(es), count_stage(es, 3)}

def do_eat(+ents: +List<Ent>) -> EatRes:
  +iw = enumerate(ents)
  eat_fin(claim(iw, iw, Claim{[], []}), iw)

# ============================================================
# One simulation step.
# ============================================================

def after_eat(r: EatRes, +tick1: U32, +rng: U32, +phase: Phase, +pouring: Bool,
  +px: F32, +py: F32, +clock: U32, +told: Bool) -> Aq:
  EatRes{es, broke, score} = r
  match broke:
    case True{}:
      Aq{es, tick1, rng, Over{score, tick1}, False{}, px, py, clock, told}
    case False{}:
      Aq{move_all(es, tick1), tick1, rng, phase, pouring, px, py, clock, told}

def one_tick(+s: Aq) -> Aq:
  Aq{ents, tick, rng, phase, pouring, px, py, clock, told} = s
  match phase:
    case Play{}:
      after_eat(do_eat(ents), (tick + 1 : U32), rng, Play{}, pouring, px, py,
        clock, told)
    case Over{score, at}:
      Aq{fall_all(ents), (tick + 1 : U32), rng, Over{score, at}, False{}, px, py,
        clock, told}
    case Start{}:
      s

# ============================================================
# Spawning eggs
# ============================================================

def add_eggs(n: Nat, +ents: +List<Ent>, +x: F32, +y: F32, +rng: U32) -> Spawn:
  match n:
    case 0n:
      Spawn{ents, rng}
    case 1n+p:
      +r1 = rng_next(rng)
      +r2 = rng_next(r1)
      +ex = clampf((x + rand_unit(r1) * 14.0 : F32), 6.0, (WF() - 6.0 : F32))
      # eggs always enter above water
      +ey = clampf(y, 4.0, (WATER_Y() - 4.0 : F32))
      add_eggs(p, Ent{Egg{}, ex, ey, (rand_unit(r2) * 0.4 : F32), 0.2, 1.0, 0,
        0, 0, r2, True{}} <> ents, x, y, r2)

# Eggs only enter above the waterline. (No entity cap: the world is
# unbounded.)
def spawn_go(air: Bool, n: Nat, +ents: +List<Ent>, +x: F32, +y: F32,
  +rng: U32) -> Spawn:
  match air:
    case True{}:
      add_eggs(n, ents, x, y, rng)
    case False{}:
      Spawn{ents, rng}

def spawn_eggs_at(n: Nat, +ents: +List<Ent>, +x: F32, +y: F32, +rng: U32) ->
  Spawn:
  spawn_go((y < WATER_Y() : F32), n, ents, x, y, rng)

def pour_fin(sp: Spawn, +tick: U32, +phase: Phase, +pouring: Bool, +px: F32,
  +py: F32, +clock: U32, +told: Bool) -> Aq:
  Spawn{es, rng} = sp
  Aq{es, tick, rng, phase, pouring, px, py, clock, told}


def pour_go(go: Bool, +s: Aq) -> Aq:
  match go:
    case False{}:
      s
    case True{}:
      Aq{ents, tick, rng, phase, pouring, px, py, clock, told} = s
      pour_fin(spawn_eggs_at(POUR_N(), ents, px, py, rng), tick, phase, pouring,
        px, py, clock, told)

def Phase.is_play(p: Phase) -> Bool:
  match p:
    case Play{}:
      True{}
    case _:
      False{}

def Aq.phase(s: Aq) -> Phase:
  Aq{_, _, _, ph, _, _, _, _, _} = s
  ph

def Aq.pouring(s: Aq) -> Bool:
  Aq{_, _, _, _, pr, _, _, _, _} = s
  pr

def Aq.ents(s: Aq) -> +List<Ent>:
  Aq{es, _, _, _, _, _, _, _, _} = s
  es

def Aq.tick(s: Aq) -> U32:
  Aq{_, t, _, _, _, _, _, _, _} = s
  t

# While the mouse is held over the air, keep trickling eggs in.
def pour_step(+s: Aq) -> Aq:
  pour_go(Phase.is_play(Aq.phase(s)) && Aq.pouring(s), s)

# One 45 ms simulation tick: eat + move (or fall), then the held pour.
def sim_tick(+s: Aq) -> Aq:
  pour_step(one_tick(s))

def run_ticks(n: Nat, +s: Aq) -> Aq:
  match n:
    case 0n:
      s
    case 1n+p:
      run_ticks(p, sim_tick(s))

# ============================================================
# Init + events
# ============================================================

def Aq.init() -> Aq:
  Aq{[], 0, 777, Start{}, False{}, 0.0, 0.0, 0, False{}}

def press_fin(sp: Spawn, +tick: U32, +fx: F32, +fy: F32, +clock: U32,
  +told: Bool) -> Aq:
  Spawn{es, rng} = sp
  Aq{es, tick, rng, Play{}, True{}, fx, fy, clock, told}

# A press at window (x, y): the front face starts DZ pixels in.

def press_go(play: Bool, +fx: F32, +fy: F32, +s: Aq) -> Aq:
  match play:
    case True{}:
      Aq{ents, tick, rng, phase, _, _, _, clock, told} = s
      press_fin(spawn_eggs_at(SPAWN_N(), ents, fx, fy, rng), tick, fx, fy, clock,
        told)
    case False{}:
      # start (or restart after the tank broke): a fresh world
      Aq{ents, tick, rng, phase, _, _, _, clock, told} = s
      press_fin(spawn_eggs_at(SPAWN_N(), [], fx, fy, rng), 0, fx, fy, clock,
        False{})

def Aq.press(+x: F32, +y: F32, +s: Aq) -> Aq:
  press_go(Phase.is_play(Aq.phase(s)), (x - DZ() : F32), y, s)

def Aq.move(+x: F32, +y: F32, +s: Aq) -> Aq:
  Aq{ents, tick, rng, phase, pouring, _, _, clock, told} = s
  Aq{ents, tick, rng, phase, pouring, (x - DZ() : F32), y, clock, told}

def Aq.release(+s: Aq) -> Aq:
  Aq{ents, tick, rng, phase, _, px, py, clock, told} = s
  Aq{ents, tick, rng, phase, False{}, px, py, clock, told}

# Esc or Close quits; R restarts; the mouse pours.
def Aq.event(e: Event, +s: Aq) -> Maybe<Aq>:
  match e:
    case Key{27, True{}}:
      None{}
    case Key{114, True{}}:
      Some{Aq.init()}
    case Press{_, _, x, y, _, _, True{}}:
      Some{Aq.press(x, y, s)}
    case Press{_, _, _, _, _, _, False{}}:
      Some{Aq.release(s)}
    case Move{_, _, x, y, _}:
      Some{Aq.move(x, y, s)}
    case Leave{_}:
      Some{Aq.release(s)}
    case Lost{_}:
      Some{Aq.release(s)}
    case Close{}:
      None{}
    case _:
      Some{s}

def Aq.events(events: List<Event>, s: Aq) -> Maybe<Aq>:
  match events:
    case []:
      Some{s}
    case e <> rest:
      Maybe.bind(&1, Aq, Aq, Aq.event(e, s), s2 => Aq.events(rest, s2))

def Aq.clock(s: Aq) -> U32:
  Aq{_, _, _, _, _, _, _, c, _} = s
  c

def clock_set(s: Aq, +c: U32) -> Aq:
  Aq{ents, tick, rng, phase, pouring, px, py, _, told} = s
  Aq{ents, tick, rng, phase, pouring, px, py, c, told}

# Run the 45 ms ticks that are due at time `now` (ms), at most MAX_CATCHUP
# per frame; a frame that lags further drops the backlog.
def Aq.advance(+now: U32, +s: Aq) -> Aq:
  +clock = Aq.clock(s)
  +start = U32.is_eq(clock, 0)
  +n = picku(start, 0, ((now - clock) / FRAME_MS() : U32))
  +late = (n > MAX_CATCHUP() : U32)
  clock_set(run_ticks(U32.to_nat(U32.min(n, MAX_CATCHUP())), s),
    picku(start || late, U32.max(now, 1), (clock + n * FRAME_MS() : U32)))

# The pure frame step: fold the frame's events (None quits), then advance
# the simulation to `now` (ms, any monotonic clock).
def Aq.step(+now: U32, events: List<Event>, s: Aq) -> Maybe<Aq>:
  Maybe.bind(&1, Aq, Aq, Aq.events(events, s), s2 => Some{Aq.advance(now, s2)})

# ============================================================
# Rendering: a list of shapes, drawn bottom to top into an Image quadtree.
# ============================================================

# The window: the 560 x 380 front face sits between two 30 px side walls.
def W_W() -> U32:
  620

def W_H() -> U32:
  380

def BG() -> U32:
  397851

def COL_CREST() -> U32:
  12903148

def COL_GLASS() -> U32:
  7972025

def COL_WALL_L() -> U32:
  3034721

def COL_WALL_R() -> U32:
  1917273

def COL_SAND() -> U32:
  6115904

def COL_PANEL() -> U32:
  926771

def COL_PANEL_EDGE() -> U32:
  3833758

def COL_TITLE() -> U32:
  8380415

def COL_TEXT() -> U32:
  15400959

def COL_HUD() -> U32:
  13626101

def COL_DIM() -> U32:
  9417668

def COL_SHARD() -> U32:
  12639721

def COL_EYE() -> U32:
  1057326

def COL_DEAD_EYE() -> U32:
  15791350

# Water: six bands from the surface (light) to the floor (deep).
def water_col(k: U32) -> U32:
  match k:
    case 0:
      5409698
    case 1:
      4818080
    case 2:
      4292254
    case 3:
      3700636
    case 4:
      3174810
    case _:
      2583192

# The empty glass face: four bands, lighter at the top.
def face_col(k: U32) -> U32:
  match k:
    case 0:
      2307134
    case 1:
      2373958
    case 2:
      2375501
    case _:
      2442325

# A shape covers the pixels whose centers it contains.
type Shape is Data:
  Box{x0: F32, y0: F32, x1: F32, y1: F32, c: U32}
  Oval{cx: F32, cy: F32, rx: F32, ry: F32, c: U32}
  Tri{ax: F32, ay: F32, bx: F32, by: F32, cx: F32, cy: F32, c: U32}

def Shape.color(s: Shape) -> U32:
  match s:
    case Box{_, _, _, _, c}:
      c
    case Oval{_, _, _, _, c}:
      c
    case Tri{_, _, _, _, _, _, c}:
      c

def edge(+ax: F32, +ay: F32, +bx: F32, +by: F32, +px: F32, +py: F32) -> F32:
  ((bx - ax) * (py - ay) - (by - ay) * (px - ax) : F32)

def Shape.has(s: Shape, +px: F32, +py: F32) -> Bool:
  match s:
    case Box{x0, y0, x1, y1, _}:
      (x0 <= px : F32) && (px < x1 : F32) && (y0 <= py : F32) && (py < y1 : F32)
    case Oval{cx, cy, rx, ry, _}:
      +u = ((px - cx) / rx : F32)
      +v = ((py - cy) / ry : F32)
      (u * u + v * v <= 1.0 : F32)
    case Tri{+ax, +ay, +bx, +by, +cx, +cy, _}:
      +e0 = edge(ax, ay, bx, by, px, py)
      +e1 = edge(bx, by, cx, cy, px, py)
      +e2 = edge(cx, cy, ax, ay, px, py)
      (e0 >= 0.0 : F32) && (e1 >= 0.0 : F32) && (e2 >= 0.0 : F32)
        || (e0 <= 0.0 : F32) && (e1 <= 0.0 : F32) && (e2 <= 0.0 : F32)

def meets(+lo: F32, +hi: F32, +a: F32, +b: F32) -> Bool:
  (lo <= b : F32) && (a <= hi : F32)

# Does the shape's bounding box meet the centers [ax, bx] x [ay, by]?
def Shape.hits(s: Shape, +ax: F32, +ay: F32, +bx: F32, +by: F32) -> Bool:
  match s:
    case Box{x0, y0, x1, y1, _}:
      (x0 <= bx : F32) && (ax < x1 : F32) && (y0 <= by : F32) && (ay < y1 : F32)
    case Oval{+cx, +cy, +rx, +ry, _}:
      meets((cx - rx : F32), (cx + rx : F32), ax, bx)
        && meets((cy - ry : F32), (cy + ry : F32), ay, by)
    case Tri{+tax, +tay, +tbx, +tby, +tcx, +tcy, _}:
      meets(F32.min(tax, F32.min(tbx, tcx)), F32.max(tax, F32.max(tbx, tcx)),
        ax, bx)
        && meets(F32.min(tay, F32.min(tby, tcy)), F32.max(tay, F32.max(tby, tcy)),
          ay, by)

def Shape.is_box(s: Shape) -> Bool:
  match s:
    case Box{_, _, _, _, _}:
      True{}
    case _:
      False{}

def box_covers(s: Shape, +ax: F32, +ay: F32, +bx: F32, +by: F32) -> Bool:
  match s:
    case Box{x0, y0, x1, y1, _}:
      (x0 <= ax : F32) && (bx < x1 : F32) && (y0 <= ay : F32) && (by < y1 : F32)
    case _:
      False{}

# Does the shape contain every center of [ax, bx] x [ay, by]? Ovals and
# triangles are convex, so their four corners decide it.
def Shape.covers(+s: Shape, +ax: F32, +ay: F32, +bx: F32, +by: F32) -> Bool:
  box_covers(s, ax, ay, bx, by) || Bool.not(Shape.is_box(s))
    && Shape.has(s, ax, ay) && Shape.has(s, bx, ay) && Shape.has(s, ax, by)
    && Shape.has(s, bx, by)

# The shapes meeting a node, in order, and what its top looks like:
# st 0 = nothing meets it, 1 = the topmost shape that meets it covers it
# (color c), 2 = mixed.
type Cut is Data:
  Cut{items: +List<Shape>, st: U32, c: U32}

def cut_add(hit: Bool, +h: Shape, +ax: F32, +ay: F32, +bx: F32, +by: F32,
  r: Cut) -> Cut:
  match hit:
    case False{}:
      r
    case True{}:
      Cut{its, +st, c} = r
      +top = U32.is_eq(st, 0)
      Cut{h <> its, picku(top, picku(Shape.covers(h, ax, ay, bx, by), 1, 2), st),
        picku(top, Shape.color(h), c)}

def cut_go(+items: +List<Shape>, +ax: F32, +ay: F32, +bx: F32, +by: F32) -> Cut:
  match items:
    case []:
      Cut{[], 0, 0}
    case h <> t:
      cut_add(Shape.hits(h, ax, ay, bx, by), h, ax, ay, bx, by,
        cut_go(t, ax, ay, bx, by))

def picku_list(off: Bool, +items: +List<Shape>) -> +List<Shape>:
  match off:
    case True{}:
      []
    case False{}:
      items

# The cut of the s x s node at (x, y); a node off the window is empty.
def cut_for(+x: U32, +y: U32, +s: U32, +items: +List<Shape>) -> Cut:
  +fx = U32.to_f32(x)
  +fy = U32.to_f32(y)
  +fs = U32.to_f32(s)
  cut_go(picku_list((x >= W_W() : U32) || (y >= W_H() : U32), items),
    (fx + 0.5 : F32), (fy + 0.5 : F32), (fx + fs - 0.5 : F32),
    (fy + fs - 0.5 : F32))


# The color of one pixel: the last shape that contains its center.
def pix_col(+items: +List<Shape>, +px: F32, +py: F32, +acc: U32) -> U32:
  match items:
    case []:
      acc
    case h <> t:
      pix_col(t, px, py, picku(Shape.has(h, px, py), Shape.color(h), acc))

# Draws the 2^d x 2^d node at (x, y), given its cut. A node with one look
# is one Pix; else it splits in four, each child cut from this node's list.
def draw(+d: Nat, +x: U32, +y: U32, c: Cut) -> Image:
  match d:
    case 0n:
      Cut{its, st, col} = c
      match st:
        case 0:
          Pix{BG()}
        case 1:
          Pix{col}
        case _:
          Pix{pix_col(its, (U32.to_f32(x) + 0.5 : F32),
            (U32.to_f32(y) + 0.5 : F32), BG())}
    case 1n+e:
      Cut{+its, st, col} = c
      match st:
        case 0:
          Pix{BG()}
        case 1:
          Pix{col}
        case _:
          +h = U32.shln(1, e)
          +x1 = (x + h : U32)
          +y1 = (y + h : U32)
          tl tr bl br = draw(e, x, y, cut_for(x, y, h, its))
            draw(e, x1, y, cut_for(x1, y, h, its))
            draw(e, x, y1, cut_for(x, y1, h, its))
            draw(e, x1, y1, cut_for(x1, y1, h, its))
          Qua{tl, tr, bl, br}

def render(+shapes: +List<Shape>) -> Image:
  draw(10n, 0, 0, cut_for(0, 0, 1024, shapes))

# ============================================================
# A 3x5 pixel font, for the HUD and the overlays
# ============================================================

# Glyph runs of the 3x5 pixel font: each U32 is row*16 + col*4 + len.
def Font.runs(c: U32) -> +List<U32>:
  match c:
    case 65:  # A
      [5, 17, 25, 35, 49, 57, 65, 73]
    case 66:  # B
      [2, 17, 25, 34, 49, 57, 66]
    case 67:  # C
      [6, 17, 33, 49, 70]
    case 68:  # D
      [2, 17, 25, 33, 41, 49, 57, 66]
    case 69:  # E
      [3, 17, 34, 49, 67]
    case 70:  # F
      [3, 17, 34, 49, 65]
    case 71:  # G
      [6, 17, 33, 41, 49, 57, 70]
    case 72:  # H
      [1, 9, 17, 25, 35, 49, 57, 65, 73]
    case 73:  # I
      [3, 21, 37, 53, 67]
    case 74:  # J
      [9, 25, 41, 49, 57, 69]
    case 75:  # K
      [1, 9, 17, 25, 34, 49, 57, 65, 73]
    case 76:  # L
      [1, 17, 33, 49, 67]
    case 77:  # M
      [1, 9, 19, 35, 49, 57, 65, 73]
    case 78:  # N
      [2, 17, 25, 33, 41, 49, 57, 65, 73]
    case 79:  # O
      [5, 17, 25, 33, 41, 49, 57, 69]
    case 80:  # P
      [2, 17, 25, 34, 49, 65]
    case 81:  # Q
      [5, 17, 25, 33, 41, 50, 70]
    case 82:  # R
      [2, 17, 25, 34, 49, 57, 65, 73]
    case 83:  # S
      [6, 17, 37, 57, 66]
    case 84:  # T
      [3, 21, 37, 53, 69]
    case 85:  # U
      [1, 9, 17, 25, 33, 41, 49, 57, 67]
    case 86:  # V
      [1, 9, 17, 25, 33, 41, 49, 57, 69]
    case 87:  # W
      [1, 9, 17, 25, 33, 41, 51, 65, 73]
    case 88:  # X
      [1, 9, 17, 25, 37, 49, 57, 65, 73]
    case 89:  # Y
      [1, 9, 17, 25, 37, 53, 69]
    case 90:  # Z
      [3, 25, 37, 49, 67]
    case 48:  # 0
      [3, 17, 25, 33, 41, 49, 57, 67]
    case 49:  # 1
      [5, 18, 37, 53, 67]
    case 50:  # 2
      [2, 25, 37, 49, 67]
    case 51:  # 3
      [2, 25, 37, 57, 66]
    case 52:  # 4
      [1, 9, 17, 25, 35, 57, 73]
    case 53:  # 5
      [3, 17, 34, 57, 66]
    case 54:  # 6
      [6, 17, 35, 49, 57, 67]
    case 55:  # 7
      [3, 25, 37, 53, 69]
    case 56:  # 8
      [3, 17, 25, 35, 49, 57, 67]
    case 57:  # 9
      [3, 17, 25, 35, 57, 66]
    case 33:  # !
      [5, 21, 37, 69]
    case 58:  # :
      [21, 53]
    case 44:  # ,
      [53, 65]
    case 46:  # .
      [69]
    case 40:  # (
      [9, 21, 37, 53, 73]
    case 41:  # )
      [1, 21, 37, 53, 65]
    case 45:  # -
      [35]
    case _:
      []

def glyph_put(+runs: +List<U32>, +x: F32, +y: F32, +k: F32, +col: U32,
  +acc: +List<Shape>) -> +List<Shape>:
  match runs:
    case []:
      acc
    case r <> rt:
      +row = U32.to_f32((r / 16 : U32))
      +c0 = U32.to_f32(((r / 4 : U32) % 4 : U32))
      +len = U32.to_f32((r % 4 : U32))
      Box{(x + c0 * k : F32), (y + row * k : F32), (x + (c0 + len) * k : F32),
        (y + (row + 1.0) * k : F32), col} <> glyph_put(rt, x, y, k, col, acc)

# Text in the 3x5 font at scale k (a k x k block per font pixel).
def text_at(+str: String, +x: F32, +y: F32, +k: F32, +col: U32,
  +acc: +List<Shape>) -> +List<Shape>:
  match str:
    case SNil{}:
      acc
    case SCon{h, t}:
      Chr{code} = h
      glyph_put(Font.runs(code), x, y, k, col,
        text_at(t, (x + 4.0 * k : F32), y, k, col, acc))

def str_len(+s: String) -> U32:
  match s:
    case SNil{}:
      0
    case SCon{_, t}:
      (1 + str_len(t) : U32)

# Text centered on x = cx.
def text_mid(+str: String, +cx: F32, +y: F32, +k: F32, +col: U32,
  +acc: +List<Shape>) -> +List<Shape>:
  +w = ((U32.to_f32(str_len(str)) * 4.0 - 1.0) * k : F32)
  text_at(str, (cx - w * 0.5 : F32), y, k, col, acc)

# ============================================================
# The scene, layer by layer. Each layer prepends its shapes onto the list of
# the layers above it, so the list runs bottom to top.
# ============================================================

def V2.rot(+px: F32, +py: F32, +ox: F32, +oy: F32, +cs: F32, +sn: F32,
  +tx: F32, +ty: F32) -> V2:
  +dx = (px - ox : F32)
  +dy = (py - oy : F32)
  V2{(ox + tx + dx * cs - dy * sn : F32), (oy + ty + dx * sn + dy * cs : F32)}

def tri3(a: V2, b: V2, c: V2, +col: U32) -> Shape:
  V2{ax, ay} = a
  V2{bx, by} = b
  V2{cx, cy} = c
  Tri{ax, ay, bx, by, cx, cy, col}

# Mix two colors: t = 0 gives a, t = 1 gives b.
def mix_ch(+a: U32, +b: U32, +sh: Nat, +t: F32) -> U32:
  +ca = U32.to_f32(((a >> sh) % 256 : U32))
  +cb = U32.to_f32(((b >> sh) % 256 : U32))
  U32.shln(F32.to_u32((ca + (cb - ca) * t + 0.5 : F32)), sh)

def mix(+a: U32, +b: U32, +t: F32) -> U32:
  (mix_ch(a, b, 16n, t) + mix_ch(a, b, 8n, t) + mix_ch(a, b, 0n, t) : U32)

def wall_put(on: Bool, +s1: Shape, +s2: Shape, +acc: +List<Shape>) ->
  +List<Shape>:
  match on:
    case True{}:
      s1 <> s2 <> acc
    case False{}:
      acc

def put_if(on: Bool, +s: Shape, +acc: +List<Shape>) -> +List<Shape>:
  match on:
    case True{}:
      s <> acc
    case False{}:
      acc

# A side wall: quad (p0 p1 p2 p3) flung by translate(sgn*8t, 3t) and
# rotate(sgn*3t deg) around (ox, 190) while it fades (t = ticks since the
# break; 0 while the tank is whole).
def wall(+sgn: F32, +t: F32, +ox: F32, +col: U32, +p0x: F32, +p0y: F32,
  +p1x: F32, +p1y: F32, +p2x: F32, +p2y: F32, +p3x: F32, +p3y: F32,
  +acc: +List<Shape>) -> +List<Shape>:
  +alpha = clampf((1.0 - t * 0.03 : F32), 0.0, 1.0)
  +rad = (sgn * t * 3.0 * F32.pi() / 180.0 : F32)
  +cs = F32.cos(rad)
  +sn = F32.sin(rad)
  +tx = (sgn * t * 8.0 : F32)
  +ty = (t * 3.0 : F32)
  +c = mix(BG(), col, alpha)
  +a = V2.rot(p0x, p0y, ox, 190.0, cs, sn, tx, ty)
  +b = V2.rot(p1x, p1y, ox, 190.0, cs, sn, tx, ty)
  +d = V2.rot(p2x, p2y, ox, 190.0, cs, sn, tx, ty)
  +e = V2.rot(p3x, p3y, ox, 190.0, cs, sn, tx, ty)
  wall_put((alpha > 0.02 : F32), tri3(a, b, d, c), tri3(a, d, e, c), acc)

# Ticks since the tank broke (0 before).
def over_t(ph: Phase, +tick: U32) -> F32:
  match ph:
    case Over{_, at}:
      U32.to_f32((tick - U32.min(at, tick) : U32))
    case _:
      0.0

def is_over(ph: Phase) -> Bool:
  match ph:
    case Over{_, _}:
      True{}
    case _:
      False{}

def L.walls(+t: F32, +acc: +List<Shape>) -> +List<Shape>:
  wall(neg(1.0), t, 15.0, COL_WALL_L(), 0.0, 16.0, 30.0, 0.0, 30.0, 380.0, 0.0,
    364.0,
    wall(1.0, t, 605.0, COL_WALL_R(), 590.0, 0.0, 620.0, 16.0, 620.0, 364.0,
      590.0, 380.0, acc))

def L.face(+acc: +List<Shape>) -> +List<Shape>:
  Box{30.0, 0.0, 590.0, 95.0, face_col(0)} <> Box{30.0, 95.0, 590.0, 190.0,
    face_col(1)} <> Box{30.0, 190.0, 590.0, 285.0, face_col(2)}
    <> Box{30.0, 285.0, 590.0, 380.0, face_col(3)} <> acc

# The water below the lowest trough, in bands that the drain uncovers.
def bands(k: Nat, +i: U32, +base: F32, +acc: +List<Shape>) -> +List<Shape>:
  match k:
    case 0n:
      acc
    case 1n+p:
      +y0 = F32.max(base, (WATER_Y() + U32.to_f32(i) * (HF() - WATER_Y()) / 6.0
        : F32))
      put_if((y0 < HF() : F32), Box{30.0, y0, 590.0, HF(), water_col(i)},
        bands(p, (i + 1 : U32), base, acc))

def wave_surface_y(+i: U32, +tick: U32, +drop: F32) -> F32:
  +ph = (U32.to_f32(tick) * WAVE_SPEED() + U32.to_f32(i) * WAVE_FREQ() : F32)
  (WATER_Y() + drop + F32.sin(ph) * WAVE_AMP() : F32)

# N_WAVE thin segments: each a strip from its wavy top down to the bands,
# plus a bright crest.
def waves(k: Nat, +i: U32, +tick: U32, +drop: F32, +base: F32,
  +acc: +List<Shape>) -> +List<Shape>:
  match k:
    case 0n:
      acc
    case 1n+p:
      +sy = wave_surface_y(i, tick, drop)
      +x0 = (DZ() + U32.to_f32(i) * SEG_W() : F32)
      +x1 = F32.min((x0 + SEG_W() + 1.0 : F32), 590.0)
      put_if((sy < base : F32) && (sy < HF() : F32),
        Box{x0, sy, x1, F32.min(base, HF()), water_col(0)},
        put_if((sy < HF() : F32), Box{x0, sy, x1, (sy + 3.0 : F32), COL_CREST()},
          waves(p, (i + 1 : U32), tick, drop, base, acc)))

def L.water(+tick: U32, +t: F32, +acc: +List<Shape>) -> +List<Shape>:
  +drop = (t * DRAIN_SPEED() : F32)
  +base = (WATER_Y() + drop + WAVE_AMP() : F32)
  bands(6n, 0, base, waves(N_WAVE(), 0, tick, drop, base, acc))

def L.glass(+acc: +List<Shape>) -> +List<Shape>:
  Box{32.0, 371.0, 588.0, 378.0, COL_SAND()} <> Box{30.0, 0.0, 32.0, 380.0,
    COL_GLASS()} <> Box{588.0, 0.0, 590.0, 380.0, COL_GLASS()}
    <> Box{30.0, 378.0, 590.0, 380.0, COL_GLASS()} <> acc

def stage_col(st: Stage) -> U32:
  match st:
    case Egg{}:
      COL_EGG()
    case Fry{}:
      COL_BROWN()
    case Juv{}:
      COL_GREEN()
    case Adult{}:
      COL_DBLUE()

# Body half-width and half-height, per stage, in units of the radius.
def body_w(st: Stage) -> F32:
  match st:
    case Adult{}:
      1.25
    case Juv{}:
      1.0
    case _:
      0.8

def body_h(st: Stage) -> F32:
  match st:
    case Adult{}:
      0.62
    case _:
      0.55

def x_eye(+ex: F32, +ey: F32, +k: F32, +i: F32, +j: F32, +acc: +List<Shape>) ->
  +List<Shape>:
  Box{(ex + (i - 0.5) * k : F32), (ey + (j - 0.5) * k : F32),
    (ex + (i + 0.5) * k : F32), (ey + (j + 0.5) * k : F32), COL_DEAD_EYE()} <> acc

# An eye: a dark dot, or an X once the fish is dead.
def eye(dead: Bool, +ex: F32, +ey: F32, +r: F32, +acc: +List<Shape>) ->
  +List<Shape>:
  match dead:
    case False{}:
      +er = F32.max(1.0, (r * 0.12 : F32))
      Oval{ex, ey, er, er, COL_EYE()} <> acc
    case True{}:
      +k = F32.max(1.0, (r * 0.1 : F32))
      x_eye(ex, ey, k, neg(1.0), neg(1.0), x_eye(ex, ey, k, 1.0, neg(1.0),
        x_eye(ex, ey, k, 0.0, 0.0, x_eye(ex, ey, k, neg(1.0), 1.0,
          x_eye(ex, ey, k, 1.0, 1.0, acc)))))

# Adults carry a dorsal fin.
def fin(adult: Bool, +cx: F32, +cy: F32, +dir: F32, +bw: F32, +bh: F32,
  +col: U32, +acc: +List<Shape>) -> +List<Shape>:
  match adult:
    case False{}:
      acc
    case True{}:
      Tri{(cx - dir * bw * 0.35 : F32), (cy - bh * 0.7 : F32),
        (cx + dir * bw * 0.25 : F32), (cy - bh * 0.7 : F32),
        (cx - dir * bw * 0.2 : F32), (cy - bh * 1.45 : F32), col} <> acc

# A fish: tail, body, fin, eye. Facing left by default (head on the left);
# `face` mirrors it. The tail flaps between two frames every FRAME_TICKS.
def fish_shapes(+e: Ent, +tick: U32, +dead: Bool, +acc: +List<Shape>) ->
  +List<Shape>:
  Ent{st, x, y, _, _, _, _, _, _, rg, fc} = e
  +r = radius(e)
  +bw = (r * body_w(st) : F32)
  +bh = (r * body_h(st) : F32)
  +cx = (DZ() + x : F32)
  +dir = pickf(fc, 1.0, neg(1.0))
  +flap = Bool.not(dead) && U32.is_eq((((tick / FRAME_TICKS() : U32) + rg) % 2 : U32), 1)
  +th = (bh * pickf(flap, 0.55, 0.95) : F32)
  +tl = (r * pickf(flap, 0.6, 0.75) : F32)
  +col = stage_col(st)
  Tri{(cx - dir * bw * 0.75 : F32), y, (cx - dir * (bw + tl) : F32),
    (y - th : F32), (cx - dir * (bw + tl) : F32), (y + th : F32), col}
    <> Oval{cx, y, bw, bh, col}
    <> fin(Stage.is_adult(st), cx, y, dir, bw, bh, col,
      eye(dead, (cx + dir * bw * 0.55 : F32), (y - bh * 0.2 : F32), r, acc))

def ent_shapes(egg: Bool, +e: Ent, +tick: U32, +dead: Bool,
  +acc: +List<Shape>) -> +List<Shape>:
  match egg:
    case True{}:
      Oval{(DZ() + Ent.x(e) : F32), Ent.y(e), 3.0, 3.0, COL_EGG()} <> acc
    case False{}:
      fish_shapes(e, tick, dead, acc)

def L.ents(+es: +List<Ent>, +tick: U32, +dead: Bool, +acc: +List<Shape>) ->
  +List<Shape>:
  match es:
    case []:
      acc
    case h <> t:
      ent_shapes(is_egg(h), h, tick, dead, L.ents(t, tick, dead, acc))

# A glass shard: an 18 px triangle flying from (sx, sy) along (dx, dy),
# falling and spinning t * 9 degrees around its center.
def shard(+sx: F32, +sy: F32, +dx: F32, +dy: F32, +t: F32,
  +acc: +List<Shape>) -> +List<Shape>:
  +x = (DZ() + sx + dx * t * SHARD_SPEED() : F32)
  +y = (sy + dy * t * SHARD_SPEED() + t * t * 0.1 : F32)
  +rad = (t * 9.0 * F32.pi() / 180.0 : F32)
  +cs = F32.cos(rad)
  +sn = F32.sin(rad)
  +ox = (x + 9.0 : F32)
  +oy = (y + 9.0 : F32)
  tri3(V2.rot(x, y, ox, oy, cs, sn, 0.0, 0.0),
    V2.rot((x + 18.0 : F32), (y + 7.2 : F32), ox, oy, cs, sn, 0.0, 0.0),
    V2.rot((x + 6.3 : F32), (y + 18.0 : F32), ox, oy, cs, sn, 0.0, 0.0),
    COL_SHARD()) <> acc

def L.shards(over: Bool, +t: F32, +acc: +List<Shape>) -> +List<Shape>:
  match over:
    case False{}:
      acc
    case True{}:
      shard(280.0, 180.0, neg(1.0), neg(0.8), t,
        shard(280.0, 180.0, 1.0, neg(0.8), t,
          shard(280.0, 180.0, neg(1.3), 0.2, t,
            shard(280.0, 180.0, 1.3, 0.2, t,
              shard(180.0, 120.0, neg(0.9), neg(1.0), t,
                shard(380.0, 120.0, 0.9, neg(1.0), t,
                  shard(120.0, 200.0, neg(1.4), neg(0.3), t,
                    shard(440.0, 200.0, 1.4, neg(0.3), t,
                      shard(220.0, 250.0, neg(0.7), 0.6, t,
                        shard(340.0, 250.0, 0.7, 0.6, t,
                          shard(280.0, 100.0, 0.1, neg(1.4), t,
                            shard(300.0, 300.0, 0.4, 0.7, t, acc))))))))))))

# The HUD line, also shown by the web page.
def Aq.hud_text(+s: Aq) -> String:
  +es = Aq.ents(s)
  "Adults: " ++ U32.show(count_stage(es, 3)) ++ "  ·  juveniles: "
    ++ U32.show(count_stage(es, 2)) ++ "  ·  fry: " ++ U32.show(count_stage(es, 1))
    ++ "  ·  eggs: " ++ U32.show(count_stage(es, 4))

def L.hud(+es: +List<Ent>, +acc: +List<Shape>) -> +List<Shape>:
  text_at("ADULTS " ++ U32.show(count_stage(es, 3)) ++ "  JUVENILES "
    ++ U32.show(count_stage(es, 2)) ++ "  FRY " ++ U32.show(count_stage(es, 1)),
    38.0, 6.0, 2.0, COL_HUD(), acc)

def panel(+x0: F32, +y0: F32, +x1: F32, +y1: F32, +acc: +List<Shape>) ->
  +List<Shape>:
  Box{(x0 - 2.0 : F32), (y0 - 2.0 : F32), (x1 + 2.0 : F32), (y1 + 2.0 : F32),
    COL_PANEL_EDGE()} <> Box{x0, y0, x1, y1, COL_PANEL()} <> acc

def L.start(+acc: +List<Shape>) -> +List<Shape>:
  panel(120.0, 112.0, 500.0, 268.0,
    text_mid("AQUARIUM", 310.0, 128.0, 6.0, COL_TITLE(),
      text_mid("CLICK OR HOLD ABOVE THE WATER", 310.0, 172.0, 3.0, COL_TEXT(),
        text_mid("TO POUR EGGS", 310.0, 192.0, 3.0, COL_TEXT(),
          text_mid("GROW AN ADULT BIG ENOUGH TO BREAK THE TANK", 310.0, 222.0,
            2.0, COL_DIM(),
            text_mid("ESC QUITS - R RESTARTS", 310.0, 244.0, 2.0, COL_DIM(),
              acc))))))

def L.over(+score: U32, +es: +List<Ent>, +acc: +List<Shape>) -> +List<Shape>:
  panel(90.0, 108.0, 530.0, 272.0,
    text_mid("THE TANK SHATTERED!", 310.0, 124.0, 5.0, COL_TITLE(),
      text_mid("SCORE: " ++ U32.show(score) ++ " ADULT FISH", 310.0, 166.0, 4.0,
        COL_TEXT(),
        text_mid("(ALSO " ++ U32.show(count_stage(es, 1)) ++ " FRY AND "
          ++ U32.show(count_stage(es, 2)) ++ " JUVENILES)", 310.0, 206.0, 2.0,
          COL_DIM(),
          text_mid("CLICK TO PLAY AGAIN", 310.0, 236.0, 3.0, COL_TEXT(), acc)))))

def L.over_if(on: Bool, +score: U32, +es: +List<Ent>, +acc: +List<Shape>) ->
  +List<Shape>:
  match on:
    case True{}:
      L.over(score, es, acc)
    case False{}:
      acc

def L.overlay(ph: Phase, +tick: U32, +es: +List<Ent>, +acc: +List<Shape>) ->
  +List<Shape>:
  match ph:
    case Start{}:
      L.start(acc)
    case Play{}:
      acc
    case Over{score, at}:
      L.over_if((tick >= at + OVER_PANEL_DELAY() : U32), score, es, acc)


def Aq.scene(+s: Aq) -> +List<Shape>:
  Aq{es, tick, _, ph, _, _, _, _, _} = s
  +t = over_t(ph, tick)
  +dead = is_over(ph)
  L.walls(t, L.face(L.water(tick, t, L.glass(L.ents(es, tick, dead,
    L.shards(dead, t, L.hud(es, L.overlay(ph, tick, es, []))))))))

def Aq.draw(+s: Aq) -> Image:
  render(Aq.scene(s))

# The pure view: the state beside its frame.
def Aq.view(s: Aq) -> Aq & Image:
  +s2 = s
  (s2, Aq.draw(s2))

# ============================================================
# Status lines (the native build prints the game-over one; the web page
# shows both), the IO tick and main.
# ============================================================

def Aq.status_text(+s: Aq) -> String:
  Aq{es, _, _, ph, _, _, _, _, _} = s
  match ph:
    case Start{}:
      "Click or hold above the water to pour eggs."
    case Play{}:
      "Grow an adult big enough to break the tank."
    case Over{score, _}:
      "The tank shattered! Score: " ++ U32.show(score) ++ " adult fish (also "
        ++ U32.show(count_stage(es, 1)) ++ " fry and "
        ++ U32.show(count_stage(es, 2)) ++ " juveniles). Click to play again."

# The tank broke and nobody has been told yet?
def Aq.untold(+s: Aq) -> Bool:
  Aq{_, _, _, ph, _, _, _, _, told} = s
  is_over(ph) && Bool.not(told)

def Aq.mark_told(s: Aq) -> Aq:
  Aq{ents, tick, rng, phase, pouring, px, py, clock, _} = s
  Aq{ents, tick, rng, phase, pouring, px, py, clock, True{}}

def tell_go(say: Bool, +s: Aq) -> IO(Maybe<Aq>):
  match say:
    case False{}:
      IO.pure(Maybe<Aq>, Some{s})
    case True{}:
      do IO<Maybe<Aq>>:
        IO.print(Aq.status_text(s))
        return Some{Aq.mark_told(s)}

def tell(m: Maybe<Aq>) -> IO(Maybe<Aq>):
  match m:
    case None{}:
      IO.pure(Maybe<Aq>, None{})
    case Some{+s}:
      tell_go(Aq.untold(s), s)

def Aq.io_tick(events: List<Event>, s: Aq) -> IO(Maybe<Aq>):
  do IO<Maybe<Aq>>:
    now : Nat <- IO.now()
    tell(Aq.step(U32.from_nat(now), events, s))

def main() -> IO(Unit):
  App.run(~Aq, ~App{Aq.view, Aq.io_tick}, "Aquarium", W_W(), W_H(), Aq.init())
