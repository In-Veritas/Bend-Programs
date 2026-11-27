# Kmer-db 2.3.1 hash_map_lp<uint32_t, V> (hashmap_lp.h) on an owned
# Array<U32>: open addressing with linear probing, items (key, val)
# interleaved, a slot is free when val == empty_value (numeric max of V:
# 2^31 - 1 for pattern_id_t, 2^32 - 1 for the SparseMatrix counts),
# INITIAL_SIZE 16, max_fill_factor 0.8, my_hasher_lp<uint32_t> (murmur3
# fmix32) masked by allocated - 1.
#
#   find_item               -> find_item
#   insert(k, v, place)     -> HM with the slot written (see kdb_db)
#   fast_insert             -> fast_insert (rehashing)
#   reserve_for_additional  -> reserve
#   operator[] (+= v)       -> add (restruct first when filled >= 0.8 cap)
#
# allocated * 0.8 is compared as (allocated * 4) / 5: for a power of two the
# binary64 product is never an integer, so both sides agree.
import Base
import ./pf_fasta.bend as F
import ./kdb_util.bend as K
import ./kdb_sort.bend as S

type HM is Type:
  HM{+filled: U32, +cap: U32, a: Array<U32>}

def hash32(+h0: U32) -> U32:
  +h1 = U32.mul(U32.xor(h0, U32.shrn(h0, 16n)), 2246822507)
  +h2 = U32.mul(U32.xor(h1, U32.shrn(h1, 13n)), 3266489909)
  U32.xor(h2, U32.shrn(h2, 16n))

# size_when_restruct = (size_t)(allocated * max_fill_factor)
def fill_max(+cap: U32) -> U32:
  U32.div(U32.mul(cap, 4), 5)

def hm_arr(+cap: U32, +ev: U32) -> Array<U32>:
  Array.new(U32, F.depth(U32.shln(cap, 1n)), ev)

def hm_new(+ev: U32) -> HM:
  HM{0, 16, hm_arr(16, ev)}

# find_item
# =========
#
# The slot holding k, or the free slot where k would be inserted.

type FS is Type:
  FS{a: Array<U32>, +i: U32, +v: U32, +go: Bool}

def fs_step(+k: U32, +ev: U32, +j: U32, g: S.A2) -> FS:
  S.A2{a, +key, +v} = g
  FS{a, j, v, Bool.not(U32.is_eq(v, ev) || U32.is_eq(key, k))}

def fs_loop(n: Nat, +m: U32, +k: U32, +ev: U32, st: FS) -> FS:
  match n st:
    case 0n _:
      st
    case 1n+p FS{a, +i, +v, +go}:
      match go:
        case True{}:
          +j = U32.and((i + 1 : U32), m)
          fs_loop(p, m, k, ev, fs_step(k, ev, j, S.get2(a, j)))
        case False{}:
          FS{a, i, v, False{}}

def find_item(a: Array<U32>, +cap: U32, +k: U32, +ev: U32) -> FS:
  +m = (cap - 1 : U32)
  +i = U32.and(hash32(k), m)
  fs_loop(U32.to_nat(cap), m, k, ev, fs_step(k, ev, i, S.get2(a, i)))

def ins_at(+k: U32, +v: U32, f: FS) -> Array<U32>:
  FS{a, +i, w, go} = f
  S.put2(a, i, k, v)

# fast_insert (k known to be absent): first free slot from hash(k)
def fast_insert(a: Array<U32>, +cap: U32, +k: U32, +v: U32, +ev: U32) -> Array<U32>:
  ins_at(k, v, find_item(a, cap, k, ev))

# Rehash (restruct / reserve_for_additional)
# =========================================

type RH is Type:
  RH{old: Array<U32>, nw: Array<U32>, +i: U32}

def rh_s(free: Bool, +ncap: U32, +ev: U32, +i: U32, nw: Array<U32>, old: Array<U32>, +key: U32, +v: U32) -> RH:
  match free:
    case True{}:
      RH{old, nw, (i + 1 : U32)}
    case False{}:
      RH{old, fast_insert(nw, ncap, key, v, ev), (i + 1 : U32)}

def rh_put(+ncap: U32, +ev: U32, +i: U32, nw: Array<U32>, g: S.A2) -> RH:
  S.A2{old, +key, +v} = g
  rh_s(U32.is_eq(v, ev), ncap, ev, i, nw, old, key, v)

def rh_go(n: Nat, +ncap: U32, +ev: U32, st: RH) -> RH:
  match n st:
    case 0n _:
      st
    case 1n+p RH{old, nw, +i}:
      rh_go(p, ncap, ev, rh_put(ncap, ev, i, nw, S.get2(old, i)))

def rh_fin(st: RH) -> Array<U32>:
  RH{old, nw, i} = st
  nw

def rehash(+cap: U32, +ncap: U32, +ev: U32, a: Array<U32>) -> Array<U32>:
  rh_fin(rh_go(U32.to_nat(cap), ncap, ev, RH{a, hm_arr(ncap, ev), 0}))

# smallest doubling of cap with filled + n <= 0.8 cap
def grow_cap(fuel: Nat, ok: Bool, +need: U32, +cap: U32) -> U32:
  match fuel ok:
    case 0n _:
      cap
    case 1n+p True{}:
      cap
    case 1n+p False{}:
      +c2 = U32.shln(cap, 1n)
      grow_cap(p, U32.is_le(need, fill_max(c2)), need, c2)

def reserve_s(ok: Bool, +n: U32, +ev: U32, +filled: U32, +cap: U32, a: Array<U32>) -> HM:
  match ok:
    case True{}:
      HM{filled, cap, a}
    case False{}:
      +ncap = grow_cap(32n, False{}, (filled + n : U32), cap)
      HM{filled, ncap, rehash(cap, ncap, ev, a)}

# reserve_for_additional(n)
def reserve(+n: U32, +ev: U32, h: HM) -> HM:
  HM{+filled, +cap, a} = h
  reserve_s(U32.is_le((filled + n : U32), fill_max(cap)), n, ev, filled, cap, a)

# operator[](k) += v
# ==================

def add_s2(free: Bool, +k: U32, +d: U32, +filled: U32, +cap: U32, +i: U32, +v: U32, a: Array<U32>) -> HM:
  match free:
    case True{}:
      HM{(filled + 1 : U32), cap, S.put2(a, i, k, d)}
    case False{}:
      HM{filled, cap, S.put2(a, i, k, (v + d : U32))}

def add_at(+k: U32, +d: U32, +ev: U32, +filled: U32, +cap: U32, f: FS) -> HM:
  FS{a, +i, +v, go} = f
  add_s2(U32.is_eq(v, ev), k, d, filled, cap, i, v, a)

def add_s(full: Bool, +k: U32, +d: U32, +ev: U32, +filled: U32, +cap: U32, a: Array<U32>) -> HM:
  match full:
    case True{}:
      +ncap = U32.shln(cap, 1n)
      add_at(k, d, ev, filled, ncap, find_item(rehash(cap, ncap, ev, a), ncap, k, ev))
    case False{}:
      add_at(k, d, ev, filled, cap, find_item(a, cap, k, ev))

def add(+k: U32, +d: U32, +ev: U32, h: HM) -> HM:
  HM{+filled, +cap, a} = h
  add_s(U32.is_ge(filled, fill_max(cap)), k, d, ev, filled, cap, a)
