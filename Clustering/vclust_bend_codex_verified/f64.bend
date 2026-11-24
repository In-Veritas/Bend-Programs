# Software IEEE-754 binary64 arithmetic on U32 pairs (round to nearest even).
#
# Bend has U32 and F32 only, while Clusty/igraph compute Leiden in C doubles,
# so a byte-identical Leiden needs bit-exact doubles. A double is its raw bits
# as (hi, lo). Every operation is exact IEEE: add, sub, mul, div, fma, the
# ordered comparisons, and glibc's exp (the FMA variant that the static
# Clusty 1.2.2 binary selects on x86-64 CPUs with FMA, ported bit for bit
# with its own __exp_data table).
#
# Internally a magnitude is a 128-bit integer W4{a, b, c, d} (a = top limb)
# times a power of two; `round128` normalizes and rounds it once.
import Base

type W4 is Data:
  W4{+a: U32, +b: U32, +c: U32, +d: U32}




# ---------------------------------------------------------------------------
# exp(x): glibc's __exp as compiled in the static Clusty binary for FMA CPUs
# (__ieee754_exp_fma: z + Shift, the reduction and the polynomial fused).
# Supported domain: every x >= 0 (inf/NaN too) and every x > -512 (the
# callers only pass x >= 0).

type Tab is Data:
  TL{+th: U32, +tl: U32, +sh: U32, +sl: U32}
  TN{+lo: Tab, +hi: Tab}



# ---------------------------------------------------------------------------
# Value-style API for non-hot code: a double as a D record.

type D is Data:
  D{+hi: U32, +lo: U32}




def sel(c: Bool, a: U32, b: U32) -> U32:
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




def shl(x: U32, s: U32) -> U32:
  U32.shln(x, U32.to_nat(s))




def shr(x: U32, s: U32) -> U32:
  U32.shrn(x, U32.to_nat(s))




def nz(x: U32) -> U32:
  b2u(U32.is_ne(x, 0))




# 32x32 -> 64 product
def mul32(+x: U32, +y: U32) -> U32 & U32:
  +xh = U32.shrn(x, 16n)
  +xl = U32.and(x, 65535)
  +yh = U32.shrn(y, 16n)
  +yl = U32.and(y, 65535)
  +ll = U32.mul(xl, yl)
  +lh = U32.mul(xl, yh)
  +hl = U32.mul(xh, yl)
  +hh = U32.mul(xh, yh)
  +mid = U32.add(lh, hl)
  +c1 = b2u(U32.is_lt(mid, lh))
  +lo = U32.add(ll, U32.shln(mid, 16n))
  +c2 = b2u(U32.is_lt(lo, ll))
  (U32.add(U32.add(hh, U32.shrn(mid, 16n)), U32.add(U32.shln(c1, 16n), c2)), lo)




# ---------------------------------------------------------------------------
# 128-bit helpers

def w4_or_low(x: W4, +s: U32) -> W4:
  match x:
    case W4{a, b, c, d}:
      W4{a, b, c, U32.or(d, s)}




# shift right by k whole words (k = 0..3) collecting the sticky word
def w4_shr_words(x: W4, +k: U32) -> W4 & U32:
  match x:
    case W4{a, b, c, d}:
      +k1 = U32.is_ge(k, 1)
      +k2 = U32.is_ge(k, 2)
      +k3 = U32.is_ge(k, 3)
      +na = sel(k1, 0, a)
      +nb = sel(k2, 0, sel(k1, a, b))
      +nc = sel(k3, 0, sel(k2, a, sel(k1, b, c)))
      +nd = sel(k3, a, sel(k2, b, sel(k1, c, d)))
      +st = U32.or(sel(k1, d, 0), U32.or(sel(k2, c, 0), sel(k3, b, 0)))
      (W4{na, nb, nc, nd}, st)




def w4_shr_bits_go(r: W4 & U32, +s: U32) -> W4:
  (x, st) = r
  match x:
    case W4{a, b, c, d}:
      +t = U32.sub(31, s)
      +lost = U32.and(d, U32.sub(shl(1, s), 1))
      +na = shr(a, s)
      +nb = U32.or(shr(b, s), shl(U32.shl(a), t))
      +nc = U32.or(shr(c, s), shl(U32.shl(b), t))
      +nd = U32.or(shr(d, s), shl(U32.shl(c), t))
      W4{na, nb, nc, U32.or(nd, nz(U32.or(st, lost)))}




# shift right by s bits, OR-ing every lost bit into bit 0 (sticky)
def w4_shr_sticky_go(big: Bool, x: W4, +s: U32) -> W4:
  match big:
    case True{}:
      match x:
        case W4{a, b, c, d}:
          W4{0, 0, 0, nz(U32.or(U32.or(a, b), U32.or(c, d)))}
    case False{}:
      w4_shr_bits_go(w4_shr_words(x, U32.shrn(s, 5n)), U32.and(s, 31))




def w4_shr_sticky(x: W4, +s: U32) -> W4:
  w4_shr_sticky_go(U32.is_ge(s, 128), x, s)




# shift left by s (< 128) bits
def w4_shl_go(x: W4, +s: U32) -> W4:
  match x:
    case W4{a, b, c, d}:
      +k = U32.shrn(s, 5n)
      +r = U32.and(s, 31)
      +t = U32.sub(31, r)
      +k1 = U32.is_ge(k, 1)
      +k2 = U32.is_ge(k, 2)
      +k3 = U32.is_ge(k, 3)
      +wa = sel(k3, d, sel(k2, c, sel(k1, b, a)))
      +wb = sel(k3, 0, sel(k2, d, sel(k1, c, b)))
      +wc = sel(k2, 0, sel(k1, d, c))
      +wd = sel(k1, 0, d)
      W4{U32.or(shl(wa, r), shr(U32.shr(wb), t)),
         U32.or(shl(wb, r), shr(U32.shr(wc), t)),
         U32.or(shl(wc, r), shr(U32.shr(wd), t)),
         shl(wd, r)}




# index of the top set bit of a nonzero 128-bit value
def w4_top(x: W4) -> U32:
  match x:
    case W4{a, b, c, d}:
      sel(U32.is_ne(a, 0), U32.add(96, U32.from_nat(U32.log2(a))),
        sel(U32.is_ne(b, 0), U32.add(64, U32.from_nat(U32.log2(b))),
          sel(U32.is_ne(c, 0), U32.add(32, U32.from_nat(U32.log2(c))),
            U32.from_nat(U32.log2(d)))))




def w4_is_zero(x: W4) -> Bool:
  match x:
    case W4{a, b, c, d}:
      U32.is_eq(U32.or(U32.or(a, b), U32.or(c, d)), 0)




def w4_add(x: W4, y: W4) -> W4:
  match x y:
    case W4{a, b, c, d} W4{e, f, g, h}:
      +s0 = U32.add(d, h)
      +k0 = b2u(U32.is_lt(s0, d))
      +t1 = U32.add(c, g)
      +j1 = b2u(U32.is_lt(t1, c))
      +s1 = U32.add(t1, k0)
      +k1 = U32.add(j1, b2u(U32.is_lt(s1, t1)))
      +t2 = U32.add(b, f)
      +j2 = b2u(U32.is_lt(t2, b))
      +s2 = U32.add(t2, k1)
      +k2 = U32.add(j2, b2u(U32.is_lt(s2, t2)))
      W4{U32.add(U32.add(a, e), k2), s2, s1, s0}




# x - y, assuming x >= y
def w4_sub(x: W4, y: W4) -> W4:
  match x y:
    case W4{a, b, c, d} W4{e, f, g, h}:
      +s0 = U32.sub(d, h)
      +k0 = b2u(U32.is_lt(d, h))
      +t1 = U32.sub(c, g)
      +j1 = b2u(U32.is_lt(c, g))
      +s1 = U32.sub(t1, k0)
      +k1 = U32.add(j1, b2u(U32.is_lt(t1, k0)))
      +t2 = U32.sub(b, f)
      +j2 = b2u(U32.is_lt(b, f))
      +s2 = U32.sub(t2, k1)
      +k2 = U32.add(j2, b2u(U32.is_lt(t2, k1)))
      W4{U32.sub(U32.sub(a, e), k2), s2, s1, s0}




def lex_lt_go(eq: Bool, lt: Bool, rest: Bool) -> Bool:
  match eq:
    case True{}:
      rest
    case False{}:
      lt




def lex_lt(+a: U32, +b: U32, rest: Bool) -> Bool:
  lex_lt_go(U32.is_eq(a, b), U32.is_lt(a, b), rest)




def w4_lt(x: W4, y: W4) -> Bool:
  match x y:
    case W4{a, b, c, d} W4{e, f, g, h}:
      lex_lt(a, e, lex_lt(b, f, lex_lt(c, g, U32.is_lt(d, h))))




def mant_mul_go(p: U32 & U32, x: U32 & U32, y: U32 & U32, z: U32 & U32) -> W4:
  (p1, p0) = p
  (x1, x0) = x
  (y1, y0) = y
  (z1, z0) = z
  w4_add(w4_add(W4{0, 0, p1, p0}, W4{0, x1, x0, 0}),
    w4_add(W4{0, y1, y0, 0}, W4{z1, z0, 0, 0}))




# 53x53-bit significand product: (xh, xl) * (yh, yl), xh, yh < 2^21
def mant_mul(+xh: U32, +xl: U32, +yh: U32, +yl: U32) -> W4:
  mant_mul_go(mul32(xl, yl), mul32(xh, yl), mul32(xl, yh), mul32(xh, yh))




# ---------------------------------------------------------------------------
# Rounding. round_pack takes the sign, E = the exponent field biased by
# 4096 for a significand m = (mh, ml) whose leading bit is bit 62; it
# denormalizes (E <= 0), rounds to 53 bits (ties to even) and packs.

def inf_bits(+sg: U32) -> U32 & U32:
  (U32.or(U32.shln(sg, 31n), 2146435072), 0)




def pack_fin(+sg: U32, +hi: U32, +lo: U32, over: Bool) -> U32 & U32:
  match over:
    case True{}:
      inf_bits(sg)
    case False{}:
      (U32.or(U32.shln(sg, 31n), hi), lo)




def pack_go(+sg: U32, +eb: U32, +mh: U32, +ml: U32) -> U32 & U32:
  +qh = U32.shrn(mh, 10n)
  +ql = U32.or(U32.shrn(ml, 10n), U32.shln(mh, 22n))
  +rem = U32.and(ml, 1023)
  +up = Bool.or(U32.is_gt(rem, 512),
    Bool.and(U32.is_eq(rem, 512), U32.is_eq(U32.and(ql, 1), 1)))
  +rl = U32.add(ql, b2u(up))
  +rh = U32.add(qh, b2u(Bool.and(up, U32.is_eq(rl, 0))))
  +hi = U32.add(rh, U32.shln(U32.sub(eb, 4097), 20n))
  pack_fin(sg, hi, rl, U32.is_ge(hi, 2146435072))




def pack_den(+sg: U32, x: W4) -> U32 & U32:
  match x:
    case W4{a, b, c, d}:
      pack_go(sg, 4097, c, d)




def pack_sub(+sg: U32, +eb: U32, +mh: U32, +ml: U32, sub: Bool) -> U32 & U32:
  match sub:
    case False{}:
      pack_go(sg, eb, mh, ml)
    case True{}:
      pack_den(sg, w4_shr_sticky(W4{0, 0, mh, ml}, U32.sub(4097, eb)))




def round_pack_go(over: Bool, +sg: U32, +eb: U32, +mh: U32, +ml: U32) -> U32 & U32:
  match over:
    case True{}:
      inf_bits(sg)
    case False{}:
      pack_sub(sg, eb, mh, ml, U32.is_lt(eb, 4097))




def round_pack(+sg: U32, +eb: U32, +mh: U32, +ml: U32) -> U32 & U32:
  round_pack_go(U32.is_ge(eb, 6143), sg, eb, mh, ml)




# round a nonzero 128-bit magnitude M * 2^(sc - 8192) (sc biased by 8192)
def r128_shift(down: Bool, x: W4, +t: U32) -> W4:
  match down:
    case True{}:
      w4_shr_sticky(x, U32.sub(t, 62))
    case False{}:
      w4_shl_go(x, U32.sub(62, t))




def r128_fin(+sg: U32, +eb: U32, x: W4) -> U32 & U32:
  match x:
    case W4{a, b, c, d}:
      round_pack(sg, eb, c, d)




def round128_go(+sg: U32, +sc: U32, x: W4, +t: U32) -> U32 & U32:
  # field exponent E = t + scale + 1023, biased by 4096
  +eb = U32.sub(U32.add(U32.add(t, sc), 5119), 8192)
  r128_fin(sg, eb, r128_shift(U32.is_ge(t, 62), x, t))




def round128_nz(zero: Bool, +sg: U32, +sc: U32, +x: W4) -> U32 & U32:
  match zero:
    case True{}:
      (0, 0)
    case False{}:
      round128_go(sg, sc, x, w4_top(x))




def round128(+sg: U32, +sc: U32, +x: W4) -> U32 & U32:
  round128_nz(w4_is_zero(x), sg, sc, x)




# ---------------------------------------------------------------------------
# Unpacking

def f_exp(+hi: U32) -> U32:
  U32.and(U32.shrn(hi, 20n), 2047)




def f_sign(+hi: U32) -> U32:
  U32.shrn(hi, 31n)




# significand high part (21 bits, hidden bit included)
def f_mh(+hi: U32) -> U32:
  +e = f_exp(hi)
  U32.or(U32.and(hi, 1048575), sel(U32.is_eq(e, 0), 0, 1048576))




# effective exponent (subnormals: 1)
def f_ee(+hi: U32) -> U32:
  +e = f_exp(hi)
  sel(U32.is_eq(e, 0), 1, e)




def is_special(+hi: U32) -> Bool:
  U32.is_eq(f_exp(hi), 2047)




def is_nan(+hi: U32, +lo: U32) -> Bool:
  Bool.and(is_special(hi), U32.is_ne(U32.or(U32.and(hi, 1048575), lo), 0))




def mag_zero(+hi: U32, +lo: U32) -> Bool:
  U32.is_eq(U32.or(U32.and(hi, 2147483647), lo), 0)




def nan_bits() -> U32 & U32:
  (2146959360, 0)




# ---------------------------------------------------------------------------
# Addition

def add_diff(ylarger: Bool, +sx: U32, +sc: U32, +x: W4, +sy: U32, +y: W4) -> U32 & U32:
  match ylarger:
    case True{}:
      round128(sy, sc, w4_sub(y, x))
    case False{}:
      round128(sx, sc, w4_sub(x, y))




def add_signs(same: Bool, +sx: U32, +sc: U32, +x: W4, +sy: U32, +y: W4) -> U32 & U32:
  match same:
    case True{}:
      round128(sx, sc, w4_add(x, y))
    case False{}:
      add_diff(w4_lt(x, y), sx, sc, x, sy, y)




# x has the larger exponent ex; y is shifted right (sticky) by ex - ey
def add_core(+sx: U32, +ex: U32, +x: W4, +sy: U32, +ey: U32, y: W4) -> U32 & U32:
  +ys = w4_shr_sticky(y, U32.sub(ex, ey))
  # value = M * 2^(ex - 1075 - 64); scale biased by 8192
  +sc = U32.sub(U32.add(ex, 8192), 1139)
  add_signs(U32.is_eq(sx, sy), sx, sc, x, sy, ys)




def add_order(swap: Bool, +sa: U32, +ea: U32, +ma: U32, +la: U32, +sb: U32,
              +eb: U32, +mb: U32, +lb: U32) -> U32 & U32:
  match swap:
    case True{}:
      add_core(sb, eb, W4{mb, lb, 0, 0}, sa, ea, W4{ma, la, 0, 0})
    case False{}:
      add_core(sa, ea, W4{ma, la, 0, 0}, sb, eb, W4{mb, lb, 0, 0})




# exact sum of two finite nonzero values, rounded once
def add_fin(+ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  add_order(U32.is_lt(f_ee(ah), f_ee(bh)), f_sign(ah), f_ee(ah), f_mh(ah), al,
    f_sign(bh), f_ee(bh), f_mh(bh), bl)




def inf_inf(same: Bool, +ah: U32, +al: U32) -> U32 & U32:
  match same:
    case True{}:
      (ah, al)
    case False{}:
      nan_bits()




def add_inf(ai: Bool, bi: Bool, +ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  match ai bi:
    case True{} True{}:
      inf_inf(U32.is_eq(ah, bh), ah, al)
    case True{} False{}:
      (ah, al)
    case False{} _:
      (bh, bl)




def add_special_b(bnan: Bool, +ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  match bnan:
    case True{}:
      (bh, bl)
    case False{}:
      add_inf(is_special(ah), is_special(bh), ah, al, bh, bl)




def add_special(anan: Bool, +ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  match anan:
    case True{}:
      (ah, al)
    case False{}:
      add_special_b(is_nan(bh, bl), ah, al, bh, bl)




# zeros: x + 0 = x; -0 + -0 = -0; -0 + +0 = +0
def add_zero(az: Bool, bz: Bool, +ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  match az bz:
    case True{} True{}:
      (U32.and(ah, bh), 0)
    case True{} False{}:
      (bh, bl)
    case False{} True{}:
      (ah, al)
    case False{} False{}:
      add_fin(ah, al, bh, bl)




def add_go(special: Bool, +ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  match special:
    case True{}:
      add_special(is_nan(ah, al), ah, al, bh, bl)
    case False{}:
      add_zero(mag_zero(ah, al), mag_zero(bh, bl), ah, al, bh, bl)




def add(+ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  add_go(Bool.or(is_special(ah), is_special(bh)), ah, al, bh, bl)




def sub(+ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  add(ah, al, U32.xor(bh, 2147483648), bl)




# ---------------------------------------------------------------------------
# Multiplication

def mul_fin(+ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  # value = P * 2^(ea + eb - 2150)
  round128(U32.xor(f_sign(ah), f_sign(bh)),
    U32.sub(U32.add(U32.add(f_ee(ah), f_ee(bh)), 8192), 2150),
    mant_mul(f_mh(ah), al, f_mh(bh), bl))




def mul_special_go(bad: Bool, +sg: U32) -> U32 & U32:
  match bad:
    case True{}:
      nan_bits()
    case False{}:
      inf_bits(sg)




def mul_zero(z: Bool, +ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  match z:
    case True{}:
      (U32.shln(U32.xor(f_sign(ah), f_sign(bh)), 31n), 0)
    case False{}:
      mul_fin(ah, al, bh, bl)




def mul_go(special: Bool, +ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  match special:
    case True{}:
      mul_special_go(Bool.or(Bool.or(is_nan(ah, al), is_nan(bh, bl)),
        Bool.or(mag_zero(ah, al), mag_zero(bh, bl))), U32.xor(f_sign(ah), f_sign(bh)))
    case False{}:
      mul_zero(Bool.or(mag_zero(ah, al), mag_zero(bh, bl)), ah, al, bh, bl)




def mul(+ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  mul_go(Bool.or(is_special(ah), is_special(bh)), ah, al, bh, bl)




# ---------------------------------------------------------------------------
# Division: bit-serial long division of normalized significands (116
# quotient bits, sticky from the remainder).

def div_step(n: Nat, q: W4, +rh: U32, +rl: U32, +dh: U32, +dl: U32) -> W4 & U32:
  match n:
    case 0n:
      (q, U32.or(rh, rl))
    case 1n+p:
      +ge = Bool.not(lex_lt(rh, dh, U32.is_lt(rl, dl)))
      +sl = U32.sub(rl, sel(ge, dl, 0))
      +sh = U32.sub(U32.sub(rh, sel(ge, dh, 0)), b2u(Bool.and(ge, U32.is_lt(rl, dl))))
      div_step(p, w4_or_low(w4_shl_go(q, 1), b2u(ge)),
        U32.or(U32.shl(sh), U32.shrn(sl, 31n)), U32.shl(sl), dh, dl)




def div_fin_go(+sg: U32, +sc: U32, r: W4 & U32) -> U32 & U32:
  (q, st) = r
  round128(sg, sc, w4_or_low(q, nz(st)))




def div_fin_n(+ah: U32, +al: U32, +bh: U32, +s: U32, mb: W4) -> U32 & U32:
  match mb:
    case W4{a, b, c, d}:
      # q = floor(ma * 2^115 / mb'); value = q * 2^(ea - eb + s - 115)
      div_fin_go(U32.xor(f_sign(ah), f_sign(bh)),
        U32.sub(U32.add(U32.sub(U32.add(f_ee(ah), 8192), f_ee(bh)), s), 115),
        div_step(116n, W4{0, 0, 0, 0}, f_mh(ah), al, c, d))




# normalize the divisor significand so its top bit is bit 52 (subnormals)
def div_fin_b(+ah: U32, +al: U32, +bh: U32, +bt: U32, +bl: U32) -> U32 & U32:
  +s = U32.sub(52, bt)
  div_fin_n(ah, al, bh, s, w4_shl_go(W4{0, 0, f_mh(bh), bl}, s))




def div_fin(+ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  div_fin_b(ah, al, bh, w4_top(W4{0, 0, f_mh(bh), bl}), bl)




def div_zero(az: Bool, bz: Bool, +ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  match az bz:
    case True{} True{}:
      nan_bits()
    case False{} True{}:
      inf_bits(U32.xor(f_sign(ah), f_sign(bh)))
    case True{} False{}:
      (U32.shln(U32.xor(f_sign(ah), f_sign(bh)), 31n), 0)
    case False{} False{}:
      div_fin(ah, al, bh, bl)




def div_go(special: Bool, +ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  match special:
    case True{}:
      nan_bits()
    case False{}:
      div_zero(mag_zero(ah, al), mag_zero(bh, bl), ah, al, bh, bl)




# (inf/NaN operands are not needed by the callers and answer NaN)
def div(+ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  div_go(Bool.or(is_special(ah), is_special(bh)), ah, al, bh, bl)




# ---------------------------------------------------------------------------
# Fused multiply-add of finite operands: a * b + c rounded once.

def fma_mix(same: Bool, +sp: U32, +sc: U32, +p: W4, +scn: U32, +c: W4) -> U32 & U32:
  add_signs(same, sp, sc, p, scn, c)




def fma_far(near: Bool, +sp: U32, +spb: U32, +p: W4, +sgc: U32, +scb: U32, +c: W4) -> U32 & U32:
  match near:
    case True{}:
      fma_mix(U32.is_eq(sp, sgc), sp, spb, p, sgc, w4_shl_go(c, U32.sub(scb, spb)))
    case False{}:
      fma_mix(U32.is_eq(sp, sgc), sp, U32.sub(scb, 73),
        w4_shr_sticky(p, U32.sub(U32.sub(scb, spb), 73)), sgc, w4_shl_go(c, 73))




# P has scale spb, C has scale scb (both biased by 8192)
def fma_align(cfirst: Bool, +sp: U32, +spb: U32, +p: W4, +sgc: U32, +scb: U32, +c: W4) -> U32 & U32:
  match cfirst:
    case True{}:
      fma_far(U32.is_le(U32.sub(scb, spb), 73), sp, spb, p, sgc, scb, c)
    case False{}:
      fma_mix(U32.is_eq(sp, sgc), sp, spb, p, sgc, w4_shr_sticky(c, U32.sub(spb, scb)))




def fma_fin(+ah: U32, +al: U32, +bh: U32, +bl: U32, +ch: U32, +cl: U32) -> U32 & U32:
  +spb = U32.sub(U32.add(U32.add(f_ee(ah), f_ee(bh)), 8192), 2150)
  +scb = U32.sub(U32.add(f_ee(ch), 8192), 1075)
  fma_align(U32.is_ge(scb, spb), U32.xor(f_sign(ah), f_sign(bh)), spb,
    mant_mul(f_mh(ah), al, f_mh(bh), bl), f_sign(ch), scb, W4{0, 0, f_mh(ch), cl})




def fma_zero(pz: Bool, cz: Bool, +ah: U32, +al: U32, +bh: U32, +bl: U32, +ch: U32, +cl: U32) -> U32 & U32:
  match pz cz:
    case True{} _:
      add(U32.shln(U32.xor(f_sign(ah), f_sign(bh)), 31n), 0, ch, cl)
    case False{} True{}:
      mul(ah, al, bh, bl)
    case False{} False{}:
      fma_fin(ah, al, bh, bl, ch, cl)




def fma_sp(p: U32 & U32, +ch: U32, +cl: U32) -> U32 & U32:
  (ph, pl) = p
  add(ph, pl, ch, cl)




# (inf/NaN operands are not reached by exp; they answer a * b + c unfused)
def fma_go(special: Bool, +ah: U32, +al: U32, +bh: U32, +bl: U32, +ch: U32, +cl: U32) -> U32 & U32:
  match special:
    case True{}:
      fma_sp(mul(ah, al, bh, bl), ch, cl)
    case False{}:
      fma_zero(Bool.or(mag_zero(ah, al), mag_zero(bh, bl)), mag_zero(ch, cl), ah, al, bh, bl, ch, cl)




def fma(+ah: U32, +al: U32, +bh: U32, +bl: U32, +ch: U32, +cl: U32) -> U32 & U32:
  fma_go(Bool.or(is_special(ah), Bool.or(is_special(bh), is_special(ch))), ah, al, bh, bl, ch, cl)




# ---------------------------------------------------------------------------
# Ordered comparisons (false when either side is NaN)

# total-order key of a non-NaN double as (hi, lo) unsigned: flips negatives
def key_hi(+h: U32, +l: U32) -> U32:
  sel(U32.is_eq(f_sign(h), 1), U32.not(h), U32.or(h, 2147483648))




def key_lo(+h: U32, +l: U32) -> U32:
  sel(U32.is_eq(f_sign(h), 1), U32.not(l), l)




# -0 == +0: map both to +0 before keying
def zfix(+h: U32, +l: U32) -> U32:
  sel(mag_zero(h, l), 0, h)




def lt_go(nan: Bool, +ah: U32, +al: U32, +bh: U32, +bl: U32) -> Bool:
  match nan:
    case True{}:
      False{}
    case False{}:
      lex_lt(key_hi(zfix(ah, al), al), key_hi(zfix(bh, bl), bl),
        U32.is_lt(key_lo(zfix(ah, al), al), key_lo(zfix(bh, bl), bl)))




def lt(+ah: U32, +al: U32, +bh: U32, +bl: U32) -> Bool:
  lt_go(Bool.or(is_nan(ah, al), is_nan(bh, bl)), ah, al, bh, bl)




def gt(+ah: U32, +al: U32, +bh: U32, +bl: U32) -> Bool:
  lt(bh, bl, ah, al)




def eq(+ah: U32, +al: U32, +bh: U32, +bl: U32) -> Bool:
  Bool.and(Bool.not(Bool.or(is_nan(ah, al), is_nan(bh, bl))),
    Bool.or(Bool.and(mag_zero(ah, al), mag_zero(bh, bl)),
      Bool.and(U32.is_eq(ah, bh), U32.is_eq(al, bl))))




def le(+ah: U32, +al: U32, +bh: U32, +bl: U32) -> Bool:
  Bool.or(lt(ah, al, bh, bl), eq(ah, al, bh, bl))




def ge(+ah: U32, +al: U32, +bh: U32, +bl: U32) -> Bool:
  le(bh, bl, ah, al)




# exact conversion of a U32
def from_u32_nz(zero: Bool, +x: U32) -> U32 & U32:
  match zero:
    case True{}:
      (0, 0)
    case False{}:
      round128(0, 8192, W4{0, 0, 0, x})




def from_u32(+x: U32) -> U32 & U32:
  from_u32_nz(U32.is_eq(x, 0), x)




def tab_get(+t: Tab, left: Bool, +i: U32, +bit: U32) -> Tab:
  match t:
    case TL{a, b, c, d}:
      TL{a, b, c, d}
    case TN{l, r}:
      match left:
        case True{}:
          tab_get(l, U32.is_eq(U32.and(i, U32.shr(bit)), 0), i, U32.shr(bit))
        case False{}:
          tab_get(r, U32.is_eq(U32.and(i, U32.shr(bit)), 0), i, U32.shr(bit))




def exp_table() -> Tab:
  TN{TN{TN{TN{TN{TN{TN{TL{0, 0, 1072693248, 0}, TL{1016806223, 445169518, 1072690749, 2851812149}}, TN{TL{3161546771, 2631457885, 1072688282, 1048019041}, TL{3163577978, 277309137, 1072685845, 3899555717}}}, TN{TN{TL{1015861842, 896005651, 1072683440, 3541402996}, TL{3163278976, 603557626, 1072681067, 702412510}}, TN{TL{1012987726, 1642514529, 1072678725, 410360776}, TL{1016112100, 1530123161, 1072676414, 3402036099}}}}, TN{TN{TN{TL{1016568486, 1568897901, 1072674136, 1828292879}, TL{1015985434, 2466115580, 1072671890, 728909815}}, TN{TL{1010744893, 1882168529, 1072669676, 852742562}, TL{3161064244, 2307943947, 1072667494, 2952712987}}}, TN{TN{TL{3163903570, 707771662, 1072665345, 3490863953}, TL{3159392495, 2353982037, 1072663229, 3228316108}}, TN{TL{3163670819, 3117806614, 1072661146, 2930322912}, TL{1015075811, 3915142575, 1072659096, 3366293073}}}}}, TN{TN{TN{TN{TL{3162512149, 3936719688, 1072657080, 1014845819}, TL{3163496432, 1440625213, 1072655097, 948735466}}, TN{TL{1015777676, 1058231231, 1072653147, 3949972341}, TL{3164002716, 1980885798, 1072651232, 2214878420}}}, TN{TN{TL{1016786167, 1044000608, 1072649351, 828946858}, TL{3163547522, 3414571165, 1072647504, 586995997}}, TN{TL{1015705409, 1151779725, 1072645691, 2288159958}, TL{1015052805, 2967733373, 1072643913, 2440944790}}}}, TN{TN{TN{TL{1016499965, 3819481236, 1072642170, 1853186616}, TL{1015504408, 4067707005, 1072640462, 1337108031}}, TN{TL{1015039787, 2552227826, 1072638789, 1709341917}, TL{3163994235, 1064372318, 1072637151, 3790955393}}}, TN{TN{TL{1015216097, 1829350193, 1072635549, 4112506593}, TL{3158122907, 443531258, 1072633983, 3504003472}}, TN{TL{1015756674, 1913391796, 1072632453, 2799960843}, TL{1013847186, 2312031119, 1072630959, 2839424854}}}}}}, TN{TN{TN{TN{TN{TL{1015238005, 1303423926, 1072629502, 171030293}, TL{1015431681, 3802952780, 1072628080, 4232894513}}, TN{TL{1016061241, 1574172746, 1072626696, 2992903935}, TL{3162940288, 999185156, 1072625349, 1603444721}}}, TN{TN{TL{3163704045, 3427487848, 1072624039, 926591435}, TL{3164145656, 458304910, 1072622766, 1829099622}}, TN{TL{3161575912, 1049900754, 1072621531, 887463927}, TL{3164150041, 3016629013, 1072620333, 3272845541}}}}, TN{TN{TN{TL{1015390024, 2804567149, 1072619174, 1276261410}, TL{3163755104, 2049468810, 1072618053, 78413852}}, TN{TL{3159926671, 1209502043, 1072616970, 569847338}, TL{3162254491, 1732876827, 1072615925, 3645941911}}}, TN{TN{TL{1011049453, 1623370769, 1072614920, 1617004845}, TL{1016489481, 990274799, 1072613953, 3978100823}}, TN{TL{1013894369, 3667985273, 1072613026, 3049340112}, TL{1016332174, 1057952304, 1072612138, 4040676318}}}}}, TN{TN{TN{TN{TL{1014403278, 3145379760, 1072611290, 3577096743}, TL{1016274365, 3948208247, 1072610482, 2583551245}}, TN{TL{3163526196, 7447438, 1072609714, 1990012071}, TL{3163021004, 3700663113, 1072608986, 2731501122}}}, TN{TN{TL{3162037958, 3171891295, 1072608299, 1453150082}, TL{3162903110, 3967507702, 1072607652, 3395129871}}, TN{TL{1016280325, 419288974, 1072607047, 917841882}, TL{1014732983, 797612805, 1072606482, 3566716925}}}}, TN{TN{TN{TL{1016095713, 3793507337, 1072605959, 3712504873}, TL{1010091909, 1343866602, 1072605478, 2321106615}}, TN{TL{1016345318, 728023093, 1072605039, 363667784}, TL{3163350090, 1637447327, 1072604641, 3111574537}}}, TN{TN{TL{3163304901, 1005538728, 1072604286, 2956612997}, TL{3162788728, 2301356462, 1072603974, 885834528}}, TN{TL{3163803357, 2018924632, 1072603704, 2186617381}, TL{1012338858, 2155747684, 1072603477, 3561793907}}}}}}}, TN{TN{TN{TN{TN{TN{TL{3163796463, 3210617384, 1072603294, 1719614413}, TL{3161068205, 2268379522, 1072603154, 1963711167}}, TN{TL{3160631279, 3094194670, 1072603058, 1013258799}, TL{3162561597, 1424001105, 1072603005, 4182873220}}}, TN{TN{TL{3161988964, 2119843535, 1072602997, 3907805044}, TL{3162959434, 3230367152, 1072603034, 1218806132}}, TN{TL{3162904882, 508946058, 1072603115, 1447192521}, TL{1016110283, 1577702611, 1072603241, 1339972927}}}}, TN{TN{TN{TL{3162190556, 3108873501, 1072603412, 1944781191}, TL{1016392957, 1416085611, 1072603629, 19972402}}, TN{TL{1013312481, 2882956373, 1072603891, 919555682}, TL{3163070917, 800313154, 1072604199, 1413356050}}}, TN{TN{TL{3163777462, 4047189812, 1072604553, 2571947539}, TL{3162529412, 974782238, 1072604954, 1176749997}}, TN{TL{3163870288, 3631372142, 1072605401, 2604962541}, TL{1016114535, 1527679488, 1072605895, 3649726105}}}}}, TN{TN{TN{TN{TL{1015920431, 3253791412, 1072606437, 1110089947}, TL{3160782432, 2630215679, 1072607026, 380978316}}, TN{TL{1014756995, 1509121860, 1072607662, 2568320822}, TL{3163752735, 2803776899, 1072608347, 194117574}}}, TN{TN{TL{3160254904, 2339118633, 1072609079, 2966275557}, TL{3161203705, 2089859417, 1072609860, 3418903055}}, TN{TL{3163702083, 586480042, 1072610690, 2682146384}, TL{3162884716, 3613822539, 1072611569, 1892288442}}}}, TN{TN{TN{TL{1014083580, 730975783, 1072612497, 2191782032}, TL{1013830197, 3775558587, 1072613475, 434316067}}, TN{TL{3163014404, 576856675, 1072614502, 2069751141}, TL{1015749766, 3823251925, 1072615579, 3964284211}}}, TN{TN{TL{3163667409, 3552361237, 1072616707, 2990417245}, TL{1016122417, 2632856018, 1072617886, 321958744}}, TN{TL{1015310724, 1853053619, 1072619115, 1434058175}, TL{3162693581, 2542706100, 1072620395, 3218338682}}}}}}, TN{TN{TN{TN{TN{TL{1015814775, 2462790535, 1072621727, 2572866477}, TL{3163585423, 1255266810, 1072623111, 697153126}}, TN{TL{3159737305, 1457303226, 1072624546, 3092190715}, TL{3163595790, 1034352192, 1072626034, 2380618042}}}, TN{TN{TL{3160987380, 950899508, 1072627574, 4076559943}, TL{3163680482, 1800964661, 1072629168, 815859274}}, TN{TL{1014300631, 174054861, 1072630814, 2420883922}, TL{3163667963, 4203911340, 1072632514, 1540824585}}}}, TN{TN{TN{TL{1014197934, 816778419, 1072634267, 3716502172}, TL{1015997234, 1553989012, 1072636075, 1610600570}}, TN{TL{1015341199, 3507050924, 1072637937, 777507147}, TL{1013173679, 944642663, 1072639853, 2483480501}}}, TN{TN{TL{1013410604, 1821514088, 1072641824, 3706687593}, TL{3162540568, 2211231186, 1072643851, 1432208378}}, TN{TL{3163532637, 1073740399, 1072645933, 1242007932}, TL{3163557294, 947235145, 1072648071, 135105010}}}}}, TN{TN{TN{TN{TL{1014276997, 2789017511, 1072650264, 3707479175}, TL{3162673566, 541073935, 1072652515, 382305176}}, TN{TL{1015962192, 3586233004, 1072654822, 64696965}, TL{1015298649, 2885774155, 1072657185, 4076975200}}}, TN{TN{TL{3162690849, 129252895, 1072659607, 863738719}, TL{3163105977, 994512329, 1072662086, 351641897}}, TN{TL{1014281732, 1614448851, 1072664622, 3884662774}, TL{1015268844, 1369272945, 1072667217, 4224142467}}}}, TN{TN{TN{TL{3163551506, 2413007344, 1072669871, 2728693978}, TL{3163401880, 3793974397, 1072672584, 764307441}}, TN{TL{1015989180, 1101668360, 1072675355, 3999357479}, TL{1015294868, 3282692914, 1072678187, 929806999}}}, TN{TN{TL{1015702697, 835814894, 1072681078, 1533953344}, TL{3163436986, 3829130221, 1072684029, 2912730644}}, TN{TL{1014466875, 1301400989, 1072687041, 2174652632}, TL{1012073921, 1096862857, 1072690114, 730821105}}}}}}}}




def exp_scale(y: U32 & U32) -> U32 & U32:
  (yh, yl) = y
  mul(yh, yl, 2130706432, 0)




def exp_fin7(large: Bool, +sh: U32, +sl: U32, +th: U32, +tl: U32) -> U32 & U32:
  match large:
    case True{}:
      exp_scale(fma(sh, sl, th, tl, sh, sl))
    case False{}:
      fma(sh, sl, th, tl, sh, sl)




def exp_fin6(+large: Bool, +sh: U32, +sl: U32, tmp: U32 & U32) -> U32 & U32:
  (th, tl) = tmp
  exp_fin7(large, U32.add(sh, sel(large, 3236954112, 0)), sl, th, tl)




def exp_poly3(large: Bool, +sh: U32, +sl: U32, p: U32 & U32, r4: U32 & U32, q: U32 & U32) -> U32 & U32:
  (ph, pl) = p
  (r4h, r4l) = r4
  (qh, ql) = q
  exp_fin6(large, sh, sl, fma(r4h, r4l, qh, ql, ph, pl))




def exp_poly2(large: Bool, +sh: U32, +sl: U32, +rh: U32, +rl: U32, p: U32 & U32, t3: U32 & U32, r2: U32 & U32) -> U32 & U32:
  (ph, pl) = p
  (t3h, t3l) = t3
  (+r2h, +r2l) = r2
  exp_poly3(large, sh, sl, fma(ph, pl, r2h, r2l, t3h, t3l), mul(r2h, r2l, r2h, r2l),
    fma(rh, rl, 1065423121, 1738854423, 1067799893, 3474402193))




def exp_tabbed(large: Bool, +kil: U32, r: U32 & U32, t: Tab) -> U32 & U32:
  (+rh, +rl) = r
  match t:
    case TL{th, tl, sh, sl}:
      exp_poly2(large, U32.add(sh, U32.shln(kil, 13n)), sl, rh, rl,
        fma(rh, rl, 1069897045, 1431655484, 1071644671, 4294966717),
        add(th, tl, rh, rl), mul(rh, rl, rh, rl))
    case TN{a, b}:
      (0, 0)




def exp_r2(large: Bool, +kil: U32, +kdh: U32, +kdl: U32, r: U32 & U32, +tab: Tab) -> U32 & U32:
  (rh, rl) = r
  exp_tabbed(large, kil, fma(kdh, kdl, 3171743642, 3164486458, rh, rl),
    tab_get(tab, U32.is_eq(U32.and(kil, 64), 0), U32.and(kil, 127), 64))




def exp_kd(large: Bool, +xh: U32, +xl: U32, +kil: U32, kd: U32 & U32, +tab: Tab) -> U32 & U32:
  (+kdh, +kdl) = kd
  exp_r2(large, kil, kdh, kdl, fma(kdh, kdl, 3212193346, 4277796864, xh, xl), tab)




def exp_main(large: Bool, +xh: U32, +xl: U32, kdr: U32 & U32, +tab: Tab) -> U32 & U32:
  (+kh, +kl) = kdr
  exp_kd(large, xh, xl, kl, sub(kh, kl, 1127743488, 0), tab)




def exp_inf(neginf: Bool, +xh: U32, +xl: U32) -> U32 & U32:
  match neginf:
    case True{}:
      (0, 0)
    case False{}:
      add(xh, xl, 1072693248, 0)




def sel2(c: Bool, +ah: U32, +al: U32, +bh: U32, +bl: U32) -> U32 & U32:
  match c:
    case True{}:
      (ah, al)
    case False{}:
      (bh, bl)




def exp_huge(special: Bool, +xh: U32, +xl: U32) -> U32 & U32:
  match special:
    case True{}:
      exp_inf(Bool.and(U32.is_eq(xh, 4293918720), U32.is_eq(xl, 0)), xh, xl)
    case False{}:
      sel2(U32.is_eq(f_sign(xh), 1), 0, 0, 2146435072, 0)




def exp_big(huge: Bool, +xh: U32, +xl: U32, +tab: Tab) -> U32 & U32:
  match huge:
    case False{}:
      exp_main(True{}, xh, xl, fma(xh, xl, 1080497479, 1697350398, 1127743488, 0), tab)
    case True{}:
      exp_huge(U32.is_eq(f_exp(xh), 2047), xh, xl)




def exp_rare(tiny: Bool, +xh: U32, +xl: U32, +tab: Tab) -> U32 & U32:
  match tiny:
    case True{}:
      add(xh, xl, 1072693248, 0)
    case False{}:
      exp_big(U32.is_gt(f_exp(xh), 1032), xh, xl, tab)




def exp_go(rare: Bool, +xh: U32, +xl: U32, +tab: Tab) -> U32 & U32:
  match rare:
    case True{}:
      exp_rare(U32.is_lt(f_exp(xh), 969), xh, xl, tab)
    case False{}:
      exp_main(False{}, xh, xl, fma(xh, xl, 1080497479, 1697350398, 1127743488, 0), tab)




def exp(+xh: U32, +xl: U32, +tab: Tab) -> U32 & U32:
  exp_go(U32.is_gt(U32.sub(f_exp(xh), 969), 62), xh, xl, tab)



def d_of(r: U32 & U32) -> D:
  (h, l) = r
  D{h, l}



def d_add(a: D, b: D) -> D:
  match a b:
    case D{ah, al} D{bh, bl}:
      d_of(add(ah, al, bh, bl))



def d_sub(a: D, b: D) -> D:
  match a b:
    case D{ah, al} D{bh, bl}:
      d_of(sub(ah, al, bh, bl))



def d_mul(a: D, b: D) -> D:
  match a b:
    case D{ah, al} D{bh, bl}:
      d_of(mul(ah, al, bh, bl))



def d_of_mul(r: U32 & U32, +bh: U32, +bl: U32) -> D:
  (ah, al) = r
  d_of(mul(ah, al, bh, bl))



def d_ge(a: D, b: D) -> Bool:
  match a b:
    case D{ah, al} D{bh, bl}:
      ge(ah, al, bh, bl)



def d_gt(a: D, b: D) -> Bool:
  match a b:
    case D{ah, al} D{bh, bl}:
      gt(ah, al, bh, bl)



def w4_lo2(x: W4) -> U32 & U32:
  match x:
    case W4{a, b, c, d}:
      (c, d)



def w4_bit127(x: W4) -> U32:
  match x:
    case W4{a, b, c, d}:
      U32.shrn(a, 31n)



def w4_mul10n(n: Nat, +x: W4) -> W4:
  match n:
    case 0n:
      x
    case 1n+p:
      w4_mul10n(p, w4_add(w4_shl_go(x, 3), w4_shl_go(x, 1)))



def w4_mul_small_pow10(+x: W4, +e: U32) -> W4:
  w4_mul10n(U32.to_nat(e), x)


def d_div(a: D, b: D) -> D:
  match a b:
    case D{ah, al} D{bh, bl}:
      d_of(div(ah, al, bh, bl))


def d_lt(a: D, b: D) -> Bool:
  match a b:
    case D{ah, al} D{bh, bl}:
      lt(ah, al, bh, bl)


def d_eq(a: D, b: D) -> Bool:
  match a b:
    case D{ah, al} D{bh, bl}:
      eq(ah, al, bh, bl)


def d_exp(a: D, +tab: Tab) -> D:
  match a:
    case D{h, l}:
      d_of(exp(h, l, tab))
