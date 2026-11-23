# web_tictactoe: two-player tic-tac-toe over the local network.
#
# The Bend process owns one game. Browsers choose X or O, poll the shared
# state, and submit moves. ../HTTP.bend runs one state owner: every request
# is folded into the Game value in arrival order, and every response closes
# its connection.
#
# routes (each also answers under the hub prefix /tic, which the page uses):
#   GET /                     the page (run from the repository root)
#   GET /state/<player>       current game as JSON
#   GET /join/<x|o>/<player>  choose an available symbol
#   GET /move/<player>/<cell> place at cell 0..8
#   GET /again/<player>       request a rematch after a finished round
#   GET /leave/<player>       leave the game and clear the board
#
# Hub interface: `Game`, `init()`, and `route(req, game)`; `route` accepts
# paths with or without the leading `/tic`.
#
# build: bend Bend3/demos/tictactoe_web/web_tictactoe.bend -o Bend3/demos/tictactoe_web/build/web_tictactoe
# run:   ./Bend3/demos/tictactoe_web/build/web_tictactoe   (from the repository root)
# open:  http://<server-lan-ip>:8082
import Base
import ../HTTP.bend as HTTP
import ../Compat.bend as Compat

# x / o: the player ids holding each symbol (0 = free).
# board: base-3 digits, 0 empty, 1 X, 2 O. turn and winner use 1 = X,
# 2 = O; winner 3 is a draw, 0 an unfinished round.
type Game is Data:
  Game{x: U32, o: U32, board: U32, moves: U32, turn: U32, winner: U32, round: U32, x_again: U32, o_again: U32}

type Action is Data:
  Action{game: Game, ok: U32, note: String}

# ---------------------------------------------------------------- board

def pow3(c: U32) -> U32:
  match c:
    case 0:
      1
    case 1:
      3
    case 2:
      9
    case 3:
      27
    case 4:
      81
    case 5:
      243
    case 6:
      729
    case 7:
      2187
    case k:
      6561

def cell(+board: U32, c: U32) -> U32:
  ((board / pow3(c) : U32) % 3 : U32)

def place(+board: U32, c: U32, +mark: U32) -> U32:
  (board + mark * pow3(c) : U32)

def line(+board: U32, +mark: U32, a: U32, b: U32, c: U32) -> Bool:
  U32.is_eq(cell(board, a), mark) && U32.is_eq(cell(board, b), mark) && U32.is_eq(cell(board, c), mark)

def win(+board: U32, +mark: U32) -> Bool:
  line(board, mark, 0, 1, 2) || line(board, mark, 3, 4, 5) || line(board, mark, 6, 7, 8) ||
  line(board, mark, 0, 3, 6) || line(board, mark, 1, 4, 7) || line(board, mark, 2, 5, 8) ||
  line(board, mark, 0, 4, 8) || line(board, mark, 2, 4, 6)

def board_json(+board: U32) -> String:
  HTTP.json_array([
    U32.show(cell(board, 0)), U32.show(cell(board, 1)), U32.show(cell(board, 2)),
    U32.show(cell(board, 3)), U32.show(cell(board, 4)), U32.show(cell(board, 5)),
    U32.show(cell(board, 6)), U32.show(cell(board, 7)), U32.show(cell(board, 8))])

# ---------------------------------------------------------------- game

def init() -> Game:
  Game{0, 0, 0, 0, 1, 0, 1, 0, 0}

# The symbol (1 X, 2 O) a player holds, or 0.
def player_mark(+game: Game, +player: U32) -> U32:
  Game{+x, +o, board, moves, turn, winner, round, xa, oa} = game
  Bool.pick(U32, U32.is_zero(player), 0,
  Bool.pick(U32, U32.is_eq(player, x), 1,
  Bool.pick(U32, U32.is_eq(player, o), 2, 0)))

def started(+game: Game) -> Bool:
  Game{+x, +o, board, moves, turn, winner, round, xa, oa} = game
  Bool.not(U32.is_zero(x)) && Bool.not(U32.is_zero(o))

def fail(game: Game, note: String) -> Action:
  Action{game, 0, note}

def ok(game: Game) -> Action:
  Action{game, 1, ""}

def join_open(+game: Game, +mark: U32, +player: U32) -> Action:
  Game{+x, +o, +board, +moves, +turn, +winner, +round, +xa, +oa} = game
  Bool.pick(Action, U32.is_eq(mark, 1),
    Bool.pick(Action, U32.is_zero(x),
      ok(Game{player, o, board, moves, turn, winner, round, xa, oa}),
      fail(game, "X is already taken.")),
  Bool.pick(Action, U32.is_eq(mark, 2),
    Bool.pick(Action, U32.is_zero(o),
      ok(Game{x, player, board, moves, turn, winner, round, xa, oa}),
      fail(game, "O is already taken.")),
    fail(game, "Choose X or O.")))

def join(+game: Game, +mark: U32, +player: U32) -> Action:
  +own = player_mark(game, player)
  Bool.pick(Action, U32.is_zero(player), fail(game, "Invalid player identity."),
  Bool.pick(Action, U32.is_zero(own), join_open(game, mark, player),
  Bool.pick(Action, U32.is_eq(own, mark), ok(game),
    fail(game, "This browser already chose the other symbol."))))

def move_commit(+game: Game, +mark: U32, c: U32) -> Action:
  Game{x, o, board, moves, turn, winner, round, xa, oa} = game
  +board2 = place(board, c, mark)
  +moves2 = (moves + 1 : U32)
  Bool.pick(Action, win(board2, mark),
    ok(Game{x, o, board2, moves2, mark, mark, round, 0, 0}),
  Bool.pick(Action, U32.is_eq(moves2, 9),
    ok(Game{x, o, board2, moves2, mark, 3, round, 0, 0}),
    ok(Game{x, o, board2, moves2, (3 - mark : U32), 0, round, 0, 0})))

def move_started(+game: Game, +mark: U32, +c: U32) -> Action:
  Game{x, o, +board, moves, +turn, +winner, round, xa, oa} = game
  Bool.pick(Action, Bool.not(U32.is_zero(winner)), fail(game, "This round is finished."),
  Bool.pick(Action, Bool.not(U32.is_eq(turn, mark)), fail(game, "It is not your turn."),
  Bool.pick(Action, U32.is_ge(c, 9), fail(game, "That square is outside the board."),
  Bool.pick(Action, Bool.not(U32.is_zero(cell(board, c))), fail(game, "That square is already taken."),
    move_commit(game, mark, c)))))

def move(+game: Game, +player: U32, +c: U32) -> Action:
  +own = player_mark(game, player)
  Bool.pick(Action, U32.is_zero(own), fail(game, "Choose X or O before making a move."),
  Bool.pick(Action, Bool.not(started(game)), fail(game, "Waiting for the other player."),
    move_started(game, own, c)))

def again_player(+game: Game, +mark: U32) -> Action:
  Game{x, o, board, moves, turn, +winner, round, xa, oa} = game
  +xa2 = Bool.to_u32(Bool.not(U32.is_zero(xa)) || U32.is_eq(mark, 1))
  +oa2 = Bool.to_u32(Bool.not(U32.is_zero(oa)) || U32.is_eq(mark, 2))
  Bool.pick(Action, U32.is_zero(winner), fail(game, "Finish this round before asking for a rematch."),
  Bool.pick(Action, U32.is_eq(xa2, 1) && U32.is_eq(oa2, 1),
    ok(Game{x, o, 0, 0, 1, 0, (round + 1 : U32), 0, 0}),
    ok(Game{x, o, board, moves, turn, winner, round, xa2, oa2})))

def again(+game: Game, +player: U32) -> Action:
  +own = player_mark(game, player)
  Bool.pick(Action, U32.is_zero(own), fail(game, "Choose X or O before asking for a rematch."),
    again_player(game, own))

def leave(+game: Game, +player: U32) -> Action:
  Game{x, o, board, moves, turn, winner, +round, xa, oa} = game
  +own = player_mark(game, player)
  Bool.pick(Action, U32.is_eq(own, 1), ok(Game{0, o, 0, 0, 1, 0, (round + 1 : U32), 0, 0}),
  Bool.pick(Action, U32.is_eq(own, 2), ok(Game{x, 0, 0, 0, 1, 0, (round + 1 : U32), 0, 0}),
    fail(game, "This browser has not joined the game.")))

# ---------------------------------------------------------------- json

def game_json(+game: Game, +player: U32, ok: U32, note: String) -> String:
  Game{+x, +o, board, moves, turn, winner, round, xa, oa} = game
  HTTP.json_object([
    ("ok", U32.show(ok)),
    ("note", HTTP.quoted(note)),
    ("you", U32.show(player_mark(game, player))),
    ("x", U32.show(Bool.to_u32(Bool.not(U32.is_zero(x))))),
    ("o", U32.show(Bool.to_u32(Bool.not(U32.is_zero(o))))),
    ("started", U32.show(Bool.to_u32(started(game)))),
    ("board", board_json(board)),
    ("turn", U32.show(turn)),
    ("winner", U32.show(winner)),
    ("round", U32.show(round)),
    ("xAgain", U32.show(xa)),
    ("oAgain", U32.show(oa))])

def action_reply(a: Action, +player: U32) -> Game & HTTP.Response:
  Action{+game, ok, note} = a
  (game, HTTP.json(game_json(game, player, ok, note)))

# ---------------------------------------------------------------- routing

def mark_of(+name: String) -> U32:
  Bool.pick(U32, String.eq(name, "x"), 1, Bool.pick(U32, String.eq(name, "o"), 2, 0))

def arg(args: List<&2, String>, i: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, args, i), "")

def argc(args: List<&2, String>) -> U32:
  U32.from_nat(List.length(&2, String, args))

# A request the pure game logic answers: the action and whose view it is.
type Out is Data:
  Json{action: Action, player: U32}
  Missing{game: Game}

def dispatch(+name: String, +args: List<&2, String>, +game: Game) -> Out:
  +n = argc(args)
  +a0 = arg(args, 0n)
  +a1 = arg(args, 1n)
  +p0 = Compat.to_u32(a0)
  +p1 = Compat.to_u32(a1)
  Bool.pick(Out, String.eq(name, "state") && U32.is_ge(n, 1), Json{ok(game), p0},
  Bool.pick(Out, String.eq(name, "join") && U32.is_ge(n, 2), Json{join(game, mark_of(a0), p1), p1},
  Bool.pick(Out, String.eq(name, "move") && U32.is_ge(n, 2), Json{move(game, p0, p1), p0},
  Bool.pick(Out, String.eq(name, "again") && U32.is_ge(n, 1), Json{again(game, p0), p0},
  Bool.pick(Out, String.eq(name, "leave") && U32.is_ge(n, 1), Json{leave(game, p0), p0},
    Missing{game})))))

def respond(out: Out) -> IO(Game & HTTP.Response):
  match out:
    case Json{action, +player}:
      IO.pure(Game & HTTP.Response, action_reply(action, player))
    case Missing{game}:
      IO.pure(Game & HTTP.Response, (game, HTTP.not_found()))

def page_reply(r: Result<&1, &1, U32 & String, String>) -> HTTP.Response:
  match r:
    case Done{body}:
      HTTP.html(body)
    case Fail{e}:
      HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run the server from the repository root\n")

def index(game: Game) -> IO(Game & HTTP.Response):
  do IO<Game & HTTP.Response>:
    r : Result<&1, &1, U32 & String, String> <- HTTP.read_text("Bend3/demos/tictactoe_web/index.html")
    return (game, page_reply(r))

# Drop the hub prefix "tic" when present.
def unprefix(segs: List<&2, String>) -> List<&2, String>:
  match segs:
    case Nil{}:
      Nil{}
    case +h <> +t:
      Bool.pick(List<&2, String>, String.eq(h, "tic"), t, h <> t)

def route.segs(get: Bool, segs: List<&2, String>, game: Game) -> IO(Game & HTTP.Response):
  match get segs:
    case False{} _:
      IO.pure(Game & HTTP.Response, (game, HTTP.method_not_allowed()))
    case True{} Nil{}:
      index(game)
    case True{} name <> args:
      respond(dispatch(name, args, game))

def route(req: HTTP.Request, game: Game) -> IO(Game & HTTP.Response):
  HTTP.Request{method, target, headers, body} = req
  route.segs(String.eq(method, "GET"), unprefix(HTTP.segments(target)), game)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("tic-tac-toe listening on all interfaces (0.0.0.0:8082)")
    IO.print("open http://<server-lan-ip>:8082 from either device (run from the repository root)")
    HTTP.serve(~Game, ~route, "0.0.0.0", 8082, init())
