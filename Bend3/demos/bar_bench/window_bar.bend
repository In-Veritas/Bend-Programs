# window_bar: the bar-bending bench, in a real OS window.
#
# Same physics as bend_bar.bend (see its header: Euler-Bernoulli cantilever,
# real material data, modal release dynamics), but rendered into a Cocoa
# window through a custom IO effect (effs/window.c) instead of the terminal.
# The pure fragment computes every frame's geometry as F32 physics and emits
# a flat List<U32> of draw commands; the effect rasterizes and presents them
# and reports the pressed key back. Bend computes, the effect displays --
# the same quarantine every other effect lives under.
#
# keys (in the window): 1 steel, 2 rubber, 3 carbon fiber,
#                       4 / b / space / enter = Bend!, q quits
#
# build:  bun bend-ts/src/bend.ts gabriel_demos/bar_bench/window_bar.bend --no-halt -o gabriel_demos/bar_bench/window_bar
# run:    ./gabriel_demos/bar_bench/window_bar
# demo:   ./gabriel_demos/bar_bench/window_bar --demo    (one steel bend, then exits)
#
# no-halt
# skip-native

import ../../bend-base/Base
import ../Compat
import ../CommandGFX

# ---------------------------------------------------------------- window effect

def win_open(w: U32, h: U32, title: String) -> IO(U32):
  CommandGFX.open(title, w, h)

def win_frame(cmds: List(U32)) -> IO(U32):
  CommandGFX.frame_key(cmds)

def win_close() -> IO(U32):
  CommandGFX.close()

# ---------------------------------------------------------------- small math

def fmin(a: F32, b: F32) -> F32:
  match b < a:
    case 0:
      a
    case k:
      b

def clamp0(x: F32) -> F32:
  match x < 0.0:
    case 0:
      x
    case k:
      0.0

def fabs(x: F32) -> F32:
  match x < 0.0:
    case 0:
      x
    case k:
      0.0 - x

def fsqrt_go(n: U32, a: F32, x: F32) -> F32:
  match n:
    case 0:
      x
    case m:
      fsqrt_go(m - 1, a, (x + (a / x)) * 0.5)

def fsqrt(a: F32) -> F32:
  match a > 0.0:
    case 0:
      0.0
    case k:
      fsqrt_go(28, a, (a * 0.5) + 1.0)

# ---------------------------------------------------------------- materials
# (data and derivations: see bend_bar.bend / README)

type Mat:
  Steel{}
  Rubber{}
  Cfrp{}

type PV:
  PV{q: F32, v: F32}

def mat_id(m: Mat) -> U32:
  match m:
    case Mat.Steel{}:
      1
    case Mat.Rubber{}:
      2
    case Mat.Cfrp{}:
      3

def mat_of(sel: U32) -> Mat:
  match sel == 2:
    case 0:
      match sel == 3:
        case 0:
          Mat.Steel{}
        case k:
          Mat.Cfrp{}
    case j:
      Mat.Rubber{}

def m_e(m: Mat) -> F32:
  match m:
    case Mat.Steel{}:
      200.0e9
    case Mat.Rubber{}:
      0.05e9
    case Mat.Cfrp{}:
      135.0e9

def m_rho(m: Mat) -> F32:
  match m:
    case Mat.Steel{}:
      7850.0
    case Mat.Rubber{}:
      1100.0
    case Mat.Cfrp{}:
      1600.0

def m_zeta(m: Mat) -> F32:
  match m:
    case Mat.Steel{}:
      0.002
    case Mat.Rubber{}:
      0.15
    case Mat.Cfrp{}:
      0.005

def m_omega(m: Mat) -> F32:
  fsqrt((m_e(m) * 2.6667e-8) / (m_rho(m) * 8.0e-4)) * 3.5160

def m_slow(m: Mat) -> U32:
  match m:
    case Mat.Steel{}:
      32
    case Mat.Rubber{}:
      1
    case Mat.Cfrp{}:
      64

def m_rgb(m: Mat) -> U32:
  match m:
    case Mat.Steel{}:
      13160668
    case Mat.Rubber{}:
      15249448
    case Mat.Cfrp{}:
      4738136

def m_name(m: Mat) -> String:
  match m:
    case Mat.Steel{}:
      "steel AISI 1020 (E=200 GPa, sy=250 MPa): yields, keeps a set, rings at 16.3 Hz (slow-mo 1/32)"
    case Mat.Rubber{}:
      "rubber vulcanized NR (E=0.05 GPa): ~1 N does it, full recovery, 0.7 Hz wobble in real time"
    case Mat.Cfrp{}:
      "carbon UD CFRP (E=135 GPa, eu~0.8%): no yield -- snaps at the root at ~1.08 GPa"

# smoothstep crosshead ramp to 0.30 m over 46 frames
def pdelta(n: U32) -> F32:
  u = U32.to_f32(45 - n) / 45.0
  0.30 * ((3.0 - (2.0 * u)) * (u * u))

def sstep(pv: PV, rest: F32, w: F32, z: F32, h: F32) -> PV:
  match pv:
    case PV.PV{q, v}:
      a = (0.0 - ((w * w) * (q - rest))) - (((2.0 * z) * w) * v)
      v2 = v + (h * a)
      PV.PV{q + (h * v2), v2}

def ssteps(k: U32, pv: PV, rest: F32, w: F32, z: F32, h: F32) -> PV:
  match k:
    case 0:
      pv
    case j:
      ssteps(j - 1, sstep(pv, rest, w, z, h), rest, w, z, h)

# ---------------------------------------------------------------- draw commands
# canvas 640x400; wall at x=36; bar 60 columns from x=48, 9 px each;
# baseline y=120, 280 px per meter of deflection; y carries the +1000 bias

def cmd_clear(rgb: U32, t: List(U32)) -> List(U32):
  List.Cons{0, List.Cons{rgb, t}}

def cmd_rect(x: U32, yb: U32, w: U32, h: U32, rgb: U32, t: List(U32)) -> List(U32):
  List.Cons{1, List.Cons{x, List.Cons{yb, List.Cons{w, List.Cons{h, List.Cons{rgb, t}}}}}}

def cmd_digit(x: U32, yb: U32, s: U32, d: U32, rgb: U32, t: List(U32)) -> List(U32):
  List.Cons{2, List.Cons{x, List.Cons{yb, List.Cons{s, List.Cons{d, List.Cons{rgb, t}}}}}}

# biased pixel row of bar column j: y = 120 + 280*(deflection + fall) - 3
def ypx(j: U32, d: F32, rx: F32, fl: F32) -> U32:
  xi = U32.to_f32(j) / 59.0
  y = (((d * rx) * ((3.0 * (xi * xi)) - ((xi * xi) * xi))) / 2.0) + fl
  F32.to_u32(clamp0((117.0 + (y * 280.0)) + 1000.5))

def bar_cmds(j: U32, rgb: U32, d: F32, rx: F32, fl: F32, t: List(U32)) -> List(U32):
  match j:
    case 0:
      t
    case k:
      bar_cmds(k - 1, rgb, d, rx, fl, cmd_rect(48 + ((k - 1) * 9), ypx(k - 1, d, rx, fl), 9, 6, rgb, t))

def sel_under(x: U32, on: U32, t: List(U32)) -> List(U32):
  match on:
    case 0:
      t
    case k:
      cmd_rect(x, 1384, 48, 3, 16777215, t)

def btn_cmd(i: U32, rgb: U32, sel: U32, t: List(U32)) -> List(U32):
  x = 48 + ((i - 1) * 64)
  cmd_rect(x, 1352, 48, 28, rgb, cmd_digit(x + 18, 1356, 4, i, 16777215, sel_under(x, sel == i, t)))

def btns_cmds(sel: U32, t: List(U32)) -> List(U32):
  btn_cmd(1, 10134708, sel, btn_cmd(2, 14196768, sel, btn_cmd(3, 3159100, sel, btn_cmd(4, 3055172, sel, t))))

# the load arrow: a red pusher above the bar tip while the crosshead drives
def arrow_cmds(ar: U32, d: F32, t: List(U32)) -> List(U32):
  match ar:
    case 0:
      t
    case k:
      tip = ypx(59, d, 1.0, 0.0)
      cmd_rect(577, tip - 42, 13, 8, 14696512, cmd_rect(580, tip - 36, 7, 28, 14696512, t))

def brk_cmds(brk: U32, t: List(U32)) -> List(U32):
  match brk:
    case 0:
      t
    case k:
      cmd_rect(44, 1108, 10, 18, 14696512, t)

def flash_rgb(m: Mat, flash: U32) -> U32:
  match flash:
    case 0:
      m_rgb(m)
    case k:
      14696512

def draw(m: Mat, d: F32, rx: F32, fl: F32, ar: U32, brk: U32, flash: U32, sel: U32) -> List(U32):
  rgb = flash_rgb(m, flash)
  cmd_clear(1317918,
    cmd_rect(36, 1040, 8, 320, 6317680,
      bar_cmds(60, rgb, d, rx, fl,
        arrow_cmds(ar, d,
          brk_cmds(brk,
            btns_cmds(sel, List.Nil{}))))))

# ---------------------------------------------------------------- animation

def frame(cmds: List(U32)) -> IO(U32):
  do IO(U32):
    k <- win_frame(cmds)
    _ <- IO.sleep(33)
    return k

def push(n: U32, m: Mat, sel: U32) -> IO(U32):
  d = pdelta(n)
  match (mat_id(m) == 3) && (d > 0.26666):
    case 0:
      push_frame(n, m, sel)
    case k:
      snap(m, sel)

def push_frame(n: U32, m: Mat, sel: U32) -> IO(U32):
  do IO(U32):
    _ <- frame(draw(m, pdelta(n), 1.0, 0.0, 1, 0, 0, sel))
    push_next(n, m, sel)

def push_next(n: U32, m: Mat, sel: U32) -> IO(U32):
  match n:
    case 0:
      release(m, sel)
    case k:
      push(k - 1, m, sel)

def snap(m: Mat, sel: U32) -> IO(U32):
  do IO(U32):
    _ <- IO.write("  *** SNAP -- sigma_root ~ 1.08 GPa at eps ~ 0.8%, no yield, no warning\n")
    snap_flash(4, m, sel)

def snap_flash(n: U32, m: Mat, sel: U32) -> IO(U32):
  match n:
    case 0:
      fall(50, 0.0, 0.0, m, sel)
    case k:
      do IO(U32):
        _ <- frame(draw(m, 0.2667, 1.0, 0.0, 0, 1, k % 2, sel))
        snap_flash(k - 1, m, sel)

# the freed bar straightens (stored elastic energy) and falls; slow-mo 1/4
def fall(n: U32, v: F32, fl: F32, m: Mat, sel: U32) -> IO(U32):
  t = U32.to_f32(50 - n) * 0.00825
  rx = clamp0(1.0 - (t / 0.15))
  v2 = v + (9.81 * 0.00825)
  f2 = fl + (v2 * 0.00825)
  do IO(U32):
    _ <- frame(draw(m, 0.2667, rx, f2, 0, 1, 0, sel))
    fall_next(n, v2, f2, m, sel)

def fall_next(n: U32, v: F32, fl: F32, m: Mat, sel: U32) -> IO(U32):
  match n:
    case 0:
      do IO(U32):
        _ <- IO.sleep(900)
        return 0
    case k:
      fall(k - 1, v, fl, m, sel)

def ring(n: U32, pv: PV, rest: F32, m: Mat, sel: U32) -> IO(U32):
  match pv:
    case PV.PV{q, v}:
      h = (0.033 / U32.to_f32(m_slow(m))) / 4.0
      p2 = ssteps(4, PV.PV{q, v}, rest, m_omega(m), m_zeta(m), h)
      do IO(U32):
        _ <- frame(draw(m, q, 1.0, 0.0, 0, 0, 0, sel))
        ring_next(n, p2, rest, m, sel)

def ring_next(n: U32, pv: PV, rest: F32, m: Mat, sel: U32) -> IO(U32):
  match n:
    case 0:
      do IO(U32):
        _ <- IO.sleep(900)
        return 0
    case k:
      ring(k - 1, pv, rest, m, sel)

def release(m: Mat, sel: U32) -> IO(U32):
  match m:
    case Mat.Steel{}:
      # permanent set = 0.30 - F_p*L^3/3EI = 0.2375 m
      ring(200, PV.PV{0.30, 0.0}, 0.2375, Mat.Steel{}, sel)
    case Mat.Rubber{}:
      ring(240, PV.PV{0.30, 0.0}, 0.0, Mat.Rubber{}, sel)
    case Mat.Cfrp{}:
      ring(200, PV.PV{0.30, 0.0}, 0.0, Mat.Cfrp{}, sel)

# ---------------------------------------------------------------- ui loop

def quit() -> IO(U32):
  do IO(U32):
    _ <- win_close()
    _ <- IO.write("bye\n")
    return 0

def run_bend(sel: U32) -> IO(U32):
  do IO(U32):
    _ <- IO.write(List.concat(Char, "bending ", List.concat(Char, m_name(mat_of(sel)), "\n")))
    _ <- push(45, mat_of(sel), sel)
    menu(sel)

def key(sel: U32, k: U32) -> IO(U32):
  match (k == 113) || (k == 81):
    case 0:
      match ((k == 52) || (k == 98)) || ((k == 13) || (k == 32)):
        case 0:
          match (k >= 49) && (k <= 51):
            case 0:
              idle(sel)
            case k1:
              menu(k - 48)
        case k2:
          run_bend(sel)
    case k3:
      quit()

def idle(sel: U32) -> IO(U32):
  do IO(U32):
    _ <- IO.sleep(33)
    menu(sel)

def menu(sel: U32) -> IO(U32):
  do IO(U32):
    k <- win_frame(draw(mat_of(sel), 0.0, 1.0, 0.0, 0, 0, 0, sel))
    key(sel, k)

def demo() -> IO(U32):
  do IO(U32):
    _ <- IO.write("demo: steel, rubber, carbon, then exit\n")
    _ <- push(45, Mat.Steel{}, 1)
    _ <- push(45, Mat.Rubber{}, 2)
    _ <- push(45, Mat.Cfrp{}, 3)
    quit()

def fail_open() -> IO(U32):
  do IO(U32):
    _ <- IO.write("could not open a window\n")
    return 1

def go2(a: List(String)) -> IO(U32):
  match a:
    case List.Nil{}:
      menu(1)
    case List.Cons{h, t}:
      demo()

def go(a: List(String), ok: U32) -> IO(U32):
  match ok:
    case 0:
      fail_open()
    case k:
      go2(a)

def main() -> IO(U32):
  do IO(U32):
    a <- IO.args()
    ok <- win_open(640, 400, "Bend3 bar bench -- 1 steel  2 rubber  3 carbon  4 bend  q quit")
    go(a, ok)
