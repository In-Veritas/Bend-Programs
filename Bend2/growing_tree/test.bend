# Headless tests for main.bend: drive the pure step/view with scripted
# events and print PASS/FAIL lines plus census summaries.
#
#   bend test.bend -o /tmp/growing_tree_test && /tmp/growing_tree_test
import Base
import ./main.bend as T

# Helpers
# =======

def press(+x: U32, +y: U32) -> Event:
  Press{0, Tool.Mouse{}, U32.to_f32(x), U32.to_f32(y), 0, 0, True{}}

def key(+c: U32) -> Event:
  Key{c, True{}}

# A click at the centre of cell (cx, cy).
def click_cell(+cx: U32, +cy: U32) -> Event:
  press((cx * 16 + 8 : U32), (cy * 16 + 8 : U32))

def ok(m: Maybe<T.State>) -> T.State:
  match m:
    case None{}:
      T.init()
    case Some{s}:
      s

def quits(m: Maybe<T.State>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{s}:
      False{}

def step(es: List<Event>, s: T.State) -> T.State:
  ok(T.Tree.step(es, s))

# n display frames with no events.
def frames(n: Nat, s: T.State) -> T.State:
  match n:
    case 0n:
      s
    case 1n+p:
      frames(p, step([], s))

def tick_of(+s: T.State) -> U32:
  T.State{b, t, r, sp, ph, sl, tx, w} = s
  t

def soil_of(+s: T.State) -> U32:
  T.State{b, t, r, sp, ph, sl, tx, w} = s
  sl

def tx_of(+s: T.State) -> U32:
  T.State{b, t, r, sp, ph, sl, tx, w} = s
  tx

def growing(+s: T.State) -> Bool:
  T.State{b, t, r, sp, ph, sl, tx, w} = s
  match ph:
    case T.Unplanted{}:
      False{}
    case T.Growing{}:
      True{}

def at(+s: T.State, +x: U32, +y: U32) -> U32:
  T.State{b, t, r, sp, ph, sl, tx, w} = s
  T.cell_get(b, x, y)

def census(+s: T.State) -> T.Census:
  T.State{b, t, r, sp, ph, sl, tx, w} = s
  T.census(b)

def total(c: T.Census) -> U32:
  T.Census{a, r, k, h, l} = c
  (a + r + k + h + l : U32)

def leaves(c: T.Census) -> U32:
  T.Census{a, r, k, h, l} = c
  l

def roots(c: T.Census) -> U32:
  T.Census{a, r, k, h, l} = c
  r

def barks(c: T.Census) -> U32:
  T.Census{a, r, k, h, l} = c
  k

# Every cell of kind k on rows [y0, y1): counts the misplaced ones.
def count_rows(n: Nat, +s: T.State, +k: U32, +i: U32, +y0: U32, +y1: U32) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      +x = (i % 46 : U32)
      +y = (i / 46 : U32)
      +hit = (U32.is_eq(at(s, x, y), k) && (y >= y0) && (y < y1) : U32)
      (T.sel(hit, 1, 0) + count_rows(p, s, k, (i + 1 : U32), y0, y1) : U32)

def misplaced(+s: T.State, +k: U32, +y0: U32, +y1: U32) -> U32:
  count_rows(1564n, s, k, 0, y0, y1)

def pick_img(q: U32, a: Image, b: Image, c: Image, d: Image) -> Image:
  match q:
    case 0:
      a
    case 1:
      b
    case 2:
      c
    case _:
      d

# The color of pixel (x, y) of an image over a 2^d square.
def sample(+d: Nat, img: Image, +x: U32, +y: U32) -> U32:
  match d img:
    case _ Pix{c}:
      c
    case 0n Qua{a, b, c, e}:
      sample(0n, a, x, y)
    case 1n+e Qua{a, b, c, dd}:
      sample(e, pick_img(T.quad(x, y, e), a, b, c, dd), x, y)

def pixel(+s: T.State, +x: U32, +y: U32) -> U32:
  sample(10n, T.render(s), x, y)

def report(name: String, pass: Bool) -> IO(Unit):
  match pass:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.print("FAIL " ++ name)

def show(c: T.Census) -> String:
  T.Census.show(c)

# A grown tree: plant at (23, soil) and run n ticks at once.
def grown(+soil: U32, n: Nat) -> T.State:
  T.run_ticks(n, step([click_cell(23, soil)], T.init()))

def main() -> IO(Unit):
  +s0 = T.init()
  +s1 = step([click_cell(23, 14)], s0)
  +s2 = step([click_cell(5, 5)], s1)
  +g14 = grown(14, 60n)
  +g8 = grown(8, 60n)
  +c14 = census(g14)
  +c8 = census(g8)
  +long = grown(14, 400n)
  +cl = census(long)
  +paused = frames(100n, step([key(112)], s1))
  +normal = frames(24n, s1)
  +f0 = T.set_speed(T.Fast{}, s1)
  +fast = frames(7n, f0)
  +m0 = T.set_speed(T.Unlimited{}, s1)
  +max = frames(1n, m0)
  +k3 = step([key(51)], s1)
  +reset = step([key(114)], g14)
  do IO<Unit>:
    report("T1 click plants seed + base (seed, 2 shoots, 2 roots)",
      growing(s1) && U32.is_eq(at(s1, 23, 14), 1) && U32.is_eq(at(s1, 23, 13), 4)
      && U32.is_eq(at(s1, 23, 12), 4) && U32.is_eq(at(s1, 22, 14), 2)
      && U32.is_eq(at(s1, 24, 14), 2) && U32.is_eq(soil_of(s1), 14)
      && U32.is_eq(tx_of(s1), 23) && U32.is_eq(total(census(s1)), 5))
    report("T2 a second click is ignored", U32.is_eq(total(census(s2)), 5)
      && U32.is_eq(at(s2, 5, 5), 0))
    report("T3 an empty board's click before planting ignores off-grid",
      Bool.not(growing(step([press(2000, 100)], s0))))
    IO.print("     soil=14, 60 ticks: " ++ show(c14))
    IO.print("     soil=8,  60 ticks: " ++ show(c8))
    IO.print("     soil=14, 400 ticks: " ++ show(cl))
    report("T4 balanced tree at soil 14 (leaves, trunk, roots all present)",
      ((leaves(c14) > 5) && (barks(c14) > 5) && (roots(c14) > 5) : U32))
    report("T5 planting high (soil 8) still grows a canopy",
      (leaves(c8) > 5 : U32))
    report("T6 roots never above the soil line",
      U32.is_eq(misplaced(g14, 2, 0, 14), 0) && U32.is_eq(misplaced(long, 2, 0, 14), 0))
    report("T7 leaves only above the soil line",
      U32.is_eq(misplaced(g14, 5, 14, 34), 0) && U32.is_eq(misplaced(long, 5, 14, 34), 0))
    report("T8 the tree keeps growing (400 ticks > 60 ticks)",
      (total(cl) > total(c14) : U32))
    report("T9 pause: 100 frames, 0 ticks", U32.is_eq(tick_of(paused), tick_of(s1)))
    report("T10 play: 24 frames = 1 tick", U32.is_eq(tick_of(normal), (tick_of(s1) + 1 : U32)))
    report("T11 fast: 7 frames = 6 ticks", U32.is_eq(tick_of(fast), (tick_of(f0) + 6 : U32)))
    report("T12 max: 1 frame = 40 ticks (key 3 selects it)",
      U32.is_eq(tick_of(max), (tick_of(m0) + 40 : U32))
      && U32.is_eq(tick_of(k3), (tick_of(s1) + 40 : U32)))
    report("T13 reset empties the board", Bool.not(growing(reset))
      && U32.is_eq(total(census(reset)), 0) && U32.is_eq(tick_of(reset), 0))
    report("T14 Esc and Close quit", quits(T.Tree.step([key(27)], s1))
      && quits(T.Tree.step([Close{}], s1)))
    report("T15 view: seed cell, board, soil dash, HUD legend pixels",
      U32.is_eq(pixel(s1, (23 * 16 + 8 : U32), (14 * 16 + 8 : U32)), 10510384)
      && U32.is_eq(pixel(s1, 100, 100), 16117729)
      && U32.is_eq(pixel(s1, 1, (14 * 16 : U32)), 11570519)
      && U32.is_eq(pixel(s1, 8, (34 * 16 + 8 : U32)), 10510384)
      && U32.is_eq(pixel(s0, 1, (14 * 16 : U32)), 16117729)
      && U32.is_eq(pixel(s1, 800, 100), 0))
    IO.print("     status: " ++ T.Tree.status(g14))
