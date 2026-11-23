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
# (all also accepted under a leading /club-corvid, as the BendJogos hub uses)
#
# check: bend Bend3/demos/club_corvid_web/web_club_corvid.bend --check-only
# build: ./Bend3/demos/club_corvid_web/build.sh
# run:   ./Bend3/demos/club_corvid_web/start.sh   (from the repository root)
# open:  http://<server-lan-ip>:8087
#
# Hub interface: `Game`, `init()`, `route(req, game)` (reads the clock) and
# `route_at(req, game, now)`.

import Base
import ../HTTP.bend as HTTP
import ../Compat.bend as Compat
import ../Clock.bend as Clock

def player_timeout() -> U32:
  30000

def player_limit() -> U32:
  12

def chat_limit() -> Nat:
  24n

type Player is Data:
  Player{id: U32, name: String, room: U32, x: U32, y: U32, seen: U32, game: U32, score: U32, aux: U32, coins: U32, owned: U32, equipped: U32}

type Message is Data:
  Message{id: U32, room: U32, author: String, text: String, at: U32}

type Game is Data:
  Game{players: List<&2, Player>, messages: List<&2, Message>, tick: U32, next_message: U32}

type Action is Data:
  Action{game: Game, ok: U32, note: String}

type Found is Data:
  Found{player: Player}
  Missing{}

# ---------------------------------------------------------------- U32

def u32_prev(+value: U32, +low: U32) -> U32:
  Bool.pick(U32, (value <= low : U32), low, (value - 3 : U32))

def u32_next(+value: U32, +ceiling: U32) -> U32:
  Bool.pick(U32, ((value + 3 : U32) >= ceiling : U32), ceiling, (value + 3 : U32))

def u32_room(+room: U32) -> U32:
  Bool.pick(U32, (room > 0 : U32) && (room <= 4 : U32), room, 1)

def u32_clamp(+value: U32, +low: U32, +high: U32) -> U32:
  Bool.pick(U32, (value < low : U32), low, Bool.pick(U32, (value > high : U32), high, value))

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

# 1 << item for the eight catalog items (0 for anything else, which has no
# price either).
def u32_item_bit(item: U32) -> U32:
  match item:
    case 1:
      2
    case 2:
      4
    case 3:
      8
    case 4:
      16
    case 5:
      32
    case 6:
      64
    case 7:
      128
    case 8:
      256
    case other:
      0

def nonzero(+n: U32) -> Bool:
  Bool.not(U32.is_zero(n))

# ---------------------------------------------------------------- Player

def player_id(player: Player) -> U32:
  Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped} = player
  id

def player_active(player: Player, +now: U32) -> Bool:
  Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped} = player
  ((now - seen : U32) < player_timeout() : U32)

def player_touch(player: Player, now: U32) -> Player:
  Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped} = player
  Player{id, name, room, x, y, now, game, score, aux, coins, owned, equipped}

def player_move.dir(player: Player, dir: U32, +now: U32) -> Player:
  match player:
    case Player{id, name, room, +x, +y, seen, game, score, aux, coins, owned, equipped}:
      match dir:
        case 0:
          Player{id, name, room, x, u32_prev(y, 14), now, 0, score, aux, coins, owned, equipped}
        case 1:
          Player{id, name, room, u32_next(x, 88), y, now, 0, score, aux, coins, owned, equipped}
        case 2:
          Player{id, name, room, x, u32_next(y, 76), now, 0, score, aux, coins, owned, equipped}
        case other:
          Player{id, name, room, u32_prev(x, 12), y, now, 0, score, aux, coins, owned, equipped}

def player_move(player: Player, +direction: U32, +now: U32) -> Player:
  player_move.dir(player, (direction % 4 : U32), now)

def player_walk(player: Player, +x: U32, +y: U32, now: U32) -> Player:
  Player{id, name, room, old_x, old_y, seen, game, score, aux, coins, owned, equipped} = player
  Player{id, name, room, u32_clamp(x, 8, 92), u32_clamp(y, 18, 80), now, 0, score, aux, coins, owned, equipped}

def player_room(player: Player, +room: U32, now: U32) -> Player:
  Player{id, name, old, x, y, seen, game, score, aux, coins, owned, equipped} = player
  Player{id, name, u32_room(room), 50, 48, now, 0, score, aux, coins, owned, equipped}

# The player with a new minigame, score, hidden state and balance.
def player_set_game(player: Player, game: U32, score: U32, aux: U32, coins: U32, now: U32) -> Player:
  Player{id, name, room, x, y, seen, g, s, a, c, owned, equipped} = player
  Player{id, name, room, x, y, now, game, score, aux, coins, owned, equipped}

# Feather Flight: each clean pass scores and pays 12.
def play_flight(start: Bool, active: Bool, +p: Player, +now: U32, +score: U32, +aux: U32, +coins: U32) -> Player:
  match start active:
    case True{} _:
      player_set_game(p, 1, 0, 0, coins, now)
    case False{} False{}:
      player_touch(p, now)
    case False{} True{}:
      player_set_game(p, 1, (score + 1 : U32), ((aux + 1 : U32) % 7 : U32), (coins + 12 : U32), now)

# Shell Shuffle: aux hides the golden acorn (1..3); a right guess pays 25.
def play_shell(start: Bool, active: Bool, +p: Player, +now: U32, +tick: U32, +guess: U32, +score: U32, +aux: U32, +coins: U32) -> Player:
  match start active:
    case True{} _:
      player_set_game(p, 2, 0, ((tick % 3 : U32) + 1 : U32), coins, now)
    case False{} False{}:
      player_touch(p, now)
    case False{} True{}:
      +next = ((((tick + guess) : U32) % 3 : U32) + 1 : U32)
      Bool.pick(Player, U32.is_eq(guess, aux),
        player_set_game(p, 2, (score + 1 : U32), next, (coins + 25 : U32), now),
        player_set_game(p, 2, score, next, coins, now))

# Worm Hunt: aux is the worm's burrow (0..10); each peck pays 8.
def play_worm(start: Bool, active: Bool, +p: Player, +now: U32, +tick: U32, +peck: U32, +score: U32, +aux: U32, +coins: U32) -> Player:
  match start active:
    case True{} _:
      player_set_game(p, 3, 0, (tick % 11 : U32), coins, now)
    case False{} False{}:
      player_touch(p, now)
    case False{} True{}:
      player_set_game(p, 3, (score + 1 : U32), ((aux + (tick + peck)) % 11 : U32), (coins + 8 : U32), now)

# Echo Perch: aux seeds the phrase (0..3); each completed phrase pays 18.
def play_echo(start: Bool, active: Bool, +p: Player, +now: U32, +tick: U32, +phrase: U32, +score: U32, +aux: U32, +coins: U32) -> Player:
  match start active:
    case True{} _:
      player_set_game(p, 4, 0, (tick % 4 : U32), coins, now)
    case False{} False{}:
      player_touch(p, now)
    case False{} True{}:
      player_set_game(p, 4, (score + 1 : U32), ((aux + (tick + phrase)) % 4 : U32), (coins + 18 : U32), now)

def player_play.go(chosen: U32, +start: Bool, +game: U32, +player: Player, +action: U32, +tick: U32, +now: U32, +score: U32, +aux: U32, +coins: U32) -> Player:
  match chosen:
    case 1:
      play_flight(start, U32.is_eq(game, 1), player, now, score, aux, coins)
    case 2:
      play_shell(start, U32.is_eq(game, 2), player, now, tick, action, score, aux, coins)
    case 3:
      play_worm(start, U32.is_eq(game, 3), player, now, tick, action, score, aux, coins)
    case 4:
      play_echo(start, U32.is_eq(game, 4), player, now, tick, action, score, aux, coins)
    case other:
      player_set_game(player, 0, score, aux, coins, now)

def player_play(+player: Player, chosen: U32, +action: U32, +tick: U32, +now: U32) -> Player:
  Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped} = player
  player_play.go(chosen, U32.is_zero(action), game, player, action, tick, now, score, aux, coins)

def player_buy(player: Player, +item: U32, price: U32, now: U32) -> Player:
  Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped} = player
  Player{id, name, room, x, y, now, game, score, aux, (coins - price : U32), (owned .|. u32_item_bit(item) : U32), equipped}

def player_equip(player: Player, item: U32, now: U32) -> Player:
  Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped} = player
  Player{id, name, room, x, y, now, game, score, aux, coins, owned, item}

def player_json(+player: Player, +now: U32) -> String:
  Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped} = player
  String.concat([
    "{\"id\":", U32.show(id),
    ",\"name\":", HTTP.quoted(name),
    ",\"room\":", U32.show(room),
    ",\"x\":", U32.show(x),
    ",\"y\":", U32.show(y),
    ",\"online\":", U32.show(Bool.to_u32(player_active(player, now))),
    ",\"game\":", U32.show(game),
    ",\"score\":", U32.show(score),
    ",\"coins\":", U32.show(coins),
    ",\"owned\":", U32.show(owned),
    ",\"equipped\":", U32.show(equipped), "}"])

# ---------------------------------------------------------------- Message

def message_json(message: Message) -> String:
  Message{id, room, author, text, at} = message
  String.concat([
    "{\"id\":", U32.show(id),
    ",\"room\":", U32.show(room),
    ",\"author\":", HTTP.quoted(author),
    ",\"text\":", HTTP.quoted(text),
    ",\"at\":", U32.show(at), "}"])

def message_room(message: Message) -> U32:
  Message{id, room, author, text, at} = message
  room

# ---------------------------------------------------------------- List

def list_player_find.pick(hit: Bool, +head: Player, rest: Found) -> Found:
  match hit:
    case True{}:
      Found{head}
    case False{}:
      rest

def list_player_find(players: List<&2, Player>, +id: U32) -> Found:
  match players:
    case Nil{}:
      Missing{}
    case Con{+head, tail}:
      list_player_find.pick((id > 0 : U32) && U32.is_eq(player_id(head), id), head, list_player_find(tail, id))

def list_player_set(players: List<&2, Player>, +player: Player) -> List<&2, Player>:
  match players:
    case Nil{}:
      Nil{}
    case Con{+head, +tail}:
      Bool.pick(List<&2, Player>, U32.is_eq(player_id(head), player_id(player)),
        player <> tail,
        head <> list_player_set(tail, player))

def list_player_remove(players: List<&2, Player>, +id: U32) -> List<&2, Player>:
  match players:
    case Nil{}:
      Nil{}
    case Con{+head, +tail}:
      Bool.pick(List<&2, Player>, U32.is_eq(player_id(head), id), tail, head <> list_player_remove(tail, id))

def list_player_active(players: List<&2, Player>, +now: U32) -> U32:
  match players:
    case Nil{}:
      0
    case Con{head, tail}:
      (Bool.to_u32(player_active(head, now)) + list_player_active(tail, now) : U32)

# The online players as JSON objects followed by "]"; `first` says no comma
# has to precede the next one.
def list_player_json.put(online: Bool, first: Bool, +head: Player, +now: U32, rest: Bool -> String) -> String:
  match online first:
    case False{} _:
      rest(first)
    case True{} True{}:
      player_json(head, now) ++ rest(False{})
    case True{} False{}:
      "," ++ player_json(head, now) ++ rest(False{})

def list_player_json(players: List<&2, Player>, +now: U32, first: Bool) -> String:
  match players:
    case Nil{}:
      "]"
    case Con{+head, tail}:
      list_player_json.put(player_active(head, now), first, head, now, f => list_player_json(tail, now, f))

def list_message_json.put(here: Bool, first: Bool, +head: Message, rest: Bool -> String) -> String:
  match here first:
    case False{} _:
      rest(first)
    case True{} True{}:
      message_json(head) ++ rest(False{})
    case True{} False{}:
      "," ++ message_json(head) ++ rest(False{})

def list_message_json(messages: List<&2, Message>, +room: U32, first: Bool) -> String:
  match messages:
    case Nil{}:
      "]"
    case Con{+head, tail}:
      list_message_json.put(U32.is_eq(message_room(head), room), first, head, f => list_message_json(tail, room, f))

# ---------------------------------------------------------------- Game

def game_empty() -> Game:
  Game{Nil{}, Nil{}, 1, 1}

# The standalone and hub entry: an empty club.
def init() -> Game:
  game_empty()

def game_ok(game: Game, note: String) -> Action:
  Action{game, 1, note}

def game_error(game: Game, note: String) -> Action:
  Action{game, 0, note}

def game_find(+game: Game, +id: U32) -> Found:
  Game{players, messages, tick, next_message} = game
  list_player_find(players, id)

# The game with one player replaced and the tick advanced.
def game_put(game: Game, +player: Player) -> Game:
  Game{players, messages, tick, next_message} = game
  Game{list_player_set(players, player), messages, (tick + 1 : U32), next_message}

def game_tick(game: Game) -> U32:
  Game{players, messages, tick, next_message} = game
  tick

def game_touch.found(found: Found, +game: Game, +now: U32) -> Game:
  match found:
    case Found{player}:
      game_put(game, player_touch(player, now))
    case Missing{}:
      game

def game_touch(+game: Game, +id: U32, +now: U32) -> Game:
  game_touch.found(game_find(game, id), game, now)

def game_join.new(fit: Bool, game: Game, +id: U32, +name: String, +now: U32) -> Action:
  match fit:
    case False{}:
      game_error(game, "Choose a name from 2 to 18 characters; the rookery holds twelve birds.")
    case True{}:
      Game{players, messages, tick, next_message} = game
      bird : Player = Player{id, name, 1, 50, 48, now, 0, 0, 0, 500, 0, 0}
      game_ok(Game{bird <> players, messages, (tick + 1 : U32), next_message}, "Welcome to Club Corvid!")

def game_join.fits(+game: Game, +id: U32, +name: String, +now: U32) -> Bool:
  Game{players, messages, tick, next_message} = game
  +len = String.length(name)
  (id > 0 : U32) && ((len >= 2n : Nat) && ((len <= 18n : Nat) && (list_player_active(players, now) < player_limit() : U32)))

def game_join.found(found: Found, +game: Game, +id: U32, +name: String, +now: U32) -> Action:
  match found:
    case Found{player}:
      game_ok(game_put(game, player_touch(player, now)), "Welcome back to the flock.")
    case Missing{}:
      game_join.new(game_join.fits(game, id, name, now), game, id, name, now)

def game_join(+game: Game, +id: U32, +name: String, +now: U32) -> Action:
  game_join.found(game_find(game, id), game, id, name, now)

def game_move.found(found: Found, +game: Game, +direction: U32, +now: U32) -> Action:
  match found:
    case Found{player}:
      game_ok(game_put(game, player_move(player, direction, now)), "")
    case Missing{}:
      game_error(game, "Join the club before waddling.")

def game_move(+game: Game, +id: U32, +direction: U32, +now: U32) -> Action:
  game_move.found(game_find(game, id), game, direction, now)

def game_walk.found(found: Found, +game: Game, +x: U32, +y: U32, +now: U32) -> Action:
  match found:
    case Found{player}:
      game_ok(game_put(game, player_walk(player, x, y, now)), "")
    case Missing{}:
      game_error(game, "Join the club before waddling.")

def game_walk(+game: Game, +id: U32, +x: U32, +y: U32, +now: U32) -> Action:
  game_walk.found(game_find(game, id), game, x, y, now)

def game_room.found(found: Found, +game: Game, +room: U32, +now: U32) -> Action:
  match found:
    case Found{player}:
      game_ok(game_put(game, player_room(player, room, now)), "You travelled to a new perch.")
    case Missing{}:
      game_error(game, "Join the club before travelling.")

def game_room(+game: Game, +id: U32, +room: U32, +now: U32) -> Action:
  game_room.found(game_find(game, id), game, room, now)

def game_chat.send(fit: Bool, +game: Game, +player: Player, +text: String, +now: U32) -> Action:
  match fit:
    case False{}:
      game_error(game, "Messages are limited to 120 characters.")
    case True{}:
      Game{players, messages, tick, next_message} = game
      Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped} = player
      line : Message = Message{next_message, room, name, text, now}
      game_ok(Game{list_player_set(players, player_touch(player, now)), List.take(&2, Message, line <> messages, chat_limit()), (tick + 1 : U32), (next_message + 1 : U32)}, "Message sent to this room.")

def game_chat.found(found: Found, +game: Game, +text: String, +now: U32) -> Action:
  match found:
    case Found{+player}:
      +len = String.length(text)
      game_chat.send((len > 0n : Nat) && (len <= 120n : Nat), game, player, text, now)
    case Missing{}:
      game_error(game, "Join the club before chatting.")

def game_chat(+game: Game, +id: U32, +text: String, +now: U32) -> Action:
  game_chat.found(game_find(game, id), game, text, now)

def player_room_of(player: Player) -> U32:
  Player{id, name, room, x, y, seen, game, score, aux, coins, owned, equipped} = player
  room

def game_play.go(arcade: Bool, open: Bool, +game: Game, +player: Player, +minigame: U32, +action: U32, +now: U32) -> Action:
  match arcade open:
    case False{} _:
      game_error(game, "Visit the Acorn Arcade before using a cabinet.")
    case True{} False{}:
      game_error(game, "That cabinet is closed.")
    case True{} True{}:
      game_ok(game_put(game, player_play(player, minigame, action, game_tick(game), now)), "Minigame state updated.")

def game_play.found(found: Found, +game: Game, +minigame: U32, +action: U32, +now: U32) -> Action:
  match found:
    case Found{+player}:
      game_play.go(U32.is_eq(player_room_of(player), 4), (minigame > 0 : U32) && (minigame <= 4 : U32), game, player, minigame, action, now)
    case Missing{}:
      game_error(game, "Join the club before playing.")

def game_play(+game: Game, +id: U32, +minigame: U32, +action: U32, +now: U32) -> Action:
  game_play.found(game_find(game, id), game, minigame, action, now)

def game_buy.go(valid: Bool, local: Bool, owned: Bool, enough: Bool, +game: Game, +player: Player, +item: U32, +price: U32, +now: U32) -> Action:
  match valid local owned enough:
    case False{} _ _ _:
      game_error(game, "That catalog item does not exist.")
    case True{} False{} _ _:
      game_error(game, "Visit the item's room catalog before buying it.")
    case True{} True{} True{} _:
      game_error(game, "You already own that item.")
    case True{} True{} False{} False{}:
      game_error(game, "You need more coins for that item.")
    case True{} True{} False{} True{}:
      game_ok(game_put(game, player_buy(player, item, price, now)), "Item added to your collection.")

def game_buy.player(+game: Game, +player: Player, +item: U32, +now: U32) -> Action:
  Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped} = player
  +price = u32_item_price(item)
  game_buy.go((price > 0 : U32), U32.is_eq(room, u32_item_room(item)), nonzero((owned .&. u32_item_bit(item) : U32)), (coins >= price : U32), game, player, item, price, now)

def game_buy.found(found: Found, +game: Game, +item: U32, +now: U32) -> Action:
  match found:
    case Found{player}:
      game_buy.player(game, player, item, now)
    case Missing{}:
      game_error(game, "Join the club before shopping.")

def game_buy(+game: Game, +id: U32, +item: U32, +now: U32) -> Action:
  game_buy.found(game_find(game, id), game, item, now)

def game_equip.go(remove: Bool, available: Bool, +game: Game, +player: Player, +item: U32, +now: U32) -> Action:
  match remove available:
    case True{} _:
      game_ok(game_put(game, player_equip(player, 0, now)), "Your catalog item has been removed.")
    case False{} False{}:
      game_error(game, "Buy that item before wearing it.")
    case False{} True{}:
      game_ok(game_put(game, player_equip(player, item, now)), "Your outfit has been updated.")

def game_equip.player(+game: Game, +player: Player, +item: U32, +now: U32) -> Action:
  Player{stored, name, room, x, y, seen, minigame, score, aux, coins, owned, equipped} = player
  game_equip.go(U32.is_zero(item), (u32_item_price(item) > 0 : U32) && nonzero((owned .&. u32_item_bit(item) : U32)), game, player, item, now)

def game_equip.found(found: Found, +game: Game, +item: U32, +now: U32) -> Action:
  match found:
    case Found{player}:
      game_equip.player(game, player, item, now)
    case Missing{}:
      game_error(game, "Join the club before changing outfits.")

def game_equip(+game: Game, +id: U32, +item: U32, +now: U32) -> Action:
  game_equip.found(game_find(game, id), game, item, now)

def game_leave.found(found: Found, game: Game, +id: U32) -> Action:
  match found:
    case Found{player}:
      Game{players, messages, tick, next_message} = game
      game_ok(Game{list_player_remove(players, id), messages, (tick + 1 : U32), next_message}, "See you next migration.")
    case Missing{}:
      game_error(game, "This bird is not in the club.")

def game_leave(+game: Game, +id: U32) -> Action:
  game_leave.found(game_find(game, id), game, id)

def game_json.found(found: Found, game: Game, +now: U32, ok: U32, note: String) -> String:
  match found:
    case Found{player}:
      Player{stored, name, +room, x, y, seen, minigame, score, aux, coins, owned, equipped} = player
      Game{players, messages, tick, next_message} = game
      String.concat([
        "{\"ok\":", U32.show(ok), ",\"note\":", HTTP.quoted(note),
        ",\"you\":", U32.show(stored), ",\"room\":", U32.show(room),
        ",\"tick\":", U32.show(tick), ",\"players\":[", list_player_json(players, now, True{}),
        ",\"messages\":[", list_message_json(messages, room, True{}), "}"])
    case Missing{}:
      Game{players, messages, tick, next_message} = game
      String.concat([
        "{\"ok\":", U32.show(ok), ",\"note\":", HTTP.quoted(note),
        ",\"you\":0,\"room\":1,\"tick\":", U32.show(tick),
        ",\"players\":[", list_player_json(players, now, True{}), ",\"messages\":[]}"])

def game_json(+game: Game, +id: U32, +now: U32, ok: U32, note: String) -> String:
  game_json.found(game_find(game, id), game, now, ok, note)

# ---------------------------------------------------------------- HTTP

def done(game: Game, r: HTTP.Response) -> IO(Game & HTTP.Response):
  IO.pure(Game & HTTP.Response, (game, r))

def action_response(action: Action, +id: U32, +now: U32) -> IO(Game & HTTP.Response):
  Action{+game, ok, note} = action
  done(game, HTTP.Response{200,
    [HTTP.Header{"Content-Type", "application/json; charset=utf-8"}, HTTP.Header{"Cache-Control", "no-store, no-cache, must-revalidate"}],
    game_json(game, id, now, ok, note)})

def game_state_response(+game: Game, +id: U32, +now: U32) -> IO(Game & HTTP.Response):
  +touched = game_touch(game, id, now)
  done(touched, HTTP.json(game_json(touched, id, now, 1, "")))

def index.got(r: Result<&1, &1, U32 & String, String>) -> HTTP.Response:
  match r:
    case Done{page}:
      HTTP.html(page)
    case Fail{e}:
      HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run from the repository root\n")

def game_index(game: Game) -> IO(Game & HTTP.Response):
  do IO<Game & HTTP.Response>:
    r : Result<&1, &1, U32 & String, String> <- HTTP.read_text("Bend3/demos/club_corvid_web/index.html")
    return (game, index.got(r))

def part(parts: List<&2, String>, n: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, parts, n), "")

def num(parts: List<&2, String>, n: Nat) -> U32:
  Compat.to_u32(part(parts, n))

def action_kind(+name: String) -> U32:
  Bool.pick(U32, String.eq(name, "join"), 1,
  Bool.pick(U32, String.eq(name, "move"), 2,
  Bool.pick(U32, String.eq(name, "walk"), 3,
  Bool.pick(U32, String.eq(name, "room"), 4,
  Bool.pick(U32, String.eq(name, "chat"), 5,
  Bool.pick(U32, String.eq(name, "play"), 6,
  Bool.pick(U32, String.eq(name, "buy"), 7,
  Bool.pick(U32, String.eq(name, "equip"), 8,
  Bool.pick(U32, String.eq(name, "leave"), 9, 0)))))))))

# A body action: the body's first line is the bird's identity.
def string_action.go(kind: U32, +id: U32, +parts: List<&2, String>, +game: Game, +now: U32) -> IO(Game & HTTP.Response):
  match kind:
    case 1:
      action_response(game_join(game, id, part(parts, 1n), now), id, now)
    case 2:
      action_response(game_move(game, id, num(parts, 1n), now), id, now)
    case 3:
      action_response(game_walk(game, id, num(parts, 1n), num(parts, 2n), now), id, now)
    case 4:
      action_response(game_room(game, id, num(parts, 1n), now), id, now)
    case 5:
      action_response(game_chat(game, id, part(parts, 1n), now), id, now)
    case 6:
      action_response(game_play(game, id, num(parts, 1n), num(parts, 2n), now), id, now)
    case 7:
      action_response(game_buy(game, id, num(parts, 1n), now), id, now)
    case 8:
      action_response(game_equip(game, id, num(parts, 1n), now), id, now)
    case 9:
      action_response(game_leave(game, id), id, now)
    case other:
      done(game, HTTP.not_found())

def string_action(+name: String, +body: String, game: Game, now: U32) -> IO(Game & HTTP.Response):
  +parts = HTTP.body_lines(body)
  string_action.go(action_kind(name), num(parts, 0n), parts, game, now)

# /state/<id> (GET or POST), "" or nothing: the page, else a body action.
def list_route.named(root: Bool, state: Bool, +name: String, +args: List<&2, String>, +body: String, game: Game, now: U32) -> IO(Game & HTTP.Response):
  match root state args:
    case True{} _ _:
      game_index(game)
    case False{} True{} +id <> rest:
      game_state_response(game, Compat.to_u32(id), now)
    case _ _ _:
      string_action(name, body, game, now)

# `parts` is the path split on '/', without the leading "" (and without a
# leading "club-corvid" prefix).
def list_route(parts: List<&2, String>, +body: String, game: Game, now: U32) -> IO(Game & HTTP.Response):
  match parts:
    case Nil{}:
      game_index(game)
    case +name <> args:
      list_route.named(String.is_empty(name), String.eq(name, "state"), name, args, body, game, now)

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
      unprefix.pick(String.eq(name, "club-corvid"), name, rest)

def route_at.go(allowed: Bool, +target: String, +body: String, game: Game, now: U32) -> IO(Game & HTTP.Response):
  match allowed:
    case False{}:
      done(game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n"))
    case True{}:
      list_route(unprefix(HTTP.split_path(target)), body, game, now)

# The club's HTTP handler with an explicit clock reading.
def route_at(req: HTTP.Request, game: Game, now: U32) -> IO(Game & HTTP.Response):
  HTTP.Request{+method, target, headers, body} = req
  route_at.go(String.eq(method, "GET") || String.eq(method, "POST"), target, body, game, now)

# The club's HTTP handler (HTTP.serve's shape).
def route(req: HTTP.Request, game: Game) -> IO(Game & HTTP.Response):
  do IO<Game & HTTP.Response>:
    now : U32 <- Clock.now_ms()
    route_at(req, game, now)

# ---------------------------------------------------------------- Server

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Club Corvid listening on all interfaces (0.0.0.0:8087)\nopen http://<server-lan-ip>:8087")
    HTTP.serve(~Game, ~route, "0.0.0.0", 8087, init())
