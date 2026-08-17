#[halts]
import Base
# Tournament maximum. Bend3 forks both child calls; Bend2 Core currently runs
# the same tree sequentially because it has no implemented parallel primitive.
# Copying the smaller depth for two child calls also requires `#[halts]`.

type Bracket:
  Player{seed: U32}
  Match{left: Bracket, right: Bracket}

def u32d(a: Nat, b: Nat, c: Nat) -> U32:
  U32.add(U32.shln(20n, U32.from_nat(a)), U32.add(U32.shln(10n, U32.from_nat(b)), U32.from_nat(c)))

def scramble.mix(x: U32) -> U32:
  match U32.copy(x):
    case ((x1, ex1), (x2, ex2)):
      U32.xor(U32.add(x1, u32d(966n, 956n, 863n)), U32.shrn(7n, x2))

def scramble(s: U32) -> U32:
  ((s1, es1), (s2, es2)) = U32.copy(s)
  x = U32.mul(s1, u32d(1n, 601n, 525n))
  scramble.mix(x)

def seed(depth: Nat, state: U32) -> Bracket:
  match depth:
    case 0n:
      Player{U32.mod(state, U32.from_nat(1000n))}
    case 1n+p:
      ((p1, ep1), (p2, ep2)) = Nat.copy(p)
      ((s1, es1), (s2, es2)) = U32.copy(state)
      left_seed = scramble(U32.mul(s1, U32.from_nat(2n)))
      right_seed = scramble(U32.inc(U32.mul(s2, U32.from_nat(2n))))
      Match{seed(p1, left_seed), seed(p2, right_seed)}

def winner(a: U32, b: U32) -> U32:
  ((a1, ea1), (a2, ea2)) = U32.copy(a)
  ((b1, eb1), (b2, eb2)) = U32.copy(b)
  match U32.is_ge(a1, b1):
    case True{}:
      a2
    case False{}:
      b2

def champion(tree: Bracket) -> U32:
  match tree:
    case Player{s}:
      s
    case Match{left, right}:
      winner(champion(left), champion(right))

def main() -> Bool:
  U32.is_eq(champion(seed(6n, U32.from_nat(42n))), U32.from_nat(995n))
