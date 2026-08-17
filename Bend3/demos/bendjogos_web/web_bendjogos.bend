# BendJogos unified LAN server: one process, one TCP port, all state shared.
#
# Namespaces:
#   /snake, /cells, /tic, /minecraft, /cubeworld2, /poker, /belote, /club-corvid, /duck-hunt
#   /obfuscator, /bar, /elements
#   /social and /api/{register,login,state,chat,invite}
#   /games/balloon-defense and /games/helicopter

import ../../bend-base/Base
import ../Compat
import ../../bend-base/IO/TCP
import ../../bend-base/IO/HTTP
import ../Clock as Clock
import ./modules/Tic
import ./modules/Snake
import ./modules/Cells
import ./modules/Mine
import ./modules/Cube
import ./modules/Poker
import ./modules/Belote
import ./modules/Corvid
import ./modules/Duck
import ./modules/Obf
import ./modules/Bar
import ./modules/Elements
import ./modules/Social

type Platform:
  Platform{tic: Tic.Game, snake: Snake.Game, cells: Cells.Game, mine: Mine.Game, cube: Cube.Game, corvid: Corvid.Game, duck: Duck.Game, obfuscator: Obf.Game, social: Social.State, belote: Belote.Game, poker: Poker.Game}

type Outcome:
  Outcome{platform: Platform, response: HTTP.Response}

def page_result(result: Result((U32 & String), String)) -> HTTP.Response:
  match result:
    case Result.Done{html}:
      HTTP.reply(200, "text/html; charset=utf-8", html)
    case Result.Fail{(code, error)}:
      HTTP.reply(500, "text/plain; charset=utf-8", "page not found -- run from the repository root\n")

def page(path: String) -> IO(HTTP.Response):
  do IO(HTTP.Response):
    result <- IO.read_text(path)
    return page_result(result)

def script_result(result: Result((U32 & String), String)) -> HTTP.Response:
  match result:
    case Result.Done{source}:
      HTTP.reply(200, "application/javascript; charset=utf-8", source)
    case Result.Fail{(code, error)}:
      HTTP.reply(500, "text/plain; charset=utf-8", "generated Core asset not found -- run sync_core.mjs\n")

def script_file(path: String) -> IO(HTTP.Response):
  do IO(HTTP.Response):
    result <- IO.read_text(path)
    return script_result(result)

def index_page() -> IO(HTTP.Response):
  page("gabriel_demos/bendjogos_web/index.html")

def rewrite(request: HTTP.Request, path: String) -> HTTP.Request:
  match request:
    case HTTP.Request.Request{method, old_path, headers, body}:
      HTTP.Request.Request{method, path, headers, body}

def suffix(args: List(String)) -> String:
  String.concat("/", String.join("/", args))

def tic_out(routed: Tic.Routed, snake: Snake.Game, cells: Cells.Game, mine: Mine.Game, cube: Cube.Game, corvid: Corvid.Game, duck: Duck.Game, obfuscator: Obf.Game, social: Social.State, belote: Belote.Game, poker: Poker.Game) -> Outcome:
  match routed:
    case Tic.Routed.Routed{game, response}:
      Outcome.Outcome{Platform.Platform{game, snake, cells, mine, cube, corvid, duck, obfuscator, social, belote, poker}, response}

def snake_out(routed: Snake.Routed, tic: Tic.Game, cells: Cells.Game, mine: Mine.Game, cube: Cube.Game, corvid: Corvid.Game, duck: Duck.Game, obfuscator: Obf.Game, social: Social.State, belote: Belote.Game, poker: Poker.Game) -> Outcome:
  match routed:
    case Snake.Routed.Routed{game, response}:
      Outcome.Outcome{Platform.Platform{tic, game, cells, mine, cube, corvid, duck, obfuscator, social, belote, poker}, response}

def cells_out(routed: Cells.Routed, tic: Tic.Game, snake: Snake.Game, mine: Mine.Game, cube: Cube.Game, corvid: Corvid.Game, duck: Duck.Game, obfuscator: Obf.Game, social: Social.State, belote: Belote.Game, poker: Poker.Game) -> Outcome:
  match routed:
    case Cells.Routed.Routed{game, response}:
      Outcome.Outcome{Platform.Platform{tic, snake, game, mine, cube, corvid, duck, obfuscator, social, belote, poker}, response}

def mine_out(routed: Mine.Routed, tic: Tic.Game, snake: Snake.Game, cells: Cells.Game, cube: Cube.Game, corvid: Corvid.Game, duck: Duck.Game, obfuscator: Obf.Game, social: Social.State, belote: Belote.Game, poker: Poker.Game) -> Outcome:
  match routed:
    case Mine.Routed.Routed{game, response}:
      Outcome.Outcome{Platform.Platform{tic, snake, cells, game, cube, corvid, duck, obfuscator, social, belote, poker}, response}

def cube_out(routed: Cube.Routed, tic: Tic.Game, snake: Snake.Game, cells: Cells.Game, mine: Mine.Game, corvid: Corvid.Game, duck: Duck.Game, obfuscator: Obf.Game, social: Social.State, belote: Belote.Game, poker: Poker.Game) -> Outcome:
  match routed:
    case Cube.Routed.Routed{game, response}:
      Outcome.Outcome{Platform.Platform{tic, snake, cells, mine, game, corvid, duck, obfuscator, social, belote, poker}, response}

def belote_out(routed: Belote.Routed, tic: Tic.Game, snake: Snake.Game, cells: Cells.Game, mine: Mine.Game, cube: Cube.Game, corvid: Corvid.Game, duck: Duck.Game, obfuscator: Obf.Game, social: Social.State, poker: Poker.Game) -> Outcome:
  match routed:
    case Belote.Routed.Routed{game, response}:
      Outcome.Outcome{Platform.Platform{tic, snake, cells, mine, cube, corvid, duck, obfuscator, social, game, poker}, response}

def corvid_out(routed: Corvid.Routed, tic: Tic.Game, snake: Snake.Game, cells: Cells.Game, mine: Mine.Game, cube: Cube.Game, duck: Duck.Game, obfuscator: Obf.Game, social: Social.State, belote: Belote.Game, poker: Poker.Game) -> Outcome:
  match routed:
    case Corvid.Routed.Routed{game, response}:
      Outcome.Outcome{Platform.Platform{tic, snake, cells, mine, cube, game, duck, obfuscator, social, belote, poker}, response}

def duck_out(routed: Duck.Routed, tic: Tic.Game, snake: Snake.Game, cells: Cells.Game, mine: Mine.Game, cube: Cube.Game, corvid: Corvid.Game, obfuscator: Obf.Game, social: Social.State, belote: Belote.Game, poker: Poker.Game) -> Outcome:
  match routed:
    case Duck.Routed.Routed{game, response}:
      Outcome.Outcome{Platform.Platform{tic, snake, cells, mine, cube, corvid, game, obfuscator, social, belote, poker}, response}

def obf_out(routed: Obf.Routed, tic: Tic.Game, snake: Snake.Game, cells: Cells.Game, mine: Mine.Game, cube: Cube.Game, corvid: Corvid.Game, duck: Duck.Game, social: Social.State, belote: Belote.Game, poker: Poker.Game) -> Outcome:
  match routed:
    case Obf.Routed.Routed{game, response}:
      Outcome.Outcome{Platform.Platform{tic, snake, cells, mine, cube, corvid, duck, game, social, belote, poker}, response}

def social_out(routed: Social.Routed, tic: Tic.Game, snake: Snake.Game, cells: Cells.Game, mine: Mine.Game, cube: Cube.Game, corvid: Corvid.Game, duck: Duck.Game, obfuscator: Obf.Game, belote: Belote.Game, poker: Poker.Game) -> Outcome:
  match routed:
    case Social.Routed.Routed{state, response}:
      Outcome.Outcome{Platform.Platform{tic, snake, cells, mine, cube, corvid, duck, obfuscator, state, belote, poker}, response}

def poker_out(routed: Poker.Routed, tic: Tic.Game, snake: Snake.Game, cells: Cells.Game, mine: Mine.Game, cube: Cube.Game, corvid: Corvid.Game, duck: Duck.Game, obfuscator: Obf.Game, social: Social.State, belote: Belote.Game) -> Outcome:
  match routed:
    case Poker.Routed.Routed{game, response}:
      Outcome.Outcome{Platform.Platform{tic, snake, cells, mine, cube, corvid, duck, obfuscator, social, belote, game}, response}

def game_tic(request: HTTP.Request, platform: Platform) -> IO(Outcome):
  match platform:
    case Platform.Platform{tic, snake, cells, mine, cube, corvid, duck, obfuscator, social, belote, poker}:
      do IO(Outcome):
        routed <- Tic.request_route(request, tic)
        return tic_out(routed, snake, cells, mine, cube, corvid, duck, obfuscator, social, belote, poker)

def game_snake(request: HTTP.Request, platform: Platform, now: U32) -> IO(Outcome):
  match platform:
    case Platform.Platform{tic, snake, cells, mine, cube, corvid, duck, obfuscator, social, belote, poker}:
      do IO(Outcome):
        routed <- Snake.request_route(request, Snake.game_advance(snake, now), now)
        return snake_out(routed, tic, cells, mine, cube, corvid, duck, obfuscator, social, belote, poker)

def game_cells(request: HTTP.Request, platform: Platform, now: U32) -> IO(Outcome):
  match platform:
    case Platform.Platform{tic, snake, cells, mine, cube, corvid, duck, obfuscator, social, belote, poker}:
      do IO(Outcome):
        routed <- Cells.request_route(request, Cells.game_advance(cells, now), now)
        return cells_out(routed, tic, snake, mine, cube, corvid, duck, obfuscator, social, belote, poker)

def game_mine(request: HTTP.Request, platform: Platform, now: U32) -> IO(Outcome):
  match platform:
    case Platform.Platform{tic, snake, cells, mine, cube, corvid, duck, obfuscator, social, belote, poker}:
      do IO(Outcome):
        routed <- Mine.request_route(request, mine, now)
        return mine_out(routed, tic, snake, cells, cube, corvid, duck, obfuscator, social, belote, poker)

def game_cube(request: HTTP.Request, platform: Platform, now: U32) -> IO(Outcome):
  match platform:
    case Platform.Platform{tic, snake, cells, mine, cube, corvid, duck, obfuscator, social, belote, poker}:
      do IO(Outcome):
        routed <- Cube.request_route(request, cube, now)
        return cube_out(routed, tic, snake, cells, mine, corvid, duck, obfuscator, social, belote, poker)

def game_belote(request: HTTP.Request, platform: Platform) -> IO(Outcome):
  match platform:
    case Platform.Platform{tic, snake, cells, mine, cube, corvid, duck, obfuscator, social, belote, poker}:
      do IO(Outcome):
        routed <- Belote.request_route(request, belote)
        return belote_out(routed, tic, snake, cells, mine, cube, corvid, duck, obfuscator, social, poker)

def game_poker(request: HTTP.Request, platform: Platform) -> IO(Outcome):
  match platform:
    case Platform.Platform{tic, snake, cells, mine, cube, corvid, duck, obfuscator, social, belote, poker}:
      do IO(Outcome):
        routed <- Poker.request_route(request, poker)
        return poker_out(routed, tic, snake, cells, mine, cube, corvid, duck, obfuscator, social, belote)

def game_corvid(request: HTTP.Request, platform: Platform, now: U32) -> IO(Outcome):
  match platform:
    case Platform.Platform{tic, snake, cells, mine, cube, corvid, duck, obfuscator, social, belote, poker}:
      do IO(Outcome):
        routed <- Corvid.request_route(request, corvid, now)
        return corvid_out(routed, tic, snake, cells, mine, cube, duck, obfuscator, social, belote, poker)

def game_duck(request: HTTP.Request, platform: Platform) -> IO(Outcome):
  match platform:
    case Platform.Platform{tic, snake, cells, mine, cube, corvid, duck, obfuscator, social, belote, poker}:
      do IO(Outcome):
        routed <- Duck.request_route(request, duck)
        return duck_out(routed, tic, snake, cells, mine, cube, corvid, obfuscator, social, belote, poker)

def game_obf(request: HTTP.Request, platform: Platform) -> IO(Outcome):
  match platform:
    case Platform.Platform{tic, snake, cells, mine, cube, corvid, duck, obfuscator, social, belote, poker}:
      do IO(Outcome):
        routed <- Obf.request_route(request, obfuscator)
        return obf_out(routed, tic, snake, cells, mine, cube, corvid, duck, social, belote, poker)

def game_social(request: HTTP.Request, platform: Platform, now: U32) -> IO(Outcome):
  match platform:
    case Platform.Platform{tic, snake, cells, mine, cube, corvid, duck, obfuscator, social, belote, poker}:
      do IO(Outcome):
        routed <- Social.request_route(request, social, now)
        return social_out(routed, tic, snake, cells, mine, cube, corvid, duck, obfuscator, belote, poker)

def core_index(platform: Platform) -> IO(Outcome):
  do IO(Outcome):
    response <- page("gabriel_demos/bendjogos_web/core/index.html")
    return Outcome.Outcome{platform, response}

def core_poker(platform: Platform) -> IO(Outcome):
  do IO(Outcome):
    response <- page("gabriel_demos/bendjogos_web/core/poker.html")
    return Outcome.Outcome{platform, response}

def core_poker_data(platform: Platform) -> IO(Outcome):
  do IO(Outcome):
    response <- script_file("gabriel_demos/bendjogos_web/core/poker_data.js")
    return Outcome.Outcome{platform, response}

def core_belote(platform: Platform) -> IO(Outcome):
  do IO(Outcome):
    response <- page("gabriel_demos/bendjogos_web/core/belote.html")
    return Outcome.Outcome{platform, response}

def core_belote_data(platform: Platform) -> IO(Outcome):
  do IO(Outcome):
    response <- script_file("gabriel_demos/bendjogos_web/core/belote_data.js")
    return Outcome.Outcome{platform, response}

def core_route(args: List(String), platform: Platform) -> IO(Outcome):
  match args:
    case List.Nil{}: core_index(platform)
    case List.Cons{"", List.Nil{}}: core_index(platform)
    case List.Cons{"poker", List.Nil{}}: core_poker(platform)
    case List.Cons{"poker", List.Cons{"", List.Nil{}}}: core_poker(platform)
    case List.Cons{"poker_data.js", List.Nil{}}: core_poker_data(platform)
    case List.Cons{"belote", List.Nil{}}: core_belote(platform)
    case List.Cons{"belote", List.Cons{"", List.Nil{}}}: core_belote(platform)
    case List.Cons{"belote_data.js", List.Nil{}}: core_belote_data(platform)
    case other: IO.pure(Outcome, Outcome.Outcome{platform, HTTP.not_found()})

def static_route(name: String, args: List(String), request: HTTP.Request, platform: Platform, now: U32) -> IO(Outcome):
  match String.eq_u32(name, "duck-hunt"):
    case 0:
      match String.eq_u32(name, "cubeworld2"):
        case 0:
          match String.eq_u32(name, "club-corvid"):
            case 0:
              match String.eq_u32(name, "obfuscator"):
                case 0:
                  match String.eq_u32(name, "snake"):
                    case 0:
                      match String.eq_u32(name, "cells"):
                        case 0:
                          match String.eq_u32(name, "tic"):
                            case 0:
                              match String.eq_u32(name, "minecraft"):
                                case 0:
                                  match String.eq_u32(name, "social"):
                                    case 0:
                                      match String.eq_u32(name, "bar"):
                                        case 0:
                                          match String.eq_u32(name, "elements"):
                                            case 0:
                                              match String.eq_u32(name, "core"):
                                                case 0:
                                                  match String.eq_u32(name, "poker"):
                                                    case 0:
                                                      match String.eq_u32(name, "belote"):
                                                        case 0:
                                                          IO.pure(Outcome, Outcome.Outcome{platform, HTTP.not_found()})
                                                        case k14:
                                                          game_belote(rewrite(request, suffix(args)), platform)
                                                    case k13:
                                                      game_poker(rewrite(request, suffix(args)), platform)
                                                case k12: core_route(args, platform)
                                            case k11:
                                              do IO(Outcome):
                                                response <- Elements.route(rewrite(request, suffix(args)))
                                                return Outcome.Outcome{platform, response}
                                        case k10:
                                          do IO(Outcome):
                                            response <- Bar.route(rewrite(request, suffix(args)))
                                            return Outcome.Outcome{platform, response}
                                    case k9:
                                      game_social(request, platform, now)
                                case k8:
                                  game_mine(rewrite(request, suffix(args)), platform, now)
                            case k7:
                              game_tic(rewrite(request, suffix(args)), platform)
                        case k6:
                          game_cells(rewrite(request, suffix(args)), platform, now)
                    case k5:
                      game_snake(rewrite(request, suffix(args)), platform, now)
                case k4:
                  game_obf(rewrite(request, suffix(args)), platform)
            case k3:
              game_corvid(rewrite(request, suffix(args)), platform, now)
        case k2:
          game_cube(rewrite(request, suffix(args)), platform, now)
    case k1:
      game_duck(rewrite(request, suffix(args)), platform)

def route_parts(parts: List(String), request: HTTP.Request, platform: Platform, now: U32) -> IO(Outcome):
  match parts:
    case List.Cons{root, List.Cons{"api", args}}:
      game_social(request, platform, now)
    case List.Cons{root, List.Cons{name, args}}:
      static_route(name, args, request, platform, now)
    case other:
      IO.pure(Outcome, Outcome.Outcome{platform, HTTP.not_found()})

def route(request: HTTP.Request, platform: Platform, now: U32) -> IO(Outcome):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(path, "/"):
        case 0:
          match String.eq_u32(path, "/games/balloon-defense"):
            case 0:
              match String.eq_u32(path, "/social"):
                case 0:
                  match String.eq_u32(path, "/games/helicopter"):
                    case 0:
                      route_parts(String.split('/', path), HTTP.Request.Request{method, path, headers, body}, platform, now)
                    case k3:
                      do IO(Outcome):
                        response <- page("gabriel_demos/bendjogos_web/games/helicopter.html")
                        return Outcome.Outcome{platform, response}
                case k_social:
                  do IO(Outcome):
                    response <- page("gabriel_demos/bendjogos_web/social.html")
                    return Outcome.Outcome{platform, response}
            case k2:
              do IO(Outcome):
                response <- page("gabriel_demos/bendjogos_web/games/balloon_defense.html")
                return Outcome.Outcome{platform, response}
        case k:
          do IO(Outcome):
            response <- index_page()
            return Outcome.Outcome{platform, response}

def outcome_send(outcome: Outcome, server: TCP, conn: HTTP) -> IO(U32):
  match outcome:
    case Outcome.Outcome{platform, response}:
      do IO(U32):
        sent <- HTTP.send_response(conn, HTTP.with_connection(0, response))
        closed <- HTTP.close(conn)
        serve(server, platform)

def inbound_serve(inbound: HTTP.Inbound, server: TCP, conn: HTTP, platform: Platform) -> IO(U32):
  match inbound:
    case HTTP.Inbound.Got{http11, request, rest}:
      do IO(U32):
        now <- clock_now_ms()
        outcome <- route(request, platform, now)
        outcome_send(outcome, server, conn)
    case HTTP.Inbound.Closed{}:
      do IO(U32):
        closed <- HTTP.close(conn)
        serve(server, platform)
    case HTTP.Inbound.Bad{code, error}:
      outcome_send(Outcome.Outcome{platform, HTTP.reply_error(code, error)}, server, conn)

def accept_result(result: Result((U32 & String), TCP), server: TCP, platform: Platform) -> IO(U32):
  match result:
    case Result.Done{fd}:
      do IO(U32):
        inbound <- HTTP.recv_request(HTTP.Plain{fd}, List.Nil{})
        inbound_serve(inbound, server, HTTP.Plain{fd}, platform)
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["accept failed: ", error, "\n"]))
        return 1

def serve(server: TCP, platform: Platform) -> IO(U32):
  do IO(U32):
    result <- TCP.accept(server)
    accept_result(result, server, platform)

def main() -> IO(U32):
  do IO(U32):
    now <- clock_now_ms()
    seed <- IO.rand_word()
    result <- TCP.listen(8090)
    match result:
      case Result.Done{server}:
        do IO(U32):
          printed <- IO.write("BendJogos unified server listening on 0.0.0.0:8090\nopen http://<server-lan-ip>:8090\n")
          serve(server, Platform.Platform{Tic.game_empty(), Snake.game_empty(now, seed), Cells.game_empty(now, seed + 1), Mine.game_empty(), Cube.game_empty(), Corvid.game_empty(), Duck.game_empty(), Obf.game_empty(), Social.empty(), Belote.game_empty(seed + 2), Poker.game_empty(seed + 3)})
      case Result.Fail{(code, error)}:
        do IO(U32):
          printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
          return 1
