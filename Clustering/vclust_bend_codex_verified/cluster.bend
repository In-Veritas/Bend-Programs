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


# the table: header in the first chunk, rows streamed
def read_tab_res(r: File & Result<&1, &1, U32 & String, List<&2, U32>>, ps: L.PS, k: File -> L.PS -> IO(L.PS)) -> IO(L.PS):
  (f, res) = r
  match res:
    case Fail{e}:
      do IO<L.PS>:
        File.close(f)
        IO.die(L.PS, 1, "Unable to read distance file")
    case Done{bs}:
      match bs:
        case Nil{}:
          do IO<L.PS>:
            File.close(f)
            return ps
        case Con{h, t}:
          k(f, L.ps_bytes(h <> t, ps))


def read_tab_loop(n: Nat, f: File, ps: L.PS) -> IO(L.PS):
  match n:
    case 0n:
      do IO<L.PS>:
        File.close(f)
        return ps
    case 1n+p:
      do IO<L.PS>:
        r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 1048576)
        read_tab_res(r, ps, g => s2 => read_tab_loop(p, g, s2))


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


def cg_le(x: CG, y: CG) -> Bool:
  match x y:
    case CG{a, b} CG{c, d}:
      Bool.or(U32.is_lt(a, c), Bool.and(U32.is_eq(a, c), U32.is_le(b, d)))


def sz_le(x: SZ, y: SZ) -> Bool:
  match x y:
    case SZ{a, b} SZ{c, d}:
      Bool.or(U32.is_gt(a, c), Bool.and(U32.is_eq(a, c), U32.is_le(b, d)))


def count_inc(rs: Array<U32> & U32, asg: Array<U32>, +c: U32) -> Array<U32> & Array<U32>:
  (sizes, +s) = rs
  (asg, Array.set(U32, sizes, c, U32.inc(s)))


def count_go(r: Array<U32> & U32, sizes: Array<U32>) -> Array<U32> & Array<U32>:
  (asg, +c) = r
  count_inc(Array.get(U32, sizes, c), asg, c)


def count_sizes(n: Nat, +v: U32, st: Array<U32> & Array<U32>) -> Array<U32> & Array<U32>:
  match n:
    case 0n:
      st
    case 1n+p:
      (asg, sizes) = st
      count_sizes(p, U32.inc(v), count_go(Array.get(U32, asg, v), sizes))


def sz_list(n: Nat, +c: U32, r: Array<U32> & U32) -> List<&2, SZ>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      (sizes, +s) = r
      SZ{s, c} <> sz_list(p, U32.inc(c), Array.get(U32, sizes, U32.inc(c)))


def old2new_go(xs: List<&2, SZ>, +i: U32, o2n: Array<U32>) -> Array<U32>:
  match xs:
    case Nil{}:
      o2n
    case Con{x, t}:
      match x:
        case SZ{s, c}:
          old2new_go(t, U32.inc(i), Array.set(U32, o2n, c, i))


def old2new(cs: Array<U32> & Array<U32>, +ncl: U32) -> Array<U32> & Array<U32>:
  (asg, sizes) = cs
  (asg, old2new_go(List.sort(~SZ, ~sz_le, sz_list(U32.to_nat(ncl), 0, Array.get(U32, sizes, 0))), 0,
    G.u32_array(ncl, 0)))


def ob_c(rc: Array<U32> & U32, g2l: Array<U32>, asg: Array<U32>, +ins: List<&2, CG>, +outs: List<&2, U32>, +gi: U32) -> OB:
  (o2n, +c) = rc
  OB{g2l, asg, o2n, CG{c, gi} <> ins, outs}


def ob_a(ra: Array<U32> & U32, g2l: Array<U32>, o2n: Array<U32>, +ins: List<&2, CG>, +outs: List<&2, U32>, +gi: U32) -> OB:
  (asg, +a) = ra
  ob_c(Array.get(U32, o2n, a), g2l, asg, ins, outs, gi)


def ob_in(out: Bool, g2l: Array<U32>, asg: Array<U32>, o2n: Array<U32>, +ins: List<&2, CG>, +outs: List<&2, U32>, +gi: U32, +l: U32) -> OB:
  match out:
    case True{}:
      OB{g2l, asg, o2n, ins, gi <> outs}
    case False{}:
      ob_a(Array.get(U32, asg, l), g2l, o2n, ins, outs, gi)


def ob_l(rl: Array<U32> & U32, asg: Array<U32>, o2n: Array<U32>, +ins: List<&2, CG>, +outs: List<&2, U32>, +gi: U32) -> OB:
  (g2l, +l) = rl
  ob_in(U32.is_eq(l, L.none()), g2l, asg, o2n, ins, outs, gi, l)


def ob_loop(n: Nat, +gi: U32, ob: OB) -> OB:
  match n:
    case 0n:
      ob
    case 1n+p:
      match ob:
        case OB{g2l, asg, o2n, ins, outs}:
          ob_loop(p, U32.inc(gi), ob_l(Array.get(U32, g2l, gi), asg, o2n, ins, outs, gi))


def rev_u32(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      rev_u32(t, h <> acc)


def line_rev(+name: List<&2, U32>, +rest: List<&2, U32>, +acc: List<&2, U32>) -> List<&2, U32>:
  10 <> cat_bytes(rest, 9 <> cat_bytes(name, acc))


def ow_emit(repr: Bool, fresh: Bool, names: Array<List<&2, U32>>, +acc: List<&2, U32>, +nm: List<&2, U32>, +rep: List<&2, U32>, +c: U32) -> OW:
  match repr:
    case False{}:
      OW{names, line_rev(nm, L.bytes_of(U32.show(c)), acc), c, rep}
    case True{}:
      match fresh:
        case True{}:
          OW{names, line_rev(nm, nm, acc), c, nm}
        case False{}:
          OW{names, line_rev(nm, rep, acc), c, rep}


def ow_cg(rn: Array<List<&2, U32>> & List<&2, U32>, +acc: List<&2, U32>, +cur: U32, +rep: List<&2, U32>, +repr: Bool, +c: U32) -> OW:
  (names, +nm) = rn
  ow_emit(repr, U32.is_ne(c, cur), names, acc, nm, rep, c)


def ow_ins(xs: List<&2, CG>, +repr: Bool, ow: OW) -> OW:
  match xs:
    case Nil{}:
      ow
    case Con{x, t}:
      match x:
        case CG{c, gi}:
          match ow:
            case OW{names, acc, cur, rep}:
              ow_ins(t, repr, ow_cg(Array.get(List<&2, U32>, names, gi), acc, cur, rep, repr, c))


def none_u32() -> U32:
  4294967295


def ow_outs(xs: List<&2, U32>, +repr: Bool, +c: U32, ow: OW) -> OW:
  match xs:
    case Nil{}:
      ow
    case Con{gi, t}:
      match ow:
        case OW{names, acc, cur, rep}:
          ow_outs(t, repr, U32.inc(c), ow_cg(Array.get(List<&2, U32>, names, gi), acc, none_u32(), rep, repr, c))


def ow_bytes(ow: OW) -> List<&2, U32>:
  match ow:
    case OW{names, acc, cur, rep}:
      rev_u32(acc, Nil{})


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


def ob_fin(ob: OB, names: Array<List<&2, U32>>, +repr: Bool, +ncl: U32) -> List<&2, U32>:
  match ob:
    case OB{g2l, asg, o2n, ins, outs}:
      ow_bytes(ow_outs(rev_u32(outs, Nil{}), repr, ncl,
        ow_ins(List.sort(~CG, ~cg_le, ins), repr, OW{names, cat_bytes(header_bytes(), Nil{}), none_u32(), Nil{}})))


def render_go(r: Array<U32> & Array<U32>, +ncl: U32, g2l: Array<U32>, names: Array<List<&2, U32>>, +nnames: U32, +repr: Bool) -> List<&2, U32>:
  (asg, o2n) = r
  ob_fin(ob_loop(U32.to_nat(nnames), 0, OB{g2l, asg, o2n, Nil{}, Nil{}}), names, repr, ncl)


# assignment over local ids (n of them) with ncl clusters -> output bytes
def render(asg: Array<U32>, +ncl: U32, +nloc: U32, g2l: Array<U32>, names: Array<List<&2, U32>>, +nnames: U32, +repr: Bool) -> List<&2, U32>:
  render_go(old2new(count_sizes(U32.to_nat(nloc), 0, (asg, G.u32_array(ncl, 0))), ncl), ncl, g2l, names, nnames, repr)


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


# ---------------------------------------------------------------------------
# main

type Parts is Type:
  Parts{g2l: Array<U32>, edges: List<&2, L.Edge>, +nloc: U32, +nedge: U32, +err: U32}

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

type VertexState is Type:
  VertexState{rows: Array<List<&2, G.Nb>>, asg: Array<U32>, vertices: List<&2, QC.Vertex>}

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

def complete_checked(r: Array<U32> & List<&2, QC.Vertex>, +ncl: U32, +nloc: U32,
    g2l: Array<U32>, names: Array<List<&2, U32>>, +nnames: U32, +repr: Bool) -> Result<&1, &1, String, List<&2, U32>>:
  (asg, +vertices) = r
  complete_emit(vertices, QC.certify(vertices), asg, ncl, nloc, g2l, names, nnames, repr)

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


def run_rows(parts: Parts, +cfg: Cfg, names: Array<List<&2, U32>>, +nnames: U32) -> IO(Unit):
  match parts:
    case Parts{g2l, edges, nloc, nedge, err}:
      do IO<Unit>:
        die_if(str_pick(U32.is_eq(err, 0), "", err_text(err)))
        write_result(cluster_bytes(g2l, edges, nloc, nedge, names, nnames, cfg), cfg_out(cfg))


def run_meta(mh: MH, rest: List<&2, U32>, f: File, +cfg: Cfg, names: Array<List<&2, U32>>, +nnames: U32, +cap: U32) -> IO(Unit):
  match mh:
    case MH{err, m}:
      do IO<Unit>:
        die_if(err)
        ps : L.PS <- read_tab_loop(chunk_fuel(), f, L.ps_bytes(rest, L.ps_new(m, G.u32_array(cap, L.none()))))
        run_rows(ps_parts(ps_finish(ps)), cfg, names, nnames)


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
