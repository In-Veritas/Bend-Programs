# CubeWorld 2: first-person multiplayer voxel survival in Bend3.
#
# Bend owns the 48x48 terrain, four player slots, four hostile mobs, block
# edits, pursuit, combat, health, and respawning. The browser only renders and
# submits actions.
#
# no-halt
# skip-native

import ../../bend-base/Base
import ../Compat
import ../../bend-base/IO/TCP
import ../../bend-base/IO/HTTP
import ../Clock as Clock

def world_size() -> U32: 48
def render_distance() -> U32: 7
def player_timeout() -> U32: 30000
def mob_interval() -> U32: 650
def max_height() -> U32: 12

type Column:
  Column{height: U32, block: U32, ground: U32}

type Player:
  Player{slot: U32, id: U32, joined: U32, x: U32, z: U32, face: U32, hp: U32, seen: U32}

type Mob:
  Mob{slot: U32, alive: U32, x: U32, z: U32, hp: U32}

type Target:
  Target{found: U32, x: U32, z: U32, distance: U32}

type Game:
  Game{world: List(Column), one: Player, two: Player, three: Player, four: Player, mob_one: Mob, mob_two: Mob, mob_three: Mob, mob_four: Mob, tick: U32}

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

def u32_distance(x: U32, z: U32, other_x: U32, other_z: U32) -> U32:
  u32_abs_diff(x, other_x) + u32_abs_diff(z, other_z)

def u32_near(x: U32, z: U32, other_x: U32, other_z: U32) -> U32:
  u32_distance(x, z, other_x, other_z) <= 3

def u32_ground(x: U32, z: U32) -> U32:
  2 + (((((x * 13) + (z * 7)) + (x * z)) + ((x / 5) * 3)) % 4)

def u32_tree(x: U32, z: U32) -> U32:
  ((x == 8) && (z == 9)) || (((x == 19) && (z == 14)) || (((x == 35) && (z == 10)) || (((x == 12) && (z == 34)) || (((x == 31) && (z == 31)) || ((x == 40) && (z == 40))))))

def u32_canopy_one(x: U32, z: U32, cx: U32, cz: U32) -> U32:
  (u32_abs_diff(x, cx) <= 1) && (u32_abs_diff(z, cz) <= 1)

def u32_canopy(x: U32, z: U32) -> U32:
  u32_canopy_one(x, z, 8, 9) || (u32_canopy_one(x, z, 19, 14) || (u32_canopy_one(x, z, 35, 10) || (u32_canopy_one(x, z, 12, 34) || (u32_canopy_one(x, z, 31, 31) || u32_canopy_one(x, z, 40, 40)))))

def u32_surface(x: U32, z: U32, ground: U32) -> U32:
  match (x < 6) || (z < 5):
    case 0:
      match (((x * 5) + (z * 11)) % 29) == 0:
        case 0:
          match ground >= 5:
            case 0:
              1
            case k:
              10
        case k:
          9
    case k:
      match ground <= 3:
        case 0:
          6
        case j:
          7

def u32_under(height: U32, ground: U32) -> U32:
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
    case 47:
      47
    case k:
      k + 1

def u32_damage(hp: U32, amount: U32) -> U32:
  match hp <= amount:
    case 0:
      hp - amount
    case k:
      0

# ---------------------------------------------------------------- Column

def column_make(x: U32, z: U32) -> Column:
  ground = u32_ground(x, z)
  match u32_tree(x, z):
    case 0:
      match u32_canopy(x, z):
        case 0:
          Column.Column{ground, u32_surface(x, z, ground), ground}
        case k:
          Column.Column{ground + 3, 5, ground}
    case k:
      Column.Column{ground + 4, 4, ground}

def column_mine(column: Column) -> Column:
  match column:
    case Column.Column{height, block, ground}:
      match height:
        case 0:
          Column.Column{0, 0, ground}
        case h:
          next = h - 1
          match next:
            case 0:
              Column.Column{0, 0, ground}
            case n:
              Column.Column{n, u32_under(n, ground), ground}

def column_place(column: Column, block: U32) -> Column:
  match column:
    case Column.Column{height, old, ground}:
      match (block > 0) && ((block <= 12) && (height < max_height())):
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
  Player.Player{slot, 0, 0, 0, 0, 0, 0, 0}

def player_spawn(slot: U32, id: U32, now: U32) -> Player:
  match slot:
    case 1:
      Player.Player{1, id, 1, 23, 23, 0, 100, now}
    case 2:
      Player.Player{2, id, 1, 26, 23, 2, 100, now}
    case 3:
      Player.Player{3, id, 1, 23, 26, 0, 100, now}
    case other:
      Player.Player{4, id, 1, 26, 26, 2, 100, now}

def player_active(player: Player, now: U32) -> U32:
  match player:
    case Player.Player{slot, id, joined, x, z, face, hp, seen}:
      joined && ((now - seen) < player_timeout())

def player_owner(player: Player, id: U32, now: U32) -> U32:
  match player:
    case Player.Player{slot, stored, joined, x, z, face, hp, seen}:
      (id > 0) && ((stored == id) && player_active(Player.Player{slot, stored, joined, x, z, face, hp, seen}, now))

def player_touch(player: Player, now: U32) -> Player:
  match player:
    case Player.Player{slot, id, joined, x, z, face, hp, seen}:
      Player.Player{slot, id, joined, x, z, face, hp, now}

def player_move(player: Player, direction: U32, now: U32) -> Player:
  match player:
    case Player.Player{slot, id, joined, x, z, face, hp, seen}:
      match direction % 4:
        case 0:
          Player.Player{slot, id, joined, x, u32_prev(z), 0, hp, now}
        case 1:
          Player.Player{slot, id, joined, u32_next(x), z, 1, hp, now}
        case 2:
          Player.Player{slot, id, joined, x, u32_next(z), 2, hp, now}
        case other:
          Player.Player{slot, id, joined, u32_prev(x), z, 3, hp, now}

def player_respawn(player: Player) -> Player:
  match player:
    case Player.Player{slot, id, joined, x, z, face, hp, seen}:
      match slot:
        case 1:
          Player.Player{1, id, joined, 23, 23, 0, 100, seen}
        case 2:
          Player.Player{2, id, joined, 26, 23, 2, 100, seen}
        case 3:
          Player.Player{3, id, joined, 23, 26, 0, 100, seen}
        case other:
          Player.Player{4, id, joined, 26, 26, 2, 100, seen}

def player_hit(player: Player, amount: U32) -> Player:
  match player:
    case Player.Player{slot, id, joined, x, z, face, hp, seen}:
      next = u32_damage(hp, amount)
      match next:
        case 0:
          player_respawn(Player.Player{slot, id, joined, x, z, face, next, seen})
        case life:
          Player.Player{slot, id, joined, x, z, face, life, seen}

def player_json(player: Player, now: U32) -> String:
  match player:
    case Player.Player{slot, id, joined, x, z, face, hp, seen}:
      String.flatten([
        "{\"slot\":", String.from_u32(slot),
        ",\"joined\":", String.from_u32(player_active(Player.Player{slot, id, joined, x, z, face, hp, seen}, now)),
        ",\"x\":", String.from_u32(x), ",\"z\":", String.from_u32(z),
        ",\"face\":", String.from_u32(face), ",\"hp\":", String.from_u32(hp), "}"
      ])

# ---------------------------------------------------------------- Target

def target_empty() -> Target:
  Target.Target{0, 0, 0, 999}

def target_offer(target: Target, player: Player, now: U32, x: U32, z: U32) -> Target:
  match target:
    case Target.Target{found, tx, tz, distance}:
      match player:
        case Player.Player{slot, id, joined, px, pz, face, hp, seen}:
          next = u32_distance(x, z, px, pz)
          match player_active(Player.Player{slot, id, joined, px, pz, face, hp, seen}, now) && (next < distance):
            case 0:
              Target.Target{found, tx, tz, distance}
            case k:
              Target.Target{1, px, pz, next}

# ---------------------------------------------------------------- Mob

def mob_spawn(slot: U32) -> Mob:
  match slot:
    case 1:
      Mob.Mob{1, 1, 17, 20, 60}
    case 2:
      Mob.Mob{2, 1, 32, 19, 60}
    case 3:
      Mob.Mob{3, 1, 18, 34, 60}
    case other:
      Mob.Mob{4, 1, 35, 33, 60}

def mob_target(mob: Mob, one: Player, two: Player, three: Player, four: Player, now: U32) -> Target:
  match mob:
    case Mob.Mob{slot, alive, x, z, hp}:
      first = target_offer(target_empty(), one, now, x, z)
      second = target_offer(first, two, now, x, z)
      third = target_offer(second, three, now, x, z)
      target_offer(third, four, now, x, z)

def mob_step(mob: Mob, target: Target, tick: U32) -> Mob:
  match mob:
    case Mob.Mob{slot, alive, x, z, hp}:
      match alive:
        case 0:
          Mob.Mob{slot, 0, x, z, hp}
        case living:
          match target:
            case Target.Target{found, tx, tz, distance}:
              match found && (distance > 1):
                case 0:
                  Mob.Mob{slot, 1, x, z, hp}
                case k:
                  match x == tx:
                    case 0:
                      match x < tx:
                        case 0:
                          Mob.Mob{slot, 1, u32_prev(x), z, hp}
                        case j:
                          Mob.Mob{slot, 1, u32_next(x), z, hp}
                    case same:
                      match z < tz:
                        case 0:
                          Mob.Mob{slot, 1, x, u32_prev(z), hp}
                        case j:
                          Mob.Mob{slot, 1, x, u32_next(z), hp}

def mob_hit(mob: Mob, amount: U32) -> Mob:
  match mob:
    case Mob.Mob{slot, alive, x, z, hp}:
      next = u32_damage(hp, amount)
      match next:
        case 0:
          Mob.Mob{slot, 0, x, z, 0}
        case life:
          Mob.Mob{slot, alive, x, z, life}

def mob_near(mob: Mob, x: U32, z: U32) -> U32:
  match mob:
    case Mob.Mob{slot, alive, mx, mz, hp}:
      alive && (u32_distance(x, z, mx, mz) <= 1)

def mob_json(mob: Mob) -> String:
  match mob:
    case Mob.Mob{slot, alive, x, z, hp}:
      String.flatten(["{\"slot\":", String.from_u32(slot), ",\"alive\":", String.from_u32(alive), ",\"x\":", String.from_u32(x), ",\"z\":", String.from_u32(z), ",\"hp\":", String.from_u32(hp), "}"])

# ---------------------------------------------------------------- Game

def game_empty() -> Game:
  Game.Game{list_world(world_size() * world_size(), 0), player_empty(1), player_empty(2), player_empty(3), player_empty(4), mob_spawn(1), mob_spawn(2), mob_spawn(3), mob_spawn(4), 1}

def game_slot(game: Game, id: U32, now: U32) -> U32:
  match game:
    case Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
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
    case Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
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
    case Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      match slot:
        case 1:
          Game.Game{world, player, two, three, four, m1, m2, m3, m4, tick}
        case 2:
          Game.Game{world, one, player, three, four, m1, m2, m3, m4, tick}
        case 3:
          Game.Game{world, one, two, player, four, m1, m2, m3, m4, tick}
        case other:
          Game.Game{world, one, two, three, player, m1, m2, m3, m4, tick}

def game_mob(game: Game, slot: U32) -> Mob:
  match game:
    case Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      match slot:
        case 1:
          m1
        case 2:
          m2
        case 3:
          m3
        case other:
          m4

def game_mob_set(game: Game, slot: U32, mob: Mob) -> Game:
  match game:
    case Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      match slot:
        case 1:
          Game.Game{world, one, two, three, four, mob, m2, m3, m4, tick}
        case 2:
          Game.Game{world, one, two, three, four, m1, mob, m3, m4, tick}
        case 3:
          Game.Game{world, one, two, three, four, m1, m2, mob, m4, tick}
        case other:
          Game.Game{world, one, two, three, four, m1, m2, m3, mob, tick}

def game_ok(game: Game) -> Action:
  Action.Action{game, 1, ""}

def game_error(game: Game, note: String) -> Action:
  Action.Action{game, 0, note}

def game_damage_player(player: Player, m1: Mob, m2: Mob, m3: Mob, m4: Mob, now: U32) -> Player:
  match player:
    case Player.Player{slot, id, joined, x, z, face, hp, seen}:
      hits = mob_near(m1, x, z) + (mob_near(m2, x, z) + (mob_near(m3, x, z) + mob_near(m4, x, z)))
      match player_active(Player.Player{slot, id, joined, x, z, face, hp, seen}, now) && (hits > 0):
        case 0:
          Player.Player{slot, id, joined, x, z, face, hp, seen}
        case k:
          player_hit(Player.Player{slot, id, joined, x, z, face, hp, seen}, hits * 3)

def game_advance(game: Game, now: U32) -> Game:
  match game:
    case Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      match (now - tick) < mob_interval():
        case 0:
          n1 = mob_step(m1, mob_target(m1, one, two, three, four, now), tick)
          n2 = mob_step(m2, mob_target(m2, one, two, three, four, now), tick)
          n3 = mob_step(m3, mob_target(m3, one, two, three, four, now), tick)
          n4 = mob_step(m4, mob_target(m4, one, two, three, four, now), tick)
          p1 = game_damage_player(one, n1, n2, n3, n4, now)
          p2 = game_damage_player(two, n1, n2, n3, n4, now)
          p3 = game_damage_player(three, n1, n2, n3, n4, now)
          p4 = game_damage_player(four, n1, n2, n3, n4, now)
          Game.Game{world, p1, p2, p3, p4, n1, n2, n3, n4, now}
        case k:
          Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}

def game_state(game: Game, id: U32, now: U32) -> Game:
  advanced = game_advance(game, now)
  slot = game_slot(advanced, id, now)
  match slot:
    case 0:
      advanced
    case own:
      game_player_set(advanced, own, player_touch(game_player(advanced, own), now))

def game_join_new(game: Game, id: U32, now: U32) -> Action:
  match game:
    case Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      match player_active(one, now):
        case 0:
          game_ok(Game.Game{world, player_spawn(1, id, now), two, three, four, m1, m2, m3, m4, tick})
        case k:
          match player_active(two, now):
            case 0:
              game_ok(Game.Game{world, one, player_spawn(2, id, now), three, four, m1, m2, m3, m4, tick})
            case j:
              match player_active(three, now):
                case 0:
                  game_ok(Game.Game{world, one, two, player_spawn(3, id, now), four, m1, m2, m3, m4, tick})
                case q:
                  match player_active(four, now):
                    case 0:
                      game_ok(Game.Game{world, one, two, three, player_spawn(4, id, now), m1, m2, m3, m4, tick})
                    case p:
                      game_error(Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}, "The world already has four active players.")

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
        case Player.Player{number, stored, joined, px, pz, face, hp, seen}:
          match (x < world_size()) && ((z < world_size()) && u32_near(px, pz, x, z)):
            case 0:
              game_error(game, "That block is outside your reach.")
            case k:
              match game:
                case Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
                  index = (z * world_size()) + x
                  touched = player_touch(Player.Player{number, stored, joined, px, pz, face, hp, seen}, now)
                  game_ok(game_player_set(Game.Game{list_column_set(world, index, column_mine(list_column_get(world, index))), one, two, three, four, m1, m2, m3, m4, tick}, own, touched))

def game_place(game: Game, id: U32, x: U32, z: U32, block: U32, now: U32) -> Action:
  slot = game_slot(game, id, now)
  match slot:
    case 0:
      game_error(game, "Join the world before building.")
    case own:
      player = game_player(game, own)
      match player:
        case Player.Player{number, stored, joined, px, pz, face, hp, seen}:
          match (x < world_size()) && ((z < world_size()) && (u32_near(px, pz, x, z) && ((block > 0) && (block <= 12)))):
            case 0:
              game_error(game, "Choose one of the twelve materials within reach.")
            case k:
              match game:
                case Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
                  index = (z * world_size()) + x
                  touched = player_touch(Player.Player{number, stored, joined, px, pz, face, hp, seen}, now)
                  game_ok(game_player_set(Game.Game{list_column_set(world, index, column_place(list_column_get(world, index), block)), one, two, three, four, m1, m2, m3, m4, tick}, own, touched))

def game_attack_mob(game: Game, id: U32, mob_slot: U32, now: U32) -> Action:
  slot = game_slot(game, id, now)
  match slot:
    case 0:
      game_error(game, "Join the world before attacking.")
    case own:
      player = game_player(game, own)
      mob = game_mob(game, mob_slot)
      match player:
        case Player.Player{number, stored, joined, px, pz, face, hp, seen}:
          match mob:
            case Mob.Mob{target, alive, mx, mz, life}:
              match (mob_slot > 0) && ((mob_slot <= 4) && (alive && (u32_distance(px, pz, mx, mz) <= 2))):
                case 0:
                  game_error(game, "That raider is outside sword reach.")
                case k:
                  game_ok(game_mob_set(game_player_set(game, own, player_touch(player, now)), target, mob_hit(mob, 25)))

def game_attack_player(game: Game, id: U32, target_slot: U32, now: U32) -> Action:
  slot = game_slot(game, id, now)
  match slot:
    case 0:
      game_error(game, "Join the world before attacking.")
    case own:
      attacker = game_player(game, own)
      target = game_player(game, target_slot)
      match attacker:
        case Player.Player{number, stored, joined, ax, az, face, hp, seen}:
          match target:
            case Player.Player{victim, target_id, target_joined, tx, tz, target_face, target_hp, target_seen}:
              match (target_slot > 0) && ((target_slot <= 4) && ((target_slot != own) && (player_active(target, now) && (u32_distance(ax, az, tx, tz) <= 2)))):
                case 0:
                  game_error(game, "That player is outside sword reach.")
                case k:
                  touched = player_touch(attacker, now)
                  damaged = player_hit(target, 20)
                  game_ok(game_player_set(game_player_set(game, target_slot, damaged), own, touched))

def game_leave(game: Game, id: U32, now: U32) -> Action:
  slot = game_slot(game, id, now)
  match slot:
    case 0:
      game_error(game, "This browser has not joined the world.")
    case own:
      game_ok(game_player_set(game, own, player_empty(own)))

def game_full(game: Game, now: U32) -> U32:
  match game:
    case Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      player_active(one, now) && (player_active(two, now) && (player_active(three, now) && player_active(four, now)))

# ---------------------------------------------------------------- JSON and routing

def game_json(game: Game, id: U32, now: U32, ok: U32, note: String) -> String:
  match game:
    case Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      String.flatten([
        "{\"ok\":", String.from_u32(ok), ",\"note\":\"", note,
        "\",\"you\":", String.from_u32(game_slot(Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}, id, now)),
        ",\"full\":", String.from_u32(game_full(Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}, now)),
        ",\"tick\":", String.from_u32(tick), ",\"size\":", String.from_u32(world_size()),
        ",\"renderDistance\":", String.from_u32(render_distance()),
        ",\"players\":[", player_json(one, now), ",", player_json(two, now), ",", player_json(three, now), ",", player_json(four, now), "],",
        "\"mobs\":[", mob_json(m1), ",", mob_json(m2), ",", mob_json(m3), ",", mob_json(m4), "],",
        "\"world\":[", list_world_json(world), "}"
      ])

def game_response(game: Game, id: U32, now: U32, ok: U32, note: String) -> HTTP.Response:
  HTTP.Response.Response{200, [HTTP.Header.Header{"Content-Type", "application/json; charset=utf-8"}, HTTP.Header.Header{"Cache-Control", "no-store, no-cache, must-revalidate"}], Bytes.from_string(game_json(game, id, now, ok, note))}

def game_routed(game: Game, id: U32, now: U32) -> Routed:
  Routed.Routed{game, game_response(game, id, now, 1, "")}

def game_missing(game: Game) -> Routed:
  Routed.Routed{game, HTTP.not_found()}

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
    result <- IO.read_text("gabriel_demos/cubeworld2_web/index.html")
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

def list_attack_mob(args: List(String), game: Game, now: U32) -> IO(Routed):
  match args:
    case List.Cons{id, List.Cons{slot, rest}}:
      player = String.to_u32(id)
      IO.pure(Routed, action_routed(game_attack_mob(game, player, String.to_u32(slot), now), player, now))
    case other:
      IO.pure(Routed, game_missing(game))

def list_attack_player(args: List(String), game: Game, now: U32) -> IO(Routed):
  match args:
    case List.Cons{id, List.Cons{slot, rest}}:
      player = String.to_u32(id)
      IO.pure(Routed, action_routed(game_attack_player(game, player, String.to_u32(slot), now), player, now))
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
                          match String.eq_u32(name, "attack-mob"):
                            case 0:
                              match String.eq_u32(name, "attack-player"):
                                case 0:
                                  match String.eq_u32(name, "leave"):
                                    case 0:
                                      IO.pure(Routed, game_missing(game))
                                    case yes:
                                      list_leave(args, game, now)
                                case yes:
                                  list_attack_player(args, game, now)
                            case yes:
                              list_attack_mob(args, game, now)
                        case yes:
                          list_place(args, game, now)
                    case yes:
                      list_mine(args, game, now)
                case yes:
                  list_move(args, game, now)
            case yes:
              list_join(args, game, now)
        case yes:
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
          IO.pure(Routed, Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")})
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
        printed <- IO.write("CubeWorld 2 listening on all interfaces (0.0.0.0:8086)\nopen http://<server-lan-ip>:8086\n")
        u32_serve(server, game_empty())
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def main() -> IO(U32):
  do IO(U32):
    result <- TCP.listen(8086)
    result_main(result)
