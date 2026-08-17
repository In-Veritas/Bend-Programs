# Generated hub-private namespace from ../elements_web/web_elements.bend.
# Regenerate after changing the standalone source.

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
# build:  bun bend-ts/src/bend.ts gabriel_demos/elements_web/web_elements.bend --no-halt -o gabriel_demos/elements_web/web_elements
# run:    ./gabriel_demos/elements_web/web_elements   (from the repo root)
# open:   http://<server-lan-ip>:8081
#
# no-halt
# skip-native

import ../../../bend-base/Base
import ../../Compat
import ../../../bend-base/IO/TCP
import ../../../bend-base/IO/HTTP

def Elements.clamp0(x: F32) -> F32:
  match x < 0.0:
    case 0:
      x
    case k:
      0.0

# sine for any |x| < ~6400: floor-based range reduction mod 2pi (the
# +1024 shift makes truncation act as floor), Bhaskara I on each half
def Elements.fsin_h(t: F32) -> F32:
  p = t * (3.14159265 - t)
  (16.0 * p) / (49.3480220 - (4.0 * p))

def Elements.fsin(x: F32) -> F32:
  q = U32.to_f32(F32.to_u32((x / 6.28318531) + 1024.0)) - 1024.0
  r = x - (q * 6.28318531)
  match r > 3.14159265:
    case 0:
      Elements.fsin_h(r)
    case k:
      0.0 - Elements.fsin_h(r - 3.14159265)

def Elements.fcos(x: F32) -> F32:
  Elements.fsin(x + 1.57079633)

def Elements.f32_abs(x: F32) -> F32:
  match x < 0.0:
    case 0:
      x
    case k:
      0.0 - x

def Elements.f32_cap(x: F32, top: F32) -> F32:
  match x > top:
    case 0:
      x
    case k:
      top

def Elements.f32_falloff(delta: F32, radius: F32) -> F32:
  radius / (radius + Elements.f32_abs(delta))

def Elements.u32_cap(x: U32, top: U32) -> U32:
  match x > top:
    case 0:
      x
    case k:
      top

# A reaction packs a six-bit countdown and the 300x152 local click point:
#   time + x*64 + y*(64*300)
def Elements.u32_reaction_make(time: U32, x: U32, y: U32) -> U32:
  (Elements.u32_cap(time, 63) + ((x % 300) * 64)) + ((y % 152) * 19200)

def Elements.u32_reaction_time(x: U32) -> U32:
  x % 64

def Elements.u32_reaction_x(x: U32) -> U32:
  (x / 64) % 300

def Elements.u32_reaction_y(x: U32) -> U32:
  (x / 19200) % 152

def Elements.u32_reaction_limit(x: U32, top: U32) -> U32:
  Elements.u32_reaction_make(Elements.u32_cap(Elements.u32_reaction_time(x), top), Elements.u32_reaction_x(x), Elements.u32_reaction_y(x))

def Elements.u32_reaction_amp(x: U32, top: U32) -> F32:
  U32.to_f32(Elements.u32_cap(Elements.u32_reaction_time(x), top)) / U32.to_f32(top)

def Elements.u32_reaction_age(x: U32, top: U32) -> F32:
  match Elements.u32_reaction_time(x):
    case 0:
      0.0
    case k:
      U32.to_f32(top - Elements.u32_cap(k, top))

def Elements.u32_active_rgb(x: U32, idle: U32, active: U32) -> U32:
  match Elements.u32_reaction_time(x):
    case 0:
      idle
    case k:
      active

# ---------------------------------------------------------------- draw commands

def Elements.cmd_clear(rgb: U32, t: List(U32)) -> List(U32):
  List.Cons{0, List.Cons{rgb, t}}

def Elements.cmd_rect(x: U32, yb: U32, w: U32, h: U32, rgb: U32, t: List(U32)) -> List(U32):
  List.Cons{1, List.Cons{x, List.Cons{yb, List.Cons{w, List.Cons{h, List.Cons{rgb, t}}}}}}

def Elements.cmd_glyph(x: U32, yb: U32, s: U32, g: U32, rgb: U32, t: List(U32)) -> List(U32):
  List.Cons{2, List.Cons{x, List.Cons{yb, List.Cons{s, List.Cons{g, List.Cons{rgb, t}}}}}}

# a rect placed inside a panel: px,py panel origin, fx,fy F32 local coords
def Elements.prect(px: U32, py: U32, fx: F32, fy: F32, w: U32, h: U32, rgb: U32, t: List(U32)) -> List(U32):
  Elements.cmd_rect(px + F32.to_u32(Elements.clamp0(fx) + 0.5), (1000 + py) + F32.to_u32(Elements.clamp0(fy) + 0.5), w, h, rgb, t)

# ---------------------------------------------------------------- earth (12,76)
# a click strikes a local epicenter: the ground pulse decays with distance,
# and each boulder is launched up and away from the point of impact

def Elements.earth_pillars(k: U32, t: F32, hit: U32, acc: List(U32)) -> List(U32):
  match k:
    case 0:
      acc
    case n:
      p = U32.to_f32(n - 1)
      x = 10.0 + (p * 28.0)
      amp = Elements.u32_reaction_amp(hit, 48)
      age = Elements.u32_reaction_age(hit, 48)
      cx = U32.to_f32(Elements.u32_reaction_x(hit))
      power = 0.55 + (U32.to_f32(Elements.u32_reaction_y(hit)) / 160.0)
      near = Elements.f32_falloff(x - cx, 44.0)
      base = 26.0 + (18.0 * Elements.fsin((p * 0.9) - (t * 2.1)))
      pulse = (((24.0 * amp) * power) * near) * Elements.fcos((Elements.f32_abs(x - cx) * 0.065) - (age * 0.34))
      ph = Elements.clamp0(base + pulse)
      y = (138.0 - ph)
      hh = F32.to_u32(ph + 0.5)
      Elements.earth_pillars(n - 1, t, hit,
        Elements.prect(12, 76, x, y, 24, hh, 9073493,
          Elements.prect(12, 76, x, y, 24, 4, 7035458, acc)))

def Elements.earth_rocks(k: U32, hit: U32, acc: List(U32)) -> List(U32):
  match k:
    case 0:
      acc
    case n:
      j = n - 1
      i = U32.to_f32(j)
      phase = Elements.u32_reaction_age(hit, 48) / 48.0
      launch = (4.0 * phase) * (1.0 - phase)
      base = 20.0 + (i * 120.0)
      cx = U32.to_f32(Elements.u32_reaction_x(hit))
      delta = (base + 10.0) - cx
      near = Elements.f32_falloff(delta, 92.0)
      away = delta / (18.0 + Elements.f32_abs(delta))
      power = 0.55 + (U32.to_f32(Elements.u32_reaction_y(hit)) / 160.0)
      x = base + ((((96.0 * power) * near) * away) * launch)
      y = 124.0 - (((52.0 + ((68.0 * power) * near)) * launch))
      Elements.earth_rocks(n - 1, hit,
        Elements.prect(12, 76, x, y, 20, 14, 10125410,
          Elements.prect(12, 76, x + 4.0, y - 4.0, 12, 5, 9073493, acc)))

def Elements.earth(t: F32, hit: U32, acc: List(U32)) -> List(U32):
  Elements.cmd_rect(12, 1214, 300, 14, 4864810,
    Elements.earth_pillars(10, t, hit, Elements.earth_rocks(3, hit, acc)))

# ---------------------------------------------------------------- water (328,76)
# the click is a pull point: it raises a local traveling ripple and draws
# the lifted ribbon toward that part of the pool

def Elements.water_cols(k: U32, t: F32, hit: U32, acc: List(U32)) -> List(U32):
  match k:
    case 0:
      acc
    case n:
      c = U32.to_f32(n - 1)
      x = c * 12.0
      amp = Elements.u32_reaction_amp(hit, 60)
      age = Elements.u32_reaction_age(hit, 60)
      cx = U32.to_f32(Elements.u32_reaction_x(hit))
      lift = 0.45 + ((151.0 - U32.to_f32(Elements.u32_reaction_y(hit))) / 170.0)
      near = Elements.f32_falloff(x - cx, 38.0 + age)
      base = (70.0 + (12.0 * Elements.fsin((c * 0.55) - (t * 2.2)))) + (5.0 * Elements.fsin((c * 1.3) + (t * 3.1)))
      pull = ((((28.0 * amp) * lift) * near) * Elements.fcos((Elements.f32_abs(x - cx) * 0.075) - (age * 0.31)))
      ys = base - pull
      hh = F32.to_u32(Elements.clamp0(152.0 - ys) + 0.5)
      Elements.water_cols(n - 1, t, hit,
        Elements.prect(328, 76, x, ys, 12, hh, 2977500,
          Elements.prect(328, 76, x, ys - 3.0, 12, 4, 8370416, acc)))

def Elements.water_whirl(k: U32, t: F32, hit: U32, acc: List(U32)) -> List(U32):
  match k:
    case 0:
      acc
    case n:
      i = U32.to_f32(n - 1)
      amp = Elements.u32_reaction_amp(hit, 60)
      cx = U32.to_f32(Elements.u32_reaction_x(hit))
      cy = U32.to_f32(Elements.u32_reaction_y(hit))
      lift = 0.45 + ((151.0 - cy) / 170.0)
      pull = amp * 0.72
      a = (((t * 1.8) + (i * 0.5)) + (Elements.u32_reaction_age(hit, 60) * 0.24)) + ((cx / 300.0) * amp)
      mx = 144.0 + (((cx - 144.0) * pull))
      my = 32.0 + (((cy - 32.0) * pull) * 0.48)
      x = mx + ((26.0 + ((24.0 * amp) * lift)) * Elements.fcos(a))
      y = my + ((18.0 + ((12.0 * amp) * lift)) * Elements.fsin(a))
      Elements.water_whirl(n - 1, t, hit,
        Elements.prect(328, 76, x, y, 9, 7, 5232869, acc))

def Elements.water(t: F32, hit: U32, acc: List(U32)) -> List(U32):
  Elements.water_cols(25, t, hit, Elements.water_whirl(6, t, hit, acc))

# ---------------------------------------------------------------- fire (12,240)
# a click feeds heat into a local point: nearby columns flare most, while
# sparks are pulled toward the hotspot before rising from it

def Elements.fire_cols(k: U32, t: F32, hit: U32, acc: List(U32)) -> List(U32):
  match k:
    case 0:
      acc
    case n:
      c = U32.to_f32(n - 1)
      x = 7.0 + (c * 13.0)
      s1 = 0.5 + (0.5 * Elements.fsin((c * 1.9) + (t * 5.3)))
      s2 = 0.6 + (0.4 * Elements.fsin((c * 0.8) - (t * 3.1)))
      amp = Elements.u32_reaction_amp(hit, 45)
      cx = U32.to_f32(Elements.u32_reaction_x(hit))
      heat = 0.55 + (U32.to_f32(Elements.u32_reaction_y(hit)) / 160.0)
      near = Elements.f32_falloff(x - cx, 34.0)
      ho = Elements.f32_cap((20.0 + (60.0 * (s1 * s2))) + (((72.0 * amp) * heat) * near), 145.0)
      hm = ho * 0.62
      hc = ho * 0.30
      Elements.fire_cols(n - 1, t, hit,
        Elements.prect(12, 240, x, 148.0 - ho, 13, F32.to_u32(ho + 0.5), 13646360,
          Elements.prect(12, 240, x + 2.0, 148.0 - hm, 9, F32.to_u32(hm + 0.5), 15759384,
            Elements.prect(12, 240, x + 4.0, 148.0 - hc, 5, F32.to_u32(hc + 0.5), 16308296, acc))))

def Elements.fire_sparks(k: U32, t: F32, hit: U32, acc: List(U32)) -> List(U32):
  match k:
    case 0:
      acc
    case n:
      i = U32.to_f32(n - 1)
      amp = Elements.u32_reaction_amp(hit, 45)
      cx = U32.to_f32(Elements.u32_reaction_x(hit))
      heat = 0.55 + (U32.to_f32(Elements.u32_reaction_y(hit)) / 160.0)
      base = 34.0 + (i * 72.0)
      near = Elements.f32_falloff(base - cx, 70.0)
      v = ((t * 55.0) + (i * 40.0)) + (((Elements.u32_reaction_age(hit, 45) * 9.0) * heat) * near)
      m = v - (U32.to_f32(F32.to_u32(v / 130.0)) * 130.0)
      x = (base + ((((cx - base) * amp) * near) * 0.62)) + (6.0 * Elements.fsin((t * 3.0) + i))
      Elements.fire_sparks(n - 1, t, hit,
        Elements.prect(12, 240, x, 140.0 - m, 4, 4, 16308296, acc))

def Elements.fire(t: F32, hit: U32, acc: List(U32)) -> List(U32):
  Elements.fire_cols(22, t, hit, Elements.fire_sparks(4, t, hit, acc))

# ---------------------------------------------------------------- air (328,240)
# the click supplies a directional gust from the panel center: its angle
# moves the vortex, while its distance controls expansion and spin

def Elements.air_parts(k: U32, t: F32, hit: U32, acc: List(U32)) -> List(U32):
  match k:
    case 0:
      acc
    case n:
      arm = U32.to_f32((n - 1) / 10)
      j = U32.to_f32((n - 1) % 10)
      amp = Elements.u32_reaction_amp(hit, 60)
      dx = (U32.to_f32(Elements.u32_reaction_x(hit)) - 150.0) / 150.0
      dy = (U32.to_f32(Elements.u32_reaction_y(hit)) - 76.0) / 76.0
      force = 0.55 + ((Elements.f32_abs(dx) + Elements.f32_abs(dy)) * 0.38)
      age = Elements.u32_reaction_age(hit, 60)
      a = (((t * 2.2) + (arm * 2.0944)) + (j * 0.30)) + (age * (0.20 + (dx * 0.12)))
      r = (13.0 + (j * 6.3)) + ((32.0 * amp) * force)
      x = (144.0 + ((dx * 55.0) * amp)) + (r * Elements.fcos(a))
      y = (72.0 + ((dy * 38.0) * amp)) + (r * Elements.fsin(a))
      sz = (7 - (((n - 1) % 10) / 2)) + (Elements.u32_reaction_time(hit) / 30)
      Elements.air_parts(n - 1, t, hit,
        Elements.prect(328, 240, x, y, sz, sz, 13358056, acc))

def Elements.air(t: F32, hit: U32, acc: List(U32)) -> List(U32):
  Elements.air_parts(30, t, hit, acc)

# ---------------------------------------------------------------- scene

# glyphs: B=10 E=11 N=12 D=13 !=14, scale 8 -> 24x40 each
def Elements.title(acc: List(U32)) -> List(U32):
  Elements.cmd_glyph(240, 1014, 8, 10, 15790072,
    Elements.cmd_glyph(272, 1014, 8, 11, 15790072,
      Elements.cmd_glyph(304, 1014, 8, 12, 15790072,
        Elements.cmd_glyph(336, 1014, 8, 13, 15790072,
          Elements.cmd_glyph(368, 1014, 8, 14, 15790072, acc)))))

def Elements.panels(e: U32, w: U32, f: U32, a: U32, acc: List(U32)) -> List(U32):
  Elements.cmd_rect(12, 1076, 300, 152, Elements.u32_active_rgb(e, 1709839, 2634274),
    Elements.cmd_rect(328, 1076, 300, 152, Elements.u32_active_rgb(w, 923168, 1323088),
      Elements.cmd_rect(12, 1240, 300, 152, Elements.u32_active_rgb(f, 1708044, 2695198),
        Elements.cmd_rect(328, 1240, 300, 152, Elements.u32_active_rgb(a, 1316378, 2177379), acc))))

def Elements.scene(t: F32, e: U32, w: U32, f: U32, a: U32) -> List(U32):
  Elements.cmd_clear(921622,
    Elements.title(
      Elements.panels(e, w, f, a,
        Elements.earth(t, e, Elements.water(t, w, Elements.fire(t, f, Elements.air(t, a, List.Nil{})))))))

# ---------------------------------------------------------------- json

def Elements.u32s_go(n: U32, k: String) -> String:
  match n:
    case 0:
      k
    case m:
      Elements.u32s_go(m / 10, List.Cons{Char.Char{48 + (m % 10)}, k})

def Elements.u32s(n: U32) -> String:
  match n:
    case 0:
      "0"
    case m:
      Elements.u32s_go(m, "")

def Elements.cat(a: String, b: String) -> String:
  List.concat(Char, a, b)

def Elements.cat3(a: String, b: String, c: String) -> String:
  Elements.cat(a, Elements.cat(b, c))

def Elements.jnums(bs: List(U32)) -> String:
  match bs:
    case List.Nil{}:
      "]"
    case List.Cons{h, t}:
      Elements.cat3(",", Elements.u32s(h), Elements.jnums(t))

def Elements.jarr(bs: List(U32)) -> String:
  match bs:
    case List.Nil{}:
      "[]"
    case List.Cons{h, t}:
      Elements.cat3("[", Elements.u32s(h), Elements.jnums(t))

def Elements.cat3j(a: String, b: String, c: String) -> String:
  Elements.cat(a, Elements.cat(b, c))

# ---------------------------------------------------------------- http

def Elements.pu32_go(s: String, acc: U32) -> U32:
  match s:
    case List.Nil{}:
      acc
    case List.Cons{c, t}:
      Elements.pu32_c(c, t, acc)

def Elements.pu32_c(c: Char, t: String, acc: U32) -> U32:
  match c:
    case Char.Char{n}:
      Elements.pu32_go(t, (acc * 10) + ((n - 48) % 10))

def Elements.pu32(s: String) -> U32:
  Elements.pu32_go(s, 0)

def Elements.frame_json(i: U32, e: U32, w: U32, f: U32, a: U32) -> HTTP.Response:
  cmds = Elements.scene(U32.to_f32(i % 190400) * 0.033,
               Elements.u32_reaction_limit(e, 48), Elements.u32_reaction_limit(w, 60),
               Elements.u32_reaction_limit(f, 45), Elements.u32_reaction_limit(a, 60))
  HTTP.reply(200, "application/json", Elements.cat3("{\"cmds\":", Elements.jarr(cmds), "}"))

def Elements.index2(h: Result((U32 & String), String)) -> IO(HTTP.Response):
  match h:
    case Result.Done{html}:
      IO.pure(HTTP.Response, HTTP.reply(200, "text/html; charset=utf-8", html))
    case Result.Fail{(code, e)}:
      IO.pure(HTTP.Response, HTTP.reply(500, "text/plain", "index.html not found -- run the server from the repo root\n"))

def Elements.index() -> IO(HTTP.Response):
  do IO(HTTP.Response):
    h <- IO.read_text("gabriel_demos/elements_web/index.html")
    Elements.index2(h)

def Elements.route_f(rest: List(String)) -> IO(HTTP.Response):
  match rest:
    case List.Cons{a, r1}:
      Elements.route_f2(Elements.pu32(a), r1)
    case List.Nil{}:
      IO.pure(HTTP.Response, HTTP.not_found())

def Elements.route_f2(i: U32, r1: List(String)) -> IO(HTTP.Response):
  match r1:
    case List.Nil{}:
      IO.pure(HTTP.Response, Elements.frame_json(i, 0, 0, 0, 0))
    case List.Cons{e, r2}:
      Elements.route_f3(i, Elements.pu32(e), r2)

def Elements.route_f3(i: U32, e: U32, r2: List(String)) -> IO(HTTP.Response):
  match r2:
    case List.Cons{w, r3}:
      Elements.route_f4(i, e, Elements.pu32(w), r3)
    case List.Nil{}:
      IO.pure(HTTP.Response, HTTP.not_found())

def Elements.route_f4(i: U32, e: U32, w: U32, r3: List(String)) -> IO(HTTP.Response):
  match r3:
    case List.Cons{f, r4}:
      Elements.route_f5(i, e, w, Elements.pu32(f), r4)
    case List.Nil{}:
      IO.pure(HTTP.Response, HTTP.not_found())

def Elements.route_f5(i: U32, e: U32, w: U32, f: U32, r4: List(String)) -> IO(HTTP.Response):
  match r4:
    case List.Cons{a, r5}:
      IO.pure(HTTP.Response, Elements.frame_json(i, e, w, f, Elements.pu32(a)))
    case List.Nil{}:
      IO.pure(HTTP.Response, HTTP.not_found())

def Elements.route_s(s1: String, rest: List(String)) -> IO(HTTP.Response):
  match String.eq_u32(s1, "frame"):
    case 0:
      Elements.route_root(s1)
    case k:
      Elements.route_f(rest)

def Elements.route_root(s1: String) -> IO(HTTP.Response):
  match String.eq_u32(s1, ""):
    case 0:
      IO.pure(HTTP.Response, HTTP.not_found())
    case k:
      Elements.index()

def Elements.route_p(segs: List(String)) -> IO(HTTP.Response):
  match segs:
    case List.Cons{e0, r0}:
      Elements.route_p2(r0)
    case List.Nil{}:
      IO.pure(HTTP.Response, HTTP.not_found())

def Elements.route_p2(r0: List(String)) -> IO(HTTP.Response):
  match r0:
    case List.Cons{s1, rest}:
      Elements.route_s(s1, rest)
    case List.Nil{}:
      Elements.index()

def Elements.route(rq: HTTP.Request) -> IO(HTTP.Response):
  match rq:
    case HTTP.Request.Request{method, path, hs, bd}:
      Elements.route_p(String.split('/', path))

def Elements.routes() -> HTTP.Router:
  HTTP.Router.Router{Elements.route, u => Elements.routes()}

def Elements.serve_conn(fd: TCP, c: Result((U32 & String), TCP)) -> IO(U32):
  match c:
    case Result.Done{cfd}:
      do IO(U32):
        _ <- HTTP.handle(HTTP.Plain{cfd}, Elements.routes())
        Elements.serve_loop(fd)
    case Result.Fail{(code, e)}:
      do IO(U32):
        _ <- IO.write(Elements.cat3("accept failed: ", e, "\n"))
        return 1

def Elements.serve_loop(fd: TCP) -> IO(U32):
  do IO(U32):
    c <- TCP.accept(fd)
    Elements.serve_conn(fd, c)

def Elements.main2(r: Result((U32 & String), TCP)) -> IO(U32):
  match r:
    case Result.Done{fd}:
      do IO(U32):
        _ <- IO.write("elements listening on all interfaces (0.0.0.0:8081)\nopen http://<server-lan-ip>:8081  (ctrl-c to stop)\n")
        Elements.serve_loop(fd)
    case Result.Fail{(code, e)}:
      do IO(U32):
        _ <- IO.write(Elements.cat3("listen failed: ", e, "\n"))
        return 1

def Elements.main() -> IO(U32):
  do IO(U32):
    r <- TCP.listen(8081)
    Elements.main2(r)
