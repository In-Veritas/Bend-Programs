# web_slither: a four-player snake arena over the local network.
#
# The Bend process owns the complete game. Browsers send a desired heading,
# receive authoritative snapshots, and interpolate them for smooth drawing.
# The simulation advances in fixed 70 ms ticks from a monotonic clock, so its
# speed does not depend on the number of connected browsers.
#
# routes:
#   GET /                         the page (run from the repository root)
#   GET /state/<player>           watch or refresh a player's session
#   GET /join/<player>            take the first available slot
#   GET /input/<player>/<heading> set heading 0..15 and return a snapshot
#   GET /leave/<player>           leave the arena
#
# build: bun bend-ts/src/bend.ts gabriel_demos/slither_web/web_slither.bend --no-halt -o gabriel_demos/slither_web/web_slither
# run:   ./gabriel_demos/slither_web/web_slither
# open:  http://<server-lan-ip>:8083
#
# no-halt
# skip-native

import ../../bend-base/Base
import ../Compat
import ../../bend-base/IO/TCP
import ../../bend-base/IO/HTTP
import ../Clock

def tick_ms() -> U32: 70
def arena_min() -> U32: 18
def arena_max() -> U32: 982
def food_count() -> U32: 36
def body_start() -> U32: 18
def body_max() -> U32: 72
def player_timeout() -> U32: 20000
def respawn_ticks() -> U32: 18

type Step:
  Step{x_pos: U32, x_by: U32, y_pos: U32, y_by: U32}

type Point:
  Point{x: U32, y: U32}

type Supply:
  Supply{points: List(Point), seed: U32}

type Snake:
  Snake{id: U32, alive: U32, dir: U32, want: U32, score: U32, grow: U32, respawn: U32, seen: U32, body: List(Point)}

type Meal:
  Meal{ate: U32, points: List(Point)}

type Fed:
  Fed{snake: Snake, points: List(Point), seed: U32}

type Game:
  Game{one: Snake, two: Snake, three: Snake, four: Snake, food: List(Point), seed: U32, at: U32, tick: U32}

type Action:
  Action{game: Game, ok: U32, note: String}

type Routed:
  Routed{game: Game, response: HTTP.Response}

# ---------------------------------------------------------------- U32

def u32_min(a: U32, b: U32) -> U32:
  match b < a:
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
      Step.Step{1, 10, 1, 0}
    case 1:
      Step.Step{1, 9, 1, 4}
    case 2:
      Step.Step{1, 7, 1, 7}
    case 3:
      Step.Step{1, 4, 1, 9}
    case 4:
      Step.Step{1, 0, 1, 10}
    case 5:
      Step.Step{0, 4, 1, 9}
    case 6:
      Step.Step{0, 7, 1, 7}
    case 7:
      Step.Step{0, 9, 1, 4}
    case 8:
      Step.Step{0, 10, 1, 0}
    case 9:
      Step.Step{0, 9, 0, 4}
    case 10:
      Step.Step{0, 7, 0, 7}
    case 11:
      Step.Step{0, 4, 0, 9}
    case 12:
      Step.Step{1, 0, 0, 10}
    case 13:
      Step.Step{1, 4, 0, 9}
    case 14:
      Step.Step{1, 7, 0, 7}
    case other:
      Step.Step{1, 9, 0, 4}

def u32_turn(dir: U32, want: U32) -> U32:
  gap = (((want % 16) + 16) - (dir % 16)) % 16
  match gap:
    case 0:
      dir % 16
    case k:
      match k < 9:
        case 0:
          (dir + 15) % 16
        case j:
          (dir + 1) % 16

def u32_random(seed: U32) -> U32:
  (seed * 1664525) + 1013904223

def u32_supply(n: U32, seed: U32) -> Supply:
  match n:
    case 0:
      Supply.Supply{List.Nil{}, seed}
    case k:
      sx = u32_random(seed)
      sy = u32_random(sx)
      tail = u32_supply(k - 1, sy)
      match tail:
        case Supply.Supply{points, out}:
          Supply.Supply{List.Cons{Point.Point{40 + (sx % 920), 40 + (sy % 920)}, points}, out}

# ---------------------------------------------------------------- Point

def point_move(point: Point, dir: U32) -> Point:
  match point:
    case Point.Point{x, y}:
      step = u32_step(dir)
      match step:
        case Step.Step{x_pos, x_by, y_pos, y_by}:
          Point.Point{u32_move(x, x_pos, x_by), u32_move(y, y_pos, y_by)}

def point_near(point: Point, other: Point, radius: U32) -> U32:
  match point:
    case Point.Point{x, y}:
      match other:
        case Point.Point{ox, oy}:
          dx = u32_abs_diff(x, ox)
          dy = u32_abs_diff(y, oy)
          ((dx * dx) + (dy * dy)) <= (radius * radius)

def point_out(point: Point) -> U32:
  match point:
    case Point.Point{x, y}:
      (x < arena_min()) || ((x > arena_max()) || ((y < arena_min()) || (y > arena_max())))

def point_body(point: Point, back: U32, n: U32) -> List(Point):
  match n:
    case 0:
      List.Nil{}
    case k:
      List.Cons{point, point_body(point_move(point, back), back, k - 1)}

def point_advance_body(point: Point, tail: List(Point), dir: U32) -> List(Point):
  match point:
    case Point.Point{x, y}:
      List.Cons{point_move(Point.Point{x, y}, dir), List.Cons{Point.Point{x, y}, tail}}

def point_json(point: Point) -> String:
  match point:
    case Point.Point{x, y}:
      String.flatten(["[", String.from_u32(x), ",", String.from_u32(y), "]"])

# ---------------------------------------------------------------- List

def list_near(point: Point, points: List(Point), skip: U32, radius: U32) -> U32:
  match points:
    case List.Cons{head, tail}:
      match skip:
        case 0:
          point_near(point, head, radius) || list_near(point, tail, 0, radius)
        case k:
          list_near(point, tail, k - 1, radius)
    case List.Nil{}:
      0

def list_meal(point: Point, points: List(Point)) -> Meal:
  match points:
    case List.Cons{head, tail}:
      match point_near(point, head, 22):
        case 0:
          rest = list_meal(point, tail)
          match rest:
            case Meal.Meal{ate, kept}:
              Meal.Meal{ate, List.Cons{head, kept}}
        case k:
          Meal.Meal{1, tail}
    case List.Nil{}:
      Meal.Meal{0, List.Nil{}}

def list_drop_last(points: List(Point)) -> List(Point):
  match points:
    case List.Cons{head, tail}:
      match tail:
        case List.Cons{next, rest}:
          List.Cons{head, list_drop_last(List.Cons{next, rest})}
        case List.Nil{}:
          List.Nil{}
    case List.Nil{}:
      List.Nil{}

def list_point_json_go(points: List(Point)) -> String:
  match points:
    case List.Cons{head, tail}:
      match tail:
        case List.Cons{next, rest}:
          String.flatten([point_json(head), ",", list_point_json_go(List.Cons{next, rest})])
        case List.Nil{}:
          point_json(head)
    case List.Nil{}:
      ""

def list_point_json(points: List(Point)) -> String:
  String.flatten(["[", list_point_json_go(points), "]"])

# ---------------------------------------------------------------- Snake

def snake_empty() -> Snake:
  Snake.Snake{0, 0, 0, 0, 0, 0, 0, 0, List.Nil{}}

def snake_spawn(slot: U32, id: U32, seen: U32) -> Snake:
  match slot:
    case 1:
      Snake.Snake{id, 1, 0, 0, 0, 0, 0, seen, point_body(Point.Point{250, 250}, 8, body_start())}
    case 2:
      Snake.Snake{id, 1, 8, 8, 0, 0, 0, seen, point_body(Point.Point{750, 750}, 0, body_start())}
    case 3:
      Snake.Snake{id, 1, 4, 4, 0, 0, 0, seen, point_body(Point.Point{750, 250}, 12, body_start())}
    case slot4:
      Snake.Snake{id, 1, 12, 12, 0, 0, 0, seen, point_body(Point.Point{250, 750}, 4, body_start())}

def snake_joined(snake: Snake) -> U32:
  match snake:
    case Snake.Snake{id, alive, dir, want, score, grow, respawn, seen, body}:
      id > 0

def snake_touch(snake: Snake, player: U32, now: U32) -> Snake:
  match snake:
    case Snake.Snake{id, alive, dir, want, score, grow, respawn, seen, body}:
      match id == player:
        case 0:
          Snake.Snake{id, alive, dir, want, score, grow, respawn, seen, body}
        case k:
          Snake.Snake{id, alive, dir, want, score, grow, respawn, now, body}

def snake_input(snake: Snake, player: U32, heading: U32, now: U32) -> Snake:
  match snake:
    case Snake.Snake{id, alive, dir, want, score, grow, respawn, seen, body}:
      match id == player:
        case 0:
          Snake.Snake{id, alive, dir, want, score, grow, respawn, seen, body}
        case k:
          Snake.Snake{id, alive, dir, heading % 16, score, grow, respawn, now, body}

def snake_leave(snake: Snake, player: U32) -> Snake:
  match snake:
    case Snake.Snake{id, alive, dir, want, score, grow, respawn, seen, body}:
      match id == player:
        case 0:
          Snake.Snake{id, alive, dir, want, score, grow, respawn, seen, body}
        case k:
          snake_empty()

def snake_expire(snake: Snake, now: U32) -> Snake:
  match snake:
    case Snake.Snake{id, alive, dir, want, score, grow, respawn, seen, body}:
      match (id > 0) && ((now - seen) > player_timeout()):
        case 0:
          Snake.Snake{id, alive, dir, want, score, grow, respawn, seen, body}
        case k:
          snake_empty()

def snake_step(snake: Snake, slot: U32) -> Snake:
  match snake:
    case Snake.Snake{id, alive, dir, want, score, grow, respawn, seen, body}:
      match id:
        case 0:
          snake_empty()
        case player:
          match alive:
            case 0:
              match respawn:
                case 0:
                  snake_spawn(slot, player, seen)
                case wait:
                  match wait == 1:
                    case 0:
                      Snake.Snake{player, 0, dir, want, 0, 0, wait - 1, seen, List.Nil{}}
                    case k:
                      snake_spawn(slot, player, seen)
            case live:
              next_dir = u32_turn(dir, want)
              match body:
                case List.Cons{head, tail}:
                  next_body = point_advance_body(head, tail, next_dir)
                  match grow:
                    case 0:
                      Snake.Snake{player, live, next_dir, want, score, 0, 0, seen, list_drop_last(next_body)}
                    case more:
                      Snake.Snake{player, live, next_dir, want, score, more - 1, 0, seen, List.take(Point, body_max(), next_body)}
                case List.Nil{}:
                  snake_spawn(slot, player, seen)

def snake_body_near(snake: Snake, point: Point, skip: U32) -> U32:
  match snake:
    case Snake.Snake{id, alive, dir, want, score, grow, respawn, seen, body}:
      match alive:
        case 0:
          0
        case k:
          list_near(point, body, skip, 15)

def snake_kill(snake: Snake) -> Snake:
  match snake:
    case Snake.Snake{id, alive, dir, want, score, grow, respawn, seen, body}:
      Snake.Snake{id, 0, dir, want, 0, 0, respawn_ticks(), seen, List.Nil{}}

def snake_crash(snake: Snake, other_a: Snake, other_b: Snake, other_c: Snake) -> Snake:
  match snake:
    case Snake.Snake{id, alive, dir, want, score, grow, respawn, seen, body}:
      match alive:
        case 0:
          Snake.Snake{id, 0, dir, want, score, grow, respawn, seen, body}
        case live:
          head = List.head(Point, Point.Point{500, 500}, body)
          hit = point_out(head) || (
                list_near(head, body, 5, 15) || (
                snake_body_near(other_a, head, 0) || (
                snake_body_near(other_b, head, 0) ||
                snake_body_near(other_c, head, 0))))
          match hit:
            case 0:
              Snake.Snake{id, live, dir, want, score, grow, respawn, seen, body}
            case k:
              snake_kill(Snake.Snake{id, live, dir, want, score, grow, respawn, seen, body})

def snake_feed(snake: Snake, points: List(Point), seed: U32) -> Fed:
  match snake:
    case Snake.Snake{id, alive, dir, want, score, grow, respawn, seen, body}:
      match alive:
        case 0:
          Fed.Fed{Snake.Snake{id, 0, dir, want, score, grow, respawn, seen, body}, points, seed}
        case live:
          meal = list_meal(List.head(Point, Point.Point{500, 500}, body), points)
          match meal:
            case Meal.Meal{ate, kept}:
              match ate:
                case 0:
                  Fed.Fed{Snake.Snake{id, live, dir, want, score, grow, respawn, seen, body}, kept, seed}
                case k:
                  sx = u32_random(seed)
                  sy = u32_random(sx)
                  Fed.Fed{Snake.Snake{id, live, dir, want, score + 1, grow + 3, respawn, seen, body}, List.Cons{Point.Point{40 + (sx % 920), 40 + (sy % 920)}, kept}, sy}

def snake_json(snake: Snake, slot: U32) -> String:
  match snake:
    case Snake.Snake{id, alive, dir, want, score, grow, respawn, seen, body}:
      String.flatten([
        "{\"slot\":", String.from_u32(slot),
        ",\"joined\":", String.from_u32(id > 0),
        ",\"alive\":", String.from_u32(alive),
        ",\"dir\":", String.from_u32(dir),
        ",\"score\":", String.from_u32(score),
        ",\"respawn\":", String.from_u32(respawn),
        ",\"body\":", list_point_json(body),
        "}"
      ])

# ---------------------------------------------------------------- Game

def game_empty(now: U32, seed: U32) -> Game:
  supply = u32_supply(food_count(), seed)
  match supply:
    case Supply.Supply{points, out}:
      Game.Game{snake_empty(), snake_empty(), snake_empty(), snake_empty(), points, out, now, 0}

def game_at(game: Game) -> U32:
  match game:
    case Game.Game{one, two, three, four, food, seed, at, tick}:
      at

def game_retime(game: Game, now: U32) -> Game:
  match game:
    case Game.Game{one, two, three, four, food, seed, at, tick}:
      Game.Game{one, two, three, four, food, seed, now, tick}

def game_expire(game: Game, now: U32) -> Game:
  match game:
    case Game.Game{one, two, three, four, food, seed, at, tick}:
      Game.Game{snake_expire(one, now), snake_expire(two, now), snake_expire(three, now), snake_expire(four, now), food, seed, at, tick}

def game_step(game: Game) -> Game:
  match game:
    case Game.Game{one, two, three, four, food, seed, at, tick}:
      moved_one = snake_step(one, 1)
      moved_two = snake_step(two, 2)
      moved_three = snake_step(three, 3)
      moved_four = snake_step(four, 4)

      safe_one = snake_crash(moved_one, moved_two, moved_three, moved_four)
      safe_two = snake_crash(moved_two, moved_one, moved_three, moved_four)
      safe_three = snake_crash(moved_three, moved_one, moved_two, moved_four)
      safe_four = snake_crash(moved_four, moved_one, moved_two, moved_three)

      fed_one = snake_feed(safe_one, food, seed)
      match fed_one:
        case Fed.Fed{next_one, food_one, seed_one}:
          fed_two = snake_feed(safe_two, food_one, seed_one)
          match fed_two:
            case Fed.Fed{next_two, food_two, seed_two}:
              fed_three = snake_feed(safe_three, food_two, seed_two)
              match fed_three:
                case Fed.Fed{next_three, food_three, seed_three}:
                  fed_four = snake_feed(safe_four, food_three, seed_three)
                  match fed_four:
                    case Fed.Fed{next_four, food_four, seed_four}:
                      Game.Game{next_one, next_two, next_three, next_four, food_four, seed_four, at, tick + 1}

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
  raw = elapsed / tick_ms()
  count = u32_min(raw, 5)
  advanced = game_steps(fresh, count)
  match raw > 5:
    case 0:
      game_retime(advanced, at + (count * tick_ms()))
    case k:
      game_retime(advanced, now)

def game_player(game: Game, player: U32) -> U32:
  match game:
    case Game.Game{one, two, three, four, food, seed, at, tick}:
      match one:
        case Snake.Snake{id_one, alive_one, dir_one, want_one, score_one, grow_one, respawn_one, seen_one, body_one}:
          match (id_one > 0) && (id_one == player):
            case 0:
              match two:
                case Snake.Snake{id_two, alive_two, dir_two, want_two, score_two, grow_two, respawn_two, seen_two, body_two}:
                  match (id_two > 0) && (id_two == player):
                    case 0:
                      match three:
                        case Snake.Snake{id_three, alive_three, dir_three, want_three, score_three, grow_three, respawn_three, seen_three, body_three}:
                          match (id_three > 0) && (id_three == player):
                            case 0:
                              match four:
                                case Snake.Snake{id_four, alive_four, dir_four, want_four, score_four, grow_four, respawn_four, seen_four, body_four}:
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
    case Game.Game{one, two, three, four, food, seed, at, tick}:
      Game.Game{snake_touch(one, player, now), snake_touch(two, player, now), snake_touch(three, player, now), snake_touch(four, player, now), food, seed, at, tick}

def game_error(game: Game, note: String) -> Action:
  Action.Action{game, 0, note}

def game_ok(game: Game) -> Action:
  Action.Action{game, 1, ""}

def game_join_open(game: Game, player: U32, now: U32) -> Action:
  match game:
    case Game.Game{one, two, three, four, food, seed, at, tick}:
      match snake_joined(one):
        case 0:
          game_ok(Game.Game{snake_spawn(1, player, now), two, three, four, food, seed, at, tick})
        case used_one:
          match snake_joined(two):
            case 0:
              game_ok(Game.Game{one, snake_spawn(2, player, now), three, four, food, seed, at, tick})
            case used_two:
              match snake_joined(three):
                case 0:
                  game_ok(Game.Game{one, two, snake_spawn(3, player, now), four, food, seed, at, tick})
                case used_three:
                  match snake_joined(four):
                    case 0:
                      game_ok(Game.Game{one, two, three, snake_spawn(4, player, now), food, seed, at, tick})
                    case used_four:
                      game_error(Game.Game{one, two, three, four, food, seed, at, tick}, "The arena already has four players.")

def game_join(game: Game, player: U32, now: U32) -> Action:
  match player:
    case 0:
      game_error(game, "Invalid player identity.")
    case id:
      match game_player(game, id):
        case 0:
          game_join_open(game, id, now)
        case slot:
          game_ok(game_touch(game, id, now))

def game_input(game: Game, player: U32, heading: U32, now: U32) -> Action:
  slot = game_player(game, player)
  match slot:
    case 0:
      game_error(game, "Join the game before moving.")
    case slot:
      match game:
        case Game.Game{one, two, three, four, food, seed, at, tick}:
          game_ok(Game.Game{
            snake_input(one, player, heading, now),
            snake_input(two, player, heading, now),
            snake_input(three, player, heading, now),
            snake_input(four, player, heading, now),
            food, seed, at, tick
          })

def game_state(game: Game, player: U32, now: U32) -> Action:
  game_ok(game_touch(game, player, now))

def game_leave(game: Game, player: U32) -> Action:
  slot = game_player(game, player)
  match slot:
    case 0:
      game_error(game, "This browser has not joined the game.")
    case slot:
      match game:
        case Game.Game{one, two, three, four, food, seed, at, tick}:
          game_ok(Game.Game{snake_leave(one, player), snake_leave(two, player), snake_leave(three, player), snake_leave(four, player), food, seed, at, tick})

def game_json(game: Game, player: U32, ok: U32, note: String) -> String:
  match game:
    case Game.Game{one, two, three, four, food, seed, at, tick}:
      String.flatten([
        "{\"ok\":", String.from_u32(ok),
        ",\"note\":\"", note,
        "\",\"you\":", String.from_u32(game_player(Game.Game{one, two, three, four, food, seed, at, tick}, player)),
        ",\"full\":", String.from_u32(snake_joined(one) && (snake_joined(two) && (snake_joined(three) && snake_joined(four)))),
        ",\"tick\":", String.from_u32(tick),
        ",\"players\":[", snake_json(one, 1), ",", snake_json(two, 2), ",", snake_json(three, 3), ",", snake_json(four, 4), "]",
        ",\"food\":", list_point_json(food),
        "}"
      ])

def game_response(game: Game, player: U32, ok: U32, note: String) -> HTTP.Response:
  HTTP.Response.Response{200,
    [HTTP.Header.Header{"Content-Type", "application/json; charset=utf-8"},
     HTTP.Header.Header{"Cache-Control", "no-store, no-cache, must-revalidate"}],
    Bytes.from_string(game_json(game, player, ok, note))}

def game_missing(game: Game) -> Routed:
  Routed.Routed{game, HTTP.not_found()}

def game_method(game: Game) -> Routed:
  Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")}

# ---------------------------------------------------------------- Action

def action_routed(action: Action, player: U32) -> Routed:
  match action:
    case Action.Action{game, ok, note}:
      Routed.Routed{game, game_response(game, player, ok, note)}

# ---------------------------------------------------------------- Result

def result_index(result: Result((U32 & String), String), game: Game) -> IO(Routed):
  match result:
    case Result.Done{html}:
      IO.pure(Routed, Routed.Routed{game, HTTP.reply(200, "text/html; charset=utf-8", html)})
    case Result.Fail{(code, error)}:
      IO.pure(Routed, Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run the server from the repository root\n")})

# ---------------------------------------------------------------- Routing

def game_index(game: Game) -> IO(Routed):
  do IO(Routed):
    result <- IO.read_text("gabriel_demos/slither_web/index.html")
    result_index(result, game)

def list_state(args: List(String), game: Game, now: U32) -> IO(Routed):
  match args:
    case List.Cons{player, rest}:
      id = String.to_u32(player)
      IO.pure(Routed, action_routed(game_state(game, id, now), id))
    case List.Nil{}:
      IO.pure(Routed, game_missing(game))

def list_join(args: List(String), game: Game, now: U32) -> IO(Routed):
  match args:
    case List.Cons{player, rest}:
      id = String.to_u32(player)
      IO.pure(Routed, action_routed(game_join(game, id, now), id))
    case List.Nil{}:
      IO.pure(Routed, game_missing(game))

def list_input(args: List(String), game: Game, now: U32) -> IO(Routed):
  match args:
    case List.Cons{player, List.Cons{heading, rest}}:
      id = String.to_u32(player)
      IO.pure(Routed, action_routed(game_input(game, id, String.to_u32(heading), now), id))
    case other:
      IO.pure(Routed, game_missing(game))

def list_leave(args: List(String), game: Game) -> IO(Routed):
  match args:
    case List.Cons{player, rest}:
      id = String.to_u32(player)
      IO.pure(Routed, action_routed(game_leave(game, id), id))
    case List.Nil{}:
      IO.pure(Routed, game_missing(game))

def string_route(name: String, args: List(String), game: Game, now: U32) -> IO(Routed):
  match String.eq_u32(name, ""):
    case 0:
      match String.eq_u32(name, "state"):
        case 0:
          match String.eq_u32(name, "join"):
            case 0:
              match String.eq_u32(name, "input"):
                case 0:
                  match String.eq_u32(name, "leave"):
                    case 0:
                      IO.pure(Routed, game_missing(game))
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
        case get:
          list_route(String.split('/', path), game, now)

# ---------------------------------------------------------------- Server

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
        routed <- request_route(request, game_advance(game, now), now)
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

def result_main(result: Result((U32 & String), TCP), now: U32, seed: U32) -> IO(U32):
  match result:
    case Result.Done{server}:
      do IO(U32):
        printed <- IO.write("snake arena listening on all interfaces (0.0.0.0:8083)\nopen http://<server-lan-ip>:8083 on up to four devices\n")
        u32_serve(server, game_empty(now, seed))
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def main() -> IO(U32):
  do IO(U32):
    now <- clock_now_ms()
    seed <- IO.rand_word()
    result <- TCP.listen(8083)
    result_main(result, now, seed)
