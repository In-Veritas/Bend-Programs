#[halts]
import Base
# Sixteen-step integer square root. Nat is the structural fuel; each U32 that
# survives a probe is explicitly copied before comparison. `#[halts]` is
# required because the recursive call receives a certified copy of the smaller
# Nat pattern, and the syntactic termination checker only accepts the original.

def isqrt.choose(n_test: U32, candidate: U32, fallback: U32) -> U32:
  match U32.copy(candidate):
    case ((ca, eca), (saved, esaved)):
      match U32.copy(ca):
        case ((c1, ec1), (c2, ec2)):
          match U32.is_le(U32.mul(c1, c2), n_test):
            case True{}:
              saved
            case False{}:
              fallback

def isqrt.go(fuel: Nat, best: U32, n: U32) -> U32:
  match fuel:
    case 0n:
      best
    case 1n+p:
      ((p1, ep1), (p2, ep2)) = Nat.copy(p)
      ((b1, eb1), (b2, eb2)) = U32.copy(best)
      ((n1, en1), (n2, en2)) = U32.copy(n)
      candidate = U32.add(b1, U32.shln(p1, U32.one()))
      chosen = isqrt.choose(n1, candidate, b2)
      isqrt.go(p2, chosen, n2)

def isqrt(n: U32) -> U32:
  isqrt.go(16n, U32.zero(), n)

def test(n: U32, expected: U32) -> Bool:
  U32.is_eq(isqrt(n), expected)

def u32d(a: Nat, b: Nat, c: Nat) -> U32:
  U32.add(U32.shln(20n, U32.from_nat(a)), U32.add(U32.shln(10n, U32.from_nat(b)), U32.from_nat(c)))

def main() -> Bool:
  t0 = test(U32.zero(), U32.zero())
  t1 = test(U32.one(), U32.one())
  t2 = test(U32.from_nat(99n), U32.from_nat(9n))
  t3 = test(U32.from_nat(100n), U32.from_nat(10n))
  t4 = test(u32d(0n, 976n, 576n), U32.from_nat(1000n))
  max = U32.not(U32.zero())
  root_max = U32.sub(U32.shln(16n, U32.one()), U32.one())
  t5 = test(max, root_max)
  Bool.and(Bool.and(Bool.and(t0, t1), Bool.and(t2, t3)), Bool.and(t4, t5))
