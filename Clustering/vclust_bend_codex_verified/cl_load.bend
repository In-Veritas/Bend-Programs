# Clusty 1.2.2 input semantics, as driven by `vclust cluster`:
# - the objects (ids) file: first field of every line after the header;
# - the distance table: header columns split on whitespace/commas, rows
#   split on '\t' or ',', every row filtered by `--min col v` / `--max col v`
#   on Clusty's own strtod value (not correctly rounded), self pairs
#   dropped, local vertex ids assigned in first-appearance order of the
#   accepted rows (query column first);
# - decimal thresholds parsed correctly rounded (std::istringstream).
#
# A numeric field "R.F" (k fraction digits) is held as the integer
# N = R * 10^k + F (U32) and its k. Clusty's double is
# v(N, k) = double(R) + double(F) * m_k with m_k = 0.1 multiplied k times;
# for a fixed k this is monotone in N, so every threshold test is the
# integer test cmin[c][k] <= N <= cmax[c][k], with the cut-offs found once
# by binary search in exact soft-double arithmetic.
import Base
import ./f64.bend as F

type Edge is Data:
  Edge{+a: U32, +b: U32, +n: U32, +k: U32}



# read-only U32 table (cut-offs), a complete binary tree
type UT is Data:
  UL{+v: U32}
  UN{+lo: UT, +hi: UT}


# cut-offs: index (col * 16 + k) * 2 + {0: cmin, 1: cmax}, cols < 32
type Meta is Data:
  Meta{+ncols: U32, +qc: U32, +rc: U32, +dc: U32, +fmask: U32, +cap: U32, +cuts: UT}



# streaming parser state: arrays, accepted edges (reverse order), local id
# -> global id list (reverse), counters and the current field/row
type PS is Type:
  PS{+m: Meta, g2l: Array<U32>, edges: List<&2, Edge>,
     l2g: List<&2, U32>, +nloc: U32, +nedge: U32, +err: U32,
     +col: U32, +num: U32, +k: U32, +mode: U32, +iv: U32, +bad: U32,
     +nch: U32, +q: U32, +r: U32, +nd: U32, +kd: U32, +dbad: U32, +rej: U32}



# ---------------------------------------------------------------------------
# First line of a chunk: (reversed line, done) carried; the rest returned.

type Cut is Data:
  Cut{+line: List<&2, U32>, +done: Bool}



# tokens of the header line (each token's bytes in order)
type Tok is Data:
  Tok{+cur: List<&2, U32>, +toks: List<&2, List<&2, U32>>}



# ---------------------------------------------------------------------------
# Decimal -> double, correctly rounded (std::istringstream >> double), for
# [-]digits[.digits][(e|E)[+-]digits] with up to 19 significant digits and a
# decimal exponent in [-19, 19] after folding the fraction.

type Dec is Data:
  Dec{+mh: U32, +ml: U32, +nd: U32, +frac: U32, +mode: U32, +eneg: U32,
      +ex: U32, +bad: U32, +neg: U32, +first: U32}



# bit-serial 128-bit long division: (quotient, remainder != 0)
type DV is Data:
  DV{+n: F.W4, +r: F.W4, +q: F.W4}


# A filter: column, min, max (doubles), and whether each bound is active.
type Filt is Data:
  Filt{+col: U32, +lo: F.D, +hi: F.D, +has_lo: Bool, +has_hi: Bool}


type MapR is Type:
  MapR{g2l: Array<U32>, l2g: List<&2, U32>, +nloc: U32, +lid: U32}



def none() -> U32:
  4294967295



# ---------------------------------------------------------------------------
# small list helpers

def bytes_of(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{c, t}:
      Char.to_u32(c) <> bytes_of(t)



def bytes_eq(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{x, xt} Con{y, yt}:
      Bool.and(U32.is_eq(x, y), bytes_eq(xt, yt))
    case _ _:
      False{}



def rev_bytes(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      rev_bytes(t, h <> acc)



def is_nl(+h: U32) -> Bool:
  Bool.or(U32.is_eq(h, 10), U32.is_eq(h, 13))



def is_sep(+h: U32) -> Bool:
  Bool.or(U32.is_eq(h, 9), U32.is_eq(h, 44))



# istream whitespace or ',' (Clusty replaces commas by spaces in the header)
def is_ws(+h: U32) -> Bool:
  Bool.or(Bool.or(U32.is_eq(h, 32), U32.is_eq(h, 44)),
    Bool.and(U32.is_ge(h, 9), U32.is_le(h, 13)))



def cut_step(+h: U32, line: List<&2, U32>, nl: Bool) -> Cut:
  match nl:
    case True{}:
      Cut{line, True{}}
    case False{}:
      Cut{h <> line, False{}}



def cut_line(bs: List<&2, U32>, c: Cut) -> Cut & List<&2, U32>:
  match bs:
    case Nil{}:
      (c, Nil{})
    case Con{+h, t}:
      match c:
        case Cut{line, done}:
          match done:
            case True{}:
              (Cut{line, True{}}, h <> t)
            case False{}:
              cut_line(t, cut_step(h, line, is_nl(h)))



def tok_flush(cur: List<&2, U32>, toks: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match cur:
    case Nil{}:
      toks
    case Con{h, t}:
      rev_bytes(h <> t, Nil{}) <> toks



def tok_step(+h: U32, t: Tok, ws: Bool) -> Tok:
  match t:
    case Tok{cur, toks}:
      match ws:
        case True{}:
          Tok{Nil{}, tok_flush(cur, toks)}
        case False{}:
          Tok{h <> cur, toks}



def tokens_go(bs: List<&2, U32>, t: Tok) -> Tok:
  match bs:
    case Nil{}:
      t
    case Con{+h, rest}:
      tokens_go(rest, tok_step(h, t, is_ws(h)))



def list_rev_toks(xs: List<&2, List<&2, U32>>, acc: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      list_rev_toks(t, h <> acc)



def tok_fin(t: Tok) -> List<&2, List<&2, U32>>:
  match t:
    case Tok{cur, toks}:
      list_rev_toks(tok_flush(cur, toks), Nil{})



def tokens(line: List<&2, U32>) -> List<&2, List<&2, U32>>:
  tok_fin(tokens_go(line, Tok{Nil{}, Nil{}}))



# index of a column name, or none()
def find_col(cols: List<&2, List<&2, U32>>, +name: List<&2, U32>, +i: U32) -> U32:
  match cols:
    case Nil{}:
      none()
    case Con{c, t}:
      F.sel(bytes_eq(c, name), i, find_col(t, name, U32.inc(i)))



def ncols(cols: List<&2, List<&2, U32>>) -> U32:
  U32.from_nat(List.length(&2, List<&2, U32>, cols))



def m10(+h: U32, +l: U32, +d: U32) -> U32 & U32:
  F.w4_lo2(F.w4_add(F.w4_add(F.w4_shl_go(F.W4{0, 0, h, l}, 3), F.w4_shl_go(F.W4{0, 0, h, l}, 1)), F.W4{0, 0, 0, d}))



def dec_mant_go(m: U32 & U32, +nd: U32, +frac: U32, +mode: U32, +eneg: U32, +ex: U32, +bad: U32,
                +neg: U32, +first: U32) -> Dec:
  (mh, ml) = m
  Dec{mh, ml, nd, frac, mode, eneg, ex, F.sel(U32.is_gt(nd, 19), 1, bad), neg, first}



def dec_mant(inm: Bool, +v: U32, +mh: U32, +ml: U32, +nd: U32, +frac: U32, +mode: U32,
             +eneg: U32, +ex: U32, +bad: U32, +neg: U32, +first: U32) -> Dec:
  match inm:
    case True{}:
      dec_mant_go(m10(mh, ml, v), U32.add(nd, F.b2u(Bool.or(U32.is_ne(v, 0), U32.is_ne(U32.or(mh, ml), 0)))),
        U32.add(frac, F.b2u(U32.is_eq(mode, 1))), mode, eneg, ex, bad, neg, first)
    case False{}:
      Dec{mh, ml, nd, frac, 3, eneg, U32.add(U32.mul(ex, 10), v), F.sel(U32.is_gt(ex, 1000), 1, bad), neg, first}



def dec_digit_go(+v: U32, d: Dec) -> Dec:
  match d:
    case Dec{mh, ml, nd, frac, mode, eneg, ex, bad, neg, first}:
      dec_mant(U32.is_le(mode, 1), v, mh, ml, nd, frac, mode, eneg, ex, bad, neg, 0)



def dec_other(+h: U32, d: Dec) -> Dec:
  match d:
    case Dec{mh, ml, nd, frac, mode, eneg, ex, bad, neg, first}:
      +dot = Bool.and(U32.is_eq(h, 46), U32.is_eq(mode, 0))
      +e = Bool.and(Bool.or(U32.is_eq(h, 101), U32.is_eq(h, 69)), U32.is_le(mode, 1))
      +sg = Bool.or(U32.is_eq(h, 45), U32.is_eq(h, 43))
      +mneg = Bool.and(sg, U32.is_eq(first, 1))
      +eg = Bool.and(sg, U32.is_eq(mode, 2))
      Dec{mh, ml, nd, frac,
        F.sel(dot, 1, F.sel(e, 2, F.sel(eg, 3, mode))),
        F.sel(Bool.and(eg, U32.is_eq(h, 45)), 1, eneg), ex,
        F.sel(Bool.or(Bool.or(dot, e), Bool.or(mneg, eg)), bad, 1),
        F.sel(Bool.and(mneg, U32.is_eq(h, 45)), 1, neg), 0}



def dec_digit(dg: Bool, +h: U32, d: Dec) -> Dec:
  match dg:
    case True{}:
      dec_digit_go(U32.sub(h, 48), d)
    case False{}:
      dec_other(h, d)



def dec_scan(s: List<&2, U32>, d: Dec) -> Dec:
  match s:
    case Nil{}:
      d
    case Con{+h, t}:
      dec_scan(t, dec_digit(U32.is_lt(U32.sub(h, 48), 10), h, d))



# 10^n as a 128-bit integer (n <= 38)
def pow10(n: Nat, +x: F.W4) -> F.W4:
  match n:
    case 0n:
      x
    case 1n+p:
      pow10(p, F.w4_add(F.w4_shl_go(x, 3), F.w4_shl_go(x, 1)))



def dv_sub(ge: Bool, +r: F.W4, +den: F.W4) -> F.W4:
  match ge:
    case True{}:
      F.w4_sub(r, den)
    case False{}:
      r



def dv_step(+den: F.W4, d: DV) -> DV:
  match d:
    case DV{n, r, q}:
      +r1 = F.w4_or_low(F.w4_shl_go(r, 1), F.w4_bit127(n))
      +ge = Bool.not(F.w4_lt(r1, den))
      DV{F.w4_shl_go(n, 1), dv_sub(ge, r1, den), F.w4_or_low(F.w4_shl_go(q, 1), F.b2u(ge))}



def dv_loop(n: Nat, +den: F.W4, d: DV) -> DV:
  match n:
    case 0n:
      d
    case 1n+p:
      dv_loop(p, den, dv_step(den, d))



def dv_fin(+sg: U32, +sc: U32, d: DV) -> U32 & U32:
  match d:
    case DV{n, r, q}:
      F.round128(sg, sc, F.w4_or_low(q, F.b2u(Bool.not(F.w4_is_zero(r)))))



# M * 10^-e (e >= 1): N = M << s with s = top(den) + 56 - top(M)
def dec_neg(+sg: U32, +m: F.W4, +den: F.W4) -> U32 & U32:
  +s = U32.sub(U32.add(F.w4_top(den), 56), F.w4_top(m))
  dv_fin(sg, U32.sub(8192, s), dv_loop(128n, den, DV{F.w4_shl_go(m, s), F.W4{0, 0, 0, 0}, F.W4{0, 0, 0, 0}}))



def dec_value(+sg: U32, +m: F.W4, +e10: U32, +eneg: Bool) -> U32 & U32:
  match eneg:
    case True{}:
      dec_neg(sg, m, pow10(U32.to_nat(e10), F.W4{0, 0, 0, 1}))
    case False{}:
      F.round128(sg, 8192, F.w4_mul_small_pow10(m, e10))



def dec_check(bad: Bool, zero: Bool, +sg: U32, +m: F.W4, +mag: U32, +eneg: Bool) -> Maybe<&2, F.D>:
  match bad zero:
    case True{} _:
      None{}
    case False{} True{}:
      Some{F.D{U32.shln(sg, 31n), 0}}
    case False{} False{}:
      Some{F.d_of(dec_value(sg, m, mag, eneg))}



# Result: Done{(hi, lo)} or Fail{} for an unsupported/ill-formed text
def dec_fin(d: Dec) -> Maybe<&2, F.D>:
  match d:
    case Dec{mh, ml, nd, frac, mode, eneg, ex, bad, neg, first}:
      # decimal exponent e10 = ex*(+-1) - frac, as sign/magnitude
      +ep = F.sel(U32.is_eq(eneg, 1), 0, ex)
      +en = U32.add(F.sel(U32.is_eq(eneg, 1), ex, 0), frac)
      +pos = U32.is_ge(ep, en)
      +mag = F.sel(pos, U32.sub(ep, en), U32.sub(en, ep))
      dec_check(Bool.or(Bool.or(U32.is_eq(bad, 1), U32.is_eq(first, 1)),
          Bool.and(U32.is_gt(mag, 19), U32.is_ne(U32.or(mh, ml), 0))),
        U32.is_eq(U32.or(mh, ml), 0), neg, F.W4{0, 0, mh, ml}, mag, Bool.not(pos))



def parse_double(s: String) -> Maybe<&2, F.D>:
  dec_fin(dec_scan(bytes_of(s), Dec{0, 0, 0, 0, 0, 0, 0, 0, 0, 1}))



# ---------------------------------------------------------------------------
# Clusty's value of an integer-coded field, v(N, k)

# m_k = 0.1 multiplied k times (k <= 15)
def mul_k(n: Nat, d: F.D) -> F.D:
  match n:
    case 0n:
      d
    case 1n+p:
      mul_k(p, F.d_mul(d, F.D{1069128089, 2576980378}))


def p10_u32(n: Nat) -> U32:
  match n:
    case 0n:
      1
    case 1n+p:
      U32.mul(10, p10_u32(p))



# R = N / 10^k, F = N % 10^k (k >= 10: R = 0, F = N)
def clusty_value(+n: U32, +k: U32, +m: F.D) -> F.D:
  +big = U32.is_ge(k, 10)
  +p = p10_u32(U32.to_nat(F.sel(big, 0, k)))
  +rr = F.sel(big, 0, U32.div(n, p))
  +ff = F.sel(big, n, U32.mod(n, p))
  F.d_add(F.d_of(F.from_u32(rr)), F.d_mul(F.d_of(F.from_u32(ff)), m))



# smallest N in [lo, hi] with v(N, k) >= t (hi + 1 when none); 33 steps
def first_ge(n: Nat, +lo: U32, +hi: U32, +k: U32, +m: F.D, +t: F.D) -> U32:
  match n:
    case 0n:
      lo
    case 1n+p:
      +mid = U32.add(lo, U32.shr(U32.sub(hi, lo)))
      +ok = F.d_ge(clusty_value(mid, k, m), t)
      first_ge(p, F.sel(ok, lo, U32.min(U32.inc(mid), hi)), F.sel(ok, mid, hi), k, m, t)



def first_gt(n: Nat, +lo: U32, +hi: U32, +k: U32, +m: F.D, +t: F.D) -> U32:
  match n:
    case 0n:
      lo
    case 1n+p:
      +mid = U32.add(lo, U32.shr(U32.sub(hi, lo)))
      +ok = F.d_gt(clusty_value(mid, k, m), t)
      first_gt(p, F.sel(ok, lo, U32.min(U32.inc(mid), hi)), F.sel(ok, mid, hi), k, m, t)


# ---------------------------------------------------------------------------
# U32 tables

def ut_get(+t: UT, left: Bool, +i: U32, +bit: U32) -> U32:
  match t:
    case UL{v}:
      v
    case UN{l, r}:
      match left:
        case True{}:
          ut_get(l, U32.is_eq(U32.and(i, U32.shr(bit)), 0), i, U32.shr(bit))
        case False{}:
          ut_get(r, U32.is_eq(U32.and(i, U32.shr(bit)), 0), i, U32.shr(bit))


# 1024-entry cut table lookup
def cut_get(+t: UT, +i: U32) -> U32:
  ut_get(t, U32.is_eq(U32.and(i, 512), 0), i, 512)


def filt_pick(mine: Bool, +f: Filt, +g: Filt) -> Filt:
  match mine:
    case True{}:
      f
    case False{}:
      g


def filt_col(f: Filt) -> U32:
  match f:
    case Filt{c, lo, hi, hl, hh}:
      c


# the filter of a column (an inactive one when none)
def filt_for(fs: List<&2, Filt>, +col: U32) -> Filt:
  match fs:
    case Nil{}:
      Filt{col, F.D{0, 0}, F.D{0, 0}, False{}, False{}}
    case Con{+f, t}:
      filt_pick(U32.is_eq(filt_col(f), col), f, filt_for(t, col))


# no N with v <= hi: an empty interval is cmax < cmin (cmin >= 0), so the
# caller treats cmax = none() as "accept nothing" via an explicit flag
def cut_max(+g: U32) -> U32:
  F.sel(U32.is_eq(g, 0), none(), U32.sub(g, 1))


def cut_bound(want_min: Bool, hl: Bool, hh: Bool, +lo: F.D, +hi: F.D, +k: U32, +m: F.D) -> U32:
  match want_min:
    case True{}:
      match hl:
        case True{}:
          first_ge(34n, 0, none(), k, m, lo)
        case False{}:
          0
    case False{}:
      match hh:
        case True{}:
          # largest N with v <= hi: (first N with v > hi) - 1; none -> empty
          cut_max(first_gt(34n, 0, none(), k, m, hi))
        case False{}:
          U32.sub(none(), 1)


def cut_of(f: Filt, +k: U32, +which: U32) -> U32:
  match f:
    case Filt{c, lo, hi, hl, hh}:
      cut_bound(U32.is_eq(which, 0), hl, hh, lo, hi, k, mul_k(U32.to_nat(k), F.D{1072693248, 0}))


# cut-off for table index i under the filter list
def cut_value(fs: List<&2, Filt>, +i: U32) -> U32:
  cut_of(filt_for(fs, U32.shrn(i, 5n)), U32.and(U32.shr(i), 15), U32.and(i, 1))


def cut_tree(+n: Nat, +base: U32, +span: U32, +fs: List<&2, Filt>) -> UT:
  match n:
    case 0n:
      UL{cut_value(fs, base)}
    case 1n+p:
      +h = U32.shr(span)
      UN{cut_tree(p, base, h, fs), cut_tree(p, U32.add(base, h), h, fs)}


def col_mask(fs: List<&2, Filt>) -> U32:
  match fs:
    case Nil{}:
      0
    case Con{f, t}:
      match f:
        case Filt{c, lo, hi, hl, hh}:
          U32.or(U32.shln(1, U32.to_nat(c)), col_mask(t))


# ---------------------------------------------------------------------------
# Streaming row parser

def ps_new(+m: Meta, g2l: Array<U32>) -> PS:
  PS{m, g2l, Nil{}, Nil{}, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}


def ps_char(+h: U32, ps: PS) -> PS:
  match ps:
    case PS{m, g2l, edges, l2g, nloc, nedge, err, col, num, k, mode, iv, bad, nch, q, r, nd, kd, dbad, rej}:
      +d = U32.sub(h, 48)
      +dig = U32.is_lt(d, 10)
      +m0 = U32.is_eq(mode, 0)
      +m1 = U32.is_eq(mode, 1)
      +acc = Bool.and(dig, Bool.or(m0, m1))
      +ovf = Bool.and(acc, U32.is_ge(num, 429496729))
      +num2 = F.sel(acc, U32.add(U32.mul(num, 10), d), num)
      +dot0 = Bool.and(U32.is_eq(h, 46), m0)
      PS{m, g2l, edges, l2g, nloc, nedge, err, col, num2,
        F.sel(Bool.and(acc, m1), U32.inc(k), k),
        F.sel(dot0, 1, F.sel(Bool.and(Bool.or(m0, m1), Bool.not(dig)), 2, mode)),
        F.sel(Bool.and(dig, m0), num2, iv),
        U32.or(bad, F.b2u(Bool.or(Bool.and(Bool.not(dig), Bool.not(dot0)), ovf))),
        U32.inc(nch), q, r, nd, kd, dbad, rej}


# end of a field: ids, distance and filters; then the next column
def ps_field(ps: PS) -> PS:
  match ps:
    case PS{m, g2l, edges, l2g, nloc, nedge, err, col, num, k, mode, iv, bad, nch, q, r, nd, kd, dbad, rej}:
      match m:
        case Meta{nc, qc, rc, dc, fmask, cap, cuts}:
          +isq = U32.is_eq(col, qc)
          +isr = U32.is_eq(col, rc)
          +isid = Bool.or(isq, isr)
          +isd = Bool.and(U32.is_eq(col, dc), Bool.not(isid))
          +isf = Bool.and(Bool.and(U32.is_lt(col, 32), Bool.not(isid)),
            U32.is_eq(U32.and(U32.shrn(fmask, U32.to_nat(U32.and(col, 31))), 1), 1))
          +kbad = U32.is_gt(k, 15)
          +ci = U32.shln(U32.add(U32.shln(U32.and(col, 31), 4n), U32.and(k, 15)), 1n)
          +cmin = F.sel(isf, cut_get(cuts, ci), 0)
          +cmax = F.sel(isf, cut_get(cuts, U32.inc(ci)), 0)
          +fail = Bool.and(isf, Bool.or(U32.is_lt(num, cmin), U32.is_gt(num, cmax)))
          +ferr = Bool.and(isf, Bool.or(U32.is_ne(bad, 0), kbad))
          PS{Meta{nc, qc, rc, dc, fmask, cap, cuts}, g2l, edges, l2g, nloc, nedge,
            U32.or(err, F.b2u(ferr)), U32.inc(col), 0, 0, 0, 0, 0, nch,
            F.sel(isq, iv, q), F.sel(isr, iv, r), F.sel(isd, num, nd), F.sel(isd, k, kd),
            F.sel(isd, U32.or(bad, F.b2u(kbad)), dbad), U32.or(rej, F.b2u(fail))}


def map_new(fresh: Bool, g2l: Array<U32>, l2g: List<&2, U32>, +nloc: U32, +id: U32, +v: U32) -> MapR:
  match fresh:
    case True{}:
      MapR{Array.set(U32, g2l, id, nloc), id <> l2g, U32.inc(nloc), nloc}
    case False{}:
      MapR{g2l, l2g, nloc, v}


def map_go(r: Array<U32> & U32, l2g: List<&2, U32>, +nloc: U32, +id: U32) -> MapR:
  (g2l, +v) = r
  map_new(U32.is_eq(v, none()), g2l, l2g, nloc, id, v)


def map_id(g2l: Array<U32>, l2g: List<&2, U32>, +nloc: U32, +id: U32) -> MapR:
  map_go(Array.get(U32, g2l, id), l2g, nloc, id)


def accept_fin(mr: MapR, +m: Meta, edges: List<&2, Edge>, +nedge: U32, +err: U32, +lq: U32, +nd: U32, +kd: U32) -> PS:
  match mr:
    case MapR{g2l, l2g, nloc, lr}:
      PS{m, g2l, Edge{lq, lr, nd, kd} <> edges, l2g, nloc, U32.inc(nedge), err,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}


def accept_r(mq: MapR, +m: Meta, edges: List<&2, Edge>, +nedge: U32, +err: U32, +r: U32, +nd: U32, +kd: U32) -> PS:
  match mq:
    case MapR{g2l, l2g, nloc, lq}:
      accept_fin(map_id(g2l, l2g, nloc, r), m, edges, nedge, err, lq, nd, kd)


def ps_reset(ps: PS) -> PS:
  match ps:
    case PS{m, g2l, edges, l2g, nloc, nedge, err, col, num, k, mode, iv, bad, nch, q, r, nd, kd, dbad, rej}:
      PS{m, g2l, edges, l2g, nloc, nedge, err, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}


def ps_accept(go: Bool, ps: PS) -> PS:
  match go:
    case False{}:
      ps_reset(ps)
    case True{}:
      match ps:
        case PS{m, g2l, edges, l2g, nloc, nedge, err, col, num, k, mode, iv, bad, nch, q, r, nd, kd, dbad, rej}:
          accept_r(map_id(g2l, l2g, nloc, q), m, edges, nedge, err, r, nd, kd)


# end of a non-empty row (after its last field)
def ps_row(ps: PS) -> PS:
  match ps:
    case PS{m, g2l, edges, l2g, nloc, nedge, err, col, num, k, mode, iv, bad, nch, q, r, nd, kd, dbad, rej}:
      match m:
        case Meta{nc, qc, rc, dc, fmask, cap, cuts}:
          +ok = U32.is_eq(col, nc)
          +go = Bool.and(Bool.and(ok, U32.is_eq(rej, 0)), U32.is_ne(q, r))
          +inr = Bool.and(U32.is_lt(q, cap), U32.is_lt(r, cap))
          +e2 = U32.or(err, U32.or(F.sel(ok, 0, 2),
            F.sel(go, U32.or(F.sel(inr, 0, 4), F.sel(U32.is_eq(dbad, 0), 0, 1)), 0)))
          ps_accept(Bool.and(go, inr), PS{Meta{nc, qc, rc, dc, fmask, cap, cuts}, g2l, edges, l2g, nloc, nedge, e2,
            col, num, k, mode, iv, bad, nch, q, r, nd, kd, dbad, rej})


def ps_nch(ps: PS) -> PS & U32:
  match ps:
    case PS{m, g2l, edges, l2g, nloc, nedge, err, col, num, k, mode, iv, bad, nch, q, r, nd, kd, dbad, rej}:
      (PS{m, g2l, edges, l2g, nloc, nedge, err, col, num, k, mode, iv, bad, nch, q, r, nd, kd, dbad, rej}, nch)


def ps_line(empty: Bool, ps: PS) -> PS:
  match empty:
    case True{}:
      ps
    case False{}:
      ps_row(ps_field(ps))


def ps_newline_go(r: PS & U32) -> PS:
  (ps, +nch) = r
  ps_line(U32.is_eq(nch, 0), ps)


def ps_newline(ps: PS) -> PS:
  ps_newline_go(ps_nch(ps))


# a separator also counts as a character of the line (",," is not empty)
def ps_sep(ps: PS) -> PS:
  match ps:
    case PS{m, g2l, edges, l2g, nloc, nedge, err, col, num, k, mode, iv, bad, nch, q, r, nd, kd, dbad, rej}:
      ps_field(PS{m, g2l, edges, l2g, nloc, nedge, err, col, num, k, mode, iv, bad, U32.inc(nch), q, r, nd, kd, dbad, rej})


def ps_byte(nl: Bool, sep: Bool, +h: U32, ps: PS) -> PS:
  match nl sep:
    case True{} _:
      ps_newline(ps)
    case False{} True{}:
      ps_sep(ps)
    case False{} False{}:
      ps_char(h, ps)


def ps_bytes(bs: List<&2, U32>, ps: PS) -> PS:
  match bs:
    case Nil{}:
      ps
    case Con{+h, t}:
      ps_bytes(t, ps_byte(is_nl(h), is_sep(h), h, ps))
