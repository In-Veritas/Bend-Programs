# CommandGFX: the flat draw-command protocol of the old window demos
# (bar_bench/window_bar, elements), rendered as a Bend 2.0.40 `Image`
# for `App.run`, plus the event decoding those demos used.
#
#   import ../CommandGFX.bend as GFX
#
# The pure side of each demo still emits the same flat `List<&2, U32>`
# command stream the web twins send to the browser canvas:
#
#   0 rgb                  clear the frame to rgb
#   1 x yb w h rgb         fill a w x h rectangle at (x, yb - 1000)
#   2 x yb s glyph rgb     a 3x5 glyph (digits 0-9, B E N D !) of s-pixel cells
#
# y carries a +1000 bias so the pure side never builds a negative U32.
# Later commands paint over earlier ones.
#
# Rendering follows `bend guide shaders`: the stream is parsed once into
# a list of rectangles, topmost first (a glyph becomes one rectangle per
# lit cell); the quadtree is built top-down, each square keeping only
# the rectangles that meet it, and a square becomes one `Pix` as soon as
# its topmost rectangle covers it (or nothing meets it). So the image has
# about as many nodes as the frame has edges, not one per pixel. The top
# levels fork in parallel lets (4^3 = 64 tasks), the rest is sequential.
import Base

# Commands
# --------

def cmd_clear(rgb: U32, t: List<&2, U32>) -> List<&2, U32>:
  0 <> rgb <> t

def cmd_rect(x: U32, yb: U32, w: U32, h: U32, rgb: U32, t: List<&2, U32>) -> List<&2, U32>:
  1 <> x <> yb <> w <> h <> rgb <> t

def cmd_glyph(x: U32, yb: U32, s: U32, g: U32, rgb: U32, t: List<&2, U32>) -> List<&2, U32>:
  2 <> x <> yb <> s <> g <> rgb <> t

# Rectangles
# ----------

# A rectangle in biased coordinates (y + 1000).
type Rect is Data:
  Rect{x: U32, y: U32, w: U32, h: U32, rgb: U32}

# Topmost first.
type Rects is Data:
  RNil{}
  RCons{r: Rect, next: Rects}

# The 3x5 font, 3 bits per row, top row in the high bits (same table as
# the old effs/window.c and the web pages): digits, then B E N D !.
def glyph_bits(code: U32) -> U32:
  match code:
    case 0:
      31599
    case 1:
      11415
    case 2:
      29671
    case 3:
      29647
    case 4:
      23497
    case 5:
      31183
    case 6:
      31215
    case 7:
      29257
    case 8:
      31727
    case 9:
      31695
    case 10:
      27566
    case 11:
      31143
    case 12:
      31597
    case 13:
      27502
    case _:
      9346

def glyph_put(on: Bool, r: Rect, acc: Rects) -> Rects:
  match on:
    case True{}:
      RCons{r, acc}
    case False{}:
      acc

# Cells b..14 of a glyph (row b / 3, column b % 3) as rectangles.
def glyph_rects(fuel: Nat, +b: U32, +bits: U32, +gx: U32, +gy: U32, +s: U32, +rgb: U32,
  acc: Rects) -> Rects:
  match fuel:
    case 0n:
      acc
    case 1n+f:
      +row = (b / 3 : U32)
      +col = (b % 3 : U32)
      +shift = (14 - b : U32)
      +on = U32.is_eq((U32.shrn(bits, U32.to_nat(shift)) .&. 1 : U32), 1)
      glyph_rects(f, (b + 1 : U32), bits, gx, gy, s, rgb,
        glyph_put(on, Rect{(gx + col * s : U32), (gy + row * s : U32), s, s, rgb}, acc))

# The command stream as rectangles, topmost first. A malformed tail is
# ignored, as the old presenter did.
def parse(cmds: List<&2, U32>, acc: Rects) -> Rects:
  match cmds:
    case 0 <> c <> t:
      parse(t, RCons{Rect{0, 0, 65535, 65535, c}, acc})
    case 1 <> x <> y <> w <> h <> c <> t:
      parse(t, RCons{Rect{x, y, w, h, c}, acc})
    case 2 <> x <> y <> s <> g <> c <> t:
      parse(t, glyph_rects(15n, 0, glyph_bits(g), x, y, s, c, acc))
    case _:
      acc

# Quadtree
# --------

# Does r meet the s x s square at (x0, y0)?
def meets(r: Rect, +x0: U32, +y0: U32, +s: U32) -> Bool:
  Rect{+x, +y, +w, +h, c} = r
  ((x < x0 + s) && (x0 < x + w) && (y < y0 + s) && (y0 < y + h) : U32)

# Does r cover the whole s x s square at (x0, y0)?
def covers(r: Rect, +x0: U32, +y0: U32, +s: U32) -> Bool:
  Rect{+x, +y, +w, +h, c} = r
  ((x <= x0) && (x0 + s <= x + w) && (y <= y0) && (y0 + s <= y + h) : U32)

def keep(on: Bool, r: Rect, rest: Rects) -> Rects:
  match on:
    case True{}:
      RCons{r, rest}
    case False{}:
      rest

# The rectangles that meet a square, order kept.
def filter(rs: Rects, +x0: U32, +y0: U32, +s: U32) -> Rects:
  match rs:
    case RNil{}:
      RNil{}
    case RCons{+r, n}:
      keep(meets(r, x0, y0, s), r, filter(n, x0, y0, s))

# One color for the square: nothing meets it, or its topmost rectangle
# covers it.
def flat(rs: Rects, +x0: U32, +y0: U32, +s: U32) -> Bool:
  match rs:
    case RNil{}:
      True{}
    case RCons{r, n}:
      covers(r, x0, y0, s)

def top(rs: Rects) -> U32:
  match rs:
    case RNil{}:
      0
    case RCons{Rect{x, y, w, h, c}, n}:
      c

# The 2^d square at (x0, y0); rs already holds only what meets it.
def draw(+d: Nat, is_flat: Bool, +x0: U32, +y0: U32, +rs: Rects) -> Image:
  match d is_flat:
    case 0n _:
      Pix{top(rs)}
    case _ True{}:
      Pix{top(rs)}
    case 1n+e False{}:
      +h = U32.shln(1, e)
      +x1 = (x0 + h : U32)
      +y1 = (y0 + h : U32)
      +a = filter(rs, x0, y0, h)
      +b = filter(rs, x1, y0, h)
      +c = filter(rs, x0, y1, h)
      +k = filter(rs, x1, y1, h)
      Qua{draw(e, flat(a, x0, y0, h), x0, y0, a), draw(e, flat(b, x1, y0, h), x1, y0, b),
        draw(e, flat(c, x0, y1, h), x0, y1, c), draw(e, flat(k, x1, y1, h), x1, y1, k)}

# The same, forking the four quarters for p more levels.
def draw_par(+p: Nat, +d: Nat, is_flat: Bool, +x0: U32, +y0: U32, +rs: Rects) -> Image:
  match p d is_flat:
    case 0n _ _:
      draw(d, is_flat, x0, y0, rs)
    case _ 0n _:
      Pix{top(rs)}
    case _ _ True{}:
      Pix{top(rs)}
    case 1n+q 1n+e False{}:
      +h = U32.shln(1, e)
      +x1 = (x0 + h : U32)
      +y1 = (y0 + h : U32)
      +a = filter(rs, x0, y0, h)
      +b = filter(rs, x1, y0, h)
      +c = filter(rs, x0, y1, h)
      +k = filter(rs, x1, y1, h)
      tl tr bl br = draw_par(q, e, flat(a, x0, y0, h), x0, y0, a)
        draw_par(q, e, flat(b, x1, y0, h), x1, y0, b)
        draw_par(q, e, flat(c, x0, y1, h), x0, y1, c)
        draw_par(q, e, flat(k, x1, y1, h), x1, y1, k)
      Qua{tl, tr, bl, br}

# The frame for a window whose larger side fits 2^d pixels (d = 10 for
# 640 x 400): the root square starts at biased y = 1000.
def image_rects(+d: Nat, +rs: Rects) -> Image:
  +s = U32.shln(1, d)
  draw_par(3n, d, flat(rs, 0, 1000, s), 0, 1000, rs)

def image(d: Nat, cmds: List<&2, U32>) -> Image:
  image_rects(d, parse(cmds, RNil{}))

# Reading images back (for headless tests)
# ----------------------------------------

def quarter(right: Bool, down: Bool, tl: Image, tr: Image, bl: Image, br: Image) -> Image:
  match right down:
    case False{} False{}:
      tl
    case True{} False{}:
      tr
    case False{} True{}:
      bl
    case True{} True{}:
      br

# The color at (x, y) of a 2^d image.
def pixel(+d: Nat, img: Image, +x: U32, +y: U32) -> U32:
  match d img:
    case _ Pix{c}:
      c
    case 0n Qua{tl, tr, bl, br}:
      0
    case 1n+e Qua{tl, tr, bl, br}:
      +h = U32.shln(1, e)
      pixel(e, quarter(U32.is_ge(x, h), U32.is_ge(y, h), tl, tr, bl, br), (x % h : U32), (y % h : U32))

# How many Pix leaves an image has.
def leaves(img: Image) -> U32:
  match img:
    case Pix{c}:
      1
    case Qua{a, b, c, d}:
      (leaves(a) + leaves(b) + leaves(c) + leaves(d) : U32)

# Events
# ------

def inside(+v: U32, +start: U32, +size: U32) -> Bool:
  ((v >= start) && (v < start + size) : U32)

# The first key pressed this frame (0 for none); a Close is 'q' (113),
# as the old presenter reported it.
def key_event(events: List<Event>) -> U32:
  match events:
    case Nil{}:
      0
    case Key{code, True{}} <> rest:
      code
    case Close{} <> rest:
      113
    case e <> rest:
      key_event(rest)

# A main-button press in one of the elements demo's four 300 x 152
# panels, as the old presenter packed it:
#   256 + 4 * (local_y * 300 + local_x) + panel   (0 earth, 1 water, 2 fire, 3 air)
def panel_click.at(top: Bool, bot: Bool, left: Bool, right: Bool, +x: U32, +y: U32) -> U32:
  match top bot left right:
    case True{} _ True{} _:
      (256 + 4 * ((y - 76) * 300 + (x - 12)) : U32)
    case True{} _ False{} True{}:
      (256 + 4 * ((y - 76) * 300 + (x - 328)) + 1 : U32)
    case False{} True{} True{} _:
      (256 + 4 * ((y - 240) * 300 + (x - 12)) + 2 : U32)
    case False{} True{} False{} True{}:
      (256 + 4 * ((y - 240) * 300 + (x - 328)) + 3 : U32)
    case _ _ _ _:
      0

def panel_click(+x: U32, +y: U32) -> U32:
  panel_click.at(inside(y, 76, 152), inside(y, 240, 152), inside(x, 12, 300), inside(x, 328, 300), x, y)

def first_nonzero(+a: U32, b: U32) -> U32:
  Bool.pick(U32, U32.is_eq(a, 0), b, a)

# The first key pressed or panel clicked this frame (0 for none); a
# Close is 'q' (113).
def panel_event(events: List<Event>) -> U32:
  match events:
    case Nil{}:
      0
    case Key{code, True{}} <> rest:
      code
    case Press{id, tool, x, y, time, 0, True{}} <> rest:
      first_nonzero(panel_click(F32.to_u32(x), F32.to_u32(y)), panel_event(rest))
    case Close{} <> rest:
      113
    case e <> rest:
      panel_event(rest)
