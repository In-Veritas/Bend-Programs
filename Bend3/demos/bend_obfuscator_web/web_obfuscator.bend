# Bend3 Source Obfuscator: a private browser editor served by Bend3.
# The transformation runs locally in the page; no pasted source is retained.
#
# build: ./gabriel_demos/bend_obfuscator_web/build.sh
# run:   ./gabriel_demos/bend_obfuscator_web/start.sh
# open:  http://<server-lan-ip>:8088
#
# no-halt
# skip-native

import ../../bend-base/Base
import ../Compat
import ../../bend-base/IO/TCP
import ../../bend-base/IO/HTTP

type Game:
  Game{served: U32}

type Routed:
  Routed{game: Game, response: HTTP.Response}

# ---------------------------------------------------------------- Game

def game_empty() -> Game:
  Game.Game{0}

def game_page(game: Game) -> Game:
  match game:
    case Game.Game{served}:
      Game.Game{served + 1}

# ---------------------------------------------------------------- Result

def result_index(result: Result((U32 & String), String), game: Game) -> Routed:
  match result:
    case Result.Done{html}:
      Routed.Routed{game_page(game), HTTP.reply(200, "text/html; charset=utf-8", html)}
    case Result.Fail{(code, error)}:
      Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run from the repository root\n")}

# ---------------------------------------------------------------- Request

def request_route(request: HTTP.Request, game: Game) -> IO(Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(method, "GET"):
        case 0:
          IO.pure(Routed, Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")})
        case get:
          match String.eq_u32(path, "/"):
            case 0:
              IO.pure(Routed, Routed.Routed{game, HTTP.not_found()})
            case root:
              do IO(Routed):
                result <- IO.read_text("gabriel_demos/bend_obfuscator_web/index.html")
                return result_index(result, game)

# ---------------------------------------------------------------- server

def routed_send(routed: Routed, server: TCP, conn: HTTP) -> IO(U32):
  match routed:
    case Routed.Routed{game, response}:
      do IO(U32):
        sent <- HTTP.send_response(conn, HTTP.with_connection(0, response))
        closed <- HTTP.close(conn)
        u32_serve(server, game)

def inbound_serve(inbound: HTTP.Inbound, server: TCP, conn: HTTP, game: Game) -> IO(U32):
  match inbound:
    case HTTP.Inbound.Got{http11, request, rest}:
      do IO(U32):
        routed <- request_route(request, game)
        routed_send(routed, server, conn)
    case HTTP.Inbound.Closed{}:
      do IO(U32):
        closed <- HTTP.close(conn)
        u32_serve(server, game)
    case HTTP.Inbound.Bad{code, error}:
      routed_send(Routed.Routed{game, HTTP.reply_error(code, error)}, server, conn)

def result_accept(result: Result((U32 & String), TCP), server: TCP, game: Game) -> IO(U32):
  match result:
    case Result.Done{fd}:
      do IO(U32):
        inbound <- HTTP.recv_request(HTTP.Plain{fd}, List.Nil{})
        inbound_serve(inbound, server, HTTP.Plain{fd}, game)
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["accept failed: ", error, "\n"]))
        return 1

def u32_serve(server: TCP, game: Game) -> IO(U32):
  do IO(U32):
    result <- TCP.accept(server)
    result_accept(result, server, game)

def result_main(result: Result((U32 & String), TCP)) -> IO(U32):
  match result:
    case Result.Done{server}:
      do IO(U32):
        printed <- IO.write("Bend3 Source Obfuscator listening on 0.0.0.0:8088\nopen http://<server-lan-ip>:8088\n")
        u32_serve(server, game_empty())
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def main() -> IO(U32):
  do IO(U32):
    result <- TCP.listen(8088)
    result_main(result)
