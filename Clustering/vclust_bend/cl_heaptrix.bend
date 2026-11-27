# Complete linkage: a port of Clusty 1.2.2's linkage_algorithm_heaptrix
# (linkage_heaptrix.h, complete_linkage = linkage<Distance, my_max>).
#
#   element         -> 8-word records of `el` (key hi, key lo of the
#                      distance, _row, _column, _index_heap), allocated from a
#                      pool with a free stack (memory_monotonic + mma_buf)
#   heap            -> `hp`, a binary heap of element ids ordered by
#                      element::operator< (value, row, column), with the
#                      elements' heap positions kept up to date
#                      (sift_up, sift_down, make_heap, insert, remove, replace)
#   matrix_row_ht   -> per group a hash table column -> element id (MurMur3
#                      fmix64 hash, linear probing, `removed` tombstones,
#                      restruct when ht_filled == when_restruct)
#   do_clustering   -> cl_loop: read the top, merge rows r < c into the next
#                      group (a common neighbour keeps max(d1, d2); for
#                      complete linkage one-sided neighbours give MAX_DOUBLE
#                      and are dropped), replace/remove the old elements in
#                      the heap, erase them from the neighbours' rows, insert
#                      the rest of the new elements.
#
# Group ids: Clusty starts at get_max_row() + 1, here at n; both are larger
# than every object id with a row and increase by one per merge, so every
# key comparison (and hence the merge sequence) is the same. The dendrogram
# is then cut exactly as before (complete_fin: roots by decreasing id).
import Base
import ./f64.bend as F
import ./cl_graph.bend as G
import ./pf_num.bend as N
import ./kdb_sort.bend as S
import ./cl_complete.bend as C
import ./kdb_util.bend as K

def nul() -> U32:
  4294967295

def removed() -> U32:
  4294967294

def when(-A: Type, c: Bool, k: Bool -> A) -> A:
  k(c)

def apply(-A: Type, -B: Type, body: A -> B, value: A) -> B:
  body(value)

# Elements
# ========

def eset(el: Array<U32>, +e: U32, +f: U32, +v: U32) -> Array<U32>:
  Array.set(U32, el, U32.add(U32.shln(e, 3n), f), v)

def eget(el: Array<U32>, +e: U32, +f: U32) -> Array<U32> & U32:
  Array.get(U32, el, U32.add(U32.shln(e, 3n), f))

type K4 is Type:
  K4{el: Array<U32>, +kh: U32, +kl: U32, +r: U32, +c: U32}

def k4_d(+kh: U32, +kl: U32, +r: U32, x: Array<U32> & U32) -> K4:
  (el, +c) = x
  K4{el, kh, kl, r, c}

def k4_c(+e: U32, +kh: U32, +kl: U32, x: Array<U32> & U32) -> K4:
  (el, +r) = x
  k4_d(kh, kl, r, eget(el, e, 3))

def k4_b(+e: U32, +kh: U32, x: Array<U32> & U32) -> K4:
  (el, +kl) = x
  k4_c(e, kh, kl, eget(el, e, 2))

def k4_a(+e: U32, x: Array<U32> & U32) -> K4:
  (el, +kh) = x
  k4_b(e, kh, eget(el, e, 1))

def key4(el: Array<U32>, +e: U32) -> K4:
  k4_a(e, eget(el, e, 0))

def lt4(+a0: U32, +a1: U32, +a2: U32, +a3: U32, +b0: U32, +b1: U32, +b2: U32, +b3: U32) -> Bool:
  F.lex_lt(a0, b0, F.lex_lt(a1, b1, F.lex_lt(a2, b2, U32.is_lt(a3, b3))))

def less_b(+a0: U32, +a1: U32, +a2: U32, +a3: U32, k: K4) -> Array<U32> & Bool:
  K4{el, +b0, +b1, +b2, +b3} = k
  (el, lt4(a0, a1, a2, a3, b0, b1, b2, b3))

def less_a(+b: U32, k: K4) -> Array<U32> & Bool:
  K4{el, +a0, +a1, +a2, +a3} = k
  less_b(a0, a1, a2, a3, key4(el, b))

# element::operator<(*a, *b)
def less(el: Array<U32>, +a: U32, +b: U32) -> Array<U32> & Bool:
  less_a(b, key4(el, a))

# Heap
# ====

type HE is Type:
  HE{el: Array<U32>, hp: Array<U32>, +n: U32}

def hget(hp: Array<U32>, +i: U32) -> Array<U32> & U32:
  Array.get(U32, hp, i)

# swap heap slots i and j (elements a = hp[i], b = hp[j]) and their indices
def hswap(el: Array<U32>, hp: Array<U32>, +n: U32, +i: U32, +j: U32, +a: U32, +b: U32) -> HE:
  HE{eset(eset(el, a, 4, j), b, 4, i), Array.set(U32, Array.set(U32, hp, i, b), j, a), n}

type SI is Type:
  SI{h: HE, +i: U32, +go: Bool}

def su_cmp(hp: Array<U32>, +n: U32, +i: U32, +p: U32, +a: U32, +b: U32, r: Array<U32> & Bool) -> SI:
  (el, +lt) = r
  when(SI, lt, \{
    True: SI{hswap(el, hp, n, i, p, a, b), p, True{}}
    False: SI{HE{el, hp, n}, i, False{}}
  })

def su_b(el: Array<U32>, +n: U32, +i: U32, +p: U32, +a: U32, r: Array<U32> & U32) -> SI:
  (hp, +b) = r
  su_cmp(hp, n, i, p, a, b, less(el, a, b))

def su_a(el: Array<U32>, +n: U32, +i: U32, +p: U32, r: Array<U32> & U32) -> SI:
  (hp, +a) = r
  su_b(el, n, i, p, a, hget(hp, p))

def su_step(h: HE, +i: U32) -> SI:
  HE{el, hp, +n} = h
  when(SI, U32.is_eq(i, 0), \{
    True: SI{HE{el, hp, n}, i, False{}}
    False: su_a(el, n, i, U32.shr(U32.sub(i, 1)), hget(hp, i))
  })

def su_go(f: Nat, st: SI) -> SI:
  match f st:
    case 0n _:
      st
    case 1n+q SI{h, +i, +go}:
      match go:
        case True{}:
          su_go(q, su_step(h, i))
        case False{}:
          SI{h, i, False{}}

def su_fin(st: SI) -> HE:
  SI{h, i, go} = st
  h

def sift_up(h: HE, +i: U32) -> HE:
  su_fin(su_go(40n, SI{h, i, True{}}))

# sift_down: smaller child sc of parent i, swap while hp[sc] < hp[i]
def sd_cmp(hp: Array<U32>, +n: U32, +i: U32, +sc: U32, +a: U32, +b: U32, r: Array<U32> & Bool) -> SI:
  (el, +lt) = r
  when(SI, lt, \{
    True: SI{hswap(el, hp, n, sc, i, b, a), sc, True{}}
    False: SI{HE{el, hp, n}, i, False{}}
  })

def sd_par(el: Array<U32>, +n: U32, +i: U32, +sc: U32, +b: U32, r: Array<U32> & U32) -> SI:
  (hp, +a) = r
  sd_cmp(hp, n, i, sc, a, b, less(el, b, a))

def sd_sc(hp: Array<U32>, +n: U32, +i: U32, +l: U32, +x: U32, +y: U32, r: Array<U32> & Bool) -> SI:
  (el, +lt) = r
  +sc = F.sel(lt, l, U32.inc(l))
  sd_par(el, n, i, sc, F.sel(lt, x, y), hget(hp, i))

def sd_r(el: Array<U32>, +n: U32, +i: U32, +l: U32, +x: U32, r: Array<U32> & U32) -> SI:
  (hp, +y) = r
  sd_sc(hp, n, i, l, x, y, less(el, x, y))

def sd_l(el: Array<U32>, +n: U32, +i: U32, +l: U32, r: Array<U32> & U32) -> SI:
  (hp, +x) = r
  when(SI, U32.is_lt(U32.inc(l), n), \{
    True: sd_r(el, n, i, l, x, hget(hp, U32.inc(l)))
    False: sd_par(el, n, i, l, x, hget(hp, i))
  })

def sd_step(h: HE, +i: U32) -> SI:
  HE{el, hp, +n} = h
  +l = U32.inc(U32.shl(i))
  when(SI, U32.is_lt(l, n), \{
    True: sd_l(el, n, i, l, hget(hp, l))
    False: SI{HE{el, hp, n}, i, False{}}
  })

def sd_go(f: Nat, st: SI) -> SI:
  match f st:
    case 0n _:
      st
    case 1n+q SI{h, +i, +go}:
      match go:
        case True{}:
          sd_go(q, sd_step(h, i))
        case False{}:
          SI{h, i, False{}}

def sift_down(h: HE, +i: U32) -> HE:
  su_fin(sd_go(40n, SI{h, i, True{}}))

# make_heap: sift_down from (size + 1) / 2 down to 0, then positions
def mh_down(f: Nat, +i: U32, h: HE) -> HE:
  match f:
    case 0n:
      h
    case 1n+q:
      mh_down(q, U32.sub(i, 1), sift_down(h, i))

type IX is Type:
  IX{el: Array<U32>, hp: Array<U32>, +i: U32}

def ix_s(el: Array<U32>, +i: U32, r: Array<U32> & U32) -> IX:
  (hp, +e) = r
  IX{eset(el, e, 4, i), hp, U32.inc(i)}

def ix_go(f: Nat, st: IX) -> IX:
  match f st:
    case 0n _:
      st
    case 1n+q IX{el, hp, +i}:
      ix_go(q, ix_s(el, i, hget(hp, i)))

def ix_fin(+n: U32, st: IX) -> HE:
  IX{el, hp, i} = st
  HE{el, hp, n}

def ix_mk(+n: U32, h: HE) -> HE:
  HE{el, hp, m} = h
  ix_fin(n, ix_go(U32.to_nat(n), IX{el, hp, 0}))

def make_heap(h: HE) -> HE:
  HE{el, hp, +n} = h
  +start = U32.shr(U32.inc(n))
  ix_mk(n, mh_down(U32.to_nat(U32.inc(start)), start, HE{el, hp, n}))

# insert(p)
def h_insert(h: HE, +e: U32) -> HE:
  HE{el, hp, +n} = h
  sift_up(HE{eset(el, e, 4, n), Array.set(U32, hp, n, e), U32.inc(n)}, n)

# remove(p): the last element moves to p's slot, then up or down
def rm_move(h: HE, +idx: U32, +last: U32, mv: Bool) -> HE:
  HE{el, hp, +n} = h
  when(HE, mv, \{
    True: sift_up(HE{eset(el, last, 4, idx), Array.set(U32, hp, idx, last), U32.sub(n, 1)}, idx)
    False: sift_down(HE{eset(el, last, 4, idx), Array.set(U32, hp, idx, last), U32.sub(n, 1)}, idx)
  })

def rm_less(hp: Array<U32>, +n: U32, +idx: U32, +last: U32, r: Array<U32> & Bool) -> HE:
  (el, +mv) = r
  rm_move(HE{el, hp, n}, idx, last, mv)

def rm_last(el: Array<U32>, +n: U32, +p: U32, +idx: U32, r: Array<U32> & U32) -> HE:
  (hp, +last) = r
  rm_less(hp, n, idx, last, less(el, last, p))

def rm_idx(hp: Array<U32>, +n: U32, +p: U32, r: Array<U32> & U32) -> HE:
  (el, +idx) = r
  when(HE, U32.is_gt(n, 1), \{
    True: rm_last(el, n, p, idx, hget(hp, U32.sub(n, 1)))
    False: HE{el, hp, U32.sub(n, 1)}
  })

def h_remove(h: HE, +p: U32) -> HE:
  HE{el, hp, +n} = h
  rm_idx(hp, n, p, eget(el, p, 4))

# replace(p_old, p_new)
def rp_less(hp: Array<U32>, +n: U32, +idx: U32, r: Array<U32> & Bool) -> HE:
  (el, +up) = r
  when(HE, up, \{
    True: sift_up(HE{el, hp, n}, idx)
    False: sift_down(HE{el, hp, n}, idx)
  })

def rp_idx(hp: Array<U32>, +n: U32, +po: U32, +pn: U32, r: Array<U32> & U32) -> HE:
  (el, +idx) = r
  rp_less(Array.set(U32, hp, idx, pn), n, idx, less(eset(el, pn, 4, idx), pn, po))

def h_replace(h: HE, +po: U32, +pn: U32) -> HE:
  HE{el, hp, +n} = h
  rp_idx(hp, n, po, pn, eget(el, po, 4))

# matrix_row_ht
# =============
#
# slots (idx, element id); empty: idx = nul, removed: idx = nul - 1; a free
# slot for insert has no element (nul). A missing row is RNil (ht_size 8,
# when_restruct 0: the first insert restructs to 16 slots).

type RW is Type:
  RNil{}
  RHt{+size: U32, +filled: U32, +wr: U32, a: Array<U32>}

def hmm(+x: U32) -> U32:
  N.w2lo(N.fmix64(N.W2{0, x}))

def g2(a: Array<U32>, +i: U32) -> S.A2:
  S.get2(a, i)

# first slot from hash(idx) without an element
type PS is Type:
  PS{a: Array<U32>, +pos: U32, +go: Bool}

def ps_s(+m: U32, +pos: U32, g: S.A2) -> PS:
  S.A2{a, +i, +p} = g
  when(PS, U32.is_eq(p, nul()), \{
    True: PS{a, pos, False{}}
    False: PS{a, U32.and(U32.inc(pos), m), True{}}
  })

def ps_go(f: Nat, +m: U32, st: PS) -> PS:
  match f st:
    case 0n _:
      st
    case 1n+q PS{a, +pos, +go}:
      match go:
        case True{}:
          ps_go(q, m, ps_s(m, pos, g2(a, pos)))
        case False{}:
          PS{a, pos, False{}}

def ps_fin(+idx: U32, +ptr: U32, st: PS) -> Array<U32>:
  PS{a, +pos, go} = st
  S.put2(a, pos, idx, ptr)

def raw_ins(a: Array<U32>, +size: U32, +idx: U32, +ptr: U32) -> Array<U32>:
  +m = U32.sub(size, 1)
  ps_fin(idx, ptr, ps_go(U32.to_nat(U32.inc(size)), m, PS{a, U32.and(hmm(idx), m), True{}}))

# restruct: twice the size, live entries reinserted
type RR is Type:
  RR{old: Array<U32>, nw: Array<U32>, +i: U32, +filled: U32}

def rr_s(nw: Array<U32>, +size: U32, +i: U32, +filled: U32, g: S.A2) -> RR:
  S.A2{old, +idx, +p} = g
  when(RR, U32.is_eq(p, nul()), \{
    True: RR{old, nw, U32.inc(i), filled}
    False: RR{old, raw_ins(nw, size, idx, p), U32.inc(i), U32.inc(filled)}
  })

def rr_go(f: Nat, +size: U32, st: RR) -> RR:
  match f st:
    case 0n _:
      st
    case 1n+q RR{old, nw, +i, +filled}:
      rr_go(q, size, rr_s(nw, size, i, filled, g2(old, i)))

def rr_fin(+size: U32, st: RR) -> RW:
  RR{old, nw, i, +filled} = st
  RHt{size, filled, U32.div(U32.mul(size, 4), 5), nw}

def restruct(+size: U32, a: Array<U32>) -> RW:
  +ns = U32.shl(size)
  rr_fin(ns, rr_go(U32.to_nat(size), ns, RR{a, Array.new(U32, G.depth(U32.shl(ns)), nul()), 0, 0}))

def ins_h(r: RW, +idx: U32, +ptr: U32) -> RW:
  match r:
    case RHt{+size, +filled, +wr, a}:
      RHt{size, U32.inc(filled), wr, raw_ins(a, size, idx, ptr)}
    case RNil{}:
      RNil{}

def ht_insert(r: RW, +idx: U32, +ptr: U32) -> RW:
  match r:
    case RNil{}:
      ins_h(restruct(8, Array.new(U32, 4n, nul())), idx, ptr)
    case RHt{+size, +filled, +wr, a}:
      when(RW, U32.is_eq(filled, wr), \{
        True: ins_h(restruct(size, a), idx, ptr)
        False: ins_h(RHt{size, filled, wr, a}, idx, ptr)
      })

# find / erase: probe until idx or an empty slot
type FD is Type:
  FD{a: Array<U32>, +pos: U32, +ptr: U32, +hit: Bool, +go: Bool}

def fd_s(+m: U32, +idx: U32, +pos: U32, g: S.A2) -> FD:
  S.A2{a, +i, +p} = g
  when(FD, U32.is_eq(i, idx), \{
    True: FD{a, pos, p, True{}, False{}}
    False: when(FD, U32.is_eq(i, nul()), \{
      True: FD{a, pos, nul(), False{}, False{}}
      False: FD{a, U32.and(U32.inc(pos), m), nul(), False{}, True{}}
    })
  })

def fd_go(f: Nat, +m: U32, +idx: U32, st: FD) -> FD:
  match f st:
    case 0n _:
      st
    case 1n+q FD{a, +pos, +ptr, +hit, +go}:
      match go:
        case True{}:
          fd_go(q, m, idx, fd_s(m, idx, pos, g2(a, pos)))
        case False{}:
          FD{a, pos, ptr, hit, False{}}

def fd_run(a: Array<U32>, +size: U32, +idx: U32) -> FD:
  +m = U32.sub(size, 1)
  fd_go(U32.to_nat(U32.inc(size)), m, idx, FD{a, U32.and(hmm(idx), m), nul(), False{}, True{}})

def fd_back(+size: U32, +filled: U32, +wr: U32, f: FD) -> RW & U32:
  FD{a, pos, +ptr, hit, go} = f
  (RHt{size, filled, wr, a}, ptr)

# the element of column idx, or nul
def ht_find(r: RW, +idx: U32) -> RW & U32:
  match r:
    case RNil{}:
      (RNil{}, nul())
    case RHt{+size, +filled, +wr, a}:
      when(RW & U32, U32.is_eq(filled, 0), \{
        True: (RHt{size, filled, wr, a}, nul())
        False: fd_back(size, filled, wr, fd_run(a, size, idx))
      })

def er_back(+size: U32, +filled: U32, +wr: U32, f: FD) -> RW:
  FD{a, +pos, ptr, +hit, go} = f
  when(RW, hit, \{
    True: RHt{size, filled, wr, S.put2(a, pos, removed(), nul())}
    False: RHt{size, filled, wr, a}
  })

def ht_erase(r: RW, +idx: U32) -> RW:
  match r:
    case RNil{}:
      RNil{}
    case RHt{+size, +filled, +wr, a}:
      when(RW, U32.is_eq(filled, 0), \{
        True: RHt{size, filled, wr, a}
        False: er_back(size, filled, wr, fd_run(a, size, idx))
      })

# the entries (column, element) in slot order
type EN is Data:
  EN{+col: U32, +el: U32}

type EI is Type:
  EI{a: Array<U32>, +i: U32, acc: List<&2, EN>}

def ei_s(+i: U32, acc: List<&2, EN>, g: S.A2) -> EI:
  S.A2{a, +c, +p} = g
  when(EI, U32.is_eq(p, nul()), \{
    True: EI{a, U32.sub(i, 1), acc}
    False: EI{a, U32.sub(i, 1), EN{c, p} <> acc}
  })

def ei_go(f: Nat, st: EI) -> EI:
  match f st:
    case 0n _:
      st
    case 1n+q EI{a, +i, acc}:
      ei_go(q, ei_s(i, acc, g2(a, i)))

def ei_fin(+size: U32, +filled: U32, +wr: U32, st: EI) -> RW & List<&2, EN>:
  EI{a, i, acc} = st
  (RHt{size, filled, wr, a}, acc)

def entries(r: RW) -> RW & List<&2, EN>:
  match r:
    case RNil{}:
      (RNil{}, Nil{})
    case RHt{+size, +filled, +wr, a}:
      ei_fin(size, filled, wr, ei_go(U32.to_nat(size), EI{a, U32.sub(size, 1), Nil{}}))

# Linkage state
# =============

type CS is Type:
  CS{h: HE, +ne: U32, fr: List<&2, U32>, rows: Array<RW>, up: Array<U32>, alive: Array<U32>,
     +next: U32, +objs: U32}

def row_take(rows: Array<RW>, +i: U32) -> Array<RW> & RW:
  Array.swap(RW, rows, i, RNil{})

def row_put(rows: Array<RW>, +i: U32, r: RW) -> Array<RW>:
  Array.set(RW, rows, i, r)

# element_allocate(row, column, index_heap, (kh, kl))
type AE is Type:
  AE{el: Array<U32>, +e: U32, +ne: U32, fr: List<&2, U32>}

def ae_set(el: Array<U32>, +e: U32, +row: U32, +col: U32, +hi: U32, +kh: U32, +kl: U32) -> Array<U32>:
  eset(eset(eset(eset(eset(el, e, 0, kh), e, 1, kl), e, 2, row), e, 3, col), e, 4, hi)

def alloc(el: Array<U32>, +ne: U32, fr: List<&2, U32>, +row: U32, +col: U32, +hi: U32, +kh: U32, +kl: U32) -> AE:
  match fr:
    case Nil{}:
      AE{ae_set(el, ne, row, col, hi, kh, kl), ne, U32.inc(ne), Nil{}}
    case Con{+e, t}:
      AE{ae_set(el, e, row, col, hi, kh, kl), e, ne, t}

# read_matrix / add_value
# -----------------------

type RM is Type:
  RM{h: HE, +ne: U32, rows: Array<RW>}

def av_new(h: HE, +ne: U32, rows: Array<RW>, +w: U32, +k: U32, +kh: U32, +kl: U32) -> RM:
  HE{el, hp, +n} = h
  K.apply(Array<RW> & RW, RM, \{Tuple: rs1 => rw => (
    K.apply(Array<RW> & RW, RM, \{Tuple: rs2 => rk => (
      RM{HE{ae_set(el, ne, w, k, n, kh, kl), Array.set(U32, hp, n, ne), U32.inc(n)}, U32.inc(ne),
        row_put(row_put(rs2, w, ht_insert(rw, k, ne)), k, ht_insert(rk, w, ne))}
    )}, row_take(rs1, k))
  )}, row_take(rows, w))

def av_found(h: HE, +ne: U32, +w: U32, +k: U32, +kh: U32, +kl: U32, rs: Array<RW>, r: RW & U32) -> RM:
  (rw, +p) = r
  when(RM, U32.is_eq(p, nul()), \{
    True: av_new(h, ne, row_put(rs, w, rw), w, k, kh, kl)
    False: RM{h, ne, row_put(rs, w, rw)}
  })

def add_value(rm: RM, +a: U32, +b: U32, +kh: U32, +kl: U32) -> RM:
  RM{h, +ne, rows} = rm
  +w = U32.min(a, b)
  +k = U32.max(a, b)
  K.apply(Array<RW> & RW, RM, \{Tuple: rs => rw => (
    av_found(h, ne, w, k, kh, kl, rs, ht_find(rw, k))
  )}, row_take(rows, w))

def rm_row(ns: List<&2, G.Nb>, +i: U32, rm: RM) -> RM:
  match ns:
    case Nil{}:
      rm
    case Con{G.Nb{+id, +dh, +dl}, t}:
      rm_row(t, i, when(RM, U32.is_eq(id, i), \{
        True: rm
        False: add_value(rm, i, id, F.key_hi(dh, dl), F.key_lo(dh, dl))
      }))

def rm_go(f: Nat, +i: U32, src: Array<List<&2, G.Nb>>, rm: RM) -> RM:
  match f:
    case 0n:
      rm
    case 1n+q:
      K.apply(Array<List<&2, G.Nb>> & List<&2, G.Nb>, RM, \{Tuple: s2 => ns => (
        rm_go(q, U32.inc(i), s2, rm_row(ns, i, rm))
      )}, Array.swap(List<&2, G.Nb>, src, i, Nil{}))

# do_clustering
# -------------

# merged row: common columns of r and c with max(d_r, d_c)
type M1 is Type:
  M1{h: HE, +ne: U32, fr: List<&2, U32>, tc: RW, mrow: RW, buf: List<&2, U32>, mcol: List<&2, EN>}

def m1_alloc(hp: Array<U32>, +n: U32, tc: RW, mrow: RW, buf: List<&2, U32>, mcol: List<&2, EN>, +col: U32, a: AE) -> M1:
  AE{el, +e, +ne, fr} = a
  M1{HE{el, hp, n}, ne, fr, tc, ht_insert(mrow, col, e), e <> buf, EN{col, e} <> mcol}

def m1_new(h: HE, +ne: U32, fr: List<&2, U32>, tc: RW, mrow: RW, buf: List<&2, U32>, mcol: List<&2, EN>,
           +col: U32, +next: U32, +kh: U32, +kl: U32) -> M1:
  HE{el, hp, +n} = h
  m1_alloc(hp, n, tc, mrow, buf, mcol, col, alloc(el, ne, fr, col, next, nul(), kh, kl))

def m1_kq(hp: Array<U32>, +n: U32, +ne: U32, fr: List<&2, U32>, tc: RW, mrow: RW, buf: List<&2, U32>,
          mcol: List<&2, EN>, +col: U32, +next: U32, +ph: U32, +pl: U32, k: K4) -> M1:
  K4{el, +qh, +ql, qr, qc} = k
  +pbig = F.lex_lt(qh, ph, U32.is_lt(ql, pl))
  m1_new(HE{el, hp, n}, ne, fr, tc, mrow, buf, mcol, col, next, F.sel(pbig, ph, qh), F.sel(pbig, pl, ql))

def m1_keys(hp: Array<U32>, +n: U32, +ne: U32, fr: List<&2, U32>, tc: RW, mrow: RW, buf: List<&2, U32>,
            mcol: List<&2, EN>, +col: U32, +next: U32, +q: U32, k: K4) -> M1:
  K4{el, +ph, +pl, pr, pc} = k
  m1_kq(hp, n, ne, fr, tc, mrow, buf, mcol, col, next, ph, pl, key4(el, q))

def m1_find(h: HE, +ne: U32, fr: List<&2, U32>, mrow: RW, buf: List<&2, U32>, mcol: List<&2, EN>, +col: U32,
            +p: U32, +next: U32, r: RW & U32) -> M1:
  HE{el, hp, +n} = h
  (tc, +q) = r
  when(M1, U32.is_eq(q, nul()), \{
    True: M1{HE{el, hp, n}, ne, fr, tc, mrow, buf, mcol}
    False: m1_keys(hp, n, ne, fr, tc, mrow, buf, mcol, col, next, q, key4(el, p))
  })

def m1_go(es: List<&2, EN>, +c: U32, +next: U32, st: M1) -> M1:
  match es st:
    case Nil{} _:
      st
    case Con{EN{+col, +p}, t} M1{h, +ne, fr, tc, mrow, buf, mcol}:
      m1_go(t, c, next, when(M1, U32.is_eq(col, c), \{
        True: M1{h, ne, fr, tc, mrow, buf, mcol}
        False: m1_find(h, ne, fr, mrow, buf, mcol, col, p, next, ht_find(tc, col))
      }))

# merged_column into the neighbours' rows
def mc_go(es: List<&2, EN>, +next: U32, rows: Array<RW>) -> Array<RW>:
  match es:
    case Nil{}:
      rows
    case Con{EN{+col, +e}, t}:
      mc_go(t, next, K.apply(Array<RW> & RW, Array<RW>, \{Tuple: rs => rw => (
        row_put(rs, col, ht_insert(rw, next, e))
      )}, row_take(rows, col)))

# old elements of row x: replaced by a pending new element or removed from
# the heap, erased from the neighbour's row (the held row c when it is c),
# freed
type M2 is Type:
  M2{h: HE, buf: List<&2, U32>, fr: List<&2, U32>, rows: Array<RW>, tc: RW}

def m2_heap(h: HE, buf: List<&2, U32>, +p: U32) -> HE & List<&2, U32>:
  match buf:
    case Nil{}:
      (h_remove(h, p), Nil{})
    case Con{+e, t}:
      (h_replace(h, p, e), t)

def m2_go(es: List<&2, EN>, +x: U32, +c: U32, st: M2) -> M2:
  match es st:
    case Nil{} _:
      st
    case Con{EN{+col, +p}, t} M2{h, buf, fr, rows, tc}:
      m2_go(t, x, c, K.apply(HE & List<&2, U32>, M2, \{Tuple: h2 => buf2 => (
        when(M2, U32.is_eq(col, c), \{
          True: M2{h2, buf2, p <> fr, rows, ht_erase(tc, x)}
          False: K.apply(Array<RW> & RW, M2, \{Tuple: rs => rw => (
            M2{h2, buf2, p <> fr, row_put(rs, col, ht_erase(rw, x)), tc}
          )}, row_take(rows, col))
        })
      )}, m2_heap(h, buf, p)))

def ins_rev(xs: List<&2, U32>, h: HE) -> HE:
  match xs:
    case Nil{}:
      h
    case Con{+e, t}:
      h_insert(ins_rev(t, h), e)

def st_fin(up: Array<U32>, alive: Array<U32>, +next: U32, +objs: U32, +ne: U32, m2: M2) -> CS:
  M2{h, buf, fr, rows, tc} = m2
  CS{ins_rev(buf, h), ne, fr, rows, up, alive, U32.inc(next), U32.sub(objs, 1)}

def st_c(up: Array<U32>, alive: Array<U32>, +next: U32, +objs: U32, +ne: U32, +r: U32, +c: U32, tr: RW, m2: M2) -> CS:
  M2{h, buf, fr, rows, tc} = m2
  K.apply(RW & List<&2, EN>, CS, \{Tuple: tc2 => lc => (
    st_fin(up, alive, next, objs, ne, m2_go(lc, c, nul(), M2{h, buf, fr, rows, RNil{}}))
  )}, entries(tc))

def st_b(rows: Array<RW>, up: Array<U32>, alive: Array<U32>, +next: U32, +objs: U32, +r: U32, +c: U32,
         tr: RW, +lr: List<&2, EN>, m1: M1) -> CS:
  M1{h, +ne, fr, tc, mrow, buf, mcol} = m1
  st_c(up, alive, next, objs, ne, r, c, tr,
    m2_go(lr, r, c, M2{h, buf, fr, mc_go(mcol, next, row_put(rows, next, mrow)), tc}))

def st_a(h: HE, +ne: U32, fr: List<&2, U32>, rows: Array<RW>, up: Array<U32>, alive: Array<U32>, +next: U32,
         +objs: U32, +r: U32, +c: U32) -> CS:
  K.apply(Array<RW> & RW, CS, \{Tuple: rs1 => tr => (
    K.apply(Array<RW> & RW, CS, \{Tuple: rs2 => tc => (
      K.apply(RW & List<&2, EN>, CS, \{Tuple: tr2 => +lr => (
        st_b(rs2, up, alive, next, objs, r, c, tr2, lr, m1_go(lr, c, next, M1{h, ne, fr, tc, RNil{}, Nil{}, Nil{}}))
      )}, entries(tr))
    )}, row_take(rs1, c))
  )}, row_take(rows, r))

def st_top(hp: Array<U32>, +n: U32, +ne: U32, fr: List<&2, U32>, rows: Array<RW>, up: Array<U32>,
           alive: Array<U32>, +next: U32, +objs: U32, k: K4) -> CS:
  K4{el, kh, kl, +r0, +c0} = k
  +r = U32.min(r0, c0)
  +c = U32.max(r0, c0)
  st_a(HE{el, hp, n}, ne, fr, rows, Array.set(U32, Array.set(U32, up, r, next), c, next),
    Array.set(U32, Array.set(U32, Array.set(U32, alive, r, 0), c, 0), next, 1), next, objs, r, c)

def st_go(el: Array<U32>, +n: U32, +ne: U32, fr: List<&2, U32>, rows: Array<RW>, up: Array<U32>,
          alive: Array<U32>, +next: U32, +objs: U32, r: Array<U32> & U32) -> CS:
  (hp, +t) = r
  st_top(hp, n, ne, fr, rows, up, alive, next, objs, key4(el, t))

def cl_go(f: Nat, cs: CS) -> CS:
  match f cs:
    case 0n _:
      cs
    case 1n+q CS{HE{el, hp, +n}, +ne, fr, rows, up, alive, +next, +objs}:
      when(CS, U32.is_gt(objs, 1) && U32.is_gt(n, 0), \{
        True: cl_go(q, st_go(el, n, ne, fr, rows, up, alive, next, objs, hget(hp, 0)))
        False: CS{HE{el, hp, n}, ne, fr, rows, up, alive, next, objs}
      })

def rows_nil(+d: Nat) -> Array<RW>:
  match d:
    case 0n:
      ALeaf{RNil{}}
    case 1n+p:
      ANode{rows_nil(p), rows_nil(p)}

def fill_one(n: Nat, +i: U32, a: Array<U32>) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      fill_one(p, U32.inc(i), Array.set(U32, a, i, 1))

def cl_fin(+n: U32, cs: CS) -> Array<U32> & U32:
  CS{h, ne, fr, rows, up, alive, next, objs} = cs
  +m2 = U32.shl(n)
  C.leaf_asg(U32.to_nat(n), 0, C.LA{
    C.fin_loop(U32.to_nat(m2), U32.sub(m2, 1), C.FN{alive, up, G.u32_array(m2, 0), G.u32_array(m2, 0), 0}),
    G.u32_array(n, 0)})

def cl_start(+n: U32, +m: U32, rm: RM) -> Array<U32> & U32:
  RM{h, +ne, rows} = rm
  cl_fin(n, cl_go(U32.to_nat(U32.add(n, 2)), CS{make_heap(h), ne, Nil{}, rows, G.u32_array(U32.shl(n), 0),
    fill_one(U32.to_nat(n), 0, G.u32_array(U32.shl(n), 0)), n, n}))

# (assignment over local ids, number of clusters); m = directed entries
def complete(src: Array<List<&2, G.Nb>>, +n: U32, +m: U32) -> Array<U32> & U32:
  +cap = U32.add(m, 16)
  cl_start(n, m, rm_go(U32.to_nat(n), 0, src,
    RM{HE{Array.new(U32, G.depth(U32.shln(cap, 3n)), 0), Array.new(U32, G.depth(cap), 0), 0}, 0,
       rows_nil(G.depth(U32.shl(n)))}))
