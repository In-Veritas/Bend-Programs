# vclust align in Bend: LZ-ANI 1.2.3 as driven by Vclust 1.3.1.
#
#   align -i in.fasta -o ani.tsv [--filter fltr.txt] [--filter-threshold F]
#         [--outfmt lite|standard|complete] [--out-ani F] [--out-tani F]
#         [--out-gani F] [--out-qcov F] [--out-rcov F] [--mal N] [--msl N]
#         [--mrd N] [--mqd N] [--reg N] [--aw N] [--am N] [--ar N] [-t N] [-v N]
#
# Threads come from the runtime (`+RTS --threads N -RTS`); `-t` is accepted
# for command-line compatibility (`python3 run.py align -t N` maps it). Writes
# ani.tsv and ani.ids.tsv exactly as `vclust align` does.
import Base
import ./align_num.bend as N
import ./align_lz.bend as L
import ./align_io.bend as R

def when(-A: Type, c: Bool, k: Bool -> A) -> A:
  k(c)

# Configuration
# =============

type Cfg is Data:
  Cfg{inp: String, out: String, flt: String, fthr: U32, fmt: U32,
    t_tani: U32, t_gani: U32, t_ani: U32, t_qcov: U32, t_rcov: U32,
    mal: U32, msl: U32, mrd: U32, mqd: U32, reg: U32, aw: U32, am: U32, ar: U32,
    err: String}

def cfg_new() -> Cfg:
  Cfg{"", "", "", 0, 1, 0, 0, 0, 0, 0, 11, 7, 40, 40, 35, 15, 7, 3, ""}

def num(+s: String) -> U32:
  Maybe.default(&2, U32, U32.read(s), 4294967295)

def frac(+s: String) -> U32:
  Maybe.default(&2, U32, N.dec_ceil9(N.string_bytes(s)), 4294967295)

def fmt_code(+s: String) -> U32:
  when(U32, String.eq(s, "lite"), \{
    True: 0
    False: when(U32, String.eq(s, "standard"), \{
      True: 1
      False: N.u32_if(String.eq(s, "complete"), 2, 9)
    })
  })

# set option k to value v
def cfg_set(+k: String, +v: String, c: Cfg) -> Cfg:
  match c:
    case Cfg{+inp, +out, +flt, +fthr, +fmt, +tt, +tg, +ta, +tq, +tr, +mal, +msl, +mrd,
             +mqd, +reg, +aw, +am, +ar, +err}:
      when(Cfg, String.eq(k, "-i") || String.eq(k, "--in"), \{
        True: Cfg{v, out, flt, fthr, fmt, tt, tg, ta, tq, tr, mal, msl, mrd, mqd, reg, aw, am, ar, err}
        False: when(Cfg, String.eq(k, "-o") || String.eq(k, "--out"), \{
        True: Cfg{inp, v, flt, fthr, fmt, tt, tg, ta, tq, tr, mal, msl, mrd, mqd, reg, aw, am, ar, err}
        False: when(Cfg, String.eq(k, "--filter"), \{
        True: Cfg{inp, out, v, fthr, fmt, tt, tg, ta, tq, tr, mal, msl, mrd, mqd, reg, aw, am, ar, err}
        False: when(Cfg, String.eq(k, "--filter-threshold"), \{
        True: Cfg{inp, out, flt, frac(v), fmt, tt, tg, ta, tq, tr, mal, msl, mrd, mqd, reg, aw, am, ar, err}
        False: when(Cfg, String.eq(k, "--outfmt"), \{
        True: Cfg{inp, out, flt, fthr, fmt_code(v), tt, tg, ta, tq, tr, mal, msl, mrd, mqd, reg, aw, am, ar, err}
        False: when(Cfg, String.eq(k, "--out-tani"), \{
        True: Cfg{inp, out, flt, fthr, fmt, frac(v), tg, ta, tq, tr, mal, msl, mrd, mqd, reg, aw, am, ar, err}
        False: when(Cfg, String.eq(k, "--out-gani"), \{
        True: Cfg{inp, out, flt, fthr, fmt, tt, frac(v), ta, tq, tr, mal, msl, mrd, mqd, reg, aw, am, ar, err}
        False: when(Cfg, String.eq(k, "--out-ani"), \{
        True: Cfg{inp, out, flt, fthr, fmt, tt, tg, frac(v), tq, tr, mal, msl, mrd, mqd, reg, aw, am, ar, err}
        False: when(Cfg, String.eq(k, "--out-qcov"), \{
        True: Cfg{inp, out, flt, fthr, fmt, tt, tg, ta, frac(v), tr, mal, msl, mrd, mqd, reg, aw, am, ar, err}
        False: when(Cfg, String.eq(k, "--out-rcov"), \{
        True: Cfg{inp, out, flt, fthr, fmt, tt, tg, ta, tq, frac(v), mal, msl, mrd, mqd, reg, aw, am, ar, err}
        False: when(Cfg, String.eq(k, "--mal"), \{
        True: Cfg{inp, out, flt, fthr, fmt, tt, tg, ta, tq, tr, num(v), msl, mrd, mqd, reg, aw, am, ar, err}
        False: when(Cfg, String.eq(k, "--msl"), \{
        True: Cfg{inp, out, flt, fthr, fmt, tt, tg, ta, tq, tr, mal, num(v), mrd, mqd, reg, aw, am, ar, err}
        False: when(Cfg, String.eq(k, "--mrd"), \{
        True: Cfg{inp, out, flt, fthr, fmt, tt, tg, ta, tq, tr, mal, msl, num(v), mqd, reg, aw, am, ar, err}
        False: when(Cfg, String.eq(k, "--mqd"), \{
        True: Cfg{inp, out, flt, fthr, fmt, tt, tg, ta, tq, tr, mal, msl, mrd, num(v), reg, aw, am, ar, err}
        False: when(Cfg, String.eq(k, "--reg"), \{
        True: Cfg{inp, out, flt, fthr, fmt, tt, tg, ta, tq, tr, mal, msl, mrd, mqd, num(v), aw, am, ar, err}
        False: when(Cfg, String.eq(k, "--aw"), \{
        True: Cfg{inp, out, flt, fthr, fmt, tt, tg, ta, tq, tr, mal, msl, mrd, mqd, reg, num(v), am, ar, err}
        False: when(Cfg, String.eq(k, "--am"), \{
        True: Cfg{inp, out, flt, fthr, fmt, tt, tg, ta, tq, tr, mal, msl, mrd, mqd, reg, aw, num(v), ar, err}
        False: when(Cfg, String.eq(k, "--ar"), \{
        True: Cfg{inp, out, flt, fthr, fmt, tt, tg, ta, tq, tr, mal, msl, mrd, mqd, reg, aw, am, num(v), err}
        False: when(Cfg, String.eq(k, "-t") || String.eq(k, "--threads") || String.eq(k, "-v"), \{
        True: Cfg{inp, out, flt, fthr, fmt, tt, tg, ta, tq, tr, mal, msl, mrd, mqd, reg, aw, am, ar, err}
        False: Cfg{inp, out, flt, fthr, fmt, tt, tg, ta, tq, tr, mal, msl, mrd, mqd, reg, aw, am, ar,
          "unknown or unsupported option: " ++ k}
        })})})})})})})})})})})})})})})})})})
      })

def parse_args(xs: List<String>, +c: Cfg) -> Cfg:
  match xs:
    case Nil{}:
      c
    case Con{+k, Nil{}}:
      cfg_set("?", "", cfg_set(k, "", c))
    case Con{+k, Con{+v, rest}}:
      parse_args(rest, cfg_set(k, v, c))

def args_tail(xs: List<String>) -> List<String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      t

# configuration problems ("" when fine)
def cfg_check(+c: Cfg) -> String:
  match c:
    case Cfg{+inp, +out, flt, +fthr, +fmt, +tt, +tg, +ta, +tq, +tr, +mal, +msl, +mrd,
             +mqd, +reg, +aw, +am, +ar, +err}:
      +bad = U32.is_gt(fmt, 2) || U32.is_gt(fthr, 1000000000) || U32.is_gt(tt, 1000000000)
        || U32.is_gt(tg, 1000000000) || U32.is_gt(ta, 1000000000) || U32.is_gt(tq, 1000000000)
        || U32.is_gt(tr, 1000000000)
      +badp = U32.is_lt(mal, 1) || U32.is_gt(mal, 16) || U32.is_lt(msl, 1) || U32.is_gt(msl, 12)
        || U32.is_gt(mrd, 100000) || U32.is_gt(mqd, 100000) || U32.is_gt(reg, 100000000)
        || U32.is_lt(aw, 1) || U32.is_gt(aw, 32) || U32.is_gt(am, 1000) || U32.is_gt(ar, 1000)
      when(String, Bool.not(String.is_empty(err)), \{
        True: err
        False: when(String, String.is_empty(inp) || String.is_empty(out), \{
          True: "the following arguments are required: -i/--in, -o/--out"
          False: when(String, bad, \{
            True: "invalid --outfmt or threshold (thresholds must be in 0..1)"
            False: when(String, badp, \{
              True: "unsupported LZ-ANI parameter (this port needs 1<=mal<=16, 1<=msl<=12, 1<=aw<=32)"
              False: ""
            })
          })
        })
      })

def cfg_prm(+c: Cfg) -> L.Prm:
  match c:
    case Cfg{inp, out, flt, fthr, fmt, tt, tg, ta, tq, tr, mal, msl, mrd, mqd, reg, aw, am, ar, err}:
      L.Prm{mal, msl, mrd, mqd, reg, aw, am, ar}

# Reading files
# =============

def bytes_last_nl(xs: List<&2, U32>, +i: U32, +best: U32) -> U32:
  match xs:
    case Nil{}:
      best
    case Con{+c, rest}:
      bytes_last_nl(rest, (i + 1 : U32), N.u32_if(U32.is_eq(c, 10), (i + 1 : U32), best))

def last_nl.k(+start: U32, r: File & Result<&1, &1, U32 & String, List<&2, U32>>,
              k: File -> U32 -> IO(File & U32)) -> IO(File & U32):
  (file, res) = r
  match res:
    case Fail{e}:
      IO.pure(File & U32, (file, 0))
    case Done{+bytes}:
      +p = bytes_last_nl(bytes, 0, 0)
      when(IO(File & U32), U32.is_gt(p, 0) || U32.is_eq(start, 0), \{
        True: IO.pure(File & U32, (file, N.u32_if(U32.is_gt(p, 0), (start + p : U32), 0)))
        False: k(file)(start)
      })

# number of bytes up to and including the last '\n' (getline drops the rest)
def last_nl(+fuel: Nat, file: File, +end: U32) -> IO(File & U32):
  match fuel:
    case 0n:
      IO.pure(File & U32, (file, 0))
    case 1n+f:
      +start = N.u32_monus(end, 1048576)
      do IO<File & U32>:
        r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_at(file, start, (end - start : U32))
        last_nl.k(start, r, h => e => last_nl(f, h, e))

def fa_read.k(r: File & Result<&1, &1, U32 & String, List<&2, U32>>, +st: R.FS,
              k: File -> R.FS -> IO(File & R.FS)) -> IO(File & R.FS):
  (file, res) = r
  match res:
    case Fail{e}:
      IO.pure(File & R.FS, (file, st))
    case Done{bytes}:
      match bytes:
        case Nil{}:
          IO.pure(File & R.FS, (file, st))
        case Con{+h, +t}:
          k(file)(R.fs_feed(Con{h, t}, st))

def fa_read(+fuel: Nat, file: File, +st: R.FS) -> IO(File & R.FS):
  match fuel:
    case 0n:
      IO.pure(File & R.FS, (file, st))
    case 1n+f:
      do IO<File & R.FS>:
        r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 1048576)
        fa_read.k(r, st, h => s => fa_read(f, h, s))

def fl_read.k(r: File & Result<&1, &1, U32 & String, List<&2, U32>>, +st: R.FL,
              k: File -> R.FL -> IO(File & R.FL)) -> IO(File & R.FL):
  (file, res) = r
  match res:
    case Fail{e}:
      IO.pure(File & R.FL, (file, st))
    case Done{bytes}:
      match bytes:
        case Nil{}:
          IO.pure(File & R.FL, (file, st))
        case Con{+h, +t}:
          k(file)(R.fl_feed(Con{h, t}, st))

def fl_read(+fuel: Nat, file: File, +st: R.FL) -> IO(File & R.FL):
  match fuel:
    case 0n:
      IO.pure(File & R.FL, (file, st))
    case 1n+f:
      do IO<File & R.FL>:
        r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 1048576)
        fl_read.k(r, st, h => s => fl_read(f, h, s))

def fuel_for(+size: U32) -> Nat:
  U32.to_nat((U32.shrn(size, 20n) + 3 : U32))

def read_fasta.c(got: File & R.FS) -> IO(List<&2, R.Rec>):
  (f3, +st) = got
  do IO<List<&2, R.Rec>>:
    File.close(f3)
    return R.fs_done(st)

def read_fasta.b(r: File & U32) -> IO(List<&2, R.Rec>):
  (f2, +limit) = r
  do IO<List<&2, R.Rec>>:
    got : File & R.FS <- fa_read(fuel_for(limit), f2, R.fs_new(limit))
    read_fasta.c(got)

def file_size(r: File & Result<&1, &1, U32 & String, U32>) -> File & U32:
  (file, res) = r
  match res:
    case Fail{e}:
      (file, 0)
    case Done{n}:
      (file, n)

def read_fasta.a(r: File & U32) -> IO(List<&2, R.Rec>):
  (file, +size) = r
  do IO<List<&2, R.Rec>>:
    lim : File & U32 <- last_nl(fuel_for(size), file, size)
    read_fasta.b(lim)

def read_fasta(+path: String) -> IO(List<&2, R.Rec>):
  do IO<List<&2, R.Rec>>:
    file : File <- IO.try(File, File.open(path, "r"))
    sz : File & Result<&1, &1, U32 & String, U32> <- File.size(file)
    read_fasta.a(file_size(sz))

def read_filter.b(got: File & R.FL) -> IO(R.FL):
  (f3, +st) = got
  do IO<R.FL>:
    File.close(f3)
    return R.fl_done(st)

def read_filter.a(+thr: U32, r: File & U32) -> IO(R.FL):
  (file, +size) = r
  do IO<R.FL>:
    got : File & R.FL <- fl_read(fuel_for(size), file, R.fl_new(thr))
    read_filter.b(got)

def read_filter(+path: String, +thr: U32) -> IO(R.FL):
  do IO<R.FL>:
    file : File <- IO.try(File, File.open(path, "r"))
    sz : File & Result<&1, &1, U32 & String, U32> <- File.size(file)
    read_filter.a(thr, file_size(sz))

# Ordering (CSeqReservoir::reorder_items)
# =======================================

type SR is Data:
  SR{key: U32, name: List<&2, U32>, idx: U32, seq: L.Seq}

def bytes_le(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  match a b:
    case Nil{} _:
      True{}
    case Con{x, xs} Nil{}:
      False{}
    case Con{+x, xs} Con{+y, ys}:
      when(Bool, U32.is_eq(x, y), \{
        True: bytes_le(xs, ys)
        False: U32.is_lt(x, y)
      })

def bytes_eq(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Nil{} Con{y, ys}:
      False{}
    case Con{x, xs} Nil{}:
      False{}
    case Con{+x, xs} Con{+y, ys}:
      U32.is_eq(x, y) && bytes_eq(xs, ys)

# longer first (len - 2 as uint32), then by name
def sr_le(a: SR, b: SR) -> Bool:
  match a b:
    case SR{+ka, na, ia, sa} SR{+kb, nb, ib, sb}:
      U32.is_gt(ka, kb) || (U32.is_eq(ka, kb) && bytes_le(na, nb))

def u32_le(a: U32, b: U32) -> Bool:
  U32.is_le(a, b)

def mk_srs(rs: List<&2, R.Rec>, +i: U32) -> List<&2, SR>:
  match rs:
    case Nil{}:
      Nil{}
    case Con{R.Rec{+name, +seq}, rest}:
      SR{(L.seq_len(seq) - 2 : U32), name, i, seq} <> mk_srs(rest, (i + 1 : U32))

def rec_names(rs: List<&2, R.Rec>) -> R.NL:
  match rs:
    case Nil{}:
      R.NLNil{}
    case Con{R.Rec{+name, seq}, rest}:
      R.NLCon{name, rec_names(rest)}

def nl_eq(a: R.NL, b: R.NL) -> Bool:
  match a b:
    case R.NLNil{} R.NLNil{}:
      True{}
    case R.NLNil{} R.NLCon{y, ys}:
      False{}
    case R.NLCon{x, xs} R.NLNil{}:
      False{}
    case R.NLCon{x, xs} R.NLCon{y, ys}:
      bytes_eq(x, y) && nl_eq(xs, ys)

# per sorted position: sequence, name, length; and file index -> position
type Tabs is Type:
  Tabs{ord: Array<U32>, seqs: Array<L.Seq>, names: Array<List<&2, U32>>, lens: Array<U32>}

def tabs_fill(xs: List<&2, SR>, +pos: U32, t: Tabs) -> Tabs:
  match xs:
    case Nil{}:
      t
    case Con{SR{k, +name, +idx, +seq}, rest}:
      match t:
        case Tabs{ord, seqs, names, lens}:
          tabs_fill(rest, (pos + 1 : U32), Tabs{Array.set(U32, ord, idx, pos),
            Array.set(L.Seq, seqs, pos, seq), Array.set(List<&2, U32>, names, pos, name),
            Array.set(U32, lens, pos, L.seq_len(seq))})

def seq_empty() -> L.Seq:
  L.Seq{0, L.WsNil{}, L.NRNil{}}

def tabs_new(+d: Nat) -> Tabs:
  Tabs{Array.new(U32, d, 0), Array.new(L.Seq, d, seq_empty()),
    Array.new(List<&2, U32>, d, Nil{}), Array.new(U32, d, 0)}

# Candidate pairs
# ===============

type LL is Data:
  LL{x: List<&2, U32>}

def adj_add.k(+at: U32, +x: U32, r: Array<List<&2, U32>> & List<&2, U32>) -> Array<List<&2, U32>>:
  (a, +old) = r
  Array.set(List<&2, U32>, a, at, x <> old)

def adj_add(a: Array<List<&2, U32>>, +at: U32, +x: U32) -> Array<List<&2, U32>>:
  adj_add.k(at, x, Array.swap(List<&2, U32>, a, at, Nil{}))

type AJ is Type:
  AJ{ord: Array<U32>, adj: Array<List<&2, U32>>}

def aj.c(+a: U32, adj: Array<List<&2, U32>>, r: Array<U32> & U32) -> AJ:
  (ord, +b) = r
  AJ{ord, adj_add(adj_add(adj, a, b), b, a)}

def aj.b(+j: U32, adj: Array<List<&2, U32>>, r: Array<U32> & U32) -> AJ:
  (ord, +a) = r
  aj.c(a, adj, Array.get(U32, ord, j))

def aj.step(ok: Bool, +i: U32, +j: U32, s: AJ) -> AJ:
  match ok s:
    case False{} AJ{ord, adj}:
      AJ{ord, adj}
    case True{} AJ{ord, adj}:
      aj.b(j, adj, Array.get(U32, ord, i))

# filter pairs (file indices) -> symmetric adjacency (sorted positions)
def aj.go(ps: List<&2, R.P2>, +n: U32, s: AJ) -> AJ:
  match ps:
    case Nil{}:
      s
    case Con{R.P2{+i, +j}, rest}:
      aj.go(rest, n, aj.step(U32.is_lt(i, n) && U32.is_lt(j, n), i, j, s))

def range_list(+fuel: Nat, +from: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match fuel:
    case 0n:
      acc
    case 1n+f:
      range_list(f, (from + 1 : U32), from <> acc)

# no filter: every pair (only partners above a are needed)
def all_pairs(+fuel: Nat, +a: U32, +n: U32, adj: Array<List<&2, U32>>) -> Array<List<&2, U32>>:
  match fuel:
    case 0n:
      adj
    case 1n+f:
      all_pairs(f, (a + 1 : U32), n, Array.set(List<&2, U32>, adj, a,
        range_list(U32.to_nat((n - a - 1 : U32)), (a + 1 : U32), Nil{})))

# Jobs: pair k = (a, b), a < b, in output order; slot 2k parses b against
# reference a, slot 2k + 1 parses a against reference b
type PK is Data:
  PK{a: U32, b: U32}

type JS is Type:
  JS{jobs: Array<List<&2, L.Job>>, seqs: Array<L.Seq>, k: U32, pk: List<&2, PK>, total: U32}

def job_add.k(+at: U32, +j: L.Job, r: Array<List<&2, L.Job>> & List<&2, L.Job>) -> Array<List<&2, L.Job>>:
  (a, +old) = r
  Array.set(List<&2, L.Job>, a, at, j <> old)

def job_add(a: Array<List<&2, L.Job>>, +at: U32, +j: L.Job) -> Array<List<&2, L.Job>>:
  job_add.k(at, j, Array.swap(List<&2, L.Job>, a, at, Nil{}))

def cost_of(+len: U32) -> U32:
  (U32.shrn(len, 10n) + 1 : U32)

def js.c(+a: U32, +b: U32, +sa: L.Seq, jobs: Array<List<&2, L.Job>>, +k: U32, +pk: List<&2, PK>,
         +total: U32, r: Array<L.Seq> & L.Seq) -> JS:
  (seqs, +sb) = r
  JS{job_add(job_add(jobs, a, L.Job{(k + k : U32), sb}), b, L.Job{(k + k + 1 : U32), sa}), seqs,
    (k + 1 : U32), PK{a, b} <> pk, (total + cost_of(L.seq_len(sa)) + cost_of(L.seq_len(sb)) : U32)}

def js.b(ok: Bool, +a: U32, +b: U32, +sa: L.Seq, s: JS) -> JS:
  match ok s:
    case False{} JS{jobs, seqs, k, pk, total}:
      JS{jobs, seqs, k, pk, total}
    case True{} JS{jobs, seqs, +k, +pk, +total}:
      js.c(a, b, sa, jobs, k, pk, total, Array.get(L.Seq, seqs, b))

def js.list(xs: List<&2, U32>, +a: U32, +sa: L.Seq, s: JS) -> JS:
  match xs:
    case Nil{}:
      s
    case Con{+b, rest}:
      js.list(rest, a, sa, js.b(U32.is_gt(b, a), a, b, sa, s))

def js.a2(+a: U32, xs: List<&2, U32>, jobs: Array<List<&2, L.Job>>, +k: U32, +pk: List<&2, PK>,
          +total: U32, r: Array<L.Seq> & L.Seq) -> JS:
  (seqs, +sa) = r
  js.list(List.sort(~U32, ~u32_le, xs), a, sa, JS{jobs, seqs, k, pk, total})

def js.a(+a: U32, xs: List<&2, U32>, s: JS) -> JS:
  match s:
    case JS{jobs, seqs, +k, +pk, +total}:
      js.a2(a, xs, jobs, k, pk, total, Array.get(L.Seq, seqs, a))


def js.r(+a: U32, s: JS, r: Array<List<&2, U32>> & List<&2, U32>) -> Array<List<&2, U32>> & JS:
  (adj, xs) = r
  (adj, js.a(a, xs, s))

# all pairs in output order, with their two jobs
def js.go(+fuel: Nat, q: Array<List<&2, U32>> & JS, +a: U32) -> Array<List<&2, U32>> & JS:
  match fuel:
    case 0n:
      q
    case 1n+f:
      (adj, s) = q
      js.go(f, js.r(a, s, Array.swap(List<&2, U32>, adj, a, Nil{})), (a + 1 : U32))

# Work units and the fork tree
# ============================

type UN is Data:
  UN{ref: L.Seq, jobs: List<&2, L.Job>, cost: U32}

def un_emit(c: Bool, +rs: L.Seq, +cur: List<&2, L.Job>, +cost: U32, us: List<&2, UN>) -> List<&2, UN>:
  match c:
    case True{}:
      UN{rs, cur, cost} <> us
    case False{}:
      us

def cur_next(cut: Bool, +j: L.Job, cur: List<&2, L.Job>) -> List<&2, L.Job>:
  match cut:
    case True{}:
      j <> Nil{}
    case False{}:
      j <> cur

# split one reference's jobs into units of about thr cost
def chunk(js: List<&2, L.Job>, +rs: L.Seq, +rc: U32, +thr: U32, +cur: List<&2, L.Job>, +cc: U32,
          us: List<&2, UN>) -> List<&2, UN>:
  match js:
    case Nil{}:
      un_emit(U32.is_gt(cc, 0), rs, cur, (rc + cc : U32), us)
    case Con{+j, rest}:
      match j:
        case L.Job{s, +q}:
          +c = cost_of(L.seq_len(q))
          +cut = U32.is_gt(cc, 0) && U32.is_gt((cc + c : U32), thr)
          chunk(rest, rs, rc, thr, cur_next(cut, j, cur), N.u32_if(cut, c, (cc + c : U32)),
            un_emit(cut, rs, cur, (rc + cc : U32), us))

type UB is Type:
  UB{jobs: Array<List<&2, L.Job>>, seqs: Array<L.Seq>, us: List<&2, UN>}

def ub.b(+thr: U32, xs: List<&2, L.Job>, jobs: Array<List<&2, L.Job>>, +us: List<&2, UN>,
         r: Array<L.Seq> & L.Seq) -> UB:
  (seqs, +rs) = r
  +rc = (cost_of(L.seq_len(rs)) * 2 : U32)
  UB{jobs, seqs, chunk(xs, rs, rc, N.u32_max(thr, (rc * 2 : U32)), Nil{}, 0, us)}

def ub.a(+thr: U32, +a: U32, seqs: Array<L.Seq>, +us: List<&2, UN>,
         r: Array<List<&2, L.Job>> & List<&2, L.Job>) -> UB:
  (jobs, xs) = r
  ub.b(thr, xs, jobs, us, Array.get(L.Seq, seqs, a))

def ub.go(+fuel: Nat, s: UB, +thr: U32, +a: U32) -> UB:
  match fuel s:
    case 0n UB{jobs, seqs, us}:
      UB{jobs, seqs, us}
    case 1n+f UB{jobs, seqs, +us}:
      ub.go(f, ub.a(thr, a, seqs, us, Array.swap(List<&2, L.Job>, jobs, a, Nil{})), thr, (a + 1 : U32))

def un_cost(+u: UN) -> U32:
  match u:
    case UN{r, j, c}:
      c

def un_total(us: List<&2, UN>, +acc: U32) -> U32:
  match us:
    case Nil{}:
      acc
    case Con{+u, rest}:
      un_total(rest, (acc + un_cost(u) : U32))

def un_count(us: List<&2, UN>, +acc: U32) -> U32:
  match us:
    case Nil{}:
      acc
    case Con{u, rest}:
      un_count(rest, (acc + 1 : U32))

type UL is Data:
  UL{xs: List<&2, UN>}

def ul_rev(xs: List<&2, UN>, acc: List<&2, UN>) -> List<&2, UN>:
  match xs:
    case Nil{}:
      acc
    case Con{+x, rest}:
      ul_rev(rest, x <> acc)

# SP{leaf, left, left cost, right, right cost}
type SP is Data:
  SP{leaf: Bool, l: List<&2, UN>, lc: U32, r: List<&2, UN>, rc: U32}

def split.go(us: List<&2, UN>, +total: U32, +half: U32, +acc: U32, lrev: List<&2, UN>) -> SP:
  match us:
    case Nil{}:
      SP{True{}, ul_rev(lrev, Nil{}), acc, Nil{}, 0}
    case Con{+u, Nil{}}:
      when(SP, U32.is_eq(acc, 0) && U32.is_eq(un_cost(u), 0), \{
        True: SP{True{}, ul_rev(lrev, u <> Nil{}), total, Nil{}, 0}
        False: SP{False{}, ul_rev(lrev, Nil{}), acc, u <> Nil{}, (total - acc : U32)}
      })
    case Con{+u, +rest}:
      +c = un_cost(u)
      when(SP, U32.is_gt(acc, 0) && U32.is_gt((acc + c : U32), half), \{
        True: SP{False{}, ul_rev(lrev, Nil{}), acc, u <> rest, (total - acc : U32)}
        False: split.go(rest, total, half, (acc + c : U32), u <> lrev)
      })

def split(+us: List<&2, UN>, +total: U32) -> SP:
  match us:
    case Nil{}:
      SP{True{}, Nil{}, 0, Nil{}, 0}
    case Con{+u, Nil{}}:
      SP{True{}, u <> Nil{}, total, Nil{}, 0}
    case Con{u, t}:
      split.go(us, total, U32.shrn(total, 1n), 0, Nil{})

type WT is Data:
  WLeaf{us: List<&2, UN>}
  WNode{l: WT, r: WT}

def ul_cat(a: List<&2, UN>, b: List<&2, UN>) -> List<&2, UN>:
  match a:
    case Nil{}:
      b
    case Con{+x, rest}:
      x <> ul_cat(rest, b)

def build(+fuel: Nat, sp: SP) -> WT:
  match fuel sp:
    case _ SP{True{}, l, lc, r, rc}:
      WLeaf{l}
    case 0n SP{False{}, l, lc, r, rc}:
      WLeaf{ul_cat(l, r)}
    case 1n+f SP{False{}, +l, +lc, +r, +rc}:
      WNode{build(f, split(l, lc)), build(f, split(r, rc))}

def run_seq(us: List<&2, UN>, +p: L.Prm, +ct: List<&2, U32>) -> L.Out:
  match us:
    case Nil{}:
      L.ONil{}
    case Con{UN{+rs, +js, c}, rest}:
      L.ONode{L.run_unit(p, ct, rs, js), run_seq(rest, p, ct)}

# the parallel part: a balanced fork-join over the work tree
def run_tree(+t: WT, +p: L.Prm, +ct: List<&2, U32>) -> L.Out:
  match t:
    case WLeaf{+us}:
      run_seq(us, p, ct)
    case WNode{+l, +r}:
      x y = run_tree(l, p, ct) run_tree(r, p, ct)
      L.ONode{x, y}

# Results
# =======
# res[3 * slot + 0..2] = nt_match, nt_mismatch, num_alns

def put_res(+slot: U32, r: L.Res, a: Array<U32>) -> Array<U32>:
  match r:
    case L.Res{+m, +l, +c}:
      +at = (slot * 3 : U32)
      Array.set(U32, Array.set(U32, Array.set(U32, a, at, m), (at + 1 : U32), l), (at + 2 : U32), c)

def write_out(o: L.Out, a: Array<U32>) -> Array<U32>:
  match o:
    case L.ONil{}:
      a
    case L.OCon{+slot, +r, tail}:
      write_out(tail, put_res(slot, r, a))
    case L.ONode{l, r}:
      write_out(r, write_out(l, a))

# Output rows (CLZMatcher::store_results)
# =======================================

type TH is Data:
  TH{tt: U32, tg: U32, ta: U32, tq: U32, tr: U32}

type RowIn is Data:
  RowIn{q: U32, r: U32, qn: List<&2, U32>, rn: List<&2, U32>, m: U32, l: U32, c: U32,
    qlen: U32, rlen: U32, mo: U32, lo: U32}

def tab(tail: List<&2, U32>) -> List<&2, U32>:
  9 <> tail

def val_lt(+a: U32, +b: U32, +t: U32) -> Bool:
  when(Bool, U32.is_eq(b, 0), \{
    True: U32.is_gt(t, 0)
    False: N.ratio_lt(a, b, t)
  })

def len_ratio(+x: U32, +y: U32, tail: List<&2, U32>) -> List<&2, U32>:
  when(List<&2, U32>, U32.is_eq(x, 0) || U32.is_eq(y, 0), \{
    True: 48 <> tail
    False: N.fmt_ratio(N.u32_min(x, y), N.u32_max(x, y), 4, tail)
  })

def row_tail(+fmt: U32, +m: U32, +l: U32, +qlen: U32, +rlen: U32) -> List<&2, U32>:
  when(List<&2, U32>, U32.is_eq(fmt, 2), \{
    True: tab(N.put_u32(qlen, tab(N.put_u32(rlen, tab(N.put_u32(m, tab(N.put_u32(l, 10 <> Nil{}))))))))
    False: 10 <> Nil{}
  })

def row_core(+fmt: U32, ri: RowIn, tail: List<&2, U32>) -> List<&2, U32>:
  match ri:
    case RowIn{q, r, qn, rn, +m, +l, +c, +qlen, +rlen, +mo, +lo}:
      N.fmt_ratio((m + mo : U32), (qlen + rlen : U32), 6, tab(
      N.fmt_ratio(m, qlen, 6, tab(
      N.fmt_ratio(m, (m + l : U32), 6, tab(
      N.fmt_ratio((m + l : U32), qlen, 6, tab(
      N.fmt_ratio((mo + lo : U32), rlen, 6, tab(
      N.put_u32(c, tab(len_ratio(qlen, rlen, N.put_str(row_tail(fmt, m, l, qlen, rlen), tail))))))))))))))

def row_keep(+th: TH, +ri: RowIn) -> Bool:
  match th ri:
    case TH{+tt, +tg, +ta, +tq, +tr} RowIn{q, r, qn, rn, +m, +l, c, +qlen, +rlen, +mo, +lo}:
      Bool.not(val_lt(m, qlen, tg) || val_lt(m, (m + l : U32), ta)
        || val_lt((m + mo : U32), (qlen + rlen : U32), tt) || val_lt((m + l : U32), qlen, tq)
        || val_lt((mo + lo : U32), rlen, tr))

def row_line(+fmt: U32, +ri: RowIn, tail: List<&2, U32>) -> List<&2, U32>:
  match ri:
    case RowIn{+q, +r, +qn, +rn, m, l, c, qlen, rlen, mo, lo}:
      N.put_u32(q, tab(N.put_u32(r, tab(when(List<&2, U32>, U32.is_eq(fmt, 0), \{
        True: row_core(fmt, ri, tail)
        False: N.put_str(qn, tab(N.put_str(rn, tab(row_core(fmt, ri, tail)))))
      })))))

def row(+fmt: U32, +th: TH, +ri: RowIn, tail: List<&2, U32>) -> List<&2, U32>:
  when(List<&2, U32>, row_keep(th, ri), \{
    True: row_line(fmt, ri, tail)
    False: tail
  })

def header(+fmt: U32) -> String:
  when(String, U32.is_eq(fmt, 0), \{
    True: "qidx\tridx\ttani\tgani\tani\tqcov\trcov\tnum_alns\tlen_ratio\n"
    False: when(String, U32.is_eq(fmt, 1), \{
      True: "qidx\tridx\tquery\treference\ttani\tgani\tani\tqcov\trcov\tnum_alns\tlen_ratio\n"
      False: "qidx\tridx\tquery\treference\ttani\tgani\tani\tqcov\trcov\tnum_alns\tlen_ratio\tqlen\trlen\tnt_match\tnt_mismatch\n"
    })
  })

type OS is Type:
  OS{res: Array<U32>, names: Array<List<&2, U32>>, lens: Array<U32>}

def g32(-B: Type, q: Array<U32> & U32, k: Array<U32> -> U32 -> B) -> B:
  (a2, +v) = q
  k(a2)(v)

def gname(-B: Type, q: Array<List<&2, U32>> & List<&2, U32>, k: Array<List<&2, U32>> -> List<&2, U32> -> B) -> B:
  (a2, +v) = q
  k(a2)(v)

def pair_rows(+fmt: U32, +th: TH, +k: U32, +p: PK, st: OS, tail: List<&2, U32>) -> OS & List<&2, U32>:
  match p st:
    case PK{+a, +b} OS{res, names, lens}:
      +at = (k * 6 : U32)
      g32(OS & List<&2, U32>, Array.get(U32, res, at), r1 => +m0 =>
      g32(OS & List<&2, U32>, Array.get(U32, r1, (at + 1 : U32)), r2 => +l0 =>
      g32(OS & List<&2, U32>, Array.get(U32, r2, (at + 2 : U32)), r3 => +c0 =>
      g32(OS & List<&2, U32>, Array.get(U32, r3, (at + 3 : U32)), r4 => +m1 =>
      g32(OS & List<&2, U32>, Array.get(U32, r4, (at + 4 : U32)), r5 => +l1 =>
      g32(OS & List<&2, U32>, Array.get(U32, r5, (at + 5 : U32)), r6 => +c1 =>
      g32(OS & List<&2, U32>, Array.get(U32, lens, b), s1 => +len0 =>
      g32(OS & List<&2, U32>, Array.get(U32, s1, a), s2 => +len1 =>
      gname(OS & List<&2, U32>, Array.get(List<&2, U32>, names, a), n1 => +na =>
      gname(OS & List<&2, U32>, Array.get(List<&2, U32>, n1, b), n2 => +nb =>
        (OS{r6, n2, s2},
         row(fmt, th, RowIn{b, a, nb, na, m0, l0, c0, len0, len1, m1, l1},
           row(fmt, th, RowIn{a, b, na, nb, m1, l1, c1, len1, len0, m0, l0}, tail)))))))))))))

type EM is Type:
  EM{st: OS, bytes: List<&2, U32>, rest: List<&2, PK>, k: U32}

def emit.k2(rest: List<&2, PK>, +k2: U32, r: OS & List<&2, U32>) -> EM:
  (st, bytes) = r
  EM{st, bytes, rest, k2}

def emit.k(+fmt: U32, +th: TH, +k: U32, +p: PK, e: EM) -> EM:
  match e:
    case EM{st, bytes, rest, k2}:
      emit.k2(rest, k2, pair_rows(fmt, th, k, p, st, bytes))

# rows of up to fuel pairs starting at pair k
def emit(+fuel: Nat, +fmt: U32, +th: TH, ps: List<&2, PK>, +k: U32, st: OS) -> EM:
  match fuel ps:
    case _ Nil{}:
      EM{st, Nil{}, Nil{}, k}
    case 0n Con{+p, +rest}:
      EM{st, Nil{}, p <> rest, k}
    case 1n+f Con{+p, rest}:
      emit.k(fmt, th, k, p, emit(f, fmt, th, rest, (k + 1 : U32), st))

def write_rows.k(r: File & Result<&1, &1, U32 & String, Unit>, k: File -> IO(Unit)) -> IO(Unit):
  (file, res) = r
  k(file)

def write_rows(+fuel: Nat, file: File, +fmt: U32, +th: TH, e: EM) -> IO(Unit):
  match fuel e:
    case 0n EM{st, bytes, rest, k}:
      File.close(file)
    case 1n+f EM{st, +bytes, +rest, +k}:
      when(IO(Unit), R.is_empty(bytes) && List.is_empty(&2, PK, rest), \{
        True: File.close(file)
        False: do IO<Unit>:
          w : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(file, bytes)
          write_rows.k(w, h => write_rows(f, h, fmt, th, emit(4096n, fmt, th, rest, k, st)))
      })

# Pipeline
# ========

type Plan is Type:
  Plan{st: OS, pairs: List<&2, PK>, np: U32, n: U32, err: String}

def recs_count(rs: List<&2, R.Rec>, +acc: U32) -> U32:
  match rs:
    case Nil{}:
      acc
    case Con{r, rest}:
      recs_count(rest, (acc + 1 : U32))

def pk_rev(xs: List<&2, PK>, acc: List<&2, PK>) -> List<&2, PK>:
  match xs:
    case Nil{}:
      acc
    case Con{+x, rest}:
      pk_rev(rest, x <> acc)

def plan.e(+n: U32, names: Array<List<&2, U32>>, lens: Array<U32>, +pk: List<&2, PK>, +k: U32,
           +p: L.Prm, +ct: List<&2, U32>, +t: WT) -> Plan:
  Plan{OS{write_out(run_tree(t, p, ct), Array.new(U32, N.depth((k * 6 + 6 : U32)), 0)), names, lens},
    pk_rev(pk, Nil{}), k, n, ""}

def plan.d(+n: U32, names: Array<List<&2, U32>>, lens: Array<U32>, +pk: List<&2, PK>, +k: U32,
           +p: L.Prm, +ct: List<&2, U32>, s: UB) -> Plan:
  match s:
    case UB{jobs, seqs, +us}:
      plan.e(n, names, lens, pk, k, p, ct, build(48n, split(us, un_total(us, 0))))

def plan.c(names: Array<List<&2, U32>>, lens: Array<U32>, +n: U32, +threads: U32, +p: L.Prm,
           +ct: List<&2, U32>, r: Array<List<&2, U32>> & JS) -> Plan:
  (adj, s) = r
  match s:
    case JS{jobs, seqs, +k, +pk, +total}:
      # one task per reference row (CLZMatcher::do_matching: a worker takes the
      # next row, prepares it as reference once and parses all its partners)
      +thr = {4294967295 : U32}
      plan.d(n, names, lens, pk, k, p, ct, ub.go(U32.to_nat(n), UB{jobs, seqs, Nil{}}, thr, 0))

def plan.b(+n: U32, +d: Nat, +threads: U32, +p: L.Prm, +ct: List<&2, U32>, seqs: Array<L.Seq>,
           names: Array<List<&2, U32>>, lens: Array<U32>, adj: Array<List<&2, U32>>) -> Plan:
  plan.c(names, lens, n, threads, p, ct, js.go(U32.to_nat(n),
    (adj, JS{Array.new(List<&2, L.Job>, d, Nil{}), seqs, 0, Nil{}, 0}), 0))

def plan.a2(+n: U32, +d: Nat, +threads: U32, +p: L.Prm, +ct: List<&2, U32>, seqs: Array<L.Seq>,
            names: Array<List<&2, U32>>, lens: Array<U32>, s: AJ) -> Plan:
  match s:
    case AJ{ord, adj}:
      plan.b(n, d, threads, p, ct, seqs, names, lens, adj)

def plan.a(+hasf: Bool, +ps: List<&2, R.P2>, +n: U32, +d: Nat, +threads: U32, +p: L.Prm,
           +ct: List<&2, U32>, t: Tabs) -> Plan:
  match hasf t:
    case True{} Tabs{ord, seqs, names, lens}:
      plan.a2(n, d, threads, p, ct, seqs, names, lens,
        aj.go(ps, n, AJ{ord, Array.new(List<&2, U32>, d, Nil{})}))
    case False{} Tabs{ord, seqs, names, lens}:
      plan.b(n, d, threads, p, ct, seqs, names, lens,
        all_pairs(U32.to_nat(n), 0, n, Array.new(List<&2, U32>, d, Nil{})))

def plan_err(+msg: String) -> Plan:
  Plan{OS{Array.new(U32, 0n, 0), Array.new(List<&2, U32>, 0n, Nil{}), Array.new(U32, 0n, 0)},
    Nil{}, 0, 0, msg}

def plan(+c: Cfg, +recs: List<&2, R.Rec>, +hasf: Bool, +fl: R.FL, +threads: U32) -> Plan:
  match fl:
    case R.FL{h, +nf, cur, +names, r, ll, fi, co, iv, idd, ids, vb, thr, +ps}:
      +n = recs_count(recs, 0)
      +d = N.depth(N.u32_max(n, 1))
      +bad = hasf && (U32.is_le(nf, 2) || Bool.not(nl_eq(R.nl_rev(names, R.NLNil{}), rec_names(recs))))
      when(Plan, bad, \{
        True: plan_err(when(String, U32.is_le(nf, 2), \{
          True: "Incorrect kmer-db filter file"
          False: "Input sequences and filter sequences are different!"
        }))
        False: (
          +p = cfg_prm(c)
          plan.a(hasf, ps, n, d, threads, p, L.close_table(L.prm_msl(p), L.prm_mqd(p), L.prm_mrd(p)),
            tabs_fill(List.sort(~SR, ~sr_le, mk_srs(recs, 0)), 0, tabs_new(d))))
      })

# ani.ids.tsv: name, length, parts in the sorted order
def ids_bytes(+fuel: Nat, +pos: U32, st: OS, acc: List<&2, U32>) -> OS & List<&2, U32>:
  match fuel st:
    case 0n OS{res, names, lens}:
      (OS{res, names, lens}, acc)
    case 1n+f OS{res, names, lens}:
      g32(OS & List<&2, U32>, Array.get(U32, lens, pos), l2 => +len =>
      gname(OS & List<&2, U32>, Array.get(List<&2, U32>, names, pos), n2 => +nm =>
        ids_bytes(f, (pos - 1 : U32), OS{res, n2, l2},
          N.put_str(nm, tab(N.put_u32(len, tab(49 <> 10 <> acc)))))))

def chars(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{+c, rest}:
      SCon{Chr{c}, chars(rest)}

def last_dot(xs: List<&2, U32>, +i: U32, +best: U32) -> U32:
  match xs:
    case Nil{}:
      best
    case Con{+c, rest}:
      last_dot(rest, (i + 1 : U32), N.u32_if(U32.is_eq(c, 46), i, best))

def ins_ids(xs: List<&2, U32>, +i: U32, +at: U32) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+c, rest}:
      when(List<&2, U32>, U32.is_eq(i, at), \{
        True: 46 <> 105 <> 100 <> 115 <> c <> rest
        False: c <> ins_ids(rest, (i + 1 : U32), at)
      })

# CLZMatcher::store_results: "x.tsv" -> "x.ids.tsv", "x" -> "x.ids"
def ids_path(+out: String) -> String:
  +bs = N.string_bytes(out)
  +d = last_dot(bs, 0, 4294967295)
  when(String, U32.is_eq(d, 4294967295), \{
    True: out ++ ".ids"
    False: chars(ins_ids(bs, 0, d))
  })

def write_ani.c(r: File & Result<&1, &1, U32 & String, Unit>, +fmt: U32, +th: TH, +pairs: List<&2, PK>,
                +np: U32, st: OS) -> IO(Unit):
  (fa, res) = r
  write_rows(U32.to_nat((U32.shrn(np, 12n) + 4 : U32)), fa, fmt, th, emit(4096n, fmt, th, pairs, 0, st))

def write_ani.b(r: File & Result<&1, &1, U32 & String, Unit>, +out: String, +fmt: U32, +th: TH,
                +pairs: List<&2, PK>, +np: U32, st: OS) -> IO(Unit):
  (fi, res) = r
  do IO<Unit>:
    File.close(fi)
    fa : File <- IO.try(File, File.open(out, "w"))
    w2 : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(fa, N.string_bytes(header(fmt)))
    write_ani.c(w2, fmt, th, pairs, np, st)

def write_ani(+c: Cfg, r: OS & List<&2, U32>, +pairs: List<&2, PK>, +np: U32) -> IO(Unit):
  match c:
    case Cfg{inp, +out, flt, fthr, +fmt, +tt, +tg, +ta, +tq, +tr, mal, msl, mrd, mqd, reg, aw, am, ar, err}:
      (st, +ids) = r
      +th = {TH{tt, tg, ta, tq, tr} : TH}
      do IO<Unit>:
        fi : File <- IO.try(File, File.open(ids_path(out), "w"))
        w1 : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(fi, N.put_str(N.string_bytes("id\tseq_len\tno_parts\n"), ids))
        write_ani.b(w1, out, fmt, th, pairs, np, st)


def finish(+c: Cfg, p: Plan) -> IO(Unit):
  match p:
    case Plan{st, +pairs, +np, +n, +err}:
      when(IO(Unit), String.is_empty(err), \{
        True: write_ani(c, ids_bytes(U32.to_nat(n), (n - 1 : U32), st, Nil{}), pairs, np)
        False: IO.die(Unit, 1, err)
      })

def run.b(+c: Cfg, +recs: List<&2, R.Rec>, +hasf: Bool, fl: R.FL) -> IO(Unit):
  do IO<Unit>:
    t : U32 <- IO.thread_count()
    finish(c, plan(c, recs, hasf, fl, t))

def run.a(+c: Cfg, recs: List<&2, R.Rec>) -> IO(Unit):
  match c:
    case Cfg{inp, out, +flt, +fthr, fmt, tt, tg, ta, tq, tr, mal, msl, mrd, mqd, reg, aw, am, ar, err}:
      when(IO(Unit), String.is_empty(flt), \{
        True: run.b(c, recs, False{}, R.fl_new(0))
        False: do IO<Unit>:
          fl : R.FL <- read_filter(flt, fthr)
          run.b(c, recs, True{}, fl)
      })

def run(+c: Cfg) -> IO(Unit):
  match c:
    case Cfg{+inp, out, flt, fthr, fmt, tt, tg, ta, tq, tr, mal, msl, mrd, mqd, reg, aw, am, ar, err}:
      +msg = cfg_check(c)
      when(IO(Unit), String.is_empty(msg), \{
        True: do IO<Unit>:
          recs : List<&2, R.Rec> <- read_fasta(inp)
          run.a(c, recs)
        False: IO.die(Unit, 1, msg)
      })

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(parse_args(args_tail(args), cfg_new()))
