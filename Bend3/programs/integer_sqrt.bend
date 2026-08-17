# integer square root as a binary search over the answer's bits: the root of
# a U32 fits in 16 bits, so exactly 16 probes settle it, most significant bit
# first. Each step proposes candidate = best-so-far + 2^(i-1) and keeps it iff
# candidate^2 still fits under n. The bit counter i is the halt measure.
#
# $ bun bend-ts/src/bend.ts integer_sqrt.bend --eval

import ../bend-base/Base

def isqrt_go(i: U32, b: U32, n: +U32) -> U32:
  match i:
    case 0:
      b
    case 1+i:
      c = b + (1 << i)
      cc = c
      match (cc * cc) <= n:
        case 0:
          isqrt_go(i, b, n)
        case k:
          isqrt_go(i, cc, n)

def isqrt(n: U32) -> U32:
  nn = n
  isqrt_go(16, 0, nn)

def main() -> List(U32):
  [isqrt(0), isqrt(1), isqrt(99), isqrt(100), isqrt(1000000), isqrt(4294967295)]
