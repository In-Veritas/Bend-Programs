# Generated hub-private namespace from ../agar_web/web_agar.bend.
# Regenerate after changing the standalone source.

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
# build: bun bend-ts/src/bend.ts gabriel_demos/agar_web/web_agar.bend --no-halt -o gabriel_demos/agar_web/web_agar
# run:   ./gabriel_demos/agar_web/web_agar
# open:  http://<server-lan-ip>:8084
#
# no-halt
# skip-native

import ../../../bend-base/Base
import ../../Compat
import ../../../bend-base/IO/TCP
import ../../../bend-base/IO/HTTP
import ../../Clock

def Cells.tick_ms() -> U32: 70
def Cells.world_size() -> U32: 1200
def Cells.food_count() -> U32: 54
def Cells.player_timeout() -> U32: 20000
def Cells.respawn_ticks() -> U32: 16

type Cells.Step:
  Step{x_pos: U32, x_by: U32, y_pos: U32, y_by: U32}

type Cells.Point:
  Point{x: U32, y: U32}

type Cells.Supply:
  Supply{points: List(Cells.Point), seed: U32}

type Cells.Cell:
  Cell{id: U32, alive: U32, x: U32, y: U32, dir: U32, mass: U32, respawn: U32, seen: U32}

type Cells.Meal:
  Meal{ate: U32, points: List(Cells.Point)}

type Cells.Fed:
  Fed{cell: Cells.Cell, points: List(Cells.Point), seed: U32}

type Cells.Duel:
  Duel{left: Cells.Cell, right: Cells.Cell}

type Cells.Game:
  Game{one: Cells.Cell, two: Cells.Cell, three: Cells.Cell, four: Cells.Cell, food: List(Cells.Point), seed: U32, at: U32, tick: U32}

type Cells.Action:
  Action{game: Cells.Game, ok: U32, note: String}

type Cells.Routed:
  Routed{game: Cells.Game, response: HTTP.Response}

# ---------------------------------------------------------------- U32

def Cells.u32_min(a: U32, b: U32) -> U32:
  match b < a:
    case 0:
      a
    case k:
      b

def Cells.u32_max(a: U32, b: U32) -> U32:
  match a < b:
    case 0:
      a
    case k:
      b

def Cells.u32_abs_diff(a: U32, b: U32) -> U32:
  match a < b:
    case 0:
      a - b
    case k:
      b - a

def Cells.u32_clamp(value: U32, low: U32, high: U32) -> U32:
  Cells.u32_min(Cells.u32_max(value, low), high)

def Cells.u32_move(value: U32, positive: U32, amount: U32) -> U32:
  match positive:
    case 0:
      match value < amount:
        case 0:
          value - amount
        case k:
          0
    case k:
      value + amount

def Cells.u32_step(dir: U32) -> Cells.Step:
  match dir % 16:
    case 0:
      Cells.Step.Step{1, 10, 1, 0}
    case 1:
      Cells.Step.Step{1, 9, 1, 4}
    case 2:
      Cells.Step.Step{1, 7, 1, 7}
    case 3:
      Cells.Step.Step{1, 4, 1, 9}
    case 4:
      Cells.Step.Step{1, 0, 1, 10}
    case 5:
      Cells.Step.Step{0, 4, 1, 9}
    case 6:
      Cells.Step.Step{0, 7, 1, 7}
    case 7:
      Cells.Step.Step{0, 9, 1, 4}
    case 8:
      Cells.Step.Step{0, 10, 1, 0}
    case 9:
      Cells.Step.Step{0, 9, 0, 4}
    case 10:
      Cells.Step.Step{0, 7, 0, 7}
    case 11:
      Cells.Step.Step{0, 4, 0, 9}
    case 12:
      Cells.Step.Step{1, 0, 0, 10}
    case 13:
      Cells.Step.Step{1, 4, 0, 9}
    case 14:
      Cells.Step.Step{1, 7, 0, 7}
    case other:
      Cells.Step.Step{1, 9, 0, 4}

def Cells.u32_random(seed: U32) -> U32:
  (seed * 1664525) + 1013904223

def Cells.u32_supply(n: U32, seed: U32) -> Cells.Supply:
  match n:
    case 0:
      Cells.Supply.Supply{List.Nil{}, seed}
    case k:
      sx = Cells.u32_random(seed)
      sy = Cells.u32_random(sx)
      tail = Cells.u32_supply(k - 1, sy)
      match tail:
        case Cells.Supply.Supply{points, out}:
          Cells.Supply.Supply{List.Cons{Cells.Point.Point{30 + (sx % 1140), 30 + (sy % 1140)}, points}, out}

# ---------------------------------------------------------------- Point

def Cells.point_near(point: Cells.Point, other: Cells.Point, radius: U32) -> U32:
  match point:
    case Cells.Point.Point{x, y}:
      match other:
        case Cells.Point.Point{ox, oy}:
          dx = Cells.u32_abs_diff(x, ox)
          dy = Cells.u32_abs_diff(y, oy)
          ((dx * dx) + (dy * dy)) <= (radius * radius)

def Cells.point_json(point: Cells.Point) -> String:
  match point:
    case Cells.Point.Point{x, y}:
      String.flatten(["[", String.from_u32(x), ",", String.from_u32(y), "]"])

# ---------------------------------------------------------------- List

def Cells.list_meal(point: Cells.Point, radius: U32, points: List(Cells.Point)) -> Cells.Meal:
  match points:
    case List.Cons{head, tail}:
      match Cells.point_near(point, head, radius):
        case 0:
          rest = Cells.list_meal(point, radius, tail)
          match rest:
            case Cells.Meal.Meal{ate, kept}:
              Cells.Meal.Meal{ate, List.Cons{head, kept}}
        case k:
          Cells.Meal.Meal{1, tail}
    case List.Nil{}:
      Cells.Meal.Meal{0, List.Nil{}}

def Cells.list_point_json_go(points: List(Cells.Point)) -> String:
  match points:
    case List.Cons{head, tail}:
      match tail:
        case List.Cons{next, rest}:
          String.flatten([Cells.point_json(head), ",", Cells.list_point_json_go(List.Cons{next, rest})])
        case List.Nil{}:
          Cells.point_json(head)
    case List.Nil{}:
      ""

def Cells.list_point_json(points: List(Cells.Point)) -> String:
  String.flatten(["[", Cells.list_point_json_go(points), "]"])

# ---------------------------------------------------------------- Cell

def Cells.cell_empty() -> Cells.Cell:
  Cells.Cell.Cell{0, 0, 0, 0, 0, 0, 0, 0}

def Cells.cell_spawn(slot: U32, id: U32, seen: U32) -> Cells.Cell:
  match slot:
    case 1:
      Cells.Cell.Cell{id, 1, 260, 260, 0, 5, 0, seen}
    case 2:
      Cells.Cell.Cell{id, 1, 940, 940, 8, 5, 0, seen}
    case 3:
      Cells.Cell.Cell{id, 1, 940, 260, 4, 5, 0, seen}
    case slot4:
      Cells.Cell.Cell{id, 1, 260, 940, 12, 5, 0, seen}

def Cells.cell_joined(cell: Cells.Cell) -> U32:
  match cell:
    case Cells.Cell.Cell{id, alive, x, y, dir, mass, respawn, seen}:
      id > 0

def Cells.cell_touch(cell: Cells.Cell, player: U32, now: U32) -> Cells.Cell:
  match cell:
    case Cells.Cell.Cell{id, alive, x, y, dir, mass, respawn, seen}:
      match id == player:
        case 0:
          Cells.Cell.Cell{id, alive, x, y, dir, mass, respawn, seen}
        case k:
          Cells.Cell.Cell{id, alive, x, y, dir, mass, respawn, now}

def Cells.cell_input(cell: Cells.Cell, player: U32, heading: U32, now: U32) -> Cells.Cell:
  match cell:
    case Cells.Cell.Cell{id, alive, x, y, dir, mass, respawn, seen}:
      match id == player:
        case 0:
          Cells.Cell.Cell{id, alive, x, y, dir, mass, respawn, seen}
        case k:
          Cells.Cell.Cell{id, alive, x, y, heading % 16, mass, respawn, now}

def Cells.cell_leave(cell: Cells.Cell, player: U32) -> Cells.Cell:
  match cell:
    case Cells.Cell.Cell{id, alive, x, y, dir, mass, respawn, seen}:
      match id == player:
        case 0:
          Cells.Cell.Cell{id, alive, x, y, dir, mass, respawn, seen}
        case k:
          Cells.cell_empty()

def Cells.cell_expire(cell: Cells.Cell, now: U32) -> Cells.Cell:
  match cell:
    case Cells.Cell.Cell{id, alive, x, y, dir, mass, respawn, seen}:
      match (id > 0) && ((now - seen) > Cells.player_timeout()):
        case 0:
          Cells.Cell.Cell{id, alive, x, y, dir, mass, respawn, seen}
        case k:
          Cells.cell_empty()

def Cells.cell_step(cell: Cells.Cell, slot: U32) -> Cells.Cell:
  match cell:
    case Cells.Cell.Cell{id, alive, x, y, dir, mass, respawn, seen}:
      match id:
        case 0:
          Cells.cell_empty()
        case player:
          match alive:
            case 0:
              match respawn:
                case 0:
                  Cells.cell_spawn(slot, player, seen)
                case wait:
                  match wait == 1:
                    case 0:
                      Cells.Cell.Cell{player, 0, x, y, dir, 0, wait - 1, seen}
                    case k:
                      Cells.cell_spawn(slot, player, seen)
            case live:
              step = Cells.u32_step(dir)
              match step:
                case Cells.Step.Step{x_pos, x_by, y_pos, y_by}:
                  pace = 10 - Cells.u32_min(mass / 8, 4)
                  radius = 18 + Cells.u32_min(mass, 34)
                  next_x = Cells.u32_clamp(Cells.u32_move(x, x_pos, (x_by * pace) / 10), radius, Cells.world_size() - radius)
                  next_y = Cells.u32_clamp(Cells.u32_move(y, y_pos, (y_by * pace) / 10), radius, Cells.world_size() - radius)
                  Cells.Cell.Cell{player, live, next_x, next_y, dir, mass, 0, seen}

def Cells.cell_kill(cell: Cells.Cell) -> Cells.Cell:
  match cell:
    case Cells.Cell.Cell{id, alive, x, y, dir, mass, respawn, seen}:
      Cells.Cell.Cell{id, 0, x, y, dir, 0, Cells.respawn_ticks(), seen}

def Cells.cell_feed(cell: Cells.Cell, points: List(Cells.Point), seed: U32) -> Cells.Fed:
  match cell:
    case Cells.Cell.Cell{id, alive, x, y, dir, mass, respawn, seen}:
      match alive:
        case 0:
          Cells.Fed.Fed{Cells.Cell.Cell{id, 0, x, y, dir, mass, respawn, seen}, points, seed}
        case live:
          meal = Cells.list_meal(Cells.Point.Point{x, y}, 18 + Cells.u32_min(mass, 34), points)
          match meal:
            case Cells.Meal.Meal{ate, kept}:
              match ate:
                case 0:
                  Cells.Fed.Fed{Cells.Cell.Cell{id, live, x, y, dir, mass, respawn, seen}, kept, seed}
                case k:
                  sx = Cells.u32_random(seed)
                  sy = Cells.u32_random(sx)
                  Cells.Fed.Fed{Cells.Cell.Cell{id, live, x, y, dir, mass + 1, respawn, seen}, List.Cons{Cells.Point.Point{30 + (sx % 1140), 30 + (sy % 1140)}, kept}, sy}

def Cells.cell_duel(left: Cells.Cell, right: Cells.Cell) -> Cells.Duel:
  match left:
    case Cells.Cell.Cell{left_id, left_alive, left_x, left_y, left_dir, left_mass, left_respawn, left_seen}:
      match right:
        case Cells.Cell.Cell{right_id, right_alive, right_x, right_y, right_dir, right_mass, right_respawn, right_seen}:
          close = Cells.point_near(Cells.Point.Point{left_x, left_y}, Cells.Point.Point{right_x, right_y}, 14 + Cells.u32_max(Cells.u32_min(left_mass, 34), Cells.u32_min(right_mass, 34)))
          match (left_alive && right_alive) && close:
            case 0:
              Cells.Duel.Duel{Cells.Cell.Cell{left_id, left_alive, left_x, left_y, left_dir, left_mass, left_respawn, left_seen}, Cells.Cell.Cell{right_id, right_alive, right_x, right_y, right_dir, right_mass, right_respawn, right_seen}}
            case together:
              match left_mass > (right_mass + 2):
                case 0:
                  match right_mass > (left_mass + 2):
                    case 0:
                      Cells.Duel.Duel{Cells.Cell.Cell{left_id, left_alive, left_x, left_y, left_dir, left_mass, left_respawn, left_seen}, Cells.Cell.Cell{right_id, right_alive, right_x, right_y, right_dir, right_mass, right_respawn, right_seen}}
                    case right_wins:
                      Cells.Duel.Duel{Cells.cell_kill(Cells.Cell.Cell{left_id, left_alive, left_x, left_y, left_dir, left_mass, left_respawn, left_seen}), Cells.Cell.Cell{right_id, right_alive, right_x, right_y, right_dir, (right_mass + left_mass) + 3, right_respawn, right_seen}}
                case left_wins:
                  Cells.Duel.Duel{Cells.Cell.Cell{left_id, left_alive, left_x, left_y, left_dir, (left_mass + right_mass) + 3, left_respawn, left_seen}, Cells.cell_kill(Cells.Cell.Cell{right_id, right_alive, right_x, right_y, right_dir, right_mass, right_respawn, right_seen})}

def Cells.cell_json(cell: Cells.Cell, slot: U32) -> String:
  match cell:
    case Cells.Cell.Cell{id, alive, x, y, dir, mass, respawn, seen}:
      String.flatten([
        "{\"slot\":", String.from_u32(slot),
        ",\"joined\":", String.from_u32(id > 0),
        ",\"alive\":", String.from_u32(alive),
        ",\"x\":", String.from_u32(x),
        ",\"y\":", String.from_u32(y),
        ",\"dir\":", String.from_u32(dir),
        ",\"mass\":", String.from_u32(mass),
        ",\"respawn\":", String.from_u32(respawn),
        "}"
      ])

# ---------------------------------------------------------------- Game

def Cells.game_empty(now: U32, seed: U32) -> Cells.Game:
  supply = Cells.u32_supply(Cells.food_count(), seed)
  match supply:
    case Cells.Supply.Supply{points, out}:
      Cells.Game.Game{Cells.cell_empty(), Cells.cell_empty(), Cells.cell_empty(), Cells.cell_empty(), points, out, now, 0}

def Cells.game_at(game: Cells.Game) -> U32:
  match game:
    case Cells.Game.Game{one, two, three, four, food, seed, at, tick}:
      at

def Cells.game_retime(game: Cells.Game, now: U32) -> Cells.Game:
  match game:
    case Cells.Game.Game{one, two, three, four, food, seed, at, tick}:
      Cells.Game.Game{one, two, three, four, food, seed, now, tick}

def Cells.game_expire(game: Cells.Game, now: U32) -> Cells.Game:
  match game:
    case Cells.Game.Game{one, two, three, four, food, seed, at, tick}:
      Cells.Game.Game{Cells.cell_expire(one, now), Cells.cell_expire(two, now), Cells.cell_expire(three, now), Cells.cell_expire(four, now), food, seed, at, tick}

def Cells.game_step(game: Cells.Game) -> Cells.Game:
  match game:
    case Cells.Game.Game{one, two, three, four, food, seed, at, tick}:
      moved_one = Cells.cell_step(one, 1)
      moved_two = Cells.cell_step(two, 2)
      moved_three = Cells.cell_step(three, 3)
      moved_four = Cells.cell_step(four, 4)

      fed_one = Cells.cell_feed(moved_one, food, seed)
      match fed_one:
        case Cells.Fed.Fed{food_one_cell, food_one, seed_one}:
          fed_two = Cells.cell_feed(moved_two, food_one, seed_one)
          match fed_two:
            case Cells.Fed.Fed{food_two_cell, food_two, seed_two}:
              fed_three = Cells.cell_feed(moved_three, food_two, seed_two)
              match fed_three:
                case Cells.Fed.Fed{food_three_cell, food_three, seed_three}:
                  fed_four = Cells.cell_feed(moved_four, food_three, seed_three)
                  match fed_four:
                    case Cells.Fed.Fed{food_four_cell, food_four, seed_four}:
                      duel_12 = Cells.cell_duel(food_one_cell, food_two_cell)
                      match duel_12:
                        case Cells.Duel.Duel{d12_one, d12_two}:
                          duel_13 = Cells.cell_duel(d12_one, food_three_cell)
                          match duel_13:
                            case Cells.Duel.Duel{d13_one, d13_three}:
                              duel_14 = Cells.cell_duel(d13_one, food_four_cell)
                              match duel_14:
                                case Cells.Duel.Duel{d14_one, d14_four}:
                                  duel_23 = Cells.cell_duel(d12_two, d13_three)
                                  match duel_23:
                                    case Cells.Duel.Duel{d23_two, d23_three}:
                                      duel_24 = Cells.cell_duel(d23_two, d14_four)
                                      match duel_24:
                                        case Cells.Duel.Duel{d24_two, d24_four}:
                                          duel_34 = Cells.cell_duel(d23_three, d24_four)
                                          match duel_34:
                                            case Cells.Duel.Duel{d34_three, d34_four}:
                                              Cells.Game.Game{d14_one, d24_two, d34_three, d34_four, food_four, seed_four, at, tick + 1}

def Cells.game_steps(game: Cells.Game, count: U32) -> Cells.Game:
  match count:
    case 0:
      game
    case k:
      Cells.game_steps(Cells.game_step(game), k - 1)

def Cells.game_advance(game: Cells.Game, now: U32) -> Cells.Game:
  fresh = Cells.game_expire(game, now)
  at = Cells.game_at(fresh)
  elapsed = now - at
  raw = elapsed / Cells.tick_ms()
  count = Cells.u32_min(raw, 5)
  advanced = Cells.game_steps(fresh, count)
  match raw > 5:
    case 0:
      Cells.game_retime(advanced, at + (count * Cells.tick_ms()))
    case k:
      Cells.game_retime(advanced, now)

def Cells.game_player(game: Cells.Game, player: U32) -> U32:
  match game:
    case Cells.Game.Game{one, two, three, four, food, seed, at, tick}:
      match one:
        case Cells.Cell.Cell{id_one, alive_one, x_one, y_one, dir_one, mass_one, respawn_one, seen_one}:
          match (id_one > 0) && (id_one == player):
            case 0:
              match two:
                case Cells.Cell.Cell{id_two, alive_two, x_two, y_two, dir_two, mass_two, respawn_two, seen_two}:
                  match (id_two > 0) && (id_two == player):
                    case 0:
                      match three:
                        case Cells.Cell.Cell{id_three, alive_three, x_three, y_three, dir_three, mass_three, respawn_three, seen_three}:
                          match (id_three > 0) && (id_three == player):
                            case 0:
                              match four:
                                case Cells.Cell.Cell{id_four, alive_four, x_four, y_four, dir_four, mass_four, respawn_four, seen_four}:
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

def Cells.game_touch(game: Cells.Game, player: U32, now: U32) -> Cells.Game:
  match game:
    case Cells.Game.Game{one, two, three, four, food, seed, at, tick}:
      Cells.Game.Game{Cells.cell_touch(one, player, now), Cells.cell_touch(two, player, now), Cells.cell_touch(three, player, now), Cells.cell_touch(four, player, now), food, seed, at, tick}

def Cells.game_error(game: Cells.Game, note: String) -> Cells.Action:
  Cells.Action.Action{game, 0, note}

def Cells.game_ok(game: Cells.Game) -> Cells.Action:
  Cells.Action.Action{game, 1, ""}

def Cells.game_join_open(game: Cells.Game, player: U32, now: U32) -> Cells.Action:
  match game:
    case Cells.Game.Game{one, two, three, four, food, seed, at, tick}:
      match Cells.cell_joined(one):
        case 0:
          Cells.game_ok(Cells.Game.Game{Cells.cell_spawn(1, player, now), two, three, four, food, seed, at, tick})
        case used_one:
          match Cells.cell_joined(two):
            case 0:
              Cells.game_ok(Cells.Game.Game{one, Cells.cell_spawn(2, player, now), three, four, food, seed, at, tick})
            case used_two:
              match Cells.cell_joined(three):
                case 0:
                  Cells.game_ok(Cells.Game.Game{one, two, Cells.cell_spawn(3, player, now), four, food, seed, at, tick})
                case used_three:
                  match Cells.cell_joined(four):
                    case 0:
                      Cells.game_ok(Cells.Game.Game{one, two, three, Cells.cell_spawn(4, player, now), food, seed, at, tick})
                    case used_four:
                      Cells.game_error(Cells.Game.Game{one, two, three, four, food, seed, at, tick}, "The arena already has four players.")

def Cells.game_join(game: Cells.Game, player: U32, now: U32) -> Cells.Action:
  match player:
    case 0:
      Cells.game_error(game, "Invalid player identity.")
    case id:
      slot = Cells.game_player(game, id)
      match slot:
        case 0:
          Cells.game_join_open(game, id, now)
        case own:
          Cells.game_ok(Cells.game_touch(game, id, now))

def Cells.game_input(game: Cells.Game, player: U32, heading: U32, now: U32) -> Cells.Action:
  slot = Cells.game_player(game, player)
  match slot:
    case 0:
      Cells.game_error(game, "Join the game before moving.")
    case own:
      match game:
        case Cells.Game.Game{one, two, three, four, food, seed, at, tick}:
          Cells.game_ok(Cells.Game.Game{Cells.cell_input(one, player, heading, now), Cells.cell_input(two, player, heading, now), Cells.cell_input(three, player, heading, now), Cells.cell_input(four, player, heading, now), food, seed, at, tick})

def Cells.game_state(game: Cells.Game, player: U32, now: U32) -> Cells.Action:
  Cells.game_ok(Cells.game_touch(game, player, now))

def Cells.game_leave(game: Cells.Game, player: U32) -> Cells.Action:
  slot = Cells.game_player(game, player)
  match slot:
    case 0:
      Cells.game_error(game, "This browser has not joined the game.")
    case own:
      match game:
        case Cells.Game.Game{one, two, three, four, food, seed, at, tick}:
          Cells.game_ok(Cells.Game.Game{Cells.cell_leave(one, player), Cells.cell_leave(two, player), Cells.cell_leave(three, player), Cells.cell_leave(four, player), food, seed, at, tick})

def Cells.game_json(game: Cells.Game, player: U32, ok: U32, note: String) -> String:
  match game:
    case Cells.Game.Game{one, two, three, four, food, seed, at, tick}:
      String.flatten([
        "{\"ok\":", String.from_u32(ok),
        ",\"note\":\"", note,
        "\",\"you\":", String.from_u32(Cells.game_player(Cells.Game.Game{one, two, three, four, food, seed, at, tick}, player)),
        ",\"full\":", String.from_u32(Cells.cell_joined(one) && (Cells.cell_joined(two) && (Cells.cell_joined(three) && Cells.cell_joined(four)))),
        ",\"tick\":", String.from_u32(tick),
        ",\"players\":[", Cells.cell_json(one, 1), ",", Cells.cell_json(two, 2), ",", Cells.cell_json(three, 3), ",", Cells.cell_json(four, 4), "]",
        ",\"food\":", Cells.list_point_json(food),
        "}"
      ])

def Cells.game_response(game: Cells.Game, player: U32, ok: U32, note: String) -> HTTP.Response:
  HTTP.Response.Response{200, [HTTP.Header.Header{"Content-Type", "application/json; charset=utf-8"}, HTTP.Header.Header{"Cache-Control", "no-store, no-cache, must-revalidate"}], Bytes.from_string(Cells.game_json(game, player, ok, note))}

def Cells.game_missing(game: Cells.Game) -> Cells.Routed:
  Cells.Routed.Routed{game, HTTP.not_found()}

def Cells.game_method(game: Cells.Game) -> Cells.Routed:
  Cells.Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")}

# ---------------------------------------------------------------- Action

def Cells.action_routed(action: Cells.Action, player: U32) -> Cells.Routed:
  match action:
    case Cells.Action.Action{game, ok, note}:
      Cells.Routed.Routed{game, Cells.game_response(game, player, ok, note)}

# ---------------------------------------------------------------- Result

def Cells.result_index(result: Result((U32 & String), String), game: Cells.Game) -> IO(Cells.Routed):
  match result:
    case Result.Done{html}:
      IO.pure(Cells.Routed, Cells.Routed.Routed{game, HTTP.reply(200, "text/html; charset=utf-8", html)})
    case Result.Fail{(code, error)}:
      IO.pure(Cells.Routed, Cells.Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run the server from the repository root\n")})

# ---------------------------------------------------------------- Routing

def Cells.game_index(game: Cells.Game) -> IO(Cells.Routed):
  do IO(Cells.Routed):
    result <- IO.read_text("gabriel_demos/agar_web/index.html")
    Cells.result_index(result, game)

def Cells.list_state(args: List(String), game: Cells.Game, now: U32) -> IO(Cells.Routed):
  match args:
    case List.Cons{player, rest}:
      id = String.to_u32(player)
      IO.pure(Cells.Routed, Cells.action_routed(Cells.game_state(game, id, now), id))
    case List.Nil{}:
      IO.pure(Cells.Routed, Cells.game_missing(game))

def Cells.list_join(args: List(String), game: Cells.Game, now: U32) -> IO(Cells.Routed):
  match args:
    case List.Cons{player, rest}:
      id = String.to_u32(player)
      IO.pure(Cells.Routed, Cells.action_routed(Cells.game_join(game, id, now), id))
    case List.Nil{}:
      IO.pure(Cells.Routed, Cells.game_missing(game))

def Cells.list_input(args: List(String), game: Cells.Game, now: U32) -> IO(Cells.Routed):
  match args:
    case List.Cons{player, List.Cons{heading, rest}}:
      id = String.to_u32(player)
      IO.pure(Cells.Routed, Cells.action_routed(Cells.game_input(game, id, String.to_u32(heading), now), id))
    case other:
      IO.pure(Cells.Routed, Cells.game_missing(game))

def Cells.list_leave(args: List(String), game: Cells.Game) -> IO(Cells.Routed):
  match args:
    case List.Cons{player, rest}:
      id = String.to_u32(player)
      IO.pure(Cells.Routed, Cells.action_routed(Cells.game_leave(game, id), id))
    case List.Nil{}:
      IO.pure(Cells.Routed, Cells.game_missing(game))

def Cells.string_route(name: String, args: List(String), game: Cells.Game, now: U32) -> IO(Cells.Routed):
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
                      IO.pure(Cells.Routed, Cells.game_missing(game))
                    case leave:
                      Cells.list_leave(args, game)
                case input:
                  Cells.list_input(args, game, now)
            case join:
              Cells.list_join(args, game, now)
        case state:
          Cells.list_state(args, game, now)
    case index:
      Cells.game_index(game)

def Cells.list_route(parts: List(String), game: Cells.Game, now: U32) -> IO(Cells.Routed):
  match parts:
    case List.Cons{root, List.Cons{name, args}}:
      Cells.string_route(name, args, game, now)
    case List.Cons{root, List.Nil{}}:
      Cells.game_index(game)
    case List.Nil{}:
      Cells.game_index(game)

def Cells.request_route(request: HTTP.Request, game: Cells.Game, now: U32) -> IO(Cells.Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(method, "GET"):
        case 0:
          IO.pure(Cells.Routed, Cells.game_method(game))
        case get:
          Cells.list_route(String.split('/', path), game, now)

# ---------------------------------------------------------------- Server

def Cells.routed_send(routed: Cells.Routed, server: TCP, conn: HTTP) -> IO(U32):
  match routed:
    case Cells.Routed.Routed{game, response}:
      do IO(U32):
        sent <- HTTP.send_response(conn, HTTP.with_connection(0, response))
        closed <- HTTP.close(conn)
        Cells.u32_serve(server, game)

def Cells.inbound_serve(inbound: HTTP.Inbound, server: TCP, conn: HTTP, game: Cells.Game) -> IO(U32):
  match inbound:
    case HTTP.Inbound.Got{http11, request, rest}:
      do IO(U32):
        now <- clock_now_ms()
        routed <- Cells.request_route(request, Cells.game_advance(game, now), now)
        Cells.routed_send(routed, server, conn)
    case HTTP.Inbound.Closed{}:
      do IO(U32):
        closed <- HTTP.close(conn)
        Cells.u32_serve(server, game)
    case HTTP.Inbound.Bad{code, error}:
      Cells.routed_send(Cells.Routed.Routed{game, HTTP.reply_error(code, error)}, server, conn)

def Cells.result_accept(result: Result((U32 & String), TCP), server: TCP, game: Cells.Game) -> IO(U32):
  match result:
    case Result.Done{fd}:
      do IO(U32):
        inbound <- HTTP.recv_request(HTTP.Plain{fd}, List.Nil{})
        Cells.inbound_serve(inbound, server, HTTP.Plain{fd}, game)
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["accept failed: ", error, "\n"]))
        return 1

def Cells.u32_serve(server: TCP, game: Cells.Game) -> IO(U32):
  do IO(U32):
    result <- TCP.accept(server)
    Cells.result_accept(result, server, game)

def Cells.result_main(result: Result((U32 & String), TCP), now: U32, seed: U32) -> IO(U32):
  match result:
    case Result.Done{server}:
      do IO(U32):
        printed <- IO.write("cell arena listening on all interfaces (0.0.0.0:8084)\nopen http://<server-lan-ip>:8084 on up to four devices\n")
        Cells.u32_serve(server, Cells.game_empty(now, seed))
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def Cells.main() -> IO(U32):
  do IO(U32):
    now <- clock_now_ms()
    seed <- IO.rand_word()
    result <- TCP.listen(8084)
    Cells.result_main(result, now, seed)
