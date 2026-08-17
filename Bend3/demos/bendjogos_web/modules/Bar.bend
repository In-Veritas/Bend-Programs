# Generated hub-private namespace from ../bar_bench_web/web_bar.bend.
# Regenerate after changing the standalone source.

# web_bar: the bar-bending bench as a webapp.
#
# Bend3 has no browser compile target -- a Bend webapp is a Bend HTTP
# server (base/HTTP: Router + keep-alive handle over the TCP effect).
# This server computes every animation frame -- the same physics as
# bar_bench (Euler-Bernoulli cantilever, real material data, modal
# release, brittle snap) -- and serves it as draw commands; the browser
# page (index.html, also served from here) is a dumb canvas rasterizer,
# the web twin of effs/window.c. Buttons are real HTML buttons.
#
# routes:
#   GET /                     the page (read from disk, so run from the repo root)
#   GET /frame/<mat>/<i>      frame i of material mat (1 steel, 2 rubber,
#                             3 carbon) as {"done":d,"st":"...","cmds":[...]}
#                             -- stateless: any frame computable from (mat, i)
#
# build:  bun bend-ts/src/bend.ts gabriel_demos/bar_bench_web/web_bar.bend --no-halt -o gabriel_demos/bar_bench_web/web_bar
# run:    ./gabriel_demos/bar_bench_web/web_bar     (from the repo root)
# open:   http://<server-lan-ip>:8080
#
# no-halt
# skip-native

import ../../../bend-base/Base
import ../../Compat
import ../../../bend-base/IO/TCP
import ../../../bend-base/IO/HTTP

# ---------------------------------------------------------------- math

def Bar.fmin(a: F32, b: F32) -> F32:
  match b < a:
    case 0:
      a
    case k:
      b

def Bar.clamp0(x: F32) -> F32:
  match x < 0.0:
    case 0:
      x
    case k:
      0.0

def Bar.fabs(x: F32) -> F32:
  match x < 0.0:
    case 0:
      x
    case k:
      0.0 - x

def Bar.fsqrt_go(n: U32, a: F32, x: F32) -> F32:
  match n:
    case 0:
      x
    case m:
      Bar.fsqrt_go(m - 1, a, (x + (a / x)) * 0.5)

def Bar.fsqrt(a: F32) -> F32:
  match a > 0.0:
    case 0:
      0.0
    case k:
      Bar.fsqrt_go(28, a, (a * 0.5) + 1.0)

def Bar.umin(a: U32, b: U32) -> U32:
  match b < a:
    case 0:
      a
    case k:
      b

# ---------------------------------------------------------------- materials
# (data and derivations: see ../bar_bench/README.md)

type Bar.Mat:
  Steel{}
  Rubber{}
  Cfrp{}

type Bar.PV:
  PV{q: F32, v: F32}

def Bar.mat_id(m: Bar.Mat) -> U32:
  match m:
    case Bar.Mat.Steel{}:
      1
    case Bar.Mat.Rubber{}:
      2
    case Bar.Mat.Cfrp{}:
      3

def Bar.mat_of(sel: U32) -> Bar.Mat:
  match sel == 2:
    case 0:
      match sel == 3:
        case 0:
          Bar.Mat.Steel{}
        case k:
          Bar.Mat.Cfrp{}
    case j:
      Bar.Mat.Rubber{}

def Bar.m_e(m: Bar.Mat) -> F32:
  match m:
    case Bar.Mat.Steel{}:
      200.0e9
    case Bar.Mat.Rubber{}:
      0.05e9
    case Bar.Mat.Cfrp{}:
      135.0e9

def Bar.m_rho(m: Bar.Mat) -> F32:
  match m:
    case Bar.Mat.Steel{}:
      7850.0
    case Bar.Mat.Rubber{}:
      1100.0
    case Bar.Mat.Cfrp{}:
      1600.0

def Bar.m_zeta(m: Bar.Mat) -> F32:
  match m:
    case Bar.Mat.Steel{}:
      0.002
    case Bar.Mat.Rubber{}:
      0.15
    case Bar.Mat.Cfrp{}:
      0.005

def Bar.m_omega(m: Bar.Mat) -> F32:
  Bar.fsqrt((Bar.m_e(m) * 2.6667e-8) / (Bar.m_rho(m) * 8.0e-4)) * 3.5160

def Bar.m_slow(m: Bar.Mat) -> U32:
  match m:
    case Bar.Mat.Steel{}:
      32
    case Bar.Mat.Rubber{}:
      1
    case Bar.Mat.Cfrp{}:
      64

def Bar.m_rgb(m: Bar.Mat) -> U32:
  match m:
    case Bar.Mat.Steel{}:
      13160668
    case Bar.Mat.Rubber{}:
      15249448
    case Bar.Mat.Cfrp{}:
      4738136

def Bar.m_rest(m: Bar.Mat) -> F32:
  match m:
    case Bar.Mat.Steel{}:
      0.2375
    case Bar.Mat.Rubber{}:
      0.0
    case Bar.Mat.Cfrp{}:
      0.0

def Bar.m_ringn(m: Bar.Mat) -> U32:
  match m:
    case Bar.Mat.Steel{}:
      200
    case Bar.Mat.Rubber{}:
      240
    case Bar.Mat.Cfrp{}:
      200

def Bar.sstep(pv: Bar.PV, rest: F32, w: F32, z: F32, h: F32) -> Bar.PV:
  match pv:
    case Bar.PV.PV{q, v}:
      a = (0.0 - ((w * w) * (q - rest))) - (((2.0 * z) * w) * v)
      v2 = v + (h * a)
      Bar.PV.PV{q + (h * v2), v2}

def Bar.ssteps(k: U32, pv: Bar.PV, rest: F32, w: F32, z: F32, h: F32) -> Bar.PV:
  match k:
    case 0:
      pv
    case j:
      Bar.ssteps(j - 1, Bar.sstep(pv, rest, w, z, h), rest, w, z, h)

# crosshead deflection at frame i (0..45), smoothstep to 0.30 m
def Bar.pd(i: U32) -> F32:
  u = U32.to_f32(Bar.umin(i, 45)) / 45.0
  0.30 * ((3.0 - (2.0 * u)) * (u * u))

# ---------------------------------------------------------------- draw commands
# same stream as effs/window.c: 0 clear, 1 rect (y biased +1000)

def Bar.cmd_clear(rgb: U32, t: List(U32)) -> List(U32):
  List.Cons{0, List.Cons{rgb, t}}

def Bar.cmd_rect(x: U32, yb: U32, w: U32, h: U32, rgb: U32, t: List(U32)) -> List(U32):
  List.Cons{1, List.Cons{x, List.Cons{yb, List.Cons{w, List.Cons{h, List.Cons{rgb, t}}}}}}

def Bar.ypx(j: U32, d: F32, rx: F32, fl: F32) -> U32:
  xi = U32.to_f32(j) / 59.0
  y = (((d * rx) * ((3.0 * (xi * xi)) - ((xi * xi) * xi))) / 2.0) + fl
  F32.to_u32(Bar.clamp0((117.0 + (y * 280.0)) + 1000.5))

def Bar.bar_cmds(j: U32, rgb: U32, d: F32, rx: F32, fl: F32, t: List(U32)) -> List(U32):
  match j:
    case 0:
      t
    case k:
      Bar.bar_cmds(k - 1, rgb, d, rx, fl, Bar.cmd_rect(48 + ((k - 1) * 9), Bar.ypx(k - 1, d, rx, fl), 9, 6, rgb, t))

def Bar.arrow_cmds(ar: U32, d: F32, t: List(U32)) -> List(U32):
  match ar:
    case 0:
      t
    case k:
      tip = Bar.ypx(59, d, 1.0, 0.0)
      Bar.cmd_rect(577, tip - 42, 13, 8, 14696512, Bar.cmd_rect(580, tip - 36, 7, 28, 14696512, t))

def Bar.brk_cmds(brk: U32, t: List(U32)) -> List(U32):
  match brk:
    case 0:
      t
    case k:
      Bar.cmd_rect(44, 1108, 10, 18, 14696512, t)

def Bar.flash_rgb(m: Bar.Mat, flash: U32) -> U32:
  match flash:
    case 0:
      Bar.m_rgb(m)
    case k:
      14696512

def Bar.draw(m: Bar.Mat, d: F32, rx: F32, fl: F32, ar: U32, brk: U32, flash: U32) -> List(U32):
  rgb = Bar.flash_rgb(m, flash)
  Bar.cmd_clear(921622,
    Bar.cmd_rect(36, 1040, 8, 320, 6317680,
      Bar.bar_cmds(60, rgb, d, rx, fl,
        Bar.arrow_cmds(ar, d,
          Bar.brk_cmds(brk, List.Nil{})))))

# ---------------------------------------------------------------- frames
# frame_at(mat, i): the whole animation as a pure function of (mat, i)

type Bar.FO:
  FO{cmds: List(U32), st: String, done: U32}

def Bar.push_st(m: Bar.Mat, d: F32) -> String:
  match (Bar.mat_id(m) == 1) && (d > 0.0417):
    case 0:
      "PUSHING -- crosshead drives the tip down"
    case k:
      "YIELDING -- plastic flow past sy = 250 MPa"

def Bar.fo_push(m: Bar.Mat, i: U32) -> Bar.FO:
  d = Bar.pd(i)
  Bar.FO.FO{Bar.draw(m, d, 1.0, 0.0, 1, 0, 0), Bar.push_st(m, d), 0}

def Bar.ring_replay(k: U32, pv: Bar.PV, rest: F32, w: F32, z: F32, h: F32) -> Bar.PV:
  match k:
    case 0:
      pv
    case j:
      Bar.ring_replay(j - 1, Bar.ssteps(4, pv, rest, w, z, h), rest, w, z, h)

def Bar.rel_st(m: Bar.Mat) -> String:
  match m:
    case Bar.Mat.Steel{}:
      "RELEASED -- springback + permanent set, ringing at 16.3 Hz (slow-mo 1/32)"
    case Bar.Mat.Rubber{}:
      "RELEASED -- full recovery, wobbling at 0.7 Hz (real time)"
    case Bar.Mat.Cfrp{}:
      "RELEASED -- ringing (slow-mo 1/64)"

def Bar.fo_ring(m: Bar.Mat, k: U32) -> Bar.FO:
  nr = Bar.m_ringn(m)
  kk = Bar.umin(k, nr)
  h = (0.033 / U32.to_f32(Bar.m_slow(m))) / 4.0
  pv = Bar.ring_replay(kk, Bar.PV.PV{0.30, 0.0}, Bar.m_rest(m), Bar.m_omega(m), Bar.m_zeta(m), h)
  Bar.fo_ring2(m, pv, k >= nr)

def Bar.done_st(done: U32, active: String) -> String:
  match done:
    case 0:
      active
    case k:
      "DONE -- fresh specimen on the next Bend!"

def Bar.fo_ring2(m: Bar.Mat, pv: Bar.PV, done: U32) -> Bar.FO:
  match pv:
    case Bar.PV.PV{q, v}:
      Bar.FO.FO{Bar.draw(m, q, 1.0, 0.0, 0, 0, 0), Bar.done_st(done, Bar.rel_st(m)), done}

def Bar.frame_sr(m: Bar.Mat, i: U32) -> Bar.FO:
  match i < 46:
    case 0:
      Bar.fo_ring(m, i - 46)
    case k:
      Bar.fo_push(m, i)

# carbon: first frame index whose imposed deflection exceeds the
# fracture deflection (root strain 0.8% -> delta = 0.2667 m)
def Bar.isnap_go(i: U32) -> U32:
  match i == 46:
    case 0:
      match Bar.pd(i) > 0.26666:
        case 0:
          Bar.isnap_go(i + 1)
        case k:
          i
    case j:
      46

def Bar.fall_replay(j: U32, pv: Bar.PV) -> Bar.PV:
  match j:
    case 0:
      pv
    case k:
      Bar.fall_replay(k - 1, Bar.fall_step(pv))

def Bar.fall_step(pv: Bar.PV) -> Bar.PV:
  match pv:
    case Bar.PV.PV{fl, v}:
      v2 = v + (9.81 * 0.00825)
      Bar.PV.PV{fl + (v2 * 0.00825), v2}

def Bar.fo_fall(m: Bar.Mat, j: U32) -> Bar.FO:
  jj = Bar.umin(j, 50)
  t = U32.to_f32(jj) * 0.00825
  rx = Bar.clamp0(1.0 - (t / 0.15))
  pv = Bar.fall_replay(jj, Bar.PV.PV{0.0, 0.0})
  Bar.fo_fall2(m, pv, rx, j > 50)

def Bar.fo_fall2(m: Bar.Mat, pv: Bar.PV, rx: F32, done: U32) -> Bar.FO:
  match pv:
    case Bar.PV.PV{fl, v}:
      Bar.FO.FO{Bar.draw(m, 0.2667, rx, fl, 0, 1, 0), Bar.done_st(done, "SNAPPED at the root -- no yield, no warning (slow-mo 1/4)"), done}

def Bar.frame_c2(m: Bar.Mat, i: U32, isnap: U32) -> Bar.FO:
  match i < (isnap + 4):
    case 0:
      Bar.fo_fall(m, i - (isnap + 4))
    case k:
      Bar.FO.FO{Bar.draw(m, Bar.pd(isnap), 1.0, 0.0, 0, 1, i % 2), "SNAP! sigma_root ~ 1.08 GPa at eps ~ 0.8%", 0}

def Bar.frame_c(m: Bar.Mat, i: U32) -> Bar.FO:
  isnap = Bar.isnap_go(0)
  match i < isnap:
    case 0:
      Bar.frame_c2(m, i, isnap)
    case k:
      Bar.fo_push(m, i)

def Bar.frame_at(m: Bar.Mat, i: U32) -> Bar.FO:
  match Bar.mat_id(m) == 3:
    case 0:
      Bar.frame_sr(m, i)
    case k:
      Bar.frame_c(m, i)

# ---------------------------------------------------------------- json

def Bar.u32s_go(n: U32, k: String) -> String:
  match n:
    case 0:
      k
    case m:
      Bar.u32s_go(m / 10, List.Cons{Char.Char{48 + (m % 10)}, k})

def Bar.u32s(n: U32) -> String:
  match n:
    case 0:
      "0"
    case m:
      Bar.u32s_go(m, "")

def Bar.cat(a: String, b: String) -> String:
  List.concat(Char, a, b)

def Bar.cat3(a: String, b: String, c: String) -> String:
  Bar.cat(a, Bar.cat(b, c))

def Bar.jnums(bs: List(U32)) -> String:
  match bs:
    case List.Nil{}:
      "]"
    case List.Cons{h, t}:
      Bar.cat3(",", Bar.u32s(h), Bar.jnums(t))

def Bar.jarr(bs: List(U32)) -> String:
  match bs:
    case List.Nil{}:
      "[]"
    case List.Cons{h, t}:
      Bar.cat3("[", Bar.u32s(h), Bar.jnums(t))

def Bar.jfo(fo: Bar.FO) -> String:
  match fo:
    case Bar.FO.FO{cmds, st, done}:
      Bar.cat3(Bar.cat3("{\"done\":", Bar.u32s(done), ",\"st\":\""),
           Bar.cat3(st, "\",\"cmds\":", Bar.jarr(cmds)),
           "}")

# ---------------------------------------------------------------- http

def Bar.pu32_go(s: String, acc: U32) -> U32:
  match s:
    case List.Nil{}:
      acc
    case List.Cons{c, t}:
      Bar.pu32_c(c, t, acc)

def Bar.pu32_c(c: Char, t: String, acc: U32) -> U32:
  match c:
    case Char.Char{n}:
      Bar.pu32_go(t, (acc * 10) + ((n - 48) % 10))

def Bar.pu32(s: String) -> U32:
  Bar.pu32_go(s, 0)

def Bar.frame_json(mat: U32, i: U32) -> HTTP.Response:
  HTTP.reply(200, "application/json", Bar.jfo(Bar.frame_at(Bar.mat_of(mat), i)))

def Bar.index2(h: Result((U32 & String), String)) -> IO(HTTP.Response):
  match h:
    case Result.Done{html}:
      IO.pure(HTTP.Response, HTTP.reply(200, "text/html; charset=utf-8", html))
    case Result.Fail{(code, e)}:
      IO.pure(HTTP.Response, HTTP.reply(500, "text/plain", "index.html not found -- run the server from the repo root\n"))

def Bar.index() -> IO(HTTP.Response):
  do IO(HTTP.Response):
    h <- IO.read_text("gabriel_demos/bar_bench_web/index.html")
    Bar.index2(h)

def Bar.route_f(rest: List(String)) -> IO(HTTP.Response):
  match rest:
    case List.Cons{a, r1}:
      Bar.route_f2(a, r1)
    case List.Nil{}:
      IO.pure(HTTP.Response, HTTP.not_found())

def Bar.route_f2(a: String, r1: List(String)) -> IO(HTTP.Response):
  match r1:
    case List.Cons{b, r2}:
      IO.pure(HTTP.Response, Bar.frame_json(Bar.pu32(a), Bar.pu32(b)))
    case List.Nil{}:
      IO.pure(HTTP.Response, HTTP.not_found())

def Bar.route_s(s1: String, rest: List(String)) -> IO(HTTP.Response):
  match String.eq_u32(s1, "frame"):
    case 0:
      Bar.route_root(s1)
    case k:
      Bar.route_f(rest)

def Bar.route_root(s1: String) -> IO(HTTP.Response):
  match String.eq_u32(s1, ""):
    case 0:
      IO.pure(HTTP.Response, HTTP.not_found())
    case k:
      Bar.index()

def Bar.route_p(segs: List(String)) -> IO(HTTP.Response):
  match segs:
    case List.Cons{e0, r0}:
      Bar.route_p2(r0)
    case List.Nil{}:
      IO.pure(HTTP.Response, HTTP.not_found())

def Bar.route_p2(r0: List(String)) -> IO(HTTP.Response):
  match r0:
    case List.Cons{s1, rest}:
      Bar.route_s(s1, rest)
    case List.Nil{}:
      Bar.index()

def Bar.route(rq: HTTP.Request) -> IO(HTTP.Response):
  match rq:
    case HTTP.Request.Request{method, path, hs, bd}:
      Bar.route_p(String.split('/', path))

def Bar.routes() -> HTTP.Router:
  HTTP.Router.Router{Bar.route, u => Bar.routes()}

def Bar.serve_conn(fd: TCP, c: Result((U32 & String), TCP)) -> IO(U32):
  match c:
    case Result.Done{cfd}:
      do IO(U32):
        _ <- HTTP.handle(HTTP.Plain{cfd}, Bar.routes())
        Bar.serve_loop(fd)
    case Result.Fail{(code, e)}:
      do IO(U32):
        _ <- IO.write(Bar.cat3("accept failed: ", e, "\n"))
        return 1

def Bar.serve_loop(fd: TCP) -> IO(U32):
  do IO(U32):
    c <- TCP.accept(fd)
    Bar.serve_conn(fd, c)

def Bar.main2(r: Result((U32 & String), TCP)) -> IO(U32):
  match r:
    case Result.Done{fd}:
      do IO(U32):
        _ <- IO.write("bar bench listening on all interfaces (0.0.0.0:8080)\nopen http://<server-lan-ip>:8080  (ctrl-c to stop)\n")
        Bar.serve_loop(fd)
    case Result.Fail{(code, e)}:
      do IO(U32):
        _ <- IO.write(Bar.cat3("listen failed: ", e, "\n"))
        return 1

def Bar.main() -> IO(U32):
  do IO(U32):
    r <- TCP.listen(8080)
    Bar.main2(r)
