# Prints fmt_ratio / chance / dec_ceil9 results for tests/test_align.py.
import Base
import ../../align_num.bend as N

def show_bytes(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{+c, rest}:
      SCon{Chr{c}, show_bytes(rest)}

def prng(+x: U32) -> U32:
  +b = U32.xor(x, U32.shln(x, 13n))
  +d = U32.xor(b, U32.shrn(b, 17n))
  U32.xor(d, U32.shln(d, 5n))

def ratios(+n: Nat, +s: U32) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+m:
      +s1 = prng(s)
      +s2 = prng(s1)
      +b = (U32.mod(s1, 400000) + 1 : U32)
      +k = U32.mod(s2, 7)
      +a = N.u32_if(U32.is_lt(k, 2), U32.mod(prng(s2), (b + 1 : U32)), N.u32_if(U32.is_eq(k, 2), U32.mod(prng(s2), 1000), N.u32_if(U32.is_eq(k, 3), b, U32.mod(prng(s2), (U32.div(b, 50) + 1 : U32)))))
      do IO<Unit>:
        IO.print(U32.show(a) ++ " " ++ U32.show(b) ++ " " ++ show_bytes(N.fmt_ratio(a, b, 6, Nil{})) ++ " " ++ show_bytes(N.fmt_ratio(a, b, 4, Nil{})))
        ratios(m, s2)

def dshow(d: N.Dbl) -> String:
  match d:
    case N.Dbl{e, hi, lo}:
      U32.show(e) ++ " " ++ U32.show(hi) ++ " " ++ U32.show(lo)

def chances(+n: Nat, +s: U32) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+m:
      +s1 = prng(s)
      +len = (U32.mod(s1, 30) + 5 : U32)
      +e = U32.mod(prng(s1), 3000000)
      do IO<Unit>:
        IO.print("C " ++ U32.show(len) ++ " " ++ U32.show(e) ++ " " ++ dshow(N.chance(len, e)))
        chances(m, prng(s1))

def main() -> IO(Unit):
  do IO<Unit>:
    ratios(3000n, 12345)
    chances(400n, 999)
    IO.print("D " ++ show_bytes(N.put_u32(Maybe.default(&2, U32, N.dec_ceil9(N.string_bytes("0.95")), 0), Nil{})))
