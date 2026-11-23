# CubeWorld 2: first-person multiplayer voxel survival in Bend.
#
# Bend owns the 48x48 terrain, four player slots, four hostile mobs, block
# edits, pursuit, combat, health, and respawning. The browser only renders and
# submits actions.
#
# routes (also accepted under a leading /cubeworld2, as the BendJogos hub uses):
#   GET /                                     page
#   GET /state/<player>                       advance mobs, shared snapshot
#   GET /join/<player>                        take an available slot
#   GET /move/<player>/<direction>            move north/east/south/west (0..3)
#   GET /mine/<player>/<x>/<z>                remove a nearby top block
#   GET /place/<player>/<x>/<z>/<material>    place one of twelve materials
#   GET /attack-mob/<player>/<mob-slot>       hit a raider in sword reach
#   GET /attack-player/<player>/<target-slot> hit another player in reach
#   GET /leave/<player>                       release the slot
#
# check: bend Bend3/demos/cubeworld2_web/web_cubeworld2.bend --check-only
# build: ./Bend3/demos/cubeworld2_web/build.sh
# run:   ./Bend3/demos/cubeworld2_web/start.sh   (from the repository root)
# open:  http://<server-lan-ip>:8086
#
# Hub interface: `Game`, `init()`, `game_advance(game, now)`,
# `route(req, game)` (reads the clock) and `route_at(req, game, now)`. Both
# routes accept paths with or without the `/cubeworld2` prefix.

import Base
import ../HTTP.bend as HTTP
import ../Compat.bend as Compat
import ../Clock.bend as Clock

def world_size() -> U32:
  48

def render_distance() -> U32:
  7

def player_timeout() -> U32:
  30000

def mob_interval() -> U32:
  650

def max_height() -> U32:
  12

type Column is Data:
  Column{height: U32, block: U32, ground: U32}

type Player is Data:
  Player{slot: U32, id: U32, joined: U32, x: U32, z: U32, face: U32, hp: U32, seen: U32}

type Mob is Data:
  Mob{slot: U32, alive: U32, x: U32, z: U32, hp: U32}

type Target is Data:
  Target{found: U32, x: U32, z: U32, distance: U32}

type Game is Data:
  Game{world: List<&2, Column>, one: Player, two: Player, three: Player, four: Player, mob_one: Mob, mob_two: Mob, mob_three: Mob, mob_four: Mob, tick: U32}

type Action is Data:
  Action{game: Game, ok: U32, note: String}

# ---------------------------------------------------------------- U32

def u32_abs_diff(+a: U32, +b: U32) -> U32:
  Bool.pick(U32, (a < b : U32), (b - a : U32), (a - b : U32))

def u32_distance(+x: U32, +z: U32, +other_x: U32, +other_z: U32) -> U32:
  (u32_abs_diff(x, other_x) + u32_abs_diff(z, other_z) : U32)

def u32_near(+x: U32, +z: U32, +other_x: U32, +other_z: U32) -> Bool:
  (u32_distance(x, z, other_x, other_z) <= 3 : U32)

def u32_ground(+x: U32, +z: U32) -> U32:
  (2 + (((((x * 13) + (z * 7)) + (x * z)) + ((x / 5) * 3)) % 4) : U32)

def at(+x: U32, +z: U32, cx: U32, cz: U32) -> Bool:
  U32.is_eq(x, cx) && U32.is_eq(z, cz)

def u32_tree(+x: U32, +z: U32) -> Bool:
  at(x, z, 8, 9) || (at(x, z, 19, 14) || (at(x, z, 35, 10) || (at(x, z, 12, 34) || (at(x, z, 31, 31) || at(x, z, 40, 40)))))

def u32_canopy_one(+x: U32, +z: U32, +cx: U32, +cz: U32) -> Bool:
  (u32_abs_diff(x, cx) <= 1 : U32) && (u32_abs_diff(z, cz) <= 1 : U32)

def u32_canopy(+x: U32, +z: U32) -> Bool:
  u32_canopy_one(x, z, 8, 9) || (u32_canopy_one(x, z, 19, 14) || (u32_canopy_one(x, z, 35, 10) || (u32_canopy_one(x, z, 12, 34) || (u32_canopy_one(x, z, 31, 31) || u32_canopy_one(x, z, 40, 40)))))

# Beach (sand/water) along the low edges, coal specks, snow on high ground.
def u32_surface(+x: U32, +z: U32, +ground: U32) -> U32:
  Bool.pick(U32, (x < 6 : U32) || (z < 5 : U32),
    Bool.pick(U32, (ground <= 3 : U32), 7, 6),
    Bool.pick(U32, U32.is_zero((((x * 5) + (z * 11)) % 29 : U32)), 9,
      Bool.pick(U32, (ground >= 5 : U32), 10, 1)))

def u32_under(+height: U32, +ground: U32) -> U32:
  Bool.pick(U32, U32.is_eq(height, ground), 1, Bool.pick(U32, ((height + 1 : U32) >= ground : U32), 2, 3))

def u32_prev(value: U32) -> U32:
  match value:
    case 0:
      0
    case k:
      (k - 1 : U32)

def u32_next(value: U32) -> U32:
  match value:
    case 47:
      47
    case k:
      (k + 1 : U32)

def u32_damage(+hp: U32, +amount: U32) -> U32:
  Bool.pick(U32, (hp <= amount : U32), 0, (hp - amount : U32))

def nonzero(+n: U32) -> Bool:
  Bool.not(U32.is_zero(n))

# ---------------------------------------------------------------- Column

def column_make.pick(tree: Bool, canopy: Bool, +x: U32, +z: U32, +ground: U32) -> Column:
  match tree canopy:
    case True{} _:
      Column{(ground + 4 : U32), 4, ground}
    case False{} True{}:
      Column{(ground + 3 : U32), 5, ground}
    case False{} False{}:
      Column{ground, u32_surface(x, z, ground), ground}

def column_make(+x: U32, +z: U32) -> Column:
  column_make.pick(u32_tree(x, z), u32_canopy(x, z), x, z, u32_ground(x, z))

def column_mine.next(next: U32, +ground: U32) -> Column:
  match next:
    case 0:
      Column{0, 0, ground}
    case +n:
      Column{n, u32_under(n, ground), ground}

def column_mine(column: Column) -> Column:
  match column:
    case Column{height, block, +ground}:
      match height:
        case 0:
          Column{0, 0, ground}
        case h:
          column_mine.next((h - 1 : U32), ground)

def column_place(column: Column, +block: U32) -> Column:
  Column{+height, +old, +ground} = column
  Bool.pick(Column, (block > 0 : U32) && ((block <= 12 : U32) && (height < max_height() : U32)),
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
  Player{slot, 0, 0, 0, 0, 0, 0, 0}

def player_spawn(slot: U32, id: U32, now: U32) -> Player:
  match slot:
    case 1:
      Player{1, id, 1, 23, 23, 0, 100, now}
    case 2:
      Player{2, id, 1, 26, 23, 2, 100, now}
    case 3:
      Player{3, id, 1, 23, 26, 0, 100, now}
    case other:
      Player{4, id, 1, 26, 26, 2, 100, now}

def player_active(player: Player, +now: U32) -> Bool:
  Player{slot, id, joined, x, z, face, hp, seen} = player
  nonzero(joined) && ((now - seen : U32) < player_timeout() : U32)

def player_owner(+player: Player, +id: U32, +now: U32) -> Bool:
  Player{slot, stored, joined, x, z, face, hp, seen} = player
  (id > 0 : U32) && (U32.is_eq(stored, id) && player_active(player, now))

def player_touch(player: Player, now: U32) -> Player:
  Player{slot, id, joined, x, z, face, hp, seen} = player
  Player{slot, id, joined, x, z, face, hp, now}

def player_move.dir(player: Player, dir: U32, +now: U32) -> Player:
  match player:
    case Player{slot, id, joined, +x, +z, face, hp, seen}:
      match dir:
        case 0:
          Player{slot, id, joined, x, u32_prev(z), 0, hp, now}
        case 1:
          Player{slot, id, joined, u32_next(x), z, 1, hp, now}
        case 2:
          Player{slot, id, joined, x, u32_next(z), 2, hp, now}
        case other:
          Player{slot, id, joined, u32_prev(x), z, 3, hp, now}

def player_move(player: Player, +direction: U32, +now: U32) -> Player:
  player_move.dir(player, (direction % 4 : U32), now)

def player_respawn(player: Player) -> Player:
  match player:
    case Player{slot, id, joined, x, z, face, hp, seen}:
      match slot:
        case 1:
          Player{1, id, joined, 23, 23, 0, 100, seen}
        case 2:
          Player{2, id, joined, 26, 23, 2, 100, seen}
        case 3:
          Player{3, id, joined, 23, 26, 0, 100, seen}
        case other:
          Player{4, id, joined, 26, 26, 2, 100, seen}

def player_hit.next(player: Player, next: U32) -> Player:
  Player{slot, id, joined, x, z, face, hp, seen} = player
  match next:
    case 0:
      player_respawn(Player{slot, id, joined, x, z, face, 0, seen})
    case life:
      Player{slot, id, joined, x, z, face, life, seen}

def player_hp(player: Player) -> U32:
  Player{slot, id, joined, x, z, face, hp, seen} = player
  hp

def player_hit(+player: Player, +amount: U32) -> Player:
  player_hit.next(player, u32_damage(player_hp(player), amount))

def player_json(+player: Player, +now: U32) -> String:
  Player{slot, id, joined, x, z, face, hp, seen} = player
  String.concat([
    "{\"slot\":", U32.show(slot),
    ",\"joined\":", U32.show(Bool.to_u32(player_active(player, now))),
    ",\"x\":", U32.show(x), ",\"z\":", U32.show(z),
    ",\"face\":", U32.show(face), ",\"hp\":", U32.show(hp), "}"])

def player_x(player: Player) -> U32:
  Player{slot, id, joined, x, z, face, hp, seen} = player
  x

def player_z(player: Player) -> U32:
  Player{slot, id, joined, x, z, face, hp, seen} = player
  z

# The distance between a player and a point.
def player_distance(+player: Player, +x: U32, +z: U32) -> U32:
  u32_distance(x, z, player_x(player), player_z(player))

# ---------------------------------------------------------------- Target

def target_empty() -> Target:
  Target{0, 0, 0, 999}

def target_offer.pick(closer: Bool, target: Target, +player: Player, next: U32) -> Target:
  match closer:
    case True{}:
      Target{1, player_x(player), player_z(player), next}
    case False{}:
      target

def target_distance(target: Target) -> U32:
  Target{found, tx, tz, distance} = target
  distance

def target_offer.at(+target: Target, +player: Player, +now: U32, +next: U32) -> Target:
  target_offer.pick(player_active(player, now) && (next < target_distance(target) : U32), target, player, next)

def target_offer(+target: Target, +player: Player, +now: U32, +x: U32, +z: U32) -> Target:
  target_offer.at(target, player, now, player_distance(player, x, z))

# ---------------------------------------------------------------- Mob

def mob_spawn(slot: U32) -> Mob:
  match slot:
    case 1:
      Mob{1, 1, 17, 20, 60}
    case 2:
      Mob{2, 1, 32, 19, 60}
    case 3:
      Mob{3, 1, 18, 34, 60}
    case other:
      Mob{4, 1, 35, 33, 60}

def mob_target(mob: Mob, one: Player, two: Player, three: Player, four: Player, +now: U32) -> Target:
  Mob{slot, alive, +x, +z, hp} = mob
  first = target_offer(target_empty(), one, now, x, z)
  second = target_offer(first, two, now, x, z)
  third = target_offer(second, three, now, x, z)
  target_offer(third, four, now, x, z)

# A living mob one step toward its target (x first, then z).
def mob_step.chase(chase: Bool, same_x: Bool, +slot: U32, +x: U32, +z: U32, +hp: U32, +tx: U32, +tz: U32) -> Mob:
  match chase same_x:
    case False{} _:
      Mob{slot, 1, x, z, hp}
    case True{} False{}:
      Bool.pick(Mob, (x < tx : U32), Mob{slot, 1, u32_next(x), z, hp}, Mob{slot, 1, u32_prev(x), z, hp})
    case True{} True{}:
      Bool.pick(Mob, (z < tz : U32), Mob{slot, 1, x, u32_next(z), hp}, Mob{slot, 1, x, u32_prev(z), hp})

def mob_step(mob: Mob, target: Target, tick: U32) -> Mob:
  match mob:
    case Mob{+slot, alive, +x, +z, +hp}:
      match alive:
        case 0:
          Mob{slot, 0, x, z, hp}
        case living:
          Target{found, +tx, +tz, distance} = target
          mob_step.chase(nonzero(found) && (distance > 1 : U32), U32.is_eq(x, tx), slot, x, z, hp, tx, tz)

def mob_hit.next(mob: Mob, next: U32) -> Mob:
  Mob{slot, alive, x, z, hp} = mob
  match next:
    case 0:
      Mob{slot, 0, x, z, 0}
    case life:
      Mob{slot, alive, x, z, life}

def mob_hp(mob: Mob) -> U32:
  Mob{slot, alive, x, z, hp} = mob
  hp

def mob_hit(+mob: Mob, +amount: U32) -> Mob:
  mob_hit.next(mob, u32_damage(mob_hp(mob), amount))

def mob_near(mob: Mob, +x: U32, +z: U32) -> U32:
  Mob{slot, alive, mx, mz, hp} = mob
  Bool.to_u32(nonzero(alive) && (u32_distance(x, z, mx, mz) <= 1 : U32))

def mob_json(mob: Mob) -> String:
  Mob{slot, alive, x, z, hp} = mob
  String.concat(["{\"slot\":", U32.show(slot), ",\"alive\":", U32.show(alive), ",\"x\":", U32.show(x), ",\"z\":", U32.show(z), ",\"hp\":", U32.show(hp), "}"])

# ---------------------------------------------------------------- Game

def game_empty() -> Game:
  Game{list_world(U32.to_nat((world_size() * world_size() : U32)), 0), player_empty(1), player_empty(2), player_empty(3), player_empty(4), mob_spawn(1), mob_spawn(2), mob_spawn(3), mob_spawn(4), 1}

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
  Game{world, one, two, three, four, m1, m2, m3, m4, tick} = game
  game_slot.pick(player_owner(one, id, now), player_owner(two, id, now), player_owner(three, id, now), player_owner(four, id, now))

def game_player(game: Game, slot: U32) -> Player:
  match game:
    case Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
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
    case Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      match slot:
        case 1:
          Game{world, player, two, three, four, m1, m2, m3, m4, tick}
        case 2:
          Game{world, one, player, three, four, m1, m2, m3, m4, tick}
        case 3:
          Game{world, one, two, player, four, m1, m2, m3, m4, tick}
        case other:
          Game{world, one, two, three, player, m1, m2, m3, m4, tick}

def game_mob(game: Game, slot: U32) -> Mob:
  match game:
    case Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
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
    case Game{world, one, two, three, four, m1, m2, m3, m4, tick}:
      match slot:
        case 1:
          Game{world, one, two, three, four, mob, m2, m3, m4, tick}
        case 2:
          Game{world, one, two, three, four, m1, mob, m3, m4, tick}
        case 3:
          Game{world, one, two, three, four, m1, m2, mob, m4, tick}
        case other:
          Game{world, one, two, three, four, m1, m2, m3, mob, tick}

def game_ok(game: Game) -> Action:
  Action{game, 1, ""}

def game_error(game: Game, note: String) -> Action:
  Action{game, 0, note}

def game_damage_player.pick(hurt: Bool, +player: Player, +hits: U32) -> Player:
  match hurt:
    case False{}:
      player
    case True{}:
      player_hit(player, (hits * 3 : U32))

def game_damage_player.hits(+player: Player, +hits: U32, +now: U32) -> Player:
  game_damage_player.pick(player_active(player, now) && (hits > 0 : U32), player, hits)

def game_damage_player(+player: Player, +m1: Mob, +m2: Mob, +m3: Mob, +m4: Mob, +now: U32) -> Player:
  +x = player_x(player)
  +z = player_z(player)
  +hits = (mob_near(m1, x, z) + (mob_near(m2, x, z) + (mob_near(m3, x, z) + mob_near(m4, x, z))) : U32)
  game_damage_player.hits(player, hits, now)

def game_advance.step(+game: Game, +now: U32) -> Game:
  Game{world, +one, +two, +three, +four, m1, m2, m3, m4, +tick} = game
  +n1 = mob_step(m1, mob_target(m1, one, two, three, four, now), tick)
  +n2 = mob_step(m2, mob_target(m2, one, two, three, four, now), tick)
  +n3 = mob_step(m3, mob_target(m3, one, two, three, four, now), tick)
  +n4 = mob_step(m4, mob_target(m4, one, two, three, four, now), tick)
  p1 = game_damage_player(one, n1, n2, n3, n4, now)
  p2 = game_damage_player(two, n1, n2, n3, n4, now)
  p3 = game_damage_player(three, n1, n2, n3, n4, now)
  p4 = game_damage_player(four, n1, n2, n3, n4, now)
  Game{world, p1, p2, p3, p4, n1, n2, n3, n4, now}

def game_advance.pick(due: Bool, +game: Game, +now: U32) -> Game:
  match due:
    case False{}:
      game
    case True{}:
      game_advance.step(game, now)

def game_tick(game: Game) -> U32:
  Game{world, one, two, three, four, m1, m2, m3, m4, tick} = game
  tick

# Steps the raiders once per mob_interval of real time (tick is the time of
# the last step), whatever the number of polling browsers.
def game_advance(+game: Game, +now: U32) -> Game:
  game_advance.pick(Bool.not(((now - game_tick(game) : U32) < mob_interval() : U32)), game, now)

def game_state.at(+game: Game, slot: U32, +now: U32) -> Game:
  match slot:
    case 0:
      game
    case +own:
      game_player_set(game, own, player_touch(game_player(game, own), now))

def game_state.go(+advanced: Game, +id: U32, +now: U32) -> Game:
  game_state.at(advanced, game_slot(advanced, id, now), now)

def game_state(+game: Game, +id: U32, +now: U32) -> Game:
  game_state.go(game_advance(game, now), id, now)

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
  Game{world, one, two, three, four, m1, m2, m3, m4, tick} = game
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
  Game{+world, one, two, three, four, m1, m2, m3, m4, tick} = game
  +index = ((z * world_size()) + x : U32)
  +g2 : Game = Game{list_column_set(world, index, edit(list_column_get(world, index))), one, two, three, four, m1, m2, m3, m4, tick}
  game_player_set(g2, own, player_touch(game_player(g2, own), now))

def player_reach(player: Player, +x: U32, +z: U32) -> Bool:
  Player{slot, id, joined, px, pz, face, hp, seen} = player
  (x < world_size() : U32) && ((z < world_size() : U32) && u32_near(px, pz, x, z))

def game_reach(+game: Game, +own: U32, +x: U32, +z: U32) -> Bool:
  player_reach(game_player(game, own), x, z)

def game_mine.ok(reach: Bool, +game: Game, +own: U32, +x: U32, +z: U32, +now: U32) -> Action:
  match reach:
    case False{}:
      game_error(game, "That block is outside your reach.")
    case True{}:
      game_ok(game_edit(game, own, x, z, c => column_mine(c), now))

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
      game_error(game, "Choose one of the twelve materials within reach.")
    case True{}:
      game_ok(game_edit(game, own, x, z, c => column_place(c, block), now))

def game_place.at(+game: Game, slot: U32, +x: U32, +z: U32, +block: U32, +now: U32) -> Action:
  match slot:
    case 0:
      game_error(game, "Join the world before building.")
    case +own:
      game_place.ok(game_reach(game, own, x, z) && ((block > 0 : U32) && (block <= 12 : U32)), game, own, x, z, block, now)

def game_place(+game: Game, +id: U32, +x: U32, +z: U32, +block: U32, +now: U32) -> Action:
  game_place.at(game, game_slot(game, id, now), x, z, block, now)

# Whether a living mob is within sword reach (2) of a player.
def mob_reach(mob: Mob, +player: Player) -> Bool:
  Mob{slot, alive, mx, mz, hp} = mob
  nonzero(alive) && (player_distance(player, mx, mz) <= 2 : U32)

def mob_slot(mob: Mob) -> U32:
  Mob{slot, alive, x, z, hp} = mob
  slot

def game_attack_mob.ok(hit: Bool, +game: Game, +own: U32, +mob: Mob, +now: U32) -> Action:
  match hit:
    case False{}:
      game_error(game, "That raider is outside sword reach.")
    case True{}:
      game_ok(game_mob_set(game_player_set(game, own, player_touch(game_player(game, own), now)), mob_slot(mob), mob_hit(mob, 25)))

def game_attack_mob.go(+game: Game, +own: U32, +mob_slot: U32, +mob: Mob, +now: U32) -> Action:
  game_attack_mob.ok((mob_slot > 0 : U32) && ((mob_slot <= 4 : U32) && mob_reach(mob, game_player(game, own))), game, own, mob, now)

def game_attack_mob.at(+game: Game, slot: U32, +mob_slot: U32, +now: U32) -> Action:
  match slot:
    case 0:
      game_error(game, "Join the world before attacking.")
    case +own:
      game_attack_mob.go(game, own, mob_slot, game_mob(game, mob_slot), now)

def game_attack_mob(+game: Game, +id: U32, +mob_slot: U32, +now: U32) -> Action:
  game_attack_mob.at(game, game_slot(game, id, now), mob_slot, now)

def game_attack_player.ok(hit: Bool, +game: Game, +own: U32, +target_slot: U32, +now: U32) -> Action:
  match hit:
    case False{}:
      game_error(game, "That player is outside sword reach.")
    case True{}:
      touched = player_touch(game_player(game, own), now)
      damaged = player_hit(game_player(game, target_slot), 20)
      game_ok(game_player_set(game_player_set(game, target_slot, damaged), own, touched))

def game_attack_player.go(+game: Game, +own: U32, +target_slot: U32, +target: Player, +now: U32) -> Action:
  game_attack_player.ok((target_slot > 0 : U32) && ((target_slot <= 4 : U32) && (U32.is_ne(target_slot, own) && (player_active(target, now) && (player_distance(game_player(game, own), player_x(target), player_z(target)) <= 2 : U32)))), game, own, target_slot, now)

def game_attack_player.at(+game: Game, slot: U32, +target_slot: U32, +now: U32) -> Action:
  match slot:
    case 0:
      game_error(game, "Join the world before attacking.")
    case +own:
      game_attack_player.go(game, own, target_slot, game_player(game, target_slot), now)

def game_attack_player(+game: Game, +id: U32, +target_slot: U32, +now: U32) -> Action:
  game_attack_player.at(game, game_slot(game, id, now), target_slot, now)

def game_leave.at(+game: Game, slot: U32) -> Action:
  match slot:
    case 0:
      game_error(game, "This browser has not joined the world.")
    case +own:
      game_ok(game_player_set(game, own, player_empty(own)))

def game_leave(+game: Game, +id: U32, +now: U32) -> Action:
  game_leave.at(game, game_slot(game, id, now))

def game_full(game: Game, +now: U32) -> Bool:
  Game{world, one, two, three, four, m1, m2, m3, m4, tick} = game
  player_active(one, now) && (player_active(two, now) && (player_active(three, now) && player_active(four, now)))

# ---------------------------------------------------------------- JSON and routing

def game_json(+game: Game, +id: U32, +now: U32, ok: U32, note: String) -> String:
  Game{world, +one, +two, +three, +four, m1, m2, m3, m4, tick} = game
  String.concat([
    "{\"ok\":", U32.show(ok), ",\"note\":", HTTP.quoted(note),
    ",\"you\":", U32.show(game_slot(game, id, now)),
    ",\"full\":", U32.show(Bool.to_u32(game_full(game, now))),
    ",\"tick\":", U32.show(tick), ",\"size\":", U32.show(world_size()),
    ",\"renderDistance\":", U32.show(render_distance()),
    ",\"players\":[", player_json(one, now), ",", player_json(two, now), ",", player_json(three, now), ",", player_json(four, now), "],",
    "\"mobs\":[", mob_json(m1), ",", mob_json(m2), ",", mob_json(m3), ",", mob_json(m4), "],",
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
    r : Result<&1, &1, U32 & String, String> <- HTTP.read_text("Bend3/demos/cubeworld2_web/index.html")
    return (game, index.got(r))

def arg(xs: List<&2, String>, n: Nat) -> U32:
  Compat.to_u32(Maybe.default(&2, String, List.get(&2, String, xs, n), ""))

def has_args(xs: List<&2, String>, n: Nat) -> Bool:
  Nat.is_ge(List.length(&2, String, xs), n)

# One game route. `kind`: 1 state, 2 join, 3 move, 4 mine, 5 place,
# 6 attack-mob, 7 attack-player, 8 leave.
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
        case 6:
          action_routed(game_attack_mob(game, id, arg(args, 1n), now), id, now)
        case 7:
          action_routed(game_attack_player(game, id, arg(args, 1n), now), id, now)
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
  Bool.pick(U32, String.eq(name, "attack-mob"), 6,
  Bool.pick(U32, String.eq(name, "attack-player"), 7,
  Bool.pick(U32, String.eq(name, "leave"), 8, 0))))))))

def route_need(kind: U32) -> Nat:
  match kind:
    case 3:
      2n
    case 4:
      3n
    case 5:
      4n
    case 6:
      2n
    case 7:
      2n
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
# leading "cubeworld2" prefix).
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
      unprefix.pick(String.eq(name, "cubeworld2"), name, rest)

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
    IO.print("CubeWorld 2 listening on all interfaces (0.0.0.0:8086)\nopen http://<server-lan-ip>:8086")
    HTTP.serve(~Game, ~route, "0.0.0.0", 8086, init())
