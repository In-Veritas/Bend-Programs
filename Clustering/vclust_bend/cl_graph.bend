# Clusty's sparse matrix and its linear-time kernels.
#
# rows[v] lists v's neighbours by increasing local id, one entry per
# neighbour, holding the smallest distance d = 1 - v among duplicate rows
# (Clusty sorts each row by (id, d) and keeps the first of equal ids).
# All kernels below are O(V + E) like Clusty's (the old benchmark kernels
# scanned every representative per object: O(V * clusters)).
import Base
import ./f64.bend as F
import ./cl_load.bend as L

type Nb is Data:
  Nb{+id: U32, +dh: U32, +dl: U32}



type RS is Type:
  RS{rows: Array<List<&2, Nb>>, +m: U32}



# ---------------------------------------------------------------------------
# Kernels share this state: rows, assignment (none = unassigned), counter.

type St is Type:
  St{rows: Array<List<&2, Nb>>, asg: Array<U32>, +cid: U32}



# set-cover order: objects by decreasing degree, stable
type DegObj is Data:
  DegObj{+deg: U32, +pos: U32, +obj: U32}



type DL is Type:
  DL{rows: Array<List<&2, Nb>>, +items: List<&2, DegObj>, +pos: U32}



# single linkage (Clusty SingleLinkageBFS): connected components, numbered
# by first object; a FIFO queue (std::deque) as front list + reversed back
type FS is Type:
  FS{rows: Array<List<&2, Nb>>, asg: Array<U32>, +cid: U32, +front: List<&2, U32>, +back: List<&2, U32>}



# UCLUST: seed[v] = cluster of seed v (none otherwise). For each object
# after the first, the closest seed among its neighbours (a strictly
# smaller distance wins, so ties keep the lowest local id) takes it, else
# it becomes a seed. Clusty's "no seed" distance is DBL_MAX, which never
# passes its threshold, so "none found" is the same test.
type Best is Data:
  Best{+cl: U32, +dh: U32, +dl: U32}



type SB is Type:
  SB{seed: Array<U32>, +b: Best}



type US is Type:
  US{rows: Array<List<&2, Nb>>, seed: Array<U32>, asg: Array<U32>, +ns: U32}



def none() -> U32:
  4294967295



# power-of-two depth holding n cells (n >= 1)
def depth_go(n: Nat, +need: U32, +cap: U32, +d: U32) -> U32:
  match n:
    case 0n:
      d
    case 1n+p:
      depth_go(p, need, F.sel(U32.is_ge(cap, need), cap, U32.shl(cap)),
        F.sel(U32.is_ge(cap, need), d, U32.inc(d)))



def depth(+n: U32) -> Nat:
  U32.to_nat(depth_go(32n, U32.max(n, 1), 1, 0))



def u32_array(+n: U32, +v: U32) -> Array<U32>:
  Array.new(U32, depth(n), v)



# ---------------------------------------------------------------------------
# Building rows

# Clusty's value table m_k for k = 0..15
def mtab(n: Nat, +m: F.D) -> List<&2, F.D>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      m <> mtab(p, F.d_mul(m, F.D{1069128089, 2576980378}))



def nth_pick(c: Bool, +a: F.D, +b: F.D) -> F.D:
  match c:
    case True{}:
      a
    case False{}:
      b



def nth_d(xs: List<&2, F.D>, +i: U32) -> F.D:
  match xs:
    case Nil{}:
      F.D{0, 0}
    case Con{+x, t}:
      nth_pick(U32.is_eq(i, 0), x, nth_d(t, U32.sub(i, 1)))



# d = 1 - v(N, k) when distances are needed, else 0
def edge_dist(need: Bool, +n: U32, +k: U32, +mt: List<&2, F.D>) -> F.D:
  match need:
    case False{}:
      F.D{0, 0}
    case True{}:
      F.d_sub(F.D{1072693248, 0}, L.clusty_value(n, k, nth_d(mt, k)))



def push_row_go(r: Array<List<&2, Nb>> & List<&2, Nb>, +v: U32, +x: Nb) -> Array<List<&2, Nb>>:
  (rows, l) = r
  Array.set(List<&2, Nb>, rows, v, x <> l)



def push_row(rows: Array<List<&2, Nb>>, +v: U32, +x: Nb) -> Array<List<&2, Nb>>:
  push_row_go(Array.swap(List<&2, Nb>, rows, v, Nil{}), v, x)



def push_edge(rows: Array<List<&2, Nb>>, +a: U32, +b: U32, d: F.D) -> Array<List<&2, Nb>>:
  match d:
    case F.D{h, l}:
      push_row(push_row(rows, a, Nb{b, h, l}), b, Nb{a, h, l})



def add_edges(es: List<&2, L.Edge>, rows: Array<List<&2, Nb>>, +need: Bool, +mt: List<&2, F.D>) -> Array<List<&2, Nb>>:
  match es:
    case Nil{}:
      rows
    case Con{e, t}:
      match e:
        case L.Edge{a, b, n, k}:
          add_edges(t, push_edge(rows, a, b, edge_dist(need, n, k, mt)), need, mt)



def nb_le(x: Nb, y: Nb) -> Bool:
  match x y:
    case Nb{xi, xh, xl} Nb{yi, yh, yl}:
      F.lex_lt_go(U32.is_eq(xi, yi), U32.is_lt(xi, yi), F.le(xh, xl, yh, yl))



def nb_id(x: Nb) -> U32:
  match x:
    case Nb{i, h, l}:
      i



def dedup_pick(same: Bool, +x: Nb, rest: List<&2, Nb>) -> List<&2, Nb>:
  match same:
    case True{}:
      rest
    case False{}:
      x <> rest



# drop entries whose id equals the previous one (input sorted)
def dedup(xs: List<&2, Nb>, +prev: U32) -> List<&2, Nb>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+x, t}:
      dedup_pick(U32.is_eq(nb_id(x), prev), x, dedup(t, nb_id(x)))



def sort_row(xs: List<&2, Nb>) -> List<&2, Nb>:
  dedup(List.sort(~Nb, ~nb_le, xs), none())



def len_nb(xs: List<&2, Nb>, +acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{x, t}:
      len_nb(t, U32.inc(acc))



def sort_rows_set(rows: Array<List<&2, Nb>>, +v: U32, +m: U32, +l: List<&2, Nb>) -> RS:
  RS{Array.set(List<&2, Nb>, rows, v, l), U32.add(m, len_nb(l, 0))}



def sort_rows_go(r: Array<List<&2, Nb>> & List<&2, Nb>, +v: U32, +m: U32) -> RS:
  (rows, l) = r
  sort_rows_set(rows, v, m, sort_row(l))



def sort_rows(n: Nat, +v: U32, st: RS) -> RS:
  match n:
    case 0n:
      st
    case 1n+p:
      match st:
        case RS{rows, m}:
          sort_rows(p, U32.inc(v), sort_rows_go(Array.swap(List<&2, Nb>, rows, v, Nil{}), v, m))



# rows of the filtered graph and its number of (directed) entries
def build_rows(es: List<&2, L.Edge>, +nloc: U32, +need: Bool) -> RS:
  sort_rows(U32.to_nat(nloc), 0, RS{add_edges(es,
    Array.new(List<&2, Nb>, depth(nloc), Nil{}), need, mtab(16n, F.D{1072693248, 0})), 0})



def row_get(rows: Array<List<&2, Nb>>, +v: U32) -> Array<List<&2, Nb>> & List<&2, Nb>:
  Array.get(List<&2, Nb>, rows, v)



def obj_cons(skip: Bool, +l: U32, rest: List<&2, U32>) -> List<&2, U32>:
  match skip:
    case True{}:
      rest
    case False{}:
      l <> rest


def rev_u32(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      rev_u32(t, h <> acc)



# ---------------------------------------------------------------------------
# Objects: local ids in ids-file order (Clusty's reorderObjects)

def objects_go(n: Nat, +gi: U32, r: Array<U32> & U32, +acc: List<&2, U32>) -> Array<U32> & List<&2, U32>:
  match n:
    case 0n:
      (g2l, l) = r
      (g2l, rev_u32(acc, Nil{}))
    case 1n+p:
      (g2l, +l) = r
      objects_go(p, U32.inc(gi), Array.get(U32, g2l, U32.inc(gi)), obj_cons(U32.is_eq(l, none()), l, acc))


def objects(g2l: Array<U32>, +nnames: U32) -> Array<U32> & List<&2, U32>:
  objects_go(U32.to_nat(nnames), 0, Array.get(U32, g2l, 0), Nil{})



# assign every unassigned neighbour to cid (CD-HIT / set-cover)
def claim_one(r: Array<U32> & U32, +id: U32, +cid: U32) -> Array<U32>:
  (asg, +v) = r
  Array.set(U32, asg, id, F.sel(U32.is_eq(v, none()), cid, v))



def claim(ns: List<&2, Nb>, asg: Array<U32>, +cid: U32) -> Array<U32>:
  match ns:
    case Nil{}:
      asg
    case Con{x, t}:
      match x:
        case Nb{id, h, l}:
          claim(t, claim_one(Array.get(U32, asg, id), id, cid), cid)



def greedy_seed(r: Array<List<&2, Nb>> & List<&2, Nb>, asg: Array<U32>, +o: U32, +cid: U32) -> St:
  (rows, ns) = r
  St{rows, claim(ns, Array.set(U32, asg, o, cid), cid), U32.inc(cid)}



def greedy_new(fresh: Bool, rows: Array<List<&2, Nb>>, asg: Array<U32>, +o: U32, +cid: U32) -> St:
  match fresh:
    case True{}:
      greedy_seed(row_get(rows, o), asg, o, cid)
    case False{}:
      St{rows, asg, cid}



def greedy_obj(r: Array<U32> & U32, rows: Array<List<&2, Nb>>, +o: U32, +cid: U32) -> St:
  (asg, +v) = r
  greedy_new(U32.is_eq(v, none()), rows, asg, o, cid)



def greedy(objs: List<&2, U32>, st: St) -> St:
  match objs:
    case Nil{}:
      st
    case Con{+o, t}:
      match st:
        case St{rows, asg, cid}:
          greedy(t, greedy_obj(Array.get(U32, asg, o), rows, o, cid))



def dego_le(x: DegObj, y: DegObj) -> Bool:
  match x y:
    case DegObj{xd, xp, xo} DegObj{yd, yp, yo}:
      Bool.or(U32.is_gt(xd, yd), Bool.and(U32.is_eq(xd, yd), U32.is_le(xp, yp)))



def dego_obj(x: DegObj) -> U32:
  match x:
    case DegObj{d, p, o}:
      o



def dego_strip(xs: List<&2, DegObj>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{x, t}:
      dego_obj(x) <> dego_strip(t)



def dego_one(r: Array<List<&2, Nb>> & List<&2, Nb>, +o: U32, +items: List<&2, DegObj>, +pos: U32) -> DL:
  (rows, ns) = r
  DL{rows, DegObj{len_nb(ns, 0), pos, o} <> items, U32.inc(pos)}



def dego_list(objs: List<&2, U32>, st: DL) -> DL:
  match objs:
    case Nil{}:
      st
    case Con{+o, t}:
      match st:
        case DL{rows, items, pos}:
          dego_list(t, dego_one(row_get(rows, o), o, items, pos))



def by_degree(dl: DL) -> Array<List<&2, Nb>> & List<&2, U32>:
  match dl:
    case DL{rows, items, pos}:
      (rows, dego_strip(List.sort(~DegObj, ~dego_le, items)))



def push_ids(ns: List<&2, Nb>, acc: List<&2, U32>) -> List<&2, U32>:
  match ns:
    case Nil{}:
      acc
    case Con{x, t}:
      push_ids(t, nb_id(x) <> acc)



def cons_if(c: Bool, +o: U32, +back: List<&2, U32>) -> List<&2, U32>:
  match c:
    case True{}:
      o <> back
    case False{}:
      back

def apply_au(-B: Type, body: Array<U32> & U32 -> B, v: Array<U32> & U32) -> B:
  body(v)

# Q.push_back(other) for every neighbour not assigned yet (edge order)
def push_new(ns: List<&2, Nb>, asg: Array<U32>, +back: List<&2, U32>) -> Array<U32> & List<&2, U32>:
  match ns:
    case Nil{}:
      (asg, back)
    case Con{x, t}:
      +o = nb_id(x)
      apply_au(Array<U32> & List<&2, U32>, \{Tuple: asg2 => +v => (
        push_new(t, asg2, cons_if(U32.is_eq(v, none()), o, back))
      )}, Array.get(U32, asg, o))

def flood_push(rows: Array<List<&2, Nb>>, +cid: U32, +front: List<&2, U32>, r: Array<U32> & List<&2, U32>) -> FS:
  (asg, +back) = r
  FS{rows, asg, cid, front, back}

def flood_open(r: Array<List<&2, Nb>> & List<&2, Nb>, asg: Array<U32>, +x: U32, +cid: U32, +front: List<&2, U32>,
               +back: List<&2, U32>) -> FS:
  (rows, ns) = r
  flood_push(rows, cid, front, push_new(ns, Array.set(U32, asg, x, cid), back))

def flood_new(fresh: Bool, rows: Array<List<&2, Nb>>, asg: Array<U32>, +x: U32, +cid: U32, +front: List<&2, U32>,
              +back: List<&2, U32>) -> FS:
  match fresh:
    case True{}:
      flood_open(row_get(rows, x), asg, x, cid, front, back)
    case False{}:
      FS{rows, asg, cid, front, back}

def flood_visit(r: Array<U32> & U32, rows: Array<List<&2, Nb>>, +x: U32, +cid: U32, +front: List<&2, U32>,
                +back: List<&2, U32>) -> FS:
  (asg, +v) = r
  flood_new(U32.is_eq(v, none()), rows, asg, x, cid, front, back)

def rev_q(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case Con{+x, t}:
      rev_q(t, x <> acc)

def flood(n: Nat, fs: FS) -> FS:
  match n:
    case 0n:
      fs
    case 1n+p:
      match fs:
        case FS{rows, asg, cid, front, back}:
          match front back:
            case Nil{} Nil{}:
              FS{rows, asg, cid, Nil{}, Nil{}}
            case Nil{} Con{+y, u}:
              flood(p, FS{rows, asg, cid, rev_q(Con{y, u}, Nil{}), Nil{}})
            case Con{+x, t} _:
              flood(p, flood_visit(Array.get(U32, asg, x), rows, x, cid, t, back))

def single_fin(fs: FS) -> St:
  match fs:
    case FS{rows, asg, cid, front, back}:
      St{rows, asg, U32.inc(cid)}



def single_new(fresh: Bool, +fuel: Nat, rows: Array<List<&2, Nb>>, asg: Array<U32>, +o: U32, +cid: U32) -> St:
  match fresh:
    case True{}:
      single_fin(flood(fuel, FS{rows, asg, cid, [o], Nil{}}))
    case False{}:
      St{rows, asg, cid}



def single_obj(r: Array<U32> & U32, +fuel: Nat, rows: Array<List<&2, Nb>>, +o: U32, +cid: U32) -> St:
  (asg, +v) = r
  single_new(U32.is_eq(v, none()), fuel, rows, asg, o, cid)



def single(objs: List<&2, U32>, +fuel: Nat, st: St) -> St:
  match objs:
    case Nil{}:
      st
    case Con{+o, t}:
      match st:
        case St{rows, asg, cid}:
          single(t, fuel, single_obj(Array.get(U32, asg, o), fuel, rows, o, cid))



def best_pick(take: Bool, seed: Array<U32>, +x: Best, +y: Best) -> SB:
  match take:
    case True{}:
      SB{seed, x}
    case False{}:
      SB{seed, y}



def best_step(r: Array<U32> & U32, +b: Best, +dh: U32, +dl: U32) -> SB:
  (seed, +c) = r
  match b:
    case Best{bc, bh, bl}:
      best_pick(Bool.and(U32.is_ne(c, none()), Bool.or(U32.is_eq(bc, none()), F.lt(dh, dl, bh, bl))),
        seed, Best{c, dh, dl}, Best{bc, bh, bl})



def best_seed(ns: List<&2, Nb>, sb: SB) -> SB:
  match ns:
    case Nil{}:
      sb
    case Con{x, t}:
      match x:
        case Nb{id, h, l}:
          match sb:
            case SB{seed, b}:
              best_seed(t, best_step(Array.get(U32, seed, id), b, h, l))



def uc_pick(fresh: Bool, rows: Array<List<&2, Nb>>, seed: Array<U32>, asg: Array<U32>, +o: U32, +ns: U32, +bc: U32) -> US:
  match fresh:
    case True{}:
      US{rows, Array.set(U32, seed, o, ns), Array.set(U32, asg, o, ns), U32.inc(ns)}
    case False{}:
      US{rows, seed, Array.set(U32, asg, o, bc), ns}



def uc_fin(sb: SB, rows: Array<List<&2, Nb>>, asg: Array<U32>, +o: U32, +ns: U32) -> US:
  match sb:
    case SB{seed, b}:
      match b:
        case Best{bc, bh, bl}:
          uc_pick(U32.is_eq(bc, none()), rows, seed, asg, o, ns, bc)



def uc_obj(r: Array<List<&2, Nb>> & List<&2, Nb>, seed: Array<U32>, asg: Array<U32>, +o: U32, +ns: U32) -> US:
  (rows, nbs) = r
  uc_fin(best_seed(nbs, SB{seed, Best{none(), 0, 0}}), rows, asg, o, ns)



def uclust(objs: List<&2, U32>, us: US) -> US:
  match objs:
    case Nil{}:
      us
    case Con{+o, t}:
      match us:
        case US{rows, seed, asg, ns}:
          uclust(t, uc_obj(row_get(rows, o), seed, asg, o, ns))



def us_st(us: US) -> St:
  match us:
    case US{rows, seed, asg, ns}:
      St{rows, asg, ns}

def nb_rev_onto(xs: List<&2, Nb>, acc: List<&2, Nb>) -> List<&2, Nb>:
  match xs:
    case Nil{}:
      acc
    case Con{x, t}:
      nb_rev_onto(t, x <> acc)
