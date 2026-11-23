import Base
# Tournament maximum: seed a bracket of 2^depth scrambled players, then crown
# the champion. As in Bend3, every Match resolves its two halves with a
# parallel let (`a b = f(x) g(y)`), which Bend 2 runs in parallel when
# compiled; Bend2 Core had no parallel primitive and ran them sequentially.
# The depth is a reusable `+Nat`, so both children recurse on the same
# structurally smaller `p` without the old `#[halts]` license.

type Bracket is Data:
  Player{seed: U32}
  Match{left: Bracket, right: Bracket}

# a little LCG scramble so the bracket looks like a real draw
def scramble(s: U32) -> U32:
  +ss = U32.mul(s, 1664525)
  U32.xor(U32.add(ss, 1013904223), U32.shrn(ss, 7n))

def seed(+depth: Nat, +state: U32) -> Bracket:
  match depth:
    case 0n:
      Player{U32.mod(state, 1000)}
    case 1n+p:
      left right = seed(p, scramble(U32.mul(state, 2))) seed(p, scramble(U32.inc(U32.mul(state, 2))))
      Match{left, right}

def winner(+a: U32, +b: U32) -> U32:
  Bool.pick(U32, U32.is_ge(a, b), a, b)

def champion(tree: Bracket) -> U32:
  match tree:
    case Player{s}:
      s
    case Match{left, right}:
      a b = champion(left) champion(right)
      winner(a, b)

def main_value() -> Bool:
  U32.is_eq(champion(seed(6n, 42)), 995)

# The executable entry prints the pure self-check, so `bend FILE`, a native
# build and the JS build all report True{} through the same IO path.
def main_show_bool(value: Bool) -> IO(Unit):
  match value:
    case False{}:
      IO.print("False{}")
    case True{}:
      IO.print("True{}")

def main() -> IO(Unit):
  main_show_bool(main_value())
