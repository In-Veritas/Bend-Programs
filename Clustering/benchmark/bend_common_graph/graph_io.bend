# Streaming reader and numeric-label writer for benchmark edge graphs.
import Base
import ../../lib/common.bend as C

type Parser is Type:
  Parser{rows: Array<C.Neighbors>, field: U32, value: U32,
    left: U32, right: U32, whole: U32, fraction: U32, places: U32,
    decimal: Bool, header: Bool}

law decimal_pad:
  for fuel: Nat
  for +value: U32
  for +places: U32
  U32

def decimal_pad(fuel, value, places):
  match fuel:
    case Zero{}:
      value
    case Succ{rest}:
      C.branch(U32, U32.is_ge(places, 6), \{
        True: value
        False: decimal_pad(rest, U32.mul(value, 10), U32.add(places, 1))
      })

law parser_reset:
  for rows: Array<C.Neighbors>
  Parser

def parser_reset(rows):
  Parser{rows, 0, 0, 0, 0, 0, 0, 0, False{}, False{}}

law parser_finish_row:
  for state: Parser
  for +size: U32
  Parser

def parser_finish_row(state, size):
  match state:
    case Parser{rows, field, value, +left, +right, +whole, fraction, places,
                decimal, header}:
      C.branch(Parser, header, \{
        True: parser_reset(rows)
        False: (
          +score = {C.branch(U32, U32.is_eq(whole, 1), \{
            True: 1000000
            False: decimal_pad(6n, fraction, places)
          }) : U32}
          updated = C.branch(Array<C.Neighbors>,
            U32.is_lt(left, size) && U32.is_lt(right, size) &&
              U32.is_ne(left, right) && U32.is_gt(score, 0), \{
            True: C.sparse_add(rows, left, right, score)
            False: rows
          })
          parser_reset(updated)
        )
      })

law parser_tab:
  for state: Parser
  Parser

def parser_tab(state):
  match state:
    case Parser{rows, +field, value, left, right, whole, fraction, places,
                +decimal, header}:
      C.branch(Parser, U32.is_eq(field, 0), \{
        True: Parser{rows, 1, 0, value, right, whole, fraction, places,
          False{}, header}
        False: Parser{rows, 2, 0, left, value, whole, fraction, places,
          False{}, header}
      })

law parser_digit:
  for state: Parser
  for +digit: U32
  Parser

def parser_digit(state, digit):
  match state:
    case Parser{rows, +field, value, left, right, whole, fraction, places,
                +decimal, header}:
      C.branch(Parser, U32.is_lt(field, 2), \{
        True: Parser{rows, field, U32.add(U32.mul(value, 10), digit),
          left, right, whole, fraction, places, decimal, header}
        False: (
          C.branch(Parser, decimal, \{
            True: Parser{rows, field, value, left, right, whole,
              U32.add(U32.mul(fraction, 10), digit), U32.add(places, 1),
              decimal, header}
            False: Parser{rows, field, value, left, right,
              U32.add(U32.mul(whole, 10), digit), fraction, places,
              decimal, header}
          })
        )
      })

law parser_dot:
  for state: Parser
  Parser

def parser_dot(state):
  match state:
    case Parser{rows, field, value, left, right, whole, fraction, places,
                decimal, header}:
      Parser{rows, field, value, left, right, whole, fraction, places,
        True{}, header}

law parser_byte:
  for state: Parser
  for +byte: U32
  for +size: U32
  Parser

def parser_byte(state, byte, size):
  C.branch(Parser, U32.is_eq(byte, 10), \{
    True: parser_finish_row(state, size)
    False: (
      C.branch(Parser, U32.is_eq(byte, 13), \{
        True: state
        False: (
          C.branch(Parser, U32.is_eq(byte, 9), \{
            True: parser_tab(state)
            False: (
              C.branch(Parser, U32.is_eq(byte, 46), \{
                True: parser_dot(state)
                False: (
                  C.branch(Parser, U32.is_ge(byte, 48) && U32.is_le(byte, 57), \{
                    True: parser_digit(state, U32.sub(byte, 48))
                    False: state
                  })
                )
              })
            )
          })
        )
      })
    )
  })

law parser_bytes:
  for bytes: List<&2, U32>
  for state: Parser
  for +size: U32
  Parser

def parser_bytes(bytes, state, size):
  match bytes:
    case Nil{}: state
    case Con{head, tail}:
      parser_bytes(tail, parser_byte(state, head, size), size)

law parser_graph:
  for state: Parser
  for +size: U32
  C.SparseGraph

def parser_graph(state, size):
  match state:
    case Parser{rows, field, value, left, right, whole, fraction, places,
                decimal, header}:
      C.SparseGraph{size, rows}

law read_result:
  for read: File & Result<(U32 & String), List<&2, U32>>
  for state: Parser
  for +size: U32
  for continue: File -> Parser -> IO(C.SparseGraph)
  IO(C.SparseGraph)

def read_result(read, state, size, continue):
  match read:
    case Tuple{handle, result}:
      match result:
        case Fail{error}:
          C.apply(U32 & String, IO(C.SparseGraph),
            \{Tuple: code => message => (
              do IO<C.SparseGraph>:
                closed: Unit <- File.close(handle)
                IO.die(C.SparseGraph, code, message)
            )}, error)
        case Done{bytes}:
          match bytes:
            case Nil{}:
              do IO<C.SparseGraph>:
                closed: Unit <- File.close(handle)
                return parser_graph(state, size)
            case Con{head, tail}:
              continue(handle, parser_bytes(Con{head, tail}, state, size))

law read_loop:
  for fuel: Nat
  for file: File
  for state: Parser
  for +size: U32
  IO(C.SparseGraph)

def read_loop(fuel, file, state, size):
  match fuel:
    case Zero{}:
      do IO<C.SparseGraph>:
        closed: Unit <- File.close(file)
        IO.die(C.SparseGraph, 2, "benchmark graph exceeds read limit")
    case Succ{rest}:
      do IO<C.SparseGraph>:
        read: File & Result<(U32 & String), List<&2, U32>> <-
          File.read_bytes(file, 65536)
        read_result(read, state, size,
          handle => next => read_loop(rest, handle, next, size))

law read_graph:
  for +size: U32
  IO(C.SparseGraph)

law read_graph_rows:
  for +size: U32
  for rows: Array<C.Neighbors>
  IO(C.SparseGraph)

def read_graph_rows(size, rows):
  do IO<C.SparseGraph>:
    path: String <- C.env("CLUSTER_GRAPH_INPUT", "")
    file: File <- IO.try(File, File.open(path, "r"))
    read_loop(4097n, file,
      Parser{rows, 0, 0, 0, 0, 0, 0, 0, False{}, True{}}, size)

def read_graph(size):
  read_graph_rows(size,
    Array.new(C.Neighbors, C.array_depth(31n, size, 1, 0n),
      C.NeighborsNil{}))

law output_rows:
  for fuel: Nat
  for +index: U32
  for labels: Array<U32>
  IO(Unit)

def output_rows(fuel, index, labels):
  match fuel:
    case Zero{}: IO.pure(Unit, Unit{})
    case Succ{rest}:
      C.apply(Array<U32> & U32, IO(Unit),
        \{Tuple: next => label => (
          do IO<Unit>:
            printed: Unit <- IO.print(U32.show(index) ++ "\t" ++ U32.show(label))
            output_rows(rest, U32.add(index, 1), next)
        )}, Array.get(U32, labels, index))

law output:
  for +size: U32
  for labels: Array<U32>
  IO(Unit)

def output(size, labels):
  do IO<Unit>:
    header: Unit <- IO.print("object\tcluster")
    output_rows(C.to_nat(size), 0, labels)
