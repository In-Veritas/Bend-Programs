# `vclust prefilter` in Bend: Kmer-db 2.3.1 (build -multisample-fasta,
# all2all-sp -sparse -min num-kmers:N -min ani-shorter:T [-sample-rows
# ani-shorter:M], distance ani-shorter -sparse -min T) on one multi-FASTA.
#
#   prefilter -i in.fasta -o fltr.txt [-k 25] [--min-kmers 20]
#             [--min-ident 0.7] [--batch-size 0] [--kmers-fraction 1]
#             [--max-seqs 0] [-t N]
#
# Threads are the runtime's: run as `prefilter ... +RTS --threads N -RTS`
# (the `prefilter.sh` wrapper maps -t N to that). The output is Kmer-db's
# sparse distance text, byte-identical to Vclust's (see README).
import Base
import ./pf_fasta.bend as F
import ./pf_num.bend as N
import ./pf_core.bend as K
import ./pf_sel.bend as S

type Opts is Data:
  Opts{inp: String, out: String, k: String, mink: String, mini: String, batch: String, frac: String,
       maxs: String}

def pick_s(c: Bool, a: String, b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

def is_flag(+f: String, a: String, b: String) -> Bool:
  String.eq(f, a) || String.eq(f, b)

def set_opt(+f: String, +v: String, o: Opts) -> Opts:
  Opts{+inp, +out, +k, +mink, +mini, +batch, +frac, +maxs} = o
  Opts{pick_s(is_flag(f, "-i", "--in"), v, inp), pick_s(is_flag(f, "-o", "--out"), v, out),
       pick_s(is_flag(f, "-k", "--k"), v, k), pick_s(is_flag(f, "--min-kmers", "--min-kmers"), v, mink),
       pick_s(is_flag(f, "--min-ident", "--min-ident"), v, mini),
       pick_s(is_flag(f, "--batch-size", "--batch-size"), v, batch),
       pick_s(is_flag(f, "--kmers-fraction", "--kmers-fraction"), v, frac),
       pick_s(is_flag(f, "--max-seqs", "--max-seqs"), v, maxs)}

def parse_args(xs: List<String>, o: Opts) -> Opts:
  match xs:
    case Nil{}:
      o
    case Con{f, Nil{}}:
      o
    case Con{+f, Con{+v, rest}}:
      parse_args(rest, set_opt(f, v, o))

def drop1(xs: List<String>) -> List<String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      t

def u32_or(s: String, +d: U32) -> U32:
  Maybe.default(&2, U32, U32.read(s), d)

def str_bytes(s: String, acc: List<&2, U32>) -> List<&2, U32>:
  match s:
    case SNil{}:
      F.bytes_reverse(acc, Nil{})
    case SCon{Chr{+c}, t}:
      str_bytes(t, Con{c, acc})

def bytes_app(a: List<&2, U32>, b: List<&2, U32>) -> List<&2, U32>:
  match a:
    case Nil{}:
      b
    case Con{+h, t}:
      Con{h, bytes_app(t, b)}

# ",name1,name2,...,"
def rev_onto(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case Con{+h, t}:
      rev_onto(t, Con{h, acc})

# reversed bytes of "name1,name2,...," onto acc
def names_rev(xs: List<&2, List<&2, U32>>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      names_rev(t, Con{44, rev_onto(h, acc)})

def names_line(xs: List<&2, List<&2, U32>>, acc: List<&2, U32>) -> List<&2, U32>:
  bytes_app(acc, F.bytes_reverse(names_rev(xs, Nil{}), Nil{}))

# Writing
# =======

type WF is Type:
  WF{f: File, names: List<&2, List<&2, U32>>}

def wrote(r: File & Result<&1, &1, U32 & String, Unit>) -> IO(File):
  (f, res) = r
  match res:
    case Fail{e}:
      IO.die(File, 1, "write failed")
    case Done{u}:
      IO.pure(File, f)

def put(f: File, bs: List<&2, U32>) -> IO(File):
  do IO<File>:
    r : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(f, bs)
    wrote(r)

def bytes_rows(xs: List<&2, List<&2, U32>>, acc: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      Con{h, bytes_rows(t, acc)}

def rt_list(rt: K.RT, acc: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match rt:
    case K.RTNil{}:
      acc
    case K.RTLeaf{rows}:
      bytes_rows(rows, acc)
    case K.RTNode{l, r}:
      rt_list(l, rt_list(r, acc))

def write_row(row: List<&2, U32>, f: File, names: List<&2, List<&2, U32>>, k: WF -> IO(WF)) -> IO(WF):
  match names:
    case Nil{}:
      k(WF{f, Nil{}})
    case Con{nm, rest}:
      do IO<WF>:
        g : File <- put(f, bytes_app(nm, Con{44, bytes_app(row, Con{10, Nil{}})}))
        k(WF{g, rest})

def write_rows(rows: List<&2, List<&2, U32>>, w: WF) -> IO(WF):
  match rows w:
    case Nil{} _:
      IO.pure(WF, w)
    case Con{row, rest} WF{f, names}:
      write_row(row, f, names, wf => write_rows(rest, wf))

# Main
# ====

type Run is Data:
  Run{c: K.Cfg, ly: K.LY, fp: K.FP, +bsz: U32}

def rows_written(+b1: U32, w: WF) -> IO(WF):
  IO.pure(WF, w)

type WA is Type:
  WA{w: WF, acc: List<&2, List<&2, U32>>}

def rows_rev(xs: List<&2, List<&2, U32>>, acc: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      rows_rev(t, Con{h, acc})

# Without --max-seqs a batch's rows are written at once; with it they are
# kept (reversed) for the final selection.
def batch_done(raw: Bool, br: K.BR, wa: WA, k: K.ST -> WA -> IO(WA)) -> IO(WA):
  match raw:
    case True{}:
      K.BR{st, rows} = br
      WA{w, acc} = wa
      k(st, WA{w, rows_rev(rt_list(rows, Nil{}), acc)})
    case False{}:
      K.BR{st, rows} = br
      WA{w, acc} = wa
      do IO<WA>:
        w2 : WF <- write_rows(rt_list(rows, Nil{}), w)
        k(st, WA{w2, acc})

type RSum is Type:
  RSum{xs: F.Raws, +sum: U32}


def run_maxs(r: Run) -> U32:
  Run{+c, +ly, +fp, +bsz} = r
  K.FP{+mink, +k, +t, +maxs} = fp
  maxs

def run_n(r: Run) -> U32:
  Run{+c, +ly, +fp, +bsz} = r
  K.LY{+lp, +lq, +lr, +n} = ly
  n

def ms_since(+t0: Nat, +t1: Nat) -> String:
  Nat.show(Nat.sub(t1, t0))

def log_if(tm: Bool, msg: String) -> IO(Unit):
  match tm:
    case True{}:
      IO.print_err(msg)
    case False{}:
      IO.pure(Unit, Unit{})

def pass_io(fuel: Nat, +c: K.Cfg, +ly: K.LY, +rb: K.RB, +tm: Bool, s: K.BS) -> IO(K.BS):
  match fuel:
    case 0n:
      IO.pure(K.BS, s)
    case 1n+q:
      K.LY{+lp, +lq, +lr, +n} = ly
      K.BS{st, uc, dt, +p} = s
      do IO<K.BS>:
        t0 : Nat <- IO.now()
        pr : K.PR = K.par_pass(st, 1, K.cfg_pass(c, p), K.shl(1, lq), K.shl(1, (lp + lq : U32)))
        +t1 : Nat <- IO.now()
        s2 : K.BS = K.bs_passed(uc, dt, p, ly, rb, pr)
        t2 : Nat <- IO.now()
        log_if(tm, "pass " ++ U32.show(p) ++ ": extract " ++ ms_since(t0, t1) ++ " groups+apply " ++ ms_since(t1, t2))
        pass_io(q, c, ly, rb, tm, s2)

def batch_loop(fuel: Nat, st: K.ST, +b0: U32, +r: Run, +tm: Bool, w: WA) -> IO(WA):
  match fuel:
    case 0n:
      IO.pure(WA, w)
    case 1n+p:
      Run{+c, +ly, +fp, +bsz} = r
      K.LY{+lp, +lq, +lr, +n} = ly
      +b1 = U32.min(n, (b0 + bsz : U32))
      +rb = K.rb_make(b0, b1, n, K.shl(1, lr))
      do IO<WA>:
        s : K.BS <- pass_io(U32.to_nat(K.shl(1, lp)), c, ly, rb, tm,
          K.BS{st, K.arr_new(n), K.dt_build(U32.to_nat(lr), 0, rb), 0})
        t0 : Nat <- IO.now()
        br : K.BR = K.br_fin(ly, fp, s)
        +t1 : Nat <- IO.now()
        log_if(tm, "final " ++ ms_since(t0, t1))
        batch_done(U32.is_ne(run_maxs(r), 0), br, w, s2 => w2 => batch_loop(p, s2, b1, r, tm, w2))
def raws_sum(xs: F.Raws, acc: F.Raws, +sum: U32) -> RSum:
  match xs:
    case F.RawNil{}:
      RSum{F.raws_reverse(acc, F.RawNil{}), sum}
    case F.RawCon{h, t}:
      F.Raw{+len, codes, +segs} = h
      raws_sum(t, F.RawCon{F.Raw{len, codes, segs}, acc}, (sum + len : U32))

def lp_of(+total: U32) -> U32:
  # P = 2^lp passes with P * 2^25 >= total bases (Q = 2^7 groups per pass)
  U32.from_nat(F.depth(U32.max(1, U32.shrn((total + 33554431 : U32), 25n))))

# R = 2^lr row blocks, lr >= 6, with ceil(n / R) * n < 2^32 (block-local
# pair codes fit a U32 and code + 1 is never 0).
def lr_ok(+n: U32, +lr: U32) -> Bool:
  U32.is_le(U32.shrn((n + K.shl(1, lr) - 1 : U32), U32.to_nat(lr)), U32.div(4294967294, U32.max(n, 1)))

def lr_go(fuel: Nat, +n: U32, +lr: U32, ok: Bool) -> U32:
  match fuel ok:
    case _ True{}:
      lr
    case 0n False{}:
      lr
    case 1n+p False{}:
      +l2 = (lr + 1 : U32)
      lr_go(p, n, l2, lr_ok(n, l2))

def lr_of(+n: U32) -> U32:
  lr_go(10n, n, 6, lr_ok(n, 6))

def cfg_mk(+k: U32, t: N.Thr, +dv: N.DV) -> K.Cfg:
  N.Thr{+one, +fx} = t
  K.Cfg{k, K.sel(U32.is_ge(k, 16), (K.shl(1, K.sel(U32.is_ge(k, 16), (U32.mul(k, 2) - 32 : U32), 0)) - 1 : U32), 0),
        K.sel(U32.is_ge(k, 16), 4294967295, (K.shl(1, U32.mul(k, 2)) - 1 : U32)),
        K.sel(U32.is_ge(k, 17), K.shl(1, K.sel(U32.is_ge(k, 17), (U32.mul(k, 2) - 34 : U32), 0)), 0),
        K.sel(U32.is_le(k, 16), K.shl(1, (U32.mul(k, 2) - 2 : U32)), 0),
        0, 0, 0, Bool.not(one), N.frac_threshold(dv), U32.shrn((k + 3 : U32), 2n),
        K.sel(U32.is_lt(k, 20), (40 - U32.mul(k, 2) : U32), 0)}

def cfg_of(+k: U32, frac: String) -> K.Cfg:
  +dv = N.dec_value(N.dec_parse(frac))
  cfg_mk(k, N.thr_of(dv), dv)

def cfg_bits(c: K.Cfg, +lb: U32, +lq: U32) -> K.Cfg:
  K.Cfg{+k, +himask, +lomask, +rhu, +rlu, +lb0, +lq0, +p, +usef, +th, +kd4, +psh} = c
  K.Cfg{k, himask, lomask, rhu, rlu, lb, lq, p, usef, th, kd4, psh}

def close_wf(w: WF) -> IO(Unit):
  WF{f, names} = w
  File.close(f)


def finish_out(raw: Bool, +n: U32, +maxs: U32, wa: WA) -> IO(Unit):
  match raw:
    case True{}:
      WA{w, acc} = wa
      do IO<Unit>:
        w2 : WF <- write_rows(S.select(n, maxs, rows_rev(acc, Nil{})), w)
        close_wf(w2)
    case False{}:
      WA{w, acc} = wa
      close_wf(w)

def is_done(r: Result<&1, &1, U32 & String, String>) -> Bool:
  match r:
    case Fail{e}:
      False{}
    case Done{v}:
      True{}

def go_tree(+out: String, +k: U32, +frac: String, +names: List<&2, List<&2, U32>>, +r: Run, +nb: U32,
            st: K.ST) -> IO(Unit):
  +hdr = bytes_app(str_bytes("kmer-length: " ++ U32.show(k) ++ " fraction: " ++ N.dec_g(N.dec_parse(frac)) ++ " ", Nil{}),
    names_line(names, Con{44, Nil{}}))
  do IO<Unit>:
    f : File <- IO.try(File, File.open(out, "w"))
    g : File <- put(f, bytes_app(hdr, Con{10, Nil{}}))
    tv : Result<&1, &1, U32 & String, String> <- IO.get_env("PF_TIME")
    w : WA <- batch_loop(U32.to_nat(nb), st, 0, r, is_done(tv), WA{WF{g, names}, Nil{}})
    finish_out(U32.is_ne(run_maxs(r), 0), run_n(r), run_maxs(r), w)


def tree_fst(r: K.ST & F.Raws) -> K.ST:
  (st, rest) = r
  st


def tree_of(+n: U32, xs: F.Raws) -> K.ST:
  # at most 2^10 leaves (chunks of consecutive samples)
  tree_fst(K.build_st(U32.to_nat(U32.min(10, U32.from_nat(F.depth(U32.max(n, 1))))), 0, n, xs))


def go_summed(+out: String, +k: U32, +n: U32, +mink: String, +mini: String, +batch: String, +frac: String, +maxs: String,
              names: List<&2, List<&2, U32>>, rs: RSum) -> IO(Unit):
  RSum{xs, +total} = rs
  +lp = lp_of(total)
  +lq = {7 : U32}
  +lr = lr_of(n)
  +ly = {K.LY{lp, lq, lr, n} : K.LY}
  +c = cfg_bits(cfg_of(k, frac), (lp + lq : U32), lq)
  +fp = {K.FP{u32_or(mink, 20), k, N.thr_of(N.dec_value(N.dec_parse(mini))), u32_or(maxs, 0)} : K.FP}
  +bs = u32_or(batch, 0)
  +bsz = K.sel(U32.is_eq(bs, 0), U32.max(n, 1), bs)
  +nb = U32.div((n + bsz - 1 : U32), bsz)
  go_tree(out, k, frac, names, Run{c, ly, fp, bsz}, nb,
    K.count_pass(tree_of(n, xs), c, ly))


def go_parsed(o: Opts, +k: U32, p: F.Parsed) -> IO(Unit):
  Opts{+inp, +out, +ks, +mink, +mini, +batch, +frac, +maxs} = o
  F.Parsed{raws, names, +n} = p
  go_summed(out, k, n, mink, mini, batch, frac, maxs, names, raws_sum(raws, F.RawNil{}, 0))

def go_opts(+o: Opts) -> IO(Unit):
  Opts{+inp, +out, +ks, +mink, +mini, +batch, +frac, +maxs} = o
  +k = u32_or(ks, 25)
  do IO<Unit>:
    +t0 : Nat <- IO.now()
    p : F.Parsed <- F.read_fasta(inp, k)
    +t1 : Nat <- IO.now()
    tv : Result<&1, &1, U32 & String, String> <- IO.get_env("PF_TIME")
    log_if(is_done(tv), "read " ++ ms_since(t0, t1))
    go_parsed(o, k, p)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    o : Opts = parse_args(drop1(args), Opts{"", "", "25", "20", "0.7", "0", "1", "0"})
    go_opts(o)

