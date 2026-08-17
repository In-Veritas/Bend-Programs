# Generated hub-private namespace from ../duck_hunt_web/web_duck_hunt.bend.
# Regenerate after changing the standalone source.

# Duck Hunt: a Bend-owned single-player light-gun game with a shared LAN high score.
#
# Routes:
#   GET /                         pixel-art browser game
#   GET /state/<player>          current hunt state
#   GET /start/<player>          begin a new ten-duck round
#   GET /shoot/<player>/<hit>/<band>
#                                 spend a shell; band 0..3 rewards accuracy
#   GET /next/<player>           advance after a hit or escaped duck
#   GET /leave/<player>          remove this browser's hunt
#
# Build:
#   bun bend-ts/src/bend.ts gabriel_demos/duck_hunt_web/web_duck_hunt.bend --no-halt -o gabriel_demos/duck_hunt_web/web_duck_hunt
#
# no-halt
# skip-native

import ../../../bend-base/Base
import ../../Compat
import ../../../bend-base/IO/TCP
import ../../../bend-base/IO/HTTP

type Duck.Player:
  Player{id: U32, score: U32, best: U32, round: U32, duck: U32, ammo: U32, round_hits: U32, total_hits: U32, status: U32, seed: U32}

type Duck.Found:
  Found{player: Duck.Player}
  Missing{}

type Duck.Game:
  Game{players: List(Duck.Player), high: U32, high_player: U32, tick: U32}

type Duck.Action:
  Action{game: Duck.Game, ok: U32, note: String}

type Duck.Routed:
  Routed{game: Duck.Game, response: HTTP.Response}

# ---------------------------------------------------------------- player

def Duck.u32_min(a: U32, b: U32) -> U32:
  match a < b:
    case 0:
      b
    case k:
      a

def Duck.u32_max(a: U32, b: U32) -> U32:
  match a > b:
    case 0:
      b
    case k:
      a

def Duck.u32_required(round: U32) -> U32:
  Duck.u32_min(8, 6 + ((round - 1) / 3))

def Duck.u32_points(band: U32, round: U32) -> U32:
  (450 + (Duck.u32_min(3, band) * 250)) + (round * 50)

def Duck.u32_high_player(score: U32, high: U32, id: U32, previous: U32) -> U32:
  match score > high:
    case 0:
      previous
    case k:
      id

def Duck.u32_shot_note(hit: U32, ammo: U32) -> String:
  match hit > 0:
    case 0:
      match ammo > 0:
        case 0:
          "Out of shells. The duck escaped."
        case k:
          "Miss. Track the flight and try again."
    case k:
      "Direct hit."

def Duck.player_idle(id: U32) -> Duck.Player:
  Duck.Player.Player{id, 0, 0, 1, 1, 3, 0, 0, 0, id}

def Duck.player_start(player: Duck.Player, seed: U32) -> Duck.Player:
  match player:
    case Duck.Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, old_seed}:
      Duck.Player.Player{id, 0, best, 1, 1, 3, 0, 0, 1, seed}

def Duck.player_shoot(player: Duck.Player, hit: U32, band: U32) -> Duck.Player:
  match player:
    case Duck.Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
      ammo2 = ammo - 1
      match hit > 0:
        case 0:
          match ammo2:
            case 0:
              Duck.Player.Player{id, score, best, round, duck, 0, round_hits, total_hits, 2, seed}
            case shells:
              Duck.Player.Player{id, score, best, round, duck, shells, round_hits, total_hits, 1, seed}
        case k:
          score2 = score + Duck.u32_points(band, round)
          Duck.Player.Player{id, score2, Duck.u32_max(best, score2), round, duck, ammo2, round_hits + 1, total_hits + 1, 2, seed}

def Duck.player_next_duck(player: Duck.Player, seed: U32) -> Duck.Player:
  match player:
    case Duck.Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, old_seed}:
      Duck.Player.Player{id, score, best, round, duck + 1, 3, round_hits, total_hits, 1, seed}

def Duck.player_next_round(player: Duck.Player, seed: U32) -> Duck.Player:
  match player:
    case Duck.Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, old_seed}:
      Duck.Player.Player{id, score, best, round + 1, 1, 3, 0, total_hits, 1, seed}

def Duck.player_game_over(player: Duck.Player) -> Duck.Player:
  match player:
    case Duck.Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
      Duck.Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, 3, seed}

def Duck.player_json(player: Duck.Player) -> String:
  match player:
    case Duck.Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
      String.flatten([
        "{\"id\":", String.from_u32(id),
        ",\"score\":", String.from_u32(score),
        ",\"best\":", String.from_u32(best),
        ",\"round\":", String.from_u32(round),
        ",\"duck\":", String.from_u32(duck),
        ",\"ammo\":", String.from_u32(ammo),
        ",\"roundHits\":", String.from_u32(round_hits),
        ",\"totalHits\":", String.from_u32(total_hits),
        ",\"status\":", String.from_u32(status),
        ",\"seed\":", String.from_u32(seed),
        ",\"required\":", String.from_u32(Duck.u32_required(round)),
        "}"
      ])

# ---------------------------------------------------------------- player list

def Duck.list_player_find(players: List(Duck.Player), id: U32) -> Duck.Found:
  match players:
    case List.Cons{head, tail}:
      match head:
        case Duck.Player.Player{stored, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
          match stored == id:
            case 0:
              Duck.list_player_find(tail, id)
            case k:
              Duck.Found.Found{Duck.Player.Player{stored, score, best, round, duck, ammo, round_hits, total_hits, status, seed}}
    case List.Nil{}:
      Duck.Found.Missing{}

def Duck.list_player_set(players: List(Duck.Player), player: Duck.Player) -> List(Duck.Player):
  match players:
    case List.Cons{head, tail}:
      match head:
        case Duck.Player.Player{stored, old_score, old_best, old_round, old_duck, old_ammo, old_round_hits, old_total_hits, old_status, old_seed}:
          match player:
            case Duck.Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
              match stored == id:
                case 0:
                  List.Cons{
                    Duck.Player.Player{stored, old_score, old_best, old_round, old_duck, old_ammo, old_round_hits, old_total_hits, old_status, old_seed},
                    Duck.list_player_set(tail, Duck.Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed})
                  }
                case k:
                  List.Cons{Duck.Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}, tail}
    case List.Nil{}:
      List.Cons{player, List.Nil{}}

def Duck.list_player_remove(players: List(Duck.Player), id: U32) -> List(Duck.Player):
  match players:
    case List.Nil{}:
      List.Nil{}
    case List.Cons{head, tail}:
      match head:
        case Duck.Player.Player{stored, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
          match stored == id:
            case 0:
              List.Cons{Duck.Player.Player{stored, score, best, round, duck, ammo, round_hits, total_hits, status, seed}, Duck.list_player_remove(tail, id)}
            case k:
              tail

# ---------------------------------------------------------------- game

def Duck.game_empty() -> Duck.Game:
  Duck.Game.Game{List.Nil{}, 0, 0, 1}

def Duck.game_error(game: Duck.Game, note: String) -> Duck.Action:
  Duck.Action.Action{game, 0, note}

def Duck.game_ok(game: Duck.Game, note: String) -> Duck.Action:
  Duck.Action.Action{game, 1, note}

def Duck.game_player(game: Duck.Game, id: U32) -> Duck.Player:
  match game:
    case Duck.Game.Game{players, high, high_player, tick}:
      match Duck.list_player_find(players, id):
        case Duck.Found.Found{player}:
          player
        case Duck.Found.Missing{}:
          Duck.player_idle(id)

def Duck.game_seed(id: U32, tick: U32) -> U32:
  ((id * 1664525) + (tick * 1013904223)) % 2147483647

def Duck.game_start(game: Duck.Game, id: U32) -> Duck.Action:
  match game:
    case Duck.Game.Game{players, high, high_player, tick}:
      match id > 0:
        case 0:
          Duck.game_error(Duck.Game.Game{players, high, high_player, tick}, "Invalid hunter identity.")
        case k:
          player = Duck.player_start(Duck.game_player(Duck.Game.Game{players, high, high_player, tick}, id), Duck.game_seed(id, tick))
          Duck.game_ok(Duck.Game.Game{Duck.list_player_set(players, player), high, high_player, tick + 1}, "Round one. Ten ducks. Make every shell count.")

def Duck.game_shoot_active(game: Duck.Game, player: Duck.Player, hit: U32, band: U32) -> Duck.Action:
  match game:
    case Duck.Game.Game{players, high, high_player, tick}:
      match player:
        case Duck.Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
          match ammo:
            case 0:
              Duck.game_error(Duck.Game.Game{players, high, high_player, tick}, "No shells remain for this duck.")
            case shells:
              shot = Duck.player_shoot(Duck.Player.Player{id, score, best, round, duck, shells, round_hits, total_hits, status, seed}, hit, band)
              match shot:
                case Duck.Player.Player{shot_id, shot_score, shot_best, shot_round, shot_duck, shot_ammo, shot_round_hits, shot_total_hits, shot_status, shot_seed}:
                  high2 = Duck.u32_max(high, shot_score)
                  high_player2 = Duck.u32_high_player(shot_score, high, shot_id, high_player)
                  note = Duck.u32_shot_note(hit, shot_ammo)
                  Duck.game_ok(Duck.Game.Game{Duck.list_player_set(players, shot), high2, high_player2, tick + 1}, note)

def Duck.game_shoot(game: Duck.Game, id: U32, hit: U32, band: U32) -> Duck.Action:
  match game:
    case Duck.Game.Game{players, high, high_player, tick}:
      match Duck.list_player_find(players, id):
        case Duck.Found.Missing{}:
          Duck.game_error(Duck.Game.Game{players, high, high_player, tick}, "Start a hunt before shooting.")
        case Duck.Found.Found{player}:
          match player:
            case Duck.Player.Player{stored, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
              match status == 1:
                case 0:
                  Duck.game_error(Duck.Game.Game{players, high, high_player, tick}, "Wait for the next duck.")
                case k:
                  Duck.game_shoot_active(Duck.Game.Game{players, high, high_player, tick}, Duck.Player.Player{stored, score, best, round, duck, ammo, round_hits, total_hits, status, seed}, hit, band)

def Duck.game_next_resolved(game: Duck.Game, player: Duck.Player) -> Duck.Action:
  match game:
    case Duck.Game.Game{players, high, high_player, tick}:
      match player:
        case Duck.Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
          seed2 = Duck.game_seed(id, tick)
          match duck < 10:
            case 0:
              match round_hits >= Duck.u32_required(round):
                case 0:
                  over = Duck.player_game_over(Duck.Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed})
                  Duck.game_ok(Duck.Game.Game{Duck.list_player_set(players, over), high, high_player, tick + 1}, "The dog closes the book on this hunt.")
                case k:
                  advanced = Duck.player_next_round(Duck.Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}, seed2)
                  Duck.game_ok(Duck.Game.Game{Duck.list_player_set(players, advanced), high, high_player, tick + 1}, "Round clear. The next flock is faster.")
            case k:
              advanced = Duck.player_next_duck(Duck.Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}, seed2)
              Duck.game_ok(Duck.Game.Game{Duck.list_player_set(players, advanced), high, high_player, tick + 1}, "Next duck.")

def Duck.game_next(game: Duck.Game, id: U32) -> Duck.Action:
  match game:
    case Duck.Game.Game{players, high, high_player, tick}:
      match Duck.list_player_find(players, id):
        case Duck.Found.Missing{}:
          Duck.game_error(Duck.Game.Game{players, high, high_player, tick}, "Start a hunt first.")
        case Duck.Found.Found{player}:
          match player:
            case Duck.Player.Player{stored, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
              match status == 2:
                case 0:
                  Duck.game_error(Duck.Game.Game{players, high, high_player, tick}, "This duck is still in flight.")
                case k:
                  Duck.game_next_resolved(Duck.Game.Game{players, high, high_player, tick}, Duck.Player.Player{stored, score, best, round, duck, ammo, round_hits, total_hits, status, seed})

def Duck.game_leave(game: Duck.Game, id: U32) -> Duck.Action:
  match game:
    case Duck.Game.Game{players, high, high_player, tick}:
      Duck.game_ok(Duck.Game.Game{Duck.list_player_remove(players, id), high, high_player, tick + 1}, "")

# ---------------------------------------------------------------- json and routing

def Duck.game_json(game: Duck.Game, id: U32, ok: U32, note: String) -> String:
  match game:
    case Duck.Game.Game{players, high, high_player, tick}:
      String.flatten([
        "{\"ok\":", String.from_u32(ok),
        ",\"note\":\"", note,
        "\",\"high\":", String.from_u32(high),
        ",\"highPlayer\":", String.from_u32(high_player),
        ",\"tick\":", String.from_u32(tick),
        ",\"player\":", Duck.player_json(Duck.game_player(Duck.Game.Game{players, high, high_player, tick}, id)),
        "}"
      ])

def Duck.game_response(game: Duck.Game, id: U32, ok: U32, note: String) -> HTTP.Response:
  HTTP.Response.Response{200,
    [HTTP.Header.Header{"Content-Type", "application/json; charset=utf-8"},
     HTTP.Header.Header{"Cache-Control", "no-store, no-cache, must-revalidate"}],
    Bytes.from_string(Duck.game_json(game, id, ok, note))}

def Duck.game_routed(game: Duck.Game, id: U32) -> Duck.Routed:
  Duck.Routed.Routed{game, Duck.game_response(game, id, 1, "")}

def Duck.game_missing(game: Duck.Game) -> Duck.Routed:
  Duck.Routed.Routed{game, HTTP.not_found()}

def Duck.game_method(game: Duck.Game) -> Duck.Routed:
  Duck.Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")}

def Duck.action_routed(action: Duck.Action, id: U32) -> Duck.Routed:
  match action:
    case Duck.Action.Action{game, ok, note}:
      Duck.Routed.Routed{game, Duck.game_response(game, id, ok, note)}

def Duck.result_index(result: Result((U32 & String), String), game: Duck.Game) -> IO(Duck.Routed):
  match result:
    case Result.Done{html}:
      IO.pure(Duck.Routed, Duck.Routed.Routed{game, HTTP.reply(200, "text/html; charset=utf-8", html)})
    case Result.Fail{(code, error)}:
      IO.pure(Duck.Routed, Duck.Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run from the repository root\n")})

def Duck.game_index(game: Duck.Game) -> IO(Duck.Routed):
  do IO(Duck.Routed):
    result <- IO.read_text("gabriel_demos/duck_hunt_web/index.html")
    Duck.result_index(result, game)

def Duck.list_state(args: List(String), game: Duck.Game) -> IO(Duck.Routed):
  match args:
    case List.Cons{id, rest}:
      IO.pure(Duck.Routed, Duck.game_routed(game, String.to_u32(id)))
    case List.Nil{}:
      IO.pure(Duck.Routed, Duck.game_missing(game))

def Duck.list_start(args: List(String), game: Duck.Game) -> IO(Duck.Routed):
  match args:
    case List.Cons{id, rest}:
      player = String.to_u32(id)
      IO.pure(Duck.Routed, Duck.action_routed(Duck.game_start(game, player), player))
    case List.Nil{}:
      IO.pure(Duck.Routed, Duck.game_missing(game))

def Duck.list_shoot(args: List(String), game: Duck.Game) -> IO(Duck.Routed):
  match args:
    case List.Cons{id, List.Cons{hit, List.Cons{band, rest}}}:
      player = String.to_u32(id)
      IO.pure(Duck.Routed, Duck.action_routed(Duck.game_shoot(game, player, String.to_u32(hit), String.to_u32(band)), player))
    case other:
      IO.pure(Duck.Routed, Duck.game_missing(game))

def Duck.list_next(args: List(String), game: Duck.Game) -> IO(Duck.Routed):
  match args:
    case List.Cons{id, rest}:
      player = String.to_u32(id)
      IO.pure(Duck.Routed, Duck.action_routed(Duck.game_next(game, player), player))
    case List.Nil{}:
      IO.pure(Duck.Routed, Duck.game_missing(game))

def Duck.list_leave(args: List(String), game: Duck.Game) -> IO(Duck.Routed):
  match args:
    case List.Cons{id, rest}:
      player = String.to_u32(id)
      IO.pure(Duck.Routed, Duck.action_routed(Duck.game_leave(game, player), player))
    case List.Nil{}:
      IO.pure(Duck.Routed, Duck.game_missing(game))

def Duck.string_route(name: String, args: List(String), game: Duck.Game) -> IO(Duck.Routed):
  match String.eq_u32(name, ""):
    case 0:
      match String.eq_u32(name, "state"):
        case 0:
          match String.eq_u32(name, "start"):
            case 0:
              match String.eq_u32(name, "shoot"):
                case 0:
                  match String.eq_u32(name, "next"):
                    case 0:
                      match String.eq_u32(name, "leave"):
                        case 0:
                          IO.pure(Duck.Routed, Duck.game_missing(game))
                        case k5:
                          Duck.list_leave(args, game)
                    case k4:
                      Duck.list_next(args, game)
                case k3:
                  Duck.list_shoot(args, game)
            case k2:
              Duck.list_start(args, game)
        case k1:
          Duck.list_state(args, game)
    case root:
      Duck.game_index(game)

def Duck.list_route(parts: List(String), game: Duck.Game) -> IO(Duck.Routed):
  match parts:
    case List.Cons{root, List.Cons{name, args}}:
      Duck.string_route(name, args, game)
    case List.Cons{root, List.Nil{}}:
      Duck.game_index(game)
    case List.Nil{}:
      Duck.game_index(game)

def Duck.request_route(request: HTTP.Request, game: Duck.Game) -> IO(Duck.Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(method, "GET"):
        case 0:
          IO.pure(Duck.Routed, Duck.game_method(game))
        case k:
          Duck.list_route(String.split('/', path), game)

# ---------------------------------------------------------------- server

def Duck.routed_send(routed: Duck.Routed, server: TCP, conn: HTTP) -> IO(U32):
  match routed:
    case Duck.Routed.Routed{game, response}:
      do IO(U32):
        sent <- HTTP.send_response(conn, HTTP.with_connection(0, response))
        closed <- HTTP.close(conn)
        Duck.u32_serve(server, game)

def Duck.inbound_serve(inbound: HTTP.Inbound, server: TCP, conn: HTTP, game: Duck.Game) -> IO(U32):
  match inbound:
    case HTTP.Inbound.Got{http11, request, rest}:
      do IO(U32):
        routed <- Duck.request_route(request, game)
        Duck.routed_send(routed, server, conn)
    case HTTP.Inbound.Closed{}:
      do IO(U32):
        closed <- HTTP.close(conn)
        Duck.u32_serve(server, game)
    case HTTP.Inbound.Bad{code, error}:
      Duck.routed_send(Duck.Routed.Routed{game, HTTP.reply_error(code, error)}, server, conn)

def Duck.result_accept(result: Result((U32 & String), TCP), server: TCP, game: Duck.Game) -> IO(U32):
  match result:
    case Result.Done{fd}:
      do IO(U32):
        inbound <- HTTP.recv_request(HTTP.Plain{fd}, List.Nil{})
        Duck.inbound_serve(inbound, server, HTTP.Plain{fd}, game)
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["accept failed: ", error, "\n"]))
        return 1

def Duck.u32_serve(server: TCP, game: Duck.Game) -> IO(U32):
  do IO(U32):
    result <- TCP.accept(server)
    Duck.result_accept(result, server, game)

def Duck.result_main(result: Result((U32 & String), TCP)) -> IO(U32):
  match result:
    case Result.Done{server}:
      do IO(U32):
        printed <- IO.write("Duck Hunt listening on all interfaces (0.0.0.0:8089)\nopen http://<server-lan-ip>:8089\n")
        Duck.u32_serve(server, Duck.game_empty())
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def Duck.main() -> IO(U32):
  do IO(U32):
    result <- TCP.listen(8089)
    Duck.result_main(result)
