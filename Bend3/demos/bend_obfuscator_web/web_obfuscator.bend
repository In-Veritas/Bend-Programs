# Bend Source Obfuscator: a private browser editor served by Bend.
# The transformation runs locally in the page; no pasted source is retained.
#
# routes (also under /obfuscator, the BendJogos hub's prefix):
#   GET /    index.html (read from disk: run from the repo root)
#
# build: Bend3/demos/bend_obfuscator_web/build.sh
# run:   Bend3/demos/bend_obfuscator_web/start.sh
# open:  http://<server-lan-ip>:8088
import Base
import ../HTTP.bend as HTTP
import ../Compat.bend as Compat

# The state: how many pages were served.
type Game is Data:
  Game{served: U32}

def init() -> Game:
  Game{0}

def done(g: Game, r: HTTP.Response) -> IO(Game & HTTP.Response):
  IO.pure(Game & HTTP.Response, (g, r))

def index(g: Game) -> IO(Game & HTTP.Response):
  Game{n} = g
  do IO<Game & HTTP.Response>:
    r : HTTP.Response <- HTTP.file("Bend3/demos/bend_obfuscator_web/index.html")
    done(Game{(n + 1 : U32)}, r)

# segments after the optional "obfuscator" prefix
def route.app(get: Bool, segs: List<&2, String>, g: Game) -> IO(Game & HTTP.Response):
  match get segs:
    case False{} _:
      done(g, HTTP.method_not_allowed())
    case True{} Nil{}:
      index(g)
    case True{} _:
      done(g, HTTP.not_found())

def route.strip(prefixed: Bool, segs: List<&2, String>) -> List<&2, String>:
  match prefixed segs:
    case True{} h <> t:
      t
    case _ other:
      other

def route.first(segs: List<&2, String>) -> Bool:
  match segs:
    case h <> t:
      Compat.eq(h, "obfuscator")
    case Nil{}:
      False{}

# Handles /, and the hub's /obfuscator unchanged.
def route(req: HTTP.Request, g: Game) -> IO(Game & HTTP.Response):
  HTTP.Request{+method, +target, headers, body} = req
  +segs = HTTP.segments(target)
  route.app(String.eq(method, "GET"), route.strip(route.first(segs), segs), g)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Bend Source Obfuscator listening on 0.0.0.0:8088\nopen http://<server-lan-ip>:8088")
    HTTP.serve(~Game, ~route, "0.0.0.0", 8088, init())
