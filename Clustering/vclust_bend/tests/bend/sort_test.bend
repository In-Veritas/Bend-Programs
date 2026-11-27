import Base
import ../../kdb_sort.bend as S

# fills n records with a xorshift sequence, values reduced mod m (duplicates)
def fill(n: Nat, +i: U32, +s: U32, +m: U32, a: Array<U32>) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      +s1 = U32.xor(s, U32.shln(s, 13n))
      +s2 = U32.xor(s1, U32.shrn(s1, 17n))
      +s3 = U32.xor(s2, U32.shln(s2, 5n))
      fill(p, (i + 1 : U32), s3, m, S.put2(a, i, U32.mod(s3, m), U32.mod(U32.shrn(s3, 7n), 3)))

type CK is Type:
  CK{a: Array<U32>, +ok: Bool, +px: U32, +py: U32, +sum: U32}

def ck_r(+i: U32, +ok: Bool, +px: U32, +py: U32, +sum: U32, g: S.A2) -> CK:
  S.A2{a, +x, +y} = g
  CK{a, ok && (U32.is_eq(i, 0) || Bool.not(S.lt2(x, y, px, py))), x, y, (sum + U32.mul(x, 31) + y : U32)}

def ck(n: Nat, +i: U32, c: CK) -> CK:
  match n c:
    case 0n _:
      c
    case 1n+p CK{a, +ok, +px, +py, +sum}:
      ck(p, (i + 1 : U32), ck_r(i, ok, px, py, sum, S.get2(a, i)))

def sumr(n: Nat, +i: U32, c: CK) -> U32:
  match n c:
    case 0n CK{a, ok, px, py, +sum}:
      sum
    case 1n+p CK{a, +ok, +px, +py, +sum}:
      sumr(p, (i + 1 : U32), ck_r(i, ok, px, py, sum, S.get2(a, i)))

def report(+s0: U32, c: CK) -> String:
  CK{a, +ok, px, py, +sum} = c
  Bool.show(ok) ++ " " ++ Bool.show(U32.is_eq(sum, s0))

def r(+n: U32, +nn: Nat, b: Array<U32> & Array<U32>) -> String:
  (x, y) = b
  report(sumr(nn, 0, CK{x, True{}, 0, 0, 0}), ck(nn, 0, CK{S.sort2(n, y), True{}, 0, 0, 0}))

def one(+n: U32, +m: U32, +seed: U32) -> String:
  +nn = U32.to_nat(n)
  a = fill(nn, 0, seed, m, Array.new(U32, 21n, 0))
  b = Array.clone(U32, a)
  r(n, nn, b)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(one(1, 5, 7))
    IO.print(one(23, 5, 7))
    IO.print(one(1000, 1000000, 9))
    IO.print(one(100000, 3, 11))
    IO.print(one(500000, 4000000000, 13))
    IO.print(one(500000, 1000, 17))
