# Generated hub-private namespace from ../tictactoe_web/web_tictactoe.bend.
# Regenerate after changing the standalone source.

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

import ../../../bend-base/Base
import ../../Compat
import ../../../bend-base/IO/TCP
import ../../../bend-base/IO/HTTP

type Tic.Game:
  Game{x: U32, o: U32, board: U32, moves: U32, turn: U32, winner: U32, round: U32, x_again: U32, o_again: U32}

type Tic.Action:
  Action{game: Tic.Game, ok: U32, note: String}

type Tic.Routed:
  Routed{game: Tic.Game, response: HTTP.Response}

# ---------------------------------------------------------------- board
# The board is a base-3 U32: digit 0 is empty, 1 is X, and 2 is O.

def Tic.u32_pow3(n: U32) -> U32:
  match n:
    case 0:
      1
    case k:
      3 * Tic.u32_pow3(k - 1)

def Tic.u32_cell(board: U32, cell: U32) -> U32:
  (board / Tic.u32_pow3(cell)) % 3

def Tic.u32_place(board: U32, cell: U32, mark: U32) -> U32:
  board + (mark * Tic.u32_pow3(cell))

def Tic.u32_line(board: U32, mark: U32, a: U32, b: U32, c: U32) -> U32:
  ((Tic.u32_cell(board, a) == mark) && (Tic.u32_cell(board, b) == mark)) && (Tic.u32_cell(board, c) == mark)

def Tic.u32_win(board: U32, mark: U32) -> U32:
  Tic.u32_line(board, mark, 0, 1, 2) || (
  Tic.u32_line(board, mark, 3, 4, 5) || (
  Tic.u32_line(board, mark, 6, 7, 8) || (
  Tic.u32_line(board, mark, 0, 3, 6) || (
  Tic.u32_line(board, mark, 1, 4, 7) || (
  Tic.u32_line(board, mark, 2, 5, 8) || (
  Tic.u32_line(board, mark, 0, 4, 8) ||
  Tic.u32_line(board, mark, 2, 4, 6)))))))

def Tic.u32_board_json_go(board: U32, cell: U32, left: U32) -> String:
  match left:
    case 0:
      "]"
    case k:
      tail = Tic.u32_board_json_go(board, cell + 1, k - 1)
      match k == 1:
        case 0:
          String.flatten([String.from_u32(Tic.u32_cell(board, cell)), ",", tail])
        case j:
          String.concat(String.from_u32(Tic.u32_cell(board, cell)), tail)

def Tic.u32_board_json(board: U32) -> String:
  String.concat("[", Tic.u32_board_json_go(board, 0, 9))

# ---------------------------------------------------------------- game

def Tic.game_empty() -> Tic.Game:
  Tic.Game.Game{0, 0, 0, 0, 1, 0, 1, 0, 0}

def Tic.game_player(game: Tic.Game, player: U32) -> U32:
  match game:
    case Tic.Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}:
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

def Tic.game_started(game: Tic.Game) -> U32:
  match game:
    case Tic.Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}:
      (x > 0) && (o > 0)

def Tic.game_error(game: Tic.Game, note: String) -> Tic.Action:
  Tic.Action.Action{game, 0, note}

def Tic.game_ok(game: Tic.Game) -> Tic.Action:
  Tic.Action.Action{game, 1, ""}

def Tic.game_join_open(game: Tic.Game, mark: U32, player: U32) -> Tic.Action:
  match game:
    case Tic.Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}:
      match mark:
        case 1:
          match x:
            case 0:
              Tic.game_ok(Tic.Game.Game{player, o, board, moves, turn, winner, round, x_again, o_again})
            case p:
              Tic.game_error(Tic.Game.Game{p, o, board, moves, turn, winner, round, x_again, o_again}, "X is already taken.")
        case 2:
          match o:
            case 0:
              Tic.game_ok(Tic.Game.Game{x, player, board, moves, turn, winner, round, x_again, o_again})
            case p:
              Tic.game_error(Tic.Game.Game{x, p, board, moves, turn, winner, round, x_again, o_again}, "O is already taken.")
        case k:
          Tic.game_error(Tic.Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}, "Choose X or O.")

def Tic.game_join(game: Tic.Game, mark: U32, player: U32) -> Tic.Action:
  match player:
    case 0:
      Tic.game_error(game, "Invalid player identity.")
    case p:
      current = Tic.game_player(game, p)
      match current:
        case 0:
          Tic.game_join_open(game, mark, p)
        case own:
          match own == mark:
            case 0:
              Tic.game_error(game, "This browser already chose the other symbol.")
            case k:
              Tic.game_ok(game)

def Tic.game_move_commit(game: Tic.Game, mark: U32, cell: U32) -> Tic.Action:
  match game:
    case Tic.Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}:
      board2 = Tic.u32_place(board, cell, mark)
      moves2 = moves + 1
      match Tic.u32_win(board2, mark):
        case 0:
          match moves2 == 9:
            case 0:
              Tic.game_ok(Tic.Game.Game{x, o, board2, moves2, 3 - mark, 0, round, 0, 0})
            case k:
              Tic.game_ok(Tic.Game.Game{x, o, board2, moves2, mark, 3, round, 0, 0})
        case k:
          Tic.game_ok(Tic.Game.Game{x, o, board2, moves2, mark, mark, round, 0, 0})

def Tic.game_move_started(game: Tic.Game, mark: U32, cell: U32) -> Tic.Action:
  match game:
    case Tic.Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}:
      match winner:
        case 0:
          match turn == mark:
            case 0:
              Tic.game_error(Tic.Game.Game{x, o, board, moves, turn, 0, round, x_again, o_again}, "It is not your turn.")
            case k:
              match cell < 9:
                case 0:
                  Tic.game_error(Tic.Game.Game{x, o, board, moves, turn, 0, round, x_again, o_again}, "That square is outside the board.")
                case j:
                  match Tic.u32_cell(board, cell):
                    case 0:
                      Tic.game_move_commit(Tic.Game.Game{x, o, board, moves, turn, 0, round, x_again, o_again}, mark, cell)
                    case used:
                      Tic.game_error(Tic.Game.Game{x, o, board, moves, turn, 0, round, x_again, o_again}, "That square is already taken.")
        case done:
          Tic.game_error(Tic.Game.Game{x, o, board, moves, turn, done, round, x_again, o_again}, "This round is finished.")

def Tic.game_move(game: Tic.Game, player: U32, cell: U32) -> Tic.Action:
  mark = Tic.game_player(game, player)
  match mark:
    case 0:
      Tic.game_error(game, "Choose X or O before making a move.")
    case own:
      match Tic.game_started(game):
        case 0:
          Tic.game_error(game, "Waiting for the other player.")
        case k:
          Tic.game_move_started(game, own, cell)

def Tic.game_again_player(game: Tic.Game, mark: U32) -> Tic.Action:
  match game:
    case Tic.Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}:
      match winner:
        case 0:
          Tic.game_error(Tic.Game.Game{x, o, board, moves, turn, 0, round, x_again, o_again}, "Finish this round before asking for a rematch.")
        case done:
          xa2 = x_again || (mark == 1)
          oa2 = o_again || (mark == 2)
          match xa2 && oa2:
            case 0:
              Tic.game_ok(Tic.Game.Game{x, o, board, moves, turn, done, round, xa2, oa2})
            case k:
              Tic.game_ok(Tic.Game.Game{x, o, 0, 0, 1, 0, round + 1, 0, 0})

def Tic.game_again(game: Tic.Game, player: U32) -> Tic.Action:
  mark = Tic.game_player(game, player)
  match mark:
    case 0:
      Tic.game_error(game, "Choose X or O before asking for a rematch.")
    case own:
      Tic.game_again_player(game, own)

def Tic.game_leave(game: Tic.Game, player: U32) -> Tic.Action:
  mark = Tic.game_player(game, player)
  match game:
    case Tic.Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}:
      match mark:
        case 1:
          Tic.game_ok(Tic.Game.Game{0, o, 0, 0, 1, 0, round + 1, 0, 0})
        case 2:
          Tic.game_ok(Tic.Game.Game{x, 0, 0, 0, 1, 0, round + 1, 0, 0})
        case k:
          Tic.game_error(Tic.Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}, "This browser has not joined the game.")

# ---------------------------------------------------------------- json and routing

def Tic.game_json(game: Tic.Game, player: U32, ok: U32, note: String) -> String:
  match game:
    case Tic.Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}:
      String.flatten([
        "{\"ok\":", String.from_u32(ok),
        ",\"note\":\"", note,
        "\",\"you\":", String.from_u32(Tic.game_player(Tic.Game.Game{x, o, board, moves, turn, winner, round, x_again, o_again}, player)),
        ",\"x\":", String.from_u32(x > 0),
        ",\"o\":", String.from_u32(o > 0),
        ",\"started\":", String.from_u32((x > 0) && (o > 0)),
        ",\"board\":", Tic.u32_board_json(board),
        ",\"turn\":", String.from_u32(turn),
        ",\"winner\":", String.from_u32(winner),
        ",\"round\":", String.from_u32(round),
        ",\"xAgain\":", String.from_u32(x_again),
        ",\"oAgain\":", String.from_u32(o_again),
        "}"
      ])

def Tic.game_response(game: Tic.Game, player: U32, ok: U32, note: String) -> HTTP.Response:
  HTTP.Response.Response{200,
    [HTTP.Header.Header{"Content-Type", "application/json; charset=utf-8"},
     HTTP.Header.Header{"Cache-Control", "no-store, no-cache, must-revalidate"}],
    Bytes.from_string(Tic.game_json(game, player, ok, note))}

def Tic.game_routed(game: Tic.Game, player: U32) -> Tic.Routed:
  Tic.Routed.Routed{game, Tic.game_response(game, player, 1, "")}

def Tic.game_missing(game: Tic.Game) -> Tic.Routed:
  Tic.Routed.Routed{game, HTTP.not_found()}

def Tic.game_method(game: Tic.Game) -> Tic.Routed:
  Tic.Routed.Routed{game, HTTP.reply(405, "text/plain; charset=utf-8", "Method Not Allowed\n")}

def Tic.action_routed(action: Tic.Action, player: U32) -> Tic.Routed:
  match action:
    case Tic.Action.Action{game, ok, note}:
      Tic.Routed.Routed{game, Tic.game_response(game, player, ok, note)}

def Tic.result_index(result: Result((U32 & String), String), game: Tic.Game) -> IO(Tic.Routed):
  match result:
    case Result.Done{html}:
      IO.pure(Tic.Routed, Tic.Routed.Routed{game, HTTP.reply(200, "text/html; charset=utf-8", html)})
    case Result.Fail{(code, error)}:
      IO.pure(Tic.Routed, Tic.Routed.Routed{game, HTTP.reply(500, "text/plain; charset=utf-8", "index.html not found -- run the server from the repository root\n")})

def Tic.game_index(game: Tic.Game) -> IO(Tic.Routed):
  do IO(Tic.Routed):
    result <- IO.read_text("gabriel_demos/tictactoe_web/index.html")
    Tic.result_index(result, game)

def Tic.string_mark(name: String) -> U32:
  match String.eq_u32(name, "x"):
    case 0:
      match String.eq_u32(name, "o"):
        case 0:
          0
        case k:
          2
    case k:
      1

def Tic.list_state(args: List(String), game: Tic.Game) -> IO(Tic.Routed):
  match args:
    case List.Cons{player, rest}:
      IO.pure(Tic.Routed, Tic.game_routed(game, String.to_u32(player)))
    case List.Nil{}:
      IO.pure(Tic.Routed, Tic.game_missing(game))

def Tic.list_join(args: List(String), game: Tic.Game) -> IO(Tic.Routed):
  match args:
    case List.Cons{mark, List.Cons{player, rest}}:
      id = String.to_u32(player)
      IO.pure(Tic.Routed, Tic.action_routed(Tic.game_join(game, Tic.string_mark(mark), id), id))
    case other:
      IO.pure(Tic.Routed, Tic.game_missing(game))

def Tic.list_move(args: List(String), game: Tic.Game) -> IO(Tic.Routed):
  match args:
    case List.Cons{player, List.Cons{cell, rest}}:
      id = String.to_u32(player)
      IO.pure(Tic.Routed, Tic.action_routed(Tic.game_move(game, id, String.to_u32(cell)), id))
    case other:
      IO.pure(Tic.Routed, Tic.game_missing(game))

def Tic.list_again(args: List(String), game: Tic.Game) -> IO(Tic.Routed):
  match args:
    case List.Cons{player, rest}:
      id = String.to_u32(player)
      IO.pure(Tic.Routed, Tic.action_routed(Tic.game_again(game, id), id))
    case List.Nil{}:
      IO.pure(Tic.Routed, Tic.game_missing(game))

def Tic.list_leave(args: List(String), game: Tic.Game) -> IO(Tic.Routed):
  match args:
    case List.Cons{player, rest}:
      id = String.to_u32(player)
      IO.pure(Tic.Routed, Tic.action_routed(Tic.game_leave(game, id), id))
    case List.Nil{}:
      IO.pure(Tic.Routed, Tic.game_missing(game))

def Tic.string_route(name: String, args: List(String), game: Tic.Game) -> IO(Tic.Routed):
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
                          IO.pure(Tic.Routed, Tic.game_missing(game))
                        case k:
                          Tic.list_leave(args, game)
                    case k:
                      Tic.list_again(args, game)
                case k:
                  Tic.list_move(args, game)
            case k:
              Tic.list_join(args, game)
        case k:
          Tic.list_state(args, game)
    case k:
      Tic.game_index(game)

def Tic.list_route(parts: List(String), game: Tic.Game) -> IO(Tic.Routed):
  match parts:
    case List.Cons{root, List.Cons{name, args}}:
      Tic.string_route(name, args, game)
    case List.Cons{root, List.Nil{}}:
      Tic.game_index(game)
    case List.Nil{}:
      Tic.game_index(game)

def Tic.request_route(request: HTTP.Request, game: Tic.Game) -> IO(Tic.Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(method, "GET"):
        case 0:
          IO.pure(Tic.Routed, Tic.game_method(game))
        case k:
          Tic.list_route(String.split('/', path), game)

# ---------------------------------------------------------------- server

def Tic.routed_send(routed: Tic.Routed, server: TCP, conn: HTTP) -> IO(U32):
  match routed:
    case Tic.Routed.Routed{game, response}:
      do IO(U32):
        sent <- HTTP.send_response(conn, HTTP.with_connection(0, response))
        closed <- HTTP.close(conn)
        Tic.u32_serve(server, game)

def Tic.inbound_serve(inbound: HTTP.Inbound, server: TCP, conn: HTTP, game: Tic.Game) -> IO(U32):
  match inbound:
    case HTTP.Inbound.Got{http11, request, rest}:
      do IO(U32):
        routed <- Tic.request_route(request, game)
        Tic.routed_send(routed, server, conn)
    case HTTP.Inbound.Closed{}:
      do IO(U32):
        closed <- HTTP.close(conn)
        Tic.u32_serve(server, game)
    case HTTP.Inbound.Bad{code, error}:
      Tic.routed_send(Tic.Routed.Routed{game, HTTP.reply_error(code, error)}, server, conn)

def Tic.result_accept(result: Result((U32 & String), TCP), server: TCP, game: Tic.Game) -> IO(U32):
  match result:
    case Result.Done{fd}:
      do IO(U32):
        inbound <- HTTP.recv_request(HTTP.Plain{fd}, List.Nil{})
        Tic.inbound_serve(inbound, server, HTTP.Plain{fd}, game)
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["accept failed: ", error, "\n"]))
        return 1

def Tic.u32_serve(server: TCP, game: Tic.Game) -> IO(U32):
  do IO(U32):
    result <- TCP.accept(server)
    Tic.result_accept(result, server, game)

def Tic.result_main(result: Result((U32 & String), TCP)) -> IO(U32):
  match result:
    case Result.Done{server}:
      do IO(U32):
        printed <- IO.write("tic-tac-toe listening on all interfaces (0.0.0.0:8082)\nopen http://<server-lan-ip>:8082 from either device\n")
        Tic.u32_serve(server, Tic.game_empty())
    case Result.Fail{(code, error)}:
      do IO(U32):
        printed <- IO.print_err(String.flatten(["listen failed: ", error, "\n"]))
        return 1

def Tic.main() -> IO(U32):
  do IO(U32):
    result <- TCP.listen(8082)
    Tic.result_main(result)
