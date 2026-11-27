# Sorting of 2-word records (x, y) of an Array<U32>, lexicographic order.
#
# Kmer-db sorts with refresh::sort::pdqsort_branchless (a pattern-defeating
# quicksort): insertion sort below 24 elements, median-of-3 (ninther above
# 128) pivots, and a partition that groups the elements equal to the pivot
# (pdqsort's partition_left), so runs of equal keys (pattern ids in
# PrefixKmerDb::addKmers) cost linear time. This is the same scheme on the
# owned array: insertion sort for small ranges, median pivots, a 3-way
# (Dijkstra) partition. Used by KmerHelper::sortAndUnique (sample k-mers),
# the samplePatterns sort of addKmers and SparseMatrix::compact2 rows.
import Base

type A2 is Type:
  A2{a: Array<U32>, +x: U32, +y: U32}

def g2b(+x: U32, r: Array<U32> & U32) -> A2:
  (a, +y) = r
  A2{a, x, y}

def g2a(+o: U32, r: Array<U32> & U32) -> A2:
  (a, +x) = r
  g2b(x, a[(o + 1 : U32)])

# record i
def get2(a: Array<U32>, +i: U32) -> A2:
  +o = U32.shln(i, 1n)
  g2a(o, a[o])

def put2(a: Array<U32>, +i: U32, +x: U32, +y: U32) -> Array<U32>:
  +o = U32.shln(i, 1n)
  b = a[o] <- x
  b[(o + 1 : U32)] <- y

def lt2(+ax: U32, +ay: U32, +bx: U32, +by: U32) -> Bool:
  U32.is_lt(ax, bx) || (U32.is_eq(ax, bx) && U32.is_lt(ay, by))

# Insertion sort
# ==============

type IS is Type:
  IS{a: Array<U32>, +j: U32, +go: Bool}

def ins_sw(c: Bool, +lo: U32, +j: U32, a: Array<U32>, +bx: U32, +by: U32) -> IS:
  match c:
    case True{}:
      +j1 = (j - 1 : U32)
      IS{put2(a, j, bx, by), j1, U32.is_gt(j1, lo)}
    case False{}:
      IS{a, j, False{}}

def ins_b(+lo: U32, +x: U32, +y: U32, +j: U32, b: A2) -> IS:
  A2{a, +bx, +by} = b
  ins_sw(lt2(x, y, bx, by), lo, j, a, bx, by)

def ins_go(n: Nat, +lo: U32, +x: U32, +y: U32, st: IS) -> IS:
  match n st:
    case 0n _:
      st
    case 1n+p IS{a, +j, +go}:
      match go:
        case True{}:
          ins_go(p, lo, x, y, ins_b(lo, x, y, j, get2(a, (j - 1 : U32))))
        case False{}:
          IS{a, j, False{}}

def ins_put(+x: U32, +y: U32, st: IS) -> Array<U32>:
  IS{a, +j, go} = st
  put2(a, j, x, y)

def ins_one(+lo: U32, +i: U32, r: A2) -> Array<U32>:
  A2{a, +x, +y} = r
  ins_put(x, y, ins_go(U32.to_nat((i - lo : U32)), lo, x, y, IS{a, i, U32.is_gt(i, lo)}))

def ins_loop(n: Nat, +lo: U32, +i: U32, a: Array<U32>) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      ins_loop(p, lo, (i + 1 : U32), ins_one(lo, i, get2(a, i)))

# sorts [lo, hi)
def insertion(+lo: U32, +hi: U32, a: Array<U32>) -> Array<U32>:
  ins_loop(U32.to_nat(U32.sub(U32.max(hi, (lo + 1 : U32)), (lo + 1 : U32))), lo, (lo + 1 : U32), a)

# 3-way partition
# ===============
#
# [lo, lt) < p, [lt, i) == p, [gt, hi) > p; every step moves i or gt.

type PT is Type:
  PT{a: Array<U32>, +lt: U32, +i: U32, +gt: U32}

def pt_lt(+lt: U32, +i: U32, +gt: U32, +rx: U32, +ry: U32, b: A2) -> PT:
  A2{a, +lx, +ly} = b
  PT{put2(put2(a, i, lx, ly), lt, rx, ry), (lt + 1 : U32), (i + 1 : U32), gt}

def pt_gt(+lt: U32, +i: U32, +g1: U32, +rx: U32, +ry: U32, b: A2) -> PT:
  A2{a, +gx, +gy} = b
  PT{put2(put2(a, i, gx, gy), g1, rx, ry), lt, i, g1}

def pt_sel(isl: Bool, isg: Bool, +lt: U32, +i: U32, +gt: U32, +rx: U32, +ry: U32, a: Array<U32>) -> PT:
  match isl isg:
    case True{} _:
      pt_lt(lt, i, gt, rx, ry, get2(a, lt))
    case False{} True{}:
      +g1 = (gt - 1 : U32)
      pt_gt(lt, i, g1, rx, ry, get2(a, g1))
    case False{} False{}:
      PT{a, lt, (i + 1 : U32), gt}

def pt_cmp(+px: U32, +py: U32, +lt: U32, +i: U32, +gt: U32, r: A2) -> PT:
  A2{a, +rx, +ry} = r
  pt_sel(lt2(rx, ry, px, py), lt2(px, py, rx, ry), lt, i, gt, rx, ry, a)

def pt_go(n: Nat, +px: U32, +py: U32, st: PT) -> PT:
  match n st:
    case 0n _:
      st
    case 1n+p PT{a, +lt, +i, +gt}:
      pt_go(p, px, py, pt_cmp(px, py, lt, i, gt, get2(a, i)))

# Pivot
# =====

type M3 is Type:
  M3{a: Array<U32>, +x: U32, +y: U32}

def med3s(ab: Bool, bc: Bool, ac: Bool, +ax: U32, +ay: U32, +bx: U32, +by: U32, +cx: U32, +cy: U32) -> U32 & U32:
  match ab bc ac:
    case True{} True{} _:
      (bx, by)
    case True{} False{} True{}:
      (cx, cy)
    case True{} False{} False{}:
      (ax, ay)
    case False{} _ True{}:
      (ax, ay)
    case False{} True{} False{}:
      (cx, cy)
    case False{} False{} False{}:
      (bx, by)

def med3(+ax: U32, +ay: U32, +bx: U32, +by: U32, +cx: U32, +cy: U32) -> U32 & U32:
  med3s(lt2(ax, ay, bx, by), lt2(bx, by, cx, cy), lt2(ax, ay, cx, cy), ax, ay, bx, by, cx, cy)

def m3_fin(a: Array<U32>, p: U32 & U32) -> M3:
  (+x, +y) = p
  M3{a, x, y}

def m3_c(+ax: U32, +ay: U32, +bx: U32, +by: U32, r: A2) -> M3:
  A2{a, +cx, +cy} = r
  m3_fin(a, med3(ax, ay, bx, by, cx, cy))

def m3_b(+ax: U32, +ay: U32, +k: U32, r: A2) -> M3:
  A2{a, +bx, +by} = r
  m3_c(ax, ay, bx, by, get2(a, k))

def m3_a(+j: U32, +k: U32, r: A2) -> M3:
  A2{a, +ax, +ay} = r
  m3_b(ax, ay, k, get2(a, j))

# median of the records i, j, k
def median(a: Array<U32>, +i: U32, +j: U32, +k: U32) -> M3:
  m3_a(j, k, get2(a, i))

# ninther: median of the medians of three triples
def nin_c(+ax: U32, +ay: U32, +bx: U32, +by: U32, m: M3) -> M3:
  M3{a, +cx, +cy} = m
  m3_fin(a, med3(ax, ay, bx, by, cx, cy))

def nin_b(+ax: U32, +ay: U32, +lo: U32, +s: U32, +n: U32, m: M3) -> M3:
  M3{a, +bx, +by} = m
  +h = (lo + U32.shrn(n, 1n) : U32)
  nin_c(ax, ay, bx, by, median(a, (lo + n - 1 - s : U32), (h + s : U32), (lo + n - 1 - U32.mul(s, 2) : U32)))

def nin_a(+lo: U32, +s: U32, +n: U32, m: M3) -> M3:
  M3{a, +ax, +ay} = m
  +h = (lo + U32.shrn(n, 1n) : U32)
  nin_b(ax, ay, lo, s, n, median(a, h, (h - s : U32), (lo + n - 1 : U32)))

def pivot_s(big: Bool, +lo: U32, +n: U32, a: Array<U32>) -> M3:
  match big:
    case True{}:
      +s = U32.div(n, 8)
      nin_a(lo, s, n, median(a, lo, (lo + s : U32), (lo + U32.mul(s, 2) : U32)))
    case False{}:
      median(a, lo, (lo + U32.shrn(n, 1n) : U32), (lo + n - 1 : U32))

def pivot(+lo: U32, +n: U32, a: Array<U32>) -> M3:
  pivot_s(U32.is_gt(n, 128), lo, n, a)

# Quicksort
# =========
#
# One loop over an explicit stack of ranges (Bend has no mutual recursion):
# a small range is insertion-sorted, a larger one is partitioned around its
# median pivot and both sides are pushed.

type RG is Data:
  RNil{}
  RCon{+lo: U32, +hi: U32, t: RG}

type QS is Type:
  QS{a: Array<U32>, st: RG}

def qs_parted(+lo: U32, +hi: U32, t: RG, p: PT) -> QS:
  PT{a, +lt, +i, +gt} = p
  QS{a, RCon{lo, lt, RCon{gt, hi, t}}}

def qs_pivot(+lo: U32, +hi: U32, t: RG, m: M3) -> QS:
  M3{a, +px, +py} = m
  qs_parted(lo, hi, t, pt_go(U32.to_nat((hi - lo : U32)), px, py, PT{a, lo, lo, hi}))

def qs_range(small: Bool, +lo: U32, +hi: U32, +n: U32, t: RG, a: Array<U32>) -> QS:
  match small:
    case True{}:
      QS{insertion(lo, hi, a), t}
    case False{}:
      qs_pivot(lo, hi, t, pivot(lo, n, a))

def qs_loop(fuel: Nat, q: QS) -> Array<U32>:
  match fuel q:
    case 0n QS{a, st}:
      a
    case 1n+p QS{a, RNil{}}:
      a
    case 1n+p QS{a, RCon{+lo, +hi, t}}:
      +n = U32.sub(U32.max(hi, lo), lo)
      qs_loop(p, qs_range(U32.is_le(n, 24), lo, hi, n, t, a))

# sorts the records [lo, hi)
def sort_range(+lo: U32, +hi: U32, a: Array<U32>) -> Array<U32>:
  qs_loop(U32.to_nat((U32.mul(U32.sub(U32.max(hi, lo), lo), 3) + 3 : U32)), QS{a, RCon{lo, hi, RNil{}}})

def sort2(+n: U32, a: Array<U32>) -> Array<U32>:
  sort_range(0, n, a)

# Unique (std::unique on sorted records)
# ======================================

type UQ is Type:
  UQ{a: Array<U32>, +w: U32, +px: U32, +py: U32}

def uq_s(keep: Bool, +w: U32, +px: U32, +py: U32, +x: U32, +y: U32, a: Array<U32>) -> UQ:
  match keep:
    case True{}:
      UQ{put2(a, w, x, y), (w + 1 : U32), x, y}
    case False{}:
      UQ{a, w, px, py}

def uq_r(+r: U32, +w: U32, +px: U32, +py: U32, g: A2) -> UQ:
  A2{a, +x, +y} = g
  uq_s(U32.is_eq(r, 0) || U32.is_ne(x, px) || U32.is_ne(y, py), w, px, py, x, y, a)

def uq_go(n: Nat, +r: U32, st: UQ) -> UQ:
  match n st:
    case 0n _:
      st
    case 1n+p UQ{a, +w, +px, +py}:
      uq_go(p, (r + 1 : U32), uq_r(r, w, px, py, get2(a, r)))

type AN is Type:
  AN{a: Array<U32>, +n: U32}

def uq_fin(st: UQ) -> AN:
  UQ{a, +w, px, py} = st
  AN{a, w}

# sort the n records, drop duplicates; returns the array and the new count
def sort_unique(+n: U32, a: Array<U32>) -> AN:
  uq_fin(uq_go(U32.to_nat(n), 0, UQ{sort2(n, a), 0, 0, 0}))
