# BendJogos unified LAN server: one process, one TCP port, all state shared.
#
# Namespaces:
#   /snake, /cells, /tic, /bar, /elements
#   /social and /api/{register,login,state,chat,invite}
#   /games/balloon-defense and /games/helicopter

import IO
import List
import String
import Char
import Result
import TCP
import HTTP
import ../Clock as Clock
import ../tictactoe_web/web_tictactoe as Tic
import ../slither_web/web_slither as Snake
import ../agar_web/web_agar as Cells
import ../bar_bench_web/web_bar as Bar
import ../elements_web/web_elements as Elements
import ./social as Social

type Platform:
  Platform{tic: Tic::Game, snake: Snake::Game, cells: Cells::Game, social: Social::State}

type Outcome:
  Outcome{platform: Platform, response: Response}

def page_result(result: Result<String>) -> Response:
  match result:
    case Done{html}:
      HTTP::reply(200, "text/html; charset=utf-8", html)
    case Fail{code, error}:
      HTTP::reply(500, "text/plain; charset=utf-8", "page not found -- run from the repository root\n")

def page(path: String) -> IO<Response>:
  do IO<Response>:
    result : Result<String> <- IO::read_text(path)
    return page_result(result)

def index_page() -> IO<Response>:
  page("gabriel_demos/bendjogos_web/index.html")

def rewrite(request: Request, path: String) -> Request:
  match request:
    case Request{method, old_path, headers, body}:
      Request{method, path, headers, body}

def suffix(args: List<String>) -> String:
  String::concat("/", String::join("/", args))

def tic_out(routed: Tic::Routed, snake: Snake::Game, cells: Cells::Game, social: Social::State) -> Outcome:
  match routed:
    case Routed{game, response}:
      Outcome{Platform{game, snake, cells, social}, response}

def snake_out(routed: Snake::Routed, tic: Tic::Game, cells: Cells::Game, social: Social::State) -> Outcome:
  match routed:
    case Routed{game, response}:
      Outcome{Platform{tic, game, cells, social}, response}

def cells_out(routed: Cells::Routed, tic: Tic::Game, snake: Snake::Game, social: Social::State) -> Outcome:
  match routed:
    case Routed{game, response}:
      Outcome{Platform{tic, snake, game, social}, response}

def social_out(routed: Social::Routed, tic: Tic::Game, snake: Snake::Game, cells: Cells::Game) -> Outcome:
  match routed:
    case Routed{state, response}:
      Outcome{Platform{tic, snake, cells, state}, response}

def game_tic(request: Request, platform: Platform) -> IO<Outcome>:
  match platform:
    case Platform{tic, snake, cells, social}:
      do IO<Outcome>:
        routed : Tic::Routed <- Tic::request_route(request, tic)
        return tic_out(routed, snake, cells, social)

def game_snake(request: Request, platform: Platform, now: U32) -> IO<Outcome>:
  match platform:
    case Platform{tic, snake, cells, social}:
      do IO<Outcome>:
        routed : Snake::Routed <- Snake::request_route(request, Snake::game_advance(snake, now), now)
        return snake_out(routed, tic, cells, social)

def game_cells(request: Request, platform: Platform, now: U32) -> IO<Outcome>:
  match platform:
    case Platform{tic, snake, cells, social}:
      do IO<Outcome>:
        routed : Cells::Routed <- Cells::request_route(request, Cells::game_advance(cells, now), now)
        return cells_out(routed, tic, snake, social)

def game_social(request: Request, platform: Platform, now: U32) -> IO<Outcome>:
  match platform:
    case Platform{tic, snake, cells, social}:
      do IO<Outcome>:
        routed : Social::Routed <- Social::request_route(request, social, now)
        return social_out(routed, tic, snake, cells)

def static_route(name: String, args: List<String>, request: Request, platform: Platform, now: U32) -> IO<Outcome>:
  match String::eq(name, "snake"):
    case 0:
      match String::eq(name, "cells"):
        case 0:
          match String::eq(name, "tic"):
            case 0:
              match String::eq(name, "social"):
                case 0:
                  match String::eq(name, "bar"):
                    case 0:
                      match String::eq(name, "elements"):
                        case 0:
                          IO::pure<Outcome>(Outcome{platform, HTTP::not_found()})
                        case k6:
                          do IO<Outcome>:
                            response : Response <- Elements::route(rewrite(request, suffix(args)))
                            return Outcome{platform, response}
                    case k5:
                      do IO<Outcome>:
                        response : Response <- Bar::route(rewrite(request, suffix(args)))
                        return Outcome{platform, response}
                case k4:
                  game_social(request, platform, now)
            case k3:
              game_tic(rewrite(request, suffix(args)), platform)
        case k2:
          game_cells(rewrite(request, suffix(args)), platform, now)
    case k:
      game_snake(rewrite(request, suffix(args)), platform, now)

def route_parts(parts: List<String>, request: Request, platform: Platform, now: U32) -> IO<Outcome>:
  match parts:
    case Cons{root, Cons{"api", args}}:
      game_social(request, platform, now)
    case Cons{root, Cons{name, args}}:
      static_route(name, args, request, platform, now)
    case other:
      IO::pure<Outcome>(Outcome{platform, HTTP::not_found()})

def route(request: Request, platform: Platform, now: U32) -> IO<Outcome>:
  match request:
    case Request{method, path, headers, body}:
      match String::eq(path, "/"):
        case 0:
          match String::eq(path, "/games/balloon-defense"):
            case 0:
              match String::eq(path, "/social"):
                case 0:
                  match String::eq(path, "/games/helicopter"):
                    case 0:
                      route_parts(String::split('/', path), Request{method, path, headers, body}, platform, now)
                    case k3:
                      do IO<Outcome>:
                        response : Response <- page("gabriel_demos/bendjogos_web/games/helicopter.html")
                        return Outcome{platform, response}
                case k_social:
                  do IO<Outcome>:
                    response : Response <- page("gabriel_demos/bendjogos_web/social.html")
                    return Outcome{platform, response}
            case k2:
              do IO<Outcome>:
                response : Response <- page("gabriel_demos/bendjogos_web/games/balloon_defense.html")
                return Outcome{platform, response}
        case k:
          do IO<Outcome>:
            response : Response <- index_page()
            return Outcome{platform, response}

def outcome_send(outcome: Outcome, server: U32, conn: Conn) -> IO<U32>:
  match outcome:
    case Outcome{platform, response}:
      do IO<U32>:
        sent : Result<U32> <- HTTP::send_response(conn, HTTP::with_connection(0, response))
        closed : U32 <- HTTP::conn_close(conn)
        serve(server, platform)

def inbound_serve(inbound: Inbound, server: U32, conn: Conn, platform: Platform) -> IO<U32>:
  match inbound:
    case Got{http11, request, rest}:
      do IO<U32>:
        now : U32 <- Clock::clock_now_ms()
        outcome : Outcome <- route(request, platform, now)
        outcome_send(outcome, server, conn)
    case Closed{}:
      do IO<U32>:
        closed : U32 <- HTTP::conn_close(conn)
        serve(server, platform)
    case Bad{code, error}:
      outcome_send(Outcome{platform, HTTP::err_response(code, error)}, server, conn)

def accept_result(result: Result<U32>, server: U32, platform: Platform) -> IO<U32>:
  match result:
    case Done{fd}:
      do IO<U32>:
        inbound : Inbound <- HTTP::read_request(Plain{fd}, Nil{})
        inbound_serve(inbound, server, Plain{fd}, platform)
    case Fail{code, error}:
      do IO<U32>:
        printed : U32 <- IO::print_err(String::flatten(["accept failed: ", error, "\n"]))
        return 1

def serve(server: U32, platform: Platform) -> IO<U32>:
  do IO<U32>:
    result : Result<U32> <- TCP::accept(server)
    accept_result(result, server, platform)

def main() -> IO<U32>:
  do IO<U32>:
    now : U32 <- Clock::clock_now_ms()
    seed : U32 <- IO::rand()
    result : Result<U32> <- TCP::listen(8090)
    match result:
      case Done{server}:
        do IO<U32>:
          printed : U32 <- IO::print("BendJogos unified server listening on 0.0.0.0:8090\nopen http://<server-lan-ip>:8090\n")
          serve(server, Platform{Tic::game_empty(), Snake::game_empty(now, seed), Cells::game_empty(now, seed + 1), Social::empty()})
      case Fail{code, error}:
        do IO<U32>:
          printed : U32 <- IO::print_err(String::flatten(["listen failed: ", error, "\n"]))
          return 1
