# integer square root as a binary search over the answer's bits: the root of
# a U32 fits in 16 bits, so exactly 16 probes settle it, most significant bit
# first. Each step proposes candidate = best-so-far + 2^(i-1) and keeps it iff
# candidate^2 still fits under n. The bit counter i is a Nat, so the recursion
# on its predecessor is structural; keep matches on the computed comparison.
#
# $ bend integer_sqrt.bend

# expect: [0, 1, 9, 10, 1000, 65535]

import Base

# keep the candidate c when it fits, otherwise keep b
def keep(b: U32, c: U32, fits: Bool) -> U32:
  match fits:
    case True{}:
      c
    case False{}:
      b

def isqrt_go(i: Nat, +b: U32, +n: U32) -> U32:
  match i:
    case 0n:
      b
    case 1n++p:            # 1n+p, with p reusable (+p): shift and recurse
      +c = (b + (1 << p) : U32)
      isqrt_go(p, keep(b, c, (c * c <= n : U32)), n)

def isqrt(n: U32) -> U32:
  isqrt_go(16n, 0, n)

def main() -> List<U32>:
  [isqrt(0), isqrt(1), isqrt(99), isqrt(100), isqrt(1000000), isqrt(4294967295)]
