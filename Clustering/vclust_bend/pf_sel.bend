# --max-seqs: Kmer-db's per-row Sampler (strategy "best", criterion
# ani-shorter).
#
# Every pair (b, a) passing the num-kmers and ani-shorter filters is offered
# to row b (item a) and to row a (item b). A row keeps its N best items,
# ordered by ani-shorter (descending) then item index (ascending), which is
# the order Sampler's heap retains; it prints them by item index. The score
# is compared exactly as the rational c / m (c shared k-mers, m the smaller
# k-mer count): ani-shorter is increasing in it, and distinct rationals with
# m < 2^24 give distinct binary64 scores.
import Base
import ./pf_fasta.bend as F
import ./pf_num.bend as N
import ./pf_core.bend as K

# Row lists hold 4 words per candidate: a, c, m, x (see K.fr_keep).

def cnt_row(xs: List<&2, U32>, +b: U32, cnt: Array<U32>) -> Array<U32>:
  match xs:
    case Con{+a, Con{+c, Con{+mn, Con{+x, t}}}}:
      cnt_row(t, b, K.bump((a + 1 : U32), 1, K.bump((b + 1 : U32), 1, cnt)))
    case _:
      cnt

def cnt_rows(rows: List<&2, List<&2, U32>>, +b: U32, cnt: Array<U32>) -> Array<U32>:
  match rows:
    case Nil{}:
      cnt
    case Con{r, t}:
      cnt_rows(t, (b + 1 : U32), cnt_row(r, b, cnt))

type SE is Type:
  SE{cur: Array<U32>, e: Array<U32>}

def se_put(e: Array<U32>, +row: U32, +it: U32, +c: U32, +mn: U32, +x: U32, r: Array<U32> & U32) -> SE:
  (cur, +pos) = r
  SE{cur[row] <- (pos + 1 : U32), K.rec_put(e, pos, it, c, mn, x)}

def se_add(+row: U32, +it: U32, +c: U32, +mn: U32, +x: U32, st: SE) -> SE:
  SE{cur, e} = st
  se_put(e, row, it, c, mn, x, cur[row])

def sc_row(xs: List<&2, U32>, +b: U32, st: SE) -> SE:
  match xs:
    case Con{+a, Con{+c, Con{+mn, Con{+x, t}}}}:
      sc_row(t, b, se_add(a, b, c, mn, x, se_add(b, a, c, mn, x, st)))
    case _:
      st

def sc_rows(rows: List<&2, List<&2, U32>>, +b: U32, st: SE) -> SE:
  match rows:
    case Nil{}:
      st
    case Con{r, t}:
      sc_rows(t, (b + 1 : U32), sc_row(r, b, st))

# better(n, o): c_n / m_n > c_o / m_o, or equal and item_n < item_o
def better(+ni: U32, +nc: U32, +nm: U32, +oi: U32, +oc: U32, +om: U32) -> Bool:
  +l = N.mul32(nc, om)
  +r = N.mul32(oc, nm)
  N.lt64(r, l) || (N.eq64(l, r) && U32.is_lt(ni, oi))

# Top-N buffer t (records sorted best first), tn records.
type TS is Type:
  TS{t: Array<U32>, +tn: U32}

# Shift worse records down to make room for the new one at pos.
type SH is Type:
  SH{t: Array<U32>, +pos: U32, +go: Bool}

def sh_move(mv: Bool, +pos: U32, o: K.R4A) -> SH:
  match mv:
    case True{}:
      K.R4A{t, +o0, +o1, +o2, +o3} = o
      SH{K.rec_put(t, pos, o0, o1, o2, o3), (pos - 1 : U32), True{}}
    case False{}:
      K.R4A{t, o0, o1, o2, o3} = o
      SH{t, pos, False{}}

def sh_cmp(+it: U32, +c: U32, +mn: U32, +pos: U32, o: K.R4A) -> SH:
  K.R4A{t, +o0, +o1, +o2, +o3} = o
  sh_move(better(it, c, mn, o0, o1, o2), pos, K.R4A{t, o0, o1, o2, o3})

def sh_step(+it: U32, +c: U32, +mn: U32, st: SH) -> SH:
  SH{t, +pos, +go} = st
  match go:
    case True{}:
      sh_cmp(it, c, mn, pos, K.rec_get(t, (pos - 1 : U32)))
    case False{}:
      SH{t, pos, False{}}

def sh_go(n: Nat, +it: U32, +c: U32, +mn: U32, st: SH) -> SH:
  match n:
    case 0n:
      st
    case 1n+p:
      sh_go(p, it, c, mn, sh_step(it, c, mn, st))

def sh_fin(+it: U32, +c: U32, +mn: U32, +x: U32, +tn: U32, +nmax: U32, st: SH) -> TS:
  SH{t, +pos, go} = st
  TS{K.rec_put(t, pos, it, c, mn, x), U32.min((tn + 1 : U32), nmax)}

def ts_ins(+it: U32, +c: U32, +mn: U32, +x: U32, +tn: U32, +nmax: U32, t: Array<U32>) -> TS:
  +pos = U32.min(tn, (nmax - 1 : U32))
  sh_fin(it, c, mn, x, tn, nmax, sh_go(U32.to_nat(pos), it, c, mn, SH{t, pos, True{}}))

def ts_keep(ok: Bool, +it: U32, +c: U32, +mn: U32, +x: U32, +tn: U32, +nmax: U32, t: Array<U32>) -> TS:
  match ok:
    case True{}:
      ts_ins(it, c, mn, x, tn, nmax, t)
    case False{}:
      TS{t, tn}

def ts_full(full: Bool, +it: U32, +c: U32, +mn: U32, +x: U32, +tn: U32, +nmax: U32, o: K.R4A) -> TS:
  match full:
    case True{}:
      K.R4A{t, +o0, +o1, +o2, +o3} = o
      ts_keep(better(it, c, mn, o0, o1, o2), it, c, mn, x, tn, nmax, t)
    case False{}:
      K.R4A{t, o0, o1, o2, o3} = o
      ts_ins(it, c, mn, x, tn, nmax, t)


# One row: the records [i, end) of e through the top-N buffer.
type RW is Type:
  RW{e: Array<U32>, t: Array<U32>, +tn: U32, +i: U32}

def rw_fin(e: Array<U32>, +i: U32, ts: TS) -> RW:
  TS{t, +tn} = ts
  RW{e, t, tn, (i + 1 : U32)}

def rw_e(t: Array<U32>, +tn: U32, +i: U32, +nmax: U32, r: K.R4A) -> RW:
  K.R4A{e, +it, +c, +mn, +x} = r
  rw_fin(e, i, ts_full(U32.is_eq(tn, nmax), it, c, mn, x, tn, nmax, K.rec_get(t, (nmax - 1 : U32))))

def rw_step(+nmax: U32, st: RW) -> RW:
  RW{e, t, +tn, +i} = st
  rw_e(t, tn, i, nmax, K.rec_get(e, i))

def rw_go(n: Nat, +nmax: U32, st: RW) -> RW:
  match n:
    case 0n:
      st
    case 1n+p:
      rw_go(p, nmax, rw_step(nmax, st))

# The kept records t[0..tn), by item, as output text.
type EO is Type:
  EO{t: Array<U32>, out: List<&2, U32>, +j: U32}

def eo_r(out: List<&2, U32>, +j: U32, r: K.R4A) -> EO:
  K.R4A{t, +it, +c, +mn, +x} = r
  EO{t, K.put_entry((it + 1 : U32), x, out), j}

def eo_step(st: EO) -> EO:
  EO{t, out, +j0} = st
  +j = (j0 - 1 : U32)
  eo_r(out, j, K.rec_get(t, j))

def eo_go(n: Nat, st: EO) -> EO:
  match n:
    case 0n:
      st
    case 1n+p:
      eo_go(p, eo_step(st))

type RO is Type:
  RO{e: Array<U32>, t: Array<U32>, out: List<&2, U32>}

def ro_of(e: Array<U32>, st: EO) -> RO:
  EO{t, out, j} = st
  RO{e, t, out}

def row_sorted(e: Array<U32>, +tn: U32, t: Array<U32>) -> RO:
  ro_of(e, eo_go(U32.to_nat(tn), EO{t, Nil{}, tn}))

def row_done(st: RW) -> RO:
  RW{e, t, +tn, i} = st
  row_sorted(e, tn, K.rs_go(U32.to_nat(K.sel(U32.is_gt(tn, 1), (tn - 1 : U32), 0)), 1, 0, t))

def row_select(+start: U32, +end: U32, +nmax: U32, e: Array<U32>, t: Array<U32>) -> RO:
  row_done(rw_go(U32.to_nat((end - start : U32)), nmax, RW{e, t, 0, start}))

# All rows, last to first.
type RA is Type:
  RA{e: Array<U32>, t: Array<U32>, st: Array<U32>, cur: Array<U32>, rows: List<&2, List<&2, U32>>, +r: U32}

def ra_fin(st: Array<U32>, cur: Array<U32>, rows: List<&2, List<&2, U32>>, +r: U32, ro: RO) -> RA:
  RO{e, t, out} = ro
  RA{e, t, st, cur, Con{out, rows}, r}

def ra_swap(e: Array<U32>, t: Array<U32>, cur: Array<U32>, rows: List<&2, List<&2, U32>>, +r: U32, +nmax: U32,
            +end: U32, q: Array<U32> & U32) -> RA:
  (st, +start) = q
  ra_fin(st, cur, rows, r, row_select(start, end, nmax, e, t))

def ra_1(e: Array<U32>, t: Array<U32>, st: Array<U32>, rows: List<&2, List<&2, U32>>, +r: U32, +nmax: U32,
         q: Array<U32> & U32) -> RA:
  (cur, +end) = q
  ra_swap(e, t, cur, rows, r, nmax, end, st[r])

def ra_step(+nmax: U32, s: RA) -> RA:
  RA{e, t, st, cur, rows, +r0} = s
  +r = (r0 - 1 : U32)
  ra_1(e, t, st, rows, r, nmax, cur[r])

def ra_go(n: Nat, +nmax: U32, s: RA) -> RA:
  match n:
    case 0n:
      s
    case 1n+p:
      ra_go(p, nmax, ra_step(nmax, s))

def ra_rows(s: RA) -> List<&2, List<&2, U32>>:
  RA{e, t, st, cur, rows, r} = s
  rows

def sel_scattered(+n: U32, +nmax: U32, st: Array<U32>, se: SE) -> List<&2, List<&2, U32>>:
  SE{cur, e} = se
  ra_rows(ra_go(U32.to_nat(n), nmax,
    RA{e, K.arr_new(U32.shln(nmax, 2n)), st, cur, Nil{}, n}))

def sel_copied(+n: U32, +total: U32, +nmax: U32, rows: List<&2, List<&2, U32>>,
               r: Array<U32> & Array<U32>) -> List<&2, List<&2, U32>>:
  (st, cur) = r
  sel_scattered(n, nmax, st, sc_rows(rows, 0, SE{cur, K.arr_new(U32.shln(total, 2n))}))

def sel_total(+n: U32, +nmax: U32, +rows: List<&2, List<&2, U32>>, r: Array<U32> & U32) -> List<&2, List<&2, U32>>:
  (st, +total) = r
  sel_copied(n, total, nmax, rows, F.copy((n + 1 : U32), 0, 0, st, K.arr_new((n + 1 : U32))))

# rows: the n candidate rows (in row order); nmax = --max-seqs.
def select(+n: U32, +nmax: U32, +rows: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  st = K.prefix((n + 1 : U32), cnt_rows(rows, 0, K.arr_new((n + 1 : U32))))
  sel_total(n, nmax, rows, st[n])
