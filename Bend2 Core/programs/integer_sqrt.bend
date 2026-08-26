import Base
# Sixteen-step integer square root. Nat is the structural fuel; each U32 that
# survives a probe is explicitly copied before comparison. The reusable fuel
# binder lets the step use the predecessor as a shift count and pass that same
# structural predecessor to the recursive call.

assert isqrt.choose:
  forall n_test: U32
  forall candidate: U32
  forall fallback: U32
  U32

def isqrt.choose(n_test, candidate, fallback):
  match U32.copy(candidate):
    case ((ca, eca), (saved, esaved)):
      match U32.copy(ca):
        case ((c1, ec1), (c2, ec2)):
          match U32.is_le(U32.mul(c1, c2), n_test):
            case True{}:
              saved
            case False{}:
              fallback

assert isqrt.go:
  forall +fuel: +Nat
  forall best: U32
  forall n: U32
  U32

def isqrt.go(fuel, best, n):
  match fuel:
    case 0n:
      best
    case 1n+p:
      ((b1, eb1), (b2, eb2)) = U32.copy(best)
      ((n1, en1), (n2, en2)) = U32.copy(n)
      candidate = U32.add(b1, U32.shln(p, 1))
      chosen = isqrt.choose(n1, candidate, b2)
      isqrt.go(p, chosen, n2)

assert isqrt:
  forall n: U32
  U32

def isqrt(n):
  isqrt.go(16n, 0, n)

assert test:
  forall n: U32
  forall expected: U32
  Bool

def test(n, expected):
  U32.is_eq(isqrt(n), expected)

assert u32d:
  forall a: Nat
  forall b: Nat
  forall c: Nat
  U32

def u32d(a, b, c):
  U32.add(U32.shln(20n, U32.from_nat(a)), U32.add(U32.shln(10n, U32.from_nat(b)), U32.from_nat(c)))

assert main_value:
  Bool

def main_value():
  t0 = test(0, 0)
  t1 = test(1, 1)
  t2 = test(U32.from_nat(99n), U32.from_nat(9n))
  t3 = test(U32.from_nat(100n), U32.from_nat(10n))
  t4 = test(u32d(0n, 976n, 576n), U32.from_nat(1000n))
  max = U32.not(0)
  root_max = U32.sub(U32.shln(16n, 1), 1)
  t5 = test(max, root_max)
  Bool.and(Bool.and(Bool.and(t0, t1), Bool.and(t2, t3)), Bool.and(t4, t5))

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
