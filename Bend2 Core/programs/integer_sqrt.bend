import Base
# Sixteen-step integer square root, one result bit per step from the top.
# Nat is the structural fuel (`1n+p` is a smaller part of `fuel`, so no
# termination license is needed); the probed values are reusable `+U32`s.

def isqrt.choose(+n: U32, +candidate: U32, fallback: U32) -> U32:
  Bool.pick(U32, U32.is_le(U32.mul(candidate, candidate), n), candidate, fallback)

def isqrt.go(+fuel: Nat, +best: U32, +n: U32) -> U32:
  match fuel:
    case 0n:
      best
    case 1n+p:
      candidate = U32.add(best, U32.shln(1, p))
      isqrt.go(p, isqrt.choose(n, candidate, best), n)

def isqrt(n: U32) -> U32:
  isqrt.go(16n, 0, n)

def test(n: U32, expected: U32) -> Bool:
  U32.is_eq(isqrt(n), expected)

def main() -> Bool:
  t0 = test(0, 0)
  t1 = test(1, 1)
  t2 = test(99, 9)
  t3 = test(100, 10)
  t4 = test(1000000, 1000)
  max = U32.not(0)
  root_max = U32.sub(U32.shln(1, 16n), 1)
  t5 = test(max, root_max)
  Bool.and(Bool.and(Bool.and(t0, t1), Bool.and(t2, t3)), Bool.and(t4, t5))
