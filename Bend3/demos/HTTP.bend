# HTTP: a small HTTP/1.1 server toolkit over Base's TCP, for the web
# demos. Import it from a demo folder as:
#
#   import ../HTTP.bend as HTTP
#
# Model: every connection serves one request and closes (Connection:
# close). An accept loop spawns one reader per connection; each reader
# parses its request (request line, headers, Content-Length body) and
# hands the socket and request to ONE state owner over a channel. The
# state owner runs the app's handler, a top-level def
#
#   def route(req: HTTP.Request, state: S) -> IO(S & HTTP.Response)
#
# sends the response, closes the socket and loops with the new state.
# So a stateful game is a plain sequential fold over requests, while a
# slow or idle client (a browser preconnect) never blocks the others.
#
#   HTTP.serve(~S, ~route, "0.0.0.0", 8080, initial_state)
#
# Bodies are Strings (UTF-8). Content-Length is computed in UTF-8 bytes.
# See HTTP.md next to this file for the full API and the migration notes.
import Base

# Types
# -----

type Header is Data:
  Header{name: String, value: String}

# path is the raw request target, query included ("/state/5?x=1").
type Request is Data:
  Request{method: String, path: String, headers: List<&2, Header>, body: String}

type Response is Data:
  Response{status: U32, headers: List<&2, Header>, body: String}

# What a reader got from a connection.
type Inbound is Data:
  Got{request: Request}
  Closed{}
  Bad{code: U32, message: String}

# A parsed request still holding its connection.
type Job is Type:
  Job{sock: Socket, request: Request}

# Limits: how long a reader waits for each chunk, and how many chunks
# (of 65536 bytes) a request may take.
def recv_timeout_ms() -> U32:
  10000

def recv_chunk() -> U32:
  65536

def recv_chunks() -> Nat:
  64n

# Text helpers
# ------------

def utf8_width(a: Bool, b: Bool, c: Bool) -> U32:
  match a b c:
    case True{} _ _:
      1
    case False{} True{} _:
      2
    case False{} False{} True{}:
      3
    case False{} False{} False{}:
      4

def char_width(c: Char) -> U32:
  match c:
    case Chr{+k}:
      utf8_width(U32.is_lt(k, 128), U32.is_lt(k, 2048), U32.is_lt(k, 65536))

def utf8_len.go(s: String, acc: U32) -> U32:
  match s:
    case SNil{}:
      acc
    case SCon{h, t}:
      utf8_len.go(t, (acc + char_width(h) : U32))

# The UTF-8 byte length of a string (what Content-Length counts).
def utf8_len(s: String) -> U32:
  utf8_len.go(s, 0)

def is_code(c: Char, k: U32) -> Bool:
  U32.is_eq(Char.to_u32(c), k)

# JSON
# ----

def hex_digit(+n: U32) -> Char:
  Char.from_u32(Bool.pick(U32, U32.is_lt(n, 10), (n + 48 : U32), (n + 87 : U32)))

def json_ctl(+k: U32) -> String:
  "\\u00" ++ String.from_list([hex_digit((k / 16 : U32)), hex_digit((k % 16 : U32))])

def json_char.pick(+k: U32, h: Char) -> String:
  Bool.pick(String, U32.is_eq(k, 34), "\\\"",
  Bool.pick(String, U32.is_eq(k, 92), "\\\\",
  Bool.pick(String, U32.is_eq(k, 10), "\\n",
  Bool.pick(String, U32.is_eq(k, 13), "\\r",
  Bool.pick(String, U32.is_eq(k, 9), "\\t",
  Bool.pick(String, U32.is_lt(k, 32), json_ctl(k), SCon{h, SNil{}}))))))

def json_char(+c: Char) -> String:
  json_char.pick(Char.to_u32(c), c)

# The characters of s escaped for a JSON string literal, no quotes.
def escape(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{h, t}:
      json_char(h) ++ escape(t)

# s as a JSON string literal, quotes included (old JSON.quoted(s, "")).
def quoted(s: String) -> String:
  "\"" ++ escape(s) ++ "\""

# A JSON boolean from a Bool.
def json_bool(b: Bool) -> String:
  match b:
    case True{}:
      "true"
    case False{}:
      "false"

# A JSON array from already-rendered items.
def json_array(xs: List<&2, String>) -> String:
  "[" ++ String.join(xs, ",") ++ "]"

# A JSON object from (key, rendered value) pairs.
def json_fields(xs: List<(String & String)>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Tuple{k, v} <> t:
      (quoted(k) ++ ":" ++ v) <> json_fields(t)

def json_object(xs: List<(String & String)>) -> String:
  "{" ++ String.join(json_fields(xs), ",") ++ "}"

# Responses
# ---------

def status_find(xs: List<(U32 & String)>, +code: U32) -> String:
  match xs:
    case Nil{}:
      "Unknown"
    case Tuple{c, t} <> rest:
      Bool.pick(String, U32.is_eq(c, code), t, status_find(rest, code))

def status_text(code: U32) -> String:
  status_find([
    (200, "OK"), (201, "Created"), (204, "No Content"),
    (301, "Moved Permanently"), (302, "Found"), (304, "Not Modified"),
    (400, "Bad Request"), (403, "Forbidden"), (404, "Not Found"),
    (405, "Method Not Allowed"), (408, "Request Timeout"),
    (409, "Conflict"), (413, "Payload Too Large"),
    (500, "Internal Server Error"), (501, "Not Implemented"),
    (503, "Service Unavailable")], code)

def render_headers(hs: List<&2, Header>) -> String:
  match hs:
    case Nil{}:
      ""
    case Header{n, v} <> t:
      n ++ ": " ++ v ++ "\r\n" ++ render_headers(t)

# The bytes sent for a response. Content-Length and Connection: close
# are always added: do not put them in the headers yourself.
def render(r: Response) -> String:
  Response{+status, headers, +body} = r
  "HTTP/1.1 " ++ U32.show(status) ++ " " ++ status_text(status) ++ "\r\n"
    ++ render_headers(headers)
    ++ "Content-Length: " ++ U32.show(utf8_len(body))
    ++ "\r\nConnection: close\r\n\r\n" ++ body

# A response with a status, a Content-Type and a body. Responses are
# marked no-store, since demo state changes on every request.
def reply(status: U32, ctype: String, body: String) -> Response:
  Response{status, [Header{"Content-Type", ctype}, Header{"Cache-Control", "no-store"}], body}

def text(body: String) -> Response:
  reply(200, "text/plain; charset=utf-8", body)

def html(body: String) -> Response:
  reply(200, "text/html; charset=utf-8", body)

def json(body: String) -> Response:
  reply(200, "application/json; charset=utf-8", body)

def reply_error(code: U32, message: String) -> Response:
  reply(code, "text/plain; charset=utf-8", message ++ "\n")

def not_found() -> Response:
  reply_error(404, "Not Found")

def bad_request(message: String) -> Response:
  reply_error(400, message)

def method_not_allowed() -> Response:
  reply_error(405, "Method Not Allowed")

def redirect(location: String) -> Response:
  Response{302, [Header{"Location", location}], ""}

# The response with one more header.
def with_header(r: Response, name: String, value: String) -> Response:
  Response{status, headers, body} = r
  Response{status, List.append(&2, Header, headers, [Header{name, value}]), body}

# Kept for old code: every response here already closes its connection.
def with_connection(keep: U32, r: Response) -> Response:
  r

# Files
# -----

def read_text.got(m: File & Result<&1, &1, U32 & String, String>) ->
  IO(Result<&1, &1, U32 & String, String>):
  (f, r) = m
  do IO<Result<&1, &1, U32 & String, String>>:
    File.close(f)
    return r

def read_text.sized(m: File & Result<&1, &1, U32 & String, U32>) ->
  IO(Result<&1, &1, U32 & String, String>):
  (f, r) = m
  match r:
    case Fail{e}:
      do IO<Result<&1, &1, U32 & String, String>>:
        File.close(f)
        return Fail{e}
    case Done{n}:
      do IO<Result<&1, &1, U32 & String, String>>:
        got : File & Result<&1, &1, U32 & String, String> <- File.read(f, U32.max(n, 1))
        read_text.got(got)

def read_text.opened(r: Result<&1, &1, U32 & String, File>) ->
  IO(Result<&1, &1, U32 & String, String>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, U32 & String, String>, Fail{e})
    case Done{f}:
      do IO<Result<&1, &1, U32 & String, String>>:
        sized : File & Result<&1, &1, U32 & String, U32> <- File.size(f)
        read_text.sized(sized)

# The whole text of a file; the path is relative to the directory the
# server was started from.
def read_text(path: String) -> IO(Result<&1, &1, U32 & String, String>):
  do IO<Result<&1, &1, U32 & String, String>>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    read_text.opened(r)

# A Content-Type from a file name's extension.
def mime(+path: String) -> String:
  Bool.pick(String, String.ends_with(path, ".html"), "text/html; charset=utf-8",
  Bool.pick(String, String.ends_with(path, ".js"), "text/javascript; charset=utf-8",
  Bool.pick(String, String.ends_with(path, ".mjs"), "text/javascript; charset=utf-8",
  Bool.pick(String, String.ends_with(path, ".css"), "text/css; charset=utf-8",
  Bool.pick(String, String.ends_with(path, ".json"), "application/json; charset=utf-8",
  Bool.pick(String, String.ends_with(path, ".svg"), "image/svg+xml",
  "text/plain; charset=utf-8"))))))

def file.got(ctype: String, +path: String, r: Result<&1, &1, U32 & String, String>) ->
  Response:
  match r:
    case Done{body}:
      reply(200, ctype, body)
    case Fail{e}:
      reply_error(404, "file not found: " ++ path ++ " (start the server from the directory its paths are relative to)")

# A 200 response with a text file's content (UTF-8 text only), or a 404.
def file(+path: String) -> IO(Response):
  do IO<Response>:
    r : Result<&1, &1, U32 & String, String> <- read_text(path)
    return file.got(mime(path), path, r)

# Requests
# --------

def method(r: Request) -> String:
  Request{m, p, h, b} = r
  m

def target(r: Request) -> String:
  Request{m, p, h, b} = r
  p

def body(r: Request) -> String:
  Request{m, p, h, b} = r
  b

def headers(r: Request) -> List<&2, Header>:
  Request{m, p, h, b} = r
  h

def header_find(hs: List<&2, Header>, +name: String) -> Maybe<&2, String>:
  match hs:
    case Nil{}:
      None{}
    case Header{n, v} <> t:
      Bool.pick(Maybe<&2, String>, String.eq(String.to_lower(n), name), Some{v}, header_find(t, name))

# A header's value; the name is matched without case.
def header_get(hs: List<&2, Header>, name: String) -> Maybe<&2, String>:
  header_find(hs, String.to_lower(name))

def before_query(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{+h, t}:
      Bool.pick(String, is_code(h, 63), SNil{}, SCon{h, before_query(t)})

def after_query(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{+h, +t}:
      Bool.pick(String, is_code(h, 63), t, after_query(t))

# "/a/b?x=1" -> "/a/b"
def path_only(target: String) -> String:
  before_query(target)

# "/a/b?x=1" -> "x=1"; "" without a query.
def query_string(target: String) -> String:
  after_query(target)

# The path cut on '/', query removed: "/state/5" -> ["", "state", "5"],
# "/" -> ["", ""]. This is the shape old demos matched with
# String.split('/', path).
def split_path(target: String) -> List<&2, String>:
  String.split(before_query(target), '/')

# The path's non-empty segments: "/state/5/" -> ["state", "5"].
def segments.put(empty: Bool, h: String, rest: List<&2, String>) -> List<&2, String>:
  match empty:
    case True{}:
      rest
    case False{}:
      h <> rest

def segments.go(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      segments.put(String.is_empty(h), h, segments.go(t))

def segments(target: String) -> List<&2, String>:
  segments.go(split_path(target))

def hex_val(c: Char) -> U32:
  +k = Char.to_u32(c)
  Bool.pick(U32, U32.is_lt(k, 48), 0,
  Bool.pick(U32, U32.is_lt(k, 58), (k - 48 : U32),
  Bool.pick(U32, U32.is_lt(k, 65), 0,
  Bool.pick(U32, U32.is_lt(k, 71), (k - 55 : U32),
  Bool.pick(U32, U32.is_lt(k, 97), 0,
  Bool.pick(U32, U32.is_lt(k, 103), (k - 87 : U32), 0))))))

def url_plain(+h: Char) -> Char:
  Char.from_u32(Bool.pick(U32, is_code(h, 43), 32, Char.to_u32(h)))

def url_step.three(pct: Bool, h: Char, a: Char, b: Char, t: String) -> Char & String:
  match pct:
    case True{}:
      (Char.from_u32((hex_val(a) * 16 + hex_val(b) : U32)), t)
    case False{}:
      (url_plain(h), SCon{a, SCon{b, t}})

# One decoded character and what follows it.
def url_step(s: String) -> Char & String:
  match s:
    case SNil{}:
      (' ', SNil{})
    case SCon{+h, SCon{a, SCon{b, t}}}:
      url_step.three(is_code(h, 37), h, a, b, t)
    case SCon{h, t}:
      (url_plain(h), t)

def url_put(p: Char & String, k: String -> String) -> String:
  (c, rest) = p
  SCon{c, k(rest)}

def url_decode.go(fuel: Nat, s: String) -> String:
  match fuel s:
    case 0n _:
      SNil{}
    case _ SNil{}:
      SNil{}
    case 1n+f SCon{h, t}:
      url_put(url_step(SCon{h, t}), r => url_decode.go(f, r))

# Percent-decoding ("%20" and "+" become spaces). ASCII escapes only: a
# multi-byte UTF-8 escape decodes byte by byte.
def url_decode(+s: String) -> String:
  url_decode.go(String.length(s), s)

def query_pair(kv: List<&2, String>, +key: String, rest: Maybe<&2, String>) -> Maybe<&2, String>:
  match kv:
    case Nil{}:
      rest
    case k <> v:
      Bool.pick(Maybe<&2, String>, String.eq(url_decode(k), key), Some{url_decode(String.join(v, "="))}, rest)

def query_find(xs: List<&2, String>, +key: String) -> Maybe<&2, String>:
  match xs:
    case Nil{}:
      None{}
    case h <> t:
      query_pair(String.split(h, '='), key, query_find(t, key))

# A query parameter: query_get("/p?a=1&b=x%20y", "b") = Some{"x y"}.
def query_get(target: String, key: String) -> Maybe<&2, String>:
  query_find(String.split(after_query(target), '&'), key)

# The body's lines, cut on '\n' (old demos' `body_parts`).
def body_lines(body: String) -> List<&2, String>:
  String.split(body, '\n')

# Parsing
# -------

# After a CR, LF, CR, LF: state 1, 2, 3, 4.
def crlf_pick(cr: Bool, lf: Bool, +st: U32) -> U32:
  match cr lf:
    case True{} _:
      Bool.pick(U32, U32.is_eq(st, 2), 3, 1)
    case False{} True{}:
      Bool.pick(U32, U32.is_eq(st, 1), 2, Bool.pick(U32, U32.is_eq(st, 3), 4, 0))
    case False{} False{}:
      0

def crlf_next(+st: U32, +c: Char) -> U32:
  crlf_pick(is_code(c, 13), is_code(c, 10), st)

# Splits "head\r\n\r\nrest": Some{(head, rest)}, or None before the blank
# line. acc is the head so far, reversed; done says the blank line ended.
def head_scan(s: String, done: Bool, acc: String, +st: U32) -> Maybe<(String & String)>:
  match s done:
    case rest True{}:
      Some{(String.reverse(String.drop(acc, 4n)), rest)}
    case SNil{} False{}:
      None{}
    case SCon{+h, t} False{}:
      +st2 = crlf_next(st, h)
      head_scan(t, U32.is_eq(st2, 4), SCon{h, acc}, st2)

def parse_header(parts: List<&2, String>) -> List<&2, Header>:
  match parts:
    case Nil{}:
      Nil{}
    case n <> rest:
      [Header{String.trim(n), String.trim(String.join(rest, ":"))}]

def parse_headers.put(empty: Bool, line: String, rest: List<&2, Header>) -> List<&2, Header>:
  match empty:
    case True{}:
      rest
    case False{}:
      List.append(&2, Header, parse_header(String.split(line, ':')), rest)

def parse_headers(lines: List<&2, String>) -> List<&2, Header>:
  match lines:
    case Nil{}:
      Nil{}
    case l <> t:
      +line = String.trim(l)
      parse_headers.put(String.is_empty(line), line, parse_headers(t))

def parse_line(parts: List<&2, String>, hs: List<&2, Header>, body: String) -> Maybe<&2, Request>:
  match parts:
    case m <> p <> v <> rest:
      Some{Request{m, p, hs, body}}
    case other:
      None{}

def parse_lines(lines: List<&2, String>, body: String) -> Maybe<&2, Request>:
  match lines:
    case Nil{}:
      None{}
    case first <> rest:
      parse_line(String.split(String.trim(first), ' '), parse_headers(rest), body)

def content_length.go(m: Maybe<&2, String>) -> U32:
  match m:
    case None{}:
      0
    case Some{v}:
      Maybe.default(&2, U32, U32.read(String.trim(v)), 0)

def content_length_of(hs: List<&2, Header>) -> U32:
  content_length.go(header_get(hs, "content-length"))

# A full request once its body has all Content-Length bytes.
def parse_ready(r: Request) -> Maybe<&2, Request>:
  Request{m, p, +h, +b} = r
  Bool.pick(Maybe<&2, Request>, U32.is_ge(utf8_len(b), content_length_of(h)), Some{Request{m, p, h, b}}, None{})

# What a buffer holds so far: 0 incomplete, 1 complete, 2 malformed.
type Parsed is Data:
  More{}
  Full{request: Request}
  Malformed{}

def parse_full(m: Maybe<&2, Request>) -> Parsed:
  match m:
    case None{}:
      More{}
    case Some{r}:
      Full{r}

def parse_req(m: Maybe<&2, Request>) -> Parsed:
  match m:
    case None{}:
      Malformed{}
    case Some{r}:
      parse_full(parse_ready(r))

def parse_split(m: Maybe<(String & String)>) -> Parsed:
  match m:
    case None{}:
      More{}
    case Some{Tuple{head, rest}}:
      parse_req(parse_lines(String.split(head, '\n'), rest))

# Parses a complete request from text (also handy for tests).
def parse(buf: String) -> Parsed:
  parse_split(head_scan(buf, False{}, SNil{}, 0))

# Receiving
# ---------

def recv_parsed(sock: Socket, buf: String, p: Parsed,
  more: Socket -> String -> IO(Socket & Inbound)) -> IO(Socket & Inbound):
  match p:
    case More{}:
      more(sock, buf)
    case Full{r}:
      IO.pure(Socket & Inbound, (sock, Got{r}))
    case Malformed{}:
      IO.pure(Socket & Inbound, (sock, Bad{400, "Bad Request"}))

def recv_end(sock: Socket, empty: Bool) -> IO(Socket & Inbound):
  match empty:
    case True{}:
      IO.pure(Socket & Inbound, (sock, Closed{}))
    case False{}:
      IO.pure(Socket & Inbound, (sock, Bad{400, "Bad Request"}))

def recv_got(
  m: Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, String>>, Unit>,
  buf: String, more: Socket -> String -> IO(Socket & Inbound)
) -> IO(Socket & Inbound):
  (sock, poll) = m
  match poll:
    case Wait{u}:
      IO.pure(Socket & Inbound, (sock, Bad{408, "Request Timeout"}))
    case Ready{Fail{e}}:
      IO.pure(Socket & Inbound, (sock, Closed{}))
    case Ready{Done{None{}}}:
      recv_end(sock, String.is_empty(buf))
    case Ready{Done{Some{chunk}}}:
      +buf2 = buf ++ chunk
      recv_parsed(sock, buf2, parse(buf2), more)

# Reads until one request is complete, for at most fuel chunks.
def recv_request(fuel: Nat, sock: Socket, buf: String) -> IO(Socket & Inbound):
  match fuel:
    case 0n:
      IO.pure(Socket & Inbound, (sock, Bad{413, "Payload Too Large"}))
    case 1n+f:
      do IO<Socket & Inbound>:
        m : Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, String>>, Unit> <- TCP.try_recv(sock, recv_chunk(), recv_timeout_ms())
        recv_got(m, buf, s => b => recv_request(f, s, b))

# Sending
# -------

def sent_close(m: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

# Sends a response and closes the socket.
def send_close(sock: Socket, r: Response) -> IO(Unit):
  do IO<Unit>:
    m : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send(sock, render(r))
    sent_close(m)

# Serving
# -------

def reader.sent(m: Result<&1, &1, Job, Unit>) -> IO(Unit):
  match m:
    case Done{u}:
      IO.pure(Unit, Unit{})
    case Fail{Job{sock, r}}:
      Socket.close(sock)

def reader.got(m: Socket & Inbound, +jobs: Chan(Job)) -> IO(Unit):
  (sock, inbound) = m
  match inbound:
    case Got{r}:
      do IO<Unit>:
        sent : Result<&1, &1, Job, Unit> <- Chan.send(Job, jobs, Job{sock, r})
        reader.sent(sent)
    case Closed{}:
      Socket.close(sock)
    case Bad{code, message}:
      send_close(sock, reply_error(code, message))

# One connection: read its request, queue it for the state owner.
def reader(sock: Socket, +jobs: Chan(Job)) -> IO(Unit):
  do IO<Unit>:
    m : Socket & Inbound <- recv_request(recv_chunks(), sock, "")
    reader.got(m, jobs)

def accept.got(r: Result<&1, &1, U32 & String, Socket>, +jobs: Chan(Job)) -> IO(Unit):
  match r:
    case Done{sock}:
      IO.spawn(Unit, reader(sock, jobs))
    case Fail{Tuple{code, msg}}:
      do IO<Unit>:
        IO.print_err("accept failed: " ++ msg)
        IO.sleep(50)

def accept.next(m: Listener & Result<&1, &1, U32 & String, Socket>, +jobs: Chan(Job),
  rest: Listener -> IO(Unit)) -> IO(Unit):
  (l, r) = m
  do IO<Unit>:
    accept.got(r, jobs)
    rest(l)

def accept_loop(fuel: Nat, l: Listener, +jobs: Chan(Job)) -> IO(Unit):
  match fuel:
    case 0n:
      Listener.close(l)
    case 1n+f:
      do IO<Unit>:
        m : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
        accept.next(m, jobs, l2 => accept_loop(f, l2, jobs))

def work.done(-S: Type, sock: Socket, out: S & Response, rest: S -> IO(Unit)) -> IO(Unit):
  (state, resp) = out
  do IO<Unit>:
    send_close(sock, resp)
    rest(state)

def work.got(-S: Type, handler: Request -> S -> IO(S & Response), got: Maybe<&1, Job>,
  state: S, rest: S -> IO(Unit)) -> IO(Unit):
  match got:
    case None{}:
      IO.pure(Unit, Unit{})
    case Some{Job{sock, r}}:
      IO.bind(S & Response, Unit, handler(r, state), out => work.done(S, sock, out, rest))

def work.step(-S: Type, handler: Request -> S -> IO(S & Response), +jobs: Chan(Job),
  state: S, rest: S -> IO(Unit)) -> IO(Unit):
  do IO<Unit>:
    got : Maybe<&1, Job> <- Chan.recv(Job, jobs)
    work.got(S, handler, got, state, rest)

# The state owner: one request at a time, threading the state.
def work(~S: Type, ~handler: Request -> S -> IO(S & Response), fuel: Nat,
  +jobs: Chan(Job), state: S) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+f:
      work.step(S, handler, jobs, state, s => work(~S, ~handler, f, jobs, s))

# Serves on an already-open listener.
def serve_on(~S: Type, ~handler: Request -> S -> IO(S & Response), l: Listener, state: S) -> IO(Unit):
  do IO<Unit>:
    +jobs : Chan(Job) <- Chan.new(Job, 256)
    IO.spawn(Unit, accept_loop(4294967295n, l, jobs))
    work(~S, ~handler, 4294967295n, jobs, state)

# Listens on host:port ("0.0.0.0" for every interface) and serves
# forever (4294967295 requests). The handler is a top-level def.
def serve(~S: Type, ~handler: Request -> S -> IO(S & Response), host: String, port: U32,
  state: S) -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen(host, port))
    serve_on(~S, ~handler, l, state)

# Stateless serving
# -----------------
# For apps with no state to thread (old HTTP.handle / HTTP.Router): every
# connection runs `handler(req)` in its own computation, concurrently.

def plain.got(handler: Request -> IO(Response), m: Socket & Inbound) -> IO(Unit):
  (sock, inbound) = m
  match inbound:
    case Got{r}:
      IO.bind(Response, Unit, handler(r), resp => send_close(sock, resp))
    case Closed{}:
      Socket.close(sock)
    case Bad{code, message}:
      send_close(sock, reply_error(code, message))

def plain.conn(handler: Request -> IO(Response), sock: Socket) -> IO(Unit):
  do IO<Unit>:
    m : Socket & Inbound <- recv_request(recv_chunks(), sock, "")
    plain.got(handler, m)

def plain.next(handler: Request -> IO(Response),
  m: Listener & Result<&1, &1, U32 & String, Socket>, rest: Listener -> IO(Unit)) -> IO(Unit):
  (l, r) = m
  match r:
    case Done{sock}:
      do IO<Unit>:
        IO.spawn(Unit, plain.conn(handler, sock))
        rest(l)
    case Fail{Tuple{code, msg}}:
      do IO<Unit>:
        IO.print_err("accept failed: " ++ msg)
        IO.sleep(50)
        rest(l)

def plain_loop(~handler: Request -> IO(Response), fuel: Nat, l: Listener) -> IO(Unit):
  match fuel:
    case 0n:
      Listener.close(l)
    case 1n+f:
      do IO<Unit>:
        m : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
        plain.next(handler, m, l2 => plain_loop(~handler, f, l2))

# Listens on host:port and answers every request with handler(req), a
# top-level def `Request -> IO(Response)`, each connection concurrently.
def serve_stateless(~handler: Request -> IO(Response), host: String, port: U32) -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen(host, port))
    plain_loop(~handler, 4294967295n, l)
