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

import ../../bend-base/Base
import ../Compat
import ../../bend-base/IO/TCP
import ../../bend-base/IO/HTTP

type Player:
  Player{id: U32, score: U32, best: U32, round: U32, duck: U32, ammo: U32, round_hits: U32, total_hits: U32, status: U32, seed: U32}

type Found:
  Found{player: Player}
  Missing{}

type Game:
  Game{players: List(Player), high: U32, high_player: U32, tick: U32}

type Action:
  Action{game: Game, ok: U32, note: String}

type Routed:
  Routed{game: Game, response: HTTP.Response}

# ---------------------------------------------------------------- player

def u32_min(a: U32, b: U32) -> U32:
  match a < b:
    case 0:
      b
    case k:
      a

def u32_max(a: U32, b: U32) -> U32:
  match a > b:
    case 0:
      b
    case k:
      a

def u32_required(round: U32) -> U32:
  u32_min(8, 6 + ((round - 1) / 3))

def u32_points(band: U32, round: U32) -> U32:
  (450 + (u32_min(3, band) * 250)) + (round * 50)

def u32_high_player(score: U32, high: U32, id: U32, previous: U32) -> U32:
  match score > high:
    case 0:
      previous
    case k:
      id

def u32_shot_note(hit: U32, ammo: U32) -> String:
  match hit > 0:
    case 0:
      match ammo > 0:
        case 0:
          "Out of shells. The duck escaped."
        case k:
          "Miss. Track the flight and try again."
    case k:
      "Direct hit."

def player_idle(id: U32) -> Player:
  Player.Player{id, 0, 0, 1, 1, 3, 0, 0, 0, id}

def player_start(player: Player, seed: U32) -> Player:
  match player:
    case Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, old_seed}:
      Player.Player{id, 0, best, 1, 1, 3, 0, 0, 1, seed}

def player_shoot(player: Player, hit: U32, band: U32) -> Player:
  match player:
    case Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
      ammo2 = ammo - 1
      match hit > 0:
        case 0:
          match ammo2:
            case 0:
              Player.Player{id, score, best, round, duck, 0, round_hits, total_hits, 2, seed}
            case shells:
              Player.Player{id, score, best, round, duck, shells, round_hits, total_hits, 1, seed}
        case k:
          score2 = score + u32_points(band, round)
          Player.Player{id, score2, u32_max(best, score2), round, duck, ammo2, round_hits + 1, total_hits + 1, 2, seed}

def player_next_duck(player: Player, seed: U32) -> Player:
  match player:
    case Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, old_seed}:
      Player.Player{id, score, best, round, duck + 1, 3, round_hits, total_hits, 1, seed}

def player_next_round(player: Player, seed: U32) -> Player:
  match player:
    case Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, old_seed}:
      Player.Player{id, score, best, round + 1, 1, 3, 0, total_hits, 1, seed}

def player_game_over(player: Player) -> Player:
  match player:
    case Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
      Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, 3, seed}

def player_json(player: Player) -> String:
  match player:
    case Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
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
        ",\"required\":", String.from_u32(u32_required(round)),
        "}"
      ])

# ---------------------------------------------------------------- player list

def list_player_find(players: List(Player), id: U32) -> Found:
  match players:
    case List.Cons{head, tail}:
      match head:
        case Player.Player{stored, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
          match stored == id:
            case 0:
              list_player_find(tail, id)
            case k:
              Found.Found{Player.Player{stored, score, best, round, duck, ammo, round_hits, total_hits, status, seed}}
    case List.Nil{}:
      Found.Missing{}

def list_player_set(players: List(Player), player: Player) -> List(Player):
  match players:
    case List.Cons{head, tail}:
      match head:
        case Player.Player{stored, old_score, old_best, old_round, old_duck, old_ammo, old_round_hits, old_total_hits, old_status, old_seed}:
          match player:
            case Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
              match stored == id:
                case 0:
                  List.Cons{
                    Player.Player{stored, old_score, old_best, old_round, old_duck, old_ammo, old_round_hits, old_total_hits, old_status, old_seed},
                    list_player_set(tail, Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed})
                  }
                case k:
                  List.Cons{Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}, tail}
    case List.Nil{}:
      List.Cons{player, List.Nil{}}

def list_player_remove(players: List(Player), id: U32) -> List(Player):
  match players:
    case List.Nil{}:
      List.Nil{}
    case List.Cons{head, tail}:
      match head:
        case Player.Player{stored, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
          match stored == id:
            case 0:
              List.Cons{Player.Player{stored, score, best, round, duck, ammo, round_hits, total_hits, status, seed}, list_player_remove(tail, id)}
            case k:
              tail

# ---------------------------------------------------------------- game

def game_empty() -> Game:
  Game.Game{List.Nil{}, 0, 0, 1}

def game_error(game: Game, note: String) -> Action:
  Action.Action{game, 0, note}

def game_ok(game: Game, note: String) -> Action:
  Action.Action{game, 1, note}

def game_player(game: Game, id: U32) -> Player:
  match game:
    case Game.Game{players, high, high_player, tick}:
      match list_player_find(players, id):
        case Found.Found{player}:
          player
        case Found.Missing{}:
          player_idle(id)

def game_seed(id: U32, tick: U32) -> U32:
  ((id * 1664525) + (tick * 1013904223)) % 2147483647

def game_start(game: Game, id: U32) -> Action:
  match game:
    case Game.Game{players, high, high_player, tick}:
      match id > 0:
        case 0:
          game_error(Game.Game{players, high, high_player, tick}, "Invalid hunter identity.")
        case k:
          player = player_start(game_player(Game.Game{players, high, high_player, tick}, id), game_seed(id, tick))
          game_ok(Game.Game{list_player_set(players, player), high, high_player, tick + 1}, "Round one. Ten ducks. Make every shell count.")

def game_shoot_active(game: Game, player: Player, hit: U32, band: U32) -> Action:
  match game:
    case Game.Game{players, high, high_player, tick}:
      match player:
        case Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
          match ammo:
            case 0:
              game_error(Game.Game{players, high, high_player, tick}, "No shells remain for this duck.")
            case shells:
              shot = player_shoot(Player.Player{id, score, best, round, duck, shells, round_hits, total_hits, status, seed}, hit, band)
              match shot:
                case Player.Player{shot_id, shot_score, shot_best, shot_round, shot_duck, shot_ammo, shot_round_hits, shot_total_hits, shot_status, shot_seed}:
                  high2 = u32_max(high, shot_score)
                  high_player2 = u32_high_player(shot_score, high, shot_id, high_player)
                  note = u32_shot_note(hit, shot_ammo)
                  game_ok(Game.Game{list_player_set(players, shot), high2, high_player2, tick + 1}, note)

def game_shoot(game: Game, id: U32, hit: U32, band: U32) -> Action:
  match game:
    case Game.Game{players, high, high_player, tick}:
      match list_player_find(players, id):
        case Found.Missing{}:
          game_error(Game.Game{players, high, high_player, tick}, "Start a hunt before shooting.")
        case Found.Found{player}:
          match player:
            case Player.Player{stored, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
              match status == 1:
                case 0:
                  game_error(Game.Game{players, high, high_player, tick}, "Wait for the next duck.")
                case k:
                  game_shoot_active(Game.Game{players, high, high_player, tick}, Player.Player{stored, score, best, round, duck, ammo, round_hits, total_hits, status, seed}, hit, band)

def game_next_resolved(game: Game, player: Player) -> Action:
  match game:
    case Game.Game{players, high, high_player, tick}:
      match player:
        case Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
          seed2 = game_seed(id, tick)
          match duck < 10:
            case 0:
              match round_hits >= u32_required(round):
                case 0:
                  over = player_game_over(Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed})
                  game_ok(Game.Game{list_player_set(players, over), high, high_player, tick + 1}, "The dog closes the book on this hunt.")
                case k:
                  advanced = player_next_round(Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}, seed2)
                  game_ok(Game.Game{list_player_set(players, advanced), high, high_player, tick + 1}, "Round clear. The next flock is faster.")
            case k:
              advanced = player_next_duck(Player.Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}, seed2)
              game_ok(Game.Game{list_player_set(players, advanced), high, high_player, tick + 1}, "Next duck.")

def game_next(game: Game, id: U32) -> Action:
  match game:
    case Game.Game{players, high, high_player, tick}:
      match list_player_find(players, id):
        case Found.Missing{}:
          game_error(Game.Game{players, high, high_player, tick}, "Start a hunt first.")
        case Found.Found{player}:
          match player:
            case Player.Player{stored, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
              match status == 2:
                case 0:
                  game_error(Game.Game{players, high, high_player, tick}, "This duck is still in flight.")
                case k:
                  game_next_resolved(Game.Game{players, high, high_player, tick}, Player.Player{stored, score, best, round, duck, ammo, round_hits, total_hits, status, seed})

def game_leave(game: Game, id: U32) -> Action:
  match game:
    case Game.Game{players, high, high_player, tick}:
      game_ok(Game.Game{list_player_remove(players, id), high, high_player, tick + 1}, "")

# ---------------------------------------------------------------- json and routing

def game_json(game: Game, id: U32, ok: U32, note: String) -> String:
  match game:
    case Game.Game{players, high, high_player, tick}:
      String.flatten([
        "{\"ok\":", String.from_u32(ok),
        ",\"note\":\"", note,
        "\",\"high\":", String.from_u32(high),
        ",\"highPlayer\":", String.from_u32(high_player),
        ",\"tick\":", String.from_u32(tick),
        ",\"player\":", player_json(game_player(Game.Game{players, high, high_player, tick}, id)),
        "}"
      ])

def game_response(game: Game, id: U32, ok: U32, note: String) -> HTTP.Response:
  HTTP.Response.Response{200,
    [HTTP.Header.Header{"Content-Type", "application/json; charset=utf-8"},
     HTTP.Header.Header{"Cache-Control", "no-store, no-cache, must-revalidate"}],
    Bytes.from_string(game_json(game, id, ok, note))}

def game_routed(game: Game, id: U32) -> Routed:
  Routed.Routed{game, game_response(game, id, 1, "")}

def game_missing(game: Game) -> Routed:
  Routed.Routed{game, HTTP.not_found()}

def game_method(game: Game) -> Routed:
  Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")}

def action_routed(action: Action, id: U32) -> Routed:
  match action:
    case Action.Action{game, ok, note}:
      Routed.Routed{game, game_response(game, id, ok, note)}

def result_index(result: Result((U32 & String), String), game: Game) -> IO(Routed):
  match result:
    case Result.Done{html}:
      IO.pure(Routed, Routed.Routed{game, HTTP.reply(200, "text/html; charset=utf-8", html)})
    case Result.Fail{(code, error)}:
      IO.pure(Routed, Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run from the repository root\n")})

def game_index(game: Game) -> IO(Routed):
  do IO(Routed):
    result <- IO.read_text("gabriel_demos/duck_hunt_web/index.html")
    result_index(result, game)

def list_state(args: List(String), game: Game) -> IO(Routed):
  match args:
    case List.Cons{id, rest}:
      IO.pure(Routed, game_routed(game, String.to_u32(id)))
    case List.Nil{}:
      IO.pure(Routed, game_missing(game))

def list_start(args: List(String), game: Game) -> IO(Routed):
  match args:
    case List.Cons{id, rest}:
      player = String.to_u32(id)
      IO.pure(Routed, action_routed(game_start(game, player), player))
    case List.Nil{}:
      IO.pure(Routed, game_missing(game))

def list_shoot(args: List(String), game: Game) -> IO(Routed):
  match args:
    case List.Cons{id, List.Cons{hit, List.Cons{band, rest}}}:
      player = String.to_u32(id)
      IO.pure(Routed, action_routed(game_shoot(game, player, String.to_u32(hit), String.to_u32(band)), player))
    case other:
      IO.pure(Routed, game_missing(game))

def list_next(args: List(String), game: Game) -> IO(Routed):
  match args:
    case List.Cons{id, rest}:
      player = String.to_u32(id)
      IO.pure(Routed, action_routed(game_next(game, player), player))
    case List.Nil{}:
      IO.pure(Routed, game_missing(game))

def list_leave(args: List(String), game: Game) -> IO(Routed):
  match args:
    case List.Cons{id, rest}:
      player = String.to_u32(id)
      IO.pure(Routed, action_routed(game_leave(game, player), player))
    case List.Nil{}:
      IO.pure(Routed, game_missing(game))

def string_route(name: String, args: List(String), game: Game) -> IO(Routed):
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
                          IO.pure(Routed, game_missing(game))
                        case k5:
                          list_leave(args, game)
                    case k4:
                      list_next(args, game)
                case k3:
                  list_shoot(args, game)
            case k2:
              list_start(args, game)
        case k1:
          list_state(args, game)
    case root:
      game_index(game)

def list_route(parts: List(String), game: Game) -> IO(Routed):
  match parts:
    case List.Cons{root, List.Cons{name, args}}:
      string_route(name, args, game)
    case List.Cons{root, List.Nil{}}:
      game_index(game)
    case List.Nil{}:
      game_index(game)

def request_route(request: HTTP.Request, game: Game) -> IO(Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(method, "GET"):
        case 0:
          IO.pure(Routed, game_method(game))
        case k:
          list_route(String.split('/', path), game)

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
        printed <- IO.write("Duck Hunt listening on all interfaces (0.0.0.0:8089)\nopen http://<server-lan-ip>:8089\n")
        u32_serve(server, game_empty())
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def main() -> IO(U32):
  do IO(U32):
    result <- TCP.listen(8089)
    result_main(result)
