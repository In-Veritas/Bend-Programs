# Constrained singleton refinement, matching igraph's weighted random choice.
import Base
import ./f64.bend as F
import ./cl_graph.bend as G
import ./cl_leiden_state.bend as S
import ./cl_leiden_rng.bend as R
import ./cl_leiden_common.bend as C
import ./cl_leiden_move.bend as M

type Pick is Type:
  Pick{s: S.S, best: U32, maxd: F.D, total: F.D, len: U32}


def clear(fuel: Nat, s: S.S, +i: U32) -> S.S:
  match fuel:
    case 0n: s
    case 1n+p:
      s = S.cw_set(s, i, C.zero())
      s = S.ext_set(s, i, C.zero())
      s = S.ewpc_set(s, i, C.zero())
      s = S.added_set(s, i, 0)
      s = S.nonsingle_set(s, i, 0)
      s = S.count_set(s, i, 0)
      clear(p, S.newc_set(s, i, 4294967295), U32.inc(i))


def ext_init(xs: List<&2, G.Nb>, s: S.S, +v: U32, +ci: U32, +csub: U32) -> S.S:
  match xs:
    case Nil{}: s
    case Con{G.Nb{+u, +h, +l}, rest}:
      C.gu(S.S, S.mem_get(s, u), s => c =>
      C.when(S.S, U32.is_ne(u, v) && U32.is_eq(c, csub), \{
        True: ext_init(rest, S.ext_add(s, ci, F.D{h, l}), v, ci, csub)
        False: ext_init(rest, s, v, ci, csub)
      }))


def initialize(xs: List<&2, U32>, s: S.S, +i: U32, +csub: U32, +total: F.D) -> S.S & F.D:
  match xs:
    case Nil{}: (s, total)
    case Con{+v, rest}:
      C.gd(S.S & F.D, S.nw_get(s, v), s => +w =>
      C.gr(S.S & F.D, S.rows_get(s, v), s => row => (
        s = S.ref_set(S.count_set(S.cw_set(s, i, w), i, 1), v, i)
        initialize(rest, ext_init(row, s, v, i, csub), U32.inc(i), csub, F.d_add(total, w)))))


def neighbors(xs: List<&2, G.Nb>, s: S.S, +v: U32, +csub: U32, ns: List<&2, U32>) -> M.NS:
  match xs:
    case Nil{}: M.NS{s, ns}
    case Con{G.Nb{+u, +h, +l}, rest}:
      C.gu(M.NS, S.mem_get(s, u), s => c =>
      C.when(M.NS, U32.is_ne(u, v) && U32.is_eq(c, csub), \{
        False: neighbors(rest, s, v, csub, ns)
        True: C.gu(M.NS, S.ref_get(s, u), s => +rc =>
          C.gu(M.NS, S.added_get(s, rc), s => added => (
            s = S.ewpc_add(s, rc, F.D{h, l})
            C.when(M.NS, U32.is_eq(added, 0), \{
              True: neighbors(rest, S.added_set(s, rc, 1), v, csub, rc <> ns)
              False: neighbors(rest, s, v, csub, ns)
            }))))
      }))


def connected(+ext: F.D, +cw: F.D, +total: F.D, +res: F.D) -> Bool:
  F.d_ge(ext, F.d_mul(F.d_mul(cw, F.d_sub(total, cw)), res))


def evaluate(s: S.S, +c: U32, +nw: F.D, +sumw: F.D, +res: F.D, +beta: F.D,
             +tab: F.Tab, +best: U32, +maxd: F.D, +tot: F.D, +j: U32) -> Pick:
  C.gd(Pick, S.ext_get(s, c), s => ext =>
  C.gd(Pick, S.cw_get(s, c), s => +cw =>
  C.gd(Pick, S.ewpc_get(s, c), s => ew => (
    s = S.added_set(S.ewpc_set(s, c, C.zero()), c, 0)
    C.when(Pick, connected(ext, cw, sumw, res), \{
      False: Pick{s, best, maxd, tot, j}
      True: (
        +d = M.gain(ew, nw, cw, res)
        +better = F.d_gt(d, maxd)
        +newbest = F.sel(better, c, best)
        +newmax = G.nth_pick(better, d, maxd)
        C.when(Pick, F.d_ge(d, C.zero()), \{
          True: Pick{s, newbest, newmax, F.d_add(tot, F.d_exp(F.d_div(d, beta), tab)), j}
          False: Pick{s, newbest, newmax, tot, j}
        })
      )
    })))))


def save_pick(p: Pick, +c: U32) -> Pick:
  match p:
    case Pick{s, best, maxd, +tot, +j}:
      Pick{S.amem_set(S.cum_set(s, j, tot), j, c), best, maxd, tot, U32.inc(j)}


def picks(ns: List<&2, U32>, p: Pick, +nw: F.D, +sumw: F.D, +res: F.D, +beta: F.D, +tab: F.Tab) -> Pick:
  match ns p:
    case Nil{} Pick{s, best, maxd, tot, j}: Pick{s, best, maxd, tot, j}
    case Con{+c, rest} Pick{s, best, maxd, tot, +j}:
      # Evaluate one choice first; its cumulative weight is stored by save_pick.
      picks(rest, save_pick(evaluate(s, c, nw, sumw, res, beta, tab, best, maxd, tot, j), c),
        nw, sumw, res, beta, tab)


def binary(fuel: Nat, s: S.S, +lo: U32, +hi: U32, +r: F.D) -> S.S & U32:
  match fuel:
    case 0n: (S.err_set(s, True{}), lo)
    case 1n+p:
      C.when(S.S & U32, U32.is_gt(lo, hi), \{
        True: (s, lo)
        False: (
          +mid = U32.add(lo, U32.shrn(U32.sub(hi, lo), 1n))
          C.gd(S.S & U32, S.cum_get(s, mid), s => +x =>
          C.when(S.S & U32, F.d_gt(x, r), \{
            True: C.when(S.S & U32, U32.is_eq(mid, 0), \{
              True: (s, 0)
              False: binary(p, s, lo, U32.sub(mid, 1), r)
            })
            False: C.when(S.S & U32, F.d_lt(x, r), \{
              True: binary(p, s, U32.inc(mid), hi, r)
              False: (s, mid)
            })
          }))
        )
      })


def selected(p: Pick) -> S.S & U32:
  match p:
    case Pick{s, best, maxd, +tot, +len}:
      C.when(S.S & U32, F.d_lt(tot, F.D{2146435072, 0}), \{
        False: (s, best)
        True: C.gd(S.S & U32, R.uniform(s, tot), s => r =>
          C.gu(S.S & U32, binary(64n, s, 0, U32.sub(len, 1), r), s => pos =>
            S.amem_get(s, pos)))
      })


def choose(ns: M.NS, +cur: U32, +nw: F.D, +sumw: F.D, +res: F.D, +beta: F.D, +tab: F.Tab) -> S.S & U32:
  match ns:
    case M.NS{s, ns}:
      selected(picks(G.rev_u32(ns, Nil{}), Pick{s, cur, C.zero(), C.zero(), 0}, nw, sumw, res, beta, tab))


def update_ext(xs: List<&2, G.Nb>, s: S.S, +chosen: U32, +csub: U32) -> S.S:
  match xs:
    case Nil{}: s
    case Con{G.Nb{+u, +h, +l}, rest}:
      C.gu(S.S, S.mem_get(s, u), s => c =>
      C.when(S.S, U32.is_eq(c, csub), \{
        False: update_ext(rest, s, chosen, csub)
        True: C.gu(S.S, S.ref_get(s, u), s => rc =>
          C.when(S.S, U32.is_eq(rc, chosen), \{
            True: update_ext(rest, S.ext_sub(s, chosen, F.D{h, l}), chosen, csub)
            False: update_ext(rest, S.ext_add(s, chosen, F.D{h, l}), chosen, csub)
          }))
      }))


def move(s: S.S, +v: U32, +cur: U32, +csub: U32, +sumw: F.D, +res: F.D, +beta: F.D, +tab: F.Tab) -> S.S:
  s = S.added_set(S.count_set(S.cw_set(s, cur, C.zero()), cur, 0), cur, 1)
  C.gd(S.S, S.nw_get(s, v), s => +nw =>
  C.gr(S.S, S.rows_get(s, v), s => xs =>
  C.gu(S.S, choose(neighbors(xs, s, v, csub, [cur]), cur, nw, sumw, res, beta, tab), s => +chosen =>
  C.gu(S.S, S.count_get(s, chosen), s => nb => (
    s = S.count_set(S.cw_add(s, chosen, nw), chosen, U32.inc(nb))
    C.gr(S.S, S.rows_get(s, v), s => xs => (
      s = update_ext(xs, s, chosen, csub)
      C.when(S.S, U32.is_eq(chosen, cur), \{
        True: s
        False: S.nonsingle_set(S.ref_set(s, v, chosen), chosen, 1)
      }))))))))


def visit(s: S.S, +v: U32, +csub: U32, +sumw: F.D, +res: F.D, +beta: F.D, +tab: F.Tab) -> S.S:
  C.gu(S.S, S.ref_get(s, v), s => +cur =>
  C.gu(S.S, S.nonsingle_get(s, cur), s => ns =>
  C.gd(S.S, S.ext_get(s, cur), s => ext =>
  C.gd(S.S, S.cw_get(s, cur), s => cw =>
  C.when(S.S, U32.is_eq(ns, 0) && connected(ext, cw, sumw, res), \{
    True: move(s, v, cur, csub, sumw, res, beta, tab)
    False: s
  })))))


def run(fuel: Nat, s: S.S, +i: U32, +csub: U32, +sumw: F.D, +res: F.D, +beta: F.D, +tab: F.Tab) -> S.S:
  match fuel:
    case 0n: s
    case 1n+p:
      C.gu(S.S, S.order_get(s, i), s => v =>
        run(p, visit(s, v, csub, sumw, res, beta, tab), U32.inc(i), csub, sumw, res, beta, tab))


def clean(xs: List<&2, U32>, s: S.S, +next: U32) -> S.S & U32:
  match xs:
    case Nil{}: (s, next)
    case Con{+v, rest}:
      C.gu(S.S & U32, S.ref_get(s, v), s => +old =>
      C.gu(S.S & U32, S.newc_get(s, old), s => +nc =>
      C.when(S.S & U32, U32.is_eq(nc, 4294967295), \{
        True: clean(rest, S.ref_set(S.newc_set(s, old, next), v, next), U32.inc(next))
        False: clean(rest, S.ref_set(s, v, nc), next)
      })))


def merge(+subset: List<&2, U32>, s: S.S, +csub: U32, +res: F.D, +beta: F.D, +tab: F.Tab, +next: U32) -> S.S & U32:
  +n = C.list_len(subset, 0)
  s = clear(U32.to_nat(n), s, 0)
  C.gd(S.S & U32, initialize(subset, s, 0, csub, C.zero()), s => sumw => (
    s = R.shuffle(C.order_from(subset, s, 0), n)
    clean(subset, run(U32.to_nat(n), s, 0, csub, sumw, res, beta, tab), next)))


def clusters(fuel: Nat, s: S.S, +c: U32, +res: F.D, +beta: F.D, +tab: F.Tab, +next: U32) -> S.S & U32:
  match fuel:
    case 0n: (s, next)
    case 1n+p:
      C.gl(S.S & U32, C.group(s, c), s => subset =>
      C.gu(S.S & U32, merge(subset, s, c, res, beta, tab, next), s => next =>
        clusters(p, s, U32.inc(c), res, beta, tab, next)))


def refine(s: S.S, +n: U32, +nc: U32, +res: F.D, +beta: F.D, +tab: F.Tab) -> S.S & U32:
  clusters(U32.to_nat(nc), C.groups(s, n, 0), 0, res, beta, tab, 0)
