# Weighted graph aggregation, retaining igraph's summation and encounter order.
import Base
import ./f64.bend as F
import ./cl_graph.bend as G
import ./cl_leiden_state.bend as S
import ./cl_leiden_common.bend as C
import ./cl_leiden_move.bend as M

type AG is Type:
  AG{s: S.S, rows: Array<List<&2, G.Nb>>}

type AN is Type:
  AN{s: S.S, ns: List<&2, U32>, weight: F.D, last: U32}

def collect_edges(xs: List<&2, G.Nb>, s: S.S, +c: U32, ns: List<&2, U32>) -> M.NS:
  match xs:
    case Nil{}: M.NS{s, ns}
    case Con{G.Nb{u, +h, +l}, rest}:
      C.gu(M.NS, S.ref_get(s, u), s => +c2 =>
      C.when(M.NS, U32.is_gt(c2, c), \{
        False: collect_edges(rest, s, c, ns)
        True: C.gu(M.NS, S.added_get(s, c2), s => added => (
          s = S.ewpc_add(s, c2, F.D{h, l})
          C.when(M.NS, U32.is_eq(added, 0), \{
            True: collect_edges(rest, S.added_set(s, c2, 1), c, c2 <> ns)
            False: collect_edges(rest, s, c, ns)
          })))
      }))

def after_edges(ns: M.NS, +weight: F.D, +last: U32) -> AN:
  match ns:
    case M.NS{s, ns}: AN{s, ns, weight, last}

def collect_vertices(vs: List<&2, U32>, a: AN, +c: U32) -> AN:
  match vs a:
    case Nil{} AN{s, ns, weight, last}: AN{s, ns, weight, last}
    case Con{+v, rest} AN{s, ns, +weight, last}:
      C.gd(AN, S.nw_get(s, v), s => w =>
      C.gr(AN, S.rows_get(s, v), s => xs =>
        collect_vertices(rest, after_edges(collect_edges(xs, s, c, ns), F.d_add(weight, w), v), c)))

def emit(ns: List<&2, U32>, a: AG, +c: U32) -> AG:
  match ns a:
    case Nil{} AG{s, rows}: AG{s, rows}
    case Con{+c2, rest} AG{s, rows}:
      C.gd(AG, S.ewpc_get(s, c2), s => w => (
        s = S.added_set(S.ewpc_set(s, c2, C.zero()), c2, 0)
        emit(rest, AG{s, G.push_edge(rows, c, c2, w)}, c)))

def finish(a: AN, rows: Array<List<&2, G.Nb>>, +c: U32) -> AG:
  match a:
    case AN{s, ns, weight, last}:
      C.gu(AG, S.mem_get(s, last), s => mem => (
        s = S.amem_set(S.anw_set(s, c, weight), c, mem)
        emit(G.rev_u32(ns, Nil{}), AG{s, rows}, c)))

def build(fuel: Nat, a: AG, +c: U32) -> AG:
  match fuel a:
    case 0n AG{s, rows}: AG{s, rows}
    case 1n+p AG{s, rows}:
      C.gl(AG, C.group(s, c), s => vs =>
        build(p, finish(collect_vertices(vs, AN{s, Nil{}, C.zero(), 0}, c), rows, c), U32.inc(c)))

def install_values(fuel: Nat, s: S.S, +i: U32) -> S.S:
  match fuel:
    case 0n: s
    case 1n+p:
      C.gu(S.S, S.amem_get(s, i), s => mem =>
      C.gd(S.S, S.anw_get(s, i), s => nw =>
        install_values(p, S.mem_set(S.nw_set(s, i, nw), i, mem), U32.inc(i))))

def install_rows(rs: G.RS, s: S.S) -> S.S:
  match rs:
    case G.RS{rows, m}: S.replace_graph(s, rows)

def install(a: AG, +n: U32) -> S.S:
  match a:
    case AG{s, rows}:
      install_values(U32.to_nat(n), install_rows(G.sort_rows(U32.to_nat(n), 0, G.RS{rows, 0}), s), 0)

def aggregate(s: S.S, +n: U32, +nr: U32) -> S.S:
  s = C.groups(s, n, 1)
  install(build(U32.to_nat(nr), AG{s, Array.new(List<&2, G.Nb>, G.depth(nr), Nil{})}, 0), nr)
