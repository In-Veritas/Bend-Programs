# Kmer-db 2.3.1 k-mer extraction of one sample (kmer_extract.h, filter.h).
#
# KmerHelper::extract: rolling forward / reverse-complement 2k-bit k-mers,
# canonical = min, widened to an 8-bit prefix when 2k - 32 < 8
# ((x << s) | (x & (2^s - 1)), s = 40 - 2k), kept when the MinHash filter
# accepts it (only with -f < 1); then KmerHelper::sortAndUnique. The sample
# arrives as valid-base segments (pf_fasta), which is the same as the
# omit_next_n_kmers skipping of k-mers that cover an invalid symbol.
#
# Output: the sorted unique k-mers as 2-word records (hi, lo) =
# (prefix, suffix) of the widened 64-bit k-mer (SUFFIX_BITS = 32).
import Base
import ./pf_fasta.bend as F
import ./pf_num.bend as N
import ./kdb_util.bend as K
import ./kdb_sort.bend as S

# k, masks / units of the rolling k-mer, MinHash parameters, widening shift.
type Cfg is Data:
  Cfg{+k: U32, +himask: U32, +lomask: U32, +rhu: U32, +rlu: U32, +usef: Bool, +th: N.W2,
      +kd4: U32, +psh: U32}

def cfg_mk(+k: U32, t: N.Thr, +dv: N.DV) -> Cfg:
  N.Thr{+one, +fx} = t
  Cfg{k, K.sel(U32.is_ge(k, 16), (K.shl(1, K.sel(U32.is_ge(k, 16), (U32.mul(k, 2) - 32 : U32), 0)) - 1 : U32), 0),
      K.sel(U32.is_ge(k, 16), 4294967295, (K.shl(1, U32.mul(k, 2)) - 1 : U32)),
      K.sel(U32.is_ge(k, 17), K.shl(1, K.sel(U32.is_ge(k, 17), (U32.mul(k, 2) - 34 : U32), 0)), 0),
      K.sel(U32.is_le(k, 16), K.shl(1, (U32.mul(k, 2) - 2 : U32)), 0),
      Bool.not(one), N.frac_threshold(dv), U32.shrn((k + 3 : U32), 2n),
      K.sel(U32.is_lt(k, 20), (40 - U32.mul(k, 2) : U32), 0)}

def cfg_of(+k: U32, frac: String) -> Cfg:
  +dv = N.dec_value(N.dec_parse(frac))
  cfg_mk(k, N.thr_of(dv), dv)

# prefix bits of the k-mer database: max(8, 2k - 32)
def prefix_bits(+k: U32) -> U32:
  U32.max(8, U32.sub(U32.max(U32.mul(k, 2), 32), 32))

# The action on one canonical k-mer
# =================================

type XS is Type:
  XS{out: Array<U32>, +pos: U32}

def keep(go: Bool, +whi: U32, +wlo: U32, x: XS) -> XS:
  match go:
    case False{}:
      x
    case True{}:
      XS{out, +pos} = x
      XS{S.put2(out, pos, whi, wlo), (pos + 1 : U32)}

def filt(usef: Bool, +w: N.W2, +kd4: U32, +th: N.W2) -> Bool:
  match usef:
    case False{}:
      True{}
    case True{}:
      N.lt64(N.minhash(w, kd4), th)

def keep_w(+w: N.W2, +c: Cfg, x: XS) -> XS:
  N.W2{+whi, +wlo} = w
  Cfg{+k, +himask, +lomask, +rhu, +rlu, +usef, +th, +kd4, +psh} = c
  keep(filt(usef, w, kd4, th), whi, wlo, x)

def act(+khi: U32, +klo: U32, +c: Cfg, x: XS) -> XS:
  Cfg{+k, +himask, +lomask, +rhu, +rlu, +usef, +th, +kd4, +psh} = c
  keep_w(N.add64(N.shl64(N.W2{khi, klo}, psh), N.W2{0, U32.and(klo, (K.shl(1, psh) - 1 : U32))}), c, x)

def act_if(go: Bool, +khi: U32, +klo: U32, +c: Cfg, x: XS) -> XS:
  match go:
    case False{}:
      x
    case True{}:
      act(khi, klo, c, x)

# Rolling extraction (16 bases per packed word)
# =============================================

type RS is Type:
  RS{+fhi: U32, +flo: U32, +rhi: U32, +rlo: U32, +v: U32, x: XS}

def ext_word(n: Nat, +w: U32, +v: U32, +fhi: U32, +flo: U32, +rhi: U32, +rlo: U32,
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
      ext_word(p, U32.shrn(w, 2n), (v + 1 : U32), nfhi, nflo, nrhi, nrlo, hm, lm, rhu, rlu, k1, c,
        act_if(U32.is_ge(v, k1), K.sel(fwd, nfhi, nrhi), K.sel(fwd, nflo, nrlo), c, x))

type CX is Type:
  CX{codes: Array<U32>, x: XS}

def ext_seg(nw: Nat, +wi: U32, +rem: U32, +hm: U32, +lm: U32, +rhu: U32, +rlu: U32,
            +k1: U32, +c: Cfg, rs: RS, r: Array<U32> & U32) -> CX:
  match nw rs:
    case 0n RS{fhi, flo, rhi, rlo, v, x}:
      (codes, _w) = r
      CX{codes, x}
    case 1n+p RS{+fhi, +flo, +rhi, +rlo, +v, x}:
      (codes, +w) = r
      +j = (wi + 1 : U32)
      ext_seg(p, j, (rem - 16 : U32), hm, lm, rhu, rlu, k1, c,
        ext_word(U32.to_nat(U32.min(rem, 16)), w, v, fhi, flo, rhi, rlo, hm, lm, rhu, rlu, k1, c, x),
        codes[j])

def seg_run(+w0: U32, +len: U32, +c: Cfg, codes: Array<U32>, x: XS) -> CX:
  Cfg{+k, +himask, +lomask, +rhu, +rlu, +usef, +th, +kd4, +psh} = c
  ext_seg(U32.to_nat(U32.shrn((len + 15 : U32), 4n)), w0, len, himask, lomask, rhu, rlu,
    (k - 1 : U32), c, RS{0, 0, 0, 0, 0, x}, codes[w0])

def ext_segs(segs: F.Seg, +c: Cfg, cx: CX) -> CX:
  match segs cx:
    case F.SegNil{} _:
      cx
    case F.SegCon{+w0, +len, t} CX{codes, x}:
      ext_segs(t, c, seg_run(w0, len, c, codes, x))

# upper bound of the k-mers of a sample: sum of (len - k + 1) over segments
def seg_kmers(segs: F.Seg, +k: U32, +acc: U32) -> U32:
  match segs:
    case F.SegNil{}:
      acc
    case F.SegCon{+w0, +len, t}:
      seg_kmers(t, k, (acc + U32.sub(U32.max(len, (k - 1 : U32)), (k - 1 : U32)) : U32))

# A sample: its unique k-mer count and the sorted unique k-mers.
type Smp is Type:
  Smp{+nk: U32, km: Array<U32>}

def smp_of(r: S.AN) -> Smp:
  S.AN{a, +n} = r
  Smp{n, a}

def extracted(cx: CX) -> Smp:
  CX{codes, x} = cx
  XS{out, +pos} = x
  smp_of(S.sort_unique(pos, out))

def extract(+c: Cfg, raw: F.Raw) -> Smp:
  Cfg{+k, +himask, +lomask, +rhu, +rlu, +usef, +th, +kd4, +psh} = c
  F.Raw{+len, codes, +segs} = raw
  +m = seg_kmers(segs, k, 0)
  extracted(ext_segs(segs, c, CX{codes, XS{K.arr_new(U32.shln(U32.max(m, 1), 1n)), 0}}))
