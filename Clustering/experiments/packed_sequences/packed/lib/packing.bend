# Safe affine packed nucleotide storage. No Array.fork or foreign effects.
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

# A,C,G,T always have codes 0,1,2,3, including in four-bit sequences.
# Encoding the remaining IUPAC symbols distinctly preserves literal identity.
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
    case SNil{}: 2
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
        True: fill(tail, bits, U32.add(index, 1), 0, 0, Array.set(U32, words, index, next))
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

def reset(cursor: Cursor) -> Cursor:
  match cursor:
    case Cursor{words, bits, index, word, available}:
      Cursor{words, bits, 0, 0, 0}

def loaded(words: Array<U32>, +bits: U32, index: U32, +word: U32,
           available: U32) -> Cursor & U32:
  choose(Cursor & U32, U32.is_eq(bits, 2), \{
    True: (Cursor{words, bits, index, U32.shr(U32.shr(word)), U32.sub(available, 1)},
      U32.and(word, 3))
    False: (Cursor{words, bits, index, U32.shr(U32.shr(U32.shr(U32.shr(word)))), U32.sub(available, 1)},
      U32.and(word, 15))
  })

# A word is fetched once, then consumed locally for 16 (or 8) bases.
def next(cursor: Cursor) -> Cursor & U32:
  match cursor:
    case Cursor{words, +bits, +index, word, +available}:
      choose(Cursor & U32, U32.is_eq(available, 0), \{
        True: apply(Array<U32> & U32, Cursor & U32,
          \{Tuple: array => block => loaded(array, bits, U32.add(index, 1), block, U32.div(32, bits))},
          Array.get(U32, words, index))
        False: loaded(words, bits, index, word, available)
      })

def reverse(text: String, acc: String) -> String:
  match text:
    case SNil{}: acc
    case SCon{head, tail}: reverse(tail, SCon{head, acc})

def unpack_loop(fuel: Nat, cursor: Cursor, acc: String) -> String:
  match fuel:
    case Zero{}: reverse(acc, "")
    case Succ{rest}:
      apply(Cursor & U32, String,
        \{Tuple: following => base => unpack_loop(rest, following, SCon{Chr{ascii(base)}, acc})},
        next(cursor))

def unpack(sequence: Sequence) -> String:
  match sequence:
    case Sequence{words, bits, length}:
      unpack_loop(U32.to_nat(length), Cursor{words, bits, 0, 0, 0}, "")
