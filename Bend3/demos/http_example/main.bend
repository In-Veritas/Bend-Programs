# http_example: a tiny stateful counter server over ../HTTP.bend.
#
# routes:
#   GET  /              index.html (read from disk on every request)
#   GET  /state         {"count":N,"requests":R,"note":"..."}
#   POST /inc           adds the body's number (empty body: 1) to the count
#   GET  /echo?msg=...  the decoded query parameter, as JSON
#   anything else       404
#
# build: bend main.bend -o /tmp/http_example
# run:   cd Bend3/demos/http_example && /tmp/http_example
# open:  http://127.0.0.1:8099
import Base
import ../HTTP.bend as HTTP
import ../Compat.bend as Compat

# The app state: the count, how many requests were served, and the
# last note a POST sent.
type Counter is Data:
  Counter{count: U32, requests: U32, note: String}

def state_json(c: Counter) -> String:
  Counter{count, requests, note} = c
  HTTP.json_object([
    ("count", U32.show(count)),
    ("requests", U32.show(requests)),
    ("note", HTTP.quoted(note))])

def seen(c: Counter) -> Counter:
  Counter{count, requests, note} = c
  Counter{count, (requests + 1 : U32), note}

# POST /inc: the body is a number, or empty for 1.
def inc(c: Counter, +body: String) -> Counter:
  Counter{count, requests, note} = c
  +by = Bool.pick(U32, String.is_empty(String.trim(body)), 1, Compat.to_u32(String.trim(body)))
  Counter{(count + by : U32), requests, "added " ++ U32.show(by)}

def done(c: Counter, r: HTTP.Response) -> IO(Counter & HTTP.Response):
  IO.pure(Counter & HTTP.Response, (c, r))

def index(c: Counter) -> IO(Counter & HTTP.Response):
  do IO<Counter & HTTP.Response>:
    r : HTTP.Response <- HTTP.file("index.html")
    return (c, r)

def echo(+target: String) -> HTTP.Response:
  HTTP.json(HTTP.quoted(Maybe.default(&2, String, HTTP.query_get(target, "msg"), "")))

def route.get(state: Bool, echo_: Bool, +target: String, c: Counter) -> IO(Counter & HTTP.Response):
  match state echo_:
    case True{} _:
      +c2 = c
      done(c2, HTTP.json(state_json(c2)))
    case False{} True{}:
      done(c, echo(target))
    case False{} False{}:
      done(c, HTTP.not_found())

def route.post(is_inc: Bool, +body: String, c: Counter) -> IO(Counter & HTTP.Response):
  match is_inc:
    case True{}:
      +c2 = inc(c, body)
      done(c2, HTTP.json(state_json(c2)))
    case False{}:
      done(c, HTTP.not_found())

# Dispatch on (method, segments).
def route.go(get: Bool, post: Bool, segs: List<&2, String>, +target: String, +body: String,
  c: Counter) -> IO(Counter & HTTP.Response):
  match get post segs:
    case True{} _ Nil{}:
      index(c)
    case True{} _ +name <> Nil{}:
      route.get(Compat.eq(name, "state"), Compat.eq(name, "echo"), target, c)
    case False{} True{} +name <> Nil{}:
      route.post(Compat.eq(name, "inc"), body, c)
    case False{} False{} _:
      done(c, HTTP.method_not_allowed())
    case _ _ _:
      done(c, HTTP.not_found())

def route(req: HTTP.Request, c: Counter) -> IO(Counter & HTTP.Response):
  HTTP.Request{+method, +target, headers, +body} = req
  route.go(String.eq(method, "GET"), String.eq(method, "POST"), HTTP.segments(target), target, body, seen(c))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("http_example listening on http://127.0.0.1:8099 (all interfaces)")
    HTTP.serve(~Counter, ~route, "0.0.0.0", 8099, Counter{0, 0, ""})
