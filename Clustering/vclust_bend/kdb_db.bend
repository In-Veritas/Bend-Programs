# Kmer-db 2.3.1 PrefixKmerDb (prefix_kmer_db.{h,cpp}, pattern.{h,cpp}).
#
# The database of a build:
#   hashtables  one hash_map_lp<suffix_t, pattern_id_t> per k-mer prefix
#               (prefix = k-mer >> 32, max(8, 2k - 32) bits): a generic
#               Array<PT> of 2^prefix_bits slots, a table created on the
#               first k-mer of its prefix (upstream allocates all of them);
#   patterns    pattern_t: num_kmers, parent_id, num_samples,
#               num_local_samples, is_parent and the local samples (the
#               samples added to the pattern itself, the rest is inherited
#               from the parent chain);
#   samples     added one after another (PrefixKmerDb::addKmers).
#
# addKmers(sample s, its sorted unique k-mers):
#   1. hashtableJob: for each prefix run of the sample, reserve_for_additional
#      on its table, then find_item for every k-mer; a new k-mer is inserted
#      with pattern 0; samplePatterns[i] = (pattern id, its table slot).
#   2. samplePatterns sorted by pattern id.
#   3. patternJob: for every run of equal pattern id p (pid_count k-mers):
#      if patterns[p].num_kmers == pid_count and p is not a parent, p is
#      extended in place with s; otherwise a new pattern (parent p when p
#      has samples, local sample s, pid_count k-mers) takes the k-mers,
#      patterns[p].num_kmers -= pid_count (p != 0), and the table entries of
#      the run are set to the new id (upstream writes through the saved
#      pointers; here through the saved slots, by a second pass over the
#      sample's prefix runs).
#
# Storage: patterns are 8-word records of one Array<U32> (num_kmers,
# parent (2^32 - 1 = -1), num_samples, num_local_samples, last local
# sample node, is_parent); local samples are nodes (sample, previous node)
# of an arena instead of pattern_t's Elias-gamma delta bit-stream (same
# sequence, uncompressed). Arrays grow by doubling (vector reallocation).
import Base
import ./pf_fasta.bend as F
import ./kdb_util.bend as K
import ./kdb_sort.bend as S
import ./kdb_hash.bend as H

# hash_map_lp<suffix_t, pattern_id_t>::empty_value
def ev() -> U32:
  2147483647

type PT is Type:
  PNil{}
  PLeaf{h: H.HM}
  PNode{l: PT, r: PT}

def pt_hm(t: PT) -> H.HM:
  match t:
    case PLeaf{h}:
      h
    case PNil{}:
      H.hm_new(ev())
    case PNode{l, r}:
      H.hm_new(ev())

# Per-sample arrays: km = the sorted unique k-mers (prefix, suffix);
# ps = samplePatterns: (pattern id, table slot) per k-mer.
type St is Type:
  St{km: Array<U32>, ps: Array<U32>}

# hashtableJob on one prefix
# =========================

type LA is Type:
  LA{h: H.HM, st: St, +i: U32}

def la_put(isnew: Bool, +i: U32, +suf: U32, +filled: U32, +cap: U32, km: Array<U32>, ps: Array<U32>,
           a: Array<U32>, +slot: U32, +v: U32) -> LA:
  match isnew:
    case True{}:
      LA{H.HM{(filled + 1 : U32), cap, S.put2(a, slot, suf, 0)}, St{km, S.put2(ps, i, 0, slot)}, (i + 1 : U32)}
    case False{}:
      LA{H.HM{filled, cap, a}, St{km, S.put2(ps, i, v, slot)}, (i + 1 : U32)}

def la_found(+i: U32, +suf: U32, +filled: U32, +cap: U32, km: Array<U32>, ps: Array<U32>, f: H.FS) -> LA:
  H.FS{a, +slot, +v, go} = f
  la_put(U32.is_eq(v, ev()), i, suf, filled, cap, km, ps, a, slot, v)

def la_k(h: H.HM, ps: Array<U32>, +i: U32, g: S.A2) -> LA:
  H.HM{+filled, +cap, a} = h
  S.A2{km, +pre, +suf} = g
  la_found(i, suf, filled, cap, km, ps, H.find_item(a, cap, suf, ev()))

def la_go(n: Nat, la: LA) -> LA:
  match n la:
    case 0n _:
      la
    case 1n+p LA{h, St{km, ps}, +i}:
      la_go(p, la_k(h, ps, i, S.get2(km, i)))

def la_fin(la: LA) -> PT & St:
  LA{h, st, i} = la
  (PLeaf{h}, st)

def leaf_find(t: PT, +lo: U32, +hi: U32, st: St) -> PT & St:
  +n = (hi - lo : U32)
  la_fin(la_go(U32.to_nat(n), LA{H.reserve(n, ev(), pt_hm(t)), st, lo}))

# Pattern id write-back on one prefix (*samplePatterns[k].second = id)
# =================================================================

type LC is Type:
  LC{a: Array<U32>, st: St, +i: U32}

def lc_k(a: Array<U32>, km: Array<U32>, +i: U32, g: S.A2) -> LC:
  S.A2{ps, +np, +slot} = g
  LC{a[(U32.shln(slot, 1n) + 1 : U32)] <- np, St{km, ps}, (i + 1 : U32)}

def lc_go(n: Nat, lc: LC) -> LC:
  match n lc:
    case 0n _:
      lc
    case 1n+p LC{a, St{km, ps}, +i}:
      lc_go(p, lc_k(a, km, i, S.get2(ps, i)))

def lc_fin(+filled: U32, +cap: U32, lc: LC) -> PT & St:
  LC{a, st, i} = lc
  (PLeaf{H.HM{filled, cap, a}}, st)

def leaf_write_h(h: H.HM, +lo: U32, +hi: U32, st: St) -> PT & St:
  H.HM{+filled, +cap, a} = h
  lc_fin(filled, cap, lc_go(U32.to_nat((hi - lo : U32)), LC{a, st, lo}))

def leaf_write(t: PT, +lo: U32, +hi: U32, st: St) -> PT & St:
  leaf_write_h(pt_hm(t), lo, hi, st)

def leaf_op(find: Bool, t: PT, +lo: U32, +hi: U32, st: St) -> PT & St:
  match find:
    case True{}:
      leaf_find(t, lo, hi, st)
    case False{}:
      leaf_write(t, lo, hi, st)

# The hashtables vector
# =====================
#
# hashtables[prefix]: a generic Array<PT> of 2^prefix_bits slots (PNil until
# the prefix's first k-mer). A sample is processed prefix run by prefix
# run, in k-mer order (hashtableJob's loop over [lo, hi)).

def tab_new(+d: Nat) -> Array<PT>:
  match d:
    case 0n:
      ALeaf{PNil{}}
    case 1n+p:
      ANode{tab_new(p), tab_new(p)}

# end of the prefix run starting at i: first j > i with another prefix
type RE2 is Type:
  RE2{km: Array<U32>, +j: U32, +go: Bool}

def r2_s(+p: U32, +j: U32, +n: U32, r: Array<U32> & U32) -> RE2:
  (km, +q) = r
  +same = U32.is_eq(q, p)
  RE2{km, K.sel(same, (j + 1 : U32), j), same && U32.is_lt((j + 1 : U32), n)}

def r2_go(f: Nat, +p: U32, +n: U32, st: RE2) -> RE2:
  match f st:
    case 0n _:
      st
    case 1n+q RE2{km, +j, +go}:
      match go:
        case True{}:
          r2_go(q, p, n, r2_s(p, j, n, km[U32.shln(j, 1n)]))
        case False{}:
          RE2{km, j, False{}}

type RL is Type:
  RL{tab: Array<PT>, st: St, +i: U32, +go: Bool}

def rl_done(tab: Array<PT>, +p: U32, +j: U32, +n: U32, r: PT & St) -> RL:
  (t, st) = r
  RL{Array.set(PT, tab, p, t), st, j, U32.is_lt(j, n)}

def rl_swap(+find: Bool, +p: U32, +i: U32, +j: U32, +n: U32, st: St, r: Array<PT> & PT) -> RL:
  (tab, t) = r
  rl_done(tab, p, j, n, leaf_op(find, t, i, j, st))

def rl_end(+find: Bool, tab: Array<PT>, ps: Array<U32>, +p: U32, +i: U32, +n: U32, re: RE2) -> RL:
  RE2{km, +j, go} = re
  rl_swap(find, p, i, j, n, St{km, ps}, Array.swap(PT, tab, p, PNil{}))

def rl_run(+find: Bool, tab: Array<PT>, ps: Array<U32>, +i: U32, +n: U32, r: Array<U32> & U32) -> RL:
  (km, +p) = r
  rl_end(find, tab, ps, p, i, n, r2_go(U32.to_nat(n), p, n, RE2{km, (i + 1 : U32), U32.is_lt((i + 1 : U32), n)}))

def rl_go(f: Nat, +find: Bool, +n: U32, st: RL) -> RL:
  match f st:
    case 0n _:
      st
    case 1n+q RL{tab, St{km, ps}, +i, +go}:
      match go:
        case True{}:
          rl_go(q, find, n, rl_run(find, tab, ps, i, n, km[U32.shln(i, 1n)]))
        case False{}:
          RL{tab, St{km, ps}, i, False{}}

def rl_fin(st: RL) -> Array<PT> & St:
  RL{tab, s, i, go} = st
  (tab, s)

# every prefix run of the n sorted k-mers: find (hashtableJob) or write back
def runs(+find: Bool, tab: Array<PT>, +n: U32, st: St) -> Array<PT> & St:
  rl_fin(rl_go(U32.to_nat(n), find, n, RL{tab, st, 0, U32.is_lt(0, n)}))

# Patterns
# ========

type PS is Type:
  PS{pat: Array<U32>, +np: U32, +pcap: U32, nod: Array<U32>, +nn: U32, +ncap: U32}

def pset(a: Array<U32>, +p: U32, +f: U32, +v: U32) -> Array<U32>:
  a[(U32.shln(p, 3n) + f : U32)] <- v

def pget(a: Array<U32>, +p: U32, +f: U32) -> Array<U32> & U32:
  a[(U32.shln(p, 3n) + f : U32)]

# pattern 0 (the empty pattern) at capacity cap
def ps_new(+pcap: U32, +ncap: U32) -> PS:
  +z = K.none()
  pat = Array.new(U32, F.depth(U32.shln(pcap, 3n)), 0)
  PS{pset(pset(pat, 0, 1, z), 0, 4, z), 1, pcap, Array.new(U32, F.depth(U32.shln(ncap, 1n)), 0), 0, ncap}

# capacity doubling until need fits (vector reallocation)
def cap_go(fuel: Nat, ok: Bool, +need: U32, +cap: U32) -> U32:
  match fuel ok:
    case 0n _:
      cap
    case 1n+p True{}:
      cap
    case 1n+p False{}:
      +c2 = U32.shln(cap, 1n)
      cap_go(p, U32.is_le(need, c2), need, c2)

def cap_for(fuel: Nat, +need: U32, +cap: U32) -> U32:
  cap_go(fuel, U32.is_le(need, cap), need, cap)

def cp_fin(r: Array<U32> & Array<U32>) -> Array<U32>:
  (old, nw) = r
  nw

def copy_s(same: Bool, +n: U32, +nsize: U32, a: Array<U32>) -> Array<U32>:
  match same:
    case True{}:
      a
    case False{}:
      cp_fin(F.copy(n, 0, 0, a, Array.new(U32, F.depth(nsize), 0)))

# room for m more patterns and nodes
def ps_room(+m: U32, ps: PS) -> PS:
  PS{pat, +np, +pcap, nod, +nn, +ncap} = ps
  +pc2 = cap_for(32n, (np + m : U32), pcap)
  +nc2 = cap_for(32n, (nn + m : U32), ncap)
  PS{copy_s(U32.is_eq(pc2, pcap), U32.shln(np, 3n), U32.shln(pc2, 3n), pat), np, pc2,
     copy_s(U32.is_eq(nc2, ncap), U32.shln(nn, 1n), U32.shln(nc2, 1n), nod), nn, nc2}

# patternJob
# ----------

type PJ is Type:
  PJ{sp: Array<U32>, ps: Array<U32>, pt: PS, +i: U32, +go: Bool}

# end of the run of pattern p from j
type RE is Type:
  RE{sp: Array<U32>, +j: U32, +go: Bool}

def re_s(+p: U32, +j: U32, +n: U32, g: S.A2) -> RE:
  S.A2{sp, +q, +idx} = g
  +same = U32.is_eq(q, p)
  RE{sp, K.sel(same, (j + 1 : U32), j), same && U32.is_lt((j + 1 : U32), n)}

def re_go(f: Nat, +p: U32, +n: U32, st: RE) -> RE:
  match f st:
    case 0n _:
      st
    case 1n+q RE{sp, +j, +go}:
      match go:
        case True{}:
          re_go(q, p, n, re_s(p, j, n, S.get2(sp, j)))
        case False{}:
          RE{sp, j, False{}}

# ps[sp[k].idx].pid = id for k in [i, j)
type MK is Type:
  MK{sp: Array<U32>, ps: Array<U32>, +k: U32}

def mk_s(+id: U32, +k: U32, ps: Array<U32>, g: S.A2) -> MK:
  S.A2{sp, +q, +idx} = g
  MK{sp, ps[U32.shln(idx, 1n)] <- id, (k + 1 : U32)}

def mk_go(f: Nat, +id: U32, st: MK) -> MK:
  match f st:
    case 0n _:
      st
    case 1n+q MK{sp, ps, +k}:
      mk_go(q, id, mk_s(id, k, ps, S.get2(sp, k)))

def mk_fin(pt: PS, +j: U32, +n: U32, st: MK) -> PJ:
  MK{sp, ps, k} = st
  PJ{sp, ps, pt, j, U32.is_lt(j, n)}

def mark(sp: Array<U32>, ps: Array<U32>, pt: PS, +id: U32, +i: U32, +j: U32, +n: U32) -> PJ:
  mk_fin(pt, j, n, mk_go(U32.to_nat((j - i : U32)), id, MK{sp, ps, i}))

# expand(s): the pattern p itself takes sample s
def pj_ext2(+s: U32, +p: U32, +ns: U32, +nl: U32, sp: Array<U32>, ps: Array<U32>, +np: U32, +pcap: U32,
            nod: Array<U32>, +nn: U32, +ncap: U32, +i: U32, +j: U32, +n: U32, r: Array<U32> & U32) -> PJ:
  (pat, +head) = r
  pat2 = pset(pset(pset(pat, p, 2, (ns + 1 : U32)), p, 3, (nl + 1 : U32)), p, 4, nn)
  mark(sp, ps, PS{pat2, np, pcap, S.put2(nod, nn, s, head), (nn + 1 : U32), ncap}, p, i, j, n)

def pj_ext(+s: U32, +p: U32, +ns: U32, sp: Array<U32>, ps: Array<U32>, +np: U32, +pcap: U32,
           nod: Array<U32>, +nn: U32, +ncap: U32, +i: U32, +j: U32, +n: U32, r: Array<U32> & U32) -> PJ:
  (pat, +nl) = r
  pj_ext2(s, p, ns, nl, sp, ps, np, pcap, nod, nn, ncap, i, j, n, pget(pat, p, 4))

def set_if(c: Bool, a: Array<U32>, +p: U32, +f: U32, +v: U32) -> Array<U32>:
  match c:
    case True{}:
      pset(a, p, f, v)
    case False{}:
      a

# pattern_t(patterns[p], p, s, pid_count): a new pattern
def pj_new(+s: U32, +p: U32, +nk: U32, +ns: U32, +c: U32, sp: Array<U32>, ps: Array<U32>, pat: Array<U32>,
           +np: U32, +pcap: U32, nod: Array<U32>, +nn: U32, +ncap: U32, +i: U32, +j: U32, +n: U32) -> PJ:
  +has = U32.is_ne(ns, 0)
  +q = np
  p1 = pset(pset(pset(pset(pset(pset(pat, q, 0, c), q, 1, K.sel(has, p, K.none())), q, 2, (ns + 1 : U32)),
                 q, 3, 1), q, 4, nn), q, 5, 0)
  p2 = set_if(has, p1, p, 5, 1)
  p3 = set_if(U32.is_ne(p, 0), p2, p, 0, (nk - c : U32))
  mark(sp, ps, PS{p3, (np + 1 : U32), pcap, S.put2(nod, nn, s, K.none()), (nn + 1 : U32), ncap}, q, i, j, n)

def pj_dec(ext: Bool, +s: U32, +p: U32, +nk: U32, +ns: U32, +c: U32, sp: Array<U32>, ps: Array<U32>,
           pat: Array<U32>, +np: U32, +pcap: U32, nod: Array<U32>, +nn: U32, +ncap: U32,
           +i: U32, +j: U32, +n: U32) -> PJ:
  match ext:
    case True{}:
      pj_ext(s, p, ns, sp, ps, np, pcap, nod, nn, ncap, i, j, n, pget(pat, p, 3))
    case False{}:
      pj_new(s, p, nk, ns, c, sp, ps, pat, np, pcap, nod, nn, ncap, i, j, n)

def pj_isp(+s: U32, +p: U32, +nk: U32, +ns: U32, sp: Array<U32>, ps: Array<U32>, +np: U32, +pcap: U32,
           nod: Array<U32>, +nn: U32, +ncap: U32, +i: U32, +j: U32, +n: U32, r: Array<U32> & U32) -> PJ:
  (pat, +isp) = r
  +c = (j - i : U32)
  pj_dec(U32.is_eq(nk, c) && U32.is_eq(isp, 0), s, p, nk, ns, c, sp, ps, pat, np, pcap, nod, nn, ncap, i, j, n)

def pj_ns(+s: U32, +p: U32, +nk: U32, sp: Array<U32>, ps: Array<U32>, +np: U32, +pcap: U32,
          nod: Array<U32>, +nn: U32, +ncap: U32, +i: U32, +j: U32, +n: U32, r: Array<U32> & U32) -> PJ:
  (pat, +ns) = r
  pj_isp(s, p, nk, ns, sp, ps, np, pcap, nod, nn, ncap, i, j, n, pget(pat, p, 5))

def pj_nk2(+s: U32, +p: U32, sp: Array<U32>, ps: Array<U32>, +np: U32, +pcap: U32,
           nod: Array<U32>, +nn: U32, +ncap: U32, +i: U32, +j: U32, +n: U32, r: Array<U32> & U32) -> PJ:
  (pat, +nk) = r
  pj_ns(s, p, nk, sp, ps, np, pcap, nod, nn, ncap, i, j, n, pget(pat, p, 2))

def pj_nk(+s: U32, +p: U32, ps: Array<U32>, pt: PS, +i: U32, +n: U32, re: RE) -> PJ:
  PS{pat, +np, +pcap, nod, +nn, +ncap} = pt
  RE{sp, +j, go} = re
  pj_nk2(s, p, sp, ps, np, pcap, nod, nn, ncap, i, j, n, pget(pat, p, 0))

def pj_run(+s: U32, +n: U32, ps: Array<U32>, pt: PS, +i: U32, g: S.A2) -> PJ:
  S.A2{sp, +p, +idx} = g
  pj_nk(s, p, ps, pt, i, n, re_go(U32.to_nat(n), p, n, RE{sp, (i + 1 : U32), U32.is_lt((i + 1 : U32), n)}))

def pj_go(f: Nat, +s: U32, +n: U32, st: PJ) -> PJ:
  match f st:
    case 0n _:
      st
    case 1n+q PJ{sp, ps, pt, +i, +go}:
      match go:
        case True{}:
          pj_go(q, s, n, pj_run(s, n, ps, pt, i, S.get2(sp, i)))
        case False{}:
          PJ{sp, ps, pt, i, False{}}

# samplePatterns as (pattern id, k-mer index) records for the sort
type SB is Type:
  SB{ps: Array<U32>, sp: Array<U32>, +i: U32}

def sb_s(sp: Array<U32>, +i: U32, r: Array<U32> & U32) -> SB:
  (ps, +pid) = r
  SB{ps, S.put2(sp, i, pid, i), (i + 1 : U32)}

def sb_go(f: Nat, st: SB) -> SB:
  match f st:
    case 0n _:
      st
    case 1n+q SB{ps, sp, +i}:
      sb_go(q, sb_s(sp, i, ps[U32.shln(i, 1n)]))

# addKmers
# ========

type DB is Type:
  DB{ht: Array<PT>, pt: PS, +pb: U32}

def db_new(+pb: U32) -> DB:
  DB{tab_new(U32.to_nat(pb)), ps_new(65536, 65536), pb}

def ak_written(pt: PS, +pb: U32, r: Array<PT> & St) -> DB:
  (ht, st) = r
  DB{ht, pt, pb}

def ak_patterns(ht: Array<PT>, km: Array<U32>, +n: U32, +pb: U32, pj: PJ) -> DB:
  PJ{sp, ps, pt, i, go} = pj
  ak_written(pt, pb, runs(False{}, ht, n, St{km, ps}))

def ak_sorted(ht: Array<PT>, km: Array<U32>, pt: PS, +s: U32, +n: U32, +pb: U32, sb: SB) -> DB:
  SB{ps, sp, i} = sb
  ak_patterns(ht, km, n, pb, pj_go(U32.to_nat(n), s, n, PJ{S.sort2(n, sp), ps, ps_room(n, pt), 0, True{}}))

def ak_found(pt: PS, +s: U32, +n: U32, +pb: U32, r: Array<PT> & St) -> DB:
  (ht, st) = r
  St{km, ps} = st
  ak_sorted(ht, km, pt, s, n, pb, sb_go(U32.to_nat(n), SB{ps, K.arr_new(U32.shln(n, 1n)), 0}))

def ak_s(empty: Bool, db: DB, +s: U32, +n: U32, km: Array<U32>) -> DB:
  match empty:
    case True{}:
      db
    case False{}:
      DB{ht, pt, +pb} = db
      ak_found(pt, s, n, pb, runs(True{}, ht, n, St{km, K.arr_new(U32.shln(n, 1n))}))

# PrefixKmerDb::addKmers of sample s with its n sorted unique k-mers
def add_kmers(db: DB, +s: U32, +n: U32, km: Array<U32>) -> DB:
  ak_s(U32.is_eq(n, 0), db, s, n, km)

def db_npat(db: DB) -> DB & U32:
  DB{ht, pt, +pb} = db
  PS{pat, +np, +pcap, nod, +nn, +ncap} = pt
  (DB{ht, PS{pat, np, pcap, nod, nn, ncap}, pb}, np)
