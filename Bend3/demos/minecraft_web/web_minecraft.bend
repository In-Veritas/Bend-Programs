# Block World: a compact multiplayer voxel sandbox over the local network.
#
# Bend owns the shared column world, four player slots, movement, mining, and
# placement. The browser renders a short-range isometric view.
#
# routes:
#   GET /                              page
#   GET /state/<player>               shared snapshot
#   GET /join/<player>                take an available slot
#   GET /move/<player>/<direction>    move north/east/south/west (0..3)
#   GET /mine/<player>/<x>/<z>        remove a nearby top block
#   GET /place/<player>/<x>/<z>/<kind> place grass/dirt/stone/wood/leaves (1..5)
#   GET /leave/<player>               release the slot
#
# build: bun bend-ts/src/bend.ts gabriel_demos/minecraft_web/web_minecraft.bend --no-halt -o gabriel_demos/minecraft_web/web_minecraft
# run:   ./gabriel_demos/minecraft_web/web_minecraft
# open:  http://<server-lan-ip>:8085
#
# no-halt
# skip-native

import ../../bend-base/Base
import ../Compat
import ../../bend-base/IO/TCP
import ../../bend-base/IO/HTTP
import ../Clock as Clock

def world_size() -> U32: 24
def render_distance() -> U32: 6
def player_timeout() -> U32: 30000
def max_height() -> U32: 9

type Column:
  Column{height: U32, block: U32, ground: U32}

type Player:
  Player{slot: U32, id: U32, joined: U32, x: U32, z: U32, seen: U32}

type Game:
  Game{world: List(Column), one: Player, two: Player, three: Player, four: Player, tick: U32}

type Action:
  Action{game: Game, ok: U32, note: String}

type Routed:
  Routed{game: Game, response: HTTP.Response}

# ---------------------------------------------------------------- U32

def u32_abs_diff(a: U32, b: U32) -> U32:
  match a < b:
    case 0:
      a - b
    case k:
      b - a

def u32_near(x: U32, z: U32, other_x: U32, other_z: U32) -> U32:
  (u32_abs_diff(x, other_x) + u32_abs_diff(z, other_z)) <= 3

def u32_ground(x: U32, z: U32) -> U32:
  2 + ((((x * 13) + (z * 7)) + (x * z)) % 3)

def u32_tree(x: U32, z: U32, cx: U32, cz: U32) -> U32:
  (x == cx) && (z == cz)

def u32_canopy(x: U32, z: U32, cx: U32, cz: U32) -> U32:
  (u32_abs_diff(x, cx) <= 1) && (u32_abs_diff(z, cz) <= 1)

def u32_tree_any(x: U32, z: U32) -> U32:
  u32_tree(x, z, 6, 6) || (u32_tree(x, z, 17, 8) || u32_tree(x, z, 9, 17))

def u32_canopy_any(x: U32, z: U32) -> U32:
  u32_canopy(x, z, 6, 6) || (u32_canopy(x, z, 17, 8) || u32_canopy(x, z, 9, 17))

def u32_layer(height: U32, ground: U32) -> U32:
  match height == ground:
    case 0:
      match (height + 1) >= ground:
        case 0:
          3
        case k:
          2
    case k:
      1

def u32_prev(value: U32) -> U32:
  match value:
    case 0:
      0
    case k:
      k - 1

def u32_next(value: U32) -> U32:
  match value:
    case 23:
      23
    case k:
      k + 1

# ---------------------------------------------------------------- Column

def column_make(x: U32, z: U32) -> Column:
  ground = u32_ground(x, z)
  match u32_tree_any(x, z):
    case 0:
      match u32_canopy_any(x, z):
        case 0:
          Column.Column{ground, 1, ground}
        case k:
          Column.Column{ground + 2, 5, ground}
    case k:
      Column.Column{ground + 3, 4, ground}

def column_mine(column: Column) -> Column:
  match column:
    case Column.Column{height, block, ground}:
      match height:
        case 0:
          Column.Column{0, 0, ground}
        case h:
          next = h - 1
          match h > ground:
            case 0:
              match next:
                case 0:
                  Column.Column{0, 0, ground}
                case n:
                  Column.Column{n, u32_layer(n, ground), ground}
            case k:
              match block == 5:
                case 0:
                  match next > ground:
                    case 0:
                      Column.Column{ground, 1, ground}
                    case j:
                      Column.Column{next, 4, ground}
                case j:
                  Column.Column{ground, 1, ground}

def column_place(column: Column, block: U32) -> Column:
  match column:
    case Column.Column{height, old, ground}:
      match (block > 0) && ((block <= 5) && (height < max_height())):
        case 0:
          Column.Column{height, old, ground}
        case k:
          Column.Column{height + 1, block, ground}

def column_json(column: Column) -> String:
  match column:
    case Column.Column{height, block, ground}:
      String.flatten(["[", String.from_u32(height), ",", String.from_u32(block), "]"])

# ---------------------------------------------------------------- List

def list_world(left: U32, index: U32) -> List(Column):
  match left:
    case 0:
      List.Nil{}
    case k:
      x = index % world_size()
      z = index / world_size()
      List.Cons{column_make(x, z), list_world(k - 1, index + 1)}

def list_column_get(columns: List(Column), index: U32) -> Column:
  match columns:
    case List.Cons{head, tail}:
      match index:
        case 0:
          head
        case k:
          list_column_get(tail, k - 1)
    case List.Nil{}:
      Column.Column{0, 0, 0}

def list_column_set(columns: List(Column), index: U32, column: Column) -> List(Column):
  match columns:
    case List.Cons{head, tail}:
      match index:
        case 0:
          List.Cons{column, tail}
        case k:
          List.Cons{head, list_column_set(tail, k - 1, column)}
    case List.Nil{}:
      List.Nil{}

def list_world_json(columns: List(Column)) -> String:
  match columns:
    case List.Cons{head, List.Nil{}}:
      String.concat(column_json(head), "]")
    case List.Cons{head, tail}:
      String.concat(column_json(head), String.concat(",", list_world_json(tail)))
    case List.Nil{}:
      "]"

# ---------------------------------------------------------------- Player

def player_empty(slot: U32) -> Player:
  Player.Player{slot, 0, 0, 0, 0, 0}

def player_spawn(slot: U32, id: U32, now: U32) -> Player:
  match slot:
    case 1:
      Player.Player{1, id, 1, 11, 11, now}
    case 2:
      Player.Player{2, id, 1, 13, 11, now}
    case 3:
      Player.Player{3, id, 1, 11, 13, now}
    case other:
      Player.Player{4, id, 1, 13, 13, now}

def player_active(player: Player, now: U32) -> U32:
  match player:
    case Player.Player{slot, id, joined, x, z, seen}:
      joined && ((now - seen) < player_timeout())

def player_owner(player: Player, id: U32, now: U32) -> U32:
  match player:
    case Player.Player{slot, stored, joined, x, z, seen}:
      (id > 0) && ((stored == id) && player_active(Player.Player{slot, stored, joined, x, z, seen}, now))

def player_touch(player: Player, now: U32) -> Player:
  match player:
    case Player.Player{slot, id, joined, x, z, seen}:
      Player.Player{slot, id, joined, x, z, now}

def player_move(player: Player, direction: U32, now: U32) -> Player:
  match player:
    case Player.Player{slot, id, joined, x, z, seen}:
      match direction % 4:
        case 0:
          Player.Player{slot, id, joined, x, u32_prev(z), now}
        case 1:
          Player.Player{slot, id, joined, u32_next(x), z, now}
        case 2:
          Player.Player{slot, id, joined, x, u32_next(z), now}
        case other:
          Player.Player{slot, id, joined, u32_prev(x), z, now}

def player_json(player: Player, now: U32) -> String:
  match player:
    case Player.Player{slot, id, joined, x, z, seen}:
      String.flatten([
        "{\"slot\":", String.from_u32(slot),
        ",\"joined\":", String.from_u32(player_active(Player.Player{slot, id, joined, x, z, seen}, now)),
        ",\"x\":", String.from_u32(x),
        ",\"z\":", String.from_u32(z), "}"
      ])

# ---------------------------------------------------------------- Game

def game_empty() -> Game:
  Game.Game{list_world(world_size() * world_size(), 0), player_empty(1), player_empty(2), player_empty(3), player_empty(4), 1}

def game_slot(game: Game, id: U32, now: U32) -> U32:
  match game:
    case Game.Game{world, one, two, three, four, tick}:
      match player_owner(one, id, now):
        case 0:
          match player_owner(two, id, now):
            case 0:
              match player_owner(three, id, now):
                case 0:
                  match player_owner(four, id, now):
                    case 0:
                      0
                    case k:
                      4
                case k:
                  3
            case k:
              2
        case k:
          1

def game_player(game: Game, slot: U32) -> Player:
  match game:
    case Game.Game{world, one, two, three, four, tick}:
      match slot:
        case 1:
          one
        case 2:
          two
        case 3:
          three
        case other:
          four

def game_player_set(game: Game, slot: U32, player: Player) -> Game:
  match game:
    case Game.Game{world, one, two, three, four, tick}:
      match slot:
        case 1:
          Game.Game{world, player, two, three, four, tick + 1}
        case 2:
          Game.Game{world, one, player, three, four, tick + 1}
        case 3:
          Game.Game{world, one, two, player, four, tick + 1}
        case other:
          Game.Game{world, one, two, three, player, tick + 1}

def game_ok(game: Game) -> Action:
  Action.Action{game, 1, ""}

def game_error(game: Game, note: String) -> Action:
  Action.Action{game, 0, note}

def game_state(game: Game, id: U32, now: U32) -> Game:
  slot = game_slot(game, id, now)
  match slot:
    case 0:
      game
    case own:
      game_player_set(game, own, player_touch(game_player(game, own), now))

def game_join_new(game: Game, id: U32, now: U32) -> Action:
  match game:
    case Game.Game{world, one, two, three, four, tick}:
      match player_active(one, now):
        case 0:
          game_ok(Game.Game{world, player_spawn(1, id, now), two, three, four, tick + 1})
        case k:
          match player_active(two, now):
            case 0:
              game_ok(Game.Game{world, one, player_spawn(2, id, now), three, four, tick + 1})
            case j:
              match player_active(three, now):
                case 0:
                  game_ok(Game.Game{world, one, two, player_spawn(3, id, now), four, tick + 1})
                case q:
                  match player_active(four, now):
                    case 0:
                      game_ok(Game.Game{world, one, two, three, player_spawn(4, id, now), tick + 1})
                    case p:
                      game_error(Game.Game{world, one, two, three, four, tick}, "The world already has four active players.")

def game_join(game: Game, id: U32, now: U32) -> Action:
  match id:
    case 0:
      game_error(game, "Invalid player identity.")
    case valid:
      slot = game_slot(game, valid, now)
      match slot:
        case 0:
          game_join_new(game, valid, now)
        case own:
          game_ok(game_player_set(game, own, player_touch(game_player(game, own), now)))

def game_move(game: Game, id: U32, direction: U32, now: U32) -> Action:
  slot = game_slot(game, id, now)
  match slot:
    case 0:
      game_error(game, "Join the world before moving.")
    case own:
      game_ok(game_player_set(game, own, player_move(game_player(game, own), direction, now)))

def game_mine(game: Game, id: U32, x: U32, z: U32, now: U32) -> Action:
  slot = game_slot(game, id, now)
  match slot:
    case 0:
      game_error(game, "Join the world before mining.")
    case own:
      player = game_player(game, own)
      match player:
        case Player.Player{number, stored, joined, px, pz, seen}:
          match (x < world_size()) && ((z < world_size()) && u32_near(px, pz, x, z)):
            case 0:
              game_error(game, "That block is outside your reach.")
            case k:
              match game:
                case Game.Game{world, one, two, three, four, tick}:
                  index = (z * world_size()) + x
                  column = column_mine(list_column_get(world, index))
                  touched = player_touch(Player.Player{number, stored, joined, px, pz, seen}, now)
                  updated = game_player_set(Game.Game{list_column_set(world, index, column), one, two, three, four, tick}, own, touched)
                  game_ok(updated)

def game_place(game: Game, id: U32, x: U32, z: U32, block: U32, now: U32) -> Action:
  slot = game_slot(game, id, now)
  match slot:
    case 0:
      game_error(game, "Join the world before placing blocks.")
    case own:
      player = game_player(game, own)
      match player:
        case Player.Player{number, stored, joined, px, pz, seen}:
          match (x < world_size()) && ((z < world_size()) && (u32_near(px, pz, x, z) && ((block > 0) && (block <= 5)))):
            case 0:
              game_error(game, "Choose a nearby block and one of the five materials.")
            case k:
              match game:
                case Game.Game{world, one, two, three, four, tick}:
                  index = (z * world_size()) + x
                  column = column_place(list_column_get(world, index), block)
                  touched = player_touch(Player.Player{number, stored, joined, px, pz, seen}, now)
                  updated = game_player_set(Game.Game{list_column_set(world, index, column), one, two, three, four, tick}, own, touched)
                  game_ok(updated)

def game_leave(game: Game, id: U32, now: U32) -> Action:
  slot = game_slot(game, id, now)
  match slot:
    case 0:
      game_error(game, "This browser has not joined the world.")
    case own:
      game_ok(game_player_set(game, own, player_empty(own)))

def game_full(game: Game, now: U32) -> U32:
  match game:
    case Game.Game{world, one, two, three, four, tick}:
      player_active(one, now) && (player_active(two, now) && (player_active(three, now) && player_active(four, now)))

# ---------------------------------------------------------------- JSON and routing

def game_json(game: Game, id: U32, now: U32, ok: U32, note: String) -> String:
  match game:
    case Game.Game{world, one, two, three, four, tick}:
      String.flatten([
        "{\"ok\":", String.from_u32(ok),
        ",\"note\":\"", note,
        "\",\"you\":", String.from_u32(game_slot(Game.Game{world, one, two, three, four, tick}, id, now)),
        ",\"full\":", String.from_u32(game_full(Game.Game{world, one, two, three, four, tick}, now)),
        ",\"tick\":", String.from_u32(tick),
        ",\"size\":", String.from_u32(world_size()),
        ",\"renderDistance\":", String.from_u32(render_distance()),
        ",\"players\":[", player_json(one, now), ",", player_json(two, now), ",", player_json(three, now), ",", player_json(four, now), "],",
        "\"world\":[", list_world_json(world), "}"
      ])

def game_response(game: Game, id: U32, now: U32, ok: U32, note: String) -> HTTP.Response:
  HTTP.Response.Response{200,
    [HTTP.Header.Header{"Content-Type", "application/json; charset=utf-8"}, HTTP.Header.Header{"Cache-Control", "no-store, no-cache, must-revalidate"}],
    Bytes.from_string(game_json(game, id, now, ok, note))}

def game_routed(game: Game, id: U32, now: U32) -> Routed:
  Routed.Routed{game, game_response(game, id, now, 1, "")}

def game_missing(game: Game) -> Routed:
  Routed.Routed{game, HTTP.not_found()}

def game_method(game: Game) -> Routed:
  Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")}

def action_routed(action: Action, id: U32, now: U32) -> Routed:
  match action:
    case Action.Action{game, ok, note}:
      Routed.Routed{game, game_response(game, id, now, ok, note)}

def result_index(result: Result((U32 & String), String), game: Game) -> IO(Routed):
  match result:
    case Result.Done{html}:
      IO.pure(Routed, Routed.Routed{game, HTTP.reply(200, "text/html; charset=utf-8", html)})
    case Result.Fail{(code, error)}:
      IO.pure(Routed, Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run from the repository root\n")})

def game_index(game: Game) -> IO(Routed):
  do IO(Routed):
    result <- IO.read_text("gabriel_demos/minecraft_web/index.html")
    result_index(result, game)

def list_state(args: List(String), game: Game, now: U32) -> IO(Routed):
  match args:
    case List.Cons{id, rest}:
      player = String.to_u32(id)
      touched = game_state(game, player, now)
      IO.pure(Routed, game_routed(touched, player, now))
    case List.Nil{}:
      IO.pure(Routed, game_missing(game))

def list_join(args: List(String), game: Game, now: U32) -> IO(Routed):
  match args:
    case List.Cons{id, rest}:
      player = String.to_u32(id)
      IO.pure(Routed, action_routed(game_join(game, player, now), player, now))
    case List.Nil{}:
      IO.pure(Routed, game_missing(game))

def list_move(args: List(String), game: Game, now: U32) -> IO(Routed):
  match args:
    case List.Cons{id, List.Cons{direction, rest}}:
      player = String.to_u32(id)
      IO.pure(Routed, action_routed(game_move(game, player, String.to_u32(direction), now), player, now))
    case other:
      IO.pure(Routed, game_missing(game))

def list_mine(args: List(String), game: Game, now: U32) -> IO(Routed):
  match args:
    case List.Cons{id, List.Cons{x, List.Cons{z, rest}}}:
      player = String.to_u32(id)
      IO.pure(Routed, action_routed(game_mine(game, player, String.to_u32(x), String.to_u32(z), now), player, now))
    case other:
      IO.pure(Routed, game_missing(game))

def list_place(args: List(String), game: Game, now: U32) -> IO(Routed):
  match args:
    case List.Cons{id, List.Cons{x, List.Cons{z, List.Cons{block, rest}}}}:
      player = String.to_u32(id)
      IO.pure(Routed, action_routed(game_place(game, player, String.to_u32(x), String.to_u32(z), String.to_u32(block), now), player, now))
    case other:
      IO.pure(Routed, game_missing(game))

def list_leave(args: List(String), game: Game, now: U32) -> IO(Routed):
  match args:
    case List.Cons{id, rest}:
      player = String.to_u32(id)
      IO.pure(Routed, action_routed(game_leave(game, player, now), player, now))
    case List.Nil{}:
      IO.pure(Routed, game_missing(game))

def string_route(name: String, args: List(String), game: Game, now: U32) -> IO(Routed):
  match String.eq_u32(name, ""):
    case 0:
      match String.eq_u32(name, "state"):
        case 0:
          match String.eq_u32(name, "join"):
            case 0:
              match String.eq_u32(name, "move"):
                case 0:
                  match String.eq_u32(name, "mine"):
                    case 0:
                      match String.eq_u32(name, "place"):
                        case 0:
                          match String.eq_u32(name, "leave"):
                            case 0:
                              IO.pure(Routed, game_missing(game))
                            case k6:
                              list_leave(args, game, now)
                        case k5:
                          list_place(args, game, now)
                    case k4:
                      list_mine(args, game, now)
                case k3:
                  list_move(args, game, now)
            case k2:
              list_join(args, game, now)
        case k1:
          list_state(args, game, now)
    case root:
      game_index(game)

def list_route(parts: List(String), game: Game, now: U32) -> IO(Routed):
  match parts:
    case List.Cons{root, List.Cons{name, args}}:
      string_route(name, args, game, now)
    case List.Cons{root, List.Nil{}}:
      game_index(game)
    case List.Nil{}:
      game_index(game)

def request_route(request: HTTP.Request, game: Game, now: U32) -> IO(Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(method, "GET"):
        case 0:
          IO.pure(Routed, game_method(game))
        case k:
          list_route(String.split('/', path), game, now)

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
        now <- clock_now_ms()
        routed <- request_route(request, game, now)
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
        printed <- IO.write("Block World listening on all interfaces (0.0.0.0:8085)\nopen http://<server-lan-ip>:8085\n")
        u32_serve(server, game_empty())
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def main() -> IO(U32):
  do IO(U32):
    result <- TCP.listen(8085)
    result_main(result)
