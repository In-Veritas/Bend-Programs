# Emits random binary64 operations and their soft-float results (hex) for
# tests/test_f64.py to verify against the host's IEEE doubles.
import Base
import ../../f64.bend as F

def xs(+x: U32) -> U32:
  +b = U32.xor(x, U32.shln(x, 13n))
  +d = U32.xor(b, U32.shrn(b, 17n))
  U32.xor(d, U32.shln(d, 5n))



def hex8(+x: U32) -> String:
  "x" ++ U32.hex(x)



# a random double: exponent field from a window around 1023, sometimes zero,
# huge or tiny, random sign and mantissa
def mk_hi(+r1: U32, +r2: U32) -> U32:
  +k = U32.and(r1, 15)
  +ex = F.sel(U32.is_lt(k, 10), U32.add(1003, U32.mod(r2, 40)),
    F.sel(U32.is_lt(k, 12), U32.mod(r2, 2047),
      F.sel(U32.is_eq(k, 12), 0, F.sel(U32.is_eq(k, 13), 2047, U32.add(1020, U32.and(r2, 7))))))
  +mant = F.sel(U32.is_eq(k, 13), 0, U32.and(U32.shrn(r1, 4n), 1048575))
  U32.or(U32.or(U32.shln(U32.and(U32.shrn(r1, 31n), 1), 31n), U32.shln(ex, 20n)), mant)



def show2(r: U32 & U32) -> String:
  (h, l) = r
  hex8(h) ++ " " ++ hex8(l)



def run_go(a: Bool, b: Bool, c: Bool, +ah: U32, +al: U32, +bh: U32, +bl: U32) -> String:
  match a b c:
    case True{} _ _:
      show2(F.add(ah, al, bh, bl))
    case False{} True{} _:
      show2(F.mul(ah, al, bh, bl))
    case False{} False{} True{}:
      show2(F.div(ah, al, bh, bl))
    case False{} False{} False{}:
      show2(F.sub(ah, al, bh, bl))



def run(+op: U32, +ah: U32, +al: U32, +bh: U32, +bl: U32) -> String:
  run_go(U32.is_eq(op, 0), U32.is_eq(op, 1), U32.is_eq(op, 2), ah, al, bh, bl)



def line(+op: U32, +ah: U32, +al: U32, +bh: U32, +bl: U32) -> String:
  +res = F.sel(U32.is_eq(op, 0), 0, 0)
  U32.show(op) ++ " " ++ hex8(ah) ++ " " ++ hex8(al) ++ " " ++ hex8(bh) ++ " " ++ hex8(bl) ++ " " ++ run(op, ah, al, bh, bl)



def show_fma(+ah: U32, +al: U32, +bh: U32, +bl: U32, +ch: U32, +cl: U32) -> String:
  "4 " ++ hex8(ah) ++ " " ++ hex8(al) ++ " " ++ hex8(bh) ++ " " ++ hex8(bl) ++ " " ++
    hex8(ch) ++ " " ++ hex8(cl) ++ " " ++ show2(F.fma(ah, al, bh, bl, ch, cl))


def show_exp(+xh: U32, +xl: U32, +tab: F.Tab) -> String:
  "5 " ++ hex8(xh) ++ " " ++ hex8(xl) ++ " " ++ show2(F.exp(xh, xl, tab))


def show_cmp(+ah: U32, +al: U32, +bh: U32, +bl: U32) -> String:
  "6 " ++ hex8(ah) ++ " " ++ hex8(al) ++ " " ++ hex8(bh) ++ " " ++ hex8(bl) ++ " " ++
    U32.show(F.b2u(F.lt(ah, al, bh, bl))) ++ U32.show(F.b2u(F.le(ah, al, bh, bl))) ++
    U32.show(F.b2u(F.eq(ah, al, bh, bl))) ++ U32.show(F.b2u(F.ge(ah, al, bh, bl)))


# exp inputs: exponent field 900..1040 (covers tiny, normal, >512, >1024)
def exp_hi(+r: U32) -> U32:
  U32.or(U32.shln(U32.add(900, U32.mod(r, 141)), 20n), U32.and(U32.shrn(r, 8n), 1048575))


def loop2(n: Nat, +seed: U32, +tab: F.Tab) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      +s1 = xs(seed)
      +s2 = xs(s1)
      +s3 = xs(s2)
      +s4 = xs(s3)
      +s5 = xs(s4)
      +s6 = xs(s5)
      +s7 = xs(s6)
      +s8 = xs(s7)
      +s9 = xs(s8)
      do IO<Unit>:
        IO.print(show_fma(mk_hi(s1, s2), s3, mk_hi(s4, s5), s6, mk_hi(s7, s8), s9))
        IO.print(show_exp(exp_hi(s1), s2, tab))
        IO.print(show_cmp(mk_hi(s3, s4), s5, F.sel(U32.is_lt(U32.and(s9, 7), 2), mk_hi(s3, s4), mk_hi(s6, s7)), F.sel(U32.is_lt(U32.and(s9, 7), 1), s5, s8)))
        loop2(p, s9, tab)


def loop(n: Nat, +seed: U32) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      +s1 = xs(seed)
      +s2 = xs(s1)
      +s3 = xs(s2)
      +s4 = xs(s3)
      +s5 = xs(s4)
      +s6 = xs(s5)
      +s7 = xs(s6)
      do IO<Unit>:
        IO.print(line(U32.and(s7, 3), mk_hi(s1, s2), s3, mk_hi(s4, s5), s6))
        loop(p, s7)



def main() -> IO(Unit):
  do IO<Unit>:
    loop(200000n, 2463534242)
    loop2(100000n, 123456789, F.exp_table())
