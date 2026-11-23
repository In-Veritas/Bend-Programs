# bend_bar: an ANSI-terminal bar-bending bench.
#
# A cantilever bar (fixed at the left wall) is bent tip-down in a
# displacement-controlled bend test -- the same protocol a real bench
# uses: the crosshead imposes deflection, the material answers with
# force. Pick a material, press Bend!, watch it answer.
#
#   [1] Steel   [2] Rubber   [3] Carbon Fiber   [4] Bend!   (q quits)
#
# Real data, real algorithms (in Bench.bend, shared with window_bar.bend):
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
# build:  bend Bend3/demos/bar_bench/bend_bar.bend -o /tmp/bend_bar
# run:    /tmp/bend_bar        (type a key and Enter: input is read by line)
# script: printf '2\n4\nq\n' | /tmp/bend_bar > /tmp/frames.txt
import Base
import ./Bench.bend as Bench

# ---------------------------------------------------------------- ansi

def ansi(s: String) -> String:
  SCon{Char.from_u32(27), s}

def red(s: String) -> String:
  ansi("[31;1m") ++ s ++ ansi("[0m")

def eol() -> String:
  ansi("[K") ++ "\n"

def pick(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def picks(c: Bool, a: String, b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

# ---------------------------------------------------------------- numbers

# one decimal: 12.3
def f1(+x: F32) -> String:
  Bench.f1(x)

# percent with two decimals, from a strain fraction: 0.0037 -> 0.37
def fpct(+x: F32) -> String:
  +n = F32.to_u32((Bench.fabs(x) * 10000.0 + 0.5 : F32))
  U32.show((n / 100 : U32)) ++ "." ++ U32.show((n / 10 % 10 : U32)) ++ U32.show((n % 10 : U32))

# ---------------------------------------------------------------- material text

def m_col(m: Bench.Mat) -> String:
  match m:
    case Bench.Steel{}:
      ansi("[97;1m")
    case Bench.Rubber{}:
      ansi("[33;1m")
    case Bench.Cfrp{}:
      ansi("[90;1m")

def m_name(m: Bench.Mat) -> String:
  match m:
    case Bench.Steel{}:
      "STEEL  AISI 1020 mild:  E=200 GPa  sy=250 MPa  rho=7850  zeta=0.2%  120 HB"
    case Bench.Rubber{}:
      "RUBBER vulcanized NR:   E=0.05 GPa  elastic>500%  rho=1100  zeta=15%  60 Shore A"
    case Bench.Cfrp{}:
      "CARBON UD CFRP 0-deg:   E=135 GPa  eu~0.8% (compr)  rho=1600  zeta=0.5%  no yield"

def rel_st.go(m: Bench.Mat, +hz: String) -> String:
  match m:
    case Bench.Steel{}:
      "RELEASED: springback + set, ringing f1=" ++ hz ++ " Hz  (slow-mo 1/32)"
    case Bench.Rubber{}:
      "RELEASED: full recovery, wobbling f1=" ++ hz ++ " Hz  (real time)"
    case Bench.Cfrp{}:
      "RELEASED: ringing f1=" ++ hz ++ " Hz  (slow-mo 1/64)"

def rel_st(+m: Bench.Mat) -> String:
  rel_st.go(m, f1((Bench.m_omega(m) / 6.2832 : F32)))

def status(+m: Bench.Mat, st: Bench.Status) -> String:
  match st:
    case Bench.StReady{}:
      "READY -- fresh specimen loaded. [4]/Enter bends it."
    case Bench.StPushing{}:
      "PUSHING (crosshead down)"
    case Bench.StYielding{}:
      red("YIELDING -- plastic flow past sy=250 MPa")
    case Bench.StSnap{}:
      red("*** SNAP! sigma_root ~ 1.08 GPa, eps ~ 0.8% ***")
    case Bench.StSnapped{}:
      red("SNAPPED at the root -- no yield, no warning  (slow-mo 1/4)")
    case Bench.StReleased{}:
      rel_st(m)

# ---------------------------------------------------------------- scene

# The bar's shape for one frame: tip deflection d, shape relax rx,
# free-fall offset fl; ar shows the load arrow, brk the root fracture.
type Shape is Data:
  Shape{d: F32, rx: F32, fl: F32, ar: Bool, brk: Bool}

# screen row of bar column j (0..59): rest row 8, 24 px per meter, 999 = clipped
def brow.down(+y: F32) -> U32:
  +r = (8 + F32.to_u32((y * 24.0 + 0.5 : F32)) : U32)
  pick(U32.is_gt(r, 15), 999, r)

def brow.up(+y: F32) -> U32:
  +up = F32.to_u32(((0.0 - y) * 24.0 + 0.5 : F32))
  pick(U32.is_gt(up, 8), 999, (8 - up : U32))

def brow.at(neg: Bool, +y: F32) -> U32:
  match neg:
    case True{}:
      brow.up(y)
    case False{}:
      brow.down(y)

def brow(+j: U32, sh: Shape) -> U32:
  Shape{+d, +rx, +fl, ar, brk} = sh
  +xi = (U32.to_f32(j) / 59.0 : F32)
  +y = (d * rx * (3.0 * (xi * xi) - xi * xi * xi) / 2.0 + fl : F32)
  brow.at(F32.is_lt(y, 0.0), y)

def next_j(+j: U32) -> U32:
  pick(U32.is_eq(j, 59), j, (j + 1 : U32))

def rdiff(+a: U32, +b: U32) -> U32:
  pick(U32.is_eq(a, 999), 0, pick(U32.is_lt(a, b), (b - a : U32), (a - b : U32)))

def glyph(+dr: U32) -> String:
  picks(U32.is_eq(dr, 0), "=", picks(U32.is_eq(dr, 1), "\\", "|"))

def bar_cell.at(on_bar: Bool, arrow: Bool, crack: Bool, +m: Bench.Mat, +j: U32, +r: U32,
  +sh: Shape) -> String:
  match on_bar arrow crack:
    case True{} _ _:
      m_col(m) ++ glyph(rdiff(brow(next_j(j), sh), r)) ++ ansi("[0m")
    case False{} True{} _:
      red("v")
    case False{} False{} True{}:
      red("x")
    case False{} False{} False{}:
      " "

def bar_cell(+i: U32, +j: U32, +m: Bench.Mat, +sh: Shape) -> String:
  Shape{d, rx, fl, +ar, +brk} = sh
  +r = brow(j, sh)
  bar_cell.at(U32.is_eq(i, r), ar && U32.is_eq(j, 59) && U32.is_eq((i + 1 : U32), r),
    brk && U32.is_eq(j, 0) && U32.is_eq(i, 8), m, j, r, sh)

def cell.at(wall: Bool, bar: Bool, +i: U32, +jc: U32, +m: Bench.Mat, +sh: Shape) -> String:
  match wall bar:
    case True{} _:
      "#"
    case False{} True{}:
      bar_cell(i, (jc - 5 : U32), m, sh)
    case False{} False{}:
      " "

def cell(+i: U32, +jc: U32, +m: Bench.Mat, +sh: Shape) -> String:
  cell.at(U32.is_eq(jc, 3) || U32.is_eq(jc, 4), U32.is_ge(jc, 5) && U32.is_le(jc, 64), i, jc, m, sh)

# columns jc .. 69 of row i
def cells(n: Nat, +i: U32, +jc: U32, +m: Bench.Mat, +sh: Shape) -> String:
  match n:
    case 0n:
      eol()
    case 1n+k:
      cell(i, jc, m, sh) ++ cells(k, i, (jc + 1 : U32), m, sh)

# rows i .. 15
def rows(n: Nat, +i: U32, +m: Bench.Mat, +sh: Shape) -> String:
  match n:
    case 0n:
      ""
    case 1n+k:
      cells(70n, i, 0, m, sh) ++ rows(k, (i + 1 : U32), m, sh)

def btn(lbl: String, on: Bool) -> String:
  match on:
    case True{}:
      ansi("[7m") ++ lbl ++ ansi("[0m")
    case False{}:
      lbl

# displayed root stress: steel is stress-capped at yield (EPP), others linear
def s_show(m: Bench.Mat, +smpa: F32) -> F32:
  match m:
    case Bench.Steel{}:
      Bench.fmin(smpa, 250.0)
    case _:
      smpa

# strain/stress gauges read the loading fiber; valid only while the
# crosshead is pushing (after yield or release the root state is residual)
def gauges(+m: Bench.Mat, +d: F32, ar: Bool) -> String:
  match ar:
    case False{}:
      "eps_root= --     s_root= --      "
    case True{}:
      +eps = (Bench.fabs(d) * 0.03 : F32)
      +smpa = s_show(m, (Bench.m_e(m) * eps / 1.0e6 : F32))
      "eps_root=" ++ fpct(eps) ++ "%   s_root=" ++ U32.show(F32.to_u32((smpa + 0.5 : F32))) ++ " MPa   "

def hud(+m: Bench.Mat, +d: F32, +fN: F32, +ar: Bool, st: String) -> String:
  "  F=" ++ f1(fN) ++ " N   tip=" ++ f1((Bench.fabs(d) * 100.0 : F32)) ++ " cm   "
    ++ gauges(m, d, ar) ++ st ++ eol()

def render(+m: Bench.Mat, pose: Bench.Pose, +sel: U32) -> String:
  Bench.Pose{+d, rx, fl, fN, +ar, brk, flash, st} = pose
  ansi("[H")
    ++ "  BEND^3 BAR BENCH -- displacement-controlled cantilever bend test" ++ eol()
    ++ "  " ++ m_name(m) ++ eol()
    ++ rows(16n, 0, m, Shape{d, rx, fl, ar, brk})
    ++ hud(m, d, fN, ar, status(m, st))
    ++ "  " ++ btn("[1] Steel", U32.is_eq(sel, 1)) ++ "  " ++ btn("[2] Rubber", U32.is_eq(sel, 2))
    ++ "  " ++ btn("[3] Carbon Fiber", U32.is_eq(sel, 3)) ++ "  [4] Bend!   (q quits)" ++ eol()
    ++ "  > " ++ ansi("[K")

# ---------------------------------------------------------------- animation

# One bend, frame by frame, until the bench is back at the menu
# (at most `fuel` frames; a bend takes 120-320).
def animate(fuel: Nat, done: Bool, +m: Bench.Mat, +sel: U32, +ph: Bench.Phase) -> IO(Unit):
  match fuel done:
    case 0n _:
      IO.pure(Unit, Unit{})
    case _ True{}:
      IO.pure(Unit, Unit{})
    case 1n+f False{}:
      +next = Bench.step(m, ph, 36)
      do IO<Unit>:
        IO.write(render(m, Bench.pose(m, ph), sel))
        IO.sleep(33)
        animate(f, Bench.is_menu(next), m, sel, next)

def run_bend(+sel: U32) -> IO(Unit):
  +m = Bench.mat_of(sel)
  animate(1000n, False{}, m, sel, Bench.start(m))

# ---------------------------------------------------------------- ui loop

def quit(file: File) -> IO(Unit):
  do IO<Unit>:
    File.close(file)
    IO.write(ansi("[?25h") ++ ansi("[0m") ++ "\n")

# 0 nothing, 1 quit, 2 select 1..3, 3 Bend! (an empty line bends too)
def key_kind(+cp: U32) -> U32:
  pick(U32.is_eq(cp, 113) || U32.is_eq(cp, 81), 1,
  pick(U32.is_eq(cp, 52) || U32.is_eq(cp, 98) || U32.is_eq(cp, 66) || U32.is_eq(cp, 10) || U32.is_eq(cp, 13), 3,
  pick(U32.is_ge(cp, 49) && U32.is_le(cp, 51), 2, 0)))

def menu.key(kind: U32, +cp: U32, +sel: U32, file: File, rest: U32 -> File -> IO(Unit)) -> IO(Unit):
  match kind:
    case 1:
      quit(file)
    case 2:
      rest((cp - 48 : U32), file)
    case 3:
      do IO<Unit>:
        run_bend(sel)
        rest(sel, file)
    case _:
      rest(sel, file)

def menu.line(line: String, +sel: U32, file: File, rest: U32 -> File -> IO(Unit)) -> IO(Unit):
  match line:
    case SNil{}:
      quit(file)
    case SCon{h, t}:
      +cp = Char.to_u32(h)
      menu.key(key_kind(cp), cp, sel, file, rest)

def menu.got(got: File & Result<&1, &1, U32 & String, String>, +sel: U32,
  rest: U32 -> File -> IO(Unit)) -> IO(Unit):
  (file, r) = got
  match r:
    case Fail{e}:
      quit(file)
    case Done{line}:
      menu.line(line, sel, file, rest)

def menu(fuel: Nat, +sel: U32, file: File) -> IO(Unit):
  match fuel:
    case 0n:
      quit(file)
    case 1n+f:
      +m = Bench.mat_of(sel)
      do IO<Unit>:
        IO.write(render(m, Bench.pose(m, Bench.Menu{}), sel))
        got : File & Result<&1, &1, U32 & String, String> <- File.read_line(file, 256)
        menu.got(got, sel, s => fl => menu(f, s, fl))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.write(ansi("[2J") ++ ansi("[?25l"))
    stdin : File <- IO.try(File, File.open("/dev/stdin", "r"))
    menu(4294967295n, 1, stdin)
