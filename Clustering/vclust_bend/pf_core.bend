# Core of the Kmer-db-compatible prefilter: canonical k-mer extraction,
# hash partitioning, grouping of identical k-mers and accumulation of
# shared-k-mer counts for every sample pair.
#
# Plan (see README "Prefilter"):
#   * every sample owns its 2-bit packed sequence (an `ST` tree leaf);
#   * the k-mer space is cut by a 32-bit hash into P passes x Q groups. A
#     count pass records, per sample, how many k-mers fall in each bucket;
#   * pass p: every sample (in parallel) extracts its k-mers of pass p into
#     Q owned arrays (`Blk`); the sample x group lists are transposed by
#     re-linking (no copy);
#   * group q (in parallel): gathers its k-mers from all samples, sorts them
#     (counting sort on more hash bits, then a stable insertion sort on the
#     full key), deduplicates per sample (counting unique k-mers per
#     sample) and emits one code T(b) + a per sample pair a < b sharing the
#     k-mer, routed to the row block of b;
#   * row block r (in parallel): adds its codes into its dense slice of the
#     lower-triangular count matrix.
# No array is shared between parallel tasks: data moves between stages by
# ownership (lists/trees of arrays), so no @unsafe is needed.
import Base
import ./pf_fasta.bend as F
import ./pf_num.bend as N

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

# A run of k-mers or codes of one sample (or one row block): s, n, data.
type Blk is Type:
  Blk{+s: U32, +n: U32, a: Array<U32>}

type Blks is Type:
  BNil{}
  BCon{h: Blk, t: Blks}

type BL is Type:
  BLNil{}
  BLCon{h: Blks, t: BL}

# Samples: a leaf holds a chunk of ns consecutive samples from idx, each its
# packed codes and segments.
type SL is Type:
  SLNil{}
  SLCon{codes: Array<U32>, segs: F.Seg, t: SL}

type ST is Type:
  STNil{}
  STLeaf{+idx: U32, +ns: U32, ss: SL, cnt: Array<U32>}
  STNode{l: ST, r: ST}

# Parameters.
#   k, masks/units of the rolling k-mer (see ext_word), lb = log2(P*Q),
#   lq = log2 Q, p = current pass, usef/th/kd4/psh = MinHash sampler.
type Cfg is Data:
  Cfg{+k: U32, +himask: U32, +lomask: U32, +rhu: U32, +rlu: U32, +lb: U32, +lq: U32,
      +p: U32, +usef: Bool, +th: N.W2, +kd4: U32, +psh: U32}

def cfg_pass(c: Cfg, +p2: U32) -> Cfg:
  Cfg{+k, +himask, +lomask, +rhu, +rlu, +lb, +lq, +p, +usef, +th, +kd4, +psh} = c
  Cfg{k, himask, lomask, rhu, rlu, lb, lq, p2, usef, th, kd4, psh}

def cfg_p(c: Cfg) -> U32:
  Cfg{+k, +himask, +lomask, +rhu, +rlu, +lb, +lq, +p, +usef, +th, +kd4, +psh} = c
  p

def mix(+hi: U32, +lo: U32) -> U32:
  +h = U32.mul(U32.xor(lo, U32.mul(U32.xor(hi, U32.shrn(lo, 16n)), 2246822519)), 2654435761)
  U32.xor(h, U32.shrn(h, 15n))

def top_bits(+h: U32, +b: U32) -> U32:
  sel(U32.is_eq(b, 0), 0, shr(h, (32 - b : U32)))

# Kmer-db's 64-bit k-mer value seen by the sampler: for k < 20 the k-mer is
# widened to an 8-bit prefix: (x << s) | (x & (2^s - 1)), s = 40 - 2k.
def sample_ok(usef: Bool, +hi: U32, +lo: U32, c: Cfg) -> Bool:
  match usef:
    case False{}:
      True{}
    case True{}:
      Cfg{+k, +himask, +lomask, +rhu, +rlu, +lb, +lq, +p, +uf, +th, +kd4, +psh} = c
      +x = {N.W2{hi, lo} : N.W2}
      +w = N.add64(N.shl64(x, psh), N.W2{0, U32.and(lo, (shl(1, psh) - 1 : U32))})
      N.lt64(N.minhash(w, kd4), th)

# Arrays
# ======

def arr_new(+n: U32) -> Array<U32>:
  Array.new(U32, F.depth(U32.max(n, 1)), 0)

def bump_at(+i: U32, +d: U32, r: Array<U32> & U32) -> Array<U32>:
  (a, +v) = r
  a[i] <- (v + d : U32)

def bump(+i: U32, +d: U32, a: Array<U32>) -> Array<U32>:
  bump_at(i, d, a[i])

# Extraction
# ==========

# The k-mer action state: out (pass array of the leaf), cur (counts or
# cursors), s (the current sample). A pass record is 3 words: hi, lo, s.
type XS is Type:
  XS{out: Array<U32>, cur: Array<U32>, +s: U32}

def put_at(+khi: U32, +klo: U32, +q: U32, +s: U32, out: Array<U32>, r: Array<U32> & U32) -> XS:
  (cur, +pos) = r
  o2 = out[pos] <- khi
  o3 = o2[(pos + 1 : U32)] <- klo
  XS{o3[(pos + 2 : U32)] <- s, cur[q] <- (pos + 3 : U32), s}

def act_fill(go: Bool, +khi: U32, +klo: U32, +q: U32, x: XS) -> XS:
  match go:
    case False{}:
      x
    case True{}:
      XS{out, cur, +s} = x
      put_at(khi, klo, q, s, out, cur[q])

def act_count(go: Bool, +b: U32, x: XS) -> XS:
  match go:
    case False{}:
      x
    case True{}:
      XS{out, cur, +s} = x
      XS{out, bump(b, 1, cur), s}

def act_fill_in(inp: Bool, +khi: U32, +klo: U32, +q: U32, +c: Cfg, +usef: Bool, x: XS) -> XS:
  match inp:
    case False{}:
      x
    case True{}:
      act_fill(sample_ok(usef, khi, klo, c), khi, klo, q, x)

def act_k(cnt: Bool, +b: U32, +khi: U32, +klo: U32, +c: Cfg, +usef: Bool, +p: U32, +lq: U32, x: XS) -> XS:
  match cnt:
    case True{}:
      act_count(sample_ok(usef, khi, klo, c), b, x)
    case False{}:
      act_fill_in(U32.is_eq(shr(b, lq), p), khi, klo, U32.and(b, (shl(1, lq) - 1 : U32)), c, usef, x)

# mode 0: count k-mers per (pass, group); mode 1: write pass p's k-mers.
def act(+mode: U32, +khi: U32, +klo: U32, +c: Cfg, x: XS) -> XS:
  Cfg{+k, +himask, +lomask, +rhu, +rlu, +lb, +lq, +p, +usef, +th, +kd4, +psh} = c
  act_k(U32.is_eq(mode, 0), top_bits(mix(khi, klo), lb), khi, klo, c, usef, p, lq, x)

def act_if(go: Bool, +mode: U32, +khi: U32, +klo: U32, +c: Cfg, x: XS) -> XS:
  match go:
    case False{}:
      x
    case True{}:
      act(mode, khi, klo, c, x)

# Rolling state after a word.
type RS is Type:
  RS{+fhi: U32, +flo: U32, +rhi: U32, +rlo: U32, +v: U32, x: XS}

# Forward k-mer (fhi, flo) = ((f << 2) | c) & mask; reverse complement
# (rhi, rlo) = (r >> 2) | (3 - c) << (2k - 2), split as rhu / rlu units.
def ext_word(n: Nat, +mode: U32, +w: U32, +v: U32, +fhi: U32, +flo: U32, +rhi: U32, +rlo: U32,
             +hm: U32, +lm: U32, +rhu: U32, +rlu: U32, +k1: U32, +c: Cfg, x: XS) -> RS:
  match n:
    case 0n:
      RS{fhi, flo, rhi, rlo, v, x}
    case 1n+p:
      +b = U32.and(w, 3)
      +nb = (3 - b : U32)
      +nfhi = U32.and(U32.or(U32.shln(fhi, 2n), U32.shrn(flo, 30n)), hm)
      +nflo = U32.and(U32.or(U32.shln(flo, 2n), b), lm)
      +nrlo = U32.or(U32.or(U32.shrn(rlo, 2n), U32.shln(rhi, 30n)), U32.mul(nb, rlu))
      +nrhi = U32.or(U32.shrn(rhi, 2n), U32.mul(nb, rhu))
      +fwd = U32.is_lt(nfhi, nrhi) || (U32.is_eq(nfhi, nrhi) && U32.is_lt(nflo, nrlo))
      ext_word(p, mode, U32.shrn(w, 2n), (v + 1 : U32), nfhi, nflo, nrhi, nrlo, hm, lm, rhu, rlu, k1, c,
        act_if(U32.is_ge(v, k1), mode, sel(fwd, nfhi, nrhi), sel(fwd, nflo, nrlo), c, x))

type CX is Type:
  CX{codes: Array<U32>, x: XS}

def ext_seg(nw: Nat, +wi: U32, +rem: U32, +mode: U32, +hm: U32, +lm: U32, +rhu: U32, +rlu: U32,
            +k1: U32, +c: Cfg, rs: RS, r: Array<U32> & U32) -> CX:
  match nw rs:
    case 0n RS{fhi, flo, rhi, rlo, v, x}:
      (codes, _w) = r
      CX{codes, x}
    case 1n+p RS{+fhi, +flo, +rhi, +rlo, +v, x}:
      (codes, +w) = r
      +j = (wi + 1 : U32)
      ext_seg(p, j, (rem - 16 : U32), mode, hm, lm, rhu, rlu, k1, c,
        ext_word(U32.to_nat(U32.min(rem, 16)), mode, w, v, fhi, flo, rhi, rlo, hm, lm, rhu, rlu, k1, c, x),
        codes[j])

def seg_run(+w0: U32, +len: U32, +mode: U32, +c: Cfg, codes: Array<U32>, x: XS) -> CX:
  Cfg{+k, +himask, +lomask, +rhu, +rlu, +lb, +lq, +p, +usef, +th, +kd4, +psh} = c
  ext_seg(U32.to_nat(U32.shrn((len + 15 : U32), 4n)), w0, len, mode, himask, lomask, rhu, rlu,
    (k - 1 : U32), c, RS{0, 0, 0, 0, 0, x}, codes[w0])

def ext_segs(segs: F.Seg, +mode: U32, +c: Cfg, cx: CX) -> CX:
  match segs cx:
    case F.SegNil{} _:
      cx
    case F.SegCon{+w0, +len, t} CX{codes, x}:
      ext_segs(t, mode, c, seg_run(w0, len, mode, c, codes, x))

# Splitting a pass array into Q group arrays
# ==========================================

type SS is Type:
  SS{+q: U32, +prev: U32, out: Array<U32>, cur: Array<U32>, acc: Blks}

# The run lengths are (end - prev) / sh words; the run tag is s, or q when s
# is 4294967295.
def split_c(+q: U32, +end: U32, +s: U32, +sh: U32, +len: U32, cur: Array<U32>, acc: Blks,
            r: Array<U32> & Array<U32>) -> SS:
  (out, dst) = r
  SS{(q + 1 : U32), end, out, cur, BCon{Blk{sel(U32.is_eq(s, 4294967295), q, s), U32.div(len, sh), dst}, acc}}

def split_r(+q: U32, +prev: U32, +s: U32, +sh: U32, out: Array<U32>, acc: Blks, r: Array<U32> & U32) -> SS:
  (cur, +end) = r
  +len = (end - prev : U32)
  split_c(q, end, s, sh, len, cur, acc, F.copy(len, prev, 0, out, arr_new(len)))

def split_step(+s: U32, +sh: U32, st: SS) -> SS:
  SS{+q, +prev, out, cur, acc} = st
  split_r(q, prev, s, sh, out, acc, cur[q])

def split_go(n: Nat, +s: U32, +sh: U32, st: SS) -> SS:
  match n:
    case 0n:
      st
    case 1n+p:
      split_go(p, s, sh, split_step(s, sh, st))

def blks_rev(xs: Blks, acc: Blks) -> Blks:
  match xs:
    case BNil{}:
      acc
    case BCon{h, t}:
      blks_rev(t, BCon{h, acc})

def split_fin(st: SS) -> Blks:
  SS{q, prev, out, cur, acc} = st
  blks_rev(acc, BNil{})

# Per-sample passes
# =================

type BT is Type:
  BTNil{}
  BTLeaf{bs: Blks}
  BTNode{l: BT, r: BT}

type PR is Type:
  PR{st: ST, bt: BT}

# The samples of a leaf, one after the other, through ext_segs with one
# shared action state (the list comes back reversed).
type SW is Type:
  SW{todo: SL, done: SL, x: XS}

def sw_done(segs: F.Seg, t: SL, done: SL, cx: CX) -> SW:
  CX{codes, x} = cx
  XS{out, cur, +s} = x
  SW{t, SLCon{codes, segs, done}, XS{out, cur, (s + 1 : U32)}}

def sw_step(+mode: U32, +c: Cfg, st: SW) -> SW:
  match st:
    case SW{SLNil{}, done, x}:
      SW{SLNil{}, done, x}
    case SW{SLCon{codes, +segs, t}, done, x}:
      sw_done(segs, t, done, ext_segs(segs, mode, c, CX{codes, x}))

def sw_go(n: Nat, +mode: U32, +c: Cfg, st: SW) -> SW:
  match n:
    case 0n:
      st
    case 1n+p:
      sw_go(p, mode, c, sw_step(mode, c, st))

def sl_rev(xs: SL, acc: SL) -> SL:
  match xs:
    case SLNil{}:
      acc
    case SLCon{codes, segs, t}:
      sl_rev(t, SLCon{codes, segs, acc})

def leaf_counted(+idx: U32, +ns: U32, st: SW) -> PR:
  SW{todo, done, x} = st
  XS{out, cnt, s} = x
  PR{STLeaf{idx, ns, sl_rev(done, SLNil{}), cnt}, BTNil{}}

# Group cursors of pass p: cur[q] = 3 * (k-mers of groups < q).
type CS is Type:
  CS{cnt: Array<U32>, cur: Array<U32>, +acc: U32}

def cs_r(+q: U32, cur: Array<U32>, +acc: U32, r: Array<U32> & U32) -> CS:
  (cnt, +v) = r
  CS{cnt, cur[q] <- acc, (acc + U32.mul(v, 3) : U32)}

def cs_go(n: Nat, +q: U32, +base: U32, st: CS) -> CS:
  match n st:
    case 0n _:
      st
    case 1n+p CS{cnt, cur, +acc}:
      cs_go(p, (q + 1 : U32), base, cs_r(q, cur, acc, cnt[(base + q : U32)]))

def leaf_filled(+idx: U32, +ns: U32, cnt: Array<U32>, +nq: U32, st: SW) -> PR:
  SW{todo, done, x} = st
  XS{out, cur, s} = x
  PR{STLeaf{idx, ns, sl_rev(done, SLNil{}), cnt},
     BTLeaf{split_fin(split_go(U32.to_nat(nq), idx, 3, SS{0, 0, out, cur, BNil{}}))}}

def leaf_fill(+idx: U32, +ns: U32, ss: SL, +c: Cfg, +nq: U32, cs: CS) -> PR:
  CS{cnt, cur, +total} = cs
  leaf_filled(idx, ns, cnt, nq, sw_go(U32.to_nat(ns), 1, c, SW{ss, SLNil{}, XS{arr_new(total), cur, idx}}))

def leaf_pass(+mode: U32, +idx: U32, +ns: U32, ss: SL, cnt: Array<U32>, +c: Cfg,
              +nq: U32, +pq: U32, isc: Bool) -> PR:
  match isc:
    case True{}:
      leaf_counted(idx, ns, sw_go(U32.to_nat(ns), 0, c, SW{ss, SLNil{}, XS{arr_new(1), arr_new(pq), idx}}))
    case False{}:
      leaf_fill(idx, ns, ss, c, nq,
        cs_go(U32.to_nat(nq), 0, U32.mul(cfg_p(c), nq), CS{cnt, arr_new(nq), 0}))

def pr_join(a: PR, b: PR) -> PR:
  PR{sa, ba} = a
  PR{sb, bb} = b
  PR{STNode{sa, sb}, BTNode{ba, bb}}

# mode 0: count pass (fills every leaf's cnt); mode 1: fill pass c.p.
def par_pass(st: ST, +mode: U32, +c: Cfg, +nq: U32, +pq: U32) -> PR:
  match st:
    case STNil{}:
      PR{STNil{}, BTNil{}}
    case STLeaf{+idx, +ns, ss, cnt}:
      leaf_pass(mode, idx, ns, ss, cnt, c, nq, pq, U32.is_eq(mode, 0))
    case STNode{l, r}:
      a b = par_pass(l, mode, c, nq, pq) par_pass(r, mode, c, nq, pq)
      pr_join(a, b)

# Transposing samples x groups
# ============================

# A group's input: its total k-mer count m and its runs, in sample order.
type GQ is Type:
  GNil{}
  GCon{+m: U32, bs: Blks, t: GQ}

def bt_flat(bt: BT, acc: BL) -> BL:
  match bt:
    case BTNil{}:
      acc
    case BTLeaf{bs}:
      BLCon{bs, acc}
    case BTNode{l, r}:
      bt_flat(r, bt_flat(l, acc))

def gq_new(n: Nat) -> GQ:
  match n:
    case 0n:
      GNil{}
    case 1n+p:
      GCon{0, BNil{}, gq_new(p)}

def gq_cons(h: Blk, +m: U32, bs: Blks, rest: GQ) -> GQ:
  Blk{+s, +n, a} = h
  GCon{(m + n : U32), BCon{Blk{s, n, a}, bs}, rest}

def zipcons(sample: Blks, accs: GQ) -> GQ:
  match sample accs:
    case BCon{h, t} GCon{+m, bs, rest}:
      gq_cons(h, m, bs, zipcons(t, rest))
    case _ _:
      accs

# rev: the samples' group lists in reverse sample order.
def transpose(rev: BL, accs: GQ) -> GQ:
  match rev:
    case BLNil{}:
      accs
    case BLCon{h, t}:
      transpose(t, zipcons(h, accs))

# Group task: gather
# ==================

type GE is Type:
  GE{a: Array<U32>, w4: Array<U32>, +i: U32, +w: U32, +s: U32}

def ge_2(w4: Array<U32>, +i: U32, +w: U32, +s: U32, +hi: U32, r: Array<U32> & U32) -> GE:
  (a, +lo) = r
  +o = U32.shln(w, 2n)
  x1 = w4[o] <- hi
  x2 = x1[(o + 1 : U32)] <- lo
  x3 = x2[(o + 2 : U32)] <- s
  GE{a, x3[(o + 3 : U32)] <- mix(hi, lo), (i + 1 : U32), (w + 1 : U32), s}

def ge_s(w4: Array<U32>, +i: U32, +w: U32, +hi: U32, +lo: U32, r: Array<U32> & U32) -> GE:
  (a, +s) = r
  ge_2(w4, i, w, s, hi, (a, lo))

def ge_lo(w4: Array<U32>, +i: U32, +w: U32, +hi: U32, r: Array<U32> & U32) -> GE:
  (a, +lo) = r
  ge_s(w4, i, w, hi, lo, a[(U32.mul(i, 3) + 2 : U32)])

def ge_1(w4: Array<U32>, +i: U32, +w: U32, +s: U32, r: Array<U32> & U32) -> GE:
  (a, +hi) = r
  ge_lo(w4, i, w, hi, a[(U32.mul(i, 3) + 1 : U32)])

def ge_step(st: GE) -> GE:
  GE{a, w4, +i, +w, +s} = st
  ge_1(w4, i, w, s, a[U32.mul(i, 3)])

def ge_go(n: Nat, st: GE) -> GE:
  match n:
    case 0n:
      st
    case 1n+p:
      ge_go(p, ge_step(st))

type WW is Type:
  WW{w4: Array<U32>, +w: U32}

def ge_fin(st: GE) -> WW:
  GE{a, w4, i, +w, s} = st
  WW{w4, w}

def gather_blk(h: Blk, ww: WW) -> WW:
  Blk{+s, +n, a} = h
  WW{w4, +w} = ww
  ge_fin(ge_go(U32.to_nat(n), GE{a, w4, 0, w, s}))

def gather(bs: Blks, ww: WW) -> WW:
  match bs:
    case BNil{}:
      ww
    case BCon{h, t}:
      gather(t, gather_blk(h, ww))

# Group task: counting sort on the sub-bucket bits
# ================================================

# sub-bucket of a record: hash bits [lb, lb + ls)
def sub_of(+h: U32, +lb: U32, +ls: U32) -> U32:
  sel(U32.is_eq(ls, 0), 0, shr(shl(h, lb), (32 - ls : U32)))

type CC is Type:
  CC{w4: Array<U32>, cnt: Array<U32>, +i: U32}

def cc_r(+i: U32, +lb: U32, +ls: U32, cnt: Array<U32>, r: Array<U32> & U32) -> CC:
  (w4, +h) = r
  CC{w4, bump((sub_of(h, lb, ls) + 1 : U32), 1, cnt), (i + 1 : U32)}

def cc_step(+lb: U32, +ls: U32, st: CC) -> CC:
  CC{w4, cnt, +i} = st
  cc_r(i, lb, ls, cnt, w4[(U32.shln(i, 2n) + 3 : U32)])

def cc_go(n: Nat, +lb: U32, +ls: U32, st: CC) -> CC:
  match n:
    case 0n:
      st
    case 1n+p:
      cc_go(p, lb, ls, cc_step(lb, ls, st))

# prefix sums in place: a[i] = a[0] + .. + a[i]
type PF is Type:
  PF{a: Array<U32>, +i: U32, +acc: U32}

def pf_r(+i: U32, +acc: U32, r: Array<U32> & U32) -> PF:
  (a, +v) = r
  +s = (acc + v : U32)
  PF{a[i] <- s, (i + 1 : U32), s}

def pf_step(st: PF) -> PF:
  PF{a, +i, +acc} = st
  pf_r(i, acc, a[i])

def pf_go(n: Nat, st: PF) -> PF:
  match n:
    case 0n:
      st
    case 1n+p:
      pf_go(p, pf_step(st))

def pf_fin(st: PF) -> Array<U32>:
  PF{a, i, acc} = st
  a

def prefix(+n: U32, a: Array<U32>) -> Array<U32>:
  pf_fin(pf_go(U32.to_nat(n), PF{a, 0, 0}))

# scatter: records of w4 to w5 at cursor cnt[sub]
type SC is Type:
  SC{w4: Array<U32>, w5: Array<U32>, cnt: Array<U32>, +i: U32}

def sc_5(w4: Array<U32>, w5: Array<U32>, +i: U32, +sub: U32, +hi: U32, +lo: U32, +s: U32, +h: U32,
         r: Array<U32> & U32) -> SC:
  (cnt, +pos) = r
  +o = U32.shln(pos, 2n)
  y1 = w5[o] <- hi
  y2 = y1[(o + 1 : U32)] <- lo
  y3 = y2[(o + 2 : U32)] <- s
  SC{w4, y3[(o + 3 : U32)] <- h, cnt[sub] <- (pos + 1 : U32), (i + 1 : U32)}

def sc_4(w5: Array<U32>, cnt: Array<U32>, +i: U32, +lb: U32, +ls: U32, +hi: U32, +lo: U32, +s: U32,
         r: Array<U32> & U32) -> SC:
  (w4, +h) = r
  +sub = sub_of(h, lb, ls)
  sc_5(w4, w5, i, sub, hi, lo, s, h, cnt[sub])

def sc_3(w5: Array<U32>, cnt: Array<U32>, +i: U32, +lb: U32, +ls: U32, +hi: U32, +lo: U32,
         r: Array<U32> & U32) -> SC:
  (w4, +s) = r
  sc_4(w5, cnt, i, lb, ls, hi, lo, s, w4[(U32.shln(i, 2n) + 3 : U32)])

def sc_2(w5: Array<U32>, cnt: Array<U32>, +i: U32, +lb: U32, +ls: U32, +hi: U32, r: Array<U32> & U32) -> SC:
  (w4, +lo) = r
  sc_3(w5, cnt, i, lb, ls, hi, lo, w4[(U32.shln(i, 2n) + 2 : U32)])

def sc_1(w5: Array<U32>, cnt: Array<U32>, +i: U32, +lb: U32, +ls: U32, r: Array<U32> & U32) -> SC:
  (w4, +hi) = r
  sc_2(w5, cnt, i, lb, ls, hi, w4[(U32.shln(i, 2n) + 1 : U32)])

def sc_step(+lb: U32, +ls: U32, st: SC) -> SC:
  SC{w4, w5, cnt, +i} = st
  sc_1(w5, cnt, i, lb, ls, w4[U32.shln(i, 2n)])

def sc_go(n: Nat, +lb: U32, +ls: U32, st: SC) -> SC:
  match n:
    case 0n:
      st
    case 1n+p:
      sc_go(p, lb, ls, sc_step(lb, ls, st))

# Group task: insertion sort of each sub-bucket on (hi, lo), stable
# =================================================================

type R4A is Type:
  R4A{a: Array<U32>, +x0: U32, +x1: U32, +x2: U32, +x3: U32}

def rg4(+x0: U32, +x1: U32, +x2: U32, r: Array<U32> & U32) -> R4A:
  (a, +x3) = r
  R4A{a, x0, x1, x2, x3}

def rg3(+o: U32, +x0: U32, +x1: U32, r: Array<U32> & U32) -> R4A:
  (a, +x2) = r
  rg4(x0, x1, x2, a[(o + 3 : U32)])

def rg2(+o: U32, +x0: U32, r: Array<U32> & U32) -> R4A:
  (a, +x1) = r
  rg3(o, x0, x1, a[(o + 2 : U32)])

def rg1(+o: U32, r: Array<U32> & U32) -> R4A:
  (a, +x0) = r
  rg2(o, x0, a[(o + 1 : U32)])

# record at slot i (4 words)
def rec_get(a: Array<U32>, +i: U32) -> R4A:
  +o = U32.shln(i, 2n)
  rg1(o, a[o])

def rec_put(a: Array<U32>, +i: U32, +x0: U32, +x1: U32, +x2: U32, +x3: U32) -> Array<U32>:
  +o = U32.shln(i, 2n)
  a1 = a[o] <- x0
  a2 = a1[(o + 1 : U32)] <- x1
  a3 = a2[(o + 2 : U32)] <- x2
  a3[(o + 3 : U32)] <- x3

type IS is Type:
  IS{a: Array<U32>, +j: U32, +go: Bool}

def is_swap(sw: Bool, +j: U32, +a0: U32, +a1: U32, +a2: U32, +a3: U32, b: R4A) -> IS:
  match sw:
    case True{}:
      R4A{arr, +b0, +b1, +b2, +b3} = b
      IS{rec_put(rec_put(arr, (j - 1 : U32), b0, b1, b2, b3), j, a0, a1, a2, a3), (j - 1 : U32), True{}}
    case False{}:
      R4A{arr, b0, b1, b2, b3} = b
      IS{arr, j, False{}}

def is_cmp(+j: U32, +a0: U32, +a1: U32, +a2: U32, +a3: U32, b: R4A) -> IS:
  R4A{arr, +b0, +b1, +b2, +b3} = b
  is_swap(U32.is_gt(a0, b0) || (U32.is_eq(a0, b0) && U32.is_gt(a1, b1)), j, a0, a1, a2, a3,
    R4A{arr, b0, b1, b2, b3})

def is_b(+j: U32, a: R4A) -> IS:
  R4A{arr, +a0, +a1, +a2, +a3} = a
  is_cmp(j, a0, a1, a2, a3, rec_get(arr, j))

def is_step(st: IS) -> IS:
  IS{a, +j, +go} = st
  match go:
    case True{}:
      is_b(j, rec_get(a, (j - 1 : U32)))
    case False{}:
      IS{a, j, False{}}

def ins_go(n: Nat, st: IS) -> IS:
  match n:
    case 0n:
      st
    case 1n+p:
      ins_go(p, is_step(st))

def is_fin(st: IS) -> Array<U32>:
  IS{a, j, go} = st
  a

# insertion sort of the records [lo, lo + n + 1): insert i = lo+1 ..
def rs_go(n: Nat, +i: U32, +lo: U32, a: Array<U32>) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      rs_go(p, (i + 1 : U32), lo, is_fin(ins_go(U32.to_nat((i - lo : U32)), IS{a, i, True{}})))

type SB is Type:
  SB{a: Array<U32>, cnt: Array<U32>, +sub: U32, +prev: U32}

def sb_r(a: Array<U32>, +sub: U32, +prev: U32, r: Array<U32> & U32) -> SB:
  (cnt, +end) = r
  +n = (end - prev : U32)
  SB{rs_go(U32.to_nat(sel(U32.is_gt(n, 1), (n - 1 : U32), 0)), (prev + 1 : U32), prev, a), cnt,
     (sub + 1 : U32), end}

def sb_step(st: SB) -> SB:
  SB{a, cnt, +sub, +prev} = st
  sb_r(a, sub, prev, cnt[sub])

def sb_go(n: Nat, st: SB) -> SB:
  match n:
    case 0n:
      st
    case 1n+p:
      sb_go(p, sb_step(st))

def sb_fin(st: SB) -> Array<U32>:
  SB{a, cnt, sub, prev} = st
  a

# Group task: scans over the sorted records
# =========================================
#
# Equal (hi, lo) records are adjacent and in sample order. A sample's first
# record of a k-mer is a distinct (k-mer, sample) pair: it counts one unique
# k-mer of the sample, and pairs it with every earlier distinct sample of the
# k-mer (gn of them). Pass 1 counts the pairs of every row block; pass 2
# writes their codes T(b) - T(B0) + a.

# Row blocks of a batch [b0, b1): R blocks of h = ceil((b1 - b0) / R)
# consecutive rows. A pair a < b of row b (block (b - b0) / h, first row r0)
# has the block-local code (b - r0) * n + a < h * n; the caller picks R so
# that h * n < 2^32 (lr_of in prefilter.bend), so codes fit a U32.
type RB is Data:
  RB{+b0: U32, +b1: U32, +h: U32, +n: U32, +rm1: U32}

def rowblk(+b: U32, rb: RB) -> U32:
  RB{+b0, +b1, +h, +n, +rm1} = rb
  sel(U32.is_lt(b, b0) || U32.is_ge(b, b1), 4294967295, U32.min(rm1, U32.div((b - b0 : U32), h)))

# code of the pair (a, b) minus a
def rb_base(+b: U32, rb: RB) -> U32:
  RB{+b0, +b1, +h, +n, +rm1} = rb
  U32.mul(U32.mod((b - b0 : U32), h), n)

def rb_make(+b0: U32, +b1: U32, +n: U32, +r: U32) -> RB:
  RB{b0, b1, U32.max(1, U32.div((b1 - b0 + r - 1 : U32), r)), n, (r - 1 : U32)}

# first row of block r
def bound(+r: U32, rb: RB) -> U32:
  RB{+b0, +b1, +h, +n, +rm1} = rb
  U32.min(b1, (b0 + U32.mul(U32.min(r, (rm1 + 1 : U32)), h) : U32))

type SN is Type:
  SN{a: Array<U32>, uc: Array<U32>, tb: Array<U32>, rc: Array<U32>, e: Array<U32>, g: Array<U32>,
     +i: U32, +phi: U32, +plo: U32, +valid: Bool, +ls: U32, +gn: U32}

type EM is Type:
  EM{g: Array<U32>, e: Array<U32>, +j: U32}

def em_r(e: Array<U32>, +j: U32, +base: U32, +pos: U32, r: Array<U32> & U32) -> EM:
  (g, +v) = r
  EM{g, e[(pos + j : U32)] <- (base + v : U32), (j + 1 : U32)}

def em_step(+base: U32, +pos: U32, st: EM) -> EM:
  EM{g, e, +j} = st
  em_r(e, j, base, pos, g[j])

def em_go(n: Nat, +base: U32, +pos: U32, st: EM) -> EM:
  match n:
    case 0n:
      st
    case 1n+p:
      em_go(p, base, pos, em_step(base, pos, st))

# emit gn codes of row s into row block blk (pass 2)
def emit_fin(a: Array<U32>, uc: Array<U32>, tb: Array<U32>, rc: Array<U32>, +blk: U32, +pos: U32,
             +gn: U32, st: EM) -> SN:
  EM{g, e, j} = st
  SN{a, uc, tb, rc[blk] <- (pos + gn : U32), e, g, 0, 0, 0, False{}, 0, 0}

def emit_r(a: Array<U32>, uc: Array<U32>, tb: Array<U32>, e: Array<U32>, g: Array<U32>, +blk: U32,
           +base: U32, +gn: U32, r: Array<U32> & U32) -> SN:
  (rc, +pos) = r
  emit_fin(a, uc, tb, rc, blk, pos, gn, em_go(U32.to_nat(gn), base, pos, EM{g, e, 0}))

def emit_if(go: Bool, a: Array<U32>, uc: Array<U32>, tb: Array<U32>, rc: Array<U32>, e: Array<U32>,
            g: Array<U32>, +blk: U32, +base: U32, +gn: U32) -> SN:
  match go:
    case True{}:
      emit_r(a, uc, tb, e, g, blk, base, gn, rc[blk])
    case False{}:
      SN{a, uc, tb, rc, e, g, 0, 0, 0, False{}, 0, 0}

# the scan state is rebuilt by sn_set after the per-record work
def sn_set(+i: U32, +hi: U32, +lo: U32, +ls: U32, +gn: U32, st: SN) -> SN:
  SN{a, uc, tb, rc, e, g, i0, p0, q0, v0, l0, n0} = st
  SN{a, uc, tb, rc, e, g, (i + 1 : U32), hi, lo, True{}, ls, gn}

def sn_mode(p1: Bool, inb: Bool, +s: U32, +gn: U32, +rb: RB, +blk: U32, a: Array<U32>, uc: Array<U32>,
            tb: Array<U32>, rc: Array<U32>, e: Array<U32>, g: Array<U32>) -> SN:
  match p1 inb:
    case True{} True{}:
      SN{a, uc, tb, bump((blk + 1 : U32), gn, rc), e, g, 0, 0, 0, False{}, 0, 0}
    case True{} False{}:
      SN{a, uc, tb, rc, e, g, 0, 0, 0, False{}, 0, 0}
    case False{} True{}:
      emit_if(U32.is_gt(gn, 0), a, uc, tb, rc, e, g[gn] <- s, blk, rb_base(s, rb), gn)
    case False{} False{}:
      SN{a, uc, tb, rc, e, g[gn] <- s, 0, 0, 0, False{}, 0, 0}

def sn_blk(+mode: U32, +s: U32, +gn: U32, +rb: RB, a: Array<U32>, uc: Array<U32>, rc: Array<U32>,
           e: Array<U32>, g: Array<U32>, r: Array<U32> & U32) -> SN:
  (tb, +blk) = r
  sn_mode(U32.is_eq(mode, 0), U32.is_ne(blk, 4294967295), s, gn, rb, blk, a, uc, tb, rc, e, g)

def uc_if(c: Bool, +s: U32, uc: Array<U32>) -> Array<U32>:
  match c:
    case True{}:
      bump(s, 1, uc)
    case False{}:
      uc

def sn_new(isnew: Bool, +mode: U32, +i: U32, +hi: U32, +lo: U32, +s: U32, +gn: U32, +ls: U32, +rb: RB,
           a: Array<U32>, uc: Array<U32>, tb: Array<U32>, rc: Array<U32>, e: Array<U32>, g: Array<U32>) -> SN:
  match isnew:
    case True{}:
      sn_set(i, hi, lo, s, (gn + 1 : U32),
        sn_blk(mode, s, gn, rb, a, uc_if(U32.is_eq(mode, 0), s, uc), rc, e, g, (tb, rowblk(s, rb))))
    case False{}:
      SN{a, uc, tb, rc, e, g, (i + 1 : U32), hi, lo, True{}, ls, gn}

def sn_3(+mode: U32, +rb: RB, uc: Array<U32>, tb: Array<U32>, rc: Array<U32>, e: Array<U32>,
         g: Array<U32>, +i: U32, +phi: U32, +plo: U32, +valid: Bool, +ls: U32, +gn: U32, +hi: U32,
         +lo: U32, r: Array<U32> & U32) -> SN:
  (a, +s) = r
  +same = valid && U32.is_eq(hi, phi) && U32.is_eq(lo, plo)
  +gn1 = sel(same, gn, 0)
  +ls1 = sel(same, ls, 4294967295)
  sn_new(U32.is_ne(s, ls1), mode, i, hi, lo, s, gn1, ls1, rb, a, uc, tb, rc, e, g)

def sn_2(+mode: U32, +rb: RB, uc: Array<U32>, tb: Array<U32>, rc: Array<U32>, e: Array<U32>,
         g: Array<U32>, +i: U32, +phi: U32, +plo: U32, +valid: Bool, +ls: U32, +gn: U32, +hi: U32,
         r: Array<U32> & U32) -> SN:
  (a, +lo) = r
  sn_3(mode, rb, uc, tb, rc, e, g, i, phi, plo, valid, ls, gn, hi, lo, a[(U32.shln(i, 2n) + 2 : U32)])

def sn_1(+mode: U32, +rb: RB, uc: Array<U32>, tb: Array<U32>, rc: Array<U32>, e: Array<U32>,
         g: Array<U32>, +i: U32, +phi: U32, +plo: U32, +valid: Bool, +ls: U32, +gn: U32,
         r: Array<U32> & U32) -> SN:
  (a, +hi) = r
  sn_2(mode, rb, uc, tb, rc, e, g, i, phi, plo, valid, ls, gn, hi, a[(U32.shln(i, 2n) + 1 : U32)])

def sn_step(+mode: U32, +rb: RB, st: SN) -> SN:
  SN{a, uc, tb, rc, e, g, +i, +phi, +plo, +valid, +ls, +gn} = st
  sn_1(mode, rb, uc, tb, rc, e, g, i, phi, plo, valid, ls, gn, a[U32.shln(i, 2n)])

def sn_go(n: Nat, +mode: U32, +rb: RB, st: SN) -> SN:
  match n:
    case 0n:
      st
    case 1n+p:
      sn_go(p, mode, rb, sn_step(mode, rb, st))

# Group task
# ==========

type GOut is Type:
  GOut{uc: Array<U32>, rbs: Blks}

def gt_split(+nr: U32, st: SN) -> GOut:
  SN{a, uc, tb, rc, e, g, i, phi, plo, valid, ls, gn} = st
  GOut{uc, split_fin(split_go(U32.to_nat(nr), 4294967295, 1, SS{0, 0, e, rc, BNil{}}))}

def gt_pass2(+m: U32, +n: U32, +nr: U32, +rb: RB, a: Array<U32>, uc: Array<U32>,
             r: Array<U32> & U32) -> GOut:
  (rc2, +total) = r
  gt_split(nr, sn_go(U32.to_nat(m), 1, rb,
    SN{a, uc, arr_new(1), rc2, arr_new(total), arr_new(U32.min(n, m)), 0, 0, 0, False{}, 0, 0}))

def gt_pass1(+m: U32, +n: U32, +nr: U32, +rb: RB, st: SN) -> GOut:
  SN{a, uc, tb, rc, e, g, i, phi, plo, valid, ls, gn} = st
  rp = prefix((nr + 1 : U32), rc)
  gt_pass2(m, n, nr, rb, a, uc, rp[nr])

def gt_sorted(+m: U32, +n: U32, +nr: U32, +rb: RB, a: Array<U32>) -> GOut:
  gt_pass1(m, n, nr, rb, sn_go(U32.to_nat(m), 0, rb,
    SN{a, arr_new(n), arr_new(1), arr_new((nr + 1 : U32)), arr_new(1), arr_new(1), 0, 0, 0, False{}, 0, 0}))

def gt_scattered(+m: U32, +n: U32, +nr: U32, +rb: RB, +nsb: U32, st: SC) -> GOut:
  SC{w4, w5, cnt, i} = st
  gt_sorted(m, n, nr, rb, sb_fin(sb_go(U32.to_nat(nsb), SB{w5, cnt, 0, 0})))

def gt_counted(+m: U32, +n: U32, +nr: U32, +rb: RB, +lb: U32, +ls: U32, st: CC) -> GOut:
  CC{w4, cnt, i} = st
  +nsb = shl(1, ls)
  gt_scattered(m, n, nr, rb, nsb,
    sc_go(U32.to_nat(m), lb, ls, SC{w4, arr_new(U32.shln(m, 2n)), prefix((nsb + 1 : U32), cnt), 0}))

def gt_gathered(+m: U32, +n: U32, +nr: U32, +rb: RB, +lb: U32, ww: WW) -> GOut:
  WW{w4, w} = ww
  +dm = F.depth(U32.max(m, 1))
  +ls = U32.min(sel(U32.is_gt(U32.from_nat(dm), 2), (U32.from_nat(dm) - 2 : U32), 0), (32 - lb : U32))
  gt_counted(m, n, nr, rb, lb, ls,
    cc_go(U32.to_nat(m), lb, ls, CC{w4, arr_new((shl(1, ls) + 1 : U32)), 0}))

# One group: m k-mers in runs bs; n samples; nr row blocks laid out by rb.
def group_task(+m: U32, bs: Blks, +n: U32, +nr: U32, +rb: RB, +lb: U32) -> GOut:
  gt_gathered(m, n, nr, rb, lb, gather(bs, WW{arr_new(U32.shln(m, 2n)), 0}))

# Trees of groups (for fork-join)
# ===============================

def apply(-A: Type, -B: Type, body: A -> B, value: A) -> B:
  body(value)

type GT is Type:
  GTNil{}
  GTLeaf{+m: U32, bs: Blks}
  GTNode{l: GT, r: GT}

# The first 2^d groups of xs as a tree, and the rest.
def gq_tree(+d: Nat, xs: GQ) -> GT & GQ:
  match d:
    case 0n:
      match xs:
        case GNil{}:
          (GTNil{}, GNil{})
        case GCon{+m, bs, t}:
          (GTLeaf{m, bs}, t)
    case 1n+p:
      apply(GT & GQ, GT & GQ, \{Tuple: l => rest => (
        apply(GT & GQ, GT & GQ, \{Tuple: r => rest2 => (
          (GTNode{l, r}, rest2)
        )}, gq_tree(p, rest))
      )}, gq_tree(p, xs))

# Parallel group tasks
# ====================

type GOT is Type:
  GONil{}
  GOLeaf{o: GOut}
  GONode{l: GOT, r: GOT}

def got_join(a: GOT, b: GOT) -> GOT:
  GONode{a, b}

def par_groups(gt: GT, +n: U32, +nr: U32, +rb: RB, +lb: U32) -> GOT:
  match gt:
    case GTNil{}:
      GONil{}
    case GTLeaf{+m, bs}:
      GOLeaf{group_task(m, bs, n, nr, rb, lb)}
    case GTNode{l, r}:
      a b = par_groups(l, n, nr, rb, lb) par_groups(r, n, nr, rb, lb)
      got_join(a, b)

# add src[0..n) into dst
type AD is Type:
  AD{src: Array<U32>, dst: Array<U32>, +i: U32}

def ad_r(dst: Array<U32>, +i: U32, r: Array<U32> & U32) -> AD:
  (src, +v) = r
  AD{src, bump(i, v, dst), (i + 1 : U32)}

def ad_step(st: AD) -> AD:
  AD{src, dst, +i} = st
  ad_r(dst, i, src[i])

def ad_go(n: Nat, st: AD) -> AD:
  match n:
    case 0n:
      st
    case 1n+p:
      ad_go(p, ad_step(st))

def ad_fin(st: AD) -> Array<U32>:
  AD{src, dst, i} = st
  dst

def arr_add(+n: U32, src: Array<U32>, dst: Array<U32>) -> Array<U32>:
  ad_fin(ad_go(U32.to_nat(n), AD{src, dst, 0}))

# Collect: unique counts summed into uc; code runs listed per group.
type CO is Type:
  CO{uc: Array<U32>, bl: BL}

def collect(got: GOT, +n: U32, co: CO) -> CO:
  match got co:
    case GONil{} _:
      co
    case GOLeaf{GOut{ouc, rbs}} CO{uc, bl}:
      CO{arr_add(n, ouc, uc), BLCon{rbs, bl}}
    case GONode{l, r} _:
      collect(r, n, collect(l, n, co))

# Sparse row blocks
# =================
#
# A row block accumulates its pair counts in an owned open-addressing hash
# table (linear probing, 2^lg slots of two words: code + 1 (0 = empty) and
# count; load kept <= 1/2). Memory is proportional to the number of pairs
# that share a k-mer, not to n^2.

type HT is Type:
  HT{+lg: U32, +cnt: U32, a: Array<U32>}

def ht_new(+lg: U32) -> HT:
  HT{lg, 0, Array.new(U32, U32.to_nat((lg + 1 : U32)), 0)}

def h_slot(+key: U32, +lg: U32) -> U32:
  shr(U32.mul(key, 2654435761), (32 - lg : U32))

# probe state: go, table, key, add, slot, mask, new (key inserted)
type HP is Type:
  HP{+go: Bool, a: Array<U32>, +key: U32, +d: U32, +i: U32, +mask: U32, +nw: Bool}

def hp_empty(e: Bool, a: Array<U32>, +key: U32, +d: U32, +i: U32, +mask: U32) -> HP:
  match e:
    case True{}:
      +o = U32.shln(i, 1n)
      a1 = a[o] <- key
      HP{False{}, a1[(o + 1 : U32)] <- d, key, d, i, mask, True{}}
    case False{}:
      HP{True{}, a, key, d, U32.and((i + 1 : U32), mask), mask, False{}}

def hp_hit(hit: Bool, +k: U32, a: Array<U32>, +key: U32, +d: U32, +i: U32, +mask: U32) -> HP:
  match hit:
    case True{}:
      HP{False{}, bump((U32.shln(i, 1n) + 1 : U32), d, a), key, d, i, mask, False{}}
    case False{}:
      hp_empty(U32.is_eq(k, 0), a, key, d, i, mask)

def hp_rd(+key: U32, +d: U32, +i: U32, +mask: U32, r: Array<U32> & U32) -> HP:
  (a, +k) = r
  hp_hit(U32.is_eq(k, key), k, a, key, d, i, mask)

def hp_go(fuel: Nat, s: HP) -> HP:
  match fuel s:
    case _ HP{False{}, a, key, d, i, mask, nw}:
      HP{False{}, a, key, d, i, mask, nw}
    case 0n HP{True{}, a, key, d, i, mask, nw}:
      HP{False{}, a, key, d, i, mask, nw}
    case 1n+f HP{True{}, a, +key, +d, +i, +mask, nw}:
      hp_go(f, hp_rd(key, d, i, mask, a[U32.shln(i, 1n)]))

# add d to the count of key (> 0), without growing
def ht_put(+key: U32, +d: U32, +lg: U32, a: Array<U32>) -> HP:
  +i = h_slot(key, lg)
  +mask = (shl(1, lg) - 1 : U32)
  hp_go(U32.to_nat(shl(1, lg)), HP{True{}, a, key, d, i, mask, False{}})

# rehash: every occupied slot of the old table into the new one
type RH is Type:
  RH{old: Array<U32>, a: Array<U32>, +lg: U32, +i: U32}

def rh_fin(old: Array<U32>, +lg: U32, +i: U32, hp: HP) -> RH:
  HP{go, a, key, d, j, mask, nw} = hp
  RH{old, a, lg, (i + 1 : U32)}

def rh_v(a: Array<U32>, +lg: U32, +i: U32, +k: U32, r: Array<U32> & U32) -> RH:
  (old, +v) = r
  rh_fin(old, lg, i, ht_put(k, v, lg, a))

def rh_k(occ: Bool, a: Array<U32>, +lg: U32, +i: U32, +k: U32, old: Array<U32>) -> RH:
  match occ:
    case True{}:
      rh_v(a, lg, i, k, old[(U32.shln(i, 1n) + 1 : U32)])
    case False{}:
      RH{old, a, lg, (i + 1 : U32)}

def rh_rd(a: Array<U32>, +lg: U32, +i: U32, r: Array<U32> & U32) -> RH:
  (old, +k) = r
  rh_k(U32.is_ne(k, 0), a, lg, i, k, old)

def rh_step(st: RH) -> RH:
  RH{old, a, +lg, +i} = st
  rh_rd(a, lg, i, old[U32.shln(i, 1n)])

def rh_go(n: Nat, st: RH) -> RH:
  match n:
    case 0n:
      st
    case 1n+p:
      rh_go(p, rh_step(st))

def rh_tab(st: RH) -> Array<U32>:
  RH{old, a, lg, i} = st
  a

def ht_grow(+lg: U32, +cnt: U32, a: Array<U32>) -> HT:
  +lg2 = (lg + 1 : U32)
  HT{lg2, cnt, rh_tab(rh_go(U32.to_nat(shl(1, lg)),
    RH{a, Array.new(U32, U32.to_nat((lg2 + 1 : U32)), 0), lg2, 0}))}

def ht_chk(big: Bool, +lg: U32, +cnt: U32, a: Array<U32>) -> HT:
  match big:
    case True{}:
      ht_grow(lg, cnt, a)
    case False{}:
      HT{lg, cnt, a}

def ht_added(+lg: U32, +cnt: U32, hp: HP) -> HT:
  HP{go, a, key, d, i, mask, +nw} = hp
  +c2 = (cnt + b2u(nw) : U32)
  ht_chk(U32.is_gt(U32.shln(c2, 1n), shl(1, lg)), lg, c2, a)

# count[code] += d
def ht_add(+code: U32, +d: U32, t: HT) -> HT:
  HT{+lg, +cnt, a} = t
  ht_added(lg, cnt, ht_put((code + 1 : U32), d, lg, a))

def ht_cnt(t: HT) -> HT & U32:
  HT{+lg, +cnt, a} = t
  (HT{lg, cnt, a}, cnt)

type DT is Type:
  DTNil{}
  DTLeaf{+r0: U32, +r1: U32, m: HT}
  DTNode{l: DT, r: DT}

def dt_build(+d: Nat, +r: U32, +rb: RB) -> DT:
  match d:
    case 0n:
      DTLeaf{bound(r, rb), bound((r + 1 : U32), rb), ht_new(10)}
    case 1n+p:
      +h = U32.shln(1, p)
      DTNode{dt_build(p, r, rb), dt_build(p, (r + h : U32), rb)}

# count[c] += 1 for the n codes c of a
type AP is Type:
  AP{a: Array<U32>, m: HT, +i: U32}

def ap_r(m: HT, +i: U32, r: Array<U32> & U32) -> AP:
  (a, +c) = r
  AP{a, ht_add(c, 1, m), (i + 1 : U32)}

def ap_step(st: AP) -> AP:
  AP{a, m, +i} = st
  ap_r(m, i, a[i])

def ap_go(n: Nat, st: AP) -> AP:
  match n:
    case 0n:
      st
    case 1n+p:
      ap_go(p, ap_step(st))

def ap_fin(st: AP) -> HT:
  AP{a, m, i} = st
  m

def ap_blks(bs: Blks, m: HT) -> HT:
  match bs:
    case BNil{}:
      m
    case BCon{Blk{+s, +n, a}, t}:
      ap_blks(t, ap_fin(ap_go(U32.to_nat(n), AP{a, m, 0})))

def dt_join(a: DT, b: DT) -> DT:
  DTNode{a, b}

def par_apply(dt: DT, gt: GT) -> DT:
  match dt gt:
    case DTLeaf{+r0, +r1, m} GTLeaf{+cm, bs}:
      DTLeaf{r0, r1, ap_blks(bs, m)}
    case DTNode{l, r} GTNode{gl, gr}:
      a b = par_apply(l, gl) par_apply(r, gr)
      dt_join(a, b)
    case _ _:
      dt

# Sorting (code, count) records
# =============================

# the occupied slots of a table, as records [code, count] in e
type HX is Type:
  HX{a: Array<U32>, e: Array<U32>, +i: U32, +w: U32}

def hx_v(e: Array<U32>, +i: U32, +w: U32, +k: U32, r: Array<U32> & U32) -> HX:
  (a, +v) = r
  +o = U32.shln(w, 1n)
  e1 = e[o] <- (k - 1 : U32)
  HX{a, e1[(o + 1 : U32)] <- v, (i + 1 : U32), (w + 1 : U32)}

def hx_k(occ: Bool, e: Array<U32>, +i: U32, +w: U32, +k: U32, a: Array<U32>) -> HX:
  match occ:
    case True{}:
      hx_v(e, i, w, k, a[(U32.shln(i, 1n) + 1 : U32)])
    case False{}:
      HX{a, e, (i + 1 : U32), w}

def hx_rd(e: Array<U32>, +i: U32, +w: U32, r: Array<U32> & U32) -> HX:
  (a, +k) = r
  hx_k(U32.is_ne(k, 0), e, i, w, k, a)

def hx_step(st: HX) -> HX:
  HX{a, e, +i, +w} = st
  hx_rd(e, i, w, a[U32.shln(i, 1n)])

def hx_go(n: Nat, st: HX) -> HX:
  match n:
    case 0n:
      st
    case 1n+p:
      hx_go(p, hx_step(st))

def hx_e(st: HX) -> Array<U32>:
  HX{a, e, i, w} = st
  e

def ht_records(t: HT) -> Array<U32>:
  HT{+lg, +cnt, a} = t
  hx_e(hx_go(U32.to_nat(shl(1, lg)), HX{a, arr_new(U32.shln(U32.max(cnt, 1), 1n)), 0, 0}))

# One stable LSD pass on the 11-bit digit at sh: count, prefix, scatter.
def dig(+k: U32, +sh: U32) -> U32:
  U32.and(shr(k, sh), 2047)

type RC is Type:
  RC{e: Array<U32>, cnt: Array<U32>, +i: U32}

def rc_r(cnt: Array<U32>, +i: U32, +sh: U32, r: Array<U32> & U32) -> RC:
  (e, +k) = r
  RC{e, bump((dig(k, sh) + 1 : U32), 1, cnt), (i + 1 : U32)}

def rc_step(+sh: U32, st: RC) -> RC:
  RC{e, cnt, +i} = st
  rc_r(cnt, i, sh, e[U32.shln(i, 1n)])

def rc_go(n: Nat, +sh: U32, st: RC) -> RC:
  match n:
    case 0n:
      st
    case 1n+p:
      rc_go(p, sh, rc_step(sh, st))

type RS2 is Type:
  RS2{e: Array<U32>, f: Array<U32>, cnt: Array<U32>, +i: U32}

def rs_p(e: Array<U32>, f: Array<U32>, +i: U32, +d: U32, +k: U32, +v: U32, r: Array<U32> & U32) -> RS2:
  (cnt, +pos) = r
  +o = U32.shln(pos, 1n)
  f1 = f[o] <- k
  RS2{e, f1[(o + 1 : U32)] <- v, cnt[d] <- (pos + 1 : U32), (i + 1 : U32)}

def rs_v(f: Array<U32>, cnt: Array<U32>, +i: U32, +sh: U32, +k: U32, r: Array<U32> & U32) -> RS2:
  (e, +v) = r
  +d = dig(k, sh)
  rs_p(e, f, i, d, k, v, cnt[d])

def rs_k(f: Array<U32>, cnt: Array<U32>, +i: U32, +sh: U32, r: Array<U32> & U32) -> RS2:
  (e, +k) = r
  rs_v(f, cnt, i, sh, k, e[(U32.shln(i, 1n) + 1 : U32)])

def rs_step(+sh: U32, st: RS2) -> RS2:
  RS2{e, f, cnt, +i} = st
  rs_k(f, cnt, i, sh, e[U32.shln(i, 1n)])

def rs2_go(n: Nat, +sh: U32, st: RS2) -> RS2:
  match n:
    case 0n:
      st
    case 1n+p:
      rs2_go(p, sh, rs_step(sh, st))

type EF is Type:
  EF{e: Array<U32>, f: Array<U32>}

def rs_fin(st: RS2) -> EF:
  RS2{e, f, cnt, i} = st
  EF{f, e}

def rx_counted(+m: U32, +sh: U32, f: Array<U32>, st: RC) -> EF:
  RC{e, cnt, i} = st
  rs_fin(rs2_go(U32.to_nat(m), sh, RS2{e, f, prefix(2049, cnt), 0}))

def rx_pass(+m: U32, +sh: U32, ef: EF) -> EF:
  EF{e, f} = ef
  rx_counted(m, sh, f, rc_go(U32.to_nat(m), sh, RC{e, arr_new(2049), 0}))

# sort the m records of e by code (codes < 2^33, three 11-bit digits)
def ef_e(ef: EF) -> Array<U32>:
  EF{e, f} = ef
  e

def rx_sort(+m: U32, e: Array<U32>) -> Array<U32>:
  ef_e(rx_pass(m, 22, rx_pass(m, 11, rx_pass(m, 0, EF{e, arr_new(U32.shln(U32.max(m, 1), 1n))}))))

# Final scan of a row block
# =========================

# Filters: c >= mink, ani-shorter >= t; k for the formula.
type FP is Data:
  FP{+mink: U32, +k: U32, +t: N.Thr, +maxs: U32}

def put_digits(fuel: Nat, +v: U32, xs: List<&2, U32>) -> List<&2, U32>:
  match fuel:
    case 0n:
      xs
    case 1n+p:
      put_digits(p, U32.div(v, 10), Con{(U32.mod(v, 10) + 48 : U32), xs})

def ndigits(+v: U32) -> U32:
  (1 + b2u(U32.is_ge(v, 10)) + b2u(U32.is_ge(v, 100)) + b2u(U32.is_ge(v, 1000)) + b2u(U32.is_ge(v, 10000))
     + b2u(U32.is_ge(v, 100000)) + b2u(U32.is_ge(v, 1000000)) + b2u(U32.is_ge(v, 10000000))
     + b2u(U32.is_ge(v, 100000000)) + b2u(U32.is_ge(v, 1000000000)) : U32)

# "<v>" before xs
def put_num(+v: U32, xs: List<&2, U32>) -> List<&2, U32>:
  put_digits(U32.to_nat(ndigits(v)), v, xs)

# "<j>:<x/1e6 with 6 decimals>," before xs
def put_entry(+j: U32, +x: U32, xs: List<&2, U32>) -> List<&2, U32>:
  +one = U32.is_ge(x, 1000000)
  +frac = put_digits(6n, sel(one, 0, x), Con{44, xs})
  put_num(j, Con{58, Con{sel(one, 49, 48), Con{46, frac}}})

def fp_k(p: FP) -> U32:
  FP{+mink, +k, +t, +maxs} = p
  k

def fp_mink(p: FP) -> U32:
  FP{+mink, +k, +t, +maxs} = p
  mink

# Row b's entries are the records with code >= (b - r0) * n at the end of
# the sorted records [0, j); they are consumed from the end, so consing
# yields ascending a.
type FR is Type:
  FR{+go: Bool, e: Array<U32>, uc: Array<U32>, row: List<&2, U32>, +j: U32}

# Without --max-seqs a kept entry is its output text; with it, the words
# a, c, m, x (for the per-row selection that follows).
def fr_keep(ok: Bool, raw: Bool, +a: U32, +c: U32, +mn: U32, +x: U32, row: List<&2, U32>) -> List<&2, U32>:
  match ok raw:
    case True{} False{}:
      put_entry((a + 1 : U32), x, row)
    case True{} True{}:
      Con{a, Con{c, Con{mn, Con{x, row}}}}
    case False{} _:
      row

def fr_ani(+a: U32, +c: U32, +mn: U32, +p: FP, +an: N.Ani, row: List<&2, U32>) -> List<&2, U32>:
  FP{+mink, +k, +t, +maxs} = p
  N.Thr{+one, +fx} = t
  fr_keep(N.ani_ge(an, one, fx), U32.is_ne(maxs, 0), a, c, mn, N.ani_x(an), row)

def fr_u(e: Array<U32>, row: List<&2, U32>, +a: U32, +c: U32, +ub: U32, +p: FP, +j: U32,
         r: Array<U32> & U32) -> FR:
  (uc, +ua) = r
  +mn = U32.min(ua, ub)
  FR{U32.is_gt(j, 0), e, uc, fr_ani(a, c, mn, p, N.ani(c, mn, fp_k(p)), row), j}

def fr_c(go: Bool, e: Array<U32>, uc: Array<U32>, row: List<&2, U32>, +a: U32, +c: U32, +ub: U32, +p: FP,
         +j: U32) -> FR:
  match go:
    case True{}:
      fr_u(e, row, a, c, ub, p, j, uc[a])
    case False{}:
      FR{U32.is_gt(j, 0), e, uc, row, j}

def fr_v(uc: Array<U32>, row: List<&2, U32>, +a: U32, +ub: U32, +p: FP, +j: U32, r: Array<U32> & U32) -> FR:
  (e, +c) = r
  fr_c(U32.is_gt(c, 0) && U32.is_ge(c, fp_mink(p)), e, uc, row, a, c, ub, p, j)

def fr_in(inr: Bool, e: Array<U32>, uc: Array<U32>, row: List<&2, U32>, +code: U32, +base: U32, +ub: U32,
          +p: FP, +j: U32) -> FR:
  match inr:
    case True{}:
      +j1 = (j - 1 : U32)
      fr_v(uc, row, (code - base : U32), ub, p, j1, e[(U32.shln(j1, 1n) + 1 : U32)])
    case False{}:
      FR{False{}, e, uc, row, j}

def fr_k(uc: Array<U32>, row: List<&2, U32>, +base: U32, +ub: U32, +p: FP, +j: U32, r: Array<U32> & U32) -> FR:
  (e, +code) = r
  fr_in(U32.is_ge(code, base), e, uc, row, code, base, ub, p, j)

def fr_go(fuel: Nat, +base: U32, +ub: U32, +p: FP, s: FR) -> FR:
  match fuel s:
    case _ FR{False{}, e, uc, row, j}:
      FR{False{}, e, uc, row, j}
    case 0n FR{True{}, e, uc, row, j}:
      FR{False{}, e, uc, row, j}
    case 1n+f FR{True{}, e, uc, row, +j}:
      fr_go(f, base, ub, p, fr_k(uc, row, base, ub, p, j, e[U32.shln((j - 1 : U32), 1n)]))

type FO is Type:
  FO{e: Array<U32>, uc: Array<U32>, rows: List<&2, List<&2, U32>>, +b: U32, +j: U32}

def fo_fin(rows: List<&2, List<&2, U32>>, +b: U32, st: FR) -> FO:
  FR{go, e, uc, row, +j} = st
  FO{e, uc, Con{row, rows}, b, j}

def fo_r(e: Array<U32>, rows: List<&2, List<&2, U32>>, +b: U32, +j: U32, +r0: U32, +n: U32, +p: FP,
         r: Array<U32> & U32) -> FO:
  (uc, +ub) = r
  fo_fin(rows, b, fr_go(U32.to_nat(j), U32.mul((b - r0 : U32), n), ub, p, FR{U32.is_gt(j, 0), e, uc, Nil{}, j}))

def fo_step(+r0: U32, +n: U32, +p: FP, st: FO) -> FO:
  FO{e, uc, rows, +b0, +j} = st
  +b = (b0 - 1 : U32)
  fo_r(e, rows, b, j, r0, n, p, uc[b])

def fo_go(fuel: Nat, +r0: U32, +n: U32, +p: FP, st: FO) -> FO:
  match fuel:
    case 0n:
      st
    case 1n+q:
      fo_go(q, r0, n, p, fo_step(r0, n, p, st))

def fo_rows(st: FO) -> List<&2, List<&2, U32>>:
  FO{e, uc, rows, b, j} = st
  rows

def block_sorted(+r0: U32, +r1: U32, +m: U32, +n: U32, e: Array<U32>, uc: Array<U32>, +p: FP)
    -> List<&2, List<&2, U32>>:
  fo_rows(fo_go(U32.to_nat((r1 - r0 : U32)), r0, n, p, FO{e, uc, Nil{}, r1, m}))

# The output rows r0 .. r1-1 of a block (entry lists, without names).
def block_rows(+r0: U32, +r1: U32, +n: U32, t: HT, uc: Array<U32>, +p: FP) -> List<&2, List<&2, U32>>:
  HT{+lg, +m, a} = t
  block_sorted(r0, r1, m, n, rx_sort(m, ht_records(HT{lg, m, a})), uc, p)

type RT is Data:
  RTNil{}
  RTLeaf{rows: List<&2, List<&2, U32>>}
  RTNode{l: RT, r: RT}

def rt_join(a: RT, b: RT) -> RT:
  RTNode{a, b}

def par_final(dt: DT, uc: Array<U32>, +n: U32, +p: FP) -> RT:
  match dt:
    case DTNil{}:
      RTNil{}
    case DTLeaf{+r0, +r1, m}:
      RTLeaf{block_rows(r0, r1, n, m, uc, p)}
    case DTNode{l, r}:
      apply(Array<U32> & Array<U32>, RT, \{Tuple: u1 => u2 => (
        a b = par_final(l, u1, n, p) par_final(r, u2, n, p)
        rt_join(a, b)
      )}, F.copy(n, 0, 0, uc, arr_new(n)))

# Samples tree
# ============

# The next cnt records as a leaf list (in order).
def sl_take(n: Nat, xs: F.Raws, acc: SL) -> SL & F.Raws:
  match n:
    case 0n:
      (sl_rev(acc, SLNil{}), xs)
    case 1n+p:
      match xs:
        case F.RawNil{}:
          (sl_rev(acc, SLNil{}), F.RawNil{})
        case F.RawCon{h, t}:
          F.Raw{+len, codes, +segs} = h
          sl_take(p, t, SLCon{codes, segs, acc})

def st_leaf(empty: Bool, +lo: U32, +cnt: U32, xs: F.Raws) -> ST & F.Raws:
  match empty:
    case True{}:
      (STNil{}, xs)
    case False{}:
      apply(SL & F.Raws, ST & F.Raws, \{Tuple: ss => rest => (
        (STLeaf{lo, cnt, ss, arr_new(1)}, rest)
      )}, sl_take(U32.to_nat(cnt), xs, SLNil{}))

# A balanced tree of the next cnt records over 2^d leaves (chunks of
# consecutive samples), indices from lo.
def build_st(+d: Nat, +lo: U32, +cnt: U32, xs: F.Raws) -> ST & F.Raws:
  match d:
    case 0n:
      st_leaf(U32.is_eq(cnt, 0), lo, cnt, xs)
    case 1n+p:
      +nl = U32.shrn((cnt + 1 : U32), 1n)
      +nr = (cnt - nl : U32)
      apply(ST & F.Raws, ST & F.Raws, \{Tuple: l => rest => (
        apply(ST & F.Raws, ST & F.Raws, \{Tuple: r => rest2 => (
          (STNode{l, r}, rest2)
        )}, build_st(p, (lo + nl : U32), nr, rest))
      )}, build_st(p, lo, nl, xs))

# Passes of one batch
# ===================

# Layout: P = 2^lp passes, Q = 2^lq groups, R = 2^lr row blocks.
type LY is Data:
  LY{+lp: U32, +lq: U32, +lr: U32, +n: U32}

type BS is Type:
  BS{st: ST, uc: Array<U32>, dt: DT, +p: U32}

def bs_applied(st: ST, uc: Array<U32>, dt: DT, +p: U32, +ly: LY, +rb: RB, co: CO) -> BS:
  LY{+lp, +lq, +lr, +n} = ly
  CO{uc2, bl} = co
  apply(GT & GQ, BS, \{Tuple: gt => rest => (
    BS{st, arr_add(n, uc2, uc), par_apply(dt, gt), (p + 1 : U32)}
  )}, gq_tree(U32.to_nat(lr), transpose(bl, gq_new(U32.to_nat(shl(1, lr))))))

def bs_passed(uc: Array<U32>, dt: DT, +p: U32, +ly: LY, +rb: RB, pr: PR) -> BS:
  LY{+lp, +lq, +lr, +n} = ly
  PR{st, bt} = pr
  apply(GT & GQ, BS, \{Tuple: gt => rest => (
    bs_applied(st, uc, dt, p, ly, rb,
      collect(par_groups(gt, n, shl(1, lr), rb, (lp + lq : U32)), n, CO{arr_new(n), BLNil{}}))
  )}, gq_tree(U32.to_nat(lq), transpose(bt_flat(bt, BLNil{}), gq_new(U32.to_nat(shl(1, lq))))))

def bs_step(+c: Cfg, +ly: LY, +rb: RB, s: BS) -> BS:
  LY{+lp, +lq, +lr, +n} = ly
  BS{st, uc, dt, +p} = s
  bs_passed(uc, dt, p, ly, rb, par_pass(st, 1, cfg_pass(c, p), shl(1, lq), shl(1, (lp + lq : U32))))

def bs_go(n: Nat, +c: Cfg, +ly: LY, +rb: RB, s: BS) -> BS:
  match n:
    case 0n:
      s
    case 1n+q:
      bs_go(q, c, ly, rb, bs_step(c, ly, rb, s))

type BR is Type:
  BR{st: ST, rows: RT}

def br_fin(+ly: LY, +fp: FP, s: BS) -> BR:
  LY{+lp, +lq, +lr, +n} = ly
  BS{st, uc, dt, p} = s
  BR{st, par_final(dt, uc, n, fp)}

# One batch of rows [b0, b1): all passes, then the filtered rows.
def run_batch(st: ST, +c: Cfg, +ly: LY, +fp: FP, +b0: U32, +b1: U32) -> BR:
  LY{+lp, +lq, +lr, +n} = ly
  +rb = rb_make(b0, b1, n, shl(1, lr))
  br_fin(ly, fp, bs_go(U32.to_nat(shl(1, lp)), c, ly, rb,
    BS{st, arr_new(n), dt_build(U32.to_nat(lr), 0, rb), 0}))

def pr_st(pr: PR) -> ST:
  PR{st, bt} = pr
  st

# The count pass (fills every sample's bucket counts).
def count_pass(st: ST, +c: Cfg, +ly: LY) -> ST:
  LY{+lp, +lq, +lr, +n} = ly
  pr_st(par_pass(st, 0, c, shl(1, lq), shl(1, (lp + lq : U32))))

