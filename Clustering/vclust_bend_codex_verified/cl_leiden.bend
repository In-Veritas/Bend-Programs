# Clusty 1.2.2 / igraph 0.10.10 weighted Leiden, entirely in Bend.
# Exhausted finite safety budgets return nclusters=U32_MAX; the CLI rejects it.
import Base
import ./f64.bend as F
import ./cl_graph.bend as G
import ./cl_leiden_state.bend as S
import ./cl_leiden_common.bend as C
import ./cl_leiden_move.bend as M
import ./cl_leiden_refine.bend as R
import ./cl_leiden_aggregate.bend as A

def initial(fuel: Nat, s: S.S, +i: U32) -> S.S:
  match fuel:
    case 0n: s
    case 1n+p: initial(p, S.orig_set(s, i, i), U32.inc(i))

def restart(fuel: Nat, s: S.S, +i: U32) -> S.S:
  match fuel:
    case 0n: s
    case 1n+p:
      C.gu(S.S, S.orig_get(s, i), s => mem =>
        restart(p, S.mapping_set(S.nw_set(S.mem_set(s, i, mem), i, C.one()), i, i), U32.inc(i)))

def project(fuel: Nat, s: S.S, +i: U32) -> S.S:
  match fuel:
    case 0n: s
    case 1n+p:
      C.gu(S.S, S.mapping_get(s, i), s => node =>
      C.gu(S.S, S.mem_get(s, node), s => mem =>
        project(p, S.orig_set(s, i, mem), U32.inc(i))))

def map_next(fuel: Nat, s: S.S, +i: U32) -> S.S:
  match fuel:
    case 0n: s
    case 1n+p:
      C.gu(S.S, S.mapping_get(s, i), s => node =>
      C.gu(S.S, S.ref_get(s, node), s => node =>
        map_next(p, S.mapping_set(s, i, node), U32.inc(i))))

def fallback(fuel: Nat, s: S.S, +i: U32) -> S.S:
  match fuel:
    case 0n: s
    case 1n+p:
      C.gu(S.S, S.mem_get(s, i), s => c =>
        fallback(p, S.ref_set(s, i, c), U32.inc(i)))

def refined(s: S.S, +n: U32, +nc: U32, +nr: U32) -> S.S & U32:
  C.when(S.S & U32, U32.is_ge(nr, n), \{
    True: (fallback(U32.to_nat(n), s, 0), nc)
    False: (s, nr)
  })

def levels(fuel: Nat, s: S.S, +n0: U32, +n: U32, +level: U32,
           +res: F.D, +beta: F.D, +tab: F.Tab) -> S.S:
  match fuel:
    case 0n: S.err_set(s, True{})
    case 1n+p:
      C.gu(S.S, M.fastmove(s, n, res), s => +nc =>
      C.when(S.S, U32.is_lt(nc, n), \{
        False: C.when(S.S, U32.is_eq(level, 0), \{
          True: project(U32.to_nat(n0), s, 0)
          False: s
        })
        True: (
          s = project(U32.to_nat(n0), s, 0)
          C.gu(S.S, R.refine(s, n, nc, res, beta, tab), s => nr =>
          C.gu(S.S, refined(s, n, nc, nr), s => +nr => (
            s = map_next(U32.to_nat(n0), s, 0)
            levels(p, A.aggregate(s, n, nr), n0, nr, U32.inc(level), res, beta, tab))))
        )
      }))

def once(s: S.S, +n: U32, +res: F.D, +beta: F.D, +tab: F.Tab) -> S.S:
  s = restart(U32.to_nat(n), S.changed_set(S.reset_graph(s), False{}), 0)
  C.gu(S.S, C.reindex(s, 0, n), s => nc =>
    levels(U32.to_nat(U32.inc(n)), s, n, n, 0, res, beta, tab))

# Preserve this bundled igraph version's negative-iteration `!changed` loop.
def iterations(fuel: Nat, s: S.S, +n: U32, +res: F.D, +beta: F.D, +tab: F.Tab, +ineg: Bool) -> S.S:
  match fuel:
    case 0n:
      C.when(S.S, ineg, \{
        True: S.err_set(s, True{})
        False: s
      })
    case 1n+p:
      s = once(s, n, res, beta, tab)
      C.gb(S.S, S.err_get(s), s => err =>
      C.when(S.S, err, \{
        True: s
        False: C.gb(S.S, S.changed_get(s), s => changed =>
          C.when(S.S, ineg && changed, \{
            True: s
            False: iterations(p, s, n, res, beta, tab, ineg)
          }))
      }))

def count_labels(fuel: Nat, s: S.S, +i: U32, +nc: U32) -> S.S & U32:
  match fuel:
    case 0n: (s, nc)
    case 1n+p:
      C.gu(S.S & U32, S.orig_get(s, i), s => c =>
        count_labels(p, s, U32.inc(i), U32.max(nc, U32.inc(c))))

def result(s: S.S, +n: U32) -> Array<U32> & U32:
  # Do not reindex projected labels: Clusty's equal-size ordering uses them.
  C.gu(Array<U32> & U32, count_labels(U32.to_nat(n), s, 0, 0), s => +nc =>
  C.gb(Array<U32> & U32, S.err_get(s), s => err =>
    (S.output(s), F.sel(err, 4294967295, nc))))

def leiden(rows: Array<List<&2, G.Nb>>, +n: U32, +m: U32, +res: F.D,
           +beta: F.D, +iters: U32, +ineg: Bool) -> Array<U32> & U32:
  rows = C.weights_rows(U32.to_nat(n), rows, 0)
  s = initial(U32.to_nat(n), S.new(n, rows), 0)
  result(iterations(U32.to_nat(F.sel(ineg, 1000, iters)), s, n, res, beta, F.exp_table(), ineg), n)
