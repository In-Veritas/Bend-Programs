# Generated hub-private namespace from ../cubeworld2_web/web_cubeworld2.bend.
# Regenerate after changing the standalone source.

# CubeWorld 2: first-person multiplayer voxel survival in Bend3.
#
# Bend owns the 48x48 terrain, four player slots, four hostile mobs, block
# edits, pursuit, combat, health, and respawning. The browser only renders and
# submits actions.
#
# no-halt
# skip-native

import ../../../bend-base/Base
import ../../Compat
import ../../../bend-base/IO/TCP
import ../../../bend-base/IO/HTTP
import ../../Clock

def Cube.world_size() -> U32: 48
def Cube.render_distance() -> U32: 7
def Cube.player_timeout() -> U32: 30000
def Cube.mob_interval() -> U32: 650
def Cube.max_height() -> U32: 12

type Cube.Column:
  Column{height: U32, block: U32, ground: U32}

type Cube.Player:
  Player{slot: U32, id: U32, joined: U32, x: U32, z: U32, face: U32, hp: U32, seen: U32}

type Cube.Mob:
  Mob{slot: U32, alive: U32, x: U32, z: U32, hp: U32}

type Cube.Target:
  Target{found: U32, x: U32, z: U32, distance: U32}

type Cube.Game:
  Game{world: List(Cube.Column), one: Cube.Player, two: Cube.Player, three: Cube.Player, four: Cube.Player, mob_one: Cube.Mob, mob_two: Cube.Mob, mob_three: Cube.Mob, mob_four: Cube.Mob, tick: U32}

type Cube.Action:
  Action{game: Cube.Game, ok: U32, note: String}

type Cube.Routed:
  Routed{game: Cube.Game, response: HTTP.Response}

# ---------------------------------------------------------------- U32

def Cube.u32_abs_diff(a: U32, b: U32) -> U32:
  match a < b:
    case 0:
      a - b
    case k:
      b - a

def Cube.u32_distance(x: U32, z: U32, other_x: U32, other_z: U32) -> U32:
  Cube.u32_abs_diff(x, other_x) + Cube.u32_abs_diff(z, other_z)

def Cube.u32_near(x: U32, z: U32, other_x: U32, other_z: U32) -> U32:
  Cube.u32_distance(x, z, other_x, other_z) <= 3

def Cube.u32_ground(x: U32, z: U32) -> U32:
  2 + (((((x * 13) + (z * 7)) + (x * z)) + ((x / 5) * 3)) % 4)

def Cube.u32_tree(x: U32, z: U32) -> U32:
  ((x == 8) && (z == 9)) || (((x == 19) && (z == 14)) || (((x == 35) && (z == 10)) || (((x == 12) && (z == 34)) || (((x == 31) && (z == 31)) || ((x == 40) && (z == 40))))))

def Cube.u32_canopy_one(x: U32, z: U32, cx: U32, cz: U32) -> U32:
  (Cube.u32_abs_diff(x, cx) <= 1) && (Cube.u32_abs_diff(z, cz) <= 1)

def Cube.u32_canopy(x: U32, z: U32) -> U32:
  Cube.u32_canopy_one(x, z, 8, 9) || (Cube.u32_canopy_one(x, z, 19, 14) || (Cube.u32_canopy_one(x, z, 35, 10) || (Cube.u32_canopy_one(x, z, 12, 34) || (Cube.u32_canopy_one(x, z, 31, 31) || Cube.u32_canopy_one(x, z, 40, 40)))))

def Cube.u32_surface(x: U32, z: U32, ground: U32) -> U32:
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

def Cube.u32_under(height: U32, ground: U32) -> U32:
  match height == ground:
    case 0:
      match (height + 1) >= ground:
        case 0:
          3
        case k:
          2
    case k:
      1

def Cube.u32_prev(value: U32) -> U32:
  match value:
    case 0:
      0
    case k:
      k - 1

def Cube.u32_next(value: U32) -> U32:
  match value:
    case 47:
      47
    case k:
      k + 1

def Cube.u32_damage(hp: U32, amount: U32) -> U32:
  match hp <= amount:
    case 0:
      hp - amount
    case k:
      0

# ---------------------------------------------------------------- Column

def Cube.column_make(x: U32, z: U32) -> Cube.Column:
  ground = Cube.u32_ground(x, z)
  match Cube.u32_tree(x, z):
    case 0:
      match Cube.u32_canopy(x, z):
        case 0:
          Cube.Column.Column{ground, Cube.u32_surface(x, z, ground), ground}
        case k:
          Cube.Column.Column{ground + 3, 5, ground}
    case k:
      Cube.Column.Column{ground + 4, 4, ground}

def Cube.column_mine(column: Cube.Column) -> Cube.Column:
  match column:
    case Cube.Column.Column{height, block, ground}:
      match height:
        case 0:
          Cube.Column.Column{0, 0, ground}
        case h:
          next = h - 1
          match next:
            case 0:
              Cube.Column.Column{0, 0, ground}
            case n:
              Cube.Column.Column{n, Cube.u32_under(n, ground), ground}

def Cube.column_place(column: Cube.Column, block: U32) -> Cube.Column:
  match column:
    case Cube.Column.Column{height, old, ground}:
      match (block > 0) && ((block <= 12) && (height < Cube.max_height())):
        case 0:
          Cube.Column.Column{height, old, ground}
        case k:
          Cube.Column.Column{height + 1, block, ground}

def Cube.column_json(column: Cube.Column) -> String:
  match column:
    case Cube.Column.Column{height, block, ground}:
      String.flatten(["[", String.from_u32(height), ",", String.from_u32(block), "]"])

# ---------------------------------------------------------------- List

def Cube.list_world(left: U32, index: U32) -> List(Cube.Column):
  match left:
    case 0:
      List.Nil{}
    case k:
      x = index % Cube.world_size()
      z = index / Cube.world_size()
      List.Cons{Cube.column_make(x, z), Cube.list_world(k - 1, index + 1)}

def Cube.list_column_get(columns: List(Cube.Column), index: U32) -> Cube.Column:
  match columns:
    case List.Cons{head, tail}:
      match index:
        case 0:
          head
        case k:
          Cube.list_column_get(tail, k - 1)
    case List.Nil{}:
      Cube.Column.Column{0, 0, 0}

def Cube.list_column_set(columns: List(Cube.Column), index: U32, column: Cube.Column) -> List(Cube.Column):
  match columns:
    case List.Cons{head, tail}:
      match index:
        case 0:
          List.Cons{column, tail}
        case k:
          List.Cons{head, Cube.list_column_set(tail, k - 1, column)}
    case List.Nil{}:
      List.Nil{}

def Cube.list_world_json(columns: List(Cube.Column)) -> String:
  match columns:
    case List.Cons{head, List.Nil{}}:
      String.concat(Cube.column_json(head), "]")
    case List.Cons{head, tail}:
      String.concat(Cube.column_json(head), String.concat(",", Cube.list_world_json(tail)))
    case List.Nil{}:
      "]"

# ---------------------------------------------------------------- Player

def Cube.player_empty(slot: U32) -> Cube.Player:
  Cube.Player.Player{slot, 0, 0, 0, 0, 0, 0, 0}

def Cube.player_spawn(slot: U32, id: U32, now: U32) -> Cube.Player:
  match slot:
    case 1:
      Cube.Player.Player{1, id, 1, 23, 23, 0, 100, now}
    case 2:
      Cube.Player.Player{2, id, 1, 26, 23, 2, 100, now}
    case 3:
      Cube.Player.Player{3, id, 1, 23, 26, 0, 100, now}
    case other:
      Cube.Player.Player{4, id, 1, 26, 26, 2, 100, now}

def Cube.player_active(player: Cube.Player, now: U32) -> U32:
  match player:
    case Cube.Player.Player{slot, id, joined, x, z, face, hp, seen}:
      joined && ((now - seen) < Cube.player_timeout())

def Cube.player_owner(player: Cube.Player, id: U32, now: U32) -> U32:
  match player:
    case Cube.Player.Player{slot, stored, joined, x, z, face, hp, seen}:
      (id > 0) && ((stored == id) && Cube.player_active(Cube.Player.Player{slot, stored, joined, x, z, face, hp, seen}, now))

def Cube.player_touch(player: Cube.Player, now: U32) -> Cube.Player:
  match player:
    case Cube.Player.Player{slot, id, joined, x, z, face, hp, seen}:
      Cube.Player.Player{slot, id, joined, x, z, face, hp, now}

def Cube.player_move(player: Cube.Player, direction: U32, now: U32) -> Cube.Player:
  match player:
    case Cube.Player.Player{slot, id, joined, x, z, face, hp, seen}:
      match direction % 4:
        case 0:
          Cube.Player.Player{slot, id, joined, x, Cube.u32_prev(z), 0, hp, now}
        case 1:
          Cube.Player.Player{slot, id, joined, Cube.u32_next(x), z, 1, hp, now}
        case 2:
          Cube.Player.Player{slot, id, joined, x, Cube.u32_next(z), 2, hp, now}
        case other:
          Cube.Player.Player{slot, id, joined, Cube.u32_prev(x), z, 3, hp, now}

def Cube.player_respawn(player: Cube.Player) -> Cube.Player:
  match player:
    case Cube.Player.Player{slot, id, joined, x, z, face, hp, seen}:
      match slot:
        case 1:
          Cube.Player.Player{1, id, joined, 23, 23, 0, 100, seen}
        case 2:
          Cube.Player.Player{2, id, joined, 26, 23, 2, 100, seen}
        case 3:
          Cube.Player.Player{3, id, joined, 23, 26, 0, 100, seen}
        case other:
          Cube.Player.Player{4, id, joined, 26, 26, 2, 100, seen}

def Cube.player_hit(player: Cube.Player, amount: U32) -> Cube.Player:
  match player:
    case Cube.Player.Player{slot, id, joined, x, z, face, hp, seen}:
      next = Cube.u32_damage(hp, amount)
      match next:
        case 0:
          Cube.player_respawn(Cube.Player.Player{slot, id, joined, x, z, face, next, seen})
        case life:
          Cube.Player.Player{slot, id, joined, x, z, face, life, seen}

def Cube.player_json(player: Cube.Player, now: U32) -> String:
  match player:
    case Cube.Player.Player{slot, id, joined, x, z, face, hp, seen}:
      String.flatten([
        "{\"slot\":", String.from_u32(slot),
        ",\"joined\":", String.from_u32(Cube.player_active(Cube.Player.Player{slot, id, joined, x, z, face, hp, seen}, now)),
        ",\"x\":", String.from_u32(x), ",\"z\":", String.from_u32(z),
        ",\"face\":", String.from_u32(face), ",\"hp\":", String.from_u32(hp), "}"
      ])

# ---------------------------------------------------------------- Target

def Cube.target_empty() -> Cube.Target:
  Cube.Target.Target{0, 0, 0, 999}

def Cube.target_offer(target: Cube.Target, player: Cube.Player, now: U32, x: U32, z: U32) -> Cube.Target:
  match target:
    case Cube.Target.Target{found, tx, tz, distance}:
      match player:
        case Cube.Player.Player{slot, id, joined, px, pz, face, hp, seen}:
          next = Cube.u32_distance(x, z, px, pz)
          match Cube.player_active(Cube.Player.Player{slot, id, joined, px, pz, face, hp, seen}, now) && (next < distance):
            case 0:
              Cube.Target.Target{found, tx, tz, distance}
            case k:
              Cube.Target.Target{1, px, pz, next}

# ---------------------------------------------------------------- Mob

def Cube.mob_spawn(slot: U32) -> Cube.Mob:
  match slot:
    case 1:
      Cube.Mob.Mob{1, 1, 17, 20, 60}
    case 2:
      Cube.Mob.Mob{2, 1, 32, 19, 60}
    case 3:
      Cube.Mob.Mob{3, 1, 18, 34, 60}
    case other:
      Cube.Mob.Mob{4, 1, 35, 33, 60}

def Cube.mob_target(mob: Cube.Mob, one: Cube.Player, two: Cube.Player, three: Cube.Player, four: Cube.Player, now: U32) -> Cube.Target:
  match mob:
    case Cube.Mob.Mob{slot, alive, x, z, hp}:
      first = Cube.target_offer(Cube.target_empty(), one, now, x, z)
      second = Cube.target_offer(first, two, now, x, z)
      third = Cube.target_offer(second, three, now, x, z)
      Cube.target_offer(third, four, now, x, z)

def Cube.mob_step(mob: Cube.Mob, target: Cube.Target, tick: U32) -> Cube.Mob:
  match mob:
    case Cube.Mob.Mob{slot, alive, x, z, hp}:
      match alive:
        case 0:
          Cube.Mob.Mob{slot, 0, x, z, hp}
        case living:
          match target:
            case Cube.Target.Target{found, tx, tz, distance}:
              match found && (distance > 1):
                case 0:
                  Cube.Mob.Mob{slot, 1, x, z, hp}
                case k:
                  match x == tx:
                    case 0:
                      match x < tx:
                        case 0:
                          Cube.Mob.Mob{slot, 1, Cube.u32_prev(x), z, hp}
                        case j:
                          Cube.Mob.Mob{slot, 1, Cube.u32_next(x), z, hp}
                    case same:
                      match z < tz:
                        case 0:
                          Cube.Mob.Mob{slot, 1, x, Cube.u32_prev(z), hp}
                        case j:
                          Cube.Mob.Mob{slot, 1, x, Cube.u32_next(z), hp}

def Cube.mob_hit(mob: Cube.Mob, amount: U32) -> Cube.Mob:
  match mob:
    case Cube.Mob.Mob{slot, alive, x, z, hp}:
      next = Cube.u32_damage(hp, amount)
      match next:
        case 0:
          Cube.Mob.Mob{slot, 0, x, z, 0}
        case life:
          Cube.Mob.Mob{slot, alive, x, z, life}

def Cube.mob_near(mob: Cube.Mob, x: U32, z: U32) -> U32:
  match mob:
    case Cube.Mob.Mob{slot, alive, mx, mz, hp}:
      alive && (Cube.u32_distance(x, z, mx, mz) <= 1)

def Cube.mob_json(mob: Cube.Mob) -> String:
  match mob:
    case Cube.Mob.Mob{slot, alive, x, z, hp}:
      String.flatten(["{\"slot\":", String.from_u32(slot), ",\"alive\":", String.from_u32(alive), ",\"x\":", String.from_u32(x), ",\"z\":", String.from_u32(z), ",\"hp\":", String.from_u32(hp), "}"])

# ---------------------------------------------------------------- Game

def Cube.game_empty() -> Cube.Game:
  Cube.Game.Game{Cube.list_world(Cube.world_size() * Cube.world_size(), 0), Cube.player_empty(1), Cube.player_empty(2), Cube.player_empty(3), Cube.player_empty(4), Cube.mob_spawn(1), Cube.mob_spawn(2), Cube.mob_spawn(3), Cube.mob_spawn(4), 1}

def Cube.game_slot(game: Cube.Game, id: U32, now: U32) -> U32:
  match game:
    case Cube.Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      match Cube.player_owner(one, id, now):
        case 0:
          match Cube.player_owner(two, id, now):
            case 0:
              match Cube.player_owner(three, id, now):
                case 0:
                  match Cube.player_owner(four, id, now):
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

def Cube.game_player(game: Cube.Game, slot: U32) -> Cube.Player:
  match game:
    case Cube.Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      match slot:
        case 1:
          one
        case 2:
          two
        case 3:
          three
        case other:
          four

def Cube.game_player_set(game: Cube.Game, slot: U32, player: Cube.Player) -> Cube.Game:
  match game:
    case Cube.Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      match slot:
        case 1:
          Cube.Game.Game{world, player, two, three, four, m1, m2, m3, m4, tick}
        case 2:
          Cube.Game.Game{world, one, player, three, four, m1, m2, m3, m4, tick}
        case 3:
          Cube.Game.Game{world, one, two, player, four, m1, m2, m3, m4, tick}
        case other:
          Cube.Game.Game{world, one, two, three, player, m1, m2, m3, m4, tick}

def Cube.game_mob(game: Cube.Game, slot: U32) -> Cube.Mob:
  match game:
    case Cube.Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      match slot:
        case 1:
          m1
        case 2:
          m2
        case 3:
          m3
        case other:
          m4

def Cube.game_mob_set(game: Cube.Game, slot: U32, mob: Cube.Mob) -> Cube.Game:
  match game:
    case Cube.Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      match slot:
        case 1:
          Cube.Game.Game{world, one, two, three, four, mob, m2, m3, m4, tick}
        case 2:
          Cube.Game.Game{world, one, two, three, four, m1, mob, m3, m4, tick}
        case 3:
          Cube.Game.Game{world, one, two, three, four, m1, m2, mob, m4, tick}
        case other:
          Cube.Game.Game{world, one, two, three, four, m1, m2, m3, mob, tick}

def Cube.game_ok(game: Cube.Game) -> Cube.Action:
  Cube.Action.Action{game, 1, ""}

def Cube.game_error(game: Cube.Game, note: String) -> Cube.Action:
  Cube.Action.Action{game, 0, note}

def Cube.game_damage_player(player: Cube.Player, m1: Cube.Mob, m2: Cube.Mob, m3: Cube.Mob, m4: Cube.Mob, now: U32) -> Cube.Player:
  match player:
    case Cube.Player.Player{slot, id, joined, x, z, face, hp, seen}:
      hits = Cube.mob_near(m1, x, z) + (Cube.mob_near(m2, x, z) + (Cube.mob_near(m3, x, z) + Cube.mob_near(m4, x, z)))
      match Cube.player_active(Cube.Player.Player{slot, id, joined, x, z, face, hp, seen}, now) && (hits > 0):
        case 0:
          Cube.Player.Player{slot, id, joined, x, z, face, hp, seen}
        case k:
          Cube.player_hit(Cube.Player.Player{slot, id, joined, x, z, face, hp, seen}, hits * 3)

def Cube.game_advance(game: Cube.Game, now: U32) -> Cube.Game:
  match game:
    case Cube.Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      match (now - tick) < Cube.mob_interval():
        case 0:
          n1 = Cube.mob_step(m1, Cube.mob_target(m1, one, two, three, four, now), tick)
          n2 = Cube.mob_step(m2, Cube.mob_target(m2, one, two, three, four, now), tick)
          n3 = Cube.mob_step(m3, Cube.mob_target(m3, one, two, three, four, now), tick)
          n4 = Cube.mob_step(m4, Cube.mob_target(m4, one, two, three, four, now), tick)
          p1 = Cube.game_damage_player(one, n1, n2, n3, n4, now)
          p2 = Cube.game_damage_player(two, n1, n2, n3, n4, now)
          p3 = Cube.game_damage_player(three, n1, n2, n3, n4, now)
          p4 = Cube.game_damage_player(four, n1, n2, n3, n4, now)
          Cube.Game.Game{world, p1, p2, p3, p4, n1, n2, n3, n4, now}
        case k:
          Cube.Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}

def Cube.game_state(game: Cube.Game, id: U32, now: U32) -> Cube.Game:
  advanced = Cube.game_advance(game, now)
  slot = Cube.game_slot(advanced, id, now)
  match slot:
    case 0:
      advanced
    case own:
      Cube.game_player_set(advanced, own, Cube.player_touch(Cube.game_player(advanced, own), now))

def Cube.game_join_new(game: Cube.Game, id: U32, now: U32) -> Cube.Action:
  match game:
    case Cube.Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      match Cube.player_active(one, now):
        case 0:
          Cube.game_ok(Cube.Game.Game{world, Cube.player_spawn(1, id, now), two, three, four, m1, m2, m3, m4, tick})
        case k:
          match Cube.player_active(two, now):
            case 0:
              Cube.game_ok(Cube.Game.Game{world, one, Cube.player_spawn(2, id, now), three, four, m1, m2, m3, m4, tick})
            case j:
              match Cube.player_active(three, now):
                case 0:
                  Cube.game_ok(Cube.Game.Game{world, one, two, Cube.player_spawn(3, id, now), four, m1, m2, m3, m4, tick})
                case q:
                  match Cube.player_active(four, now):
                    case 0:
                      Cube.game_ok(Cube.Game.Game{world, one, two, three, Cube.player_spawn(4, id, now), m1, m2, m3, m4, tick})
                    case p:
                      Cube.game_error(Cube.Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}, "The world already has four active players.")

def Cube.game_join(game: Cube.Game, id: U32, now: U32) -> Cube.Action:
  match id:
    case 0:
      Cube.game_error(game, "Invalid player identity.")
    case valid:
      slot = Cube.game_slot(game, valid, now)
      match slot:
        case 0:
          Cube.game_join_new(game, valid, now)
        case own:
          Cube.game_ok(Cube.game_player_set(game, own, Cube.player_touch(Cube.game_player(game, own), now)))

def Cube.game_move(game: Cube.Game, id: U32, direction: U32, now: U32) -> Cube.Action:
  slot = Cube.game_slot(game, id, now)
  match slot:
    case 0:
      Cube.game_error(game, "Join the world before moving.")
    case own:
      Cube.game_ok(Cube.game_player_set(game, own, Cube.player_move(Cube.game_player(game, own), direction, now)))

def Cube.game_mine(game: Cube.Game, id: U32, x: U32, z: U32, now: U32) -> Cube.Action:
  slot = Cube.game_slot(game, id, now)
  match slot:
    case 0:
      Cube.game_error(game, "Join the world before mining.")
    case own:
      player = Cube.game_player(game, own)
      match player:
        case Cube.Player.Player{number, stored, joined, px, pz, face, hp, seen}:
          match (x < Cube.world_size()) && ((z < Cube.world_size()) && Cube.u32_near(px, pz, x, z)):
            case 0:
              Cube.game_error(game, "That block is outside your reach.")
            case k:
              match game:
                case Cube.Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
                  index = (z * Cube.world_size()) + x
                  touched = Cube.player_touch(Cube.Player.Player{number, stored, joined, px, pz, face, hp, seen}, now)
                  Cube.game_ok(Cube.game_player_set(Cube.Game.Game{Cube.list_column_set(world, index, Cube.column_mine(Cube.list_column_get(world, index))), one, two, three, four, m1, m2, m3, m4, tick}, own, touched))

def Cube.game_place(game: Cube.Game, id: U32, x: U32, z: U32, block: U32, now: U32) -> Cube.Action:
  slot = Cube.game_slot(game, id, now)
  match slot:
    case 0:
      Cube.game_error(game, "Join the world before building.")
    case own:
      player = Cube.game_player(game, own)
      match player:
        case Cube.Player.Player{number, stored, joined, px, pz, face, hp, seen}:
          match (x < Cube.world_size()) && ((z < Cube.world_size()) && (Cube.u32_near(px, pz, x, z) && ((block > 0) && (block <= 12)))):
            case 0:
              Cube.game_error(game, "Choose one of the twelve materials within reach.")
            case k:
              match game:
                case Cube.Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
                  index = (z * Cube.world_size()) + x
                  touched = Cube.player_touch(Cube.Player.Player{number, stored, joined, px, pz, face, hp, seen}, now)
                  Cube.game_ok(Cube.game_player_set(Cube.Game.Game{Cube.list_column_set(world, index, Cube.column_place(Cube.list_column_get(world, index), block)), one, two, three, four, m1, m2, m3, m4, tick}, own, touched))

def Cube.game_attack_mob(game: Cube.Game, id: U32, mob_slot: U32, now: U32) -> Cube.Action:
  slot = Cube.game_slot(game, id, now)
  match slot:
    case 0:
      Cube.game_error(game, "Join the world before attacking.")
    case own:
      player = Cube.game_player(game, own)
      mob = Cube.game_mob(game, mob_slot)
      match player:
        case Cube.Player.Player{number, stored, joined, px, pz, face, hp, seen}:
          match mob:
            case Cube.Mob.Mob{target, alive, mx, mz, life}:
              match (mob_slot > 0) && ((mob_slot <= 4) && (alive && (Cube.u32_distance(px, pz, mx, mz) <= 2))):
                case 0:
                  Cube.game_error(game, "That raider is outside sword reach.")
                case k:
                  Cube.game_ok(Cube.game_mob_set(Cube.game_player_set(game, own, Cube.player_touch(player, now)), target, Cube.mob_hit(mob, 25)))

def Cube.game_attack_player(game: Cube.Game, id: U32, target_slot: U32, now: U32) -> Cube.Action:
  slot = Cube.game_slot(game, id, now)
  match slot:
    case 0:
      Cube.game_error(game, "Join the world before attacking.")
    case own:
      attacker = Cube.game_player(game, own)
      target = Cube.game_player(game, target_slot)
      match attacker:
        case Cube.Player.Player{number, stored, joined, ax, az, face, hp, seen}:
          match target:
            case Cube.Player.Player{victim, target_id, target_joined, tx, tz, target_face, target_hp, target_seen}:
              match (target_slot > 0) && ((target_slot <= 4) && ((target_slot != own) && (Cube.player_active(target, now) && (Cube.u32_distance(ax, az, tx, tz) <= 2)))):
                case 0:
                  Cube.game_error(game, "That player is outside sword reach.")
                case k:
                  touched = Cube.player_touch(attacker, now)
                  damaged = Cube.player_hit(target, 20)
                  Cube.game_ok(Cube.game_player_set(Cube.game_player_set(game, target_slot, damaged), own, touched))

def Cube.game_leave(game: Cube.Game, id: U32, now: U32) -> Cube.Action:
  slot = Cube.game_slot(game, id, now)
  match slot:
    case 0:
      Cube.game_error(game, "This browser has not joined the world.")
    case own:
      Cube.game_ok(Cube.game_player_set(game, own, Cube.player_empty(own)))

def Cube.game_full(game: Cube.Game, now: U32) -> U32:
  match game:
    case Cube.Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      Cube.player_active(one, now) && (Cube.player_active(two, now) && (Cube.player_active(three, now) && Cube.player_active(four, now)))

# ---------------------------------------------------------------- JSON and routing

def Cube.game_json(game: Cube.Game, id: U32, now: U32, ok: U32, note: String) -> String:
  match game:
    case Cube.Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      String.flatten([
        "{\"ok\":", String.from_u32(ok), ",\"note\":\"", note,
        "\",\"you\":", String.from_u32(Cube.game_slot(Cube.Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}, id, now)),
        ",\"full\":", String.from_u32(Cube.game_full(Cube.Game.Game{world, one, two, three, four, m1, m2, m3, m4, tick}, now)),
        ",\"tick\":", String.from_u32(tick), ",\"size\":", String.from_u32(Cube.world_size()),
        ",\"renderDistance\":", String.from_u32(Cube.render_distance()),
        ",\"players\":[", Cube.player_json(one, now), ",", Cube.player_json(two, now), ",", Cube.player_json(three, now), ",", Cube.player_json(four, now), "],",
        "\"mobs\":[", Cube.mob_json(m1), ",", Cube.mob_json(m2), ",", Cube.mob_json(m3), ",", Cube.mob_json(m4), "],",
        "\"world\":[", Cube.list_world_json(world), "}"
      ])

def Cube.game_response(game: Cube.Game, id: U32, now: U32, ok: U32, note: String) -> HTTP.Response:
  HTTP.Response.Response{200, [HTTP.Header.Header{"Content-Type", "application/json; charset=utf-8"}, HTTP.Header.Header{"Cache-Control", "no-store, no-cache, must-revalidate"}], Bytes.from_string(Cube.game_json(game, id, now, ok, note))}

def Cube.game_routed(game: Cube.Game, id: U32, now: U32) -> Cube.Routed:
  Cube.Routed.Routed{game, Cube.game_response(game, id, now, 1, "")}

def Cube.game_missing(game: Cube.Game) -> Cube.Routed:
  Cube.Routed.Routed{game, HTTP.not_found()}

def Cube.action_routed(action: Cube.Action, id: U32, now: U32) -> Cube.Routed:
  match action:
    case Cube.Action.Action{game, ok, note}:
      Cube.Routed.Routed{game, Cube.game_response(game, id, now, ok, note)}

def Cube.result_index(result: Result((U32 & String), String), game: Cube.Game) -> IO(Cube.Routed):
  match result:
    case Result.Done{html}:
      IO.pure(Cube.Routed, Cube.Routed.Routed{game, HTTP.reply(200, "text/html; charset=utf-8", html)})
    case Result.Fail{(code, error)}:
      IO.pure(Cube.Routed, Cube.Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run from the repository root\n")})

def Cube.game_index(game: Cube.Game) -> IO(Cube.Routed):
  do IO(Cube.Routed):
    result <- IO.read_text("gabriel_demos/cubeworld2_web/index.html")
    Cube.result_index(result, game)

def Cube.list_state(args: List(String), game: Cube.Game, now: U32) -> IO(Cube.Routed):
  match args:
    case List.Cons{id, rest}:
      player = String.to_u32(id)
      touched = Cube.game_state(game, player, now)
      IO.pure(Cube.Routed, Cube.game_routed(touched, player, now))
    case List.Nil{}:
      IO.pure(Cube.Routed, Cube.game_missing(game))

def Cube.list_join(args: List(String), game: Cube.Game, now: U32) -> IO(Cube.Routed):
  match args:
    case List.Cons{id, rest}:
      player = String.to_u32(id)
      IO.pure(Cube.Routed, Cube.action_routed(Cube.game_join(game, player, now), player, now))
    case List.Nil{}:
      IO.pure(Cube.Routed, Cube.game_missing(game))

def Cube.list_move(args: List(String), game: Cube.Game, now: U32) -> IO(Cube.Routed):
  match args:
    case List.Cons{id, List.Cons{direction, rest}}:
      player = String.to_u32(id)
      IO.pure(Cube.Routed, Cube.action_routed(Cube.game_move(game, player, String.to_u32(direction), now), player, now))
    case other:
      IO.pure(Cube.Routed, Cube.game_missing(game))

def Cube.list_mine(args: List(String), game: Cube.Game, now: U32) -> IO(Cube.Routed):
  match args:
    case List.Cons{id, List.Cons{x, List.Cons{z, rest}}}:
      player = String.to_u32(id)
      IO.pure(Cube.Routed, Cube.action_routed(Cube.game_mine(game, player, String.to_u32(x), String.to_u32(z), now), player, now))
    case other:
      IO.pure(Cube.Routed, Cube.game_missing(game))

def Cube.list_place(args: List(String), game: Cube.Game, now: U32) -> IO(Cube.Routed):
  match args:
    case List.Cons{id, List.Cons{x, List.Cons{z, List.Cons{block, rest}}}}:
      player = String.to_u32(id)
      IO.pure(Cube.Routed, Cube.action_routed(Cube.game_place(game, player, String.to_u32(x), String.to_u32(z), String.to_u32(block), now), player, now))
    case other:
      IO.pure(Cube.Routed, Cube.game_missing(game))

def Cube.list_attack_mob(args: List(String), game: Cube.Game, now: U32) -> IO(Cube.Routed):
  match args:
    case List.Cons{id, List.Cons{slot, rest}}:
      player = String.to_u32(id)
      IO.pure(Cube.Routed, Cube.action_routed(Cube.game_attack_mob(game, player, String.to_u32(slot), now), player, now))
    case other:
      IO.pure(Cube.Routed, Cube.game_missing(game))

def Cube.list_attack_player(args: List(String), game: Cube.Game, now: U32) -> IO(Cube.Routed):
  match args:
    case List.Cons{id, List.Cons{slot, rest}}:
      player = String.to_u32(id)
      IO.pure(Cube.Routed, Cube.action_routed(Cube.game_attack_player(game, player, String.to_u32(slot), now), player, now))
    case other:
      IO.pure(Cube.Routed, Cube.game_missing(game))

def Cube.list_leave(args: List(String), game: Cube.Game, now: U32) -> IO(Cube.Routed):
  match args:
    case List.Cons{id, rest}:
      player = String.to_u32(id)
      IO.pure(Cube.Routed, Cube.action_routed(Cube.game_leave(game, player, now), player, now))
    case List.Nil{}:
      IO.pure(Cube.Routed, Cube.game_missing(game))

def Cube.string_route(name: String, args: List(String), game: Cube.Game, now: U32) -> IO(Cube.Routed):
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
                                      IO.pure(Cube.Routed, Cube.game_missing(game))
                                    case yes:
                                      Cube.list_leave(args, game, now)
                                case yes:
                                  Cube.list_attack_player(args, game, now)
                            case yes:
                              Cube.list_attack_mob(args, game, now)
                        case yes:
                          Cube.list_place(args, game, now)
                    case yes:
                      Cube.list_mine(args, game, now)
                case yes:
                  Cube.list_move(args, game, now)
            case yes:
              Cube.list_join(args, game, now)
        case yes:
          Cube.list_state(args, game, now)
    case root:
      Cube.game_index(game)

def Cube.list_route(parts: List(String), game: Cube.Game, now: U32) -> IO(Cube.Routed):
  match parts:
    case List.Cons{root, List.Cons{name, args}}:
      Cube.string_route(name, args, game, now)
    case List.Cons{root, List.Nil{}}:
      Cube.game_index(game)
    case List.Nil{}:
      Cube.game_index(game)

def Cube.request_route(request: HTTP.Request, game: Cube.Game, now: U32) -> IO(Cube.Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(method, "GET"):
        case 0:
          IO.pure(Cube.Routed, Cube.Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")})
        case k:
          Cube.list_route(String.split('/', path), game, now)

# ---------------------------------------------------------------- server

def Cube.routed_send(routed: Cube.Routed, server: TCP, conn: HTTP) -> IO(U32):
  match routed:
    case Cube.Routed.Routed{game, response}:
      do IO(U32):
        sent <- HTTP.send_response(conn, HTTP.with_connection(0, response))
        closed <- HTTP.close(conn)
        Cube.u32_serve(server, game)

def Cube.inbound_serve(inbound: HTTP.Inbound, server: TCP, conn: HTTP, game: Cube.Game) -> IO(U32):
  match inbound:
    case HTTP.Inbound.Got{http11, request, rest}:
      do IO(U32):
        now <- clock_now_ms()
        routed <- Cube.request_route(request, game, now)
        Cube.routed_send(routed, server, conn)
    case HTTP.Inbound.Closed{}:
      do IO(U32):
        closed <- HTTP.close(conn)
        Cube.u32_serve(server, game)
    case HTTP.Inbound.Bad{code, error}:
      Cube.routed_send(Cube.Routed.Routed{game, HTTP.reply_error(code, error)}, server, conn)

def Cube.result_accept(result: Result((U32 & String), TCP), server: TCP, game: Cube.Game) -> IO(U32):
  match result:
    case Result.Done{fd}:
      do IO(U32):
        inbound <- HTTP.recv_request(HTTP.Plain{fd}, List.Nil{})
        Cube.inbound_serve(inbound, server, HTTP.Plain{fd}, game)
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["accept failed: ", error, "\n"]))
        return 1

def Cube.u32_serve(server: TCP, game: Cube.Game) -> IO(U32):
  do IO(U32):
    result <- TCP.accept(server)
    Cube.result_accept(result, server, game)

def Cube.result_main(result: Result((U32 & String), TCP)) -> IO(U32):
  match result:
    case Result.Done{server}:
      do IO(U32):
        printed <- IO.write("CubeWorld 2 listening on all interfaces (0.0.0.0:8086)\nopen http://<server-lan-ip>:8086\n")
        Cube.u32_serve(server, Cube.game_empty())
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def Cube.main() -> IO(U32):
  do IO(U32):
    result <- TCP.listen(8086)
    Cube.result_main(result)
