# LZ-ANI 1.2.3 parser (CParser) for the Vclust `align` stage.
#
# One working Array<U32> per task holds every region (reference with its
# reverse complement, reference k-mer buckets, query, query k-mers, factor
# stack, probability tables); `Ctx` records the region offsets and the
# LZ-ANI parameters. The parse is a faithful port of CParser::parse,
# compare_ranges, compare_ranges_both_ways, try_extend_forward/backward and
# calc_stats (see README "align" section for the correspondences).
import Base
import ./align_num.bend as N

def when(-A: Type, c: Bool, k: Bool -> A) -> A:
  k(c)

# box: a dummy boxed field, so a Ctx is passed as one pointer (borrowed)
# instead of 24 unboxed words per call
type Ctx is Data:
  Ctx{o_r: U32, rlen: U32, o_lh: U32, lmask: U32, o_lp: U32, o_lk: U32, o_sh: U32, o_sp: U32, o_at: U32, o_ct: U32, o_d: U32, dlen: U32, o_dl: U32, o_ds: U32, o_f: U32, o_w: U32, mal: U32, msl: U32, mrd: U32, mqd: U32, reg: U32, aw: U32, am: U32, ar: U32, box: List<&2, U32>}

def c_o_r(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      o_r

def c_rlen(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      rlen

def c_o_lh(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      o_lh

def c_lmask(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      lmask

def c_o_lp(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      o_lp

def c_o_lk(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      o_lk

def c_o_sh(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      o_sh

def c_o_sp(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      o_sp

def c_o_at(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      o_at

def c_o_ct(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      o_ct

def c_o_d(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      o_d

def c_dlen(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      dlen

def c_o_dl(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      o_dl

def c_o_ds(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      o_ds

def c_o_f(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      o_f

def c_o_w(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      o_w

def c_mal(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      mal

def c_msl(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      msl

def c_mrd(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      mrd

def c_mqd(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      mqd

def c_reg(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      reg

def c_aw(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      aw

def c_am(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      am

def c_ar(+c: Ctx) -> U32:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen, o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      ar
def ctx_dlen(+c: Ctx, +dlen: U32) -> Ctx:
  match c:
    case Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, old,
             o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}:
      Ctx{o_r, rlen, o_lh, lmask, o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, dlen,
        o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, box}

def INV() -> U32:
  4294967295

def F_CLOSE() -> U32:
  0

def F_DIST() -> U32:
  1

def F_RUN() -> U32:
  2

def hash(+word: U32) -> U32:
  +a = U32.xor(word, U32.shrn(word, 16n))
  +b = (a * 2146121005 : U32)
  +d = U32.xor(b, U32.shrn(b, 15n))
  +e = (d * 2221713035 : U32)
  U32.xor(e, U32.shrn(e, 16n))

def rd(-B: Type, q: Array<U32> & U32, k: Array<U32> -> U32 -> B) -> B:
  (m, v) = q
  k(m)(v)

def get(m: Array<U32>, +i: U32) -> Array<U32> & U32:
  Array.get(U32, m, i)

def set(m: Array<U32>, +i: U32, +v: U32) -> Array<U32>:
  Array.set(U32, m, i, v)

def set_if(c: Bool, m: Array<U32>, +i: U32, +v: U32) -> Array<U32>:
  match c:
    case True{}:
      Array.set(U32, m, i, v)
    case False{}:
      m

# Factor stack
# ============
# factor k: f[2k] = data position, f[2k+1] = len * 4 + flag

type Fac is Data:
  Fac{pos: U32, flag: U32, len: U32}

def spush(+c: Ctx, m: Array<U32>, +n: U32, +pos: U32, +flag: U32, +len: U32) -> Array<U32>:
  +at = (c_o_f(c) + n + n : U32)
  set(set(m, at, pos), (at + 1 : U32), (len * 4 + flag : U32))

def spush_if(b: Bool, +c: Ctx, m: Array<U32>, +n: U32, +pos: U32, +flag: U32, +len: U32) -> Array<U32>:
  match b:
    case True{}:
      spush(c, m, n, pos, flag, len)
    case False{}:
      m

# rewrite the top factor's length/flag
def sset(+c: Ctx, m: Array<U32>, +n: U32, +flag: U32, +len: U32) -> Array<U32>:
  set(m, (c_o_f(c) + n + n - 1 : U32), (len * 4 + flag : U32))

def sback.b(+pos: U32, q: Array<U32> & U32) -> Array<U32> & Fac:
  (m, +w) = q
  (m, Fac{pos, U32.and(w, 3), U32.shrn(w, 2n)})

def sback.a(+at: U32, q: Array<U32> & U32) -> Array<U32> & Fac:
  (m, pos) = q
  sback.b(pos, get(m, (at + 1 : U32)))

# factor k (0-based)
def sget(+c: Ctx, m: Array<U32>, +k: U32) -> Array<U32> & Fac:
  +at = (c_o_f(c) + k + k : U32)
  sback.a(at, get(m, at))

# equal_len
# =========

type Re is Type:
  Re{same: Bool, m: Array<U32>}

def eql.cmp(+b: U32, q: Array<U32> & U32) -> Re:
  (m, a) = q
  Re{U32.is_eq(a, b), m}

def eql.rd(+rp: U32, q: Array<U32> & U32) -> Re:
  (m, b) = q
  eql.cmp(b, get(m, rp))

def eql.go(+fuel: Nat, x: Re, +rp: U32, +dp: U32, +k: U32) -> Array<U32> & U32:
  match fuel x:
    case _ Re{False{}, m}:
      (m, k)
    case 0n Re{True{}, m}:
      (m, (k + 1 : U32))
    case 1n+f Re{True{}, m}:
      eql.go(f, eql.rd(rp, get(m, dp)), (rp + 1 : U32), (dp + 1 : U32), (k + 1 : U32))

# CParser::equal_len(pos, i, start)
def eql(+c: Ctx, m: Array<U32>, +pos: U32, +i: U32, +start: U32) -> Array<U32> & U32:
  +maxr = N.u32_min((c_rlen(c) - pos : U32), (c_dlen(c) - i : U32))
  eql.go(U32.to_nat(N.u32_monus(maxr, start)), Re{True{}, m},
    (c_o_r(c) + pos + start : U32), (c_o_d(c) + i + start : U32), (start - 1 : U32))

# Anchor searches
# ===============

type Best is Data:
  Best{pos: U32, len: U32}

type LS is Type:
  LS{go: Bool, m: Array<U32>, j: U32, e: U32, bp: U32, bl: U32}

def ls.fin(s: LS) -> Array<U32> & Best:
  match s:
    case LS{g, m, j, e, bp, bl}:
      (m, Best{bp, bl})

def ls.upd(+c: Ctx, +j: U32, +e: U32, +bp: U32, +bl: U32, +pos: U32,
           q: Array<U32> & U32) -> LS:
  (m, +ml) = q
  +up = U32.is_ge(ml, c_mal(c)) && U32.is_gt(ml, bl)
  +j2 = (j + 1 : U32)
  LS{U32.is_lt(j2, e), m, j2, e, N.u32_if(up, pos, bp), N.u32_if(up, ml, bl)}

def ls.rd3(+c: Ctx, +i: U32, +j: U32, +e: U32, +bp: U32, +bl: U32,
           q: Array<U32> & U32) -> LS:
  (m, +pos) = q
  ls.upd(c, j, e, bp, bl, pos, eql(c, m, pos, i, c_mal(c)))

def ls.rd2(hit: Bool, +c: Ctx, +i: U32, +j: U32, +e: U32, +bp: U32, +bl: U32, m: Array<U32>) -> LS:
  match hit:
    case True{}:
      ls.rd3(c, i, j, e, bp, bl, get(m, (c_o_lp(c) + j : U32)))
    case False{}:
      +j2 = (j + 1 : U32)
      LS{U32.is_lt(j2, e), m, j2, e, bp, bl}

# slot j: key at lk[j], position at lp[j]
def ls.rd(+c: Ctx, +i: U32, +kv: U32, +j: U32, +e: U32, +bp: U32, +bl: U32,
          q: Array<U32> & U32) -> LS:
  (m, +key) = q
  ls.rd2(U32.is_eq(key, kv), c, i, j, e, bp, bl, m)

def ls.go(+fuel: Nat, s: LS, +c: Ctx, +i: U32, +kv: U32) -> LS:
  match fuel s:
    case _ LS{False{}, m, j, e, bp, bl}:
      LS{False{}, m, j, e, bp, bl}
    case 0n LS{True{}, m, j, e, bp, bl}:
      LS{False{}, m, j, e, bp, bl}
    case 1n+f LS{True{}, m, +j, +e, +bp, +bl}:
      ls.go(f, ls.rd(c, i, kv, j, e, bp, bl, get(m, (c_o_lk(c) + j : U32))), c, i, kv)

def lfind.b(+c: Ctx, +i: U32, +kv: U32, +s: U32, q: Array<U32> & U32) -> Array<U32> & Best:
  (m, +e) = q
  ls.fin(ls.go(U32.to_nat(N.u32_monus(e, s)), LS{U32.is_lt(s, e), m, s, e, 0, 0}, c, i, kv))

def lfind.a(+c: Ctx, +i: U32, +kv: U32, +b: U32, q: Array<U32> & U32) -> Array<U32> & Best:
  (m, +s) = q
  lfind.b(c, i, kv, s, get(m, (c_o_lh(c) + b + 1 : U32)))

def lfind.k2(inv: Bool, +c: Ctx, +i: U32, +kv: U32, m: Array<U32>) -> Array<U32> & Best:
  match inv:
    case True{}:
      (m, Best{0, 0})
    case False{}:
      +b = U32.and(hash(kv), c_lmask(c))
      lfind.a(c, i, kv, b, get(m, (c_o_lh(c) + b : U32)))

def lfind.k(+c: Ctx, +i: U32, q: Array<U32> & U32) -> Array<U32> & Best:
  (m, +kv) = q
  lfind.k2(U32.is_eq(kv, INV()), c, i, kv, m)

# longest reference match >= mal of the query k-mer at i (first on ties)
def lfind(+c: Ctx, m: Array<U32>, +i: U32) -> Array<U32> & Best:
  lfind.k(c, i, get(m, (c_o_dl(c) + i : U32)))

type BS is Type:
  BS{go: Bool, m: Array<U32>, lo: U32, hi: U32}

def lb.step(+lo: U32, +hi: U32, +mid: U32, +t: U32, q: Array<U32> & U32) -> BS:
  (m, +v) = q
  +lt = U32.is_lt(v, t)
  +lo2 = N.u32_if(lt, (mid + 1 : U32), lo)
  +hi2 = N.u32_if(lt, hi, mid)
  BS{U32.is_lt(lo2, hi2), m, lo2, hi2}

# first slot in [lo, hi) of the sorted region at o whose value is >= t
def lb.go(+fuel: Nat, s: BS, +o: U32, +t: U32) -> BS:
  match fuel s:
    case _ BS{False{}, m, lo, hi}:
      BS{False{}, m, lo, hi}
    case 0n BS{True{}, m, lo, hi}:
      BS{False{}, m, lo, hi}
    case 1n+f BS{True{}, m, +lo, +hi}:
      +mid = (lo + U32.shrn((hi - lo : U32), 1n) : U32)
      lb.go(f, lb.step(lo, hi, mid, t, get(m, (o + mid : U32))), o, t)

def cs.upd(+pred: U32, +j: U32, +e: U32, +bp: U32, +bl: U32, +pos: U32,
           q: Array<U32> & U32) -> LS:
  (m, +ml) = q
  +ge = U32.is_ge(ml, bl)
  +eq = U32.is_eq(ml, bl)
  +closer = U32.is_lt(N.u32_dist(pos, pred), N.u32_dist(bp, pred))
  +nbp = N.u32_if(ge, N.u32_if(eq, N.u32_if(closer, pos, bp), pos), bp)
  +j2 = (j + 1 : U32)
  LS{U32.is_lt(j2, e), m, j2, e, nbp, N.u32_if(ge, ml, bl)}

def cs.rd2(ok: Bool, +c: Ctx, +i: U32, +pred: U32, +j: U32, +e: U32, +bp: U32,
           +bl: U32, +pos: U32, m: Array<U32>) -> LS:
  match ok:
    case True{}:
      cs.upd(pred, j, e, bp, bl, pos, eql(c, m, pos, i, c_msl(c)))
    case False{}:
      LS{False{}, m, j, e, bp, bl}

def cs.rd(+c: Ctx, +i: U32, +pred: U32, +lim: U32, +j: U32, +e: U32, +bp: U32,
          +bl: U32, q: Array<U32> & U32) -> LS:
  (m, +pos) = q
  cs.rd2(U32.is_lt(pos, lim), c, i, pred, j, e, bp, bl, pos, m)

def cs.go(+fuel: Nat, s: LS, +c: Ctx, +i: U32, +pred: U32, +lim: U32) -> LS:
  match fuel s:
    case _ LS{False{}, m, j, e, bp, bl}:
      LS{False{}, m, j, e, bp, bl}
    case 0n LS{True{}, m, j, e, bp, bl}:
      LS{False{}, m, j, e, bp, bl}
    case 1n+f LS{True{}, m, +j, +e, +bp, +bl}:
      cs.go(f, cs.rd(c, i, pred, lim, j, e, bp, bl, get(m, (c_o_sp(c) + j : U32))),
        c, i, pred, lim)

def cfind.c(+c: Ctx, +i: U32, +pred: U32, +e: U32, s: BS) -> Array<U32> & Best:
  match s:
    case BS{g, m, +lo, hi}:
      ls.fin(cs.go(U32.to_nat(N.u32_monus(e, lo)), LS{U32.is_lt(lo, e), m, lo, e, 0, 0},
        c, i, pred, (pred + c_mrd(c) : U32)))

def cfind.b(+c: Ctx, +i: U32, +pred: U32, +lit: U32, +s: U32, q: Array<U32> & U32) -> Array<U32> & Best:
  (m, +e) = q
  cfind.c(c, i, pred, e, lb.go(33n, BS{U32.is_lt(s, e), m, s, e}, c_o_sp(c), (pred - lit : U32)))

def cfind.a(+c: Ctx, +i: U32, +pred: U32, +lit: U32, +h: U32, q: Array<U32> & U32) -> Array<U32> & Best:
  (m, +s) = q
  cfind.b(c, i, pred, lit, s, get(m, (c_o_sh(c) + h + 1 : U32)))

def cfind.k2(inv: Bool, +c: Ctx, +i: U32, +pred: U32, +lit: U32, +h: U32, m: Array<U32>) -> Array<U32> & Best:
  match inv:
    case True{}:
      (m, Best{0, 0})
    case False{}:
      cfind.a(c, i, pred, lit, h, get(m, (c_o_sh(c) + h : U32)))

def cfind.k(+c: Ctx, +i: U32, +pred: U32, +lit: U32, q: Array<U32> & U32) -> Array<U32> & Best:
  (m, +h) = q
  cfind.k2(U32.is_eq(h, INV()), c, i, pred, lit, h, m)

# best close seed: reference positions in [pred - lit, pred + mrd)
def cfind(+c: Ctx, m: Array<U32>, +i: U32, +pred: U32, +lit: U32) -> Array<U32> & Best:
  cfind.k(c, i, pred, lit, get(m, (c_o_ds(c) + i : U32)))

# Close/distant probability choice
# ================================

def dbl_at.c(+e: U32, +hi: U32, q: Array<U32> & U32) -> Array<U32> & N.Dbl:
  (m, +lo) = q
  (m, N.Dbl{e, hi, lo})

def dbl_at.b(+at: U32, +e: U32, q: Array<U32> & U32) -> Array<U32> & N.Dbl:
  (m, +hi) = q
  dbl_at.c(e, hi, get(m, (at + 2 : U32)))

def dbl_at.a(+at: U32, q: Array<U32> & U32) -> Array<U32> & N.Dbl:
  (m, +e) = q
  dbl_at.b(at, e, get(m, (at + 1 : U32)))

def dbl_at(m: Array<U32>, +at: U32, +one: Bool) -> Array<U32> & N.Dbl:
  match one:
    case True{}:
      (m, N.dbl_one())
    case False{}:
      dbl_at.a(at, get(m, at))

def best_pick(c: Bool, +a: Best, +b: Best) -> Best:
  match c:
    case True{}:
      a
    case False{}:
      b

def choose.b(cb: Best, ab: Best, a: N.Dbl, q: Array<U32> & N.Dbl) -> Array<U32> & Best:
  (m, cl) = q
  (m, best_pick(N.dbl_gt(a, cl), ab, cb))

def choose.a(+c: Ctx, +lit: U32, +cb: Best, +ab: Best, q: Array<U32> & N.Dbl) -> Array<U32> & Best:
  match cb:
    case Best{cp, +cl}:
      (m, a) = q
      choose.b(cb, ab, a, dbl_at(m,
        (c_o_ct(c) + 3 * ((cl - c_msl(c)) * (c_mqd(c) + 1) + lit) : U32),
        U32.is_ge(cl, 27)))

def choose.k(noa: Bool, noc: Bool, +c: Ctx, m: Array<U32>, +lit: U32, +cb: Best, +ab: Best, +al: U32) -> Array<U32> & Best:
  match noa noc:
    case True{} _:
      (m, cb)
    case False{} True{}:
      (m, ab)
    case False{} False{}:
      choose.a(c, lit, cb, ab, dbl_at(m, (c_o_at(c) + 3 * (al - c_mal(c)) : U32), U32.is_ge(al, 27)))

# CParser::parse anchor/close selection
def choose(+c: Ctx, m: Array<U32>, +lit: U32, +cb: Best, +ab: Best) -> Array<U32> & Best:
  match cb ab:
    case Best{+cp, cl} Best{+ap, +al}:
      choose.k(U32.is_eq(ap, 0), U32.is_eq(cp, 0), c, m, lit, cb, ab, al)

def find.b(+c: Ctx, +lit: U32, +cb: Best, q: Array<U32> & Best) -> Array<U32> & Best:
  (m, +ab) = q
  choose(c, m, lit, cb, ab)

def find.a(+c: Ctx, +i: U32, +lit: U32, q: Array<U32> & Best) -> Array<U32> & Best:
  (m, +cb) = q
  find.b(c, lit, cb, lfind(c, m, i))

def find(+c: Ctx, m: Array<U32>, +i: U32, +has: Bool, +pred: U32, +lit: U32) -> Array<U32> & Best:
  match has:
    case False{}:
      lfind(c, m, i)
    case True{}:
      find.a(c, i, lit, cfind(c, m, i, pred, lit))

# Approximate extensions
# ======================

type XS is Type:
  XS{go: Bool, m: Array<U32>, e: U32, nm: U32, win: U32, run: U32, last: U32}

def xs.fin(s: XS) -> Array<U32> & U32:
  match s:
    case XS{g, m, e, nm, win, run, last}:
      (m, last)

# one window step: a = query symbol, b = reference symbol
def xs.next(+c: Ctx, +a: U32, +e: U32, +nm: U32, +win: U32, +run: U32,
            +last: U32, +more: Bool, q: Array<U32> & U32) -> XS:
  (m, +b) = q
  +mis = U32.is_ne(a, b)
  +mi = N.b2u(mis)
  +aw = c_aw(c)
  +old = U32.and(U32.shrn(win, U32.to_nat((aw - 1 : U32))), 1)
  +win2 = U32.and(U32.or(U32.shln(win, 1n), mi), (U32.shln(1, U32.to_nat(aw)) - 1 : U32))
  +nm2 = (nm - old + mi : U32)
  +run2 = N.u32_if(mis, 0, (run + 1 : U32))
  +e2 = (e + 1 : U32)
  +last2 = N.u32_if(Bool.not(mis) && U32.is_ge(run2, c_ar(c)), e2, last)
  XS{U32.is_le(nm2, c_am(c)) && more, m, e2, nm2, win2, run2, last2}

def xf.j(+c: Ctx, +ds: U32, +rs: U32, +e: U32, +nm: U32, +win: U32, +run: U32,
         +last: U32, q: Array<U32> & U32) -> XS:
  (m, +a) = q
  +e2 = (e + 1 : U32)
  xs.next(c, a, e, nm, win, run, last,
    U32.is_lt((ds + e2 : U32), c_dlen(c)) && U32.is_lt((rs + e2 : U32), c_rlen(c)),
    get(m, (c_o_r(c) + rs + e : U32)))

def xf.go(+fuel: Nat, s: XS, +c: Ctx, +ds: U32, +rs: U32) -> XS:
  match fuel s:
    case _ XS{False{}, m, e, nm, win, run, last}:
      XS{False{}, m, e, nm, win, run, last}
    case 0n XS{True{}, m, e, nm, win, run, last}:
      XS{False{}, m, e, nm, win, run, last}
    case 1n+f XS{True{}, m, +e, +nm, +win, +run, +last}:
      xf.go(f, xf.j(c, ds, rs, e, nm, win, run, last, get(m, (c_o_d(c) + ds + e : U32))), c, ds, rs)

# CParser::try_extend_forward
def xfwd(+c: Ctx, m: Array<U32>, +ds: U32, +rs: U32) -> Array<U32> & U32:
  xs.fin(xf.go(U32.to_nat(c_dlen(c)),
    XS{U32.is_lt(ds, c_dlen(c)) && U32.is_lt(rs, c_rlen(c)), m, 0, 0, 0, c_ar(c), 0},
    c, ds, rs))

def xb.j(+c: Ctx, +ds: U32, +rs: U32, +ml: U32, +e: U32, +nm: U32, +win: U32,
         +run: U32, +last: U32, q: Array<U32> & U32) -> XS:
  (m, +a) = q
  +e2 = (e + 1 : U32)
  xs.next(c, a, e, nm, win, run, last,
    U32.is_gt(ds, e2) && U32.is_gt(rs, e2) && U32.is_lt(e2, ml),
    get(m, (c_o_r(c) + rs - e - 1 : U32)))

def xb.go(+fuel: Nat, s: XS, +c: Ctx, +ds: U32, +rs: U32, +ml: U32) -> XS:
  match fuel s:
    case _ XS{False{}, m, e, nm, win, run, last}:
      XS{False{}, m, e, nm, win, run, last}
    case 0n XS{True{}, m, e, nm, win, run, last}:
      XS{False{}, m, e, nm, win, run, last}
    case 1n+f XS{True{}, m, +e, +nm, +win, +run, +last}:
      xb.go(f, xb.j(c, ds, rs, ml, e, nm, win, run, last,
        get(m, (c_o_d(c) + ds - e - 1 : U32))), c, ds, rs, ml)

# CParser::try_extend_backward
def xbwd(+c: Ctx, m: Array<U32>, +ds: U32, +rs: U32, +ml: U32) -> Array<U32> & U32:
  xs.fin(xb.go(U32.to_nat(ml),
    XS{U32.is_gt(ds, 0) && U32.is_gt(rs, 0) && U32.is_gt(ml, 0), m, 0, 0, 0, c_ar(c), 0},
    c, ds, rs, ml))

# compare_ranges
# ==============

type CR is Type:
  CR{go: Bool, m: Array<U32>, j: U32, n: U32, rl: U32, mat: Bool, flag: U32}

def cr.k(+c: Ctx, +ds: U32, +len: U32, +j: U32, +n: U32, +rl: U32, +mat: Bool,
         +flag: U32, +a: U32, q: Array<U32> & U32) -> CR:
  (m, +b) = q
  +eq = U32.is_eq(b, a)
  +push = (eq && Bool.not(mat) && U32.is_gt(rl, 0)) || (Bool.not(eq) && mat)
  +j2 = (j + 1 : U32)
  CR{U32.is_lt(j2, len),
    spush_if(push, c, m, n, (ds + j - rl : U32), N.u32_if(eq, F_RUN(), flag), rl),
    j2, (n + N.b2u(push) : U32),
    N.u32_if(Bool.not(eq) && Bool.not(mat), (rl + 1 : U32), N.u32_if(eq && mat, (rl + 1 : U32), 1)),
    eq, N.u32_if(Bool.not(eq) && mat, F_CLOSE(), flag)}

def cr.j(+c: Ctx, +ds: U32, +rs: U32, +len: U32, +j: U32, +n: U32, +rl: U32,
         +mat: Bool, +flag: U32, q: Array<U32> & U32) -> CR:
  (m, +a) = q
  cr.k(c, ds, len, j, n, rl, mat, flag, a, get(m, (c_o_r(c) + rs + j : U32)))

def cr.go(+fuel: Nat, s: CR, +c: Ctx, +ds: U32, +rs: U32, +len: U32) -> CR:
  match fuel s:
    case _ CR{False{}, m, j, n, rl, mat, flag}:
      CR{False{}, m, j, n, rl, mat, flag}
    case 0n CR{True{}, m, j, n, rl, mat, flag}:
      CR{False{}, m, j, n, rl, mat, flag}
    case 1n+f CR{True{}, m, +j, +n, +rl, +mat, +flag}:
      cr.go(f, cr.j(c, ds, rs, len, j, n, rl, mat, flag, get(m, (c_o_d(c) + ds + j : U32))),
        c, ds, rs, len)

def cr.fin(+c: Ctx, +ds: U32, +len: U32, s: CR) -> Array<U32> & U32:
  match s:
    case CR{g, m, j, +n, +rl, +mat, +flag}:
      +push = mat || U32.is_gt(rl, 0)
      (spush_if(push, c, m, n, (ds + len - rl : U32), N.u32_if(mat, flag, F_RUN()), rl),
       (n + N.b2u(push) : U32))

# CParser::compare_ranges; returns the new stack size
def crange(+c: Ctx, m: Array<U32>, +n: U32, +ds: U32, +rs: U32, +len: U32, +bw: Bool) -> Array<U32> & U32:
  cr.fin(c, ds, len, cr.go(U32.to_nat(len),
    CR{U32.is_gt(len, 0), m, 0, n, 0, False{}, N.u32_if(bw, F_DIST(), F_CLOSE())}, c, ds, rs, len))

# compare_ranges_both_ways
# ========================
# left_side[i] at w[i], right_side[i] at w[mqd + 2 + i], each count * 2 + match

type CW is Type:
  CW{go: Bool, m: Array<U32>, i: U32, cnt: U32}

def cw.fin(s: CW) -> Array<U32>:
  match s:
    case CW{g, m, i, cnt}:
      m

def cwl.k(+c: Ctx, +to: U32, +i: U32, +cnt: U32, +a: U32, q: Array<U32> & U32) -> CW:
  (m, +b) = q
  +eq = U32.is_eq(b, a)
  +cnt2 = (cnt + N.b2u(eq) : U32)
  +i2 = (i + 1 : U32)
  CW{U32.is_lt(i2, to), set(m, (c_o_w(c) + i2 : U32), (cnt2 * 2 + N.b2u(eq) : U32)), i2, cnt2}

def cwl.j(+c: Ctx, +ds: U32, +rsl: U32, +to: U32, +i: U32, +cnt: U32, q: Array<U32> & U32) -> CW:
  (m, +a) = q
  cwl.k(c, to, i, cnt, a, get(m, (c_o_r(c) + rsl + i : U32)))

def cwl.go(+fuel: Nat, s: CW, +c: Ctx, +ds: U32, +rsl: U32, +to: U32) -> CW:
  match fuel s:
    case _ CW{False{}, m, i, cnt}:
      CW{False{}, m, i, cnt}
    case 0n CW{True{}, m, i, cnt}:
      CW{False{}, m, i, cnt}
    case 1n+f CW{True{}, m, +i, +cnt}:
      cwl.go(f, cwl.j(c, ds, rsl, to, i, cnt, get(m, (c_o_d(c) + ds + i : U32))), c, ds, rsl, to)

# right side: i from 1 to lim
def cwr.k(+c: Ctx, +lim: U32, +i: U32, +cnt: U32, +a: U32, q: Array<U32> & U32) -> CW:
  (m, +b) = q
  +eq = U32.is_eq(b, a)
  +cnt2 = (cnt + N.b2u(eq) : U32)
  CW{U32.is_lt(i, lim), set(m, (c_o_w(c) + c_mqd(c) + 2 + i : U32), (cnt2 * 2 + N.b2u(eq) : U32)),
    (i + 1 : U32), cnt2}

def cwr.j(+c: Ctx, +rer: U32, +lim: U32, +i: U32, +cnt: U32, q: Array<U32> & U32) -> CW:
  (m, +a) = q
  cwr.k(c, lim, i, cnt, a, get(m, (c_o_r(c) + rer - i : U32)))

def cwr.go(+fuel: Nat, s: CW, +c: Ctx, +ds: U32, +rer: U32, +len: U32, +lim: U32) -> CW:
  match fuel s:
    case _ CW{False{}, m, i, cnt}:
      CW{False{}, m, i, cnt}
    case 0n CW{True{}, m, i, cnt}:
      CW{False{}, m, i, cnt}
    case 1n+f CW{True{}, m, +i, +cnt}:
      cwr.go(f, cwr.j(c, rer, lim, i, cnt, get(m, (c_o_d(c) + ds + len - i : U32))),
        c, ds, rer, len, lim)

def zfill(+fuel: Nat, m: Array<U32>, +at: U32) -> Array<U32>:
  match fuel:
    case 0n:
      m
    case 1n+f:
      zfill(f, set(m, at, 0), (at + 1 : U32))

def vfill(+fuel: Nat, m: Array<U32>, +at: U32, +v: U32) -> Array<U32>:
  match fuel:
    case 0n:
      m
    case 1n+f:
      vfill(f, set(m, at, v), (at + 1 : U32), v)

# best split: max over i of left[i].cnt + right[to - i].cnt, latest on ties
type BB is Type:
  BB{m: Array<U32>, best: U32, mx: U32}

def bb.b(+i: U32, +l: U32, +best: U32, +mx: U32, q: Array<U32> & U32) -> BB:
  (m, +r) = q
  +nm = (U32.shrn(l, 1n) + U32.shrn(r, 1n) : U32)
  +ge = U32.is_ge(nm, mx)
  BB{m, N.u32_if(ge, i, best), N.u32_if(ge, nm, mx)}

def bb.a(+c: Ctx, +to: U32, +i: U32, +best: U32, +mx: U32, q: Array<U32> & U32) -> BB:
  (m, +l) = q
  bb.b(i, l, best, mx, get(m, (c_o_w(c) + c_mqd(c) + 2 + to - i : U32)))

def bb.go(+fuel: Nat, s: BB, +c: Ctx, +to: U32, +i: U32) -> BB:
  match fuel s:
    case 0n BB{m, best, mx}:
      BB{m, best, mx}
    case 1n+f BB{m, +best, +mx}:
      bb.go(f, bb.a(c, to, i, best, mx, get(m, (c_o_w(c) + i : U32))), c, to, (i + 1 : U32))

# store flags: back = (bf, blen) is the top factor we pushed (n factors)
type SW is Type:
  SW{m: Array<U32>, n: U32, bf: U32, blen: U32}

def sw.put(+c: Ctx, +dp: U32, +cf: U32, s: SW, +merge: Bool) -> SW:
  match s merge:
    case SW{m, +n, +bf, +blen} True{}:
      SW{sset(c, m, n, bf, (blen + 1 : U32)), n, bf, (blen + 1 : U32)}
    case SW{m, +n, bf, blen} False{}:
      SW{spush(c, m, n, dp, cf, 1), (n + 1 : U32), cf, 1}

def flag_of(+w: U32) -> U32:
  N.u32_if(U32.is_eq(U32.and(w, 1), 1), F_CLOSE(), F_RUN())

def swl.k(+c: Ctx, +dp: U32, q: Array<U32> & U32, +n: U32, +bf: U32, +blen: U32) -> SW:
  (m, +w) = q
  +cf = flag_of(w)
  sw.put(c, dp, cf, SW{m, n, bf, blen}, U32.is_eq(cf, bf))

# left side i = from..best (ascending), data position ds + i - 1
def swl.go(+fuel: Nat, s: SW, +c: Ctx, +ds: U32, +i: U32) -> SW:
  match fuel s:
    case 0n SW{m, n, bf, blen}:
      SW{m, n, bf, blen}
    case 1n+f SW{m, +n, +bf, +blen}:
      swl.go(f, swl.k(c, (ds + i - 1 : U32), get(m, (c_o_w(c) + i : U32)), n, bf, blen),
        c, ds, (i + 1 : U32))

# right side i = from..1 (descending), data positions dp, dp + 1, ...
def swr.go(+fuel: Nat, s: SW, +c: Ctx, +dp: U32, +i: U32) -> SW:
  match fuel s:
    case 0n SW{m, n, bf, blen}:
      SW{m, n, bf, blen}
    case 1n+f SW{m, +n, +bf, +blen}:
      swr.go(f, swl.k(c, dp, get(m, (c_o_w(c) + c_mqd(c) + 2 + i : U32)), n, bf, blen),
        c, (dp + 1 : U32), (i - 1 : U32))

def sw.fin(s: SW) -> Array<U32> & U32:
  match s:
    case SW{m, n, bf, blen}:
      (m, n)

# right part, first symbol
def bw.right1(+c: Ctx, +dp: U32, +best: U32, +shift: U32, +fr: U32, q: Array<U32> & U32,
              +n: U32, +bf: U32, +blen: U32) -> SW:
  (m, +w) = q
  +cf = flag_of(w)
  +merge = U32.is_eq(cf, F_RUN()) && (U32.is_gt(best, 0) || U32.is_gt(shift, 0))
    && U32.is_eq(bf, F_RUN())
  +dp2 = N.u32_if(merge, dp, (dp + 1 : U32))
  swr.go(U32.to_nat((fr - 1 : U32)), sw.put(c, dp, cf, SW{m, n, bf, blen}, merge), c, dp2,
    (fr - 1 : U32))

def bw.right(+c: Ctx, +ds: U32, +len: U32, +to: U32, +best: U32, s: SW) -> SW:
  match s:
    case SW{m, +n, +bf, +blen}:
      when(SW, U32.is_lt(best, to), \{
        True: (
          +shift = (len - to : U32)
          +fr = (to - best : U32)
          bw.right1(c, (ds + best + shift : U32), best, shift, fr,
            get(m, (c_o_w(c) + c_mqd(c) + 2 + fr : U32)), n, bf, blen))
        False: SW{m, n, bf, blen}
      })

def bw.middle(+c: Ctx, +ds: U32, +len: U32, +to: U32, +best: U32, s: SW) -> SW:
  match s:
    case SW{m, +n, +bf, +blen}:
      when(SW, U32.is_lt(to, len), \{
        True: when(SW, U32.is_gt(best, 0) && U32.is_eq(bf, F_RUN()), \{
          True: (
            +l2 = (blen + len - to : U32)
            SW{sset(c, m, n, bf, l2), n, bf, l2})
          False: SW{spush(c, m, n, (ds + best : U32), F_RUN(), (len - to : U32)),
            (n + 1 : U32), F_RUN(), (len - to : U32)}
        })
        False: SW{m, n, bf, blen}
      })

def bw.left1(+c: Ctx, +ds: U32, +best: U32, +n: U32, q: Array<U32> & U32) -> SW:
  (m, +w) = q
  +cf = flag_of(w)
  swl.go(U32.to_nat((best - 1 : U32)), SW{spush(c, m, n, ds, cf, 1), (n + 1 : U32), cf, 1},
    c, ds, 2)

def bw.left(+c: Ctx, +ds: U32, +best: U32, s: BB, +n: U32) -> SW:
  match s:
    case BB{m, b, mx}:
      when(SW, U32.is_gt(best, 0), \{
        True: bw.left1(c, ds, best, n, get(m, (c_o_w(c) + 1 : U32)))
        False: SW{m, n, 4, 0}
      })

def bw.store(+c: Ctx, +ds: U32, +len: U32, +to: U32, +n: U32, s: BB) -> Array<U32> & U32:
  match s:
    case BB{m, +best, mx}:
      sw.fin(bw.right(c, ds, len, to, best, bw.middle(c, ds, len, to, best,
        bw.left(c, ds, best, BB{m, best, mx}, n))))

def bw.split(+c: Ctx, +ds: U32, +len: U32, +to: U32, +n: U32, m: Array<U32>) -> Array<U32> & U32:
  bw.store(c, ds, len, to, n, bb.go(U32.to_nat((to + 1 : U32)), BB{m, 0, 0}, c, to, 0))

# CParser::compare_ranges_both_ways (ds = data start, rsl = left reference
# start, rer = right reference end, len = literal run); returns stack size
def both_ways(+c: Ctx, m: Array<U32>, +n: U32, +ds: U32, +rsl: U32, +rer: U32, +len: U32) -> Array<U32> & U32:
  +to = N.u32_if(U32.is_lt(rer, rsl), len, N.u32_min((rer - rsl : U32), len))
  +lim = N.u32_min(to, rer)
  ml = cw.fin(cwl.go(U32.to_nat(to), CW{U32.is_gt(to, 0), set(m, c_o_w(c), 0), 0, 0}, c, ds, rsl, to))
  mr = cw.fin(cwr.go(U32.to_nat(lim), CW{U32.is_ge(lim, 1), set(ml, (c_o_w(c) + c_mqd(c) + 2 : U32), 0), 1, 0},
    c, ds, rer, len, lim))
  bw.split(c, ds, len, to, n, zfill(U32.to_nat(N.u32_monus(to, lim)), mr,
    (c_o_w(c) + c_mqd(c) + 3 + lim : U32)))

# Distant-anchor bookkeeping
# ==========================

type MN is Type:
  MN{m: Array<U32>, n: U32, prs: U32}

type PG is Type:
  PG{go: Bool, m: Array<U32>, n: U32, acc: U32}

def pg.fin(s: PG) -> MN:
  match s:
    case PG{g, m, n, acc}:
      MN{m, n, acc}

def popge.k(+prs: U32, +n: U32, +acc: U32, q: Array<U32> & Fac) -> PG:
  (m, f) = q
  match f:
    case Fac{+pos, flag, len}:
      +pop = U32.is_ge(pos, prs)
      +n2 = (n - N.b2u(pop) : U32)
      PG{pop && U32.is_gt(n2, 0), m, n2, acc}

# pop while the top factor starts at or after prs
def popge.go(+fuel: Nat, s: PG, +c: Ctx, +prs: U32) -> PG:
  match fuel s:
    case _ PG{False{}, m, n, acc}:
      PG{False{}, m, n, acc}
    case 0n PG{True{}, m, n, acc}:
      PG{False{}, m, n, acc}
    case 1n+f PG{True{}, m, +n, +acc}:
      popge.go(f, popge.k(prs, n, acc, sget(c, m, (n - 1 : U32))), c, prs)

def poprun.k(+n: U32, +acc: U32, q: Array<U32> & Fac) -> PG:
  (m, f) = q
  match f:
    case Fac{pos, +flag, +len}:
      +pop = U32.is_eq(flag, F_RUN())
      +n2 = (n - N.b2u(pop) : U32)
      PG{pop && U32.is_gt(n2, 0), m, n2, N.u32_if(pop, (acc + len : U32), acc)}

# pop literal runs, adding their lengths to acc
def poprun.go(+fuel: Nat, s: PG, +c: Ctx) -> PG:
  match fuel s:
    case _ PG{False{}, m, n, acc}:
      PG{False{}, m, n, acc}
    case 0n PG{True{}, m, n, acc}:
      PG{False{}, m, n, acc}
    case 1n+f PG{True{}, m, +n, +acc}:
      poprun.go(f, poprun.k(n, acc, sget(c, m, (n - 1 : U32))), c)

def scand.k(+k: U32, +acc: U32, q: Array<U32> & Fac) -> PG:
  (m, f) = q
  match f:
    case Fac{+pos, +flag, len}:
      +hit = U32.is_eq(flag, F_DIST())
      PG{Bool.not(hit) && U32.is_gt(k, 0), m, (k - 1 : U32), N.u32_if(hit, pos, acc)}

# position of the topmost match_distant factor (acc stays INV if none)
def scand.go(+fuel: Nat, s: PG, +c: Ctx) -> PG:
  match fuel s:
    case _ PG{False{}, m, n, acc}:
      PG{False{}, m, n, acc}
    case 0n PG{True{}, m, n, acc}:
      PG{False{}, m, n, acc}
    case 1n+f PG{True{}, m, +k, +acc}:
      scand.go(f, scand.k(k, acc, sget(c, m, k)), c)

def dist.region3(+c: Ctx, +i: U32, s: MN) -> MN:
  match s:
    case MN{m, +n, +run}:
      MN{spush(c, m, n, (i - run : U32), F_RUN(), run), (n + 1 : U32), INV()}

def dist.region2(+c: Ctx, +i: U32, +prs: U32, s: MN) -> MN:
  match s:
    case MN{m, +n, x}:
      dist.region3(c, i, pg.fin(poprun.go(U32.to_nat(n),
        PG{U32.is_gt(n, 0), m, n, (i - prs : U32)}, c)))

# Remove a too-short previous region (eval_region false)
def dist.region(+c: Ctx, +i: U32, +pre: U32, s: MN) -> MN:
  match s:
    case MN{m, +n, +prs}:
      when(MN, U32.is_ne(prs, INV()) && (U32.is_lt(pre, prs)
          || U32.is_lt((pre - prs : U32), c_reg(c))), \{
        True: dist.region2(c, i, prs, pg.fin(popge.go(U32.to_nat(n),
          PG{U32.is_gt(n, 0), m, n, 0}, c, prs)))
        False: MN{m, n, prs}
      })

# after a successful backward extension of apx symbols
def dist.bw3(+i: U32, +apx: U32, +prs: U32, q: Array<U32> & U32) -> MN & U32:
  (m, +n) = q
  (MN{m, n, (i - apx : U32)}, F_CLOSE())

def dist.bw2(+c: Ctx, +i: U32, +bp: U32, +n: U32, +blen: U32, +prs: U32,
             q: Array<U32> & U32) -> MN & U32:
  (m, +apx) = q
  when(MN & U32, U32.is_gt(apx, 0), \{
    True: (
      +nl = (blen - apx : U32)
      +n2 = (n - N.b2u(U32.is_eq(nl, 0)) : U32)
      m2 = set_if(U32.is_gt(nl, 0), m, (c_o_f(c) + n + n - 1 : U32), (nl * 4 + F_RUN() : U32))
      dist.bw3(i, apx, prs, crange(c, m2, n2, (i - apx : U32), (bp - apx : U32), apx, True{})))
    False: (MN{m, n, prs}, F_DIST())
  })

def dist.bw1(+c: Ctx, +i: U32, +bp: U32, +n: U32, +prs: U32, q: Array<U32> & Fac) -> MN & U32:
  (m, f) = q
  match f:
    case Fac{pos, +flag, +len}:
      when(MN & U32, U32.is_eq(flag, F_RUN()), \{
        True: dist.bw2(c, i, bp, n, len, prs, xbwd(c, m, i, bp, len))
        False: (MN{m, n, prs}, F_DIST())
      })

# backward approximate extension over the pending literal run
def dist.bw(+c: Ctx, +i: U32, +bp: U32, s: MN) -> MN & U32:
  match s:
    case MN{m, +n, +prs}:
      when(MN & U32, U32.is_gt(n, 0), \{
        True: dist.bw1(c, i, bp, n, prs, sget(c, m, (n - 1 : U32)))
        False: (MN{m, n, prs}, F_DIST())
      })

def dist.scan2(+n: U32, g: PG) -> MN:
  match g:
    case PG{x, m, k, acc}:
      MN{m, n, acc}

def dist.scan(+c: Ctx, s: MN) -> MN:
  match s:
    case MN{m, +n, +prs}:
      when(MN, U32.is_eq(prs, INV()) && U32.is_gt(n, 0), \{
        True: dist.scan2(n, scand.go(U32.to_nat(n), PG{True{}, m, (n - 1 : U32), INV()}, c))
        False: MN{m, n, prs}
      })

def dist.push(+c: Ctx, +i: U32, +bl: U32, r: MN & U32) -> MN:
  (s, +flag) = r
  match s:
    case MN{m, +n, +prs}:
      dist.scan(c, MN{spush(c, m, n, i, flag, bl), (n + 1 : U32),
        N.u32_if(U32.is_eq(flag, F_DIST()), i, prs)})

# the match is not close to the prediction: start a new region
def distant(+c: Ctx, m: Array<U32>, +i: U32, +lit: U32, +prs: U32, +pre: U32, +n: U32,
            +bp: U32, +bl: U32) -> MN:
  +haslit = U32.is_gt(lit, 0)
  m1 = spush_if(haslit, c, m, n, (i - lit : U32), F_RUN(), lit)
  dist.push(c, i, bl, dist.bw(c, i, bp, dist.region(c, i, pre,
    MN{m1, (n + N.b2u(haslit) : U32), prs})))

def close_part(+c: Ctx, +i: U32, +bp: U32, +bl: U32, +prs: U32, q: Array<U32> & U32) -> MN:
  (m, +n) = q
  MN{spush(c, m, n, i, F_CLOSE(), bl), (n + 1 : U32), prs}

# Main parse loop
# ===============

type Sc is Data:
  Sc{i: U32, pred: U32, lit: U32, prs: U32, pre: U32, n: U32, has: Bool}

def mt.c(+i3: U32, +p3: U32, +prs: U32, q: Array<U32> & U32) -> Array<U32> & Sc:
  (m, +n) = q
  (m, Sc{i3, p3, 0, prs, i3, n, True{}})

def mt.b(+c: Ctx, +i2: U32, +p2: U32, +n: U32, +prs: U32, q: Array<U32> & U32) -> Array<U32> & Sc:
  (m, +ae) = q
  mt.c((i2 + ae : U32), (p2 + ae : U32), prs, crange(c, m, n, i2, p2, ae, False{}))

def mt.a(+c: Ctx, +i: U32, +bp: U32, +bl: U32, s: MN) -> Array<U32> & Sc:
  match s:
    case MN{m, +n, +prs}:
      +i2 = (i + bl : U32)
      +p2 = (bp + bl : U32)
      mt.b(c, i2, p2, n, prs, xfwd(c, m, i2, p2))

def matched.k(close: Bool, +c: Ctx, m: Array<U32>, +i: U32, +pred: U32, +lit: U32, +prs: U32,
              +pre: U32, +n: U32, +bp: U32, +bl: U32) -> Array<U32> & Sc:
  match close:
    case True{}:
      mt.a(c, i, bp, bl, close_part(c, i, bp, bl, prs,
        both_ways(c, m, n, (i - lit : U32), (pred - lit : U32), (bp + bl : U32), lit)))
    case False{}:
      mt.a(c, i, bp, bl, distant(c, m, i, lit, prs, pre, n, bp, bl))

def matched(+c: Ctx, m: Array<U32>, +sc: Sc, +bp: U32, +bl: U32) -> Array<U32> & Sc:
  match sc:
    case Sc{+i, +pred, +lit, +prs, +pre, +n, +has}:
      matched.k(has && U32.is_le(N.u32_dist(bp, pred), c_mrd(c)), c, m, i, pred, lit, prs, pre, n, bp, bl)

def literal(+c: Ctx, +sc: Sc) -> Sc:
  match sc:
    case Sc{+i, +pred, +lit, +prs, +pre, +n, +has}:
      +l2 = (lit + 1 : U32)
      Sc{(i + 1 : U32), (pred + 1 : U32), l2, prs, pre, n, has && U32.is_le(l2, c_mqd(c))}

def step.c(ok: Bool, +c: Ctx, m: Array<U32>, +sc: Sc, +bp: U32, +bl: U32) -> Array<U32> & Sc:
  match ok:
    case True{}:
      matched(c, m, sc, bp, bl)
    case False{}:
      (m, literal(c, sc))

def step.b(+c: Ctx, +sc: Sc, q: Array<U32> & Best) -> Array<U32> & Sc:
  (m, b) = q
  match b:
    case Best{+bp, +bl}:
      step.c(U32.is_ge(bl, c_msl(c)), c, m, sc, bp, bl)

# Literal fast path (no prediction): a literal step only advances i, pred
# and lit, so skip every position whose long k-mer key is absent from the
# reference table (those steps find no anchor).
type KK is Type:
  KK{go: Bool, m: Array<U32>, j: U32, hit: Bool}

def kk.k(+e: U32, +kv: U32, +j: U32, q: Array<U32> & U32) -> KK:
  (m, +key) = q
  +hit = U32.is_eq(key, kv)
  +j2 = (j + 1 : U32)
  KK{Bool.not(hit) && U32.is_lt(j2, e), m, j2, hit}

def kk.go(+fuel: Nat, s: KK, +ok: U32, +e: U32, +kv: U32) -> KK:
  match fuel s:
    case _ KK{False{}, m, j, hit}:
      KK{False{}, m, j, hit}
    case 0n KK{True{}, m, j, hit}:
      KK{False{}, m, j, hit}
    case 1n+f KK{True{}, m, +j, hit}:
      kk.go(f, kk.k(e, kv, j, get(m, (ok + j : U32))), ok, e, kv)

type SK is Type:
  SK{go: Bool, m: Array<U32>, i: U32}

def sk.d(+c: Ctx, +i: U32, s: KK) -> SK:
  match s:
    case KK{g, m, j, +hit}:
      +i2 = (i + 1 : U32)
      SK{Bool.not(hit) && U32.is_lt((i2 + c_msl(c) : U32), c_dlen(c)), m, N.u32_if(hit, i, i2)}

def sk.c(+c: Ctx, +i: U32, +kv: U32, +st: U32, q: Array<U32> & U32) -> SK:
  (m, +e) = q
  sk.d(c, i, kk.go(U32.to_nat(N.u32_monus(e, st)), KK{U32.is_lt(st, e), m, st, False{}}, c_o_lk(c), e, kv))

def sk.b(+c: Ctx, +i: U32, +kv: U32, +b: U32, q: Array<U32> & U32) -> SK:
  (m, +st) = q
  sk.c(c, i, kv, st, get(m, (c_o_lh(c) + b + 1 : U32)))

def sk.a(inv: Bool, +c: Ctx, +i: U32, +kv: U32, m: Array<U32>) -> SK:
  match inv:
    case True{}:
      +i2 = (i + 1 : U32)
      SK{U32.is_lt((i2 + c_msl(c) : U32), c_dlen(c)), m, i2}
    case False{}:
      +b = U32.and(hash(kv), c_lmask(c))
      sk.b(c, i, kv, b, get(m, (c_o_lh(c) + b : U32)))

def sk.k(+c: Ctx, +i: U32, q: Array<U32> & U32) -> SK:
  (m, +kv) = q
  sk.a(U32.is_eq(kv, INV()), c, i, kv, m)

def sk.go(+fuel: Nat, s: SK, +c: Ctx) -> SK:
  match fuel s:
    case _ SK{False{}, m, i}:
      SK{False{}, m, i}
    case 0n SK{True{}, m, i}:
      SK{False{}, m, i}
    case 1n+f SK{True{}, m, +i}:
      sk.go(f, sk.k(c, i, get(m, (c_o_dl(c) + i : U32))), c)

def step.skip(+c: Ctx, +sc: Sc, s: SK) -> Array<U32> & Sc:
  match sc s:
    case Sc{+i, +pred, +lit, +prs, +pre, +n, has} SK{g, m, +i2}:
      when(Array<U32> & Sc, U32.is_eq(i2, i), \{
        True: step.b(c, sc, lfind(c, m, i))
        False: (m, Sc{i2, (pred + i2 - i : U32), (lit + i2 - i : U32), prs, pre, n, False{}})
      })

def step.h(has: Bool, +c: Ctx, m: Array<U32>, +sc: Sc, +i: U32, +pred: U32, +lit: U32) -> Array<U32> & Sc:
  match has:
    case True{}:
      step.b(c, sc, find(c, m, i, True{}, pred, lit))
    case False{}:
      step.skip(c, sc, sk.go(U32.to_nat(c_dlen(c)), SK{True{}, m, i}, c))

def step(+c: Ctx, m: Array<U32>, +sc: Sc) -> Array<U32> & Sc:
  match sc:
    case Sc{+i, +pred, +lit, prs, pre, n, +has}:
      step.h(has, c, m, sc, i, pred, lit)

type PL is Type:
  PL{go: Bool, m: Array<U32>, sc: Sc}

def pl.next(+c: Ctx, q: Array<U32> & Sc) -> PL:
  (m, +sc) = q
  match sc:
    case Sc{+i, pred, lit, prs, pre, n, has}:
      PL{U32.is_lt((i + c_msl(c) : U32), c_dlen(c)), m, sc}

def pl.go(+fuel: Nat, s: PL, +c: Ctx) -> PL:
  match fuel s:
    case _ PL{False{}, m, sc}:
      PL{False{}, m, sc}
    case 0n PL{True{}, m, sc}:
      PL{False{}, m, sc}
    case 1n+f PL{True{}, m, +sc}:
      pl.go(f, pl.next(c, step(c, m, sc)), c)

def pl.fin(+c: Ctx, s: PL) -> Array<U32> & U32:
  match s:
    case PL{g, m, Sc{+i, +pred, +lit, prs, pre, +n, has}}:
      match has:
        case False{}:
          (spush(c, m, n, (i - lit : U32), F_RUN(), (lit + c_dlen(c) - i : U32)), (n + 1 : U32))
        case True{}:
          crange(c, m, n, (i - lit : U32), (pred - lit - c_msl(c) : U32),
            (lit + c_dlen(c) - i : U32), False{})

# calc_stats
# ==========

type Res is Data:
  Res{matches: U32, literals: U32, components: U32}

type ST is Type:
  ST{m: Array<U32>, cur: U32, curl: U32, nl: U32, tm: U32, tl: U32, tc: U32}

def st.k(+reg: U32, +cur: U32, +curl: U32, +nl: U32, +tm: U32, +tl: U32, +tc: U32,
         q: Array<U32> & U32) -> ST:
  (m, +w) = q
  +flag = U32.and(w, 3)
  +len = U32.shrn(w, 2n)
  +isd = U32.is_eq(flag, F_DIST())
  +isc = U32.is_eq(flag, F_CLOSE())
  +emit = isd && U32.is_gt(cur, 0) && U32.is_ge((cur + curl : U32), reg)
  ST{m, N.u32_if(isd, len, N.u32_if(isc, (cur + len : U32), cur)),
    N.u32_if(isd, 0, N.u32_if(isc, (curl + nl : U32), curl)),
    N.u32_if(isd || isc, 0, (nl + len : U32)),
    N.u32_if(emit, (tm + cur : U32), tm), N.u32_if(emit, (tl + curl : U32), tl),
    (tc + N.b2u(emit) : U32)}

def st.go(+fuel: Nat, s: ST, +c: Ctx, +k: U32) -> ST:
  match fuel s:
    case 0n ST{m, cur, curl, nl, tm, tl, tc}:
      ST{m, cur, curl, nl, tm, tl, tc}
    case 1n+f ST{m, +cur, +curl, +nl, +tm, +tl, +tc}:
      st.go(f, st.k(c_reg(c), cur, curl, nl, tm, tl, tc,
        get(m, (c_o_f(c) + k + k + 1 : U32))), c, (k + 1 : U32))

def st.fin(+reg: U32, s: ST) -> Array<U32> & Res:
  match s:
    case ST{m, +cur, +curl, nl, +tm, +tl, +tc}:
      +emit = U32.is_gt(cur, 0) && U32.is_ge((cur + curl : U32), reg)
      (m, Res{N.u32_if(emit, (tm + cur : U32), tm), N.u32_if(emit, (tl + curl : U32), tl),
        (tc + N.b2u(emit) : U32)})

def stats(+c: Ctx, q: Array<U32> & U32) -> Array<U32> & Res:
  (m, +n) = q
  st.fin(c_reg(c), st.go(U32.to_nat(n), ST{m, 0, 0, 0, 0, 0, 0}, c, 0))

# CParser::parse + calc_stats for the prepared query
def parse(+c: Ctx, m: Array<U32>) -> Array<U32> & Res:
  stats(c, pl.fin(c, pl.go(U32.to_nat((c_dlen(c) + 1 : U32)),
    PL{U32.is_lt(c_msl(c), c_dlen(c)), m, Sc{0, 0, 0, INV(), 0, 0, False{}}}, c)))

# Packed sequences (shared, read-only Data)
# =========================================
# 2-bit symbols, 16 per word, 64 per node, plus runs of non-ACGT symbols.

type Ws is Data:
  WsNil{}
  Ws4{a: U32, b: U32, c: U32, d: U32, tail: Ws}

type NRun is Data:
  NRNil{}
  NRCon{pos: U32, len: U32, tail: NRun}

type Seq is Data:
  Seq{len: U32, ws: Ws, nr: NRun}

def put16(+fuel: Nat, +w: U32, +at: U32, m: Array<U32>) -> Array<U32>:
  match fuel:
    case 0n:
      m
    case 1n+f:
      put16(f, U32.shrn(w, 2n), (at + 1 : U32), set(m, at, U32.and(w, 3)))

def unpack(ws: Ws, +at: U32, m: Array<U32>) -> Array<U32>:
  match ws:
    case WsNil{}:
      m
    case Ws4{+a, +b, +c, +d, tail}:
      unpack(tail, (at + 64 : U32), put16(16n, d, (at + 48 : U32),
        put16(16n, c, (at + 32 : U32), put16(16n, b, (at + 16 : U32), put16(16n, a, at, m)))))

def napply(nr: NRun, +at: U32, +v: U32, m: Array<U32>) -> Array<U32>:
  match nr:
    case NRNil{}:
      m
    case NRCon{+pos, +len, tail}:
      napply(tail, at, v, vfill(U32.to_nat(len), m, (at + pos : U32), v))

def comp(+b: U32) -> U32:
  N.u32_if(U32.is_lt(b, 4), (3 - b : U32), 4)

def rc.k(+dst: U32, q: Array<U32> & U32) -> Array<U32>:
  (m, +b) = q
  set(m, dst, comp(b))

# m[dst + j] = comp(m[src - j]) for j < fuel
def rc.go(+fuel: Nat, m: Array<U32>, +src: U32, +dst: U32) -> Array<U32>:
  match fuel:
    case 0n:
      m
    case 1n+f:
      rc.go(f, rc.k(dst, get(m, src)), (src - 1 : U32), (dst + 1 : U32))

def inc.k(+at: U32, q: Array<U32> & U32) -> Array<U32>:
  (m, +v) = q
  set(m, at, (v + 1 : U32))

def inc_if(c: Bool, m: Array<U32>, +at: U32) -> Array<U32>:
  match c:
    case True{}:
      inc.k(at, get(m, at))
    case False{}:
      m

def place.k(+oh: U32, +op: U32, +p: U32, q: Array<U32> & U32) -> Array<U32>:
  (m, +v) = q
  +v2 = (v - 1 : U32)
  set(set(m, oh, v2), (op + v2 : U32), p)

def place_if(c: Bool, m: Array<U32>, +oh: U32, +op: U32, +p: U32) -> Array<U32>:
  match c:
    case True{}:
      place.k(oh, op, p, get(m, oh))
    case False{}:
      m

# long table slot: position at lp, key at lk
def placek.k(+oh: U32, +op: U32, +ok: U32, +p: U32, +key: U32, q: Array<U32> & U32) -> Array<U32>:
  (m, +v) = q
  +v2 = (v - 1 : U32)
  set(set(set(m, oh, v2), (op + v2 : U32), p), (ok + v2 : U32), key)

def placek_if(c: Bool, m: Array<U32>, +oh: U32, +op: U32, +ok: U32, +p: U32, +key: U32) -> Array<U32>:
  match c:
    case True{}:
      placek.k(oh, op, ok, p, key, get(m, oh))
    case False{}:
      m

# rolling k-mers right-to-left: kmer at p covers p .. p + k - 1
type KS is Type:
  KS{m: Array<U32>, kl: U32, ks: U32, run: U32}

type K3 is Data:
  K3{kl: U32, ks: U32, run: U32}

def kroll(+c: Ctx, +kl: U32, +ks: U32, +run: U32, +b: U32) -> K3:
  +b3 = U32.and(b, 3)
  K3{U32.or(U32.shrn(kl, 2n), U32.shln(b3, U32.to_nat((c_mal(c) + c_mal(c) - 2 : U32)))),
    U32.or(U32.shrn(ks, 2n), U32.shln(b3, U32.to_nat((c_msl(c) + c_msl(c) - 2 : U32)))),
    N.u32_if(U32.is_lt(b, 4), (run + 1 : U32), 0)}

def kc.k2(+c: Ctx, +p: U32, place: Bool, m: Array<U32>, k: K3) -> KS:
  match place k:
    case True{} K3{+kl2, +ks2, +run2}:
      +hl = (c_o_lh(c) + U32.and(hash(kl2), c_lmask(c)) : U32)
      +hs = (c_o_sh(c) + ks2 : U32)
      KS{place_if(U32.is_ge(run2, c_msl(c)), placek_if(U32.is_ge(run2, c_mal(c)), m, hl, c_o_lp(c), c_o_lk(c), p, kl2),
        hs, c_o_sp(c), p), kl2, ks2, run2}
    case False{} K3{+kl2, +ks2, +run2}:
      +hl = (c_o_lh(c) + U32.and(hash(kl2), c_lmask(c)) : U32)
      +hs = (c_o_sh(c) + ks2 : U32)
      KS{inc_if(U32.is_ge(run2, c_msl(c)), inc_if(U32.is_ge(run2, c_mal(c)), m, hl), hs), kl2, ks2, run2}

def kc.k(+c: Ctx, +p: U32, +place: Bool, q: Array<U32> & U32, +kl: U32, +ks: U32, +run: U32) -> KS:
  (m, +b) = q
  kc.k2(c, p, place, m, kroll(c, kl, ks, run, b))

# count (place = False) or place (place = True) every valid reference k-mer
def kc.go(+fuel: Nat, s: KS, +c: Ctx, +p: U32, +place: Bool) -> KS:
  match fuel s:
    case 0n KS{m, kl, ks, run}:
      KS{m, kl, ks, run}
    case 1n+f KS{m, +kl, +ks, +run}:
      kc.go(f, kc.k(c, p, place, get(m, (c_o_r(c) + p : U32)), kl, ks, run), c, (p - 1 : U32), place)

def ks.fin(s: KS) -> Array<U32>:
  match s:
    case KS{m, kl, ks, run}:
      m

def pfx.k(+at: U32, +acc: U32, q: Array<U32> & U32) -> Array<U32> & U32:
  (m, +v) = q
  +a2 = (acc + v : U32)
  (set(m, at, a2), a2)

# inclusive prefix sums over fuel slots, then slot[fuel] = total
def pfx.go(+fuel: Nat, q: Array<U32> & U32, +at: U32) -> Array<U32>:
  match fuel:
    case 0n:
      (m, +acc) = q
      set(m, at, acc)
    case 1n+f:
      (m, +acc) = q
      pfx.go(f, pfx.k(at, acc, get(m, at)), (at + 1 : U32))

def dblput(m: Array<U32>, +at: U32, d: N.Dbl) -> Array<U32>:
  match d:
    case N.Dbl{+e, +hi, +lo}:
      set(set(set(m, at, e), (at + 1 : U32), hi), (at + 2 : U32), lo)

# anchor_prob for La = mal + k
def atab(+fuel: Nat, m: Array<U32>, +c: Ctx, +k: U32) -> Array<U32>:
  match fuel:
    case 0n:
      m
    case 1n+f:
      +la = (c_mal(c) + k : U32)
      atab(f, dblput(m, (c_o_at(c) + 3 * k : U32),
        N.chance(la, (2 * (c_rlen(c) + 1 - la) : U32))), c, (k + 1 : U32))

def lcopy(xs: List<&2, U32>, +at: U32, m: Array<U32>) -> Array<U32>:
  match xs:
    case Nil{}:
      m
    case Con{+x, rest}:
      lcopy(rest, (at + 1 : U32), set(m, at, x))

def dbl_cons(d: N.Dbl, tail: List<&2, U32>) -> List<&2, U32>:
  match d:
    case N.Dbl{+e, +hi, +lo}:
      e <> hi <> lo <> tail

# close_prob table, row-major (Lc - msl, lit), 3 words each
def ctab.lit(+fuel: Nat, +cl: U32, +lit: U32, +mrd: U32, tail: List<&2, U32>) -> List<&2, U32>:
  match fuel:
    case 0n:
      tail
    case 1n+f:
      dbl_cons(N.chance(cl, (lit + mrd + 1 - cl : U32)), ctab.lit(f, cl, (lit + 1 : U32), mrd, tail))

def ctab.go(+fuel: Nat, +cl: U32, +mqd: U32, +mrd: U32) -> List<&2, U32>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+f:
      ctab.lit(U32.to_nat((mqd + 1 : U32)), cl, 0, mrd, ctab.go(f, (cl + 1 : U32), mqd, mrd))

def close_table(+msl: U32, +mqd: U32, +mrd: U32) -> List<&2, U32>:
  ctab.go(U32.to_nat(N.u32_monus(27, msl)), msl, mqd, mrd)

# LZ-ANI parameters
type Prm is Data:
  Prm{mal: U32, msl: U32, mrd: U32, mqd: U32, reg: U32, aw: U32, am: U32, ar: U32}

# region layout for a reference of length L and queries up to qmax
def layout(+p: Prm, +len: U32, +qmax: U32) -> Ctx & Nat:
  match p:
    case Prm{+mal, +msl, +mrd, +mqd, +reg, +aw, +am, +ar}:
      +rlen = (len + len + 3 * mrd : U32)
      +nb = U32.shln(1, N.depth(N.u32_max(rlen, 1)))
      +ns = U32.shln(1, U32.to_nat((msl + msl : U32)))
      +o_lh = (rlen + 64 : U32)
      +o_lp = (o_lh + nb + 1 : U32)
      +o_lk = (o_lp + rlen : U32)
      +o_sh = (o_lk + rlen : U32)
      +o_sp = (o_sh + ns + 1 : U32)
      +o_at = (o_sp + rlen : U32)
      +o_ct = (o_at + 96 : U32)
      +o_d = (o_ct + 3 * N.u32_monus(27, msl) * (mqd + 1) + 8 : U32)
      +dmax = (qmax + mrd : U32)
      +o_dl = (o_d + dmax + 64 : U32)
      +o_ds = (o_dl + dmax : U32)
      +o_f = (o_ds + dmax : U32)
      +o_w = (o_f + 2 * dmax + 32 : U32)
      +total = (o_w + 2 * mqd + 16 : U32)
      (Ctx{0, rlen, o_lh, (nb - 1 : U32), o_lp, o_lk, o_sh, o_sp, o_at, o_ct, o_d, 0,
        o_dl, o_ds, o_f, o_w, mal, msl, mrd, mqd, reg, aw, am, ar, [1]}, N.depth(total))

# CParser::prepare_reference: forward, 2 * mrd N, reverse complement, mrd N;
# then both k-mer tables and the anchor probabilities.
def prep_ref(+c: Ctx, m: Array<U32>, +s: Seq, +ct: List<&2, U32>) -> Array<U32>:
  match s:
    case Seq{+len, ws, nr}:
      +mrd = c_mrd(c)
      +o = c_o_r(c)
      m1 = vfill(U32.to_nat((2 * mrd : U32)), napply(nr, o, 4, unpack(ws, o, m)), (o + len : U32), 4)
      m2 = vfill(U32.to_nat(mrd), rc.go(U32.to_nat(len), m1, (o + len - 1 : U32), (o + len + 2 * mrd : U32)),
        (o + len + len + 2 * mrd : U32), 4)
      +rl = c_rlen(c)
      m3 = ks.fin(kc.go(U32.to_nat(rl), KS{m2, 0, 0, 0}, c, (rl - 1 : U32), False{}))
      m4 = pfx.go(U32.to_nat((c_lmask(c) + 1 : U32)), (m3, 0), c_o_lh(c))
      m5 = pfx.go(U32.to_nat(U32.shln(1, U32.to_nat((c_msl(c) + c_msl(c) : U32)))), (m4, 0), c_o_sh(c))
      m6 = ks.fin(kc.go(U32.to_nat(rl), KS{m5, 0, 0, 0}, c, (rl - 1 : U32), True{}))
      lcopy(ct, c_o_ct(c), atab(U32.to_nat(N.u32_monus(27, c_mal(c))), m6, c, 0))

def dk.k2(+c: Ctx, +p: U32, m: Array<U32>, k: K3) -> KS:
  match k:
    case K3{+kl2, +ks2, +run2}:
      KS{set(set(m, (c_o_dl(c) + p : U32),
          N.u32_if(U32.is_ge(run2, c_mal(c)), kl2, INV())),
          (c_o_ds(c) + p : U32), N.u32_if(U32.is_ge(run2, c_msl(c)), ks2, INV())),
        kl2, ks2, run2}

def dk.k(+c: Ctx, +p: U32, q: Array<U32> & U32, +kl: U32, +ks: U32, +run: U32) -> KS:
  (m, +b) = q
  dk.k2(c, p, m, kroll(c, kl, ks, run, b))

def dk.go(+fuel: Nat, s: KS, +c: Ctx, +p: U32) -> KS:
  match fuel s:
    case 0n KS{m, kl, ks, run}:
      KS{m, kl, ks, run}
    case 1n+f KS{m, +kl, +ks, +run}:
      dk.go(f, dk.k(c, p, get(m, (c_o_d(c) + p : U32)), kl, ks, run), c, (p - 1 : U32))

# CParser::prepare_data: query, mrd N; then its k-mers (bucket ids / values)
def prep_data(+c: Ctx, m: Array<U32>, +s: Seq) -> Array<U32>:
  match s:
    case Seq{+len, ws, nr}:
      +o = c_o_d(c)
      m1 = vfill(U32.to_nat(c_mrd(c)), napply(nr, o, 5, unpack(ws, o, m)), (o + len : U32), 5)
      ks.fin(dk.go(U32.to_nat(c_dlen(c)), KS{m1, 0, 0, 0}, c, (c_dlen(c) - 1 : U32)))

# Work units
# ==========

type Job is Data:
  Job{slot: U32, q: Seq}

type Out is Data:
  ONil{}
  OCon{slot: U32, res: Res, tail: Out}
  ONode{l: Out, r: Out}

def jobs_qmax(js: List<&2, Job>, +acc: U32) -> U32:
  match js:
    case Nil{}:
      acc
    case Con{Job{s, Seq{+len, w, r}}, rest}:
      jobs_qmax(rest, N.u32_max(acc, len))

def seq_len(+s: Seq) -> U32:
  match s:
    case Seq{len, w, r}:
      len

def run.k(+slot: U32, acc: Out, q: Array<U32> & Res) -> Array<U32> & Out:
  (m, +r) = q
  (m, OCon{slot, r, acc})

def run_jobs(js: List<&2, Job>, +c: Ctx, q: Array<U32> & Out) -> Out:
  match js:
    case Nil{}:
      (m, acc) = q
      acc
    case Con{Job{+slot, +qs}, rest}:
      (m, acc) = q
      +c2 = ctx_dlen(c, (seq_len(qs) + c_mrd(c) : U32))
      run_jobs(rest, c, run.k(slot, acc, parse(c2, prep_data(c2, m, qs))))

def run_unit2(js: List<&2, Job>, +ct: List<&2, U32>, +r: Seq, cd: Ctx & Nat) -> Out:
  (+c, +d) = cd
  run_jobs(js, c, (prep_ref(c, Array.new(U32, d, 0), r, ct), ONil{}))

# one work unit: a reference and some of its partners
def run_unit(+p: Prm, +ct: List<&2, U32>, +r: Seq, +js: List<&2, Job>) -> Out:
  run_unit2(js, ct, r, layout(p, seq_len(r), jobs_qmax(js, 0)))

def prm_msl(+p: Prm) -> U32:
  match p:
    case Prm{mal, msl, mrd, mqd, reg, aw, am, ar}:
      msl

def prm_mqd(+p: Prm) -> U32:
  match p:
    case Prm{mal, msl, mrd, mqd, reg, aw, am, ar}:
      mqd

def prm_mrd(+p: Prm) -> U32:
  match p:
    case Prm{mal, msl, mrd, mqd, reg, aw, am, ar}:
      mrd
