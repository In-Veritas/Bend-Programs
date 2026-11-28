# `vclust prefilter` in Bend: a port of Kmer-db 2.3.1 as Vclust 1.3.1 runs it
# on one multi-FASTA file:
#   kmer-db build -multisample-fasta -k K -f F          (kdb_build, kdb_db)
#   kmer-db all2all-sp -sparse -min num-kmers:N -min ani-shorter:T
#           [-sample-rows ani-shorter:M]                (kdb_a2a, pf_sel)
#   kmer-db distance ani-shorter -sparse -min T         (rows written below)
# With --batch-size B: mfasta-tool split + all2all-parts (kdb_parts).
#
#   prefilter -i in.fasta -o fltr.txt [-k 25] [--min-kmers 20]
#             [--min-ident 0.7] [--batch-size 0] [--kmers-fraction 1]
#             [--max-seqs 0] [-t 12] [--bubble-size 8000]
#
# -t is Kmer-db's thread count (all2all-sp workers, rows mod 2t); the Bend
# runtime threads are `+RTS --threads N -RTS`. --bubble-size is Kmer-db's
# -bubble-size (Vclust leaves the default 8000).
import Base
import ./pf_fasta.bend as F
import ./pf_num.bend as N
import ./pf_sel.bend as S
import ./kdb_util.bend as K
import ./kdb_extract.bend as X
import ./kdb_db.bend as D
import ./kdb_a2a.bend as A
import ./kdb_build.bend as B
import ./kdb_parts.bend as P

type Opts is Data:
  Opts{inp: String, out: String, k: String, mink: String, mini: String, batch: String, frac: String,
       maxs: String, thr: String, bub: String}

def pick_s(c: Bool, a: String, b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

def is_flag(+f: String, a: String, b: String) -> Bool:
  String.eq(f, a) || String.eq(f, b)

def set_opt(+f: String, +v: String, o: Opts) -> Opts:
  Opts{+inp, +out, +k, +mink, +mini, +batch, +frac, +maxs, +thr, +bub} = o
  Opts{pick_s(is_flag(f, "-i", "--in"), v, inp), pick_s(is_flag(f, "-o", "--out"), v, out),
       pick_s(is_flag(f, "-k", "--k"), v, k), pick_s(is_flag(f, "--min-kmers", "--min-kmers"), v, mink),
       pick_s(is_flag(f, "--min-ident", "--min-ident"), v, mini),
       pick_s(is_flag(f, "--batch-size", "--batch-size"), v, batch),
       pick_s(is_flag(f, "--kmers-fraction", "--kmers-fraction"), v, frac),
       pick_s(is_flag(f, "--max-seqs", "--max-seqs"), v, maxs),
       pick_s(is_flag(f, "-t", "--threads"), v, thr),
       pick_s(is_flag(f, "--bubble-size", "--bubble-size"), v, bub)}

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


def write_row(row: List<&2, U32>, f: File, names: List<&2, List<&2, U32>>, k: WF -> IO(WF)) -> IO(WF):
  match names:
    case Nil{}:
      k(WF{f, Nil{}})
    case Con{nm, rest}:
      do IO<WF>:
        g : File <- put(f, bytes_app(nm, Con{44, bytes_app(row, Con{10, Nil{}})}))
        k(WF{g, rest})

def write_rows(rows: List<&2, List<&2, U32>>, w: WF, k: WF -> IO(WF)) -> IO(WF):
  match rows w:
    case Nil{} _:
      k(w)
    case Con{row, rest} WF{f, names}:
      write_row(row, f, names, wf => write_rows(rest, wf, k))

def rl_list(rl: A.RL) -> List<&2, List<&2, U32>>:
  match rl:
    case A.RLNil{}:
      Nil{}
    case A.RLCon{+r, row, t}:
      Con{row, rl_list(t)}

def close_wf(w: WF) -> IO(Unit):
  WF{f, names} = w
  File.close(f)

# distance rows, written block by block (rows [r0, r0 + 4096))
def blk_loop(f: Nat, ot: A.OT, +r0: U32, +n: U32, +w2: U32, +op: A.OP, wf: WF) -> IO(WF):
  match f:
    case 0n:
      IO.pure(WF, wf)
    case 1n+q:
      +r1 = U32.min(n, (r0 + 4096 : U32))
      K.apply(A.OT & A.RL, IO(WF), \{Tuple: ot2 => rl => (
        write_rows(rl_list(rl), wf, w => blk_loop(q, ot2, r1, n, w2, op, w))
      )}, A.out_block(ot, r0, r1, w2, op))

def raw_out(+n: U32, +maxs: U32, wf: WF, r: A.OT & A.RL) -> IO(WF):
  (ot, rl) = r
  write_rows(S.select(n, maxs, rl_list(rl)), wf, w => IO.pure(WF, w))

def write_out(raw: Bool, ot: A.OT, +n: U32, +w2: U32, +maxs: U32, +op: A.OP, wf: WF) -> IO(WF):
  match raw:
    case True{}:
      raw_out(n, maxs, wf, A.out_block(ot, 0, n, w2, op))
    case False{}:
      blk_loop(U32.to_nat((U32.div(n, 4096) + 1 : U32)), ot, 0, n, w2, op, wf)

def header(+k: U32, +frac: String, +names: List<&2, List<&2, U32>>) -> List<&2, U32>:
  bytes_app(str_bytes("kmer-length: " ++ U32.show(k) ++ " fraction: " ++ N.dec_g(N.dec_parse(frac)) ++ " ", Nil{}),
    bytes_app(names_line(names, Con{44, Nil{}}), Con{10, Nil{}}))

def op_of(+mink: U32, +k: U32, t: N.Thr, +maxs: U32) -> A.OP:
  N.Thr{+one, +fx} = t
  A.OP{mink, k, one, fx, U32.is_ne(maxs, 0)}

# PF_TIME=1: phase times (ms) on stderr
def log_if(tm: Bool, msg: String) -> IO(Unit):
  match tm:
    case True{}:
      IO.print_err(msg)
    case False{}:
      IO.pure(Unit, Unit{})

def is_set(r: Result<&1, &1, U32 & String, String>) -> Bool:
  match r:
    case Fail{e}:
      False{}
    case Done{v}:
      True{}

def ms(+t0: Nat, +t1: Nat) -> String:
  Nat.show(Nat.sub(t1, t0))

# all2all-sp + distance on the built database
def run_a2a(o: Opts, +n: U32, +k: U32, +names: List<&2, List<&2, U32>>, +tm: Bool, +t0: Nat, +t1: Nat, bs: B.BS) -> IO(Unit):
  Opts{+inp, +out, +ks, +mink, +mini, +batch, +frac, +maxs, +thr, +bub} = o
  B.BS{db, cnt, s} = bs
  D.DB{ht, pt, +pb} = db
  D.PS{pat, +np, +pcap, nod, +nn, +ncap} = pt
  +w = U32.max(1, u32_or(thr, 12))
  +ms0 = u32_or(maxs, 0)
  +op = op_of(u32_or(mink, 20), k, N.thr_of(N.dec_value(N.dec_parse(mini))), ms0)
  +bsize = K.sel(U32.is_lt(2000000, n), U32.shln(n, 1n), 2000000)
  do IO<Unit>:
    +t2 : Nat <- IO.now()
    ar : A.AR = A.all2all_sp(pat, nod, np, n, w, bsize, u32_or(bub, 8000))
    +t3 : Nat <- IO.now()
    ot : A.OT = A.out_tree(n, ar, cnt)
    f : File <- IO.try(File, File.open(out, "w"))
    g : File <- put(f, header(k, frac, names))
    w2 : WF <- write_out(U32.is_ne(ms0, 0), ot, n, U32.shln(w, 1n), ms0, op, WF{g, names})
    close_wf(w2)
    +t4 : Nat <- IO.now()
    log_if(tm, "patterns " ++ U32.show(np) ++ " read " ++ ms(t0, t1) ++ " build " ++ ms(t1, t2) ++
      " all2all-sp " ++ ms(t2, t3) ++ " compact+distance+write " ++ ms(t3, t4))

# --batch-size: all2all-parts, row part by row part
type PW is Type:
  PW{wf: WF, acc: List<&2, List<&2, U32>>}

def rows_rev(xs: List<&2, List<&2, U32>>, acc: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      rows_rev(t, Con{h, acc})

def part_rows(raw: Bool, ot: A.OT, +o: U32, +b: U32, +w2: U32, +op: A.OP, pw: PW, k: PW -> IO(PW)) -> IO(PW):
  match raw:
    case True{}:
      PW{wf, acc} = pw
      K.apply(A.OT & A.RL, IO(PW), \{Tuple: ot2 => rl => (
        k(PW{wf, rows_rev(rl_list(rl), acc)})
      )}, A.out_block(ot, o, (o + b : U32), w2, op))
    case False{}:
      PW{wf, acc} = pw
      do IO<PW>:
        w2f : WF <- blk_loop(U32.to_nat((U32.div(b, 4096) + 1 : U32)), ot, o, (o + b : U32), w2, op, wf)
        k(PW{w2f, acc})

def parts_loop(xs: P.PL, done: P.PL, cnt: Array<U32>, +n: U32, +w: U32, +bubble: U32, +raw: Bool, +op: A.OP,
               pw: PW) -> IO(PW):
  match xs:
    case P.PLNil{}:
      IO.pure(PW, pw)
    case P.PLCon{r, t}:
      K.apply(Array<U32> & Array<U32>, IO(PW), \{Tuple: c1 => c2 => (
        K.apply(P.RP, IO(PW), \{P.RP: done2 => ot => +o => +b => (
          part_rows(raw, ot, o, b, U32.shln(w, 1n), op, pw, pw2 => parts_loop(t, done2, c2, n, w, bubble, raw, op, pw2))
        )}, P.row_part(r, done, n, c1, w, bubble))
      )}, Array.clone(U32, cnt))

def parts_fin(raw: Bool, +n: U32, +maxs: U32, pw: PW) -> IO(WF):
  match raw:
    case True{}:
      PW{wf, acc} = pw
      write_rows(S.select(n, maxs, rows_rev(acc, Nil{})), wf, w => IO.pure(WF, w))
    case False{}:
      PW{wf, acc} = pw
      IO.pure(WF, wf)

def run_parts(o: Opts, +n: U32, +k: U32, +bsz: U32, +names: List<&2, List<&2, U32>>, bp: P.BP) -> IO(Unit):
  Opts{+inp, +out, +ks, +mink, +mini, +batch, +frac, +maxs, +thr, +bub} = o
  P.BP{parts, cnt, ob} = bp
  +w = U32.max(1, u32_or(thr, 12))
  +ms = u32_or(maxs, 0)
  +op = op_of(u32_or(mink, 20), k, N.thr_of(N.dec_value(N.dec_parse(mini))), ms)
  do IO<Unit>:
    f : File <- IO.try(File, File.open(out, "w"))
    g : File <- put(f, header(k, frac, names))
    pw : PW <- parts_loop(parts, P.PLNil{}, cnt, n, w, u32_or(bub, 8000), U32.is_ne(ms, 0), op, PW{WF{g, names}, Nil{}})
    w2 : WF <- parts_fin(U32.is_ne(ms, 0), n, ms, pw)
    close_wf(w2)

def go_split(split: Bool, +t0: Nat, +o: Opts, +k: U32, +bsz: U32, +n: U32, +names: List<&2, List<&2, U32>>, raws: F.Raws) -> IO(Unit):
  match split:
    case True{}:
      Opts{+inp, +out, +ks, +mink, +mini, +batch, +frac, +maxs, +thr, +bub} = o
      run_parts(o, n, k, bsz, names, P.build_parts(n, bsz, X.cfg_of(k, frac), raws))
    case False{}:
      Opts{+inp, +out, +ks, +mink, +mini, +batch, +frac, +maxs, +thr, +bub} = o
      do IO<Unit>:
        tv : Result<&1, &1, U32 & String, String> <- IO.get_env("PF_TIME")
        +t1 : Nat <- IO.now()
        bs : B.BS = B.build(n, X.cfg_of(k, frac), 64, raws)
        run_a2a(o, n, k, names, is_set(tv), t0, t1, bs)

def go_parsed(+o: Opts, +k: U32, +t0: Nat, p: F.Parsed) -> IO(Unit):
  Opts{+inp, +out, +ks, +mink, +mini, +batch, +frac, +maxs, +thr, +bub} = o
  F.Parsed{raws, +names, +n} = p
  +bsz = u32_or(batch, 0)
  go_split(U32.is_ne(bsz, 0) && U32.is_lt(bsz, n), t0, o, k, bsz, n, names, raws)

def go_opts(+o: Opts) -> IO(Unit):
  Opts{+inp, +out, +ks, +mink, +mini, +batch, +frac, +maxs, +thr, +bub} = o
  +k = u32_or(ks, 25)
  do IO<Unit>:
    +t0 : Nat <- IO.now()
    p : F.Parsed <- F.read_fasta(inp, k)
    go_parsed(o, k, t0, p)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    o : Opts = parse_args(drop1(args), Opts{"", "", "25", "20", "0.7", "0", "1", "0", "12", "8000"})
    go_opts(o)
