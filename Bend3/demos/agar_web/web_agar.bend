# web_agar: a four-player cell-eating arena over the local network.
#
# The Bend process owns movement, food, player consumption, respawns, and
# session cleanup. Browsers send a quantized desired direction and draw the
# returned snapshots.
#
# routes:
#   GET /                         the page
#   GET /state/<player>           watch or refresh a session
#   GET /join/<player>            take the first available slot
#   GET /input/<player>/<heading> set heading 0..15 and return a snapshot
#   GET /leave/<player>           leave the arena
#
# build: node bend-ts/src/main.ts gabriel_demos/agar_web/web_agar.bend --no-halt -o gabriel_demos/agar_web/web_agar
# run:   ./gabriel_demos/agar_web/web_agar
# open:  http://<server-lan-ip>:8084
#
# no-halt
# skip-native

import IO
import List
import String
import Char
import Result
import TCP
import HTTP
import ../Clock

tick_ms : U32 = 70
world_size : U32 = 1200
food_count : U32 = 54
player_timeout : U32 = 20000
respawn_ticks : U32 = 16

type Step:
  Step{x_pos: U32, x_by: U32, y_pos: U32, y_by: U32}

type Point:
  Point{x: U32, y: U32}

type Supply:
  Supply{points: List<Point>, seed: U32}

type Cell:
  Cell{id: U32, alive: U32, x: U32, y: U32, dir: U32, mass: U32, respawn: U32, seen: U32}

type Meal:
  Meal{ate: U32, points: List<Point>}

type Fed:
  Fed{cell: Cell, points: List<Point>, seed: U32}

type Duel:
  Duel{left: Cell, right: Cell}

type Game:
  Game{one: Cell, two: Cell, three: Cell, four: Cell, food: List<Point>, seed: U32, at: U32, tick: U32}

type Action:
  Action{game: Game, ok: U32, note: String}

type Routed:
  Routed{game: Game, response: Response}

# ---------------------------------------------------------------- U32

def u32_min(a: U32, b: U32) -> U32:
  match b < a:
    case 0:
      a
    case k:
      b

def u32_max(a: U32, b: U32) -> U32:
  match a < b:
    case 0:
      a
    case k:
      b

def u32_abs_diff(a: U32, b: U32) -> U32:
  match a < b:
    case 0:
      a - b
    case k:
      b - a

def u32_clamp(value: U32, low: U32, high: U32) -> U32:
  u32_min(u32_max(value, low), high)

def u32_move(value: U32, positive: U32, amount: U32) -> U32:
  match positive:
    case 0:
      match value < amount:
        case 0:
          value - amount
        case k:
          0
    case k:
      value + amount

def u32_step(dir: U32) -> Step:
  match dir % 16:
    case 0:
      Step{1, 10, 1, 0}
    case 1:
      Step{1, 9, 1, 4}
    case 2:
      Step{1, 7, 1, 7}
    case 3:
      Step{1, 4, 1, 9}
    case 4:
      Step{1, 0, 1, 10}
    case 5:
      Step{0, 4, 1, 9}
    case 6:
      Step{0, 7, 1, 7}
    case 7:
      Step{0, 9, 1, 4}
    case 8:
      Step{0, 10, 1, 0}
    case 9:
      Step{0, 9, 0, 4}
    case 10:
      Step{0, 7, 0, 7}
    case 11:
      Step{0, 4, 0, 9}
    case 12:
      Step{1, 0, 0, 10}
    case 13:
      Step{1, 4, 0, 9}
    case 14:
      Step{1, 7, 0, 7}
    case other:
      Step{1, 9, 0, 4}

def u32_random(seed: U32) -> U32:
  (seed * 1664525) + 1013904223

def u32_supply(n: U32, seed: U32) -> Supply:
  match n:
    case 0:
      Supply{Nil{}, seed}
    case k:
      sx = u32_random(seed)
      sy = u32_random(sx)
      tail = u32_supply(k - 1, sy)
      match tail:
        case Supply{points, out}:
          Supply{Cons{Point{30 + (sx % 1140), 30 + (sy % 1140)}, points}, out}

# ---------------------------------------------------------------- Point

def point_near(point: Point, other: Point, radius: U32) -> U32:
  match point:
    case Point{x, y}:
      match other:
        case Point{ox, oy}:
          dx = u32_abs_diff(x, ox)
          dy = u32_abs_diff(y, oy)
          ((dx * dx) + (dy * dy)) <= (radius * radius)

def point_json(point: Point) -> String:
  match point:
    case Point{x, y}:
      String::flatten(["[", String::from_u32(x), ",", String::from_u32(y), "]"])

# ---------------------------------------------------------------- List

def list_meal(point: Point, radius: U32, points: List<Point>) -> Meal:
  match points:
    case Cons{head, tail}:
      match point_near(point, head, radius):
        case 0:
          rest = list_meal(point, radius, tail)
          match rest:
            case Meal{ate, kept}:
              Meal{ate, Cons{head, kept}}
        case k:
          Meal{1, tail}
    case Nil{}:
      Meal{0, Nil{}}

def list_point_json_go(points: List<Point>) -> String:
  match points:
    case Cons{head, tail}:
      match tail:
        case Cons{next, rest}:
          String::flatten([point_json(head), ",", list_point_json_go(Cons{next, rest})])
        case Nil{}:
          point_json(head)
    case Nil{}:
      ""

def list_point_json(points: List<Point>) -> String:
  String::flatten(["[", list_point_json_go(points), "]"])

# ---------------------------------------------------------------- Cell

def cell_empty() -> Cell:
  Cell{0, 0, 0, 0, 0, 0, 0, 0}

def cell_spawn(slot: U32, id: U32, seen: U32) -> Cell:
  match slot:
    case 1:
      Cell{id, 1, 260, 260, 0, 5, 0, seen}
    case 2:
      Cell{id, 1, 940, 940, 8, 5, 0, seen}
    case 3:
      Cell{id, 1, 940, 260, 4, 5, 0, seen}
    case slot4:
      Cell{id, 1, 260, 940, 12, 5, 0, seen}

def cell_joined(cell: Cell) -> U32:
  match cell:
    case Cell{id, alive, x, y, dir, mass, respawn, seen}:
      id > 0

def cell_touch(cell: Cell, player: U32, now: U32) -> Cell:
  match cell:
    case Cell{id, alive, x, y, dir, mass, respawn, seen}:
      match id == player:
        case 0:
          Cell{id, alive, x, y, dir, mass, respawn, seen}
        case k:
          Cell{id, alive, x, y, dir, mass, respawn, now}

def cell_input(cell: Cell, player: U32, heading: U32, now: U32) -> Cell:
  match cell:
    case Cell{id, alive, x, y, dir, mass, respawn, seen}:
      match id == player:
        case 0:
          Cell{id, alive, x, y, dir, mass, respawn, seen}
        case k:
          Cell{id, alive, x, y, heading % 16, mass, respawn, now}

def cell_leave(cell: Cell, player: U32) -> Cell:
  match cell:
    case Cell{id, alive, x, y, dir, mass, respawn, seen}:
      match id == player:
        case 0:
          Cell{id, alive, x, y, dir, mass, respawn, seen}
        case k:
          cell_empty()

def cell_expire(cell: Cell, now: U32) -> Cell:
  match cell:
    case Cell{id, alive, x, y, dir, mass, respawn, seen}:
      match (id > 0) && ((now - seen) > player_timeout):
        case 0:
          Cell{id, alive, x, y, dir, mass, respawn, seen}
        case k:
          cell_empty()

def cell_step(cell: Cell, slot: U32) -> Cell:
  match cell:
    case Cell{id, alive, x, y, dir, mass, respawn, seen}:
      match id:
        case 0:
          cell_empty()
        case player:
          match alive:
            case 0:
              match respawn:
                case 0:
                  cell_spawn(slot, player, seen)
                case wait:
                  match wait == 1:
                    case 0:
                      Cell{player, 0, x, y, dir, 0, wait - 1, seen}
                    case k:
                      cell_spawn(slot, player, seen)
            case live:
              step = u32_step(dir)
              match step:
                case Step{x_pos, x_by, y_pos, y_by}:
                  pace = 10 - u32_min(mass / 8, 4)
                  radius = 18 + u32_min(mass, 34)
                  next_x = u32_clamp(u32_move(x, x_pos, (x_by * pace) / 10), radius, world_size - radius)
                  next_y = u32_clamp(u32_move(y, y_pos, (y_by * pace) / 10), radius, world_size - radius)
                  Cell{player, live, next_x, next_y, dir, mass, 0, seen}

def cell_kill(cell: Cell) -> Cell:
  match cell:
    case Cell{id, alive, x, y, dir, mass, respawn, seen}:
      Cell{id, 0, x, y, dir, 0, respawn_ticks, seen}

def cell_feed(cell: Cell, points: List<Point>, seed: U32) -> Fed:
  match cell:
    case Cell{id, alive, x, y, dir, mass, respawn, seen}:
      match alive:
        case 0:
          Fed{Cell{id, 0, x, y, dir, mass, respawn, seen}, points, seed}
        case live:
          meal = list_meal(Point{x, y}, 18 + u32_min(mass, 34), points)
          match meal:
            case Meal{ate, kept}:
              match ate:
                case 0:
                  Fed{Cell{id, live, x, y, dir, mass, respawn, seen}, kept, seed}
                case k:
                  sx = u32_random(seed)
                  sy = u32_random(sx)
                  Fed{Cell{id, live, x, y, dir, mass + 1, respawn, seen}, Cons{Point{30 + (sx % 1140), 30 + (sy % 1140)}, kept}, sy}

def cell_duel(left: Cell, right: Cell) -> Duel:
  match left:
    case Cell{left_id, left_alive, left_x, left_y, left_dir, left_mass, left_respawn, left_seen}:
      match right:
        case Cell{right_id, right_alive, right_x, right_y, right_dir, right_mass, right_respawn, right_seen}:
          close = point_near(Point{left_x, left_y}, Point{right_x, right_y}, 14 + u32_max(u32_min(left_mass, 34), u32_min(right_mass, 34)))
          match left_alive && right_alive && close:
            case 0:
              Duel{Cell{left_id, left_alive, left_x, left_y, left_dir, left_mass, left_respawn, left_seen}, Cell{right_id, right_alive, right_x, right_y, right_dir, right_mass, right_respawn, right_seen}}
            case together:
              match left_mass > (right_mass + 2):
                case 0:
                  match right_mass > (left_mass + 2):
                    case 0:
                      Duel{Cell{left_id, left_alive, left_x, left_y, left_dir, left_mass, left_respawn, left_seen}, Cell{right_id, right_alive, right_x, right_y, right_dir, right_mass, right_respawn, right_seen}}
                    case right_wins:
                      Duel{cell_kill(Cell{left_id, left_alive, left_x, left_y, left_dir, left_mass, left_respawn, left_seen}), Cell{right_id, right_alive, right_x, right_y, right_dir, right_mass + left_mass + 3, right_respawn, right_seen}}
                case left_wins:
                  Duel{Cell{left_id, left_alive, left_x, left_y, left_dir, left_mass + right_mass + 3, left_respawn, left_seen}, cell_kill(Cell{right_id, right_alive, right_x, right_y, right_dir, right_mass, right_respawn, right_seen})}

def cell_json(cell: Cell, slot: U32) -> String:
  match cell:
    case Cell{id, alive, x, y, dir, mass, respawn, seen}:
      String::flatten([
        "{\"slot\":", String::from_u32(slot),
        ",\"joined\":", String::from_u32(id > 0),
        ",\"alive\":", String::from_u32(alive),
        ",\"x\":", String::from_u32(x),
        ",\"y\":", String::from_u32(y),
        ",\"dir\":", String::from_u32(dir),
        ",\"mass\":", String::from_u32(mass),
        ",\"respawn\":", String::from_u32(respawn),
        "}"
      ])

# ---------------------------------------------------------------- Game

def game_empty(now: U32, seed: U32) -> Game:
  supply = u32_supply(food_count, seed)
  match supply:
    case Supply{points, out}:
      Game{cell_empty(), cell_empty(), cell_empty(), cell_empty(), points, out, now, 0}

def game_at(game: Game) -> U32:
  match game:
    case Game{one, two, three, four, food, seed, at, tick}:
      at

def game_retime(game: Game, now: U32) -> Game:
  match game:
    case Game{one, two, three, four, food, seed, at, tick}:
      Game{one, two, three, four, food, seed, now, tick}

def game_expire(game: Game, now: U32) -> Game:
  match game:
    case Game{one, two, three, four, food, seed, at, tick}:
      Game{cell_expire(one, now), cell_expire(two, now), cell_expire(three, now), cell_expire(four, now), food, seed, at, tick}

def game_step(game: Game) -> Game:
  match game:
    case Game{one, two, three, four, food, seed, at, tick}:
      moved_one = cell_step(one, 1)
      moved_two = cell_step(two, 2)
      moved_three = cell_step(three, 3)
      moved_four = cell_step(four, 4)

      fed_one = cell_feed(moved_one, food, seed)
      match fed_one:
        case Fed{food_one_cell, food_one, seed_one}:
          fed_two = cell_feed(moved_two, food_one, seed_one)
          match fed_two:
            case Fed{food_two_cell, food_two, seed_two}:
              fed_three = cell_feed(moved_three, food_two, seed_two)
              match fed_three:
                case Fed{food_three_cell, food_three, seed_three}:
                  fed_four = cell_feed(moved_four, food_three, seed_three)
                  match fed_four:
                    case Fed{food_four_cell, food_four, seed_four}:
                      duel_12 = cell_duel(food_one_cell, food_two_cell)
                      match duel_12:
                        case Duel{d12_one, d12_two}:
                          duel_13 = cell_duel(d12_one, food_three_cell)
                          match duel_13:
                            case Duel{d13_one, d13_three}:
                              duel_14 = cell_duel(d13_one, food_four_cell)
                              match duel_14:
                                case Duel{d14_one, d14_four}:
                                  duel_23 = cell_duel(d12_two, d13_three)
                                  match duel_23:
                                    case Duel{d23_two, d23_three}:
                                      duel_24 = cell_duel(d23_two, d14_four)
                                      match duel_24:
                                        case Duel{d24_two, d24_four}:
                                          duel_34 = cell_duel(d23_three, d24_four)
                                          match duel_34:
                                            case Duel{d34_three, d34_four}:
                                              Game{d14_one, d24_two, d34_three, d34_four, food_four, seed_four, at, tick + 1}

def game_steps(game: Game, count: U32) -> Game:
  match count:
    case 0:
      game
    case k:
      game_steps(game_step(game), k - 1)

def game_advance(game: Game, now: U32) -> Game:
  fresh = game_expire(game, now)
  at = game_at(fresh)
  elapsed = now - at
  raw = elapsed / tick_ms
  count = u32_min(raw, 5)
  advanced = game_steps(fresh, count)
  match raw > 5:
    case 0:
      game_retime(advanced, at + (count * tick_ms))
    case k:
      game_retime(advanced, now)

def game_player(game: Game, player: U32) -> U32:
  match game:
    case Game{one, two, three, four, food, seed, at, tick}:
      match one:
        case Cell{id_one, alive_one, x_one, y_one, dir_one, mass_one, respawn_one, seen_one}:
          match (id_one > 0) && (id_one == player):
            case 0:
              match two:
                case Cell{id_two, alive_two, x_two, y_two, dir_two, mass_two, respawn_two, seen_two}:
                  match (id_two > 0) && (id_two == player):
                    case 0:
                      match three:
                        case Cell{id_three, alive_three, x_three, y_three, dir_three, mass_three, respawn_three, seen_three}:
                          match (id_three > 0) && (id_three == player):
                            case 0:
                              match four:
                                case Cell{id_four, alive_four, x_four, y_four, dir_four, mass_four, respawn_four, seen_four}:
                                  match (id_four > 0) && (id_four == player):
                                    case 0:
                                      0
                                    case hit_four:
                                      4
                            case hit_three:
                              3
                    case hit_two:
                      2
            case hit_one:
              1

def game_touch(game: Game, player: U32, now: U32) -> Game:
  match game:
    case Game{one, two, three, four, food, seed, at, tick}:
      Game{cell_touch(one, player, now), cell_touch(two, player, now), cell_touch(three, player, now), cell_touch(four, player, now), food, seed, at, tick}

def game_error(game: Game, note: String) -> Action:
  Action{game, 0, note}

def game_ok(game: Game) -> Action:
  Action{game, 1, ""}

def game_join_open(game: Game, player: U32, now: U32) -> Action:
  match game:
    case Game{one, two, three, four, food, seed, at, tick}:
      match cell_joined(one):
        case 0:
          game_ok(Game{cell_spawn(1, player, now), two, three, four, food, seed, at, tick})
        case used_one:
          match cell_joined(two):
            case 0:
              game_ok(Game{one, cell_spawn(2, player, now), three, four, food, seed, at, tick})
            case used_two:
              match cell_joined(three):
                case 0:
                  game_ok(Game{one, two, cell_spawn(3, player, now), four, food, seed, at, tick})
                case used_three:
                  match cell_joined(four):
                    case 0:
                      game_ok(Game{one, two, three, cell_spawn(4, player, now), food, seed, at, tick})
                    case used_four:
                      game_error(Game{one, two, three, four, food, seed, at, tick}, "The arena already has four players.")

def game_join(game: Game, player: U32, now: U32) -> Action:
  match player:
    case 0:
      game_error(game, "Invalid player identity.")
    case id:
      slot = game_player(game, id)
      match slot:
        case 0:
          game_join_open(game, id, now)
        case own:
          game_ok(game_touch(game, id, now))

def game_input(game: Game, player: U32, heading: U32, now: U32) -> Action:
  slot = game_player(game, player)
  match slot:
    case 0:
      game_error(game, "Join the game before moving.")
    case own:
      match game:
        case Game{one, two, three, four, food, seed, at, tick}:
          game_ok(Game{cell_input(one, player, heading, now), cell_input(two, player, heading, now), cell_input(three, player, heading, now), cell_input(four, player, heading, now), food, seed, at, tick})

def game_state(game: Game, player: U32, now: U32) -> Action:
  game_ok(game_touch(game, player, now))

def game_leave(game: Game, player: U32) -> Action:
  slot = game_player(game, player)
  match slot:
    case 0:
      game_error(game, "This browser has not joined the game.")
    case own:
      match game:
        case Game{one, two, three, four, food, seed, at, tick}:
          game_ok(Game{cell_leave(one, player), cell_leave(two, player), cell_leave(three, player), cell_leave(four, player), food, seed, at, tick})

def game_json(game: Game, player: U32, ok: U32, note: String) -> String:
  match game:
    case Game{one, two, three, four, food, seed, at, tick}:
      String::flatten([
        "{\"ok\":", String::from_u32(ok),
        ",\"note\":\"", note,
        "\",\"you\":", String::from_u32(game_player(Game{one, two, three, four, food, seed, at, tick}, player)),
        ",\"full\":", String::from_u32(cell_joined(one) && cell_joined(two) && cell_joined(three) && cell_joined(four)),
        ",\"tick\":", String::from_u32(tick),
        ",\"players\":[", cell_json(one, 1), ",", cell_json(two, 2), ",", cell_json(three, 3), ",", cell_json(four, 4), "]",
        ",\"food\":", list_point_json(food),
        "}"
      ])

def game_response(game: Game, player: U32, ok: U32, note: String) -> Response:
  Response{200, [Header{"Content-Type", "application/json; charset=utf-8"}, Header{"Cache-Control", "no-store, no-cache, must-revalidate"}], HTTP::body(game_json(game, player, ok, note))}

def game_missing(game: Game) -> Routed:
  Routed{game, HTTP::not_found()}

def game_method(game: Game) -> Routed:
  Routed{game, HTTP::reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")}

# ---------------------------------------------------------------- Action

def action_routed(action: Action, player: U32) -> Routed:
  match action:
    case Action{game, ok, note}:
      Routed{game, game_response(game, player, ok, note)}

# ---------------------------------------------------------------- Result

def result_index(result: Result<String>, game: Game) -> IO<Routed>:
  match result:
    case Done{html}:
      IO::pure<Routed>(Routed{game, HTTP::reply(200, "text/html; charset=utf-8", html)})
    case Fail{code, error}:
      IO::pure<Routed>(Routed{game, HTTP::reply(500, "text/plain; charset=utf-8", "index.html not found -- run the server from the repository root\n")})

# ---------------------------------------------------------------- Routing

def game_index(game: Game) -> IO<Routed>:
  do IO<Routed>:
    result : Result<String> <- IO::read_text("gabriel_demos/agar_web/index.html")
    result_index(result, game)

def list_state(args: List<String>, game: Game, now: U32) -> IO<Routed>:
  match args:
    case Cons{player, rest}:
      id = String::to_u32(player)
      IO::pure<Routed>(action_routed(game_state(game, id, now), id))
    case Nil{}:
      IO::pure<Routed>(game_missing(game))

def list_join(args: List<String>, game: Game, now: U32) -> IO<Routed>:
  match args:
    case Cons{player, rest}:
      id = String::to_u32(player)
      IO::pure<Routed>(action_routed(game_join(game, id, now), id))
    case Nil{}:
      IO::pure<Routed>(game_missing(game))

def list_input(args: List<String>, game: Game, now: U32) -> IO<Routed>:
  match args:
    case Cons{player, Cons{heading, rest}}:
      id = String::to_u32(player)
      IO::pure<Routed>(action_routed(game_input(game, id, String::to_u32(heading), now), id))
    case other:
      IO::pure<Routed>(game_missing(game))

def list_leave(args: List<String>, game: Game) -> IO<Routed>:
  match args:
    case Cons{player, rest}:
      id = String::to_u32(player)
      IO::pure<Routed>(action_routed(game_leave(game, id), id))
    case Nil{}:
      IO::pure<Routed>(game_missing(game))

def string_route(name: String, args: List<String>, game: Game, now: U32) -> IO<Routed>:
  match String::eq(name, ""):
    case 0:
      match String::eq(name, "state"):
        case 0:
          match String::eq(name, "join"):
            case 0:
              match String::eq(name, "input"):
                case 0:
                  match String::eq(name, "leave"):
                    case 0:
                      IO::pure<Routed>(game_missing(game))
                    case leave:
                      list_leave(args, game)
                case input:
                  list_input(args, game, now)
            case join:
              list_join(args, game, now)
        case state:
          list_state(args, game, now)
    case index:
      game_index(game)

def list_route(parts: List<String>, game: Game, now: U32) -> IO<Routed>:
  match parts:
    case Cons{root, Cons{name, args}}:
      string_route(name, args, game, now)
    case Cons{root, Nil{}}:
      game_index(game)
    case Nil{}:
      game_index(game)

def request_route(request: Request, game: Game, now: U32) -> IO<Routed>:
  match request:
    case Request{method, path, headers, body}:
      match String::eq(method, "GET"):
        case 0:
          IO::pure<Routed>(game_method(game))
        case get:
          list_route(String::split('/', path), game, now)

# ---------------------------------------------------------------- Server

def routed_send(routed: Routed, server: U32, conn: Conn) -> IO<U32>:
  match routed:
    case Routed{game, response}:
      do IO<U32>:
        sent : Result<U32> <- HTTP::send_response(conn, HTTP::with_connection(0, response))
        closed : U32 <- HTTP::conn_close(conn)
        u32_serve(server, game)

def inbound_serve(inbound: Inbound, server: U32, conn: Conn, game: Game) -> IO<U32>:
  match inbound:
    case Got{http11, request, rest}:
      do IO<U32>:
        now : U32 <- clock_now_ms()
        routed : Routed <- request_route(request, game_advance(game, now), now)
        routed_send(routed, server, conn)
    case Closed{}:
      do IO<U32>:
        closed : U32 <- HTTP::conn_close(conn)
        u32_serve(server, game)
    case Bad{code, error}:
      routed_send(Routed{game, HTTP::err_response(code, error)}, server, conn)

def result_accept(result: Result<U32>, server: U32, game: Game) -> IO<U32>:
  match result:
    case Done{fd}:
      do IO<U32>:
        inbound : Inbound <- HTTP::read_request(Plain{fd}, Nil{})
        inbound_serve(inbound, server, Plain{fd}, game)
    case Fail{code, error}:
      do IO<U32>:
        printed : U32 <- IO::print_err(String::flatten(["accept failed: ", error, "\n"]))
        return 1

def u32_serve(server: U32, game: Game) -> IO<U32>:
  do IO<U32>:
    result : Result<U32> <- TCP::accept(server)
    result_accept(result, server, game)

def result_main(result: Result<U32>, now: U32, seed: U32) -> IO<U32>:
  match result:
    case Done{server}:
      do IO<U32>:
        printed : U32 <- IO::print("cell arena listening on all interfaces (0.0.0.0:8084)\nopen http://<server-lan-ip>:8084 on up to four devices\n")
        u32_serve(server, game_empty(now, seed))
    case Fail{code, error}:
      do IO<U32>:
        printed : U32 <- IO::print_err(String::flatten(["listen failed: ", error, "\n"]))
        return 1

def main() -> IO<U32>:
  do IO<U32>:
    now : U32 <- clock_now_ms()
    seed : U32 <- IO::rand()
    result : Result<U32> <- TCP::listen(8084)
    result_main(result, now, seed)
