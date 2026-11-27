# kmer-db all2all-parts (console_all2all_parts.cpp, SimilarityCalculator::
# db2db_sp), as Vclust runs it with --batch-size B: the input is split into
# parts of B records (mfasta-tool split), each part gets its own database
# (kmer-db build), then row part i is compared with every part j < i
# (db2db_sp) and with itself (all2all_sp), and its rows are written.
#
# Upstream keeps the part databases on disk (deserialised with
# CompactedHashtables for the columns); here they stay in memory as the
# compacted form: per part the (prefix, suffix) records in k-mer order with
# their pattern ids (suffix_kmers sorted by suffix within each prefix,
# prefixes ascending) and the patterns.
#
# The cells of a row part accumulate into the same worker rows, keyed by
# global sample ids (upstream: one SparseMatrix per cell, each compacted,
# filtered and concatenated in column order): the filter is per entry and the
# cells' columns are disjoint, so the rows are the same.
import Base
import ./pf_fasta.bend as F
import ./pf_num.bend as N
import ./kdb_util.bend as K
import ./kdb_sort.bend as S
import ./kdb_hash.bend as H
import ./kdb_db.bend as D
import ./kdb_a2a.bend as A
import ./kdb_extract.bend as X
import ./kdb_build.bend as B

# Compaction of a database (CompactedHashtables)
# ==============================================

def pt_filled(t: D.PT) -> D.PT & U32:
  match t:
    case D.PLeaf{h}:
      H.HM{+f, +c, a} = h
      (D.PLeaf{H.HM{f, c, a}}, f)
    case D.PNil{}:
      (D.PNil{}, 0)
    case D.PNode{l, r}:
      (D.PNode{l, r}, 0)

def tab_count(t: Array<D.PT>) -> Array<D.PT> & U32:
  match t:
    case ALeaf{x}:
      K.apply(D.PT & U32, Array<D.PT> & U32, \{Tuple: x2 => +c => ((ALeaf{x2}, c))}, pt_filled(x))
    case ANode{l, r}:
      K.apply(Array<D.PT> & U32, Array<D.PT> & U32, \{Tuple: l2 => +a => (
        K.apply(Array<D.PT> & U32, Array<D.PT> & U32, \{Tuple: r2 => +b => (
          (ANode{l2, r2}, (a + b : U32))
        )}, tab_count(r))
      )}, tab_count(l))

# the k-mers of one table appended to (ka: (prefix, suffix), pa: pattern id)
type CA is Type:
  CA{ka: Array<U32>, pa: Array<U32>, +n: U32}

type CT is Type:
  CT{es: Array<U32>, ca: CA, +i: U32}

def ct_s(ca: CA, +pre: U32, +i: U32, g: S.A2) -> CT:
  CA{ka, pa, +n} = ca
  S.A2{es, +suf, +pid} = g
  CT{es, CA{S.put2(ka, n, pre, suf), pa[n] <- pid, (n + 1 : U32)}, (i + 1 : U32)}

def ct_go(f: Nat, +pre: U32, st: CT) -> CT:
  match f st:
    case 0n _:
      st
    case 1n+q CT{es, ca, +i}:
      ct_go(q, pre, ct_s(ca, pre, i, S.get2(es, i)))

def ct_fin(st: CT) -> CA:
  CT{es, ca, i} = st
  ca

# the used slots (suffix, pattern id) of a table, sorted by suffix
type CO is Type:
  CO{a: Array<U32>, out: Array<U32>, +i: U32, +m: U32}

def co_s(out: Array<U32>, +i: U32, +m: U32, g: S.A2) -> CO:
  S.A2{a, +key, +v} = g
  K.when(CO, U32.is_eq(v, D.ev()), \{
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

def collect_pid(h: H.HM) -> S.AN:
  H.HM{+filled, +cap, a} = h
  co_fin(co_go(U32.to_nat(cap), CO{a, K.arr_new(U32.shln(U32.max(filled, 1), 1n)), 0, 0}))

def leaf_sorted(+pre: U32, ca: CA, an: S.AN) -> CA:
  S.AN{es, +m} = an
  ct_fin(ct_go(U32.to_nat(m), pre, CT{es, ca, 0}))

def leaf_comp(+pre: U32, x: D.PT, ca: CA) -> CA:
  match x:
    case D.PLeaf{h}:
      H.HM{+f, +c, a} = h
      leaf_sorted(pre, ca, collect_pid(H.HM{f, c, a}))
    case D.PNil{}:
      ca
    case D.PNode{l, r}:
      ca

# prefixes in increasing order (base = first prefix of the subtree)
def tab_comp(t: Array<D.PT>, +d: Nat, +base: U32, ca: CA) -> CA:
  match t d:
    case ALeaf{x} _:
      leaf_comp(base, x, ca)
    case ANode{l, r} 0n:
      ca
    case ANode{l, r} 1n+p:
      tab_comp(r, p, (base + K.shl(1, U32.from_nat(p)) : U32), tab_comp(l, p, base, ca))

# A part: its first global sample, size, patterns, compacted k-mers.
type PR is Type:
  PR{+o: U32, +b: U32, pat: Array<U32>, +np: U32, nod: Array<U32>, ka: Array<U32>, pa: Array<U32>, +nk: U32}

def pr_fin(+o: U32, +b: U32, pat: Array<U32>, +np: U32, nod: Array<U32>, +nk: U32, ca: CA) -> PR:
  CA{ka, pa, n} = ca
  PR{o, b, pat, np, nod, ka, pa, nk}

def pr_comp(+o: U32, +b: U32, pt: D.PS, +pb: U32, r: Array<D.PT> & U32) -> PR:
  D.PS{pat, +np, +pcap, nod, +nn, +ncap} = pt
  (tab, +nk) = r
  pr_fin(o, b, pat, np, nod, nk, tab_comp(tab, U32.to_nat(pb), 0,
    CA{K.arr_new(U32.shln(U32.max(nk, 1), 1n)), K.arr_new(U32.max(nk, 1)), 0}))


# db2db_sp: matching k-mers of two parts
# ======================================

# merge of the two sorted k-mer lists: (pattern id in R, pattern id in C)
type MJ is Type:
  MJ{ka1: Array<U32>, pa1: Array<U32>, ka2: Array<U32>, pa2: Array<U32>, m: Array<U32>,
     +i1: U32, +i2: U32, +nm: U32, +go: Bool}

def mj_eq(ka1: Array<U32>, ka2: Array<U32>, pa2: Array<U32>, m: Array<U32>, +i1: U32, +i2: U32, +nm: U32,
          +n1: U32, +n2: U32, +x: U32, r: Array<U32> & U32) -> MJ:
  (pa1, +y) = r
  +j1 = (i1 + 1 : U32)
  +j2 = (i2 + 1 : U32)
  MJ{ka1, pa1, ka2, pa2, S.put2(m, nm, y, x), j1, j2, (nm + 1 : U32), U32.is_lt(j1, n1) && U32.is_lt(j2, n2)}

def mj_e2(ka1: Array<U32>, pa1: Array<U32>, ka2: Array<U32>, m: Array<U32>, +i1: U32, +i2: U32, +nm: U32,
          +n1: U32, +n2: U32, r: Array<U32> & U32) -> MJ:
  (pa2, +x) = r
  mj_eq(ka1, ka2, pa2, m, i1, i2, nm, n1, n2, x, pa1[i1])

def mj_c(ka1: Array<U32>, pa1: Array<U32>, ka2: Array<U32>, pa2: Array<U32>, m: Array<U32>, +i1: U32, +i2: U32,
         +nm: U32, +n1: U32, +n2: U32, +h1: U32, +l1: U32, +h2: U32, +l2: U32) -> MJ:
  K.when(MJ, U32.is_eq(h1, h2) && U32.is_eq(l1, l2), \{
    True: mj_e2(ka1, pa1, ka2, m, i1, i2, nm, n1, n2, pa2[i2])
    False: K.when(MJ, S.lt2(h1, l1, h2, l2), \{
      True: MJ{ka1, pa1, ka2, pa2, m, (i1 + 1 : U32), i2, nm, U32.is_lt((i1 + 1 : U32), n1)}
      False: MJ{ka1, pa1, ka2, pa2, m, i1, (i2 + 1 : U32), nm, U32.is_lt((i2 + 1 : U32), n2)}
    })
  })

def mj_b(ka1: Array<U32>, pa1: Array<U32>, pa2: Array<U32>, m: Array<U32>, +i1: U32, +i2: U32, +nm: U32,
         +n1: U32, +n2: U32, +h1: U32, +l1: U32, g: S.A2) -> MJ:
  S.A2{ka2, +h2, +l2} = g
  mj_c(ka1, pa1, ka2, pa2, m, i1, i2, nm, n1, n2, h1, l1, h2, l2)

def mj_a(pa1: Array<U32>, ka2: Array<U32>, pa2: Array<U32>, m: Array<U32>, +i1: U32, +i2: U32, +nm: U32,
         +n1: U32, +n2: U32, g: S.A2) -> MJ:
  S.A2{ka1, +h1, +l1} = g
  mj_b(ka1, pa1, pa2, m, i1, i2, nm, n1, n2, h1, l1, S.get2(ka2, i2))

def mj_go(f: Nat, +n1: U32, +n2: U32, st: MJ) -> MJ:
  match f st:
    case 0n _:
      st
    case 1n+q MJ{ka1, pa1, ka2, pa2, m, +i1, +i2, +nm, +go}:
      match go:
        case True{}:
          mj_go(q, n1, n2, mj_a(pa1, ka2, pa2, m, i1, i2, nm, n1, n2, S.get2(ka1, i1)))
        case False{}:
          MJ{ka1, pa1, ka2, pa2, m, i1, i2, nm, False{}}

# runs of equal (pid1, pid2) pairs: triples (pid1, pid2, count)
type RC is Type:
  RC{m: Array<U32>, t: Array<U32>, +i: U32, +nt: U32, +c1: U32, +c2: U32, +cnt: U32}

def rc_emit(t: Array<U32>, +nt: U32, +c1: U32, +c2: U32, +cnt: U32) -> Array<U32>:
  +o = U32.mul(nt, 3)
  t1 = t[o] <- c1
  t2 = t1[(o + 1 : U32)] <- c2
  t2[(o + 2 : U32)] <- cnt

def rc_s(t: Array<U32>, +i: U32, +nt: U32, +c1: U32, +c2: U32, +cnt: U32, g: S.A2) -> RC:
  S.A2{m, +x, +y} = g
  K.when(RC, U32.is_gt(i, 0) && U32.is_eq(x, c1) && U32.is_eq(y, c2), \{
    True: RC{m, t, (i + 1 : U32), nt, c1, c2, (cnt + 1 : U32)}
    False: K.when(RC, U32.is_eq(i, 0), \{
      True: RC{m, t, 1, 0, x, y, 1}
      False: RC{m, rc_emit(t, nt, c1, c2, cnt), (i + 1 : U32), (nt + 1 : U32), x, y, 1}
    })
  })

def rc_go(f: Nat, st: RC) -> RC:
  match f st:
    case 0n _:
      st
    case 1n+q RC{m, t, +i, +nt, +c1, +c2, +cnt}:
      rc_go(q, rc_s(t, i, nt, c1, c2, cnt, S.get2(m, i)))

type TR is Type:
  TR{t: Array<U32>, +nt: U32}

def rc_fin(st: RC) -> TR:
  RC{m, t, +i, +nt, +c1, +c2, +cnt} = st
  K.when(TR, U32.is_eq(i, 0), \{
    True: TR{t, 0}
    False: TR{rc_emit(t, nt, c1, c2, cnt), (nt + 1 : U32)}
  })

def counted(+nm: U32, m: Array<U32>) -> TR:
  rc_fin(rc_go(U32.to_nat(nm), RC{S.sort2(nm, m), K.arr_new(U32.mul(U32.max(nm, 1), 3)), 0, 0, 0, 0, 0}))

# global_kmer_matchings_counts of parts R and C; the k-mer lists come back
type MT is Type:
  MT{ka1: Array<U32>, pa1: Array<U32>, ka2: Array<U32>, pa2: Array<U32>, tr: TR}

def mt_fin(st: MJ) -> MT:
  MJ{ka1, pa1, ka2, pa2, m, i1, i2, +nm, go} = st
  MT{ka1, pa1, ka2, pa2, counted(nm, m)}

def matchings(ka1: Array<U32>, pa1: Array<U32>, +n1: U32, ka2: Array<U32>, pa2: Array<U32>, +n2: U32) -> MT:
  mt_fin(mj_go(U32.to_nat((n1 + n2 : U32)), n1, n2,
    MJ{ka1, pa1, ka2, pa2, K.arr_new(U32.shln(U32.max(U32.min(n1, n2), 1), 1n)), 0, 0, 0,
       U32.is_lt(0, n1) && U32.is_lt(0, n2)}))

# db2db_sp decoder: pattern pairs into a buffer
# =============================================

type DD is Type:
  DD{patR: Array<U32>, nodR: Array<U32>, patC: Array<U32>, nodC: Array<U32>, t: Array<U32>, +nt: U32, +e: U32,
     +offR: U32, +offC: U32, bubs: List<&2, A.BB>}

type DE is Type:
  DE{dd: DD, ch: A.CH, +bp: U32, +go: Bool}

def de_bub2(patR: Array<U32>, nodR: Array<U32>, patC: Array<U32>, nodC: Array<U32>, t: Array<U32>, +nt: U32,
            +e: U32, +offR: U32, +offC: U32, bubs: List<&2, A.BB>, meta: Array<U32>, +nm: U32, +nbp: U32,
            +cnt: U32, cols: List<&2, U32>, bl: A.BL) -> DE:
  A.BL{buf, ids, i} = bl
  DE{DD{patR, nodR, patC, nodC, t, nt, (e + 1 : U32), offR, offC, Con{A.BB{cnt, ids, cols}, bubs}},
     A.CH{buf, meta, nm}, nbp, True{}}

def de_bub(patR: Array<U32>, nodR: Array<U32>, patC: Array<U32>, nodC: Array<U32>, t: Array<U32>, +nt: U32,
           +e: U32, +offR: U32, +offC: U32, bubs: List<&2, A.BB>, meta: Array<U32>, +nm: U32, +nbp: U32,
           +cnt: U32, +ns1: U32, bl: A.BL) -> DE:
  A.BL{buf, cols, +i} = bl
  de_bub2(patR, nodR, patC, nodC, t, nt, e, offR, offC, bubs, meta, nm, nbp, cnt, cols,
    A.bl_go(U32.to_nat(ns1), A.BL{buf, Nil{}, i}))

def de_meta(patR: Array<U32>, nodR: Array<U32>, patC: Array<U32>, nodC: Array<U32>, t: Array<U32>, +nt: U32,
            +e: U32, +offR: U32, +offC: U32, bubs: List<&2, A.BB>, +nm: U32, +nbp: U32, +cnt: U32, +ns1: U32,
            +bp: U32, +ns2: U32, buf: Array<U32>, meta: Array<U32>) -> DE:
  +o = U32.mul(nm, 5)
  m1 = meta[o] <- cnt
  m2 = m1[(o + 1 : U32)] <- ns1
  m3 = m2[(o + 2 : U32)] <- bp
  m4 = m3[(o + 3 : U32)] <- ns2
  DE{DD{patR, nodR, patC, nodC, t, nt, (e + 1 : U32), offR, offC, bubs},
     A.CH{buf, m4[(o + 4 : U32)] <- (bp + ns1 : U32), (nm + 1 : U32)}, nbp, True{}}

# the decoded pair: bubble or a meta entry (count, ns1, off1, ns2, off2)
def de_put(patR: Array<U32>, nodR: Array<U32>, patC: Array<U32>, nodC: Array<U32>, t: Array<U32>, +nt: U32,
           +e: U32, +offR: U32, +offC: U32, bubs: List<&2, A.BB>, meta: Array<U32>, +nm: U32, +bp: U32,
           +cnt: U32, +ns1: U32, +ns2: U32, +bubble: U32, buf: Array<U32>) -> DE:
  +bb = N.mul32(bubble, bubble)
  +big = Bool.not(N.lt64(N.mul32(ns1, ns2), bb))
  +nbp = (bp + ns1 + ns2 : U32)
  K.when(DE, big, \{
    True: de_bub(patR, nodR, patC, nodC, t, nt, e, offR, offC, bubs, meta, nm, nbp, cnt, ns1,
      A.bl_go(U32.to_nat(ns2), A.BL{buf, Nil{}, nbp}))
    False: de_meta(patR, nodR, patC, nodC, t, nt, e, offR, offC, bubs, nm, nbp, cnt, ns1, bp, ns2, buf, meta)
  })

def de_dec2(patR: Array<U32>, nodR: Array<U32>, t: Array<U32>, +nt: U32, +e: U32, +offR: U32, +offC: U32,
            bubs: List<&2, A.BB>, meta: Array<U32>, +nm: U32, +bp: U32, +cnt: U32, +ns1: U32, +ns2: U32,
            +bubble: U32, dw: A.DW) -> DE:
  A.DW{patC, nodC, buf, cur, out, off} = dw
  de_put(patR, nodR, patC, nodC, t, nt, e, offR, offC, bubs, meta, nm, bp, cnt, ns1, ns2, bubble, buf)

def de_dec1(patC: Array<U32>, nodC: Array<U32>, t: Array<U32>, +nt: U32, +e: U32, +offR: U32, +offC: U32,
            bubs: List<&2, A.BB>, meta: Array<U32>, +nm: U32, +bp: U32, +cnt: U32, +p2: U32, +ns1: U32,
            +ns2: U32, +bubble: U32, dw: A.DW) -> DE:
  A.DW{patR, nodR, buf, cur, out, off} = dw
  de_dec2(patR, nodR, t, nt, e, offR, offC, bubs, meta, nm, bp, cnt, ns1, ns2, bubble,
    A.dw_go(U32.to_nat((ns2 + 1 : U32)), A.DW{patC, nodC, buf, p2, (bp + ns1 + ns2 : U32), offC}))

def de_fits(full: Bool, patR: Array<U32>, nodR: Array<U32>, patC: Array<U32>, nodC: Array<U32>, t: Array<U32>,
            +nt: U32, +e: U32, +offR: U32, +offC: U32, bubs: List<&2, A.BB>, buf: Array<U32>, meta: Array<U32>,
            +nm: U32, +bp: U32, +cnt: U32, +p1: U32, +p2: U32, +ns1: U32, +ns2: U32, +bubble: U32) -> DE:
  match full:
    case True{}:
      DE{DD{patR, nodR, patC, nodC, t, nt, e, offR, offC, bubs}, A.CH{buf, meta, nm}, bp, False{}}
    case False{}:
      de_dec1(patC, nodC, t, nt, e, offR, offC, bubs, meta, nm, bp, cnt, p2, ns1, ns2, bubble,
        A.dw_go(U32.to_nat((ns1 + 1 : U32)), A.DW{patR, nodR, buf, p1, (bp + ns1 : U32), offR}))

def de_ns2(patR: Array<U32>, nodR: Array<U32>, nodC: Array<U32>, t: Array<U32>, +nt: U32, +e: U32,
           +offR: U32, +offC: U32, bubs: List<&2, A.BB>, buf: Array<U32>, meta: Array<U32>, +nm: U32, +bp: U32,
           +cnt: U32, +p1: U32, +p2: U32, +ns1: U32, +bsize: U32, +bubble: U32, r: Array<U32> & U32) -> DE:
  (patC, +ns2) = r
  de_fits(U32.is_ge((bp + ns1 + ns2 : U32), bsize), patR, nodR, patC, nodC, t, nt, e, offR, offC, bubs, buf,
    meta, nm, bp, cnt, p1, p2, ns1, ns2, bubble)

def de_ns1(nodR: Array<U32>, patC: Array<U32>, nodC: Array<U32>, t: Array<U32>, +nt: U32, +e: U32,
           +offR: U32, +offC: U32, bubs: List<&2, A.BB>, buf: Array<U32>, meta: Array<U32>, +nm: U32, +bp: U32,
           +cnt: U32, +p1: U32, +p2: U32, +bsize: U32, +bubble: U32, r: Array<U32> & U32) -> DE:
  (patR, +ns1) = r
  de_ns2(patR, nodR, nodC, t, nt, e, offR, offC, bubs, buf, meta, nm, bp, cnt, p1, p2, ns1, bsize, bubble,
    D.pget(patC, p2, 2))

def de_c(patR: Array<U32>, nodR: Array<U32>, patC: Array<U32>, nodC: Array<U32>, +nt: U32, +e: U32,
         +offR: U32, +offC: U32, bubs: List<&2, A.BB>, buf: Array<U32>, meta: Array<U32>, +nm: U32, +bp: U32,
         +p1: U32, +p2: U32, +bsize: U32, +bubble: U32, r: Array<U32> & U32) -> DE:
  (t, +cnt) = r
  de_ns1(nodR, patC, nodC, t, nt, e, offR, offC, bubs, buf, meta, nm, bp, cnt, p1, p2, bsize, bubble,
    D.pget(patR, p1, 2))

def de_p2(patR: Array<U32>, nodR: Array<U32>, patC: Array<U32>, nodC: Array<U32>, +nt: U32, +e: U32,
          +offR: U32, +offC: U32, bubs: List<&2, A.BB>, buf: Array<U32>, meta: Array<U32>, +nm: U32, +bp: U32,
          +p1: U32, +bsize: U32, +bubble: U32, r: Array<U32> & U32) -> DE:
  (t, +p2) = r
  de_c(patR, nodR, patC, nodC, nt, e, offR, offC, bubs, buf, meta, nm, bp, p1, p2, bsize, bubble,
    t[(U32.mul(e, 3) + 2 : U32)])

def de_p1(patR: Array<U32>, nodR: Array<U32>, patC: Array<U32>, nodC: Array<U32>, +nt: U32, +e: U32,
          +offR: U32, +offC: U32, bubs: List<&2, A.BB>, buf: Array<U32>, meta: Array<U32>, +nm: U32, +bp: U32,
          +bsize: U32, +bubble: U32, r: Array<U32> & U32) -> DE:
  (t, +p1) = r
  de_p2(patR, nodR, patC, nodC, nt, e, offR, offC, bubs, buf, meta, nm, bp, p1, bsize, bubble,
    t[(U32.mul(e, 3) + 1 : U32)])

def de_step(dd: DD, ch: A.CH, +bp: U32, +bsize: U32, +bubble: U32) -> DE:
  DD{patR, nodR, patC, nodC, t, +nt, +e, +offR, +offC, bubs} = dd
  A.CH{buf, meta, +nm} = ch
  de_p1(patR, nodR, patC, nodC, nt, e, offR, offC, bubs, buf, meta, nm, bp, bsize, bubble, t[U32.mul(e, 3)])

def dd_more(dd: DD) -> DD & Bool:
  DD{patR, nodR, patC, nodC, t, +nt, +e, +offR, +offC, bubs} = dd
  (DD{patR, nodR, patC, nodC, t, nt, e, offR, offC, bubs}, U32.is_lt(e, nt))

def de_more(ch: A.CH, +bp: U32, +go: Bool, r: DD & Bool) -> DE:
  (dd, +more) = r
  DE{dd, ch, bp, go && more}

def de_again(st: DE) -> DE:
  DE{dd, ch, +bp, +go} = st
  de_more(ch, bp, go, dd_more(dd))

def de_go(f: Nat, +bsize: U32, +bubble: U32, st: DE) -> DE:
  match f st:
    case 0n _:
      st
    case 1n+q DE{dd, ch, +bp, +go}:
      match go:
        case True{}:
          de_go(q, bsize, bubble, de_again(de_step(dd, ch, bp, bsize, bubble)))
        case False{}:
          DE{dd, ch, bp, False{}}

def de_fin(st: DE) -> A.CH & DD:
  DE{dd, ch, bp, go} = st
  (ch, dd)

def decode2(+bsize: U32, +bubble: U32, dd: DD) -> A.CH & DD:
  de_fin(de_go(U32.to_nat((bsize + 2 : U32)), bsize, bubble,
    de_more(A.CH{Array.new(U32, F.depth(bsize), 0), Array.new(U32, F.depth(U32.mul((bsize + 2 : U32), 5)), 0), 0},
      0, True{}, dd_more(dd))))

# db2db_sp workers: row s1 of the pattern of R (owned), += count for the
# samples s2 of the pattern of C
# ======================================================================

type WJ is Type:
  WJ{buf: Array<U32>, rows: Array<D.PT>, +j: U32}

def wj_kk(rows: Array<D.PT>, +li: U32, +j: U32, st: A.KK) -> WJ:
  A.KK{buf, hm, k} = st
  WJ{buf, Array.set(D.PT, rows, li, D.PLeaf{hm}), (j + 1 : U32)}

def wj_row(buf: Array<U32>, +li: U32, +j: U32, +nk: U32, +off2: U32, +ns2: U32, r: Array<D.PT> & D.PT) -> WJ:
  (rows, t) = r
  wj_kk(rows, li, j, A.kk_go(U32.to_nat(ns2), nk, A.KK{buf, A.row_hm(t), off2}))

def wj_s(+w: U32, +w2: U32, +nk: U32, +off2: U32, +ns2: U32, rows: Array<D.PT>, +j: U32, r: Array<U32> & U32) -> WJ:
  (buf, +id) = r
  +m = U32.mod(id, w2)
  +first = U32.is_eq(m, w)
  K.when(WJ, first || U32.is_eq(m, (w2 - 1 - w : U32)), \{
    True: wj_row(buf, (U32.shln(U32.div(id, w2), 1n) + K.sel(first, 0, 1) : U32), j, nk, off2, ns2,
      Array.swap(D.PT, rows, (U32.shln(U32.div(id, w2), 1n) + K.sel(first, 0, 1) : U32), D.PNil{}))
    False: WJ{buf, rows, (j + 1 : U32)}
  })

def wj_go(f: Nat, +w: U32, +w2: U32, +nk: U32, +off2: U32, +ns2: U32, st: WJ) -> WJ:
  match f st:
    case 0n _:
      st
    case 1n+q WJ{buf, rows, +j}:
      wj_go(q, w, w2, nk, off2, ns2, wj_s(w, w2, nk, off2, ns2, rows, j, buf[j]))

type WE is Type:
  WE{buf: Array<U32>, meta: Array<U32>, rows: Array<D.PT>, +e: U32}

def we_fin(meta: Array<U32>, +e: U32, st: WJ) -> WE:
  WJ{buf, rows, j} = st
  WE{buf, meta, rows, (e + 1 : U32)}

def we_5(buf: Array<U32>, rows: Array<D.PT>, +w: U32, +w2: U32, +e: U32, +nk: U32, +ns1: U32, +off1: U32,
         +ns2: U32, r: Array<U32> & U32) -> WE:
  (meta, +off2) = r
  we_fin(meta, e, wj_go(U32.to_nat(ns1), w, w2, nk, off2, ns2, WJ{buf, rows, off1}))

def we_4(buf: Array<U32>, rows: Array<D.PT>, +w: U32, +w2: U32, +e: U32, +nk: U32, +ns1: U32, +off1: U32,
         r: Array<U32> & U32) -> WE:
  (meta, +ns2) = r
  we_5(buf, rows, w, w2, e, nk, ns1, off1, ns2, meta[(U32.mul(e, 5) + 4 : U32)])

def we_3(buf: Array<U32>, rows: Array<D.PT>, +w: U32, +w2: U32, +e: U32, +nk: U32, +ns1: U32, r: Array<U32> & U32) -> WE:
  (meta, +off1) = r
  we_4(buf, rows, w, w2, e, nk, ns1, off1, meta[(U32.mul(e, 5) + 3 : U32)])

def we_2(buf: Array<U32>, rows: Array<D.PT>, +w: U32, +w2: U32, +e: U32, +nk: U32, r: Array<U32> & U32) -> WE:
  (meta, +ns1) = r
  we_3(buf, rows, w, w2, e, nk, ns1, meta[(U32.mul(e, 5) + 2 : U32)])

def we_1(buf: Array<U32>, rows: Array<D.PT>, +w: U32, +w2: U32, +e: U32, r: Array<U32> & U32) -> WE:
  (meta, +nk) = r
  we_2(buf, rows, w, w2, e, nk, meta[(U32.mul(e, 5) + 1 : U32)])

def we_go(f: Nat, +w: U32, +w2: U32, st: WE) -> WE:
  match f st:
    case 0n _:
      st
    case 1n+q WE{buf, meta, rows, +e}:
      we_go(q, w, w2, we_1(buf, rows, w, w2, e, meta[U32.mul(e, 5)]))

def we_rows(st: WE) -> Array<D.PT>:
  WE{buf, meta, rows, e} = st
  rows

def work_leaf(+w: U32, rows: Array<D.PT>, +w2: U32, ch: A.CH) -> A.WT:
  A.CH{buf, meta, +nm} = ch
  A.WLeaf{w, we_rows(we_go(U32.to_nat(nm), w, w2, WE{buf, meta, rows, 0}))}

def work(wt: A.WT, +w2: U32, ch: A.CH) -> A.WT:
  match wt:
    case A.WLeaf{+w, rows}:
      work_leaf(w, rows, w2, ch)
    case A.WNode{l, r}:
      K.apply(A.CH & A.CH, A.WT, \{Tuple: c1 => c2 => (
        a b = work(l, w2, c1) work(r, w2, c2)
        A.WNode{a, b}
      )}, A.ch_clone(ch))

# Main loop of a cell (decode the next buffer while the workers run)
type AL is Type:
  AL{wt: A.WT, ch: A.CH, dd: DD, +go: Bool}

def al_pair(wt: A.WT, r: A.CH & DD) -> AL:
  (ch, dd) = r
  AL{wt, ch, dd, True{}}

def al_step(more: Bool, +w2: U32, +bsize: U32, +bubble: U32, wt: A.WT, ch: A.CH, dd: DD) -> AL:
  match more:
    case True{}:
      a b = work(wt, w2, ch) decode2(bsize, bubble, dd)
      al_pair(a, b)
    case False{}:
      AL{work(wt, w2, ch), A.ch_empty(), dd, False{}}

def al_go(f: Nat, +w2: U32, +bsize: U32, +bubble: U32, st: AL) -> AL:
  match f st:
    case 0n _:
      st
    case 1n+q AL{wt, ch, dd, +go}:
      match go:
        case True{}:
          K.apply(DD & Bool, AL, \{Tuple: dd2 => +more => (
            al_go(q, w2, bsize, bubble, al_step(more, w2, bsize, bubble, wt, ch, dd2))
          )}, dd_more(dd))
        case False{}:
          AL{wt, ch, dd, False{}}

def al_fin(st: AL) -> A.WT & DD:
  AL{wt, ch, dd, go} = st
  (wt, dd)

# One cell (row part R, column part C): db2db_sp into the rows of R
# ==================================================================

type CR is Type:
  CR{r: PR, c: PR, wt: A.WT, bubs: List<&2, A.BB>}

def cell_fin(+oR: U32, +bR: U32, +npR: U32, kaR: Array<U32>, paR: Array<U32>, +nkR: U32, +oC: U32, +bC: U32,
             +npC: U32, kaC: Array<U32>, paC: Array<U32>, +nkC: U32, r: A.WT & DD) -> CR:
  (wt, dd) = r
  DD{patR, nodR, patC, nodC, t, nt, e, offR, offC, bubs} = dd
  CR{PR{oR, bR, patR, npR, nodR, kaR, paR, nkR}, PR{oC, bC, patC, npC, nodC, kaC, paC, nkC}, wt, bubs}

def cell_m(patR: Array<U32>, nodR: Array<U32>, +oR: U32, +bR: U32, +npR: U32, +nkR: U32, patC: Array<U32>,
           nodC: Array<U32>, +oC: U32, +bC: U32, +npC: U32, +nkC: U32, wt: A.WT, bubs: List<&2, A.BB>,
           +w2: U32, +bubble: U32, mt: MT) -> CR:
  MT{kaR, paR, kaC, paC, tr} = mt
  TR{t, +nt} = tr
  +bsize = U32.div(U32.max(U32.shln((bR + bC : U32), 1n), 8000000), 4)
  K.apply(A.CH & DD, CR, \{Tuple: ch => dd => (
    cell_fin(oR, bR, npR, kaR, paR, nkR, oC, bC, npC, kaC, paC, nkC,
      al_fin(al_go(U32.to_nat((nt + 2 : U32)), w2, bsize, bubble, AL{wt, ch, dd, True{}})))
  )}, decode2(bsize, bubble, DD{patR, nodR, patC, nodC, t, nt, 0, oR, oC, bubs}))

def cell(r: PR, c: PR, wt: A.WT, bubs: List<&2, A.BB>, +w2: U32, +bubble: U32) -> CR:
  PR{+oR, +bR, patR, +npR, nodR, kaR, paR, +nkR} = r
  PR{+oC, +bC, patC, +npC, nodC, kaC, paC, +nkC} = c
  cell_m(patR, nodR, oR, bR, npR, nkR, patC, nodC, oC, bC, npC, nkC, wt, bubs, w2, bubble,
    matchings(kaR, paR, nkR, kaC, paC, nkC))

# Parts
# =====

type PL is Type:
  PLNil{}
  PLCon{h: PR, t: PL}

def pl_snoc(xs: PL, x: PR) -> PL:
  match xs:
    case PLNil{}:
      PLCon{x, PLNil{}}
    case PLCon{h, t}:
      PLCon{h, pl_snoc(t, x)}

# the cells (R, C) for every earlier part C, in part order
type RS is Type:
  RS{r: PR, wt: A.WT, bubs: List<&2, A.BB>, done: PL}

def rs_cell(done: PL, +w2: U32, +bubble: U32, cr: CR) -> RS:
  CR{r, c, wt, bubs} = cr
  RS{r, wt, bubs, pl_snoc(done, c)}

def cells(xs: PL, +w2: U32, +bubble: U32, st: RS) -> RS:
  match xs st:
    case PLNil{} _:
      st
    case PLCon{c, t} RS{r, wt, bubs, done}:
      cells(t, w2, bubble, rs_cell(done, w2, bubble, cell(r, c, wt, bubs, w2, bubble)))

# the diagonal cell (all2all_sp of R), then the rows of R are complete
type RP is Type:
  RP{done: PL, ot: A.OT, +o: U32, +b: U32}

def rp_fin(done: PL, +o: U32, +b: U32, +npR: U32, ka: Array<U32>, pa: Array<U32>, +nk: U32, +n: U32,
           cnt: Array<U32>, ar: A.AR) -> RP:
  A.AR{wt, pat, nod, +bubs} = ar
  RP{pl_snoc(done, PR{o, b, pat, npR, nod, ka, pa, nk}), A.out_tree2(n, wt, bubs, cnt), o, b}

def rp_diag(+n: U32, cnt: Array<U32>, +w2: U32, +bubble: U32, st: RS) -> RP:
  RS{r, wt, bubs, done} = st
  PR{+o, +b, pat, +np, nod, ka, pa, +nk} = r
  +bsize = K.sel(U32.is_lt(2000000, b), U32.shln(b, 1n), 2000000)
  rp_fin(done, o, b, np, ka, pa, nk, n, cnt, A.a2a_on(wt, pat, nod, np, o, w2, bsize, bubble, bubs))

# row part r against the earlier parts done; the worker rows of r for output
def row_part(r: PR, done: PL, +n: U32, cnt: Array<U32>, +w: U32, +bubble: U32) -> RP:
  +w2 = U32.shln(w, 1n)
  +rd = F.depth((U32.shln(U32.div((n + w2 : U32), w2), 1n) + 2 : U32))
  rp_diag(n, cnt, w2, bubble, cells(done, w2, bubble,
    RS{r, A.wt_new(F.depth(w), U32.is_le(w, 1), 0, w, rd), Nil{}, PLNil{}}))

# Building the parts (kmer-db build of every mfasta-tool part)
# ============================================================

def take(xs: F.Raws, +k: U32) -> F.Raws & F.Raws:
  match xs:
    case F.RawNil{}:
      (F.RawNil{}, F.RawNil{})
    case F.RawCon{h, t}:
      K.when(F.Raws & F.Raws, U32.is_eq(k, 0), \{
        True: (F.RawNil{}, F.RawCon{h, t})
        False: K.apply(F.Raws & F.Raws, F.Raws & F.Raws, \{Tuple: a => b => ((F.RawCon{h, a}, b))},
          take(t, (k - 1 : U32)))
      })

type BP is Type:
  BP{parts: PL, cnt: Array<U32>, +o: U32}

def bp_cnt(+o: U32, +b: U32, parts: PL, pr: PR, r: Array<U32> & Array<U32>) -> BP:
  (pc, gcnt) = r
  BP{pl_snoc(parts, pr), gcnt, (o + b : U32)}

def bp_part(+o: U32, +b: U32, parts: PL, gcnt: Array<U32>, bs: B.BS) -> BP:
  B.BS{db, cnt, s} = bs
  D.DB{ht, pt, +pb} = db
  bp_cnt(o, b, parts, pr_comp(o, b, pt, pb, tab_count(ht)), F.copy(b, 0, o, cnt, gcnt))

def bp_go(f: Nat, +bsz: U32, +n: U32, +c: X.Cfg, xs: F.Raws, st: BP) -> BP:
  match f xs:
    case 0n _:
      st
    case _ F.RawNil{}:
      st
    case 1n+q F.RawCon{h, t}:
      BP{parts, gcnt, +o} = st
      +b = U32.min(bsz, (n - o : U32))
      K.apply(F.Raws & F.Raws, BP, \{Tuple: part => rest => (
        bp_go(q, bsz, n, c, rest, bp_part(o, b, parts, gcnt, B.build(b, c, 64, part)))
      )}, take(F.RawCon{h, t}, b))

# all parts of bsz records, and the k-mer counts of all samples
def build_parts(+n: U32, +bsz: U32, +c: X.Cfg, xs: F.Raws) -> BP:
  bp_go(U32.to_nat((U32.div(n, bsz) + 2 : U32)), bsz, n, c, xs, BP{PLNil{}, K.arr_new(n), 0})
