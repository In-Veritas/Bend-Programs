# web_elements: the four bending arts as a webapp.
#
# Same pure scene stack as ../elements (four clickable panels of
# traveling-sine motion, Bhaskara sine, "BEND!" glyph title) -- imported
# from ../elements/elements.bend, not copied -- but the presenter is a
# browser canvas instead of a window: this Bend HTTP server computes any
# frame on demand and serves it as draw commands; the page (index.html,
# served from here) only rasterizes. Stateless: frame i is the scene at
# t = i*0.033 (i wraps at 190400 so t stays in fsin range).
#
# routes (each also under /elements, the BendJogos hub's prefix, which
# the page uses):
#   GET /            the page (read from disk: run from the repo root)
#   GET /frame/<i>/<earth>/<water>/<fire>/<air>
#                     {"cmds":[...]} for frame i and four packed
#                     {countdown, local x, local y} reaction states
#   GET /frame/<i>    the same frame with every reaction inactive
#
# build:  bend Bend3/demos/elements_web/web_elements.bend -o Bend3/demos/elements_web/build/web_elements
# run:    Bend3/demos/elements_web/build/web_elements   (from the repo root)
# open:   http://<server-lan-ip>:8081
import Base
import ../HTTP.bend as HTTP
import ../Compat.bend as Compat
import ../elements/elements.bend as E

# A reaction from the page, its countdown capped at the panel's length.
def limit(+x: U32, +top: U32) -> U32:
  E.u32_reaction_make(E.u32_cap(E.u32_reaction_time(x), top), E.u32_reaction_x(x), E.u32_reaction_y(x))

def nums(xs: List<&2, U32>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      U32.show(h) <> nums(t)

def frame_json(+i: U32, +e: U32, +w: U32, +f: U32, +a: U32) -> String:
  "{\"cmds\":" ++ HTTP.json_array(nums(E.scene((U32.to_f32((i % 190400 : U32)) * 0.033 : F32),
    limit(e, 48), limit(w, 60), limit(f, 45), limit(a, 60)))) ++ "}"

# ---------------------------------------------------------------- http

# The server keeps no game state; Elements only counts requests, so the
# hub can treat this demo like the stateful ones.
type Elements is Data:
  Elements{served: U32}

def init() -> Elements:
  Elements{0}

def done(s: Elements, r: HTTP.Response) -> IO(Elements & HTTP.Response):
  Elements{n} = s
  IO.pure(Elements & HTTP.Response, (Elements{(n + 1 : U32)}, r))

def index(s: Elements) -> IO(Elements & HTTP.Response):
  do IO<Elements & HTTP.Response>:
    r : HTTP.Response <- HTTP.file("Bend3/demos/elements_web/index.html")
    done(s, r)

def frame(ok: Bool, r: String, s: Elements) -> IO(Elements & HTTP.Response):
  match ok:
    case True{}:
      done(s, HTTP.json(r))
    case False{}:
      done(s, HTTP.not_found())

# segments after the optional "elements" prefix
def route.app(get: Bool, segs: List<&2, String>, s: Elements) -> IO(Elements & HTTP.Response):
  match get segs:
    case False{} _:
      done(s, HTTP.method_not_allowed())
    case True{} Nil{}:
      index(s)
    case True{} +n <> i <> Nil{}:
      frame(Compat.eq(n, "frame"), frame_json(Compat.to_u32(i), 0, 0, 0, 0), s)
    case True{} +n <> i <> e <> w <> f <> a <> Nil{}:
      frame(Compat.eq(n, "frame"), frame_json(Compat.to_u32(i), Compat.to_u32(e),
        Compat.to_u32(w), Compat.to_u32(f), Compat.to_u32(a)), s)
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
      Compat.eq(h, "elements")
    case Nil{}:
      False{}

# Handles /..., and the hub's /elements/... unchanged.
def route(req: HTTP.Request, s: Elements) -> IO(Elements & HTTP.Response):
  HTTP.Request{+method, +target, headers, body} = req
  +segs = HTTP.segments(target)
  route.app(String.eq(method, "GET"), route.strip(route.first(segs), segs), s)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("elements listening on all interfaces (0.0.0.0:8081)\nopen http://<server-lan-ip>:8081  (ctrl-c to stop)")
    HTTP.serve(~Elements, ~route, "0.0.0.0", 8081, init())
