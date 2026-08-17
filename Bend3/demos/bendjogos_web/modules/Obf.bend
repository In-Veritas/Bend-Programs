# Generated hub-private namespace from ../bend_obfuscator_web/web_obfuscator.bend.
# Regenerate after changing the standalone source.

# Bend3 Source Obfuscator: a private browser editor served by Bend3.
# The transformation runs locally in the page; no pasted source is retained.
#
# build: ./gabriel_demos/bend_obfuscator_web/build.sh
# run:   ./gabriel_demos/bend_obfuscator_web/start.sh
# open:  http://<server-lan-ip>:8088
#
# no-halt
# skip-native

import ../../../bend-base/Base
import ../../Compat
import ../../../bend-base/IO/TCP
import ../../../bend-base/IO/HTTP

type Obf.Game:
  Game{served: U32}

type Obf.Routed:
  Routed{game: Obf.Game, response: HTTP.Response}

# ---------------------------------------------------------------- Game

def Obf.game_empty() -> Obf.Game:
  Obf.Game.Game{0}

def Obf.game_page(game: Obf.Game) -> Obf.Game:
  match game:
    case Obf.Game.Game{served}:
      Obf.Game.Game{served + 1}

# ---------------------------------------------------------------- Result

def Obf.result_index(result: Result((U32 & String), String), game: Obf.Game) -> Obf.Routed:
  match result:
    case Result.Done{html}:
      Obf.Routed.Routed{Obf.game_page(game), HTTP.reply(200, "text/html; charset=utf-8", html)}
    case Result.Fail{(code, error)}:
      Obf.Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run from the repository root\n")}

# ---------------------------------------------------------------- Request

def Obf.request_route(request: HTTP.Request, game: Obf.Game) -> IO(Obf.Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(method, "GET"):
        case 0:
          IO.pure(Obf.Routed, Obf.Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")})
        case get:
          match String.eq_u32(path, "/"):
            case 0:
              IO.pure(Obf.Routed, Obf.Routed.Routed{game, HTTP.not_found()})
            case root:
              do IO(Obf.Routed):
                result <- IO.read_text("gabriel_demos/bend_obfuscator_web/index.html")
                return Obf.result_index(result, game)

# ---------------------------------------------------------------- server

def Obf.routed_send(routed: Obf.Routed, server: TCP, conn: HTTP) -> IO(U32):
  match routed:
    case Obf.Routed.Routed{game, response}:
      do IO(U32):
        sent <- HTTP.send_response(conn, HTTP.with_connection(0, response))
        closed <- HTTP.close(conn)
        Obf.u32_serve(server, game)

def Obf.inbound_serve(inbound: HTTP.Inbound, server: TCP, conn: HTTP, game: Obf.Game) -> IO(U32):
  match inbound:
    case HTTP.Inbound.Got{http11, request, rest}:
      do IO(U32):
        routed <- Obf.request_route(request, game)
        Obf.routed_send(routed, server, conn)
    case HTTP.Inbound.Closed{}:
      do IO(U32):
        closed <- HTTP.close(conn)
        Obf.u32_serve(server, game)
    case HTTP.Inbound.Bad{code, error}:
      Obf.routed_send(Obf.Routed.Routed{game, HTTP.reply_error(code, error)}, server, conn)

def Obf.result_accept(result: Result((U32 & String), TCP), server: TCP, game: Obf.Game) -> IO(U32):
  match result:
    case Result.Done{fd}:
      do IO(U32):
        inbound <- HTTP.recv_request(HTTP.Plain{fd}, List.Nil{})
        Obf.inbound_serve(inbound, server, HTTP.Plain{fd}, game)
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["accept failed: ", error, "\n"]))
        return 1

def Obf.u32_serve(server: TCP, game: Obf.Game) -> IO(U32):
  do IO(U32):
    result <- TCP.accept(server)
    Obf.result_accept(result, server, game)

def Obf.result_main(result: Result((U32 & String), TCP)) -> IO(U32):
  match result:
    case Result.Done{server}:
      do IO(U32):
        printed <- IO.write("Bend3 Source Obfuscator listening on 0.0.0.0:8088\nopen http://<server-lan-ip>:8088\n")
        Obf.u32_serve(server, Obf.game_empty())
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def Obf.main() -> IO(U32):
  do IO(U32):
    result <- TCP.listen(8088)
    Obf.result_main(result)
