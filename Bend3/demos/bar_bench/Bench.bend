# Bench: the bar-bending bench's physics and animation, shared by the
# terminal front-end (bend_bar.bend) and the window one (window_bar.bend).
# The derivations are in bend_bar.bend's header and README.md.
#
#   import ./Bench.bend as Bench
#
# The old demos ran the animation as a chain of IO loops (push -> snap
# -> fall -> ring -> sleep). Bend 2.0.40 wants terminating recursion and
# App.run wants a state per frame, so the chain is a pure state machine:
# `step(m, phase)` is one 33 ms frame, `pose(m, phase)` what that frame
# shows. Each front-end only renders poses.
import Base

type Mat is Data:
  Steel{}
  Rubber{}
  Cfrp{}

# Small math
# ----------

def pickf(c: Bool, a: F32, b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def fmin(+a: F32, +b: F32) -> F32:
  pickf(F32.is_lt(b, a), b, a)

def clamp0(+x: F32) -> F32:
  pickf(F32.is_lt(x, 0.0), 0.0, x)

def fabs(+x: F32) -> F32:
  pickf(F32.is_lt(x, 0.0), (0.0 - x : F32), x)

def umin(+a: U32, +b: U32) -> U32:
  pick(U32.is_lt(b, a), b, a)

# Newton sqrt: x <- (x + a/x)/2, 28 rounds (kept from the original demo,
# which predates F32.sqrt).
def fsqrt.go(n: Nat, +a: F32, +x: F32) -> F32:
  match n:
    case 0n:
      x
    case 1n+m:
      fsqrt.go(m, a, ((x + a / x) * 0.5 : F32))

def fsqrt(+a: F32) -> F32:
  pickf(F32.is_gt(a, 0.0), fsqrt.go(28n, a, (a * 0.5 + 1.0 : F32)), 0.0)

# Materials
# ---------

def mat_id(m: Mat) -> U32:
  match m:
    case Steel{}:
      1
    case Rubber{}:
      2
    case Cfrp{}:
      3

def mat_of.go(two: Bool, three: Bool) -> Mat:
  match two three:
    case True{} _:
      Rubber{}
    case False{} True{}:
      Cfrp{}
    case False{} False{}:
      Steel{}

def mat_of(+sel: U32) -> Mat:
  mat_of.go(U32.is_eq(sel, 2), U32.is_eq(sel, 3))

# Young's modulus, Pa
def m_e(m: Mat) -> F32:
  match m:
    case Steel{}:
      200.0e9
    case Rubber{}:
      0.05e9
    case Cfrp{}:
      135.0e9

# density, kg/m^3
def m_rho(m: Mat) -> F32:
  match m:
    case Steel{}:
      7850.0
    case Rubber{}:
      1100.0
    case Cfrp{}:
      1600.0

# damping ratio
def m_zeta(m: Mat) -> F32:
  match m:
    case Steel{}:
      0.002
    case Rubber{}:
      0.15
    case Cfrp{}:
      0.005

# 3*E*I/L^3, N per m of tip deflection (I = 2.6667e-8, L = 1)
def m_stiff(m: Mat) -> F32:
  (m_e(m) * 8.0e-8 : F32)

# plastic-hinge force cap: sigma_y*b*h^2/4 / L for steel, none else
def m_fcap(m: Mat) -> F32:
  match m:
    case Steel{}:
      1000.0
    case Rubber{}:
      1.0e9
    case Cfrp{}:
      1.0e9

# first cantilever mode, rad/s: 3.5160*sqrt(E*I/(rho*A))/L^2
def m_omega(+m: Mat) -> F32:
  (fsqrt((m_e(m) * 2.6667e-8 / (m_rho(m) * 8.0e-4) : F32)) * 3.5160 : F32)

# slow-motion playback divisor on release
def m_slow(m: Mat) -> U32:
  match m:
    case Steel{}:
      32
    case Rubber{}:
      1
    case Cfrp{}:
      64

# rest shape after release: steel keeps the permanent set
# 0.30 - F_p*L^3/3EI = 0.30 - 1000/16000 = 0.2375 m
def m_rest(m: Mat) -> F32:
  match m:
    case Steel{}:
      0.2375
    case Rubber{}:
      0.0
    case Cfrp{}:
      0.0

# release frames
def m_ringn(m: Mat) -> U32:
  match m:
    case Steel{}:
      200
    case Rubber{}:
      240
    case Cfrp{}:
      200

def is_cfrp(m: Mat) -> Bool:
  match m:
    case Cfrp{}:
      True{}
    case _:
      False{}

def is_steel(m: Mat) -> Bool:
  match m:
    case Steel{}:
      True{}
    case _:
      False{}

# Kinematics
# ----------

# smoothstep crosshead ramp: n counts 45..0, target 0.30 m
def pdelta(+n: U32) -> F32:
  +u = (U32.to_f32((45 - umin(n, 45) : U32)) / 45.0 : F32)
  (0.30 * ((3.0 - 2.0 * u) * (u * u)) : F32)

# the force the crosshead reads at deflection d: elastic, capped at the
# plastic hinge (EPP knee simplified to min)
def force(+m: Mat, +d: F32) -> F32:
  fmin((d * m_stiff(m) : F32), m_fcap(m))

# carbon fractures past 0.8% root strain: delta = 0.2667 m
def snaps(+m: Mat, +d: F32) -> Bool:
  is_cfrp(m) && F32.is_gt(d, 0.26666)

# steel yields past eps_y = 0.125%: delta = 4.17 cm
def yields(+m: Mat, +d: F32) -> Bool:
  is_steel(m) && F32.is_gt(d, 0.0417)

# One substep of the release oscillator q'' = -w^2 (q-rest) - 2 zeta w q',
# semi-implicit Euler.
type PV is Data:
  PV{q: F32, v: F32}

def sstep(pv: PV, +rest: F32, +w: F32, +z: F32, +h: F32) -> PV:
  PV{+q, +v} = pv
  +a = (0.0 - w * w * (q - rest) - 2.0 * z * w * v : F32)
  +v2 = (v + h * a : F32)
  PV{(q + h * v2 : F32), v2}

def ssteps(k: Nat, pv: PV, +rest: F32, +w: F32, +z: F32, +h: F32) -> PV:
  match k:
    case 0n:
      pv
    case 1n+j:
      ssteps(j, sstep(pv, rest, w, z, h), rest, w, z, h)

# one release frame (33 ms of slow-motion playback): 4 substeps
def ring_frame(+m: Mat, pv: PV) -> PV:
  ssteps(4n, pv, m_rest(m), m_omega(m), m_zeta(m), (0.033 / U32.to_f32(m_slow(m)) / 4.0 : F32))

# the freed carbon bar's free fall: one frame of the 1/4 slow motion
def fall_v(+v: F32) -> F32:
  (v + 9.81 * 0.00825 : F32)

# the stored elastic shape releasing as it falls (rx 1 -> 0 in 0.15 s)
def fall_rx(+n: U32) -> F32:
  clamp0((1.0 - U32.to_f32((50 - umin(n, 50) : U32)) * 0.00825 / 0.15 : F32))

# The animation
# -------------

type Phase is Data:
  Menu{}
  Push{n: U32}
  Flash{n: U32}
  Fall{n: U32, v: F32, fl: F32}
  Ring{n: U32, q: F32, v: F32}
  Hold{n: U32, d: F32, rx: F32, fl: F32, brk: Bool}

# What a frame's HUD says.
type Status is Data:
  StReady{}
  StPushing{}
  StYielding{}
  StSnap{}
  StSnapped{}
  StReleased{}

# What a frame shows: tip deflection d (m, + is down), shape relax rx
# (1..0), free-fall offset fl (m), crosshead force fN, the load arrow,
# the root fracture mark, the snap flash, the status.
type Pose is Data:
  Pose{d: F32, rx: F32, fl: F32, fN: F32, ar: Bool, brk: Bool, flash: Bool, st: Status}

# A push frame n, or the snap if the bar breaks there.
def enter_push.go(snap: Bool, n: U32) -> Phase:
  match snap:
    case True{}:
      Flash{4}
    case False{}:
      Push{n}

def enter_push(+m: Mat, +n: U32) -> Phase:
  enter_push.go(snaps(m, pdelta(n)), n)

# The bend starting on a fresh specimen.
def start(+m: Mat) -> Phase:
  enter_push(m, 45)

def push_status.go(y: Bool) -> Status:
  match y:
    case True{}:
      StYielding{}
    case False{}:
      StPushing{}

def push_status(+m: Mat, +d: F32) -> Status:
  push_status.go(yields(m, d))

def pick_status(brk: Bool) -> Status:
  match brk:
    case True{}:
      StSnapped{}
    case False{}:
      StReleased{}


def pose(+m: Mat, ph: Phase) -> Pose:
  match ph:
    case Menu{}:
      Pose{0.0, 1.0, 0.0, 0.0, False{}, False{}, False{}, StReady{}}
    case Push{+n}:
      +d = pdelta(n)
      Pose{d, 1.0, 0.0, force(m, d), True{}, False{}, False{}, push_status(m, d)}
    case Flash{+n}:
      Pose{0.2667, 1.0, 0.0, 2880.0, False{}, True{}, U32.is_eq((n % 2 : U32), 1), StSnap{}}
    case Fall{+n, +v, +fl}:
      Pose{0.2667, fall_rx(n), (fl + fall_v(v) * 0.00825 : F32), 0.0, False{}, True{}, False{}, StSnapped{}}
    case Ring{n, q, v}:
      Pose{q, 1.0, 0.0, 0.0, False{}, False{}, False{}, StReleased{}}
    case Hold{n, d, rx, fl, +brk}:
      Pose{d, rx, fl, 0.0, False{}, brk, False{}, pick_status(brk)}

def release(+m: Mat) -> Phase:
  Ring{m_ringn(m), 0.30, 0.0}

def ring_next.go(last: Bool, +n: U32, pv: PV, +hold: U32) -> Phase:
  match last:
    case True{}:
      PV{q, v} = pv
      Hold{hold, q, 1.0, 0.0, False{}}
    case False{}:
      PV{q, v} = pv
      Ring{(n - 1 : U32), q, v}

def ring_next(+n: U32, pv: PV, +hold: U32) -> Phase:
  ring_next.go(U32.is_eq(n, 0), n, pv, hold)

def push_next(last: Bool, +m: Mat, +n: U32) -> Phase:
  match last:
    case True{}:
      release(m)
    case False{}:
      enter_push(m, (n - 1 : U32))

def flash_next(last: Bool, +n: U32) -> Phase:
  match last:
    case True{}:
      Fall{50, 0.0, 0.0}
    case False{}:
      Flash{(n - 1 : U32)}

def fall_next(last: Bool, +n: U32, +v2: F32, +f2: F32, +hold: U32) -> Phase:
  match last:
    case True{}:
      Hold{hold, 0.2667, fall_rx(n), f2, True{}}
    case False{}:
      Fall{(n - 1 : U32), v2, f2}

def hold_next(last: Bool, +n: U32, d: F32, rx: F32, fl: F32, brk: Bool) -> Phase:
  match last:
    case True{}:
      Menu{}
    case False{}:
      Hold{(n - 1 : U32), d, rx, fl, brk}

# One 33 ms frame. `hold` is how many frames the last pose stays up
# before the bench is back to Menu (window: 27 ~ 900 ms, terminal: 36 ~
# 1200 ms, as the old demos slept).
def step(+m: Mat, ph: Phase, +hold: U32) -> Phase:
  match ph:
    case Menu{}:
      Menu{}
    case Push{+n}:
      push_next(U32.is_eq(n, 0), m, n)
    case Flash{+n}:
      flash_next(U32.is_le(n, 1), n)
    case Fall{+n, +v, +fl}:
      +v2 = fall_v(v)
      fall_next(U32.is_eq(n, 0), n, v2, (fl + v2 * 0.00825 : F32), hold)
    case Ring{+n, +q, +v}:
      ring_next(n, ring_frame(m, PV{q, v}), hold)
    case Hold{+n, d, rx, fl, brk}:
      hold_next(U32.is_le(n, 1), n, d, rx, fl, brk)

def is_menu(ph: Phase) -> Bool:
  match ph:
    case Menu{}:
      True{}
    case _:
      False{}

# Headless probe
# --------------
# Runs one bend of material m frame by frame and reports what the README
# promises: the peak crosshead force, the first yielding deflection,
# the snap, the release's rest shape and ringing frequency.

type Probe is Data:
  Probe{frames: U32, fmax: F32, dyield: F32, snapped: Bool, qmin: F32, qmax: F32,
    qlast: F32, crossings: U32, ringf: U32, sign: Bool}

def pickBool(c: Bool, a: Bool, b: Bool) -> Bool:
  match c:
    case True{}:
      a
    case False{}:
      b


def probe.ringing(ph: Phase) -> Bool:
  match ph:
    case Ring{n, q, v}:
      True{}
    case _:
      False{}


def probe.flashing(ph: Phase) -> Bool:
  match ph:
    case Flash{n}:
      True{}
    case _:
      False{}


def probe.add(+m: Mat, +ringing: Bool, flashing: Bool, ps: Pose, p: Probe) -> Probe:
  Pose{+d, rx, fl, +fN, ar, brk, flash, st} = ps
  Probe{+frames, +fmax, +dyield, +snapped, +qmin, +qmax, qlast, +crossings, +ringf, +sign} = p
  +now = F32.is_gt(d, m_rest(m))
  +first_yield = yields(m, d) && F32.is_eq(dyield, 0.0)
  Probe{(frames + 1 : U32), F32.max(fmax, fN), pickf(first_yield, d, dyield),
    snapped || flashing,
    pickf(ringing, F32.min(qmin, d), qmin), pickf(ringing, F32.max(qmax, d), qmax),
    pickf(ringing, d, qlast),
    pick(ringing && Bool.xor(now, sign) && U32.is_gt(ringf, 0), (crossings + 1 : U32), crossings),
    pick(ringing, (ringf + 1 : U32), ringf), pickBool(ringing, now, sign)}

def probe.see(+m: Mat, +ph: Phase, p: Probe) -> Probe:
  probe.add(m, probe.ringing(ph), probe.flashing(ph), pose(m, ph), p)

def probe.go(fuel: Nat, done: Bool, +m: Mat, +ph: Phase, p: Probe) -> Probe:
  match fuel done:
    case 0n _:
      p
    case _ True{}:
      p
    case 1n+f False{}:
      +next = step(m, ph, 27)
      probe.go(f, is_menu(next), m, next, probe.see(m, ph, p))

def probe(+m: Mat) -> Probe:
  probe.go(1000n, False{}, m, start(m), Probe{0, 0.0, 0.0, False{}, 1.0, (0.0 - 1.0 : F32), 0.0, 0, 0, True{}})

# one decimal: 12.3
def f1(+x: F32) -> String:
  +n = F32.to_u32((fabs(x) * 10.0 + 0.5 : F32))
  U32.show((n / 10 : U32)) ++ "." ++ U32.show((n % 10 : U32))

# one decimal with its sign: -12.3
def fs1(+x: F32) -> String:
  Bool.pick(String, F32.is_lt(x, 0.0), "-", "") ++ f1(x)

# The probe as a report line.
def probe.text(+m: Mat, p: Probe) -> String:
  Probe{+frames, fmax, +dyield, snapped, qmin, qmax, qlast, +crossings, +ringf, sign} = p
  +secs = (U32.to_f32(ringf) * 0.033 / U32.to_f32(m_slow(m)) : F32)
  +hz = pickf(U32.is_gt(ringf, 0), (U32.to_f32(crossings) / 2.0 / secs : F32), 0.0)
  "mat " ++ U32.show(mat_id(m)) ++ ": frames=" ++ U32.show(frames)
    ++ " Fmax=" ++ f1(fmax) ++ " N"
    ++ " yield_at=" ++ f1((dyield * 100.0 : F32)) ++ " cm"
    ++ " snapped=" ++ Bool.show(snapped)
    ++ " ring[min,max,last]=[" ++ fs1((qmin * 100.0 : F32)) ++ "," ++ fs1((qmax * 100.0 : F32))
    ++ "," ++ fs1((qlast * 100.0 : F32)) ++ "] cm"
    ++ " rest=" ++ f1((m_rest(m) * 100.0 : F32)) ++ " cm"
    ++ " springback=" ++ f1(((0.30 - m_rest(m)) * 100.0 : F32)) ++ " cm"
    ++ " f1(model)=" ++ f1((m_omega(m) / 6.2832 : F32)) ++ " Hz"
    ++ " f1(measured)=" ++ f1(hz) ++ " Hz"

def probe.show(+m: Mat) -> String:
  probe.text(m, probe(m))
