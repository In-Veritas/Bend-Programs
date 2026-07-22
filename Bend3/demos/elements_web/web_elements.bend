# web_elements: the four bending arts as a webapp.
#
# Same pure scene stack as ../elements (four clickable panels of
# traveling-sine motion, Bhaskara sine, "BEND!" glyph title), but the presenter is a
# browser canvas instead of a Cocoa window: this Bend HTTP server
# computes any frame on demand and serves it as draw commands; the page
# (index.html, served from here) only rasterizes. Stateless: frame i is
# the scene at t = i*0.033 (i wraps at 190400 so t stays in fsin range).
#
# routes:
#   GET /            the page (read from disk, so run from the repo root)
#   GET /frame/<i>/<earth>/<water>/<fire>/<air>
#                     {"cmds":[...]} for frame i and four packed
#                     {countdown, local x, local y} reaction states
#
# build:  node bend-ts/src/main.ts gabriel_demos/elements_web/web_elements.bend --no-halt -o gabriel_demos/elements_web/web_elements
# run:    ./gabriel_demos/elements_web/web_elements   (from the repo root)
# open:   http://<server-lan-ip>:8081
#
# no-halt
# skip-native

import IO
import List
import String
import Char
import Result
import TCP
import HTTP

def clamp0(x: F32) -> F32:
  match x <. 0.0:
    case 0:
      x
    case k:
      0.0

# sine for any |x| < ~6400: floor-based range reduction mod 2pi (the
# +1024 shift makes truncation act as floor), Bhaskara I on each half
def fsin_h(t: F32) -> F32:
  p = t *. (3.14159265 -. t)
  (16.0 *. p) /. (49.3480220 -. (4.0 *. p))

def fsin(x: F32) -> F32:
  q = u32_to_f32(f32_to_u32((x /. 6.28318531) +. 1024.0)) -. 1024.0
  r = x -. (q *. 6.28318531)
  match r >. 3.14159265:
    case 0:
      fsin_h(r)
    case k:
      0.0 -. fsin_h(r -. 3.14159265)

def fcos(x: F32) -> F32:
  fsin(x +. 1.57079633)

def f32_abs(x: F32) -> F32:
  match x <. 0.0:
    case 0:
      x
    case k:
      0.0 -. x

def f32_cap(x: F32, top: F32) -> F32:
  match x >. top:
    case 0:
      x
    case k:
      top

def f32_falloff(delta: F32, radius: F32) -> F32:
  radius /. (radius +. f32_abs(delta))

def u32_cap(x: U32, top: U32) -> U32:
  match x > top:
    case 0:
      x
    case k:
      top

# A reaction packs a six-bit countdown and the 300x152 local click point:
#   time + x*64 + y*(64*300)
def u32_reaction_make(time: U32, x: U32, y: U32) -> U32:
  u32_cap(time, 63) + ((x % 300) * 64) + ((y % 152) * 19200)

def u32_reaction_time(x: U32) -> U32:
  x % 64

def u32_reaction_x(x: U32) -> U32:
  (x / 64) % 300

def u32_reaction_y(x: U32) -> U32:
  (x / 19200) % 152

def u32_reaction_limit(x: U32, top: U32) -> U32:
  u32_reaction_make(u32_cap(u32_reaction_time(x), top), u32_reaction_x(x), u32_reaction_y(x))

def u32_reaction_amp(x: U32, top: U32) -> F32:
  u32_to_f32(u32_cap(u32_reaction_time(x), top)) /. u32_to_f32(top)

def u32_reaction_age(x: U32, top: U32) -> F32:
  match u32_reaction_time(x):
    case 0:
      0.0
    case k:
      u32_to_f32(top - u32_cap(k, top))

def u32_active_rgb(x: U32, idle: U32, active: U32) -> U32:
  match u32_reaction_time(x):
    case 0:
      idle
    case k:
      active

# ---------------------------------------------------------------- draw commands

def cmd_clear(rgb: U32, t: List<U32>) -> List<U32>:
  Cons{0, Cons{rgb, t}}

def cmd_rect(x: U32, yb: U32, w: U32, h: U32, rgb: U32, t: List<U32>) -> List<U32>:
  Cons{1, Cons{x, Cons{yb, Cons{w, Cons{h, Cons{rgb, t}}}}}}

def cmd_glyph(x: U32, yb: U32, s: U32, g: U32, rgb: U32, t: List<U32>) -> List<U32>:
  Cons{2, Cons{x, Cons{yb, Cons{s, Cons{g, Cons{rgb, t}}}}}}

# a rect placed inside a panel: px,py panel origin, fx,fy F32 local coords
def prect(px: U32, py: U32, fx: F32, fy: F32, w: U32, h: U32, rgb: U32, t: List<U32>) -> List<U32>:
  cmd_rect(px + f32_to_u32(clamp0(fx) +. 0.5), (1000 + py) + f32_to_u32(clamp0(fy) +. 0.5), w, h, rgb, t)

# ---------------------------------------------------------------- earth (12,76)
# a click strikes a local epicenter: the ground pulse decays with distance,
# and each boulder is launched up and away from the point of impact

def earth_pillars(k: U32, t: F32, hit: U32, acc: List<U32>) -> List<U32>:
  match k:
    case 0:
      acc
    case n:
      p = u32_to_f32(n - 1)
      x = 10.0 +. (p *. 28.0)
      amp = u32_reaction_amp(hit, 48)
      age = u32_reaction_age(hit, 48)
      cx = u32_to_f32(u32_reaction_x(hit))
      power = 0.55 +. (u32_to_f32(u32_reaction_y(hit)) /. 160.0)
      near = f32_falloff(x -. cx, 44.0)
      base = 26.0 +. (18.0 *. fsin((p *. 0.9) -. (t *. 2.1)))
      pulse = (((24.0 *. amp) *. power) *. near) *. fcos((f32_abs(x -. cx) *. 0.065) -. (age *. 0.34))
      ph = clamp0(base +. pulse)
      y = (138.0 -. ph)
      hh = f32_to_u32(ph +. 0.5)
      earth_pillars(n - 1, t, hit,
        prect(12, 76, x, y, 24, hh, 9073493,
          prect(12, 76, x, y, 24, 4, 7035458, acc)))

def earth_rocks(k: U32, hit: U32, acc: List<U32>) -> List<U32>:
  match k:
    case 0:
      acc
    case n:
      j = n - 1
      i = u32_to_f32(j)
      phase = u32_reaction_age(hit, 48) /. 48.0
      launch = (4.0 *. phase) *. (1.0 -. phase)
      base = 20.0 +. (i *. 120.0)
      cx = u32_to_f32(u32_reaction_x(hit))
      delta = (base +. 10.0) -. cx
      near = f32_falloff(delta, 92.0)
      away = delta /. (18.0 +. f32_abs(delta))
      power = 0.55 +. (u32_to_f32(u32_reaction_y(hit)) /. 160.0)
      x = base +. ((((96.0 *. power) *. near) *. away) *. launch)
      y = 124.0 -. (((52.0 +. ((68.0 *. power) *. near)) *. launch))
      earth_rocks(n - 1, hit,
        prect(12, 76, x, y, 20, 14, 10125410,
          prect(12, 76, x +. 4.0, y -. 4.0, 12, 5, 9073493, acc)))

def earth(t: F32, hit: U32, acc: List<U32>) -> List<U32>:
  cmd_rect(12, 1214, 300, 14, 4864810,
    earth_pillars(10, t, hit, earth_rocks(3, hit, acc)))

# ---------------------------------------------------------------- water (328,76)
# the click is a pull point: it raises a local traveling ripple and draws
# the lifted ribbon toward that part of the pool

def water_cols(k: U32, t: F32, hit: U32, acc: List<U32>) -> List<U32>:
  match k:
    case 0:
      acc
    case n:
      c = u32_to_f32(n - 1)
      x = c *. 12.0
      amp = u32_reaction_amp(hit, 60)
      age = u32_reaction_age(hit, 60)
      cx = u32_to_f32(u32_reaction_x(hit))
      lift = 0.45 +. ((151.0 -. u32_to_f32(u32_reaction_y(hit))) /. 170.0)
      near = f32_falloff(x -. cx, 38.0 +. age)
      base = (70.0 +. (12.0 *. fsin((c *. 0.55) -. (t *. 2.2)))) +. (5.0 *. fsin((c *. 1.3) +. (t *. 3.1)))
      pull = ((((28.0 *. amp) *. lift) *. near) *. fcos((f32_abs(x -. cx) *. 0.075) -. (age *. 0.31)))
      ys = base -. pull
      hh = f32_to_u32(clamp0(152.0 -. ys) +. 0.5)
      water_cols(n - 1, t, hit,
        prect(328, 76, x, ys, 12, hh, 2977500,
          prect(328, 76, x, ys -. 3.0, 12, 4, 8370416, acc)))

def water_whirl(k: U32, t: F32, hit: U32, acc: List<U32>) -> List<U32>:
  match k:
    case 0:
      acc
    case n:
      i = u32_to_f32(n - 1)
      amp = u32_reaction_amp(hit, 60)
      cx = u32_to_f32(u32_reaction_x(hit))
      cy = u32_to_f32(u32_reaction_y(hit))
      lift = 0.45 +. ((151.0 -. cy) /. 170.0)
      pull = amp *. 0.72
      a = (((t *. 1.8) +. (i *. 0.5)) +. (u32_reaction_age(hit, 60) *. 0.24)) +. ((cx /. 300.0) *. amp)
      mx = 144.0 +. (((cx -. 144.0) *. pull))
      my = 32.0 +. (((cy -. 32.0) *. pull) *. 0.48)
      x = mx +. ((26.0 +. ((24.0 *. amp) *. lift)) *. fcos(a))
      y = my +. ((18.0 +. ((12.0 *. amp) *. lift)) *. fsin(a))
      water_whirl(n - 1, t, hit,
        prect(328, 76, x, y, 9, 7, 5232869, acc))

def water(t: F32, hit: U32, acc: List<U32>) -> List<U32>:
  water_cols(25, t, hit, water_whirl(6, t, hit, acc))

# ---------------------------------------------------------------- fire (12,240)
# a click feeds heat into a local point: nearby columns flare most, while
# sparks are pulled toward the hotspot before rising from it

def fire_cols(k: U32, t: F32, hit: U32, acc: List<U32>) -> List<U32>:
  match k:
    case 0:
      acc
    case n:
      c = u32_to_f32(n - 1)
      x = 7.0 +. (c *. 13.0)
      s1 = 0.5 +. (0.5 *. fsin((c *. 1.9) +. (t *. 5.3)))
      s2 = 0.6 +. (0.4 *. fsin((c *. 0.8) -. (t *. 3.1)))
      amp = u32_reaction_amp(hit, 45)
      cx = u32_to_f32(u32_reaction_x(hit))
      heat = 0.55 +. (u32_to_f32(u32_reaction_y(hit)) /. 160.0)
      near = f32_falloff(x -. cx, 34.0)
      ho = f32_cap((20.0 +. (60.0 *. (s1 *. s2))) +. (((72.0 *. amp) *. heat) *. near), 145.0)
      hm = ho *. 0.62
      hc = ho *. 0.30
      fire_cols(n - 1, t, hit,
        prect(12, 240, x, 148.0 -. ho, 13, f32_to_u32(ho +. 0.5), 13646360,
          prect(12, 240, x +. 2.0, 148.0 -. hm, 9, f32_to_u32(hm +. 0.5), 15759384,
            prect(12, 240, x +. 4.0, 148.0 -. hc, 5, f32_to_u32(hc +. 0.5), 16308296, acc))))

def fire_sparks(k: U32, t: F32, hit: U32, acc: List<U32>) -> List<U32>:
  match k:
    case 0:
      acc
    case n:
      i = u32_to_f32(n - 1)
      amp = u32_reaction_amp(hit, 45)
      cx = u32_to_f32(u32_reaction_x(hit))
      heat = 0.55 +. (u32_to_f32(u32_reaction_y(hit)) /. 160.0)
      base = 34.0 +. (i *. 72.0)
      near = f32_falloff(base -. cx, 70.0)
      v = ((t *. 55.0) +. (i *. 40.0)) +. (((u32_reaction_age(hit, 45) *. 9.0) *. heat) *. near)
      m = v -. (u32_to_f32(f32_to_u32(v /. 130.0)) *. 130.0)
      x = (base +. ((((cx -. base) *. amp) *. near) *. 0.62)) +. (6.0 *. fsin((t *. 3.0) +. i))
      fire_sparks(n - 1, t, hit,
        prect(12, 240, x, 140.0 -. m, 4, 4, 16308296, acc))

def fire(t: F32, hit: U32, acc: List<U32>) -> List<U32>:
  fire_cols(22, t, hit, fire_sparks(4, t, hit, acc))

# ---------------------------------------------------------------- air (328,240)
# the click supplies a directional gust from the panel center: its angle
# moves the vortex, while its distance controls expansion and spin

def air_parts(k: U32, t: F32, hit: U32, acc: List<U32>) -> List<U32>:
  match k:
    case 0:
      acc
    case n:
      arm = u32_to_f32((n - 1) / 10)
      j = u32_to_f32((n - 1) % 10)
      amp = u32_reaction_amp(hit, 60)
      dx = (u32_to_f32(u32_reaction_x(hit)) -. 150.0) /. 150.0
      dy = (u32_to_f32(u32_reaction_y(hit)) -. 76.0) /. 76.0
      force = 0.55 +. ((f32_abs(dx) +. f32_abs(dy)) *. 0.38)
      age = u32_reaction_age(hit, 60)
      a = (((t *. 2.2) +. (arm *. 2.0944)) +. (j *. 0.30)) +. (age *. (0.20 +. (dx *. 0.12)))
      r = (13.0 +. (j *. 6.3)) +. ((32.0 *. amp) *. force)
      x = (144.0 +. ((dx *. 55.0) *. amp)) +. (r *. fcos(a))
      y = (72.0 +. ((dy *. 38.0) *. amp)) +. (r *. fsin(a))
      sz = (7 - (((n - 1) % 10) / 2)) + (u32_reaction_time(hit) / 30)
      air_parts(n - 1, t, hit,
        prect(328, 240, x, y, sz, sz, 13358056, acc))

def air(t: F32, hit: U32, acc: List<U32>) -> List<U32>:
  air_parts(30, t, hit, acc)

# ---------------------------------------------------------------- scene

# glyphs: B=10 E=11 N=12 D=13 !=14, scale 8 -> 24x40 each
def title(acc: List<U32>) -> List<U32>:
  cmd_glyph(240, 1014, 8, 10, 15790072,
    cmd_glyph(272, 1014, 8, 11, 15790072,
      cmd_glyph(304, 1014, 8, 12, 15790072,
        cmd_glyph(336, 1014, 8, 13, 15790072,
          cmd_glyph(368, 1014, 8, 14, 15790072, acc)))))

def panels(e: U32, w: U32, f: U32, a: U32, acc: List<U32>) -> List<U32>:
  cmd_rect(12, 1076, 300, 152, u32_active_rgb(e, 1709839, 2634274),
    cmd_rect(328, 1076, 300, 152, u32_active_rgb(w, 923168, 1323088),
      cmd_rect(12, 1240, 300, 152, u32_active_rgb(f, 1708044, 2695198),
        cmd_rect(328, 1240, 300, 152, u32_active_rgb(a, 1316378, 2177379), acc))))

def scene(t: F32, e: U32, w: U32, f: U32, a: U32) -> List<U32>:
  cmd_clear(921622,
    title(
      panels(e, w, f, a,
        earth(t, e, water(t, w, fire(t, f, air(t, a, Nil{})))))))

# ---------------------------------------------------------------- json

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

def cat(a: String, b: String) -> String:
  List::concat<Char>(a, b)

def cat3(a: String, b: String, c: String) -> String:
  cat(a, cat(b, c))

def jnums(bs: List<U32>) -> String:
  match bs:
    case Nil{}:
      "]"
    case Cons{h, t}:
      cat3(",", u32s(h), jnums(t))

def jarr(bs: List<U32>) -> String:
  match bs:
    case Nil{}:
      "[]"
    case Cons{h, t}:
      cat3("[", u32s(h), jnums(t))

def cat3j(a: String, b: String, c: String) -> String:
  cat(a, cat(b, c))

# ---------------------------------------------------------------- http

def pu32_go(s: String, acc: U32) -> U32:
  match s:
    case Nil{}:
      acc
    case Cons{c, t}:
      pu32_c(c, t, acc)

def pu32_c(c: Char, t: String, acc: U32) -> U32:
  match c:
    case Char{n}:
      pu32_go(t, (acc * 10) + ((n - 48) % 10))

def pu32(s: String) -> U32:
  pu32_go(s, 0)

def frame_json(i: U32, e: U32, w: U32, f: U32, a: U32) -> Response:
  cmds = scene(u32_to_f32(i % 190400) *. 0.033,
               u32_reaction_limit(e, 48), u32_reaction_limit(w, 60),
               u32_reaction_limit(f, 45), u32_reaction_limit(a, 60))
  reply(200, "application/json", cat3("{\"cmds\":", jarr(cmds), "}"))

def index2(h: Result<String>) -> IO<Response>:
  match h:
    case Done{html}:
      IO::pure<Response>(reply(200, "text/html; charset=utf-8", html))
    case Fail{code, e}:
      IO::pure<Response>(reply(500, "text/plain", "index.html not found -- run the server from the repo root\n"))

def index() -> IO<Response>:
  do IO<Response>:
    h : Result<String> <- read_text("gabriel_demos/elements_web/index.html")
    index2(h)

def route_f(rest: List<String>) -> IO<Response>:
  match rest:
    case Cons{a, r1}:
      route_f2(pu32(a), r1)
    case Nil{}:
      IO::pure<Response>(not_found())

def route_f2(i: U32, r1: List<String>) -> IO<Response>:
  match r1:
    case Nil{}:
      IO::pure<Response>(frame_json(i, 0, 0, 0, 0))
    case Cons{e, r2}:
      route_f3(i, pu32(e), r2)

def route_f3(i: U32, e: U32, r2: List<String>) -> IO<Response>:
  match r2:
    case Cons{w, r3}:
      route_f4(i, e, pu32(w), r3)
    case Nil{}:
      IO::pure<Response>(not_found())

def route_f4(i: U32, e: U32, w: U32, r3: List<String>) -> IO<Response>:
  match r3:
    case Cons{f, r4}:
      route_f5(i, e, w, pu32(f), r4)
    case Nil{}:
      IO::pure<Response>(not_found())

def route_f5(i: U32, e: U32, w: U32, f: U32, r4: List<String>) -> IO<Response>:
  match r4:
    case Cons{a, r5}:
      IO::pure<Response>(frame_json(i, e, w, f, pu32(a)))
    case Nil{}:
      IO::pure<Response>(not_found())

def route_s(s1: String, rest: List<String>) -> IO<Response>:
  match String::eq(s1, "frame"):
    case 0:
      route_root(s1)
    case k:
      route_f(rest)

def route_root(s1: String) -> IO<Response>:
  match String::eq(s1, ""):
    case 0:
      IO::pure<Response>(not_found())
    case k:
      index()

def route_p(segs: List<String>) -> IO<Response>:
  match segs:
    case Cons{e0, r0}:
      route_p2(r0)
    case Nil{}:
      IO::pure<Response>(not_found())

def route_p2(r0: List<String>) -> IO<Response>:
  match r0:
    case Cons{s1, rest}:
      route_s(s1, rest)
    case Nil{}:
      index()

def route(rq: Request) -> IO<Response>:
  match rq:
    case Request{method, path, hs, bd}:
      route_p(String::split('/', path))

def routes() -> Router:
  Router{route, u => routes()}

def serve_conn(fd: U32, c: Result<U32>) -> IO<U32>:
  match c:
    case Done{cfd}:
      do IO<U32>:
        _ : U32 <- handle(Plain{cfd}, routes())
        serve_loop(fd)
    case Fail{code, e}:
      do IO<U32>:
        _ : U32 <- print(cat3("accept failed: ", e, "\n"))
        return 1

def serve_loop(fd: U32) -> IO<U32>:
  do IO<U32>:
    c : Result<U32> <- TCP::accept(fd)
    serve_conn(fd, c)

def main2(r: Result<U32>) -> IO<U32>:
  match r:
    case Done{fd}:
      do IO<U32>:
        _ : U32 <- print("elements listening on all interfaces (0.0.0.0:8081)\nopen http://<server-lan-ip>:8081  (ctrl-c to stop)\n")
        serve_loop(fd)
    case Fail{code, e}:
      do IO<U32>:
        _ : U32 <- print(cat3("listen failed: ", e, "\n"))
        return 1

def main() -> IO<U32>:
  do IO<U32>:
    r : Result<U32> <- TCP::listen(8081)
    main2(r)
