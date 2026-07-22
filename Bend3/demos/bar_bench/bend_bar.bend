# bend_bar: an ANSI-terminal bar-bending bench.
#
# A cantilever bar (fixed at the left wall) is bent tip-down in a
# displacement-controlled bend test -- the same protocol a real bench
# uses: the crosshead imposes deflection, the material answers with
# force. Pick a material, press Bend!, watch it answer.
#
#   [1] Steel   [2] Rubber   [3] Carbon Fiber   [4] Bend!   (q quits)
#
# Real data, real algorithms:
#   geometry     L = 1.0 m, b = 40 mm, h = 20 mm rectangle
#                I = b*h^3/12 = 2.6667e-8 m^4, c = h/2 = 0.01 m, A = 8e-4 m^2
#   deflection   Euler-Bernoulli tip-load curve y(x) = d*(3xi^2 - xi^3)/2
#   stiffness    F = 3*E*I*d / L^3;  root strain eps = 3*d*c / L^2
#   steel        AISI 1020: E=200 GPa, sigma_y=250 MPa, rho=7850, zeta=0.2%
#                yields past eps_y=0.125% (delta=4.2 cm); force plateaus at the
#                plastic hinge F_p = sigma_y*b*h^2/4 / L = 1000 N (EPP knee
#                simplified to min()); on release springs back only the
#                elastic share F_p*L^3/3EI = 6.2 cm and keeps a permanent
#                set, then rings at the first cantilever mode
#   rubber       vulcanized NR ~60 Shore A: E=0.05 GPa, rho=1100, zeta=15%
#                bends with F ~ 1 N, fully recovers, wobbles slowly
#   carbon       UD CFRP laminate: E=135 GPa, rho=1600, zeta=0.5%
#                no yield: at ~0.8% compressive strain (delta=26.7 cm,
#                sigma ~ 1.08 GPa) it fractures at the root -- brittle snap
#   vibration    first mode omega1 = 3.5160*sqrt(E*I/(rho*A))/L^2
#                (sqrt by Newton iteration); release is the modal oscillator
#                q'' = -w^2 (q-rest) - 2 zeta w q', semi-implicit Euler,
#                4 substeps/frame; steel/carbon shown in slow motion
#                (playback factor in the HUD -- 16-30 Hz can't render at 30fps)
#
# build:  node bend-ts/src/main.ts gabriel_demos/bar_bench/bend_bar.bend --no-halt -o gabriel_demos/bar_bench/bend_bar
# run:    ./gabriel_demos/bar_bench/bend_bar        (needs a real terminal for input)
#
# no-halt
# skip-native

import IO
import List
import String
import Char
import Result

type Mat:
  Steel{}
  Rubber{}
  Cfrp{}

type PV:
  PV{q: F32, v: F32}

# ---------------------------------------------------------------- ansi

def ansi(s: String) -> String:
  Cons{Char{27}, s}

def cat(a: String, b: String) -> String:
  List::concat<Char>(a, b)

def cat3(a: String, b: String, c: String) -> String:
  cat(a, cat(b, c))

def red(s: String) -> String:
  cat3(ansi("[31;1m"), s, ansi("[0m"))

def eol() -> String:
  cat(ansi("[K"), "\n")

# ---------------------------------------------------------------- numbers

def u32s_go(n: U32, k: String) -> String:
  match n:
    case 0:
      k
    case m:
      u32s_go(m / 10, Cons{Char{48 + (m % 10)}, k})

def u32s(n: U32) -> String:
  match n:
    case 0:
      "0"
    case m:
      u32s_go(m, "")

def fmin(a: F32, b: F32) -> F32:
  match b <. a:
    case 0:
      a
    case k:
      b

def clamp0(x: F32) -> F32:
  match x <. 0.0:
    case 0:
      x
    case k:
      0.0

def fabs(x: F32) -> F32:
  match x <. 0.0:
    case 0:
      x
    case k:
      0.0 -. x

# one decimal: 12.3
def f1(x: F32) -> String:
  n = f32_to_u32((fabs(x) *. 10.0) +. 0.5)
  cat(u32s(n / 10), Cons{Char{46}, Cons{Char{48 + (n % 10)}, ""}})

# percent with two decimals, from a strain fraction: 0.0037 -> 0.37
def fpct(x: F32) -> String:
  n = f32_to_u32((fabs(x) *. 10000.0) +. 0.5)
  cat(u32s(n / 100), Cons{Char{46}, Cons{Char{48 + ((n / 10) % 10)}, Cons{Char{48 + (n % 10)}, ""}}})

# Newton sqrt: x <- (x + a/x)/2
def fsqrt_go(n: U32, a: F32, x: F32) -> F32:
  match n:
    case 0:
      x
    case m:
      fsqrt_go(m - 1, a, (x +. (a /. x)) *. 0.5)

def fsqrt(a: F32) -> F32:
  match a >. 0.0:
    case 0:
      0.0
    case k:
      fsqrt_go(28, a, (a *. 0.5) +. 1.0)

# ---------------------------------------------------------------- material data

def mat_id(m: Mat) -> U32:
  match m:
    case Steel{}:
      1
    case Rubber{}:
      2
    case Cfrp{}:
      3

def mat_of(sel: U32) -> Mat:
  match sel == 2:
    case 0:
      match sel == 3:
        case 0:
          Steel{}
        case k:
          Cfrp{}
    case j:
      Rubber{}

def m_e(m: Mat) -> F32:            # Young's modulus, Pa
  match m:
    case Steel{}:
      200.0e9
    case Rubber{}:
      0.05e9
    case Cfrp{}:
      135.0e9

def m_rho(m: Mat) -> F32:          # density, kg/m^3
  match m:
    case Steel{}:
      7850.0
    case Rubber{}:
      1100.0
    case Cfrp{}:
      1600.0

def m_zeta(m: Mat) -> F32:         # damping ratio
  match m:
    case Steel{}:
      0.002
    case Rubber{}:
      0.15
    case Cfrp{}:
      0.005

def m_col(m: Mat) -> String:       # bar color
  match m:
    case Steel{}:
      ansi("[97;1m")
    case Rubber{}:
      ansi("[33;1m")
    case Cfrp{}:
      ansi("[90;1m")

def m_name(m: Mat) -> String:
  match m:
    case Steel{}:
      "STEEL  AISI 1020 mild:  E=200 GPa  sy=250 MPa  rho=7850  zeta=0.2%  120 HB"
    case Rubber{}:
      "RUBBER vulcanized NR:   E=0.05 GPa  elastic>500%  rho=1100  zeta=15%  60 Shore A"
    case Cfrp{}:
      "CARBON UD CFRP 0-deg:   E=135 GPa  eu~0.8% (compr)  rho=1600  zeta=0.5%  no yield"

# 3*E*I/L^3, N per m of tip deflection (I = 2.6667e-8, L = 1)
def m_stiff(m: Mat) -> F32:
  m_e(m) *. 8.0e-8

# plastic-hinge force cap: sigma_y*b*h^2/4 / L for steel, effectively none else
def m_fcap(m: Mat) -> F32:
  match m:
    case Steel{}:
      1000.0
    case Rubber{}:
      1.0e9
    case Cfrp{}:
      1.0e9

# first cantilever mode, rad/s: 3.5160*sqrt(E*I/(rho*A))/L^2
def m_omega(m: Mat) -> F32:
  fsqrt((m_e(m) *. 2.6667e-8) /. (m_rho(m) *. 8.0e-4)) *. 3.5160

def m_slow(m: Mat) -> U32:         # slow-motion playback divisor on release
  match m:
    case Steel{}:
      32
    case Rubber{}:
      1
    case Cfrp{}:
      64

# ---------------------------------------------------------------- scene

# d: tip deflection (m, + is down); rx: shape relax 1..0 (snap energy release);
# fl: free-fall offset (m); fN: force HUD; st: status; ar: show load arrow;
# brk: show root fracture; sel: 1..3 button highlight
type Scene:
  Scene{m: Mat, d: F32, rx: F32, fl: F32, fN: F32, st: String, ar: U32, brk: U32, sel: U32}

# screen row of bar column j (0..59): rest row 8, 24 px per meter, 999 = clipped
def brow(j: U32, d: F32, rx: F32, fl: F32) -> U32:
  xi = u32_to_f32(j) /. 59.0
  y = (((d *. rx) *. ((3.0 *. (xi *. xi)) -. ((xi *. xi) *. xi))) /. 2.0) +. fl
  match y <. 0.0:
    case 0:
      r = 8 + f32_to_u32((y *. 24.0) +. 0.5)
      match r > 15:
        case 0:
          r
        case k1:
          999
    case k2:
      up = f32_to_u32(((0.0 -. y) *. 24.0) +. 0.5)
      match up > 8:
        case 0:
          8 - up
        case k3:
          999

def next_j(j: U32) -> U32:
  match j == 59:
    case 0:
      j + 1
    case k:
      j

def rdiff(a: U32, b: U32) -> U32:
  match a == 999:
    case 0:
      match a < b:
        case 0:
          a - b
        case k:
          b - a
    case z:
      0

def glyph(dr: U32) -> String:
  match dr == 0:
    case 0:
      match dr == 1:
        case 0:
          "|"
        case k1:
          "\\"
    case k2:
      "="

def bar_cell(i: U32, j: U32, sc: Scene) -> String:
  match sc:
    case Scene{m, d, rx, fl, fN, st, ar, brk, sel}:
      r = brow(j, d, rx, fl)
      match i == r:
        case 0:
          match ((ar == 1) && (j == 59)) && ((i + 1) == r):
            case 0:
              match ((brk == 1) && (j == 0)) && (i == 8):
                case 0:
                  " "
                case k1:
                  red("x")
            case k2:
              red("v")
        case k3:
          rn = brow(next_j(j), d, rx, fl)
          cat3(m_col(m), glyph(rdiff(rn, r)), ansi("[0m"))

def cell(i: U32, jc: U32, sc: Scene) -> String:
  match (jc == 3) || (jc == 4):
    case 0:
      match (jc >= 5) && (jc <= 64):
        case 0:
          " "
        case k1:
          bar_cell(i, jc - 5, sc)
    case k2:
      "#"

def cells_go(i: U32, jc: U32, sc: Scene) -> String:
  match jc == 70:
    case 0:
      cat(cell(i, jc, sc), cells_go(i, jc + 1, sc))
    case k:
      eol()

def rows_go(i: U32, sc: Scene) -> String:
  match i == 16:
    case 0:
      cat(cells_go(i, 0, sc), rows_go(i + 1, sc))
    case k:
      ""

def btn(lbl: String, on: U32) -> String:
  match on:
    case 0:
      lbl
    case k:
      cat3(ansi("[7m"), lbl, ansi("[0m"))

# displayed root stress: steel is stress-capped at yield (EPP), others linear
def s_show(m: Mat, smpa: F32) -> F32:
  match m:
    case Steel{}:
      fmin(smpa, 250.0)
    case Rubber{}:
      smpa
    case Cfrp{}:
      smpa

# strain/stress gauges read the loading fiber; valid only while the
# crosshead is pushing (after yield or release the root state is residual)
def gauges(m: Mat, d: F32, ar: U32) -> String:
  match ar:
    case 0:
      "eps_root= --     s_root= --      "
    case k:
      eps = fabs(d) *. 0.03
      smpa = s_show(m, (m_e(m) *. eps) /. 1.0e6)
      cat(cat3("eps_root=", fpct(eps), "%   "), cat3("s_root=", u32s(f32_to_u32(smpa +. 0.5)), " MPa   "))

def hud(sc: Scene) -> String:
  match sc:
    case Scene{m, d, rx, fl, fN, st, ar, brk, sel}:
      l1 = cat3("  F=", f1(fN), " N   ")
      l2 = cat3("tip=", f1(fabs(d) *. 100.0), " cm   ")
      cat3(cat(cat(l1, l2), gauges(m, d, ar)), st, eol())

def render(sc: Scene) -> String:
  match sc:
    case Scene{m, d, rx, fl, fN, st, ar, brk, sel}:
      top = cat3("  BEND^3 BAR BENCH -- displacement-controlled cantilever bend test", eol(), cat3("  ", m_name(m), eol()))
      bt = cat3("  ", cat(cat(btn("[1] Steel", sel == 1), cat("  ", btn("[2] Rubber", sel == 2))), cat(cat("  ", btn("[3] Carbon Fiber", sel == 3)), "  [4] Bend!   (q quits)")), eol())
      body = cat(rows_go(0, Scene{m, d, rx, fl, fN, st, ar, brk, sel}), hud(Scene{m, d, rx, fl, fN, st, ar, brk, sel}))
      cat3(ansi("[H"), cat(top, body), cat3(bt, "  > ", ansi("[K")))

# ---------------------------------------------------------------- animation

def frame(sc: Scene) -> IO<U32>:
  do IO<U32>:
    _ : U32 <- print(render(sc))
    sleep(33)

# smoothstep displacement ramp: n counts NPUSH..0, target 0.30 m
def pdelta(n: U32) -> F32:
  u = u32_to_f32(45 - n) /. 45.0
  0.30 *. ((3.0 -. (2.0 *. u)) *. (u *. u))

def push_st(m: Mat, d: F32) -> String:
  match (mat_id(m) == 1) && (d >. 0.0417):
    case 0:
      "PUSHING (crosshead down)"
    case k:
      red("YIELDING -- plastic flow past sy=250 MPa")

def push(n: U32, m: Mat, sel: U32) -> IO<U32>:
  d = pdelta(n)
  match (mat_id(m) == 3) && (d >. 0.26666):
    case 0:
      push_frame(n, m, sel)
    case k:
      snap_flash(4, m, sel)

def push_frame(n: U32, m: Mat, sel: U32) -> IO<U32>:
  d = pdelta(n)
  fc = fmin(d *. m_stiff(m), m_fcap(m))
  do IO<U32>:
    _ : U32 <- frame(Scene{m, d, 1.0, 0.0, fc, push_st(m, d), 1, 0, sel})
    push_next(n, m, sel)

def push_next(n: U32, m: Mat, sel: U32) -> IO<U32>:
  match n:
    case 0:
      release(m, sel)
    case k:
      push(k - 1, m, sel)

# --- carbon snap: flash, then the bar tears off the root and falls, its
# stored elastic shape releasing (rx -> 0) while gravity takes it
def snap_flash(n: U32, m: Mat, sel: U32) -> IO<U32>:
  match n:
    case 0:
      fall(50, 0.0, 0.0, m, sel)
    case k:
      do IO<U32>:
        _ : U32 <- frame(Scene{m, 0.2667, 1.0, 0.0, 2880.0, red("*** SNAP! sigma_root ~ 1.08 GPa, eps ~ 0.8% ***"), 0, 1, sel})
        snap_flash(k - 1, m, sel)

def fall(n: U32, v: F32, fl: F32, m: Mat, sel: U32) -> IO<U32>:
  t = u32_to_f32(50 - n) *. 0.00825
  rx = clamp0(1.0 -. (t /. 0.15))
  v2 = v +. (9.81 *. 0.00825)
  f2 = fl +. (v2 *. 0.00825)
  do IO<U32>:
    _ : U32 <- frame(Scene{m, 0.2667, rx, f2, 0.0, red("SNAPPED at the root -- no yield, no warning  (slow-mo 1/4)"), 0, 1, sel})
    fall_next(n, v2, f2, m, sel)

def fall_next(n: U32, v: F32, fl: F32, m: Mat, sel: U32) -> IO<U32>:
  match n:
    case 0:
      do IO<U32>:
        _ : U32 <- sleep(1200)
        return 0
    case k:
      fall(k - 1, v, fl, m, sel)

# --- release: the modal oscillator about the rest shape
def sstep(pv: PV, rest: F32, w: F32, z: F32, h: F32) -> PV:
  match pv:
    case PV{q, v}:
      a = (0.0 -. ((w *. w) *. (q -. rest))) -. (((2.0 *. z) *. w) *. v)
      v2 = v +. (h *. a)
      PV{q +. (h *. v2), v2}

def ssteps(k: U32, pv: PV, rest: F32, w: F32, z: F32, h: F32) -> PV:
  match k:
    case 0:
      pv
    case j:
      ssteps(j - 1, sstep(pv, rest, w, z, h), rest, w, z, h)

def ring(n: U32, pv: PV, rest: F32, m: Mat, st: String, sel: U32) -> IO<U32>:
  match pv:
    case PV{q, v}:
      w = m_omega(m)
      h = (0.033 /. u32_to_f32(m_slow(m))) /. 4.0
      p2 = ssteps(4, PV{q, v}, rest, w, m_zeta(m), h)
      do IO<U32>:
        _ : U32 <- frame(Scene{m, q, 1.0, 0.0, 0.0, st, 0, 0, sel})
        ring_next(n, p2, rest, m, st, sel)

def ring_next(n: U32, pv: PV, rest: F32, m: Mat, st: String, sel: U32) -> IO<U32>:
  match n:
    case 0:
      do IO<U32>:
        _ : U32 <- sleep(1200)
        return 0
    case k:
      ring(k - 1, pv, rest, m, st, sel)

def rel_st(m: Mat) -> String:
  hz = f1(m_omega(m) /. 6.2832)
  match m:
    case Steel{}:
      cat3("RELEASED: springback + set, ringing f1=", hz, " Hz  (slow-mo 1/32)")
    case Rubber{}:
      cat3("RELEASED: full recovery, wobbling f1=", hz, " Hz  (real time)")
    case Cfrp{}:
      cat3("RELEASED: ringing f1=", hz, " Hz  (slow-mo 1/64)")

def release(m: Mat, sel: U32) -> IO<U32>:
  match m:
    case Steel{}:
      # permanent set = 0.30 - F_p*L^3/3EI = 0.30 - 1000/16000 = 0.2375 m
      ring(200, PV{0.30, 0.0}, 0.2375, Steel{}, rel_st(Steel{}), sel)
    case Rubber{}:
      ring(240, PV{0.30, 0.0}, 0.0, Rubber{}, rel_st(Rubber{}), sel)
    case Cfrp{}:
      ring(200, PV{0.30, 0.0}, 0.0, Cfrp{}, rel_st(Cfrp{}), sel)

# ---------------------------------------------------------------- ui loop

def quit() -> IO<U32>:
  do IO<U32>:
    _ : U32 <- print(cat3(ansi("[?25h"), ansi("[0m"), "\n"))
    return 0

def dispatch(sel: U32, r: Result<String>) -> IO<U32>:
  match r:
    case Fail{code, err}:
      quit()
    case Done{s}:
      match s:
        case Nil{}:
          run_bend(sel)
        case Cons{h, t}:
          key(sel, h)

def key(sel: U32, h: Char) -> IO<U32>:
  match h:
    case Char{cp}:
      match (cp == 113) || (cp == 81):
        case 0:
          match ((cp == 52) || (cp == 98)) || (cp == 66):
            case 0:
              match (cp >= 49) && (cp <= 51):
                case 0:
                  menu(sel)
                case k1:
                  menu(cp - 48)
            case k2:
              run_bend(sel)
        case k3:
          quit()

def run_bend(sel: U32) -> IO<U32>:
  do IO<U32>:
    _ : U32 <- push(45, mat_of(sel), sel)
    menu(sel)

def menu(sel: U32) -> IO<U32>:
  do IO<U32>:
    _ : U32 <- print(render(Scene{mat_of(sel), 0.0, 1.0, 0.0, 0.0, "READY -- fresh specimen loaded. [4]/Enter bends it.", 0, 0, sel}))
    r : Result<String> <- input()
    dispatch(sel, r)

def main() -> IO<U32>:
  do IO<U32>:
    _ : U32 <- print(cat(ansi("[2J"), ansi("[?25l")))
    menu(1)
