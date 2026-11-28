# vclust cluster, in Bend: byte-identical to `vclust cluster` (Vclust 1.3.1,
# which runs Clusty 1.2.2 with --objects-file <ids> --algo <a>
# --id-cols qidx ridx --distance-col <metric> --similarity --numeric-ids
# --min <col> <v>... [--max num_alns n] [--out-representatives]
# [--leiden-*]).
#
# usage: cluster -i ani.tsv -o clusters.tsv --ids ani.ids.tsv [-r]
#   [--algorithm single|complete|uclust|cd-hit|set-cover|leiden]
#   [--metric tani|gani|ani] [--tani F] [--gani F] [--ani F] [--qcov F]
#   [--rcov F] [--len_ratio F] [--num_alns N] [--leiden-resolution F]
#   [--leiden-beta F] [--leiden-iterations N] [-v N] [-t N]
# (-t is accepted for symmetry with the other stages; Bend's worker count
# is the runtime's `+RTS --threads N -RTS`.)
import Base
import ./f64.bend as F
import ./cl_load.bend as L
import ./cl_graph.bend as G
import ./cl_complete.bend as C
import ./cl_leiden.bend as LD
import ./partition_certificate.bend as PC
import ./clique_certificate.bend as QC

type Opt is Data:
  Opt{+key: String, +val: String}




type PA is Data:
  PA{+rest: List<&2, String>, +opts: List<&2, Opt>, +err: String}




# ---------------------------------------------------------------------------
# configuration

type Cfg is Data:
  Cfg{+inp: String, +out: String, +ids: String, +repr: Bool, +algo: U32,
      +metric: String, +thr: List<&2, Th>, +nalns: U32, +res: F.D,
      +beta: F.D, +iters: U32, +iters_neg: Bool}




# a minimum threshold on a named column (value > 0 only)
type Th is Data:
  Th{+name: String, +v: F.D}




# signed decimal integer: (magnitude, negative, ok)
type SI is Data:
  SI{+mag: U32, +neg: Bool, +ok: Bool}




# ---------------------------------------------------------------------------
# reading files in chunks: a pure step over each chunk

type IDS is Data:
  IDS{+hdr: Bool, +infld: Bool, +cur: List<&2, U32>, +names: List<&2, List<&2, U32>>, +cnt: U32}






type MH is Data:
  MH{+err: String, +m: L.Meta}




# (cluster, global id) of the in-matrix objects
type CG is Data:
  CG{+cl: U32, +gi: U32}




# cluster sizes and the size order (Clusty's sortClustersBySize)
type SZ is Data:
  SZ{+size: U32, +id: U32}




# per global id: in-matrix (cluster, gi) list and outside gi list
type OB is Type:
  OB{g2l: Array<U32>, asg: Array<U32>, o2n: Array<U32>, +ins: List<&2, CG>, +outs: List<&2, U32>}




# output lines, accumulated in reverse byte order
type OW is Type:
  OW{names: Array<List<&2, U32>>, +acc: List<&2, U32>, +cur: U32, +rep: List<&2, U32>}




# ---------------------------------------------------------------------------
# main

type Parts is Type:
  Parts{g2l: Array<U32>, edges: List<&2, L.Edge>, +nloc: U32, +nedge: U32, +err: U32}



type VertexState is Type:
  VertexState{rows: Array<List<&2, G.Nb>>, asg: Array<U32>, vertices: List<&2, QC.Vertex>}


type GC is Type:
  GC{gs: Array<List<&2, QC.Vertex>>, +ok: Bool}




def str_pick(c: Bool, +a: String, +b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b




# 1: option with a value, 2: switch, 0: unknown
def opt_kind(ks: List<&2, String>, +a: String) -> U32:
  match ks:
    case Nil{}:
      F.sel(Bool.or(String.eq(a, "-r"), String.eq(a, "--out-repr")), 2, 0)
    case Con{+k, t}:
      F.sel(String.eq(k, a), 1, opt_kind(t, a))




def value_opts() -> List<&2, String>:
  ["-i", "--in", "-o", "--out", "--ids", "--algorithm", "--metric", "--tani",
   "--gani", "--ani", "--qcov", "--rcov", "--len_ratio", "--num_alns",
   "--leiden-resolution", "--leiden-beta", "--leiden-iterations", "-v", "-t"]




def canon(+a: String) -> String:
  str_pick(String.eq(a, "--in"), "-i", str_pick(String.eq(a, "--out"), "-o",
    str_pick(String.eq(a, "--out-repr"), "-r", a)))




def pa_value(rest: List<&2, String>, +a: String, +opts: List<&2, Opt>, +err: String) -> PA:
  match rest:
    case Nil{}:
      PA{Nil{}, opts, "argument " ++ a ++ ": expected one argument"}
    case Con{v, t}:
      PA{t, Opt{canon(a), v} <> opts, err}




def pa_kind_go(val: Bool, sw: Bool, +a: String, +t: List<&2, String>, +opts: List<&2, Opt>, +err: String) -> PA:
  match val sw:
    case True{} _:
      pa_value(t, a, opts, err)
    case False{} True{}:
      PA{t, Opt{"-r", "1"} <> opts, err}
    case False{} False{}:
      PA{Nil{}, opts, "unrecognized arguments: " ++ a}




def pa_kind(+kind: U32, +a: String, +t: List<&2, String>, +opts: List<&2, Opt>, +err: String) -> PA:
  pa_kind_go(U32.is_eq(kind, 1), U32.is_eq(kind, 2), a, t, opts, err)




def pa_step(p: PA) -> PA:
  match p:
    case PA{rest, opts, err}:
      match rest:
        case Nil{}:
          PA{Nil{}, opts, err}
        case Con{+a, t}:
          pa_kind(opt_kind(value_opts(), a), a, t, opts, err)




def pa_loop(n: Nat, p: PA) -> PA:
  match n:
    case 0n:
      p
    case 1n+k:
      pa_loop(k, pa_step(p))




# last occurrence wins (opts is in reverse order); default when absent
def opt_get(+os: List<&2, Opt>, +k: String, +dflt: String) -> String:
  match os:
    case Nil{}:
      dflt
    case Con{o, t}:
      match o:
        case Opt{key, val}:
          str_pick(String.eq(key, k), val, opt_get(t, k, dflt))




def opt_has(+os: List<&2, Opt>, +k: String) -> Bool:
  match os:
    case Nil{}:
      False{}
    case Con{o, t}:
      match o:
        case Opt{key, val}:
          Bool.or(String.eq(key, k), opt_has(t, k))




def algo_code(+a: String) -> U32:
  F.sel(String.eq(a, "single"), 0, F.sel(String.eq(a, "complete"), 1,
    F.sel(String.eq(a, "uclust"), 2, F.sel(String.eq(a, "cd-hit"), 3,
      F.sel(String.eq(a, "set-cover"), 4, F.sel(String.eq(a, "leiden"), 5, 9))))))




def d_pos(d: F.D) -> Bool:
  match d:
    case F.D{h, l}:
      F.gt(h, l, 0, 0)




def d_in01(d: F.D) -> Bool:
  match d:
    case F.D{h, l}:
      Bool.and(F.ge(h, l, 0, 0), F.le(h, l, 1072693248, 0))




def num_or(m: Maybe<&2, F.D>) -> F.D:
  match m:
    case None{}:
      F.D{2146959360, 0}
    case Some{d}:
      d




def thr_list(+os: List<&2, Opt>, names: List<&2, String>) -> List<&2, Th>:
  match names:
    case Nil{}:
      Nil{}
    case Con{+n, t}:
      Th{n, num_or(L.parse_double(opt_get(os, "--" ++ n, "0")))} <> thr_list(os, t)




def th_bad(ts: List<&2, Th>) -> String:
  match ts:
    case Nil{}:
      ""
    case Con{x, t}:
      match x:
        case Th{n, v}:
          str_pick(d_in01(v), th_bad(t), "argument --" ++ n ++ ": must be between 0 and 1")




def d_pick(c: Bool, +a: F.D, +b: F.D) -> F.D:
  match c:
    case True{}:
      a
    case False{}:
      b




def th_value(ts: List<&2, Th>, +n: String) -> F.D:
  match ts:
    case Nil{}:
      F.D{0, 0}
    case Con{x, t}:
      match x:
        case Th{k, v}:
          d_pick(String.eq(k, n), v, th_value(t, n))




def si_go(bs: List<&2, U32>, +acc: U32, +ok: Bool) -> SI:
  match bs:
    case Nil{}:
      SI{acc, False{}, ok}
    case Con{+h, t}:
      si_go(t, U32.add(U32.mul(acc, 10), U32.sub(h, 48)),
        Bool.and(ok, Bool.and(U32.is_lt(U32.sub(h, 48), 10), U32.is_lt(acc, 100000000))))




def si_flip(s: SI) -> SI:
  match s:
    case SI{m, n, ok}:
      SI{m, True{}, ok}




def si_neg(neg: Bool, +h: U32, t: List<&2, U32>) -> SI:
  match neg:
    case True{}:
      si_flip(si_go(t, 0, True{}))
    case False{}:
      si_go(h <> t, 0, True{})




def si_sign(bs: List<&2, U32>) -> SI:
  match bs:
    case Nil{}:
      SI{0, False{}, False{}}
    case Con{+h, t}:
      si_neg(U32.is_eq(h, 45), h, t)




def parse_int(+s: String) -> SI:
  si_sign(L.bytes_of(s))




def si_mag(s: SI) -> U32:
  match s:
    case SI{m, n, ok}:
      F.sel(n, 0, m)




def si_ok(s: SI) -> Bool:
  match s:
    case SI{m, n, ok}:
      ok




def si_neg_of(s: SI) -> Bool:
  match s:
    case SI{m, n, ok}:
      n




def metric_names() -> List<&2, String>:
  ["tani", "gani", "ani", "qcov", "rcov", "len_ratio"]




# error text ("" when fine) and the configuration
def config(+os: List<&2, Opt>) -> String & Cfg:
  +thr = thr_list(os, metric_names())
  +metric = opt_get(os, "--metric", "tani")
  +algo = opt_get(os, "--algorithm", "single")
  +na = parse_int(opt_get(os, "--num_alns", "0"))
  +it = parse_int(opt_get(os, "--leiden-iterations", "2"))
  +res = num_or(L.parse_double(opt_get(os, "--leiden-resolution", "0.7")))
  +beta = num_or(L.parse_double(opt_get(os, "--leiden-beta", "0.01")))
  +e1 = str_pick(Bool.and(opt_has(os, "-i"), Bool.and(opt_has(os, "-o"), opt_has(os, "--ids"))), "",
    "the following arguments are required: -i/--in, -o/--out, --ids")
  +e2 = str_pick(U32.is_eq(algo_code(algo), 9), "argument --algorithm: invalid choice: '" ++ algo ++ "'", "")
  +e3 = str_pick(Bool.or(String.eq(metric, "tani"), Bool.or(String.eq(metric, "gani"), String.eq(metric, "ani"))),
    "", "argument --metric: invalid choice: '" ++ metric ++ "'")
  +e4 = th_bad(thr)
  +e5 = str_pick(Bool.and(si_ok(na), Bool.and(si_ok(it), Bool.and(Bool.or(si_neg_of(it), U32.is_le(si_mag(it), 1000)), Bool.and(d_in01(res), Bool.and(d_in01(beta), d_pos(beta)))))), "",
    "invalid --num_alns / --leiden-* value (beta must be positive; iterations at most 1000)")
  +e6 = str_pick(d_pos(th_value(thr, metric)), "", metric ++ " threshold must be above 0. Specify the option: --" ++ metric)
  (str_pick(String.eq(e1, ""), str_pick(String.eq(e2, ""), str_pick(String.eq(e3, ""),
     str_pick(String.eq(e4, ""), str_pick(String.eq(e5, ""), e6, e5), e4), e3), e2), e1),
   Cfg{opt_get(os, "-i", ""), opt_get(os, "-o", ""), opt_get(os, "--ids", ""), opt_has(os, "-r"),
     algo_code(algo), metric, thr, si_mag(na), res, beta, si_mag(it), si_neg_of(it)})




def ids_flush(cur: List<&2, U32>, +names: List<&2, List<&2, U32>>, +cnt: U32) -> List<&2, List<&2, U32>> & U32:
  match cur:
    case Nil{}:
      (names, cnt)
    case Con{h, t}:
      (L.rev_bytes(h <> t, Nil{}) <> names, U32.inc(cnt))




def ids_cut(r: List<&2, List<&2, U32>> & U32, +infld: Bool) -> IDS:
  (names, +cnt) = r
  IDS{True{}, infld, Nil{}, names, cnt}




def ids_body(nl: Bool, sep: Bool, +h: U32, +infld: Bool, +cur: List<&2, U32>, +names: List<&2, List<&2, U32>>, +cnt: U32) -> IDS:
  match nl sep:
    case True{} _:
      ids_cut(ids_flush(cur, names, cnt), True{})
    case False{} True{}:
      ids_cut(ids_flush(cur, names, cnt), False{})
    case False{} False{}:
      match infld:
        case True{}:
          IDS{True{}, True{}, h <> cur, names, cnt}
        case False{}:
          IDS{True{}, False{}, cur, names, cnt}




def ids_byte(+h: U32, s: IDS) -> IDS:
  match s:
    case IDS{hdr, infld, cur, names, cnt}:
      match hdr:
        case False{}:
          IDS{U32.is_eq(h, 10), True{}, cur, names, cnt}
        case True{}:
          ids_body(L.is_nl(h), L.is_sep(h), h, infld, cur, names, cnt)




def ids_bytes(bs: List<&2, U32>, s: IDS) -> IDS:
  match bs:
    case Nil{}:
      s
    case Con{+h, t}:
      ids_bytes(t, ids_byte(h, s))




def ids_end(s: IDS) -> List<&2, List<&2, U32>> & U32:
  match s:
    case IDS{hdr, infld, cur, names, cnt}:
      ids_flush(cur, names, cnt)




def read_ids_res(r: File & Result<&1, &1, U32 & String, List<&2, U32>>, s: IDS, k: File -> IDS -> IO(IDS)) -> IO(IDS):
  (f, res) = r
  match res:
    case Fail{e}:
      do IO<IDS>:
        File.close(f)
        IO.die(IDS, 1, "Unable to read objects file")
    case Done{bs}:
      match bs:
        case Nil{}:
          do IO<IDS>:
            File.close(f)
            return s
        case Con{h, t}:
          k(f, ids_bytes(h <> t, s))




def read_ids_loop(n: Nat, f: File, s: IDS) -> IO(IDS):
  match n:
    case 0n:
      do IO<IDS>:
        File.close(f)
        return s
    case 1n+p:
      do IO<IDS>:
        r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 1048576)
        read_ids_res(r, s, g => s2 => read_ids_loop(p, g, s2))




def chunk_fuel() -> Nat:
  U32.to_nat(1000000)




# The table: header in the first chunk; the rest is read in batches of
# chunks that are parsed in parallel (fork-join). A chunk's bytes up to its
# first newline (head) and after its last one (tail) belong to lines shared
# with its neighbours: they are joined and parsed in order between the
# chunks' bodies. After a newline the row parser is back in its initial
# per-line state, so every body parses from a fresh state; accepted rows
# keep global ids, mapped to local ids afterwards in file order
# (L.map_edges), so the result equals the sequential parse.

# accepted rows of a stretch of lines (reversed), their count, error bits
type Grp is Data:
  Grp{edges: List<&2, L.Edge>, +nedge: U32, +err: U32}

type CRes is Data:
  CRes{+hasnl: Bool, head: List<&2, U32>, tail: List<&2, U32>, +body: Grp}

def ps_grp(ps: L.PS) -> Grp:
  match ps:
    case L.PS{m, g2l, edges, l2g, nloc, nedge, err, col, num, k, mode, iv, bad, nch, q, r, nd, kd, dbad, rej}:
      Grp{edges, nedge, err}

def ps_fresh(+m: L.Meta) -> L.PS:
  L.ps_new(m, G.u32_array(1, 0))

# one complete line (without its newline)
def line_grp(bs: List<&2, U32>, +m: L.Meta) -> Grp:
  ps_grp(L.ps_newline(L.ps_bytes(bs, ps_fresh(m))))

# number of bytes up to and including the last newline
def last_nl(bs: List<&2, U32>, +i: U32, +at: U32) -> U32:
  match bs:
    case Nil{}:
      at
    case Con{+h, t}:
      +j = U32.inc(i)
      last_nl(t, j, F.sel(L.is_nl(h), j, at))

def drop_n(n: Nat, bs: List<&2, U32>) -> List<&2, U32>:
  match n bs:
    case 0n _:
      bs
    case _ Nil{}:
      Nil{}
    case 1n+p Con{h, t}:
      drop_n(p, t)

def chunk_body(+hasnl: Bool, +head: List<&2, U32>, +rest: List<&2, U32>, +m: L.Meta) -> CRes:
  CRes{hasnl, head, drop_n(U32.to_nat(last_nl(rest, 0, 0)), rest), ps_grp(L.ps_bytes(rest, ps_fresh(m)))}

def chunk_cut(c: L.Cut & List<&2, U32>, +m: L.Meta) -> CRes:
  (cut, +rest) = c
  match cut:
    case L.Cut{+line, +done}:
      chunk_body(done, L.rev_bytes(line, Nil{}), rest, m)

def chunk_task(bs: List<&2, U32>, +m: L.Meta) -> CRes:
  chunk_cut(L.cut_line(bs, L.Cut{Nil{}, False{}}), m)

type CT is Type:
  CTNil{}
  CTLeaf{bs: List<&2, U32>}
  CTNode{l: CT, r: CT}

type CO is Type:
  CONil{}
  COLeaf{+r: CRes}
  CONode{l: CO, r: CO}

def ct_apply(-A: Type, -B: Type, body: A -> B, value: A) -> B:
  body(value)

# the first 2^d chunks of xs as a tree, and the rest
def ct_tree(+d: Nat, xs: List<&2, List<&2, U32>>) -> CT & List<&2, List<&2, U32>>:
  match d:
    case 0n:
      match xs:
        case Nil{}:
          (CTNil{}, Nil{})
        case Con{h, t}:
          (CTLeaf{h}, t)
    case 1n+p:
      ct_apply(CT & List<&2, List<&2, U32>>, CT & List<&2, List<&2, U32>>, \{Tuple: l => rest => (
        ct_apply(CT & List<&2, List<&2, U32>>, CT & List<&2, List<&2, U32>>, \{Tuple: r => rest2 => (
          (CTNode{l, r}, rest2)
        )}, ct_tree(p, rest))
      )}, ct_tree(p, xs))

def co_join(a: CO, b: CO) -> CO:
  CONode{a, b}

def par_chunks(ct: CT, +m: L.Meta) -> CO:
  match ct:
    case CTNil{}:
      CONil{}
    case CTLeaf{bs}:
      COLeaf{chunk_task(bs, m)}
    case CTNode{l, r}:
      a b = par_chunks(l, m) par_chunks(r, m)
      co_join(a, b)

# carry: bytes of the open line (in order); groups in reverse file order
type TA is Data:
  TA{carry: List<&2, U32>, groups: List<&2, Grp>}

def bytes_app(a: List<&2, U32>, b: List<&2, U32>) -> List<&2, U32>:
  match a:
    case Nil{}:
      b
    case Con{+h, t}:
      h <> bytes_app(t, b)

def ta_nl(hasnl: Bool, +head: List<&2, U32>, +tail: List<&2, U32>, +body: Grp, +m: L.Meta, ta: TA) -> TA:
  match hasnl ta:
    case True{} TA{carry, groups}:
      TA{tail, body <> (line_grp(bytes_app(carry, head), m) <> groups)}
    case False{} TA{carry, groups}:
      TA{bytes_app(carry, head), groups}

def ta_add(+r: CRes, +m: L.Meta, ta: TA) -> TA:
  match r:
    case CRes{+hasnl, +head, +tail, +body}:
      ta_nl(hasnl, head, tail, body, m, ta)

def co_fold(co: CO, +m: L.Meta, ta: TA) -> TA:
  match co:
    case CONil{}:
      ta
    case COLeaf{+r}:
      ta_add(r, m, ta)
    case CONode{l, r}:
      co_fold(r, m, co_fold(l, m, ta))

def chunks_rev(xs: List<&2, List<&2, U32>>, acc: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      chunks_rev(t, h <> acc)

def batch_tree(r: CT & List<&2, List<&2, U32>>, +m: L.Meta, ta: TA) -> TA:
  (ct, rest) = r
  co_fold(par_chunks(ct, m), m, ta)

# chunks in reverse order (at most 32)
def ta_batch(cs: List<&2, List<&2, U32>>, +m: L.Meta, ta: TA) -> TA:
  batch_tree(ct_tree(5n, chunks_rev(cs, Nil{})), m, ta)

type RB is Type:
  RB{f: File, cs: List<&2, List<&2, U32>>, +eof: Bool}

def rb_res(r: File & Result<&1, &1, U32 & String, List<&2, U32>>, cs: List<&2, List<&2, U32>>,
           k: File -> List<&2, List<&2, U32>> -> IO(RB)) -> IO(RB):
  (f, res) = r
  match res:
    case Fail{e}:
      do IO<RB>:
        File.close(f)
        IO.die(RB, 1, "Unable to read distance file")
    case Done{bs}:
      match bs:
        case Nil{}:
          IO.pure(RB, RB{f, cs, True{}})
        case Con{h, t}:
          k(f, (h <> t) <> cs)

def rb_loop(n: Nat, f: File, cs: List<&2, List<&2, U32>>) -> IO(RB):
  match n:
    case 0n:
      IO.pure(RB, RB{f, cs, False{}})
    case 1n+p:
      do IO<RB>:
        r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 524288)
        rb_res(r, cs, g => c2 => rb_loop(p, g, c2))

def tab_res(b: RB, +m: L.Meta, ta: TA, k: File -> TA -> IO(TA)) -> IO(TA):
  match b:
    case RB{f, cs, eof}:
      match eof:
        case True{}:
          do IO<TA>:
            File.close(f)
            return ta_batch(cs, m, ta)
        case False{}:
          k(f, ta_batch(cs, m, ta))

def tab_loop(n: Nat, f: File, +m: L.Meta, first: List<&2, List<&2, U32>>, ta: TA) -> IO(TA):
  match n:
    case 0n:
      do IO<TA>:
        File.close(f)
        return ta
    case 1n+p:
      do IO<TA>:
        b : RB <- rb_loop(24n, f, first)
        tab_res(b, m, ta, g => t2 => tab_loop(p, g, m, Nil{}, t2))

type PM is Type:
  PM{ms: L.MS, +nedge: U32, +err: U32}

def pm_grp(+g: Grp, pm: PM) -> PM:
  match g pm:
    case Grp{+es, +ne, +er} PM{ms, +nedge, +err}:
      PM{L.map_edges(L.edges_rev(es, Nil{}), ms), U32.add(nedge, ne), U32.or(err, er)}

def pm_go(gs: List<&2, Grp>, pm: PM) -> PM:
  match gs:
    case Nil{}:
      pm
    case Con{+g, t}:
      pm_go(t, pm_grp(g, pm))

def grps_rev(xs: List<&2, Grp>, acc: List<&2, Grp>) -> List<&2, Grp>:
  match xs:
    case Nil{}:
      acc
    case Con{+h, t}:
      grps_rev(t, h <> acc)

def pm_parts(pm: PM) -> Parts:
  match pm:
    case PM{ms, nedge, err}:
      match ms:
        case L.MS{g2l, edges, l2g, nloc}:
          Parts{g2l, edges, nloc, nedge, err}

# the last open line, then every group in file order through the id map
def ta_parts(+m: L.Meta, +cap: U32, ta: TA) -> Parts:
  match ta:
    case TA{+carry, +groups}:
      pm_parts(pm_go(grps_rev(line_grp(carry, m) <> groups, Nil{}),
        PM{L.MS{G.u32_array(cap, L.none()), Nil{}, Nil{}, 0}, 0, 0}))

def filt_add(on: Bool, +c: U32, +v: F.D, +rest: List<&2, L.Filt>) -> List<&2, L.Filt>:
  match on:
    case True{}:
      L.Filt{c, v, F.D{0, 0}, True{}, False{}} <> rest
    case False{}:
      rest




# ---------------------------------------------------------------------------
# header -> Meta (+ an error text)

def filt_of(ts: List<&2, Th>, +cols: List<&2, List<&2, U32>>) -> List<&2, L.Filt>:
  match ts:
    case Nil{}:
      Nil{}
    case Con{x, t}:
      match x:
        case Th{n, v}:
          filt_add(d_pos(v), L.find_col(cols, L.bytes_of(n), 0), v, filt_of(t, cols))




def filt_missing(fs: List<&2, L.Filt>) -> Bool:
  match fs:
    case Nil{}:
      False{}
    case Con{f, t}:
      Bool.or(U32.is_eq(L.filt_col(f), L.none()), filt_missing(t))




def u32_to_d(+n: U32) -> F.D:
  F.d_of(F.from_u32(n))




def nalns_go(on: Bool, +n: U32, +c: U32, +rest: List<&2, L.Filt>) -> List<&2, L.Filt>:
  match on:
    case True{}:
      L.Filt{c, F.D{0, 0}, u32_to_d(n), False{}, True{}} <> rest
    case False{}:
      rest




def nalns_filt(+n: U32, +c: U32, +rest: List<&2, L.Filt>) -> List<&2, L.Filt>:
  nalns_go(U32.is_gt(n, 0), n, c, rest)




def meta_of(+cols: List<&2, List<&2, U32>>, cfg: Cfg, +cap: U32) -> MH:
  match cfg:
    case Cfg{inp, out, ids, repr, algo, metric, thr, nalns, res, beta, iters, ineg}:
      +q0 = L.find_col(cols, L.bytes_of("qidx"), 0)
      +r0 = L.find_col(cols, L.bytes_of("ridx"), 0)
      +dc = L.find_col(cols, L.bytes_of(metric), 0)
      +fs = nalns_filt(nalns, L.find_col(cols, L.bytes_of("num_alns"), 0), filt_of(thr, cols))
      +nc = L.ncols(cols)
      MH{str_pick(Bool.or(U32.is_eq(q0, L.none()), U32.is_eq(r0, L.none())), "missing columns `qidx` and `ridx`",
           str_pick(filt_missing(fs), "missing a filtered column in the input table",
             str_pick(U32.is_eq(dc, L.none()), "Error loading distances: " ++ metric ++ " column not found",
               str_pick(U32.is_lt(nc, 3), "Error loading distances: at least three columns are required",
                 str_pick(U32.is_gt(nc, 32), "more than 32 columns are not supported", ""))))),
        L.Meta{nc, U32.min(q0, r0), U32.max(q0, r0), dc, L.col_mask(fs), cap,
          L.cut_tree(10n, 0, 1024, fs)}}




# ---------------------------------------------------------------------------
# output

def cat_bytes(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      cat_bytes(t, h <> acc)




def rev_u32(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      rev_u32(t, h <> acc)




def write_close(r: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (f, res) = r
  match res:
    case Fail{e}:
      do IO<Unit>:
        File.close(f)
        IO.die(Unit, 1, "Unable to write the output file")
    case Done{u}:
      File.close(f)




def write_out(+path: String, bytes: List<&2, U32>) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open(path, "w"))
    r : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(f, bytes)
    write_close(r)




# names array from the reversed name list
def names_fill(xs: List<&2, List<&2, U32>>, +i: U32, a: Array<List<&2, U32>>) -> Array<List<&2, U32>>:
  match xs:
    case Nil{}:
      a
    case Con{x, t}:
      names_fill(t, U32.sub(i, 1), Array.set(List<&2, U32>, a, i, x))




def header_bytes() -> List<&2, U32>:
  L.bytes_of("object\tcluster\n")




# Rendering (Clusty's output order)
# =================================
#
# Clusters are renumbered by decreasing size, ties by old id (a stable
# counting sort on the key nloc - size); in-matrix objects are listed by
# (new cluster, ids position) (a counting sort by new cluster over the ids
# positions in ascending order); then the objects absent from the graph as
# singletons in ids order. The text is built from the last line backwards,
# so the byte list comes out in order.

def a_get(a: Array<U32>, +i: U32) -> Array<U32> & U32:
  Array.get(U32, a, i)

# sizes[c] = members of old cluster c
type CZ is Type:
  CZ{asg: Array<U32>, sz: Array<U32>, +i: U32}

def cz_c(asg: Array<U32>, +i: U32, +c: U32, r: Array<U32> & U32) -> CZ:
  (sz, +v) = r
  CZ{asg, Array.set(U32, sz, c, U32.inc(v)), U32.inc(i)}

def cz_r(sz: Array<U32>, +i: U32, r: Array<U32> & U32) -> CZ:
  (asg, +c) = r
  cz_c(asg, i, c, a_get(sz, c))

def cz_go(n: Nat, st: CZ) -> CZ:
  match n st:
    case 0n _:
      st
    case 1n+p CZ{asg, sz, +i}:
      cz_go(p, cz_r(sz, i, a_get(asg, i)))

# kc[k + 1] += 1 for key k = nloc - size of every cluster
type KC is Type:
  KC{sz: Array<U32>, kc: Array<U32>, +i: U32}

def kc_w(sz: Array<U32>, +i: U32, +k: U32, r: Array<U32> & U32) -> KC:
  (kc, +x) = r
  KC{sz, Array.set(U32, kc, k, U32.inc(x)), U32.inc(i)}

def kc_v(kc: Array<U32>, +i: U32, +nloc: U32, r: Array<U32> & U32) -> KC:
  (sz, +v) = r
  +k = U32.inc(U32.sub(nloc, v))
  kc_w(sz, i, k, a_get(kc, k))

def kc_go(n: Nat, +nloc: U32, st: KC) -> KC:
  match n st:
    case 0n _:
      st
    case 1n+p KC{sz, kc, +i}:
      kc_go(p, nloc, kc_v(kc, i, nloc, a_get(sz, i)))

# exclusive prefix sums in place over [0, n): a[i] = a[0] + .. + a[i-1] of
# the input shifted by one (the counts sit at k + 1)
type PX is Type:
  PX{a: Array<U32>, +i: U32, +acc: U32}

def px_r(+i: U32, +acc: U32, r: Array<U32> & U32) -> PX:
  (a, +v) = r
  +s2 = U32.add(acc, v)
  PX{Array.set(U32, a, i, s2), U32.inc(i), s2}

def px_go(n: Nat, st: PX) -> PX:
  match n st:
    case 0n _:
      st
    case 1n+p PX{a, +i, +acc}:
      px_go(p, px_r(i, acc, a_get(a, i)))

def px_arr(st: PX) -> Array<U32>:
  match st:
    case PX{a, i, acc}:
      a

def prefix_incl(+n: U32, a: Array<U32>) -> Array<U32>:
  px_arr(px_go(U32.to_nat(n), PX{a, 0, 0}))

# o2n[c] = kc[k]++ ; nsz[o2n[c]] = size
type ON is Type:
  ON{sz: Array<U32>, kc: Array<U32>, o2n: Array<U32>, nsz: Array<U32>, +i: U32}

def on_p(sz: Array<U32>, o2n: Array<U32>, nsz: Array<U32>, +i: U32, +k: U32, +v: U32, r: Array<U32> & U32) -> ON:
  (kc, +pos) = r
  ON{sz, Array.set(U32, kc, k, U32.inc(pos)), Array.set(U32, o2n, i, pos), Array.set(U32, nsz, pos, v), U32.inc(i)}

def on_v(kc: Array<U32>, o2n: Array<U32>, nsz: Array<U32>, +i: U32, +nloc: U32, r: Array<U32> & U32) -> ON:
  (sz, +v) = r
  +k = U32.sub(nloc, v)
  on_p(sz, o2n, nsz, i, k, v, a_get(kc, k))

def on_go(n: Nat, +nloc: U32, st: ON) -> ON:
  match n st:
    case 0n _:
      st
    case 1n+p ON{sz, kc, o2n, nsz, +i}:
      on_go(p, nloc, on_v(kc, o2n, nsz, i, nloc, a_get(sz, i)))

# placement of the in-matrix objects; outs = absent ones, descending
type PL is Type:
  PL{g2l: Array<U32>, asg: Array<U32>, o2n: Array<U32>, st: Array<U32>, order: Array<U32>, cl: Array<U32>,
     repg: Array<U32>, +outs: List<&2, U32>, +gi: U32}

def pl_rep(g2l: Array<U32>, asg: Array<U32>, o2n: Array<U32>, st: Array<U32>, order: Array<U32>, cl: Array<U32>,
           +outs: List<&2, U32>, +gi: U32, +c: U32, r: Array<U32> & U32) -> PL:
  (repg, +rp) = r
  PL{g2l, asg, o2n, st, order, cl, Array.set(U32, repg, c, F.sel(U32.is_eq(rp, L.none()), gi, rp)), outs, U32.inc(gi)}

def pl_pos(g2l: Array<U32>, asg: Array<U32>, o2n: Array<U32>, order: Array<U32>, cl: Array<U32>, repg: Array<U32>,
           +outs: List<&2, U32>, +gi: U32, +c: U32, r: Array<U32> & U32) -> PL:
  (st, +pos) = r
  pl_rep(g2l, asg, o2n, Array.set(U32, st, c, U32.inc(pos)), Array.set(U32, order, pos, gi), Array.set(U32, cl, pos, c),
    outs, gi, c, a_get(repg, c))

def pl_c(g2l: Array<U32>, asg: Array<U32>, st: Array<U32>, order: Array<U32>, cl: Array<U32>, repg: Array<U32>,
         +outs: List<&2, U32>, +gi: U32, r: Array<U32> & U32) -> PL:
  (o2n, +c) = r
  pl_pos(g2l, asg, o2n, order, cl, repg, outs, gi, c, a_get(st, c))

def pl_a(g2l: Array<U32>, o2n: Array<U32>, st: Array<U32>, order: Array<U32>, cl: Array<U32>, repg: Array<U32>,
         +outs: List<&2, U32>, +gi: U32, r: Array<U32> & U32) -> PL:
  (asg, +a) = r
  pl_c(g2l, asg, st, order, cl, repg, outs, gi, a_get(o2n, a))

def pl_in(out: Bool, +l: U32, g2l: Array<U32>, asg: Array<U32>, o2n: Array<U32>, st: Array<U32>, order: Array<U32>,
          cl: Array<U32>, repg: Array<U32>, +outs: List<&2, U32>, +gi: U32) -> PL:
  match out:
    case True{}:
      PL{g2l, asg, o2n, st, order, cl, repg, gi <> outs, U32.inc(gi)}
    case False{}:
      pl_a(g2l, o2n, st, order, cl, repg, outs, gi, a_get(asg, l))

def pl_l(asg: Array<U32>, o2n: Array<U32>, st: Array<U32>, order: Array<U32>, cl: Array<U32>, repg: Array<U32>,
         +outs: List<&2, U32>, +gi: U32, r: Array<U32> & U32) -> PL:
  (g2l, +l) = r
  pl_in(U32.is_eq(l, L.none()), l, g2l, asg, o2n, st, order, cl, repg, outs, gi)

def pl_go(n: Nat, s: PL) -> PL:
  match n s:
    case 0n _:
      s
    case 1n+p PL{g2l, asg, o2n, st, order, cl, repg, +outs, +gi}:
      pl_go(p, pl_l(asg, o2n, st, order, cl, repg, outs, gi, a_get(g2l, gi)))

# output text
def app_bytes(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      ys
    case Con{+h, t}:
      h <> app_bytes(t, ys)

def dig_go(n: Nat, +v: U32, xs: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      xs
    case 1n+p:
      dig_go(p, U32.div(v, 10), U32.add(U32.mod(v, 10), 48) <> xs)

def ndig(+v: U32) -> U32:
  U32.add(1, U32.add(F.b2u(U32.is_ge(v, 10)), U32.add(F.b2u(U32.is_ge(v, 100)), U32.add(F.b2u(U32.is_ge(v, 1000)),
    U32.add(F.b2u(U32.is_ge(v, 10000)), U32.add(F.b2u(U32.is_ge(v, 100000)), U32.add(F.b2u(U32.is_ge(v, 1000000)),
    U32.add(F.b2u(U32.is_ge(v, 10000000)), U32.add(F.b2u(U32.is_ge(v, 100000000)), F.b2u(U32.is_ge(v, 1000000000)))))))))))

def num_bytes(+v: U32, xs: List<&2, U32>) -> List<&2, U32>:
  dig_go(U32.to_nat(ndig(v)), v, xs)

def name_of(names: Array<List<&2, U32>>, +gi: U32) -> Array<List<&2, U32>> & List<&2, U32>:
  Array.get(List<&2, U32>, names, gi)

type NA is Type:
  NA{names: Array<List<&2, U32>>, +acc: List<&2, U32>}

def na_line(+nm: List<&2, U32>, +second: List<&2, U32>, names: Array<List<&2, U32>>) -> NA:
  NA{names, app_bytes(nm, 9 <> second)}

def apply_na(r: Array<List<&2, U32>> & List<&2, U32>, +second: List<&2, U32>) -> NA:
  (names, +nm) = r
  na_line(nm, second, names)

def na_rep(+gi: U32, r: Array<List<&2, U32>> & List<&2, U32>, +acc: List<&2, U32>) -> NA:
  (names, +rn) = r
  apply_na(name_of(names, gi), app_bytes(rn, 10 <> acc))

# the line of object gi in cluster c (representative rg) before acc
def na_obj(repr: Bool, names: Array<List<&2, U32>>, +gi: U32, +c: U32, +rg: U32, +acc: List<&2, U32>) -> NA:
  match repr:
    case True{}:
      na_rep(gi, name_of(names, rg), acc)
    case False{}:
      apply_na(name_of(names, gi), num_bytes(c, 10 <> acc))

type OS is Type:
  OS{order: Array<U32>, cl: Array<U32>, repg: Array<U32>, names: Array<List<&2, U32>>, +acc: List<&2, U32>, +i: U32}

def os_fin(order: Array<U32>, cl: Array<U32>, repg: Array<U32>, +i: U32, na: NA) -> OS:
  match na:
    case NA{names, +acc}:
      OS{order, cl, repg, names, acc, i}

def os_r(order: Array<U32>, cl: Array<U32>, names: Array<List<&2, U32>>, +acc: List<&2, U32>, +i: U32, +repr: Bool,
         +gi: U32, +c: U32, r: Array<U32> & U32) -> OS:
  (repg, +rg) = r
  os_fin(order, cl, repg, i, na_obj(repr, names, gi, c, rg, acc))

def os_c(order: Array<U32>, repg: Array<U32>, names: Array<List<&2, U32>>, +acc: List<&2, U32>, +i: U32, +repr: Bool,
         +gi: U32, r: Array<U32> & U32) -> OS:
  (cl, +c) = r
  os_r(order, cl, names, acc, i, repr, gi, c, a_get(repg, c))

def os_hole(hole: Bool, order: Array<U32>, cl: Array<U32>, repg: Array<U32>, names: Array<List<&2, U32>>,
            +acc: List<&2, U32>, +i: U32, +repr: Bool, +gi: U32) -> OS:
  match hole:
    case True{}:
      OS{order, cl, repg, names, acc, i}
    case False{}:
      os_c(order, repg, names, acc, i, repr, gi, a_get(cl, i))

# a position stays empty only for a local id outside the ids file
def os_g(cl: Array<U32>, repg: Array<U32>, names: Array<List<&2, U32>>, +acc: List<&2, U32>, +i: U32, +repr: Bool,
         r: Array<U32> & U32) -> OS:
  (order, +gi) = r
  os_hole(U32.is_eq(gi, L.none()), order, cl, repg, names, acc, i, repr, gi)

# positions i-1 .. 0
def os_go(n: Nat, +repr: Bool, s: OS) -> OS:
  match n s:
    case 0n _:
      s
    case 1n+p OS{order, cl, repg, names, +acc, +i}:
      +j = U32.sub(i, 1)
      os_go(p, repr, os_g(cl, repg, names, acc, j, repr, a_get(order, j)))

# the absent objects (descending ids), clusters c-1, c-2, ..
def outs_go(xs: List<&2, U32>, +repr: Bool, +c: U32, na: NA) -> NA:
  match xs na:
    case Nil{} _:
      na
    case Con{+gi, t} NA{names, +acc}:
      +c1 = U32.sub(c, 1)
      outs_go(t, repr, c1, na_obj(repr, names, gi, c1, gi, acc))

def os_names(s: OS) -> List<&2, U32>:
  match s:
    case OS{order, cl, repg, names, +acc, i}:
      acc

def len_u32(xs: List<&2, U32>, +n: U32) -> U32:
  match xs:
    case Nil{}:
      n
    case Con{h, t}:
      len_u32(t, U32.inc(n))

def os_after(na: NA, order: Array<U32>, cl: Array<U32>, repg: Array<U32>, +nloc: U32, +repr: Bool) -> List<&2, U32>:
  match na:
    case NA{names, +acc}:
      app_bytes(header_bytes(), os_names(os_go(U32.to_nat(nloc), repr, OS{order, cl, repg, names, acc, nloc})))

def os_start(pl: PL, names: Array<List<&2, U32>>, +ncl: U32, +nloc: U32, +repr: Bool) -> List<&2, U32>:
  match pl:
    case PL{g2l, asg, o2n, st, order, cl, repg, +outs, +gi}:
      os_after(outs_go(outs, repr, U32.add(ncl, len_u32(outs, 0)), NA{names, Nil{}}), order, cl, repg, nloc, repr)

type SH is Type:
  SH{a: Array<U32>, b: Array<U32>, +i: U32}

def sh_r(b: Array<U32>, +i: U32, r: Array<U32> & U32) -> SH:
  (a, +v) = r
  SH{a, Array.set(U32, b, U32.inc(i), v), U32.inc(i)}

def sh_go(n: Nat, s: SH) -> SH:
  match n s:
    case 0n _:
      s
    case 1n+p SH{a, b, +i}:
      sh_go(p, sh_r(b, i, a_get(a, i)))

def sh_b(s: SH) -> Array<U32>:
  match s:
    case SH{a, b, i}:
      b

def shift_excl(+n: U32, a: Array<U32>) -> Array<U32>:
  prefix_incl(n, sh_b(sh_go(U32.to_nat(n), SH{a, G.u32_array(U32.inc(n), 0), 0})))

def render_pl(on: ON, g2l: Array<U32>, asg: Array<U32>, names: Array<List<&2, U32>>, +ncl: U32, +nloc: U32,
              +nnames: U32, +repr: Bool) -> List<&2, U32>:
  match on:
    case ON{sz, kc, o2n, nsz, i}:
      os_start(pl_go(U32.to_nat(nnames), PL{g2l, asg, o2n, shift_excl(ncl, nsz), G.u32_array(nloc, L.none()),
          G.u32_array(nloc, 0), G.u32_array(ncl, L.none()), Nil{}, 0}),
        names, ncl, nloc, repr)

# exclusive prefix of a[0..n): via the inclusive prefix of the counts
# shifted by one slot
def render_kc(kc: KC, g2l: Array<U32>, asg: Array<U32>, names: Array<List<&2, U32>>, +ncl: U32, +nloc: U32,
              +nnames: U32, +repr: Bool) -> List<&2, U32>:
  match kc:
    case KC{sz, kc, i}:
      render_pl(on_go(U32.to_nat(ncl), nloc, ON{sz, prefix_incl(U32.add(nloc, 2), kc), G.u32_array(ncl, 0),
          G.u32_array(ncl, 0), 0}), g2l, asg, names, ncl, nloc, nnames, repr)

def render_cz(cz: CZ, g2l: Array<U32>, names: Array<List<&2, U32>>, +ncl: U32, +nloc: U32, +nnames: U32,
              +repr: Bool) -> List<&2, U32>:
  match cz:
    case CZ{asg, sz, i}:
      render_kc(kc_go(U32.to_nat(ncl), nloc, KC{sz, G.u32_array(U32.add(nloc, 2), 0), 0}), g2l, asg, names, ncl,
        nloc, nnames, repr)

# assignment over local ids (n of them) with ncl clusters -> output bytes
def render(asg: Array<U32>, +ncl: U32, +nloc: U32, g2l: Array<U32>, names: Array<List<&2, U32>>, +nnames: U32, +repr: Bool) -> List<&2, U32>:
  render_cz(cz_go(U32.to_nat(nloc), CZ{asg, G.u32_array(ncl, 0), 0}), g2l, names, ncl, nloc, nnames, repr)


# ---------------------------------------------------------------------------
# clustering dispatch: (assignment over local ids, number of clusters)

def st_res(st: G.St) -> Array<U32> & U32:
  match st:
    case G.St{rows, asg, cid}:
      (asg, cid)




def sc_go(r: Array<List<&2, G.Nb>> & List<&2, U32>, +n: U32) -> Array<U32> & U32:
  (rows, objs) = r
  st_res(G.greedy(objs, G.St{rows, G.u32_array(n, L.none()), 0}))




def run_algo_go(a0: Bool, a1: Bool, a2: Bool, a3: Bool, a4: Bool, rows: Array<List<&2, G.Nb>>, +n: U32, +m: U32,
                +objs: List<&2, U32>, cfg: Cfg) -> Array<U32> & U32:
  match a0 a1 a2 a3 a4:
    case True{} _ _ _ _:
      st_res(G.single(objs, U32.to_nat(U32.add(U32.add(m, n), 2)), G.St{rows, G.u32_array(n, L.none()), 0}))
    case False{} True{} _ _ _:
      C.complete(rows, n, m)
    case False{} False{} True{} _ _:
      st_res(G.us_st(G.uclust(objs, G.US{rows, G.u32_array(n, L.none()), G.u32_array(n, L.none()), 0})))
    case False{} False{} False{} True{} _:
      st_res(G.greedy(objs, G.St{rows, G.u32_array(n, L.none()), 0}))
    case False{} False{} False{} False{} True{}:
      sc_go(G.by_degree(G.dego_list(objs, G.DL{rows, Nil{}, 0})), n)
    case False{} False{} False{} False{} False{}:
      match cfg:
        case Cfg{inp, out, ids, repr, algo, metric, thr, nalns, res, beta, iters, ineg}:
          LD.leiden(rows, n, m, res, beta, iters, ineg)




def run_algo(+algo: U32, rows: Array<List<&2, G.Nb>>, +n: U32, +m: U32, +objs: List<&2, U32>, cfg: Cfg) -> Array<U32> & U32:
  run_algo_go(U32.is_eq(algo, 0), U32.is_eq(algo, 1), U32.is_eq(algo, 2), U32.is_eq(algo, 3),
    U32.is_eq(algo, 4), rows, n, m, objs, cfg)



def ps_parts(ps: L.PS) -> Parts:
  match ps:
    case L.PS{m, g2l, edges, l2g, nloc, nedge, err, col, num, k, mode, iv, bad, nch, q, r, nd, kd, dbad, rej}:
      Parts{g2l, edges, nloc, nedge, err}




def err_text(+e: U32) -> String:
  str_pick(U32.is_ne(U32.and(e, 2), 0), "Ill-formatted input table",
    str_pick(U32.is_ne(U32.and(e, 4), 0), "sequence index outside the ids file",
      "unsupported number format in a filtered or metric column (expected non-negative decimals, at most 9 digits, at most 15 decimals, no exponent)"))




def needs_dist(+a: U32) -> Bool:
  Bool.or(U32.is_eq(a, 1), Bool.or(U32.is_eq(a, 2), U32.is_eq(a, 5)))




def pair_bind(-A: Type, -B: Type, -R: Type, p: A & B, k: A -> B -> R) -> R:
  (a, b) = p
  k(a)(b)



def labels_collect(fuel: Nat, asg: Array<U32>, +i: U32, acc: List<&2, U32>) -> Array<U32> & List<&2, U32>:
  match fuel:
    case 0n: (asg, G.rev_u32(acc, Nil{}))
    case 1n+p:
      pair_bind(Array<U32>, U32, Array<U32> & List<&2, U32>, Array.get(U32, asg, i), asg => value =>
        labels_collect(p, asg, U32.inc(i), value <> acc))



def certified_emit(-labels: List<&2, U32>, +ncl: U32, +nloc: U32,
    certificate: Maybe<&2, PC.Certified<U32.to_nat(nloc), ncl, labels>>, asg: Array<U32>,
    g2l: Array<U32>, names: Array<List<&2, U32>>, +nnames: U32, +repr: Bool) -> Result<&1, &1, String, List<&2, U32>>:
  match certificate:
    case None{}:
      Fail{"partition certificate rejected: missing, extra, or out-of-range cluster assignment"}
    case Some{proof}:
      Done{render(asg, ncl, nloc, g2l, names, nnames, repr)}



def certify_labels(r: Array<U32> & List<&2, U32>, +ncl: U32, +nloc: U32,
    g2l: Array<U32>, names: Array<List<&2, U32>>, +nnames: U32, +repr: Bool) -> Result<&1, &1, String, List<&2, U32>>:
  (asg, +labels) = r
  certified_emit(labels, ncl, nloc, PC.certify(U32.to_nat(nloc), ncl, labels), asg, g2l, names, nnames, repr)



def neighbor_ids(xs: List<&2, G.Nb>) -> List<&2, U32>:
  match xs:
    case Nil{}: Nil{}
    case Con{G.Nb{id, h, l}, rest}: id <> neighbor_ids(rest)



def reverse_vertices(xs: List<&2, QC.Vertex>, acc: List<&2, QC.Vertex>) -> List<&2, QC.Vertex>:
  match xs:
    case Nil{}: acc
    case Con{v, rest}: reverse_vertices(rest, v <> acc)



def collect_vertices(fuel: Nat, s: VertexState, +i: U32) -> Array<U32> & List<&2, QC.Vertex>:
  match fuel s:
    case 0n VertexState{rows, asg, vertices}: (asg, reverse_vertices(vertices, Nil{}))
    case 1n+p VertexState{rows, asg, vertices}:
      pair_bind(Array<List<&2, G.Nb>>, List<&2, G.Nb>, Array<U32> & List<&2, QC.Vertex>,
        Array.get(List<&2, G.Nb>, rows, i), rows => ns =>
      pair_bind(Array<U32>, U32, Array<U32> & List<&2, QC.Vertex>, Array.get(U32, asg, i), asg => label =>
        collect_vertices(p, VertexState{rows, asg, QC.Vertex{i, label, neighbor_ids(ns)} <> vertices}, U32.inc(i))))



def complete_emit(-vertices: List<&2, QC.Vertex>, certificate: Maybe<&2, QC.Certified<vertices>>,
    asg: Array<U32>, +ncl: U32, +nloc: U32, g2l: Array<U32>, names: Array<List<&2, U32>>,
    +nnames: U32, +repr: Bool) -> Result<&1, &1, String, List<&2, U32>>:
  match certificate:
    case None{}: Fail{"complete-linkage certificate rejected: a within-cluster pair has no accepted edge"}
    case Some{proof}:
      certify_labels(labels_collect(U32.to_nat(nloc), asg, 0, Nil{}), ncl, nloc, g2l, names, nnames, repr)



# Each label group is certified on its own (QC.certify on the group's
# vertices): a within-group pair always shares the label, so this is the
# same pairwise contract, checked in O(sum of squared cluster sizes) instead
# of over all vertex pairs.
def group_ok(-xs: List<&2, QC.Vertex>, m: Maybe<&2, QC.Certified<xs>>) -> Bool:
  match m:
    case None{}: False{}
    case Some{c}: True{}


def group_push(r: Array<List<&2, QC.Vertex>> & List<&2, QC.Vertex>, +v: QC.Vertex) -> Array<List<&2, QC.Vertex>>:
  (gs, xs) = r
  Array.set(List<&2, QC.Vertex>, gs, QC.vertex_label(v), v <> xs)


def group_all(vs: List<&2, QC.Vertex>, gs: Array<List<&2, QC.Vertex>>) -> Array<List<&2, QC.Vertex>>:
  match vs:
    case Nil{}: gs
    case Con{+v, t}: group_all(t, group_push(Array.swap(List<&2, QC.Vertex>, gs, QC.vertex_label(v), Nil{}), v))


def groups_step(r: Array<List<&2, QC.Vertex>> & List<&2, QC.Vertex>, +ok: Bool) -> GC:
  (gs, +g) = r
  GC{gs, Bool.and(ok, group_ok(g, QC.certify(g)))}


def groups_check(n: Nat, +c: U32, st: GC) -> Bool:
  match n:
    case 0n:
      match st:
        case GC{gs, ok}: ok
    case 1n+p:
      match st:
        case GC{gs, ok}: groups_check(p, U32.inc(c), groups_step(Array.swap(List<&2, QC.Vertex>, gs, c, Nil{}), ok))


def complete_groups(ok: Bool, asg: Array<U32>, +ncl: U32, +nloc: U32, g2l: Array<U32>, names: Array<List<&2, U32>>,
    +nnames: U32, +repr: Bool) -> Result<&1, &1, String, List<&2, U32>>:
  match ok:
    case False{}: Fail{"complete-linkage certificate rejected: a within-cluster pair has no accepted edge"}
    case True{}: certify_labels(labels_collect(U32.to_nat(nloc), asg, 0, Nil{}), ncl, nloc, g2l, names, nnames, repr)


def complete_checked(r: Array<U32> & List<&2, QC.Vertex>, +ncl: U32, +nloc: U32,
    g2l: Array<U32>, names: Array<List<&2, U32>>, +nnames: U32, +repr: Bool) -> Result<&1, &1, String, List<&2, U32>>:
  (asg, +vertices) = r
  complete_groups(groups_check(U32.to_nat(ncl), 0,
      GC{group_all(vertices, Array.new(List<&2, QC.Vertex>, G.depth(ncl), Nil{})), True{}}),
    asg, ncl, nloc, g2l, names, nnames, repr)


def verify_graph(complete: Bool, rows: Array<List<&2, G.Nb>>, asg: Array<U32>, +ncl: U32, +nloc: U32,
    g2l: Array<U32>, names: Array<List<&2, U32>>, +nnames: U32, +repr: Bool) -> Result<&1, &1, String, List<&2, U32>>:
  match complete:
    case True{}:
      complete_checked(collect_vertices(U32.to_nat(nloc), VertexState{rows, asg, Nil{}}, 0), ncl, nloc, g2l, names, nnames, repr)
    case False{}:
      certify_labels(labels_collect(U32.to_nat(nloc), asg, 0, Nil{}), ncl, nloc, g2l, names, nnames, repr)



def cluster_checked(failed: Bool, asg: Array<U32>, +ncl: U32, +nloc: U32, g2l: Array<U32>, names: Array<List<&2, U32>>, +nnames: U32, +repr: Bool, rows: Array<List<&2, G.Nb>>, +algo: U32) -> Result<&1, &1, String, List<&2, U32>>:
  match failed:
    case True{}:
      Fail{"Leiden exceeded its safety budget; no clustering output was written"}
    case False{}:
      verify_graph(U32.is_eq(algo, 1), rows, asg, ncl, nloc, g2l, names, nnames, repr)




def cluster_fin(r: Array<U32> & U32, g2l: Array<U32>, +nloc: U32, names: Array<List<&2, U32>>, +nnames: U32, +repr: Bool, rows: Array<List<&2, G.Nb>>, +algo: U32) -> Result<&1, &1, String, List<&2, U32>>:
  (asg, +ncl) = r
  cluster_checked(U32.is_eq(ncl, 4294967295), asg, ncl, nloc, g2l, names, nnames, repr, rows, algo)




def cluster_objs(ro: Array<U32> & List<&2, U32>, rows: Array<List<&2, G.Nb>>, +m: U32, +nloc: U32, names: Array<List<&2, U32>>, +nnames: U32, cfg: Cfg) -> Result<&1, &1, String, List<&2, U32>>:
  (g2l, +objs) = ro
  match cfg:
    case Cfg{inp, out, ids, repr, algo, metric, thr, nalns, res, beta, iters, ineg}:
      pair_bind(Array<List<&2, G.Nb>>, Array<List<&2, G.Nb>>, Result<&1, &1, String, List<&2, U32>>,
        Array.clone(List<&2, G.Nb>, rows), working => original =>
          cluster_fin(run_algo(algo, working, nloc, m, objs, Cfg{inp, out, ids, repr, algo, metric, thr, nalns, res, beta, iters, ineg}),
            g2l, nloc, names, nnames, repr, original, algo))




def cluster_rows(rs: G.RS, g2l: Array<U32>, +nloc: U32, names: Array<List<&2, U32>>, +nnames: U32, cfg: Cfg) -> Result<&1, &1, String, List<&2, U32>>:
  match rs:
    case G.RS{rows, m}:
      match cfg:
        case Cfg{inp, out, ids, repr, algo, metric, thr, nalns, res, beta, iters, ineg}:
          cluster_objs(G.objects(g2l, nnames), rows, m, nloc, names, nnames,
            Cfg{inp, out, ids, repr, algo, metric, thr, nalns, res, beta, iters, ineg})




def cluster_go(empty: Bool, g2l: Array<U32>, edges: List<&2, L.Edge>, +nloc: U32, names: Array<List<&2, U32>>, +nnames: U32, cfg: Cfg) -> Result<&1, &1, String, List<&2, U32>>:
  match empty:
    case True{}:
      match cfg:
        case Cfg{inp, out, ids, repr, algo, metric, thr, nalns, res, beta, iters, ineg}:
          cluster_checked(False{}, G.u32_array(1, 0), 0, 0, g2l, names, nnames, repr, Array.new(List<&2, G.Nb>, 0n, Nil{}), algo)
    case False{}:
      match cfg:
        case Cfg{inp, out, ids, repr, algo, metric, thr, nalns, res, beta, iters, ineg}:
          cluster_rows(G.build_rows(edges, nloc, needs_dist(algo)), g2l, nloc, names, nnames,
            Cfg{inp, out, ids, repr, algo, metric, thr, nalns, res, beta, iters, ineg})




def cluster_bytes(g2l: Array<U32>, edges: List<&2, L.Edge>, +nloc: U32, +nedge: U32, names: Array<List<&2, U32>>, +nnames: U32, cfg: Cfg) -> Result<&1, &1, String, List<&2, U32>>:
  match cfg:
    case Cfg{inp, out, ids, repr, algo, metric, thr, nalns, res, beta, iters, ineg}:
      cluster_go(U32.is_eq(nedge, 0), g2l, edges, nloc, names, nnames,
        Cfg{inp, out, ids, repr, algo, metric, thr, nalns, res, beta, iters, ineg})




def die_go(ok: Bool, +e: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 2, "vclust cluster: error: " ++ e)




def die_if(+e: String) -> IO(Unit):
  die_go(String.eq(e, ""), e)




def first_chunk(r: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> File & List<&2, U32>:
  (f, res) = r
  match res:
    case Fail{e}:
      (f, Nil{})
    case Done{bs}:
      (f, bs)




def header_of(c: L.Cut & List<&2, U32>) -> List<&2, List<&2, U32>> & List<&2, U32>:
  (cut, rest) = c
  match cut:
    case L.Cut{line, done}:
      (L.tokens(L.rev_bytes(line, Nil{})), rest)




def ps_finish(ps: L.PS) -> L.PS:
  L.ps_newline(ps)




def depth_n(+n: U32) -> Nat:
  G.depth(n)




def cfg_out(cfg: Cfg) -> String:
  match cfg:
    case Cfg{inp, out, ids, repr, algo, metric, thr, nalns, res, beta, iters, ineg}:
      out




def write_result(result: Result<&1, &1, String, List<&2, U32>>, path: String) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 2, "vclust cluster: error: " ++ e)
    case Done{bytes}: write_out(path, bytes)




def cfg_algo(cfg: Cfg) -> U32:
  match cfg:
    case Cfg{inp, out, ids, repr, algo, metric, thr, nalns, res, beta, iters, ineg}:
      algo



def cfg_repr(cfg: Cfg) -> Bool:
  match cfg:
    case Cfg{inp, out, ids, repr, algo, metric, thr, nalns, res, beta, iters, ineg}:
      repr



# phase timings on stderr when CLUSTER_TIMING is set (milliseconds)
def timing_line(+tparse: Nat, +tbuild: Nat, +tkern: Nat, +tcert: Nat, +twrite: Nat) -> String:
  "cluster timing ms: parse " ++ Nat.show(tparse) ++ " build " ++ Nat.show(tbuild) ++ " kernel " ++
    Nat.show(tkern) ++ " certify+render " ++ Nat.show(tcert) ++ " write " ++ Nat.show(twrite)



def report_go(r: Result<&1, &1, U32 & String, String>, +line: String) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.pure(Unit, Unit{})
    case Done{v}:
      IO.print_err(line)



def report(+line: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, String> <- IO.get_env("CLUSTER_TIMING")
    report_go(r, line)



def run_render(ar: Array<U32> & U32, g2l: Array<U32>, original: Array<List<&2, G.Nb>>, +nloc: U32, names: Array<List<&2, U32>>,
               +nnames: U32, +cfg: Cfg, +tparse: Nat, +tbuild: Nat, +tkern: Nat) -> IO(Unit):
  do IO<Unit>:
    +t5 : Nat <- IO.now()
    res : Result<&1, &1, String, List<&2, U32>> = cluster_fin(ar, g2l, nloc, names, nnames, cfg_repr(cfg), original, cfg_algo(cfg))
    +t6 : Nat <- IO.now()
    write_result(res, cfg_out(cfg))
    +t7 : Nat <- IO.now()
    report(timing_line(tparse, tbuild, tkern, Nat.sub(t6, t5), Nat.sub(t7, t6)))



def run_kernel3(rc: Array<List<&2, G.Nb>> & Array<List<&2, G.Nb>>, g2l: Array<U32>, +objs: List<&2, U32>, +m: U32, +nloc: U32,
                names: Array<List<&2, U32>>, +nnames: U32, +cfg: Cfg, +tparse: Nat, +tbuild: Nat) -> IO(Unit):
  (working, original) = rc
  do IO<Unit>:
    +t3 : Nat <- IO.now()
    ar : Array<U32> & U32 = run_algo(cfg_algo(cfg), working, nloc, m, objs, cfg)
    +t4 : Nat <- IO.now()
    run_render(ar, g2l, original, nloc, names, nnames, cfg, tparse, tbuild, Nat.sub(t4, t3))



def run_kernel2(ro: Array<U32> & List<&2, U32>, rows: Array<List<&2, G.Nb>>, +m: U32, +nloc: U32, names: Array<List<&2, U32>>,
                +nnames: U32, +cfg: Cfg, +tparse: Nat, +tbuild: Nat) -> IO(Unit):
  (g2l, +objs) = ro
  run_kernel3(Array.clone(List<&2, G.Nb>, rows), g2l, objs, m, nloc, names, nnames, cfg, tparse, tbuild)



def run_kernel(rs: G.RS, g2l: Array<U32>, +nloc: U32, names: Array<List<&2, U32>>, +nnames: U32, +cfg: Cfg, +tparse: Nat, +tbuild: Nat) -> IO(Unit):
  match rs:
    case G.RS{rows, m}:
      run_kernel2(G.objects(g2l, nnames), rows, m, nloc, names, nnames, cfg, tparse, tbuild)



def run_stage(empty: Bool, g2l: Array<U32>, edges: List<&2, L.Edge>, +nloc: U32, +nedge: U32, names: Array<List<&2, U32>>,
              +nnames: U32, +cfg: Cfg, +tparse: Nat) -> IO(Unit):
  match empty:
    case True{}:
      write_result(cluster_bytes(g2l, edges, nloc, nedge, names, nnames, cfg), cfg_out(cfg))
    case False{}:
      do IO<Unit>:
        +t1 : Nat <- IO.now()
        rs : G.RS = G.build_rows(edges, nloc, needs_dist(cfg_algo(cfg)))
        +t2 : Nat <- IO.now()
        run_kernel(rs, g2l, nloc, names, nnames, cfg, tparse, Nat.sub(t2, t1))



def run_rows(parts: Parts, +cfg: Cfg, names: Array<List<&2, U32>>, +nnames: U32, +tparse: Nat) -> IO(Unit):
  match parts:
    case Parts{g2l, edges, nloc, nedge, err}:
      do IO<Unit>:
        die_if(str_pick(U32.is_eq(err, 0), "", err_text(err)))
        run_stage(U32.is_eq(nedge, 0), g2l, edges, nloc, nedge, names, nnames, cfg, tparse)



def run_meta(mh: MH, rest: List<&2, U32>, f: File, +cfg: Cfg, names: Array<List<&2, U32>>, +nnames: U32, +cap: U32) -> IO(Unit):
  match mh:
    case MH{err, +m}:
      do IO<Unit>:
        die_if(err)
        +t0 : Nat <- IO.now()
        ta : TA <- tab_loop(chunk_fuel(), f, m, rest <> Nil{}, TA{Nil{}, Nil{}})
        pp : Parts = ta_parts(m, cap, ta)
        +t1 : Nat <- IO.now()
        run_rows(pp, cfg, names, nnames, Nat.sub(t1, t0))




def run_header(hr: List<&2, List<&2, U32>> & List<&2, U32>, f: File, +cfg: Cfg, names: Array<List<&2, U32>>, +nnames: U32) -> IO(Unit):
  (+cols, rest) = hr
  +cap = U32.shln(1, depth_n(U32.inc(nnames)))
  run_meta(meta_of(cols, cfg, cap), rest, f, cfg, names, nnames, cap)




def run_table(fc: File & List<&2, U32>, +cfg: Cfg, names: Array<List<&2, U32>>, +nnames: U32) -> IO(Unit):
  (f, bs) = fc
  run_header(header_of(L.cut_line(bs, L.Cut{Nil{}, False{}})), f, cfg, names, nnames)




def cfg_inp(cfg: Cfg) -> String:
  match cfg:
    case Cfg{inp, out, ids, repr, algo, metric, thr, nalns, res, beta, iters, ineg}:
      inp




def cfg_ids(cfg: Cfg) -> String:
  match cfg:
    case Cfg{inp, out, ids, repr, algo, metric, thr, nalns, res, beta, iters, ineg}:
      ids




def run_ids(r: List<&2, List<&2, U32>> & U32, +cfg: Cfg) -> IO(Unit):
  (rnames, +nnames) = r
  do IO<Unit>:
    f : File <- IO.try(File, File.open(cfg_inp(cfg), "r"))
    c : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 1048576)
    run_table(first_chunk(c), cfg,
      names_fill(rnames, U32.sub(nnames, 1), Array.new(List<&2, U32>, G.depth(nnames), Nil{})), nnames)




def run_cfg(ec: String & Cfg) -> IO(Unit):
  (e, +cfg) = ec
  do IO<Unit>:
    die_if(e)
    f : File <- IO.try(File, File.open(cfg_ids(cfg), "r"))
    s : IDS <- read_ids_loop(chunk_fuel(), f, IDS{False{}, True{}, Nil{}, Nil{}, 0})
    run_ids(ids_end(s), cfg)




def args_tail(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      t




def pa_opts(p: PA) -> String & List<&2, Opt>:
  match p:
    case PA{rest, opts, err}:
      (err, opts)




def run_pa(eo: String & List<&2, Opt>) -> IO(Unit):
  (e, +opts) = eo
  do IO<Unit>:
    die_if(e)
    run_cfg(config(opts))




def to_data(xs: List<&1, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      h <> to_data(t)



def run_args(+args: List<&2, String>) -> IO(Unit):
  run_pa(pa_opts(pa_loop(U32.to_nat(U32.add(U32.from_nat(List.length(&2, String, args)), 1)),
    PA{args_tail(args), Nil{}, ""})))



def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    run_args(to_data(args))
