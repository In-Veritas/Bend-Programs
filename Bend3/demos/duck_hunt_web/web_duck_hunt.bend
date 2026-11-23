# Duck Hunt: a Bend-owned single-player light-gun game with a shared LAN high score.
#
# Routes (each also answers under the hub prefix /duck-hunt):
#   GET /                         pixel-art browser game
#   GET /state/<player>           current hunt state
#   GET /start/<player>           begin a new ten-duck round
#   GET /shoot/<player>/<hit>/<band>
#                                 spend a shell; band 0..3 rewards accuracy
#   GET /next/<player>            advance after a hit or escaped duck
#   GET /leave/<player>           remove this browser's hunt
#
# Player status: 0 idle, 1 duck in flight, 2 duck resolved (hit or
# escaped), 3 game over.
#
# Hub interface: `Game`, `init()`, and `route(req, game)`; `route` accepts
# paths with or without the leading `/duck-hunt`.
#
# Build (from the repository root):
#   ./Bend3/demos/duck_hunt_web/build.sh
#   (bend Bend3/demos/duck_hunt_web/web_duck_hunt.bend -o Bend3/demos/duck_hunt_web/build/web_duck_hunt)
import Base
import ../HTTP.bend as HTTP
import ../Compat.bend as Compat

type Player is Data:
  Player{id: U32, score: U32, best: U32, round: U32, duck: U32, ammo: U32, round_hits: U32, total_hits: U32, status: U32, seed: U32}

type Game is Data:
  Game{players: List<&2, Player>, high: U32, high_player: U32, tick: U32}

type Action is Data:
  Action{game: Game, ok: U32, note: String}

# ---------------------------------------------------------------- player

# Qualifying hits per ten ducks: 6, rising by one every three rounds, up to 8.
def required(+round: U32) -> U32:
  U32.min(8, (6 + (round - 1 : U32) / 3 : U32))

def points(band: U32, +round: U32) -> U32:
  (450 + U32.min(3, band) * 250 + round * 50 : U32)

def shot_note(+hit: Bool, +ammo: U32) -> String:
  Bool.pick(String, hit, "Direct hit.",
  Bool.pick(String, U32.is_zero(ammo), "Out of shells. The duck escaped.",
    "Miss. Track the flight and try again."))

def player_id(p: Player) -> U32:
  match p:
    case Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
      id

def player_idle(+id: U32) -> Player:
  Player{id, 0, 0, 1, 1, 3, 0, 0, 0, id}

def player_start(p: Player, seed: U32) -> Player:
  match p:
    case Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, old}:
      Player{id, 0, best, 1, 1, 3, 0, 0, 1, seed}

# Spend a shell (ammo > 0). A hit scores and resolves the duck; the last
# missed shell lets it escape.
def player_shoot(+p: Player, +hit: Bool, band: U32) -> Player:
  Player{id, +score, +best, +round, duck, +ammo, +round_hits, +total_hits, status, seed} = p
  +ammo2 = (ammo - 1 : U32)
  +score2 = (score + points(band, round) : U32)
  Bool.pick(Player, hit,
    Player{id, score2, U32.max(best, score2), round, duck, ammo2, (round_hits + 1 : U32), (total_hits + 1 : U32), 2, seed},
    Player{id, score, best, round, duck, ammo2, round_hits, total_hits, Bool.pick(U32, U32.is_zero(ammo2), 2, 1), seed})

def player_next_duck(p: Player, seed: U32) -> Player:
  match p:
    case Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, old}:
      Player{id, score, best, round, (duck + 1 : U32), 3, round_hits, total_hits, 1, seed}

def player_next_round(p: Player, seed: U32) -> Player:
  match p:
    case Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, old}:
      Player{id, score, best, (round + 1 : U32), 1, 3, 0, total_hits, 1, seed}

def player_game_over(p: Player) -> Player:
  match p:
    case Player{id, score, best, round, duck, ammo, round_hits, total_hits, status, seed}:
      Player{id, score, best, round, duck, ammo, round_hits, total_hits, 3, seed}

def player_json(p: Player) -> String:
  match p:
    case Player{id, score, best, +round, duck, ammo, round_hits, total_hits, status, seed}:
      HTTP.json_object([
        ("id", U32.show(id)),
        ("score", U32.show(score)),
        ("best", U32.show(best)),
        ("round", U32.show(round)),
        ("duck", U32.show(duck)),
        ("ammo", U32.show(ammo)),
        ("roundHits", U32.show(round_hits)),
        ("totalHits", U32.show(total_hits)),
        ("status", U32.show(status)),
        ("seed", U32.show(seed)),
        ("required", U32.show(required(round)))])

# ---------------------------------------------------------------- player list

def players_find(players: List<&2, Player>, +id: U32) -> Maybe<&2, Player>:
  match players:
    case Nil{}:
      None{}
    case +h <> t:
      Bool.pick(Maybe<&2, Player>, U32.is_eq(player_id(h), id), Some{h}, players_find(t, id))

# Replace the player with the same id, or append it.
def players_set(players: List<&2, Player>, +p: Player) -> List<&2, Player>:
  match players:
    case Nil{}:
      [p]
    case +h <> +t:
      Bool.pick(List<&2, Player>, U32.is_eq(player_id(h), player_id(p)), p <> t, h <> players_set(t, p))

def players_remove(players: List<&2, Player>, +id: U32) -> List<&2, Player>:
  match players:
    case Nil{}:
      Nil{}
    case +h <> +t:
      Bool.pick(List<&2, Player>, U32.is_eq(player_id(h), id), t, h <> players_remove(t, id))

# ---------------------------------------------------------------- game

def init() -> Game:
  Game{Nil{}, 0, 0, 1}

def fail(g: Game, note: String) -> Action:
  Action{g, 0, note}

def ok(g: Game, note: String) -> Action:
  Action{g, 1, note}

def game_player(g: Game, +id: U32) -> Player:
  match g:
    case Game{players, high, high_player, tick}:
      Maybe.default(&2, Player, players_find(players, id), player_idle(id))

def seed_of(+id: U32, +tick: U32) -> U32:
  ((id * 1664525 + tick * 1013904223 : U32) % 2147483647 : U32)

def game_start(+g: Game, +id: U32) -> Action:
  Game{players, high, high_player, +tick} = g
  Bool.pick(Action, U32.is_zero(id), fail(g, "Invalid hunter identity."),
    ok(Game{players_set(players, player_start(game_player(g, id), seed_of(id, tick))), high, high_player, (tick + 1 : U32)},
      "Round one. Ten ducks. Make every shell count."))

def game_shoot.scored(+g: Game, +shot: Player, +hit: Bool) -> Action:
  Game{players, +high, high_player, tick} = g
  Player{+shot_id, +shot_score, shot_best, shot_round, shot_duck, +shot_ammo, shot_rh, shot_th, shot_status, shot_seed} = shot
  ok(Game{players_set(players, shot), U32.max(high, shot_score),
    Bool.pick(U32, U32.is_gt(shot_score, high), shot_id, high_player), (tick + 1 : U32)},
    shot_note(hit, shot_ammo))

def game_shoot.active(+g: Game, +p: Player, +hit: Bool, band: U32) -> Action:
  Player{id, score, best, round, duck, +ammo, round_hits, total_hits, status, seed} = p
  Bool.pick(Action, U32.is_zero(ammo), fail(g, "No shells remain for this duck."),
    game_shoot.scored(g, player_shoot(p, hit, band), hit))

def game_shoot.found(m: Maybe<&2, Player>, +g: Game, +hit: Bool, band: U32) -> Action:
  match m:
    case None{}:
      fail(g, "Start a hunt before shooting.")
    case Some{+p}:
      Player{id, score, best, round, duck, ammo, round_hits, total_hits, +status, seed} = p
      Bool.pick(Action, U32.is_eq(status, 1), game_shoot.active(g, p, hit, band), fail(g, "Wait for the next duck."))

def game_shoot(+g: Game, +id: U32, hit: U32, band: U32) -> Action:
  Game{players, high, high_player, tick} = g
  game_shoot.found(players_find(players, id), g, Bool.not(U32.is_zero(hit)), band)

def game_next.resolved(+g: Game, +p: Player) -> Action:
  Game{players, high, high_player, +tick} = g
  Player{+id, score, best, +round, +duck, ammo, +round_hits, total_hits, status, seed} = p
  +seed2 = seed_of(id, tick)
  Bool.pick(Action, U32.is_lt(duck, 10),
    ok(Game{players_set(players, player_next_duck(p, seed2)), high, high_player, (tick + 1 : U32)}, "Next duck."),
  Bool.pick(Action, U32.is_ge(round_hits, required(round)),
    ok(Game{players_set(players, player_next_round(p, seed2)), high, high_player, (tick + 1 : U32)}, "Round clear. The next flock is faster."),
    ok(Game{players_set(players, player_game_over(p)), high, high_player, (tick + 1 : U32)}, "The dog closes the book on this hunt.")))

def game_next.found(m: Maybe<&2, Player>, +g: Game) -> Action:
  match m:
    case None{}:
      fail(g, "Start a hunt first.")
    case Some{+p}:
      Player{id, score, best, round, duck, ammo, round_hits, total_hits, +status, seed} = p
      Bool.pick(Action, U32.is_eq(status, 2), game_next.resolved(g, p), fail(g, "This duck is still in flight."))

def game_next(+g: Game, +id: U32) -> Action:
  Game{players, high, high_player, tick} = g
  game_next.found(players_find(players, id), g)

def game_leave(g: Game, +id: U32) -> Action:
  match g:
    case Game{players, high, high_player, tick}:
      ok(Game{players_remove(players, id), high, high_player, (tick + 1 : U32)}, "")

# ---------------------------------------------------------------- json and routing

def game_json(+g: Game, +id: U32, ok: U32, note: String) -> String:
  Game{players, high, high_player, tick} = g
  HTTP.json_object([
    ("ok", U32.show(ok)),
    ("note", HTTP.quoted(note)),
    ("high", U32.show(high)),
    ("highPlayer", U32.show(high_player)),
    ("tick", U32.show(tick)),
    ("player", player_json(game_player(g, id)))])

def action_reply(a: Action, +id: U32) -> Game & HTTP.Response:
  Action{+g, ok, note} = a
  (g, HTTP.json(game_json(g, id, ok, note)))

def arg(args: List<&2, String>, i: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, args, i), "")

def argc(args: List<&2, String>) -> U32:
  U32.from_nat(List.length(&2, String, args))

type Out is Data:
  Json{action: Action, id: U32}
  Missing{game: Game}

def dispatch(+name: String, +args: List<&2, String>, +g: Game) -> Out:
  +n = argc(args)
  +id = Compat.to_u32(arg(args, 0n))
  Bool.pick(Out, String.eq(name, "state") && U32.is_ge(n, 1), Json{ok(g, ""), id},
  Bool.pick(Out, String.eq(name, "start") && U32.is_ge(n, 1), Json{game_start(g, id), id},
  Bool.pick(Out, String.eq(name, "shoot") && U32.is_ge(n, 3),
    Json{game_shoot(g, id, Compat.to_u32(arg(args, 1n)), Compat.to_u32(arg(args, 2n))), id},
  Bool.pick(Out, String.eq(name, "next") && U32.is_ge(n, 1), Json{game_next(g, id), id},
  Bool.pick(Out, String.eq(name, "leave") && U32.is_ge(n, 1), Json{game_leave(g, id), id},
    Missing{g})))))

def respond(out: Out) -> IO(Game & HTTP.Response):
  match out:
    case Json{action, +id}:
      IO.pure(Game & HTTP.Response, action_reply(action, id))
    case Missing{g}:
      IO.pure(Game & HTTP.Response, (g, HTTP.not_found()))

def page_reply(r: Result<&1, &1, U32 & String, String>) -> HTTP.Response:
  match r:
    case Done{body}:
      HTTP.html(body)
    case Fail{e}:
      HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run from the repository root\n")

def index(g: Game) -> IO(Game & HTTP.Response):
  do IO<Game & HTTP.Response>:
    r : Result<&1, &1, U32 & String, String> <- HTTP.read_text("Bend3/demos/duck_hunt_web/index.html")
    return (g, page_reply(r))

# Drop the hub prefix "duck-hunt" when present.
def unprefix(segs: List<&2, String>) -> List<&2, String>:
  match segs:
    case Nil{}:
      Nil{}
    case +h <> +t:
      Bool.pick(List<&2, String>, String.eq(h, "duck-hunt"), t, h <> t)

def route.segs(get: Bool, segs: List<&2, String>, g: Game) -> IO(Game & HTTP.Response):
  match get segs:
    case False{} _:
      IO.pure(Game & HTTP.Response, (g, HTTP.method_not_allowed()))
    case True{} Nil{}:
      index(g)
    case True{} name <> args:
      respond(dispatch(name, args, g))

def route(req: HTTP.Request, g: Game) -> IO(Game & HTTP.Response):
  HTTP.Request{method, target, headers, body} = req
  route.segs(String.eq(method, "GET"), unprefix(HTTP.segments(target)), g)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Duck Hunt listening on all interfaces (0.0.0.0:8089)")
    IO.print("open http://<server-lan-ip>:8089 (run from the repository root)")
    HTTP.serve(~Game, ~route, "0.0.0.0", 8089, init())
