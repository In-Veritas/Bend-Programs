# web_slither: a four-player snake arena over the local network.
#
# The Bend process owns the complete game. Browsers send a desired heading,
# receive authoritative snapshots, and interpolate them for smooth drawing.
# The simulation advances in fixed 70 ms ticks from a monotonic clock, so its
# speed does not depend on the number of connected browsers: before every
# request the game catches up on the ticks that elapsed (at most 5 at once).
#
# routes (each also answers under the hub prefix /snake, which the page uses):
#   GET /                         the page (run from the repository root)
#   GET /state/<player>           watch or refresh a player's session
#   GET /join/<player>            take the first available slot
#   GET /input/<player>/<heading> set heading 0..15 and return a snapshot
#   GET /leave/<player>           leave the arena
#
# Hub interface: `Game`, `init() -> IO(Game)`, `route_now(req, game, now)`
# (advances the clock to `now`, then routes; paths with or without the
# leading `/snake`) and `route(req, game)` (reads the clock itself).
#
# build: bend Bend3/demos/slither_web/web_slither.bend -o Bend3/demos/slither_web/build/web_slither
# run:   ./Bend3/demos/slither_web/build/web_slither   (from the repository root)
# open:  http://<server-lan-ip>:8083
import Base
import ../HTTP.bend as HTTP
import ../Compat.bend as Compat
import ../Clock.bend as Clock

def tick_ms() -> U32:
  70

def arena_min() -> U32:
  18

def arena_max() -> U32:
  982

def food_count() -> Nat:
  36n

def body_start() -> Nat:
  18n

def body_max() -> Nat:
  72n

def player_timeout() -> U32:
  20000

def respawn_ticks() -> U32:
  18

type Step is Data:
  Step{x_pos: Bool, x_by: U32, y_pos: Bool, y_by: U32}

type Point is Data:
  Point{x: U32, y: U32}

type Supply is Data:
  Supply{points: List<&2, Point>, seed: U32}

type Snake is Data:
  Snake{id: U32, alive: U32, dir: U32, want: U32, score: U32, grow: U32, respawn: U32, seen: U32, body: List<&2, Point>}

type Meal is Data:
  Meal{ate: Bool, points: List<&2, Point>}

type Fed is Data:
  Fed{snake: Snake, points: List<&2, Point>, seed: U32}

type Game is Data:
  Game{one: Snake, two: Snake, three: Snake, four: Snake, food: List<&2, Point>, seed: U32, at: U32, tick: U32}

type Action is Data:
  Action{game: Game, ok: U32, note: String}

# ---------------------------------------------------------------- U32

def abs_diff(+a: U32, +b: U32) -> U32:
  Bool.pick(U32, U32.is_lt(a, b), (b - a : U32), (a - b : U32))

# Move by amount, towards + or -, never below 0.
def move(+value: U32, positive: Bool, +amount: U32) -> U32:
  match positive:
    case True{}:
      (value + amount : U32)
    case False{}:
      Bool.pick(U32, U32.is_lt(value, amount), 0, (value - amount : U32))

def step.go(d: U32) -> Step:
  match d:
    case 0:
      Step{True{}, 10, True{}, 0}
    case 1:
      Step{True{}, 9, True{}, 4}
    case 2:
      Step{True{}, 7, True{}, 7}
    case 3:
      Step{True{}, 4, True{}, 9}
    case 4:
      Step{True{}, 0, True{}, 10}
    case 5:
      Step{False{}, 4, True{}, 9}
    case 6:
      Step{False{}, 7, True{}, 7}
    case 7:
      Step{False{}, 9, True{}, 4}
    case 8:
      Step{False{}, 10, True{}, 0}
    case 9:
      Step{False{}, 9, False{}, 4}
    case 10:
      Step{False{}, 7, False{}, 7}
    case 11:
      Step{False{}, 4, False{}, 9}
    case 12:
      Step{True{}, 0, False{}, 10}
    case 13:
      Step{True{}, 4, False{}, 9}
    case 14:
      Step{True{}, 7, False{}, 7}
    case other:
      Step{True{}, 9, False{}, 4}

# One of 16 headings: a unit-ish step of length 10.
def step(dir: U32) -> Step:
  step.go((dir % 16 : U32))

# Turn dir one notch towards want (the shorter way round).
def turn(+dir: U32, +want: U32) -> U32:
  +gap = ((want % 16 + 16 - dir % 16 : U32) % 16 : U32)
  Bool.pick(U32, U32.is_zero(gap), (dir % 16 : U32),
  Bool.pick(U32, U32.is_lt(gap, 9), ((dir + 1 : U32) % 16 : U32), ((dir + 15 : U32) % 16 : U32)))

def random(seed: U32) -> U32:
  (seed * 1664525 + 1013904223 : U32)

def food_at(+sx: U32, +sy: U32) -> Point:
  Point{(40 + sx % 920 : U32), (40 + sy % 920 : U32)}

def supply.cons(p: Point, s: Supply) -> Supply:
  match s:
    case Supply{points, out}:
      Supply{p <> points, out}

def supply(n: Nat, seed: U32) -> Supply:
  match n:
    case 0n:
      Supply{Nil{}, seed}
    case 1n+k:
      +sx = random(seed)
      +sy = random(sx)
      supply.cons(food_at(sx, sy), supply(k, sy))

# ---------------------------------------------------------------- Point

def point_move.go(p: Point, s: Step) -> Point:
  match p s:
    case Point{x, y} Step{xp, xb, yp, yb}:
      Point{move(x, xp, xb), move(y, yp, yb)}

def point_move(p: Point, dir: U32) -> Point:
  point_move.go(p, step(dir))

def point_near(p: Point, q: Point, +radius: U32) -> Bool:
  match p q:
    case Point{x, y} Point{ox, oy}:
      +dx = abs_diff(x, ox)
      +dy = abs_diff(y, oy)
      U32.is_le((dx * dx + dy * dy : U32), (radius * radius : U32))

def point_out(p: Point) -> Bool:
  match p:
    case Point{+x, +y}:
      U32.is_lt(x, arena_min()) || U32.is_gt(x, arena_max()) || U32.is_lt(y, arena_min()) || U32.is_gt(y, arena_max())

def point_body(n: Nat, +p: Point, +back: U32) -> List<&2, Point>:
  match n:
    case 0n:
      Nil{}
    case 1n+k:
      p <> point_body(k, point_move(p, back), back)

def point_json(p: Point) -> String:
  match p:
    case Point{x, y}:
      "[" ++ U32.show(x) ++ "," ++ U32.show(y) ++ "]"

# ---------------------------------------------------------------- List

# Is p within radius of any point of the list after skipping `skip` of them?
def list_near(points: List<&2, Point>, +p: Point, skip: U32, +radius: U32) -> Bool:
  match points:
    case Nil{}:
      False{}
    case h <> t:
      match skip:
        case 0:
          point_near(p, h, radius) || list_near(t, p, 0, radius)
        case k:
          list_near(t, p, (k - 1 : U32), radius)

def meal.keep(h: Point, m: Meal) -> Meal:
  match m:
    case Meal{ate, kept}:
      Meal{ate, h <> kept}

# Eat the first food within 22 of p.
def list_meal(points: List<&2, Point>, +p: Point) -> Meal:
  match points:
    case Nil{}:
      Meal{False{}, Nil{}}
    case +h <> +t:
      Bool.pick(Meal, point_near(p, h, 22), Meal{True{}, t}, meal.keep(h, list_meal(t, p)))

def drop_last(points: List<&2, Point>) -> List<&2, Point>:
  match points:
    case Nil{}:
      Nil{}
    case h <> Nil{}:
      Nil{}
    case h <> t:
      h <> drop_last(t)

def points_json.go(points: List<&2, Point>) -> List<&2, String>:
  match points:
    case Nil{}:
      Nil{}
    case h <> t:
      point_json(h) <> points_json.go(t)

def points_json(points: List<&2, Point>) -> String:
  HTTP.json_array(points_json.go(points))

# ---------------------------------------------------------------- Snake

def snake_empty() -> Snake:
  Snake{0, 0, 0, 0, 0, 0, 0, 0, Nil{}}

def snake_spawn(slot: U32, id: U32, seen: U32) -> Snake:
  match slot:
    case 1:
      Snake{id, 1, 0, 0, 0, 0, 0, seen, point_body(body_start(), Point{250, 250}, 8)}
    case 2:
      Snake{id, 1, 8, 8, 0, 0, 0, seen, point_body(body_start(), Point{750, 750}, 0)}
    case 3:
      Snake{id, 1, 4, 4, 0, 0, 0, seen, point_body(body_start(), Point{750, 250}, 12)}
    case other:
      Snake{id, 1, 12, 12, 0, 0, 0, seen, point_body(body_start(), Point{250, 750}, 4)}

def snake_id(s: Snake) -> U32:
  match s:
    case Snake{id, alive, dir, want, score, grow, respawn, seen, body}:
      id

def snake_joined(s: Snake) -> Bool:
  Bool.not(U32.is_zero(snake_id(s)))

def snake_touch(+s: Snake, +player: U32, now: U32) -> Snake:
  Snake{+id, alive, dir, want, score, grow, respawn, seen, body} = s
  Bool.pick(Snake, U32.is_eq(id, player), Snake{id, alive, dir, want, score, grow, respawn, now, body}, s)

def snake_input(+s: Snake, +player: U32, +heading: U32, now: U32) -> Snake:
  Snake{+id, alive, dir, want, score, grow, respawn, seen, body} = s
  Bool.pick(Snake, U32.is_eq(id, player), Snake{id, alive, dir, (heading % 16 : U32), score, grow, respawn, now, body}, s)

def snake_leave(+s: Snake, +player: U32) -> Snake:
  Bool.pick(Snake, U32.is_eq(snake_id(s), player), snake_empty(), s)

def snake_expire(+s: Snake, +now: U32) -> Snake:
  Snake{+id, alive, dir, want, score, grow, respawn, +seen, body} = s
  Bool.pick(Snake, Bool.not(U32.is_zero(id)) && U32.is_gt((now - seen : U32), player_timeout()), snake_empty(), s)

def advance_body(+head: Point, tail: List<&2, Point>, dir: U32) -> List<&2, Point>:
  point_move(head, dir) <> head <> tail

def snake_step.live(+slot: U32, +player: U32, dir: U32, +want: U32, +score: U32, +grow: U32, +seen: U32,
  body: List<&2, Point>) -> Snake:
  match body:
    case Nil{}:
      snake_spawn(slot, player, seen)
    case +h <> +t:
      +nd = turn(dir, want)
      +nb = advance_body(h, t, nd)
      Bool.pick(Snake, U32.is_zero(grow),
        Snake{player, 1, nd, want, score, 0, 0, seen, drop_last(nb)},
        Snake{player, 1, nd, want, score, (grow - 1 : U32), 0, seen, List.take(&2, Point, nb, body_max())})

def snake_step(s: Snake, +slot: U32) -> Snake:
  match s:
    case Snake{id, alive, dir, want, score, grow, respawn, +seen, body}:
      match id:
        case 0:
          snake_empty()
        case +player:
          match alive:
            case 0:
              match respawn:
                case 0:
                  snake_spawn(slot, player, seen)
                case 1:
                  snake_spawn(slot, player, seen)
                case wait:
                  Snake{player, 0, dir, want, 0, 0, (wait - 1 : U32), seen, Nil{}}
            case live:
              snake_step.live(slot, player, dir, want, score, grow, seen, body)

def snake_body_near(s: Snake, +p: Point, skip: U32) -> Bool:
  match s:
    case Snake{id, alive, dir, want, score, grow, respawn, seen, body}:
      match alive:
        case 0:
          False{}
        case k:
          list_near(body, p, skip, 15)

def snake_kill(s: Snake) -> Snake:
  match s:
    case Snake{id, alive, dir, want, score, grow, respawn, seen, body}:
      Snake{id, 0, dir, want, 0, 0, respawn_ticks(), seen, Nil{}}

def snake_head(body: List<&2, Point>) -> Point:
  Maybe.default(&2, Point, List.head(&2, Point, body), Point{500, 500})

def snake_crash(+s: Snake, a: Snake, b: Snake, c: Snake) -> Snake:
  Snake{id, +alive, dir, want, score, grow, respawn, seen, +body} = s
  +head = snake_head(body)
  +hit = point_out(head) || list_near(body, head, 5, 15) ||
         snake_body_near(a, head, 0) || snake_body_near(b, head, 0) || snake_body_near(c, head, 0)
  Bool.pick(Snake, Bool.not(U32.is_zero(alive)) && hit, snake_kill(s), s)

def snake_feed.ate(+s: Snake, kept: List<&2, Point>, +seed: U32) -> Fed:
  Snake{id, alive, dir, want, score, grow, respawn, seen, body} = s
  +sx = random(seed)
  +sy = random(sx)
  Fed{Snake{id, alive, dir, want, (score + 1 : U32), (grow + 3 : U32), respawn, seen, body}, food_at(sx, sy) <> kept, sy}

def snake_feed.meal(m: Meal, +s: Snake, +seed: U32) -> Fed:
  match m:
    case Meal{True{}, kept}:
      snake_feed.ate(s, kept, seed)
    case Meal{False{}, kept}:
      Fed{s, kept, seed}

def snake_feed(+s: Snake, +points: List<&2, Point>, +seed: U32) -> Fed:
  Snake{id, +alive, dir, want, score, grow, respawn, seen, +body} = s
  Bool.pick(Fed, U32.is_zero(alive), Fed{s, points, seed},
    snake_feed.meal(list_meal(points, snake_head(body)), s, seed))

def snake_json(s: Snake, slot: U32) -> String:
  match s:
    case Snake{id, alive, dir, want, score, grow, respawn, seen, body}:
      HTTP.json_object([
        ("slot", U32.show(slot)),
        ("joined", U32.show(Bool.to_u32(Bool.not(U32.is_zero(id))))),
        ("alive", U32.show(alive)),
        ("dir", U32.show(dir)),
        ("score", U32.show(score)),
        ("respawn", U32.show(respawn)),
        ("body", points_json(body))])

# ---------------------------------------------------------------- Game

def game_empty.go(s: Supply, now: U32) -> Game:
  match s:
    case Supply{points, out}:
      Game{snake_empty(), snake_empty(), snake_empty(), snake_empty(), points, out, now, 0}

def game_empty(now: U32, seed: U32) -> Game:
  game_empty.go(supply(food_count(), seed), now)

def game_at(g: Game) -> U32:
  match g:
    case Game{one, two, three, four, food, seed, at, tick}:
      at

def game_retime(g: Game, now: U32) -> Game:
  match g:
    case Game{one, two, three, four, food, seed, at, tick}:
      Game{one, two, three, four, food, seed, now, tick}

def game_expire(g: Game, +now: U32) -> Game:
  match g:
    case Game{one, two, three, four, food, seed, at, tick}:
      Game{snake_expire(one, now), snake_expire(two, now), snake_expire(three, now), snake_expire(four, now), food, seed, at, tick}

def game_step.done(n1: Snake, n2: Snake, n3: Snake, f: Fed, at: U32, tick: U32) -> Game:
  match f:
    case Fed{n4, food, seed}:
      Game{n1, n2, n3, n4, food, seed, at, (tick + 1 : U32)}

def game_step.four(n1: Snake, n2: Snake, f: Fed, s4: Snake, at: U32, tick: U32) -> Game:
  match f:
    case Fed{n3, food, seed}:
      game_step.done(n1, n2, n3, snake_feed(s4, food, seed), at, tick)

def game_step.three(n1: Snake, f: Fed, s3: Snake, s4: Snake, at: U32, tick: U32) -> Game:
  match f:
    case Fed{n2, food, seed}:
      game_step.four(n1, n2, snake_feed(s3, food, seed), s4, at, tick)

def game_step.two(f: Fed, s2: Snake, s3: Snake, s4: Snake, at: U32, tick: U32) -> Game:
  match f:
    case Fed{n1, food, seed}:
      game_step.three(n1, snake_feed(s2, food, seed), s3, s4, at, tick)

# One tick: move every snake, then crash checks, then feeding in slot order.
def game_step(g: Game) -> Game:
  match g:
    case Game{one, two, three, four, food, seed, at, tick}:
      +m1 = snake_step(one, 1)
      +m2 = snake_step(two, 2)
      +m3 = snake_step(three, 3)
      +m4 = snake_step(four, 4)
      s1 = snake_crash(m1, m2, m3, m4)
      s2 = snake_crash(m2, m1, m3, m4)
      s3 = snake_crash(m3, m1, m2, m4)
      s4 = snake_crash(m4, m1, m2, m3)
      game_step.two(snake_feed(s1, food, seed), s2, s3, s4, at, tick)

def game_steps(count: Nat, g: Game) -> Game:
  match count:
    case 0n:
      g
    case 1n+k:
      game_steps(k, game_step(g))

# Catch up on the 70 ms ticks elapsed since the last advance; after a
# long pause (more than 5 ticks) only 5 run and the clock jumps to now.
def game_advance(g: Game, +now: U32) -> Game:
  +fresh = game_expire(g, now)
  +at = game_at(fresh)
  +raw = ((now - at : U32) / tick_ms() : U32)
  +count = U32.min(raw, 5)
  game_retime(game_steps(U32.to_nat(count), fresh),
    Bool.pick(U32, U32.is_gt(raw, 5), now, (at + count * tick_ms() : U32)))

# The slot (1..4) a player holds, or 0.
def game_player(+g: Game, +player: U32) -> U32:
  Game{one, two, three, four, food, seed, at, tick} = g
  +live = Bool.not(U32.is_zero(player))
  Bool.pick(U32, live && U32.is_eq(snake_id(one), player), 1,
  Bool.pick(U32, live && U32.is_eq(snake_id(two), player), 2,
  Bool.pick(U32, live && U32.is_eq(snake_id(three), player), 3,
  Bool.pick(U32, live && U32.is_eq(snake_id(four), player), 4, 0))))

def game_touch(g: Game, +player: U32, +now: U32) -> Game:
  match g:
    case Game{one, two, three, four, food, seed, at, tick}:
      Game{snake_touch(one, player, now), snake_touch(two, player, now), snake_touch(three, player, now), snake_touch(four, player, now), food, seed, at, tick}

def fail(g: Game, note: String) -> Action:
  Action{g, 0, note}

def ok(g: Game) -> Action:
  Action{g, 1, ""}

def game_join_open(+g: Game, +player: U32, +now: U32) -> Action:
  Game{+one, +two, +three, +four, +food, +seed, +at, +tick} = g
  Bool.pick(Action, Bool.not(snake_joined(one)), ok(Game{snake_spawn(1, player, now), two, three, four, food, seed, at, tick}),
  Bool.pick(Action, Bool.not(snake_joined(two)), ok(Game{one, snake_spawn(2, player, now), three, four, food, seed, at, tick}),
  Bool.pick(Action, Bool.not(snake_joined(three)), ok(Game{one, two, snake_spawn(3, player, now), four, food, seed, at, tick}),
  Bool.pick(Action, Bool.not(snake_joined(four)), ok(Game{one, two, three, snake_spawn(4, player, now), food, seed, at, tick}),
    fail(g, "The arena already has four players.")))))

def game_join(+g: Game, +player: U32, +now: U32) -> Action:
  Bool.pick(Action, U32.is_zero(player), fail(g, "Invalid player identity."),
  Bool.pick(Action, U32.is_zero(game_player(g, player)), game_join_open(g, player, now),
    ok(game_touch(g, player, now))))

def game_input.go(g: Game, +player: U32, +heading: U32, +now: U32) -> Game:
  match g:
    case Game{one, two, three, four, food, seed, at, tick}:
      Game{snake_input(one, player, heading, now), snake_input(two, player, heading, now),
        snake_input(three, player, heading, now), snake_input(four, player, heading, now), food, seed, at, tick}

def game_input(+g: Game, +player: U32, heading: U32, now: U32) -> Action:
  Bool.pick(Action, U32.is_zero(game_player(g, player)), fail(g, "Join the game before moving."),
    ok(game_input.go(g, player, heading, now)))

def game_state(g: Game, player: U32, now: U32) -> Action:
  ok(game_touch(g, player, now))

def game_leave.go(g: Game, +player: U32) -> Game:
  match g:
    case Game{one, two, three, four, food, seed, at, tick}:
      Game{snake_leave(one, player), snake_leave(two, player), snake_leave(three, player), snake_leave(four, player), food, seed, at, tick}

def game_leave(+g: Game, +player: U32) -> Action:
  Bool.pick(Action, U32.is_zero(game_player(g, player)), fail(g, "This browser has not joined the game."),
    ok(game_leave.go(g, player)))

def game_json(+g: Game, +player: U32, ok: U32, note: String) -> String:
  Game{+one, +two, +three, +four, food, seed, at, tick} = g
  HTTP.json_object([
    ("ok", U32.show(ok)),
    ("note", HTTP.quoted(note)),
    ("you", U32.show(game_player(g, player))),
    ("full", U32.show(Bool.to_u32(snake_joined(one) && snake_joined(two) && snake_joined(three) && snake_joined(four)))),
    ("tick", U32.show(tick)),
    ("players", HTTP.json_array([snake_json(one, 1), snake_json(two, 2), snake_json(three, 3), snake_json(four, 4)])),
    ("food", points_json(food))])

def action_reply(a: Action, +player: U32) -> Game & HTTP.Response:
  Action{+g, ok, note} = a
  (g, HTTP.json(game_json(g, player, ok, note)))

# ---------------------------------------------------------------- routing

def arg(args: List<&2, String>, i: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, args, i), "")

def argc(args: List<&2, String>) -> U32:
  U32.from_nat(List.length(&2, String, args))

type Out is Data:
  Json{action: Action, player: U32}
  Missing{game: Game}

def dispatch(+name: String, +args: List<&2, String>, +g: Game, +now: U32) -> Out:
  +n = argc(args)
  +p = Compat.to_u32(arg(args, 0n))
  +heading = Compat.to_u32(arg(args, 1n))
  Bool.pick(Out, String.eq(name, "state") && U32.is_ge(n, 1), Json{game_state(g, p, now), p},
  Bool.pick(Out, String.eq(name, "join") && U32.is_ge(n, 1), Json{game_join(g, p, now), p},
  Bool.pick(Out, String.eq(name, "input") && U32.is_ge(n, 2), Json{game_input(g, p, heading, now), p},
  Bool.pick(Out, String.eq(name, "leave") && U32.is_ge(n, 1), Json{game_leave(g, p), p},
    Missing{g}))))

def respond(out: Out) -> IO(Game & HTTP.Response):
  match out:
    case Json{action, +player}:
      IO.pure(Game & HTTP.Response, action_reply(action, player))
    case Missing{g}:
      IO.pure(Game & HTTP.Response, (g, HTTP.not_found()))

def page_reply(r: Result<&1, &1, U32 & String, String>) -> HTTP.Response:
  match r:
    case Done{body}:
      HTTP.html(body)
    case Fail{e}:
      HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run the server from the repository root\n")

def index(g: Game) -> IO(Game & HTTP.Response):
  do IO<Game & HTTP.Response>:
    r : Result<&1, &1, U32 & String, String> <- HTTP.read_text("Bend3/demos/slither_web/index.html")
    return (g, page_reply(r))

# Drop the hub prefix "snake" when present.
def unprefix(segs: List<&2, String>) -> List<&2, String>:
  match segs:
    case Nil{}:
      Nil{}
    case +h <> +t:
      Bool.pick(List<&2, String>, String.eq(h, "snake"), t, h <> t)

def route.segs(get: Bool, segs: List<&2, String>, g: Game, now: U32) -> IO(Game & HTTP.Response):
  match get segs:
    case False{} _:
      IO.pure(Game & HTTP.Response, (g, HTTP.method_not_allowed()))
    case True{} Nil{}:
      index(g)
    case True{} name <> args:
      respond(dispatch(name, args, g, now))

# Advance the simulation to `now`, then answer the request.
def route_now(req: HTTP.Request, g: Game, +now: U32) -> IO(Game & HTTP.Response):
  HTTP.Request{method, target, headers, body} = req
  route.segs(String.eq(method, "GET"), unprefix(HTTP.segments(target)), game_advance(g, now), now)

def route(req: HTTP.Request, g: Game) -> IO(Game & HTTP.Response):
  do IO<Game & HTTP.Response>:
    now : U32 <- Clock.now_ms()
    route_now(req, g, now)

def init() -> IO(Game):
  do IO<Game>:
    now : U32 <- Clock.now_ms()
    seed : U32 <- IO.try(U32, IO.random_u32())
    return game_empty(now, seed)

def main() -> IO(Unit):
  do IO<Unit>:
    g : Game <- init()
    IO.print("snake arena listening on all interfaces (0.0.0.0:8083)")
    IO.print("open http://<server-lan-ip>:8083 on up to four devices (run from the repository root)")
    HTTP.serve(~Game, ~route, "0.0.0.0", 8083, g)
