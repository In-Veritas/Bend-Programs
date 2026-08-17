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

import ../../bend-base/Base
import ../Compat
import ../../bend-base/IO/TCP
import ../../bend-base/IO/HTTP

# ---------------------------------------------------------------- math

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

def umin(a: U32, b: U32) -> U32:
  match b < a:
    case 0:
      a
    case k:
      b

# ---------------------------------------------------------------- materials
# (data and derivations: see ../bar_bench/README.md)

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

def m_rest(m: Mat) -> F32:
  match m:
    case Mat.Steel{}:
      0.2375
    case Mat.Rubber{}:
      0.0
    case Mat.Cfrp{}:
      0.0

def m_ringn(m: Mat) -> U32:
  match m:
    case Mat.Steel{}:
      200
    case Mat.Rubber{}:
      240
    case Mat.Cfrp{}:
      200

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

# crosshead deflection at frame i (0..45), smoothstep to 0.30 m
def pd(i: U32) -> F32:
  u = U32.to_f32(umin(i, 45)) / 45.0
  0.30 * ((3.0 - (2.0 * u)) * (u * u))

# ---------------------------------------------------------------- draw commands
# same stream as effs/window.c: 0 clear, 1 rect (y biased +1000)

def cmd_clear(rgb: U32, t: List(U32)) -> List(U32):
  List.Cons{0, List.Cons{rgb, t}}

def cmd_rect(x: U32, yb: U32, w: U32, h: U32, rgb: U32, t: List(U32)) -> List(U32):
  List.Cons{1, List.Cons{x, List.Cons{yb, List.Cons{w, List.Cons{h, List.Cons{rgb, t}}}}}}

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

def draw(m: Mat, d: F32, rx: F32, fl: F32, ar: U32, brk: U32, flash: U32) -> List(U32):
  rgb = flash_rgb(m, flash)
  cmd_clear(921622,
    cmd_rect(36, 1040, 8, 320, 6317680,
      bar_cmds(60, rgb, d, rx, fl,
        arrow_cmds(ar, d,
          brk_cmds(brk, List.Nil{})))))

# ---------------------------------------------------------------- frames
# frame_at(mat, i): the whole animation as a pure function of (mat, i)

type FO:
  FO{cmds: List(U32), st: String, done: U32}

def push_st(m: Mat, d: F32) -> String:
  match (mat_id(m) == 1) && (d > 0.0417):
    case 0:
      "PUSHING -- crosshead drives the tip down"
    case k:
      "YIELDING -- plastic flow past sy = 250 MPa"

def fo_push(m: Mat, i: U32) -> FO:
  d = pd(i)
  FO.FO{draw(m, d, 1.0, 0.0, 1, 0, 0), push_st(m, d), 0}

def ring_replay(k: U32, pv: PV, rest: F32, w: F32, z: F32, h: F32) -> PV:
  match k:
    case 0:
      pv
    case j:
      ring_replay(j - 1, ssteps(4, pv, rest, w, z, h), rest, w, z, h)

def rel_st(m: Mat) -> String:
  match m:
    case Mat.Steel{}:
      "RELEASED -- springback + permanent set, ringing at 16.3 Hz (slow-mo 1/32)"
    case Mat.Rubber{}:
      "RELEASED -- full recovery, wobbling at 0.7 Hz (real time)"
    case Mat.Cfrp{}:
      "RELEASED -- ringing (slow-mo 1/64)"

def fo_ring(m: Mat, k: U32) -> FO:
  nr = m_ringn(m)
  kk = umin(k, nr)
  h = (0.033 / U32.to_f32(m_slow(m))) / 4.0
  pv = ring_replay(kk, PV.PV{0.30, 0.0}, m_rest(m), m_omega(m), m_zeta(m), h)
  fo_ring2(m, pv, k >= nr)

def done_st(done: U32, active: String) -> String:
  match done:
    case 0:
      active
    case k:
      "DONE -- fresh specimen on the next Bend!"

def fo_ring2(m: Mat, pv: PV, done: U32) -> FO:
  match pv:
    case PV.PV{q, v}:
      FO.FO{draw(m, q, 1.0, 0.0, 0, 0, 0), done_st(done, rel_st(m)), done}

def frame_sr(m: Mat, i: U32) -> FO:
  match i < 46:
    case 0:
      fo_ring(m, i - 46)
    case k:
      fo_push(m, i)

# carbon: first frame index whose imposed deflection exceeds the
# fracture deflection (root strain 0.8% -> delta = 0.2667 m)
def isnap_go(i: U32) -> U32:
  match i == 46:
    case 0:
      match pd(i) > 0.26666:
        case 0:
          isnap_go(i + 1)
        case k:
          i
    case j:
      46

def fall_replay(j: U32, pv: PV) -> PV:
  match j:
    case 0:
      pv
    case k:
      fall_replay(k - 1, fall_step(pv))

def fall_step(pv: PV) -> PV:
  match pv:
    case PV.PV{fl, v}:
      v2 = v + (9.81 * 0.00825)
      PV.PV{fl + (v2 * 0.00825), v2}

def fo_fall(m: Mat, j: U32) -> FO:
  jj = umin(j, 50)
  t = U32.to_f32(jj) * 0.00825
  rx = clamp0(1.0 - (t / 0.15))
  pv = fall_replay(jj, PV.PV{0.0, 0.0})
  fo_fall2(m, pv, rx, j > 50)

def fo_fall2(m: Mat, pv: PV, rx: F32, done: U32) -> FO:
  match pv:
    case PV.PV{fl, v}:
      FO.FO{draw(m, 0.2667, rx, fl, 0, 1, 0), done_st(done, "SNAPPED at the root -- no yield, no warning (slow-mo 1/4)"), done}

def frame_c2(m: Mat, i: U32, isnap: U32) -> FO:
  match i < (isnap + 4):
    case 0:
      fo_fall(m, i - (isnap + 4))
    case k:
      FO.FO{draw(m, pd(isnap), 1.0, 0.0, 0, 1, i % 2), "SNAP! sigma_root ~ 1.08 GPa at eps ~ 0.8%", 0}

def frame_c(m: Mat, i: U32) -> FO:
  isnap = isnap_go(0)
  match i < isnap:
    case 0:
      frame_c2(m, i, isnap)
    case k:
      fo_push(m, i)

def frame_at(m: Mat, i: U32) -> FO:
  match mat_id(m) == 3:
    case 0:
      frame_sr(m, i)
    case k:
      frame_c(m, i)

# ---------------------------------------------------------------- json

def u32s_go(n: U32, k: String) -> String:
  match n:
    case 0:
      k
    case m:
      u32s_go(m / 10, List.Cons{Char.Char{48 + (m % 10)}, k})

def u32s(n: U32) -> String:
  match n:
    case 0:
      "0"
    case m:
      u32s_go(m, "")

def cat(a: String, b: String) -> String:
  List.concat(Char, a, b)

def cat3(a: String, b: String, c: String) -> String:
  cat(a, cat(b, c))

def jnums(bs: List(U32)) -> String:
  match bs:
    case List.Nil{}:
      "]"
    case List.Cons{h, t}:
      cat3(",", u32s(h), jnums(t))

def jarr(bs: List(U32)) -> String:
  match bs:
    case List.Nil{}:
      "[]"
    case List.Cons{h, t}:
      cat3("[", u32s(h), jnums(t))

def jfo(fo: FO) -> String:
  match fo:
    case FO.FO{cmds, st, done}:
      cat3(cat3("{\"done\":", u32s(done), ",\"st\":\""),
           cat3(st, "\",\"cmds\":", jarr(cmds)),
           "}")

# ---------------------------------------------------------------- http

def pu32_go(s: String, acc: U32) -> U32:
  match s:
    case List.Nil{}:
      acc
    case List.Cons{c, t}:
      pu32_c(c, t, acc)

def pu32_c(c: Char, t: String, acc: U32) -> U32:
  match c:
    case Char.Char{n}:
      pu32_go(t, (acc * 10) + ((n - 48) % 10))

def pu32(s: String) -> U32:
  pu32_go(s, 0)

def frame_json(mat: U32, i: U32) -> HTTP.Response:
  HTTP.reply(200, "application/json", jfo(frame_at(mat_of(mat), i)))

def index2(h: Result((U32 & String), String)) -> IO(HTTP.Response):
  match h:
    case Result.Done{html}:
      IO.pure(HTTP.Response, HTTP.reply(200, "text/html; charset=utf-8", html))
    case Result.Fail{(code, e)}:
      IO.pure(HTTP.Response, HTTP.reply(500, "text/plain", "index.html not found -- run the server from the repo root\n"))

def index() -> IO(HTTP.Response):
  do IO(HTTP.Response):
    h <- IO.read_text("gabriel_demos/bar_bench_web/index.html")
    index2(h)

def route_f(rest: List(String)) -> IO(HTTP.Response):
  match rest:
    case List.Cons{a, r1}:
      route_f2(a, r1)
    case List.Nil{}:
      IO.pure(HTTP.Response, HTTP.not_found())

def route_f2(a: String, r1: List(String)) -> IO(HTTP.Response):
  match r1:
    case List.Cons{b, r2}:
      IO.pure(HTTP.Response, frame_json(pu32(a), pu32(b)))
    case List.Nil{}:
      IO.pure(HTTP.Response, HTTP.not_found())

def route_s(s1: String, rest: List(String)) -> IO(HTTP.Response):
  match String.eq_u32(s1, "frame"):
    case 0:
      route_root(s1)
    case k:
      route_f(rest)

def route_root(s1: String) -> IO(HTTP.Response):
  match String.eq_u32(s1, ""):
    case 0:
      IO.pure(HTTP.Response, HTTP.not_found())
    case k:
      index()

def route_p(segs: List(String)) -> IO(HTTP.Response):
  match segs:
    case List.Cons{e0, r0}:
      route_p2(r0)
    case List.Nil{}:
      IO.pure(HTTP.Response, HTTP.not_found())

def route_p2(r0: List(String)) -> IO(HTTP.Response):
  match r0:
    case List.Cons{s1, rest}:
      route_s(s1, rest)
    case List.Nil{}:
      index()

def route(rq: HTTP.Request) -> IO(HTTP.Response):
  match rq:
    case HTTP.Request.Request{method, path, hs, bd}:
      route_p(String.split('/', path))

def routes() -> HTTP.Router:
  HTTP.Router.Router{route, u => routes()}

def serve_conn(fd: TCP, c: Result((U32 & String), TCP)) -> IO(U32):
  match c:
    case Result.Done{cfd}:
      do IO(U32):
        _ <- HTTP.handle(HTTP.Plain{cfd}, routes())
        serve_loop(fd)
    case Result.Fail{(code, e)}:
      do IO(U32):
        _ <- IO.write(cat3("accept failed: ", e, "\n"))
        return 1

def serve_loop(fd: TCP) -> IO(U32):
  do IO(U32):
    c <- TCP.accept(fd)
    serve_conn(fd, c)

def main2(r: Result((U32 & String), TCP)) -> IO(U32):
  match r:
    case Result.Done{fd}:
      do IO(U32):
        _ <- IO.write("bar bench listening on all interfaces (0.0.0.0:8080)\nopen http://<server-lan-ip>:8080  (ctrl-c to stop)\n")
        serve_loop(fd)
    case Result.Fail{(code, e)}:
      do IO(U32):
        _ <- IO.write(cat3("listen failed: ", e, "\n"))
        return 1

def main() -> IO(U32):
  do IO(U32):
    r <- TCP.listen(8080)
    main2(r)
