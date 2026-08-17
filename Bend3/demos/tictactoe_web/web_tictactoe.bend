# web_tictactoe: two-player tic-tac-toe over the local network.
#
# The Bend process owns one game. Browsers choose X or O,
# poll the shared state, and submit moves. Each HTTP connection serves
# exactly one request and closes: base/HTTP's keep-alive handler is ideal
# for stateless apps, but a stateful sequential server must carry the new
# Game value back to the accept loop after every request.
#
# routes:
#   GET /                    the page (run from the repository root)
#   GET /state/<player>      current game as JSON
#   GET /join/<x|o>/<player> choose an available symbol
#   GET /move/<player>/<cell> place at cell 0..8
#   GET /again/<player>      request a rematch after a finished round
#   GET /leave/<player>      leave the game and clear the board
#
# build: bun bend-ts/src/bend.ts gabriel_demos/tictactoe_web/web_tictactoe.bend --no-halt -o gabriel_demos/tictactoe_web/web_tictactoe
# run:   ./gabriel_demos/tictactoe_web/web_tictactoe
# open:  http://<server-lan-ip>:8082
#
# no-halt
# skip-native

import ../../bend-base/Base
import ../Compat
import ../../bend-base/IO/TCP
import ../../bend-base/IO/HTTP

type Game:
  Game{x: U32, o: U32, board: U32, moves: U32, turn: U32, winner: U32, round: U32, x_again: U32, o_again: U32}

type Action:
  Action{game: Game, ok: U32, note: String}

type Routed:
  Routed{game: Game, response: HTTP.Response}

# ---------------------------------------------------------------- board
# The board is a base-3 U32: digit 0 is empty, 1 is X, and 2 is O.

def u32_pow3(n: U32) -> U32:
  match n:
    case 0:
      1
    case k:
      3 * u32_pow3(k - 1)

def u32_cell(board: U32, cell: U32) -> U32:
  (board / u32_pow3(cell)) % 3

def u32_place(board: U32, cell: U32, mark: U32) -> U32:
  board + (mark * u32_pow3(cell))

def u32_line(board: U32, mark: U32, a: U32, b: U32, c: U32) -> U32:
  ((u32_cell(board, a) == mark) && (u32_cell(board, b) == mark)) && (u32_cell(board, c) == mark)

def u32_win(board: U32, mark: U32) -> U32:
  u32_line(board, mark, 0, 1, 2) || (
  u32_line(board, mark, 3, 4, 5) || (
  u32_line(board, mark, 6, 7, 8) || (
  u32_line(board, mark, 0, 3, 6) || (
  u32_line(board, mark, 1, 4, 7) || (
  u32_line(board, mark, 2, 5, 8) || (
  u32_line(board, mark, 0, 4, 8) ||
  u32_line(board, mark, 2, 4, 6)))))))

def u32_board_json_go(board: U32, cell: U32, left: U32) -> String:
  match left:
    case 0:
      "]"
    case k:
      tail = u32_board_json_go(board, cell + 1, k - 1)
      match k == 1:
        case 0:
          String.flatten([String.from_u32(u32_cell(board, cell)), ",", tail])
        case j:
          String.concat(String.from_u32(u32_cell(board, cell)), tail)

def u32_board_json(board: U32) -> String:
  String.concat("[", u32_board_json_go(board, 0, 9))

# ---------------------------------------------------------------- game

def game_empty() -> Game:
  Game.Game{0, 0, 0, 0, 1, 0, 1, 0, 0}

def game_player(game: Game, player: U32) -> U32:
  match game:
    case Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}:
      match player:
        case 0:
          0
        case p:
          match p == x:
            case 0:
              match p == o:
                case 0:
                  0
                case k:
                  2
            case k:
              1

def game_started(game: Game) -> U32:
  match game:
    case Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}:
      (x > 0) && (o > 0)

def game_error(game: Game, note: String) -> Action:
  Action.Action{game, 0, note}

def game_ok(game: Game) -> Action:
  Action.Action{game, 1, ""}

def game_join_open(game: Game, mark: U32, player: U32) -> Action:
  match game:
    case Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}:
      match mark:
        case 1:
          match x:
            case 0:
              game_ok(Game.Game{player, o, board, moves, turn, winner, round, x_again, o_again})
            case p:
              game_error(Game.Game{p, o, board, moves, turn, winner, round, x_again, o_again}, "X is already taken.")
        case 2:
          match o:
            case 0:
              game_ok(Game.Game{x, player, board, moves, turn, winner, round, x_again, o_again})
            case p:
              game_error(Game.Game{x, p, board, moves, turn, winner, round, x_again, o_again}, "O is already taken.")
        case k:
          game_error(Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}, "Choose X or O.")

def game_join(game: Game, mark: U32, player: U32) -> Action:
  match player:
    case 0:
      game_error(game, "Invalid player identity.")
    case p:
      current = game_player(game, p)
      match current:
        case 0:
          game_join_open(game, mark, p)
        case own:
          match own == mark:
            case 0:
              game_error(game, "This browser already chose the other symbol.")
            case k:
              game_ok(game)

def game_move_commit(game: Game, mark: U32, cell: U32) -> Action:
  match game:
    case Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}:
      board2 = u32_place(board, cell, mark)
      moves2 = moves + 1
      match u32_win(board2, mark):
        case 0:
          match moves2 == 9:
            case 0:
              game_ok(Game.Game{x, o, board2, moves2, 3 - mark, 0, round, 0, 0})
            case k:
              game_ok(Game.Game{x, o, board2, moves2, mark, 3, round, 0, 0})
        case k:
          game_ok(Game.Game{x, o, board2, moves2, mark, mark, round, 0, 0})

def game_move_started(game: Game, mark: U32, cell: U32) -> Action:
  match game:
    case Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}:
      match winner:
        case 0:
          match turn == mark:
            case 0:
              game_error(Game.Game{x, o, board, moves, turn, 0, round, x_again, o_again}, "It is not your turn.")
            case k:
              match cell < 9:
                case 0:
                  game_error(Game.Game{x, o, board, moves, turn, 0, round, x_again, o_again}, "That square is outside the board.")
                case j:
                  match u32_cell(board, cell):
                    case 0:
                      game_move_commit(Game.Game{x, o, board, moves, turn, 0, round, x_again, o_again}, mark, cell)
                    case used:
                      game_error(Game.Game{x, o, board, moves, turn, 0, round, x_again, o_again}, "That square is already taken.")
        case done:
          game_error(Game.Game{x, o, board, moves, turn, done, round, x_again, o_again}, "This round is finished.")

def game_move(game: Game, player: U32, cell: U32) -> Action:
  mark = game_player(game, player)
  match mark:
    case 0:
      game_error(game, "Choose X or O before making a move.")
    case own:
      match game_started(game):
        case 0:
          game_error(game, "Waiting for the other player.")
        case k:
          game_move_started(game, own, cell)

def game_again_player(game: Game, mark: U32) -> Action:
  match game:
    case Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}:
      match winner:
        case 0:
          game_error(Game.Game{x, o, board, moves, turn, 0, round, x_again, o_again}, "Finish this round before asking for a rematch.")
        case done:
          xa2 = x_again || (mark == 1)
          oa2 = o_again || (mark == 2)
          match xa2 && oa2:
            case 0:
              game_ok(Game.Game{x, o, board, moves, turn, done, round, xa2, oa2})
            case k:
              game_ok(Game.Game{x, o, 0, 0, 1, 0, round + 1, 0, 0})

def game_again(game: Game, player: U32) -> Action:
  mark = game_player(game, player)
  match mark:
    case 0:
      game_error(game, "Choose X or O before asking for a rematch.")
    case own:
      game_again_player(game, own)

def game_leave(game: Game, player: U32) -> Action:
  mark = game_player(game, player)
  match game:
    case Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}:
      match mark:
        case 1:
          game_ok(Game.Game{0, o, 0, 0, 1, 0, round + 1, 0, 0})
        case 2:
          game_ok(Game.Game{x, 0, 0, 0, 1, 0, round + 1, 0, 0})
        case k:
          game_error(Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}, "This browser has not joined the game.")

# ---------------------------------------------------------------- json and routing

def game_json(game: Game, player: U32, ok: U32, note: String) -> String:
  match game:
    case Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}:
      String.flatten([
        "{\"ok\":", String.from_u32(ok),
        ",\"note\":\"", note,
        "\",\"you\":", String.from_u32(game_player(Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}, player)),
        ",\"x\":", String.from_u32(x > 0),
        ",\"o\":", String.from_u32(o > 0),
        ",\"started\":", String.from_u32((x > 0) && (o > 0)),
        ",\"board\":", u32_board_json(board),
        ",\"turn\":", String.from_u32(turn),
        ",\"winner\":", String.from_u32(winner),
        ",\"round\":", String.from_u32(round),
        ",\"xAgain\":", String.from_u32(x_again),
        ",\"oAgain\":", String.from_u32(o_again),
        "}"
      ])

def game_response(game: Game, player: U32, ok: U32, note: String) -> HTTP.Response:
  HTTP.Response.Response{200,
    [HTTP.Header.Header{"Content-Type", "application/json; charset=utf-8"},
     HTTP.Header.Header{"Cache-Control", "no-store, no-cache, must-revalidate"}],
    Bytes.from_string(game_json(game, player, ok, note))}

def game_routed(game: Game, player: U32) -> Routed:
  Routed.Routed{game, game_response(game, player, 1, "")}

def game_missing(game: Game) -> Routed:
  Routed.Routed{game, HTTP.not_found()}

def game_method(game: Game) -> Routed:
  Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")}

def action_routed(action: Action, player: U32) -> Routed:
  match action:
    case Action.Action{game, ok, note}:
      Routed.Routed{game, game_response(game, player, ok, note)}

def result_index(result: Result((U32 & String), String), game: Game) -> IO(Routed):
  match result:
    case Result.Done{html}:
      IO.pure(Routed, Routed.Routed{game, HTTP.reply(200, "text/html; charset=utf-8", html)})
    case Result.Fail{(code, error)}:
      IO.pure(Routed, Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run the server from the repository root\n")})

def game_index(game: Game) -> IO(Routed):
  do IO(Routed):
    result <- IO.read_text("gabriel_demos/tictactoe_web/index.html")
    result_index(result, game)

def string_mark(name: String) -> U32:
  match String.eq_u32(name, "x"):
    case 0:
      match String.eq_u32(name, "o"):
        case 0:
          0
        case k:
          2
    case k:
      1

def list_state(args: List(String), game: Game) -> IO(Routed):
  match args:
    case List.Cons{player, rest}:
      IO.pure(Routed, game_routed(game, String.to_u32(player)))
    case List.Nil{}:
      IO.pure(Routed, game_missing(game))

def list_join(args: List(String), game: Game) -> IO(Routed):
  match args:
    case List.Cons{mark, List.Cons{player, rest}}:
      id = String.to_u32(player)
      IO.pure(Routed, action_routed(game_join(game, string_mark(mark), id), id))
    case other:
      IO.pure(Routed, game_missing(game))

def list_move(args: List(String), game: Game) -> IO(Routed):
  match args:
    case List.Cons{player, List.Cons{cell, rest}}:
      id = String.to_u32(player)
      IO.pure(Routed, action_routed(game_move(game, id, String.to_u32(cell)), id))
    case other:
      IO.pure(Routed, game_missing(game))

def list_again(args: List(String), game: Game) -> IO(Routed):
  match args:
    case List.Cons{player, rest}:
      id = String.to_u32(player)
      IO.pure(Routed, action_routed(game_again(game, id), id))
    case List.Nil{}:
      IO.pure(Routed, game_missing(game))

def list_leave(args: List(String), game: Game) -> IO(Routed):
  match args:
    case List.Cons{player, rest}:
      id = String.to_u32(player)
      IO.pure(Routed, action_routed(game_leave(game, id), id))
    case List.Nil{}:
      IO.pure(Routed, game_missing(game))

def string_route(name: String, args: List(String), game: Game) -> IO(Routed):
  match String.eq_u32(name, ""):
    case 0:
      match String.eq_u32(name, "state"):
        case 0:
          match String.eq_u32(name, "join"):
            case 0:
              match String.eq_u32(name, "move"):
                case 0:
                  match String.eq_u32(name, "again"):
                    case 0:
                      match String.eq_u32(name, "leave"):
                        case 0:
                          IO.pure(Routed, game_missing(game))
                        case k:
                          list_leave(args, game)
                    case k:
                      list_again(args, game)
                case k:
                  list_move(args, game)
            case k:
              list_join(args, game)
        case k:
          list_state(args, game)
    case k:
      game_index(game)

def list_route(parts: List(String), game: Game) -> IO(Routed):
  match parts:
    case List.Cons{root, List.Cons{name, args}}:
      string_route(name, args, game)
    case List.Cons{root, List.Nil{}}:
      game_index(game)
    case List.Nil{}:
      game_index(game)

def request_route(request: HTTP.Request, game: Game) -> IO(Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(method, "GET"):
        case 0:
          IO.pure(Routed, game_method(game))
        case k:
          list_route(String.split('/', path), game)

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
        routed <- request_route(request, game)
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
        printed <- IO.write("tic-tac-toe listening on all interfaces (0.0.0.0:8082)\nopen http://<server-lan-ip>:8082 from either device\n")
        u32_serve(server, game_empty())
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def main() -> IO(U32):
  do IO(U32):
    result <- TCP.listen(8082)
    result_main(result)
