# Exact numeric helpers for the Vclust `align` stage (LZ-ANI 1.2.3).
#
# - `Dbl`: an exact emulation of IEEE-754 binary64 multiplication for the
#   positive normal numbers LZ-ANI's close/distant probability test uses
#   (`ipow(1 - 4^-len, n)`), so that every anchor choice is decided exactly as
#   upstream decides it.
# - `fmt_ratio`: prints the exact rational a/b the way LZ-ANI's
#   `refresh::real_to_pchar(double(a/b), prec)` prints it (dragonbox shortest
#   decimal, then round-half-up to `prec` significant digits).
# - `dec_ceil9`: parses a decimal (optionally with an exponent) into
#   ceil(value * 10^9), used for exact threshold comparisons.
import Base

def when(-A: Type, c: Bool, k: Bool -> A) -> A:
  k(c)

def u32_if(c: Bool, +a: U32, +b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def b2u(c: Bool) -> U32:
  match c:
    case True{}:
      1
    case False{}:
      0

def u32_min(+a: U32, +b: U32) -> U32:
  u32_if(U32.is_lt(a, b), a, b)

def u32_max(+a: U32, +b: U32) -> U32:
  u32_if(U32.is_lt(a, b), b, a)

# |a - b|
def u32_dist(+a: U32, +b: U32) -> U32:
  u32_if(U32.is_lt(a, b), (b - a : U32), (a - b : U32))

# max(a - b, 0)
def u32_monus(+a: U32, +b: U32) -> U32:
  u32_if(U32.is_lt(a, b), 0, (a - b : U32))

# Smallest d with 2^d >= n (n >= 1), at most 31.
def depth_for(+fuel: Nat, +n: U32, +cap: U32, +d: Nat) -> Nat:
  match fuel:
    case 0n:
      d
    case 1n+f:
      when(Nat, U32.is_le(n, cap), \{
        True: d
        False: depth_for(f, n, U32.shl(cap), 1n+d)
      })
def depth(+n: U32) -> Nat:
  depth_for(31n, n, 1, 0n)

# Binary64 emulation
# ==================
# A positive normal double is m * 2^(E - 1073741824) with m = hi * 2^32 + lo
# in [2^52, 2^53): hi has 21 bits.

type Dbl is Data:
  Dbl{e: U32, hi: U32, lo: U32}

def dbl_one() -> Dbl:
  Dbl{(1073741824 - 52 : U32), 1048576, 0}

def lo16(+x: U32) -> U32:
  U32.and(x, 65535)

def hi16(+x: U32) -> U32:
  U32.shrn(x, 16n)

type Cols is Data:
  Cols{c0: U32, c1: U32, c2: U32, c3: U32, c4: U32, c5: U32, c6: U32}

# 16-bit-limb product of two 53-bit mantissas, normalised limbs c0..c6
# (the product is below 2^106, so the eighth limb is zero).
def mant_mul(+a0: U32, +a1: U32, +a2: U32, +a3: U32,
             +b0: U32, +b1: U32, +b2: U32, +b3: U32) -> Cols:
  +p00 = (a0 * b0 : U32)
  +p01 = (a0 * b1 : U32)
  +p10 = (a1 * b0 : U32)
  +p02 = (a0 * b2 : U32)
  +p11 = (a1 * b1 : U32)
  +p20 = (a2 * b0 : U32)
  +p03 = (a0 * b3 : U32)
  +p12 = (a1 * b2 : U32)
  +p21 = (a2 * b1 : U32)
  +p30 = (a3 * b0 : U32)
  +p13 = (a1 * b3 : U32)
  +p22 = (a2 * b2 : U32)
  +p31 = (a3 * b1 : U32)
  +p23 = (a2 * b3 : U32)
  +p32 = (a3 * b2 : U32)
  +p33 = (a3 * b3 : U32)
  +k0 = lo16(p00)
  +k1 = (hi16(p00) + lo16(p01) + lo16(p10) : U32)
  +k2 = (hi16(p01) + hi16(p10) + lo16(p02) + lo16(p11) + lo16(p20) : U32)
  +k3 = (hi16(p02) + hi16(p11) + hi16(p20) + lo16(p03) + lo16(p12)
    + lo16(p21) + lo16(p30) : U32)
  +k4 = (hi16(p03) + hi16(p12) + hi16(p21) + hi16(p30) + lo16(p13)
    + lo16(p22) + lo16(p31) : U32)
  +k5 = (hi16(p13) + hi16(p22) + hi16(p31) + lo16(p23) + lo16(p32) : U32)
  +k6 = (hi16(p23) + hi16(p32) + lo16(p33) : U32)
  +s1 = (k1 + hi16(k0) : U32)
  +s2 = (k2 + hi16(s1) : U32)
  +s3 = (k3 + hi16(s2) : U32)
  +s4 = (k4 + hi16(s3) : U32)
  +s5 = (k5 + hi16(s4) : U32)
  +s6 = (k6 + hi16(s5) : U32)
  Cols{lo16(k0), lo16(s1), lo16(s2), lo16(s3), lo16(s4), lo16(s5), s6}

def dbl_round(+e: U32, +hi: U32, +lo: U32, up: Bool) -> Dbl:
  match up:
    case False{}:
      Dbl{e, hi, lo}
    case True{}:
      +lo2 = (lo + 1 : U32)
      +hi2 = (hi + b2u(U32.is_eq(lo2, 0)) : U32)
      when(Dbl, U32.is_eq(hi2, 2097152), \{
        True: Dbl{(e + 1 : U32), 1048576, 0}
        False: Dbl{e, hi2, lo2}
      })
# Shift the product right by 48 + t (t = 4 or 5) with round-half-even.
def dbl_norm(+t: Nat, +ebase: U32, c: Cols) -> Dbl:
  match c:
    case Cols{+c0, +c1, +c2, +c3, +c4, +c5, +c6}:
      +tt = U32.from_nat(t)
      +lo = U32.or(U32.shrn(U32.or(c3, U32.shln(c4, 16n)), t),
        U32.shln(c5, Nat.sub(32n, t)))
      +hi = U32.and(U32.or(U32.shrn(c5, t), U32.shln(c6, Nat.sub(16n, t))),
        2097151)
      +guard = U32.and(U32.shrn(c3, Nat.sub(t, 1n)), 1)
      +below = U32.and(c3, (U32.shln(1, Nat.sub(t, 1n)) - 1 : U32))
      +sticky = U32.is_ne(U32.or(U32.or(below, c0), U32.or(c1, c2)), 0)
      +up = U32.is_eq(guard, 1) && (sticky || U32.is_eq(U32.and(lo, 1), 1))
      dbl_round((ebase + 48 + tt : U32), hi, lo, up)

def dbl_mul_top(+ebase: U32, c: Cols, top: Bool) -> Dbl:
  match top:
    case True{}:
      dbl_norm(5n, ebase, c)
    case False{}:
      dbl_norm(4n, ebase, c)

def dbl_mul_cols(+ebase: U32, c: Cols) -> Dbl:
  match c:
    case Cols{+c0, +c1, +c2, +c3, +c4, +c5, +c6}:
      dbl_mul_top(ebase, Cols{c0, c1, c2, c3, c4, c5, c6}, U32.is_ge(c6, 512))

def dbl_mul(x: Dbl, y: Dbl) -> Dbl:
  match x y:
    case Dbl{+xe, +xh, +xl} Dbl{+ye, +yh, +yl}:
      dbl_mul_cols((xe + ye - 1073741824 : U32),
        mant_mul(lo16(xl), hi16(xl), lo16(xh), hi16(xh),
          lo16(yl), hi16(yl), lo16(yh), hi16(yh)))

def dbl_pick(c: Bool, +a: Dbl, +b: Dbl) -> Dbl:
  match c:
    case True{}:
      a
    case False{}:
      b

# LZ-ANI's ipow: r = 1; while e: if e & 1: r *= b; b *= b; e /= 2
def dbl_ipow(+fuel: Nat, done: Bool, +e: U32, +r: Dbl, +b: Dbl) -> Dbl:
  match fuel done:
    case _ True{}:
      r
    case 0n False{}:
      r
    case 1n+f False{}:
      +e2 = U32.shrn(e, 1n)
      dbl_ipow(f, U32.is_eq(e2, 0), e2,
        dbl_pick(U32.is_eq(U32.and(e, 1), 1), dbl_mul(r, b), r), dbl_mul(b, b))

# 1 - 4^-len in binary64 (exact for len <= 26, rounds to 1 above).
def dbl_base(+len: U32) -> Dbl:
  when(Dbl, U32.is_ge(len, 27), \{
    True: dbl_one()
    False: (
      +sh = (53 - len - len : U32)
      when(Dbl, U32.is_ge(sh, 32), \{
        True: (
          Dbl{(1073741824 - 53 : U32),
            (2097152 - U32.shln(1, U32.to_nat((sh - 32 : U32))) : U32), 0})
        False: (
          Dbl{(1073741824 - 53 : U32), 2097151,
            (0 - U32.shln(1, U32.to_nat(sh)) : U32)})
      }))
  })
# ipow(1 - prob_len(len), e)
def chance(+len: U32, +e: U32) -> Dbl:
  dbl_ipow(33n, U32.is_eq(e, 0), e, dbl_one(), dbl_base(len))

def dbl_gt(x: Dbl, y: Dbl) -> Bool:
  match x y:
    case Dbl{+xe, +xh, +xl} Dbl{+ye, +yh, +yl}:
      U32.is_gt(xe, ye) || (U32.is_eq(xe, ye) && (U32.is_gt(xh, yh)
        || (U32.is_eq(xh, yh) && U32.is_gt(xl, yl))))

# 64-bit helpers
# ==============

type W64 is Data:
  W64{hi: U32, lo: U32}

def mul64(+a: U32, +b: U32) -> W64:
  +a0 = lo16(a)
  +a1 = hi16(a)
  +b0 = lo16(b)
  +b1 = hi16(b)
  +p00 = (a0 * b0 : U32)
  +p01 = (a0 * b1 : U32)
  +p10 = (a1 * b0 : U32)
  +p11 = (a1 * b1 : U32)
  +mid = (hi16(p00) + lo16(p01) + lo16(p10) : U32)
  W64{(p11 + hi16(p01) + hi16(p10) + hi16(mid) : U32),
    U32.or(lo16(p00), U32.shln(lo16(mid), 16n))}

def w64_lt(x: W64, y: W64) -> Bool:
  match x y:
    case W64{+xh, +xl} W64{+yh, +yl}:
      U32.is_lt(xh, yh) || (U32.is_eq(xh, yh) && U32.is_lt(xl, yl))

# a / b < t9 / 10^9, exactly (b > 0).
def ratio_lt(+a: U32, +b: U32, +t9: U32) -> Bool:
  w64_lt(mul64(a, 1000000000), mul64(t9, b))

# Decimal parsing: ceil(value * 10^9)
# ==================================

type Dec is Data:
  Dec{digits: List<&2, U32>, point: U32, seen_point: Bool, exp: U32,
    exp_neg: Bool, in_exp: Bool, ok: Bool}

def is_digit(+c: U32) -> Bool:
  U32.is_ge(c, 48) && U32.is_le(c, 57)

def dec_char(+c: U32, d: Dec) -> Dec:
  match d:
    case Dec{+digits, +point, +seen, +exp, +eneg, in_exp, +ok}:
      match in_exp:
        case True{}:
          when(Dec, is_digit(c), \{
            True: Dec{digits, point, seen, (exp * 10 + c - 48 : U32), eneg, True{}, ok}
            False: (
              when(Dec, U32.is_eq(c, 45), \{
                True: Dec{digits, point, seen, exp, True{}, True{}, ok}
                False: (
                  Dec{digits, point, seen, exp, eneg, True{},
                    ok && U32.is_eq(c, 43)})
              }))
          })
        case False{}:
          when(Dec, is_digit(c), \{
            True: (
              Dec{(c - 48 : U32) <> digits, (point + b2u(seen) : U32), seen,
                exp, eneg, False{}, ok})
            False: (
              when(Dec, U32.is_eq(c, 46), \{
                True: Dec{digits, point, True{}, exp, eneg, False{}, ok}
                False: (
                  Dec{digits, point, seen, exp, eneg,
                    U32.is_eq(c, 101) || U32.is_eq(c, 69), ok})
              }))
          })
def dec_feed(bytes: List<&2, U32>, d: Dec) -> Dec:
  match bytes:
    case Nil{}:
      d
    case Con{+c, rest}:
      dec_feed(rest, dec_char(c, d))

# digits are least-significant first; scale = power of ten of the first one
# relative to 10^-9 (as a signed offset +1000).
def dec_sum(digits: List<&2, U32>, +scale: U32, +acc: U32, +sticky: Bool) -> U32:
  match digits:
    case Nil{}:
      (acc + b2u(sticky) : U32)
    case Con{+d, rest}:
      when(U32, U32.is_lt(scale, 1000), \{
        True: dec_sum(rest, (scale + 1 : U32), acc, sticky || U32.is_ne(d, 0))
        False: (
          when(U32, U32.is_ge(scale, 1010), \{
            True: (
              dec_sum(rest, (scale + 1 : U32),
                u32_if(U32.is_eq(d, 0), acc, 4294967295), sticky))
            False: (
              dec_sum(rest, (scale + 1 : U32),
                (acc + d * U32.pow(10, U32.to_nat((scale - 1000 : U32))) : U32), sticky))
          }))
      })
def dec_value(d: Dec) -> Maybe<&2, U32>:
  match d:
    case Dec{+digits, +point, +seen, +exp, +eneg, in_exp, +ok}:
      match ok:
        case False{}:
          None{}
        case True{}:
          # value = int(digits) * 10^(-point +/- exp)
          +sc = u32_if(eneg, (1009 - point - exp : U32), (1009 - point + exp : U32))
          Some{dec_sum(digits, sc, 0, False{})}

def dec_ceil9(bytes: List<&2, U32>) -> Maybe<&2, U32>:
  dec_value(dec_feed(bytes, Dec{Nil{}, 0, False{}, 0, False{}, False{}, True{}}))

def string_bytes(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{c, t}:
      Char.to_u32(c) <> string_bytes(t)

# Decimal printing
# ================

def put_u32_go(+fuel: Nat, +x: U32, tail: List<&2, U32>) -> List<&2, U32>:
  match fuel:
    case 0n:
      tail
    case 1n+f:
      +t2 = {(U32.mod(x, 10) + 48 : U32) <> tail : List<&2, U32>}
      when(List<&2, U32>, U32.is_lt(x, 10), \{
        True: t2
        False: put_u32_go(f, U32.div(x, 10), t2)
      })
def put_u32(+x: U32, tail: List<&2, U32>) -> List<&2, U32>:
  put_u32_go(10n, x, tail)

def put_str(s: List<&2, U32>, tail: List<&2, U32>) -> List<&2, U32>:
  match s:
    case Nil{}:
      tail
    case Con{+c, rest}:
      c <> put_str(rest, tail)

# the nd digits of s, most significant first
def digits_go(+fuel: Nat, +s: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match fuel:
    case 0n:
      acc
    case 1n+f:
      digits_go(f, U32.div(s, 10), (U32.mod(s, 10) + 48 : U32) <> acc)

def zeros(+n: Nat, tail: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      tail
    case 1n+f:
      48 <> zeros(f, tail)

# digits with a '.' after the first k of them
def dotted(+k: Nat, ds: List<&2, U32>, tail: List<&2, U32>) -> List<&2, U32>:
  match k ds:
    case 0n _:
      46 <> put_str(ds, tail)
    case _ Nil{}:
      tail
    case 1n+f Con{+c, rest}:
      c <> dotted(f, rest, tail)

def two_digits(+x: U32, tail: List<&2, U32>) -> List<&2, U32>:
  when(List<&2, U32>, U32.is_lt(x, 10), \{
    True: 48 <> put_u32(x, tail)
    False: put_u32(x, tail)
  })
# refresh::real_to_pchar layout of s * 10^-me with nd significant digits
def fmt_layout(+s: U32, +nd: U32, +me: U32, tail: List<&2, U32>) -> List<&2, U32>:
  +ds = digits_go(U32.to_nat(nd), s, Nil{})
  when(List<&2, U32>, U32.is_eq(me, 0), \{
    True: put_str(ds, tail)
    False: (
      when(List<&2, U32>, U32.is_ge(me, (nd + 4 : U32)), \{
        True: (
          # scientific: d[.ddd]e-XX with exponent nd - 1 - me (negative)
          +ex = (me + 1 - nd : U32)
          when(List<&2, U32>, U32.is_eq(nd, 1), \{
            True: put_str(ds, 101 <> 45 <> two_digits(ex, tail))
            False: dotted(1n, ds, 101 <> 45 <> two_digits(ex, tail))
          }))
        False: (
          when(List<&2, U32>, U32.is_lt(me, nd), \{
            True: dotted(U32.to_nat((nd - me : U32)), ds, tail)
            False: 48 <> 46 <> zeros(U32.to_nat((me - nd : U32)), put_str(ds, tail))
          }))
      }))
  })
# strip trailing zeros of an exact short decimal
def fmt_strip(+fuel: Nat, +s: U32, +nd: U32, +me: U32, tail: List<&2, U32>) -> List<&2, U32>:
  match fuel:
    case 0n:
      fmt_layout(s, nd, me, tail)
    case 1n+f:
      when(List<&2, U32>, U32.is_eq(U32.mod(s, 10), 0) && U32.is_gt(nd, 1) && U32.is_gt(me, 0), \{
        True: fmt_strip(f, U32.div(s, 10), (nd - 1 : U32), (me - 1 : U32), tail)
        False: fmt_layout(s, nd, me, tail)
      })
def fmt_round(+s: U32, +prec: U32, +me: U32, up: Bool, tail: List<&2, U32>) -> List<&2, U32>:
  +s2 = (s + b2u(up) : U32)
  when(List<&2, U32>, U32.is_eq(s2, U32.pow(10, U32.to_nat(prec))), \{
    True: fmt_layout(U32.pow(10, U32.to_nat((prec - 1 : U32))), prec, (me - 1 : U32), tail)
    False: fmt_layout(s2, prec, me, tail)
  })
# collect significant digits: s so far (nd digits), remainder r
def fmt_collect(+fuel: Nat, +s: U32, +nd: U32, +me: U32, +r: U32, +b: U32,
                +prec: U32, tail: List<&2, U32>) -> List<&2, U32>:
  match fuel:
    case 0n:
      tail
    case 1n+f:
      when(List<&2, U32>, U32.is_lt(nd, prec), \{
        True: (
          +r10 = (r * 10 : U32)
          fmt_collect(f, (s * 10 + U32.div(r10, b) : U32), (nd + 1 : U32),
            (me + 1 : U32), U32.mod(r10, b), b, prec, tail))
        False: when(List<&2, U32>, U32.is_eq(r, 0), \{
          True: fmt_strip(12n, s, nd, me, tail)
          False: fmt_round(s, prec, me, U32.is_ge(U32.div((r * 10 : U32), b), 5), tail)
        })
      })

# skip leading fractional zeros of r / b (r < b, r > 0)
def fmt_lead(+fuel: Nat, +z: U32, +r: U32, +b: U32, +prec: U32,
             tail: List<&2, U32>) -> List<&2, U32>:
  match fuel:
    case 0n:
      tail
    case 1n+f:
      +r10 = (r * 10 : U32)
      +d = U32.div(r10, b)
      when(List<&2, U32>, U32.is_eq(d, 0), \{
        True: fmt_lead(f, (z + 1 : U32), r10, b, prec, tail)
        False: fmt_collect(20n, d, 1, (z + 1 : U32), U32.mod(r10, b), b, prec, tail)
      })

# real_to_pchar(double(a) / b, prec): requires b < 429496730 and a / b < 10.
def fmt_ratio(+a: U32, +b: U32, +prec: U32, tail: List<&2, U32>) -> List<&2, U32>:
  when(List<&2, U32>, U32.is_eq(a, 0) || U32.is_eq(b, 0), \{
    True: 48 <> tail
    False: (
      +q = U32.div(a, b)
      when(List<&2, U32>, U32.is_eq(q, 0), \{
        True: fmt_lead(60n, 0, a, b, prec, tail)
        False: fmt_collect(20n, q, 1, 0, U32.mod(a, b), b, prec, tail)
      }))
  })