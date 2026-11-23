# tournament maximum: seed a single-elimination bracket of 2^d players with
# scrambled numbers, then crown the champion. Every Match resolves its two
# halves with a parallel let (a b = f(..) g(..)), so the whole bracket plays
# out in parallel on the compiled runtime -- finding a maximum in log(n)
# rounds. winner is branchless: the two comparison bits pick exactly one
# operand. The depth d is a Nat, so seed recurses structurally.
#
# $ bend tournament.bend          # normalized by the checker
# $ bend tournament.bend -o t && ./t

# expect: 995

import Base

type Bracket is Data:
  Player{seed: U32}
  Match{lft: Bracket, rgt: Bracket}

# a little LCG scramble so the bracket looks like a real draw
def scramble(s: U32) -> U32:
  +ss = (s * 1664525 : U32)
  ((ss + 1013904223) .^. (ss >> 7n) : U32)

def seed(+d: Nat, +s: U32) -> Bracket:
  match d:
    case 0n:
      Player{(s % 1000 : U32)}
    case 1n+p:
      l r = seed(p, scramble((s * 2 : U32))) seed(p, scramble((s * 2 + 1 : U32)))
      Match{l, r}

def winner(+a: U32, +b: U32) -> U32:
  (Bool.to_u32((a >= b : U32)) * a + Bool.to_u32((a < b : U32)) * b : U32)

def champion(t: Bracket) -> U32:
  match t:
    case Player{s}:
      s
    case Match{l, r}:
      a b = champion(l) champion(r)
      winner(a, b)

# 64 scrambled players enter, one number leaves
# (the checker normalizes this fine; compiled, crank d way up)
def main() -> U32:
  champion(seed(6n, 42))
