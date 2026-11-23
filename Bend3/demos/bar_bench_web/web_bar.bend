# web_bar: the bar-bending bench as a webapp.
#
# A Bend webapp here is a Bend HTTP server (../HTTP.bend over Base's
# TCP). This server computes every animation frame -- the same physics as
# bar_bench (Euler-Bernoulli cantilever, real material data, modal
# release, brittle snap), shared through ../bar_bench/Bench.bend -- and
# serves it as draw commands; the browser page (index.html, also served
# from here) is a dumb canvas rasterizer, the web twin of
# ../CommandGFX.bend. Buttons are real HTML buttons.
#
# routes (each also under /bar, the BendJogos hub's prefix, which the
# page uses):
#   GET /                     the page (read from disk: run from the repo root)
#   GET /frame/<mat>/<i>      frame i of material mat (1 steel, 2 rubber,
#                             3 carbon) as {"done":d,"st":"...","cmds":[...]}
#                             -- stateless: any frame computable from (mat, i)
#
# build:  bend Bend3/demos/bar_bench_web/web_bar.bend -o Bend3/demos/bar_bench_web/build/web_bar
# run:    Bend3/demos/bar_bench_web/build/web_bar     (from the repo root)
# open:   http://<server-lan-ip>:8080
import Base
import ../HTTP.bend as HTTP
import ../Compat.bend as Compat
import ../bar_bench/Bench.bend as Bench

# ---------------------------------------------------------------- draw commands
# the stream of ../CommandGFX.bend: 0 clear, 1 rect (y biased +1000)

def cmd_clear(rgb: U32, t: List<&2, U32>) -> List<&2, U32>:
  0 <> rgb <> t

def cmd_rect(x: U32, yb: U32, w: U32, h: U32, rgb: U32, t: List<&2, U32>) -> List<&2, U32>:
  1 <> x <> yb <> w <> h <> rgb <> t

def pick(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def m_rgb(m: Bench.Mat) -> U32:
  match m:
    case Bench.Steel{}:
      13160668
    case Bench.Rubber{}:
      15249448
    case Bench.Cfrp{}:
      4738136

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
      bar_cmds(k, rgb, d, rx, fl, cmd_rect((48 + c * 9 : U32), ypx(c, d, rx, fl), 9, 6, rgb, t))

def arrow_cmds(ar: Bool, +d: F32, t: List<&2, U32>) -> List<&2, U32>:
  match ar:
    case True{}:
      +tip = ypx(59, d, 1.0, 0.0)
      cmd_rect(577, (tip - 42 : U32), 13, 8, 14696512, cmd_rect(580, (tip - 36 : U32), 7, 28, 14696512, t))
    case False{}:
      t

def brk_cmds(brk: Bool, t: List<&2, U32>) -> List<&2, U32>:
  match brk:
    case True{}:
      cmd_rect(44, 1108, 10, 18, 14696512, t)
    case False{}:
      t

def draw(+m: Bench.Mat, pose: Bench.Pose) -> List<&2, U32>:
  Bench.Pose{+d, rx, fl, fN, ar, brk, flash, st} = pose
  cmd_clear(921622,
    cmd_rect(36, 1040, 8, 320, 6317680,
      bar_cmds(60n, pick(flash, 14696512, m_rgb(m)), d, rx, fl,
        arrow_cmds(ar, d,
          brk_cmds(brk, Nil{})))))

# ---------------------------------------------------------------- frames
# frame_at(mat, i): the whole animation as a pure function of (mat, i):
# frame i is the bench's state machine stepped i times from a fresh
# specimen (at most ~330 cheap steps), so any frame can be asked for in
# any order with no session state on the server.

def rel_st(m: Bench.Mat) -> String:
  match m:
    case Bench.Steel{}:
      "RELEASED -- springback + permanent set, ringing at 16.3 Hz (slow-mo 1/32)"
    case Bench.Rubber{}:
      "RELEASED -- full recovery, wobbling at 0.7 Hz (real time)"
    case Bench.Cfrp{}:
      "RELEASED -- ringing (slow-mo 1/64)"

def status(+m: Bench.Mat, st: Bench.Status) -> String:
  match st:
    case Bench.StReady{}:
      "READY"
    case Bench.StPushing{}:
      "PUSHING -- crosshead drives the tip down"
    case Bench.StYielding{}:
      "YIELDING -- plastic flow past sy = 250 MPa"
    case Bench.StSnap{}:
      "SNAP! sigma_root ~ 1.08 GPa at eps ~ 0.8%"
    case Bench.StSnapped{}:
      "SNAPPED at the root -- no yield, no warning (slow-mo 1/4)"
    case Bench.StReleased{}:
      rel_st(m)

def is_hold(ph: Bench.Phase) -> Bool:
  match ph:
    case Bench.Hold{n, d, rx, fl, brk}:
      True{}
    case _:
      False{}

def pick_phase(c: Bool, a: Bench.Phase, b: Bench.Phase) -> Bench.Phase:
  match c:
    case True{}:
      a
    case False{}:
      b

# The phase after i frames; the last pose (a Hold) is the final frame.
def replay(i: Nat, stop: Bool, +m: Bench.Mat, +ph: Bench.Phase) -> Bench.Phase:
  match i stop:
    case 0n _:
      ph
    case _ True{}:
      ph
    case 1n+k False{}:
      +next = Bench.step(m, ph, 1)
      replay(k, is_hold(ph), m, pick_phase(is_hold(ph), ph, next))

def pose_st(pose: Bench.Pose) -> Bench.Status:
  Bench.Pose{d, rx, fl, fN, ar, brk, flash, st} = pose
  st

def nums(xs: List<&2, U32>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      U32.show(h) <> nums(t)

def frame_text(+m: Bench.Mat, +done: Bool, +pose: Bench.Pose) -> String:
  HTTP.json_object([
    ("done", U32.show(Bool.to_u32(done))),
    ("st", HTTP.quoted(Bool.pick(String, done, "DONE -- fresh specimen on the next Bend!", status(m, pose_st(pose))))),
    ("cmds", HTTP.json_array(nums(draw(m, pose))))])

def frame_ph(+m: Bench.Mat, +ph: Bench.Phase) -> String:
  frame_text(m, is_hold(ph), Bench.pose(m, ph))

# Frame i (clamped to 400) of material sel as JSON.
def frame_at(+sel: U32, +i: U32) -> String:
  +m = Bench.mat_of(sel)
  frame_ph(m, replay(U32.to_nat(Bench.umin(i, 400)), False{}, m, Bench.start(m)))

# ---------------------------------------------------------------- http

# The server keeps no game state; Bar only counts requests, so the hub
# can treat this demo like the stateful ones.
type Bar is Data:
  Bar{served: U32}

def init() -> Bar:
  Bar{0}

def done(s: Bar, r: HTTP.Response) -> IO(Bar & HTTP.Response):
  Bar{n} = s
  IO.pure(Bar & HTTP.Response, (Bar{(n + 1 : U32)}, r))

def index(s: Bar) -> IO(Bar & HTTP.Response):
  do IO<Bar & HTTP.Response>:
    r : HTTP.Response <- HTTP.file("Bend3/demos/bar_bench_web/index.html")
    done(s, r)

def route.frame(ok: Bool, a: String, b: String, s: Bar) -> IO(Bar & HTTP.Response):
  match ok:
    case True{}:
      done(s, HTTP.json(frame_at(Compat.to_u32(a), Compat.to_u32(b))))
    case False{}:
      done(s, HTTP.not_found())

# segments after the optional "bar" prefix
def route.app(get: Bool, segs: List<&2, String>, s: Bar) -> IO(Bar & HTTP.Response):
  match get segs:
    case False{} _:
      done(s, HTTP.method_not_allowed())
    case True{} Nil{}:
      index(s)
    case True{} +f <> a <> b <> Nil{}:
      route.frame(Compat.eq(f, "frame"), a, b, s)
    case True{} _:
      done(s, HTTP.not_found())

def route.strip(prefixed: Bool, segs: List<&2, String>) -> List<&2, String>:
  match prefixed segs:
    case True{} h <> t:
      t
    case _ other:
      other

def route.first(segs: List<&2, String>) -> Bool:
  match segs:
    case h <> t:
      Compat.eq(h, "bar")
    case Nil{}:
      False{}

# Handles /..., and the hub's /bar/... unchanged.
def route(req: HTTP.Request, s: Bar) -> IO(Bar & HTTP.Response):
  HTTP.Request{+method, +target, headers, body} = req
  +segs = HTTP.segments(target)
  route.app(String.eq(method, "GET"), route.strip(route.first(segs), segs), s)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("bar bench listening on all interfaces (0.0.0.0:8080)\nopen http://<server-lan-ip>:8080  (ctrl-c to stop)")
    HTTP.serve(~Bar, ~route, "0.0.0.0", 8080, init())
