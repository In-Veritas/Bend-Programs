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

import ../../bend-base/Base
import ../Compat
import ../../bend-base/IO/TCP
import ../../bend-base/IO/HTTP
import ../../bend-base/JSON
import ../Clock as Clock

def player_timeout() -> U32: 30000
def player_limit() -> U32: 12
def chat_limit() -> U32: 24

type Player:
  Player{id: U32, name: String, room: U32, x: U32, y: U32, seen: U32, game: U32, score: U32, aux: U32, coins: U32, owned: U32, equipped: U32}

type Message:
  Message{id: U32, room: U32, author: String, text: String, at: U32}

type Game:
  Game{players: List(Player), messages: List(Message), tick: U32, next_message: U32}

type Action:
  Action{game: Game, ok: U32, note: String}

type Routed:
  Routed{game: Game, response: HTTP.Response}

type Found:
  Found{player: Player}
  Missing{}

# ---------------------------------------------------------------- U32

def u32_prev(value: U32, low: U32) -> U32:
  match value <= low:
    case 0:
      value - 3
    case k:
      low

def u32_next(value: U32, ceiling: U32) -> U32:
  match (value + 3) >= ceiling:
    case 0:
      value + 3
    case k:
      ceiling

def u32_room(room: U32) -> U32:
  match (room > 0) && (room <= 4):
    case 0:
      1
    case k:
      room

def u32_clamp(value: U32, low: U32, high: U32) -> U32:
  match value < low:
    case 0:
      match value > high:
        case 0:
          value
        case k:
          high
    case k:
      low

def u32_item_price(item: U32) -> U32:
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

def u32_item_room(item: U32) -> U32:
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

def u32_item_bit(item: U32) -> U32:
  1 << item

# ---------------------------------------------------------------- Player

def player_active(player: Player, now: U32) -> U32:
  match player:
    case Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
      (now - seen) < player_timeout()

def player_touch(player: Player, now: U32) -> Player:
  match player:
    case Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
      Player.Player{id, name, room, x, y, now, game, score, aux, coins, owned, equipped}

def player_move(player: Player, direction: U32, now: U32) -> Player:
  match player:
    case Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
      match direction % 4:
        case 0:
          Player.Player{id, name, room, x, u32_prev(y, 14), now, 0, score, aux, coins, owned, equipped}
        case 1:
          Player.Player{id, name, room, u32_next(x, 88), y, now, 0, score, aux, coins, owned, equipped}
        case 2:
          Player.Player{id, name, room, x, u32_next(y, 76), now, 0, score, aux, coins, owned, equipped}
        case other:
          Player.Player{id, name, room, u32_prev(x, 12), y, now, 0, score, aux, coins, owned, equipped}

def player_walk(player: Player, x: U32, y: U32, now: U32) -> Player:
  match player:
    case Player.Player{id, name, room, old_x, old_y, seen, game, score, aux, coins, owned, equipped}:
      Player.Player{id, name, room, u32_clamp(x, 8, 92), u32_clamp(y, 18, 80), now, 0, score, aux, coins, owned, equipped}

def player_room(player: Player, room: U32, now: U32) -> Player:
  match player:
    case Player.Player{id, name, old, x, y, seen, game, score, aux, coins, owned, equipped}:
      Player.Player{id, name, u32_room(room), 50, 48, now, 0, score, aux, coins, owned, equipped}

def player_play(player: Player, chosen: U32, action: U32, tick: U32, now: U32) -> Player:
  match player:
    case Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
      match chosen:
        case 1:
          match action:
            case 0:
              Player.Player{id, name, room, x, y, now, 1, 0, 0, coins, owned, equipped}
            case k:
              match game == 1:
                case 0:
                  Player.Player{id, name, room, x, y, now, game, score, aux, coins, owned, equipped}
                case j:
                  Player.Player{id, name, room, x, y, now, 1, score + 1, (aux + 1) % 7, coins + 12, owned, equipped}
        case 2:
          match action:
            case 0:
              Player.Player{id, name, room, x, y, now, 2, 0, (tick % 3) + 1, coins, owned, equipped}
            case guess:
              match game == 2:
                case 0:
                  Player.Player{id, name, room, x, y, now, game, score, aux, coins, owned, equipped}
                case j:
                  match guess == aux:
                    case 0:
                      Player.Player{id, name, room, x, y, now, 2, score, ((tick + guess) % 3) + 1, coins, owned, equipped}
                    case win:
                      Player.Player{id, name, room, x, y, now, 2, score + 1, ((tick + guess) % 3) + 1, coins + 25, owned, equipped}
        case 3:
          match action:
            case 0:
              Player.Player{id, name, room, x, y, now, 3, 0, tick % 11, coins, owned, equipped}
            case peck:
              match game == 3:
                case 0:
                  Player.Player{id, name, room, x, y, now, game, score, aux, coins, owned, equipped}
                case active:
                  Player.Player{id, name, room, x, y, now, 3, score + 1, (aux + (tick + peck)) % 11, coins + 8, owned, equipped}
        case 4:
          match action:
            case 0:
              Player.Player{id, name, room, x, y, now, 4, 0, tick % 4, coins, owned, equipped}
            case phrase:
              match game == 4:
                case 0:
                  Player.Player{id, name, room, x, y, now, game, score, aux, coins, owned, equipped}
                case active:
                  Player.Player{id, name, room, x, y, now, 4, score + 1, (aux + (tick + phrase)) % 4, coins + 18, owned, equipped}
        case other:
          Player.Player{id, name, room, x, y, now, 0, score, aux, coins, owned, equipped}

def player_buy(player: Player, item: U32, price: U32, now: U32) -> Player:
  match player:
    case Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
      Player.Player{id, name, room, x, y, now, game, score, aux, coins - price, owned .|. u32_item_bit(item), equipped}

def player_equip(player: Player, item: U32, now: U32) -> Player:
  match player:
    case Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
      Player.Player{id, name, room, x, y, now, game, score, aux, coins, owned, item}

def player_json(player: Player, now: U32) -> String:
  match player:
    case Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
      String.flatten([
        "{\"id\":", String.from_u32(id),
        ",\"name\":", JSON.quoted(name, ""),
        ",\"room\":", String.from_u32(room),
        ",\"x\":", String.from_u32(x),
        ",\"y\":", String.from_u32(y),
        ",\"online\":", String.from_u32(player_active(Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}, now)),
        ",\"game\":", String.from_u32(game),
        ",\"score\":", String.from_u32(score),
        ",\"coins\":", String.from_u32(coins),
        ",\"owned\":", String.from_u32(owned),
        ",\"equipped\":", String.from_u32(equipped), "}"
      ])

# ---------------------------------------------------------------- Message

def message_json(message: Message) -> String:
  match message:
    case Message.Message{id, room, author, text, at}:
      String.flatten([
        "{\"id\":", String.from_u32(id),
        ",\"room\":", String.from_u32(room),
        ",\"author\":", JSON.quoted(author, ""),
        ",\"text\":", JSON.quoted(text, ""),
        ",\"at\":", String.from_u32(at), "}"
      ])

# ---------------------------------------------------------------- List

def list_player_find(players: List(Player), id: U32) -> Found:
  match players:
    case List.Cons{head, tail}:
      match head:
        case Player.Player{stored, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
          match (id > 0) && (stored == id):
            case 0:
              list_player_find(tail, id)
            case k:
              Found.Found{Player.Player{stored, name, room, x, y, seen, game, score, aux, coins, owned, equipped}}
    case List.Nil{}:
      Found.Missing{}

def list_player_set(players: List(Player), player: Player) -> List(Player):
  match players:
    case List.Cons{head, tail}:
      match head:
        case Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
          match player:
            case Player.Player{target, tname, troom, tx, ty, tseen, tgame, tscore, taux, tcoins, towned, tequipped}:
              match id == target:
                case 0:
                  List.Cons{Player.Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped}, list_player_set(tail, Player.Player{target, tname, troom, tx, ty, tseen, tgame, tscore, taux, tcoins, towned, tequipped})}
                case k:
                  List.Cons{Player.Player{target, tname, troom, tx, ty, tseen, tgame, tscore, taux, tcoins, towned, tequipped}, tail}
    case List.Nil{}:
      List.Nil{}

def list_player_remove(players: List(Player), id: U32) -> List(Player):
  match players:
    case List.Cons{head, tail}:
      match head:
        case Player.Player{stored, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
          match stored == id:
            case 0:
              List.Cons{Player.Player{stored, name, room, x, y, seen, game, score, aux, coins, owned, equipped}, list_player_remove(tail, id)}
            case k:
              tail
    case List.Nil{}:
      List.Nil{}

def list_player_active(players: List(Player), now: U32) -> U32:
  match players:
    case List.Cons{head, tail}:
      player_active(head, now) + list_player_active(tail, now)
    case List.Nil{}:
      0

def list_player_json(players: List(Player), now: U32, first: U32) -> String:
  match players:
    case List.Cons{head, tail}:
      match player_active(head, now):
        case 0:
          list_player_json(tail, now, first)
        case k:
          match first:
            case 0:
              String.concat(",", String.concat(player_json(head, now), list_player_json(tail, now, 0)))
            case j:
              String.concat(player_json(head, now), list_player_json(tail, now, 0))
    case List.Nil{}:
      "]"

def list_message_json(messages: List(Message), room: U32, first: U32) -> String:
  match messages:
    case List.Cons{head, tail}:
      match head:
        case Message.Message{id, stored, author, text, at}:
          match stored == room:
            case 0:
              list_message_json(tail, room, first)
            case k:
              match first:
                case 0:
                  String.concat(",", String.concat(message_json(Message.Message{id, stored, author, text, at}), list_message_json(tail, room, 0)))
                case j:
                  String.concat(message_json(Message.Message{id, stored, author, text, at}), list_message_json(tail, room, 0))
    case List.Nil{}:
      "]"

# ---------------------------------------------------------------- Game

def game_empty() -> Game:
  Game.Game{List.Nil{}, List.Nil{}, 1, 1}

def game_ok(game: Game, note: String) -> Action:
  Action.Action{game, 1, note}

def game_error(game: Game, note: String) -> Action:
  Action.Action{game, 0, note}

def game_touch(game: Game, id: U32, now: U32) -> Game:
  match game:
    case Game.Game{players, messages, tick, next_message}:
      match list_player_find(players, id):
        case Found.Found{player}:
          Game.Game{list_player_set(players, player_touch(player, now)), messages, tick + 1, next_message}
        case Found.Missing{}:
          Game.Game{players, messages, tick, next_message}

def game_join(game: Game, id: U32, name: String, now: U32) -> Action:
  match game:
    case Game.Game{players, messages, tick, next_message}:
      match list_player_find(players, id):
        case Found.Found{player}:
          game_ok(Game.Game{list_player_set(players, player_touch(player, now)), messages, tick + 1, next_message}, "Welcome back to the flock.")
        case Found.Missing{}:
          match (id > 0) && ((String.length(name) >= 2) && ((String.length(name) <= 18) && (list_player_active(players, now) < player_limit()))):
            case 0:
              game_error(Game.Game{players, messages, tick, next_message}, "Choose a name from 2 to 18 characters; the rookery holds twelve birds.")
            case k:
              bird : Player = Player.Player{id, name, 1, 50, 48, now, 0, 0, 0, 500, 0, 0}
              game_ok(Game.Game{List.Cons{bird, players}, messages, tick + 1, next_message}, "Welcome to Club Corvid!")

def game_move(game: Game, id: U32, direction: U32, now: U32) -> Action:
  match game:
    case Game.Game{players, messages, tick, next_message}:
      match list_player_find(players, id):
        case Found.Found{player}:
          game_ok(Game.Game{list_player_set(players, player_move(player, direction, now)), messages, tick + 1, next_message}, "")
        case Found.Missing{}:
          game_error(Game.Game{players, messages, tick, next_message}, "Join the club before waddling.")

def game_walk(game: Game, id: U32, x: U32, y: U32, now: U32) -> Action:
  match game:
    case Game.Game{players, messages, tick, next_message}:
      match list_player_find(players, id):
        case Found.Found{player}:
          game_ok(Game.Game{list_player_set(players, player_walk(player, x, y, now)), messages, tick + 1, next_message}, "")
        case Found.Missing{}:
          game_error(Game.Game{players, messages, tick, next_message}, "Join the club before waddling.")

def game_room(game: Game, id: U32, room: U32, now: U32) -> Action:
  match game:
    case Game.Game{players, messages, tick, next_message}:
      match list_player_find(players, id):
        case Found.Found{player}:
          game_ok(Game.Game{list_player_set(players, player_room(player, room, now)), messages, tick + 1, next_message}, "You travelled to a new perch.")
        case Found.Missing{}:
          game_error(Game.Game{players, messages, tick, next_message}, "Join the club before travelling.")

def game_chat(game: Game, id: U32, text: String, now: U32) -> Action:
  match game:
    case Game.Game{players, messages, tick, next_message}:
      match list_player_find(players, id):
        case Found.Found{player}:
          match player:
            case Player.Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped}:
              match (String.length(text) > 0) && (String.length(text) <= 120):
                case 0:
                  game_error(Game.Game{players, messages, tick, next_message}, "Messages are limited to 120 characters.")
                case k:
                  bird = player_touch(Player.Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped}, now)
                  line : Message = Message.Message{next_message, room, name, text, now}
                  game_ok(Game.Game{list_player_set(players, bird), List.take(Message, chat_limit(), List.Cons{line, messages}), tick + 1, next_message + 1}, "Message sent to this room.")
        case Found.Missing{}:
          game_error(Game.Game{players, messages, tick, next_message}, "Join the club before chatting.")

def game_play(game: Game, id: U32, minigame: U32, action: U32, now: U32) -> Action:
  match game:
    case Game.Game{players, messages, tick, next_message}:
      match list_player_find(players, id):
        case Found.Found{player}:
          match player:
            case Player.Player{stored, name, room, x, y, seen, game, score, aux, coins, owned, equipped}:
              match room == 4:
                case 0:
                  game_error(Game.Game{players, messages, tick, next_message}, "Visit the Acorn Arcade before using a cabinet.")
                case arcade:
                  match (minigame > 0) && (minigame <= 4):
                    case 0:
                      game_error(Game.Game{players, messages, tick, next_message}, "That cabinet is closed.")
                    case k:
                      played = player_play(Player.Player{stored, name, room, x, y, seen, game, score, aux, coins, owned, equipped}, minigame, action, tick, now)
                      game_ok(Game.Game{list_player_set(players, played), messages, tick + 1, next_message}, "Minigame state updated.")
        case Found.Missing{}:
          game_error(Game.Game{players, messages, tick, next_message}, "Join the club before playing.")

def game_buy(game: Game, id: U32, item: U32, now: U32) -> Action:
  match game:
    case Game.Game{players, messages, tick, next_message}:
      match list_player_find(players, id):
        case Found.Found{player}:
          match player:
            case Player.Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped}:
              price = u32_item_price(item)
              bit = u32_item_bit(item)
              match price > 0:
                case 0:
                  game_error(Game.Game{players, messages, tick, next_message}, "That catalog item does not exist.")
                case valid:
                  match room == u32_item_room(item):
                    case 0:
                      game_error(Game.Game{players, messages, tick, next_message}, "Visit the item's room catalog before buying it.")
                    case local:
                      match (owned .&. bit) > 0:
                        case 0:
                          match coins >= price:
                            case 0:
                              game_error(Game.Game{players, messages, tick, next_message}, "You need more coins for that item.")
                            case enough:
                              bird = player_buy(Player.Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped}, item, price, now)
                              game_ok(Game.Game{list_player_set(players, bird), messages, tick + 1, next_message}, "Item added to your collection.")
                        case already:
                          game_error(Game.Game{players, messages, tick, next_message}, "You already own that item.")
        case Found.Missing{}:
          game_error(Game.Game{players, messages, tick, next_message}, "Join the club before shopping.")

def game_equip(game: Game, id: U32, item: U32, now: U32) -> Action:
  match game:
    case Game.Game{players, messages, tick, next_message}:
      match list_player_find(players, id):
        case Found.Found{player}:
          match player:
            case Player.Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped}:
              match item == 0:
                case 0:
                  match (u32_item_price(item) > 0) && ((owned .&. u32_item_bit(item)) > 0):
                    case 0:
                      game_error(Game.Game{players, messages, tick, next_message}, "Buy that item before wearing it.")
                    case available:
                      bird = player_equip(Player.Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped}, item, now)
                      game_ok(Game.Game{list_player_set(players, bird), messages, tick + 1, next_message}, "Your outfit has been updated.")
                case remove:
                  bird = player_equip(Player.Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped}, 0, now)
                  game_ok(Game.Game{list_player_set(players, bird), messages, tick + 1, next_message}, "Your catalog item has been removed.")
        case Found.Missing{}:
          game_error(Game.Game{players, messages, tick, next_message}, "Join the club before changing outfits.")

def game_leave(game: Game, id: U32) -> Action:
  match game:
    case Game.Game{players, messages, tick, next_message}:
      match list_player_find(players, id):
        case Found.Found{player}:
          game_ok(Game.Game{list_player_remove(players, id), messages, tick + 1, next_message}, "See you next migration.")
        case Found.Missing{}:
          game_error(Game.Game{players, messages, tick, next_message}, "This bird is not in the club.")

def game_json(game: Game, id: U32, now: U32, ok: U32, note: String) -> String:
  match game:
    case Game.Game{players, messages, tick, next_message}:
      match list_player_find(players, id):
        case Found.Found{player}:
          match player:
            case Player.Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped}:
              String.flatten([
                "{\"ok\":", String.from_u32(ok), ",\"note\":", JSON.quoted(note, ""),
                ",\"you\":", String.from_u32(stored), ",\"room\":", String.from_u32(room),
                ",\"tick\":", String.from_u32(tick), ",\"players\":[", list_player_json(players, now, 1),
                ",\"messages\":[", list_message_json(messages, room, 1), "}"
              ])
        case Found.Missing{}:
          String.flatten([
            "{\"ok\":", String.from_u32(ok), ",\"note\":", JSON.quoted(note, ""),
            ",\"you\":0,\"room\":1,\"tick\":", String.from_u32(tick),
            ",\"players\":[", list_player_json(players, now, 1), ",\"messages\":[]}"
          ])

# ---------------------------------------------------------------- HTTP

def action_response(action: Action, id: U32, now: U32) -> Routed:
  match action:
    case Action.Action{game, ok, note}:
      Routed.Routed{game, HTTP.Response.Response{200,
        [HTTP.Header.Header{"Content-Type", "application/json; charset=utf-8"}, HTTP.Header.Header{"Cache-Control", "no-store, no-cache, must-revalidate"}],
        Bytes.from_string(game_json(game, id, now, ok, note))}}

def game_state_response(game: Game, id: U32, now: U32) -> Routed:
  touched = game_touch(game, id, now)
  Routed.Routed{touched, HTTP.reply(200, "application/json; charset=utf-8", game_json(touched, id, now, 1, ""))}

def game_missing(game: Game) -> Routed:
  Routed.Routed{game, HTTP.not_found()}

def result_index(result: Result((U32 & String), String), game: Game) -> IO(Routed):
  match result:
    case Result.Done{html}:
      IO.pure(Routed, Routed.Routed{game, HTTP.reply(200, "text/html; charset=utf-8", html)})
    case Result.Fail{(code, error)}:
      IO.pure(Routed, Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run from the repository root\n")})

def game_index(game: Game) -> IO(Routed):
  do IO(Routed):
    result <- IO.read_text("gabriel_demos/club_corvid_web/index.html")
    result_index(result, game)

def bytes_parts(body: Bytes) -> List(String):
  String.split(Char.Char{10}, Bytes.to_string(body))

def list_part(parts: List(String), index: U32) -> String:
  List.head(String, "", List.drop(String, index, parts))

def string_action(name: String, request: HTTP.Request, game: Game, now: U32) -> IO(Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      parts = bytes_parts(body)
      id = String.to_u32(list_part(parts, 0))
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
                                          IO.pure(Routed, game_missing(game))
                                        case k9:
                                          IO.pure(Routed, action_response(game_leave(game, id), id, now))
                                    case k8:
                                      IO.pure(Routed, action_response(game_equip(game, id, String.to_u32(list_part(parts, 1)), now), id, now))
                                case k7:
                                  IO.pure(Routed, action_response(game_buy(game, id, String.to_u32(list_part(parts, 1)), now), id, now))
                            case k6:
                              IO.pure(Routed, action_response(game_play(game, id, String.to_u32(list_part(parts, 1)), String.to_u32(list_part(parts, 2)), now), id, now))
                        case k5:
                          IO.pure(Routed, action_response(game_chat(game, id, list_part(parts, 1), now), id, now))
                    case k4:
                      IO.pure(Routed, action_response(game_room(game, id, String.to_u32(list_part(parts, 1)), now), id, now))
                case k3:
                  IO.pure(Routed, action_response(game_walk(game, id, String.to_u32(list_part(parts, 1)), String.to_u32(list_part(parts, 2)), now), id, now))
            case k2:
              IO.pure(Routed, action_response(game_move(game, id, String.to_u32(list_part(parts, 1)), now), id, now))
        case k1:
          IO.pure(Routed, action_response(game_join(game, id, list_part(parts, 1), now), id, now))

def list_route(parts: List(String), request: HTTP.Request, game: Game, now: U32) -> IO(Routed):
  match parts:
    case List.Cons{root, List.Cons{"state", List.Cons{id, rest}}}:
      IO.pure(Routed, game_state_response(game, String.to_u32(id), now))
    case List.Cons{root, List.Cons{"", rest}}:
      game_index(game)
    case List.Cons{root, List.Cons{name, rest}}:
      string_action(name, request, game, now)
    case List.Cons{root, List.Nil{}}:
      game_index(game)
    case List.Nil{}:
      game_index(game)

def request_route(request: HTTP.Request, game: Game, now: U32) -> IO(Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(method, "GET"):
        case 0:
          match String.eq_u32(method, "POST"):
            case 0:
              IO.pure(Routed, Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")})
            case post:
              list_route(String.split('/', path), HTTP.Request.Request{method, path, headers, body}, game, now)
        case get:
          list_route(String.split('/', path), HTTP.Request.Request{method, path, headers, body}, game, now)

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
        printed <- IO.write("Club Corvid listening on all interfaces (0.0.0.0:8087)\nopen http://<server-lan-ip>:8087\n")
        u32_serve(server, game_empty())
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def main() -> IO(U32):
  do IO(U32):
    result <- TCP.listen(8087)
    result_main(result)
