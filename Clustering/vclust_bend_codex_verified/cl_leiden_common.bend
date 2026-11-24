# Shared, affine operations for the Clusty-compatible Leiden port.
import Base
import ./f64.bend as F
import ./cl_graph.bend as G
import ./cl_leiden_state.bend as S

def when(-A: Type, c: Bool, k: Bool -> A) -> A:
  k(c)

def gu(-A: Type, p: S.S & U32, k: S.S -> U32 -> A) -> A:
  (s, x) = p
  k(s)(x)

def gd(-A: Type, p: S.S & F.D, k: S.S -> F.D -> A) -> A:
  (s, x) = p
  k(s)(x)

def gl(-A: Type, p: S.S & List<&2, U32>, k: S.S -> List<&2, U32> -> A) -> A:
  (s, x) = p
  k(s)(x)

def gr(-A: Type, p: S.S & List<&2, G.Nb>, k: S.S -> List<&2, G.Nb> -> A) -> A:
  (s, x) = p
  k(s)(x)

def gb(-A: Type, p: S.S & Bool, k: S.S -> Bool -> A) -> A:
  (s, x) = p
  k(s)(x)

def zero() -> F.D:
  F.D{0, 0}

def one() -> F.D:
  F.D{1072693248, 0}

def clear(fuel: Nat, s: S.S, +i: U32) -> S.S:
  match fuel:
    case 0n:
      s
    case 1n+p:
      s = S.count_set(s, i, 0)
      s = S.stable_set(s, i, 0)
      s = S.added_set(s, i, 0)
      s = S.nonsingle_set(s, i, 0)
      s = S.newc_set(s, i, 4294967295)
      s = S.order_set(s, i, i)
      s = S.cw_set(s, i, zero())
      s = S.ext_set(s, i, zero())
      s = S.ewpc_set(s, i, zero())
      s = S.cum_set(s, i, zero())
      s = S.anw_set(s, i, zero())
      clear(p, S.groups_set(s, i, Nil{}), U32.inc(i))

def reindex_clear(fuel: Nat, s: S.S, +i: U32) -> S.S:
  match fuel:
    case 0n:
      s
    case 1n+p:
      reindex_clear(p, S.newc_set(s, i, 4294967295), U32.inc(i))

def label_get(s: S.S, +which: U32, +i: U32) -> S.S & U32:
  when(S.S & U32, U32.is_eq(which, 0), \{
    True: S.mem_get(s, i)
    False: S.orig_get(s, i)
  })

def label_set(s: S.S, +which: U32, +i: U32, x: U32) -> S.S:
  when(S.S, U32.is_eq(which, 0), \{
    True: S.mem_set(s, i, x)
    False: S.orig_set(s, i, x)
  })

def reindex_go(fuel: Nat, s: S.S, +which: U32, +i: U32, +k: U32) -> S.S & U32:
  match fuel:
    case 0n:
      (s, k)
    case 1n+p:
      gu(S.S & U32, label_get(s, which, i), s => +old =>
      gu(S.S & U32, S.newc_get(s, old), s => +v =>
      when(S.S & U32, U32.is_eq(v, 4294967295), \{
        True: reindex_go(p, label_set(S.newc_set(s, old, k), which, i, k), which, U32.inc(i), U32.inc(k))
        False: reindex_go(p, label_set(s, which, i, v), which, U32.inc(i), k)
      })))

def reindex(s: S.S, +which: U32, +n: U32) -> S.S & U32:
  reindex_go(U32.to_nat(n), reindex_clear(U32.to_nat(n), s, 0), which, 0, 0)

def groups_build(fuel: Nat, s: S.S, +i: U32, +which: U32) -> S.S:
  match fuel:
    case 0n:
      s
    case 1n+p:
      gu(S.S, when(S.S & U32, U32.is_eq(which, 0), \{
        True: S.mem_get(s, i)
        False: S.ref_get(s, i)
      }), s => +c =>
      gl(S.S, S.groups_get(s, c), s => old =>
        groups_build(p, S.groups_set(s, c, i <> old), U32.inc(i), which)))

def groups_clear(fuel: Nat, s: S.S, +i: U32) -> S.S:
  match fuel:
    case 0n:
      s
    case 1n+p:
      groups_clear(p, S.groups_set(s, i, Nil{}), U32.inc(i))

def groups(s: S.S, +n: U32, +which: U32) -> S.S:
  groups_build(U32.to_nat(n), groups_clear(U32.to_nat(n), s, 0), 0, which)

def group(s: S.S, +c: U32) -> S.S & List<&2, U32>:
  gl(S.S & List<&2, U32>, S.groups_get(s, c), s => xs => (s, G.rev_u32(xs, Nil{})))

def list_len(xs: List<&2, U32>, +n: U32) -> U32:
  match xs:
    case Nil{}: n
    case Con{h, t}: list_len(t, U32.inc(n))

def order_from(xs: List<&2, U32>, s: S.S, +i: U32) -> S.S:
  match xs:
    case Nil{}: s
    case Con{h, t}: order_from(t, S.order_set(s, i, h), U32.inc(i))

# Clusty inserts both matrix directions into an undirected igraph graph.
# Each neighbour is therefore encountered twice, in the same sorted order.
def weights(xs: List<&2, G.Nb>) -> List<&2, G.Nb>:
  match xs:
    case Nil{}: Nil{}
    case Con{G.Nb{+id, h, l}, t}:
      S.pair(U32, U32, List<&2, G.Nb>, F.sub(1072693248, 0, h, l), +wh => +wl =>
        G.Nb{id, wh, wl} <> G.Nb{id, wh, wl} <> weights(t))

def weights_rows(fuel: Nat, rows: Array<List<&2, G.Nb>>, +i: U32) -> Array<List<&2, G.Nb>>:
  match fuel:
    case 0n: rows
    case 1n+p:
      S.pair(Array<List<&2, G.Nb>>, List<&2, G.Nb>, Array<List<&2, G.Nb>>,
        Array.get(List<&2, G.Nb>, rows, i), rows => xs =>
          weights_rows(p, Array.set(List<&2, G.Nb>, rows, i, weights(xs)), U32.inc(i)))
