# Generated hub-private namespace from ../minecraft_web/web_minecraft.bend.
# Regenerate after changing the standalone source.

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

import ../../../bend-base/Base
import ../../Compat
import ../../../bend-base/IO/TCP
import ../../../bend-base/IO/HTTP
import ../../Clock

def Mine.world_size() -> U32: 24
def Mine.render_distance() -> U32: 6
def Mine.player_timeout() -> U32: 30000
def Mine.max_height() -> U32: 9

type Mine.Column:
  Column{height: U32, block: U32, ground: U32}

type Mine.Player:
  Player{slot: U32, id: U32, joined: U32, x: U32, z: U32, seen: U32}

type Mine.Game:
  Game{world: List(Mine.Column), one: Mine.Player, two: Mine.Player, three: Mine.Player, four: Mine.Player, tick: U32}

type Mine.Action:
  Action{game: Mine.Game, ok: U32, note: String}

type Mine.Routed:
  Routed{game: Mine.Game, response: HTTP.Response}

# ---------------------------------------------------------------- U32

def Mine.u32_abs_diff(a: U32, b: U32) -> U32:
  match a < b:
    case 0:
      a - b
    case k:
      b - a

def Mine.u32_near(x: U32, z: U32, other_x: U32, other_z: U32) -> U32:
  (Mine.u32_abs_diff(x, other_x) + Mine.u32_abs_diff(z, other_z)) <= 3

def Mine.u32_ground(x: U32, z: U32) -> U32:
  2 + ((((x * 13) + (z * 7)) + (x * z)) % 3)

def Mine.u32_tree(x: U32, z: U32, cx: U32, cz: U32) -> U32:
  (x == cx) && (z == cz)

def Mine.u32_canopy(x: U32, z: U32, cx: U32, cz: U32) -> U32:
  (Mine.u32_abs_diff(x, cx) <= 1) && (Mine.u32_abs_diff(z, cz) <= 1)

def Mine.u32_tree_any(x: U32, z: U32) -> U32:
  Mine.u32_tree(x, z, 6, 6) || (Mine.u32_tree(x, z, 17, 8) || Mine.u32_tree(x, z, 9, 17))

def Mine.u32_canopy_any(x: U32, z: U32) -> U32:
  Mine.u32_canopy(x, z, 6, 6) || (Mine.u32_canopy(x, z, 17, 8) || Mine.u32_canopy(x, z, 9, 17))

def Mine.u32_layer(height: U32, ground: U32) -> U32:
  match height == ground:
    case 0:
      match (height + 1) >= ground:
        case 0:
          3
        case k:
          2
    case k:
      1

def Mine.u32_prev(value: U32) -> U32:
  match value:
    case 0:
      0
    case k:
      k - 1

def Mine.u32_next(value: U32) -> U32:
  match value:
    case 23:
      23
    case k:
      k + 1

# ---------------------------------------------------------------- Column

def Mine.column_make(x: U32, z: U32) -> Mine.Column:
  ground = Mine.u32_ground(x, z)
  match Mine.u32_tree_any(x, z):
    case 0:
      match Mine.u32_canopy_any(x, z):
        case 0:
          Mine.Column.Column{ground, 1, ground}
        case k:
          Mine.Column.Column{ground + 2, 5, ground}
    case k:
      Mine.Column.Column{ground + 3, 4, ground}

def Mine.column_mine(column: Mine.Column) -> Mine.Column:
  match column:
    case Mine.Column.Column{height, block, ground}:
      match height:
        case 0:
          Mine.Column.Column{0, 0, ground}
        case h:
          next = h - 1
          match h > ground:
            case 0:
              match next:
                case 0:
                  Mine.Column.Column{0, 0, ground}
                case n:
                  Mine.Column.Column{n, Mine.u32_layer(n, ground), ground}
            case k:
              match block == 5:
                case 0:
                  match next > ground:
                    case 0:
                      Mine.Column.Column{ground, 1, ground}
                    case j:
                      Mine.Column.Column{next, 4, ground}
                case j:
                  Mine.Column.Column{ground, 1, ground}

def Mine.column_place(column: Mine.Column, block: U32) -> Mine.Column:
  match column:
    case Mine.Column.Column{height, old, ground}:
      match (block > 0) && ((block <= 5) && (height < Mine.max_height())):
        case 0:
          Mine.Column.Column{height, old, ground}
        case k:
          Mine.Column.Column{height + 1, block, ground}

def Mine.column_json(column: Mine.Column) -> String:
  match column:
    case Mine.Column.Column{height, block, ground}:
      String.flatten(["[", String.from_u32(height), ",", String.from_u32(block), "]"])

# ---------------------------------------------------------------- List

def Mine.list_world(left: U32, index: U32) -> List(Mine.Column):
  match left:
    case 0:
      List.Nil{}
    case k:
      x = index % Mine.world_size()
      z = index / Mine.world_size()
      List.Cons{Mine.column_make(x, z), Mine.list_world(k - 1, index + 1)}

def Mine.list_column_get(columns: List(Mine.Column), index: U32) -> Mine.Column:
  match columns:
    case List.Cons{head, tail}:
      match index:
        case 0:
          head
        case k:
          Mine.list_column_get(tail, k - 1)
    case List.Nil{}:
      Mine.Column.Column{0, 0, 0}

def Mine.list_column_set(columns: List(Mine.Column), index: U32, column: Mine.Column) -> List(Mine.Column):
  match columns:
    case List.Cons{head, tail}:
      match index:
        case 0:
          List.Cons{column, tail}
        case k:
          List.Cons{head, Mine.list_column_set(tail, k - 1, column)}
    case List.Nil{}:
      List.Nil{}

def Mine.list_world_json(columns: List(Mine.Column)) -> String:
  match columns:
    case List.Cons{head, List.Nil{}}:
      String.concat(Mine.column_json(head), "]")
    case List.Cons{head, tail}:
      String.concat(Mine.column_json(head), String.concat(",", Mine.list_world_json(tail)))
    case List.Nil{}:
      "]"

# ---------------------------------------------------------------- Player

def Mine.player_empty(slot: U32) -> Mine.Player:
  Mine.Player.Player{slot, 0, 0, 0, 0, 0}

def Mine.player_spawn(slot: U32, id: U32, now: U32) -> Mine.Player:
  match slot:
    case 1:
      Mine.Player.Player{1, id, 1, 11, 11, now}
    case 2:
      Mine.Player.Player{2, id, 1, 13, 11, now}
    case 3:
      Mine.Player.Player{3, id, 1, 11, 13, now}
    case other:
      Mine.Player.Player{4, id, 1, 13, 13, now}

def Mine.player_active(player: Mine.Player, now: U32) -> U32:
  match player:
    case Mine.Player.Player{slot, id, joined, x, z, seen}:
      joined && ((now - seen) < Mine.player_timeout())

def Mine.player_owner(player: Mine.Player, id: U32, now: U32) -> U32:
  match player:
    case Mine.Player.Player{slot, stored, joined, x, z, seen}:
      (id > 0) && ((stored == id) && Mine.player_active(Mine.Player.Player{slot, stored, joined, x, z, seen}, now))

def Mine.player_touch(player: Mine.Player, now: U32) -> Mine.Player:
  match player:
    case Mine.Player.Player{slot, id, joined, x, z, seen}:
      Mine.Player.Player{slot, id, joined, x, z, now}

def Mine.player_move(player: Mine.Player, direction: U32, now: U32) -> Mine.Player:
  match player:
    case Mine.Player.Player{slot, id, joined, x, z, seen}:
      match direction % 4:
        case 0:
          Mine.Player.Player{slot, id, joined, x, Mine.u32_prev(z), now}
        case 1:
          Mine.Player.Player{slot, id, joined, Mine.u32_next(x), z, now}
        case 2:
          Mine.Player.Player{slot, id, joined, x, Mine.u32_next(z), now}
        case other:
          Mine.Player.Player{slot, id, joined, Mine.u32_prev(x), z, now}

def Mine.player_json(player: Mine.Player, now: U32) -> String:
  match player:
    case Mine.Player.Player{slot, id, joined, x, z, seen}:
      String.flatten([
        "{\"slot\":", String.from_u32(slot),
        ",\"joined\":", String.from_u32(Mine.player_active(Mine.Player.Player{slot, id, joined, x, z, seen}, now)),
        ",\"x\":", String.from_u32(x),
        ",\"z\":", String.from_u32(z), "}"
      ])

# ---------------------------------------------------------------- Game

def Mine.game_empty() -> Mine.Game:
  Mine.Game.Game{Mine.list_world(Mine.world_size() * Mine.world_size(), 0), Mine.player_empty(1), Mine.player_empty(2), Mine.player_empty(3), Mine.player_empty(4), 1}

def Mine.game_slot(game: Mine.Game, id: U32, now: U32) -> U32:
  match game:
    case Mine.Game.Game{world, one, two, three, four, tick}:
      match Mine.player_owner(one, id, now):
        case 0:
          match Mine.player_owner(two, id, now):
            case 0:
              match Mine.player_owner(three, id, now):
                case 0:
                  match Mine.player_owner(four, id, now):
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

def Mine.game_player(game: Mine.Game, slot: U32) -> Mine.Player:
  match game:
    case Mine.Game.Game{world, one, two, three, four, tick}:
      match slot:
        case 1:
          one
        case 2:
          two
        case 3:
          three
        case other:
          four

def Mine.game_player_set(game: Mine.Game, slot: U32, player: Mine.Player) -> Mine.Game:
  match game:
    case Mine.Game.Game{world, one, two, three, four, tick}:
      match slot:
        case 1:
          Mine.Game.Game{world, player, two, three, four, tick + 1}
        case 2:
          Mine.Game.Game{world, one, player, three, four, tick + 1}
        case 3:
          Mine.Game.Game{world, one, two, player, four, tick + 1}
        case other:
          Mine.Game.Game{world, one, two, three, player, tick + 1}

def Mine.game_ok(game: Mine.Game) -> Mine.Action:
  Mine.Action.Action{game, 1, ""}

def Mine.game_error(game: Mine.Game, note: String) -> Mine.Action:
  Mine.Action.Action{game, 0, note}

def Mine.game_state(game: Mine.Game, id: U32, now: U32) -> Mine.Game:
  slot = Mine.game_slot(game, id, now)
  match slot:
    case 0:
      game
    case own:
      Mine.game_player_set(game, own, Mine.player_touch(Mine.game_player(game, own), now))

def Mine.game_join_new(game: Mine.Game, id: U32, now: U32) -> Mine.Action:
  match game:
    case Mine.Game.Game{world, one, two, three, four, tick}:
      match Mine.player_active(one, now):
        case 0:
          Mine.game_ok(Mine.Game.Game{world, Mine.player_spawn(1, id, now), two, three, four, tick + 1})
        case k:
          match Mine.player_active(two, now):
            case 0:
              Mine.game_ok(Mine.Game.Game{world, one, Mine.player_spawn(2, id, now), three, four, tick + 1})
            case j:
              match Mine.player_active(three, now):
                case 0:
                  Mine.game_ok(Mine.Game.Game{world, one, two, Mine.player_spawn(3, id, now), four, tick + 1})
                case q:
                  match Mine.player_active(four, now):
                    case 0:
                      Mine.game_ok(Mine.Game.Game{world, one, two, three, Mine.player_spawn(4, id, now), tick + 1})
                    case p:
                      Mine.game_error(Mine.Game.Game{world, one, two, three, four, tick}, "The world already has four active players.")

def Mine.game_join(game: Mine.Game, id: U32, now: U32) -> Mine.Action:
  match id:
    case 0:
      Mine.game_error(game, "Invalid player identity.")
    case valid:
      slot = Mine.game_slot(game, valid, now)
      match slot:
        case 0:
          Mine.game_join_new(game, valid, now)
        case own:
          Mine.game_ok(Mine.game_player_set(game, own, Mine.player_touch(Mine.game_player(game, own), now)))

def Mine.game_move(game: Mine.Game, id: U32, direction: U32, now: U32) -> Mine.Action:
  slot = Mine.game_slot(game, id, now)
  match slot:
    case 0:
      Mine.game_error(game, "Join the world before moving.")
    case own:
      Mine.game_ok(Mine.game_player_set(game, own, Mine.player_move(Mine.game_player(game, own), direction, now)))

def Mine.game_mine(game: Mine.Game, id: U32, x: U32, z: U32, now: U32) -> Mine.Action:
  slot = Mine.game_slot(game, id, now)
  match slot:
    case 0:
      Mine.game_error(game, "Join the world before mining.")
    case own:
      player = Mine.game_player(game, own)
      match player:
        case Mine.Player.Player{number, stored, joined, px, pz, seen}:
          match (x < Mine.world_size()) && ((z < Mine.world_size()) && Mine.u32_near(px, pz, x, z)):
            case 0:
              Mine.game_error(game, "That block is outside your reach.")
            case k:
              match game:
                case Mine.Game.Game{world, one, two, three, four, tick}:
                  index = (z * Mine.world_size()) + x
                  column = Mine.column_mine(Mine.list_column_get(world, index))
                  touched = Mine.player_touch(Mine.Player.Player{number, stored, joined, px, pz, seen}, now)
                  updated = Mine.game_player_set(Mine.Game.Game{Mine.list_column_set(world, index, column), one, two, three, four, tick}, own, touched)
                  Mine.game_ok(updated)

def Mine.game_place(game: Mine.Game, id: U32, x: U32, z: U32, block: U32, now: U32) -> Mine.Action:
  slot = Mine.game_slot(game, id, now)
  match slot:
    case 0:
      Mine.game_error(game, "Join the world before placing blocks.")
    case own:
      player = Mine.game_player(game, own)
      match player:
        case Mine.Player.Player{number, stored, joined, px, pz, seen}:
          match (x < Mine.world_size()) && ((z < Mine.world_size()) && (Mine.u32_near(px, pz, x, z) && ((block > 0) && (block <= 5)))):
            case 0:
              Mine.game_error(game, "Choose a nearby block and one of the five materials.")
            case k:
              match game:
                case Mine.Game.Game{world, one, two, three, four, tick}:
                  index = (z * Mine.world_size()) + x
                  column = Mine.column_place(Mine.list_column_get(world, index), block)
                  touched = Mine.player_touch(Mine.Player.Player{number, stored, joined, px, pz, seen}, now)
                  updated = Mine.game_player_set(Mine.Game.Game{Mine.list_column_set(world, index, column), one, two, three, four, tick}, own, touched)
                  Mine.game_ok(updated)

def Mine.game_leave(game: Mine.Game, id: U32, now: U32) -> Mine.Action:
  slot = Mine.game_slot(game, id, now)
  match slot:
    case 0:
      Mine.game_error(game, "This browser has not joined the world.")
    case own:
      Mine.game_ok(Mine.game_player_set(game, own, Mine.player_empty(own)))

def Mine.game_full(game: Mine.Game, now: U32) -> U32:
  match game:
    case Mine.Game.Game{world, one, two, three, four, tick}:
      Mine.player_active(one, now) && (Mine.player_active(two, now) && (Mine.player_active(three, now) && Mine.player_active(four, now)))

# ---------------------------------------------------------------- JSON and routing

def Mine.game_json(game: Mine.Game, id: U32, now: U32, ok: U32, note: String) -> String:
  match game:
    case Mine.Game.Game{world, one, two, three, four, tick}:
      String.flatten([
        "{\"ok\":", String.from_u32(ok),
        ",\"note\":\"", note,
        "\",\"you\":", String.from_u32(Mine.game_slot(Mine.Game.Game{world, one, two, three, four, tick}, id, now)),
        ",\"full\":", String.from_u32(Mine.game_full(Mine.Game.Game{world, one, two, three, four, tick}, now)),
        ",\"tick\":", String.from_u32(tick),
        ",\"size\":", String.from_u32(Mine.world_size()),
        ",\"renderDistance\":", String.from_u32(Mine.render_distance()),
        ",\"players\":[", Mine.player_json(one, now), ",", Mine.player_json(two, now), ",", Mine.player_json(three, now), ",", Mine.player_json(four, now), "],",
        "\"world\":[", Mine.list_world_json(world), "}"
      ])

def Mine.game_response(game: Mine.Game, id: U32, now: U32, ok: U32, note: String) -> HTTP.Response:
  HTTP.Response.Response{200,
    [HTTP.Header.Header{"Content-Type", "application/json; charset=utf-8"}, HTTP.Header.Header{"Cache-Control", "no-store, no-cache, must-revalidate"}],
    Bytes.from_string(Mine.game_json(game, id, now, ok, note))}

def Mine.game_routed(game: Mine.Game, id: U32, now: U32) -> Mine.Routed:
  Mine.Routed.Routed{game, Mine.game_response(game, id, now, 1, "")}

def Mine.game_missing(game: Mine.Game) -> Mine.Routed:
  Mine.Routed.Routed{game, HTTP.not_found()}

def Mine.game_method(game: Mine.Game) -> Mine.Routed:
  Mine.Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")}

def Mine.action_routed(action: Mine.Action, id: U32, now: U32) -> Mine.Routed:
  match action:
    case Mine.Action.Action{game, ok, note}:
      Mine.Routed.Routed{game, Mine.game_response(game, id, now, ok, note)}

def Mine.result_index(result: Result((U32 & String), String), game: Mine.Game) -> IO(Mine.Routed):
  match result:
    case Result.Done{html}:
      IO.pure(Mine.Routed, Mine.Routed.Routed{game, HTTP.reply(200, "text/html; charset=utf-8", html)})
    case Result.Fail{(code, error)}:
      IO.pure(Mine.Routed, Mine.Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run from the repository root\n")})

def Mine.game_index(game: Mine.Game) -> IO(Mine.Routed):
  do IO(Mine.Routed):
    result <- IO.read_text("gabriel_demos/minecraft_web/index.html")
    Mine.result_index(result, game)

def Mine.list_state(args: List(String), game: Mine.Game, now: U32) -> IO(Mine.Routed):
  match args:
    case List.Cons{id, rest}:
      player = String.to_u32(id)
      touched = Mine.game_state(game, player, now)
      IO.pure(Mine.Routed, Mine.game_routed(touched, player, now))
    case List.Nil{}:
      IO.pure(Mine.Routed, Mine.game_missing(game))

def Mine.list_join(args: List(String), game: Mine.Game, now: U32) -> IO(Mine.Routed):
  match args:
    case List.Cons{id, rest}:
      player = String.to_u32(id)
      IO.pure(Mine.Routed, Mine.action_routed(Mine.game_join(game, player, now), player, now))
    case List.Nil{}:
      IO.pure(Mine.Routed, Mine.game_missing(game))

def Mine.list_move(args: List(String), game: Mine.Game, now: U32) -> IO(Mine.Routed):
  match args:
    case List.Cons{id, List.Cons{direction, rest}}:
      player = String.to_u32(id)
      IO.pure(Mine.Routed, Mine.action_routed(Mine.game_move(game, player, String.to_u32(direction), now), player, now))
    case other:
      IO.pure(Mine.Routed, Mine.game_missing(game))

def Mine.list_mine(args: List(String), game: Mine.Game, now: U32) -> IO(Mine.Routed):
  match args:
    case List.Cons{id, List.Cons{x, List.Cons{z, rest}}}:
      player = String.to_u32(id)
      IO.pure(Mine.Routed, Mine.action_routed(Mine.game_mine(game, player, String.to_u32(x), String.to_u32(z), now), player, now))
    case other:
      IO.pure(Mine.Routed, Mine.game_missing(game))

def Mine.list_place(args: List(String), game: Mine.Game, now: U32) -> IO(Mine.Routed):
  match args:
    case List.Cons{id, List.Cons{x, List.Cons{z, List.Cons{block, rest}}}}:
      player = String.to_u32(id)
      IO.pure(Mine.Routed, Mine.action_routed(Mine.game_place(game, player, String.to_u32(x), String.to_u32(z), String.to_u32(block), now), player, now))
    case other:
      IO.pure(Mine.Routed, Mine.game_missing(game))

def Mine.list_leave(args: List(String), game: Mine.Game, now: U32) -> IO(Mine.Routed):
  match args:
    case List.Cons{id, rest}:
      player = String.to_u32(id)
      IO.pure(Mine.Routed, Mine.action_routed(Mine.game_leave(game, player, now), player, now))
    case List.Nil{}:
      IO.pure(Mine.Routed, Mine.game_missing(game))

def Mine.string_route(name: String, args: List(String), game: Mine.Game, now: U32) -> IO(Mine.Routed):
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
                              IO.pure(Mine.Routed, Mine.game_missing(game))
                            case k6:
                              Mine.list_leave(args, game, now)
                        case k5:
                          Mine.list_place(args, game, now)
                    case k4:
                      Mine.list_mine(args, game, now)
                case k3:
                  Mine.list_move(args, game, now)
            case k2:
              Mine.list_join(args, game, now)
        case k1:
          Mine.list_state(args, game, now)
    case root:
      Mine.game_index(game)

def Mine.list_route(parts: List(String), game: Mine.Game, now: U32) -> IO(Mine.Routed):
  match parts:
    case List.Cons{root, List.Cons{name, args}}:
      Mine.string_route(name, args, game, now)
    case List.Cons{root, List.Nil{}}:
      Mine.game_index(game)
    case List.Nil{}:
      Mine.game_index(game)

def Mine.request_route(request: HTTP.Request, game: Mine.Game, now: U32) -> IO(Mine.Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(method, "GET"):
        case 0:
          IO.pure(Mine.Routed, Mine.game_method(game))
        case k:
          Mine.list_route(String.split('/', path), game, now)

# ---------------------------------------------------------------- server

def Mine.routed_send(routed: Mine.Routed, server: TCP, conn: HTTP) -> IO(U32):
  match routed:
    case Mine.Routed.Routed{game, response}:
      do IO(U32):
        sent <- HTTP.send_response(conn, HTTP.with_connection(0, response))
        closed <- HTTP.close(conn)
        Mine.u32_serve(server, game)

def Mine.inbound_serve(inbound: HTTP.Inbound, server: TCP, conn: HTTP, game: Mine.Game) -> IO(U32):
  match inbound:
    case HTTP.Inbound.Got{http11, request, rest}:
      do IO(U32):
        now <- clock_now_ms()
        routed <- Mine.request_route(request, game, now)
        Mine.routed_send(routed, server, conn)
    case HTTP.Inbound.Closed{}:
      do IO(U32):
        closed <- HTTP.close(conn)
        Mine.u32_serve(server, game)
    case HTTP.Inbound.Bad{code, error}:
      Mine.routed_send(Mine.Routed.Routed{game, HTTP.reply_error(code, error)}, server, conn)

def Mine.result_accept(result: Result((U32 & String), TCP), server: TCP, game: Mine.Game) -> IO(U32):
  match result:
    case Result.Done{fd}:
      do IO(U32):
        inbound <- HTTP.recv_request(HTTP.Plain{fd}, List.Nil{})
        Mine.inbound_serve(inbound, server, HTTP.Plain{fd}, game)
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["accept failed: ", error, "\n"]))
        return 1

def Mine.u32_serve(server: TCP, game: Mine.Game) -> IO(U32):
  do IO(U32):
    result <- TCP.accept(server)
    Mine.result_accept(result, server, game)

def Mine.result_main(result: Result((U32 & String), TCP)) -> IO(U32):
  match result:
    case Result.Done{server}:
      do IO(U32):
        printed <- IO.write("Block World listening on all interfaces (0.0.0.0:8085)\nopen http://<server-lan-ip>:8085\n")
        Mine.u32_serve(server, Mine.game_empty())
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def Mine.main() -> IO(U32):
  do IO(U32):
    result <- TCP.listen(8085)
    Mine.result_main(result)
