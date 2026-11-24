# Complete linkage on the sparse graph, exactly as Clusty 1.2.2's
# linkage_heaptrix: repeatedly merge the live pair with the smallest key
# (d, row, col) (row < col are group ids, merged groups get ids n, n+1, ...);
# the merged group keeps an edge to x only if both parts had one, with the
# larger distance. Clusty's heap holds every live pair once and its key is
# unique, so a lazy min-heap (dead pairs skipped on pop) yields the same
# merge sequence in O(E log E). Clusters are the final trees, numbered by
# decreasing root id (Clusty's dendrogram walk from the last position).
#
# Distances are kept as order keys (F.key_hi/key_lo: unsigned order equals
# double order), adjacency lists by decreasing group id.
import Base
import ./f64.bend as F
import ./cl_graph.bend as G

type HE is Data:
  HE{+kh: U32, +kl: U32, +r: U32, +c: U32}


type AH is Type:
  AH{hp: Array<U32>, +e: HE}


# sift-up with a hole at i for element e
type SU is Type:
  SU{hp: Array<U32>, +i: U32, +e: HE, +done: Bool}


type HP is Type:
  HP{hp: Array<U32>, +n: U32}


# sift-down with a hole at i for element e, heap size n
type SD is Type:
  SD{hp: Array<U32>, +i: U32, +e: HE, +done: Bool}


# pop the minimum: (heap, top); the heap must be non-empty
type HT is Type:
  HT{h: HP, +top: HE}


# ---------------------------------------------------------------------------
# Linkage state

type CL is Type:
  CL{adj: Array<List<&2, G.Nb>>, alive: Array<U32>, up: Array<U32>, h: HP,
     +next: U32, +left: U32}


type IB is Type:
  IB{rows: Array<List<&2, G.Nb>>, adj: Array<List<&2, G.Nb>>, h: HP}


# merge-join of the two parts' lists (descending ids)
type MJ is Type:
  MJ{xs: List<&2, G.Nb>, ys: List<&2, G.Nb>, out: List<&2, G.Nb>, cl: CL, +g: U32}


# final group of each group, from the highest id down: fin[g] = g when
# alive, else fin[up[g]]
type FN is Type:
  FN{alive: Array<U32>, up: Array<U32>, fin: Array<U32>, cid: Array<U32>, +cnt: U32}


# assignment of the leaves 0..n-1
type LA is Type:
  LA{fn: FN, asg: Array<U32>}


def he_lt(x: HE, y: HE) -> Bool:
  match x y:
    case HE{a, b, c, d} HE{e, f, g, h}:
      F.lex_lt(a, e, F.lex_lt(b, f, F.lex_lt(c, g, U32.is_lt(d, h))))


def hget1(r: Array<U32> & U32, +a: U32, +b: U32, +c: U32) -> AH:
  (hp, +d) = r
  AH{hp, HE{a, b, c, d}}


def hget2(r: Array<U32> & U32, +i: U32, +a: U32, +b: U32) -> AH:
  (hp, +c) = r
  hget1(Array.get(U32, hp, U32.add(i, 3)), a, b, c)


def hget3(r: Array<U32> & U32, +i: U32, +a: U32) -> AH:
  (hp, +b) = r
  hget2(Array.get(U32, hp, U32.add(i, 2)), i, a, b)


def hget4(r: Array<U32> & U32, +i: U32) -> AH:
  (hp, +a) = r
  hget3(Array.get(U32, hp, U32.add(i, 1)), i, a)


def hget(hp: Array<U32>, +i: U32) -> AH:
  hget4(Array.get(U32, hp, U32.shln(i, 2n)), U32.shln(i, 2n))


def hset(hp: Array<U32>, +i: U32, e: HE) -> Array<U32>:
  match e:
    case HE{a, b, c, d}:
      +j = U32.shln(i, 2n)
      Array.set(U32, Array.set(U32, Array.set(U32, Array.set(U32, hp, j, a),
        U32.add(j, 1), b), U32.add(j, 2), c), U32.add(j, 3), d)


def su_move(up: Bool, hp: Array<U32>, +i: U32, +p: U32, +e: HE, +pe: HE) -> SU:
  match up:
    case True{}:
      SU{hset(hp, i, pe), p, e, False{}}
    case False{}:
      SU{hp, i, e, True{}}


def su_cmp(ah: AH, +i: U32, +p: U32, +e: HE) -> SU:
  match ah:
    case AH{hp, pe}:
      su_move(he_lt(e, pe), hp, i, p, e, pe)


def su_step(top: Bool, hp: Array<U32>, +i: U32, +e: HE) -> SU:
  match top:
    case True{}:
      SU{hp, i, e, True{}}
    case False{}:
      su_cmp(hget(hp, U32.shr(U32.sub(i, 1))), i, U32.shr(U32.sub(i, 1)), e)


def sift_up(n: Nat, su: SU) -> SU:
  match n:
    case 0n:
      su
    case 1n+p:
      match su:
        case SU{hp, i, e, done}:
          match done:
            case True{}:
              SU{hp, i, e, True{}}
            case False{}:
              sift_up(p, su_step(U32.is_eq(i, 0), hp, i, e))


def su_fin(su: SU) -> Array<U32>:
  match su:
    case SU{hp, i, e, done}:
      hset(hp, i, e)


def h_push(h: HP, +e: HE) -> HP:
  match h:
    case HP{hp, n}:
      HP{su_fin(sift_up(40n, SU{hp, n, e, False{}})), U32.inc(n)}


def sd_move(down: Bool, hp: Array<U32>, +ci: U32, +ce: HE, +i: U32, +e: HE) -> SD:
  match down:
    case True{}:
      SD{hset(hp, i, ce), ci, e, False{}}
    case False{}:
      SD{hp, i, e, True{}}


def sd_cmp(right: Bool, hp: Array<U32>, +re: HE, +ri: U32, +le: HE, +l: U32, +i: U32, +e: HE) -> SD:
  match right:
    case True{}:
      sd_move(he_lt(re, e), hp, ri, re, i, e)
    case False{}:
      sd_move(he_lt(le, e), hp, l, le, i, e)


def sd_pick2(ar: AH, +le: HE, +l: U32, +ri: U32, +n: U32, +i: U32, +e: HE) -> SD:
  match ar:
    case AH{hp, re}:
      sd_cmp(he_lt(re, le), hp, re, ri, le, l, i, e)


def sd_right(has: Bool, hp: Array<U32>, +le: HE, +l: U32, +n: U32, +i: U32, +e: HE) -> SD:
  match has:
    case True{}:
      sd_pick2(hget(hp, U32.inc(l)), le, l, U32.inc(l), n, i, e)
    case False{}:
      sd_move(he_lt(le, e), hp, l, le, i, e)


def sd_left(al: AH, +l: U32, +n: U32, +i: U32, +e: HE) -> SD:
  match al:
    case AH{hp, le}:
      sd_right(U32.is_lt(U32.inc(l), n), hp, le, l, n, i, e)


def sd_step(leaf: Bool, hp: Array<U32>, +n: U32, +i: U32, +e: HE) -> SD:
  match leaf:
    case True{}:
      SD{hp, i, e, True{}}
    case False{}:
      sd_left(hget(hp, U32.inc(U32.shl(i))), U32.inc(U32.shl(i)), n, i, e)


def sift_down(k: Nat, +n: U32, sd: SD) -> SD:
  match k:
    case 0n:
      sd
    case 1n+p:
      match sd:
        case SD{hp, i, e, done}:
          match done:
            case True{}:
              SD{hp, i, e, True{}}
            case False{}:
              sift_down(p, n, sd_step(U32.is_ge(U32.inc(U32.shl(i)), n), hp, n, i, e))


def sd_fin(sd: SD) -> Array<U32>:
  match sd:
    case SD{hp, i, e, done}:
      hset(hp, i, e)


def h_pop_go(at: AH, +m: U32, last: HE) -> HP & HE:
  match at:
    case AH{hp, top}:
      (HP{sd_fin(sift_down(40n, m, SD{hp, 0, last, False{}})), m}, top)


def h_pop_last(al: AH, +m: U32) -> HP & HE:
  match al:
    case AH{hp, last}:
      h_pop_go(hget(hp, 0), m, last)


def h_pop(h: HP) -> HP & HE:
  match h:
    case HP{hp, n}:
      h_pop_last(hget(hp, U32.sub(n, 1)), U32.sub(n, 1))


# initial lists: descending ids, order keys; heap entries for r < c
def key_list(ns: List<&2, G.Nb>, acc: List<&2, G.Nb>) -> List<&2, G.Nb>:
  match ns:
    case Nil{}:
      acc
    case Con{x, t}:
      match x:
        case G.Nb{id, dh, dl}:
          key_list(t, G.Nb{id, F.key_hi(dh, dl), F.key_lo(dh, dl)} <> acc)


def push_if(c: Bool, h: HP, +e: HE) -> HP:
  match c:
    case True{}:
      h_push(h, e)
    case False{}:
      h


def push_upper(ns: List<&2, G.Nb>, +v: U32, h: HP) -> HP:
  match ns:
    case Nil{}:
      h
    case Con{x, t}:
      match x:
        case G.Nb{id, kh, kl}:
          push_upper(t, v, push_if(U32.is_gt(id, v), h, HE{kh, kl, v, id}))


def init_row2(rows: Array<List<&2, G.Nb>>, adj: Array<List<&2, G.Nb>>, h: HP, +v: U32, +ks: List<&2, G.Nb>) -> IB:
  IB{rows, Array.set(List<&2, G.Nb>, adj, v, ks), push_upper(ks, v, h)}


def init_row(r: Array<List<&2, G.Nb>> & List<&2, G.Nb>, adj: Array<List<&2, G.Nb>>, h: HP, +v: U32) -> IB:
  (rows, ns) = r
  init_row2(rows, adj, h, v, key_list(ns, Nil{}))


def init_rows(n: Nat, +v: U32, ib: IB) -> IB:
  match n:
    case 0n:
      ib
    case 1n+p:
      match ib:
        case IB{rows, adj, h}:
          init_rows(p, U32.inc(v), init_row(G.row_get(rows, v), adj, h, v))


def max_key(+ah: U32, +al: U32, +bh: U32, +bl: U32) -> G.Nb:
  G.Nb{0, F.sel(F.lex_lt(ah, bh, U32.is_lt(al, bl)), bh, ah), F.sel(F.lex_lt(ah, bh, U32.is_lt(al, bl)), bl, al)}


def common_go(live: Bool, alive: Array<U32>, adj: Array<List<&2, G.Nb>>, up: Array<U32>, h: HP, +next: U32, +left: U32,
              +x: U32, +k: G.Nb, +g: U32, +out: List<&2, G.Nb>, +xt: List<&2, G.Nb>, +yt: List<&2, G.Nb>) -> MJ:
  match live:
    case False{}:
      MJ{xt, yt, out, CL{adj, alive, up, h, next, left}, g}
    case True{}:
      match k:
        case G.Nb{z, kh, kl}:
          MJ{xt, yt, G.Nb{x, kh, kl} <> out,
            CL{G.push_row(adj, x, G.Nb{g, kh, kl}), alive, up, h_push(h, HE{kh, kl, x, g}), next, left}, g}


def common_new(r: Array<U32> & U32, adj: Array<List<&2, G.Nb>>, up: Array<U32>, h: HP, +next: U32, +left: U32,
               +x: U32, +k: G.Nb, +g: U32, +out: List<&2, G.Nb>, +xt: List<&2, G.Nb>, +yt: List<&2, G.Nb>) -> MJ:
  (alive, +a) = r
  common_go(U32.is_eq(a, 1), alive, adj, up, h, next, left, x, k, g, out, xt, yt)


def mj_both(cmp: Cmp, +x: G.Nb, +xt: List<&2, G.Nb>, +y: G.Nb, +yt: List<&2, G.Nb>, +out: List<&2, G.Nb>, cl: CL, +g: U32) -> MJ:
  match cmp:
    case GT{}:
      MJ{xt, y <> yt, out, cl, g}
    case LT{}:
      MJ{x <> xt, yt, out, cl, g}
    case EQ{}:
      match x y:
        case G.Nb{xi, xh, xl} G.Nb{yi, yh, yl}:
          match cl:
            case CL{adj, alive, up, h, next, left}:
              common_new(Array.get(U32, alive, xi), adj, up, h, next, left, xi,
                max_key(xh, xl, yh, yl), g, out, xt, yt)


def mj(n: Nat, m: MJ) -> MJ:
  match n:
    case 0n:
      m
    case 1n+p:
      match m:
        case MJ{xs, ys, out, cl, g}:
          match xs ys:
            case Nil{} Nil{}:
              MJ{Nil{}, Nil{}, out, cl, g}
            case Con{x, xt} Nil{}:
              mj(p, MJ{xt, Nil{}, out, cl, g})
            case Nil{} Con{y, yt}:
              mj(p, MJ{Nil{}, yt, out, cl, g})
            case Con{+x, xt} Con{+y, yt}:
              mj(p, mj_both(U32.cmp(G.nb_id(x), G.nb_id(y)), x, xt, y, yt, out, cl, g))


def rev_nb(xs: List<&2, G.Nb>, acc: List<&2, G.Nb>) -> List<&2, G.Nb>:
  match xs:
    case Nil{}:
      acc
    case Con{x, t}:
      rev_nb(t, x <> acc)


def mj_fin(m: MJ, +r: U32, +c: U32) -> CL:
  match m:
    case MJ{xs, ys, out, cl, g}:
      match cl:
        case CL{adj, alive, up, h, next, left}:
          CL{Array.set(List<&2, G.Nb>, Array.set(List<&2, G.Nb>, Array.set(List<&2, G.Nb>, adj, g, rev_nb(out, Nil{})), r, Nil{}), c, Nil{}),
            Array.set(U32, Array.set(U32, Array.set(U32, alive, r, 0), c, 0), g, 1),
            Array.set(U32, Array.set(U32, up, r, g), c, g), h, U32.inc(next), U32.sub(left, 1)}


def take_c(rc: Array<List<&2, G.Nb>> & List<&2, G.Nb>, +xs: List<&2, G.Nb>, alive: Array<U32>, up: Array<U32>, h: HP,
           +next: U32, +left: U32, +r: U32, +c: U32) -> CL:
  (adj, +ys) = rc
  mj_fin(mj(U32.to_nat(U32.add(U32.add(G.len_nb(xs, 0), G.len_nb(ys, 0)), 1)),
    MJ{xs, ys, Nil{}, CL{adj, alive, up, h, next, left}, next}), r, c)


def take_r(rr: Array<List<&2, G.Nb>> & List<&2, G.Nb>, alive: Array<U32>, up: Array<U32>, h: HP,
           +next: U32, +left: U32, +r: U32, +c: U32) -> CL:
  (adj, xs) = rr
  take_c(G.row_get(adj, c), xs, alive, up, h, next, left, r, c)


def merge(live: Bool, cl: CL, +r: U32, +c: U32) -> CL:
  match live:
    case False{}:
      cl
    case True{}:
      match cl:
        case CL{adj, alive, up, h, next, left}:
          take_r(G.row_get(adj, r), alive, up, h, next, left, r, c)


def live2b(rb: Array<U32> & U32, +a: U32) -> Array<U32> & Bool:
  (alive, +b) = rb
  (alive, Bool.and(U32.is_eq(a, 1), U32.is_eq(b, 1)))


def live2(ra: Array<U32> & U32, +c: U32) -> Array<U32> & Bool:
  (alive, +a) = ra
  live2b(Array.get(U32, alive, c), a)


def step_live(la: Array<U32> & Bool, adj: Array<List<&2, G.Nb>>, up: Array<U32>, h: HP, +next: U32, +left: U32, +r: U32, +c: U32) -> CL:
  (alive, live) = la
  merge(live, CL{adj, alive, up, h, next, left}, r, c)


def step_top(hp: HP & HE, adj: Array<List<&2, G.Nb>>, alive: Array<U32>, up: Array<U32>, +next: U32, +left: U32) -> CL:
  (h, e) = hp
  match e:
    case HE{kh, kl, r, c}:
      step_live(live2(Array.get(U32, alive, r), c), adj, up, h, next, left, r, c)


def hp_size(h: HP) -> HP & U32:
  match h:
    case HP{hp, n}:
      (HP{hp, n}, n)


def run_go(go: Bool, cl: CL) -> CL & Bool:
  match go:
    case False{}:
      (cl, False{})
    case True{}:
      match cl:
        case CL{adj, alive, up, h, next, left}:
          (step_top(h_pop(h), adj, alive, up, next, left), True{})


def run_check2(hs: HP & U32, adj: Array<List<&2, G.Nb>>, alive: Array<U32>, up: Array<U32>, +next: U32, +left: U32) -> CL & Bool:
  (h, +sz) = hs
  run_go(Bool.and(U32.is_gt(sz, 0), U32.is_gt(left, 1)), CL{adj, alive, up, h, next, left})


def run_check(cl: CL) -> CL & Bool:
  match cl:
    case CL{adj, alive, up, h, next, left}:
      run_check2(hp_size(h), adj, alive, up, next, left)


def run(n: Nat, r: CL & Bool) -> CL:
  match n:
    case 0n:
      (cl, more) = r
      cl
    case 1n+p:
      (cl, more) = r
      match more:
        case False{}:
          cl
        case True{}:
          run(p, run_check(cl))


def fin_f(root: Bool, rf: Array<U32> & U32, alive: Array<U32>, up: Array<U32>, cid: Array<U32>, +cnt: U32, +g: U32) -> FN:
  match root:
    case True{}:
      (fin, +fu) = rf
      FN{alive, up, Array.set(U32, fin, g, g), Array.set(U32, cid, g, cnt), U32.inc(cnt)}
    case False{}:
      (fin, +fu) = rf
      FN{alive, up, Array.set(U32, fin, g, fu), cid, cnt}


def fin_u(ru: Array<U32> & U32, alive: Array<U32>, fin: Array<U32>, cid: Array<U32>, +cnt: U32, +g: U32, +a: U32) -> FN:
  (up, +u) = ru
  fin_f(U32.is_eq(a, 1), Array.get(U32, fin, u), alive, up, cid, cnt, g)


def fin_a(ra: Array<U32> & U32, up: Array<U32>, fin: Array<U32>, cid: Array<U32>, +cnt: U32, +g: U32) -> FN:
  (alive, +a) = ra
  fin_u(Array.get(U32, up, g), alive, fin, cid, cnt, g, a)


def fin_loop(n: Nat, +g: U32, fn: FN) -> FN:
  match n:
    case 0n:
      fn
    case 1n+p:
      match fn:
        case FN{alive, up, fin, cid, cnt}:
          fin_loop(p, U32.sub(g, 1), fin_a(Array.get(U32, alive, g), up, fin, cid, cnt, g))


def leaf_set(rc: Array<U32> & U32, alive: Array<U32>, up: Array<U32>, fin: Array<U32>, +cnt: U32, asg: Array<U32>, +v: U32) -> LA:
  (cid, +c) = rc
  LA{FN{alive, up, fin, cid, cnt}, Array.set(U32, asg, v, c)}


def leaf_fin(rf: Array<U32> & U32, alive: Array<U32>, up: Array<U32>, cid: Array<U32>, +cnt: U32, asg: Array<U32>, +v: U32) -> LA:
  (fin, +f) = rf
  leaf_set(Array.get(U32, cid, f), alive, up, fin, cnt, asg, v)


def leaf_step(fn: FN, asg: Array<U32>, +v: U32) -> LA:
  match fn:
    case FN{alive, up, fin, cid, cnt}:
      leaf_fin(Array.get(U32, fin, v), alive, up, cid, cnt, asg, v)


def leaf_asg(n: Nat, +v: U32, la: LA) -> Array<U32> & U32:
  match n:
    case 0n:
      match la:
        case LA{fn, asg}:
          match fn:
            case FN{alive, up, fin, cid, cnt}:
              (asg, cnt)
    case 1n+p:
      match la:
        case LA{fn, asg}:
          leaf_asg(p, U32.inc(v), leaf_step(fn, asg, v))


def complete_fin(cl: CL, +n: U32) -> Array<U32> & U32:
  match cl:
    case CL{adj, alive, up, h, next, left}:
      +m = U32.shl(n)
      leaf_asg(U32.to_nat(n), 0, LA{
        fin_loop(U32.to_nat(m), U32.sub(m, 1), FN{alive, up, G.u32_array(m, 0), G.u32_array(m, 0), 0}),
        G.u32_array(n, 0)})


def fill_one(n: Nat, +i: U32, a: Array<U32>) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      fill_one(p, U32.inc(i), Array.set(U32, a, i, 1))


def complete_init(ib: IB, +n: U32, +m: U32) -> CL:
  match ib:
    case IB{rows, adj, h}:
      CL{adj, fill_one(U32.to_nat(n), 0, G.u32_array(U32.shl(n), 0)), G.u32_array(U32.shl(n), 0), h, n, n}


# (assignment over local ids, number of clusters); m = directed entries
def complete(rows: Array<List<&2, G.Nb>>, +n: U32, +m: U32) -> Array<U32> & U32:
  +cap = U32.shln(U32.add(m, 4), 2n)
  complete_fin(run(U32.to_nat(U32.add(m, 4)), (complete_init(init_rows(U32.to_nat(n), 0,
      IB{rows, Array.new(List<&2, G.Nb>, G.depth(U32.shl(n)), Nil{}), HP{G.u32_array(cap, 0), 0}}), n, m), True{})), n)
