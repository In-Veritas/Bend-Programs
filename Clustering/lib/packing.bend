# Safe affine packed nucleotide storage and reusable 3-mer signatures.
import Base

type Sequence is Type:
  Sequence{words: Array<U32>, bits: U32, length: U32}

type Cursor is Type:
  Cursor{words: Array<U32>, bits: U32, index: U32, word: U32, available: U32}

def apply(-A: Type, -B: Type, f: A -> B, x: A) -> B:
  f(x)

def choose(-A: Type, b: Bool, f: Bool -> A) -> A:
  f(b)

def depth(fuel: Nat, +size: U32, +capacity: U32, n: Nat) -> Nat:
  match fuel:
    case Zero{}:
      n
    case Succ{rest}:
      choose(Nat, U32.is_ge(capacity, size), \{
        True: n
        False: depth(rest, size, U32.mul(capacity, 2), Succ{n})
      })

# A,C,G,T retain the compact codes 0..3. Ambiguity symbols are distinct.
def code(c: U32) -> U32:
  match c:
    case 65: 0
    case 67: 1
    case 71: 2
    case 84: 3
    case 82: 4
    case 89: 5
    case 83: 6
    case 87: 7
    case 75: 8
    case 77: 9
    case 66: 10
    case 68: 11
    case 72: 12
    case 86: 13
    case 78: 14
    case _: 15

def ascii(c: U32) -> U32:
  match c:
    case 0: 65
    case 1: 67
    case 2: 71
    case 3: 84
    case 4: 82
    case 5: 89
    case 6: 83
    case 7: 87
    case 8: 75
    case 9: 77
    case 10: 66
    case 11: 68
    case 12: 72
    case 13: 86
    case _: 78

def bit_width(text: String) -> U32:
  match text:
    case SNil{}:
      2
    case SCon{Chr{c}, tail}:
      choose(U32, U32.is_gt(code(c), 3), \{
        True: 4
        False: bit_width(tail)
      })

def fill(text: String, +bits: U32, +index: U32, +offset: U32,
         word: U32, words: Array<U32>) -> Array<U32>:
  match text:
    case SNil{}:
      choose(Array<U32>, U32.is_eq(offset, 0), \{
        True: words
        False: Array.set(U32, words, index, word)
      })
    case SCon{Chr{c}, tail}:
      +next = {U32.or(word, U32.shln(code(c), U32.to_nat(offset))) : U32}
      +position = {U32.add(offset, bits) : U32}
      choose(Array<U32>, U32.is_eq(position, 32), \{
        True: fill(tail, bits, U32.add(index, 1), 0, 0,
          Array.set(U32, words, index, next))
        False: fill(tail, bits, index, position, next, words)
      })

def pack(+text: String, +length: U32) -> Sequence:
  +bits = {bit_width(text) : U32}
  count = U32.div(U32.add(U32.mul(length, bits), 31), 32)
  words = Array.new(U32, depth(31n, count, 1, 0n), 0)
  Sequence{fill(text, bits, 0, 0, 0, words), bits, length}

def copy(sequence: Sequence) -> Sequence & Sequence:
  match sequence:
    case Sequence{words, +bits, +length}:
      apply(Array<U32> & Array<U32>, Sequence & Sequence,
        \{Tuple: a => b => (Sequence{a, bits, length}, Sequence{b, bits, length})},
        Array.clone(U32, words))

def cursor(sequence: Sequence) -> Cursor:
  match sequence:
    case Sequence{words, bits, length}:
      Cursor{words, bits, 0, 0, 0}

def loaded(words: Array<U32>, +bits: U32, index: U32, +word: U32,
           available: U32) -> Cursor & U32:
  choose(Cursor & U32, U32.is_eq(bits, 2), \{
    True: (
      Cursor{words, bits, index, U32.shr(U32.shr(word)), U32.sub(available, 1)},
      U32.and(word, 3)
    )
    False: (
      Cursor{words, bits, index,
        U32.shr(U32.shr(U32.shr(U32.shr(word)))), U32.sub(available, 1)},
      U32.and(word, 15)
    )
  })

def next(cursor: Cursor) -> Cursor & U32:
  match cursor:
    case Cursor{words, +bits, +index, word, +available}:
      choose(Cursor & U32, U32.is_eq(available, 0), \{
        True: apply(Array<U32> & U32, Cursor & U32,
          \{Tuple: array => block => loaded(array, bits, U32.add(index, 1), block,
            U32.div(32, bits))},
          Array.get(U32, words, index))
        False: loaded(words, bits, index, word, available)
      })

# Start a cursor at an arbitrary base without unpacking or copying the
# sequence. Only the partial first machine word is skipped.
def cursor_skip(fuel: Nat, cursor: Cursor) -> Cursor:
  match fuel:
    case Zero{}:
      cursor
    case Succ{rest}:
      apply(Cursor & U32, Cursor,
        \{Tuple: following => base => cursor_skip(rest, following)},
        next(cursor))

def cursor_at(words: Array<U32>, +bits: U32, +position: U32) -> Cursor:
  +per_word = {U32.div(32, bits) : U32}
  +word_index = {U32.div(position, per_word) : U32}
  +offset = {U32.mod(position, per_word) : U32}
  cursor_skip(U32.to_nat(offset), Cursor{words, bits, word_index, 0, 0})

def cursor_words(cursor: Cursor) -> Array<U32>:
  match cursor:
    case Cursor{words, bits, index, word, available}:
      words

def reverse(text: String, acc: String) -> String:
  match text:
    case SNil{}:
      acc
    case SCon{head, tail}:
      reverse(tail, SCon{head, acc})

def unpack_loop(fuel: Nat, cursor: Cursor, acc: String) -> String:
  match fuel:
    case Zero{}:
      reverse(acc, "")
    case Succ{rest}:
      apply(Cursor & U32, String,
        \{Tuple: following => base =>
          unpack_loop(rest, following, SCon{Chr{ascii(base)}, acc})},
        next(cursor))

def unpack(sequence: Sequence) -> String:
  match sequence:
    case Sequence{words, bits, length}:
      unpack_loop(U32.to_nat(length), Cursor{words, bits, 0, 0, 0}, "")

# The 12-bit exact 3-mer code is folded into 256 counters. Hash collisions can
# only increase a pair's multiset intersection, preserving filter sensitivity.
def signature_loop(fuel: Nat, cursor: Cursor, +rolling: U32, +seen: U32,
                   counts: Array<U32>) -> Array<U32>:
  match fuel:
    case Zero{}:
      counts
    case Succ{rest}:
      apply(Cursor & U32, Array<U32>, \{Tuple: following => +base => (
        +word = {U32.mod(U32.add(U32.mul(rolling, 16), base), 4096) : U32}
        +bucket = {U32.and(U32.xor(word, U32.shrn(word, 8n)), 255) : U32}
        apply(Array<U32> & U32, Array<U32>, \{Tuple: next_counts => previous => (
          updated = Array.set(U32, next_counts, bucket,
            U32.add(previous, choose(U32, U32.is_ge(seen, 2),
              \{True: 1; False: 0})))
          signature_loop(rest, following, word, U32.add(seen, 1), updated)
        )}, Array.get(U32, counts, bucket))
      )}, next(cursor))

def signature(sequence: Sequence, +length: U32) -> Array<U32>:
  signature_loop(U32.to_nat(length), cursor(sequence), 0, 0,
    Array.new(U32, 8n, 0))

def hash30(+word: U32) -> U32:
  +a = {U32.xor(word, U32.shrn(word, 16n)) : U32}
  +b = {U32.mul(a, 2146121005) : U32}
  +c = {U32.xor(b, U32.shrn(b, 15n)) : U32}
  +d = {U32.mul(c, 2221713035) : U32}
  U32.xor(d, U32.shrn(d, 16n))

# Sixty-four one-per-bin MinHash values over exact A/C/G/T 15-mers. IUPAC
# codes are folded to two bits, which can add candidates but cannot make the
# conservative 3-mer stage reject one. This sketch is only an explicit
# approximate acceleration layer; the exact mode does not use it to reject.
def sketch_loop(fuel: Nat, cursor: Cursor, +rolling: U32, +seen: U32,
                values: Array<U32>) -> Array<U32>:
  match fuel:
    case Zero{}:
      values
    case Succ{rest}:
      apply(Cursor & U32, Array<U32>, \{Tuple: following => +base => (
        +word = {U32.and(U32.or(U32.shln(rolling, 2n), U32.and(base, 3)),
          1073741823) : U32}
        choose(Array<U32>, U32.is_ge(seen, 14), \{
          True: (
            +hash = {hash30(word) : U32}
            +bin = {U32.and(hash, 63) : U32}
            +value = {U32.shrn(hash, 6n) : U32}
            apply(Array<U32> & U32, Array<U32>,
              \{Tuple: next_values => +previous => (
                updated = Array.set(U32, next_values, bin,
                  choose(U32, U32.is_lt(value, previous),
                    \{True: value; False: previous}))
                sketch_loop(rest, following, word, U32.add(seen, 1), updated)
              )},
              Array.get(U32, values, bin))
          )
          False: (
            sketch_loop(rest, following, word, U32.add(seen, 1), values)
          )
        })
      )}, next(cursor))

def sketch(sequence: Sequence, +length: U32) -> Array<U32>:
  sketch_loop(U32.to_nat(length), cursor(sequence), 0, 0,
    Array.new(U32, 6n, 4294967295))

def signature15_loop(fuel: Nat, cursor: Cursor, +rolling: U32, +seen: U32,
                     counts: Array<U32>) -> Array<U32>:
  match fuel:
    case Zero{}:
      counts
    case Succ{rest}:
      apply(Cursor & U32, Array<U32>, \{Tuple: following => +base => (
        +word = {U32.and(U32.or(U32.shln(rolling, 2n), U32.and(base, 3)),
          1073741823) : U32}
        choose(Array<U32>, U32.is_ge(seen, 14), \{
          True: (
            +bucket = {U32.and(hash30(word), 65535) : U32}
            apply(Array<U32> & U32, Array<U32>,
              \{Tuple: next_counts => previous => (
                updated = Array.set(U32, next_counts, bucket,
                  U32.add(previous, 1))
                signature15_loop(rest, following, word, U32.add(seen, 1), updated)
              )},
              Array.get(U32, counts, bucket))
          )
          False: (
            signature15_loop(rest, following, word, U32.add(seen, 1), counts)
          )
        })
      )}, next(cursor))

def signature15(sequence: Sequence, +length: U32) -> Array<U32>:
  signature15_loop(U32.to_nat(length), cursor(sequence), 0, 0,
    Array.new(U32, 16n, 0))
