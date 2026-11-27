# Kmer-db 2.3.1 all2all-sp (SimilarityCalculator::all2all_sp, the
# SparseMatrix of array.h and CBubbleHelper of bubble_helper.h).
#
#   decompress thread -> decode_chunk: patterns in id order, samples decoded
#                     through the parent chain (decode_pattern_samples) into
#                     a buffer of cacheBufferMb (8 MB) of ids; a pattern
#                     with num_samples >= bubble size (8000) becomes a
#                     bubble (CBubbleHelper::add); a full buffer goes to the
#                     workers while the next one is decoded (a parallel call
#                     here; the barrier pair upstream).
#   worker t          -> work_chunk: the rows with row_id mod 2T in
#                     {t, 2T-1-t}; for every pattern and every owned position
#                     j, matrix[pat[j]][pat[k]] += num_kmers for k < j; a row
#                     is a hash_map_lp<uint32_t, uint32_t> (SparseMatrix with
#                     SparseMatrix_CUSTOM_HASH_MAP).
#   compact2 / add_to_sampler -> row_out: bubble adders (get_adders), then the
#                     entries passing the filter (num-kmers, ani-shorter),
#                     sorted by column.
#
# The buffer is read by every worker. Bend has no shared mutable arrays, so
# each worker receives its own copy (Array.clone): the same O(T x buffer)
# reads as the upstream workers' scans of the shared buffer.
import Base
import ./pf_fasta.bend as F
import ./pf_num.bend as N
import ./kdb_util.bend as K
import ./kdb_sort.bend as S
import ./kdb_hash.bend as H
import ./kdb_db.bend as D

# SparseMatrix<uint32_t> row: hash_map_lp<uint32_t, uint32_t>::empty_value
def ev() -> U32:
  4294967295

def row_hm(t: D.PT) -> H.HM:
  match t:
    case D.PLeaf{h}:
      h
    case D.PNil{}:
      H.hm_new(ev())
    case D.PNode{l, r}:
      H.hm_new(ev())

# Decoding patterns
# =================

# Local samples of one pattern: buf[pos - 1], buf[pos - 2], ... from its
# last node backwards (pattern_t::decodeSamples fills the run from the end).
type DL is Type:
  DL{nod: Array<U32>, buf: Array<U32>, +node: U32, +pos: U32, +off: U32}

def dl_b(buf: Array<U32>, +pos: U32, +smp: U32, +off: U32, r: Array<U32> & U32) -> DL:
  (nod, +prev) = r
  DL{nod, buf[pos] <- (smp + off : U32), prev, pos, off}

def dl_a(buf: Array<U32>, +node: U32, +pos: U32, +off: U32, r: Array<U32> & U32) -> DL:
  (nod, +smp) = r
  dl_b(buf, (pos - 1 : U32), smp, off, nod[(U32.shln(node, 1n) + 1 : U32)])

def dl_go(f: Nat, st: DL) -> DL:
  match f st:
    case 0n _:
      st
    case 1n+q DL{nod, buf, +node, +pos, +off}:
      dl_go(q, dl_a(buf, node, pos, off, nod[U32.shln(node, 1n)]))

# decode_pattern_samples: the chain from pattern cur up to the root,
# filling buf[.. out) downwards.
type DW is Type:
  DW{pat: Array<U32>, nod: Array<U32>, buf: Array<U32>, +cur: U32, +out: U32, +off: U32}

def dw_d(+nl: U32, +out: U32, dl: DL, r: Array<U32> & U32) -> DW:
  DL{nod, buf, node, pos, +off} = dl
  (pat, +par) = r
  DW{pat, nod, buf, par, (out - nl : U32), off}

def dw_c(nod: Array<U32>, buf: Array<U32>, +cur: U32, +out: U32, +off: U32, +nl: U32, r: Array<U32> & U32) -> DW:
  (pat, +head) = r
  dw_d(nl, out, dl_go(U32.to_nat(nl), DL{nod, buf, head, out, off}), D.pget(pat, cur, 1))

def dw_b(nod: Array<U32>, buf: Array<U32>, +cur: U32, +out: U32, +off: U32, r: Array<U32> & U32) -> DW:
  (pat, +nl) = r
  dw_c(nod, buf, cur, out, off, nl, D.pget(pat, cur, 4))

def dw_s(stop: Bool, pat: Array<U32>, nod: Array<U32>, buf: Array<U32>, +cur: U32, +out: U32, +off: U32) -> DW:
  match stop:
    case True{}:
      DW{pat, nod, buf, cur, out, off}
    case False{}:
      dw_b(nod, buf, cur, out, off, D.pget(pat, cur, 3))

def dw_go(f: Nat, st: DW) -> DW:
  match f st:
    case 0n _:
      st
    case 1n+q DW{pat, nod, buf, +cur, +out, +off}:
      dw_go(q, dw_s(U32.is_eq(cur, K.none()), pat, nod, buf, cur, out, off))

# Bubbles
# =======

type BB is Data:
  BB{+nk: U32, ids: List<&2, U32>, cols: List<&2, U32>}

type BL is Type:
  BL{buf: Array<U32>, ids: List<&2, U32>, +i: U32}

def bl_r(ids: List<&2, U32>, +i: U32, r: Array<U32> & U32) -> BL:
  (buf, +v) = r
  BL{buf, Con{v, ids}, i}

def bl_go(f: Nat, st: BL) -> BL:
  match f st:
    case 0n _:
      st
    case 1n+q BL{buf, ids, +i}:
      +j = (i - 1 : U32)
      bl_go(q, bl_r(ids, j, buf[j]))

# Decoder
# =======

# The database patterns and the next pattern id; the bubbles (reversed).
type DS is Type:
  DS{pat: Array<U32>, nod: Array<U32>, +np: U32, +p: U32, +off: U32, bubs: List<&2, BB>}

# A decoded chunk: ids and the list of its patterns (meta: num_kmers,
# num_samples, offset).
type CH is Type:
  CH{buf: Array<U32>, meta: Array<U32>, +nm: U32}

type DC is Type:
  DC{ds: DS, ch: CH, +bp: U32, +go: Bool}

def dc_bub2(pat: Array<U32>, nod: Array<U32>, +np: U32, +off: U32, +p: U32, bubs: List<&2, BB>, meta: Array<U32>,
            +nm: U32, +bp: U32, +nk: U32, bl: BL) -> DC:
  BL{buf, ids, i} = bl
  DC{DS{pat, nod, np, (p + 1 : U32), off, Con{BB{nk, ids, Nil{}}, bubs}}, CH{buf, meta, nm}, bp, True{}}

def dc_bubble(isb: Bool, pat: Array<U32>, nod: Array<U32>, +np: U32, +off: U32, +p: U32, bubs: List<&2, BB>,
              buf: Array<U32>, +bp: U32, meta: Array<U32>, +nm: U32, +nk: U32, +ns: U32) -> DC:
  match isb:
    case True{}:
      dc_bub2(pat, nod, np, off, p, bubs, meta, nm, bp, nk, bl_go(U32.to_nat(ns), BL{buf, Nil{}, (bp + ns : U32)}))
    case False{}:
      +o = U32.mul(nm, 3)
      m1 = meta[o] <- nk
      m2 = m1[(o + 1 : U32)] <- ns
      DC{DS{pat, nod, np, (p + 1 : U32), off, bubs}, CH{buf, m2[(o + 2 : U32)] <- bp, (nm + 1 : U32)},
         (bp + ns : U32), True{}}

def dc_decoded(bubs: List<&2, BB>, meta: Array<U32>, +np: U32, +off: U32, +p: U32, +bp: U32, +nm: U32, +nk: U32,
               +ns: U32, +bubble: U32, dw: DW) -> DC:
  DW{pat, nod, buf, cur, out, off2} = dw
  dc_bubble(U32.is_ge(ns, bubble), pat, nod, np, off, p, bubs, buf, bp, meta, nm, nk, ns)

def dc_fits(full: Bool, pat: Array<U32>, nod: Array<U32>, +np: U32, +off: U32, +p: U32, bubs: List<&2, BB>,
            buf: Array<U32>, +bp: U32, meta: Array<U32>, +nm: U32, +nk: U32, +ns: U32, +bubble: U32) -> DC:
  match full:
    case True{}:
      DC{DS{pat, nod, np, p, off, bubs}, CH{buf, meta, nm}, bp, False{}}
    case False{}:
      dc_decoded(bubs, meta, np, off, p, bp, nm, nk, ns, bubble,
        dw_go(U32.to_nat((ns + 1 : U32)), DW{pat, nod, buf, p, (bp + ns : U32), off}))

def dc_ns(nod: Array<U32>, +np: U32, +off: U32, +p: U32, bubs: List<&2, BB>, buf: Array<U32>, +bp: U32,
          meta: Array<U32>, +nm: U32, +nk: U32, +bsize: U32, +bubble: U32, r: Array<U32> & U32) -> DC:
  (pat, +ns) = r
  dc_fits(U32.is_ge((bp + ns : U32), bsize), pat, nod, np, off, p, bubs, buf, bp, meta, nm, nk, ns, bubble)

def dc_nk(nod: Array<U32>, +np: U32, +off: U32, +p: U32, bubs: List<&2, BB>, buf: Array<U32>, +bp: U32,
          meta: Array<U32>, +nm: U32, +bsize: U32, +bubble: U32, r: Array<U32> & U32) -> DC:
  (pat, +nk) = r
  dc_ns(nod, np, off, p, bubs, buf, bp, meta, nm, nk, bsize, bubble, D.pget(pat, p, 2))

def dc_step(go: Bool, ds: DS, ch: CH, +bp: U32, +bsize: U32, +bubble: U32) -> DC:
  match go:
    case True{}:
      DS{pat, nod, +np, +p, +off, bubs} = ds
      CH{buf, meta, +nm} = ch
      dc_nk(nod, np, off, p, bubs, buf, bp, meta, nm, bsize, bubble, D.pget(pat, p, 0))
    case False{}:
      DC{ds, ch, bp, False{}}

def ds_more(ds: DS) -> DS & Bool:
  DS{pat, nod, +np, +p, +off, bubs} = ds
  (DS{pat, nod, np, p, off, bubs}, U32.is_lt(p, np))

def dc_more(ch: CH, +bp: U32, +go: Bool, r: DS & Bool) -> DC:
  (ds, +more) = r
  DC{ds, ch, bp, go && more}

def dc_again(st: DC) -> DC:
  DC{ds, ch, +bp, +go} = st
  dc_more(ch, bp, go, ds_more(ds))

def dc_go(f: Nat, +bsize: U32, +bubble: U32, st: DC) -> DC:
  match f st:
    case 0n _:
      st
    case 1n+q DC{ds, ch, +bp, +go}:
      match go:
        case True{}:
          dc_go(q, bsize, bubble, dc_again(dc_step(True{}, ds, ch, bp, bsize, bubble)))
        case False{}:
          DC{ds, ch, bp, False{}}

def dc_fin(st: DC) -> CH & DS:
  DC{ds, ch, bp, go} = st
  (ch, ds)

# the next buffer of decoded patterns (bsize ids; bubbles set aside)
def decode_chunk(+bsize: U32, +bubble: U32, ds: DS) -> CH & DS:
  dc_fin(dc_go(U32.to_nat((bsize + 2 : U32)), bsize, bubble,
    dc_more(CH{Array.new(U32, F.depth(bsize), 0), Array.new(U32, F.depth(U32.mul((bsize + 2 : U32), 3)), 0), 0},
      0, True{}, ds_more(ds))))

# Workers
# =======

# matrix[row] += num_kmers for the ids buf[off .. off + j)
type KK is Type:
  KK{buf: Array<U32>, hm: H.HM, +k: U32}

def kk_s(+nk: U32, +k: U32, hm: H.HM, r: Array<U32> & U32) -> KK:
  (buf, +id) = r
  KK{buf, H.add(id, nk, ev(), hm), (k + 1 : U32)}

def kk_go(f: Nat, +nk: U32, st: KK) -> KK:
  match f st:
    case 0n _:
      st
    case 1n+q KK{buf, hm, +k}:
      kk_go(q, nk, kk_s(nk, k, hm, buf[k]))

type WJ is Type:
  WJ{buf: Array<U32>, rows: Array<D.PT>, +j: U32}

def wj_kk(rows: Array<D.PT>, +li: U32, +j: U32, st: KK) -> WJ:
  KK{buf, hm, k} = st
  WJ{buf, Array.set(D.PT, rows, li, D.PLeaf{hm}), (j + 1 : U32)}

def wj_row(buf: Array<U32>, +li: U32, +j: U32, +nk: U32, +off: U32, r: Array<D.PT> & D.PT) -> WJ:
  (rows, t) = r
  wj_kk(rows, li, j, kk_go(U32.to_nat((j - off : U32)), nk, KK{buf, row_hm(t), off}))

def wj_own(own: Bool, +first: Bool, buf: Array<U32>, rows: Array<D.PT>, +id: U32, +j: U32, +nk: U32,
           +off: U32, +w2: U32) -> WJ:
  match own:
    case True{}:
      +li = (U32.shln(U32.div(id, w2), 1n) + K.sel(first, 0, 1) : U32)
      wj_row(buf, li, j, nk, off, Array.swap(D.PT, rows, li, D.PNil{}))
    case False{}:
      WJ{buf, rows, (j + 1 : U32)}

def wj_s(+w: U32, +w2: U32, +nk: U32, +off: U32, rows: Array<D.PT>, +j: U32, r: Array<U32> & U32) -> WJ:
  (buf, +id) = r
  +m = U32.mod(id, w2)
  +first = U32.is_eq(m, w)
  wj_own(first || U32.is_eq(m, (w2 - 1 - w : U32)), first, buf, rows, id, j, nk, off, w2)

# positions j of one pattern (absolute: off .. off + cnt)
def wj_go(f: Nat, +w: U32, +w2: U32, +nk: U32, +off: U32, st: WJ) -> WJ:
  match f st:
    case 0n _:
      st
    case 1n+q WJ{buf, rows, +j}:
      wj_go(q, w, w2, nk, off, wj_s(w, w2, nk, off, rows, j, buf[j]))

type WE is Type:
  WE{buf: Array<U32>, meta: Array<U32>, rows: Array<D.PT>, +e: U32}

def we_fin(meta: Array<U32>, +e: U32, st: WJ) -> WE:
  WJ{buf, rows, j} = st
  WE{buf, meta, rows, (e + 1 : U32)}

def we_3(buf: Array<U32>, rows: Array<D.PT>, +w: U32, +w2: U32, +e: U32, +nk: U32, +cnt: U32,
         r: Array<U32> & U32) -> WE:
  (meta, +off) = r
  we_fin(meta, e, wj_go(U32.to_nat(cnt), w, w2, nk, off, WJ{buf, rows, off}))

def we_2(buf: Array<U32>, rows: Array<D.PT>, +w: U32, +w2: U32, +e: U32, +nk: U32, r: Array<U32> & U32) -> WE:
  (meta, +cnt) = r
  we_3(buf, rows, w, w2, e, nk, cnt, meta[(U32.mul(e, 3) + 2 : U32)])

def we_1(buf: Array<U32>, rows: Array<D.PT>, +w: U32, +w2: U32, +e: U32, r: Array<U32> & U32) -> WE:
  (meta, +nk) = r
  we_2(buf, rows, w, w2, e, nk, meta[(U32.mul(e, 3) + 1 : U32)])

def we_go(f: Nat, +w: U32, +w2: U32, st: WE) -> WE:
  match f st:
    case 0n _:
      st
    case 1n+q WE{buf, meta, rows, +e}:
      we_go(q, w, w2, we_1(buf, rows, w, w2, e, meta[U32.mul(e, 3)]))

def we_rows(st: WE) -> Array<D.PT>:
  WE{buf, meta, rows, e} = st
  rows

# The workers as a balanced tree of leaves (worker id, its rows).
type WT is Type:
  WLeaf{+w: U32, rows: Array<D.PT>}
  WNode{l: WT, r: WT}

def ch_split(+nm: U32, a: Array<U32> & Array<U32>, b: Array<U32> & Array<U32>) -> CH & CH:
  (a1, a2) = a
  (b1, b2) = b
  (CH{a1, b1, nm}, CH{a2, b2, nm})

def ch_clone(ch: CH) -> CH & CH:
  CH{buf, meta, +nm} = ch
  ch_split(nm, Array.clone(U32, buf), Array.clone(U32, meta))

def work_leaf(+w: U32, rows: Array<D.PT>, +w2: U32, ch: CH) -> WT:
  CH{buf, meta, +nm} = ch
  WLeaf{w, we_rows(we_go(U32.to_nat(nm), w, w2, WE{buf, meta, rows, 0}))}

def work(wt: WT, +w2: U32, ch: CH) -> WT:
  match wt:
    case WLeaf{+w, rows}:
      work_leaf(w, rows, w2, ch)
    case WNode{l, r}:
      K.apply(CH & CH, WT, \{Tuple: c1 => c2 => (
        a b = work(l, w2, c1) work(r, w2, c2)
        WNode{a, b}
      )}, ch_clone(ch))

# the rows of worker w: local index 2 (id / 2W) + (0 | 1)
def rows_new(+d: Nat) -> Array<D.PT>:
  match d:
    case 0n:
      ALeaf{D.PNil{}}
    case 1n+p:
      ANode{rows_new(p), rows_new(p)}

# workers lo .. lo + cnt - 1 (cnt <= 2^d)
def wt_new(+d: Nat, one: Bool, +lo: U32, +cnt: U32, +rd: Nat) -> WT:
  match d one:
    case 0n _:
      WLeaf{lo, rows_new(rd)}
    case 1n+p True{}:
      WLeaf{lo, rows_new(rd)}
    case 1n+p False{}:
      +nl = U32.shrn((cnt + 1 : U32), 1n)
      +nr = (cnt - nl : U32)
      WNode{wt_new(p, U32.is_le(nl, 1), lo, nl, rd), wt_new(p, U32.is_le(nr, 1), (lo + nl : U32), nr, rd)}

# Main loop: work on one buffer while the next one is decoded
# ===========================================================

type AL is Type:
  AL{wt: WT, ch: CH, ds: DS, +go: Bool}

def al_pair(wt: WT, r: CH & DS) -> AL:
  (ch, ds) = r
  AL{wt, ch, ds, True{}}

def ch_empty() -> CH:
  CH{[0 : U32*1n], [0 : U32*1n], 0}

def al_step(more: Bool, +w2: U32, +bsize: U32, +bubble: U32, wt: WT, ch: CH, ds: DS) -> AL:
  match more:
    case True{}:
      a b = work(wt, w2, ch) decode_chunk(bsize, bubble, ds)
      al_pair(a, b)
    case False{}:
      AL{work(wt, w2, ch), ch_empty(), ds, False{}}

def al_go(f: Nat, +w2: U32, +bsize: U32, +bubble: U32, st: AL) -> AL:
  match f st:
    case 0n _:
      st
    case 1n+q AL{wt, ch, ds, +go}:
      match go:
        case True{}:
          K.apply(DS & Bool, AL, \{Tuple: ds2 => +more => (
            al_go(q, w2, bsize, bubble, al_step(more, w2, bsize, bubble, wt, ch, ds2))
          )}, ds_more(ds))
        case False{}:
          AL{wt, ch, ds, False{}}

type AR is Type:
  AR{wt: WT, pat: Array<U32>, nod: Array<U32>, bubs: List<&2, BB>}

def al_fin(st: AL) -> AR:
  AL{wt, ch, ds, go} = st
  DS{pat, nod, np, p, off, bubs} = ds
  AR{wt, pat, nod, bubs}

def al_start(wt: WT, +w2: U32, +bsize: U32, +bubble: U32, +np: U32, r: CH & DS) -> AR:
  (ch, ds) = r
  al_fin(al_go(U32.to_nat((np + 2 : U32)), w2, bsize, bubble, AL{wt, ch, ds, True{}}))

# all2all_sp over the patterns of the database: W workers (rows mod 2W),
# buffer of bsize ids, bubble size threshold.
def all2all_sp(pat: Array<U32>, nod: Array<U32>, +np: U32, +n: U32, +w: U32, +bsize: U32, +bubble: U32) -> AR:
  +w2 = U32.shln(w, 1n)
  +rd = F.depth((U32.shln(U32.div((n + w2 : U32), w2), 1n) + 2 : U32))
  al_start(wt_new(F.depth(w), U32.is_le(w, 1), 0, w, rd), w2, bsize, bubble, np,
    decode_chunk(bsize, bubble, DS{pat, nod, np, 0, 0, Nil{}}))

# all2all_sp of one database into existing worker rows (all2all-parts: the
# diagonal cell of a row part); sample ids are shifted by off.
def a2a_on(wt: WT, pat: Array<U32>, nod: Array<U32>, +np: U32, +off: U32, +w2: U32, +bsize: U32, +bubble: U32,
           bubs: List<&2, BB>) -> AR:
  al_start(wt, w2, bsize, bubble, np, decode_chunk(bsize, bubble, DS{pat, nod, np, 0, off, bubs}))

# Output: compact2 / add_to_sampler
# =================================

# Filter (CombinedFilter: num-kmers >= mink, ani-shorter >= t) and output
# form: text entries "<a+1>:<value>," or raw (a, c, m, x) words for the
# --max-seqs sampler.
type OP is Data:
  OP{+mink: U32, +k: U32, +tone: Bool, +tfx: N.W2, +raw: Bool}

# Bubble presence (CBubbleHelper::presence1) and the bubbles.
type BX is Type:
  BXNone{}
  BXSome{pres: Array<List<&2, U32>>, tab: Array<BB>}

type RL is Data:
  RLNil{}
  RLCon{+r: U32, row: List<&2, U32>, t: RL}

# one worker leaf for the output: its rows, the sample k-mer counts, bubbles
type OT is Type:
  OLeaf{+w: U32, rows: Array<D.PT>, cnt: Array<U32>, bx: BX}
  ONode{l: OT, r: OT}

# entries of a row: collect the used slots, sort by column
type CO is Type:
  CO{a: Array<U32>, out: Array<U32>, +i: U32, +m: U32}

def co_s(out: Array<U32>, +i: U32, +m: U32, g: S.A2) -> CO:
  S.A2{a, +key, +v} = g
  K.when(CO, U32.is_eq(v, ev()), \{
    True: CO{a, out, (i + 1 : U32), m}
    False: CO{a, S.put2(out, m, key, v), (i + 1 : U32), (m + 1 : U32)}
  })

def co_go(f: Nat, st: CO) -> CO:
  match f st:
    case 0n _:
      st
    case 1n+q CO{a, out, +i, +m}:
      co_go(q, co_s(out, i, m, S.get2(a, i)))

def co_fin(st: CO) -> S.AN:
  CO{a, out, i, +m} = st
  S.AN{S.sort2(m, out), m}

# the (column, count) entries of a row table, sorted by column
def collect(h: H.HM) -> S.AN:
  H.HM{+filled, +cap, a} = h
  co_fin(co_go(U32.to_nat(cap), CO{a, K.arr_new(U32.shln(U32.max(filled, 1), 1n)), 0, 0}))

# get_adders: for each bubble holding row i, += num_kmers for its ids < i
def bub_ids(ids: List<&2, U32>, +i: U32, +nk: U32, h: H.HM) -> H.HM:
  match ids:
    case Nil{}:
      h
    case Con{+id, t}:
      K.when(H.HM, U32.is_lt(id, i), \{
        True: bub_ids(t, i, nk, H.add(id, nk, ev(), h))
        False: h
      })

# db2db-sp mode (ids2 not empty): += num_kmers for every column
def bub_cols(cs: List<&2, U32>, +nk: U32, h: H.HM) -> H.HM:
  match cs:
    case Nil{}:
      h
    case Con{+c, t}:
      bub_cols(t, nk, H.add(c, nk, ev(), h))

def bub_one(+i: U32, h: H.HM, r: Array<BB> & BB) -> Array<BB> & H.HM:
  (tab, b) = r
  BB{+nk, ids, cols} = b
  match cols:
    case Nil{}:
      (tab, bub_ids(ids, i, nk, h))
    case Con{c, t}:
      (tab, bub_cols(Con{c, t}, nk, h))

def bub_list(bl: List<&2, U32>, +i: U32, tab: Array<BB>, h: H.HM) -> Array<BB> & H.HM:
  match bl:
    case Nil{}:
      (tab, h)
    case Con{+b, t}:
      K.apply(Array<BB> & H.HM, Array<BB> & H.HM, \{Tuple: tab2 => h2 => (
        bub_list(t, i, tab2, h2)
      )}, bub_one(i, h, Array.get(BB, tab, b)))

def bub_got(tab: Array<BB>, +i: U32, h: H.HM, r: Array<List<&2, U32>> & List<&2, U32>) -> BX & H.HM:
  (pres, bl) = r
  K.apply(Array<BB> & H.HM, BX & H.HM, \{Tuple: tab2 => h2 => (
    (BXSome{pres, tab2}, h2)
  )}, bub_list(bl, i, tab, h))

def bubbles(bx: BX, +i: U32, h: H.HM) -> BX & H.HM:
  match bx:
    case BXNone{}:
      (BXNone{}, h)
    case BXSome{pres, tab}:
      bub_got(tab, i, h, Array.get(List<&2, U32>, pres, i))

# Row entries, last to first, consed in front (so in column order).
type EM is Type:
  EM{es: Array<U32>, cnt: Array<U32>, row: List<&2, U32>, +e: U32}

def em_ani(+a: U32, +c: U32, +mn: U32, +tone: Bool, +tfx: N.W2, +raw: Bool, +an: N.Ani, row: List<&2, U32>) -> List<&2, U32>:
  K.fr_keep(N.ani_ge(an, tone, tfx), raw, a, c, mn, N.ani_x(an), row)

# c == 0 (patterns left without k-mers): ani-shorter is 0 (d_jaccard == 0);
# kept only by the sampler path (distance drops common == 0).
def em_val(+a: U32, +c: U32, +mn: U32, +op: OP, row: List<&2, U32>) -> List<&2, U32>:
  OP{+mink, +k, +tone, +tfx, +raw} = op
  K.when(List<&2, U32>, U32.is_eq(c, 0), \{
    True: K.fr_keep(raw && U32.is_eq(mink, 0) && Bool.not(tone) && N.eq64(tfx, N.W2{0, 0}), raw, a, 0, mn, 0, row)
    False: K.when(List<&2, U32>, U32.is_ge(c, mink), \{
      True: em_ani(a, c, mn, tone, tfx, raw, N.ani(c, mn, k), row)
      False: row
    })
  })

def em_c(es: Array<U32>, row: List<&2, U32>, +e: U32, +a: U32, +c: U32, +ub: U32, +op: OP, r: Array<U32> & U32) -> EM:
  (cnt, +ua) = r
  EM{es, cnt, em_val(a, c, U32.min(ua, ub), op, row), e}

def em_s(cnt: Array<U32>, row: List<&2, U32>, +e: U32, +ub: U32, +op: OP, g: S.A2) -> EM:
  S.A2{es, +a, +c} = g
  em_c(es, row, e, a, c, ub, op, cnt[a])

def em_go(f: Nat, +ub: U32, +op: OP, st: EM) -> EM:
  match f st:
    case 0n _:
      st
    case 1n+q EM{es, cnt, row, +e0}:
      +e = (e0 - 1 : U32)
      em_go(q, ub, op, em_s(cnt, row, e, ub, op, S.get2(es, e)))

def em_fin(st: EM) -> Array<U32> & List<&2, U32>:
  EM{es, cnt, row, e} = st
  (cnt, row)

def row_emit(cnt: Array<U32>, +ub: U32, +op: OP, an: S.AN) -> Array<U32> & List<&2, U32>:
  S.AN{es, +m} = an
  em_fin(em_go(U32.to_nat(m), ub, op, EM{es, cnt, Nil{}, m}))

def row_cnt(+op: OP, h: H.HM, r: Array<U32> & U32) -> Array<U32> & List<&2, U32>:
  (cnt, +ub) = r
  row_emit(cnt, ub, op, collect(h))

# one output row (its table is released)
type RO is Type:
  RO{rows: Array<D.PT>, cnt: Array<U32>, bx: BX, row: List<&2, U32>}

def ro_b(rows: Array<D.PT>, bx: BX, r: Array<U32> & List<&2, U32>) -> RO:
  (cnt, row) = r
  RO{rows, cnt, bx, row}

def ro_a(rows: Array<D.PT>, cnt: Array<U32>, +i: U32, +op: OP, r: BX & H.HM) -> RO:
  (bx, h) = r
  ro_b(rows, bx, row_cnt(op, h, cnt[i]))

def row_out(cnt: Array<U32>, bx: BX, +i: U32, +op: OP, r: Array<D.PT> & D.PT) -> RO:
  (rows, t) = r
  ro_a(rows, cnt, i, op, bubbles(bx, i, row_hm(t)))

# Rows of a block [r0, r1) owned by worker w, consed from the last.
type OB is Type:
  OB{rows: Array<D.PT>, cnt: Array<U32>, bx: BX, acc: RL, +r: U32}

def ob_ro(+r: U32, acc: RL, ro: RO) -> OB:
  RO{rows, cnt, bx, row} = ro
  OB{rows, cnt, bx, RLCon{r, row, acc}, r}

def ob_s(+w: U32, +w2: U32, +op: OP, rows: Array<D.PT>, cnt: Array<U32>, bx: BX, acc: RL, +r: U32) -> OB:
  +m = U32.mod(r, w2)
  +first = U32.is_eq(m, w)
  K.when(OB, first || U32.is_eq(m, (w2 - 1 - w : U32)), \{
    True: ob_ro(r, acc, row_out(cnt, bx, r, op,
      Array.swap(D.PT, rows, (U32.shln(U32.div(r, w2), 1n) + K.sel(first, 0, 1) : U32), D.PNil{})))
    False: OB{rows, cnt, bx, acc, r}
  })

def ob_go(f: Nat, +w: U32, +w2: U32, +op: OP, st: OB) -> OB:
  match f st:
    case 0n _:
      st
    case 1n+q OB{rows, cnt, bx, acc, +r0}:
      ob_go(q, w, w2, op, ob_s(w, w2, op, rows, cnt, bx, acc, (r0 - 1 : U32)))

def ob_fin(+w: U32, st: OB) -> OT & RL:
  OB{rows, cnt, bx, acc, r} = st
  (OLeaf{w, rows, cnt, bx}, acc)

def rl_merge(a: RL, b: RL) -> RL:
  match a b:
    case RLNil{} _:
      b
    case RLCon{+ra, xa, ta} RLNil{}:
      RLCon{ra, xa, ta}
    case RLCon{+ra, xa, ta} RLCon{+rb, xb, tb}:
      K.when(RL, U32.is_lt(ra, rb), \{
        True: RLCon{ra, xa, rl_merge(ta, RLCon{rb, xb, tb})}
        False: RLCon{rb, xb, rl_merge(RLCon{ra, xa, ta}, tb)}
      })

def ot_join(a: OT & RL, b: OT & RL) -> OT & RL:
  (ta, la) = a
  (tb, lb) = b
  (ONode{ta, tb}, rl_merge(la, lb))

# the rows [r0, r1) of every worker, in row order
def out_block(ot: OT, +r0: U32, +r1: U32, +w2: U32, +op: OP) -> OT & RL:
  match ot:
    case OLeaf{+w, rows, cnt, bx}:
      ob_fin(w, ob_go(U32.to_nat((r1 - r0 : U32)), w, w2, op, OB{rows, cnt, bx, RLNil{}, r1}))
    case ONode{l, r}:
      a b = out_block(l, r0, r1, w2, op) out_block(r, r0, r1, w2, op)
      ot_join(a, b)

# Bubbles and output tree
# =======================

type BT is Type:
  BT{pres: Array<List<&2, U32>>, tab: Array<BB>, +b: U32}

def bp_cons(+b: U32, +id: U32, r: Array<List<&2, U32>> & List<&2, U32>) -> Array<List<&2, U32>>:
  (pres, l) = r
  Array.set(List<&2, U32>, pres, id, Con{b, l})

def bp_ids(ids: List<&2, U32>, +b: U32, pres: Array<List<&2, U32>>) -> Array<List<&2, U32>>:
  match ids:
    case Nil{}:
      pres
    case Con{+id, t}:
      bp_ids(t, b, bp_cons(b, id, Array.get(List<&2, U32>, pres, id)))

# bubbles in descending id order (the decoder's list): presence lists end
# up ascending, as CBubbleHelper::add appends them
def bt_go(bs: List<&2, BB>, st: BT) -> BT:
  match bs st:
    case Nil{} _:
      st
    case Con{BB{+nk, +ids, +cols}, t} BT{pres, tab, +b0}:
      +b = (b0 - 1 : U32)
      bt_go(t, BT{bp_ids(ids, b, pres), Array.set(BB, tab, b, BB{nk, ids, cols}), b})

def list_len(xs: List<&2, BB>, +n: U32) -> U32:
  match xs:
    case Nil{}:
      n
    case Con{h, t}:
      list_len(t, (n + 1 : U32))

def bt_fin(st: BT) -> BX:
  BT{pres, tab, b} = st
  BXSome{pres, tab}

def bx_of(+n: U32, +nb: U32, bs: List<&2, BB>) -> BX:
  K.when(BX, U32.is_eq(nb, 0), \{
    True: BXNone{}
    False: bt_fin(bt_go(bs, BT{Array.new(List<&2, U32>, F.depth(n), Nil{}),
      Array.new(BB, F.depth(nb), BB{0, Nil{}, Nil{}}), nb}))
  })

def bx_pair(a: Array<List<&2, U32>> & Array<List<&2, U32>>, b: Array<BB> & Array<BB>) -> BX & BX:
  (a1, a2) = a
  (b1, b2) = b
  (BXSome{a1, b1}, BXSome{a2, b2})

def bx_clone(bx: BX) -> BX & BX:
  match bx:
    case BXNone{}:
      (BXNone{}, BXNone{})
    case BXSome{pres, tab}:
      bx_pair(Array.clone(List<&2, U32>, pres), Array.clone(BB, tab))

def ot_of(wt: WT, cnt: Array<U32>, bx: BX) -> OT:
  match wt:
    case WLeaf{+w, rows}:
      OLeaf{w, rows, cnt, bx}
    case WNode{l, r}:
      K.apply(Array<U32> & Array<U32>, OT, \{Tuple: c1 => c2 => (
        K.apply(BX & BX, OT, \{Tuple: x1 => x2 => (
          ONode{ot_of(l, c1, x1), ot_of(r, c2, x2)}
        )}, bx_clone(bx))
      )}, Array.clone(U32, cnt))

# the workers' rows ready for output, with the counts and the bubbles
def out_tree(+n: U32, ar: AR, cnt: Array<U32>) -> OT:
  AR{wt, pat, nod, +bubs} = ar
  ot_of(wt, cnt, bx_of(n, list_len(bubs, 0), bubs))

def out_tree2(+n: U32, wt: WT, +bubs: List<&2, BB>, cnt: Array<U32>) -> OT:
  ot_of(wt, cnt, bx_of(n, list_len(bubs, 0), bubs))
