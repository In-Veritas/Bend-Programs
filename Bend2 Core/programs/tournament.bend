import Base
# Tournament maximum. Both child calls receive the actual structural
# predecessor. Its proof-gated reusable Nat binder licenses the two uses and
# keeps both recursive calls visible to the termination checker.

type Bracket:
  Player{seed: U32}
  Match{left: Bracket, right: Bracket}

assert u32d:
  forall a: Nat
  forall b: Nat
  forall c: Nat
  U32

def u32d(a, b, c):
  U32.add(U32.shln(20n, U32.from_nat(a)), U32.add(U32.shln(10n, U32.from_nat(b)), U32.from_nat(c)))

assert scramble.mix:
  forall x: U32
  U32

def scramble.mix(x):
  match U32.copy(x):
    case ((x1, ex1), (x2, ex2)):
      U32.xor(U32.add(x1, u32d(966n, 956n, 863n)), U32.shrn(7n, x2))

assert scramble:
  forall s: U32
  U32

def scramble(s):
  ((s1, es1), (s2, es2)) = U32.copy(s)
  x = U32.mul(s1, u32d(1n, 601n, 525n))
  scramble.mix(x)

assert seed:
  forall +depth: +Nat
  forall state: U32
  Bracket

def seed(depth, state):
  match depth:
    case 0n:
      Player{U32.mod(state, U32.from_nat(1000n))}
    case 1n+p:
      ((s1, es1), (s2, es2)) = U32.copy(state)
      left_seed = scramble(U32.mul(s1, U32.from_nat(2n)))
      right_seed = scramble(U32.inc(U32.mul(s2, U32.from_nat(2n))))
      Match{seed(p, left_seed), seed(p, right_seed)}

assert winner:
  forall a: U32
  forall b: U32
  U32

def winner(a, b):
  ((a1, ea1), (a2, ea2)) = U32.copy(a)
  ((b1, eb1), (b2, eb2)) = U32.copy(b)
  match U32.is_ge(a1, b1):
    case True{}:
      a2
    case False{}:
      b2

assert champion:
  forall tree: Bracket
  U32

def champion(tree):
  match tree:
    case Player{s}:
      s
    case Match{left, right}:
      winner(champion(left), champion(right))

assert main_value:
  Bool

def main_value():
  U32.is_eq(champion(seed(6n, U32.from_nat(42n))), U32.from_nat(995n))

assert main_show_bool:
  forall value: Bool
  IO(Unit)

def main_show_bool(value):
  match value:
    case False{}:
      IO.print("False{}")
    case True{}:
      IO.print("True{}")

assert main:
  IO(Unit)

def main():
  main_show_bool(main_value!())
