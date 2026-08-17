# tournament maximum: seed a single-elimination bracket of 2^d players with
# scrambled numbers, then crown the champion. Every Match resolves its two
# halves with a fork/join let (a, b = f, g), so the whole bracket plays out
# in parallel on the compiled runtime -- finding a maximum in log(n) rounds.
# winner is branchless: the two comparison bits pick exactly one operand.
#
# $ bend tournament.bend

type Bracket:
  Player{seed: U32}
  Match{lft: Bracket, rgt: Bracket}

# a little LCG scramble so the bracket looks like a real draw
def scramble(s: U32) -> U32:
  ss = s * 1664525
  (ss + 1013904223) .^. (ss >> 7)

def seed(d: U32, s: U32) -> Bracket:
  match d:
    case 0:
      Bracket.Player{s % 1000}
    case 1+d:
      l & r = seed(d, scramble(s * 2)) & seed(d, scramble((s * 2) + 1))
      Bracket.Match{l, r}

def winner(a: U32, b: U32) -> U32:
  ((a >= b) * a) +
  ((a < b) * b)

def champion(t: Bracket) -> U32:
  match t:
    case Bracket.Player{s}:
      s
    case Bracket.Match{l, r}:
      a & b = champion(l) & champion(r)
      winner(a, b)

# 64 scrambled players enter, one number leaves
# (the interpreter is fine up to here; compiled, crank d way up)
def main() -> U32:
  champion(seed(6, 42))
