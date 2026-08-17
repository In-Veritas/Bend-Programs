# Generated hub-private namespace from ../club_corvid_web/web_club_corvid.bend.
# Regenerate after changing the standalone source.

# Club Corvid: a small authoritative multiplayer social world.
#
# Bend owns player identity, rooms, positions, room chat, currency, inventory,
# equipped catalog items, and all four minigames.
# The browser is a renderer and input client only.
#
# POST /join       body: identity\nname
# POST /move       body: identity\ndirection (0 north, 1 east, 2 south, 3 west)
# POST /walk       body: identity\nx\ny (percentage coordinates)
# POST /room       body: identity\nroom (1..4)
# POST /chat       body: identity\nmessage
# POST /play       body: identity\ngame\naction
# POST /buy        body: identity\nitem
# POST /equip      body: identity\nitem (0 removes the equipped item)
# POST /leave      body: identity
# GET  /state/<identity>
#
# no-halt
# skip-native

import ../../../bend-base/Base
import ../../Compat
import ../../../bend-base/IO/TCP
import ../../../bend-base/IO/HTTP
import ../../../bend-base/JSON
import ../../Clock

def Corvid.player_timeout() -> U32: 30000
def Corvid.player_limit() -> U32: 12
def Corvid.chat_limit() -> U32: 24

type Corvid.Player:
  Player{id: U32, name: String, room: U32, x: U32, y: U32, seen: U32, game: U32, score: U32, aux: U32, coins: U32, owned: U32, equipped: U32}

type Corvid.Message:
  Message{id: U32, room: U32, author: String, text: String, at: U32}

type Corvid.Game:
  Game{players: List(Corvid.Player), messages: List(Corvid.Message), tick: U32, next_message: U32}

type Corvid.Action:
  Action{game: Corvid.Game, ok: U32, note: String}

type Corvid.Routed:
  Routed{game: Corvid.Game, response: HTTP.Response}

type Corvid.Found:
  Found{player: Corvid.Player}
  Missing{}

# ---------------------------------------------------------------- U32

def Corvid.u32_prev(value: U32, low: U32) -> U32:
  match value <= low:
    case 0:
      value - 3
    case k:
      low

def Corvid.u32_next(value: U32, ceiling: U32) -> U32:
  match (value + 3) >= ceiling:
    case 0:
      value + 3
    case k:
      ceiling

def Corvid.u32_room(room: U32) -> U32:
  match (room > 0) && (room <= 4):
    case 0:
      1
    case k:
      room

def Corvid.u32_clamp(value: U32, low: U32, high: U32) -> U32:
  match value < low:
    case 0:
      match value > high:
        case 0:
          value
        case k:
          high
    case k:
      low

def Corvid.u32_item_price(item: U32) -> U32:
  match item:
    case 1:
      120
    case 2:
      180
    case 3:
      160
    case 4:
      240
    case 5:
      140
    case 6:
      260
    case 7:
      300
    case 8:
      350
    case other:
      0

def Corvid.u32_item_room(item: U32) -> U32:
  match item:
    case 1:
      1
    case 2:
      1
    case 3:
      2
    case 4:
      2
    case 5:
      3
    case 6:
      3
    case 7:
      4
    case 8:
      4
    case other:
      0

def Corvid.u32_item_bit(item: U32) -> U32:
  1 << item

# ---------------------------------------------------------------- Player

def Corvid.player_active(player: Corvid.Player, now: U32) -> U32:
  match player:
    case Corvid.Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
      (now - seen) < Corvid.player_timeout()

def Corvid.player_touch(player: Corvid.Player, now: U32) -> Corvid.Player:
  match player:
    case Corvid.Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
      Corvid.Player.Player{id, name, room, x, y, now, game, score, aux, coins, owned, equipped}

def Corvid.player_move(player: Corvid.Player, direction: U32, now: U32) -> Corvid.Player:
  match player:
    case Corvid.Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
      match direction % 4:
        case 0:
          Corvid.Player.Player{id, name, room, x, Corvid.u32_prev(y, 14), now, 0, score, aux, coins, owned, equipped}
        case 1:
          Corvid.Player.Player{id, name, room, Corvid.u32_next(x, 88), y, now, 0, score, aux, coins, owned, equipped}
        case 2:
          Corvid.Player.Player{id, name, room, x, Corvid.u32_next(y, 76), now, 0, score, aux, coins, owned, equipped}
        case other:
          Corvid.Player.Player{id, name, room, Corvid.u32_prev(x, 12), y, now, 0, score, aux, coins, owned, equipped}

def Corvid.player_walk(player: Corvid.Player, x: U32, y: U32, now: U32) -> Corvid.Player:
  match player:
    case Corvid.Player.Player{id, name, room, old_x, old_y, seen, game, score, aux, coins, owned, equipped}:
      Corvid.Player.Player{id, name, room, Corvid.u32_clamp(x, 8, 92), Corvid.u32_clamp(y, 18, 80), now, 0, score, aux, coins, owned, equipped}

def Corvid.player_room(player: Corvid.Player, room: U32, now: U32) -> Corvid.Player:
  match player:
    case Corvid.Player.Player{id, name, old, x, y, seen, game, score, aux, coins, owned, equipped}:
      Corvid.Player.Player{id, name, Corvid.u32_room(room), 50, 48, now, 0, score, aux, coins, owned, equipped}

def Corvid.player_play(player: Corvid.Player, chosen: U32, action: U32, tick: U32, now: U32) -> Corvid.Player:
  match player:
    case Corvid.Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
      match chosen:
        case 1:
          match action:
            case 0:
              Corvid.Player.Player{id, name, room, x, y, now, 1, 0, 0, coins, owned, equipped}
            case k:
              match game == 1:
                case 0:
                  Corvid.Player.Player{id, name, room, x, y, now, game, score, aux, coins, owned, equipped}
                case j:
                  Corvid.Player.Player{id, name, room, x, y, now, 1, score + 1, (aux + 1) % 7, coins + 12, owned, equipped}
        case 2:
          match action:
            case 0:
              Corvid.Player.Player{id, name, room, x, y, now, 2, 0, (tick % 3) + 1, coins, owned, equipped}
            case guess:
              match game == 2:
                case 0:
                  Corvid.Player.Player{id, name, room, x, y, now, game, score, aux, coins, owned, equipped}
                case j:
                  match guess == aux:
                    case 0:
                      Corvid.Player.Player{id, name, room, x, y, now, 2, score, ((tick + guess) % 3) + 1, coins, owned, equipped}
                    case win:
                      Corvid.Player.Player{id, name, room, x, y, now, 2, score + 1, ((tick + guess) % 3) + 1, coins + 25, owned, equipped}
        case 3:
          match action:
            case 0:
              Corvid.Player.Player{id, name, room, x, y, now, 3, 0, tick % 11, coins, owned, equipped}
            case peck:
              match game == 3:
                case 0:
                  Corvid.Player.Player{id, name, room, x, y, now, game, score, aux, coins, owned, equipped}
                case active:
                  Corvid.Player.Player{id, name, room, x, y, now, 3, score + 1, (aux + (tick + peck)) % 11, coins + 8, owned, equipped}
        case 4:
          match action:
            case 0:
              Corvid.Player.Player{id, name, room, x, y, now, 4, 0, tick % 4, coins, owned, equipped}
            case phrase:
              match game == 4:
                case 0:
                  Corvid.Player.Player{id, name, room, x, y, now, game, score, aux, coins, owned, equipped}
                case active:
                  Corvid.Player.Player{id, name, room, x, y, now, 4, score + 1, (aux + (tick + phrase)) % 4, coins + 18, owned, equipped}
        case other:
          Corvid.Player.Player{id, name, room, x, y, now, 0, score, aux, coins, owned, equipped}

def Corvid.player_buy(player: Corvid.Player, item: U32, price: U32, now: U32) -> Corvid.Player:
  match player:
    case Corvid.Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
      Corvid.Player.Player{id, name, room, x, y, now, game, score, aux, coins - price, owned .|. Corvid.u32_item_bit(item), equipped}

def Corvid.player_equip(player: Corvid.Player, item: U32, now: U32) -> Corvid.Player:
  match player:
    case Corvid.Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
      Corvid.Player.Player{id, name, room, x, y, now, game, score, aux, coins, owned, item}

def Corvid.player_json(player: Corvid.Player, now: U32) -> String:
  match player:
    case Corvid.Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
      String.flatten([
        "{\"id\":", String.from_u32(id),
        ",\"name\":", JSON.quoted(name, ""),
        ",\"room\":", String.from_u32(room),
        ",\"x\":", String.from_u32(x),
        ",\"y\":", String.from_u32(y),
        ",\"online\":", String.from_u32(Corvid.player_active(Corvid.Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}, now)),
        ",\"game\":", String.from_u32(game),
        ",\"score\":", String.from_u32(score),
        ",\"coins\":", String.from_u32(coins),
        ",\"owned\":", String.from_u32(owned),
        ",\"equipped\":", String.from_u32(equipped), "}"
      ])

# ---------------------------------------------------------------- Message

def Corvid.message_json(message: Corvid.Message) -> String:
  match message:
    case Corvid.Message.Message{id, room, author, text, at}:
      String.flatten([
        "{\"id\":", String.from_u32(id),
        ",\"room\":", String.from_u32(room),
        ",\"author\":", JSON.quoted(author, ""),
        ",\"text\":", JSON.quoted(text, ""),
        ",\"at\":", String.from_u32(at), "}"
      ])

# ---------------------------------------------------------------- List

def Corvid.list_player_find(players: List(Corvid.Player), id: U32) -> Corvid.Found:
  match players:
    case List.Cons{head, tail}:
      match head:
        case Corvid.Player.Player{stored, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
          match (id > 0) && (stored == id):
            case 0:
              Corvid.list_player_find(tail, id)
            case k:
              Corvid.Found.Found{Corvid.Player.Player{stored, name, room, x, y, seen, game, score, aux, coins, owned, equipped}}
    case List.Nil{}:
      Corvid.Found.Missing{}

def Corvid.list_player_set(players: List(Corvid.Player), player: Corvid.Player) -> List(Corvid.Player):
  match players:
    case List.Cons{head, tail}:
      match head:
        case Corvid.Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
          match player:
            case Corvid.Player.Player{target, tname, troom, tx, ty, tseen, tgame, tscore, taux, tcoins, towned, tequipped}:
              match id == target:
                case 0:
                  List.Cons{Corvid.Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}, Corvid.list_player_set(tail, Corvid.Player.Player{target, tname, troom, tx, ty, tseen, tgame, tscore, taux, tcoins, towned, tequipped})}
                case k:
                  List.Cons{Corvid.Player.Player{target, tname, troom, tx, ty, tseen, tgame, tscore, taux, tcoins, towned, tequipped}, tail}
    case List.Nil{}:
      List.Nil{}

def Corvid.list_player_remove(players: List(Corvid.Player), id: U32) -> List(Corvid.Player):
  match players:
    case List.Cons{head, tail}:
      match head:
        case Corvid.Player.Player{stored, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
          match stored == id:
            case 0:
              List.Cons{Corvid.Player.Player{stored, name, room, x, y, seen, game, score, aux, coins, owned, equipped}, Corvid.list_player_remove(tail, id)}
            case k:
              tail
    case List.Nil{}:
      List.Nil{}

def Corvid.list_player_active(players: List(Corvid.Player), now: U32) -> U32:
  match players:
    case List.Cons{head, tail}:
      Corvid.player_active(head, now) + Corvid.list_player_active(tail, now)
    case List.Nil{}:
      0

def Corvid.list_player_json(players: List(Corvid.Player), now: U32, first: U32) -> String:
  match players:
    case List.Cons{head, tail}:
      match Corvid.player_active(head, now):
        case 0:
          Corvid.list_player_json(tail, now, first)
        case k:
          match first:
            case 0:
              String.concat(",", String.concat(Corvid.player_json(head, now), Corvid.list_player_json(tail, now, 0)))
            case j:
              String.concat(Corvid.player_json(head, now), Corvid.list_player_json(tail, now, 0))
    case List.Nil{}:
      "]"

def Corvid.list_message_json(messages: List(Corvid.Message), room: U32, first: U32) -> String:
  match messages:
    case List.Cons{head, tail}:
      match head:
        case Corvid.Message.Message{id, stored, author, text, at}:
          match stored == room:
            case 0:
              Corvid.list_message_json(tail, room, first)
            case k:
              match first:
                case 0:
                  String.concat(",", String.concat(Corvid.message_json(Corvid.Message.Message{id, stored, author, text, at}), Corvid.list_message_json(tail, room, 0)))
                case j:
                  String.concat(Corvid.message_json(Corvid.Message.Message{id, stored, author, text, at}), Corvid.list_message_json(tail, room, 0))
    case List.Nil{}:
      "]"

# ---------------------------------------------------------------- Game

def Corvid.game_empty() -> Corvid.Game:
  Corvid.Game.Game{List.Nil{}, List.Nil{}, 1, 1}

def Corvid.game_ok(game: Corvid.Game, note: String) -> Corvid.Action:
  Corvid.Action.Action{game, 1, note}

def Corvid.game_error(game: Corvid.Game, note: String) -> Corvid.Action:
  Corvid.Action.Action{game, 0, note}

def Corvid.game_touch(game: Corvid.Game, id: U32, now: U32) -> Corvid.Game:
  match game:
    case Corvid.Game.Game{players, messages, tick, next_message}:
      match Corvid.list_player_find(players, id):
        case Corvid.Found.Found{player}:
          Corvid.Game.Game{Corvid.list_player_set(players, Corvid.player_touch(player, now)), messages, tick + 1, next_message}
        case Corvid.Found.Missing{}:
          Corvid.Game.Game{players, messages, tick, next_message}

def Corvid.game_join(game: Corvid.Game, id: U32, name: String, now: U32) -> Corvid.Action:
  match game:
    case Corvid.Game.Game{players, messages, tick, next_message}:
      match Corvid.list_player_find(players, id):
        case Corvid.Found.Found{player}:
          Corvid.game_ok(Corvid.Game.Game{Corvid.list_player_set(players, Corvid.player_touch(player, now)), messages, tick + 1, next_message}, "Welcome back to the flock.")
        case Corvid.Found.Missing{}:
          match (id > 0) && ((String.length(name) >= 2) && ((String.length(name) <= 18) && (Corvid.list_player_active(players, now) < Corvid.player_limit()))):
            case 0:
              Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "Choose a name from 2 to 18 characters; the rookery holds twelve birds.")
            case k:
              bird : Corvid.Player = Corvid.Player.Player{id, name, 1, 50, 48, now, 0, 0, 0, 500, 0, 0}
              Corvid.game_ok(Corvid.Game.Game{List.Cons{bird, players}, messages, tick + 1, next_message}, "Welcome to Club Corvid!")

def Corvid.game_move(game: Corvid.Game, id: U32, direction: U32, now: U32) -> Corvid.Action:
  match game:
    case Corvid.Game.Game{players, messages, tick, next_message}:
      match Corvid.list_player_find(players, id):
        case Corvid.Found.Found{player}:
          Corvid.game_ok(Corvid.Game.Game{Corvid.list_player_set(players, Corvid.player_move(player, direction, now)), messages, tick + 1, next_message}, "")
        case Corvid.Found.Missing{}:
          Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "Join the club before waddling.")

def Corvid.game_walk(game: Corvid.Game, id: U32, x: U32, y: U32, now: U32) -> Corvid.Action:
  match game:
    case Corvid.Game.Game{players, messages, tick, next_message}:
      match Corvid.list_player_find(players, id):
        case Corvid.Found.Found{player}:
          Corvid.game_ok(Corvid.Game.Game{Corvid.list_player_set(players, Corvid.player_walk(player, x, y, now)), messages, tick + 1, next_message}, "")
        case Corvid.Found.Missing{}:
          Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "Join the club before waddling.")

def Corvid.game_room(game: Corvid.Game, id: U32, room: U32, now: U32) -> Corvid.Action:
  match game:
    case Corvid.Game.Game{players, messages, tick, next_message}:
      match Corvid.list_player_find(players, id):
        case Corvid.Found.Found{player}:
          Corvid.game_ok(Corvid.Game.Game{Corvid.list_player_set(players, Corvid.player_room(player, room, now)), messages, tick + 1, next_message}, "You travelled to a new perch.")
        case Corvid.Found.Missing{}:
          Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "Join the club before travelling.")

def Corvid.game_chat(game: Corvid.Game, id: U32, text: String, now: U32) -> Corvid.Action:
  match game:
    case Corvid.Game.Game{players, messages, tick, next_message}:
      match Corvid.list_player_find(players, id):
        case Corvid.Found.Found{player}:
          match player:
            case Corvid.Player.Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped}:
              match (String.length(text) > 0) && (String.length(text) <= 120):
                case 0:
                  Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "Messages are limited to 120 characters.")
                case k:
                  bird = Corvid.player_touch(Corvid.Player.Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped}, now)
                  line : Corvid.Message = Corvid.Message.Message{next_message, room, name, text, now}
                  Corvid.game_ok(Corvid.Game.Game{Corvid.list_player_set(players, bird), List.take(Corvid.Message, Corvid.chat_limit(), List.Cons{line, messages}), tick + 1, next_message + 1}, "Corvid.Message sent to this room.")
        case Corvid.Found.Missing{}:
          Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "Join the club before chatting.")

def Corvid.game_play(game: Corvid.Game, id: U32, minigame: U32, action: U32, now: U32) -> Corvid.Action:
  match game:
    case Corvid.Game.Game{players, messages, tick, next_message}:
      match Corvid.list_player_find(players, id):
        case Corvid.Found.Found{player}:
          match player:
            case Corvid.Player.Player{stored, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
              match room == 4:
                case 0:
                  Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "Visit the Acorn Arcade before using a cabinet.")
                case arcade:
                  match (minigame > 0) && (minigame <= 4):
                    case 0:
                      Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "That cabinet is closed.")
                    case k:
                      played = Corvid.player_play(Corvid.Player.Player{stored, name, room, x, y, seen, game, score, aux, coins, owned, equipped}, minigame, action, tick, now)
                      Corvid.game_ok(Corvid.Game.Game{Corvid.list_player_set(players, played), messages, tick + 1, next_message}, "Minigame state updated.")
        case Corvid.Found.Missing{}:
          Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "Join the club before playing.")

def Corvid.game_buy(game: Corvid.Game, id: U32, item: U32, now: U32) -> Corvid.Action:
  match game:
    case Corvid.Game.Game{players, messages, tick, next_message}:
      match Corvid.list_player_find(players, id):
        case Corvid.Found.Found{player}:
          match player:
            case Corvid.Player.Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped}:
              price = Corvid.u32_item_price(item)
              bit = Corvid.u32_item_bit(item)
              match price > 0:
                case 0:
                  Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "That catalog item does not exist.")
                case valid:
                  match room == Corvid.u32_item_room(item):
                    case 0:
                      Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "Visit the item's room catalog before buying it.")
                    case local:
                      match (owned .&. bit) > 0:
                        case 0:
                          match coins >= price:
                            case 0:
                              Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "You need more coins for that item.")
                            case enough:
                              bird = Corvid.player_buy(Corvid.Player.Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped}, item, price, now)
                              Corvid.game_ok(Corvid.Game.Game{Corvid.list_player_set(players, bird), messages, tick + 1, next_message}, "Item added to your collection.")
                        case already:
                          Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "You already own that item.")
        case Corvid.Found.Missing{}:
          Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "Join the club before shopping.")

def Corvid.game_equip(game: Corvid.Game, id: U32, item: U32, now: U32) -> Corvid.Action:
  match game:
    case Corvid.Game.Game{players, messages, tick, next_message}:
      match Corvid.list_player_find(players, id):
        case Corvid.Found.Found{player}:
          match player:
            case Corvid.Player.Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped}:
              match item == 0:
                case 0:
                  match (Corvid.u32_item_price(item) > 0) && ((owned .&. Corvid.u32_item_bit(item)) > 0):
                    case 0:
                      Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "Buy that item before wearing it.")
                    case available:
                      bird = Corvid.player_equip(Corvid.Player.Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped}, item, now)
                      Corvid.game_ok(Corvid.Game.Game{Corvid.list_player_set(players, bird), messages, tick + 1, next_message}, "Your outfit has been updated.")
                case remove:
                  bird = Corvid.player_equip(Corvid.Player.Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped}, 0, now)
                  Corvid.game_ok(Corvid.Game.Game{Corvid.list_player_set(players, bird), messages, tick + 1, next_message}, "Your catalog item has been removed.")
        case Corvid.Found.Missing{}:
          Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "Join the club before changing outfits.")

def Corvid.game_leave(game: Corvid.Game, id: U32) -> Corvid.Action:
  match game:
    case Corvid.Game.Game{players, messages, tick, next_message}:
      match Corvid.list_player_find(players, id):
        case Corvid.Found.Found{player}:
          Corvid.game_ok(Corvid.Game.Game{Corvid.list_player_remove(players, id), messages, tick + 1, next_message}, "See you next migration.")
        case Corvid.Found.Missing{}:
          Corvid.game_error(Corvid.Game.Game{players, messages, tick, next_message}, "This bird is not in the club.")

def Corvid.game_json(game: Corvid.Game, id: U32, now: U32, ok: U32, note: String) -> String:
  match game:
    case Corvid.Game.Game{players, messages, tick, next_message}:
      match Corvid.list_player_find(players, id):
        case Corvid.Found.Found{player}:
          match player:
            case Corvid.Player.Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped}:
              String.flatten([
                "{\"ok\":", String.from_u32(ok), ",\"note\":", JSON.quoted(note, ""),
                ",\"you\":", String.from_u32(stored), ",\"room\":", String.from_u32(room),
                ",\"tick\":", String.from_u32(tick), ",\"players\":[", Corvid.list_player_json(players, now, 1),
                ",\"messages\":[", Corvid.list_message_json(messages, room, 1), "}"
              ])
        case Corvid.Found.Missing{}:
          String.flatten([
            "{\"ok\":", String.from_u32(ok), ",\"note\":", JSON.quoted(note, ""),
            ",\"you\":0,\"room\":1,\"tick\":", String.from_u32(tick),
            ",\"players\":[", Corvid.list_player_json(players, now, 1), ",\"messages\":[]}"
          ])

# ---------------------------------------------------------------- HTTP

def Corvid.action_response(action: Corvid.Action, id: U32, now: U32) -> Corvid.Routed:
  match action:
    case Corvid.Action.Action{game, ok, note}:
      Corvid.Routed.Routed{game, HTTP.Response.Response{200,
        [HTTP.Header.Header{"Content-Type", "application/json; charset=utf-8"}, HTTP.Header.Header{"Cache-Control", "no-store, no-cache, must-revalidate"}],
        Bytes.from_string(Corvid.game_json(game, id, now, ok, note))}}

def Corvid.game_state_response(game: Corvid.Game, id: U32, now: U32) -> Corvid.Routed:
  touched = Corvid.game_touch(game, id, now)
  Corvid.Routed.Routed{touched, HTTP.reply(200, "application/json; charset=utf-8", Corvid.game_json(touched, id, now, 1, ""))}

def Corvid.game_missing(game: Corvid.Game) -> Corvid.Routed:
  Corvid.Routed.Routed{game, HTTP.not_found()}

def Corvid.result_index(result: Result((U32 & String), String), game: Corvid.Game) -> IO(Corvid.Routed):
  match result:
    case Result.Done{html}:
      IO.pure(Corvid.Routed, Corvid.Routed.Routed{game, HTTP.reply(200, "text/html; charset=utf-8", html)})
    case Result.Fail{(code, error)}:
      IO.pure(Corvid.Routed, Corvid.Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run from the repository root\n")})

def Corvid.game_index(game: Corvid.Game) -> IO(Corvid.Routed):
  do IO(Corvid.Routed):
    result <- IO.read_text("gabriel_demos/club_corvid_web/index.html")
    Corvid.result_index(result, game)

def Corvid.bytes_parts(body: Bytes) -> List(String):
  String.split(Char.Char{10}, Bytes.to_string(body))

def Corvid.list_part(parts: List(String), index: U32) -> String:
  List.head(String, "", List.drop(String, index, parts))

def Corvid.string_action(name: String, request: HTTP.Request, game: Corvid.Game, now: U32) -> IO(Corvid.Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      parts = Corvid.bytes_parts(body)
      id = String.to_u32(Corvid.list_part(parts, 0))
      match String.eq_u32(name, "join"):
        case 0:
          match String.eq_u32(name, "move"):
            case 0:
              match String.eq_u32(name, "walk"):
                case 0:
                  match String.eq_u32(name, "room"):
                    case 0:
                      match String.eq_u32(name, "chat"):
                        case 0:
                          match String.eq_u32(name, "play"):
                            case 0:
                              match String.eq_u32(name, "buy"):
                                case 0:
                                  match String.eq_u32(name, "equip"):
                                    case 0:
                                      match String.eq_u32(name, "leave"):
                                        case 0:
                                          IO.pure(Corvid.Routed, Corvid.game_missing(game))
                                        case k9:
                                          IO.pure(Corvid.Routed, Corvid.action_response(Corvid.game_leave(game, id), id, now))
                                    case k8:
                                      IO.pure(Corvid.Routed, Corvid.action_response(Corvid.game_equip(game, id, String.to_u32(Corvid.list_part(parts, 1)), now), id, now))
                                case k7:
                                  IO.pure(Corvid.Routed, Corvid.action_response(Corvid.game_buy(game, id, String.to_u32(Corvid.list_part(parts, 1)), now), id, now))
                            case k6:
                              IO.pure(Corvid.Routed, Corvid.action_response(Corvid.game_play(game, id, String.to_u32(Corvid.list_part(parts, 1)), String.to_u32(Corvid.list_part(parts, 2)), now), id, now))
                        case k5:
                          IO.pure(Corvid.Routed, Corvid.action_response(Corvid.game_chat(game, id, Corvid.list_part(parts, 1), now), id, now))
                    case k4:
                      IO.pure(Corvid.Routed, Corvid.action_response(Corvid.game_room(game, id, String.to_u32(Corvid.list_part(parts, 1)), now), id, now))
                case k3:
                  IO.pure(Corvid.Routed, Corvid.action_response(Corvid.game_walk(game, id, String.to_u32(Corvid.list_part(parts, 1)), String.to_u32(Corvid.list_part(parts, 2)), now), id, now))
            case k2:
              IO.pure(Corvid.Routed, Corvid.action_response(Corvid.game_move(game, id, String.to_u32(Corvid.list_part(parts, 1)), now), id, now))
        case k1:
          IO.pure(Corvid.Routed, Corvid.action_response(Corvid.game_join(game, id, Corvid.list_part(parts, 1), now), id, now))

def Corvid.list_route(parts: List(String), request: HTTP.Request, game: Corvid.Game, now: U32) -> IO(Corvid.Routed):
  match parts:
    case List.Cons{root, List.Cons{"state", List.Cons{id, rest}}}:
      IO.pure(Corvid.Routed, Corvid.game_state_response(game, String.to_u32(id), now))
    case List.Cons{root, List.Cons{"", rest}}:
      Corvid.game_index(game)
    case List.Cons{root, List.Cons{name, rest}}:
      Corvid.string_action(name, request, game, now)
    case List.Cons{root, List.Nil{}}:
      Corvid.game_index(game)
    case List.Nil{}:
      Corvid.game_index(game)

def Corvid.request_route(request: HTTP.Request, game: Corvid.Game, now: U32) -> IO(Corvid.Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(method, "GET"):
        case 0:
          match String.eq_u32(method, "POST"):
            case 0:
              IO.pure(Corvid.Routed, Corvid.Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")})
            case post:
              Corvid.list_route(String.split('/', path), HTTP.Request.Request{method, path, headers, body}, game, now)
        case get:
          Corvid.list_route(String.split('/', path), HTTP.Request.Request{method, path, headers, body}, game, now)

# ---------------------------------------------------------------- Server

def Corvid.routed_send(routed: Corvid.Routed, server: TCP, conn: HTTP) -> IO(U32):
  match routed:
    case Corvid.Routed.Routed{game, response}:
      do IO(U32):
        sent <- HTTP.send_response(conn, HTTP.with_connection(0, response))
        closed <- HTTP.close(conn)
        Corvid.u32_serve(server, game)

def Corvid.inbound_serve(inbound: HTTP.Inbound, server: TCP, conn: HTTP, game: Corvid.Game) -> IO(U32):
  match inbound:
    case HTTP.Inbound.Got{http11, request, rest}:
      do IO(U32):
        now <- clock_now_ms()
        routed <- Corvid.request_route(request, game, now)
        Corvid.routed_send(routed, server, conn)
    case HTTP.Inbound.Closed{}:
      do IO(U32):
        closed <- HTTP.close(conn)
        Corvid.u32_serve(server, game)
    case HTTP.Inbound.Bad{code, error}:
      Corvid.routed_send(Corvid.Routed.Routed{game, HTTP.reply_error(code, error)}, server, conn)

def Corvid.result_accept(result: Result((U32 & String), TCP), server: TCP, game: Corvid.Game) -> IO(U32):
  match result:
    case Result.Done{fd}:
      do IO(U32):
        inbound <- HTTP.recv_request(HTTP.Plain{fd}, List.Nil{})
        Corvid.inbound_serve(inbound, server, HTTP.Plain{fd}, game)
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["accept failed: ", error, "\n"]))
        return 1

def Corvid.u32_serve(server: TCP, game: Corvid.Game) -> IO(U32):
  do IO(U32):
    result <- TCP.accept(server)
    Corvid.result_accept(result, server, game)

def Corvid.result_main(result: Result((U32 & String), TCP)) -> IO(U32):
  match result:
    case Result.Done{server}:
      do IO(U32):
        printed <- IO.write("Club Corvid listening on all interfaces (0.0.0.0:8087)\nopen http://<server-lan-ip>:8087\n")
        Corvid.u32_serve(server, Corvid.game_empty())
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def Corvid.main() -> IO(U32):
  do IO(U32):
    result <- TCP.listen(8087)
    Corvid.result_main(result)
