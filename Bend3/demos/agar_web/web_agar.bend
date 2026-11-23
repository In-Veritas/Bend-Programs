# web_agar: a four-player cell-eating arena over the local network.
#
# The Bend process owns movement, food, player consumption, respawns, and
# session cleanup. Browsers send a quantized desired direction and draw the
# returned snapshots. The simulation advances in fixed 70 ms ticks from a
# monotonic clock (catching up at most 5 ticks before each request).
#
# routes (each also answers under the hub prefix /cells, which the page uses):
#   GET /                         the page (run from the repository root)
#   GET /state/<player>           watch or refresh a session
#   GET /join/<player>            take the first available slot
#   GET /input/<player>/<heading> set heading 0..15 and return a snapshot
#   GET /leave/<player>           leave the arena
#
# Hub interface: `Game`, `init() -> IO(Game)`, `route_now(req, game, now)`
# (advances the clock to `now`, then routes; paths with or without the
# leading `/cells`) and `route(req, game)` (reads the clock itself).
#
# build: bend Bend3/demos/agar_web/web_agar.bend -o Bend3/demos/agar_web/build/web_agar
# run:   ./Bend3/demos/agar_web/build/web_agar   (from the repository root)
# open:  http://<server-lan-ip>:8084
import Base
import ../HTTP.bend as HTTP
import ../Compat.bend as Compat
import ../Clock.bend as Clock

def tick_ms() -> U32:
  70

def world_size() -> U32:
  1200

def food_count() -> Nat:
  54n

def player_timeout() -> U32:
  20000

def respawn_ticks() -> U32:
  16

type Step is Data:
  Step{x_pos: Bool, x_by: U32, y_pos: Bool, y_by: U32}

type Point is Data:
  Point{x: U32, y: U32}

type Supply is Data:
  Supply{points: List<&2, Point>, seed: U32}

type Cell is Data:
  Cell{id: U32, alive: U32, x: U32, y: U32, dir: U32, mass: U32, respawn: U32, seen: U32}

type Meal is Data:
  Meal{ate: Bool, points: List<&2, Point>}

type Fed is Data:
  Fed{cell: Cell, points: List<&2, Point>, seed: U32}

type Duel is Data:
  Duel{left: Cell, right: Cell}

type Game is Data:
  Game{one: Cell, two: Cell, three: Cell, four: Cell, food: List<&2, Point>, seed: U32, at: U32, tick: U32}

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

def random(seed: U32) -> U32:
  (seed * 1664525 + 1013904223 : U32)

def clamp(value: U32, low: U32, high: U32) -> U32:
  U32.min(U32.max(value, low), high)

def food_at(+sx: U32, +sy: U32) -> Point:
  Point{(30 + sx % 1140 : U32), (30 + sy % 1140 : U32)}

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

def point_near(p: Point, q: Point, +radius: U32) -> Bool:
  match p q:
    case Point{x, y} Point{ox, oy}:
      +dx = abs_diff(x, ox)
      +dy = abs_diff(y, oy)
      U32.is_le((dx * dx + dy * dy : U32), (radius * radius : U32))

def point_json(p: Point) -> String:
  match p:
    case Point{x, y}:
      "[" ++ U32.show(x) ++ "," ++ U32.show(y) ++ "]"

# ---------------------------------------------------------------- List

def meal.keep(h: Point, m: Meal) -> Meal:
  match m:
    case Meal{ate, kept}:
      Meal{ate, h <> kept}

# Eat the first food within radius of p.
def list_meal(points: List<&2, Point>, +p: Point, +radius: U32) -> Meal:
  match points:
    case Nil{}:
      Meal{False{}, Nil{}}
    case +h <> +t:
      Bool.pick(Meal, point_near(p, h, radius), Meal{True{}, t}, meal.keep(h, list_meal(t, p, radius)))

def points_json.go(points: List<&2, Point>) -> List<&2, String>:
  match points:
    case Nil{}:
      Nil{}
    case h <> t:
      point_json(h) <> points_json.go(t)

def points_json(points: List<&2, Point>) -> String:
  HTTP.json_array(points_json.go(points))

# ---------------------------------------------------------------- Cell

def cell_empty() -> Cell:
  Cell{0, 0, 0, 0, 0, 0, 0, 0}

def cell_spawn(slot: U32, id: U32, seen: U32) -> Cell:
  match slot:
    case 1:
      Cell{id, 1, 260, 260, 0, 5, 0, seen}
    case 2:
      Cell{id, 1, 940, 940, 8, 5, 0, seen}
    case 3:
      Cell{id, 1, 940, 260, 4, 5, 0, seen}
    case other:
      Cell{id, 1, 260, 940, 12, 5, 0, seen}

def cell_id(c: Cell) -> U32:
  match c:
    case Cell{id, alive, x, y, dir, mass, respawn, seen}:
      id

def cell_joined(c: Cell) -> Bool:
  Bool.not(U32.is_zero(cell_id(c)))

# The radius a cell draws and eats with.
def cell_radius(mass: U32) -> U32:
  (18 + U32.min(mass, 34) : U32)

def cell_touch(+c: Cell, +player: U32, now: U32) -> Cell:
  Cell{+id, alive, x, y, dir, mass, respawn, seen} = c
  Bool.pick(Cell, U32.is_eq(id, player), Cell{id, alive, x, y, dir, mass, respawn, now}, c)

def cell_input(+c: Cell, +player: U32, +heading: U32, now: U32) -> Cell:
  Cell{+id, alive, x, y, dir, mass, respawn, seen} = c
  Bool.pick(Cell, U32.is_eq(id, player), Cell{id, alive, x, y, (heading % 16 : U32), mass, respawn, now}, c)

def cell_leave(+c: Cell, +player: U32) -> Cell:
  Bool.pick(Cell, U32.is_eq(cell_id(c), player), cell_empty(), c)

def cell_expire(+c: Cell, +now: U32) -> Cell:
  Cell{+id, alive, x, y, dir, mass, respawn, +seen} = c
  Bool.pick(Cell, Bool.not(U32.is_zero(id)) && U32.is_gt((now - seen : U32), player_timeout()), cell_empty(), c)

# Move one tick along dir; heavier cells are slower, and stay inside the world.
def cell_step.live(s: Step, player: U32, x: U32, y: U32, dir: U32, +mass: U32, seen: U32) -> Cell:
  match s:
    case Step{xp, xb, yp, yb}:
      +pace = (10 - U32.min((mass / 8 : U32), 4) : U32)
      +radius = cell_radius(mass)
      +high = (world_size() - radius : U32)
      +nx = clamp(move(x, xp, (xb * pace / 10 : U32)), radius, high)
      +ny = clamp(move(y, yp, (yb * pace / 10 : U32)), radius, high)
      Cell{player, 1, nx, ny, dir, mass, 0, seen}

def cell_step(c: Cell, +slot: U32) -> Cell:
  match c:
    case Cell{id, alive, x, y, +dir, mass, respawn, +seen}:
      match id:
        case 0:
          cell_empty()
        case +player:
          match alive:
            case 0:
              match respawn:
                case 0:
                  cell_spawn(slot, player, seen)
                case 1:
                  cell_spawn(slot, player, seen)
                case wait:
                  Cell{player, 0, x, y, dir, 0, (wait - 1 : U32), seen}
            case live:
              cell_step.live(step(dir), player, x, y, dir, mass, seen)

def cell_kill(c: Cell) -> Cell:
  match c:
    case Cell{id, alive, x, y, dir, mass, respawn, seen}:
      Cell{id, 0, x, y, dir, 0, respawn_ticks(), seen}

def cell_feed.ate(+c: Cell, kept: List<&2, Point>, +seed: U32) -> Fed:
  Cell{id, alive, x, y, dir, mass, respawn, seen} = c
  +sx = random(seed)
  +sy = random(sx)
  Fed{Cell{id, alive, x, y, dir, (mass + 1 : U32), respawn, seen}, food_at(sx, sy) <> kept, sy}

def cell_feed.meal(m: Meal, +c: Cell, +seed: U32) -> Fed:
  match m:
    case Meal{True{}, kept}:
      cell_feed.ate(c, kept, seed)
    case Meal{False{}, kept}:
      Fed{c, kept, seed}

def cell_feed(+c: Cell, +points: List<&2, Point>, +seed: U32) -> Fed:
  Cell{id, +alive, +x, +y, dir, +mass, respawn, seen} = c
  Bool.pick(Fed, U32.is_zero(alive), Fed{c, points, seed},
    cell_feed.meal(list_meal(points, Point{x, y}, cell_radius(mass)), c, seed))

def cell_mass(c: Cell) -> U32:
  match c:
    case Cell{id, alive, x, y, dir, mass, respawn, seen}:
      mass

def cell_grow(c: Cell, +by: U32) -> Cell:
  match c:
    case Cell{id, alive, x, y, dir, mass, respawn, seen}:
      Cell{id, alive, x, y, dir, (mass + by + 3 : U32), respawn, seen}

# Two touching live cells: one at least three mass larger absorbs the other.
def cell_duel(+left: Cell, +right: Cell) -> Duel:
  Cell{li, +la, +lx, +ly, ld, +lm, lr, ls} = left
  Cell{ri, +ra, +rx, +ry, rd, +rm, rr, rs} = right
  +close = point_near(Point{lx, ly}, Point{rx, ry}, (14 + U32.max(U32.min(lm, 34), U32.min(rm, 34)) : U32))
  +fight = Bool.not(U32.is_zero(la)) && Bool.not(U32.is_zero(ra)) && close
  Bool.pick(Duel, fight && U32.is_gt(lm, (rm + 2 : U32)), Duel{cell_grow(left, rm), cell_kill(right)},
  Bool.pick(Duel, fight && U32.is_gt(rm, (lm + 2 : U32)), Duel{cell_kill(left), cell_grow(right, lm)},
    Duel{left, right}))

def cell_json(c: Cell, slot: U32) -> String:
  match c:
    case Cell{id, alive, x, y, dir, mass, respawn, seen}:
      HTTP.json_object([
        ("slot", U32.show(slot)),
        ("joined", U32.show(Bool.to_u32(Bool.not(U32.is_zero(id))))),
        ("alive", U32.show(alive)),
        ("x", U32.show(x)),
        ("y", U32.show(y)),
        ("dir", U32.show(dir)),
        ("mass", U32.show(mass)),
        ("respawn", U32.show(respawn))])

# ---------------------------------------------------------------- Game

def game_empty.go(s: Supply, now: U32) -> Game:
  match s:
    case Supply{points, out}:
      Game{cell_empty(), cell_empty(), cell_empty(), cell_empty(), points, out, now, 0}

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
      Game{cell_expire(one, now), cell_expire(two, now), cell_expire(three, now), cell_expire(four, now), food, seed, at, tick}

# The rest of a game (food and clocks) while the cells are being resolved.
type Rest is Data:
  Rest{food: List<&2, Point>, seed: U32, at: U32, tick: U32}

# Duels in the order 1-2, 1-3, 1-4, 2-3, 2-4, 3-4.
def duel.d34(d: Duel, f1: Cell, f2: Cell, r: Rest) -> Game:
  match d r:
    case Duel{f3, f4} Rest{food, seed, at, tick}:
      Game{f1, f2, f3, f4, food, seed, at, (tick + 1 : U32)}

def duel.d24(d: Duel, f1: Cell, b3: Cell, r: Rest) -> Game:
  match d:
    case Duel{f2, b4}:
      duel.d34(cell_duel(b3, b4), f1, f2, r)

def duel.d23(d: Duel, f1: Cell, a4: Cell, r: Rest) -> Game:
  match d:
    case Duel{b2, b3}:
      duel.d24(cell_duel(b2, a4), f1, b3, r)

def duel.d14(d: Duel, a2: Cell, a3: Cell, r: Rest) -> Game:
  match d:
    case Duel{f1, a4}:
      duel.d23(cell_duel(a2, a3), f1, a4, r)

def duel.d13(d: Duel, a2: Cell, c4: Cell, r: Rest) -> Game:
  match d:
    case Duel{b1, a3}:
      duel.d14(cell_duel(b1, c4), a2, a3, r)

def duel.d12(d: Duel, c3: Cell, c4: Cell, r: Rest) -> Game:
  match d:
    case Duel{a1, a2}:
      duel.d13(cell_duel(a1, c3), a2, c4, r)

def game_step.done(n1: Cell, n2: Cell, n3: Cell, f: Fed, at: U32, tick: U32) -> Game:
  match f:
    case Fed{n4, food, seed}:
      duel.d12(cell_duel(n1, n2), n3, n4, Rest{food, seed, at, tick})

def game_step.four(n1: Cell, n2: Cell, f: Fed, c4: Cell, at: U32, tick: U32) -> Game:
  match f:
    case Fed{n3, food, seed}:
      game_step.done(n1, n2, n3, cell_feed(c4, food, seed), at, tick)

def game_step.three(n1: Cell, f: Fed, c3: Cell, c4: Cell, at: U32, tick: U32) -> Game:
  match f:
    case Fed{n2, food, seed}:
      game_step.four(n1, n2, cell_feed(c3, food, seed), c4, at, tick)

def game_step.two(f: Fed, c2: Cell, c3: Cell, c4: Cell, at: U32, tick: U32) -> Game:
  match f:
    case Fed{n1, food, seed}:
      game_step.three(n1, cell_feed(c2, food, seed), c3, c4, at, tick)

# One tick: move every cell, feed them in slot order, then resolve duels.
def game_step(g: Game) -> Game:
  match g:
    case Game{one, two, three, four, food, seed, at, tick}:
      game_step.two(cell_feed(cell_step(one, 1), food, seed), cell_step(two, 2), cell_step(three, 3), cell_step(four, 4), at, tick)

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
  Bool.pick(U32, live && U32.is_eq(cell_id(one), player), 1,
  Bool.pick(U32, live && U32.is_eq(cell_id(two), player), 2,
  Bool.pick(U32, live && U32.is_eq(cell_id(three), player), 3,
  Bool.pick(U32, live && U32.is_eq(cell_id(four), player), 4, 0))))

def game_touch(g: Game, +player: U32, +now: U32) -> Game:
  match g:
    case Game{one, two, three, four, food, seed, at, tick}:
      Game{cell_touch(one, player, now), cell_touch(two, player, now), cell_touch(three, player, now), cell_touch(four, player, now), food, seed, at, tick}

def fail(g: Game, note: String) -> Action:
  Action{g, 0, note}

def ok(g: Game) -> Action:
  Action{g, 1, ""}

def game_join_open(+g: Game, +player: U32, +now: U32) -> Action:
  Game{+one, +two, +three, +four, +food, +seed, +at, +tick} = g
  Bool.pick(Action, Bool.not(cell_joined(one)), ok(Game{cell_spawn(1, player, now), two, three, four, food, seed, at, tick}),
  Bool.pick(Action, Bool.not(cell_joined(two)), ok(Game{one, cell_spawn(2, player, now), three, four, food, seed, at, tick}),
  Bool.pick(Action, Bool.not(cell_joined(three)), ok(Game{one, two, cell_spawn(3, player, now), four, food, seed, at, tick}),
  Bool.pick(Action, Bool.not(cell_joined(four)), ok(Game{one, two, three, cell_spawn(4, player, now), food, seed, at, tick}),
    fail(g, "The arena already has four players.")))))

def game_join(+g: Game, +player: U32, +now: U32) -> Action:
  Bool.pick(Action, U32.is_zero(player), fail(g, "Invalid player identity."),
  Bool.pick(Action, U32.is_zero(game_player(g, player)), game_join_open(g, player, now),
    ok(game_touch(g, player, now))))

def game_input.go(g: Game, +player: U32, +heading: U32, +now: U32) -> Game:
  match g:
    case Game{one, two, three, four, food, seed, at, tick}:
      Game{cell_input(one, player, heading, now), cell_input(two, player, heading, now),
        cell_input(three, player, heading, now), cell_input(four, player, heading, now), food, seed, at, tick}

def game_input(+g: Game, +player: U32, heading: U32, now: U32) -> Action:
  Bool.pick(Action, U32.is_zero(game_player(g, player)), fail(g, "Join the game before moving."),
    ok(game_input.go(g, player, heading, now)))

def game_state(g: Game, player: U32, now: U32) -> Action:
  ok(game_touch(g, player, now))

def game_leave.go(g: Game, +player: U32) -> Game:
  match g:
    case Game{one, two, three, four, food, seed, at, tick}:
      Game{cell_leave(one, player), cell_leave(two, player), cell_leave(three, player), cell_leave(four, player), food, seed, at, tick}

def game_leave(+g: Game, +player: U32) -> Action:
  Bool.pick(Action, U32.is_zero(game_player(g, player)), fail(g, "This browser has not joined the game."),
    ok(game_leave.go(g, player)))

def game_json(+g: Game, +player: U32, ok: U32, note: String) -> String:
  Game{+one, +two, +three, +four, food, seed, at, tick} = g
  HTTP.json_object([
    ("ok", U32.show(ok)),
    ("note", HTTP.quoted(note)),
    ("you", U32.show(game_player(g, player))),
    ("full", U32.show(Bool.to_u32(cell_joined(one) && cell_joined(two) && cell_joined(three) && cell_joined(four)))),
    ("tick", U32.show(tick)),
    ("players", HTTP.json_array([cell_json(one, 1), cell_json(two, 2), cell_json(three, 3), cell_json(four, 4)])),
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
    r : Result<&1, &1, U32 & String, String> <- HTTP.read_text("Bend3/demos/agar_web/index.html")
    return (g, page_reply(r))

# Drop the hub prefix "cells" when present.
def unprefix(segs: List<&2, String>) -> List<&2, String>:
  match segs:
    case Nil{}:
      Nil{}
    case +h <> +t:
      Bool.pick(List<&2, String>, String.eq(h, "cells"), t, h <> t)

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
    IO.print("cell arena listening on all interfaces (0.0.0.0:8084)")
    IO.print("open http://<server-lan-ip>:8084 on up to four devices (run from the repository root)")
    HTTP.serve(~Game, ~route, "0.0.0.0", 8084, g)
