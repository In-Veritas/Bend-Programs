# Leiden exactly as Clusty 1.2.2 calls igraph 0.10.10-43
# (igraph_community_leiden(g, w, NULL, resolution, beta, false, iters, ...)):
# CPM with unit node weights, igraph's default PCG32 RNG in its startup state
# (PCG32_INITIALIZER, never reseeded), and C-double arithmetic reproduced
# with the soft binary64 of f64.bend (glibc's FMA exp included).
#
# Graphs: adj[v] lists (neighbour, weight bits) by increasing neighbour; at
# level 0 every pair is two parallel igraph edges of equal weight (Clusty adds
# edge (i, j) for every matrix row entry), so each entry counts twice (m2);
# aggregated levels have single edges. This equals igraph's incidence lists
# (sorted by the other endpoint; parallel edges by decreasing id, same weight).
#
# Workspaces: every phase keeps its arrays in one Array<U32> W at fixed
# offsets (doubles as two words, hi then lo).
import Base
import ./f64.bend as F
import ./cl_graph.bend as G

# ---------------------------------------------------------------------------
# PCG32 (pcg_setseq_64_xsh_rr_32) and igraph's derived draws

type RNG is Data:
  RNG{+h: U32, +l: U32}






type RV is Data:
  RV{+g: RNG, +v: U32}






# Lemire bounded draw in [0, n): igraph_i_rng_get_uint32_bounded
type BD is Data:
  BD{+g: RNG, +v: U32, +ok: Bool}






# uniform double in [0, 1): 52 random bits as 1.m - 1
type RD is Data:
  RD{+g: RNG, +d: F.D}






# igraph_rng_get_unif(0, t): u * t, redrawn while it equals t
type UD is Data:
  UD{+g: RNG, +d: F.D, +done: Bool}






# ---------------------------------------------------------------------------
# array helpers

type AD is Type:
  AD{a: Array<U32>, +d: F.D}






type AU is Type:
  AU{a: Array<U32>, +v: U32}






# shuffle a[off .. off+n) in place (igraph_vector_int_shuffle)
type SH is Type:
  SH{a: Array<U32>, +g: RNG}






# ---------------------------------------------------------------------------
# a level graph

type GR is Type:
  GR{adj: Array<List<&2, G.Nb>>, nw: Array<U32>, +n: U32, +m2: Bool}






# igraph_reindex_membership: first-appearance order
type RX is Type:
  RX{memb: Array<U32>, nc: Array<U32>, +k: U32}





# ---------------------------------------------------------------------------
# Fast local moving (igraph_i_community_leiden_fastmovenodes)

type FP is Data:
  FP{+n: U32, +mask: U32, +m2: Bool, +res: F.D}





type FM is Type:
  FM{gr: GR, memb: Array<U32>, w: Array<U32>, +etop: U32, +qh: U32, +qt: U32,
     +chg: Bool, +g: RNG}





# init: cluster weights and sizes
type FI is Type:
  FI{gr: GR, memb: Array<U32>, w: Array<U32>}





# empty clusters pushed in increasing order
type WE is Type:
  WE{w: Array<U32>, +etop: U32}





# neighbour scan: added flags, discovered clusters (reverse), edge weights
type SC is Type:
  SC{memb: Array<U32>, w: Array<U32>, +neigh: List<&2, U32>}





# best cluster: strictly larger diff wins, clusters in discovery order
type BS is Type:
  BS{w: Array<U32>, +best: U32, +maxd: F.D}





# requeue stable neighbours outside the new cluster
type RQ is Type:
  RQ{memb: Array<U32>, w: Array<U32>, +qt: U32}





# one popped node v
type NV is Type:
  NV{gr: GR, memb: Array<U32>, w: Array<U32>, +etop: U32, +qt: U32, +chg: Bool}





type FMR is Type:
  FMR{gr: GR, memb: Array<U32>, +k: U32, +chg: Bool, +g: RNG}




# ---------------------------------------------------------------------------
# Refinement of one cluster (igraph_i_community_leiden_mergenodes)

type MP is Data:
  MP{+ns: U32, +csub: U32, +m2: Bool, +res: F.D, +beta: F.D, +tab: F.Tab}




type MG is Type:
  MG{gr: GR, memb: Array<U32>, refined: Array<U32>, w: Array<U32>, +total: F.D, +g: RNG}




# external weight scan: ext[i] += w for neighbours inside the cluster
type XS is Type:
  XS{memb: Array<U32>, w: Array<U32>}




# neighbour scan inside the cluster (refined clusters, reverse discovery)
type RS2 is Type:
  RS2{memb: Array<U32>, refined: Array<U32>, w: Array<U32>, +neigh: List<&2, U32>}




# diffs over the discovered clusters: best, cumulative exp(diff / beta)
type DS is Type:
  DS{w: Array<U32>, +best: U32, +maxd: F.D, +tot: F.D, +j: U32}




# igraph_vector_binsearch_slice over cum[0, len)
type BI is Type:
  BI{w: Array<U32>, +lo: U32, +hi: U32, +found: Bool}




# ext update after the move: -w towards the chosen cluster, +w otherwise
type EU is Type:
  EU{memb: Array<U32>, refined: Array<U32>, w: Array<U32>}




# clean the refined membership of the subset: numbers nbref+1, ...
type CR is Type:
  CR{refined: Array<U32>, w: Array<U32>, +nb: U32}




# mergenodes for cluster csub with node list xs: (gr, memb, refined, nbref, rng)
type MR is Type:
  MR{gr: GR, memb: Array<U32>, refined: Array<U32>, +nb: U32, +g: RNG}



# ---------------------------------------------------------------------------
# clusters as node lists (increasing node id)

type CL2 is Type:
  CL2{memb: Array<U32>, cl: Array<List<&2, U32>>}



# refine every cluster in order
type RF is Type:
  RF{gr: GR, memb: Array<U32>, refined: Array<U32>, cl: Array<List<&2, U32>>, +nb: U32, +g: RNG}



# ---------------------------------------------------------------------------
# Aggregation (igraph_i_community_leiden_aggregate)

type AG is Type:
  AG{gr: GR, memb: Array<U32>, refined: Array<U32>, ws: Array<U32>, lower: Array<List<&2, G.Nb>>,
     upper: Array<List<&2, G.Nb>>, nw2: Array<U32>, amemb: Array<U32>}



# per cluster scan: neighbours c2 > c, summed weights
type AS is Type:
  AS{refined: Array<U32>, ws: Array<U32>, +neigh: List<&2, U32>}



# over the cluster's nodes: (scan state, node-weight sum, last node)
type AN is Type:
  AN{gr: GR, s: AS, +anw: F.D, +last: U32}



# emit the edges (c, c2) in discovery order, resetting the scratch
type AE is Type:
  AE{ws: Array<U32>, lower: Array<List<&2, G.Nb>>, +up: List<&2, G.Nb>}



type AJ is Type:
  AJ{lower: Array<List<&2, G.Nb>>, upper: Array<List<&2, G.Nb>>, adj: Array<List<&2, G.Nb>>}



# (old graph, level membership, new graph, aggregated membership)
type AR is Type:
  AR{gr: GR, memb: Array<U32>, refined: Array<U32>, ng: GR, amemb: Array<U32>}


# memb0[i] = imemb[agg[i]] for every original node
type MU is Type:
  MU{memb0: Array<U32>, imemb: Array<U32>, agg: Array<U32>}


# agg[i] = refined[agg[i]]
type AU2 is Type:
  AU2{agg: Array<U32>, refined: Array<U32>}


# Level state. At level 0 the level membership is memb0 itself (lvl0).
type LV is Type:
  LV{g0: GR, gr: GR, imemb: Array<U32>, memb0: Array<U32>, agg: Array<U32>, +lvl0: Bool, +nbc: U32,
     +chg: Bool, +g: RNG, +done: Bool}


type PR is Data:
  PR{+n0: U32, +res: F.D, +beta: F.D, +tab: F.Tab}


# one call of igraph_i_community_leiden: (g0, memb0, changed, rng)
type IT is Type:
  IT{g0: GR, memb0: Array<U32>, +chg: Bool, +g: RNG}






def rng0() -> RNG:
  RNG{2235320806, 1955588763}






def pcg_next_go(p: U32 & U32, +h: U32, +l: U32) -> RNG:
  (+ph, +pl) = p
  +hi = U32.add(U32.add(ph, U32.mul(h, 1284865837)), U32.mul(l, 1481765933))
  +lo = U32.add(pl, 2495175643)
  RNG{U32.add(U32.add(hi, 3661511115), F.b2u(U32.is_lt(lo, pl))), lo}






def pcg_out(+h: U32, +l: U32) -> U32:
  +xh = U32.xor(h, U32.shrn(h, 18n))
  +xl = U32.xor(l, U32.or(U32.shrn(l, 18n), U32.shln(h, 14n)))
  +xs = U32.or(U32.shrn(xl, 27n), U32.shln(xh, 5n))
  +rot = U32.shrn(h, 27n)
  U32.or(F.shr(xs, rot), F.shl(xs, U32.and(U32.sub(32, rot), 31)))






def pcg(g: RNG) -> RV:
  match g:
    case RNG{h, l}:
      RV{pcg_next_go(F.mul32(l, 1284865837), h, l), pcg_out(h, l)}






def bd_mul(m: U32 & U32, +g: RNG, +t: U32) -> BD:
  (mh, ml) = m
  BD{g, mh, U32.is_ge(ml, t)}






def bd_of(r: RV, +n: U32, +t: U32) -> BD:
  match r:
    case RV{g, x}:
      bd_mul(F.mul32(x, n), g, t)






def bd_loop(k: Nat, b: BD, +n: U32, +t: U32) -> BD:
  match k:
    case 0n:
      b
    case 1n+p:
      match b:
        case BD{g, v, ok}:
          match ok:
            case True{}:
              BD{g, v, True{}}
            case False{}:
              bd_loop(p, bd_of(pcg(g), n, t), n, t)






def bd_rv(b: BD) -> RV:
  match b:
    case BD{g, v, ok}:
      RV{g, v}






def bounded(+g: RNG, +n: U32) -> RV:
  +t = U32.mod(U32.sub(0, n), n)
  bd_rv(bd_loop(64n, BD{g, 0, False{}}, n, t))






def unif01_b(r: RV, +a: U32) -> RD:
  match r:
    case RV{g, b}:
      RD{g, F.d_of(F.sub(U32.or(1072693248, U32.shrn(a, 12n)),
        U32.or(U32.shln(a, 20n), U32.shrn(b, 12n)), 1072693248, 0))}






def unif01_a(r: RV) -> RD:
  match r:
    case RV{g, a}:
      unif01_b(pcg(g), a)






def unif01(+g: RNG) -> RD:
  unif01_a(pcg(g))






def unif_chk(+x: F.D, +g: RNG, +t: F.D) -> UD:
  UD{g, x, Bool.not(F.d_eq(x, t))}






def unif_try(r: RD, +t: F.D) -> UD:
  match r:
    case RD{g, u}:
      unif_chk(F.d_mul(u, t), g, t)






def unif_loop(k: Nat, u: UD, +t: F.D) -> UD:
  match k:
    case 0n:
      u
    case 1n+p:
      match u:
        case UD{g, d, done}:
          match done:
            case True{}:
              UD{g, d, True{}}
            case False{}:
              unif_loop(p, unif_try(unif01(g), t), t)






def unif_fin(u: UD) -> RD:
  match u:
    case UD{g, d, done}:
      RD{g, d}






def unif(+g: RNG, +t: F.D) -> RD:
  unif_fin(unif_loop(64n, UD{g, F.D{0, 0}, False{}}, t))






def uget_go(r: Array<U32> & U32) -> AU:
  (a, +v) = r
  AU{a, v}






def uget(a: Array<U32>, +i: U32) -> AU:
  uget_go(Array.get(U32, a, i))






def dget_b(r: Array<U32> & U32, +h: U32) -> AD:
  (a, +l) = r
  AD{a, F.D{h, l}}






def dget_a(r: Array<U32> & U32, +i: U32) -> AD:
  (a, +h) = r
  dget_b(Array.get(U32, a, U32.inc(i)), h)






# double stored at word index i (hi) and i + 1 (lo)
def dget(a: Array<U32>, +i: U32) -> AD:
  dget_a(Array.get(U32, a, i), i)






def dset(a: Array<U32>, +i: U32, d: F.D) -> Array<U32>:
  match d:
    case F.D{h, l}:
      Array.set(U32, Array.set(U32, a, i, h), U32.inc(i), l)






def dadd_go(r: AD, +i: U32, +x: F.D) -> Array<U32>:
  match r:
    case AD{a, y}:
      dset(a, i, F.d_add(y, x))






def dadd(a: Array<U32>, +i: U32, +x: F.D) -> Array<U32>:
  dadd_go(dget(a, i), i, x)






def dsub_go(r: AD, +i: U32, +x: F.D) -> Array<U32>:
  match r:
    case AD{a, y}:
      dset(a, i, F.d_sub(y, x))






def dsub(a: Array<U32>, +i: U32, +x: F.D) -> Array<U32>:
  dsub_go(dget(a, i), i, x)






# twice when the entry stands for two parallel edges
def dadd_m(m2: Bool, a: Array<U32>, +i: U32, +x: F.D) -> Array<U32>:
  match m2:
    case True{}:
      dadd(dadd(a, i, x), i, x)
    case False{}:
      dadd(a, i, x)






def dsub_m(m2: Bool, a: Array<U32>, +i: U32, +x: F.D) -> Array<U32>:
  match m2:
    case True{}:
      dsub(dsub(a, i, x), i, x)
    case False{}:
      dsub(a, i, x)






def uinc_go(r: Array<U32> & U32, +i: U32, +k: U32) -> Array<U32>:
  (a, +v) = r
  Array.set(U32, a, i, U32.add(v, k))






def uinc(a: Array<U32>, +i: U32, +k: U32) -> Array<U32>:
  uinc_go(Array.get(U32, a, i), i, k)






def rev_u(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      rev_u(t, h <> acc)






def sh_swap2(r: AU, +x: U32, +k: U32, +j: U32, +g: RNG) -> SH:
  match r:
    case AU{a, y}:
      SH{Array.set(U32, Array.set(U32, a, k, y), j, x), g}






def sh_swap(r: AU, +k: U32, +j: U32, +g: RNG) -> SH:
  match r:
    case AU{a, x}:
      sh_swap2(uget(a, j), x, k, j, g)






def sh_draw(r: RV, a: Array<U32>, +off: U32, +k: U32) -> SH:
  match r:
    case RV{g, j}:
      # n-- then swap v[n] and v[k]
      sh_swap(uget(a, U32.add(off, U32.sub(k, 1))), U32.add(off, U32.sub(k, 1)), U32.add(off, j), g)






def shuffle(n: Nat, +k: U32, +off: U32, s: SH) -> SH:
  match n:
    case 0n:
      s
    case 1n+p:
      match s:
        case SH{a, g}:
          shuffle(p, U32.sub(k, 1), off, sh_draw(bounded(g, k), a, off, k))






# shuffle all n elements (draws only while n > 1)
def shuffle_all(+n: U32, +off: U32, a: Array<U32>, +g: RNG) -> SH:
  shuffle(U32.to_nat(F.sel(U32.is_gt(n, 1), U32.sub(n, 1), 0)), n, off, SH{a, g})






def fill_id(n: Nat, +i: U32, +off: U32, a: Array<U32>) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      fill_id(p, U32.inc(i), off, Array.set(U32, a, U32.add(off, i), i))






def adj_get(adj: Array<List<&2, G.Nb>>, +v: U32) -> Array<List<&2, G.Nb>> & List<&2, G.Nb>:
  Array.get(List<&2, G.Nb>, adj, v)






def rx_put(fresh: Bool, memb: Array<U32>, nc: Array<U32>, +c: U32, +k: U32) -> RX:
  match fresh:
    case True{}:
      RX{memb, Array.set(U32, nc, c, k), U32.inc(k)}
    case False{}:
      RX{memb, nc, k}






def rx_new(r: AU, memb: Array<U32>, +c: U32, +k: U32) -> RX:
  match r:
    case AU{nc, x}:
      rx_put(U32.is_eq(x, 0), memb, nc, c, k)






def rx_scan_go(r: AU, nc: Array<U32>, +k: U32) -> RX:
  match r:
    case AU{memb, c}:
      rx_new(uget(nc, c), memb, c, k)






def rx_scan(n: Nat, +i: U32, x: RX) -> RX:
  match n:
    case 0n:
      x
    case 1n+p:
      match x:
        case RX{memb, nc, k}:
          rx_scan(p, U32.inc(i), rx_scan_go(uget(memb, i), nc, k))






def rx_map_set(r: AU, memb: Array<U32>, +k: U32, +i: U32) -> RX:
  match r:
    case AU{nc, v}:
      RX{Array.set(U32, memb, i, U32.sub(v, 1)), nc, k}






def rx_map_go(r: AU, nc: Array<U32>, +k: U32, +i: U32) -> RX:
  match r:
    case AU{memb, c}:
      rx_map_set(uget(nc, c), memb, k, i)






def rx_map(n: Nat, +i: U32, x: RX) -> RX:
  match n:
    case 0n:
      x
    case 1n+p:
      match x:
        case RX{memb, nc, k}:
          rx_map(p, U32.inc(i), rx_map_go(uget(memb, i), nc, k, i))






def rx_fin(x: RX) -> AU:
  match x:
    case RX{memb, nc, k}:
      AU{memb, U32.sub(k, 1)}






def reindex(memb: Array<U32>, +n: U32) -> AU:
  rx_fin(rx_map(U32.to_nat(n), 0, rx_scan(U32.to_nat(n), 0, RX{memb, G.u32_array(n, 0), 1})))





def fp_n(fp: FP) -> U32:
  match fp:
    case FP{n, mask, m2, res}:
      n





def fp_cap(fp: FP) -> U32:
  match fp:
    case FP{n, mask, m2, res}:
      U32.inc(mask)





def fp_mask(fp: FP) -> U32:
  match fp:
    case FP{n, mask, m2, res}:
      mask





def fp_m2(fp: FP) -> Bool:
  match fp:
    case FP{n, mask, m2, res}:
      m2





def fp_res(fp: FP) -> F.D:
  match fp:
    case FP{n, mask, m2, res}:
      res





# workspace offsets
def o_nb(+fp: FP) -> U32:
  0





def o_emp(+fp: FP) -> U32:
  fp_n(fp)





def o_add(+fp: FP) -> U32:
  U32.mul(fp_n(fp), 2)





def o_stb(+fp: FP) -> U32:
  U32.mul(fp_n(fp), 3)





def o_q(+fp: FP) -> U32:
  U32.mul(fp_n(fp), 4)





def o_cw(+fp: FP) -> U32:
  U32.add(U32.mul(fp_n(fp), 4), fp_cap(fp))





def o_ew(+fp: FP) -> U32:
  U32.add(U32.mul(fp_n(fp), 6), fp_cap(fp))





def w_size(+fp: FP) -> U32:
  U32.add(U32.mul(fp_n(fp), 8), fp_cap(fp))





def fi_w(r: AD, memb: Array<U32>, w: Array<U32>, +fp: FP, +c: U32, adj: Array<List<&2, G.Nb>>, +n: U32, +m2: Bool) -> FI:
  match r:
    case AD{nw, x}:
      FI{GR{adj, nw, n, m2}, memb, uinc(dadd(w, U32.add(o_cw(fp), U32.shl(c)), x), U32.add(o_nb(fp), c), 1)}





def fi_c(r: AU, gr: GR, w: Array<U32>, +fp: FP, +i: U32) -> FI:
  match r:
    case AU{memb, c}:
      match gr:
        case GR{adj, nw, n, m2}:
          fi_w(dget(nw, U32.shl(i)), memb, w, fp, c, adj, n, m2)





def fi_loop(k: Nat, +i: U32, +fp: FP, s: FI) -> FI:
  match k:
    case 0n:
      s
    case 1n+p:
      match s:
        case FI{gr, memb, w}:
          fi_loop(p, U32.inc(i), fp, fi_c(uget(memb, i), gr, w, fp, i))





def we_c(r: AU, +fp: FP, +c: U32, +etop: U32) -> WE:
  match r:
    case AU{w, s}:
      WE{Array.set(U32, w, U32.add(o_emp(fp), etop), c), U32.add(etop, F.b2u(U32.is_eq(s, 0)))}





def we_loop(k: Nat, +c: U32, +fp: FP, s: WE) -> WE:
  match k:
    case 0n:
      s
    case 1n+p:
      match s:
        case WE{w, etop}:
          we_loop(p, U32.inc(c), fp, we_c(uget(w, U32.add(o_nb(fp), c)), fp, c, etop))





def sc_cons(fresh: Bool, +c: U32, +neigh: List<&2, U32>) -> List<&2, U32>:
  match fresh:
    case True{}:
      c <> neigh
    case False{}:
      neigh





def sc_add(r: AU, memb: Array<U32>, +fp: FP, +c: U32, +wt: F.D, +neigh: List<&2, U32>) -> SC:
  match r:
    case AU{w, a}:
      SC{memb, dadd_m(fp_m2(fp), Array.set(U32, w, U32.add(o_add(fp), c), 1), U32.add(o_ew(fp), U32.shl(c)), wt),
        sc_cons(U32.is_eq(a, 0), c, neigh)}





def sc_memb(r: AU, w: Array<U32>, +fp: FP, +wt: F.D, +neigh: List<&2, U32>) -> SC:
  match r:
    case AU{memb, c}:
      sc_add(uget(w, U32.add(o_add(fp), c)), memb, fp, c, wt, neigh)





def sc_entry(self: Bool, memb: Array<U32>, w: Array<U32>, +fp: FP, +u: U32, +wt: F.D, +neigh: List<&2, U32>) -> SC:
  match self:
    case True{}:
      SC{memb, w, neigh}
    case False{}:
      sc_memb(uget(memb, u), w, fp, wt, neigh)





def fm_scan(es: List<&2, G.Nb>, +fp: FP, +v: U32, s: SC) -> SC:
  match es:
    case Nil{}:
      s
    case Con{e, t}:
      match e:
        case G.Nb{u, wh, wl}:
          match s:
            case SC{memb, w, neigh}:
              fm_scan(t, fp, v, sc_entry(U32.is_eq(u, v), memb, w, fp, u, F.D{wh, wl}, neigh))





# diff = ewpc[c] - nw[v] * cw[c] * res
def diff_of(+ew: F.D, +nwv: F.D, +cwc: F.D, +res: F.D) -> F.D:
  F.d_sub(ew, F.d_mul(F.d_mul(nwv, cwc), res))





def bs_pick(better: Bool, w: Array<U32>, +c: U32, +d: F.D, +best: U32, +maxd: F.D) -> BS:
  match better:
    case True{}:
      BS{w, c, d}
    case False{}:
      BS{w, best, maxd}





def bs_d(+d: F.D, w: Array<U32>, +c: U32, +best: U32, +maxd: F.D) -> BS:
  bs_pick(F.d_gt(d, maxd), w, c, d, best, maxd)





def bs_cw(r: AD, +ew: F.D, +fp: FP, +nwv: F.D, +c: U32, +best: U32, +maxd: F.D) -> BS:
  match r:
    case AD{w, cwc}:
      bs_d(diff_of(ew, nwv, cwc, fp_res(fp)),
        Array.set(U32, dset(w, U32.add(o_ew(fp), U32.shl(c)), F.D{0, 0}), U32.add(o_add(fp), c), 0),
        c, best, maxd)





def bs_ew(r: AD, +fp: FP, +nwv: F.D, +c: U32, +best: U32, +maxd: F.D) -> BS:
  match r:
    case AD{w, ew}:
      bs_cw(dget(w, U32.add(o_cw(fp), U32.shl(c))), ew, fp, nwv, c, best, maxd)





def fm_best(cs: List<&2, U32>, +fp: FP, +nwv: F.D, s: BS) -> BS:
  match cs:
    case Nil{}:
      s
    case Con{+c, t}:
      match s:
        case BS{w, best, maxd}:
          fm_best(t, fp, nwv, bs_ew(dget(w, U32.add(o_ew(fp), U32.shl(c))), fp, nwv, c, best, maxd))





def rq_push(go: Bool, memb: Array<U32>, w: Array<U32>, +fp: FP, +u: U32, +qt: U32) -> RQ:
  match go:
    case True{}:
      RQ{memb, Array.set(U32, Array.set(U32, w, U32.add(o_q(fp), U32.and(qt, fp_mask(fp))), u),
        U32.add(o_stb(fp), u), 0), U32.inc(qt)}
    case False{}:
      RQ{memb, w, qt}





def rq_m(r: AU, w: Array<U32>, +fp: FP, +u: U32, +best: U32, +qt: U32, +st: U32) -> RQ:
  match r:
    case AU{memb, mu}:
      rq_push(Bool.and(U32.is_eq(st, 1), U32.is_ne(mu, best)), memb, w, fp, u, qt)





def rq_s(r: AU, memb: Array<U32>, +fp: FP, +u: U32, +best: U32, +qt: U32) -> RQ:
  match r:
    case AU{w, st}:
      rq_m(uget(memb, u), w, fp, u, best, qt, st)





def fm_requeue(es: List<&2, G.Nb>, +fp: FP, +best: U32, s: RQ) -> RQ:
  match es:
    case Nil{}:
      s
    case Con{e, t}:
      match e:
        case G.Nb{u, wh, wl}:
          match s:
            case RQ{memb, w, qt}:
              fm_requeue(t, fp, best, rq_s(uget(w, U32.add(o_stb(fp), u)), memb, fp, u, best, qt))





def nv_rq(r: RQ, gr: GR, +etop: U32) -> NV:
  match r:
    case RQ{memb, w, qt}:
      NV{gr, memb, w, etop, qt, True{}}





def nv_moved(moved: Bool, es: List<&2, G.Nb>, gr: GR, memb: Array<U32>, w: Array<U32>, +fp: FP, +v: U32, +best: U32,
             +etop: U32, +qt: U32, +chg: Bool) -> NV:
  match moved:
    case False{}:
      NV{gr, memb, w, etop, qt, chg}
    case True{}:
      nv_rq(fm_requeue(es, fp, best, RQ{Array.set(U32, memb, v, best), w, qt}), gr, etop)





# after choosing best: move v (cw, nb, empty-stack pop), mark stable, requeue
def nv_top(r: AU, es: List<&2, G.Nb>, gr: GR, memb: Array<U32>, +fp: FP, +v: U32, +cur: U32, +best: U32,
           +etop: U32, +qt: U32, +chg: Bool) -> NV:
  match r:
    case AU{w, top}:
      nv_moved(U32.is_ne(best, cur), es, gr, memb, Array.set(U32, w, U32.add(o_stb(fp), v), 1), fp, v, best,
        U32.sub(etop, F.b2u(U32.is_eq(best, top))), qt, chg)





def nv_put(b: BS, es: List<&2, G.Nb>, gr: GR, memb: Array<U32>, +fp: FP, +v: U32, +cur: U32, +nwv: F.D,
           +etop: U32, +qt: U32, +chg: Bool) -> NV:
  match b:
    case BS{w, best, maxd}:
      nv_top(uget(uinc(dadd(w, U32.add(o_cw(fp), U32.shl(best)), nwv), U32.add(o_nb(fp), best), 1),
          U32.add(o_emp(fp), U32.sub(etop, 1))),
        es, gr, memb, fp, v, cur, best, etop, qt, chg)





def nv_max_cw(r: AD, +ew: F.D, sc: SC, es: List<&2, G.Nb>, gr: GR, +fp: FP, +v: U32, +cur: U32, +nwv: F.D,
              +etop: U32, +qt: U32, +chg: Bool) -> NV:
  match r:
    case AD{w, cwc}:
      match sc:
        case SC{memb, w0, neigh}:
          nv_put(fm_best(rev_u(neigh, Nil{}), fp, nwv, BS{w, cur, diff_of(ew, nwv, cwc, fp_res(fp))}),
            es, gr, memb, fp, v, cur, nwv, etop, qt, chg)





def nv_max_ew(r: AD, memb: Array<U32>, +neigh: List<&2, U32>, es: List<&2, G.Nb>, gr: GR, +fp: FP, +v: U32, +cur: U32,
              +nwv: F.D, +etop: U32, +qt: U32, +chg: Bool) -> NV:
  match r:
    case AD{w, ew}:
      nv_max_cw(dget(w, U32.add(o_cw(fp), U32.shl(cur))), ew, SC{memb, Array.new(U32, 0n, 0), neigh}, es, gr, fp, v, cur,
        nwv, etop, qt, chg)





def nv_max(sc: SC, es: List<&2, G.Nb>, gr: GR, +fp: FP, +v: U32, +cur: U32, +nwv: F.D, +etop: U32, +qt: U32, +chg: Bool) -> NV:
  match sc:
    case SC{memb, w, neigh}:
      nv_max_ew(dget(w, U32.add(o_ew(fp), U32.shl(cur))), memb, neigh, es, gr, fp, v, cur, nwv, etop, qt, chg)





def nv_scan(r: Array<List<&2, G.Nb>> & List<&2, G.Nb>, nw: Array<U32>, +n: U32, +m2: Bool, memb: Array<U32>, w: Array<U32>,
            +fp: FP, +v: U32, +cur: U32, +nwv: F.D, +etop: U32, +qt: U32, +chg: Bool, +c0: U32) -> NV:
  (adj, +es) = r
  nv_max(fm_scan(es, fp, v, SC{memb, Array.set(U32, w, U32.add(o_add(fp), c0), 1), [c0]}), es, GR{adj, nw, n, m2},
    fp, v, cur, nwv, etop, qt, chg)





def nv_c0(r: AU, gr: GR, memb: Array<U32>, +fp: FP, +v: U32, +cur: U32, +nwv: F.D, +etop: U32, +qt: U32, +chg: Bool) -> NV:
  match r:
    case AU{w, c0}:
      match gr:
        case GR{adj, nw, n, m2}:
          nv_scan(adj_get(adj, v), nw, n, m2, memb, w, fp, v, cur, nwv, etop, qt, chg, c0)





def nv_rm(emptied: Bool, w: Array<U32>, gr: GR, memb: Array<U32>, +fp: FP, +v: U32, +cur: U32, +nwv: F.D, +etop: U32,
          +qt: U32, +chg: Bool) -> NV:
  match emptied:
    case True{}:
      nv_c0(uget(Array.set(U32, w, U32.add(o_emp(fp), etop), cur), U32.add(o_emp(fp), etop)), gr, memb, fp, v, cur, nwv,
        U32.inc(etop), qt, chg)
    case False{}:
      nv_c0(uget(w, U32.add(o_emp(fp), U32.sub(etop, 1))), gr, memb, fp, v, cur, nwv, etop, qt, chg)





# remove v from its cluster: cw -= nw[v], nb--, push to empty stack if 0
def nv_nb(r: AU, gr: GR, memb: Array<U32>, +fp: FP, +v: U32, +cur: U32, +nwv: F.D, +etop: U32, +qt: U32, +chg: Bool) -> NV:
  match r:
    case AU{w, nbc}:
      nv_rm(U32.is_eq(nbc, 1), Array.set(U32, w, U32.add(o_nb(fp), cur), U32.sub(nbc, 1)), gr, memb, fp, v, cur, nwv, etop, qt, chg)





def nv_nw(r: AD, memb: Array<U32>, w: Array<U32>, adj: Array<List<&2, G.Nb>>, +n: U32, +m2: Bool, +fp: FP, +v: U32,
          +cur: U32, +etop: U32, +qt: U32, +chg: Bool) -> NV:
  match r:
    case AD{nw, nwv}:
      nv_nb(uget(dsub(w, U32.add(o_cw(fp), U32.shl(cur)), nwv), U32.add(o_nb(fp), cur)), GR{adj, nw, n, m2}, memb, fp, v,
        cur, nwv, etop, qt, chg)





def nv_cur(r: AU, gr: GR, w: Array<U32>, +fp: FP, +v: U32, +etop: U32, +qt: U32, +chg: Bool) -> NV:
  match r:
    case AU{memb, cur}:
      match gr:
        case GR{adj, nw, n, m2}:
          nv_nw(dget(nw, U32.shl(v)), memb, w, adj, n, m2, fp, v, cur, etop, qt, chg)





def nv_fm(nv: NV, +qh: U32, +g: RNG) -> FM:
  match nv:
    case NV{gr, memb, w, etop, qt, chg}:
      FM{gr, memb, w, etop, qh, qt, chg, g}





def fm_pop(r: AU, gr: GR, memb: Array<U32>, +fp: FP, +etop: U32, +qh: U32, +qt: U32, +chg: Bool, +g: RNG) -> FM:
  match r:
    case AU{w, v}:
      nv_fm(nv_cur(uget(memb, v), gr, w, fp, v, etop, qt, chg), qh, g)





def fm_more(s: FM) -> FM & Bool:
  match s:
    case FM{gr, memb, w, etop, qh, qt, chg, g}:
      (FM{gr, memb, w, etop, qh, qt, chg, g}, U32.is_ne(qh, qt))





def fm_step(+fp: FP, s: FM) -> FM:
  match s:
    case FM{gr, memb, w, etop, qh, qt, chg, g}:
      fm_pop(uget(w, U32.add(o_q(fp), U32.and(qh, fp_mask(fp)))), gr, memb, fp, etop, U32.inc(qh), qt, chg, g)





def fm_loop(k: Nat, +fp: FP, r: FM & Bool) -> FM:
  match k:
    case 0n:
      (s, more) = r
      s
    case 1n+p:
      (s, more) = r
      match more:
        case False{}:
          s
        case True{}:
          fm_loop(p, fp, fm_more(fm_step(fp, s)))





def fm_fin2(r: AU, gr: GR, +chg: Bool, +g: RNG) -> FMR:
  match r:
    case AU{memb, k}:
      FMR{gr, memb, k, chg, g}





def fm_fin(s: FM, +n: U32) -> FMR:
  match s:
    case FM{gr, memb, w, etop, qh, qt, chg, g}:
      fm_fin2(reindex(memb, n), gr, chg, g)





def fm_run(sh: SH, gr: GR, memb: Array<U32>, +fp: FP, +etop: U32, +chg: Bool) -> FMR:
  match sh:
    case SH{w, g}:
      fm_fin(fm_loop(U32.to_nat(4000000000), fp, fm_more(FM{gr, memb, w, etop, 0, fp_n(fp), chg, g})), fp_n(fp))





def fm_empties(s: WE, gr: GR, memb: Array<U32>, +fp: FP, +chg: Bool, +g: RNG) -> FMR:
  match s:
    case WE{w, etop}:
      fm_run(shuffle_all(fp_n(fp), o_q(fp), fill_id(U32.to_nat(fp_n(fp)), 0, o_q(fp), w), g), gr, memb, fp, etop, chg)





def fm_inited(s: FI, +fp: FP, +chg: Bool, +g: RNG) -> FMR:
  match s:
    case FI{gr, memb, w}:
      fm_empties(we_loop(U32.to_nat(fp_n(fp)), 0, fp, WE{w, 0}), gr, memb, fp, chg, g)





# fastmove(graph, membership): (graph, reindexed membership, #clusters, changed, rng)
def fastmove(gr: GR, memb: Array<U32>, +fp: FP, +chg: Bool, +g: RNG) -> FMR:
  fm_inited(fi_loop(U32.to_nat(fp_n(fp)), 0, fp, FI{gr, memb, G.u32_array(w_size(fp), 0)}), fp, chg, g)




def mp_ns(mp: MP) -> U32:
  match mp:
    case MP{ns, csub, m2, res, beta, tab}:
      ns




def mp_csub(mp: MP) -> U32:
  match mp:
    case MP{ns, csub, m2, res, beta, tab}:
      csub




def mp_m2(mp: MP) -> Bool:
  match mp:
    case MP{ns, csub, m2, res, beta, tab}:
      m2




def mp_res(mp: MP) -> F.D:
  match mp:
    case MP{ns, csub, m2, res, beta, tab}:
      res




def mp_beta(mp: MP) -> F.D:
  match mp:
    case MP{ns, csub, m2, res, beta, tab}:
      beta




def mp_tab(mp: MP) -> F.Tab:
  match mp:
    case MP{ns, csub, m2, res, beta, tab}:
      tab




def p_cw(+mp: MP, +c: U32) -> U32:
  U32.shl(c)




def p_ext(+mp: MP, +c: U32) -> U32:
  U32.add(U32.mul(mp_ns(mp), 2), U32.shl(c))




def p_ew(+mp: MP, +c: U32) -> U32:
  U32.add(U32.mul(mp_ns(mp), 4), U32.shl(c))




def p_cum(+mp: MP, +j: U32) -> U32:
  U32.add(U32.mul(mp_ns(mp), 6), U32.shl(j))




def p_nons(+mp: MP, +c: U32) -> U32:
  U32.add(U32.mul(mp_ns(mp), 8), c)




def p_add(+mp: MP, +c: U32) -> U32:
  U32.add(U32.mul(mp_ns(mp), 9), c)




def p_ord(+mp: MP, +i: U32) -> U32:
  U32.add(U32.mul(mp_ns(mp), 10), i)




def p_newc(+mp: MP, +c: U32) -> U32:
  U32.add(U32.mul(mp_ns(mp), 11), c)




def xs_add(inside: Bool, memb: Array<U32>, w: Array<U32>, +mp: MP, +i: U32, +wt: F.D) -> XS:
  match inside:
    case True{}:
      XS{memb, dadd_m(mp_m2(mp), w, p_ext(mp, i), wt)}
    case False{}:
      XS{memb, w}




def xs_m(r: AU, w: Array<U32>, +mp: MP, +i: U32, +wt: F.D) -> XS:
  match r:
    case AU{memb, mu}:
      xs_add(U32.is_eq(mu, mp_csub(mp)), memb, w, mp, i, wt)




def xs_e(self: Bool, memb: Array<U32>, w: Array<U32>, +mp: MP, +u: U32, +i: U32, +wt: F.D) -> XS:
  match self:
    case True{}:
      XS{memb, w}
    case False{}:
      xs_m(uget(memb, u), w, mp, i, wt)




def xs_scan(es: List<&2, G.Nb>, +mp: MP, +v: U32, +i: U32, s: XS) -> XS:
  match es:
    case Nil{}:
      s
    case Con{e, t}:
      match e:
        case G.Nb{u, wh, wl}:
          match s:
            case XS{memb, w}:
              xs_scan(t, mp, v, i, xs_e(U32.is_eq(u, v), memb, w, mp, u, i, F.D{wh, wl}))




def mi_fin(x: XS, gr: GR, refined: Array<U32>, +total: F.D, +g: RNG) -> MG:
  match x:
    case XS{memb, w}:
      MG{gr, memb, refined, w, total, g}




def mi_scan(r: Array<List<&2, G.Nb>> & List<&2, G.Nb>, nw: Array<U32>, +n: U32, +m2: Bool, memb: Array<U32>,
            refined: Array<U32>, w: Array<U32>, +total: F.D, +g: RNG, +mp: MP, +v: U32, +i: U32) -> MG:
  (adj, +es) = r
  mi_fin(xs_scan(es, mp, v, i, XS{memb, w}), GR{adj, nw, n, m2}, refined, total, g)




def mi_nw(r: AD, adj: Array<List<&2, G.Nb>>, +n: U32, +m2: Bool, memb: Array<U32>, refined: Array<U32>, w: Array<U32>,
          +total: F.D, +g: RNG, +mp: MP, +v: U32, +i: U32) -> MG:
  match r:
    case AD{nw, x}:
      mi_scan(adj_get(adj, v), nw, n, m2, memb, refined,
        Array.set(U32, dset(w, p_cw(mp, i), x), p_ord(mp, i), v), F.d_add(total, x), g, mp, v, i)




def mi_one(s: MG, +mp: MP, +v: U32, +i: U32) -> MG:
  match s:
    case MG{gr, memb, refined, w, total, g}:
      match gr:
        case GR{adj, nw, n, m2}:
          mi_nw(dget(nw, U32.shl(v)), adj, n, m2, memb, Array.set(U32, refined, v, i), w, total, g, mp, v, i)




def mi_loop(xs: List<&2, U32>, +mp: MP, +i: U32, s: MG) -> MG:
  match xs:
    case Nil{}:
      s
    case Con{+v, t}:
      mi_loop(t, mp, U32.inc(i), mi_one(s, mp, v, i))




# well-connectedness: ext[c] >= cw[c] * (total - cw[c]) * res
def well(+ext: F.D, +cwc: F.D, +total: F.D, +res: F.D) -> Bool:
  F.d_ge(ext, F.d_mul(F.d_mul(cwc, F.d_sub(total, cwc)), res))




def rs_add(r: AU, memb: Array<U32>, refined: Array<U32>, +mp: MP, +c: U32, +wt: F.D, +neigh: List<&2, U32>) -> RS2:
  match r:
    case AU{w, a}:
      RS2{memb, refined, dadd_m(mp_m2(mp), Array.set(U32, w, p_add(mp, c), 1), p_ew(mp, c), wt),
        sc_cons(U32.is_eq(a, 0), c, neigh)}




def rs_ref(r: AU, memb: Array<U32>, w: Array<U32>, +mp: MP, +wt: F.D, +neigh: List<&2, U32>) -> RS2:
  match r:
    case AU{refined, c}:
      rs_add(uget(w, p_add(mp, c)), memb, refined, mp, c, wt, neigh)




def rs_in(inside: Bool, memb: Array<U32>, refined: Array<U32>, w: Array<U32>, +mp: MP, +u: U32, +wt: F.D, +neigh: List<&2, U32>) -> RS2:
  match inside:
    case True{}:
      rs_ref(uget(refined, u), memb, w, mp, wt, neigh)
    case False{}:
      RS2{memb, refined, w, neigh}




def rs_m(r: AU, refined: Array<U32>, w: Array<U32>, +mp: MP, +u: U32, +wt: F.D, +neigh: List<&2, U32>) -> RS2:
  match r:
    case AU{memb, mu}:
      rs_in(U32.is_eq(mu, mp_csub(mp)), memb, refined, w, mp, u, wt, neigh)




def rs_e(self: Bool, memb: Array<U32>, refined: Array<U32>, w: Array<U32>, +mp: MP, +u: U32, +wt: F.D, +neigh: List<&2, U32>) -> RS2:
  match self:
    case True{}:
      RS2{memb, refined, w, neigh}
    case False{}:
      rs_m(uget(memb, u), refined, w, mp, u, wt, neigh)




def rs_scan(es: List<&2, G.Nb>, +mp: MP, +v: U32, s: RS2) -> RS2:
  match es:
    case Nil{}:
      s
    case Con{e, t}:
      match e:
        case G.Nb{u, wh, wl}:
          match s:
            case RS2{memb, refined, w, neigh}:
              rs_scan(t, mp, v, rs_e(U32.is_eq(u, v), memb, refined, w, mp, u, F.D{wh, wl}, neigh))




def ds_pos(pos: Bool, +d: F.D, +mp: MP, +tot: F.D) -> F.D:
  match pos:
    case True{}:
      F.d_add(tot, F.d_exp(F.d_div(d, mp_beta(mp)), mp_tab(mp)))
    case False{}:
      tot




def ds_store(w: Array<U32>, +mp: MP, +c: U32, +best: U32, +maxd: F.D, +tot: F.D, +j: U32) -> DS:
  DS{Array.set(U32, dset(dset(w, p_cum(mp, j), tot), p_ew(mp, c), F.D{0, 0}), p_add(mp, c), 0), best, maxd, tot, U32.inc(j)}




def ds_fin(better: Bool, w: Array<U32>, +mp: MP, +c: U32, +d: F.D, +best: U32, +maxd: F.D, +tot: F.D, +j: U32) -> DS:
  match better:
    case True{}:
      ds_store(w, mp, c, c, d, tot, j)
    case False{}:
      ds_store(w, mp, c, best, maxd, tot, j)




def ds_d(+d: F.D, w: Array<U32>, +mp: MP, +c: U32, +best: U32, +maxd: F.D, +tot: F.D, +j: U32) -> DS:
  ds_fin(F.d_gt(d, maxd), w, mp, c, d, best, maxd, ds_pos(F.d_ge(d, F.D{0, 0}), d, mp, tot), j)




def ds_ok(ok: Bool, +ew: F.D, +cwc: F.D, w: Array<U32>, +mp: MP, +nwv: F.D, +c: U32, +best: U32, +maxd: F.D, +tot: F.D, +j: U32) -> DS:
  match ok:
    case True{}:
      ds_d(diff_of(ew, nwv, cwc, mp_res(mp)), w, mp, c, best, maxd, tot, j)
    case False{}:
      ds_store(w, mp, c, best, maxd, tot, j)




def ds_cw(r: AD, +ew: F.D, +ext: F.D, +mp: MP, +nwv: F.D, +total: F.D, +c: U32, +best: U32, +maxd: F.D, +tot: F.D, +j: U32) -> DS:
  match r:
    case AD{w, cwc}:
      ds_ok(well(ext, cwc, total, mp_res(mp)), ew, cwc, w, mp, nwv, c, best, maxd, tot, j)




def ds_ew(r: AD, +ext: F.D, +mp: MP, +nwv: F.D, +total: F.D, +c: U32, +best: U32, +maxd: F.D, +tot: F.D, +j: U32) -> DS:
  match r:
    case AD{w, ew}:
      ds_cw(dget(w, p_cw(mp, c)), ew, ext, mp, nwv, total, c, best, maxd, tot, j)




def ds_ext(r: AD, +mp: MP, +nwv: F.D, +total: F.D, +c: U32, +best: U32, +maxd: F.D, +tot: F.D, +j: U32) -> DS:
  match r:
    case AD{w, ext}:
      ds_ew(dget(w, p_ew(mp, c)), ext, mp, nwv, total, c, best, maxd, tot, j)




def ds_loop(cs: List<&2, U32>, +mp: MP, +nwv: F.D, +total: F.D, s: DS) -> DS:
  match cs:
    case Nil{}:
      s
    case Con{+c, t}:
      match s:
        case DS{w, best, maxd, tot, j}:
          ds_loop(t, mp, nwv, total, ds_ext(dget(w, p_ext(mp, c)), mp, nwv, total, c, best, maxd, tot, j))




def bi_pick(gt: Bool, lt: Bool, w: Array<U32>, +lo: U32, +hi: U32, +mid: U32) -> BI:
  match gt lt:
    case True{} _:
      BI{w, lo, mid, False{}}
    case False{} True{}:
      BI{w, U32.inc(mid), hi, False{}}
    case False{} False{}:
      BI{w, mid, mid, True{}}




def bi_cmp(r: AD, +x: F.D, +lo: U32, +hi: U32, +mid: U32) -> BI:
  match r:
    case AD{w, c}:
      bi_pick(F.d_gt(c, x), F.d_lt(c, x), w, lo, hi, mid)




def bi_go(stop: Bool, w: Array<U32>, +lo: U32, +hi: U32, +mp: MP, +x: F.D) -> BI:
  match stop:
    case True{}:
      BI{w, lo, hi, True{}}
    case False{}:
      +mid = U32.add(lo, U32.shr(U32.sub(U32.sub(hi, 1), lo)))
      bi_cmp(dget(w, p_cum(mp, mid)), x, lo, hi, mid)




def bi_step(s: BI, +mp: MP, +x: F.D) -> BI:
  match s:
    case BI{w, lo, hi, found}:
      bi_go(Bool.or(found, U32.is_ge(lo, hi)), w, lo, hi, mp, x)




def bi_loop(k: Nat, +mp: MP, +x: F.D, s: BI) -> BI:
  match k:
    case 0n:
      s
    case 1n+p:
      bi_loop(p, mp, x, bi_step(s, mp, x))




def nth_u(xs: List<&2, U32>, +i: U32) -> U32:
  match xs:
    case Nil{}:
      0
    case Con{+x, t}:
      F.sel(U32.is_eq(i, 0), x, nth_u(t, U32.sub(i, 1)))




def eu_apply(same: Bool, memb: Array<U32>, refined: Array<U32>, w: Array<U32>, +mp: MP, +chosen: U32, +wt: F.D) -> EU:
  match same:
    case True{}:
      EU{memb, refined, dsub_m(mp_m2(mp), w, p_ext(mp, chosen), wt)}
    case False{}:
      EU{memb, refined, dadd_m(mp_m2(mp), w, p_ext(mp, chosen), wt)}




def eu_r(r: AU, memb: Array<U32>, w: Array<U32>, +mp: MP, +chosen: U32, +wt: F.D) -> EU:
  match r:
    case AU{refined, ru}:
      eu_apply(U32.is_eq(ru, chosen), memb, refined, w, mp, chosen, wt)




def eu_in(inside: Bool, memb: Array<U32>, refined: Array<U32>, w: Array<U32>, +mp: MP, +u: U32, +chosen: U32, +wt: F.D) -> EU:
  match inside:
    case True{}:
      eu_r(uget(refined, u), memb, w, mp, chosen, wt)
    case False{}:
      EU{memb, refined, w}




def eu_m(r: AU, refined: Array<U32>, w: Array<U32>, +mp: MP, +u: U32, +chosen: U32, +wt: F.D) -> EU:
  match r:
    case AU{memb, mu}:
      eu_in(U32.is_eq(mu, mp_csub(mp)), memb, refined, w, mp, u, chosen, wt)




def eu_scan(es: List<&2, G.Nb>, +mp: MP, +chosen: U32, s: EU) -> EU:
  match es:
    case Nil{}:
      s
    case Con{e, t}:
      match e:
        case G.Nb{u, wh, wl}:
          match s:
            case EU{memb, refined, w}:
              eu_scan(t, mp, chosen, eu_m(uget(memb, u), refined, w, mp, u, chosen, F.D{wh, wl}))




# one node of the shuffled order
def mv_set(chosen_new: Bool, e: EU, gr: GR, +total: F.D, +g: RNG, +mp: MP, +v: U32, +chosen: U32) -> MG:
  match chosen_new:
    case True{}:
      match e:
        case EU{memb, refined, w}:
          MG{gr, memb, Array.set(U32, refined, v, chosen), Array.set(U32, w, p_nons(mp, chosen), 1), total, g}
    case False{}:
      match e:
        case EU{memb, refined, w}:
          MG{gr, memb, refined, w, total, g}




def mv_move(+chosen: U32, es: List<&2, G.Nb>, gr: GR, memb: Array<U32>, refined: Array<U32>, w: Array<U32>,
            +total: F.D, +g: RNG, +mp: MP, +v: U32, +cur: U32, +nwv: F.D) -> MG:
  mv_set(U32.is_ne(chosen, cur), eu_scan(es, mp, chosen, EU{memb, refined, dadd(w, p_cw(mp, chosen), nwv)}),
    gr, total, g, mp, v, chosen)




def mv_bi(b: BI, +neigh: List<&2, U32>, +g: RNG, es: List<&2, G.Nb>, gr: GR, memb: Array<U32>, refined: Array<U32>,
          +total: F.D, +mp: MP, +v: U32, +cur: U32, +nwv: F.D) -> MG:
  match b:
    case BI{w, lo, hi, found}:
      mv_move(nth_u(neigh, lo), es, gr, memb, refined, w, total, g, mp, v, cur, nwv)




def mv_r(r: RD, w: Array<U32>, +neigh: List<&2, U32>, +len: U32, es: List<&2, G.Nb>, gr: GR, memb: Array<U32>,
         refined: Array<U32>, +total: F.D, +mp: MP, +v: U32, +cur: U32, +nwv: F.D) -> MG:
  match r:
    case RD{g, x}:
      mv_bi(bi_loop(40n, mp, x, BI{w, 0, len, False{}}), neigh, g, es, gr, memb, refined, total, mp, v, cur, nwv)




def mv_choose(finite: Bool, d: DS, +neigh: List<&2, U32>, es: List<&2, G.Nb>, gr: GR, memb: Array<U32>, refined: Array<U32>,
              +total: F.D, +g: RNG, +mp: MP, +v: U32, +cur: U32, +nwv: F.D) -> MG:
  match finite:
    case True{}:
      match d:
        case DS{w, best, maxd, tot, j}:
          mv_r(unif(g, tot), w, neigh, j, es, gr, memb, refined, total, mp, v, cur, nwv)
    case False{}:
      match d:
        case DS{w, best, maxd, tot, j}:
          mv_move(best, es, gr, memb, refined, w, total, g, mp, v, cur, nwv)




def ds_tot(d: DS) -> DS & F.D:
  match d:
    case DS{w, best, maxd, tot, j}:
      (DS{w, best, maxd, tot, j}, tot)




def mv_ds(dt: DS & F.D, +neigh: List<&2, U32>, es: List<&2, G.Nb>, gr: GR, memb: Array<U32>, refined: Array<U32>,
          +total: F.D, +g: RNG, +mp: MP, +v: U32, +cur: U32, +nwv: F.D) -> MG:
  (d, +tot) = dt
  mv_choose(F.d_lt(tot, F.D{2146435072, 0}), d, neigh, es, gr, memb, refined, total, g, mp, v, cur, nwv)




def mv_scanned(s: RS2, es: List<&2, G.Nb>, gr: GR, +total: F.D, +g: RNG, +mp: MP, +cur: U32, +v: U32, +nwv: F.D) -> MG:
  match s:
    case RS2{memb, refined, w, neigh}:
      mv_ds(ds_tot(ds_loop(rev_u(neigh, Nil{}), mp, nwv, total, DS{w, cur, F.D{0, 0}, F.D{0, 0}, 0})),
        rev_u(neigh, Nil{}), es, gr, memb, refined, total, g, mp, v, cur, nwv)




def mv_go(r: Array<List<&2, G.Nb>> & List<&2, G.Nb>, nw: Array<U32>, +n: U32, +m2: Bool, memb: Array<U32>,
          refined: Array<U32>, w: Array<U32>, +total: F.D, +g: RNG, +mp: MP, +v: U32, +cur: U32, +nwv: F.D) -> MG:
  (adj, +es) = r
  mv_scanned(rs_scan(es, mp, v, RS2{memb, refined, Array.set(U32, dset(w, p_cw(mp, cur), F.D{0, 0}), p_add(mp, cur), 1), [cur]}),
    es, GR{adj, nw, n, m2}, total, g, mp, cur, v, nwv)




def mv_nw(r: AD, adj: Array<List<&2, G.Nb>>, +n: U32, +m2: Bool, memb: Array<U32>, refined: Array<U32>, w: Array<U32>,
          +total: F.D, +g: RNG, +mp: MP, +v: U32, +cur: U32) -> MG:
  match r:
    case AD{nw, nwv}:
      mv_go(adj_get(adj, v), nw, n, m2, memb, refined, w, total, g, mp, v, cur, nwv)




def mv_when(ok: Bool, gr: GR, memb: Array<U32>, refined: Array<U32>, w: Array<U32>, +total: F.D, +g: RNG, +mp: MP, +v: U32, +cur: U32) -> MG:
  match ok:
    case False{}:
      MG{gr, memb, refined, w, total, g}
    case True{}:
      match gr:
        case GR{adj, nw, n, m2}:
          mv_nw(dget(nw, U32.shl(v)), adj, n, m2, memb, refined, w, total, g, mp, v, cur)




def mv_cw(r: AD, +ext: F.D, +nons: U32, gr: GR, memb: Array<U32>, refined: Array<U32>, +total: F.D, +g: RNG, +mp: MP, +v: U32, +cur: U32) -> MG:
  match r:
    case AD{w, cwc}:
      mv_when(Bool.and(U32.is_eq(nons, 0), well(ext, cwc, total, mp_res(mp))), gr, memb, refined, w, total, g, mp, v, cur)




def mv_ext(r: AD, +nons: U32, gr: GR, memb: Array<U32>, refined: Array<U32>, +total: F.D, +g: RNG, +mp: MP, +v: U32, +cur: U32) -> MG:
  match r:
    case AD{w, ext}:
      mv_cw(dget(w, p_cw(mp, cur)), ext, nons, gr, memb, refined, total, g, mp, v, cur)




def mv_nons(r: AU, gr: GR, memb: Array<U32>, refined: Array<U32>, +total: F.D, +g: RNG, +mp: MP, +v: U32, +cur: U32) -> MG:
  match r:
    case AU{w, nons}:
      mv_ext(dget(w, p_ext(mp, cur)), nons, gr, memb, refined, total, g, mp, v, cur)




def mv_cur(r: AU, gr: GR, memb: Array<U32>, w: Array<U32>, +total: F.D, +g: RNG, +mp: MP, +v: U32) -> MG:
  match r:
    case AU{refined, cur}:
      mv_nons(uget(w, p_nons(mp, cur)), gr, memb, refined, total, g, mp, v, cur)




def mv_v(r: AU, gr: GR, memb: Array<U32>, refined: Array<U32>, +total: F.D, +g: RNG, +mp: MP) -> MG:
  match r:
    case AU{w, v}:
      mv_cur(uget(refined, v), gr, memb, w, total, g, mp, v)




def mv_loop(k: Nat, +i: U32, +mp: MP, s: MG) -> MG:
  match k:
    case 0n:
      s
    case 1n+p:
      match s:
        case MG{gr, memb, refined, w, total, g}:
          mv_loop(p, U32.inc(i), mp, mv_v(uget(w, p_ord(mp, i)), gr, memb, refined, total, g, mp))




def cr_put(fresh: Bool, refined: Array<U32>, w: Array<U32>, +mp: MP, +c: U32, +nb: U32) -> CR:
  match fresh:
    case True{}:
      CR{refined, Array.set(U32, w, p_newc(mp, c), nb), U32.inc(nb)}
    case False{}:
      CR{refined, w, nb}




def cr_new(r: AU, refined: Array<U32>, +mp: MP, +c: U32, +nb: U32) -> CR:
  match r:
    case AU{w, x}:
      cr_put(U32.is_eq(x, 0), refined, w, mp, c, nb)




def cr_c(r: AU, w: Array<U32>, +mp: MP, +nb: U32) -> CR:
  match r:
    case AU{refined, c}:
      cr_new(uget(w, p_newc(mp, c)), refined, mp, c, nb)




def cr_scan(xs: List<&2, U32>, +mp: MP, s: CR) -> CR:
  match xs:
    case Nil{}:
      s
    case Con{+v, t}:
      match s:
        case CR{refined, w, nb}:
          cr_scan(t, mp, cr_c(uget(refined, v), w, mp, nb))




def cr_m2(r: AU, refined: Array<U32>, +v: U32, +nb: U32) -> CR:
  match r:
    case AU{w, x}:
      CR{Array.set(U32, refined, v, U32.sub(x, 1)), w, nb}




def cr_m1(r: AU, w: Array<U32>, +mp: MP, +v: U32, +nb: U32) -> CR:
  match r:
    case AU{refined, c}:
      cr_m2(uget(w, p_newc(mp, c)), refined, v, nb)




def cr_map(xs: List<&2, U32>, +mp: MP, s: CR) -> CR:
  match xs:
    case Nil{}:
      s
    case Con{+v, t}:
      match s:
        case CR{refined, w, nb}:
          cr_map(t, mp, cr_m1(uget(refined, v), w, mp, v, nb))




def mn_fin(c: CR, gr: GR, memb: Array<U32>, +g: RNG) -> MR:
  match c:
    case CR{refined, w, nb}:
      MR{gr, memb, refined, U32.sub(nb, 1), g}




def mn_clean(s: MG, +xs: List<&2, U32>, +mp: MP, +nb: U32) -> MR:
  match s:
    case MG{gr, memb, refined, w, total, g}:
      mn_fin(cr_map(xs, mp, cr_scan(xs, mp, CR{refined, w, U32.inc(nb)})), gr, memb, g)




def mn_shuffled(sh: SH, gr: GR, memb: Array<U32>, refined: Array<U32>, +total: F.D, +xs: List<&2, U32>, +mp: MP, +nb: U32) -> MR:
  match sh:
    case SH{w, g}:
      mn_clean(mv_loop(U32.to_nat(mp_ns(mp)), 0, mp, MG{gr, memb, refined, w, total, g}), xs, mp, nb)




def mn_inited(s: MG, +xs: List<&2, U32>, +mp: MP, +nb: U32) -> MR:
  match s:
    case MG{gr, memb, refined, w, total, g}:
      mn_shuffled(shuffle_all(mp_ns(mp), p_ord(mp, 0), w, g), gr, memb, refined, total, xs, mp, nb)




def mergenodes(gr: GR, memb: Array<U32>, refined: Array<U32>, +xs: List<&2, U32>, +mp: MP, +nb: U32, +g: RNG) -> MR:
  mn_inited(mi_loop(xs, mp, 0, MG{gr, memb, refined, G.u32_array(U32.mul(mp_ns(mp), 12), 0), F.D{0, 0}, g}), xs, mp, nb)



def cl_push_go(r: Array<List<&2, U32>> & List<&2, U32>, +c: U32, +v: U32) -> Array<List<&2, U32>>:
  (cl, xs) = r
  Array.set(List<&2, U32>, cl, c, v <> xs)



def cl_push(r: AU, cl: Array<List<&2, U32>>, +v: U32) -> CL2:
  match r:
    case AU{memb, c}:
      CL2{memb, cl_push_go(Array.swap(List<&2, U32>, cl, c, Nil{}), c, v)}



def cl_loop(k: Nat, +v: U32, s: CL2) -> CL2:
  match k:
    case 0n:
      s
    case 1n+p:
      match s:
        case CL2{memb, cl}:
          cl_loop(p, U32.sub(v, 1), cl_push(uget(memb, v), cl, v))



def clusters_of(memb: Array<U32>, +n: U32, +k: U32) -> CL2:
  cl_loop(U32.to_nat(n), U32.sub(n, 1), CL2{memb, Array.new(List<&2, U32>, G.depth(k), Nil{})})



def len_u(xs: List<&2, U32>, +acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{x, t}:
      len_u(t, U32.inc(acc))



def rf_mr(m: MR, cl: Array<List<&2, U32>>) -> RF:
  match m:
    case MR{gr, memb, refined, nb, g}:
      RF{gr, memb, refined, cl, nb, g}



def rf_c(r: Array<List<&2, U32>> & List<&2, U32>, gr: GR, memb: Array<U32>, refined: Array<U32>, +nb: U32, +g: RNG,
         +c: U32, +res: F.D, +beta: F.D, +tab: F.Tab) -> RF:
  (cl, +xs) = r
  match gr:
    case GR{adj, nw, n, m2}:
      rf_mr(mergenodes(GR{adj, nw, n, m2}, memb, refined, xs, MP{len_u(xs, 0), c, m2, res, beta, tab}, nb, g), cl)



def rf_loop(k: Nat, +c: U32, +res: F.D, +beta: F.D, +tab: F.Tab, s: RF) -> RF:
  match k:
    case 0n:
      s
    case 1n+p:
      match s:
        case RF{gr, memb, refined, cl, nb, g}:
          rf_loop(p, U32.inc(c), res, beta, tab, rf_c(Array.get(List<&2, U32>, cl, c), gr, memb, refined, nb, g, c, res, beta, tab))



def as_add(r: AU, refined: Array<U32>, +m2: Bool, +c2: U32, +wt: F.D, +neigh: List<&2, U32>, +nref: U32) -> AS:
  match r:
    case AU{ws, a}:
      AS{refined, dadd_m(m2, Array.set(U32, ws, U32.add(U32.shl(nref), c2), 1), U32.shl(c2), wt), sc_cons(U32.is_eq(a, 0), c2, neigh)}



def as_up(up: Bool, refined: Array<U32>, ws: Array<U32>, +m2: Bool, +c2: U32, +wt: F.D, +neigh: List<&2, U32>, +nref: U32) -> AS:
  match up:
    case True{}:
      as_add(uget(ws, U32.add(U32.shl(nref), c2)), refined, m2, c2, wt, neigh, nref)
    case False{}:
      AS{refined, ws, neigh}



def as_r(r: AU, ws: Array<U32>, +m2: Bool, +c: U32, +wt: F.D, +neigh: List<&2, U32>, +nref: U32) -> AS:
  match r:
    case AU{refined, c2}:
      as_up(U32.is_gt(c2, c), refined, ws, m2, c2, wt, neigh, nref)



def as_scan(es: List<&2, G.Nb>, +m2: Bool, +c: U32, +nref: U32, s: AS) -> AS:
  match es:
    case Nil{}:
      s
    case Con{e, t}:
      match e:
        case G.Nb{u, wh, wl}:
          match s:
            case AS{refined, ws, neigh}:
              as_scan(t, m2, c, nref, as_r(uget(refined, u), ws, m2, c, F.D{wh, wl}, neigh, nref))



def an_es(r: Array<List<&2, G.Nb>> & List<&2, G.Nb>, nw: Array<U32>, +n: U32, +m2: Bool, s: AS, +anw: F.D, +v: U32, +c: U32, +nref: U32) -> AN:
  (adj, +es) = r
  AN{GR{adj, nw, n, m2}, as_scan(es, m2, c, nref, s), anw, v}



def an_nw(r: AD, adj: Array<List<&2, G.Nb>>, +n: U32, +m2: Bool, s: AS, +anw: F.D, +v: U32, +c: U32, +nref: U32) -> AN:
  match r:
    case AD{nw, x}:
      an_es(adj_get(adj, v), nw, n, m2, s, F.d_add(anw, x), v, c, nref)



def an_loop(xs: List<&2, U32>, +c: U32, +nref: U32, a: AN) -> AN:
  match xs:
    case Nil{}:
      a
    case Con{+v, t}:
      match a:
        case AN{gr, s, anw, last}:
          match gr:
            case GR{adj, nw, n, m2}:
              an_loop(t, c, nref, an_nw(dget(nw, U32.shl(v)), adj, n, m2, s, anw, v, c, nref))



def ae_w(r: AD, lower: Array<List<&2, G.Nb>>, +up: List<&2, G.Nb>, +c: U32, +c2: U32, +nref: U32) -> AE:
  match r:
    case AD{ws, wt}:
      match wt:
        case F.D{h, l}:
          AE{Array.set(U32, dset(ws, U32.shl(c2), F.D{0, 0}), U32.add(U32.shl(nref), c2), 0),
            G.push_row(lower, c2, G.Nb{c, h, l}), G.Nb{c2, h, l} <> up}



def ae_loop(cs: List<&2, U32>, +c: U32, +nref: U32, a: AE) -> AE:
  match cs:
    case Nil{}:
      a
    case Con{+c2, t}:
      match a:
        case AE{ws, lower, up}:
          ae_loop(t, c, nref, ae_w(dget(ws, U32.shl(c2)), lower, up, c, c2, nref))



def ag_emit(e: AE, gr: GR, memb: Array<U32>, refined: Array<U32>, upper: Array<List<&2, G.Nb>>, nw2: Array<U32>,
            amemb: Array<U32>, +c: U32, +anw: F.D, +mlast: U32) -> AG:
  match e:
    case AE{ws, lower, up}:
      AG{gr, memb, refined, ws, lower, Array.set(List<&2, G.Nb>, upper, c, up), dset(nw2, U32.shl(c), anw),
        Array.set(U32, amemb, c, mlast)}



def ag_ml(r: AU, s: AS, gr: GR, +anw: F.D, lower: Array<List<&2, G.Nb>>, upper: Array<List<&2, G.Nb>>, nw2: Array<U32>,
          amemb: Array<U32>, +c: U32, +nref: U32) -> AG:
  match r:
    case AU{memb, ml}:
      match s:
        case AS{refined, ws, neigh}:
          ag_emit(ae_loop(rev_u(neigh, Nil{}), c, nref, AE{ws, lower, Nil{}}), gr, memb, refined, upper, nw2, amemb, c, anw, ml)



def ag_an(a: AN, memb: Array<U32>, lower: Array<List<&2, G.Nb>>, upper: Array<List<&2, G.Nb>>, nw2: Array<U32>,
          amemb: Array<U32>, +c: U32, +nref: U32) -> AG:
  match a:
    case AN{gr, s, anw, last}:
      ag_ml(uget(memb, last), s, gr, anw, lower, upper, nw2, amemb, c, nref)



def ag_c(r: Array<List<&2, U32>> & List<&2, U32>, ag: AG, +c: U32, +nref: U32) -> AG & Array<List<&2, U32>>:
  (cl, +xs) = r
  match ag:
    case AG{gr, memb, refined, ws, lower, upper, nw2, amemb}:
      (ag_an(an_loop(xs, c, nref, AN{gr, AS{refined, ws, Nil{}}, F.D{0, 0}, 0}), memb, lower, upper, nw2, amemb, c, nref), cl)



def ag_loop(k: Nat, +c: U32, +nref: U32, r: AG & Array<List<&2, U32>>) -> AG:
  match k:
    case 0n:
      (ag, cl) = r
      ag
    case 1n+p:
      (ag, cl) = r
      ag_loop(p, U32.inc(c), nref, ag_c(Array.get(List<&2, U32>, cl, c), ag, c, nref))



# final incidence lists: lower part (increasing) then sorted upper part
def adj_join(+lo: List<&2, G.Nb>, +up: List<&2, G.Nb>) -> List<&2, G.Nb>:
  G.nb_rev_onto(lo, List.sort(~G.Nb, ~G.nb_le, up))



def aj_u(r: Array<List<&2, G.Nb>> & List<&2, G.Nb>, +lo: List<&2, G.Nb>, lower: Array<List<&2, G.Nb>>, adj: Array<List<&2, G.Nb>>, +c: U32) -> AJ:
  (upper, +up) = r
  AJ{lower, upper, Array.set(List<&2, G.Nb>, adj, c, adj_join(lo, up))}



def aj_l(r: Array<List<&2, G.Nb>> & List<&2, G.Nb>, upper: Array<List<&2, G.Nb>>, adj: Array<List<&2, G.Nb>>, +c: U32) -> AJ:
  (lower, +lo) = r
  aj_u(Array.get(List<&2, G.Nb>, upper, c), lo, lower, adj, c)



def aj_loop(k: Nat, +c: U32, s: AJ) -> AJ:
  match k:
    case 0n:
      s
    case 1n+p:
      match s:
        case AJ{lower, upper, adj}:
          aj_loop(p, U32.inc(c), aj_l(Array.get(List<&2, G.Nb>, lower, c), upper, adj, c))



def aj_adj(s: AJ) -> Array<List<&2, G.Nb>>:
  match s:
    case AJ{lower, upper, adj}:
      adj



def ag_fin(ag: AG, +nref: U32) -> AR:
  match ag:
    case AG{gr, memb, refined, ws, lower, upper, nw2, amemb}:
      AR{gr, memb, refined, GR{aj_adj(aj_loop(U32.to_nat(nref), 0,
          AJ{lower, upper, Array.new(List<&2, G.Nb>, G.depth(nref), Nil{})})), nw2, nref, False{}}, amemb}



def ag_cl(c2: CL2, gr: GR, memb: Array<U32>, +nref: U32) -> AR:
  match c2:
    case CL2{refined, cl}:
      ag_fin(ag_loop(U32.to_nat(nref), 0, nref, (AG{gr, memb, refined, G.u32_array(U32.mul(nref, 3), 0),
          Array.new(List<&2, G.Nb>, G.depth(nref), Nil{}), Array.new(List<&2, G.Nb>, G.depth(nref), Nil{}),
          G.u32_array(U32.shl(nref), 0), G.u32_array(nref, 0)}, cl)), nref)



def aggregate(gr: GR, memb: Array<U32>, refined: Array<U32>, +gn: U32, +nref: U32) -> AR:
  ag_cl(clusters_of(refined, gn, nref), gr, memb, nref)


# ---------------------------------------------------------------------------
# Levels (igraph_i_community_leiden) and iterations

def fp_of(+n: U32, +m2: Bool, +res: F.D) -> FP:
  FP{n, U32.sub(U32.shln(1, G.depth(n)), 1), m2, res}


def gr_n(gr: GR) -> GR & U32:
  match gr:
    case GR{adj, nw, n, m2}:
      (GR{adj, nw, n, m2}, n)


def gr_m2(gr: GR) -> GR & Bool:
  match gr:
    case GR{adj, nw, n, m2}:
      (GR{adj, nw, n, m2}, m2)


def mu_b(r: AU, memb0: Array<U32>, agg: Array<U32>, +i: U32) -> MU:
  match r:
    case AU{imemb, x}:
      MU{Array.set(U32, memb0, i, x), imemb, agg}


def mu_a(r: AU, memb0: Array<U32>, imemb: Array<U32>, +i: U32) -> MU:
  match r:
    case AU{agg, a}:
      mu_b(uget(imemb, a), memb0, agg, i)


def mu_loop(k: Nat, +i: U32, s: MU) -> MU:
  match k:
    case 0n:
      s
    case 1n+p:
      match s:
        case MU{memb0, imemb, agg}:
          mu_loop(p, U32.inc(i), mu_a(uget(agg, i), memb0, imemb, i))


def au_b(r: AU, agg: Array<U32>, +i: U32) -> AU2:
  match r:
    case AU{refined, x}:
      AU2{Array.set(U32, agg, i, x), refined}


def au_a(r: AU, refined: Array<U32>, +i: U32) -> AU2:
  match r:
    case AU{agg, a}:
      au_b(uget(refined, a), agg, i)


def au_loop(k: Nat, +i: U32, s: AU2) -> AU2:
  match k:
    case 0n:
      s
    case 1n+p:
      match s:
        case AU2{agg, refined}:
          au_loop(p, U32.inc(i), au_a(uget(agg, i), refined, i))


def pr_n0(p: PR) -> U32:
  match p:
    case PR{n0, res, beta, tab}:
      n0


def pr_res(p: PR) -> F.D:
  match p:
    case PR{n0, res, beta, tab}:
      res


def pr_beta(p: PR) -> F.D:
  match p:
    case PR{n0, res, beta, tab}:
      beta


def pr_tab(p: PR) -> F.Tab:
  match p:
    case PR{n0, res, beta, tab}:
      tab


# at level 0 "gr" is the original graph and "imemb" is memb0
def lv_next0(lvl0: Bool, g0: GR, gr: GR, imemb: Array<U32>, memb0: Array<U32>, agg: Array<U32>, refined: Array<U32>,
             ng: GR, amemb: Array<U32>, +nbc: U32, +chg: Bool, +g: RNG) -> LV:
  match lvl0:
    case True{}:
      LV{gr, ng, amemb, imemb, agg, False{}, nbc, chg, g, False{}}
    case False{}:
      LV{g0, ng, amemb, memb0, agg, False{}, nbc, chg, g, False{}}


# after aggregation: next level
def lv_next(ar: AR, g0: GR, memb0: Array<U32>, agg: Array<U32>, +lvl0: Bool, +nbc: U32, +chg: Bool, +g: RNG) -> LV:
  match ar:
    case AR{gr, imemb, refined, ng, amemb}:
      lv_next0(lvl0, g0, gr, imemb, memb0, agg, refined, ng, amemb, nbc, chg, g)


def lv_agg(s: AU2, gr: GR, imemb: Array<U32>, g0: GR, memb0: Array<U32>, +gn: U32, +nref: U32, +lvl0: Bool,
           +nbc: U32, +chg: Bool, +g: RNG) -> LV:
  match s:
    case AU2{agg, refined}:
      lv_next(aggregate(gr, imemb, refined, gn, nref), g0, memb0, agg, lvl0, nbc, chg, g)


def lv_clone(r: Array<U32> & Array<U32>, gr: GR, g0: GR, memb0: Array<U32>, agg: Array<U32>, +gn: U32, +n0: U32,
             +lvl0: Bool, +nbc: U32, +chg: Bool, +g: RNG) -> LV:
  (imemb, refined) = r
  lv_agg(au_loop(U32.to_nat(n0), 0, AU2{agg, refined}), gr, imemb, g0, memb0, gn, nbc, lvl0, nbc, chg, g)


def lv_pick(same: Bool, gr: GR, imemb: Array<U32>, refined: Array<U32>, g0: GR, memb0: Array<U32>, agg: Array<U32>,
            +gn: U32, +n0: U32, +nref: U32, +lvl0: Bool, +nbc: U32, +chg: Bool, +g: RNG) -> LV:
  match same:
    case True{}:
      lv_clone(Array.clone(U32, imemb), gr, g0, memb0, agg, gn, n0, lvl0, nbc, chg, g)
    case False{}:
      lv_agg(au_loop(U32.to_nat(n0), 0, AU2{agg, refined}), gr, imemb, g0, memb0, gn, nref, lvl0, nbc, chg, g)


def lv_refined(rf: RF, g0: GR, memb0: Array<U32>, agg: Array<U32>, +gn: U32, +n0: U32, +lvl0: Bool, +nbc: U32, +chg: Bool) -> LV:
  match rf:
    case RF{gr, imemb, refined, cl, nref, g}:
      lv_pick(U32.is_ge(nref, gn), gr, imemb, refined, g0, memb0, agg, gn, n0, nref, lvl0, nbc, chg, g)


def lv_refine(c2: CL2, gr: GR, g0: GR, memb0: Array<U32>, agg: Array<U32>, +gn: U32, +pr: PR, +lvl0: Bool,
              +nbc: U32, +chg: Bool, +g: RNG) -> LV:
  match c2:
    case CL2{imemb, cl}:
      lv_refined(rf_loop(U32.to_nat(nbc), 0, pr_res(pr), pr_beta(pr), pr_tab(pr),
          RF{gr, imemb, G.u32_array(gn, 0), cl, 0, g}), g0, memb0, agg, gn, pr_n0(pr), lvl0, nbc, chg)


# continue: update memb0 (levels > 0), refine, aggregate
def lv_cont(mu: MU, gr: GR, g0: GR, +gn: U32, +pr: PR, +lvl0: Bool, +nbc: U32, +chg: Bool, +g: RNG) -> LV:
  match mu:
    case MU{memb0, imemb, agg}:
      lv_refine(clusters_of(imemb, gn, nbc), gr, g0, memb0, agg, gn, pr, lvl0, nbc, chg, g)


def lv_stop(lvl0: Bool, g0: GR, gr: GR, imemb: Array<U32>, memb0: Array<U32>, agg: Array<U32>, +k: U32, +chg: Bool, +g: RNG) -> LV:
  match lvl0:
    case True{}:
      LV{gr, g0, Array.new(U32, 0n, 0), imemb, agg, True{}, k, chg, g, True{}}
    case False{}:
      LV{g0, gr, imemb, memb0, agg, False{}, k, chg, g, True{}}


def lv_cont_go(lvl0: Bool, g0: GR, gr: GR, imemb: Array<U32>, memb0: Array<U32>, agg: Array<U32>, +gn: U32, +pr: PR,
               +k: U32, +chg: Bool, +g: RNG) -> LV:
  match lvl0:
    case True{}:
      lv_cont(MU{memb0, imemb, agg}, gr, g0, gn, pr, True{}, k, chg, g)
    case False{}:
      lv_cont(mu_loop(U32.to_nat(pr_n0(pr)), 0, MU{memb0, imemb, agg}), gr, g0, gn, pr, False{}, k, chg, g)


def lv_after(cont: Bool, f: FMR, g0: GR, memb0: Array<U32>, agg: Array<U32>, +gn: U32, +pr: PR, +lvl0: Bool) -> LV:
  match cont:
    case False{}:
      match f:
        case FMR{gr, imemb, k, chg, g}:
          lv_stop(lvl0, g0, gr, imemb, memb0, agg, k, chg, g)
    case True{}:
      match f:
        case FMR{gr, imemb, k, chg, g}:
          lv_cont_go(lvl0, g0, gr, imemb, memb0, agg, gn, pr, k, chg, g)


def lv_fm2(f: FMR, g0: GR, memb0: Array<U32>, agg: Array<U32>, +gn: U32, +pr: PR, +lvl0: Bool) -> LV:
  match f:
    case FMR{gr, imemb, k, chg, g}:
      lv_after(U32.is_lt(k, gn), FMR{gr, imemb, k, chg, g}, g0, memb0, agg, gn, pr, lvl0)


def lv_fm(r: GR & U32, +m2: Bool, imemb: Array<U32>, g0: GR, memb0: Array<U32>, agg: Array<U32>, +pr: PR, +lvl0: Bool,
          +chg: Bool, +g: RNG) -> LV:
  (gr, +gn) = r
  lv_fm2(fastmove(gr, imemb, fp_of(gn, m2, pr_res(pr)), chg, g), g0, memb0, agg, gn, pr, lvl0)


def lv_m2(r: GR & Bool, imemb: Array<U32>, g0: GR, memb0: Array<U32>, agg: Array<U32>, +pr: PR, +lvl0: Bool, +chg: Bool, +g: RNG) -> LV:
  (gr, +m2) = r
  lv_fm(gr_n(gr), m2, imemb, g0, memb0, agg, pr, lvl0, chg, g)


# at level 0 the graph is g0 and the membership memb0
def lv_step_go(lvl0: Bool, g0: GR, gr: GR, imemb: Array<U32>, memb0: Array<U32>, agg: Array<U32>, +pr: PR, +chg: Bool, +g: RNG) -> LV:
  match lvl0:
    case True{}:
      lv_m2(gr_m2(g0), memb0, gr, imemb, agg, pr, True{}, chg, g)
    case False{}:
      lv_m2(gr_m2(gr), imemb, g0, memb0, agg, pr, False{}, chg, g)


def lv_step(s: LV, +pr: PR) -> LV:
  match s:
    case LV{g0, gr, imemb, memb0, agg, lvl0, nbc, chg, g, done}:
      lv_step_go(lvl0, g0, gr, imemb, memb0, agg, pr, chg, g)


def lv_more(s: LV) -> LV & Bool:
  match s:
    case LV{g0, gr, imemb, memb0, agg, lvl0, nbc, chg, g, done}:
      (LV{g0, gr, imemb, memb0, agg, lvl0, nbc, chg, g, done}, Bool.not(done))


def lv_loop(k: Nat, +pr: PR, r: LV & Bool) -> LV:
  match k:
    case 0n:
      (s, more) = r
      s
    case 1n+p:
      (s, more) = r
      match more:
        case False{}:
          s
        case True{}:
          lv_loop(p, pr, lv_more(lv_step(s, pr)))


def it_fin(s: LV) -> IT:
  match s:
    case LV{g0, gr, imemb, memb0, agg, lvl0, nbc, chg, g, done}:
      IT{g0, memb0, chg, g}


def it_once(r: AU, g0: GR, +pr: PR, +g: RNG) -> IT:
  match r:
    case AU{memb0, k}:
      it_fin(lv_loop(U32.to_nat(U32.add(pr_n0(pr), 4)), pr,
        (LV{g0, GR{Array.new(List<&2, G.Nb>, 0n, Nil{}), Array.new(U32, 0n, 0), 0, False{}}, Array.new(U32, 0n, 0),
            memb0, fill_id(U32.to_nat(pr_n0(pr)), 0, 0, G.u32_array(pr_n0(pr), 0)), True{}, k, False{}, g, False{}}, True{})))


def it_step(s: IT, +pr: PR) -> IT:
  match s:
    case IT{g0, memb0, chg, g}:
      it_once(reindex(memb0, pr_n0(pr)), g0, pr, g)


# n_iterations >= 0: that many; < 0: while not changed (igraph's loop test)
def it_more(neg: Bool, +left: U32, s: IT) -> IT & Bool:
  match neg:
    case True{}:
      match s:
        case IT{g0, memb0, chg, g}:
          (IT{g0, memb0, chg, g}, Bool.not(chg))
    case False{}:
      match s:
        case IT{g0, memb0, chg, g}:
          (IT{g0, memb0, chg, g}, U32.is_gt(left, 0))


def it_loop(k: Nat, +neg: Bool, +left: U32, +pr: PR, r: IT & Bool) -> IT:
  match k:
    case 0n:
      (s, more) = r
      s
    case 1n+p:
      (s, more) = r
      match more:
        case False{}:
          s
        case True{}:
          it_loop(p, neg, U32.sub(left, 1), pr, it_more(neg, U32.sub(left, 1), it_step(s, pr)))


def w_entry(w: U32 & U32, +id: U32, +rest: List<&2, G.Nb>) -> List<&2, G.Nb>:
  (h, l) = w
  G.Nb{id, h, l} <> rest


# level-0 graph: w = 1 - d per entry, every entry a pair of parallel edges
def w_list(ns: List<&2, G.Nb>) -> List<&2, G.Nb>:
  match ns:
    case Nil{}:
      Nil{}
    case Con{x, t}:
      match x:
        case G.Nb{id, dh, dl}:
          w_entry(F.sub(1072693248, 0, dh, dl), id, w_list(t))


def w_row(r: Array<List<&2, G.Nb>> & List<&2, G.Nb>, +v: U32) -> Array<List<&2, G.Nb>>:
  (rows, ns) = r
  Array.set(List<&2, G.Nb>, rows, v, w_list(ns))


def w_rows(k: Nat, +v: U32, rows: Array<List<&2, G.Nb>>) -> Array<List<&2, G.Nb>>:
  match k:
    case 0n:
      rows
    case 1n+p:
      w_rows(p, U32.inc(v), w_row(Array.swap(List<&2, G.Nb>, rows, v, Nil{}), v))


def ones(k: Nat, +i: U32, a: Array<U32>) -> Array<U32>:
  match k:
    case 0n:
      a
    case 1n+p:
      ones(p, U32.inc(i), Array.set(U32, a, U32.shl(i), 1072693248))


# max + 1 of the membership
def max_go(k: Nat, +i: U32, +mx: U32, r: AU) -> U32:
  match k:
    case 0n:
      match r:
        case AU{a, v}:
          U32.inc(U32.max(mx, v))
    case 1n+p:
      match r:
        case AU{a, v}:
          max_go(p, U32.inc(i), U32.max(mx, v), uget(a, U32.inc(i)))


def it_res2(r: Array<U32> & Array<U32>, +n: U32) -> Array<U32> & U32:
  (a, b) = r
  (a, max_go(U32.to_nat(U32.sub(n, 1)), 0, 0, uget(b, 0)))


def it_res(s: IT, +n: U32) -> Array<U32> & U32:
  match s:
    case IT{g0, memb0, chg, g}:
      it_res2(Array.clone(U32, memb0), n)


# Clusty's Leiden: (assignment over local ids, number of clusters)
def leiden(rows: Array<List<&2, G.Nb>>, +n: U32, +m: U32, +res: F.D, +beta: F.D, +iters: U32, +ineg: Bool) -> Array<U32> & U32:
  +pr = {PR{n, res, beta, F.exp_table()} : PR}
  it_res(it_loop(U32.to_nat(F.sel(ineg, 1000, U32.inc(iters))), ineg, iters, pr,
    (IT{GR{w_rows(U32.to_nat(n), 0, rows), ones(U32.to_nat(n), 0, G.u32_array(U32.shl(n), 0)), n, True{}},
        fill_id(U32.to_nat(n), 0, 0, G.u32_array(n, 0)), False{}, rng0()},
     Bool.or(ineg, U32.is_gt(iters, 0)))), n)
