# Exact integer arithmetic for the Kmer-db-compatible prefilter.
#
# Bend has U32 (and F32) only. Kmer-db works with 64-bit k-mers and doubles:
#
# * the --kmers-fraction sampler (Kmer-db MinHashFilter) hashes a 64-bit
#   k-mer with MurmurHash3-style 64-bit multiplies; `minhash` reproduces it
#   bit for bit on U32 pairs, and `frac_threshold` reproduces
#   (uint64_t)((double)UINT64_MAX * fraction) from the decimal fraction
#   (correctly rounded to binary64 first, as strtod/istream would);
# * ani-shorter = 1 + ln(2c / (c + m)) / k (c shared k-mers, m the smaller
#   k-mer count). `ani_x` computes round(1e6 * ani-shorter) with a 64-bit
#   fixed-point natural logarithm (atanh series), i.e. the 6-decimal value
#   Kmer-db prints with Double2PChar. Its error is below 1e-17, so it only
#   differs from the binary64 computation when the exact value lies within
#   ~1e-10 of a rounding boundary of the 6th decimal.
import Base

type W2 is Data:
  W2{+hi: U32, +lo: U32}

type W3 is Data:
  W3{+i: U32, +hi: U32, +lo: U32}

def sel(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def b2u(c: Bool) -> U32:
  sel(c, 1, 0)

def shl(x: U32, s: U32) -> U32:
  U32.shln(x, U32.to_nat(s))

def shr(x: U32, s: U32) -> U32:
  U32.shrn(x, U32.to_nat(s))

def w2sel(c: Bool, a: W2, b: W2) -> W2:
  match c:
    case True{}:
      a
    case False{}:
      b

# High word of the 32 x 32 -> 64 product (the low word is U32.mul).
def mulhi(+x: U32, +y: U32) -> U32:
  +xl = U32.and(x, 65535)
  +xh = U32.shrn(x, 16n)
  +yl = U32.and(y, 65535)
  +yh = U32.shrn(y, 16n)
  +ll = U32.mul(xl, yl)
  +lh = U32.mul(xl, yh)
  +hl = U32.mul(xh, yl)
  +hh = U32.mul(xh, yh)
  +mid = (lh + hl : U32)
  +mc = b2u(U32.is_lt(mid, lh))
  +lo = (ll + U32.shln(mid, 16n) : U32)
  +lc = b2u(U32.is_lt(lo, ll))
  (hh + U32.shrn(mid, 16n) + U32.shln(mc, 16n) + lc : U32)

def mul32(+x: U32, +y: U32) -> W2:
  W2{mulhi(x, y), U32.mul(x, y)}

def add64(a: W2, b: W2) -> W2:
  W2{+ah, +al} = a
  W2{+bh, +bl} = b
  +lo = (al + bl : U32)
  W2{(ah + bh + b2u(U32.is_lt(lo, al)) : U32), lo}

def sub64(a: W2, b: W2) -> W2:
  W2{+ah, +al} = a
  W2{+bh, +bl} = b
  W2{(ah - bh - b2u(U32.is_lt(al, bl)) : U32), (al - bl : U32)}

def lt64(a: W2, b: W2) -> Bool:
  W2{+ah, +al} = a
  W2{+bh, +bl} = b
  U32.is_lt(ah, bh) || (U32.is_eq(ah, bh) && U32.is_lt(al, bl))

def eq64(a: W2, b: W2) -> Bool:
  W2{+ah, +al} = a
  W2{+bh, +bl} = b
  U32.is_eq(ah, bh) && U32.is_eq(al, bl)

def xor64(a: W2, b: W2) -> W2:
  W2{+ah, +al} = a
  W2{+bh, +bl} = b
  W2{U32.xor(ah, bh), U32.xor(al, bl)}

def shl1(a: W2) -> W2:
  W2{+h, +l} = a
  W2{U32.or(U32.shln(h, 1n), U32.shrn(l, 31n)), U32.shln(l, 1n)}

# a << s for s < 64.
def shl64(a: W2, +s: U32) -> W2:
  W2{+h, +l} = a
  w2sel(U32.is_ge(s, 32), W2{shl(l, (s - 32 : U32)), 0},
    w2sel(U32.is_eq(s, 0), W2{h, l},
      W2{U32.or(shl(h, s), shr(l, (32 - s : U32))), shl(l, s)}))

# a >> s for s < 64.
def shr64(a: W2, +s: U32) -> W2:
  W2{+h, +l} = a
  w2sel(U32.is_ge(s, 32), W2{0, shr(h, (s - 32 : U32))},
    w2sel(U32.is_eq(s, 0), W2{h, l},
      W2{shr(h, s), U32.or(shr(l, s), shl(h, (32 - s : U32)))}))

# a * b mod 2^64.
def mul64lo(a: W2, b: W2) -> W2:
  W2{+ah, +al} = a
  W2{+bh, +bl} = b
  W2{(mulhi(al, bl) + U32.mul(ah, bl) + U32.mul(al, bh) : U32), U32.mul(al, bl)}

def w2hi(a: W2) -> U32:
  W2{+h, +l} = a
  h

def w2lo(a: W2) -> U32:
  W2{+h, +l} = a
  l

# MinHash filter (Kmer-db filter.h)
# ================================

def fmix_step(k: W2, m: W2) -> W2:
  W2{+h, +l} = k
  mul64lo(W2{h, U32.xor(l, U32.shrn(h, 1n))}, m)

def fmix_fin(b: W2) -> W2:
  W2{+h, +l} = b
  W2{h, U32.xor(l, U32.shrn(h, 1n))}

def fmix64(k: W2) -> W2:
  fmix_fin(fmix_step(fmix_step(k, W2{4283543511, 3981806797}), W2{3301882366, 444984403}))

def rotl31(a: W2) -> W2:
  W2{+h, +l} = a
  W2{U32.or(U32.shln(h, 31n), U32.shrn(l, 1n)), U32.or(U32.shln(l, 31n), U32.shrn(h, 1n))}

def minhash_fin(+h1: W2, +h2: W2) -> W2:
  +f1 = fmix64(h1)
  +f2 = fmix64(h2)
  +g1 = add64(f1, f2)
  xor64(g1, add64(f2, g1))

def minhash_mid(h: W2, +kd4: U32) -> W2:
  W2{+hh, +hl} = h
  +c = {W2{0, U32.xor(42, kd4)} : W2}
  +h1 = add64(W2{hh, U32.xor(U32.xor(hl, 42), kd4)}, c)
  minhash_fin(h1, add64(c, h1))

# Kmer-db MinHashFilter::hash; kd4 = ceil(k / 4).
def minhash(+kmer: W2, +kd4: U32) -> W2:
  minhash_mid(mul64lo(rotl31(mul64lo(kmer, W2{2277735313, 289559509})), W2{1291169091, 658871167}), kd4)

# Bit-serial division
# ===================

# Shifts n more quotient bits: r < den, each step r = 2r, subtract when
# r >= den. Returns (q, r). den < 2^63.
type QR is Data:
  QR{+q: W3, +r: W2}

def w3shl1(+q: W3, +bit: U32) -> W3:
  W3{+i, +h, +l} = q
  W3{U32.or(U32.shln(i, 1n), U32.shrn(h, 31n)), U32.or(U32.shln(h, 1n), U32.shrn(l, 31n)),
     U32.or(U32.shln(l, 1n), bit)}

def bitdiv_step(+q: W3, +r2: W2, +den: W2, ge: Bool) -> QR:
  match ge:
    case True{}:
      QR{w3shl1(q, 1), sub64(r2, den)}
    case False{}:
      QR{w3shl1(q, 0), r2}

def bitdiv(n: Nat, +den: W2, qr: QR) -> QR:
  match n:
    case 0n:
      qr
    case 1n+p:
      QR{+q, +r} = qr
      +r2 = shl1(r)
      bitdiv(p, den, bitdiv_step(q, r2, den, Bool.not(lt64(r2, den))))

def qr_low(qr: QR) -> W2:
  QR{+q, +r} = qr
  W3{+i, +h, +l} = q
  W2{h, l}

# floor(num * 2^64 / den) for num < den < 2^63.
def frac64(+num: W2, +den: W2) -> W2:
  qr_low(bitdiv(64n, den, QR{W3{0, 0, 0}, num}))

# 64-bit fixed-point fractions
# ============================

# floor(a * b / 2^64)
def mulfx(+a: W2, +b: W2) -> W2:
  W2{+ah, +al} = a
  W2{+bh, +bl} = b
  +hll = U32.mul(ah, bl)
  +lhl = U32.mul(al, bh)
  +llh = mulhi(al, bl)
  +s1 = (hll + lhl : U32)
  +c1 = b2u(U32.is_lt(s1, hll))
  +s2 = (s1 + llh : U32)
  +c2 = b2u(U32.is_lt(s2, s1))
  add64(W2{mulhi(ah, bh), U32.mul(ah, bh)},
    add64(W2{0, mulhi(ah, bl)}, add64(W2{0, mulhi(al, bh)}, W2{0, (c1 + c2 : U32)})))

# a / m for m < 65536, by 16-bit chunks.
def div_small(+a: W2, +m: U32) -> W2:
  W2{+h, +l} = a
  +d3 = U32.shrn(h, 16n)
  +q3 = U32.div(d3, m)
  +t2 = U32.or(U32.shln(U32.mod(d3, m), 16n), U32.and(h, 65535))
  +q2 = U32.div(t2, m)
  +t1 = U32.or(U32.shln(U32.mod(t2, m), 16n), U32.shrn(l, 16n))
  +q1 = U32.div(t1, m)
  +t0 = U32.or(U32.shln(U32.mod(t1, m), 16n), U32.and(l, 65535))
  +q0 = U32.div(t0, m)
  W2{U32.or(U32.shln(q3, 16n), q2), U32.or(U32.shln(q1, 16n), q0)}

# 2 * atanh(s) = sum 2 s^(2i+1) / (2i+1)
def atanh_go(n: Nat, +t: W2, +term: W2, +odd: U32, +acc: W2) -> W2:
  match n:
    case 0n:
      acc
    case 1n+p:
      +t2 = mulfx(term, t)
      atanh_go(p, t, t2, (odd + 2 : U32), add64(acc, div_small(t2, odd)))

def atanh2(+s: W2) -> W2:
  shl1(atanh_go(16n, mulfx(s, s), s, 3, s))

def bitlen_go(n: Nat, +x: U32, +acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      bitlen_go(p, U32.shrn(x, 1n), (acc + b2u(U32.is_ne(x, 0)) : U32))

def bitlen64(a: W2) -> U32:
  W2{+h, +l} = a
  sel(U32.is_ne(h, 0), (32 + bitlen_go(32n, h, 0) : U32), bitlen_go(32n, l, 0))

# e ln 2 as (integer part, 64-bit fraction); ln 2 = 0.B17217F7D1CF79AB...
def eln2(+e: U32) -> W3:
  +lo = U32.mul(e, 3520035243)
  +mid = add64(W2{mulhi(e, 2977044471), U32.mul(e, 2977044471)}, W2{0, mulhi(e, 3520035243)})
  W3{w2hi(mid), w2lo(mid), lo}

def w3add2(a: W3, +b: W2) -> W3:
  W3{+i, +h, +l} = a
  +f = add64(W2{h, l}, b)
  W3{(i + b2u(lt64(f, b)) : U32), w2hi(f), w2lo(f)}

def w3sub2(a: W3, +b: W2) -> W3:
  W3{+i, +h, +l} = a
  +f = {W2{h, l} : W2}
  +g = sub64(f, b)
  W3{(i - b2u(lt64(f, b)) : U32), w2hi(g), w2lo(g)}

# ln(d / n) for 1 <= n <= d < 2^62, as integer part and 64-bit fraction.
def ln_ratio_fin(+e: U32, +d: W2, +bb: W2, up: Bool) -> W3:
  # d / bb in [1, 1.5) when up is False; with up, d / 2bb in [0.75, 1)
  match up:
    case True{}:
      +b2 = shl1(bb)
      w3sub2(eln2((e + 1 : U32)), atanh2(frac64(sub64(b2, d), add64(b2, d))))
    case False{}:
      w3add2(eln2(e), atanh2(frac64(sub64(d, bb), add64(d, bb))))

def ln_ratio_norm(+e: U32, +d: W2, +n: W2, +bb: W2, low: Bool) -> W3:
  match low:
    case True{}:
      +e2 = (e - 1 : U32)
      +b2 = shl64(n, e2)
      ln_ratio_fin(e2, d, b2, Bool.not(lt64(shl1(d), add64(b2, shl1(b2)))))
    case False{}:
      ln_ratio_fin(e, d, bb, Bool.not(lt64(shl1(d), add64(bb, shl1(bb)))))

def ln_ratio(+d: W2, +n: W2) -> W3:
  +e = (bitlen64(d) - bitlen64(n) : U32)
  +bb = shl64(n, e)
  ln_ratio_norm(e, d, n, bb, lt64(d, bb))

# ani-shorter
# ===========

# The value v = 1 - ln(d/n) / k as (one, w): one when v = 1, else w is
# floor(v * 2^64) when 0 <= v < 1; neg when v < 0.
type Ani is Data:
  Ani{one: Bool, neg: Bool, +w: W2}

def ani_of(+z: W3) -> Ani:
  W3{+zi, +zh, +zl} = z
  +zero = U32.is_eq(zh, 0) && U32.is_eq(zl, 0)
  Ani{U32.is_eq(zi, 0) && zero, (U32.is_eq(zi, 1) && Bool.not(zero)) || U32.is_gt(zi, 1),
      sub64(W2{0, 0}, W2{zh, zl})}

# ln(d/n) / k for k < 65536 (W3 by small).
def div3_small(+a: W3, +m: U32) -> W3:
  W3{+i, +h, +l} = a
  +qi = U32.div(i, m)
  +ri = U32.mod(i, m)
  +d3 = U32.or(U32.shln(ri, 16n), U32.shrn(h, 16n))
  +q3 = U32.div(d3, m)
  +t2 = U32.or(U32.shln(U32.mod(d3, m), 16n), U32.and(h, 65535))
  +q2 = U32.div(t2, m)
  +t1 = U32.or(U32.shln(U32.mod(t2, m), 16n), U32.shrn(l, 16n))
  +q1 = U32.div(t1, m)
  +t0 = U32.or(U32.shln(U32.mod(t1, m), 16n), U32.and(l, 65535))
  +q0 = U32.div(t0, m)
  W3{qi, U32.or(U32.shln(q3, 16n), q2), U32.or(U32.shln(q1, 16n), q0)}

# ani-shorter for c shared k-mers, m = min(count_a, count_b), 1 <= c <= m.
def ani(+c: U32, +m: U32, +k: U32) -> Ani:
  +n = {W2{U32.shrn(c, 31n), U32.shln(c, 1n)} : W2}
  +d = add64(W2{0, c}, W2{0, m})
  ani_of(div3_small(ln_ratio(d, n), k))

def ani_x_w(w: W2) -> U32:
  W2{+wh, +wl} = w
  +p1h = mulhi(wl, 1000000)
  +p2h = mulhi(wh, 1000000)
  +p2l = U32.mul(wh, 1000000)
  +m1 = (p2l + p1h : U32)
  +c1 = b2u(U32.is_lt(m1, p2l))
  +m2 = (m1 + 2147483648 : U32)
  +c2 = b2u(U32.is_lt(m2, m1))
  (p2h + c1 + c2 : U32)

# round(1e6 * v) for 0 <= v <= 1.
def ani_x(a: Ani) -> U32:
  Ani{one, neg, +w} = a
  match one:
    case True{}:
      1000000
    case False{}:
      ani_x_w(w)

# v >= t, with t = (t_one, t_fx) (t_fx = floor(t * 2^64) when t < 1).
def ani_ge(a: Ani, t_one: Bool, +t_fx: W2) -> Bool:
  Ani{one, neg, +w} = a
  match one:
    case True{}:
      True{}
    case False{}:
      match neg t_one:
        case True{} _:
          False{}
        case False{} True{}:
          False{}
        case False{} False{}:
          Bool.not(lt64(w, t_fx))

# Decimal numbers
# ===============

# A parsed decimal string I[.F][(e|E)[+-]X]: its digits (most significant
# first), the number of fraction digits and the exponent.
type Dec is Data:
  Dec{+ok: Bool, digits: List<&2, U32>, +nfrac: U32, +eneg: Bool, +ex: U32}

# st: 0 integer part, 1 fraction part, 2 after 'e', 3 exponent digits
type DS is Data:
  DS{+st: U32, digits: List<&2, U32>, +nfrac: U32, +eneg: Bool, +ex: U32, +ok: Bool, +seen: Bool}

def ds_digit_k(ise: Bool, +d: U32, +st: U32, digits: List<&2, U32>, +nfrac: U32, +eneg: Bool, +ex: U32,
               +ok: Bool, +seen: Bool) -> DS:
  match ise:
    case True{}:
      DS{3, digits, nfrac, eneg, (ex * 10 + d : U32), ok, seen}
    case False{}:
      DS{st, Con{d, digits}, (nfrac + b2u(U32.is_eq(st, 1)) : U32), eneg, ex, ok, True{}}

def ds_digit(+d: U32, s: DS) -> DS:
  DS{+st, digits, +nfrac, +eneg, +ex, +ok, +seen} = s
  ds_digit_k(U32.is_ge(st, 2), d, st, digits, nfrac, eneg, ex, ok, seen)

def ds_dot(s: DS) -> DS:
  DS{+st, digits, +nfrac, +eneg, +ex, +ok, +seen} = s
  DS{sel(U32.is_eq(st, 0), 1, 9), digits, nfrac, eneg, ex, ok && U32.is_eq(st, 0), seen}

def ds_e(s: DS) -> DS:
  DS{+st, digits, +nfrac, +eneg, +ex, +ok, +seen} = s
  DS{2, digits, nfrac, eneg, ex, ok && U32.is_lt(st, 2) && seen, seen}

def ds_sign(+c: U32, s: DS) -> DS:
  DS{+st, digits, +nfrac, +eneg, +ex, +ok, +seen} = s
  DS{3, digits, nfrac, U32.is_eq(c, 45), ex, ok && U32.is_eq(st, 2), seen}

def ds_bad(s: DS) -> DS:
  DS{+st, digits, +nfrac, +eneg, +ex, +ok, +seen} = s
  DS{st, digits, nfrac, eneg, ex, False{}, seen}

def ds_char(isd: Bool, isdot: Bool, ise: Bool, issign: Bool, +c: U32, s: DS) -> DS:
  match isd isdot ise issign:
    case True{} _ _ _:
      ds_digit((c - 48 : U32), s)
    case False{} True{} _ _:
      ds_dot(s)
    case False{} False{} True{} _:
      ds_e(s)
    case False{} False{} False{} True{}:
      ds_sign(c, s)
    case False{} False{} False{} False{}:
      ds_bad(s)

def ds_go(t: String, s: DS) -> DS:
  match t:
    case SNil{}:
      s
    case SCon{Chr{+c}, rest}:
      ds_go(rest, ds_char(U32.is_ge(c, 48) && U32.is_le(c, 57), U32.is_eq(c, 46),
        U32.is_eq(c, 101) || U32.is_eq(c, 69), U32.is_eq(c, 43) || U32.is_eq(c, 45), c, s))

def u32_rev(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case Con{+h, t}:
      u32_rev(t, Con{h, acc})

def ds_fin(s: DS) -> Dec:
  DS{+st, digits, +nfrac, +eneg, +ex, +ok, +seen} = s
  Dec{ok && seen && U32.is_ne(st, 2), u32_rev(digits, Nil{}), nfrac, eneg, ex}

def dec_parse(t: String) -> Dec:
  ds_fin(ds_go(t, DS{0, Nil{}, 0, False{}, 0, True{}, False{}}))

def strip_zeros(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{0, t}:
      strip_zeros(t)
    case Con{+h, t}:
      Con{h, t}

# A decimal as num / 10^den_e (value = D * 10^up / 10^dn), D < 10^18.
type DV is Data:
  DV{+num: W2, +den: W2}

def pow10(n: Nat, +acc: W2) -> W2:
  match n:
    case 0n:
      acc
    case 1n+p:
      pow10(p, mul64lo(acc, W2{0, 10}))


# digits -> W2 (at most 18 significant digits are used; the number of
# dropped digits raises the exponent)
type DVal is Data:
  DVal{+v: W2, +dropped: U32}

def digits_val(xs: List<&2, U32>, +acc: W2, +used: U32, +dropped: U32) -> DVal:
  match xs:
    case Nil{}:
      DVal{acc, dropped}
    case Con{+h, t}:
      +take = U32.is_lt(used, 18)
      digits_val(t, w2sel(take, add64(mul64lo(acc, W2{0, 10}), W2{0, h}), acc),
        (used + b2u(take) : U32), (dropped + b2u(Bool.not(take)) : U32))

# value = num / den with den = 10^d, d <= 18 (smaller values lose digits).
def dv_scale(n: Nat, +num: W2, +d: U32) -> DV:
  match n:
    case 0n:
      DV{num, pow10(U32.to_nat(d), W2{0, 1})}
    case 1n+p:
      +big = U32.is_gt(d, 18)
      dv_scale(p, w2sel(big, div_small(num, 10), num), sel(big, (d - 1 : U32), d))

def dv_make(dv: DVal, +nfrac: U32, +eneg: Bool, +ex: U32) -> DV:
  DVal{+v, +dropped} = dv
  # exponent E = +-ex - nfrac + dropped; value = v * 10^E
  +pos = (sel(eneg, 0, ex) + dropped : U32)
  +neg = (sel(eneg, ex, 0) + nfrac : U32)
  +up = sel(U32.is_gt(pos, neg), (pos - neg : U32), 0)
  +dn = sel(U32.is_gt(neg, pos), (neg - pos : U32), 0)
  +num = pow10(U32.to_nat(U32.min(up, 20)), v)
  dv_scale(U32.to_nat(dn), num, dn)

def dec_value(d: Dec) -> DV:
  Dec{+ok, digits, +nfrac, +eneg, +ex} = d
  dv_make(digits_val(strip_zeros(digits), W2{0, 0}, 0, 0), nfrac, eneg, ex)

# A threshold t in [0, 1]: (t >= 1, floor(t * 2^64)).
type Thr is Data:
  Thr{+one: Bool, +fx: W2}

def thr_of(dv: DV) -> Thr:
  DV{+num, +den} = dv
  +ge = Bool.not(lt64(num, den))
  Thr{ge, w2sel(ge, W2{0, 0}, frac64(w2sel(ge, W2{0, 0}, num), den))}

# MinHash threshold (uint64_t)((double)UINT64_MAX * f) for 0 <= f < 1,
# where f is first rounded to the nearest binary64 (ties to even).
type FS is Data:
  FS{+r: W2, +p: U32, +found: Bool, +m: W2, +nb: U32}

# Scan quotient bits: find the leading one (position p after the point),
# then collect 52 more mantissa bits.
def fth_go(n: Nat, +den: W2, s: FS) -> FS:
  match n:
    case 0n:
      s
    case 1n+q:
      FS{+r, +p, +found, +m, +nb} = s
      +r2 = shl1(r)
      +bit = Bool.not(lt64(r2, den))
      +r3 = w2sel(bit, sub64(r2, den), r2)
      +collect = found && U32.is_lt(nb, 52)
      +done = found && U32.is_eq(nb, 52)
      fth_go(q, den, FS{w2sel(done, r, r3), sel(found, p, (p + 1 : U32)), found || bit,
        w2sel(collect, add64(shl1(m), W2{0, b2u(bit)}), w2sel(found, m, W2{0, 1})),
        sel(collect, (nb + 1 : U32), nb)})

def fth_round(s: FS, +den: W2) -> W2:
  FS{+r, +p, +found, +m, +nb} = s
  +r2 = shl1(r)
  +rb = Bool.not(lt64(r2, den))
  +sticky = Bool.not(eq64(w2sel(rb, sub64(r2, den), r2), W2{0, 0}))
  +up = rb && (sticky || U32.is_eq(U32.and(w2lo(m), 1), 1))
  +m2 = add64(m, W2{0, b2u(up)})
  +carry = U32.is_eq(w2hi(m2), 2097152)
  +m3 = w2sel(carry, W2{1048576, 0}, m2)
  +p2 = sel(carry, (p - 1 : U32), p)
  w2sel(Bool.not(found), W2{0, 0},
    w2sel(U32.is_le(p2, 12), shl64(m3, (12 - p2 : U32)),
      w2sel(U32.is_ge(p2, 76), W2{0, 0}, shr64(m3, U32.min((p2 - 12 : U32), 63)))))

def frac_threshold(dv: DV) -> W2:
  DV{+num, +den} = dv
  fth_round(fth_go(1200n, den, FS{num, 0, False{}, W2{0, 0}, 0}), den)

# %g (6 significant digits) of a decimal, as C++ ostream prints a double.
# The rounding to 6 digits is done on the decimal digits (half up).
type G6 is Data:
  G6{+n: U32, +next: U32, +len: U32}

def g6_go(xs: List<&2, U32>, +i: U32, +n: U32, +next: U32, +len: U32) -> G6:
  match xs:
    case Nil{}:
      G6{n, next, len}
    case Con{+h, t}:
      +lt = U32.is_lt(i, 6)
      g6_go(t, (i + 1 : U32), sel(lt, (n * 10 + h : U32), n), sel(U32.is_eq(i, 6), h, next), (len + 1 : U32))

# n < 10^6 as 6 digits without trailing zeros (n > 0)
def digits6(fuel: Nat, +n: U32, +acc: String, +strip: Bool) -> String:
  match fuel:
    case 0n:
      acc
    case 1n+p:
      +d = U32.mod(n, 10)
      +skip = strip && U32.is_eq(d, 0)
      digits6(p, U32.div(n, 10), Bool.pick(String, skip, acc, SCon{Chr{(d + 48 : U32)}, acc}), skip)

def zeros(n: Nat, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      zeros(p, SCon{'0', acc})

def str_split(n: Nat, s: String, acc: String) -> String & String:
  match n s:
    case 0n _:
      (String.reverse(acc), s)
    case 1n+p SNil{}:
      str_split(p, SNil{}, SCon{'0', acc})
    case 1n+p SCon{h, t}:
      str_split(p, t, SCon{h, acc})

def fixed_pos(r: String & String) -> String:
  (ip, fp) = r
  match fp:
    case SNil{}:
      ip
    case SCon{h, t}:
      ip ++ "." ++ SCon{h, t}

def exp2(+x: U32) -> String:
  Bool.pick(String, U32.is_lt(x, 10), "0", "") ++ U32.show(x)

def sci_e(+xneg: Bool, +xa: U32) -> String:
  "e" ++ Bool.pick(String, xneg, "-", "+") ++ exp2(xa)

def sci(s: String, +xneg: Bool, +xa: U32) -> String:
  match s:
    case SNil{}:
      "0"
    case SCon{h, SNil{}}:
      SCon{h, SNil{}} ++ sci_e(xneg, xa)
    case SCon{h, SCon{h2, t2}}:
      SCon{h, SNil{}} ++ "." ++ SCon{h2, t2} ++ sci_e(xneg, xa)

# Only the selected branch is evaluated (Bool.pick would build both).
def g_layout(sc: Bool, neg: Bool, s: String, +xneg: Bool, +xa: U32) -> String:
  match sc neg:
    case True{} _:
      sci(s, xneg, xa)
    case False{} True{}:
      "0." ++ zeros(U32.to_nat((xa - 1 : U32)), s)
    case False{} False{}:
      fixed_pos(str_split(U32.to_nat((xa + 1 : U32)), s, ""))

def g_fmt(+n: U32, +x: U32) -> String:
  # x = decimal exponent of the first digit + 1000
  +s = digits6(6n, n, "", True{})
  +xneg = U32.is_lt(x, 1000)
  +xa = sel(xneg, (1000 - x : U32), (x - 1000 : U32))
  g_layout((xneg && U32.is_gt(xa, 4)) || (Bool.not(xneg) && U32.is_ge(xa, 6)), xneg, s, xneg, xa)

def g_zero(z: Bool, +m: U32, +x: U32) -> String:
  match z:
    case True{}:
      "0"
    case False{}:
      g_fmt(m, x)

def g_of(g: G6, +e: U32) -> String:
  G6{+n, +next, +len} = g
  # pad n to 6 digits when the mantissa is shorter
  +pad = (n * U32.pow(10, U32.to_nat((6 - U32.min(len, 6) : U32))) : U32)
  +m = (pad + b2u(U32.is_ge(next, 5) && U32.is_gt(len, 6)) : U32)
  +carry = U32.is_eq(m, 1000000)
  +x = (e + len - 1 + b2u(carry) : U32)
  g_zero(U32.is_eq(len, 0), sel(carry, 100000, m), x)

# e = exponent of the last digit + 1000
def dec_g(d: Dec) -> String:
  Dec{+ok, digits, +nfrac, +eneg, +ex} = d
  g_of(g6_go(strip_zeros(digits), 0, 0, 0, 0), (1000 + sel(eneg, 0, ex) - sel(eneg, ex, 0) - nfrac : U32))
