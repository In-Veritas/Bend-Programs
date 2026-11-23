# Block World: a compact multiplayer voxel sandbox over the local network.
#
# Bend owns the shared column world, four player slots, movement, mining, and
# placement. The browser renders a short-range isometric view.
#
# routes (also accepted under a leading /minecraft, as the BendJogos hub uses):
#   GET /                              page
#   GET /state/<player>               shared snapshot
#   GET /join/<player>                take an available slot
#   GET /move/<player>/<direction>    move north/east/south/west (0..3)
#   GET /mine/<player>/<x>/<z>        remove a nearby top block
#   GET /place/<player>/<x>/<z>/<kind> place grass/dirt/stone/wood/leaves (1..5)
#   GET /leave/<player>               release the slot
#
# check: bend Bend3/demos/minecraft_web/web_minecraft.bend --check-only
# build: ./Bend3/demos/minecraft_web/build.sh   (bend ... -o Bend3/demos/minecraft_web/build/web_minecraft)
# run:   ./Bend3/demos/minecraft_web/start.sh   (from the repository root)
# open:  http://<server-lan-ip>:8085
#
# Hub interface: `Game`, `init()`, `route(req, game)` (reads the clock) and
# `route_at(req, game, now)` (pure clock argument). Both accept paths with or
# without the `/minecraft` prefix.

import Base
import ../HTTP.bend as HTTP
import ../Compat.bend as Compat
import ../Clock.bend as Clock

def world_size() -> U32:
  24

def render_distance() -> U32:
  6

def player_timeout() -> U32:
  30000

def max_height() -> U32:
  9

type Column is Data:
  Column{height: U32, block: U32, ground: U32}

type Player is Data:
  Player{slot: U32, id: U32, joined: U32, x: U32, z: U32, seen: U32}

type Game is Data:
  Game{world: List<&2, Column>, one: Player, two: Player, three: Player, four: Player, tick: U32}

type Action is Data:
  Action{game: Game, ok: U32, note: String}

# ---------------------------------------------------------------- U32

def u32_abs_diff(+a: U32, +b: U32) -> U32:
  Bool.pick(U32, (a < b : U32), (b - a : U32), (a - b : U32))

def u32_near(+x: U32, +z: U32, +other_x: U32, +other_z: U32) -> Bool:
  ((u32_abs_diff(x, other_x) + u32_abs_diff(z, other_z) : U32) <= 3 : U32)

def u32_ground(+x: U32, +z: U32) -> U32:
  (2 + ((((x * 13) + (z * 7)) + (x * z)) % 3) : U32)

def u32_tree(+x: U32, +z: U32, +cx: U32, +cz: U32) -> Bool:
  U32.is_eq(x, cx) && U32.is_eq(z, cz)

def u32_canopy(+x: U32, +z: U32, +cx: U32, +cz: U32) -> Bool:
  (u32_abs_diff(x, cx) <= 1 : U32) && (u32_abs_diff(z, cz) <= 1 : U32)

def u32_tree_any(+x: U32, +z: U32) -> Bool:
  u32_tree(x, z, 6, 6) || (u32_tree(x, z, 17, 8) || u32_tree(x, z, 9, 17))

def u32_canopy_any(+x: U32, +z: U32) -> Bool:
  u32_canopy(x, z, 6, 6) || (u32_canopy(x, z, 17, 8) || u32_canopy(x, z, 9, 17))

def u32_layer(+height: U32, +ground: U32) -> U32:
  Bool.pick(U32, U32.is_eq(height, ground), 1, Bool.pick(U32, ((height + 1 : U32) >= ground : U32), 2, 3))

def u32_prev(value: U32) -> U32:
  match value:
    case 0:
      0
    case k:
      (k - 1 : U32)

def u32_next(value: U32) -> U32:
  match value:
    case 23:
      23
    case k:
      (k + 1 : U32)

# ---------------------------------------------------------------- Column

def column_make.pick(tree: Bool, canopy: Bool, +ground: U32) -> Column:
  match tree canopy:
    case True{} _:
      Column{(ground + 3 : U32), 4, ground}
    case False{} True{}:
      Column{(ground + 2 : U32), 5, ground}
    case False{} False{}:
      Column{ground, 1, ground}

def column_make(+x: U32, +z: U32) -> Column:
  column_make.pick(u32_tree_any(x, z), u32_canopy_any(x, z), u32_ground(x, z))

# Mining the soil: one layer down, or bedrock-empty at zero.
def column_mine.soil(next: U32, +ground: U32) -> Column:
  match next:
    case 0:
      Column{0, 0, ground}
    case +n:
      Column{n, u32_layer(n, ground), ground}

# Mining above the ground: leaves clear the whole canopy, a trunk shrinks.
def column_mine.tree(leaf: Bool, above: Bool, +next: U32, +ground: U32) -> Column:
  match leaf above:
    case True{} _:
      Column{ground, 1, ground}
    case False{} True{}:
      Column{next, 4, ground}
    case False{} False{}:
      Column{ground, 1, ground}

def column_mine.at(raised: Bool, +h: U32, +block: U32, +ground: U32) -> Column:
  match raised:
    case False{}:
      column_mine.soil((h - 1 : U32), ground)
    case True{}:
      column_mine.tree(U32.is_eq(block, 5), ((h - 1 : U32) > ground : U32), (h - 1 : U32), ground)

def column_mine(column: Column) -> Column:
  match column:
    case Column{height, +block, +ground}:
      match height:
        case 0:
          Column{0, 0, ground}
        case +h:
          column_mine.at((h > ground : U32), h, block, ground)

def column_place(column: Column, +block: U32) -> Column:
  Column{+height, +old, +ground} = column
  Bool.pick(Column, (block > 0 : U32) && ((block <= 5 : U32) && (height < max_height() : U32)),
    Column{(height + 1 : U32), block, ground},
    Column{height, old, ground})

def column_json(column: Column) -> String:
  Column{height, block, ground} = column
  "[" ++ U32.show(height) ++ "," ++ U32.show(block) ++ "]"

# ---------------------------------------------------------------- List

def list_world(left: Nat, +index: U32) -> List<&2, Column>:
  match left:
    case 0n:
      Nil{}
    case 1n+k:
      column_make((index % world_size() : U32), (index / world_size() : U32)) <> list_world(k, (index + 1 : U32))

def list_column_get(columns: List<&2, Column>, index: U32) -> Column:
  match columns:
    case Nil{}:
      Column{0, 0, 0}
    case Con{head, tail}:
      match index:
        case 0:
          head
        case k:
          list_column_get(tail, (k - 1 : U32))

def list_column_set(columns: List<&2, Column>, index: U32, column: Column) -> List<&2, Column>:
  match columns:
    case Nil{}:
      Nil{}
    case Con{head, tail}:
      match index:
        case 0:
          column <> tail
        case k:
          head <> list_column_set(tail, (k - 1 : U32), column)

# ",[h,b],[h,b]..." for the columns after the first.
def list_world_json.rest(columns: List<&2, Column>) -> String:
  match columns:
    case Nil{}:
      ""
    case Con{head, tail}:
      "," ++ column_json(head) ++ list_world_json.rest(tail)

# The columns and the closing bracket of the world array.
def list_world_json(columns: List<&2, Column>) -> String:
  match columns:
    case Nil{}:
      "]"
    case Con{head, tail}:
      column_json(head) ++ list_world_json.rest(tail) ++ "]"

# ---------------------------------------------------------------- Player

def player_empty(slot: U32) -> Player:
  Player{slot, 0, 0, 0, 0, 0}

def player_spawn(slot: U32, id: U32, now: U32) -> Player:
  match slot:
    case 1:
      Player{1, id, 1, 11, 11, now}
    case 2:
      Player{2, id, 1, 13, 11, now}
    case 3:
      Player{3, id, 1, 11, 13, now}
    case other:
      Player{4, id, 1, 13, 13, now}

def player_active(player: Player, +now: U32) -> Bool:
  Player{slot, id, joined, x, z, seen} = player
  Bool.not(U32.is_zero(joined)) && ((now - seen : U32) < player_timeout() : U32)

def player_owner(+player: Player, +id: U32, +now: U32) -> Bool:
  Player{slot, stored, joined, x, z, seen} = player
  (id > 0 : U32) && (U32.is_eq(stored, id) && player_active(player, now))

def player_touch(player: Player, now: U32) -> Player:
  Player{slot, id, joined, x, z, seen} = player
  Player{slot, id, joined, x, z, now}

def player_move.dir(player: Player, dir: U32, +now: U32) -> Player:
  match player:
    case Player{slot, id, joined, +x, +z, seen}:
      match dir:
        case 0:
          Player{slot, id, joined, x, u32_prev(z), now}
        case 1:
          Player{slot, id, joined, u32_next(x), z, now}
        case 2:
          Player{slot, id, joined, x, u32_next(z), now}
        case other:
          Player{slot, id, joined, u32_prev(x), z, now}

def player_json(+player: Player, +now: U32) -> String:
  Player{slot, id, joined, x, z, seen} = player
  String.concat([
    "{\"slot\":", U32.show(slot),
    ",\"joined\":", U32.show(Bool.to_u32(player_active(player, now))),
    ",\"x\":", U32.show(x),
    ",\"z\":", U32.show(z), "}"])

def player_move(player: Player, +direction: U32, +now: U32) -> Player:
  player_move.dir(player, (direction % 4 : U32), now)

# ---------------------------------------------------------------- Game

def game_empty() -> Game:
  Game{list_world(U32.to_nat((world_size() * world_size() : U32)), 0), player_empty(1), player_empty(2), player_empty(3), player_empty(4), 1}

# The standalone and hub entry: the initial world.
def init() -> Game:
  game_empty()

def game_slot.pick(a: Bool, b: Bool, c: Bool, d: Bool) -> U32:
  match a b c d:
    case True{} _ _ _:
      1
    case False{} True{} _ _:
      2
    case False{} False{} True{} _:
      3
    case False{} False{} False{} True{}:
      4
    case False{} False{} False{} False{}:
      0

def game_slot(+game: Game, +id: U32, +now: U32) -> U32:
  Game{world, one, two, three, four, tick} = game
  game_slot.pick(player_owner(one, id, now), player_owner(two, id, now), player_owner(three, id, now), player_owner(four, id, now))

def game_player(game: Game, slot: U32) -> Player:
  match game:
    case Game{world, one, two, three, four, tick}:
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
    case Game{world, one, two, three, four, tick}:
      match slot:
        case 1:
          Game{world, player, two, three, four, (tick + 1 : U32)}
        case 2:
          Game{world, one, player, three, four, (tick + 1 : U32)}
        case 3:
          Game{world, one, two, player, four, (tick + 1 : U32)}
        case other:
          Game{world, one, two, three, player, (tick + 1 : U32)}

def game_ok(game: Game) -> Action:
  Action{game, 1, ""}

def game_error(game: Game, note: String) -> Action:
  Action{game, 0, note}

def game_state.at(+game: Game, slot: U32, +now: U32) -> Game:
  match slot:
    case 0:
      game
    case +own:
      game_player_set(game, own, player_touch(game_player(game, own), now))

def game_state(+game: Game, +id: U32, +now: U32) -> Game:
  game_state.at(game, game_slot(game, id, now), now)

def game_join_new.pick(a: Bool, b: Bool, c: Bool, d: Bool, game: Game, +id: U32, +now: U32) -> Action:
  match a b c d:
    case False{} _ _ _:
      game_ok(game_player_set(game, 1, player_spawn(1, id, now)))
    case True{} False{} _ _:
      game_ok(game_player_set(game, 2, player_spawn(2, id, now)))
    case True{} True{} False{} _:
      game_ok(game_player_set(game, 3, player_spawn(3, id, now)))
    case True{} True{} True{} False{}:
      game_ok(game_player_set(game, 4, player_spawn(4, id, now)))
    case True{} True{} True{} True{}:
      game_error(game, "The world already has four active players.")

def game_join_new(+game: Game, +id: U32, +now: U32) -> Action:
  Game{world, one, two, three, four, tick} = game
  game_join_new.pick(player_active(one, now), player_active(two, now), player_active(three, now), player_active(four, now), game, id, now)

def game_join.at(+game: Game, slot: U32, +id: U32, +now: U32) -> Action:
  match slot:
    case 0:
      game_join_new(game, id, now)
    case +own:
      game_ok(game_player_set(game, own, player_touch(game_player(game, own), now)))

def game_join(+game: Game, id: U32, +now: U32) -> Action:
  match id:
    case 0:
      game_error(game, "Invalid player identity.")
    case +valid:
      game_join.at(game, game_slot(game, valid, now), valid, now)

def game_move.at(+game: Game, slot: U32, direction: U32, +now: U32) -> Action:
  match slot:
    case 0:
      game_error(game, "Join the world before moving.")
    case +own:
      game_ok(game_player_set(game, own, player_move(game_player(game, own), direction, now)))

def game_move(+game: Game, +id: U32, direction: U32, +now: U32) -> Action:
  game_move.at(game, game_slot(game, id, now), direction, now)

# Rewrites the column at (x, z) with `edit` and touches the acting player.
def game_edit(game: Game, +own: U32, +x: U32, +z: U32, edit: Column -> Column, now: U32) -> Game:
  Game{+world, one, two, three, four, tick} = game
  +index = ((z * world_size()) + x : U32)
  +g2 : Game = Game{list_column_set(world, index, edit(list_column_get(world, index))), one, two, three, four, tick}
  game_player_set(g2, own, player_touch(game_player(g2, own), now))

def game_mine.ok(reach: Bool, +game: Game, +own: U32, +x: U32, +z: U32, +now: U32) -> Action:
  match reach:
    case False{}:
      game_error(game, "That block is outside your reach.")
    case True{}:
      game_ok(game_edit(game, own, x, z, c => column_mine(c), now))

def player_reach(player: Player, +x: U32, +z: U32) -> Bool:
  Player{number, stored, joined, px, pz, seen} = player
  (x < world_size() : U32) && ((z < world_size() : U32) && u32_near(px, pz, x, z))

def game_reach(+game: Game, +own: U32, +x: U32, +z: U32) -> Bool:
  player_reach(game_player(game, own), x, z)

def game_mine.at(+game: Game, slot: U32, +x: U32, +z: U32, +now: U32) -> Action:
  match slot:
    case 0:
      game_error(game, "Join the world before mining.")
    case +own:
      game_mine.ok(game_reach(game, own, x, z), game, own, x, z, now)

def game_mine(+game: Game, +id: U32, +x: U32, +z: U32, +now: U32) -> Action:
  game_mine.at(game, game_slot(game, id, now), x, z, now)

def game_place.ok(fit: Bool, +game: Game, +own: U32, +x: U32, +z: U32, +block: U32, +now: U32) -> Action:
  match fit:
    case False{}:
      game_error(game, "Choose a nearby block and one of the five materials.")
    case True{}:
      game_ok(game_edit(game, own, x, z, c => column_place(c, block), now))

def game_place.at(+game: Game, slot: U32, +x: U32, +z: U32, +block: U32, +now: U32) -> Action:
  match slot:
    case 0:
      game_error(game, "Join the world before placing blocks.")
    case +own:
      game_place.ok(game_reach(game, own, x, z) && ((block > 0 : U32) && (block <= 5 : U32)), game, own, x, z, block, now)

def game_place(+game: Game, +id: U32, +x: U32, +z: U32, +block: U32, +now: U32) -> Action:
  game_place.at(game, game_slot(game, id, now), x, z, block, now)

def game_leave.at(+game: Game, slot: U32) -> Action:
  match slot:
    case 0:
      game_error(game, "This browser has not joined the world.")
    case +own:
      game_ok(game_player_set(game, own, player_empty(own)))

def game_leave(+game: Game, +id: U32, +now: U32) -> Action:
  game_leave.at(game, game_slot(game, id, now))

def game_full(game: Game, +now: U32) -> Bool:
  Game{world, one, two, three, four, tick} = game
  player_active(one, now) && (player_active(two, now) && (player_active(three, now) && player_active(four, now)))

# ---------------------------------------------------------------- JSON and routing

def game_json(+game: Game, +id: U32, +now: U32, ok: U32, note: String) -> String:
  Game{world, +one, +two, +three, +four, tick} = game
  String.concat([
    "{\"ok\":", U32.show(ok),
    ",\"note\":", HTTP.quoted(note),
    ",\"you\":", U32.show(game_slot(game, id, now)),
    ",\"full\":", U32.show(Bool.to_u32(game_full(game, now))),
    ",\"tick\":", U32.show(tick),
    ",\"size\":", U32.show(world_size()),
    ",\"renderDistance\":", U32.show(render_distance()),
    ",\"players\":[", player_json(one, now), ",", player_json(two, now), ",", player_json(three, now), ",", player_json(four, now), "],",
    "\"world\":[", list_world_json(world), "}"])

def game_response(+game: Game, +id: U32, +now: U32, ok: U32, note: String) -> HTTP.Response:
  HTTP.Response{200,
    [HTTP.Header{"Content-Type", "application/json; charset=utf-8"}, HTTP.Header{"Cache-Control", "no-store, no-cache, must-revalidate"}],
    game_json(game, id, now, ok, note)}

def done(game: Game, r: HTTP.Response) -> IO(Game & HTTP.Response):
  IO.pure(Game & HTTP.Response, (game, r))

def action_routed(action: Action, +id: U32, +now: U32) -> IO(Game & HTTP.Response):
  Action{+game, ok, note} = action
  done(game, game_response(game, id, now, ok, note))

def index.got(r: Result<&1, &1, U32 & String, String>) -> HTTP.Response:
  match r:
    case Done{page}:
      HTTP.html(page)
    case Fail{e}:
      HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run from the repository root\n")

def game_index(game: Game) -> IO(Game & HTTP.Response):
  do IO<Game & HTTP.Response>:
    r : Result<&1, &1, U32 & String, String> <- HTTP.read_text("Bend3/demos/minecraft_web/index.html")
    return (game, index.got(r))

def arg(xs: List<&2, String>, n: Nat) -> U32:
  Compat.to_u32(Maybe.default(&2, String, List.get(&2, String, xs, n), ""))

def has_args(xs: List<&2, String>, n: Nat) -> Bool:
  Nat.is_ge(List.length(&2, String, xs), n)

# One game route. `kind`: 1 state, 2 join, 3 move, 4 mine, 5 place, 6 leave.
def game_route.go(ok: Bool, kind: U32, +id: U32, +args: List<&2, String>, +game: Game, +now: U32) -> IO(Game & HTTP.Response):
  match ok:
    case False{}:
      done(game, HTTP.not_found())
    case True{}:
      match kind:
        case 1:
          +touched = game_state(game, id, now)
          done(touched, game_response(touched, id, now, 1, ""))
        case 2:
          action_routed(game_join(game, id, now), id, now)
        case 3:
          action_routed(game_move(game, id, arg(args, 1n), now), id, now)
        case 4:
          action_routed(game_mine(game, id, arg(args, 1n), arg(args, 2n), now), id, now)
        case 5:
          action_routed(game_place(game, id, arg(args, 1n), arg(args, 2n), arg(args, 3n), now), id, now)
        case other:
          action_routed(game_leave(game, id, now), id, now)

def game_route(kind: U32, +need: Nat, +args: List<&2, String>, game: Game, now: U32) -> IO(Game & HTTP.Response):
  game_route.go(has_args(args, need), kind, arg(args, 0n), args, game, now)

def route_kind(+name: String) -> U32:
  Bool.pick(U32, String.eq(name, "state"), 1,
  Bool.pick(U32, String.eq(name, "join"), 2,
  Bool.pick(U32, String.eq(name, "move"), 3,
  Bool.pick(U32, String.eq(name, "mine"), 4,
  Bool.pick(U32, String.eq(name, "place"), 5,
  Bool.pick(U32, String.eq(name, "leave"), 6, 0))))))

def route_need(kind: U32) -> Nat:
  match kind:
    case 3:
      2n
    case 4:
      3n
    case 5:
      4n
    case other:
      1n

def string_route(kind: U32, +args: List<&2, String>, game: Game, now: U32) -> IO(Game & HTTP.Response):
  match kind:
    case 0:
      done(game, HTTP.not_found())
    case +k:
      game_route(k, route_need(k), args, game, now)

def list_route.named(root: Bool, +name: String, +args: List<&2, String>, game: Game, now: U32) -> IO(Game & HTTP.Response):
  match root:
    case True{}:
      game_index(game)
    case False{}:
      string_route(route_kind(name), args, game, now)

# `parts` is the path split on '/', without the leading "" (and without a
# leading "minecraft" prefix).
def list_route(parts: List<&2, String>, game: Game, now: U32) -> IO(Game & HTTP.Response):
  match parts:
    case Nil{}:
      game_index(game)
    case +name <> args:
      list_route.named(String.is_empty(name), name, args, game, now)

def unprefix.pick(hub: Bool, +name: String, rest: List<&2, String>) -> List<&2, String>:
  match hub:
    case True{}:
      rest
    case False{}:
      name <> rest

def unprefix(parts: List<&2, String>) -> List<&2, String>:
  match parts:
    case Nil{}:
      Nil{}
    case _ <> Nil{}:
      Nil{}
    case _ <> +name <> rest:
      unprefix.pick(String.eq(name, "minecraft"), name, rest)

def route_at.go(get: Bool, +target: String, game: Game, now: U32) -> IO(Game & HTTP.Response):
  match get:
    case False{}:
      done(game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n"))
    case True{}:
      list_route(unprefix(HTTP.split_path(target)), game, now)

# The game's HTTP handler with an explicit clock reading.
def route_at(req: HTTP.Request, game: Game, now: U32) -> IO(Game & HTTP.Response):
  HTTP.Request{method, target, headers, body} = req
  route_at.go(String.eq(method, "GET"), target, game, now)

# The game's HTTP handler (HTTP.serve's shape).
def route(req: HTTP.Request, game: Game) -> IO(Game & HTTP.Response):
  do IO<Game & HTTP.Response>:
    now : U32 <- Clock.now_ms()
    route_at(req, game, now)

# ---------------------------------------------------------------- server

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Block World listening on all interfaces (0.0.0.0:8085)\nopen http://<server-lan-ip>:8085")
    HTTP.serve(~Game, ~route, "0.0.0.0", 8085, init())
