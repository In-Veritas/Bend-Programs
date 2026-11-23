# HTTP.bend, Compat.bend, Clock.bend on Bend 2.0.40

Shared helpers for the `*_web` demos, replacing old Bend3's
`bend-base/IO/HTTP`, `IO/TCP`, `JSON` and the global-merge `Compat`/`Clock`.
Working reference: `http_example/main.bend` (stateful counter, verified with
curl and a 1300-request soak test).

```python
import Base
import ../HTTP.bend as HTTP      # from a demo folder (two levels: ../../HTTP.bend)
import ../Compat.bend as Compat
import ../Clock.bend as Clock
```

An import is a namespace: every def, type and constructor of `HTTP.bend` is
`HTTP.<name>` (`HTTP.Request{..}`, `HTTP.reply(..)`). Old Bend3 merged all
imports into one global book; that is gone.

## Serving

```python
# stateful (games): one state owner, requests handled one at a time
def route(req: HTTP.Request, s: State) -> IO(State & HTTP.Response):
  ...
def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("listening on http://0.0.0.0:8082")
    HTTP.serve(~State, ~route, "0.0.0.0", 8082, initial_state())

# stateless (old HTTP.handle / HTTP.Router): every connection concurrent
def route(req: HTTP.Request) -> IO(HTTP.Response):
  ...
def main() -> IO(Unit):
  HTTP.serve_stateless(~route, "0.0.0.0", 8081)
```

- `~route` must be a **top-level def** (templates take closed syntax), and
  `~State` the state type. `HTTP.serve_on(~S, ~route, listener, state)` takes
  an already-open `Listener` instead.
- Model: an accept loop spawns one reader per connection (so an idle browser
  preconnect never blocks anyone); readers queue `(socket, request)` on a
  channel; the state owner runs `route`, sends the response, closes the
  socket and loops with the new state. Every response is
  `Connection: close` with a computed `Content-Length` (UTF-8 bytes).
- Limits: 10 s per receive (then `408`), 64 chunks of 64 KiB per request
  (then `413`), malformed request line `400`. Fuel: 4294967295 requests
  (Nat fuel, so everything checks without `@unsafe`).
- To return the state and a response: `IO.pure(State & HTTP.Response, (s, r))`.

## Types

```python
type Header   is Data: Header{name: String, value: String}
type Request  is Data: Request{method: String, path: String, headers: List<&2, Header>, body: String}
type Response is Data: Response{status: U32, headers: List<&2, Header>, body: String}
type Inbound  is Data: Got{request: Request} | Closed{} | Bad{code: U32, message: String}
type Parsed   is Data: More{} | Full{request: Request} | Malformed{}
```

`path` is the raw target, query included (`"/state/5?x=1"`). Bodies are
`String` (no `Bytes`).

## Functions

| name | type / meaning |
|---|---|
| `reply(status, ctype, body)` | `U32, String, String -> Response`; adds `Content-Type` and `Cache-Control: no-store` |
| `text(b)` `html(b)` `json(b)` | 200 with `text/plain`, `text/html`, `application/json` (utf-8) |
| `reply_error(code, msg)` | plain-text `msg\n` with that status |
| `not_found()` `bad_request(msg)` `method_not_allowed()` | 404 / 400 / 405 |
| `redirect(location)` | 302 |
| `with_header(resp, name, value)` | appends a header (never add Content-Length/Connection) |
| `with_connection(k, resp)` | identity, kept for old code |
| `render(resp)` | the exact bytes sent (status line, headers, body) |
| `status_text(code)` | `"OK"`, `"Not Found"`, ... |
| `file(path)` | `IO(Response)`: a text file with a Content-Type from its extension, or 404 |
| `read_text(path)` | `IO(Result<&1, &1, U32 & String, String>)` (old `IO.read_text`) |
| `mime(path)` | Content-Type for `.html .js .mjs .css .json .svg`, else text/plain |
| `method(r)` `target(r)` `headers(r)` `body(r)` | request fields |
| `header_get(hs, name)` | `Maybe<&2, String>`, case-insensitive |
| `path_only(t)` `query_string(t)` | `"/a?x=1"` -> `"/a"` / `"x=1"` |
| `split_path(t)` | `"/state/5"` -> `["", "state", "5"]` (old `String.split('/', path)` shape, query removed) |
| `segments(t)` | non-empty segments: `"/state/5"` -> `["state", "5"]`, `"/"` -> `[]` |
| `query_get(t, key)` | `Maybe<&2, String>`, percent-decoded (`+` is space; ASCII escapes only) |
| `url_decode(s)` | percent-decoding |
| `body_lines(body)` | `String.split(body, '\n')` (old `body_parts`) |
| `quoted(s)` | JSON string literal with quotes (old `JSON.quoted(s, "")`) |
| `escape(s)` | JSON escaping without quotes |
| `json_bool(b)` `json_array(items)` `json_object([("k", v), ..])` | tiny JSON builders over rendered strings; `json_object` takes `List<(String & String)>` |
| `utf8_len(s)` | UTF-8 byte length, `U32` |
| `parse(buf)` | `Parsed`, the request parser (for tests) |
| `recv_request(fuel, sock, "")` `send_close(sock, resp)` | low-level, for a custom loop |

`Compat`: `from_u32(n)`, `to_u32(s)` (0 on bad input), `eq_u32(a, b)` (1/0),
`eq(a, b)` (Bool), `b2u(Bool)`, `u2b(U32)`, `length(s)` (U32),
`flatten(list)`, `concat(a, b)`.

`Clock`: `now_ms() -> IO(U32)` (monotonic ms; wraps after ~49 days, so only
use differences), `clock_now_ms()` (same, old name).

## Migration cheat-sheet (old Bend3 -> Bend 2.0.40)

| old | new |
|---|---|
| `import ../../bend-base/Base` | `import Base` |
| `import ../../bend-base/IO/HTTP`, `IO/TCP`, `JSON` | `import ../HTTP.bend as HTTP` (TCP is in Base) |
| `import ../Compat` / `import ../Clock` | `import ../Compat.bend as Compat` / `import ../Clock.bend as Clock` |
| `HTTP.Request.Request{method, path, headers, body}` | `HTTP.Request{method, path, headers, body}` |
| `HTTP.Response.Response{code, hs, Bytes.from_string(s)}` | `HTTP.Response{code, hs, s}` |
| `HTTP.Header.Header{n, v}` | `HTTP.Header{n, v}` |
| `HTTP.reply(code, ctype, body)` | same |
| `HTTP.not_found()`, `HTTP.reply_error(code, msg)` | same |
| `HTTP.with_connection(0, r)` | `r` (or same, identity) |
| the whole accept / `HTTP.recv_request` / `HTTP.Inbound.{Got,Closed,Bad}` / `HTTP.send_response` / `HTTP.close` / `HTTP.Plain{fd}` loop (`u32_serve`, `result_accept`, `inbound_serve`, `routed_send`, `result_main`) | delete it; `main` calls `HTTP.serve(~State, ~route, "0.0.0.0", port, init)` and `route` returns `IO(State & HTTP.Response)` instead of a `Routed{game, response}` |
| `HTTP.Router.Router{route, u => routes()}` + `HTTP.handle(conn, routes())` | `HTTP.serve_stateless(~route, "0.0.0.0", port)` |
| `TCP.listen(port)` | `TCP.listen("0.0.0.0", port)` (answers a `Listener`; usually hidden by `HTTP.serve`) |
| `JSON.quoted(s, "")` | `HTTP.quoted(s)` |
| `Bytes.from_string(s)` / `Bytes.to_string(b)` | `s` / `b` (bodies are Strings) |
| `IO.read_text(path)` | `HTTP.read_text(path)`, or `HTTP.file(path)` for a whole response |
| `clock_now_ms()` / `IO.now_ms()` | `Clock.now_ms()` (`IO.now()` answers a `Nat`) |
| `IO.rand_word()` | `IO.try(U32, IO.random_u32())` (or match its `Result`) |
| `String.from_u32(n)` | `U32.show(n)` (or `Compat.from_u32`) |
| `String.to_u32(s)` | `Compat.to_u32(s)` (`U32.read` answers a `Maybe`) |
| `String.eq_u32(a, b)` | `String.eq(a, b)` -> `Bool` (or `Compat.eq_u32`) |
| `String.flatten([..])` | `String.concat([..])` |
| `String.concat(a, b)` | `a ++ b` |
| `String.split('/', s)` | `String.split(s, '/')` (arguments swapped) |
| `String.length(s)` (U32) | `String.length(s)` is a `Nat`; `Compat.length(s)` for U32 |
| `String.join(..)` | `String.join(list, sep)` |
| `List.Cons{h, t}` / `List.Nil{}` | `h <> t` (or `Con{h, t}`) / `Nil{}` / `[a, b]` |
| `Result.Done{x}` / `Result.Fail{(code, e)}` | `Done{x}` / `Fail{Tuple{code, e}}` |
| `Char.Char{10}` | `'\n'` or `Char.from_u32(10)` |
| `List(String)` | `List<&2, String>` (copyable) or `List<String>` (affine) |
| `Result((U32 & String), T)` | `Result<&1, &1, U32 & String, T>` |
| `U32.max/min`, `U32.to_f32`, `F32.to_u32` | same |
| `IO.write(s)`, `IO.print_err(s)`, `IO.sleep(ms)` | same, but answer `IO(Unit)`; `main` returns `IO(Unit)` |

## Syntax gotchas learned while porting

- Types: `type Game is Data:` (copyable) or `is Type` (affine, needed when
  a field is a handle/closure/Array). Constructors are bare: `Game{..}`,
  matched as `case Game{x, o, ..}:`; from a module, `HTTP.Request{..}`.
  Destructure a parameter directly: `Game{x, o, board} = game`.
- Booleans are `Bool`, not U32. Comparisons answer `Bool` (`U32.is_eq`,
  `(a < b : U32)`), `&&`/`||` work on `Bool`. Old `match (x == 1): case 0 ..
  case k` becomes a helper: `f.if(U32.is_eq(x, 1), ..)` whose body does
  `match flag: case True{}: .. case False{}: ..`. `Bool.to_u32(b)` for JSON.
  `Bool.pick(T, c, a, b)` is a one-liner if, but evaluates both sides.
- **`match` only on parameters or pattern variables**, never a call:
  `match String.eq(a, b):` is rejected. The same holds for a destructuring
  let of a computed value: `(c, rest) = step(s)` is rejected; pass the value
  to a helper (or `put(step(s), r => ..)`). Plain lets (`+x = f(y)`) are fine.
- U32 literal patterns work: `match n: case 0: .. case 1: .. case k: ..`.
  Multi-scrutinee: `match a b: case True{} _: ..`. Nested list patterns:
  `case +name <> Nil{}:`, `case m <> p <> v <> rest:`.
- Operators need a type: `(a + b * c : U32)`, `(x / 2.0 : F32)`. Spaces
  around operators. `++` on String works anywhere.
- Affine by default: a variable is used at most once. Reuse needs `+`:
  `def f(+x: U32)`, `+x = ..`, `+x : T <- io`, `case SCon{+h, t}:`,
  `Request{+method, path, ..} = req`. A `+` param must be a `Data` type.
  Branches of one `match` may each use a variable once.
- Defs are checked in file order: a def can only call defs **above** it.
  No mutual recursion; recursion must be structural (recursive call on a
  pattern-bound sub-part, first changing argument) or count down a `Nat`
  fuel (`match fuel: case 0n: .. case 1n+f: ..`). Loops through a helper:
  pass a closure `rest` that does the recursive call (see `HTTP.work`), or
  carry a pre-computed `Bool` flag as an extra matched parameter
  (`HTTP.head_scan`).
- `do IO<T>:` (angle brackets). Every bind is annotated: `x : T <- io`.
  A Unit step is written bare (`IO.print("..")`), no `_ <-`. `return v`.
  Outside a `do`: `IO.pure(T, v)`, `IO.bind(A, B, io, x => ..)`.
- `A & B` (pairs) are `Type`: they cannot be fields of a `Data` type or
  elements of a `List<&2, ..>`; write `List<(A & B)>` (parens required in
  type arguments) or declare a small `is Data` type. Tuple patterns inside
  constructors: `Fail{Tuple{code, msg}}`; known bug: `case (a, b) (c, d):`
  in a multi-match fails, write `Tuple{a, b} Tuple{c, d}`
  (`bugs/multi-match-tuple-pattern-not-split`).
- Templates (`~S`, `~route`) take closed syntax: a top-level def name, not
  a local closure. Closures are affine (call once).
- Handles (`Socket`, `Listener`, `File`) come back beside every result:
  `TCP.recv(s, n) -> IO(Socket & Result<..>)`.
- Commands: `bend f.bend --check-only` (ALL PROOFS CHECK), `bend f.bend -o
  /tmp/f` (native, ~3 s for the example), then run `/tmp/f`. Run servers
  from the directory their `HTTP.file`/`read_text` paths are relative to.
