# igraph Leiden fast local moves, including queue order and strict tie rules.
import Base
import ./f64.bend as F
import ./cl_graph.bend as G
import ./cl_leiden_state.bend as S
import ./cl_leiden_rng.bend as R
import ./cl_leiden_common.bend as C

type Q is Type:
  Q{s: S.S, head: U32, tail: U32, ne: U32}

type NS is Type:
  NS{s: S.S, ns: List<&2, U32>}

type Choice is Type:
  Choice{s: S.S, best: U32, gain: F.D}

def initialize(fuel: Nat, s: S.S, +i: U32) -> S.S:
  match fuel:
    case 0n: s
    case 1n+p:
      C.gu(S.S, S.mem_get(s, i), s => +c =>
      C.gd(S.S, S.nw_get(s, i), s => w =>
      C.gu(S.S, S.count_get(s, c), s => count =>
        initialize(p, S.count_set(S.cw_add(s, c, w), c, U32.inc(count)), U32.inc(i)))))

def empties(fuel: Nat, s: S.S, +i: U32, +ne: U32) -> S.S & U32:
  match fuel:
    case 0n: (s, ne)
    case 1n+p:
      C.gu(S.S & U32, S.count_get(s, i), s => count =>
      C.when(S.S & U32, U32.is_eq(count, 0), \{
        True: empties(p, S.empty_set(s, ne, i), U32.inc(i), U32.inc(ne))
        False: empties(p, s, U32.inc(i), ne)
      }))

def queue_init(fuel: Nat, s: S.S, +i: U32) -> S.S:
  match fuel:
    case 0n: s
    case 1n+p:
      C.gu(S.S, S.order_get(s, i), s => v =>
        queue_init(p, S.queue_set(s, i, v), U32.inc(i)))

def neighbors(xs: List<&2, G.Nb>, s: S.S, +v: U32, ns: List<&2, U32>) -> NS:
  match xs:
    case Nil{}: NS{s, ns}
    case Con{G.Nb{+u, +h, +l}, rest}:
      C.when(NS, U32.is_eq(u, v), \{
        True: neighbors(rest, s, v, ns)
        False: C.gu(NS, S.mem_get(s, u), s => +c =>
          C.gu(NS, S.added_get(s, c), s => added => (
            s = S.ewpc_add(s, c, F.D{h, l})
            C.when(NS, U32.is_eq(added, 0), \{
              True: neighbors(rest, S.added_set(s, c, 1), v, c <> ns)
              False: neighbors(rest, s, v, ns)
            }))))
      })

def gain(+ew: F.D, +nw: F.D, +cw: F.D, +res: F.D) -> F.D:
  F.d_sub(ew, F.d_mul(F.d_mul(nw, cw), res))

def choose_loop(ns: List<&2, U32>, s: S.S, +nw: F.D, +res: F.D, +best: U32, +maxd: F.D) -> Choice:
  match ns:
    case Nil{}: Choice{s, best, maxd}
    case Con{+c, rest}:
      C.gd(Choice, S.ewpc_get(s, c), s => ew =>
      C.gd(Choice, S.cw_get(s, c), s => cw => (
        +d = gain(ew, nw, cw, res)
        s = S.added_set(S.ewpc_set(s, c, C.zero()), c, 0)
        C.when(Choice, F.d_gt(d, maxd), \{
          True: choose_loop(rest, s, nw, res, c, d)
          False: choose_loop(rest, s, nw, res, best, maxd)
        }))))

def choose(ns: NS, +cur: U32, +nw: F.D, +res: F.D) -> Choice:
  match ns:
    case NS{s, ns}:
      C.gd(Choice, S.ewpc_get(s, cur), s => ew =>
      C.gd(Choice, S.cw_get(s, cur), s => cw =>
        choose_loop(G.rev_u32(ns, Nil{}), s, nw, res, cur, gain(ew, nw, cw, res))))

def enqueue(xs: List<&2, G.Nb>, s: S.S, +best: U32, +tail: U32, +n: U32) -> S.S & U32:
  match xs:
    case Nil{}: (s, tail)
    case Con{G.Nb{+u, h, l}, rest}:
      C.gu(S.S & U32, S.stable_get(s, u), s => stable =>
      C.gu(S.S & U32, S.mem_get(s, u), s => mem =>
      C.when(S.S & U32, U32.is_ne(stable, 0) && U32.is_ne(mem, best), \{
        True: enqueue(rest, S.stable_set(S.queue_set(s, U32.mod(tail, n), u), u, 0), best, U32.inc(tail), n)
        False: enqueue(rest, s, best, tail, n)
      })))

def finish_choice(ch: Choice, +v: U32, +cur: U32, +nw: F.D, +head: U32, +tail: U32, +ne: U32, +n: U32) -> Q:
  match ch:
    case Choice{s, +best, maxd}:
      C.gu(Q, S.count_get(s, best), s => nb =>
      C.gu(Q, S.empty_get(s, U32.sub(ne, 1)), s => last => (
        s = S.stable_set(S.count_set(S.cw_add(s, best, nw), best, U32.inc(nb)), v, 1)
        +ne2 = U32.sub(ne, F.b2u(U32.is_eq(best, last)))
        C.when(Q, U32.is_eq(best, cur), \{
          True: Q{s, head, tail, ne2}
          False: C.gr(Q, S.rows_get(S.mem_set(S.changed_set(s, True{}), v, best), v), s => xs =>
            C.gu(Q, enqueue(xs, s, best, tail, n), s => t => Q{s, head, t, ne2}))
        }))))

def remove(s: S.S, +v: U32, +cur: U32, +nw: F.D, +ne: U32) -> S.S & U32:
  C.gu(S.S & U32, S.count_get(s, cur), s => nb => (
    +nb2 = U32.sub(nb, 1)
    s = S.count_set(S.cw_sub(s, cur, nw), cur, nb2)
    C.when(S.S & U32, U32.is_eq(nb2, 0), \{
      True: (S.empty_set(s, ne, cur), U32.inc(ne))
      False: (s, ne)
    })))

def visit(s: S.S, +v: U32, +head: U32, +tail: U32, +ne: U32, +n: U32, +res: F.D) -> Q:
  C.gu(Q, S.mem_get(s, v), s => +cur =>
  C.gd(Q, S.nw_get(s, v), s => +nw =>
  C.gu(Q, remove(s, v, cur, nw, ne), s => +ne =>
  C.gu(Q, S.empty_get(s, U32.sub(ne, 1)), s => +empty =>
  C.gr(Q, S.rows_get(S.added_set(s, empty, 1), v), s => xs =>
    finish_choice(choose(neighbors(xs, s, v, [empty]), cur, nw, res),
      v, cur, nw, head, tail, ne, n))))))

def step(q: Q, +n: U32, +res: F.D) -> Q:
  match q:
    case Q{s, +head, +tail, +ne}:
      C.gu(Q, S.queue_get(s, U32.mod(head, n)), s => v =>
        visit(s, v, U32.inc(head), tail, ne, n, res))

def run(fuel: Nat, q: Q, +n: U32, +res: F.D) -> S.S:
  match fuel q:
    case 0n Q{s, +head, +tail, ne}:
      C.when(S.S, U32.is_eq(head, tail), \{
        True: s
        False: S.err_set(s, True{})
      })
    case 1n+p Q{s, +head, +tail, ne}:
      C.when(S.S, U32.is_eq(head, tail), \{
        True: s
        False: run(p, step(Q{s, head, tail, ne}, n, res), n, res)
      })

def fastmove(s: S.S, +n: U32, +res: F.D) -> S.S & U32:
  s = initialize(U32.to_nat(n), C.clear(U32.to_nat(n), s, 0), 0)
  C.gu(S.S & U32, empties(U32.to_nat(n), s, 0, 0), s => ne => (
    s = queue_init(U32.to_nat(n), R.shuffle(s, n), 0)
    C.reindex(run(U32.to_nat(1000000), Q{s, 0, n, ne}, n, res), 0, n)))
