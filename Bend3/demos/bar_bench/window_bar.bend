# window_bar: the bar-bending bench, in a real OS window.
#
# Same physics as bend_bar.bend (see its header: Euler-Bernoulli cantilever,
# real material data, modal release dynamics), shared through Bench.bend,
# but drawn in a window by Base's App.run instead of the terminal. The
# pure side computes every frame's geometry as F32 physics and emits the
# demos' flat List<U32> of draw commands (the same stream the web twin
# sends to its canvas); ../CommandGFX.bend turns it into an Image
# quadtree and the window's events back into the old key codes.
#
# keys (in the window): 1 steel, 2 rubber, 3 carbon fiber,
#                       4 / b / space / enter = Bend!, q (or closing) quits
#
# build:  bend Bend3/demos/bar_bench/window_bar.bend -o /tmp/window_bar
# run:    /tmp/window_bar
# demo:   /tmp/window_bar --demo     (unattended: steel, rubber, carbon, exit)
# probe:  /tmp/window_bar --probe    (headless: no window; prints the
#                                     physics and checks rendered frames)
import Base
import ../Clock.bend as Clock
import ../CommandGFX.bend as GFX
import ./Bench.bend as Bench

# ---------------------------------------------------------------- materials
# (data and derivations: see Bench.bend / bend_bar.bend / README)

def m_rgb(m: Bench.Mat) -> U32:
  match m:
    case Bench.Steel{}:
      13160668
    case Bench.Rubber{}:
      15249448
    case Bench.Cfrp{}:
      4738136

def m_name(m: Bench.Mat) -> String:
  match m:
    case Bench.Steel{}:
      "steel AISI 1020 (E=200 GPa, sy=250 MPa): yields, keeps a set, rings at 16.3 Hz (slow-mo 1/32)"
    case Bench.Rubber{}:
      "rubber vulcanized NR (E=0.05 GPa): ~1 N does it, full recovery, 0.7 Hz wobble in real time"
    case Bench.Cfrp{}:
      "carbon UD CFRP (E=135 GPa, eu~0.8%): no yield -- snaps at the root at ~1.08 GPa"

# ---------------------------------------------------------------- draw commands
# canvas 640x400; wall at x=36; bar 60 columns from x=48, 9 px each;
# baseline y=120, 280 px per meter of deflection; y carries the +1000 bias

def pick(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

# biased pixel row of bar column j: y = 120 + 280*(deflection + fall) - 3
def ypx(+j: U32, +d: F32, +rx: F32, +fl: F32) -> U32:
  +xi = (U32.to_f32(j) / 59.0 : F32)
  +y = (d * rx * (3.0 * (xi * xi) - xi * xi * xi) / 2.0 + fl : F32)
  F32.to_u32(Bench.clamp0((117.0 + y * 280.0 + 1000.5 : F32)))

def bar_cmds(+j: Nat, +rgb: U32, +d: F32, +rx: F32, +fl: F32, t: List<&2, U32>) -> List<&2, U32>:
  match j:
    case 0n:
      t
    case 1n+k:
      +c = U32.from_nat(k)
      bar_cmds(k, rgb, d, rx, fl, GFX.cmd_rect((48 + c * 9 : U32), ypx(c, d, rx, fl), 9, 6, rgb, t))

def sel_under(on: Bool, +x: U32, t: List<&2, U32>) -> List<&2, U32>:
  match on:
    case True{}:
      GFX.cmd_rect(x, 1384, 48, 3, 16777215, t)
    case False{}:
      t

def btn_cmd(+i: U32, rgb: U32, +sel: U32, t: List<&2, U32>) -> List<&2, U32>:
  +x = (48 + (i - 1) * 64 : U32)
  GFX.cmd_rect(x, 1352, 48, 28, rgb, GFX.cmd_glyph((x + 18 : U32), 1356, 4, i, 16777215, sel_under(U32.is_eq(sel, i), x, t)))

def btns_cmds(+sel: U32, t: List<&2, U32>) -> List<&2, U32>:
  btn_cmd(1, 10134708, sel, btn_cmd(2, 14196768, sel, btn_cmd(3, 3159100, sel, btn_cmd(4, 3055172, sel, t))))

# the load arrow: a red pusher above the bar tip while the crosshead drives
def arrow_cmds(ar: Bool, +d: F32, t: List<&2, U32>) -> List<&2, U32>:
  match ar:
    case True{}:
      +tip = ypx(59, d, 1.0, 0.0)
      GFX.cmd_rect(577, (tip - 42 : U32), 13, 8, 14696512, GFX.cmd_rect(580, (tip - 36 : U32), 7, 28, 14696512, t))
    case False{}:
      t

def brk_cmds(brk: Bool, t: List<&2, U32>) -> List<&2, U32>:
  match brk:
    case True{}:
      GFX.cmd_rect(44, 1108, 10, 18, 14696512, t)
    case False{}:
      t

def draw(+m: Bench.Mat, pose: Bench.Pose, +sel: U32) -> List<&2, U32>:
  Bench.Pose{+d, rx, fl, fN, ar, brk, flash, st} = pose
  GFX.cmd_clear(1317918,
    GFX.cmd_rect(36, 1040, 8, 320, 6317680,
      bar_cmds(60n, pick(flash, 14696512, m_rgb(m)), d, rx, fl,
        arrow_cmds(ar, d,
          brk_cmds(brk,
            btns_cmds(sel, Nil{}))))))

# ---------------------------------------------------------------- app state

# sel: the selected material (1..3); phase: the bench animation; demo:
# run steel, rubber, carbon unattended, then quit; paced: advance one
# frame per 33 ms of wall clock (off in the headless probe); last: the
# clock of the last advanced frame.
type Bar is Data:
  Bar{sel: U32, phase: Bench.Phase, demo: Bool, paced: Bool, last: U32}

def frame_cmds(b: Bar) -> List<&2, U32>:
  Bar{+sel, phase, demo, paced, last} = b
  +m = Bench.mat_of(sel)
  draw(m, Bench.pose(m, phase), sel)

def view(b: Bar) -> Bar & Image:
  +b2 = b
  (b2, GFX.image(10n, frame_cmds(b2)))

def done(b: Bar) -> IO(Maybe<Bar>):
  IO.pure(Maybe<Bar>, Some{b})

def quit() -> IO(Maybe<Bar>):
  do IO<Maybe<Bar>>:
    IO.print("bye")
    return None{}

def bending(+sel: U32) -> IO(Unit):
  IO.print("bending " ++ m_name(Bench.mat_of(sel)))

def is_flash4(ph: Bench.Phase) -> Bool:
  match ph:
    case Bench.Flash{4}:
      True{}
    case _:
      False{}

def snap_note(on: Bool) -> IO(Unit):
  match on:
    case True{}:
      IO.print("  *** SNAP -- sigma_root ~ 1.08 GPa at eps ~ 0.8%, no yield, no warning")
    case False{}:
      IO.pure(Unit, Unit{})

# A bend just ended: back to the menu, or (demo) the next material.
def ended(demo: Bool, last_mat: Bool, +sel: U32, paced: Bool, +now: U32) -> IO(Maybe<Bar>):
  match demo last_mat:
    case True{} True{}:
      quit()
    case True{} False{}:
      +next = (sel + 1 : U32)
      do IO<Maybe<Bar>>:
        bending(next)
        return Some{Bar{next, Bench.start(Bench.mat_of(next)), True{}, paced, now}}
    case False{} _:
      done(Bar{sel, Bench.Menu{}, False{}, paced, now})

def moved(ended_now: Bool, +sel: U32, +ph: Bench.Phase, demo: Bool, paced: Bool, +now: U32) -> IO(Maybe<Bar>):
  match ended_now:
    case True{}:
      ended(demo, U32.is_ge(sel, 3), sel, paced, now)
    case False{}:
      do IO<Maybe<Bar>>:
        snap_note(is_flash4(ph))
        return Some{Bar{sel, ph, demo, paced, now}}

# One 33 ms frame of the bench.
def advance.go(was_menu: Bool, +sel: U32, +ph: Bench.Phase, demo: Bool, paced: Bool, +now: U32) -> IO(Maybe<Bar>):
  match was_menu:
    case True{}:
      done(Bar{sel, ph, demo, paced, now})
    case False{}:
      moved(Bench.is_menu(ph), sel, ph, demo, paced, now)

def advance(b: Bar, +now: U32) -> IO(Maybe<Bar>):
  Bar{+sel, +phase, demo, paced, last} = b
  advance.go(Bench.is_menu(phase), sel, Bench.step(Bench.mat_of(sel), phase, 27), demo, paced, now)

def advance.at(due: Bool, b: Bar, +now: U32) -> IO(Maybe<Bar>):
  match due:
    case True{}:
      advance(b, now)
    case False{}:
      done(b)

def advance.paced(b: Bar, paced: Bool, +last: U32) -> IO(Maybe<Bar>):
  match paced:
    case True{}:
      do IO<Maybe<Bar>>:
        +now : U32 <- Clock.now_ms()
        advance.at(U32.is_ge((now - last : U32), 33), b, now)
    case False{}:
      advance(b, 0)

def tick.advance(b: Bar) -> IO(Maybe<Bar>):
  Bar{sel, phase, demo, +paced, +last} = b
  advance.paced(Bar{sel, phase, demo, paced, last}, paced, last)

# 0 nothing, 1 quit, 2 select 1..3, 3 Bend!
def key_kind(+k: U32) -> U32:
  pick(U32.is_eq(k, 113) || U32.is_eq(k, 81), 1,
  pick(U32.is_eq(k, 52) || U32.is_eq(k, 98) || U32.is_eq(k, 13) || U32.is_eq(k, 32), 3,
  pick(U32.is_ge(k, 49) && U32.is_le(k, 51), 2, 0)))

def tick.menu(menu: Bool, kind: U32, +k: U32, b: Bar) -> IO(Maybe<Bar>):
  match menu kind:
    case True{} 2:
      Bar{sel, phase, demo, paced, last} = b
      tick.advance(Bar{(k - 48 : U32), phase, demo, paced, last})
    case True{} 3:
      Bar{+sel, phase, demo, paced, last} = b
      do IO<Maybe<Bar>>:
        bending(sel)
        tick.advance(Bar{sel, Bench.start(Bench.mat_of(sel)), demo, paced, last})
    case _ _:
      tick.advance(b)

def tick.key.go(q: Bool, +kind: U32, +k: U32, b: Bar) -> IO(Maybe<Bar>):
  match q:
    case True{}:
      quit()
    case False{}:
      Bar{sel, +phase, demo, paced, last} = b
      tick.menu(Bench.is_menu(phase), kind, k, Bar{sel, phase, demo, paced, last})

def tick.key(+kind: U32, +k: U32, b: Bar) -> IO(Maybe<Bar>):
  tick.key.go(U32.is_eq(kind, 1), kind, k, b)

# keys are read only at the menu, as the old loop did; q or closing the
# window quits at any time
def tick(events: List<Event>, b: Bar) -> IO(Maybe<Bar>):
  +k = GFX.key_event(events)
  tick.key(key_kind(k), k, b)

# ---------------------------------------------------------------- headless probe

def check(name: String, +got: U32, +want: U32) -> IO(Unit):
  IO.print(Bool.pick(String, U32.is_eq(got, want), "ok   ", "FAIL ") ++ name ++ ": "
    ++ U32.show(got) ++ " (want " ++ U32.show(want) ++ ")")

def frame_image(+sel: U32, ph: Bench.Phase) -> Image:
  GFX.image(10n, frame_cmds(Bar{sel, ph, False{}, False{}, 0}))

def replicate(n: Nat) -> List<List<Event>>:
  match n:
    case 0n:
      Nil{}
    case 1n+k:
      Nil{} <> replicate(k)

def press(+code: U32) -> List<Event>:
  [Key{code, True{}}]

def probe_play(r: Maybe<Bar>) -> IO(Unit):
  match r:
    case None{}:
      IO.print("ok   scripted App.play: 2, 4, 320 frames, q -> quit")
    case Some{b}:
      IO.print("FAIL scripted App.play did not quit")

def probe_menu(r: Maybe<Bar>) -> IO(Unit):
  match r:
    case Some{Bar{sel, Bench.Menu{}, demo, paced, last}}:
      check("after a rubber bend the bench is back at the menu, sel", sel, 2)
    case _:
      IO.print("FAIL a rubber bend did not return to the menu")

def probe() -> IO(Unit):
  +steel = frame_image(1, Bench.Menu{})
  +tip = frame_image(1, Bench.Push{0})
  +flash = frame_image(1, Bench.Flash{3})
  +carbon = frame_image(3, Bench.Fall{0, 0.4, 0.1})
  do IO<Unit>:
    IO.print("window_bar probe (no window)")
    IO.print(Bench.probe.show(Bench.Steel{}))
    IO.print(Bench.probe.show(Bench.Rubber{}))
    IO.print(Bench.probe.show(Bench.Cfrp{}))
    check("menu: background at (300,300)", GFX.pixel(10n, steel, 300, 300), 1317918)
    check("menu: steel bar root at (52,119)", GFX.pixel(10n, steel, 52, 119), 13160668)
    check("menu: steel bar tip at rest (583,119)", GFX.pixel(10n, steel, 583, 119), 13160668)
    check("menu: wall at (40,200)", GFX.pixel(10n, steel, 40, 200), 6317680)
    check("menu: button 1 glyph cell (72,358)", GFX.pixel(10n, steel, 72, 358), 16777215)
    check("full push: tip moved down 30 cm = 84 px (583,203)", GFX.pixel(10n, tip, 583, 203), 13160668)
    check("full push: rest row now empty (583,119)", GFX.pixel(10n, tip, 583, 119), 1317918)
    check("full push: load arrow above the tip (583,162)", GFX.pixel(10n, tip, 583, 162), 14696512)
    check("snap flash: bar drawn red (52,119)", GFX.pixel(10n, flash, 52, 119), 14696512)
    check("snap: root fracture mark (48,112)", GFX.pixel(10n, flash, 48, 112), 14696512)
    check("carbon falling 10 cm: rest row empty (60,119)", GFX.pixel(10n, carbon, 60, 119), 1317918)
    check("carbon falling 10 cm: straightened bar 29 px lower (60,147)", GFX.pixel(10n, carbon, 60, 147), 4738136)
    IO.print("menu frame: " ++ U32.show(GFX.leaves(steel)) ++ " leaves, full push: "
      ++ U32.show(GFX.leaves(tip)) ++ " leaves (vs 409600 pixels)")
    r1 : Maybe<Bar> <- App.play(~Bar, ~App{view, tick}, press(50) <> press(52) <> replicate(320n), Bar{1, Bench.Menu{}, False{}, False{}, 0})
    probe_menu(r1)
    r2 : Maybe<Bar> <- App.play(~Bar, ~App{view, tick},
      press(50) <> press(52) <> List.append(&1, List<Event>, replicate(320n), [press(113)]),
      Bar{1, Bench.Menu{}, False{}, False{}, 0})
    probe_play(r2)

# ---------------------------------------------------------------- main

def run(r: Result<&1, &1, U32 & String, Window>, b: Bar) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("could not open a window")
    case Done{w}:
      App.loop(~Bar, ~App{view, tick}, 4294967295n, w, b)

def open(b: Bar) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, Window> <- Window.open("Bend bar bench -- 1 steel  2 rubber  3 carbon  4 bend  q quit", 640, 400)
    run(r, b)

def go(+now: U32, args: List<String>) -> IO(Unit):
  match args:
    case prog <> "--probe" <> rest:
      probe()
    case prog <> a <> rest:
      do IO<Unit>:
        IO.print("demo: steel, rubber, carbon, then exit")
        bending(1)
        open(Bar{1, Bench.start(Bench.Steel{}), True{}, True{}, now})
    case _:
      open(Bar{1, Bench.Menu{}, False{}, True{}, now})

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    +now : U32 <- Clock.now_ms()
    go(now, args)
