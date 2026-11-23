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

type Block is Type:
  Block{row: Array<U32>, diagonal: U32, left: U32}

# Consume up to 16 bases from a register, without a cursor per base.
def columns2(fuel: Nat, +word: U32, +base: U32, +index: U32,
             +diagonal: U32, +left: U32, row: Array<U32>) -> Block:
  match fuel:
    case Zero{}: Block{row, diagonal, left}
    case Succ{rest}:
      P.apply(Array<U32> & U32, Block, \{Tuple: next => +above => (
        diag = P.choose(U32, U32.is_eq(base, U32.and(word, 3)), \{
          True: U32.sub(diagonal, 1)
          False: U32.add(diagonal, 65536)
        })
        +cell = {minimum(diag, U32.add(minimum(left, above), 65536)) : U32}
        columns2(rest, U32.shr(U32.shr(word)), base, U32.add(index, 1), above, cell,
          Array.set(U32, next, index, cell))
      )}, Array.get(U32, row, index))

# Consume up to 8 bases from a register, without a cursor per base.
def columns4(fuel: Nat, +word: U32, +base: U32, +index: U32,
             +diagonal: U32, +left: U32, row: Array<U32>) -> Block:
  match fuel:
    case Zero{}: Block{row, diagonal, left}
    case Succ{rest}:
      P.apply(Array<U32> & U32, Block, \{Tuple: next => +above => (
        diag = P.choose(U32, U32.is_eq(base, U32.and(word, 15)), \{
          True: U32.sub(diagonal, 1)
          False: U32.add(diagonal, 65536)
        })
        +cell = {minimum(diag, U32.add(minimum(left, above), 65536)) : U32}
        columns4(rest, U32.shr(U32.shr(U32.shr(U32.shr(word)))), base, U32.add(index, 1), above, cell,
          Array.set(U32, next, index, cell))
      )}, Array.get(U32, row, index))

def columns(fuel: Nat, +word_index: U32, +remaining: U32, +bits: U32,
            +base: U32, +index: U32, diagonal: U32, left: U32,
            words: Array<U32>, row: Array<U32>) -> Array<U32> & Array<U32>:
  match fuel:
    case Zero{}: (words, row)
    case Succ{rest}:
      P.apply(Array<U32> & U32, Array<U32> & Array<U32>, \{Tuple: next_words => block => (
        +count = {minimum(U32.div(32, bits), remaining) : U32}
        result = P.choose(Block, U32.is_eq(bits, 2), \{
          True: columns2(U32.to_nat(count), block, base, index, diagonal, left, row)
          False: columns4(U32.to_nat(count), block, base, index, diagonal, left, row)
        })
        P.apply(Block, Array<U32> & Array<U32>, \{Block: next_row => next_diagonal => next_left => (
          columns(rest, U32.add(word_index, 1), U32.sub(remaining, count), bits,
            base, U32.add(index, count), next_diagonal, next_left, next_words, next_row)
        )}, result)
      )}, Array.get(U32, words, word_index))

def rows(fuel: Nat, left: P.Cursor, right: Array<U32>, +bits: U32,
         +right_size: U32, +index: U32, row: Array<U32>) -> Array<U32>:
  match fuel:
    case Zero{}: row
    case Succ{rest}:
      P.apply(P.Cursor & U32, Array<U32>, \{Tuple: next_left => base => (
        +first = {U32.add(U32.mul(index, 65536), 65535) : U32}
        initialized = Array.set(U32, row, 0, first)
        blocks = U32.div(U32.add(U32.mul(right_size, bits), 31), 32)
        P.apply(Array<U32> & Array<U32>, Array<U32>, \{Tuple: next_right => next_row => (
          rows(rest, next_left, next_right, bits, right_size, U32.add(index, 1), next_row)
        )}, columns(U32.to_nat(blocks), 0, right_size, bits, base, 1,
          U32.sub(first, 65536), first, right, initialized))
      )}, P.next(left))

def identity(left: P.Sequence, right: P.Sequence, +left_size: U32,
             +right_size: U32, shorter: Bool) -> U32:
  match right:
    case P.Sequence{words, bits, length}:
      width = U32.add(right_size, 1)
      row = initial(U32.to_nat(U32.add(right_size, 1)), 0,
        Array.new(U32, P.depth(31n, width, 1, 0n), 0))
      result = rows(U32.to_nat(left_size), P.cursor(left), words, bits, right_size, 1, row)
      P.apply(Array<U32> & U32, U32, \{Tuple: unused => +cell => (
        +matches = {U32.sub(65535, U32.mod(cell, 65536)) : U32}
        denominator = P.choose(U32, shorter, \{
          True: minimum(left_size, right_size)
          False: U32.add(matches, U32.div(cell, 65536))
        })
        U32.div(U32.mul(matches, 10000), denominator)
      )}, Array.get(U32, result, right_size))
