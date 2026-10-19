# Same edit-distance / maximum-match DP and packed score as the baseline.
# Only the source of bases changes. The right cursor is rewound after each row.
import Base
import ./packing.bend as P

def minimum(+a: U32, +b: U32) -> U32:
  P.choose(U32, U32.is_lt(a, b), \{True: a; False: b})

def initial(fuel: Nat, +index: U32, row: Array<U32>) -> Array<U32>:
  match fuel:
    case Zero{}: row
    case Succ{rest}:
      initial(rest, U32.add(index, 1),
        Array.set(U32, row, index, U32.add(U32.mul(index, 65536), 65535)))

def columns(fuel: Nat, cursor: P.Cursor, +base: U32, +index: U32,
            +diagonal: U32, +left: U32, row: Array<U32>) -> P.Cursor & Array<U32>:
  match fuel:
    case Zero{}: (cursor, row)
    case Succ{rest}:
      P.apply(P.Cursor & U32, P.Cursor & Array<U32>, \{Tuple: following => code => (
        P.apply(Array<U32> & U32, P.Cursor & Array<U32>, \{Tuple: next => +above => (
          diag = P.choose(U32, U32.is_eq(base, code), \{
            True: U32.sub(diagonal, 1)
            False: U32.add(diagonal, 65536)
          })
          +cell = {minimum(diag, U32.add(minimum(left, above), 65536)) : U32}
          columns(rest, following, base, U32.add(index, 1), above, cell,
            Array.set(U32, next, index, cell))
        )}, Array.get(U32, row, index))
      )}, P.next(cursor))

def rows(fuel: Nat, left: P.Cursor, right: P.Cursor, +right_size: U32,
         +index: U32, row: Array<U32>) -> Array<U32>:
  match fuel:
    case Zero{}: row
    case Succ{rest}:
      P.apply(P.Cursor & U32, Array<U32>, \{Tuple: next_left => base => (
        +first = {U32.add(U32.mul(index, 65536), 65535) : U32}
        initialized = Array.set(U32, row, 0, first)
        P.apply(P.Cursor & Array<U32>, Array<U32>, \{Tuple: next_right => next_row => (
          rows(rest, next_left, next_right, right_size, U32.add(index, 1), next_row)
        )}, columns(U32.to_nat(right_size), P.reset(right), base, 1,
          U32.sub(first, 65536), first, initialized))
      )}, P.next(left))

def identity(left: P.Sequence, right: P.Sequence, +left_size: U32,
             +right_size: U32, shorter: Bool) -> U32:
  width = U32.add(right_size, 1)
  row = initial(U32.to_nat(U32.add(right_size, 1)), 0,
    Array.new(U32, P.depth(31n, width, 1, 0n), 0))
  result = rows(U32.to_nat(left_size), P.cursor(left), P.cursor(right), right_size, 1, row)
  P.apply(Array<U32> & U32, U32, \{Tuple: unused => +cell => (
    +matches = {U32.sub(65535, U32.mod(cell, 65536)) : U32}
    denominator = P.choose(U32, shorter, \{
      True: minimum(left_size, right_size)
      False: U32.add(matches, U32.div(cell, 65536))
    })
    U32.div(U32.mul(matches, 10000), denominator)
  )}, Array.get(U32, result, right_size))
